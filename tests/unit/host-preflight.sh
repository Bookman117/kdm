#!/usr/bin/env bash
set -u

ROOT="$(cd -P -- "${BASH_SOURCE[0]%/*}/../.." && pwd)"
FIXTURES="${ROOT}/tests/fixtures/host"
INVENTORY="${ROOT}/config/inventory.example.yaml"
LOCK="${ROOT}/config/compatibility-lock.yaml"
source "${ROOT}/tests/test_helper.sh"
source "${ROOT}/lib/core.sh"
source "${ROOT}/lib/log.sh"
source "${ROOT}/lib/validation.sh"
source "${ROOT}/lib/config.sh"
source "${ROOT}/lib/host.sh"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

assert_preflight_status() {
  local fixture="$1"
  local expected="$2"
  local status
  set +e
  kdm_host_preflight "$INVENTORY" cp-1 "$FIXTURES/$fixture" "$LOCK" >/dev/null 2>&1
  status=$?
  set -e
  assert_status "$status" "$expected" "preflight fixture $fixture"
}

kdm_compatibility_validate_lock "$LOCK" >/dev/null 2>&1 || fail 'compatibility lock must validate'
assert_preflight_status supported.yaml 0
assert_preflight_status wrong-os.yaml "$KDM_EXIT_CONFIG"
assert_preflight_status wrong-arch.yaml "$KDM_EXIT_CONFIG"
assert_preflight_status wrong-cgroup.yaml "$KDM_EXIT_CONFIG"
assert_preflight_status active-swap.yaml "$KDM_EXIT_CONFIG"
assert_preflight_status low-disk.yaml "$KDM_EXIT_CONFIG"
assert_preflight_status repo-drift.yaml "$KDM_EXIT_CONFIG"

yq 'del(.profiles."ubuntu-24.04-arm64-k8s-1.35".kubernetes.packageVersion)' "$LOCK" >"${tmp_dir}/invalid-lock.yaml"
set +e
kdm_compatibility_validate_lock "${tmp_dir}/invalid-lock.yaml" >/dev/null 2>&1
status=$?
set -e
assert_status "$status" "$KDM_EXIT_CONFIG" 'incomplete compatibility lock must fail closed'

yq '.profiles."ubuntu-24.04-arm64-k8s-1.35".kubernetes.minor = "v9.99" | .profiles."ubuntu-24.04-arm64-k8s-1.35".runtime.minor = "v9.99"' "$LOCK" >"${tmp_dir}/inconsistent-lock.yaml"
set +e
kdm_compatibility_validate_lock "${tmp_dir}/inconsistent-lock.yaml" >/dev/null 2>&1
status=$?
set -e
assert_status "$status" "$KDM_EXIT_CONFIG" 'minor/version/repository inconsistency must fail closed'

yq '.profiles."ubuntu-24.04-arm64-k8s-1.35".kubernetes.packageVersion = "garbage"' "$LOCK" >"${tmp_dir}/garbage-package-lock.yaml"
set +e
kdm_compatibility_validate_lock "${tmp_dir}/garbage-package-lock.yaml" >/dev/null 2>&1
status=$?
set -e
assert_status "$status" "$KDM_EXIT_CONFIG" 'invalid package version must fail closed'

yq '.spec.profile = "unknown-profile"' "$INVENTORY" >"${tmp_dir}/unknown-profile-inventory.yaml"
set +e
kdm_host_preflight "${tmp_dir}/unknown-profile-inventory.yaml" cp-1 "$FIXTURES/supported.yaml" "$LOCK" >/dev/null 2>&1
status=$?
set -e
assert_status "$status" "$KDM_EXIT_CONFIG" 'unknown compatibility profile must fail closed'

yq '.spec.token = "forbidden-placeholder"' "$FIXTURES/supported.yaml" >"${tmp_dir}/secret-facts.yaml"
set +e
kdm_host_validate_facts "${tmp_dir}/secret-facts.yaml" >/dev/null 2>&1
status=$?
set -e
assert_status "$status" "$KDM_EXIT_CONFIG" 'HostFacts credential fields must fail closed'

yq '.spec.sshPrivateKey = "forbidden-placeholder"' "$FIXTURES/supported.yaml" >"${tmp_dir}/credential-variant-facts.yaml"
set +e
kdm_host_validate_facts "${tmp_dir}/credential-variant-facts.yaml" >/dev/null 2>&1
status=$?
set -e
assert_status "$status" "$KDM_EXIT_CONFIG" 'HostFacts unknown credential-like fields must fail schema allowlist'

yq '.spec.keyrings.kubernetes = {"ownership": "managed", "fingerprint": "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"}' "$FIXTURES/supported.yaml" >"${tmp_dir}/keyring-drift-facts.yaml"
set +e
kdm_host_preflight "$INVENTORY" cp-1 "${tmp_dir}/keyring-drift-facts.yaml" "$LOCK" >/dev/null 2>&1
status=$?
set -e
assert_status "$status" "$KDM_EXIT_CONFIG" 'managed keyring fingerprint drift must fail closed'

pass 'host preflight accepts supported facts and rejects unsafe baselines'
