#!/usr/bin/env bash
set -u

ROOT="$(cd -P -- "${BASH_SOURCE[0]%/*}/../.." && pwd)"
source "${ROOT}/tests/test_helper.sh"
source "${ROOT}/lib/core.sh"
source "${ROOT}/lib/log.sh"
source "${ROOT}/lib/ssh.sh"

fake_ssh="${ROOT}/tests/helpers/fake-ssh"
log_file="$(mktemp)"
trap 'rm -f "$log_file"' EXIT
export FAKE_SSH_LOG="$log_file"

records=$'cp-1\tcontrol-plane\t192.0.2.11\tubuntu\t22\t7\tyes\nwk-1\tworker\t192.0.2.21\tubuntu\t22\t7\tyes'

kdm_ssh_orchestrate "$fake_ssh" "$records" hostname >/dev/null 2>&1 || fail 'all-success mock orchestration failed'
log_text="$(<"$log_file")"
assert_contains "$log_text" 'BatchMode=yes'
assert_contains "$log_text" 'StdinNull=yes'
assert_contains "$log_text" 'ConnectTimeout=7'
assert_contains "$log_text" 'StrictHostKeyChecking=yes'
assert_contains "$log_text" 'ubuntu@192.0.2.11'
assert_contains "$log_text" 'ubuntu@192.0.2.21'

: >"$log_file"
export FAKE_SSH_FAIL_TARGET='192.0.2.21'
set +e
kdm_ssh_orchestrate "$fake_ssh" "$records" hostname >/dev/null 2>&1
status=$?
set -e
assert_status "$status" "$KDM_EXIT_EXECUTION" 'partial SSH failure must aggregate to execution error'
log_text="$(<"$log_file")"
assert_contains "$log_text" 'ubuntu@192.0.2.11'
assert_contains "$log_text" 'ubuntu@192.0.2.21'
unset FAKE_SSH_FAIL_TARGET

: >"$log_file"
export FAKE_SSH_TIMEOUT_TARGET='192.0.2.11'
set +e
kdm_ssh_orchestrate "$fake_ssh" "$records" hostname >/dev/null 2>&1
status=$?
set -e
assert_status "$status" "$KDM_EXIT_EXECUTION" 'SSH timeout must aggregate to execution error'
log_text="$(<"$log_file")"
assert_contains "$log_text" 'ubuntu@192.0.2.11'
assert_contains "$log_text" 'ubuntu@192.0.2.21'
unset FAKE_SSH_TIMEOUT_TARGET

set +e
kdm_ssh_orchestrate "$fake_ssh" '' hostname >/dev/null 2>&1
status=$?
set -e
assert_status "$status" "$KDM_EXIT_CONFIG" 'empty target set must fail closed'

pass 'mock SSH argv and aggregate result handling'
