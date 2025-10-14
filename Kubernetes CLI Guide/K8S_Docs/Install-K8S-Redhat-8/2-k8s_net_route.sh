#!/bin/bash

# Kubernetes Cluster Network Configuration Script
# Configures routing for Tailscale network on RHEL nodes
# Run this script on ALL cluster nodes

set -e

echo "=========================================="
echo "Kubernetes Cluster Network Configuration"
echo "=========================================="

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root or with sudo"
    exit 1
fi

# Cluster node information
declare -A NODES=(
    ["master"]="100.124.179.28"
    ["worker1"]="100.110.147.24"
    ["worker2"]="100.72.236.100"
    ["worker3"]="100.121.197.110"
)

echo ""
echo "Detected nodes in cluster:"
for node in "${!NODES[@]}"; do
    echo "  $node: ${NODES[$node]}"
done
echo ""

# Detect current node
CURRENT_IP=""
CURRENT_ROLE=""

for node in "${!NODES[@]}"; do
    if ip addr | grep -q "${NODES[$node]}"; then
        CURRENT_IP="${NODES[$node]}"
        CURRENT_ROLE="$node"
        break
    fi
done

if [ -z "$CURRENT_IP" ]; then
    echo "WARNING: Could not auto-detect this node's IP."
    echo "Available IPs in cluster:"
    for node in "${!NODES[@]}"; do
        echo "  [$node] ${NODES[$node]}"
    done
    read -p "Enter this node's role (master/worker1/worker2/worker3): " CURRENT_ROLE
    CURRENT_IP="${NODES[$CURRENT_ROLE]}"
fi

echo "Configuring network for: $CURRENT_ROLE ($CURRENT_IP)"
echo ""

echo "[1/8] Checking Tailscale interface..."
# Detect Tailscale interface
TAILSCALE_IF=$(ip -o link show | grep -i tailscale | awk '{print $2}' | sed 's/:$//' | head -1)

if [ -z "$TAILSCALE_IF" ]; then
    echo "Tailscale interface not found. Checking for tailscale0..."
    TAILSCALE_IF="tailscale0"
fi

echo "Using Tailscale interface: $TAILSCALE_IF"

echo "[2/8] Configuring IP forwarding..."
# Enable IP forwarding
cat <<EOF > /etc/sysctl.d/99-k8s-network.conf
# Enable IP forwarding for Kubernetes
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

# Bridge netfilter settings
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1

# Disable source route verification (if needed)
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.$TAILSCALE_IF.rp_filter = 0
EOF

sysctl --system

echo "[3/8] Configuring firewall rules..."
# Configure firewalld to allow Tailscale traffic
if systemctl is-active --quiet firewalld; then
    echo "Configuring firewalld for Tailscale network..."
    
    # Add Tailscale interface to trusted zone
    firewall-cmd --permanent --zone=trusted --add-interface=$TAILSCALE_IF 2>/dev/null || true
    
    # Allow Tailscale subnet
    firewall-cmd --permanent --zone=trusted --add-source=100.64.0.0/10
    
    # Allow Kubernetes pod network
    firewall-cmd --permanent --zone=trusted --add-source=10.244.0.0/16
    
    # Ensure masquerading is enabled
    firewall-cmd --permanent --zone=public --add-masquerade
    firewall-cmd --permanent --zone=trusted --add-masquerade
    
    firewall-cmd --reload
    echo "Firewall configured successfully"
else
    echo "Firewalld not active, skipping firewall configuration"
fi

echo "[4/8] Adding static routes..."
# Add routes to other cluster nodes via Tailscale
for node in "${!NODES[@]}"; do
    if [ "$node" != "$CURRENT_ROLE" ]; then
        NODE_IP="${NODES[$node]}"
        
        # Remove existing route if present
        ip route del $NODE_IP 2>/dev/null || true
        
        # Add route via Tailscale interface
        echo "Adding route to $node ($NODE_IP)"
        ip route add $NODE_IP dev $TAILSCALE_IF 2>/dev/null || echo "  Route already exists"
    fi
done

