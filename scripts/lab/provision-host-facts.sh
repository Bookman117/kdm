#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -P -- "${BASH_SOURCE[0]%/*}/../.." && pwd)"
: "${KDM_LAB_VM:?KDM_LAB_VM is required}"
: "${KDM_LAB_HOST_FACTS_PUBLIC_KEY:?KDM_LAB_HOST_FACTS_PUBLIC_KEY is required}"
: "${KDM_LAB_PROVISION_CONFIRM:?KDM_LAB_PROVISION_CONFIRM is required}"

[ "$KDM_LAB_PROVISION_CONFIRM" = "$KDM_LAB_VM" ] || {
  printf 'lab provision confirmation must exactly match VM name\n' >&2
  exit 5
}
[ -r "$KDM_LAB_HOST_FACTS_PUBLIC_KEY" ] || {
  printf 'host-facts public key is not readable\n' >&2
  exit 4
}
[ -x "${ROOT}/scripts/guest/kdm-host-facts" ] || {
  printf 'guest collector is not executable\n' >&2
  exit 4
}

read -r key_type key_material _ <"$KDM_LAB_HOST_FACTS_PUBLIC_KEY"
if [ "$key_type" != ssh-ed25519 ] || [ -z "$key_material" ]; then
  printf 'host-facts public key is invalid\n' >&2
  exit 3
fi

remote_collector='/tmp/kdm-host-facts.provision'
remote_public_key='/tmp/kdm-host-facts.pub.provision'
multipass transfer "${ROOT}/scripts/guest/kdm-host-facts" "${KDM_LAB_VM}:${remote_collector}"
multipass transfer "$KDM_LAB_HOST_FACTS_PUBLIC_KEY" "${KDM_LAB_VM}:${remote_public_key}"

multipass exec "$KDM_LAB_VM" -- sudo bash -s -- "$remote_collector" "$remote_public_key" <<'GUEST'
set -Eeuo pipefail
collector_source="$1"
public_key_source="$2"
collector_target='/usr/local/libexec/kdm-host-facts'
authorized_keys='/home/kdm-probe/.ssh/authorized_keys'
temp_authorized="$(mktemp)"
trap 'rm -f "$collector_source" "$public_key_source" "$temp_authorized"' EXIT

install -d -o root -g root -m 0755 /usr/local/libexec
install -o root -g root -m 0755 "$collector_source" "$collector_target"
read -r key_type key_material _ <"$public_key_source"
while IFS= read -r existing; do
  case "$existing" in
    *" ${key_type} ${key_material}"*) ;;
    *) printf '%s\n' "$existing" >>"$temp_authorized" ;;
  esac
done <"$authorized_keys"
printf 'restrict,command="%s" %s %s kdm-host-facts\n' "$collector_target" "$key_type" "$key_material" >>"$temp_authorized"
install -o kdm-probe -g kdm-probe -m 0600 "$temp_authorized" "$authorized_keys"
GUEST

local_sha="$(shasum -a 256 "${ROOT}/scripts/guest/kdm-host-facts")"
local_sha="${local_sha%% *}"
remote_sha="$(multipass exec "$KDM_LAB_VM" -- sha256sum /usr/local/libexec/kdm-host-facts)"
remote_sha="${remote_sha%% *}"
[ "$local_sha" = "$remote_sha" ] || {
  printf 'collector checksum mismatch after provision\n' >&2
  exit 4
}
printf 'PASS: provisioned fixed host-facts collector on %s\n' "$KDM_LAB_VM"
