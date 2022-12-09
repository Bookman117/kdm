# kdm

Deploy kubernetes on ubuntu server 20.04/22.04 LTS & Rocky Linux 8/9 & RHEL 8/9.  
  
System-setup  
 > system-info: Show host basic information.  
 > system-var: Check script variables.  
 > system-conf: Configure file & directory.  
 > system-check: Check node basic status.  
 > system-date: Check system time-zone.  
 > set-ssh-key: Let ssh login without password. [ host | renew ]  
 > set-hosts: Setup hosts. [ hosts <m> <Start> <End> <w> <Start> <End> [ Detect NETID just input xxx xxx ] ]  
 > set-ip: Setup IP Address. [ set-ip <IP/NETMASK> [ Detect NETID just input xxx/XX ] ]  
 > set-hostname: Setup hostname. [ hostname [ name ] ]  
 > sync-ssh: scp .ssh to every nodes.  
 > sync-kdm: scp kdm to every nodes.  
 > sync-yaml: scp yaml to every nodes.  
 > package-ver: Check package repositories.  
 > package-repo: Setup package repositories. [ add-all | add | remove ]  
 > package-install: Install basic package & setup environment.  
 > package-remove: Remove basic package & setup environment.  
 > package-check: Check node package status.  
 > k9s-install: Install k9s.  
 > k9s-delete: Delete k9s.  

Kubernetes-deploy  
  └─cp-init >> cp-join >> wk-join >> dns-rollout >> controller-deploy >> metrics-deploy >> csi-deploy  
 > cp-init: Init first control-plane node & deploy CNI. [ calico | flannel ]  
 > cp-join:  Let control-plane nodes join cluster. [ <hosts> | <node-name> ... ]  
 > wk-join: Let worker nodes join cluster. [ <hosts> | <node-name> ... ]  
 > cni-deploy: Deploy kubernetes CNI. [ calico | flannel ]  
 > cni-delete: Delete kubernetes CNI. [ calico | flannel ]  
 > dns-rollout: Rollout coredns & calico-api-server. [ if pod present ]  
 > csi-deploy: Deploy kubernetes CSI. [ local-path | rook-ceph ]  
 > csi-delete: Delete kubernetes CSI. [ local-path | rook-ceph ]  
 > csi-rook: Check rook status or DataDir. [ status | dashboard-pw | data-check | lvm-status | wipe-data ]  
 > controller-deploy: Deploy basic service. [ metallb & nginx-ingress ] [ controller-deploy <Start> <End> [ Detect NETID just input xxx xxx ] ]  
 > controller-delete: Delete basic service. [ metallb & nginx-ingress ]  
 > metrics-deploy: Deploy metrics-server.  
 > metrics-delete: Delete metrics-server.  

Kubernetes-functions  
 > <project-name>-deploy: Deploy Kubenetes projects. [ jenkins | quay | grafana | landlord  ]  
 > <project-name>-delete: Delete Kubenetes projects. [ jenkins | quay | grafana | landlord  ]  
 > cp-join:  Let control-plane nodes join cluster. [ <hosts> | <node-name> ... ]  
 > wk-join: Let worker nodes join cluster. [ <hosts> | <node-name> ... ]  
 > nodes: Check all nodes status.  
 > pods: Check all pods status.  
 > images: Check cluster images.  
 > image-send: save >> scp >> load target image to every worker node [ <image-name> <name.tar> ]  
 > image-remove: Remove dangling images on cluster.  
 > helm-repo: Check helm repository.  
 > cluster-check: Check kubernetes cluster info.  
 > cluster-upgrade: Upgrade cluster [ upgrade kubeadm、kubectl、kubelet、crio ]  
 > cluster-reset: Reset kubernetes cluster.  
 > cri-update: Update crio package.  
 > cri-check: Check CRI running pods.  
 > cri-clean: Remove CRI running pods.  
 > node-check: Check nodes port | hostname. [ node-check <NETID> <Start> <End> <Port> hostname ]  
 > node-reset: Reset hosts | specify nodes. [ node-reset <node-name> ... ]  
 > node-power: Reboot/Poweroff hosts | specify node. [ <node-name> ... ]  
 > help: Show script parameters information.  