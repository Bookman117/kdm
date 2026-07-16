#!/usr/bin/env bash

kdm_host_fail() {
  kdm_error "host preflight failed: $*"
  return "$KDM_EXIT_CONFIG"
}

kdm_compatibility_validate_lock() {
  local path="${1:-}"
  local profile_count profile record
  local os_id os_version architecture min_root_free cgroup_version
  local kube_version kube_package kube_repository kube_key_url kube_key_fingerprint kube_key_sha
  local runtime_name runtime_version runtime_package runtime_repository runtime_key_url runtime_key_fingerprint runtime_key_sha
  local kube_minor runtime_minor missing_fields expected_profile kube_base runtime_base

  kdm_require_yq_v4 || return "$?"
  [ -n "$path" ] || kdm_host_fail 'compatibility lock path is required' || return "$?"
  [ -r "$path" ] || kdm_host_fail 'compatibility lock is not readable' || return "$?"
  yq eval '.' "$path" >/dev/null 2>&1 || kdm_host_fail 'compatibility lock YAML parse failed' || return "$?"
  [ "$(yq -r '.apiVersion // ""' "$path")" = 'kdm.io/v2alpha1' ] || kdm_host_fail 'compatibility lock apiVersion is invalid' || return "$?"
  [ "$(yq -r '.kind // ""' "$path")" = 'CompatibilityLock' ] || kdm_host_fail 'compatibility lock kind is invalid' || return "$?"
  profile_count="$(yq -r '.profiles // {} | length' "$path")"
  [[ "$profile_count" =~ ^[0-9]+$ ]] && [ "$profile_count" -ge 1 ] || kdm_host_fail 'compatibility lock requires at least one profile' || return "$?"

  while IFS= read -r profile; do
    [[ "$profile" =~ ^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$ ]] || kdm_host_fail "compatibility profile name is invalid: ${profile}" || return "$?"
    missing_fields="$(KDM_PROFILE="$profile" yq -r '
      .profiles[strenv(KDM_PROFILE)] as $p |
      [
        $p.os.id, $p.os.version, $p.os.architecture, $p.os.minRootFreeMiB, $p.os.cgroupVersion,
        $p.kubernetes.minor, $p.kubernetes.version, $p.kubernetes.packageVersion,
        $p.kubernetes.repository, $p.kubernetes.keyUrl, $p.kubernetes.keyFingerprint, $p.kubernetes.keySha256,
        $p.runtime.name, $p.runtime.minor, $p.runtime.version, $p.runtime.packageVersion,
        $p.runtime.repository, $p.runtime.keyUrl, $p.runtime.keyFingerprint, $p.runtime.keySha256
      ] | map(select(. == null or . == "")) | length
    ' "$path")"
    [ "$missing_fields" -eq 0 ] || kdm_host_fail "compatibility profile has missing required fields: ${profile}" || return "$?"
    record="$(kdm_compatibility_profile_record "$path" "$profile")"
    IFS=$'\t' read -r os_id os_version architecture min_root_free cgroup_version \
      kube_version kube_package kube_repository kube_key_url kube_key_fingerprint kube_key_sha \
      runtime_name runtime_version runtime_package runtime_repository runtime_key_url runtime_key_fingerprint runtime_key_sha <<<"$record"
    [ -n "$os_id" ] && [ -n "$os_version" ] && [ -n "$architecture" ] || kdm_host_fail "compatibility profile OS fields are incomplete: ${profile}" || return "$?"
    [[ "$min_root_free" =~ ^[0-9]+$ ]] && [ "$min_root_free" -ge 1 ] || kdm_host_fail "compatibility profile minRootFreeMiB is invalid: ${profile}" || return "$?"
    [ "$cgroup_version" = v2 ] || kdm_host_fail "compatibility profile cgroupVersion must be v2: ${profile}" || return "$?"
    [[ "$kube_version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] && [ -n "$kube_package" ] || kdm_host_fail "Kubernetes version fields are invalid: ${profile}" || return "$?"
    [[ "$runtime_version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] && [ -n "$runtime_package" ] && [ "$runtime_name" = crio ] || kdm_host_fail "runtime version fields are invalid: ${profile}" || return "$?"
    case "$kube_repository $kube_key_url $runtime_repository $runtime_key_url" in *'http://'*) kdm_host_fail "repository URLs must use HTTPS: ${profile}" || return "$?" ;; esac
    [[ "$kube_repository" == https://* && "$kube_key_url" == https://* && "$runtime_repository" == https://* && "$runtime_key_url" == https://* ]] || kdm_host_fail "repository URLs are incomplete: ${profile}" || return "$?"
    [[ "$kube_key_fingerprint" =~ ^[A-F0-9]{40}$ && "$runtime_key_fingerprint" =~ ^[A-F0-9]{40}$ ]] || kdm_host_fail "key fingerprint is invalid: ${profile}" || return "$?"
    [[ "$kube_key_sha" =~ ^[a-f0-9]{64}$ && "$runtime_key_sha" =~ ^[a-f0-9]{64}$ ]] || kdm_host_fail "key SHA-256 is invalid: ${profile}" || return "$?"
    kube_minor="$(KDM_PROFILE="$profile" yq -r '.profiles[strenv(KDM_PROFILE)].kubernetes.minor // ""' "$path")"
    runtime_minor="$(KDM_PROFILE="$profile" yq -r '.profiles[strenv(KDM_PROFILE)].runtime.minor // ""' "$path")"
    [[ "$kube_minor" =~ ^v[0-9]+\.[0-9]+$ ]] && [ "$kube_minor" = "$runtime_minor" ] || kdm_host_fail "Kubernetes and runtime minor versions must match: ${profile}" || return "$?"
    case "$kube_version" in "${kube_minor}."*) ;; *) kdm_host_fail "Kubernetes version does not match minor: ${profile}" || return "$?" ;; esac
    case "$runtime_version" in "${runtime_minor}."*) ;; *) kdm_host_fail "runtime version does not match minor: ${profile}" || return "$?" ;; esac
    [[ "$kube_package" =~ ^[0-9]+\.[0-9]+\.[0-9]+-[0-9]+\.[0-9]+$ ]] || kdm_host_fail "Kubernetes packageVersion is invalid: ${profile}" || return "$?"
    [[ "$runtime_package" =~ ^[0-9]+\.[0-9]+\.[0-9]+-[0-9]+\.[0-9]+$ ]] || kdm_host_fail "runtime packageVersion is invalid: ${profile}" || return "$?"
    kube_base="${kube_package%%-*}"
    runtime_base="${runtime_package%%-*}"
    [ "$kube_base" = "${kube_version#v}" ] || kdm_host_fail "Kubernetes packageVersion does not match version: ${profile}" || return "$?"
    [ "$runtime_base" = "${runtime_version#v}" ] || kdm_host_fail "runtime packageVersion does not match version: ${profile}" || return "$?"
    [ "$kube_repository" = "https://pkgs.k8s.io/core:/stable:/${kube_minor}/deb/" ] || kdm_host_fail "Kubernetes repository does not match minor: ${profile}" || return "$?"
    [ "$runtime_repository" = "https://download.opensuse.org/repositories/isv:/cri-o:/stable:/${runtime_minor}/deb/" ] || kdm_host_fail "CRI-O repository does not match minor: ${profile}" || return "$?"
    [ "$kube_key_url" = "${kube_repository}Release.key" ] && [ "$runtime_key_url" = "${runtime_repository}Release.key" ] || kdm_host_fail "repository key URL does not match repository: ${profile}" || return "$?"
    expected_profile="${os_id}-${os_version}-${architecture}-k8s-${kube_minor#v}"
    [ "$profile" = "$expected_profile" ] || kdm_host_fail "compatibility profile name does not match its fields: ${profile}" || return "$?"
  done < <(yq -r '.profiles | keys | .[]' "$path")

  return 0
}

kdm_compatibility_profile_record() {
  local lock_path="$1"
  local profile="$2"

  KDM_PROFILE="$profile" yq -r '
    .profiles[strenv(KDM_PROFILE)] |
    select(. != null) |
    . as $p |
    [
      $p.os.id,
      $p.os.version,
      $p.os.architecture,
      $p.os.minRootFreeMiB,
      $p.os.cgroupVersion,
      $p.kubernetes.version,
      $p.kubernetes.packageVersion,
      $p.kubernetes.repository,
      $p.kubernetes.keyUrl,
      $p.kubernetes.keyFingerprint,
      $p.kubernetes.keySha256,
      $p.runtime.name,
      $p.runtime.version,
      $p.runtime.packageVersion,
      $p.runtime.repository,
      $p.runtime.keyUrl,
      $p.runtime.keyFingerprint,
      $p.runtime.keySha256
    ] | @tsv
  ' "$lock_path"
}

kdm_host_validate_map_keys() {
  local path="$1"
  local expression="$2"
  local context="$3"
  local key allowed matched
  shift 3

  while IFS= read -r key; do
    [ -n "$key" ] || continue
    matched=false
    for allowed in "$@"; do
      if [ "$key" = "$allowed" ]; then
        matched=true
        break
      fi
    done
    [ "$matched" = true ] || kdm_host_fail "HostFacts contains unknown field in ${context}: ${key}" || return "$?"
  done < <(yq -r "${expression} | keys | .[]" "$path")
}

kdm_host_validate_facts() {
  local path="${1:-}"
  local root_free file_path ownership sha keyring_name fingerprint

  [ -n "$path" ] || kdm_host_fail 'HostFacts path is required' || return "$?"
  [ -r "$path" ] || kdm_host_fail 'HostFacts is not readable' || return "$?"
  yq eval '.' "$path" >/dev/null 2>&1 || kdm_host_fail 'HostFacts YAML parse failed' || return "$?"
  [ "$(yq -r '.apiVersion // ""' "$path")" = 'kdm.io/v2alpha1' ] || kdm_host_fail 'HostFacts apiVersion is invalid' || return "$?"
  [ "$(yq -r '.kind // ""' "$path")" = 'HostFacts' ] || kdm_host_fail 'HostFacts kind is invalid' || return "$?"
  [[ "$(yq -r '.metadata.name // ""' "$path")" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] || kdm_host_fail 'HostFacts metadata.name is invalid' || return "$?"
  [ -n "$(yq -r '.spec.os.id // ""' "$path")" ] || kdm_host_fail 'HostFacts OS id is required' || return "$?"
  [ -n "$(yq -r '.spec.os.version // ""' "$path")" ] || kdm_host_fail 'HostFacts OS version is required' || return "$?"
  [ -n "$(yq -r '.spec.architecture // ""' "$path")" ] || kdm_host_fail 'HostFacts architecture is required' || return "$?"
  [ -n "$(yq -r '.spec.kernel // ""' "$path")" ] || kdm_host_fail 'HostFacts kernel is required' || return "$?"
  case "$(yq -r '.spec.swapActive' "$path")" in true|false) ;; *) kdm_host_fail 'HostFacts swapActive must be boolean' || return "$?" ;; esac
  root_free="$(yq -r '.spec.rootFreeMiB // ""' "$path")"
  [[ "$root_free" =~ ^[0-9]+$ ]] || kdm_host_fail 'HostFacts rootFreeMiB must be a non-negative integer' || return "$?"

  kdm_host_validate_map_keys "$path" '.' root apiVersion kind metadata spec || return "$?"
  kdm_host_validate_map_keys "$path" '.metadata' metadata name || return "$?"
  kdm_host_validate_map_keys "$path" '.spec' spec os architecture kernel cgroupVersion swapActive rootFreeMiB modules sysctl files keyrings packages holds services || return "$?"
  kdm_host_validate_map_keys "$path" '.spec.os' spec.os id version || return "$?"
  kdm_host_validate_map_keys "$path" '(.spec.modules // {})' spec.modules overlay brNetfilter || return "$?"
  kdm_host_validate_map_keys "$path" '(.spec.sysctl // {})' spec.sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward || return "$?"
  kdm_host_validate_map_keys "$path" '(.spec.keyrings // {})' spec.keyrings kubernetes crio || return "$?"
  kdm_host_validate_map_keys "$path" '(.spec.keyrings.kubernetes // {})' spec.keyrings.kubernetes ownership fingerprint || return "$?"
  kdm_host_validate_map_keys "$path" '(.spec.keyrings.crio // {})' spec.keyrings.crio ownership fingerprint || return "$?"
  kdm_host_validate_map_keys "$path" '(.spec.packages // {})' spec.packages ca-certificates curl gpg cri-o kubelet kubeadm kubectl || return "$?"
  kdm_host_validate_map_keys "$path" '(.spec.holds // {})' spec.holds cri-o kubelet kubeadm kubectl || return "$?"
  kdm_host_validate_map_keys "$path" '(.spec.services // {})' spec.services crio kubelet || return "$?"
  kdm_host_validate_map_keys "$path" '(.spec.services.crio // {})' spec.services.crio enabled active || return "$?"
  kdm_host_validate_map_keys "$path" '(.spec.services.kubelet // {})' spec.services.kubelet enabled || return "$?"
  yq -e '[.spec.files // {} | to_entries[].value | keys | .[] | select(. != "ownership" and . != "sha256")] | length == 0' "$path" >/dev/null 2>&1 || kdm_host_fail 'HostFacts file records contain unknown fields' || return "$?"

  while IFS=$'\t' read -r file_path ownership sha; do
    [ -n "$file_path" ] || continue
    case "$file_path" in
      /etc/modules-load.d/kdm-kubernetes.conf|\
      /etc/sysctl.d/99-kdm-kubernetes.conf|\
      /etc/apt/sources.list.d/kdm-kubernetes-v1.35.list|\
      /etc/apt/sources.list.d/kdm-crio-v1.35.list) ;;
      *) kdm_host_fail "HostFacts contains an unmanaged file path: ${file_path}" || return "$?" ;;
    esac
    case "$ownership" in absent|foreign) ;; managed) [[ "$sha" =~ ^[a-f0-9]{64}$ ]] || kdm_host_fail "managed HostFacts file requires SHA-256: ${file_path}" || return "$?" ;; *) kdm_host_fail "HostFacts file ownership is invalid: ${file_path}" || return "$?" ;; esac
  done < <(yq -r '.spec.files // {} | to_entries[] | [.key, (.value.ownership // ""), (.value.sha256 // "")] | @tsv' "$path")

  for keyring_name in kubernetes crio; do
    ownership="$(KDM_KEYRING="$keyring_name" yq -r '.spec.keyrings[strenv(KDM_KEYRING)].ownership // "absent"' "$path")"
    fingerprint="$(KDM_KEYRING="$keyring_name" yq -r '.spec.keyrings[strenv(KDM_KEYRING)].fingerprint // ""' "$path")"
    case "$ownership" in
      absent) [ -z "$fingerprint" ] || kdm_host_fail "absent keyring must not have a fingerprint: ${keyring_name}" || return "$?" ;;
      managed|foreign) [[ "$fingerprint" =~ ^[A-F0-9]{40}$ ]] || kdm_host_fail "keyring fingerprint is invalid: ${keyring_name}" || return "$?" ;;
      *) kdm_host_fail "keyring ownership is invalid: ${keyring_name}" || return "$?" ;;
    esac
  done

  return 0
}

