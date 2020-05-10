#taken from https://ahmermansoor.blogspot.com/2019/04/install-kubernetes-cluster-docker-ce-centos-7.html

# Turn off fire wall
systemctl disable firewalld && systemctl stop firewalld

yum install -y device-mapper-persistent-data lvm2 yum-utils

yum-config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo

yum makecache fast

yum install -y docker-ce

mkdir /etc/docker

sudo bash -c 'cat > /etc/docker/daemon.json << EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ]
}
EOF'

systemctl enable docker.service

 systemctl start docker.service

 sudo bash -c 'cat > /etc/sysctl.d/kubernetes.conf << EOF
 net.ipv4.ip_forward = 1
 net.bridge.bridge-nf-call-ip6tables = 1
 net.bridge.bridge-nf-call-iptables = 1
EOF'

modprobe br_netfilter

sysctl --system

swapoff -a

sed -e '/swap/s/^/#/g' -i /etc/fstab

setenforce 0

sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# add the kubetnetes package to our repos so we can install it via YUM
sudo bash -c 'cat > /etc/yum.repos.d/kubernetes.repo <<EOF
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF'

yum makecache fast

yum install -y kubelet kubeadm kubectl

source <(kubectl completion bash)

kubectl completion bash > /etc/bash_completion.d/kubectl

systemctl start kubelet && systemctl enable kubelet
systemctl restart kubelet 

#install cockpit
#yum install cockpit cockpit-dashboard cockpit-kubernetes -y
#systemctl enable cockpit.socket
#systemctl start cockpit.socket

