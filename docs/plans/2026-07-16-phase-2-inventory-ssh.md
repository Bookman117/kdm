# KDM Phase 2 Inventory 與 Mock SSH Implementation Plan

> **For Hermes:** 依序執行；每個程式任務都先建立失敗測試，再寫最小實作。不得 commit/push，除非使用者明確要求。

**Goal:** 建立可驗證的 YAML inventory、node/role/target resolution 與可注入 mock 的 SSH orchestration；Phase 2A 不連線真實節點。

**Architecture:** 使用 Mike Farah `yq` v4 將 inventory 正規化成 tab-separated records，Bash 只處理經驗證欄位。SSH command 以 Bash array 組裝、禁止 `eval`；unit tests 透過 PATH 中的 fake `ssh` 驗證每節點與 aggregate result。真實 VM SSH 延後至 Phase 2B。

**Tech Stack:** Bash 3.2+、Mike Farah yq v4、Make、ShellCheck、actionlint、Multipass Ubuntu 24.04（Phase 2B 才使用）。

---

## 1. Scope

### Phase 2A 包含

- Inventory schema 與 example。
- 有效／無效 fixtures。
- `kdm config validate -f <path>`。
- Inventory 正規化 records。
- 依 node name、role、`all` 選 target。
- SSH option/argv builder。
- Fake SSH per-node execution 與 aggregate exit code。
- 禁止 credential／kubeconfig 欄位與檔案傳送能力。

### Phase 2A 不包含

- 不連線 `kdm-lab-cp1`。
- 不使用 Multipass internal key。
- 不安裝套件、CRI-O、kubeadm 或 CNI。
- 不提供任意遠端 shell passthrough CLI。
- 不提供 scp、rsync、private key 或 kubeconfig sync。
- 不修改 legacy `kdm`／`kdm_function`。

## 2. Inventory contract

### 最小格式

```yaml
apiVersion: kdm.io/v2alpha1
kind: Inventory
metadata:
  name: lab
spec:
  ssh:
    user: ubuntu
    port: 22
    connectTimeoutSeconds: 5
    hostKeyPolicy: accept-new
  nodes:
    - name: cp-1
      address: 192.0.2.11
      role: control-plane
    - name: wk-1
      address: 192.0.2.21
      role: worker
```

### 必填與限制

| 欄位 | 規則 |
|---|---|
| `apiVersion` | 必須等於 `kdm.io/v2alpha1` |
| `kind` | 必須等於 `Inventory` |
| `metadata.name` | DNS-label-like：小寫英數與 `-`，不可空白 |
| `spec.ssh.user` | `[A-Za-z_][A-Za-z0-9_-]*` |
| `spec.ssh.port` | 1–65535，預設 22 |
| `connectTimeoutSeconds` | 1–60，預設 5 |
| `hostKeyPolicy` | `yes` 或 `accept-new`；不允許 `no` |
| `spec.nodes` | 至少一筆 |
| `nodes[].name` | 唯一、DNS-label-like |
| `nodes[].address` | 唯一；IPv4/IPv6/hostname，不接受 shell metacharacter |
| `nodes[].role` | `control-plane` 或 `worker` |

### 禁止欄位

Inventory 任意層級若出現以下 key（case-insensitive）即驗證失敗：

```text
password
passphrase
token
privateKey
private_key
kubeconfig
clientSecret
```

Phase 2A inventory 只引用 identity label；不放 private-key path。真實 SSH identity 決策延後 Phase 2B。

### 正規化輸出

`kdm_inventory_records` 每行固定五欄，以 tab 分隔：

```text
name<TAB>role<TAB>address<TAB>ssh_user<TAB>ssh_port
```

不得使用 `eval`、source inventory 或產生 shell assignments。

## 3. CLI contract

### Validate

```bash
bin/kdm config validate -f config/inventory.example.yaml
```

成功：

```text
Inventory valid: lab (2 nodes)
```

Exit code：

- `0`：有效
- `2`：CLI 使用錯誤
- `3`：inventory/schema 驗證失敗
- `4`：缺少或錯誤的 yq v4

### Target resolution

Phase 2A 先提供唯讀命令：

```bash
bin/kdm inventory targets -f <inventory> --all
bin/kdm inventory targets -f <inventory> --role control-plane
bin/kdm inventory targets -f <inventory> --node cp-1
```

