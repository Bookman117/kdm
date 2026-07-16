#!/usr/bin/env bash
set -u

ROOT="$(cd -P -- "${BASH_SOURCE[0]%/*}/../.." && pwd)"
FIXTURE="${ROOT}/tests/fixtures/inventory/valid-multi.yaml"
source "${ROOT}/tests/test_helper.sh"
source "${ROOT}/lib/core.sh"
source "${ROOT}/lib/log.sh"
source "${ROOT}/lib/validation.sh"
source "${ROOT}/lib/config.sh"
source "${ROOT}/lib/inventory.sh"

records="$(kdm_inventory_records "$FIXTURE")" || fail 'failed to normalize inventory'
assert_contains "$records" $'cp-1\tcontrol-plane\tcp-1.example.test\toperator\t2222'
assert_contains "$records" $'wk-1\tworker\t2001:db8::21\toperator\t2222'

all_targets="$(kdm_inventory_targets "$FIXTURE" all)" || fail 'all target resolution failed'
assert_contains "$all_targets" 'cp-1'
assert_contains "$all_targets" 'cp-2'
assert_contains "$all_targets" 'wk-1'

cp_targets="$(kdm_inventory_targets "$FIXTURE" role control-plane)" || fail 'role target resolution failed'
assert_contains "$cp_targets" 'cp-1'
assert_contains "$cp_targets" 'cp-2'
case "$cp_targets" in
  *wk-1*) fail 'worker leaked into control-plane targets' ;;
esac

node_targets="$(kdm_inventory_targets "$FIXTURE" node wk-1 cp-1 wk-1)" || fail 'node target resolution failed'
[ "$node_targets" = $'wk-1\ncp-1' ] || fail "unexpected node target order: ${node_targets}"

set +e
kdm_inventory_targets "$FIXTURE" node missing >/dev/null 2>&1
status=$?
set -e
assert_status "$status" "$KDM_EXIT_CONFIG" 'unknown node must fail'

set +e
kdm_inventory_targets "${ROOT}/tests/fixtures/inventory/valid-single.yaml" role worker >/dev/null 2>&1
status=$?
set -e
assert_status "$status" "$KDM_EXIT_CONFIG" 'empty role target set must fail closed'

pass 'inventory normalization and target resolution'
