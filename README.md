# Overview
kdm is a bash script based command-line tool for Kubernetes deployment.

Support OS:
- Ubuntu server 20.04/22.04 LTS
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
wget -qO - 'https://raw.githubusercontent.com/Bookman-W/kdm/master/install.sh' | bash
```
## curl
```bash
curl -s 'https://raw.githubusercontent.com/Bookman-W/kdm/master/install.sh' | bash
```
# Usage
```bash
kdm help
system-setup | 27
 > sys-info: Show host basic information.
 > sys-var: Check script variables.
 > sys-conf: Configure file & directory.
 > sys-check: Check node basic status.
 > sys-date: Check system time-zone.
 > set-ssh-key: Let ssh login without password. [ host | renew ]
...
```