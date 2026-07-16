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

: "${KDM_LAB_INVENTORY:?KDM_LAB_INVENTORY is required}"
: "${KDM_LAB_IDENTITY:?KDM_LAB_IDENTITY is required}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
export KDM_LAB_KNOWN_HOSTS="${tmp_dir}/known_hosts"

executor="${ROOT}/tests/helpers/lab-ssh"
expected_hostname="${KDM_LAB_EXPECTED_HOSTNAME:-kdm-lab-cp1}"
reachable_record="$(kdm_inventory_records "$KDM_LAB_INVENTORY")" || fail 'failed to normalize lab inventory'
IFS=$'\t' read -r node_name node_role node_address ssh_user ssh_port ssh_timeout _ <<<"$reachable_record"
strict_record="$(printf '%s\t%s\t%s\t%s\t%s\t%s\tyes' "$node_name" "$node_role" "$node_address" "$ssh_user" "$ssh_port" "$ssh_timeout")"
unreachable_records="${reachable_record}"$'\n'$'unreachable-1\tworker\t127.0.0.1\tkdm-probe\t1\t1\taccept-new'

set +e
kdm_ssh_orchestrate "$executor" "$strict_record" hostname >/dev/null 2>&1
status=$?
set -e
assert_status "$status" "$KDM_EXIT_EXECUTION" 'unknown host with strict policy must fail closed'

output="$(kdm_ssh_orchestrate "$executor" "$reachable_record" hostname 2>/dev/null)" || fail 'real SSH accept-new probe failed'
[ "$output" = "$expected_hostname" ] || fail "unexpected real SSH output: ${output}"

output="$(kdm_ssh_orchestrate "$executor" "$strict_record" hostname 2>/dev/null)" || fail 'real SSH strict host-key probe failed'
[ "$output" = "$expected_hostname" ] || fail "unexpected strict SSH output: ${output}"

set +e
output="$(kdm_ssh_orchestrate "$executor" "$unreachable_records" hostname 2>/dev/null)"
status=$?
set -e
assert_status "$status" "$KDM_EXIT_EXECUTION" 'real SSH partial failure must aggregate to execution error'
assert_contains "$output" "$expected_hostname"

pass 'disposable lab real SSH read-only probe and failure aggregation'
