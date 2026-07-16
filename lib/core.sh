#!/usr/bin/env bash

readonly KDM_VERSION='2.0.0-dev'
readonly KDM_EXIT_USAGE=2
readonly KDM_EXIT_CONFIG=3
readonly KDM_EXIT_PREREQUISITE=4
readonly KDM_EXIT_SAFETY=5
readonly KDM_EXIT_EXECUTION=10

kdm_usage() {
  printf '%s\n' \
    'KDM v2 — plan-first Kubernetes Deployment Manager' \
    '' \
    'Usage:' \
    '  kdm help' \
    '  kdm version' \
    '  kdm doctor' \
    '  kdm config validate -f <inventory.yaml>' \
    '  kdm inventory targets -f <inventory.yaml> --all' \
    '  kdm inventory targets -f <inventory.yaml> --role <control-plane|worker>' \
    '  kdm inventory targets -f <inventory.yaml> --node <name> [--node <name> ...]' \
    '  kdm host bootstrap -f <inventory.yaml> --node <name> --facts-file <host-facts.yaml>' \
    '' \
    'Phase 3A scope:' \
    '  - host bootstrap renders a deterministic plan from local HostFacts' \
    '  - --apply is disabled; no sudo, package manager, SSH, or host mutation' \
    '' \
    'Legacy v1 remains available in the repository root and is not sourced by v2.'
}

kdm_dispatch_config() {
  local action="${1:-}"
  local path=''
  shift || true

  if [ "$action" != 'validate' ]; then
    kdm_error 'usage: kdm config validate -f <inventory.yaml>'
    return "$KDM_EXIT_USAGE"
  fi

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -f|--file)
        if [ "$#" -lt 2 ]; then
          kdm_error 'inventory file value is required'
          return "$KDM_EXIT_USAGE"
        fi
        path="$2"
        shift 2
        ;;
      *)
        kdm_error "unknown config option: $1"
        return "$KDM_EXIT_USAGE"
        ;;
    esac
  done

  if [ -z "$path" ]; then
    kdm_error 'inventory file is required'
    return "$KDM_EXIT_USAGE"
  fi
  kdm_config_validate_file "$path" || return "$?"
  printf 'Inventory valid: %s (%s nodes)\n' "$(kdm_config_inventory_name "$path")" "$(kdm_config_node_count "$path")"
}

kdm_dispatch_inventory() {
  local action="${1:-}"
  local path=''
  local selector=''
  local role=''
  local -a nodes
  nodes=()
  shift || true

  if [ "$action" != 'targets' ]; then
    kdm_error 'usage: kdm inventory targets -f <inventory.yaml> <selector>'
    return "$KDM_EXIT_USAGE"
  fi

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -f|--file)
        if [ "$#" -lt 2 ]; then
          kdm_error 'inventory file value is required'
          return "$KDM_EXIT_USAGE"
        fi
        path="$2"
        shift 2
        ;;
      --all)
        if [ -n "$selector" ]; then
          kdm_error 'target selectors are mutually exclusive'
          return "$KDM_EXIT_USAGE"
        fi
        selector=all
        shift
        ;;
      --role)
        if [ "$#" -lt 2 ]; then
          kdm_error 'role value is required'
          return "$KDM_EXIT_USAGE"
        fi
        if [ -n "$selector" ]; then
          kdm_error 'target selectors are mutually exclusive'
          return "$KDM_EXIT_USAGE"
        fi
        selector=role
        role="$2"
        shift 2
        ;;
      --node)
        if [ "$#" -lt 2 ]; then
          kdm_error 'node value is required'
          return "$KDM_EXIT_USAGE"
        fi
        if [ -n "$selector" ] && [ "$selector" != node ]; then
          kdm_error 'target selectors are mutually exclusive'
          return "$KDM_EXIT_USAGE"
        fi
        selector=node
        nodes+=("$2")
        shift 2
        ;;
      *)
        kdm_error "unknown inventory option: $1"
        return "$KDM_EXIT_USAGE"
        ;;
    esac
  done

  if [ -z "$path" ]; then
    kdm_error 'inventory file is required'
    return "$KDM_EXIT_USAGE"
  fi

  case "$selector" in
    all) kdm_inventory_targets "$path" all ;;
    role) kdm_inventory_targets "$path" role "$role" ;;
    node) kdm_inventory_targets "$path" node "${nodes[@]}" ;;
    *) kdm_error 'one target selector is required'; return "$KDM_EXIT_USAGE" ;;
  esac
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
    config)
      shift
      kdm_dispatch_config "$@"
      ;;
    inventory)
      shift
      kdm_dispatch_inventory "$@"
      ;;
    host)
      shift
      kdm_dispatch_host "$@"
      ;;
    *)
      kdm_error "unknown command: ${command_name}"
      kdm_usage >&2
      return "$KDM_EXIT_USAGE"
      ;;
  esac
}
