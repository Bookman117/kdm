#!/usr/bin/env bash

kdm_host_facts_fail() {
  kdm_error "HostFacts protocol invalid: $*"
  return "$KDM_EXIT_CONFIG"
}

kdm_host_facts_validate_pair() {
  local key="$1"
  local value="$2"

  case "$key" in
    metadata.name) [[ "$value" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] ;;
    os.id) [[ "$value" =~ ^[a-z0-9][a-z0-9._-]*$ ]] ;;
    os.version) [[ "$value" =~ ^[0-9]+\.[0-9]+([.][0-9]+)?$ ]] ;;
    architecture) [[ "$value" =~ ^[a-z0-9][a-z0-9_-]*$ ]] ;;
    kernel) [[ "$value" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*$ ]] ;;
    cgroupVersion) [[ "$value" =~ ^v[12]$ ]] ;;
    swapActive|module.overlay|module.brNetfilter|hold.cri-o|hold.kubelet|hold.kubeadm|hold.kubectl|service.crio.enabled|service.crio.active|service.kubelet.enabled)
      [ "$value" = true ] || [ "$value" = false ]
      ;;
    rootFreeMiB) [[ "$value" =~ ^[0-9]+$ ]] ;;
    sysctl.net.bridge.bridge-nf-call-iptables|sysctl.net.bridge.bridge-nf-call-ip6tables|sysctl.net.ipv4.ip_forward)
      [[ "$value" =~ ^-?[0-9]+$ ]]
      ;;
    file.modulesLoad.ownership|file.sysctl.ownership|file.kubernetesRepository.ownership|file.crioRepository.ownership|keyring.kubernetes.ownership|keyring.crio.ownership)
      [ "$value" = absent ] || [ "$value" = managed ] || [ "$value" = foreign ]
      ;;
    file.modulesLoad.sha256|file.sysctl.sha256|file.kubernetesRepository.sha256|file.crioRepository.sha256)
      [ -z "$value" ] || [[ "$value" =~ ^[a-f0-9]{64}$ ]]
      ;;
    keyring.kubernetes.fingerprint|keyring.crio.fingerprint)
      [ -z "$value" ] || [[ "$value" =~ ^[A-F0-9]{40}$ ]]
      ;;
    package.ca-certificates|package.curl|package.gpg|package.cri-o|package.kubelet|package.kubeadm|package.kubectl)
      [[ "$value" =~ ^(absent|present|[A-Za-z0-9][A-Za-z0-9.+:~_-]*)$ ]]
      ;;
    *) return 1 ;;
  esac
}

