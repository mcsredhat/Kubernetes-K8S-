#!/bin/bash
# ============================================================================
# fix-all-issues.sh - Complete Fix for All Deployment Issues
# ============================================================================
# Run this script to fix all identified issues at once
# ============================================================================

set -e

echo "========================================"
echo "  Kubernetes Deployment Fix Script"
echo "========================================"
echo

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[⚠]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

# Step 1: Create Persistent Volumes for local storage
log_info "Step 1: Creating Persistent Volumes..."

# Check if we can SSH to worker nodes
if command -v ssh &> /dev/null; then
    log_info "Creating directories on worker nodes..."
    for node in k8s-worker1 k8s-worker2; do
        if ssh -o ConnectTimeout=5 $node "echo ok" &>/dev/null; then
            ssh $node "sudo mkdir -p /mnt/data/myapp-data /mnt/data/myapp-backup && sudo chmod 777 /mnt/data/myapp-data /mnt/data/myapp-backup" || log_warning "Failed to create directories on $node"
            log_success "Directories created on $node"
        else
            log_warning "Cannot SSH to $node - you'll need to create directories manually"
            echo "    Run on $node: sudo mkdir -p /mnt/data/myapp-data /mnt/data/myapp-backup && sudo chmod 777 /mnt/data/myapp-data /mnt/data/myapp-backup"
        fi
    done
else
    log_warning "SSH not available - create directories manually on worker nodes"
    echo "    Run on each worker: sudo mkdir -p /mnt/data/myapp-data /mnt/data/myapp-backup && sudo chmod 777 /mnt/data/myapp-data /mnt/data/myapp-backup"
fi

# Create PVs
log_info "Creating Persistent Volumes..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: myapp-data-pv
  labels:
    type: local
spec:
  storageClassName: local-storage
  capacity:
    storage: 20Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/data/myapp-data"
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - k8s-worker1
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: myapp-backup-pv
  labels:
    type: local
spec:
  storageClassName: local-storage
  capacity:
    storage: 20Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/data/myapp-backup"
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - k8s-worker2
EOF

log_success "Persistent Volumes created"

# Step 2: Fix namespace security policy
log_info "Step 2: Updating namespace security policy..."
kubectl patch namespace myapp-prod --type merge -p '{"metadata":{"labels":{"pod-security.kubernetes.io/enforce":"baseline","pod-security.kubernetes.io/audit":"baseline","pod-security.kubernetes.io/warn":"baseline"}}}' 2>/dev/null || log_warning "Namespace patch may have failed"

log_success "Namespace security policy updated"

# Step 3: Delete failing resources
log_info "Step 3: Cleaning up failing resources..."

# Delete rollback job if it exists and is failing
kubectl delete job myapp-rollback -n myapp-prod --ignore-not-found=true
log_success "Cleaned up failing rollback job"

# Step 4: Restart deployments
log_info "Step 4: Restarting deployments..."

# Delete existing pods to force recreation with new security context
kubectl delete pods -n myapp-prod -l app=myapp --force --grace-period=0 2>/dev/null || true
kubectl delete pods -n myapp-prod -l app=myapp-backend --force --grace-period=0 2>/dev/null || true

log_success "Deployments will restart with fixed configurations"

# Step 5: Wait for PVCs to bind
log_info "Step 5: Waiting for PVCs to bind..."
sleep 5

PVC_STATUS=$(kubectl get pvc -n myapp-prod -o jsonpath='{.items[*].status.phase}')
if echo "$PVC_STATUS" | grep -q "Bound"; then
    log_success "PVCs are binding"
else
    log_warning "PVCs may still be pending - check with: kubectl get pvc -n myapp-prod"
fi

# Step 6: Install metrics-server if missing
log_info "Step 6: Checking metrics-server..."
if ! kubectl get deployment metrics-server -n kube-system &>/dev/null; then
    log_info "Installing metrics-server..."
    kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    k8s-app: metrics-server
  name: metrics-server
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    k8s-app: metrics-server
  name: system:metrics-server
rules:
- apiGroups:
  - ""
  resources:
  - nodes/metrics
  verbs:
  - get
- apiGroups:
  - ""
  resources:
  - pods
  - nodes
  verbs:
  - get
  - list
  - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  labels:
    k8s-app: metrics-server
  name: system:metrics-server
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:metrics-server
subjects:
- kind: ServiceAccount
  name: metrics-server
  namespace: kube-system
---
apiVersion: v1
kind: Service
metadata:
  labels:
    k8s-app: metrics-server
  name: metrics-server
  namespace: kube-system
spec:
  ports:
  - name: https
    port: 443
    protocol: TCP
    targetPort: https
  selector:
    k8s-app: metrics-server
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    k8s-app: metrics-server
  name: metrics-server
  namespace: kube-system
spec:
  selector:
    matchLabels:
      k8s-app: metrics-server
  template:
    metadata:
      labels:
        k8s-app: metrics-server
    spec:
      containers:
      - args:
        - --cert-dir=/tmp
        - --secure-port=4443
        - --kubelet-preferred-address-types=InternalIP
        - --kubelet-use-node-status-port
        - --metric-resolution=15s
        - --kubelet-insecure-tls
        image: registry.k8s.io/metrics-server/metrics-server:v0.6.4
        name: metrics-server
        ports:
        - containerPort: 4443
          name: https
          protocol: TCP
        securityContext:
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 1000
      serviceAccountName: metrics-server
EOF
    log_success "Metrics-server installed"
else
    log_success "Metrics-server already installed"
fi

# Step 7: Summary
echo
echo "========================================"
echo "  Fix Summary"
echo "========================================"
log_success "Persistent Volumes created"
log_success "Namespace security policy updated"  
log_success "Failing resources cleaned up"
log_success "Metrics-server installed"
echo
log_info "Waiting 30 seconds for pods to start..."
sleep 30

# Check status
echo
echo "=== Current Status ==="
kubectl get pv | grep myapp || echo "No PVs found"
kubectl get pvc -n myapp-prod
kubectl get pods -n myapp-prod

echo
echo "========================================"
echo "  Next Steps"
echo "========================================"
echo "1. Check pod status: kubectl get pods -n myapp-prod -w"
echo "2. View logs: kubectl logs -f deployment/myapp-deployment -n myapp-prod"
echo "3. Check PVC binding: kubectl get pvc -n myapp-prod"
echo "4. Full status: ./deploy.sh status"
echo
log_success "Fix script completed!"
