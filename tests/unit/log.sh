#!/usr/bin/env bash
set -u

ROOT="$(cd -P -- "${BASH_SOURCE[0]%/*}/../.." && pwd)"
# shellcheck source=../test_helper.sh
source "${ROOT}/tests/test_helper.sh"
# shellcheck source=../../lib/log.sh
source "${ROOT}/lib/log.sh"

stdout_file="$(mktemp)"
stderr_file="$(mktemp)"
trap 'rm -f "$stdout_file" "$stderr_file"' EXIT

assert_log_contract() {
  local function_name="$1"
  local expected_level="$2"
  local message="logging contract message"
  local stdout_text stderr_text

  : >"$stdout_file"
  : >"$stderr_file"
  "$function_name" "$message" >"$stdout_file" 2>"$stderr_file"

  stdout_text="$(<"$stdout_file")"
  stderr_text="$(<"$stderr_file")"

  [ -z "$stdout_text" ] || fail "${function_name} wrote to stdout"
  assert_contains "$stderr_text" "[${expected_level}] ${message}"
}

assert_log_contract kdm_info INFO
assert_log_contract kdm_warn WARN
assert_log_contract kdm_error ERROR

pass 'logging functions write only to stderr with stable level prefixes'
