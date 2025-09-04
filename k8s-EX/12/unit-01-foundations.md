# Unit 1: Storage Classes Foundations

## Learning Objectives
- Understand what Storage Classes are and why they exist
- Identify the key components of a Storage Class
- Distinguish between static and dynamic provisioning
- Create your first basic Storage Class

## Prerequisites
- Basic Kubernetes knowledge (pods, services, deployments)
- Access to a Kubernetes cluster (minikube, kind, or cloud cluster)
- kubectl configured and working

## Theory: Understanding the Storage Problem

### The Challenge
In traditional infrastructure, storage provisioning was manual:
1. Admin creates a disk/volume
2. Admin attaches it to a server
3. Admin formats and mounts it
4. Application uses it

In Kubernetes, we need:
- **Dynamic provisioning**: Automatic volume creation
- **Abstraction**: Applications shouldn't know storage details
- **Portability**: Same app should work on different storage backends
- **Lifecycle management**: Volumes created, resized, deleted automatically

### What Are Storage Classes?
Storage Classes are like "templates" or "profiles" for storage. They define:
- **What** storage backend to use (AWS EBS, GCE PD, local disk, etc.)
- **How** to configure that storage (type, size, performance)
- **When** to create volumes (immediately or when needed)
- **What** to do when volumes are no longer needed

## Hands-On Lab 1: Your First Storage Class

### Step 1: Examine Your Cluster's Current Storage
```bash
# List existing storage classes
kubectl get storageclass

# Look for a default storage class (marked with annotation)
kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}'
```

**Question**: What storage classes do you see? Is there a default one? What do you think the provisioner names tell you about the underlying storage?

### Step 2: Create a Simple Local Storage Class
```yaml
# simple-storage.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: simple-local
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
```

Apply it:
```bash
kubectl apply -f simple-storage.yaml
kubectl describe storageclass simple-local
```

### Step 3: Test with a PVC
```yaml
# test-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-claim
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
  storageClassName: simple-local
```

```bash
kubectl apply -f test-pvc.yaml
kubectl get pvc test-claim
```

**Question**: What's the status of your PVC? Why do you think it's in this state?

### Step 4: Understanding the Components

Look at the storage class definition again. Can you identify:
1. What each field does?
2. Why `volumeBindingMode` is set to `WaitForFirstConsumer`?
3. What `reclaimPolicy: Delete` means?

## Mini-Project: Storage Class Inspector

Create a script that analyzes all storage classes in your cluster:

```bash
#!/bin/bash
# storage-inspector.sh

echo "Storage Class Analysis Report"
echo "============================"

# List all storage classes with key info
kubectl get storageclass -o custom-columns=\
NAME:.metadata.name,\
PROVISIONER:.provisioner,\
RECLAIM:.reclaimPolicy,\
BINDING:.volumeBindingMode,\
DEFAULT:.metadata.annotations.storageclass\.kubernetes\.io/is-default-class

echo ""
echo "Detailed Analysis:"
for sc in $(kubectl get storageclass -o name | cut -d/ -f2); do
    echo "Storage Class: $sc"
    echo "Provisioner: $(kubectl get storageclass $sc -o jsonpath='{.provisioner}')"
    echo "Parameters: $(kubectl get storageclass $sc -o jsonpath='{.parameters}')"
    echo "---"
done
```

## Reflection Questions

1. Why might you want multiple storage classes in a cluster?
2. What happens if you don't specify a `storageClassName` in a PVC?
3. How does `WaitForFirstConsumer` help with node affinity and availability zones?
4. When would you use `Retain` vs `Delete` reclaim policy?

## Next Steps Preview

In Unit 2, we'll explore how different provisioners work and create storage classes for cloud providers. Think about:
- What cloud provider are you using (or planning to use)?
- What types of workloads need different storage characteristics?

## Cleanup
```bash
kubectl delete pvc test-claim
kubectl delete storageclass simple-local
```

## Assessment Checklist
- [ ] Can explain what a Storage Class is in simple terms
- [ ] Can identify the four key components of a Storage Class
- [ ] Can create a basic Storage Class definition
- [ ] Understands the difference between static and dynamic provisioning
- [ ] Can troubleshoot why a PVC might be pending