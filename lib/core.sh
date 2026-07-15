#!/usr/bin/env bash

readonly KDM_VERSION='2.0.0-dev'
readonly KDM_EXIT_USAGE=2
readonly KDM_EXIT_CONFIG=3
readonly KDM_EXIT_PREREQUISITE=4
readonly KDM_EXIT_SAFETY=5

kdm_usage() {
  printf '%s\n' \
    'KDM v2 — plan-first Kubernetes Deployment Manager' \
    '' \
    'Usage:' \
    '  kdm help' \
    '  kdm version' \
    '  kdm doctor' \
    '' \
    'Phase 1 scope:' \
    '  - help/version/doctor are read-only and have no cluster side effects' \
    '  - host, cluster, node and addon mutation workflows are not implemented' \
    '' \
    'Legacy v1 remains available in the repository root and is not sourced by v2.'
}

kdm_dispatch() {
  local command_name="${1:-help}"

  case "$command_name" in
    help|-h|--help)
      kdm_usage
      ;;
    version|--version)
      printf 'kdm %s\n' "$KDM_VERSION"
      ;;
    doctor)
      shift
      kdm_doctor "$@"
      ;;
    *)
      kdm_error "unknown command: ${command_name}"
      kdm_usage >&2
      return "$KDM_EXIT_USAGE"
      ;;
  esac
}
