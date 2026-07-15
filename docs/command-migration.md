# KDM v1 → v2 命令遷移表

> 日期：2026-07-16
> 來源：`kdm` 靜態解析
> 範圍：95 個一般 case command；特殊 shorthand 與空參數另列。

## 遷移原則

- **重寫**：保留能力，但重新定義輸入、安全閘門與驗證。
- **內部化**：不再作公開 CLI，由 provider/workflow 呼叫。
- **移至 legacy**：不是 v2 叢集核心，保留歷史參考但不優先移植。
- **淘汰**：原始介面風險過高或沒有保留價值。
- **延後重寫**：需要額外安全設計，不能在早期 Phase 恢復。

## 命令清單

| v1 命令 | 原行號 | 決策 | v2 目的地 | 備註 |
|---|---:|---|---|---|
| `sys-info` | `32` | 重寫 | `doctor host` | 唯讀介面，納入新命令模型 |
| `sys-var` | `36` | 重寫 | `config show` | 唯讀介面，納入新命令模型 |
| `sys-conf` | `40` | 待重寫 | `TBD` | Phase 0 待確認 |
| `sys-check` | `102` | 重寫 | `doctor host` | 唯讀介面，納入新命令模型 |
| `sys-date` | `106` | 重寫 | `host time status` | 唯讀介面，納入新命令模型 |
| `set-ssh-key` | `115` | 淘汰 | `無直接替代` | 原行為風險過高，需以更窄介面取代 |
| `set-hosts` | `135` | 重寫 | `config set/validate` | 不再自我修改 shell 原始碼 |
| `jce-set-hosts` | `169` | 淘汰 | `無直接替代` | 原行為風險過高，需以更窄介面取代 |
| `set-ip` | `203` | 重寫 | `config set/validate` | 不再自我修改 shell 原始碼 |
| `set-hostname` | `281` | 重寫 | `config set/validate` | 不再自我修改 shell 原始碼 |
| `set-suffix` | `290` | 重寫 | `config set/validate` | 不再自我修改 shell 原始碼 |
| `set-ver` | `298` | 重寫 | `config set/validate` | 不再自我修改 shell 原始碼 |
| `set-sc` | `314` | 重寫 | `config set/validate` | 不再自我修改 shell 原始碼 |
| `set-eck-node` | `325` | 重寫 | `config set/validate` | 不再自我修改 shell 原始碼 |
| `set-context` | `340` | 重寫 | `config set/validate` | 不再自我修改 shell 原始碼 |
| `set-coredns` | `360` | 重寫 | `config set/validate` | 不再自我修改 shell 原始碼 |
| `set-selinux` | `371` | 重寫 | `config set/validate` | 不再自我修改 shell 原始碼 |
| `sync-ssh` | `402` | 淘汰 | `無直接替代` | 原行為風險過高，需以更窄介面取代 |
| `sync-kdm` | `413` | 重寫 | `artifact sync` | 只傳公開 artifact；不得傳 credential |
| `sync-yaml` | `428` | 重寫 | `artifact sync` | 只傳公開 artifact；不得傳 credential |
| `sync-file` | `438` | 重寫 | `artifact sync` | 只傳公開 artifact；不得傳 credential |
| `sync-kube-config` | `449` | 淘汰 | `無直接替代` | 原行為風險過高，需以更窄介面取代 |
| `pkg-ver` | `459` | 重寫 | `package versions` | 唯讀介面，納入新命令模型 |
| `pkg-repo` | `481` | 重寫 | `package plan/apply` | provider 化且只管理 KDM 自有 repo |
| `pkg-install` | `519` | 重寫 | `package plan/apply` | provider 化且只管理 KDM 自有 repo |
| `pkg-rm` | `583` | 重寫 | `package plan/apply` | provider 化且只管理 KDM 自有 repo |
| `pkg-check` | `614` | 重寫 | `package status` | 唯讀介面，納入新命令模型 |
| `pkg-fix` | `618` | 淘汰 | `無直接替代` | 原行為風險過高，需以更窄介面取代 |
| `podman-install` | `636` | 移至工具安裝 | `tool install` | 不與 cluster bootstrap 隱式綁定 |
| `podman-rm` | `644` | 重寫 | `addon install/remove` | 只保留 Kubernetes 基礎 addon |
| `docker-install` | `652` | 移至工具安裝 | `tool install` | 不與 cluster bootstrap 隱式綁定 |
| `docker-compose-install` | `656` | 移至工具安裝 | `tool install` | 不與 cluster bootstrap 隱式綁定 |
| `k9s-install` | `660` | 移至工具安裝 | `tool install` | 不與 cluster bootstrap 隱式綁定 |
| `k9s-rm` | `683` | 重寫 | `addon install/remove` | 只保留 Kubernetes 基礎 addon |
| `daemon-enable` | `694` | 內部化 | `provider service` | 不保留公開 CLI |
| `daemon-reload` | `709` | 內部化 | `provider service` | 不保留公開 CLI |
| `vip-deploy` | `717` | 重寫 | `addon install/remove` | 只保留 Kubernetes 基礎 addon |
| `cp-init` | `729` | 重寫 | `cluster init/join` | 改用 inventory 與 kubeadm config |
| `cp-join` | `850` | 重寫 | `cluster init/join` | 改用 inventory 與 kubeadm config |
| `wk-join` | `899` | 重寫 | `cluster init/join` | 改用 inventory 與 kubeadm config |
| `cni-deploy` | `926` | 重寫 | `addon cni` | 固定版本、render/validate |
| `cni-rm` | `946` | 重寫 | `addon cni` | 固定版本、render/validate |
| `dns-rollout` | `967` | 待重寫 | `TBD` | Phase 0 待確認 |
| `csi-deploy` | `988` | 重寫 | `addon storage` | 固定版本；remove 與 wipe 分離 |
| `csi-rm` | `1058` | 重寫 | `addon storage` | 固定版本；remove 與 wipe 分離 |
| `csi-rook` | `1090` | 延後重寫 | `addon rook` | disk wipe 必須獨立雙重確認 |
| `controller-deploy` | `1165` | 重寫 | `addon install/remove` | 只保留 Kubernetes 基礎 addon |
| `controller-rm` | `1226` | 重寫 | `addon install/remove` | 只保留 Kubernetes 基礎 addon |
| `metrics-deploy` | `1234` | 重寫 | `addon install/remove` | 只保留 Kubernetes 基礎 addon |
| `metrics-rm` | `1249` | 重寫 | `addon install/remove` | 只保留 Kubernetes 基礎 addon |
| `prometheus-deploy` | `1254` | 重寫 | `addon install/remove` | 只保留 Kubernetes 基礎 addon |
| `prometheus-rm` | `1271` | 重寫 | `addon install/remove` | 只保留 Kubernetes 基礎 addon |
| `eck-deploy` | `1277` | 重寫 | `addon install/remove` | 只保留 Kubernetes 基礎 addon |
| `kibana-deploy` | `1305` | 重寫 | `addon install/remove` | 只保留 Kubernetes 基礎 addon |
| `eck-rm` | `1316` | 重寫 | `addon install/remove` | 只保留 Kubernetes 基礎 addon |
| `eck-check` | `1342` | 待重寫 | `TBD` | Phase 0 待確認 |
| `mariadb-galera-deploy` | `1355` | 移至 legacy | `legacy/applications` | 非叢集核心；不在 Phase 1 執行 |
| `mariadb-galera-rm` | `1431` | 移至 legacy | `legacy/applications` | 非叢集核心；不在 Phase 1 執行 |
| `harbor-deploy` | `1445` | 移至 legacy | `legacy/applications` | 非叢集核心；不在 Phase 1 執行 |
| `jenkins-deploy` | `1456` | 移至 legacy | `legacy/applications` | 非叢集核心；不在 Phase 1 執行 |
| `jenkins-rm` | `1466` | 移至 legacy | `legacy/applications` | 非叢集核心；不在 Phase 1 執行 |
| `quay-deploy` | `1472` | 移至 legacy | `legacy/applications` | 非叢集核心；不在 Phase 1 執行 |
| `quay-rm` | `1482` | 移至 legacy | `legacy/applications` | 非叢集核心；不在 Phase 1 執行 |
| `grafana-deploy` | `1487` | 移至 legacy | `legacy/applications` | 非叢集核心；不在 Phase 1 執行 |
| `grafana-rm` | `1497` | 移至 legacy | `legacy/applications` | 非叢集核心；不在 Phase 1 執行 |
| `landlord-deploy` | `1503` | 移至 legacy | `legacy/applications` | 非叢集核心；不在 Phase 1 執行 |
| `landlord-rm` | `1548` | 移至 legacy | `legacy/applications` | 非叢集核心；不在 Phase 1 執行 |
| `images` | `1568` | 重寫 | `image list` | 唯讀介面，納入新命令模型 |
| `image-send` | `1579` | 重寫 | `image lifecycle` | 限定目標與不安全 registry policy |
| `image-rm` | `1594` | 淘汰 | `image prune --plan` | 原行為風險過高，需以更窄介面取代 |
| `helm-repo` | `1608` | 重寫 | `addon repo status` | 唯讀介面，納入新命令模型 |
| `cluster-info` | `1616` | 重寫 | `cluster status` | 唯讀介面，納入新命令模型 |
| `cluster-upgrade` | `1641` | 重寫 | `cluster upgrade` | plan/apply 與 read-back verification |
| `cluster-rm` | `1860` | 重寫 | `addon install/remove` | 只保留 Kubernetes 基礎 addon |
| `cri-upgrade` | `1963` | 重寫 | `runtime lifecycle` | CRI-O provider 與 drain/uncordon 驗證 |
| `cri-check` | `2000` | 重寫 | `runtime status` | 唯讀介面，納入新命令模型 |
| `cri-rm` | `2010` | 淘汰 | `無直接替代` | 原行為風險過高，需以更窄介面取代 |
| `node-info` | `2028` | 重寫 | `node info` | 唯讀介面，納入新命令模型 |
| `node-check` | `2047` | 重寫 | `node check` | 唯讀介面，納入新命令模型 |
| `node-reset` | `2055` | 重寫 | `node reset` | inventory target + safety gate |
| `node-power` | `2097` | 重寫 | `node power` | inventory target + safety gate |
| `deploy` | `2101` | 重寫 | `cluster create` | 顯式 stages，不遞迴呼叫 PATH 中的 kdm |
| `etcdctl-install` | `2115` | 移至工具安裝 | `tool install` | 不與 cluster bootstrap 隱式綁定 |
| `parm-check` | `2131` | 重寫 | `help` | 唯讀介面，納入新命令模型 |
| `test-nginx` | `2163` | 移至 legacy | `legacy/applications` | 非叢集核心；不在 Phase 1 執行 |
| `test-apache` | `2169` | 移至 legacy | `legacy/applications` | 非叢集核心；不在 Phase 1 執行 |
| `test-images-push` | `2175` | 移至 legacy | `legacy/applications` | 非叢集核心；不在 Phase 1 執行 |
| `test-images-rm` | `2209` | 移至 legacy | `legacy/applications` | 非叢集核心；不在 Phase 1 執行 |
| `pkg-hold-check` | `2222` | 重寫 | `package hold status` | 唯讀介面，納入新命令模型 |
| `pkg-hold` | `2234` | 重寫 | `package plan/apply` | provider 化且只管理 KDM 自有 repo |
| `podman-login` | `2246` | 移至 legacy | `legacy/applications` | 非叢集核心；不在 Phase 1 執行 |
| `podman-cni` | `2259` | 移至 legacy | `legacy/applications` | 非叢集核心；不在 Phase 1 執行 |
| `watch` | `2268` | 重寫 | `cluster watch` | 唯讀介面，納入新命令模型 |
| `metrics` | `2277` | 重寫 | `node metrics` | 唯讀介面，納入新命令模型 |
| `test` | `2344` | 淘汰 | `tests/` | 測試不應是 production CLI command |

## 特殊入口

| v1 入口 | v2 決策 |
|---|---|
| 空參數顯示 cluster summary | 改為明確 `kdm status`；空參數顯示 help |
| `--help` | Phase 1 保留，另支援 `help` |
| `-` 進入 k9s | 淘汰 shorthand；避免隱式 interactive dependency |
| `-- <command>` 遠端任意命令 | 淘汰；改為受控 command/provider，不提供任意 shell passthrough |

## Migration gate

某命令只有在以下條件完成後才能從 legacy 標為 migrated：

- [ ] 有明確 CLI contract 與 exit code。
- [ ] 有 plan/apply 或唯讀分類。
- [ ] 有輸入與 target validation。
- [ ] 有 no-side-effect test 或 integration test。
- [ ] 有實際 read-back verification。
- [ ] 不傳播 credential，不依賴 upstream `main`。
