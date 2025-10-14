#!/bin/bash

# Kubernetes Master Node Installation Script for RHEL 8
# Run this script with sudo privileges

set -e

echo "=========================================="
echo "Kubernetes Master Node Installation"
echo "=========================================="

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root or with sudo"
    exit 1
fi

# Step 1: System Preparation
echo "[1/9] Updating system packages..."
dnf update -y

echo "[2/9] Installing essential packages..."
# Install basic system utilities
dnf install -y \
    curl wget vim nano htop net-tools bind-utils \
    git unzip tar which tree lsof

# Install firewall and network utilities
dnf install -y \
    firewalld iptables-services ipset ipvsadm

# Install container and system utilities
dnf install -y \
    yum-utils device-mapper-persistent-data lvm2 chrony rsync

# Start and enable essential services
systemctl enable --now firewalld
systemctl enable --now chronyd

echo "[3/9] Configuring system settings..."
# Set hostname (modify as needed)
read -p "Enter hostname for master node (default: k8s-master): " HOSTNAME
HOSTNAME=${HOSTNAME:-k8s-master}
hostnamectl set-hostname $HOSTNAME

# Disable swap
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Configure SELinux
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# Configure firewall for master node
echo "Configuring firewall rules..."
firewall-cmd --permanent --add-port=6443/tcp
firewall-cmd --permanent --add-port=2379-2380/tcp
firewall-cmd --permanent --add-port=10250/tcp
firewall-cmd --permanent --add-port=10251/tcp
firewall-cmd --permanent --add-port=10252/tcp
firewall-cmd --reload

echo "[4/9] Configuring container runtime..."
# Load required kernel modules
cat <<EOF | tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Configure sysctl parameters
cat <<EOF | tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sysctl --system

echo "[5/9] Installing containerd..."
# Install containerd
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
dnf install -y containerd.io

# Configure containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml

# Enable SystemdCgroup
sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

# Start and enable containerd
systemctl restart containerd
systemctl enable containerd

echo "[6/9] Adding Kubernetes repository..."
cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

echo "[7/9] Installing Kubernetes components..."
dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
systemctl enable --now kubelet

echo "[8/9] Initializing Kubernetes cluster..."
kubeadm init --pod-network-cidr=10.244.0.0/16

echo "[9/9] Configuring kubectl..."
# Configure kubectl for root user
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# Configure kubectl for regular user if SUDO_USER exists
if [ -n "$SUDO_USER" ]; then
    USER_HOME=$(eval echo ~$SUDO_USER)
    sudo -u $SUDO_USER mkdir -p $USER_HOME/.kube
    cp -i /etc/kubernetes/admin.conf $USER_HOME/.kube/config
    chown $SUDO_USER:$SUDO_USER $USER_HOME/.kube/config
fi

echo "Installing Flannel CNI network plugin..."
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

echo "Enabling kubectl autocompletion..."
echo 'source <(kubectl completion bash)' >> ~/.bashrc

echo ""
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo ""
echo "Waiting for cluster to be ready..."
sleep 30

echo "Cluster Status:"
kubectl get nodes
echo ""
kubectl get pods --all-namespaces
echo ""

echo "=========================================="
echo "IMPORTANT: Save the join command below!"
echo "=========================================="
echo ""
echo "Run this command to generate the join command for worker nodes:"
echo "kubeadm token create --print-join-command"
echo ""
kubeadm token create --print-join-command
echo ""
echo "=========================================="
echo "Master node installation completed successfully!"
echo "=========================================="