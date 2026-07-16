# KDM v2 相容性策略

> 日期：2026-07-16
> 狀態：設計基線；不是正式支援宣告

## 結論

本輪不修改 legacy v1 的 Kubernetes／CRI-O／addon 版本字串。v2 先建立版本選擇與驗證規則，再決定第一個正式支援組合。

2026-07-16 由官方 Kubernetes stable endpoint 唯讀確認：

| Minor | 最新 patch |
|---|---|
| 1.34 | v1.34.9 |
| 1.35 | v1.35.6 |
| 1.36 | v1.36.2 |

`v1.36.2` 是當下觀察值，不等於 KDM 已支援。正式採用前仍需完成 kubeadm、CRI-O、CNI、kube-vip 與 addon 整合測試。

## Legacy v1 基線

| 項目 | v1 目前值 | 本輪處理 |
|---|---|---|
| Kubernetes | 1.28.1 | 保持不動 |
| CRI-O | 1.28.1 | 保持不動 |
| Rook | v1.12.8 | 保持不動 |
| Calico | v3.26.3 | 保持不動 |
| Flannel | v0.23.0 變數／v0.18.1 manifest | 記錄差異，不修改 |
| ingress-nginx | controller 1.9.4／chart 4.8.3 | 保持不動 |
| metrics-server chart | 3.11.0 | 保持不動 |
| kube-prometheus-stack | 52.1.0 | 保持不動 |

## 支援等級

| 等級 | 定義 |
|---|---|
| Supported | 具固定版本組合、文件、重複成功的 integration test |
| Candidate | 已完成官方相容性查核與 render validation，尚未完成多節點測試 |
| Experimental | 有 provider 實作，但只做局部驗證 |
| Legacy | 保留原行為，不宣告符合現代版本 |
| Unsupported | 已知不相容或未納入範圍 |

## OS 矩陣

| OS | v1 宣稱 | v2 目前 | 升級條件 |
|---|---|---|---|
| Ubuntu 20.04 | 支援 | Legacy | 不建議作新 baseline；需另行決定維護期 |
| Ubuntu 22.04 | 支援 | Deferred | 第一版不投入 integration 資源；未宣告 unsupported |
| Ubuntu 24.04 ARM64 | 未列 | Candidate selected | 完成 host bootstrap、kubeadm 與多節點測試後再升級 Supported |
| Rocky Linux 8 | 調整中 | Experimental | 修正 OS detection 與 repository provider |
| Rocky Linux 9 | 調整中 | Experimental | 獨立 provider 與 SELinux 測試 |
| RHEL 8/9 | 調整中 | Unsupported until tested | subscription/repository/sudoers 流程需獨立驗證 |
| macOS | 控制端開發 | Dev-only | 只保證 help/version/doctor/lint/smoke |

## Kubernetes 與 runtime 規則

1. Kubernetes 與 CRI-O 預設使用相同 minor。
2. patch version 必須明確固定；不可在 apply 時靜默改用 latest。
3. repository 必須使用現代官方來源，不解析舊 OpenSUSE HTML listing。
4. kubeadm upgrade 只允許官方支援的逐 minor 路徑。
5. client/server version skew 必須在 plan 階段檢查。
6. 每個版本組合都需記錄：OS image、kernel、CRI-O、kubeadm、CNI、addon、測試日期。

## CNI 與 addon 驗證

每個元件進入 Candidate 前需通過：

- [ ] 固定 release/chart version。
- [ ] 下載來源可驗證。
- [ ] `helm template` 或 manifest render 成功。
- [ ] kubeconform/schema validation 成功。
- [ ] 不含已移除 Kubernetes API。
- [ ] install/remove 使用同一 release source。
- [ ] disposable cluster 安裝與卸載成功。
- [ ] 版本值記錄在 lock/compatibility 資料，而非散落 shell 程式。

## 已知不相容項目

| 項目 | 問題 | v2 決策 |
|---|---|---|
| `policy/v1beta1` PodSecurityPolicy | Kubernetes 1.25 起移除 | 不移植；改用現代 upstream CNI 與 Pod Security Admission |
| `apt-key` | 已淘汰 | 使用 keyring + `signed-by` |
| 舊 `packages.cloud.google.com` Kubernetes repo | 非現代安裝路徑 | 改用 `pkgs.k8s.io` provider |
| upstream `main` 直接 apply | 無法重現 | 固定 tag/commit/checksum |
| `k8s.gcr.io` 舊映像路徑 | 已遷移且 manifest 過時 | 由新版 chart/upstream manifest 提供 |

## 第一個 Candidate 組合：已決策

Phase 3 設計 baseline；不代表已宣告 Supported：

```text
Control OS: macOS（只跑 CLI）
Node OS: Ubuntu 24.04.4 LTS ARM64
Kernel observed: 6.8.0-134-generic
Kubernetes: v1.35.6 / package 1.35.6-1.1
Runtime: CRI-O v1.35.5 / package 1.35.5-1.1
Bootstrap: kubeadm
HA endpoint: kube-vip 或外部 LB（二選一）
CNI: Calico 或 Flannel（二選一）
```

Kubernetes 1.35 選為目前 N-1 minor；CRI-O 與 Kubernetes保持同 minor，patch cadence可不同。Repository固定為：

```text
https://pkgs.k8s.io/core:/stable:/v1.35/deb/
https://download.opensuse.org/repositories/isv:/cri-o:/stable:/v1.35/deb/
```

完整 repository key、KDM-owned files與 plan/apply邊界見：

[`plans/2026-07-16-phase-3-host-bootstrap.md`](plans/2026-07-16-phase-3-host-bootstrap.md)

正式 Supported仍需完成 host bootstrap idempotency、kubeadm、CNI與多節點 integration。
