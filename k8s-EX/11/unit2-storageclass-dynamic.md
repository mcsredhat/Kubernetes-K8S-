# Unit 2: StorageClasses and Dynamic Provisioning

## Learning Objectives
By the end of this unit, you will:
- Understand the limitations of static PV provisioning
- Create and configure StorageClasses for different storage tiers
- Experience dynamic provisioning in action
- Implement volume expansion capabilities
- Build a multi-tier storage system

## Prerequisites
- Completed Unit 1
- Understanding of PV/PVC binding concepts
- Kubernetes cluster with CSI driver support (most modern clusters)

---

## 1. The Static Provisioning Problem

### Scenario: Managing Storage at Scale

Imagine you're a platform administrator supporting 50 development teams. Each team needs storage for their applications. With static provisioning, you'd need to:

1. Pre-create hundreds of PVs with different sizes
2. Guess what storage capacities teams will need
3. Manually create new PVs when teams request them
4. Deal with wasted storage when small PVCs bind to large PVs

Let's see this problem in practice:

```bash
# Create a large PV
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: large-pv
spec:
  capacity:
    storage: 100Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /tmp/large-storage
    type: DirectoryOrCreate
EOF

# Create a small PVC that will bind to our large PV
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: small-request-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi  # Only need 1Gi but will get 100Gi
EOF

# Check the waste
kubectl get pv,pvc
```

**Result**: The 1Gi PVC binds to the 100Gi PV, wasting 99Gi of storage!

---

## 2. Introduction to StorageClasses

StorageClasses solve the static provisioning problem by defining templates for dynamic storage creation.

### Basic StorageClass Concepts

```bash
# Check what StorageClasses are available in your cluster
kubectl get storageclass
kubectl get sc  # Short form

# Look at a StorageClass in detail
kubectl describe storageclass
```

### Creating Your First StorageClass

```yaml
# Create file: basic-storageclass.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: demo-storage
  annotations:
    # Optional: make this the default StorageClass
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: k8s.io/minikube-hostpath  # Use appropriate provisioner for your cluster
parameters:
  type: pd-standard  # Provisioner-specific parameters
allowVolumeExpansion: true  # Allow growing volumes after creation
reclaimPolicy: Delete      # Delete PV when PVC is deleted
volumeBindingMode: WaitForFirstConsumer  # Delay binding until pod creation
```

**Important**: The `provisioner` field depends on your cluster type:
- Minikube: `k8s.io/minikube-hostpath`
- AWS EKS: `ebs.csi.aws.com`
- Google GKE: `pd.csi.storage.gke.io`
- Azure AKS: `disk.csi.azure.com`

---

## 3. Hands-On: Dynamic Provisioning in Action

### Step 1: Create StorageClass for Your Environment

First, determine your cluster type:

```bash
# Check your cluster info
kubectl cluster-info
kubectl get nodes -o wide

# Check available CSI drivers
kubectl get csidriver
```

Create appropriate StorageClass:

```yaml
# For minikube/local development
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-local
provisioner: k8s.io/minikube-hostpath
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
```

```bash
# Apply the StorageClass
kubectl apply -f basic-storageclass.yaml

# Verify it was created
kubectl get storageclass fast-local
```

### Step 2: Test Dynamic Provisioning

```yaml
# Create file: dynamic-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dynamic-pvc-test
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
  storageClassName: fast-local  # Reference our StorageClass
```

```bash
# Create the PVC
kubectl apply -f dynamic-pvc.yaml

# Watch what happens - initially it will be Pending
kubectl get pvc dynamic-pvc-test

# Check if a PV was created automatically
kubectl get pv
```

Notice the PVC stays in "Pending" state because we used `WaitForFirstConsumer` mode.

### Step 3: Trigger Dynamic Provisioning with a Pod

