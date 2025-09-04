# Unit 3: Advanced Storage Features

## Learning Objectives
- Implement volume expansion capabilities
- Configure and use volume snapshots
- Design storage classes with mount options
- Handle storage class lifecycle and updates

## Prerequisites
- Completed Units 1-2
- Understanding of storage provisioners
- Experience with cloud-based storage classes

## Theory: Beyond Basic Provisioning

By now you've seen how storage classes enable dynamic provisioning. But real-world applications need more sophisticated capabilities:

- **Volume Expansion**: Growing storage without downtime
- **Snapshots**: Point-in-time backups and cloning
- **Mount Options**: Fine-tuning filesystem behavior
- **Binding Modes**: Controlling when and where volumes are created

## Hands-On Lab 1: Volume Expansion

### Challenge Question
Before we start: What problems might arise if you need to grow a database's storage while it's running? How do you think Kubernetes might solve this?

### Step 1: Create an Expandable Storage Class
```yaml
# expandable-storage.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: expandable-gp3
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
  encrypted: "true"
allowVolumeExpansion: true  # This is the key setting
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
```

**Investigation Question**: What do you think happens if you set `allowVolumeExpansion: false` and then try to expand a volume?

### Step 2: Test Volume Expansion
```yaml
# expansion-test-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: storage-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: storage-app
  template:
    metadata:
      labels:
        app: storage-app
    spec:
      containers:
      - name: app
        image: ubuntu:20.04
        command: ["/bin/bash", "-c"]
        args:
        - |
          # Create some test data
          mkdir -p /data/test
          dd if=/dev/zero of=/data/test/large-file bs=1M count=100
          echo "Created 100MB test file"
          df -h /data
          tail -f /dev/null  # Keep container running
        volumeMounts:
        - name: storage
          mountPath: /data
      volumes:
      - name: storage
        persistentVolumeClaim:
          claimName: expandable-pvc
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: expandable-pvc
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi  # Start small
  storageClassName: expandable-gp3
```

Deploy and observe the initial state:
```bash
kubectl apply -f expandable-storage.yaml
kubectl apply -f expansion-test-app.yaml

# Wait for pod to be ready
kubectl wait --for=condition=Ready pod -l app=storage-app --timeout=300s

# Check current storage usage
kubectl exec -l app=storage-app -- df -h /data
```

### Step 3: Perform the Expansion
Now let's expand the volume from 1Gi to 3Gi:

```bash
# Expand the PVC
kubectl patch pvc expandable-pvc -p '{"spec":{"resources":{"requests":{"storage":"3Gi"}}}}'

# Monitor the expansion process
kubectl describe pvc expandable-pvc
kubectl get events --sort-by='.lastTimestamp' | grep -i expand
```

**Critical Thinking Questions**:
1. What happens to the filesystem inside the pod during expansion?
2. Do you need to restart the pod for the expansion to take effect?
3. What would happen if the underlying storage system didn't support expansion?

### Step 4: Verify the Expansion
```bash
# Check if the filesystem sees the new size
kubectl exec -l app=storage-app -- df -h /data

# If the filesystem hasn't been resized automatically:
kubectl exec -l app=storage-app -- resize2fs /dev/xvda1  # Only if needed
```

## Hands-On Lab 2: Volume Snapshots

### Theory Check
Before implementing snapshots, consider: How might snapshots be useful for database backups versus application deployment strategies?

### Step 1: Check Snapshot Support
```bash
# Check if your cluster supports volume snapshots
kubectl get crd | grep snapshot
kubectl get volumesnapshotclasses
```

If you don't see snapshot CRDs, you might need to install the snapshot controller.

### Step 2: Create a Snapshot-Capable Storage Class
```yaml
# snapshot-storage.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: snapshot-enabled
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain  # Important for production snapshots
```

### Step 3: Create Test Data for Snapshotting
```yaml
# snapshot-test-app.yaml
apiVersion: v1
kind: Pod
metadata:
  name: snapshot-test
spec:
  containers:
  - name: test
    image: ubuntu:20.04
    command: ["/bin/bash", "-c"]
    args:
    - |
      # Create identifiable test data
      echo "Initial data - $(date)" > /data/initial.txt
      echo "This is version 1 of our data" > /data/version.txt
      mkdir -p /data/logs
      for i in {1..100}; do
        echo "Log entry $i - $(date)" >> /data/logs/application.log
      done
      echo "Test data created, sleeping..."
      sleep 3600
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: snapshot-pvc
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: snapshot-pvc
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 2Gi
  storageClassName: snapshot-enabled
```

### Step 4: Create and Test Snapshots
```bash
# Deploy the test application
kubectl apply -f snapshot-storage.yaml
kubectl apply -f snapshot-test-app.yaml

# Wait and verify initial data
kubectl wait --for=condition=Ready pod/snapshot-test --timeout=300s
kubectl exec snapshot-test -- ls -la /data/
kubectl exec snapshot-test -- cat /data/version.txt
```

Create the snapshot:
```yaml
# volume-snapshot.yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: data-snapshot-v1
spec:
  source:
    persistentVolumeClaimName: snapshot-pvc
```

```bash
kubectl apply -f volume-snapshot.yaml
kubectl get volumesnapshots
kubectl describe volumesnapshot data-snapshot-v1
```

### Step 5: Modify Data and Create Another Snapshot
```bash
# Modify the data
kubectl exec snapshot-test -- bash -c 'echo "This is version 2 - $(date)" > /data/version.txt'
kubectl exec snapshot-test -- bash -c 'echo "Important update logged" >> /data/logs/application.log'

# Create second snapshot
kubectl apply -f - <<EOF
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: data-snapshot-v2
spec:
  source:
    persistentVolumeClaimName: snapshot-pvc
EOF
```

