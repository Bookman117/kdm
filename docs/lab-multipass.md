# KDM Disposable Multipass Lab

> 日期：2026-07-16
> 狀態：單節點基線已建立
> 用途：KDM v2 的 inventory、SSH、host bootstrap 與後續 kubeadm integration 驗證

## 結論

目前 lab 只有一台 Ubuntu 24.04 ARM64 VM，足以驗證 Phase 2 inventory/SSH 與 Phase 3 單節點 host bootstrap；**不代表三節點 HA 或 Kubernetes 相容性已驗證**。

Host 磁碟只剩約 14 GiB，因此禁止擴充第二、第三台 VM，直到可用空間達到至少 35–40 GiB。

## 已建立資源

| 項目 | 值 |
|---|---|
| Hypervisor frontend | Multipass 1.16.3 |
| Driver | QEMU |
| Instance | `kdm-lab-cp1` |
| Image | Ubuntu 24.04 LTS |
| Guest release | Ubuntu 24.04.4 LTS |
| Architecture | aarch64 |
| CPU | 2 |
| RAM | 4 GiB 配置／3.8 GiB guest 可見 |
| Disk | 10 GiB 配置／9.6 GiB Multipass 可見 |
| IPv4 | `192.168.252.2/24`（動態，不可寫死到 inventory） |
| Hostname | `kdm-lab-cp1` |

## 實際驗證結果

- [x] Multipass daemon 可用。
- [x] cloud-init：`done`。
- [x] systemd：`running`。
- [x] SSH service：`active`。
- [x] Host 到 guest TCP/22：PASS。
- [x] Guest DNS：可解析 `archive.ubuntu.com`。
- [x] Guest HTTPS：可連線 Ubuntu archive。
- [x] Guest root disk：2.0 GiB used／6.8 GiB available。
- [x] Guest memory：啟動後約 311 MiB used。
- [x] Host disk：Phase 2B 驗收時約 14 GiB available。
- [x] `kdm-probe` 專用 SSH key 登入；密碼鎖定、無 sudo、forced `/usr/bin/hostname`、`restrict`。
- [x] Strict unknown host fail → accept-new → strict match。
- [x] Reachable/unreachable aggregate exit status 10。
- [ ] kubeadm／CRI-O：尚未安裝。
- [ ] 多節點網路與 HA：尚未驗證。

## 日常操作

### 查詢

```bash
multipass list
multipass info kdm-lab-cp1
```

### 進入 VM

```bash
multipass shell kdm-lab-cp1
```

### 非互動命令

```bash
multipass exec kdm-lab-cp1 -- hostname
multipass exec kdm-lab-cp1 -- systemctl is-system-running
```

### 停止與啟動

```bash
multipass stop kdm-lab-cp1
multipass start kdm-lab-cp1
```

### 取得當下 IP

```bash
multipass info kdm-lab-cp1 --format json \
  | yq -p=json '.info."kdm-lab-cp1".ipv4[0]'
```

IP 由 Multipass 網路動態配置；committed fixture 不得假設永遠是 `192.168.252.2`。Phase 2B 使用已忽略的 `.kdm/lab/inventory.yaml` 保存當次動態值。

### Phase 2B real SSH probe

Lab identity 與 local inventory 位於 Git 忽略的 `.kdm/lab/`。Integration test 使用暫存 known_hosts，不修改 `~/.ssh/known_hosts`：

```bash
KDM_LAB_INVENTORY="$PWD/.kdm/lab/inventory.yaml" \
KDM_LAB_IDENTITY="$PWD/.kdm/lab/id_ed25519" \
KDM_LAB_EXPECTED_HOSTNAME='kdm-lab-cp1' \
make integration-ssh
```

一般 `make test` 只執行 offline unit/smoke tests，不連線 VM。

## Disposable reset policy

刪除 VM 是 destructive operation，必須先確認 target：

```bash
multipass info kdm-lab-cp1
multipass delete kdm-lab-cp1
multipass purge
```

`delete` 與 `purge` 不得由一般 test 自動執行。未來 integration harness 應使用 run-specific 名稱並在明確 cleanup 階段處理。

## 容量限制

目前 host 只有約 14 GiB 可用：

- 不建立第二台 VM。
- 不執行大型 image preload。
- 不安裝 Kubernetes／CRI-O 前先重新檢查 host 與 guest disk。
- Host 可用空間若低於 10 GiB，停止 lab 擴充與 image pull。
- 三節點 lab 前，先釋放至少 35–40 GiB。

## Phase 對應

| Phase | 此 lab 的用途 |
|---|---|
| Phase 2A | 不使用真實 VM；只做 fixtures 與 mock SSH |
| Phase 2B | 驗證一般 SSH user、host key、timeout、per-node result |
| Phase 3 | 驗證 Ubuntu 24.04 host bootstrap 與 idempotency |
| Phase 4 | 空間足夠並擴成三節點後才驗證 kubeadm lifecycle |

## 安全邊界

- 不放 private key、password、token 或 kubeconfig 到 repository。
- 不修改 production SSH config。
- 不將 Multipass 內部管理 key 複製到 KDM。
- Lab private key、local inventory 與 persistent known_hosts 全部位於 Git 忽略的 `.kdm/`。
- Phase 2A mock SSH 不連線此 VM。
- Phase 2B 真實 SSH 只執行 forced `hostname`，並由明確 `make integration-ssh` 觸發。
