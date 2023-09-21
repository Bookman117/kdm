# Overview  
>kdm: Kubernetes Deployment Manager

kdm is a Shell script based command-line tool for Kubernetes deployment.

Support OS:
- Ubuntu server 20.04/22.04 LTS

Adjusting:
- Rocky Linux 8/9
- RHEL 8/9
# What can it do ?
- Prepare the system configuration on multiple nodes for deploying Kubernetes.
- Install the Kubernetes dependencies package on multiple nodes.
- Deploy Kubernetes applications, such as:
  - metallb
  - ingress-nginx
  - metrics
  - Kube-prometheus
  - rook-ceph
  - mariadb-galera
  - eck
  - harbor
  - ...
# Installation

## wget
```bash
$ wget -qO - 'https://raw.githubusercontent.com/Bookman117/kdm/master/install.sh' | bash
```
## curl
```bash
$ curl -s 'https://raw.githubusercontent.com/Bookman117/kdm/master/install.sh' | bash
```
# Usage

Set kube* & cri-o package target version:
```bash
$ kdm set-ver check
Target release: 1.28
 [●] 1.28.1
 [●] 1.28.0
Target release: 1.27
 [●] 1.27.1
 [●] 1.27.0
Target release: 1.26
 [●] 1.26.4
 [●] 1.26.3
 [●] 1.26.2
 [●] 1.26.1
 [●] 1.26.0

$ kdm set-ver sub 1.28.0
 [●] Version setting is completed
 [●] cri-o version: 1.28.0 is available
 [●] cri-o version: 1.28.1 is available
```

Install packages and dependencies:
```bash
$ kdm pkg-install local
91-m1 | package install procedure
 [●] System      | swap disabled
 [●] System      | modules br_netfilter | overlay enabled
 [●] System      | ipv4_forward enabled
 [●] System      | ipv6 disabled
 [●] Repository  | podman repository added
 [●] Repository  | cri-o 1.27.0 repository added
 [●] Repository  | Helm package repository added
 [●] Repository  | cache updated
 [●] Package     | crio 1.27.0 installed
 [●] Package     | crio.conf configured
 [●] Package     | policy.json updated
 [●] Package     | kubelet v1.27.0 installed
 [●] Package     | 10-kubeadm.conf checked
 [●] Package     | kubeadm v1.27.0 installed
 [●] Package     | kubectl v1.27.0 installed
 [●] Package     | helm installed
 [●] Package     | k9s installed
 [●] Package     | podman 4.5.1 installed
 [●] Daemon      | crio enabled
 [●] Daemon      | crio restarted
 [●] Daemon      | kubelet enabled
 [●] Daemon      | kubelet restarted
 [●] Daemon      | daemon has been reload
Package Check list
91-m1 | Package status
 [●] crio     | 1.27.0 | active (running) | 4s ago
 [●] kubelet  | 1.27.0 | activating (auto-restart) | 3s ago
 [●] kubeadm  | 1.27.0
 [●] kubectl  | 1.27.0
 [●] helm     | 3.11.3
 [●] podman   | 4.5.1
 [●] k9s      | 0.27.4
```

Check packages:
```bash
$ kdm pkg-check local
91-m1 | Package status
 [●] crio     | 1.27.0 | active (running) | 33min ago
 [●] kubelet  | 1.27.0 | activating (auto-restart) | 2s ago
 [●] kubeadm  | 1.27.0
 [●] kubectl  | 1.27.0
 [●] helm     | 3.11.3
 [●] podman   | 4.5.1
 [●] k9s      | 0.27.4
```

Deploy highly available cluster:
```bash
$ kdm deploy high calico hosts 100 109 rook-ceph
Please confirm this command will initialize kubernetes via 91-m1.
Press N/n to stop, other key to continue.
```

Show basic cluster information:
```bash
$ kdm
● Kubernetes deployed | v1.27.0 | current-context | cp-1 node age: 79d
  ├─ Active nodes
  │  ├─ control-plane | cp-1 cp-2 cp-3
  │  └─ worker        | wk-1 wk-2 wk-3
  ├─ StorageClass     | deployed: local-path
  ├─ StorageClass     | deployed: rook-ceph-block
  ├─ Controller       | deployed: metallb
  ├─ Controller       | deployed: nginx ingress
  ├─ Monitoring       | deployed: metrics
  └─ Monitoring       | deployed: prometheus
```

Help information:
```bash
$ kdm help
system-setup | 27
 > sys-info: Show host basic information.
 > sys-var: Check script variables.
 > sys-conf: Configure file & directory.
 > sys-check: Check node basic status.
 > sys-date: Check system time-zone.
 > set-ssh-key: Let ssh login without password. [ host | renew ]
...
```