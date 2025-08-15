# Kubernetes Storage Classes - Complete Guide

Storage Classes are the foundation of dynamic storage provisioning in Kubernetes, providing an abstraction layer between applications and underlying storage infrastructure. They enable automatic volume creation, configuration, and lifecycle management across different environments.

## Table of Contents
1. [Core Concepts](#core-concepts)
2. [Creating and Managing Storage Classes](#creating-and-managing-storage-classes)
3. [Cloud Provider Storage Classes](#cloud-provider-storage-classes)
4. [Storage Class Parameters](#storage-class-parameters)
5. [Volume Binding Modes](#volume-binding-modes)
6. [Reclaim Policies](#reclaim-policies)
7. [Advanced Configuration](#advanced-configuration)
8. [Troubleshooting](#troubleshooting)
9. [Best Practices](#best-practices)
10. [Real-World Examples](#real-world-examples)

---

## 1. Core Concepts

### What are Storage Classes?
Storage Classes define the "classes" of storage available in a cluster. They act as templates for dynamic volume provisioning, specifying:
- **Provisioner**: Which storage backend to use
- **Parameters**: Storage-specific configuration options
- **Reclaim Policy**: What happens to volumes when claims are deleted
- **Volume Binding Mode**: When volume binding and provisioning occurs

### Key Components
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: my-storage-class
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp3
  fsType: ext4
  encrypted: "true"
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
mountOptions:
  - debug
  - rsize=1048576
```

---

## 2. Creating and Managing Storage Classes

### Basic Storage Class Creation

```bash
# Create a basic Storage Class for local storage
kubectl create -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
EOF
```

### Setting Default Storage Class

```bash
# Set a Storage Class as default
kubectl patch storageclass standard -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Remove default annotation
kubectl patch storageclass standard -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

# View current default Storage Class
kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}'
```

### Management Commands

```bash
# List all Storage Classes with detailed information
kubectl get storageclass -o wide

# Show Storage Class with custom columns
kubectl get storageclass -o custom-columns=NAME:.metadata.name,PROVISIONER:.provisioner,RECLAIM:.reclaimPolicy,BINDING:.volumeBindingMode

# Describe Storage Class with events
kubectl describe storageclass my-storage-class

# Export Storage Class configuration
kubectl get storageclass my-storage-class -o yaml > my-storage-class.yaml

# Validate Storage Class before applying
kubectl apply --dry-run=client -f my-storage-class.yaml

# Delete Storage Class (safe - doesn't affect existing PVs)
kubectl delete storageclass my-storage-class
```

---

## 3. Cloud Provider Storage Classes

### AWS EBS Storage Classes

```yaml
# High-performance SSD (gp3)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: aws-gp3-fast
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
  fsType: ext4
  encrypted: "true"
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Delete
---
# Cost-optimized HDD
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: aws-st1-cold
provisioner: ebs.csi.aws.com
parameters:
  type: st1
  fsType: ext4
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Delete
---
# High IOPS SSD for databases
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: aws-io2-database
provisioner: ebs.csi.aws.com
parameters:
  type: io2
  iops: "10000"
  fsType: ext4
  encrypted: "true"
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Retain
```

### Google Cloud Storage Classes

```yaml
# Standard SSD
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gcp-ssd-standard
provisioner: pd.csi.storage.gke.io
parameters:
  type: pd-ssd
  replication-type: regional-pd
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Delete
---
# Balanced performance/cost
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gcp-balanced
provisioner: pd.csi.storage.gke.io
parameters:
  type: pd-balanced
  provisioned-iops-on-create: "3000"
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
---
# High-performance NVMe
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gcp-extreme
provisioner: pd.csi.storage.gke.io
parameters:
  type: pd-extreme
  provisioned-iops-on-create: "10000"
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

### Azure Disk Storage Classes

```yaml
# Premium SSD
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azure-premium-ssd
provisioner: disk.csi.azure.com
parameters:
  skuName: Premium_LRS
  cachingMode: ReadOnly
  fsType: ext4
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Delete
---
# Ultra Disk for extreme performance
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azure-ultra-disk
provisioner: disk.csi.azure.com
parameters:
  skuName: UltraSSD_LRS
  diskIOPSReadWrite: "20000"
  diskMBpsReadWrite: "1000"
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

### On-Premises Storage Classes

```yaml
# NFS Storage Class
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-storage
provisioner: nfs.csi.k8s.io
parameters:
  server: nfs-server.example.com
  share: /shared/volumes
  mountPermissions: "0755"
volumeBindingMode: Immediate
reclaimPolicy: Delete
---
# Ceph RBD Storage Class
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ceph-rbd
provisioner: rbd.csi.ceph.com
parameters:
  clusterID: ceph-cluster-id
  pool: rbd-pool
  imageFormat: "2"
  imageFeatures: layering
  csi.storage.k8s.io/provisioner-secret-name: ceph-csi-rbd-secret
  csi.storage.k8s.io/provisioner-secret-namespace: default
  csi.storage.k8s.io/node-stage-secret-name: ceph-csi-rbd-secret
  csi.storage.k8s.io/node-stage-secret-namespace: default
volumeBindingMode: Immediate
reclaimPolicy: Delete
allowVolumeExpansion: true
---
# Local Path Storage Class
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path
provisioner: rancher.io/local-path
parameters:
  nodePath: /opt/local-path-provisioner
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
```

---

## 4. Storage Class Parameters

### Common Parameters by Provisioner

| Provisioner | Parameter | Description | Example Values |
|-------------|-----------|-------------|----------------|
| `ebs.csi.aws.com` | `type` | EBS volume type | `gp2`, `gp3`, `io1`, `io2`, `st1`, `sc1` |
| | `iops` | Provisioned IOPS | `100-64000` |
| | `throughput` | Throughput (MB/s) | `125-1000` |
| | `encrypted` | Enable encryption | `true`, `false` |
| | `kmsKeyId` | KMS key for encryption | `arn:aws:kms:...` |
| `pd.csi.storage.gke.io` | `type` | Disk type | `pd-standard`, `pd-ssd`, `pd-balanced` |
| | `replication-type` | Replication | `none`, `regional-pd` |
| | `provisioned-iops-on-create` | IOPS | `10000` |
| `disk.csi.azure.com` | `skuName` | Disk SKU | `Standard_LRS`, `Premium_LRS`, `UltraSSD_LRS` |
| | `cachingMode` | Caching mode | `None`, `ReadOnly`, `ReadWrite` |
| | `diskIOPSReadWrite` | IOPS limit | `2-160000` |

### Parameter Validation Script

```bash
#!/bin/bash
# validate-storage-class.sh - Validates Storage Class parameters

validate_aws_ebs() {
    local type=$1
    local iops=$2
    local throughput=$3
    
    case $type in
        gp3)
            if [[ $iops -lt 3000 || $iops -gt 16000 ]]; then
                echo "❌ GP3 IOPS must be between 3000-16000, got: $iops"
                return 1
            fi
            if [[ $throughput -lt 125 || $throughput -gt 1000 ]]; then
                echo "❌ GP3 throughput must be between 125-1000 MB/s, got: $throughput"
                return 1
            fi
            ;;
        io2)
            if [[ $iops -lt 100 || $iops -gt 64000 ]]; then
                echo "❌ IO2 IOPS must be between 100-64000, got: $iops"
                return 1
            fi
            ;;
    esac
    echo "✅ Parameters valid for $type"
}

# Usage example
validate_aws_ebs "gp3" "3000" "125"
```

---

## 5. Volume Binding Modes

### Immediate vs WaitForFirstConsumer

```yaml
# Immediate binding - PV created immediately when PVC is created
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: immediate-binding
provisioner: ebs.csi.aws.com
volumeBindingMode: Immediate
parameters:
  type: gp3
---
# WaitForFirstConsumer - PV created when pod is scheduled
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: wait-for-consumer
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
parameters:
  type: gp3
```

### Demonstration of Binding Modes

```bash
# Create test PVCs with different binding modes
kubectl create -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: immediate-pvc
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
  storageClassName: immediate-binding
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: wait-pvc
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
  storageClassName: wait-for-consumer
EOF

# Check PVC status
kubectl get pvc
# immediate-pvc should be Bound
# wait-pvc should be Pending

# Create pod to trigger binding for wait-for-consumer
kubectl create -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  containers:
  - name: test
    image: nginx
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: wait-pvc
EOF

# Now wait-pvc should become Bound
kubectl get pvc wait-pvc
```

---

## 6. Reclaim Policies

### Understanding Reclaim Policies

```yaml
# Delete - PV is deleted when PVC is deleted (default)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: delete-policy
provisioner: ebs.csi.aws.com
reclaimPolicy: Delete
parameters:
  type: gp3
---
# Retain - PV is retained when PVC is deleted
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: retain-policy
provisioner: ebs.csi.aws.com
reclaimPolicy: Retain
parameters:
  type: gp3
```

### Reclaim Policy Demo

```bash
#!/bin/bash
# reclaim-policy-demo.sh

echo "🔄 Demonstrating Reclaim Policies"

# Create Storage Classes with different reclaim policies
kubectl create -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: delete-sc
provisioner: kubernetes.io/no-provisioner
reclaimPolicy: Delete
volumeBindingMode: Immediate
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: retain-sc
provisioner: kubernetes.io/no-provisioner
reclaimPolicy: Retain
volumeBindingMode: Immediate
EOF

# Create manual PVs for demonstration
kubectl create -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: delete-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: delete-sc
  hostPath:
    path: /tmp/delete-data
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: retain-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: retain-sc
  hostPath:
    path: /tmp/retain-data
EOF

# Create PVCs
kubectl create -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: delete-pvc
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
  storageClassName: delete-sc
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: retain-pvc
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
  storageClassName: retain-sc
EOF

echo "📊 PVs before PVC deletion:"
kubectl get pv

echo "🗑️  Deleting PVCs..."
kubectl delete pvc delete-pvc retain-pvc

echo "📊 PVs after PVC deletion:"
kubectl get pv
echo "Notice: delete-pv should be gone, retain-pv should be Available"

# Cleanup
kubectl delete pv retain-pv
kubectl delete sc delete-sc retain-sc
```

---

## 7. Advanced Configuration

### Volume Expansion

```yaml
# Storage Class with volume expansion enabled
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: expandable-storage
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
```

### Volume Expansion Demo

```bash
# Create expandable PVC
kubectl create -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: expandable-pvc
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
  storageClassName: expandable-storage
EOF

# Create pod using the PVC
kubectl create -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: expansion-test
spec:
  containers:
  - name: test
    image: nginx
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: expandable-pvc
EOF

# Check initial size
kubectl exec expansion-test -- df -h /data

# Expand the volume
kubectl patch pvc expandable-pvc -p '{"spec":{"resources":{"requests":{"storage":"2Gi"}}}}'

# Check expansion status
kubectl describe pvc expandable-pvc

# Verify new size (may require pod restart)
kubectl delete pod expansion-test
kubectl create -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: expansion-test
spec:
  containers:
  - name: test
    image: nginx
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: expandable-pvc
EOF

kubectl exec expansion-test -- df -h /data
```

### Mount Options

```yaml
# Storage Class with custom mount options
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: optimized-storage
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
mountOptions:
  - rsize=1048576
  - wsize=1048576
  - hard
  - intr
  - timeo=600
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
```

### Topology Constraints

```yaml
# Storage Class with topology constraints
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: zone-specific
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
volumeBindingMode: WaitForFirstConsumer
allowedTopologies:
- matchLabelExpressions:
  - key: topology.ebs.csi.aws.com/zone
    values:
    - us-west-2a
    - us-west-2b
```

---

## 8. Troubleshooting

### Common Issues and Solutions

#### Issue 1: PVC Stuck in Pending State

```bash
# Diagnose pending PVC
kubectl describe pvc my-pvc

# Common causes and solutions:
echo "🔍 Troubleshooting Pending PVC:"
echo "1. Check if Storage Class exists:"
kubectl get storageclass

echo "2. Verify provisioner is running:"
kubectl get pods -n kube-system | grep provisioner

echo "3. Check for resource constraints:"
kubectl describe node

echo "4. Examine events:"
kubectl get events --sort-by=.metadata.creationTimestamp
```

#### Issue 2: Volume Mount Failures

```bash
# Debug volume mount issues
troubleshoot_mount() {
    local pod_name=$1
    echo "🔧 Debugging mount issues for pod: $pod_name"
    
    # Check pod events
    kubectl describe pod $pod_name
    
    # Check PVC status
    local pvc_name=$(kubectl get pod $pod_name -o jsonpath='{.spec.volumes[0].persistentVolumeClaim.claimName}')
    kubectl describe pvc $pvc_name
    
    # Check PV status
    local pv_name=$(kubectl get pvc $pvc_name -o jsonpath='{.spec.volumeName}')
    kubectl describe pv $pv_name
    
    # Check node capacity
    local node_name=$(kubectl get pod $pod_name -o jsonpath='{.spec.nodeName}')
    kubectl describe node $node_name | grep -A 10 "Allocated resources"
}

# Usage
# troubleshoot_mount "my-pod"
```

#### Issue 3: Storage Class Parameter Errors

```bash
# Validate Storage Class configuration
validate_storage_class() {
    local sc_name=$1
    echo "✅ Validating Storage Class: $sc_name"
    
    # Check if Storage Class exists
    if ! kubectl get storageclass $sc_name &>/dev/null; then
        echo "❌ Storage Class $sc_name not found"
        return 1
    fi
    
    # Get provisioner
    local provisioner=$(kubectl get storageclass $sc_name -o jsonpath='{.provisioner}')
    echo "📦 Provisioner: $provisioner"
    
    # Check if CSI driver is running
    if [[ $provisioner == *"csi"* ]]; then
        local driver_name=$(echo $provisioner | sed 's/\.csi\..*/.csi/')
        kubectl get csidriver $driver_name &>/dev/null || echo "⚠️  CSI driver not found"
    fi
    
    # Validate parameters
    kubectl get storageclass $sc_name -o jsonpath='{.parameters}' | jq .
}
```

### Diagnostic Script

```bash
#!/bin/bash
# storage-diagnostics.sh - Comprehensive storage diagnostics

echo "🏥 Kubernetes Storage Health Check"
echo "=================================="

# Check Storage Classes
echo "📚 Storage Classes:"
kubectl get storageclass -o custom-columns=NAME:.metadata.name,PROVISIONER:.provisioner,DEFAULT:.metadata.annotations.storageclass\.kubernetes\.io/is-default-class

# Check CSI Drivers
echo -e "\n🔌 CSI Drivers:"
kubectl get csidriver

# Check PVCs and their status
echo -e "\n📋 Persistent Volume Claims:"
kubectl get pvc --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATUS:.status.phase,VOLUME:.spec.volumeName,CAPACITY:.status.capacity.storage,STORAGECLASS:.spec.storageClassName

# Check PVs and their status
echo -e "\n💾 Persistent Volumes:"
kubectl get pv -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,CLAIM:.spec.claimRef.name,CAPACITY:.spec.capacity.storage,STORAGECLASS:.spec.storageClassName,REASON:.status.reason

# Check for storage-related events
echo -e "\n📝 Recent Storage Events:"
kubectl get events --all-namespaces --field-selector type=Warning | grep -i -E "(volume|storage|pvc|pv)" | tail -10

# Check node storage capacity
echo -e "\n💽 Node Storage Capacity:"
kubectl top nodes

# Check for failed pods due to storage issues
echo -e "\n🚨 Pods with Storage Issues:"
kubectl get pods --all-namespaces --field-selector status.phase=Pending -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,REASON:.status.containerStatuses[0].state.waiting.reason | grep -i -E "(volume|mount)"

echo -e "\n✅ Storage diagnostics complete!"
```

---

## 9. Best Practices

### Performance Optimization

```yaml
# High-performance database storage
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: database-storage
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: ebs.csi.aws.com
parameters:
  type: io2
  iops: "10000"
  fsType: ext4
  encrypted: "true"
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Retain
mountOptions:
  - noatime
  - discard
```

### Cost Optimization

```yaml
# Cost-optimized storage for logs and backups
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: cost-optimized
provisioner: ebs.csi.aws.com
parameters:
  type: st1  # Throughput Optimized HDD
  fsType: ext4
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
allowVolumeExpansion: true
```

### Multi-Environment Storage Classes

```yaml
# Development environment
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: dev-storage
  labels:
    environment: development
provisioner: ebs.csi.aws.com
parameters:
  type: gp2
  fsType: ext4
reclaimPolicy: Delete
volumeBindingMode: Immediate
---
# Production environment
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: prod-storage
  labels:
    environment: production
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
  fsType: ext4
  encrypted: "true"
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

### Storage Class Selection Script

```bash
#!/bin/bash
# storage-selector.sh - Intelligent Storage Class selection

select_storage_class() {
    local workload_type=$1
    local environment=$2
    local performance_tier=$3
    
    echo "🎯 Selecting optimal Storage Class..."
    echo "Workload: $workload_type | Environment: $environment | Performance: $performance_tier"
    
    case $workload_type in
        "database")
            case $performance_tier in
                "high") echo "Recommended: database-high-perf (io2, 10000 IOPS)" ;;
                "medium") echo "Recommended: database-medium-perf (gp3, 3000 IOPS)" ;;
                "low") echo "Recommended: database-low-perf (gp2)" ;;
            esac
            ;;
        "web")
            case $environment in
                "prod") echo "Recommended: web-prod (gp3, encrypted)" ;;
                "dev") echo "Recommended: web-dev (gp2)" ;;
            esac
            ;;
        "analytics")
            echo "Recommended: analytics-storage (st1, large capacity)"
            ;;
        "logs")
            echo "Recommended: logs-storage (sc1, cold storage)"
            ;;
        *)
            echo "Recommended: standard (gp3, balanced)"
            ;;
    esac
}

# Interactive selection
echo "Storage Class Selector"
echo "====================="
read -p "Workload type (database/web/analytics/logs): " workload
read -p "Environment (dev/staging/prod): " env
read -p "Performance tier (low/medium/high): " perf

select_storage_class $workload $env $perf
```

---

## 10. Real-World Examples

### E-Commerce Platform Storage Architecture

```yaml
# Frontend web servers - fast, deletable
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: web-frontend
  labels:
    tier: frontend
    app: ecommerce
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "3000"
  fsType: ext4
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
allowVolumeExpansion: true
---
# Database storage - high performance, retained
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: database-primary
  labels:
    tier: database
    app: ecommerce
provisioner: ebs.csi.aws.com
parameters:
  type: io2
  iops: "20000"
  fsType: ext4
  encrypted: "true"
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain
allowVolumeExpansion: true
mountOptions:
  - noatime
---
# Log aggregation - cost-optimized
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: logs-aggregation
  labels:
    tier: logging
    app: ecommerce
provisioner: ebs.csi.aws.com
parameters:
  type: st1
  fsType: ext4
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
allowVolumeExpansion: true
```

### Multi-Cloud Storage Strategy

```bash
#!/bin/bash
# multi-cloud-setup.sh - Deploy storage classes across cloud providers

setup_aws_storage() {
    echo "☁️  Setting up AWS Storage Classes..."
    kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: aws-general
  labels:
    cloud-provider: aws
    performance: standard
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
  fsType: ext4
  encrypted: "true"
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
allowVolumeExpansion: true
EOF
}

setup_gcp_storage() {
    echo "☁️  Setting up GCP Storage Classes..."
    kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gcp-general
  labels:
    cloud-provider: gcp
    performance: standard
provisioner: pd.csi.storage.gke.io
parameters:
  type: pd-ssd
  replication-type: regional-pd
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
allowVolumeExpansion: true
EOF
}

setup_azure_storage() {
    echo "☁️  Setting up Azure Storage Classes..."
    kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azure-general
  labels:
    cloud-provider: azure
    performance: standard
provisioner: disk.csi.azure.com
parameters:
  skuName: Premium_LRS
  cachingMode: ReadOnly
  fsType: ext4
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
allowVolumeExpansion: true
EOF
}

# Detect cloud provider and setup appropriate storage
detect_and_setup() {
    echo "🔍 Detecting cloud provider..."
    
    # Check for AWS
    if kubectl get nodes -o jsonpath='{.items[0].spec.providerID}' | grep -q "aws"; then
        echo "✅ AWS detected"
        setup_aws_storage
    # Check for GCP
    elif kubectl get nodes -o jsonpath='{.items[0].spec.providerID}' | grep -q "gce"; then
        echo "✅ GCP detected"
        setup_gcp_storage
    # Check for Azure
    elif kubectl get nodes -o jsonpath='{.items[0].spec.providerID}' | grep -q "azure"; then
        echo "✅ Azure detected"
        setup_azure_storage
    else
        echo "⚠️  Cloud provider not detected, using local storage"
        setup_local_storage
    fi
}

setup_local_storage() {
    echo "💽 Setting up local storage classes..."
    kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-general
  labels:
    cloud-provider: local
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
EOF
}

# Run setup
detect_and_setup
```

### Disaster Recovery Storage Classes

```yaml
# Primary storage with snapshots enabled
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: disaster-recovery-primary
  labels:
    backup-enabled: "true"
    tier: primary
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "3000"
  fsType: ext4
  encrypted: "true"
  # Enable snapshots for backup
  csi.storage.k8s.io/snapshotter-secret-name: ebs-snapshotter-secret
  csi.storage.k8s.io/snapshotter-secret-namespace: kube-system
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain
allowVolumeExpansion: true
---
# Cross-region backup storage
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: disaster-recovery-backup
  labels:
    backup-enabled: "true"
    tier: backup
provisioner: ebs.csi.aws.com
parameters:
  type: sc1  # Cold HDD for cost-effective backup
  fsType: ext4
  encrypted: "true"
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain
allowVolumeExpansion: true
```

### Storage Monitoring and Metrics

```yaml
# Storage Class with monitoring labels
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: monitored-storage
  labels:
    monitoring: "enabled"
    alerting: "enabled"
    cost-tracking: "enabled"
  annotations:
    cost-center: "engineering"
    team: "platform"
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "3000"
  fsType: ext4
  encrypted: "true"
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
allowVolumeExpansion: true
```

### Comprehensive Storage Benchmarking Tool

```bash
#!/bin/bash
# advanced-storage-benchmark.sh - Comprehensive storage performance testing

set -euo pipefail

# Configuration
BENCHMARK_NAMESPACE="storage-benchmark"
TEST_SIZE="1Gi"
BLOCK_SIZES=("4k" "64k" "1M")
TEST_TYPES=("seq-read" "seq-write" "rand-read" "rand-write")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Setup benchmark environment
setup_benchmark_env() {
    log "Setting up benchmark environment..."
    
    # Create namespace if it doesn't exist
    kubectl create namespace $BENCHMARK_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # Apply network policies for isolation
    kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: benchmark-isolation
  namespace: $BENCHMARK_NAMESPACE
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  egress:
  - {}
EOF
}

# Create test Storage Class
create_test_storage_class() {
    local sc_name=$1
    local provisioner=${2:-"ebs.csi.aws.com"}
    local type=${3:-"gp3"}
    local iops=${4:-"3000"}
    
    log "Creating test Storage Class: $sc_name"
    
    kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: $sc_name
  namespace: $BENCHMARK_NAMESPACE
  labels:
    benchmark: "true"
provisioner: $provisioner
parameters:
  type: $type
  iops: "$iops"
  fsType: ext4
  encrypted: "true"
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
allowVolumeExpansion: true
EOF
}

# Run FIO benchmark
run_fio_benchmark() {
    local sc_name=$1
    local test_name=$2
    local block_size=$3
    local test_type=$4
    
    log "Running FIO benchmark: $test_name ($test_type, $block_size)"
    
    # Create PVC
    kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: fio-pvc-$test_name
  namespace: $BENCHMARK_NAMESPACE
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: $TEST_SIZE
  storageClassName: $sc_name
EOF

    # Wait for PVC to be bound
    kubectl wait --for=condition=bound pvc/fio-pvc-$test_name -n $BENCHMARK_NAMESPACE --timeout=300s

    # Create FIO job
    local fio_args=""
    case $test_type in
        "seq-read")
            fio_args="--rw=read --bs=$block_size"
            ;;
        "seq-write")
            fio_args="--rw=write --bs=$block_size"
            ;;
        "rand-read")
            fio_args="--rw=randread --bs=$block_size"
            ;;
        "rand-write")
            fio_args="--rw=randwrite --bs=$block_size"
            ;;
    esac

    kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: fio-job-$test_name
  namespace: $BENCHMARK_NAMESPACE
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: fio
        image: wallnerryan/fio-tools:3.16
        command: ["/bin/sh", "-c"]
        args:
        - |
          echo "Starting FIO benchmark: $test_type with $block_size blocks"
          echo "=============================================="
          fio --name=$test_type \\
              --filename=/data/testfile \\
              --size=900M \\
              --time_based \\
              --runtime=30 \\
              --ioengine=libaio \\
              --direct=1 \\
              --iodepth=32 \\
              --numjobs=1 \\
              $fio_args \\
              --output-format=json \\
              --output=/tmp/results.json
          echo "Results:"
          cat /tmp/results.json | jq '.jobs[0].read + .jobs[0].write'
        volumeMounts:
        - name: test-volume
          mountPath: /data
        resources:
          requests:
            memory: "256Mi"
            cpu: "500m"
          limits:
            memory: "512Mi"
            cpu: "1000m"
      volumes:
      - name: test-volume
        persistentVolumeClaim:
          claimName: fio-pvc-$test_name
EOF

    # Wait for job completion
    kubectl wait --for=condition=complete job/fio-job-$test_name -n $BENCHMARK_NAMESPACE --timeout=600s

    # Get results
    local results=$(kubectl logs job/fio-job-$test_name -n $BENCHMARK_NAMESPACE)
    echo "$results" > "benchmark-results-$test_name-$test_type-$block_size.txt"
    
    success "Benchmark completed: $test_name ($test_type, $block_size)"
    
    # Cleanup job and PVC
    kubectl delete job fio-job-$test_name -n $BENCHMARK_NAMESPACE
    kubectl delete pvc fio-pvc-$test_name -n $BENCHMARK_NAMESPACE
}

# Generate benchmark report
generate_report() {
    local report_file="storage-benchmark-report-$(date +%Y%m%d-%H%M%S).html"
    
    log "Generating benchmark report: $report_file"
    
    cat > "$report_file" <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Kubernetes Storage Benchmark Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 20px; border-radius: 5px; }
        .result { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .metrics { display: flex; justify-content: space-between; }
        .metric { text-align: center; padding: 10px; background-color: #f9f9f9; border-radius: 3px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🚀 Kubernetes Storage Benchmark Report</h1>
        <p>Generated on: $(date)</p>
        <p>Cluster: $(kubectl config current-context)</p>
    </div>
EOF

    # Process benchmark results
    for result_file in benchmark-results-*.txt; do
        if [[ -f "$result_file" ]]; then
            echo "    <div class='result'>" >> "$report_file"
            echo "        <h3>$(basename "$result_file" .txt)</h3>" >> "$report_file"
            echo "        <pre>$(cat "$result_file")</pre>" >> "$report_file"
            echo "    </div>" >> "$report_file"
        fi
    done

    cat >> "$report_file" <<EOF
</body>
</html>
EOF

    success "Report generated: $report_file"
}

# Main benchmark execution
main() {
    log "🚀 Starting Advanced Storage Benchmark"
    
    setup_benchmark_env
    
    # List of Storage Classes to test
    declare -A storage_classes=(
        ["gp3-standard"]="ebs.csi.aws.com gp3 3000"
        ["gp3-high-iops"]="ebs.csi.aws.com gp3 10000"
        ["io2-ultra"]="ebs.csi.aws.com io2 20000"
    )
    
    # Create and test each Storage Class
    for sc_name in "${!storage_classes[@]}"; do
        IFS=' ' read -r provisioner type iops <<< "${storage_classes[$sc_name]}"
        
        log "Testing Storage Class: $sc_name"
        create_test_storage_class "$sc_name" "$provisioner" "$type" "$iops"
        
        # Run benchmarks for different block sizes and test types
        for block_size in "${BLOCK_SIZES[@]}"; do
            for test_type in "${TEST_TYPES[@]}"; do
                run_fio_benchmark "$sc_name" "$sc_name" "$block_size" "$test_type"
                sleep 10  # Cool down period
            done
        done
        
        # Cleanup Storage Class
        kubectl delete storageclass "$sc_name" --ignore-not-found=true
    done
    
    generate_report
    
    # Cleanup namespace
    kubectl delete namespace $BENCHMARK_NAMESPACE --ignore-not-found=true
    
    success "✅ Storage benchmark completed successfully!"
    warning "⚠️  Remember to review the generated report and clean up any remaining resources"
}

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

### Storage Lifecycle Management

```bash
#!/bin/bash
# storage-lifecycle-manager.sh - Automated storage lifecycle management

# Configuration
RETENTION_DAYS=30
BACKUP_RETENTION_DAYS=90
LOG_FILE="/var/log/storage-lifecycle.log"

log_message() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Identify orphaned PVs
find_orphaned_volumes() {
    log_message "🔍 Scanning for orphaned volumes..."
    
    kubectl get pv -o json | jq -r '
        .items[] | 
        select(.status.phase == "Available" and .spec.claimRef != null) |
        select(
            (now - (.metadata.creationTimestamp | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime)) 
            > ('"$RETENTION_DAYS"' * 86400)
        ) |
        .metadata.name
    ' > orphaned_volumes.txt
    
    local count=$(wc -l < orphaned_volumes.txt)
    log_message "Found $count orphaned volumes older than $RETENTION_DAYS days"
}

# Create volume snapshots for backup
create_volume_snapshots() {
    log_message "📸 Creating volume snapshots for backup..."
    
    # Get all PVCs that need backup
    kubectl get pvc --all-namespaces -o json | jq -r '
        .items[] |
        select(.metadata.labels."backup-enabled" == "true") |
        "\(.metadata.namespace) \(.metadata.name)"
    ' | while read -r namespace pvc_name; do
        local snapshot_name="backup-$pvc_name-$(date +%Y%m%d)"
        
        kubectl apply -f - <<EOF
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: $snapshot_name
  namespace: $namespace
  labels:
    backup-type: "automated"
    retention-days: "$BACKUP_RETENTION_DAYS"
spec:
  source:
    persistentVolumeClaimName: $pvc_name
EOF
        
        log_message "Created snapshot: $snapshot_name for PVC: $namespace/$pvc_name"
    done
}

# Cleanup old snapshots
cleanup_old_snapshots() {
    log_message "🧹 Cleaning up old snapshots..."
    
    kubectl get volumesnapshots --all-namespaces -o json | jq -r '
        .items[] |
        select(.metadata.labels."backup-type" == "automated") |
        select(
            (now - (.metadata.creationTimestamp | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime)) 
            > ('"$BACKUP_RETENTION_DAYS"' * 86400)
        ) |
        "\(.metadata.namespace) \(.metadata.name)"
    ' | while read -r namespace snapshot_name; do
        kubectl delete volumesnapshot "$snapshot_name" -n "$namespace"
        log_message "Deleted old snapshot: $namespace/$snapshot_name"
    done
}

# Monitor storage usage
monitor_storage_usage() {
    log_message "📊 Monitoring storage usage..."
    
    # Create usage report
    local usage_report="storage-usage-$(date +%Y%m%d).json"
    
    kubectl get pvc --all-namespaces -o json | jq '{
        total_pvcs: (.items | length),
        total_storage_requested: (.items | map(.spec.resources.requests.storage | gsub("[^0-9]"; "") | tonumber) | add),
        storage_by_class: (.items | group_by(.spec.storageClassName) | map({
            storage_class: .[0].spec.storageClassName,
            count: length,
            total_storage: (map(.spec.resources.requests.storage | gsub("[^0-9]"; "") | tonumber) | add)
        })),
        namespaces: (.items | group_by(.metadata.namespace) | map({
            namespace: .[0].metadata.namespace,
            pvc_count: length,
            total_storage: (map(.spec.resources.requests.storage | gsub("[^0-9]"; "") | tonumber) | add)
        }))
    }' > "$usage_report"
    
    log_message "Storage usage report generated: $usage_report"
}

# Main execution
main() {
    log_message "🔄 Starting storage lifecycle management..."
    
    find_orphaned_volumes
    create_volume_snapshots
    cleanup_old_snapshots
    monitor_storage_usage
    
    log_message "✅ Storage lifecycle management completed"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

---

## Summary

This comprehensive guide covers all aspects of Kubernetes Storage Classes, from basic concepts to advanced enterprise scenarios. Key takeaways:

### Essential Commands Quick Reference

```bash
# Storage Class Management
kubectl get storageclass
kubectl describe storageclass <name>
kubectl apply -f storageclass.yaml
kubectl delete storageclass <name>

# Set default Storage Class
kubectl patch storageclass <name> -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# PVC with Storage Class
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
  storageClassName: my-storage-class
EOF

# Monitor storage resources
kubectl get pv,pvc,storageclass
kubectl top nodes
```

### Key Best Practices Recap

1. **Performance**: Match Storage Class parameters to workload requirements
2. **Cost**: Use appropriate volume types (GP3 vs IO2 vs ST1)
3. **Security**: Enable encryption and use proper access modes
4. **Reliability**: Set appropriate reclaim policies and enable backups
5. **Monitoring**: Implement storage usage tracking and alerting
6. **Lifecycle**: Automate cleanup and snapshot management

Storage Classes are fundamental to effective Kubernetes storage management, providing the flexibility and automation needed for modern containerized applications across any infrastructure.