kdm_host_inventory_profile() {
  yq -r '.spec.profile // ""' "$1"
}

kdm_host_preflight() {
  local inventory="$1"
  local target="$2"
  local facts="$3"
  local lock="$4"
  local profile record
  local expected_os expected_version expected_arch min_root_free expected_cgroup
  local kube_version kube_package kube_repository kube_key_url kube_key_fingerprint kube_key_sha
  local runtime_name runtime_version runtime_package runtime_repository runtime_key_url runtime_key_fingerprint runtime_key_sha
  local observed_os observed_version observed_arch observed_cgroup swap_active root_free foreign_files
  local keyring_ownership current_fingerprint

  kdm_config_validate_file "$inventory" || return "$?"
  kdm_compatibility_validate_lock "$lock" || return "$?"
  kdm_host_validate_facts "$facts" || return "$?"
  [ -n "$target" ] || kdm_host_fail 'exact target is required' || return "$?"
  KDM_TARGET="$target" yq -e '[.spec.nodes[] | select(.name == strenv(KDM_TARGET))] | length == 1' "$inventory" >/dev/null 2>&1 || kdm_host_fail "target not found: ${target}" || return "$?"
  [ "$(yq -r '.metadata.name' "$facts")" = "$target" ] || kdm_host_fail 'HostFacts target mismatch' || return "$?"

  profile="$(kdm_host_inventory_profile "$inventory")"
  [ -n "$profile" ] || kdm_host_fail 'inventory spec.profile is required for host bootstrap' || return "$?"
  record="$(kdm_compatibility_profile_record "$lock" "$profile")"
  [ -n "$record" ] || kdm_host_fail "unknown compatibility profile: ${profile}" || return "$?"
  IFS=$'\t' read -r expected_os expected_version expected_arch min_root_free expected_cgroup \
    kube_version kube_package kube_repository kube_key_url kube_key_fingerprint kube_key_sha \
    runtime_name runtime_version runtime_package runtime_repository runtime_key_url runtime_key_fingerprint runtime_key_sha <<<"$record"

  observed_os="$(yq -r '.spec.os.id' "$facts")"
  observed_version="$(yq -r '.spec.os.version' "$facts")"
  observed_arch="$(yq -r '.spec.architecture' "$facts")"
  observed_cgroup="$(yq -r '.spec.cgroupVersion // ""' "$facts")"
  swap_active="$(yq -r '.spec.swapActive' "$facts")"
  root_free="$(yq -r '.spec.rootFreeMiB' "$facts")"
  foreign_files="$(yq -r '[.spec.files // {} | to_entries[] | select(.value.ownership == "foreign")] | length' "$facts")"

  [ "$observed_os" = "$expected_os" ] || kdm_host_fail "OS mismatch: expected ${expected_os}, got ${observed_os}" || return "$?"
  [ "$observed_version" = "$expected_version" ] || kdm_host_fail "OS version mismatch: expected ${expected_version}, got ${observed_version}" || return "$?"
  [ "$observed_arch" = "$expected_arch" ] || kdm_host_fail "architecture mismatch: expected ${expected_arch}, got ${observed_arch}" || return "$?"
  [ "$observed_cgroup" = "$expected_cgroup" ] || kdm_host_fail "cgroup mismatch: expected ${expected_cgroup}, got ${observed_cgroup:-missing}" || return "$?"
  [ "$swap_active" = false ] || kdm_host_fail 'active swap is not allowed by this profile' || return "$?"
  [ "$root_free" -ge "$min_root_free" ] || kdm_host_fail "insufficient root disk: ${root_free} MiB available, ${min_root_free} MiB required" || return "$?"
  [ "$foreign_files" -eq 0 ] || kdm_host_fail 'foreign content exists at a KDM-owned path' || return "$?"

  keyring_ownership="$(yq -r '.spec.keyrings.kubernetes.ownership // "absent"' "$facts")"
  current_fingerprint="$(yq -r '.spec.keyrings.kubernetes.fingerprint // ""' "$facts")"
  [ "$keyring_ownership" != foreign ] || kdm_host_fail 'foreign Kubernetes keyring exists at a KDM-owned path' || return "$?"
  [ "$keyring_ownership" != managed ] || [ "$current_fingerprint" = "$kube_key_fingerprint" ] || kdm_host_fail 'managed Kubernetes keyring fingerprint mismatch' || return "$?"
  keyring_ownership="$(yq -r '.spec.keyrings.crio.ownership // "absent"' "$facts")"
  current_fingerprint="$(yq -r '.spec.keyrings.crio.fingerprint // ""' "$facts")"
  [ "$keyring_ownership" != foreign ] || kdm_host_fail 'foreign CRI-O keyring exists at a KDM-owned path' || return "$?"
  [ "$keyring_ownership" != managed ] || [ "$current_fingerprint" = "$runtime_key_fingerprint" ] || kdm_host_fail 'managed CRI-O keyring fingerprint mismatch' || return "$?"

  return 0
}

