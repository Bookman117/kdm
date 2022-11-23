# kdm

Deploy kubernetes on ubuntu server 20.04/22.04 LTS & Rocky Linux 8 & 9.  
  
= System-setup  
 > hostinfo: Show host basic information  
 > system-configure: Configure file & directory.  
 > ssh-key: Let ssh login without password. [ host | renew ]  
 > set-hosts: Setup hosts. [ hosts <m> <Start> <End> <w> <Start> <End> [ Detect NETID just input xxx xxx ] ]  
 > set-ip: Setup IP Address. [ set-ip <IP/NETMASK> [ Detect NETID just input xxx/XX ] ]  
 > set-hostname: Setup hostname. [ hostname [ name ] ]  

= Kubernetes-deploy  
  └─init-control-plane >> control-plane-join >> worker-join >> dns-rollout >> controller-deploy >> metrics-deploy  
 > host-variable: Check script variable.  
 > package-install: Install basic package & setup environment.  
 > k9s-delete: Delete k9s package.  
 > init-control-plane: Init first control-plane node & deploy CNI. [ calico | flannel ]  
 > control-plane-join:  Let control-plane nodes join cluster. [ hosts | <node-name> ... ]  
 > worker-join: Let worker nodes join cluster. [ hosts | <node-name> ... ]  
 > cni-deploy: Deploy kubernetes CNI. [ calico | flannel ]  
 > cni-delete: Delete kubernetes CNI. [ calico | flannel ]  
 > dns-rollout: Rollout coredns & calico-api-server. [ if pod present ]  
 > csi-deploy: Deploy kubernetes CSI. [ local-path | rook-ceph ]  
 > csi-delete: Delete kubernetes CSI. [ local-path | rook-ceph ]  
 > rook: Check rook status or DataDir. [ ceph-status | OSD-status | dashboard-pw | data-dir | LVM-status | LVM-wipe | clean-data ]  
 > controller-deploy: Deploy basic service. [ metallb & nginx-ingress ] [ controller-deploy <Start> <End> [ Detect NETID just input xxx xxx ] ]  
 > controller-delete: Delete basic service. [ metallb & nginx-ingress ]  
 > metrics-deploy: Deploy metrics-server.  
 > metrics-delete: Delete metrics-server.  

= Kubernetes-functions  
 > [ name ]-deploy: Deploy service. [ name: jenkins | quay | grafana | landlord  ]  
 > [ name ]-delete: Delete service. [ name: jenkins | quay | grafana | landlord  ]  
 > taints: Check all nodes taint status.  
 > nodes: Check all nodes status.  
 > pods: Check all pods status.  
 > images: Check cluster images.  
 > image-send: save >> scp >> load target image to every worker node [ <image-name> <image name> <name.tar> ]  
 > rmi: Remove dangling images on cluster.  
 > helm-repo: Check helm repository.  
 > cluster-check: Check kubernetes cluster.  
 > cluster-upgrade: Upgrade cluster [ upgrade kubeadm、kubectl、kubelet、crio ]  
 > cluster-reset: Reset kubernetes cluster.  
 > cri-update: Update crio package.  
 > cri-check: Check CRI running pods.  
 > cri-clean: Remove CRI running pods.  
 > node-check: Check nodes port | hostname. [ node-check <NETID> <Start> <End> <Port> hostname ]  
 > node-reset: Reset hosts | specify nodes. [ node-reset <node-name> ... ]  
 > node-power: Reboot/Poweroff hosts | specify node. [ <node-name> ... ]  
 > help: Show script function message.  
 