#!/usr/bin/env bash
set -u

ROOT="$(cd -P -- "${BASH_SOURCE[0]%/*}/../.." && pwd)"
FIXTURES="${ROOT}/tests/fixtures/inventory"
source "${ROOT}/tests/test_helper.sh"
source "${ROOT}/lib/core.sh"
source "${ROOT}/lib/log.sh"
source "${ROOT}/lib/validation.sh"
source "${ROOT}/lib/config.sh"

assert_valid_inventory() {
  local path="$1"
  kdm_config_validate_file "$path" >/dev/null 2>&1 || fail "expected valid inventory: ${path}"
}

assert_invalid_inventory() {
  local path="$1"
  local status
  set +e
  kdm_config_validate_file "$path" >/dev/null 2>&1
  status=$?
  set -e
  assert_status "$status" "$KDM_EXIT_CONFIG" "expected invalid inventory: ${path}"
}

assert_valid_inventory "${FIXTURES}/valid-single.yaml"
assert_valid_inventory "${FIXTURES}/valid-multi.yaml"

for fixture in \
  invalid-api-version.yaml \
  invalid-kind.yaml \
  invalid-missing-nodes.yaml \
  invalid-missing-node-field.yaml \
  invalid-duplicate-name.yaml \
  invalid-duplicate-address.yaml \
  invalid-role.yaml \
  invalid-address.yaml \
  invalid-ssh-port.yaml \
  invalid-host-key-policy.yaml \
  invalid-secret.yaml \
  invalid-yaml.txt; do
  assert_invalid_inventory "${FIXTURES}/${fixture}"
done

assert_invalid_inventory "${FIXTURES}/does-not-exist.yaml"

set +e
PATH='' kdm_require_yq_v4 >/dev/null 2>&1
status=$?
set -e
assert_status "$status" "$KDM_EXIT_PREREQUISITE" 'missing yq v4 must fail as a prerequisite'

pass 'inventory schema accepts valid fixtures and rejects invalid fixtures'
