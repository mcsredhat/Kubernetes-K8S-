#!/bin/bash

# Kubernetes Worker Node Installation Script for RHEL 8
# Run this script with sudo privileges

set -e

echo "=========================================="
echo "Kubernetes Worker Node Installation"
echo "=========================================="

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root or with sudo"
    exit 1
fi

# Step 1: System Preparation
echo "[1/8] Updating system packages..."
dnf update -y

echo "[2/8] Installing essential packages..."
# Install basic system utilities
dnf install -y \
    curl wget vim nano net-tools bind-utils \
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

echo "[3/8] Configuring system settings..."
# Set hostname (modify as needed)
read -p "Enter hostname for worker node (e.g., k8s-worker1): " HOSTNAME
HOSTNAME=${HOSTNAME:-k8s-worker1}
hostnamectl set-hostname $HOSTNAME

# Disable swap
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Configure SELinux
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# Configure firewall for worker node
echo "Configuring firewall rules..."
firewall-cmd --permanent --add-port=10250/tcp
firewall-cmd --permanent --add-port=30000-32767/tcp
firewall-cmd --reload

echo "[4/8] Configuring container runtime..."
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

echo "[5/8] Installing containerd..."
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

echo "[6/8] Adding Kubernetes repository..."
cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

echo "[7/8] Installing Kubernetes components..."
dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
systemctl enable --now kubelet

echo "[8/8] Worker node preparation complete!"
echo ""
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo ""
echo "The worker node is now ready to join the cluster."
echo ""
echo "To join this worker node to the cluster, run the join command"
echo "that was provided when you initialized the master node."
echo ""
echo "The command format is:"
echo "sudo kubeadm join <master-ip>:6443 --token <token> \\"
echo "  --discovery-token-ca-cert-hash sha256:<hash>"
echo ""
echo "If you don't have the join command, generate it on the master node:"
echo "kubeadm token create --print-join-command"
echo ""
echo "=========================================="
echo ""
read -p "Do you have the join command ready? (y/n): " READY

if [ "$READY" == "y" ] || [ "$READY" == "Y" ]; then
    echo ""
    echo "Please paste the complete join command below and press Enter:"
    read -p "> " JOIN_COMMAND
    
    if [ -n "$JOIN_COMMAND" ]; then
        echo ""
        echo "Executing join command..."
        eval $JOIN_COMMAND
        echo ""
        echo "=========================================="
        echo "Worker node joined successfully!"
        echo "Verify on master node with: kubectl get nodes"
        echo "=========================================="
    else
        echo "No command entered. Please run the join command manually."
    fi
else
    echo ""
    echo "Please run the join command manually when ready."
    echo ""
fi

echo ""
echo "Worker node installation completed!"
echo ""