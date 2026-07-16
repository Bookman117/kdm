# KDM Phase 3 Host Bootstrap Design Baseline

> 日期：2026-07-16
> 狀態：Phase 3A planner/preflight 已實作；apply installer 尚未撰寫或執行
> 適用範圍：Ubuntu 24.04 LTS ARM64 candidate、Kubernetes 1.35、CRI-O 1.35

## 結論

第一個 Phase 3 candidate 固定為：

```text
Node OS: Ubuntu 24.04.4 LTS
Architecture: arm64
Kernel observed in lab: 6.8.0-134-generic
Cgroup: v2
Kubernetes: v1.35.6 / Debian package 1.35.6-1.1
CRI-O: v1.35.5 / Debian package 1.35.5-1.1
Package manager: apt
Init system: systemd
```

選 Kubernetes 1.35 而非 1.36，理由是 1.35 為目前 N-1 minor，已有較多 patch 累積；CRI-O 與 Kubernetes 保持相同 minor，但 patch release 不要求相同。

這仍是 **Candidate**，不是 Supported。必須完成 host bootstrap idempotency、kubeadm preflight、單節點與多節點 integration 後才可升級支援等級。

## 1. 已驗證的 lab baseline

`kdm-lab-cp1` 實際 read-only probe：

| 項目 | 實際值 | Phase 3 決策 |
|---|---|---|
| OS | Ubuntu 24.04 | 第一個 candidate |
| Architecture | arm64 | 第一個已驗證架構；amd64 repo 可用但尚未做 lab integration |
| Kernel | 6.8.0-134-generic | 交由 kubeadm SystemVerification 最終判定 |
| Cgroup filesystem | cgroup2fs | 要求 cgroup v2 |
| systemd | 255 | 使用 systemd cgroup manager |
| Swap | 0 active entries | 要求 apply 前已停用；KDM 不自動改未知 fstab |
| AppArmor | active | 保持啟用，不停用安全機制 |
| iptables | nf_tables backend | 接受，不切換 legacy backend |
| nftables | 1.0.9 | 保持系統預設 |
| `br_netfilter` | 尚未載入 | KDM-owned modules-load file 管理 |
| `overlay` | 尚未載入 | KDM-owned modules-load file 管理 |
| IPv4 forwarding | 0 | KDM-owned sysctl file設為 1 |
| Guest root free | 約 6.7 GiB | 不足以進入完整 apply + image integration |
| Host free | 約 14 GiB | 暫停 VM 擴充與大型 image pull |

## 2. Version baseline

### Kubernetes

| 項目 | 固定值 |
|---|---|
| Minor repository | `v1.35` |
| Upstream stable endpoint | `v1.35.6` |
| `kubelet` package | `1.35.6-1.1` |
| `kubeadm` package | `1.35.6-1.1` |
| `kubectl` package | `1.35.6-1.1` |

### CRI-O

| 項目 | 固定值 |
|---|---|
| Minor repository | `v1.35` |
| `cri-o` package | `1.35.5-1.1` |
| CRI socket | `unix:///var/run/crio/crio.sock` |
| Cgroup manager | systemd；實作前需以 package default/read-back 驗證 |

Kubernetes 與 CRI-O minor 必須相同。CRI-O 官方說明明確指出 patch release cadence 不與 Kubernetes 同步，因此 `1.35.6` 搭配 `1.35.5` 是允許的 minor-aligned model。

## 3. Official repository baseline

### Kubernetes repository

```text
https://pkgs.k8s.io/core:/stable:/v1.35/deb/
```

Repository metadata 已確認包含：

```text
Architectures: amd64 arm64 s390x ppc64el
Description: Kubernetes v1.35 (Stable) (deb)
```

Signing key observation（2026-07-16）：

```text
Fingerprint: DE15B14486CD377B9E876E1A234654DA9A296436
SHA-256: 7627818cf7bae52f9008c93e8b1f961f53dea11d40891778de216fb1b43be54d
Expires: 2026-12-29
```

