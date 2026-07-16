#!/usr/bin/env bash
set -u

ROOT="$(cd -P -- "${BASH_SOURCE[0]%/*}/../.." && pwd)"
source "${ROOT}/tests/test_helper.sh"
source "${ROOT}/lib/core.sh"
source "${ROOT}/lib/log.sh"
source "${ROOT}/lib/validation.sh"
source "${ROOT}/lib/config.sh"
source "${ROOT}/lib/inventory.sh"
source "${ROOT}/lib/ssh.sh"
source "${ROOT}/lib/host.sh"
source "${ROOT}/lib/host-facts.sh"

: "${KDM_LAB_INVENTORY:?KDM_LAB_INVENTORY is required}"
: "${KDM_LAB_IDENTITY:?KDM_LAB_IDENTITY is required}"

LOCK="${ROOT}/config/compatibility-lock.yaml"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
export KDM_LAB_KNOWN_HOSTS="${tmp_dir}/known_hosts"
executor="${ROOT}/tests/helpers/lab-ssh"
inventory="${tmp_dir}/inventory.yaml"
facts="${tmp_dir}/facts.yaml"
protocol="${tmp_dir}/facts.tsv"

yq '.spec.profile = "ubuntu-24.04-arm64-k8s-1.35"' "$KDM_LAB_INVENTORY" >"$inventory" || fail 'failed to add lab compatibility profile'
reachable_record="$(kdm_inventory_records "$inventory")" || fail 'failed to normalize lab inventory'
IFS=$'\t' read -r node_name node_role node_address ssh_user ssh_port ssh_timeout _ <<<"$reachable_record"
strict_record="$(printf '%s\t%s\t%s\t%s\t%s\t%s\tyes' "$node_name" "$node_role" "$node_address" "$ssh_user" "$ssh_port" "$ssh_timeout")"

set +e
kdm_ssh_orchestrate "$executor" "$strict_record" host-facts --node "$node_name" >/dev/null 2>&1
status=$?
set -e
assert_status "$status" "$KDM_EXIT_EXECUTION" 'unknown host with strict policy must fail closed'

kdm_ssh_orchestrate "$executor" "$reachable_record" host-facts --node "$node_name" 2>/dev/null >"$protocol" || fail 'real HostFacts accept-new collection failed'
kdm_host_facts_parse_protocol "$protocol" "$facts" || fail 'real HostFacts protocol parse failed'
kdm_host_validate_facts "$facts" || fail 'real HostFacts schema validation failed'
[ "$(yq -r '.metadata.name' "$facts")" = "$node_name" ] || fail 'real HostFacts target mismatch'
[ "$(yq -r '.spec.os.id' "$facts")" = ubuntu ] || fail 'real HostFacts OS mismatch'
[ "$(yq -r '.spec.os.version' "$facts")" = 24.04 ] || fail 'real HostFacts OS version mismatch'
[ "$(yq -r '.spec.architecture' "$facts")" = arm64 ] || fail 'real HostFacts architecture mismatch'
[ "$(yq -r '.spec.cgroupVersion' "$facts")" = v2 ] || fail 'real HostFacts cgroup mismatch'

kdm_ssh_orchestrate "$executor" "$strict_record" host-facts --node "$node_name" 2>/dev/null >"${tmp_dir}/strict.tsv" || fail 'real HostFacts strict host-key collection failed'
kdm_host_facts_parse_protocol "${tmp_dir}/strict.tsv" "${tmp_dir}/strict.yaml" || fail 'strict HostFacts protocol parse failed'

set +e
kdm_ssh_orchestrate "$executor" "$strict_record" hostname >/dev/null 2>&1
status=$?
set -e
assert_status "$status" "$KDM_EXIT_EXECUTION" 'forced collector must reject arbitrary SSH command'

set +e
preflight_output="$(kdm_host_preflight "$inventory" "$node_name" "$facts" "$LOCK" 2>&1)"
status=$?
set -e
assert_status "$status" "$KDM_EXIT_CONFIG" 'undersized disposable VM must fail capacity preflight'
assert_contains "$preflight_output" 'insufficient root disk'

pass 'real SSH HostFacts collection, strict parsing, and capacity fail-closed gate'
