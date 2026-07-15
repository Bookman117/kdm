#!/usr/bin/env bash

kdm_check_bash() {
  if [ "${BASH_VERSINFO[0]}" -lt 3 ]; then
    kdm_error "Bash 3.0 or newer is required; detected ${BASH_VERSION}"
    return "$KDM_EXIT_PREREQUISITE"
  fi

  printf '  %-14s %s\n' 'bash' "PASS (${BASH_VERSION})"
}

kdm_print_optional_command() {
  local command_name="$1"

  if command -v "$command_name" >/dev/null 2>&1; then
    printf '  %-14s %s\n' "$command_name" 'AVAILABLE'
  else
    printf '  %-14s %s\n' "$command_name" 'MISSING'
  fi
}

kdm_doctor() {
  local command_name

  printf '%s\n' 'Required'
  kdm_check_bash || return "$?"

  printf '%s\n' 'Optional'
  for command_name in shellcheck shfmt kubectl kubeconform yq; do
    kdm_print_optional_command "$command_name"
  done

  printf '%s\n' 'Doctor completed. Optional tools are not installed or executed automatically.'
}