### CRI-O repository

```text
https://download.opensuse.org/repositories/isv:/cri-o:/stable:/v1.35/deb/
```

Repository metadata 已確認包含：

```text
Architectures: amd64 arm64 ppc64el s390x
Description: CRI-O v1.35 (Stable) (deb)
```

Signing key observation（2026-07-16）：

```text
Fingerprint: 85B67D5C50100B1AC8CEFE49CBA9C85640A2B579
SHA-256: 4e1f851eccaad9068a8287332a3b615f9a8243cb53dc3c084109c701caa684bc
Expires: 2027-04-22
```

Fingerprint/SHA 是 compatibility lock 的觀察值，不應散落在 shell function。Key rotation 或到期必須透過明確 compatibility update，不可在 apply 時靜默接受新 key。

## 4. KDM-owned files

Phase 3 只能建立或修改以下專屬路徑：

```text
/etc/modules-load.d/kdm-kubernetes.conf
/etc/sysctl.d/99-kdm-kubernetes.conf
/etc/apt/keyrings/kdm-kubernetes-v1.35.gpg
/etc/apt/keyrings/kdm-crio-v1.35.gpg
/etc/apt/sources.list.d/kdm-kubernetes-v1.35.list
/etc/apt/sources.list.d/kdm-crio-v1.35.list
```

Text files必須包含：

```text
# Managed by KDM v2
```

規則：

1. 不刪除 `/etc/apt/sources.list.d/*`。
2. 不覆寫 `kubernetes.list`、`cri-o.list` 或任何非 KDM 路徑。
3. 若 KDM 專屬 text path 已存在但缺少 managed marker，apply fail closed。
4. 若 keyring fingerprint 不符，apply fail closed，不直接覆寫。
5. 每個檔案使用 temp + atomic install；plan 顯示 current/desired SHA-256。
6. Remove/rollback 只碰 KDM-owned path，且不是 host bootstrap apply 的隱含步驟。

## 5. Desired host state

### Kernel modules

`/etc/modules-load.d/kdm-kubernetes.conf`：

```text
# Managed by KDM v2
overlay
br_netfilter
```

Apply 後 read-back：

```text
/sys/module/overlay
/sys/module/br_netfilter
```

### Sysctl

`/etc/sysctl.d/99-kdm-kubernetes.conf`：

```text
# Managed by KDM v2
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
```

Apply 僅載入 KDM file，不盲目改寫其他 sysctl 設定。

### Swap

第一版 policy：

```text
require-disabled
```

- Plan 顯示 active swap devices/units count。
- Active swap 時 apply fail closed。
- KDM 不自動註解 `/etc/fstab`，也不停用未知 systemd swap unit。
- 若未來支援 NodeSwap，另立 compatibility 與 kubelet config 決策。

### Security/network defaults

- 保持 AppArmor 啟用。
- 不執行 `ufw disable`、`systemctl disable firewalld` 或全域 firewall flush。
- 不停用 IPv6。
- 不切換 iptables legacy/nft backend。
- CNI 需要的 ports/rules 延後至 CNI/cluster phase，以 plan 顯示。

## 6. Package baseline

### Repository prerequisites

只在缺少時安裝：

```text
ca-certificates
curl
gpg
```

不安裝已淘汰或不必要的 `apt-transport-https`；不執行 distribution upgrade。

### Exact package transaction

```text
cri-o=1.35.5-1.1
kubelet=1.35.6-1.1
kubeadm=1.35.6-1.1
kubectl=1.35.6-1.1
```

Apply 規則：

1. `apt-get update` 只在 KDM repo files就緒後執行。
2. 使用 exact version install，不使用裸 package name抓 latest。
3. 安裝完成後 `apt-mark hold kubelet kubeadm kubectl cri-o`。
4. Read-back `dpkg-query` 與 hold state。
5. 不執行 `apt-get upgrade`、`dist-upgrade`、`autoremove`。
6. 不啟用 CRI-O package附帶的 default bridge CNI；正式 CNI 由 Phase 5 管理。

