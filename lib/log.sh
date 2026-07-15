#!/usr/bin/env bash

kdm_info() {
  printf '[INFO] %s\n' "$*" >&2
}

kdm_warn() {
  printf '[WARN] %s\n' "$*" >&2
}

kdm_error() {
  printf '[ERROR] %s\n' "$*" >&2
}