```yaml
# Create file: pod-triggers-provisioning.yaml
apiVersion: v1
kind: Pod
metadata:
  name: trigger-provisioning
spec:
  containers:
  - name: app
    image: busybox
    command: ["sleep", "3600"]
    volumeMounts:
    - name: dynamic-storage
      mountPath: /data
  volumes:
  - name: dynamic-storage
    persistentVolumeClaim:
      claimName: dynamic-pvc-test
```

```bash
# Create the pod
kubectl apply -f pod-triggers-provisioning.yaml

# Watch the magic happen
kubectl get pvc,pv

# The PVC should now be Bound and a PV should appear automatically!
```

---

## 4. Multi-Tier Storage System Project

Let's build a realistic storage system with different performance tiers.

### Step 1: Create Multiple StorageClasses

```yaml
# Create file: multi-tier-storage.yaml
# Premium SSD tier for databases
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: premium-ssd
  labels:
    performance: high
    cost: high
provisioner: k8s.io/minikube-hostpath  # Adjust for your cluster
parameters:
  type: premium-ssd
allowVolumeExpansion: true
reclaimPolicy: Retain  # Don't delete data automatically
volumeBindingMode: WaitForFirstConsumer
---
# Standard tier for general applications
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
  labels:
    performance: medium
    cost: medium
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: k8s.io/minikube-hostpath
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
---
# Economy tier for backups and archives
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: economy
  labels:
    performance: low
    cost: low
provisioner: k8s.io/minikube-hostpath
parameters:
  type: cold-storage
allowVolumeExpansion: false  # No expansion for cheap storage
reclaimPolicy: Delete
volumeBindingMode: Immediate  # Provision immediately for batch workloads
```

```bash
# Apply all StorageClasses
kubectl apply -f multi-tier-storage.yaml

# Verify they were created
kubectl get storageclass --show-labels
```

### Step 2: Deploy Applications Using Different Tiers

```yaml
# Create file: tiered-applications.yaml
# Database using premium storage
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: database-storage
  labels:
    app: database
    tier: premium
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: premium-ssd
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
    spec:
      containers:
      - name: postgres
        image: postgres:13
        env:
        - name: POSTGRES_PASSWORD
          value: demo123
        - name: POSTGRES_DB
          value: appdb
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
          subPath: postgres
        resources:
          requests:
            memory: 256Mi
            cpu: 250m
          limits:
            memory: 512Mi
            cpu: 500m
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: database-storage
---
# Web application using standard storage
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: webapp-storage
  labels:
    app: webapp
    tier: standard
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: standard  # Uses default class
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        volumeMounts:
        - name: content
          mountPath: /usr/share/nginx/html
        - name: content
          mountPath: /var/log/nginx
          subPath: logs
        resources:
          requests:
            memory: 64Mi
            cpu: 50m
          limits:
            memory: 128Mi
            cpu: 100m
      volumes:
      - name: content
        persistentVolumeClaim:
          claimName: webapp-storage
---
# Backup system using economy storage
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: backup-storage
  labels:
    app: backup
    tier: economy
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
  storageClassName: economy
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup-job
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: busybox
            command:
            - /bin/sh
            - -c
            - |
              echo "Starting backup at $(date)"
              echo "Simulating database backup..."
              echo "backup-$(date +%Y%m%d)" > /backup/latest-backup.txt
              ls -la /backup/
              echo "Backup completed at $(date)"
            volumeMounts:
            - name: backup-vol
              mountPath: /backup
          volumes:
          - name: backup-vol
            persistentVolumeClaim:
              claimName: backup-storage
          restartPolicy: OnFailure
```

```bash
# Deploy the tiered applications
kubectl apply -f tiered-applications.yaml

# Watch the storage get provisioned
kubectl get pvc,pv

# Check that different storage classes were used
kubectl get pvc -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,CAPACITY:.status.capacity.storage,STORAGECLASS:.spec.storageClassName"
```

---

## 5. Volume Expansion Demonstration

One powerful feature of StorageClasses is the ability to expand volumes after creation.

### Step 1: Check Current Storage Usage

