#!/usr/bin/env bash
set -u

ROOT="$(cd -P -- "${BASH_SOURCE[0]%/*}/../.." && pwd)"
source "${ROOT}/tests/test_helper.sh"

output="$(${KDM_BIN} doctor 2>&1)" || fail 'kdm doctor failed'
assert_contains "$output" 'Required'
assert_contains "$output" 'Optional'
assert_contains "$output" 'bash'
assert_contains "$output" 'kubectl'

pass 'doctor is informational when optional tools are missing'