### Step 6: Restore from Snapshot
```yaml
# restore-from-snapshot.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: restored-pvc
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 2Gi
  storageClassName: snapshot-enabled
  dataSource:
    name: data-snapshot-v1  # Restore from first snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
---
apiVersion: v1
kind: Pod
metadata:
  name: restore-test
spec:
  containers:
  - name: test
    image: ubuntu:20.04
    command: ["sleep", "3600"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: restored-pvc
```

```bash
kubectl apply -f restore-from-snapshot.yaml
kubectl wait --for=condition=Ready pod/restore-test --timeout=300s

# Compare the restored data
kubectl exec restore-test -- cat /data/version.txt
# Should show version 1, not version 2
```

**Analysis Questions**:
1. What are the performance implications of frequent snapshots?
2. How might you automate snapshot creation for backup purposes?
3. What's the difference between snapshots and traditional backup methods?

## Mini-Project: Database Backup Strategy

Design a complete backup strategy using snapshots for a database workload:

### Requirements:
- Daily snapshots for 7 days
- Weekly snapshots for 4 weeks  
- Monthly snapshots for 6 months
- Automated cleanup of old snapshots
- Ability to quickly restore to any snapshot

### Your Design Challenge:
Create the storage class, deployment, and automation scripts needed. Consider:

1. What storage parameters optimize for database workloads?
2. How would you schedule snapshot creation?
3. What's your snapshot naming convention?
4. How do you handle snapshot cleanup?

```yaml
# Your database storage class design
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: database-with-snapshots
# Complete this implementation
```

```bash
#!/bin/bash
# Your automated backup script
# snapshot-manager.sh

# Implement:
# - Create daily snapshot
# - Clean up snapshots based on retention policy
# - Validate snapshot creation success
# - Handle failure scenarios
```

## Advanced Lab: Custom Mount Options

### Scenario
You're running a high-performance application that needs specific filesystem optimizations. How would you configure these through storage classes?

```yaml
# performance-optimized.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: high-performance
provisioner: ebs.csi.aws.com
parameters:
  type: io2
  iops: "20000"
  fsType: ext4
mountOptions:
  - noatime      # Disable access time updates
  - discard      # Enable TRIM support
  - barrier=0    # Disable write barriers for performance
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
allowVolumeExpansion: true
```

### Investigation Task:
1. Research what each mount option does
2. What are the risks of these performance optimizations?
3. How would you test the performance impact?

Create a benchmarking pod to test different mount options:

```yaml
# benchmark-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: storage-benchmark
spec:
  containers:
  - name: fio
    image: ljishen/fio
    command: ["/bin/bash", "-c"]
    args:
    - |
      echo "Starting storage benchmark..."
      fio --name=test --filename=/data/testfile --size=1G --rw=randwrite --bs=4k --numjobs=1 --time_based --runtime=60 --group_reporting
      echo "Benchmark complete"
      sleep 3600
    volumeMounts:
    - name: test-storage
      mountPath: /data
  volumes:
  - name: test-storage
    persistentVolumeClaim:
      claimName: benchmark-pvc
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: benchmark-pvc
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 5Gi
  storageClassName: high-performance
```

## Troubleshooting Lab: Common Issues

Let's create some intentionally problematic configurations and learn to fix them:

### Problem 1: Expansion Fails
```yaml
# problematic-storage.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: problematic-storage
provisioner: ebs.csi.aws.com
parameters:
  type: gp2  # Old type with limitations
allowVolumeExpansion: true
volumeBindingMode: Immediate
```

Create a PVC and try to expand it. What issues do you encounter?

### Problem 2: Snapshot Failures
```yaml
# snapshot-issues.yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: failing-snapshot
spec:
  source:
    persistentVolumeClaimName: nonexistent-pvc  # Intentional error
```

What error messages help you diagnose snapshot issues?

### Problem 3: Mount Option Conflicts
```yaml
# conflicting-mount-options.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: conflicting-options
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
mountOptions:
  - rw
  - ro  # Conflict: can't be both read-write and read-only
```

How do you identify and resolve mount option conflicts?

## Reflection and Assessment

### Comprehensive Challenge:
Design a storage solution for a multi-tier application with these requirements:

1. **Web tier**: Fast, expendable storage for caches
2. **Application tier**: Balanced performance with snapshots for rollbacks  
3. **Database tier**: High IOPS, encrypted, with comprehensive backup strategy
4. **Log aggregation**: Cost-effective, large capacity

### Questions for Deep Understanding:
1. How do volume expansion capabilities change your application design decisions?
2. What are the cost implications of different snapshot strategies?
3. How do mount options interact with application performance tuning?
4. What monitoring would you implement for storage health?

## Assessment Checklist
- [ ] Can configure and perform volume expansion
- [ ] Can create and manage volume snapshots  
- [ ] Can restore data from snapshots
- [ ] Can optimize storage classes with mount options
- [ ] Can troubleshoot common storage class issues
- [ ] Can design storage strategies for complex applications

## Next Steps Preview
Unit 4 will cover enterprise storage patterns including multi-cloud storage, disaster recovery, and cost optimization strategies. Consider:
- How do you handle storage across multiple availability zones or regions?
- What's your strategy for storage cost optimization at scale?
- How do you implement disaster recovery for persistent data?

## Cleanup
```bash
kubectl delete pod,pvc,volumesnapshot --all
kubectl delete storageclass expandable-gp3 snapshot-enabled high-performance problematic-storage conflicting-options
```