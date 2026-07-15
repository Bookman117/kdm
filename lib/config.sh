#!/usr/bin/env bash

kdm_config_require_implemented() {
  kdm_error 'inventory/config loading is not implemented in Phase 1'
  return "$KDM_EXIT_CONFIG"
}