輸出每行一個 node name；沒有 target 或 selector 衝突時回傳 exit code 3。

### SSH orchestration

Phase 2A 不公開可執行任意遠端命令的 production CLI。SSH orchestration 只作 library + mock tests；Phase 2B 經真實 lab 驗證後再定義受控 CLI。

## 4. File plan

### 新增

```text
config/inventory.example.yaml
lib/inventory.sh
tests/fixtures/inventory/valid-single.yaml
tests/fixtures/inventory/valid-multi.yaml
tests/fixtures/inventory/invalid-missing-nodes.yaml
tests/fixtures/inventory/invalid-duplicate-name.yaml
tests/fixtures/inventory/invalid-duplicate-address.yaml
tests/fixtures/inventory/invalid-role.yaml
tests/fixtures/inventory/invalid-address.yaml
tests/fixtures/inventory/invalid-secret.yaml
tests/unit/config.sh
tests/unit/inventory.sh
tests/unit/ssh.sh
tests/helpers/fake-ssh
```

### 修改

```text
bin/kdm
lib/core.sh
lib/config.sh
lib/validation.sh
lib/ssh.sh
Makefile
docs/development-roadmap.md
```

### 保持不動

```text
kdm
kdm_function
install.sh
yaml/
```

## 5. Task breakdown

### Task 1：建立 fixtures 與 schema expectations

**Objective:** 先定義資料契約與失敗案例，不寫 parser。

**Files:**

- Create: `config/inventory.example.yaml`
- Create: `tests/fixtures/inventory/*.yaml`
- Create: `tests/unit/config.sh`

**Steps:**

1. 建立 valid single/multi fixtures。
2. 建立 missing nodes、duplicate、unknown role、invalid address、secret key fixtures。
3. 寫 `tests/unit/config.sh` 呼叫尚不存在的 validator。
4. 執行：

   ```bash
   bash tests/unit/config.sh
   ```

5. 預期：FAIL，因 `kdm_config_validate_file` 尚未實作。

### Task 2：驗證 yq v4 prerequisite

**Objective:** 明確拒絕 Python yq、v3 或缺少 yq。

**Files:**

- Modify: `lib/validation.sh`
- Modify: `lib/config.sh`
- Test: `tests/unit/config.sh`

**Acceptance:**

- `yq --version` 必須能辨識 Mike Farah yq v4。
- 缺少或版本錯誤回傳 4。
- 不自動安裝 yq。

### Task 3：實作最小 inventory validation

**Objective:** 讓 fixtures 依預期通過／失敗。

**Files:**

- Modify: `lib/config.sh`
- Test: `tests/unit/config.sh`

**Validation order:**

1. 檔案存在且可讀。
2. YAML 可解析。
3. apiVersion/kind。
4. metadata name。
5. SSH defaults/ranges。
6. nodes 非空。
7. 每個 node 欄位格式。
8. name/address uniqueness。
9. forbidden key scan。

**Acceptance:** 所有 invalid fixtures 回傳 3，stderr 含穩定但不洩密的原因。

### Task 4：CLI `config validate`

**Objective:** 將 validator 接到 v2 CLI。

**Files:**

- Modify: `lib/core.sh`
- Modify: `bin/kdm`（僅在需要新增 source 時）
- Test: `tests/smoke/cli.sh`

**Steps:**

1. 先新增 CLI failing tests。
2. 實作 `config validate -f` dispatch。
3. 測試缺 `-f`、未知 flag、有效與無效 inventory。
4. 確認 help/version/doctor sentinel test 仍通過。

### Task 5：正規化 records

**Objective:** 以固定 TSV 介面隔離 YAML 與 Bash orchestration。

**Files:**

- Create: `lib/inventory.sh`
- Create: `tests/unit/inventory.sh`
- Modify: `bin/kdm` source order

**Acceptance:**

- valid-multi 產生固定順序與五欄 TSV。
- 空值不會變成 literal `null`。
- 含 tab/newline/metacharacter 的欄位被 validator 拒絕。

### Task 6：Target resolution

**Objective:** 解析 `all`、role、node selectors，且結果穩定去重。

**Files:**

- Modify: `lib/inventory.sh`
- Modify: `tests/unit/inventory.sh`
- Modify: `lib/core.sh`
- Modify: `tests/smoke/cli.sh`

