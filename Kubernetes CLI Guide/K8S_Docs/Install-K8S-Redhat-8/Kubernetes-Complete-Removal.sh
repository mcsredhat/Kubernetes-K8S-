#!/bin/bash

# Kubernetes Complete Removal Script for RHEL 8
# This script removes Kubernetes and all related components
# Run this script with sudo privileges

set -e

echo "=========================================="
echo "Kubernetes Complete Removal Script"
echo "=========================================="
echo ""
echo "WARNING: This will completely remove Kubernetes"
echo "and all associated components from this system."
echo ""
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Removal cancelled."
    exit 0
fi

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root or with sudo"
    exit 1
fi

echo ""
echo "[1/10] Draining node (if part of cluster)..."
# Try to drain the node if kubectl is available
if command -v kubectl &> /dev/null; then
    NODE_NAME=$(hostname)
    kubectl drain $NODE_NAME --delete-emptydir-data --force --ignore-daemonsets 2>/dev/null || true
    kubectl delete node $NODE_NAME 2>/dev/null || true
fi

echo "[2/10] Resetting kubeadm..."
if command -v kubeadm &> /dev/null; then
    kubeadm reset -f
fi

echo "[3/10] Stopping Kubernetes services..."
systemctl stop kubelet 2>/dev/null || true
systemctl disable kubelet 2>/dev/null || true

echo "[4/10] Stopping container runtime..."
systemctl stop containerd 2>/dev/null || true
systemctl disable containerd 2>/dev/null || true

echo "[5/10] Removing Kubernetes packages..."
dnf remove -y kubelet kubeadm kubectl kubernetes-cni 2>/dev/null || true
dnf remove -y containerd.io 2>/dev/null || true

echo "[6/10] Cleaning up configuration files..."
# Remove Kubernetes directories
rm -rf /etc/kubernetes
rm -rf /var/lib/kubelet
rm -rf /var/lib/etcd
rm -rf /etc/cni
rm -rf /opt/cni
rm -rf /var/lib/cni
rm -rf /run/flannel
rm -rf /etc/kube-flannel

# Remove kubectl config
rm -rf $HOME/.kube
if [ -n "$SUDO_USER" ]; then
    USER_HOME=$(eval echo ~$SUDO_USER)
    rm -rf $USER_HOME/.kube
fi

# Remove containerd config
rm -rf /etc/containerd
rm -rf /var/lib/containerd

echo "[7/10] Removing Kubernetes repositories..."
rm -f /etc/yum.repos.d/kubernetes.repo

echo "[8/10] Cleaning up network settings..."
# Remove kernel modules config
rm -f /etc/modules-load.d/containerd.conf
rm -f /etc/sysctl.d/99-kubernetes-cri.conf

# Clean up network interfaces
ip link delete cni0 2>/dev/null || true
ip link delete flannel.1 2>/dev/null || true

# Remove iptables rules
iptables -F 2>/dev/null || true
iptables -t nat -F 2>/dev/null || true
iptables -t mangle -F 2>/dev/null || true
iptables -X 2>/dev/null || true

# Clean up ipvs rules
ipvsadm --clear 2>/dev/null || true

echo "[9/10] Removing firewall rules..."
# Remove Kubernetes firewall rules
firewall-cmd --permanent --remove-port=6443/tcp 2>/dev/null || true
firewall-cmd --permanent --remove-port=2379-2380/tcp 2>/dev/null || true
firewall-cmd --permanent --remove-port=10250/tcp 2>/dev/null || true
firewall-cmd --permanent --remove-port=10251/tcp 2>/dev/null || true
firewall-cmd --permanent --remove-port=10252/tcp 2>/dev/null || true
firewall-cmd --permanent --remove-port=30000-32767/tcp 2>/dev/null || true
firewall-cmd --reload 2>/dev/null || true

echo "[10/10] Final cleanup..."
# Clean up any remaining processes
pkill -9 kube 2>/dev/null || true
pkill -9 etcd 2>/dev/null || true

# Remove systemd service files
rm -f /etc/systemd/system/kubelet.service
rm -f /etc/systemd/system/kubelet.service.d
rm -f /usr/lib/systemd/system/kubelet.service
systemctl daemon-reload
systemctl reset-failed

# Clean dnf cache
dnf clean all

echo ""
echo "=========================================="
echo "Kubernetes Removal Complete!"
echo "=========================================="
echo ""
echo "The following have been removed:"
echo "  - Kubernetes packages (kubelet, kubeadm, kubectl)"
echo "  - Container runtime (containerd)"
echo "  - All configuration files and data"
echo "  - Network interfaces and rules"
echo "  - Firewall rules"
echo ""
echo "NOTE: The following settings remain modified:"
echo "  - Swap is still disabled"
echo "  - SELinux is still in permissive mode"
echo ""
echo "To re-enable swap, edit /etc/fstab and uncomment swap lines,"
echo "then run: sudo swapon -a"
echo ""
echo "To restore SELinux to enforcing mode:"
echo "  sudo setenforce 1"
echo "  sudo sed -i 's/^SELINUX=permissive$/SELINUX=enforcing/' /etc/selinux/config"
echo ""
echo "A system reboot is recommended to ensure all changes take effect."
read -p "Would you like to reboot now? (y/n): " REBOOT

if [ "$REBOOT" == "y" ] || [ "$REBOOT" == "Y" ]; then
    echo "Rebooting system in 5 seconds..."
    sleep 5
    reboot
else
    echo "Please reboot the system manually when convenient."
fi

echo ""
echo "=========================================="