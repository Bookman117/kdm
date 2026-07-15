#!/usr/bin/env bash
set -u

ROOT="$(cd -P -- "${BASH_SOURCE[0]%/*}/../.." && pwd)"
source "${ROOT}/tests/test_helper.sh"
source "${ROOT}/lib/core.sh"
source "${ROOT}/lib/log.sh"
source "${ROOT}/lib/safety.sh"

KDM_MODE=plan
set +e
kdm_require_apply 'cluster init' >/dev/null 2>&1
status=$?
set -e
assert_status "$status" 5 'plan must block mutation'

KDM_MODE=apply
kdm_require_apply 'cluster init' >/dev/null 2>&1 || fail 'apply mode should allow mutation gate'

set +e
kdm_require_exact_target 'wk-1' 'wk-2' >/dev/null 2>&1
status=$?
set -e
assert_status "$status" 5 'target mismatch must fail'

kdm_require_exact_target 'wk-1' 'wk-1' >/dev/null 2>&1 || fail 'exact target should pass'

set +e
kdm_forbid_data_destruction 'rook wipe' >/dev/null 2>&1
status=$?
set -e
assert_status "$status" 5 'data destruction must remain disabled in Phase 1'

pass 'plan/apply and destructive safety gates'
