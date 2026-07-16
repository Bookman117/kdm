#!/usr/bin/env bash
set -u

ROOT="$(cd -P -- "${BASH_SOURCE[0]%/*}/../.." && pwd)"
INVENTORY="${ROOT}/config/inventory.example.yaml"
FACTS="${ROOT}/tests/fixtures/host/supported.yaml"
LOCK="${ROOT}/config/compatibility-lock.yaml"
source "${ROOT}/tests/test_helper.sh"
source "${ROOT}/lib/core.sh"
source "${ROOT}/lib/log.sh"
source "${ROOT}/lib/validation.sh"
source "${ROOT}/lib/config.sh"
source "${ROOT}/providers/os/ubuntu-24.04.sh"
source "${ROOT}/providers/runtime/crio.sh"
source "${ROOT}/lib/host.sh"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

first="$(kdm_host_render_plan "$INVENTORY" cp-1 "$FACTS" "$LOCK")" || fail 'supported host plan failed'
second="$(kdm_host_render_plan "$INVENTORY" cp-1 "$FACTS" "$LOCK")" || fail 'second supported host plan failed'
[ "$first" = "$second" ] || fail 'host plan must be deterministic'

assert_contains "$first" 'PLAN host-bootstrap'
assert_contains "$first" 'target=cp-1'
assert_contains "$first" 'profile=ubuntu-24.04-arm64-k8s-1.35'
assert_contains "$first" 'baseline=PASS'
assert_contains "$first" '/etc/modules-load.d/kdm-kubernetes.conf'
assert_contains "$first" '/etc/sysctl.d/99-kdm-kubernetes.conf'
assert_contains "$first" 'name=cri-o current=absent desired=1.35.5-1.1'
assert_contains "$first" 'name=kubelet current=absent desired=1.35.6-1.1'
assert_contains "$first" 'name=ca-certificates current=absent desired=present'
assert_contains "$first" 'name=curl current=absent desired=present'
assert_contains "$first" 'name=gpg current=absent desired=present'
assert_contains "$first" 'repository=https://pkgs.k8s.io/core:/stable:/v1.35/deb/'
assert_contains "$first" 'mode=PLAN_ONLY'
case "$first" in
  *'apt-get update'*|*'apt-get install'*|*'sudo '*) fail 'plan output exposed executable mutation commands' ;;
esac

no_change="$(kdm_host_render_plan "$INVENTORY" cp-1 "${ROOT}/tests/fixtures/host/no-change.yaml" "$LOCK")" || fail 'no-change host plan failed'
assert_contains "$no_change" 'KEYRING action=NO_CHANGE path=/etc/apt/keyrings/kdm-kubernetes-v1.35.gpg'
assert_contains "$no_change" 'MODULE action=NO_CHANGE name=overlay'
assert_contains "$no_change" 'SYSCTL action=NO_CHANGE name=net.ipv4.ip_forward'
assert_contains "$no_change" 'PACKAGE action=NO_CHANGE name=cri-o'
assert_contains "$no_change" 'HOLD action=NO_CHANGE packages=cri-o,kubelet,kubeadm,kubectl'
assert_contains "$no_change" 'SERVICE action=NO_CHANGE name=crio'
assert_contains "$no_change" 'current=enabled:true,active:true'
case "$no_change" in
  *'action=WRITE'*|*'action=INSTALL'*|*'action=LOAD'*|*'action=SET'*|*'action=HOLD'*|*'action=ENABLE'*) fail 'idempotent plan contains a mutating action' ;;
esac

yq '.spec.services.crio.enabled = false | .spec.services.crio.active = true' "${ROOT}/tests/fixtures/host/no-change.yaml" >"${tmp_dir}/crio-active-disabled.yaml"
service_drift="$(kdm_host_render_plan "$INVENTORY" cp-1 "${tmp_dir}/crio-active-disabled.yaml" "$LOCK")" || fail 'CRI-O service drift plan failed'
assert_contains "$service_drift" 'SERVICE action=ENABLE name=crio desired=enabled,active current=enabled:false,active:true'

pass 'host bootstrap plan is deterministic and contains exact desired state'