echo "[5/8] Creating persistent route configuration..."
# Create NetworkManager dispatcher script for persistent routes
mkdir -p /etc/NetworkManager/dispatcher.d

cat <<'ROUTE_SCRIPT' > /etc/NetworkManager/dispatcher.d/99-k8s-routes.sh
#!/bin/bash
# Persistent routes for Kubernetes cluster

INTERFACE=$1
ACTION=$2

if [ "$ACTION" == "up" ]; then
    # Add routes when interface comes up
    TAILSCALE_IF=$(ip -o link show | grep -i tailscale | awk '{print $2}' | sed 's/:$//' | head -1)
    
    if [ -n "$TAILSCALE_IF" ]; then
ROUTE_SCRIPT

# Add route commands for each node
for node in "${!NODES[@]}"; do
    if [ "$node" != "$CURRENT_ROLE" ]; then
        echo "        ip route add ${NODES[$node]} dev \$TAILSCALE_IF 2>/dev/null || true" >> /etc/NetworkManager/dispatcher.d/99-k8s-routes.sh
    fi
done

cat <<'ROUTE_SCRIPT' >> /etc/NetworkManager/dispatcher.d/99-k8s-routes.sh
    fi
fi
ROUTE_SCRIPT

chmod +x /etc/NetworkManager/dispatcher.d/99-k8s-routes.sh

echo "[6/8] Updating /etc/hosts file..."
# Add entries to /etc/hosts for all nodes
cp /etc/hosts /etc/hosts.backup.$(date +%Y%m%d_%H%M%S)

# Remove old Kubernetes entries
sed -i '/# Kubernetes cluster nodes/,/# End Kubernetes cluster nodes/d' /etc/hosts

# Add new entries
cat <<EOF >> /etc/hosts

# Kubernetes cluster nodes
100.124.179.28  k8s-master master
100.110.147.24  k8s-worker1 worker1
100.72.236.100  k8s-worker2 worker2 k8s-worker2-node
100.121.197.110 k8s-worker3 worker3 k8s-worker3-node
# End Kubernetes cluster nodes
EOF

echo "[7/8] Verifying network connectivity..."
echo ""
echo "Testing connectivity to other nodes:"
for node in "${!NODES[@]}"; do
    if [ "$node" != "$CURRENT_ROLE" ]; then
        NODE_IP="${NODES[$node]}"
        echo -n "  Testing $node ($NODE_IP)... "
        if ping -c 2 -W 2 $NODE_IP >/dev/null 2>&1; then
            echo "OK"
        else
            echo "FAILED (may need to wait for Tailscale sync)"
        fi
    fi
done

echo ""
echo "[8/8] Configuring Kubernetes to use Tailscale network..."

# If this is the master node during cluster init
if [ "$CURRENT_ROLE" == "master" ]; then
    echo ""
    echo "For master node initialization, use:"
    echo "  sudo kubeadm init --apiserver-advertise-address=$CURRENT_IP --pod-network-cidr=10.244.0.0/16"
    echo ""
fi

# If this is a worker node
if [[ "$CURRENT_ROLE" == worker* ]]; then
    echo ""
    echo "For worker node, when joining use the master IP: 100.77.67.87"
    echo "  sudo kubeadm join 100.77.67.87:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>"
    echo ""
fi

echo ""
echo "=========================================="
echo "Network Configuration Complete!"
echo "=========================================="
echo ""
echo "Current node: $CURRENT_ROLE ($CURRENT_IP)"
echo "Tailscale interface: $TAILSCALE_IF"
echo ""
echo "Configuration summary:"
echo "  ✓ IP forwarding enabled"
echo "  ✓ Firewall rules configured"
echo "  ✓ Static routes added"
echo "  ✓ Persistent routes configured"
echo "  ✓ /etc/hosts updated"
echo ""
echo "Network routes:"
ip route | grep "100\." || echo "No Tailscale routes found"
echo ""
echo "Active Kubernetes networking should now work across all nodes"
echo "using the Tailscale 100.x.x.x addresses."
echo ""
echo "=========================================="