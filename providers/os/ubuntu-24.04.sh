#!/usr/bin/env bash

kdm_ubuntu_modules_content() {
  printf '%s\n' \
    '# Managed by KDM v2' \
    'overlay' \
    'br_netfilter'
}

kdm_ubuntu_sysctl_content() {
  printf '%s\n' \
    '# Managed by KDM v2' \
    'net.bridge.bridge-nf-call-iptables = 1' \
    'net.bridge.bridge-nf-call-ip6tables = 1' \
    'net.ipv4.ip_forward = 1'
}

kdm_ubuntu_apt_source_content() {
  local repository="$1"
  local keyring="$2"

  printf '%s\n' \
    '# Managed by KDM v2' \
    "deb [signed-by=${keyring}] ${repository} /"
}
