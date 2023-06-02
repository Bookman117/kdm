# kdm  
Kubernetes Deployment Manager  
Support OS: Ubuntu server 20.04/22.04 LTS | Rocky Linux 8/9 | RHEL 8/9.  
  
sys-setup | 23  
 > sys-info: Show host basic information.  
 > sys-var: Check script variables.  
 > sys-conf: Configure file & directory.  
 > sys-check: Check node basic status.  
 > sys-date: Check system time-zone.  
 > set-ssh-key: Let ssh login without password. [ host | renew ]  
 > set-hosts: Setup hosts. [ hosts m start end w start end [ Detect NETID just input xxx xxx ] ]  
 > set-ip: Setup IP Address. [ set-ip IP/NETMASK [ Detect NETID just input xxx/XX ] ]  
 > set-hostname: Setup hostname. [ hostname [ name ] ]  
 > set-ver: Set kube*、cri-o package version.  
 > set-selinux: Setting SELinux mod [ set | apply ]  
 > sync-ssh: scp .ssh to every nodes.  
 > sync-kdm: scp kdm to every nodes.  
 > sync-yaml: scp yaml to every nodes.  
 > sync-kube-config: scp yaml to every nodes.  
 > pkg-ver: Check package repositories.  
 > pkg-repo: Setup package repositories. [ add | rm ]  
 > pkg-install: Install basic package & setup environment.  
 > pkg-rm: Remove basic package & setup environment.  
 > pkg-check: Check node package status.  
 > pkg-fix: Fix Ubuntu pkg.  
 > k9s-deploy: Deploy k9s.  
 > k9s-rm: Delete k9s.  

Kubernetes-deploy | 9  
  └─cp-init >> cp-join >> wk-join >> dns-rollout >> controller-deploy >> metrics-deploy >> csi-deploy  
 > cp-init: Init first control-plane node & deploy CNI. [ calico or flannel ]  
 > cp-join:  Let control-plane nodes join cluster. [ hosts | node ]  
 > wk-join: Let worker nodes join cluster. [ hosts | node ]  
 > cni-deploy: Deploy kubernetes CNI. [ calico or flannel ]  
 > cni-rm: Delete kubernetes CNI. [ calico or flannel ]  
 > dns-rollout: Rollout coredns & calico-api-server. [ if pod present ]  
 > csi-deploy: Deploy kubernetes CSI. [ local-path | rook-ceph ]  
 > csi-rm: Delete kubernetes CSI. [ local-path | rook-ceph ]  
 > csi-rook: Check rook status or DataDir. [ status | dashboard-pw | data-check | lvm-status | wipe-data | disk-check ]  

Kubernetes-functions | 15  
 > project-name-deploy: Deploy Kubenetes projects.  
  └─ [ k9s | controller | metrics | prometheus | eck | mariadb-galera | harbor | jenkins | quay | grafana | landlord  ]  
 > project-name-rm: Delete Kubenetes projects.  
  └─ [ k9s | controller | metrics | prometheus | eck | mariadb-galera | harbor | jenkins | quay | grafana | landlord  ]  
 > images: Check cluster images.  
 > image-send: save >> scp >> load target image to every worker node [ <image-name> <name.tar> ]  
 > image-rm: Remove dangling images on cluster.  
 > helm-repo: Check helm repository.  
 > cluster-info: Check kubernetes cluster info.  
 > cluster-upgrade: Upgrade cluster [ upgrade kubeadm、kubectl、kubelet、crio ]  
 > cluster-rm: Remove kubernetes cluster.  
 > cri-upgrade: Update crio package.  
 > cri-check: Check CRI running pods.  
 > cri-clean: Remove CRI running pods.  
 > node-check: Check nodes port | hostname. [ hosts | hosts name | hosts port | NETID start end <Port> ]  
 > node-reset: Reset hosts | specify nodes. [ node-reset node ]  
 > node-power: Reboot/Poweroff hosts | specify node. [ node ]  