#!/usr/bin/env bash
set -u

ROOT="$(cd -P -- "${BASH_SOURCE[0]%/*}/../.." && pwd)"
# shellcheck source=../test_helper.sh
source "${ROOT}/tests/test_helper.sh"

output="$(${KDM_BIN} help 2>&1)" || fail 'kdm help failed'
assert_contains "$output" 'KDM v2'
assert_contains "$output" 'doctor'
assert_contains "$output" 'host bootstrap'

output="$(${KDM_BIN} --help 2>&1)" || fail 'kdm --help failed'
assert_contains "$output" 'Usage:'

output="$(${KDM_BIN} version 2>&1)" || fail 'kdm version failed'
assert_contains "$output" 'kdm 2.0.0-dev'

inventory="${ROOT}/tests/fixtures/inventory/valid-multi.yaml"
output="$(${KDM_BIN} config validate -f "$inventory" 2>&1)" || fail 'config validate failed'
assert_contains "$output" 'Inventory valid: multi (3 nodes)'

output="$(${KDM_BIN} inventory targets -f "$inventory" --role control-plane 2>&1)" || fail 'inventory role target failed'
assert_contains "$output" 'cp-1'
assert_contains "$output" 'cp-2'
case "$output" in
  *wk-1*) fail 'worker leaked into CLI control-plane targets' ;;
esac

output="$(${KDM_BIN} host bootstrap -f "${ROOT}/config/inventory.example.yaml" --node cp-1 --facts-file "${ROOT}/tests/fixtures/host/supported.yaml" 2>&1)" || fail 'host bootstrap plan failed'
assert_contains "$output" 'PLAN host-bootstrap'
assert_contains "$output" 'mode=PLAN_ONLY'

set +e
output="$(${KDM_BIN} host bootstrap -f "${ROOT}/config/inventory.example.yaml" --node cp-1 --facts-file "${ROOT}/tests/fixtures/host/supported.yaml" --apply 2>&1)"
status=$?
set -e
assert_status "$status" 5 'Phase 3A host apply must fail closed'
assert_contains "$output" 'apply is disabled'

set +e
output="$(${KDM_BIN} host bootstrap -f "${ROOT}/config/inventory.example.yaml" --node cp-1 --facts-file "${ROOT}/tests/fixtures/host/supported.yaml" --facts-file "${ROOT}/tests/fixtures/host/supported.yaml" 2>&1)"
status=$?
set -e
assert_status "$status" 2 'repeated HostFacts option must fail closed'
assert_contains "$output" 'specified more than once'

output="$(${KDM_BIN} inventory targets -f "$inventory" --node wk-1 --node cp-1 --node wk-1 2>&1)" || fail 'inventory node target failed'
[ "$output" = $'wk-1\ncp-1' ] || fail "unexpected CLI node target order: ${output}"

set +e
output="$(${KDM_BIN} config validate -f "${ROOT}/tests/fixtures/inventory/invalid-role.yaml" 2>&1)"
status=$?
set -e
assert_status "$status" 3 'invalid inventory CLI status'
assert_contains "$output" 'inventory invalid'

set +e
output="$(${KDM_BIN} inventory targets -f "$inventory" --all --role worker 2>&1)"
status=$?
set -e
assert_status "$status" 2 'conflicting target selector CLI status'
assert_contains "$output" 'mutually exclusive'

set +e
output="$(${KDM_BIN} inventory targets -f "$inventory" --role control-plane --role worker 2>&1)"
status=$?
set -e
assert_status "$status" 2 'repeated role selector CLI status'
assert_contains "$output" 'mutually exclusive'

set +e
output="$(${KDM_BIN} unknown-command 2>&1)"
status=$?
set -e
assert_status "$status" 2 'unknown command'
assert_contains "$output" 'unknown command'

pass 'CLI help/version/error contract'
