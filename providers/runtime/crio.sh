#!/usr/bin/env bash

kdm_crio_apt_source_content() {
  local repository="$1"
  local keyring="$2"

  printf '%s\n' \
    '# Managed by KDM v2' \
    "deb [signed-by=${keyring}] ${repository} /"
}