## 7. Plan/apply CLI boundary

第一版只允許單一 exact node：

```bash
# Default plan；不修改 remote host
bin/kdm host bootstrap -f <inventory> --node cp-1

# Apply；必須同時提供 exact target confirmation
bin/kdm host bootstrap -f <inventory> --node cp-1 \
  --apply --confirm-target cp-1
```

Phase 3 第一版禁止：

```text
--all --apply
--role worker --apply
隱式使用目前 hostname
未確認 target 的 apply
```

### Plan guarantees

Plan 可以執行 read-only SSH probes，但不得：

- 寫入檔案；
- 執行 apt update/install；
- modprobe/sysctl write；
- start/enable service；
- 修改 swap/firewall；
- 使用互動 sudo prompt。

Plan 必須輸出：

```text
target + resolved address
observed OS/arch/kernel/cgroup/swap/disk
current/desired file hashes
repository URLs + key fingerprints
current/desired package versions
hold state
module/sysctl/service differences
ordered actions
blocked reasons
```

Plan exit：

- `0`：plan 產生成功，包括 no-change。
- `3`：輸入/狀態不符 baseline。
- `4`：必要 command、SSH 或 non-interactive sudo capability不足。
- `5`：apply confirmation不足。
- `10`：remote probe/execution failure。

### Apply gates

Apply 前全部成立：

1. Inventory validation PASS。
2. Exact node resolution只有一筆。
3. OS/arch/cgroup/swap/capacity PASS。
4. Repository metadata與 key fingerprint lock一致。
5. Exact package versions仍可用。
6. `--apply` 已提供。
7. `--confirm-target` 完全匹配 node name。
8. Remote credential 支援 `BatchMode=yes` 與 non-interactive sudo。

## 8. Apply transaction and verification

順序固定：

```text
preflight
→ render desired files locally
→ show plan
→ safety gates
→ install modules-load/sysctl files
→ load modules/apply KDM sysctl
→ install keyrings/repository files
→ apt-get update
→ exact-version package install
→ apt-mark hold
→ enable/start CRI-O
→ enable kubelet（kubeadm 前可能保持未健康）
→ read-back verification
```

每一步失敗立即停止，不繼續後續節點。

### Idempotency

第二次 plan/apply 必須：

- KDM files hash相同；
- modules已載入；
- sysctl值相同；
- package versions相同；
- hold state相同；
- CRI-O active；
- 不再執行不必要的 package transaction；
- 結果為 `NO CHANGE`。

### Failure/rollback boundary

- Package transaction前失敗：只回復本次建立/替換的 KDM-owned files。
- Package transaction開始後失敗：不自動 apt remove/downgrade；報告 partial state並產生 recovery plan。
- 不還原或刪除非 KDM repository/config。
- 不把 rollback 與 data destruction 混在同一命令。
- 所有 backup/state只能位於 KDM namespace，例如 `/var/lib/kdm/`；格式在實作前另行定義。

## 9. Credential boundary

Phase 2B 的 `kdm-probe` key被 forced為 `hostname`，**不能用於 bootstrap apply**。

Phase 3 production前提：

- SSH identity由 operator提供；KDM不建立、不複製、不提交 private key。
- Remote user需具 non-interactive sudo能力。
- KDM不修改 production sudoers或 SSH authorization。

Phase 3 lab apply 前需另行明確授權建立 lab-only bootstrap credential。該 credential只能存在 `.kdm/lab/`，不得沿用到 production。

## 10. Capacity gate

目前狀態阻擋 apply integration：

```text
Host free: 約 14 GiB
Guest root free: 約 6.7 GiB
```

Phase 3B apply integration 前建議至少：

```text
Host free >= 20 GiB
Guest root free >= 10 GiB
```

三節點 cluster lab仍要求 host free至少 35–40 GiB。容量不足時只允許 plan/fixture/unit test，不下載 images、不擴 VM。

## 11. Machine-readable compatibility lock

