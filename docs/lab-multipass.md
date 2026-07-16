# KDM Disposable Multipass Lab

> 日期：2026-07-16
> 狀態：單節點基線已建立
> 用途：KDM v2 的 inventory、SSH、host bootstrap 與後續 kubeadm integration 驗證

## 結論

目前 lab 只有一台 Ubuntu 24.04 ARM64 VM，足以驗證 Phase 2 inventory/SSH 與 Phase 3 單節點 host bootstrap；**不代表三節點 HA 或 Kubernetes 相容性已驗證**。

Host 磁碟只剩約 15 GiB，因此禁止擴充第二、第三台 VM，直到可用空間達到至少 35–40 GiB。

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
- [x] Host disk：建立後約 15 GiB available。
- [ ] 一般使用者 SSH key 登入：Phase 2 後續驗證。
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

IP 由 Multipass 網路動態配置；測試與 inventory fixture 不得假設永遠是 `192.168.252.2`。

## Disposable reset policy

刪除 VM 是 destructive operation，必須先確認 target：

```bash
multipass info kdm-lab-cp1
multipass delete kdm-lab-cp1
multipass purge
```

`delete` 與 `purge` 不得由一般 test 自動執行。未來 integration harness 應使用 run-specific 名稱並在明確 cleanup 階段處理。

## 容量限制

目前 host 只有約 15 GiB 可用：

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
- Phase 2A mock SSH 不連線此 VM。
- 真實 SSH 測試必須有獨立 inventory 與明確 target。
