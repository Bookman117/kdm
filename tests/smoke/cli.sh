#!/usr/bin/env bash
set -u

ROOT="$(cd -P -- "${BASH_SOURCE[0]%/*}/../.." && pwd)"
# shellcheck source=../test_helper.sh
source "${ROOT}/tests/test_helper.sh"

output="$(${KDM_BIN} help 2>&1)" || fail 'kdm help failed'
assert_contains "$output" 'KDM v2'
assert_contains "$output" 'doctor'

output="$(${KDM_BIN} --help 2>&1)" || fail 'kdm --help failed'
assert_contains "$output" 'Usage:'

output="$(${KDM_BIN} version 2>&1)" || fail 'kdm version failed'
assert_contains "$output" 'kdm 2.0.0-dev'

set +e
output="$(${KDM_BIN} unknown-command 2>&1)"
status=$?
set -e
assert_status "$status" 2 'unknown command'
assert_contains "$output" 'unknown command'

pass 'CLI help/version/error contract'