版本、repository與 key資料不得硬編碼在 shell function。Phase 3A新增：

```text
config/compatibility-lock.yaml
```

預定結構：

```yaml
apiVersion: kdm.io/v2alpha1
kind: CompatibilityLock
profiles:
  ubuntu-24.04-arm64-k8s-1.35:
    os:
      id: ubuntu
      version: "24.04"
      architecture: arm64
    kubernetes:
      minor: v1.35
      version: v1.35.6
      packageVersion: 1.35.6-1.1
      repository: https://pkgs.k8s.io/core:/stable:/v1.35/deb/
      keyFingerprint: DE15B14486CD377B9E876E1A234654DA9A296436
    runtime:
      name: crio
      minor: v1.35
      version: v1.35.5
      packageVersion: 1.35.5-1.1
      repository: https://download.opensuse.org/repositories/isv:/cri-o:/stable:/v1.35/deb/
      keyFingerprint: 85B67D5C50100B1AC8CEFE49CBA9C85640A2B579
```

Host bootstrap inventory需引用 profile：

```yaml
spec:
  profile: ubuntu-24.04-arm64-k8s-1.35
```

一般 inventory validation可先允許缺少 profile；`host bootstrap` command必須要求 profile存在且能在 lock中唯一解析。Unknown profile回傳 config error 3。

## 12. Phase 3A file plan

### 新增

```text
config/compatibility-lock.yaml
commands/host.sh
lib/host.sh
providers/os/ubuntu-24.04.sh
providers/runtime/crio.sh
tests/fixtures/host/supported.yaml
tests/fixtures/host/wrong-os.yaml
tests/fixtures/host/wrong-arch.yaml
tests/fixtures/host/active-swap.yaml
tests/fixtures/host/low-disk.yaml
tests/fixtures/host/repo-drift.yaml
tests/unit/host-preflight.sh
tests/unit/host-plan.sh
```

### 修改

```text
bin/kdm
lib/core.sh
lib/config.sh
Makefile
config/inventory.example.yaml
docs/development-roadmap.md
```

### Phase 3A 明確不新增

```text
apply executor
apt install command
sudo writer
service mutation
swap/fstab editor
firewall mutation
kubeadm init/join
```

## 13. Implementation phases

### Phase 3A：Planner/preflight

- [x] OS/arch/cgroup/swap/disk HostFacts model。
- [x] Desired files renderer與 canonical LF SHA-256。
- [x] Repository/version/key compatibility lock。
- [x] Human-readable deterministic plan與 full NO_CHANGE fixture。
- [x] Unit fixtures：supported、wrong OS/arch/cgroup、active swap、low disk、repo drift。
- [x] `--apply` fail closed；沒有 apply executor。

Phase 3A的普通CLI仍只讀local YAML；remote transport保持在明確gated integration之外。

### Phase 3A.5：Real SSH HostFacts collector

- [x] 獨立ignored Ed25519 lab identity，不覆寫Phase 2B hostname identity。
- [x] Root-owned fixed collector `/usr/local/libexec/kdm-host-facts`。
- [x] 非sudo `kdm-probe` forced-command key；拒絕任意SSH command。
- [x] Strict `KDM_HOST_FACTS_V1` protocol：unknown、duplicate、missing、invalid type全部fail closed。
- [x] Local parser轉換成既有HostFacts schema並再次allowlist validation。
- [x] Strict unknown → accept-new → strict host-key sequence通過。
- [x] `make integration-host-facts`真實收集Ubuntu 24.04 ARM64 facts。
- [x] 收集後preflight因guest `rootFreeMiB=6752`如預期fail closed。
- [x] 原`make integration-ssh`仍通過。

Phase 3A.5不包含sudo probe、package mutation、apply executor或公開任意remote exec。

Lab provision與驗證：