```bash
# Get a shell in the webapp pod
kubectl exec deployment/webapp -it -- /bin/sh

# Check current storage size
df -h /usr/share/nginx/html
exit
```

### Step 2: Fill Up the Storage

```bash
# Create files to use storage space
kubectl exec deployment/webapp -- /bin/sh -c "
for i in {1..100}; do
  echo 'This is test file $i with some content to use space' > /usr/share/nginx/html/file$i.txt
done
du -sh /usr/share/nginx/html
"
```

### Step 3: Expand the Volume

```bash
# Expand the PVC from 5Gi to 8Gi
kubectl patch pvc webapp-storage -p '{"spec":{"resources":{"requests":{"storage":"8Gi"}}}}'

# Check the expansion status
kubectl describe pvc webapp-storage
kubectl get pvc webapp-storage

# Verify the expansion worked
kubectl exec deployment/webapp -- df -h /usr/share/nginx/html
```

---

## 6. Understanding Volume Binding Modes

Let's explore the difference between binding modes with an experiment.

### Immediate vs WaitForFirstConsumer

```yaml
# Create file: binding-mode-test.yaml
# Test Immediate binding
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: immediate-binding
provisioner: k8s.io/minikube-hostpath
volumeBindingMode: Immediate
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: immediate-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: immediate-binding
---
# Test WaitForFirstConsumer binding
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: wait-for-consumer
provisioner: k8s.io/minikube-hostpath
volumeBindingMode: WaitForFirstConsumer
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: wait-for-consumer-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: wait-for-consumer
```

```bash
# Apply the test configuration
kubectl apply -f binding-mode-test.yaml

# Compare the behavior
kubectl get pvc immediate-pvc wait-for-consumer-pvc

# immediate-pvc should be Bound immediately
# wait-for-consumer-pvc should be Pending
```

---

## 7. Troubleshooting Dynamic Provisioning

### Common Issues and Solutions

#### Issue 1: PVC Stuck in Pending
```bash
# Diagnose a pending PVC
kubectl describe pvc stuck-pvc-name

# Common causes:
# 1. StorageClass doesn't exist
kubectl get storageclass requested-class-name

# 2. Insufficient cluster resources
kubectl get nodes
kubectl describe nodes

# 3. Provisioner not available
kubectl get pods -n kube-system | grep -i provision
```

#### Issue 2: Provisioner Errors
```bash
# Check provisioner logs
kubectl logs -n kube-system deployment/ebs-csi-controller  # For AWS
kubectl logs -n kube-system deployment/gce-pd-csi-driver  # For GKE

# Check CSI driver status
kubectl get csinode
kubectl describe csinode your-node-name
```

---

## 8. Storage Class Best Practices

### Production-Ready StorageClass Configuration

```yaml
# Create file: production-storageclass.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: production-ssd
  labels:
    environment: production
    performance-tier: high
  annotations:
    storageclass.kubernetes.io/description: "High-performance SSD storage for production workloads"
    storageclass.kubernetes.io/cost-per-gb-month: "0.10"
    storageclass.kubernetes.io/iops: "3000"
provisioner: k8s.io/minikube-hostpath  # Replace with your provisioner
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
  encrypted: "true"  # Always encrypt production data
allowVolumeExpansion: true
reclaimPolicy: Retain  # Don't automatically delete production data
volumeBindingMode: WaitForFirstConsumer
allowedTopologies:
- matchLabelExpressions:
  - key: topology.kubernetes.io/zone
    values:
    - us-west-2a
    - us-west-2b
    - us-west-2c
```

### Validation Script for StorageClasses

