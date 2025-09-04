# Unit 1: Understanding the Container Storage Problem

## Learning Objectives
By the end of this unit, you will:
- Understand why container storage is fundamentally different from traditional applications
- Experience firsthand what happens when container data is lost
- Recognize the need for persistent storage solutions
- Create your first persistent volume in Kubernetes

## Prerequisites
- Basic understanding of containers (Docker helpful but not required)
- Access to a Kubernetes cluster (minikube, kind, or cloud provider)
- `kubectl` installed and configured

---

## 1. The Ephemeral Nature Problem

### Demonstration: Data Loss in Action

Let's start with a practical demonstration to experience the storage problem firsthand.

```bash
# Create a simple pod that writes data
kubectl run writer-pod --image=busybox --rm -it --restart=Never -- /bin/sh

# Inside the pod, create some important data
echo "Important user data created at $(date)" > /tmp/important-file.txt
echo "User preferences: theme=dark, language=en" >> /tmp/important-file.txt
ls -la /tmp/important-file.txt
cat /tmp/important-file.txt
exit
```

**Now let's see what happened to our data:**

```bash
# Try to access the same data by creating another pod
kubectl run reader-pod --image=busybox --rm -it --restart=Never -- /bin/sh

# Look for our important file
ls -la /tmp/
cat /tmp/important-file.txt  # This will fail!
exit
```

**Question for Reflection:** What happened to the data we created in the first pod? Why couldn't the second pod access it?

---

## 2. Real-World Impact Scenarios

### Scenario A: Database Data Loss
```bash
# Deploy a simple database without persistent storage
kubectl create deployment temp-database --image=postgres:13
kubectl set env deployment/temp-database POSTGRES_PASSWORD=mypassword POSTGRES_DB=testdb

# Wait for it to be ready
kubectl wait deployment/temp-database --for=condition=available --timeout=60s

# Connect and create some data
kubectl exec deployment/temp-database -it -- psql -U postgres -d testdb -c "
CREATE TABLE users (id SERIAL PRIMARY KEY, name VARCHAR(50), email VARCHAR(100));
INSERT INTO users (name, email) VALUES ('Alice', 'alice@example.com'), ('Bob', 'bob@example.com');
SELECT * FROM users;"
```

Now simulate a pod restart (which happens frequently in Kubernetes):
```bash
# Delete the pod to simulate a crash or update
kubectl delete pod -l app=temp-database

# Wait for new pod to start
kubectl wait deployment/temp-database --for=condition=available --timeout=60s

# Try to access our data
kubectl exec deployment/temp-database -it -- psql -U postgres -d testdb -c "SELECT * FROM users;"
```

**Discussion Point:** What happened to the users table? How would this affect a real application?

---

## 3. Introduction to Kubernetes Storage Solutions

Kubernetes provides three main abstractions to solve the storage problem:

### Storage Abstractions Quick Overview

| Component | Purpose | Analogy |
|-----------|---------|---------|
| **PersistentVolume (PV)** | Actual storage resource | Physical hard drive in a server room |
| **PersistentVolumeClaim (PVC)** | Request for storage | Purchase order for storage |
| **StorageClass** | Storage provisioning template | Different tiers of cloud storage plans |

---

## 4. Hands-On Mini-Project: Your First Persistent Storage

### Step 1: Create a Simple Persistent Volume

```yaml
# Create file: first-persistent-volume.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: my-first-pv
  labels:
    type: local
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /tmp/k8s-storage-demo
    type: DirectoryOrCreate
```

```bash
# Apply the PV
kubectl apply -f first-persistent-volume.yaml

# Check if it was created
kubectl get pv
kubectl describe pv my-first-pv
```

### Step 2: Create a Persistent Volume Claim

```yaml
# Create file: first-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-first-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi  # Request less than PV capacity
```

```bash
# Apply the PVC
kubectl apply -f first-pvc.yaml

# Watch the binding process
kubectl get pvc
kubectl get pv  # Notice the STATUS changed to "Bound"
```

### Step 3: Use the Storage in a Pod

```yaml
# Create file: pod-with-storage.yaml
apiVersion: v1
kind: Pod
metadata:
  name: storage-demo-pod
spec:
  containers:
  - name: demo-container
    image: busybox
    command: ["sleep", "3600"]
    volumeMounts:
    - name: demo-storage
      mountPath: /data
  volumes:
  - name: demo-storage
    persistentVolumeClaim:
      claimName: my-first-pvc
```

```bash
# Create the pod
kubectl apply -f pod-with-storage.yaml

# Wait for it to be ready
kubectl wait pod/storage-demo-pod --for=condition=ready --timeout=60s
```

---

## 5. Testing Persistence

### Experiment 1: Data Survives Pod Deletion

```bash
# Create some data in the persistent storage
kubectl exec storage-demo-pod -- /bin/sh -c "
echo 'This data should survive pod restarts' > /data/persistent-file.txt
echo 'Created at: $(date)' >> /data/persistent-file.txt
ls -la /data/
cat /data/persistent-file.txt
"

# Delete the pod
kubectl delete pod storage-demo-pod

# Create a new pod using the same PVC
kubectl apply -f pod-with-storage.yaml
kubectl wait pod/storage-demo-pod --for=condition=ready --timeout=60s

# Check if our data survived
kubectl exec storage-demo-pod -- cat /data/persistent-file.txt
```

**Success!** The data survived the pod deletion and recreation.

---

## 6. Understanding What Just Happened

### Reflection Questions

1. **What's different** between this storage demo and our earlier examples where data was lost?

2. **Why did the PVC bind** to our PV automatically? What criteria did Kubernetes use?

3. **What would happen** if we created another PVC requesting the same storage? Try it:

```bash
# Create a second PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: second-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
EOF

# Check the status
kubectl get pvc
kubectl describe pvc second-pvc
```

---

## 7. Key Concepts Summary

### What We Learned
- **Container storage is ephemeral** by default - data disappears when containers stop
- **PersistentVolumes** represent actual storage resources
- **PersistentVolumeClaims** are requests that bind to suitable PVs  
- **Data persists** beyond pod lifecycle when using persistent volumes

### Important Behaviors Observed
- PV and PVC binding is **one-to-one and exclusive**
- **AccessModes must match** between PV and PVC
- **Storage capacity** in PVC must be <= PV capacity
- **Once bound**, the relationship persists until PVC deletion

---

## 8. Practice Exercises

### Exercise 1: Storage Troubleshooting
Create a PVC that cannot bind and diagnose why:

```yaml
# This PVC will have issues - can you spot why?
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: problematic-pvc
spec:
  accessModes:
  - ReadWriteMany  # Different from our PV!
  resources:
    requests:
      storage: 2Gi   # More than our PV capacity!
```

### Exercise 2: Multiple Pods, Same Storage
Try to create two pods that both use the same PVC. What happens and why?

---

## 9. Cleanup

```bash
# Remove all resources created in this unit
kubectl delete pod storage-demo-pod
kubectl delete pvc my-first-pvc second-pvc problematic-pvc
kubectl delete pv my-first-pv

# Clean up local files
rm -f first-persistent-volume.yaml first-pvc.yaml pod-with-storage.yaml
```

---

## Next Steps

In Unit 2, we'll explore:
- **StorageClasses** and dynamic provisioning
- **Different storage backends** (cloud storage, NFS, etc.)
- **AccessModes** in detail
- **Storage lifecycle management**

### Before Moving On
Make sure you can explain:
- Why containers need external storage for persistent data
- The relationship between PV, PVC, and pods
- What "binding" means in the context of storage
- How data persistence differs from container persistence