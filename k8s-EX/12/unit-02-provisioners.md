# Unit 2: Understanding Provisioners and Cloud Storage

## Learning Objectives
- Understand how different provisioners work
- Configure Storage Classes for major cloud providers
- Identify appropriate storage types for different workloads
- Create performance-optimized storage configurations

## Prerequisites
- Completed Unit 1: Storage Classes Foundations
- Access to a cloud-based Kubernetes cluster (or ability to simulate one)

## Theory: Provisioners Deep Dive

### What Is a Provisioner?
A provisioner is the component that actually creates storage volumes. Think of it as the "driver" that knows how to talk to a specific storage system.

Types of provisioners:
- **Internal**: Built into Kubernetes (`kubernetes.io/aws-ebs`, `kubernetes.io/gce-pd`)
- **CSI (Container Storage Interface)**: Modern, plugin-based (`ebs.csi.aws.com`)
- **External**: Third-party storage solutions

### Why CSI Matters
CSI is the modern standard because:
- Vendor independence
- Better feature support
- Active development
- Snapshot support

## Hands-On Lab 1: Cloud Provider Storage Classes

Before we start, which cloud provider are you using? The examples below cover AWS, GCP, and Azure. Pick the one that matches your environment.

### AWS EBS Storage Classes

#### Basic GP3 Storage Class
```yaml
# aws-gp3-basic.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: aws-gp3-basic
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
allowVolumeExpansion: true
```

#### High-Performance Storage Class
```yaml
# aws-high-performance.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: aws-high-perf
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "10000"
  throughput: "500"
  fsType: ext4
  encrypted: "true"
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
allowVolumeExpansion: true
```

### Experiment: Performance Comparison
Create both storage classes and test them:

```bash
# Apply the storage classes
kubectl apply -f aws-gp3-basic.yaml
kubectl apply -f aws-high-performance.yaml

# Create test PVCs
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: basic-test
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 10Gi
  storageClassName: aws-gp3-basic
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: high-perf-test
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 10Gi
  storageClassName: aws-high-perf
EOF
```

Now create pods to trigger the volume creation:

```yaml
# performance-test-pods.yaml
apiVersion: v1
kind: Pod
metadata:
  name: basic-test-pod
spec:
  containers:
  - name: test
    image: ubuntu:20.04
    command: ["/bin/bash", "-c", "sleep 3600"]
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: basic-test
---
apiVersion: v1
kind: Pod
metadata:
  name: high-perf-test-pod
spec:
  containers:
  - name: test
    image: ubuntu:20.04
    command: ["/bin/bash", "-c", "sleep 3600"]
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: high-perf-test
EOF
```

### Investigation Questions
After the pods are running, investigate:

1. What are the actual IOPS and throughput values for each volume in the AWS console?
2. How long did each volume take to provision?
3. What's the cost difference between the two configurations?

## Hands-On Lab 2: Storage Parameters Deep Dive

### Parameter Exploration Script
Create a script to understand what parameters do:

```bash
#!/bin/bash
# parameter-explorer.sh

echo "Storage Class Parameter Explorer"
echo "================================"

# Function to create and test a storage class
test_storage_class() {
    local name=$1
    local parameters=$2
    
    echo "Testing: $name"
    echo "Parameters: $parameters"
    
    # Create storage class with parameters
    cat > temp-sc.yaml <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: test-$name
provisioner: ebs.csi.aws.com
parameters:
$parameters
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
EOF

    kubectl apply -f temp-sc.yaml
    
    # Test with a small PVC
    kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-$name-pvc
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
  storageClassName: test-$name
EOF

    echo "Created test PVC for $name"
    echo "---"
}

# Test different parameter combinations
test_storage_class "encrypted" "  type: gp3\n  encrypted: \"true\""
test_storage_class "custom-iops" "  type: gp3\n  iops: \"5000\""
test_storage_class "throughput" "  type: gp3\n  throughput: \"250\""

echo "Check PVC status with: kubectl get pvc"
echo "Clean up with: kubectl delete pvc,sc -l app=parameter-test"
```

What patterns do you notice in how different parameters affect provisioning time and success?

## Mini-Project: Workload-Specific Storage Classes

Design storage classes for these scenarios. Think about what parameters each workload needs:

### Scenario 1: Database Storage
**Requirements:**
- High IOPS for random read/write
- Data must be encrypted
- Needs to be retained if pod is deleted
- Should allow volume expansion

```yaml
# Your storage class design here
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: database-storage
# Complete this based on requirements
```

### Scenario 2: Log Storage
**Requirements:**
- Cost-effective for large volumes
- Sequential write-heavy workload
- Can be deleted when pod is deleted
- Doesn't need high IOPS

### Scenario 3: Cache Storage
**Requirements:**
- Extremely fast access
- Data can be lost (cache can be rebuilt)
- Small volumes
- Maximum performance

### Design Challenge Questions:
1. Which AWS EBS volume type would you choose for each scenario?
2. What IOPS settings make sense?
3. How would you handle encryption requirements?
4. What about backup and retention policies?

## Advanced Lab: Multi-Zone Storage Classes

Create storage classes that work across availability zones:

```yaml
# multi-zone-storage.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: multi-zone-storage
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
allowVolumeExpansion: true
allowedTopologies:
- matchLabelExpressions:
  - key: topology.ebs.csi.aws.com/zone
    values:
    - us-west-2a
    - us-west-2b
    - us-west-2c
```

### Topology Challenge:
1. Create the multi-zone storage class
2. Create multiple PVCs using this storage class
3. Deploy pods that use these PVCs to different zones
4. Observe how Kubernetes handles the scheduling

What happens if a pod gets scheduled to a zone where its volume doesn't exist?

## Troubleshooting Lab

Let's create some broken storage classes and fix them:

```yaml
# broken-storage-classes.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: broken-1
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "100000"  # Too high
  fsType: ext4
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: broken-2
provisioner: nonexistent.provisioner
parameters:
  type: gp3
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: broken-3
provisioner: ebs.csi.aws.com
parameters:
  type: invalid-type
```

Apply these and create PVCs. What errors do you get? How would you diagnose each issue?

## Reflection Questions

1. How do you determine the right balance between performance and cost for storage?
2. When would you use `Immediate` vs `WaitForFirstConsumer` binding mode?
3. What are the security implications of different parameter choices?
4. How do cloud provider limits affect your storage class design?

## Assessment Checklist
- [ ] Can identify appropriate provisioners for different clouds
- [ ] Can configure performance parameters based on workload requirements
- [ ] Can troubleshoot common storage class provisioning issues
- [ ] Understands the trade-offs between different storage types
- [ ] Can design storage classes for multi-zone deployments

## Next Steps
Unit 3 will cover advanced storage class features like snapshots, volume expansion, and backup strategies. Start thinking about:
- How do you handle storage for stateful applications?
- What's your backup strategy for persistent data?
- How do you manage storage costs at scale?