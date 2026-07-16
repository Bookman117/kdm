#!/usr/bin/env bash
set -u

ROOT="$(cd -P -- "${BASH_SOURCE[0]%/*}/../.." && pwd)"
FIXTURE="${ROOT}/tests/fixtures/host-facts/protocol-valid.tsv"
source "${ROOT}/tests/test_helper.sh"
source "${ROOT}/lib/core.sh"
source "${ROOT}/lib/log.sh"
source "${ROOT}/lib/validation.sh"
source "${ROOT}/lib/config.sh"
source "${ROOT}/lib/host.sh"
source "${ROOT}/lib/host-facts.sh"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
facts="${tmp_dir}/facts.yaml"

kdm_host_facts_parse_protocol "$FIXTURE" "$facts" || fail 'valid HostFacts protocol must parse'
kdm_host_validate_facts "$facts" || fail 'parsed HostFacts must pass schema validation'
[ "$(yq -r '.metadata.name' "$facts")" = cp-1 ] || fail 'parsed target mismatch'
[ "$(yq -r '.spec.architecture' "$facts")" = arm64 ] || fail 'parsed architecture mismatch'
[ "$(yq -r '.spec.services.crio.enabled' "$facts")" = false ] || fail 'parsed CRI-O enabled mismatch'
[ "$(yq -r '.spec.packages."ca-certificates"' "$facts")" = present ] || fail 'parsed prerequisite package mismatch'

assert_protocol_invalid() {
  local path="$1"
  local context="$2"
  local status
  set +e
  kdm_host_facts_parse_protocol "$path" "${tmp_dir}/invalid-output.yaml" >/dev/null 2>&1
  status=$?
  set -e
  assert_status "$status" "$KDM_EXIT_CONFIG" "$context"
}

{
  printf 'KDM_HOST_FACTS_V1\n'
  printf 'unknown.key\tvalue\n'
  printf 'KDM_HOST_FACTS_END\n'
} >"${tmp_dir}/unknown.tsv"
assert_protocol_invalid "${tmp_dir}/unknown.tsv" 'unknown protocol key must fail'

while IFS= read -r line; do
  if [ "$line" = KDM_HOST_FACTS_END ]; then printf 'metadata.name\tcp-1\n'; fi
  printf '%s\n' "$line"
done <"$FIXTURE" >"${tmp_dir}/duplicate.tsv"
assert_protocol_invalid "${tmp_dir}/duplicate.tsv" 'duplicate protocol key must fail'

while IFS= read -r line; do
  case "$line" in architecture$'\t'*) ;; *) printf '%s\n' "$line" ;; esac
done <"$FIXTURE" >"${tmp_dir}/missing.tsv"
assert_protocol_invalid "${tmp_dir}/missing.tsv" 'missing protocol key must fail'

while IFS= read -r line; do
  case "$line" in swapActive$'\t'*) printf 'swapActive\tmaybe\n' ;; *) printf '%s\n' "$line" ;; esac
done <"$FIXTURE" >"${tmp_dir}/invalid-bool.tsv"
assert_protocol_invalid "${tmp_dir}/invalid-bool.tsv" 'invalid protocol boolean must fail'

cp "$FIXTURE" "${tmp_dir}/post-end.tsv"
printf 'metadata.name\tcp-1\n' >>"${tmp_dir}/post-end.tsv"
assert_protocol_invalid "${tmp_dir}/post-end.tsv" 'data after protocol end must fail'

while IFS= read -r line; do
  [ "$line" = KDM_HOST_FACTS_END ] || printf '%s\n' "$line"
done <"$FIXTURE" >"${tmp_dir}/missing-end.tsv"
assert_protocol_invalid "${tmp_dir}/missing-end.tsv" 'missing protocol end must fail'

set +e
SSH_ORIGINAL_COMMAND='uname -a' "${ROOT}/scripts/guest/kdm-host-facts" >/dev/null 2>&1
status=$?
set -e
assert_status "$status" "$KDM_EXIT_SAFETY" 'guest collector must reject non-allowlisted original command'

set +e
KDM_LAB_VM='lab-a' \
KDM_LAB_HOST_FACTS_PUBLIC_KEY='/dev/null' \
KDM_LAB_PROVISION_CONFIRM='lab-b' \
  "${ROOT}/scripts/lab/provision-host-facts.sh" >/dev/null 2>&1
status=$?
set -e
assert_status "$status" "$KDM_EXIT_SAFETY" 'lab provision requires exact VM confirmation'

pass 'strict HostFacts v1 protocol parser'
