#!/usr/bin/env bash

kdm_ssh_require_implemented() {
  kdm_error 'SSH execution is not implemented in Phase 1'
  return "$KDM_EXIT_PREREQUISITE"
}
