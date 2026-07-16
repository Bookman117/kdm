# KDM v2 Development Roadmap

> **For Hermes:** Implement tasks sequentially; do not commit/push unless explicitly requested.

**Goal:** 將 KDM 從不可測試的多功能 legacy 腳本，漸進轉為 plan-first、可驗證的 kubeadm 多節點生命週期工具。

**Architecture:** v1 保持不動，v2 使用 `bin/kdm` 與小型 `lib/*.sh`。先完成零副作用 CLI 與安全閘門，再移植 inventory、SSH、bootstrap、cluster 與 addon。

**Tech Stack:** Bash、Make、shellcheck（可選但建議）、shfmt（可選）、YAML parser、kubeconform、disposable Linux VMs。

---

## Phase 0：規格與邊界

### 交付物

- [x] `docs/architecture.md`
- [x] `docs/command-migration.md`
- [x] `docs/compatibility.md`
- [x] `docs/development-roadmap.md`

### 驗收

- 95 個 legacy 命令皆有去向。
- v2 核心與 application workload 邊界明確。
- 現代版本是候選，不修改 legacy version string。
- destructive command 有統一安全政策。

## Phase 1：CLI 與安全基線

### 實作狀態（2026-07-16）

- [x] 建立獨立 `bin/kdm`，以 `BASH_SOURCE` 解析 repo root。
- [x] 建立 `core/log/config/validation/ssh/safety` 函式庫邊界。
- [x] `help`、`version`、`doctor` 不載入 legacy，也不執行 sudo/SSH/kubectl/package manager。
- [x] 未知命令回傳 exit code 2。
- [x] plan/apply、exact-target 與 data-destruction-disabled 安全閘門已有 unit test。
- [x] 建立 `make doctor`、`make lint`、`make smoke`、`make test`。
- [x] `make test` 實際通過。
- [x] ShellCheck 0.11.0 已安裝並納入 `make lint`，以 `-x -P SCRIPTDIR` 從實際 entrypoints 追蹤函式庫。
- [ ] shfmt、kubeconform 尚未安裝；目前格式與 Kubernetes schema 尚未形成完整 gate。
- [ ] Inventory、SSH 執行與任何 mutating workflow 刻意保持未實作。

### Task 1：建立獨立入口

**Files:**

- Create: `bin/kdm`
- Create: `lib/core.sh`
- Test: `tests/smoke/cli.sh`

**Steps:**

1. 先寫 smoke test，要求 `help`、`--help`、`version` 能在清空 PATH 外部依賴情境下執行。
2. 驗證 legacy 入口不被 v2 source。
3. 實作以 `BASH_SOURCE` 推導 root 的入口。
4. 執行 smoke test。

### Task 2：建立 logging 與 exit code

**Files:**

- Create: `lib/log.sh`
- Modify: `lib/core.sh`
- Test: `tests/unit/log.sh`

**Acceptance:** 未知命令回傳 2；log 只寫 stderr；無秘密輸出。

### Task 3：建立 prerequisite doctor

**Files:**

- Create: `lib/validation.sh`
- Modify: `bin/kdm`
- Test: `tests/smoke/doctor.sh`

**Acceptance:** doctor 只執行 `command -v` 類唯讀檢查；缺少 optional tool 時輸出 MISSING 並回傳 0，缺少 Bash baseline 時回傳 4。

### Task 4：建立 plan/apply safety gate

**Files:**

- Create: `lib/safety.sh`
- Test: `tests/unit/safety.sh`

**Acceptance:** 預設 plan；`--apply` 才允許 mutating；destructive 還需 exact target；資料清除介面預設拒絕。

### Task 5：建立 config 與 SSH 介面邊界

**Files:**

- Create: `lib/config.sh`
- Create: `lib/ssh.sh`

**Acceptance:** Phase 1 僅定義安全預設與未實作錯誤；不得實際 SSH、讀 kubeconfig 或變更主機。

### Task 6：建立 repo quality gates

**Files:**

- Create: `Makefile`
- Create: `tests/smoke/no-side-effects.sh`

**Commands:**

```bash
make doctor
make lint
make smoke
make test
```

**Acceptance:** 不需 sudo、SSH server 或 Kubernetes cluster；所有測試通過。

