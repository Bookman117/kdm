# KDM v2 技術架構

> 版本：0.1
> 日期：2026-07-16
> 狀態：Phase 3A.5 real SSH read-only HostFacts
> 目的：定義 KDM v2 的責任邊界、安全模型與可漸進移植架構；既有 `kdm` 與 `kdm_function` 視為 legacy v1。

---

## 0. 先說結論

KDM v2 可以先理解成：

> **以 Bash 實作、預設唯讀／plan-first、透過受控 SSH 編排 kubeadm 多節點叢集生命週期的工具。**

它不再是把主機設定、套件管理、Kubernetes、應用部署與資料清除混在同一個入口的萬用腳本。核心只負責：

1. 讀取與驗證 inventory/config。
2. 對節點執行可追蹤、可重試、可預覽的主機準備作業。
3. 管理 kubeadm 叢集 init/join/status/upgrade/reset。
4. 透過版本固定的 provider/addon 安裝基礎元件。
5. 對 destructive 操作提供獨立且更嚴格的安全閘門。

## 1. 現況與問題邊界

目前 v1 由兩個大型腳本構成：

| 元件 | 規模 | 現況 |
|---|---:|---|
| `kdm` | 2,389 行、約 95 個命令 | CLI、系統修改、叢集部署與應用部署混合 |
| `kdm_function` | 1,674 行、70 個函式 | 設定、OS 偵測、SSH、套件與清除邏輯混合 |
| `yaml/` | 5 個檔案 | 含過時 API、placeholder 與固定映像 |

v2 不直接覆寫 v1。新入口放在 `bin/kdm`，讓兩者可並存、比較與逐步移植。

## 2. 系統脈絡

```text
使用者 / CI
    │
    ▼
bin/kdm ── CLI dispatch；help/version/doctor 必須零副作用
    │
    ├── lib/config.sh       inventory 與設定
    ├── lib/validation.sh   輸入、環境與相依性驗證
    ├── lib/safety.sh       plan/apply 與 destructive gate
    ├── lib/ssh.sh          遠端執行介面
    ├── lib/host.sh         HostFacts preflight與deterministic plan
    ├── lib/host-facts.sh   Strict remote facts protocol parser
    ├── scripts/guest/      Root-owned fixed read-only collector
    ├── scripts/lab/        Explicit disposable-lab provisioner
    └── lib/log.sh          可讀輸出與錯誤碼
    │
    ▼
commands/                   host / cluster / node / addon 工作流
    │
    ▼
providers/                  OS / runtime / CNI 差異實作
    │
    ▼
節點與 Kubernetes API
```

Phase 3A/3A.5已加入HostFacts preflight、plan-only bootstrap與gated real SSH fixed collector；尚未加入apply executor或Kubernetes API操作。

## 3. KDM v2 不是什麼

| 誤解 | 更準確的說法 |
|---|---|
| KDM 是 application catalog | v2 核心只管理叢集與必要 addon；Jenkins、Grafana 等移至 legacy/examples |
| 執行命令就直接套用 | 變更命令預設輸出 plan；明確 `--apply` 才能執行 |
| `/etc/hosts` 就是 inventory | 可作 fallback discovery，但正式輸入是具 schema 的 inventory |
| 一次支援所有 Linux | 每個 OS/version 必須通過 compatibility matrix 與整合測試後才宣告支援 |
| reset 與 disk wipe 是同一層操作 | disk wipe 是獨立高風險工作流，不得被一般 reset 隱式觸發 |

## 4. 目標目錄

```text
kdm/
├── bin/kdm
├── lib/
│   ├── core.sh
│   ├── log.sh
│   ├── config.sh
│   ├── validation.sh
│   ├── ssh.sh
│   └── safety.sh
├── commands/
├── providers/
│   ├── os/
│   ├── runtime/
│   └── cni/
├── addons/
├── config/
├── legacy/
├── tests/
│   ├── unit/
│   ├── smoke/
│   └── fixtures/
├── docs/
└── Makefile
```

目前不搬動 legacy 檔案；待命令 migration 表逐項驗證後再移植。

## 5. 執行資料流

### 5.1 唯讀命令

```text
參數 → parse → validate → read local state → render result → exit
```

`help`、`version`、`doctor` 的約束：

- 不使用 sudo。
- 不執行 apt/dnf。
- 不連線 SSH。
- 不讀 kubeconfig。
- 不呼叫 kubectl。
- 缺少 optional tool 時仍可執行並明確回報。

### 5.2 變更命令

```text
參數 → config validation → target resolution → plan render
                                            │
                          無 --apply ────────┴─→ exit 0
                          有 --apply → safety gate → execute → verify
```

### 5.3 Destructive 命令

```text
target + resource → plan → exact confirmation → execute → read-back verification
```

