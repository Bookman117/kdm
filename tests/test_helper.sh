#!/usr/bin/env bash
set -u

TEST_ROOT="$(cd -P -- "${BASH_SOURCE[0]%/*}/.." && pwd)"
KDM_BIN="${TEST_ROOT}/bin/kdm"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  case "$haystack" in
    *"$needle"*) ;;
    *) fail "expected output to contain: ${needle}" ;;
  esac
}

assert_status() {
  local actual="$1"
  local expected="$2"
  local context="$3"
  [ "$actual" -eq "$expected" ] || fail "${context}: expected status ${expected}, got ${actual}"
}

pass() {
  printf 'PASS: %s\n' "$*"
}