kdm_host_sha256_text() {
  local content="$1"
  local output

  command -v shasum >/dev/null 2>&1 || {
    kdm_error 'shasum is required to render host plans'
    return "$KDM_EXIT_PREREQUISITE"
  }
  output="$(printf '%s\n' "$content" | shasum -a 256)" || return "$KDM_EXIT_PREREQUISITE"
  printf '%s\n' "${output%% *}"
}

kdm_host_fact_file_record() {
  local facts="$1"
  local path="$2"

  KDM_FACT_PATH="$path" yq -r '
    .spec.files[strenv(KDM_FACT_PATH)] // {"ownership": "absent", "sha256": ""} |
    [.ownership, (.sha256 // "")] | @tsv
  ' "$facts"
}

kdm_host_plan_file() {
  local facts="$1"
  local path="$2"
  local content="$3"
  local current ownership current_sha desired_sha action

  current="$(kdm_host_fact_file_record "$facts" "$path")"
  IFS=$'\t' read -r ownership current_sha <<<"$current"
  desired_sha="$(kdm_host_sha256_text "$content")" || return "$?"
  if [ "$ownership" = managed ] && [ "$current_sha" = "$desired_sha" ]; then action=NO_CHANGE; else action=WRITE; fi
  printf 'FILE action=%s path=%s current=%s current_sha256=%s desired_sha256=%s\n' \
    "$action" "$path" "$ownership" "${current_sha:-none}" "$desired_sha"
}

kdm_host_package_action() {
  local facts="$1"
  local package_name="$2"
  local desired_version="$3"
  local current action

  current="$(KDM_PACKAGE="$package_name" yq -r '.spec.packages[strenv(KDM_PACKAGE)] // "absent"' "$facts")"
  if [ "$current" = "$desired_version" ]; then action=NO_CHANGE; else action=INSTALL; fi
  printf 'PACKAGE action=%s name=%s current=%s desired=%s\n' "$action" "$package_name" "$current" "$desired_version"
}

kdm_host_presence_package_action() {
  local facts="$1"
  local package_name="$2"
  local current action

  current="$(KDM_PACKAGE="$package_name" yq -r '.spec.packages[strenv(KDM_PACKAGE)] // "absent"' "$facts")"
  if [ "$current" = absent ]; then action=INSTALL; else action=NO_CHANGE; fi
  printf 'PACKAGE action=%s name=%s current=%s desired=present\n' "$action" "$package_name" "$current"
}

kdm_host_render_plan() {
  local inventory="$1"
  local target="$2"
  local facts="$3"
  local lock="$4"
  local profile record
  local os_id os_version architecture min_root_free cgroup_version
  local kube_version kube_package kube_repository kube_key_url kube_key_fingerprint kube_key_sha
  local runtime_name runtime_version runtime_package runtime_repository runtime_key_url runtime_key_fingerprint runtime_key_sha
  local modules_content sysctl_content kubernetes_source crio_source
  local current_kube_fingerprint current_runtime_fingerprint key_action
  local current_value action hold_state service_enabled service_active

  kdm_host_preflight "$inventory" "$target" "$facts" "$lock" || return "$?"
  profile="$(kdm_host_inventory_profile "$inventory")"
  record="$(kdm_compatibility_profile_record "$lock" "$profile")"
  IFS=$'\t' read -r os_id os_version architecture min_root_free cgroup_version \
    kube_version kube_package kube_repository kube_key_url kube_key_fingerprint kube_key_sha \
    runtime_name runtime_version runtime_package runtime_repository runtime_key_url runtime_key_fingerprint runtime_key_sha <<<"$record"

  modules_content="$(kdm_ubuntu_modules_content)"
  sysctl_content="$(kdm_ubuntu_sysctl_content)"
  kubernetes_source="$(kdm_ubuntu_apt_source_content "$kube_repository" '/etc/apt/keyrings/kdm-kubernetes-v1.35.gpg')"
  crio_source="$(kdm_crio_apt_source_content "$runtime_repository" '/etc/apt/keyrings/kdm-crio-v1.35.gpg')"

  printf 'PLAN host-bootstrap\n'
  printf 'target=%s\n' "$target"
  printf 'profile=%s\n' "$profile"
  printf 'observed=os:%s/%s arch:%s kernel:%s cgroup:%s swap:%s rootFreeMiB:%s\n' \
    "$(yq -r '.spec.os.id' "$facts")" "$(yq -r '.spec.os.version' "$facts")" \
    "$(yq -r '.spec.architecture' "$facts")" "$(yq -r '.spec.kernel' "$facts")" \
    "$(yq -r '.spec.cgroupVersion' "$facts")" "$(yq -r '.spec.swapActive' "$facts")" \
    "$(yq -r '.spec.rootFreeMiB' "$facts")"
  printf 'baseline=PASS\n'
  kdm_host_plan_file "$facts" '/etc/modules-load.d/kdm-kubernetes.conf' "$modules_content" || return "$?"
  kdm_host_plan_file "$facts" '/etc/sysctl.d/99-kdm-kubernetes.conf' "$sysctl_content" || return "$?"
  current_kube_fingerprint="$(yq -r '.spec.keyrings.kubernetes.fingerprint // ""' "$facts")"
  if [ "$current_kube_fingerprint" = "$kube_key_fingerprint" ]; then key_action=NO_CHANGE; else key_action=INSTALL; fi
  printf 'KEYRING action=%s path=/etc/apt/keyrings/kdm-kubernetes-v1.35.gpg fingerprint=%s source_sha256=%s\n' "$key_action" "$kube_key_fingerprint" "$kube_key_sha"
  current_runtime_fingerprint="$(yq -r '.spec.keyrings.crio.fingerprint // ""' "$facts")"
  if [ "$current_runtime_fingerprint" = "$runtime_key_fingerprint" ]; then key_action=NO_CHANGE; else key_action=INSTALL; fi
  printf 'KEYRING action=%s path=/etc/apt/keyrings/kdm-crio-v1.35.gpg fingerprint=%s source_sha256=%s\n' "$key_action" "$runtime_key_fingerprint" "$runtime_key_sha"
  kdm_host_plan_file "$facts" '/etc/apt/sources.list.d/kdm-kubernetes-v1.35.list' "$kubernetes_source" || return "$?"
  kdm_host_plan_file "$facts" '/etc/apt/sources.list.d/kdm-crio-v1.35.list' "$crio_source" || return "$?"
  printf 'REPOSITORY name=kubernetes repository=%s key_url=%s\n' "$kube_repository" "$kube_key_url"
  printf 'REPOSITORY name=cri-o repository=%s key_url=%s\n' "$runtime_repository" "$runtime_key_url"
  current_value="$(yq -r '.spec.modules.overlay // false' "$facts")"; if [ "$current_value" = true ]; then action=NO_CHANGE; else action=LOAD; fi
  printf 'MODULE action=%s name=overlay desired=loaded current=%s\n' "$action" "$current_value"
  current_value="$(yq -r '.spec.modules.brNetfilter // false' "$facts")"; if [ "$current_value" = true ]; then action=NO_CHANGE; else action=LOAD; fi
  printf 'MODULE action=%s name=br_netfilter desired=loaded current=%s\n' "$action" "$current_value"
  current_value="$(yq -r '.spec.sysctl."net.bridge.bridge-nf-call-iptables" // 0' "$facts")"; if [ "$current_value" = 1 ]; then action=NO_CHANGE; else action=SET; fi
  printf 'SYSCTL action=%s name=net.bridge.bridge-nf-call-iptables desired=1 current=%s\n' "$action" "$current_value"
  current_value="$(yq -r '.spec.sysctl."net.bridge.bridge-nf-call-ip6tables" // 0' "$facts")"; if [ "$current_value" = 1 ]; then action=NO_CHANGE; else action=SET; fi
  printf 'SYSCTL action=%s name=net.bridge.bridge-nf-call-ip6tables desired=1 current=%s\n' "$action" "$current_value"
  current_value="$(yq -r '.spec.sysctl."net.ipv4.ip_forward" // 0' "$facts")"; if [ "$current_value" = 1 ]; then action=NO_CHANGE; else action=SET; fi
  printf 'SYSCTL action=%s name=net.ipv4.ip_forward desired=1 current=%s\n' "$action" "$current_value"
  kdm_host_presence_package_action "$facts" ca-certificates
  kdm_host_presence_package_action "$facts" curl
  kdm_host_presence_package_action "$facts" gpg
  kdm_host_package_action "$facts" cri-o "$runtime_package"
  kdm_host_package_action "$facts" kubelet "$kube_package"
  kdm_host_package_action "$facts" kubeadm "$kube_package"
  kdm_host_package_action "$facts" kubectl "$kube_package"
  hold_state="$(yq -r '(.spec.holds."cri-o" == true) and (.spec.holds.kubelet == true) and (.spec.holds.kubeadm == true) and (.spec.holds.kubectl == true)' "$facts")"
  if [ "$hold_state" = true ]; then action=NO_CHANGE; else action=HOLD; fi
  printf 'HOLD action=%s packages=cri-o,kubelet,kubeadm,kubectl desired=true\n' "$action"
  service_enabled="$(yq -r '.spec.services.crio.enabled // false' "$facts")"
  service_active="$(yq -r '.spec.services.crio.active // false' "$facts")"
  if [ "$service_enabled" = true ] && [ "$service_active" = true ]; then action=NO_CHANGE; else action=ENABLE; fi
  printf 'SERVICE action=%s name=crio desired=enabled,active current=enabled:%s,active:%s\n' "$action" "$service_enabled" "$service_active"
  service_enabled="$(yq -r '.spec.services.kubelet.enabled // false' "$facts")"
  if [ "$service_enabled" = true ]; then action=NO_CHANGE; else action=ENABLE; fi
  printf 'SERVICE action=%s name=kubelet desired=enabled current=enabled:%s\n' "$action" "$service_enabled"
  printf 'mode=PLAN_ONLY\n'
}
