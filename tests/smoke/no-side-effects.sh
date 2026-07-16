#!/usr/bin/env bash
set -u

ROOT="$(cd -P -- "${BASH_SOURCE[0]%/*}/../.." && pwd)"
source "${ROOT}/tests/test_helper.sh"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
log_file="${tmp_dir}/calls.log"
mkdir -p "${tmp_dir}/bin"

for command_name in sudo ssh kubectl apt apt-get dnf yum helm systemctl service modprobe sysctl swapoff ufw tee install; do
  cat >"${tmp_dir}/bin/${command_name}" <<SCRIPT
#!/usr/bin/env bash
printf '%s\\n' '${command_name}' >>'${log_file}'
exit 99
SCRIPT
  chmod +x "${tmp_dir}/bin/${command_name}"
done

ln -s "$(command -v yq)" "${tmp_dir}/bin/yq"

safe_path="${tmp_dir}/bin:/usr/bin:/bin:/usr/sbin:/sbin"
PATH="$safe_path" /bin/bash "${KDM_BIN}" help >/dev/null || fail 'help failed under side-effect sentinels'
PATH="$safe_path" /bin/bash "${KDM_BIN}" version >/dev/null || fail 'version failed under side-effect sentinels'
PATH="$safe_path" /bin/bash "${KDM_BIN}" doctor >/dev/null || fail 'doctor failed under side-effect sentinels'
PATH="$safe_path" /bin/bash "${KDM_BIN}" config validate -f "${ROOT}/tests/fixtures/inventory/valid-single.yaml" >/dev/null || fail 'config validate failed under side-effect sentinels'
PATH="$safe_path" /bin/bash "${KDM_BIN}" inventory targets -f "${ROOT}/tests/fixtures/inventory/valid-single.yaml" --all >/dev/null || fail 'inventory targets failed under side-effect sentinels'
PATH="$safe_path" /bin/bash "${KDM_BIN}" host bootstrap -f "${ROOT}/config/inventory.example.yaml" --node cp-1 --facts-file "${ROOT}/tests/fixtures/host/supported.yaml" >/dev/null || fail 'host bootstrap plan failed under side-effect sentinels'

[ ! -s "$log_file" ] || fail "read-only commands executed a mutating/external command: $(tr '\n' ' ' <"$log_file")"
pass 'read-only CLI commands perform no sudo/SSH/Kubernetes/package-manager/host-mutation calls'