## Phase 1.5：Repository 品質閘門

### 實作狀態（2026-07-16）

- [x] 新增 `tests/unit/log.sh`，驗證 INFO/WARN/ERROR 只寫 stderr 且 prefix 穩定。
- [x] 將 logging test 納入 `make lint` 與 `make test`。
- [x] 新增 `.github/workflows/ci.yml`。
- [x] GitHub Actions 使用最小 `contents: read` 權限。
- [x] `actions/checkout` 固定至 v4 tag 當前 commit SHA，不使用可漂移 branch。
- [x] CI 僅執行 ShellCheck 與本機 unit/smoke tests，不連線節點或叢集。
- [x] GitHub Actions `Bash quality gates` 已在 run `29467957372` 實際通過。

### 驗收命令

```bash
make test
yq eval '.' .github/workflows/ci.yml >/dev/null
git diff --check
```

## Phase 2：Inventory 與 SSH orchestration

詳細計畫：[`plans/2026-07-16-phase-2-inventory-ssh.md`](plans/2026-07-16-phase-2-inventory-ssh.md)

Lab 基線：[`lab-multipass.md`](lab-multipass.md)

### Phase 2A：Inventory 與 mock SSH

- [x] 定義 inventory schema 與 example。
- [x] 先寫 validation fixtures 與失敗案例。
- [x] 實作 node/role/target resolution。
- [x] 統一 mock SSH option、timeout、host-key policy。
- [x] 實作 mock per-node result 與 aggregate exit status。
- [x] Inventory 拒絕 credential/kubeconfig 欄位，且未提供檔案傳送能力。

### Phase 2B：Disposable VM 真實 SSH

- [x] 建立 `kdm-probe` 一般使用者與 lab 專用 key；不使用 Multipass internal key，且不授予 sudo。
- [x] 以 forced `hostname` probe 驗證 BatchMode、StdinNull、strict unknown fail、accept-new 與後續 strict match。
- [x] 驗證 reachable/unreachable per-node result 與 aggregate exit status 10。
- [x] 真實 SSH 只由明確 `make integration-ssh` 執行；未公開 `node exec` CLI。

驗收：fixture 測試覆蓋重複 node、未知 role、無效 IP/hostname、空 target；mock SSH 可重現部分節點失敗與 timeout；disposable VM 真實 SSH read-only probe、host-key policy 與 failure aggregation 通過。

## Phase 3：Host bootstrap

- [ ] 選定一個正式 baseline OS。
- [ ] 實作 OS/version detection。
- [ ] 建立 KDM 專屬 modules-load/sysctl/repository 檔案。
- [ ] 現代化 Kubernetes/CRI-O repository。
- [ ] 實作 package plan/apply 與 idempotency check。
- [ ] 在 disposable VM 驗證重複 apply。

驗收：第二次 apply 無非預期變更；不刪除非 KDM repository；help/doctor 仍零副作用。

## Phase 4：Cluster lifecycle

- [ ] Render kubeadm config。
- [ ] Validate config。
- [ ] First control-plane init。
- [ ] HA endpoint。
- [ ] Control-plane/worker join。
- [ ] Status/read-back verification。
- [ ] 逐 minor upgrade plan。
- [ ] Node/cluster reset，但不含 disk wipe。

驗收：至少三節點 disposable cluster 可建立、重啟後健康、加入/移除 worker，並能安全 reset。

## Phase 5：Addon lifecycle

順序：CNI → kube-vip/LB → MetalLB → ingress-nginx → metrics-server → local-path → monitoring → Rook/Ceph。

每個 addon 必須有固定版本、render、schema validation、install/remove 對稱與 integration test。

## Phase 6：Release 與 migration

- [ ] v1/v2 command comparison。
- [ ] migration guide。
- [ ] install artifact checksum。
- [ ] release archive 與 rollback。
- [ ] CI matrix。
- [ ] 移除或封存已完成替代的 legacy command。

## 不在目前範圍

- 自動操作 production cluster。
- 自動 git commit/push/release。
- Jenkins、Grafana、Quay、MariaDB 等 application workload。
- 在未選定磁碟前恢復 Rook wipe。
- 單純把 legacy 1.28 字串改成當前 latest。
