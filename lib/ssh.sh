#!/usr/bin/env bash

kdm_ssh_run_node() {
  local executor="$1"
  local user="$2"
  local address="$3"
  local port="$4"
  local timeout="$5"
  local host_key_policy="$6"
  shift 6
  local -a argv

  if [ ! -x "$executor" ]; then
    kdm_error 'SSH executor is not executable'
    return "$KDM_EXIT_PREREQUISITE"
  fi
  if [ "$#" -lt 1 ]; then
    kdm_error 'controlled SSH command is required'
    return "$KDM_EXIT_CONFIG"
  fi

  argv=(
    "$executor"
    -o 'BatchMode=yes'
    -o "ConnectTimeout=${timeout}"
    -o "StrictHostKeyChecking=${host_key_policy}"
    -p "$port"
    --
    "${user}@${address}"
    "$@"
  )

  "${argv[@]}"
}

kdm_ssh_orchestrate() {
  local executor="${1:-}"
  local records="${2:-}"
  shift 2 || true
  local node_name node_role node_address ssh_user ssh_port
  local aggregate_status=0
  local node_count=0

  if [ -z "$records" ]; then
    kdm_error 'SSH target set is empty'
    return "$KDM_EXIT_CONFIG"
  fi
  if [ "$#" -lt 1 ]; then
    kdm_error 'controlled SSH command is required'
    return "$KDM_EXIT_CONFIG"
  fi

  while IFS=$'\t' read -r node_name node_role node_address ssh_user ssh_port; do
    [ -n "$node_name" ] || continue
    node_count=$((node_count + 1))
    if kdm_ssh_run_node "$executor" "$ssh_user" "$node_address" "$ssh_port" 5 accept-new "$@"; then
      kdm_info "SSH result: ${node_name} (${node_role}) success"
    else
      kdm_error "SSH result: ${node_name} (${node_role}) failed"
      aggregate_status="$KDM_EXIT_EXECUTION"
    fi
  done <<<"$records"

  if [ "$node_count" -lt 1 ]; then
    kdm_error 'SSH target set is empty'
    return "$KDM_EXIT_CONFIG"
  fi
  return "$aggregate_status"
}