kdm_host_facts_parse_protocol() {
  local input="${1:-}"
  local output="${2:-}"
  local line key value seen ended required temp_path
  local metadata_name os_id os_version architecture kernel cgroup_version swap_active root_free_mib
  local module_overlay module_br_netfilter sysctl_iptables sysctl_ip6tables sysctl_ipv4_forward
  local modules_ownership modules_sha sysctl_ownership sysctl_sha kube_repo_ownership kube_repo_sha crio_repo_ownership crio_repo_sha
  local kube_key_ownership kube_key_fingerprint crio_key_ownership crio_key_fingerprint
  local package_ca package_curl package_gpg package_crio package_kubelet package_kubeadm package_kubectl
  local hold_crio hold_kubelet hold_kubeadm hold_kubectl service_crio_enabled service_crio_active service_kubelet_enabled

  [ -r "$input" ] || kdm_host_facts_fail 'input is not readable' || return "$?"
  [ -n "$output" ] || kdm_host_facts_fail 'output path is required' || return "$?"
  IFS= read -r line <"$input" || kdm_host_facts_fail 'protocol is empty' || return "$?"
  [ "$line" = KDM_HOST_FACTS_V1 ] || kdm_host_facts_fail 'unsupported header' || return "$?"

  seen=$'\n'
  ended=false
  while IFS= read -r line; do
    if [ "$ended" = true ]; then
      [ -z "$line" ] || kdm_host_facts_fail 'data found after protocol end' || return "$?"
      continue
    fi
    if [ "$line" = KDM_HOST_FACTS_END ]; then
      ended=true
      continue
    fi
    case "$line" in *$'\t'*) ;; *) kdm_host_facts_fail 'record is not tab-delimited' || return "$?" ;; esac
    key="${line%%$'\t'*}"
    value="${line#*$'\t'}"
    case "$seen" in *$'\n'"$key"$'\n'*) kdm_host_facts_fail "duplicate key: ${key}" || return "$?" ;; esac
    kdm_host_facts_validate_pair "$key" "$value" || kdm_host_facts_fail "invalid key/value: ${key}" || return "$?"
    seen="${seen}${key}"$'\n'
    case "$key" in
      metadata.name) metadata_name="$value" ;;
      os.id) os_id="$value" ;;
      os.version) os_version="$value" ;;
      architecture) architecture="$value" ;;
      kernel) kernel="$value" ;;
      cgroupVersion) cgroup_version="$value" ;;
      swapActive) swap_active="$value" ;;
      rootFreeMiB) root_free_mib="$value" ;;
      module.overlay) module_overlay="$value" ;;
      module.brNetfilter) module_br_netfilter="$value" ;;
      sysctl.net.bridge.bridge-nf-call-iptables) sysctl_iptables="$value" ;;
      sysctl.net.bridge.bridge-nf-call-ip6tables) sysctl_ip6tables="$value" ;;
      sysctl.net.ipv4.ip_forward) sysctl_ipv4_forward="$value" ;;
      file.modulesLoad.ownership) modules_ownership="$value" ;;
      file.modulesLoad.sha256) modules_sha="$value" ;;
      file.sysctl.ownership) sysctl_ownership="$value" ;;
      file.sysctl.sha256) sysctl_sha="$value" ;;
      file.kubernetesRepository.ownership) kube_repo_ownership="$value" ;;
      file.kubernetesRepository.sha256) kube_repo_sha="$value" ;;
      file.crioRepository.ownership) crio_repo_ownership="$value" ;;
      file.crioRepository.sha256) crio_repo_sha="$value" ;;
      keyring.kubernetes.ownership) kube_key_ownership="$value" ;;
      keyring.kubernetes.fingerprint) kube_key_fingerprint="$value" ;;
      keyring.crio.ownership) crio_key_ownership="$value" ;;
      keyring.crio.fingerprint) crio_key_fingerprint="$value" ;;
      package.ca-certificates) package_ca="$value" ;;
      package.curl) package_curl="$value" ;;
      package.gpg) package_gpg="$value" ;;
      package.cri-o) package_crio="$value" ;;
      package.kubelet) package_kubelet="$value" ;;
      package.kubeadm) package_kubeadm="$value" ;;
      package.kubectl) package_kubectl="$value" ;;
      hold.cri-o) hold_crio="$value" ;;
      hold.kubelet) hold_kubelet="$value" ;;
      hold.kubeadm) hold_kubeadm="$value" ;;
      hold.kubectl) hold_kubectl="$value" ;;
      service.crio.enabled) service_crio_enabled="$value" ;;
      service.crio.active) service_crio_active="$value" ;;
      service.kubelet.enabled) service_kubelet_enabled="$value" ;;
    esac
  done < <(sed '1d' "$input")
  [ "$ended" = true ] || kdm_host_facts_fail 'protocol end marker is missing' || return "$?"

  for required in metadata.name os.id os.version architecture kernel cgroupVersion swapActive rootFreeMiB module.overlay module.brNetfilter \
    sysctl.net.bridge.bridge-nf-call-iptables sysctl.net.bridge.bridge-nf-call-ip6tables sysctl.net.ipv4.ip_forward \
    file.modulesLoad.ownership file.modulesLoad.sha256 file.sysctl.ownership file.sysctl.sha256 \
    file.kubernetesRepository.ownership file.kubernetesRepository.sha256 file.crioRepository.ownership file.crioRepository.sha256 \
    keyring.kubernetes.ownership keyring.kubernetes.fingerprint keyring.crio.ownership keyring.crio.fingerprint \
    package.ca-certificates package.curl package.gpg package.cri-o package.kubelet package.kubeadm package.kubectl \
    hold.cri-o hold.kubelet hold.kubeadm hold.kubectl service.crio.enabled service.crio.active service.kubelet.enabled; do
    case "$seen" in *$'\n'"$required"$'\n'*) ;; *) kdm_host_facts_fail "required key is missing: ${required}" || return "$?" ;; esac
  done

  [ "$modules_ownership" != managed ] || [ -n "$modules_sha" ] || kdm_host_facts_fail 'managed modules file requires SHA-256' || return "$?"
  [ "$sysctl_ownership" != managed ] || [ -n "$sysctl_sha" ] || kdm_host_facts_fail 'managed sysctl file requires SHA-256' || return "$?"
  [ "$kube_repo_ownership" != managed ] || [ -n "$kube_repo_sha" ] || kdm_host_facts_fail 'managed Kubernetes repository requires SHA-256' || return "$?"
  [ "$crio_repo_ownership" != managed ] || [ -n "$crio_repo_sha" ] || kdm_host_facts_fail 'managed CRI-O repository requires SHA-256' || return "$?"
  case "$kube_key_ownership" in
    absent) [ -z "$kube_key_fingerprint" ] || kdm_host_facts_fail 'absent Kubernetes keyring has a fingerprint' || return "$?" ;;
    managed|foreign) [ -n "$kube_key_fingerprint" ] || kdm_host_facts_fail 'present Kubernetes keyring lacks a fingerprint' || return "$?" ;;
  esac
  case "$crio_key_ownership" in
    absent) [ -z "$crio_key_fingerprint" ] || kdm_host_facts_fail 'absent CRI-O keyring has a fingerprint' || return "$?" ;;
    managed|foreign) [ -n "$crio_key_fingerprint" ] || kdm_host_facts_fail 'present CRI-O keyring lacks a fingerprint' || return "$?" ;;
  esac

  temp_path="${output}.tmp.$$"
  {
    printf 'apiVersion: kdm.io/v2alpha1\nkind: HostFacts\nmetadata:\n  name: %s\nspec:\n' "$metadata_name"
    printf '  os:\n    id: %s\n    version: "%s"\n' "$os_id" "$os_version"
    printf '  architecture: %s\n  kernel: %s\n  cgroupVersion: %s\n  swapActive: %s\n  rootFreeMiB: %s\n' "$architecture" "$kernel" "$cgroup_version" "$swap_active" "$root_free_mib"
    printf '  modules:\n    overlay: %s\n    brNetfilter: %s\n' "$module_overlay" "$module_br_netfilter"
    printf '  sysctl:\n    net.bridge.bridge-nf-call-iptables: %s\n    net.bridge.bridge-nf-call-ip6tables: %s\n    net.ipv4.ip_forward: %s\n' "$sysctl_iptables" "$sysctl_ip6tables" "$sysctl_ipv4_forward"
    printf '  files:\n'
    printf '    /etc/modules-load.d/kdm-kubernetes.conf:\n      ownership: %s\n      sha256: "%s"\n' "$modules_ownership" "$modules_sha"
    printf '    /etc/sysctl.d/99-kdm-kubernetes.conf:\n      ownership: %s\n      sha256: "%s"\n' "$sysctl_ownership" "$sysctl_sha"
    printf '    /etc/apt/sources.list.d/kdm-kubernetes-v1.35.list:\n      ownership: %s\n      sha256: "%s"\n' "$kube_repo_ownership" "$kube_repo_sha"
    printf '    /etc/apt/sources.list.d/kdm-crio-v1.35.list:\n      ownership: %s\n      sha256: "%s"\n' "$crio_repo_ownership" "$crio_repo_sha"
    printf '  keyrings:\n    kubernetes:\n      ownership: %s\n      fingerprint: "%s"\n    crio:\n      ownership: %s\n      fingerprint: "%s"\n' "$kube_key_ownership" "$kube_key_fingerprint" "$crio_key_ownership" "$crio_key_fingerprint"
    printf '  packages:\n    ca-certificates: "%s"\n    curl: "%s"\n    gpg: "%s"\n    cri-o: "%s"\n    kubelet: "%s"\n    kubeadm: "%s"\n    kubectl: "%s"\n' "$package_ca" "$package_curl" "$package_gpg" "$package_crio" "$package_kubelet" "$package_kubeadm" "$package_kubectl"
    printf '  holds:\n    cri-o: %s\n    kubelet: %s\n    kubeadm: %s\n    kubectl: %s\n' "$hold_crio" "$hold_kubelet" "$hold_kubeadm" "$hold_kubectl"
    printf '  services:\n    crio:\n      enabled: %s\n      active: %s\n    kubelet:\n      enabled: %s\n' "$service_crio_enabled" "$service_crio_active" "$service_kubelet_enabled"
  } >"$temp_path" || { rm -f "$temp_path"; return "$KDM_EXIT_CONFIG"; }
  kdm_host_validate_facts "$temp_path" >/dev/null 2>&1 || { rm -f "$temp_path"; kdm_host_facts_fail 'rendered HostFacts failed schema validation'; return "$?"; }
  mv "$temp_path" "$output"
}
