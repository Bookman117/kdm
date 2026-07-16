#!/usr/bin/env bash

kdm_dispatch_host() {
  local action="${1:-}"
  local inventory=''
  local target=''
  local facts=''
  local lock="${KDM_ROOT}/config/compatibility-lock.yaml"
  local lock_overridden=false
  shift || true

  if [ "$action" != bootstrap ]; then
    kdm_error 'usage: kdm host bootstrap -f <inventory.yaml> --node <name> --facts-file <host-facts.yaml>'
    return "$KDM_EXIT_USAGE"
  fi

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -f|--file)
        [ "$#" -ge 2 ] || { kdm_error 'inventory file value is required'; return "$KDM_EXIT_USAGE"; }
        [ -z "$inventory" ] || { kdm_error 'inventory file specified more than once'; return "$KDM_EXIT_USAGE"; }
        inventory="$2"
        shift 2
        ;;
      --node)
        [ "$#" -ge 2 ] || { kdm_error 'node value is required'; return "$KDM_EXIT_USAGE"; }
        [ -z "$target" ] || { kdm_error 'host bootstrap requires exactly one --node'; return "$KDM_EXIT_USAGE"; }
        target="$2"
        shift 2
        ;;
      --facts-file)
        [ "$#" -ge 2 ] || { kdm_error 'HostFacts file value is required'; return "$KDM_EXIT_USAGE"; }
        [ -z "$facts" ] || { kdm_error 'HostFacts file specified more than once'; return "$KDM_EXIT_USAGE"; }
        facts="$2"
        shift 2
        ;;
      --lock-file)
        [ "$#" -ge 2 ] || { kdm_error 'compatibility lock file value is required'; return "$KDM_EXIT_USAGE"; }
        [ "$lock_overridden" = false ] || { kdm_error 'compatibility lock file specified more than once'; return "$KDM_EXIT_USAGE"; }
        lock="$2"
        lock_overridden=true
        shift 2
        ;;
      --apply)
        kdm_error 'host bootstrap apply is disabled in Phase 3A; plan only'
        return "$KDM_EXIT_SAFETY"
        ;;
      --all|--role|--confirm-target)
        kdm_error "unsupported Phase 3A host bootstrap option: $1"
        return "$KDM_EXIT_USAGE"
        ;;
      *)
        kdm_error "unknown host bootstrap option: $1"
        return "$KDM_EXIT_USAGE"
        ;;
    esac
  done

  [ -n "$inventory" ] || { kdm_error 'inventory file is required'; return "$KDM_EXIT_USAGE"; }
  [ -n "$target" ] || { kdm_error 'exactly one --node is required'; return "$KDM_EXIT_USAGE"; }
  [ -n "$facts" ] || { kdm_error 'HostFacts file is required'; return "$KDM_EXIT_USAGE"; }

  kdm_host_render_plan "$inventory" "$target" "$facts" "$lock"
}