```bash
# Create file: validate-storage.sh
#!/bin/bash

echo "Validating StorageClass configuration..."

# Check if StorageClass exists
SC_NAME=${1:-production-ssd}
if ! kubectl get storageclass $SC_NAME &>/dev/null; then
    echo "ERROR: StorageClass $SC_NAME not found"
    exit 1
fi

# Test dynamic provisioning
echo "Testing dynamic provisioning..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: validation-test-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: $SC_NAME
EOF

# Create test pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: validation-test-pod
spec:
  containers:
  - name: test
    image: busybox
    command: ["sleep", "60"]
    volumeMounts:
    - name: test-vol
      mountPath: /test
  volumes:
  - name: test-vol
    persistentVolumeClaim:
      claimName: validation-test-pvc
EOF

# Wait for pod to be ready
if kubectl wait pod/validation-test-pod --for=condition=ready --timeout=120s; then
    echo "SUCCESS: Dynamic provisioning working"
    
    # Test volume expansion if supported
    if kubectl get storageclass $SC_NAME -o jsonpath='{.allowVolumeExpansion}' | grep -q true; then
        echo "Testing volume expansion..."
        kubectl patch pvc validation-test-pvc -p '{"spec":{"resources":{"requests":{"storage":"2Gi"}}}}'
        sleep 10
        if kubectl get pvc validation-test-pvc -o jsonpath='{.status.capacity.storage}' | grep -q 2Gi; then
            echo "SUCCESS: Volume expansion working"
        else
            echo "WARNING: Volume expansion may not be working"
        fi
    fi
else
    echo "ERROR: Dynamic provisioning failed"
    kubectl describe pod validation-test-pod
    kubectl describe pvc validation-test-pvc
fi

# Cleanup
kubectl delete pod validation-test-pod
kubectl delete pvc validation-test-pvc
```

---

## 9. Key Concepts Summary

### What We Learned
- **StorageClasses eliminate** the need to pre-provision PVs
- **Dynamic provisioning** creates storage on-demand with exact requested capacity
- **Volume binding modes** control when storage is actually created
- **Volume expansion** allows growing storage after creation
- **Multiple tiers** enable cost and performance optimization

### Critical Behaviors
- PVCs without storageClassName use the default StorageClass
- `WaitForFirstConsumer` prevents cross-zone mounting issues
- Volume expansion requires both StorageClass and CSI driver support
- Reclaim policies affect what happens to data when PVCs are deleted

---

## 10. Practice Exercises

### Exercise 1: Multi-Environment Setup
Create StorageClasses for dev, staging, and production with different:
- Reclaim policies
- Volume expansion settings  
- Performance characteristics

### Exercise 2: Storage Migration
Create a process to migrate data from one StorageClass to another:
1. Create new PVC with target StorageClass
2. Copy data between volumes
3. Update application to use new PVC

### Exercise 3: Cost Optimization
Design a system that automatically moves old data from premium to economy storage based on age.

---

## 11. Cleanup

```bash
# Remove all resources from this unit
kubectl delete cronjob backup-job
kubectl delete deployment database-app webapp
kubectl delete pvc database-storage webapp-storage backup-storage
kubectl delete pvc dynamic-pvc-test immediate-pvc wait-for-consumer-pvc
kubectl delete storageclass demo-storage fast-local premium-ssd standard economy
kubectl delete storageclass immediate-binding wait-for-consumer production-ssd
kubectl delete pod trigger-provisioning validation-test-pod
kubectl delete pv --all  # Be careful with this in shared clusters!

# Clean up files
rm -f basic-storageclass.yaml dynamic-pvc.yaml pod-triggers-provisioning.yaml
rm -f multi-tier-storage.yaml tiered-applications.yaml binding-mode-test.yaml
rm -f production-storageclass.yaml validate-storage.sh
```

---

## Next Steps

In Unit 3, we'll explore:
- **Access modes** in depth (ReadWriteOnce vs ReadWriteMany)
- **Sharing storage** between multiple pods
- **Network storage** solutions (NFS, Ceph, cloud storage)
- **StatefulSets** and their unique storage requirements

### Before Moving On
Ensure you understand:
- How StorageClasses eliminate static provisioning overhead
- The relationship between provisioners and storage backends
- When to use different volume binding modes
- How to design storage tiers for different workload requirements