**Acceptance:**

- `--all` 保留 inventory 順序。
- `--role control-plane` 只輸出 control-plane。
- 多個 `--node` 依 request 順序、重複只出現一次。
- unknown node/role 與空結果回傳 3；CLI selector 衝突回傳 usage code 2。

### Task 7：安全 SSH argv builder

**Objective:** 建立不使用 `eval` 的 SSH command array。

**Files:**

- Modify: `lib/ssh.sh`
- Create: `tests/unit/ssh.sh`

**預期 argv：**

```text
ssh
-o BatchMode=yes
-o ConnectTimeout=5
-o StrictHostKeyChecking=accept-new
-p 22
--
ubuntu@192.0.2.11
<controlled-command>
```

**Acceptance:**

- 參數以 array 傳遞。
- user/address/port/timeout 已先驗證。
- host key policy 不允許 `no`。
- 不接受整段 command string 再 `eval`。

### Task 8：Mock per-node orchestration

**Objective:** 使用 fake ssh 驗證多節點成功、部分失敗與 aggregate exit status。

**Files:**

- Create: `tests/helpers/fake-ssh`
- Modify: `lib/ssh.sh`
- Modify: `tests/unit/ssh.sh`

**Scenarios:**

1. 全節點成功 → aggregate 0。
2. 一台失敗 → 繼續其他節點，aggregate 10。
3. timeout 模擬 → node result 標記 failed，aggregate 10。
4. 空 target → 不呼叫 ssh，回傳 3。
5. fake ssh invocation log 不含 secret/kubeconfig/private-key content。

### Task 9：Quality gates 與回歸

**Objective:** 納入現有 Make/CI，不破壞 Phase 1 安全保證。

**Files:**

- Modify: `Makefile`
- Modify: `docs/development-roadmap.md`

**Commands:**

```bash
actionlint .github/workflows/ci.yml
yq eval '.' config/inventory.example.yaml >/dev/null
make test
git diff --check
```

**Acceptance:**

- ShellCheck 0 warning。
- unit/smoke 全通過。
- no-side-effect sentinel 證明 help/version/doctor/config/inventory 不呼叫 SSH/kubectl/sudo/package manager。
- legacy files 無 diff。

## 6. Phase 2B gate：真實 VM SSH

完成 Phase 2A 後才執行：

1. 為 `kdm-lab-cp1` 建立一般 SSH user/key policy。
2. 產生不含秘密的 local-only inventory。
3. 驗證 host key `accept-new` 首次加入與後續 strict match。
4. 驗證 BatchMode、timeout、reachable/unreachable。
5. 驗證 per-node output 與 aggregate exit。
6. 不執行任意 shell；只測試固定 read-only probe，例如 `hostname`。

Phase 2B 完成前，KDM 不公開真實 `node exec` CLI。

## 7. Risks and controls

| 風險 | 控制 |
|---|---|
| YAML 值注入 shell | yq → TSV；格式驗證；array；禁止 eval/source |
| Inventory 帶 secrets | forbidden-key scan；fixtures；文件規則 |
| Target 選錯節點 | exact selectors；unknown/empty fail closed；穩定輸出 |
| SSH host spoofing | 禁止 StrictHostKeyChecking=no；預設 accept-new |
| 單節點失敗被掩蓋 | per-node result + aggregate non-zero |
| 測試誤連真機 | fake ssh 放 PATH 前端；sentinel；Phase 2A 不公開 execution CLI |
| Bash 3.2 portability | 不使用 associative arrays、mapfile、nameref |
| VM IP 漂移 | runtime discovery；不提交當下 IP |
| Host disk 不足 | Phase 2A 不使用 VM；低於 10 GiB 停止 image/VM 擴充 |

## 8. Completion checklist

- [x] Inventory contract 寫入 example 與 fixtures。
- [x] Valid/invalid tests 先紅後綠。
- [x] `config validate` exit codes 符合契約。
- [x] Target resolution deterministic。
- [x] SSH argv 無 eval、無 secrets。
- [x] Mock partial failure/timeout aggregate 為 10。
- [x] `make test`、actionlint、YAML parse、diff check 通過。
- [x] Legacy files 無變更。
- [x] Phase 2A 不連線 `kdm-lab-cp1`。