不得接受「除 N 外都繼續」；必須匹配目標名稱，磁碟操作還要匹配 device path。

## 6. 安全模型

| 等級 | 範例 | 預設 | 套用條件 |
|---|---|---|---|
| Read-only | help、version、doctor、status | 直接執行 | 不需確認 |
| Mutating | bootstrap、init、join、addon install | plan | `--apply` |
| Destructive | reset、remove | plan | `--apply` + exact target |
| Data destructive | Rook disk wipe | 禁止 | 獨立命令 + target + disk 雙重確認 |

硬性規則：

1. 不複製 private key 或管理者 kubeconfig。
2. 不刪除 KDM 未建立的 repository/config。
3. 不從 upstream `main` 直接 `kubectl apply`。
4. 下載 artifact 需固定版本；正式 apply 前驗證 checksum/schema。
5. 任何失敗都需非零 exit code，不以成功訊息掩蓋錯誤。
6. log 不輸出 token、password、private key、kubeconfig 內容。

## 7. 設定模型

預定 inventory 最小欄位：

```yaml
cluster:
  name: lab
  kubernetesVersion: vX.Y.Z
  endpoint: 192.0.2.10
  podCIDR: 172.16.0.0/17
  serviceCIDR: 172.16.128.0/17

runtime:
  name: crio
  version: vX.Y

ssh:
  user: operator
  port: 22

nodes:
  - name: cp-1
    address: 192.0.2.11
    role: control-plane
```

版本值在 compatibility 決策完成前只是 schema 範例，不代表本輪修改 v1 的版本字串。

設定優先序預定為：

```text
CLI flag > inventory > environment allowlist > defaults
```

秘密不放在 inventory；未來如需 credential provider，另立介面。

## 8. 錯誤碼與輸出

| Exit code | 意義 |
|---:|---|
| 0 | 成功，或 plan 已成功產生但未 apply |
| 2 | CLI 使用錯誤 |
| 3 | 設定／輸入驗證失敗 |
| 4 | prerequisite 不滿足 |
| 5 | safety gate 未通過 |
| 10 | 執行失敗 |

Phase 1 先實作 0、2、3、4、5；遠端執行錯誤碼於後續 Phase 完成。

## 9. 關鍵設計決策

| 決策 | 預設 | 理由 |
|---|---|---|
| 語言 | Bash | 保留原專案定位與維運者可讀性 |
| v1/v2 | 並存 | 避免尚未驗證的重構覆蓋可追溯 legacy |
| 套用模式 | plan-first | 降低多節點與 destructive 操作風險 |
| Inventory | 結構化檔案 | 不再依 hostname suffix 與 `/etc/hosts` 猜測角色 |
| Addon | 版本固定、可 render/validate | 避免 upstream drift |
| 測試 | unit + no-side-effect smoke + VM integration | 本機先驗證控制流程，再驗證真正多節點行為 |

## 10. 風險

| 風險 | 影響 | 緩解方式 |
|---|---|---|
| v1 行為沒有完整規格 | 移植時可能遺漏隱含功能 | command migration 表逐項建立驗收案例 |
| `set -u` 與 legacy 不相容 | 直接導入會造成大量未定義變數錯誤 | strict mode 只用於 v2 新檔案 |
| 多 OS 矩陣過早擴張 | 難以驗證 | 先選一個 OS baseline，其他標記 experimental |
| 真實叢集測試成本高 | 單元測試無法覆蓋 kubeadm 行為 | disposable VM integration gate |
| Addon 版本與 K8s 相容性漂移 | 部署失敗 | compatibility 文件與 release pin 同步更新 |

## 11. 待釐清

- [x] 第一個 candidate OS：Ubuntu 24.04 ARM64；正式支援仍需完成 bootstrap/kubeadm integration。
- [x] 第一個 integration lab：Multipass；目前先建立單節點，磁碟足夠後擴成三節點。
- [x] Inventory 使用 YAML 與 Mike Farah `yq` v4；版本不符時 fail closed。
- [x] Phase 3 candidate：Ubuntu 24.04.4 ARM64 + Kubernetes 1.35.6 + CRI-O 1.35.5；仍待 bootstrap/kubeadm integration。
- [ ] HA endpoint 預設使用 kube-vip，或允許外部 load balancer？
- [ ] CNI 首個正式支援項目選 Calico 或 Flannel？
- [ ] Rook/Ceph 是否納入 v2 核心，或作獨立擴充套件？

## 12. 文件維護規則

1. 架構調整需同步更新本文件與 command migration 表。
2. 版本支援宣告只來自 compatibility 文件與實際測試結果。
3. 未驗證行為標記為「候選」或「待釐清」，不可寫成已支援。
4. destructive 操作的安全規則不可由 addon 覆寫。
5. 每個 Phase 完成時更新 roadmap 的實際驗證命令與結果。
