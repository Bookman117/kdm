#!/usr/bin/env bash

KDM_MODE="${KDM_MODE:-plan}"

kdm_set_execution_mode() {
  case "${1:-plan}" in
    plan)
      KDM_MODE=plan
      ;;
    apply|--apply)
      KDM_MODE=apply
      ;;
    *)
      kdm_error "invalid execution mode: ${1:-}"
      return "$KDM_EXIT_USAGE"
      ;;
  esac
}

kdm_require_apply() {
  local operation="${1:-operation}"

  if [ "$KDM_MODE" != 'apply' ]; then
    kdm_warn "PLAN ONLY: ${operation}; pass --apply in a future implemented workflow to mutate state"
    return "$KDM_EXIT_SAFETY"
  fi

  return 0
}

kdm_require_exact_target() {
  local expected_target="${1:-}"
  local confirmed_target="${2:-}"

  kdm_require_apply "target ${expected_target:-<empty>}" || return "$?"

  if [ -z "$expected_target" ] || [ "$expected_target" != "$confirmed_target" ]; then
    kdm_error "target confirmation mismatch"
    return "$KDM_EXIT_SAFETY"
  fi

  return 0
}

kdm_forbid_data_destruction() {
  local operation="${1:-data destruction}"
  kdm_error "${operation} is disabled in Phase 1"
  return "$KDM_EXIT_SAFETY"
}