```bash
identity='.kdm/lab/host_facts_id_ed25519'
[ -f "$identity" ] || ssh-keygen -q -t ed25519 -N '' -C 'kdm-host-facts-lab' -f "$identity"

KDM_LAB_VM='kdm-lab-cp1' \
KDM_LAB_HOST_FACTS_PUBLIC_KEY="${identity}.pub" \
KDM_LAB_PROVISION_CONFIRM='kdm-lab-cp1' \
make provision-host-facts

KDM_LAB_INVENTORY='.kdm/lab/inventory.yaml' \
KDM_LAB_IDENTITY="$identity" \
make integration-host-facts
```

### Phase 3B：Single-node apply

前提：容量與 lab bootstrap credential另外確認。

- KDM-owned atomic files。
- Exact package transaction。
- Hold/service/read-back。
- Second apply no-change。

### Phase 3C：Multi-node

前提：host可用空間 35–40 GiB，建立三節點 lab。

- Per-node plan aggregation。
- Bounded fan-out。
- Partial failure/retry。
- 不包含 kubeadm init/join；cluster lifecycle屬 Phase 4。

## 14. Official sources checked

- Kubernetes kubeadm installation guide: `https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/`
- Kubernetes package repository: `https://pkgs.k8s.io/core:/stable:/v1.35/deb/`
- Kubernetes stable endpoint: `https://dl.k8s.io/release/stable-1.35.txt`
- CRI-O packaging guide: `https://github.com/cri-o/packaging`
- CRI-O compatibility matrix: `https://github.com/cri-o/cri-o#compatibility-matrix-cri-o--kubernetes`
- CRI-O package repository: `https://download.opensuse.org/repositories/isv:/cri-o:/stable:/v1.35/deb/`

## 15. Design completion checklist

- [x] Ubuntu 24.04.4 ARM64 candidate確認。
- [x] Kubernetes/CRI-O minor對齊規則確認。
- [x] Exact Debian package versions確認。
- [x] Official repository URLs與 architectures確認。
- [x] Signing key fingerprint/SHA observation記錄。
- [x] KDM-owned file namespace確認。
- [x] Swap/AppArmor/firewall/IPv6 policy確認。
- [x] Plan/apply/confirmation/idempotency/rollback邊界確認。
- [x] Machine-readable compatibility lock與 inventory profile reference確認。
- [x] Phase 3A exact file plan與 non-goals確認。
- [x] Credential與capacity blocker明確記錄。
- [x] Phase 3A planner/preflight code與 plan-only CLI完成。
- [x] Phase 3A.5 real SSH read-only HostFacts collector與gated integration完成。
- [ ] Phase 3B lab apply：尚未授權且容量不足。

## 16. Phase 3A implementation result

CLI：

```bash
bin/kdm host bootstrap \
  -f config/inventory.example.yaml \
  --node cp-1 \
  --facts-file tests/fixtures/host/supported.yaml
```

安全邊界：

- HostFacts只從local YAML讀取。
- 不呼叫 SSH、sudo、apt、kubectl或systemd。
- `--apply`固定回傳 safety exit 5。
- `--all`、`--role`與多個 `--node`不允許。
- Lock缺欄位、minor不一致、HTTP URL、fingerprint/SHA格式錯誤時 fail closed。
- Lock同時驗證 profile/minor/version/packageVersion/repository/key URL語意一致性。
- Unsupported OS/arch/cgroup、active swap、容量不足、foreign KDM path時回傳 config exit 3。
- HostFacts採 map-key allowlist；未知或credential-like欄位一律拒絕。
- Repository prerequisites `ca-certificates`、`curl`、`gpg`納入presence plan。
- CRI-O service分別比較 enabled與active，避免錯誤NO_CHANGE。

驗證：

```text
host preflight fixtures: PASS
deterministic plan: PASS
full NO_CHANGE plan: PASS
CLI apply fail closed: PASS
no-side-effect sentinels: PASS
strict HostFacts protocol parser: PASS
real SSH HostFacts collector: PASS
capacity fail-closed gate: PASS (6752 MiB < 10240 MiB)
Phase 2B hostname integration regression: PASS
```
