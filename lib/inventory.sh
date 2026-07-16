#!/usr/bin/env bash

kdm_inventory_records() {
  local path="${1:-}"

  kdm_config_validate_file "$path" || return "$?"
  yq -r '.spec as $s | $s.nodes[] | [.name, .role, .address, $s.ssh.user, ($s.ssh.port // 22)] | @tsv' "$path"
}

kdm_inventory_targets() {
  local path="${1:-}"
  local selector="${2:-}"
  local value node selected

  shift 2 || true
  kdm_config_validate_file "$path" || return "$?"

  case "$selector" in
    all)
      [ "$#" -eq 0 ] || kdm_config_fail 'all selector accepts no values' || return "$?"
      yq -r '.spec.nodes[].name' "$path"
      ;;
    role)
      [ "$#" -eq 1 ] || kdm_config_fail 'role selector requires one value' || return "$?"
      value="$1"
      case "$value" in
        control-plane|worker) ;;
        *) kdm_config_fail 'unknown node role' || return "$?" ;;
      esac
      node="$(ROLE_NAME="$value" yq -r '.spec.nodes[] | select(.role == strenv(ROLE_NAME)) | .name' "$path")"
      [ -n "$node" ] || kdm_config_fail "no nodes matched role: ${value}" || return "$?"
      printf '%s\n' "$node"
      ;;
    node)
      [ "$#" -ge 1 ] || kdm_config_fail 'node selector requires at least one name' || return "$?"
      selected=$'\n'
      for node in "$@"; do
        NODE_NAME="$node" yq -e '[.spec.nodes[] | select(.name == strenv(NODE_NAME))] | length > 0' "$path" >/dev/null 2>&1 || kdm_config_fail "unknown node: ${node}" || return "$?"
        case "$selected" in
          *$'\n'"${node}"$'\n'*) ;;
          *)
            printf '%s\n' "$node"
            selected="${selected}${node}"$'\n'
            ;;
        esac
      done
      ;;
    *)
      kdm_config_fail 'target selector must be all, role, or node'
      return "$?"
      ;;
  esac
}
