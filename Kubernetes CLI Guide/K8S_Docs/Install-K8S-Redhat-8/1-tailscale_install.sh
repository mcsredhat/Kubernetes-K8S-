#!/bin/bash

# Tailscale Installation Script for RHEL 8/9
# Based on: https://tailscale.com/kb/1046/install-rhel-8
# Run this script with sudo privileges

set -e

echo "=========================================="
echo "Tailscale Installation for RHEL"
echo "=========================================="

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root or with sudo"
    exit 1
fi

# Detect RHEL version
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_VERSION=$VERSION_ID
    OS_MAJOR_VERSION=${VERSION_ID%%.*}
    echo "Detected: $NAME $VERSION_ID"
else
    echo "Cannot detect OS version"
    exit 1
fi

# Verify RHEL 8 or 9
if [[ "$OS_MAJOR_VERSION" != "8" && "$OS_MAJOR_VERSION" != "9" ]]; then
    echo "This script is for RHEL 8 or 9 only"
    exit 1
fi

echo ""
echo "[1/5] Configuring Tailscale repository..."

# Add Tailscale repository
cat <<EOF > /etc/yum.repos.d/tailscale.repo
[tailscale-stable]
name=Tailscale stable
baseurl=https://pkgs.tailscale.com/stable/rhel/$OS_MAJOR_VERSION/\$basearch
enabled=1
type=rpm
repo_gpgcheck=1
gpgcheck=0
gpgkey=https://pkgs.tailscale.com/stable/rhel/$OS_MAJOR_VERSION/repo.gpg
EOF

echo "Repository configured successfully"

echo ""
echo "[2/5] Installing Tailscale..."
dnf install -y tailscale

echo ""
echo "[3/5] Enabling and starting Tailscale service..."
systemctl enable --now tailscaled

echo ""
echo "[4/5] Configuring firewall (if active)..."
if systemctl is-active --quiet firewalld; then
    echo "Configuring firewalld for Tailscale..."
    
    # Allow Tailscale port
    firewall-cmd --permanent --add-port=41641/udp
    
    # Add Tailscale interface to trusted zone (will be added after connection)
    firewall-cmd --permanent --zone=trusted --add-source=100.64.0.0/10
    
    firewall-cmd --reload
    echo "Firewall configured successfully"
else
    echo "Firewalld not active, skipping firewall configuration"
fi

echo ""
echo "[5/5] Checking Tailscale status..."
systemctl status tailscaled --no-pager

echo ""
echo "=========================================="
echo "Tailscale Installation Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Connect to Tailscale network:"
echo "   sudo tailscale up"
echo ""
echo "2. (Optional) Set a hostname for this node:"
echo "   sudo tailscale up --hostname=k8s-master"
echo "   # or k8s-worker1, k8s-worker2, etc."
echo ""
echo "3. (Optional) Enable subnet routing (for Kubernetes):"
echo "   sudo tailscale up --advertise-routes=10.244.0.0/16"
echo ""
echo "4. (Optional) Accept routes from other nodes:"
echo "   sudo tailscale up --accept-routes"
echo ""
echo "5. Check connection status:"
echo "   sudo tailscale status"
echo ""
echo "6. Get your Tailscale IP:"
echo "   sudo tailscale ip -4"
echo ""
echo "7. (Optional) Enable IP forwarding for routing:"
echo "   echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf"
echo "   echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.conf"
echo "   sudo sysctl -p"
echo ""
echo "=========================================="
echo ""
read -p "Would you like to connect to Tailscale now? (y/n): " CONNECT

if [ "$CONNECT" == "y" ] || [ "$CONNECT" == "Y" ]; then
    echo ""
    read -p "Enter hostname for this node (optional, press Enter to skip): " HOSTNAME
    
    if [ -n "$HOSTNAME" ]; then
        echo "Connecting to Tailscale with hostname: $HOSTNAME"
        tailscale up --hostname=$HOSTNAME
    else
        echo "Connecting to Tailscale..."
        tailscale up
    fi
    
    echo ""
    echo "Tailscale connection initiated!"
    echo "Follow the link above to authenticate in your browser."
    echo ""
    
    # Wait a moment for connection
    sleep 5
    
    echo "Current Tailscale status:"
    tailscale status
    echo ""
    echo "Your Tailscale IP address:"
    tailscale ip -4
    echo ""
else
    echo ""
    echo "You can connect later by running: sudo tailscale up"
    echo ""
fi

echo "=========================================="
echo "Installation and setup complete!"
echo "=========================================="