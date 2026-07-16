#!/usr/bin/env bash

kdm_require_yq_v4() {
  local version_output

  if ! command -v yq >/dev/null 2>&1; then
    kdm_error 'Mike Farah yq v4 is required for inventory commands'
    return "$KDM_EXIT_PREREQUISITE"
  fi

  version_output="$(yq --version 2>/dev/null)"
  case "$version_output" in
    *mikefarah/yq*'version v4.'*) return 0 ;;
    *)
      kdm_error 'unsupported yq implementation; Mike Farah yq v4 is required'
      return "$KDM_EXIT_PREREQUISITE"
      ;;
  esac
}

kdm_config_fail() {
  kdm_error "inventory invalid: $*"
  return "$KDM_EXIT_CONFIG"
}

kdm_config_validate_file() {
  local path="${1:-}"
  local api_version kind inventory_name ssh_user ssh_port ssh_timeout host_key_policy
  local node_count unique_names unique_addresses key key_lower
  local node_name node_address node_role

  kdm_require_yq_v4 || return "$?"

  [ -n "$path" ] || kdm_config_fail 'file path is required' || return "$?"
  [ -r "$path" ] || kdm_config_fail 'file is not readable' || return "$?"
  yq eval '.' "$path" >/dev/null 2>&1 || kdm_config_fail 'YAML parse failed' || return "$?"

  api_version="$(yq -r '.apiVersion // ""' "$path")"
  kind="$(yq -r '.kind // ""' "$path")"
  inventory_name="$(yq -r '.metadata.name // ""' "$path")"
  ssh_user="$(yq -r '.spec.ssh.user // ""' "$path")"
  ssh_port="$(yq -r '.spec.ssh.port // 22' "$path")"
  ssh_timeout="$(yq -r '.spec.ssh.connectTimeoutSeconds // 5' "$path")"
  host_key_policy="$(yq -r '.spec.ssh.hostKeyPolicy // "accept-new"' "$path")"

  [ "$api_version" = 'kdm.io/v2alpha1' ] || kdm_config_fail 'unsupported apiVersion' || return "$?"
  [ "$kind" = 'Inventory' ] || kdm_config_fail 'kind must be Inventory' || return "$?"
  [[ "$inventory_name" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] || kdm_config_fail 'metadata.name format is invalid' || return "$?"
  [[ "$ssh_user" =~ ^[A-Za-z_][A-Za-z0-9_-]*$ ]] || kdm_config_fail 'spec.ssh.user format is invalid' || return "$?"
  [[ "$ssh_port" =~ ^[0-9]+$ ]] && [ "$ssh_port" -ge 1 ] && [ "$ssh_port" -le 65535 ] || kdm_config_fail 'SSH port must be between 1 and 65535' || return "$?"
  [[ "$ssh_timeout" =~ ^[0-9]+$ ]] && [ "$ssh_timeout" -ge 1 ] && [ "$ssh_timeout" -le 60 ] || kdm_config_fail 'SSH timeout must be between 1 and 60 seconds' || return "$?"
  case "$host_key_policy" in
    yes|accept-new) ;;
    *) kdm_config_fail 'SSH host key policy must be yes or accept-new' || return "$?" ;;
  esac

  while IFS= read -r key; do
    key_lower="$(printf '%s' "$key" | tr '[:upper:]' '[:lower:]')"
    case "$key_lower" in
      password|passphrase|token|privatekey|private_key|kubeconfig|clientsecret)
        kdm_config_fail "forbidden credential field: ${key}" || return "$?"
        ;;
    esac
  done < <(yq -r '.. | select(tag == "!!map") | keys | .[]' "$path")

  node_count="$(yq -r '.spec.nodes // [] | length' "$path")"
  [[ "$node_count" =~ ^[0-9]+$ ]] && [ "$node_count" -ge 1 ] || kdm_config_fail 'at least one node is required' || return "$?"
  yq -e '[.spec.nodes[] | select((.name | tag) != "!!str" or (.address | tag) != "!!str" or (.role | tag) != "!!str")] | length == 0' "$path" >/dev/null 2>&1 || kdm_config_fail 'node name, address, and role must be strings' || return "$?"

  unique_names="$(yq -r '[.spec.nodes[].name] | length == (unique | length)' "$path")"
  unique_addresses="$(yq -r '[.spec.nodes[].address] | length == (unique | length)' "$path")"
  [ "$unique_names" = 'true' ] || kdm_config_fail 'node names must be unique' || return "$?"
  [ "$unique_addresses" = 'true' ] || kdm_config_fail 'node addresses must be unique' || return "$?"

  while IFS=$'\t' read -r node_name node_address node_role; do
    [[ "$node_name" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] || kdm_config_fail 'node name format is invalid' || return "$?"
    [[ "$node_address" =~ ^[A-Za-z0-9][A-Za-z0-9.:%-]*$ ]] || kdm_config_fail "node address format is invalid: ${node_name}" || return "$?"
    case "$node_role" in
      control-plane|worker) ;;
      *) kdm_config_fail "node role is invalid: ${node_name}" || return "$?" ;;
    esac
  done < <(yq -r '.spec.nodes[] | [.name, .address, .role] | @tsv' "$path")

  return 0
}

kdm_config_inventory_name() {
  local path="$1"
  yq -r '.metadata.name' "$path"
}

kdm_config_node_count() {
  local path="$1"
  yq -r '.spec.nodes | length' "$path"
}
