# Unit 4: Advanced Storage Backends and Security

## Learning Objectives
By the end of this unit, you will:
- Understand different storage backend types (NFS, Ceph, cloud-native solutions)
- Implement storage security with encryption and access controls
- Configure storage authentication and authorization
- Work with external storage systems and CSI drivers
- Design secure storage architectures for sensitive data

## Prerequisites
- Completed Units 1-3: Basic storage concepts, StorageClasses, and StatefulSets
- Understanding of Kubernetes RBAC concepts
- Basic knowledge of encryption concepts
- Familiarity with network storage systems (helpful but not required)

---

## 1. Storage Backend Fundamentals

### Understanding Storage Types

Let's start by understanding the different categories of storage backends available in Kubernetes:

```bash
# Examine your current storage ecosystem
echo "=== Current Storage Environment Analysis ==="

# Check available storage classes and their provisioners
kubectl get storageclass -o custom-columns="NAME:.metadata.name,PROVISIONER:.provisioner,PARAMETERS:.parameters"

# Check what CSI drivers are available
kubectl get csinode -o custom-columns="NODE:.metadata.name,DRIVERS:.spec.drivers[*].name"

# Check storage capacity if available
kubectl get csistoragecapacity 2>/dev/null || echo "CSI storage capacity not available"

# Look at existing PVs and their types
kubectl get pv -o custom-columns="NAME:.metadata.name,CAPACITY:.spec.capacity.storage,ACCESS_MODES:.spec.accessModes,STORAGE_CLASS:.spec.storageClassName,TYPE:.spec.hostPath.path"
```

### Storage Backend Categories

| Category | Examples | Use Cases | Characteristics |
|----------|----------|-----------|----------------|
| **Local** | hostPath, local volumes | Development, testing | High performance, node-bound |
| **Network Attached** | NFS, SMB/CIFS | Shared storage needs | Multi-access, network dependent |
| **Block Storage** | iSCSI, FC, cloud disks | Databases, high performance | Raw block access, single attachment |
| **Object Storage** | S3, GCS, Azure Blob | Backups, static content | Web APIs, eventual consistency |
| **Distributed** | Ceph, GlusterFS | Scale-out storage | Fault tolerance, scalability |
| **Cloud Native** | EBS, GCE PD, Azure Disk | Cloud deployments | Managed, integrated billing |

---

## 2. NFS Storage Backend Implementation

### Setting Up NFS Storage

First, let's implement an NFS-based storage solution that demonstrates shared storage capabilities:

```yaml
# Create file: nfs-storage-setup.yaml
# NFS Server Pod (for demonstration - in production use external NFS)
apiVersion: v1
kind: Pod
metadata:
  name: nfs-server
  labels:
    app: nfs-server
spec:
  containers:
  - name: nfs-server
    image: k8s.gcr.io/volume-nfs:0.8
    ports:
    - containerPort: 2049
      name: nfs
    - containerPort: 20048
      name: mountd
    - containerPort: 111
      name: rpcbind
    securityContext:
      privileged: true
    volumeMounts:
    - name: nfs-storage
      mountPath: /exports
  volumes:
  - name: nfs-storage
    hostPath:
      path: /tmp/nfs-storage
      type: DirectoryOrCreate
  restartPolicy: Always
---
# Service to expose NFS server
apiVersion: v1
kind: Service
metadata:
  name: nfs-server-service
  labels:
    app: nfs-server
spec:
  selector:
    app: nfs-server
  ports:
  - port: 2049
    name: nfs
    protocol: TCP
  - port: 20048
    name: mountd
    protocol: TCP
  - port: 111
    name: rpcbind
    protocol: TCP
  type: ClusterIP
```

### NFS Storage Class and Provisioner

```yaml
# Create file: nfs-provisioner.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nfs-client-provisioner
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nfs-client-provisioner
  template:
    metadata:
      labels:
        app: nfs-client-provisioner
    spec:
      serviceAccountName: nfs-client-provisioner
      containers:
      - name: nfs-client-provisioner
        image: k8s.gcr.io/sig-storage/nfs-subdir-external-provisioner:v4.0.2
        env:
        - name: PROVISIONER_NAME
          value: nfs-provisioner
        - name: NFS_SERVER
          value: nfs-server-service.default.svc.cluster.local
        - name: NFS_PATH
          value: /
        volumeMounts:
        - name: nfs-client-root
          mountPath: /persistentvolumes
      volumes:
      - name: nfs-client-root
        nfs:
          server: nfs-server-service.default.svc.cluster.local
          path: /
---
# ServiceAccount and RBAC for NFS provisioner
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nfs-client-provisioner
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: nfs-client-provisioner-runner
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["persistentvolumes"]
  verbs: ["get", "list", "watch", "create", "delete"]
- apiGroups: [""]
  resources: ["persistentvolumeclaims"]
  verbs: ["get", "list", "watch", "update"]
- apiGroups: ["storage.k8s.io"]
  resources: ["storageclasses"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["events"]
  verbs: ["create", "update", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: run-nfs-client-provisioner
subjects:
- kind: ServiceAccount
  name: nfs-client-provisioner
  namespace: default
roleRef:
  kind: ClusterRole
  name: nfs-client-provisioner-runner
  apiGroup: rbac.authorization.k8s.io
---
# NFS Storage Class
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-shared
provisioner: nfs-provisioner
parameters:
  archiveOnDelete: "false"  # Don't archive data when PVC is deleted
allowVolumeExpansion: false
reclaimPolicy: Delete
volumeBindingMode: Immediate
mountOptions:
  - nfsvers=4.1
  - hard
  - intr
```

### Testing NFS Shared Storage

```yaml
# Create file: nfs-shared-test.yaml
# Test shared ReadWriteMany access with NFS
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-shared-pvc
spec:
  accessModes:
  - ReadWriteMany  # This should work with NFS
  resources:
    requests:
      storage: 5Gi
  storageClassName: nfs-shared
---
# Multiple pods writing to shared storage
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nfs-shared-writers
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nfs-writer
  template:
    metadata:
      labels:
        app: nfs-writer
    spec:
      containers:
      - name: writer
        image: busybox
        command:
        - /bin/sh
        - -c
        - |
          POD_NAME=$(hostname)
          while true; do
            echo "$(date): Message from pod $POD_NAME" >> /shared-data/collaborative.log
            echo "Pod $POD_NAME - File count: $(ls /shared-data/ | wc -l)" >> /shared-data/status-$POD_NAME.txt
            
            # Read what other pods have written
            echo "=== Reading shared data ==="
            cat /shared-data/collaborative.log | tail -5
            
            sleep 20
          done
        volumeMounts:
        - name: shared-storage
          mountPath: /shared-data
        resources:
          requests:
            memory: 32Mi
            cpu: 25m
          limits:
            memory: 64Mi
            cpu: 50m
      volumes:
      - name: shared-storage
        persistentVolumeClaim:
          claimName: nfs-shared-pvc
```

### Deploy and Test NFS Storage

```bash
# Deploy NFS infrastructure
kubectl apply -f nfs-storage-setup.yaml
kubectl apply -f nfs-provisioner.yaml

# Wait for NFS components to be ready
kubectl wait pod/nfs-server --for=condition=Ready --timeout=120s
kubectl wait deployment/nfs-client-provisioner --for=condition=available --timeout=120s

# Test the shared storage
kubectl apply -f nfs-shared-test.yaml
kubectl wait deployment/nfs-shared-writers --for=condition=available --timeout=120s

# Verify shared access
kubectl logs deployment/nfs-shared-writers --tail=10

# Check that all pods can read each other's data
kubectl exec deployment/nfs-shared-writers -- cat /shared-data/collaborative.log
```

---

## 3. Storage Encryption and Security

### Encryption at Rest

```yaml
# Create file: encrypted-storage-class.yaml
# Example for AWS EBS with encryption
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: encrypted-premium
  annotations:
    description: "Encrypted premium storage for sensitive data"
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp3
  encrypted: "true"
  kmsKeyId: "alias/kubernetes-storage-key"  # Use your KMS key
  iops: "3000"
  throughput: "125"
allowVolumeExpansion: true
reclaimPolicy: Retain  # Important: don't auto-delete encrypted data
volumeBindingMode: WaitForFirstConsumer
---
# Alternative: Azure Disk with encryption
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: encrypted-azure
provisioner: kubernetes.io/azure-disk
parameters:
  storageaccounttype: Premium_LRS
  kind: Managed
  diskEncryptionSetID: "/subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.Compute/diskEncryptionSets/{des-name}"
allowVolumeExpansion: true
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
---
# GCP Persistent Disk with encryption
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: encrypted-gcp
provisioner: kubernetes.io/gce-pd
parameters:
  type: pd-ssd
  disk-encryption-key: "projects/{project}/locations/{location}/keyRings/{ring}/cryptoKeys/{key}"
allowVolumeExpansion: true
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
```

### Application-Level Encryption Demo

```yaml
# Create file: app-level-encryption.yaml
apiVersion: v1
kind: Secret
metadata:
  name: encryption-keys
type: Opaque
data:
  # Base64 encoded encryption key (in production, use proper key management)
  encryption.key: YWVzLTI1Ni1rZXktZXhhbXBsZS0xMjM0NTY3ODkwMTI=
  salt: c2FsdC1leGFtcGxlLWZvci1lbmNyeXB0aW9u
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: encrypted-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: encrypted-app
  template:
    metadata:
      labels:
        app: encrypted-app
    spec:
      containers:
      - name: app
        image: busybox
        command:
        - /bin/sh
        - -c
        - |
          echo "Starting encrypted application..."
          
          # Simulate application-level encryption
          encrypt_data() {
            local data="$1"
            local key_file="/etc/encryption/encryption.key"
            
            # Simple XOR encryption for demonstration (use proper encryption in production)
            echo -n "$data" | base64 | tr 'A-Za-z0-9+/' 'N-ZA-Mn-za-m5-90-4+/'
          }
          
          decrypt_data() {
            local encrypted="$1"
            echo -n "$encrypted" | tr 'N-ZA-Mn-za-m5-90-4+/' 'A-Za-z0-9+/' | base64 -d
          }
          
          while true; do
            # Create sensitive data
            sensitive_data="Credit Card: 4532-1234-5678-9012, SSN: 123-45-6789, User: $(date)"
            
            # Encrypt and store
            encrypted_data=$(encrypt_data "$sensitive_data")
            echo "$encrypted_data" > /encrypted-storage/encrypted-$(date +%s).dat
            
            # Verify we can decrypt
            decrypted=$(decrypt_data "$encrypted_data")
            echo "$(date): Stored encrypted data, verified decryption works"
            
            # Show encrypted vs decrypted
            echo "Encrypted: $encrypted_data" >> /encrypted-storage/audit.log
            echo "Original:  $sensitive_data" >> /encrypted-storage/audit.log
            echo "---" >> /encrypted-storage/audit.log
            
            sleep 60
          done
        volumeMounts:
        - name: encrypted-storage
          mountPath: /encrypted-storage
        - name: encryption-keys
          mountPath: /etc/encryption
          readOnly: true
        env:
        - name: ENCRYPTION_KEY_PATH
          value: /etc/encryption/encryption.key
        resources:
          requests:
            memory: 64Mi
            cpu: 50m
          limits:
            memory: 128Mi
            cpu: 100m
      volumes:
      - name: encrypted-storage
        persistentVolumeClaim:
          claimName: encrypted-app-pvc
      - name: encryption-keys
        secret:
          secretName: encryption-keys
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: encrypted-app-pvc
  labels:
    encryption: required
    data-classification: sensitive
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: encrypted-premium  # Use encrypted storage class
```

---

## 4. Storage Access Control and RBAC

### Fine-Grained Storage RBAC

```yaml
# Create file: storage-rbac.yaml
# Create different service accounts for different access levels
apiVersion: v1
kind: ServiceAccount
metadata:
  name: storage-admin
  namespace: default
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: storage-user
  namespace: default
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: storage-readonly
  namespace: default
---
# Storage Admin Role - Full storage management
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: storage-admin-role
rules:
- apiGroups: [""]
  resources: ["persistentvolumes", "persistentvolumeclaims"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["storage.k8s.io"]
  resources: ["storageclasses"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "create"]
  resourceNames: [] # Can access any pod
---
# Storage User Role - Can create and use PVCs
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: storage-user-role
rules:
- apiGroups: [""]
  resources: ["persistentvolumeclaims"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
- apiGroups: [""]
  resources: ["persistentvolumes"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["storage.k8s.io"]
  resources: ["storageclasses"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "create"]
---
# Storage ReadOnly Role - Can only read storage info
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: storage-readonly-role
rules:
- apiGroups: [""]
  resources: ["persistentvolumes", "persistentvolumeclaims"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["storage.k8s.io"]
  resources: ["storageclasses"]
  verbs: ["get", "list", "watch"]
---
# Bind roles to service accounts
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: storage-admin-binding
subjects:
- kind: ServiceAccount
  name: storage-admin
  namespace: default
roleRef:
  kind: Role
  name: storage-admin-role
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: storage-user-binding
subjects:
- kind: ServiceAccount
  name: storage-user
  namespace: default
roleRef:
  kind: Role
  name: storage-user-role
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: storage-readonly-binding
subjects:
- kind: ServiceAccount
  name: storage-readonly
  namespace: default
roleRef:
  kind: Role
  name: storage-readonly-role
  apiGroup: rbac.authorization.k8s.io
```

### Testing RBAC Permissions

```yaml
# Create file: rbac-test-pods.yaml
# Test pod for storage admin
apiVersion: v1
kind: Pod
metadata:
  name: storage-admin-test
spec:
  serviceAccountName: storage-admin
  containers:
  - name: admin-test
    image: bitnami/kubectl:latest
    command: ["sleep", "3600"]
  restartPolicy: Never
---
# Test pod for storage user
apiVersion: v1
kind: Pod
metadata:
  name: storage-user-test
spec:
  serviceAccountName: storage-user
  containers:
  - name: user-test
    image: bitnami/kubectl:latest
    command: ["sleep", "3600"]
  restartPolicy: Never
---
# Test pod for readonly user
apiVersion: v1
kind: Pod
metadata:
  name: storage-readonly-test
spec:
  serviceAccountName: storage-readonly
  containers:
  - name: readonly-test
    image: bitnami/kubectl:latest
    command: ["sleep", "3600"]
  restartPolicy: Never
```

```bash
# Deploy RBAC configuration
kubectl apply -f storage-rbac.yaml
kubectl apply -f rbac-test-pods.yaml

# Wait for test pods
kubectl wait pod/storage-admin-test --for=condition=Ready --timeout=60s
kubectl wait pod/storage-user-test --for=condition=Ready --timeout=60s
kubectl wait pod/storage-readonly-test --for=condition=Ready --timeout=60s

# Test admin permissions (should work)
echo "Testing Storage Admin permissions:"
kubectl exec storage-admin-test -- kubectl get pvc
kubectl exec storage-admin-test -- kubectl get storageclass

# Test user permissions (limited)
echo "Testing Storage User permissions:"
kubectl exec storage-user-test -- kubectl get pvc  # Should work
kubectl exec storage-user-test -- kubectl delete pvc test-pvc 2>/dev/null || echo "Delete failed (expected)"

# Test readonly permissions (very limited)
echo "Testing Storage ReadOnly permissions:"
kubectl exec storage-readonly-test -- kubectl get pvc  # Should work
kubectl exec storage-readonly-test -- kubectl create -f - <<EOF 2>/dev/null || echo "Create failed (expected)"
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: unauthorized-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF
```

---

## 5. CSI Drivers and External Storage

### Understanding CSI (Container Storage Interface)

```bash
# Explore CSI components in your cluster
echo "=== CSI Driver Analysis ==="

# List CSI drivers
kubectl get csidriver

# Check CSI nodes
kubectl get csinode -o yaml

# Look for CSI storage capacity
kubectl get csistoragecapacity

# Check for CSI snapshots support
kubectl get volumesnapshotclass 2>/dev/null || echo "Volume snapshots not available"
```

### Example: Local Storage CSI Driver

```yaml
# Create file: local-storage-csi.yaml
# Local storage provisioner for high-performance local SSDs
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-ssd-fast
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
---
# Create a local PV manually (simulating what CSI driver would do)
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-ssd-pv-1
  labels:
    storage-type: local-ssd
spec:
  capacity:
    storage: 50Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: local-ssd-fast
  local:
    path: /mnt/local-ssd
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - your-node-name  # Replace with actual node name
```

### CSI Snapshot Example

```yaml
# Create file: csi-snapshot-example.yaml
# Volume Snapshot Class (if supported by your CSI driver)
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: fast-snapshot-class
driver: ebs.csi.aws.com  # Use your CSI driver
deletionPolicy: Delete
parameters:
  # CSI driver specific parameters
---
# Create a snapshot of existing volume
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: database-backup-snapshot
spec:
  volumeSnapshotClassName: fast-snapshot-class
  source:
    persistentVolumeClaimName: postgres-data  # Reference existing PVC
---
# Restore from snapshot
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: restored-database
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
  dataSource:
    name: database-backup-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  storageClassName: standard
```

---

## 6. Multi-Tenant Storage Security

### Namespace-Based Storage Isolation

```yaml
# Create file: multi-tenant-storage.yaml
# Create separate namespaces for different teams
apiVersion: v1
kind: Namespace
metadata:
  name: team-alpha
  labels:
    storage-tier: premium
    data-classification: confidential
---
apiVersion: v1
kind: Namespace
metadata:
  name: team-beta
  labels:
    storage-tier: standard
    data-classification: internal
---
apiVersion: v1
kind: Namespace
metadata:
  name: team-gamma
  labels:
    storage-tier: basic
    data-classification: public
---
# Storage classes with different access patterns
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: premium-encrypted
  annotations:
    description: "Premium encrypted storage for confidential data"
provisioner: kubernetes.io/aws-ebs
parameters:
  type: io2
  encrypted: "true"
  iops: "10000"
allowVolumeExpansion: true
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard-secure
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp3
  encrypted: "true"
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: basic-storage
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp2
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
```

### Resource Quotas for Storage

```yaml
# Create file: storage-quotas.yaml
# Team Alpha - Premium tier with high limits
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-alpha-storage-quota
  namespace: team-alpha
spec:
  hard:
    requests.storage: "500Gi"  # Total storage across all PVCs
    persistentvolumeclaims: "20"  # Max number of PVCs
    premium-encrypted.storageclass.storage.k8s.io/requests.storage: "300Gi"
    premium-encrypted.storageclass.storage.k8s.io/persistentvolumeclaims: "10"
---
# Team Beta - Standard tier with medium limits
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-beta-storage-quota
  namespace: team-beta
spec:
  hard:
    requests.storage: "200Gi"
    persistentvolumeclaims: "15"
    standard-secure.storageclass.storage.k8s.io/requests.storage: "150Gi"
    standard-secure.storageclass.storage.k8s.io/persistentvolumeclaims: "10"
---
# Team Gamma - Basic tier with low limits
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-gamma-storage-quota
  namespace: team-gamma
spec:
  hard:
    requests.storage: "50Gi"
    persistentvolumeclaims: "5"
    basic-storage.storageclass.storage.k8s.io/requests.storage: "50Gi"
    basic-storage.storageclass.storage.k8s.io/persistentvolumeclaims: "5"
```

### Network Policies for Storage Access

```yaml
# Create file: storage-network-policies.yaml
# Network policy to restrict access to NFS server
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: nfs-server-access-policy
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: nfs-server
  policyTypes:
  - Ingress
  ingress:
  - from:
    # Only allow access from pods with specific labels
    - podSelector:
        matchLabels:
          storage-access: "nfs-allowed"
    # Only allow access from specific namespaces
    - namespaceSelector:
        matchLabels:
          storage-tier: premium
    ports:
    - protocol: TCP
      port: 2049
    - protocol: TCP
      port: 20048
    - protocol: TCP
      port: 111
---
# Network policy for team isolation
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: team-alpha-storage-isolation
  namespace: team-alpha
spec:
  podSelector: {}  # Apply to all pods in namespace
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: team-alpha
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: team-alpha
  # Allow egress to storage systems
  - to: []
    ports:
    - protocol: TCP
      port: 443  # HTTPS for cloud storage APIs
    - protocol: TCP
      port: 2049  # NFS
```

---

## 7. Storage Security Best Practices Implementation

### Secure Database Deployment

```yaml
# Create file: secure-database-deployment.yaml
apiVersion: v1
kind: Secret
metadata:
  name: secure-db-credentials
  namespace: team-alpha
type: Opaque
data:
  username: cG9zdGdyZXM=  # postgres
  password: c3VwZXJfc2VjdXJlX3Bhc3N3b3JkXzEyMw==  # super_secure_password_123
  encryption-key: YWVzMjU2a2V5Zm9yZGF0YWJhc2VlbmNyeXB0aW9u  # aes256keyfordatabaseencryption
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: secure-database
  namespace: team-alpha
  labels:
    app: secure-database
    security-level: high
spec:
  serviceName: secure-database
  replicas: 1
  selector:
    matchLabels:
      app: secure-database
  template:
    metadata:
      labels:
        app: secure-database
        storage-access: nfs-allowed  # For network policy
      annotations:
        # Security annotations
        seccomp.security.alpha.kubernetes.io/pod: runtime/default
        apparmor.security.beta.kubernetes.io/secure-database: runtime/default
    spec:
      serviceAccountName: storage-user  # Limited permissions
      securityContext:
        runAsNonRoot: true
        runAsUser: 999
        runAsGroup: 999
        fsGroup: 999
        # Prevent privilege escalation
        allowPrivilegeEscalation: false
        # Drop all capabilities
        capabilities:
          drop:
          - ALL
        # Read-only root filesystem
        readOnlyRootFilesystem: true
      
      initContainers:
      - name: secure-init
        image: postgres:14
        securityContext:
          runAsNonRoot: false  # May need root for initialization
          allowPrivilegeEscalation: false
        command:
        - /bin/bash
        - -c
        - |
          echo "Initializing secure database storage..."
          
          # Create directory structure
          mkdir -p /var/lib/postgresql/data
          mkdir -p /tmp/postgresql
          
          # Set proper permissions
          chown -R 999:999 /var/lib/postgresql
          chmod 700 /var/lib/postgresql/data
          
          echo "Secure initialization complete"
        volumeMounts:
        - name: database-storage
          mountPath: /var/lib/postgresql/data
        - name: tmp-volume
          mountPath: /tmp
      
      containers:
      - name: secure-database
        image: postgres:14
        env:
        - name: POSTGRES_DB
          value: securedb
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: secure-db-credentials
              key: username
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: secure-db-credentials
              key: password
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        
        ports:
        - containerPort: 5432
          name: postgresql
        
        # Resource limits for security
        resources:
          requests:
            memory: 512Mi
            cpu: 250m
          limits:
            memory: 1Gi
            cpu: 500m
        
        # Security-focused health checks
        livenessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - pg_isready -U $POSTGRES_USER -d $POSTGRES_DB -t 3
          initialDelaySeconds: 60
          periodSeconds: 30
          timeoutSeconds: 10
          failureThreshold: 3
        
        readinessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - pg_isready -U $POSTGRES_USER -d $POSTGRES_DB -t 3
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
        
        # Secure volume mounts
        volumeMounts:
        - name: database-storage
          mountPath: /var/lib/postgresql/data
        - name: tmp-volume
          mountPath: /tmp
        - name: run-volume
          mountPath: /var/run/postgresql
      
      # Secure volumes
      volumes:
      - name: tmp-volume
        emptyDir: {}
      - name: run-volume
        emptyDir: {}
  
  volumeClaimTemplates:
  - metadata:
      name: database-storage
      labels:
        encryption: required
        backup-required: "true"
        data-classification: confidential
    spec:
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: 50Gi
      storageClassName: premium-encrypted
---
# Secure service with network policy integration
apiVersion: v1
kind: Service
metadata:
  name: secure-database-service
  namespace: team-alpha
  labels:
    app: secure-database
spec:
  selector:
    app: secure-database
  ports:
  - port: 5432
    targetPort: 5432
  type: ClusterIP
```

---

## 8. Storage Monitoring and Auditing

### Storage Security Monitoring

```yaml
# Create file: storage-security-monitoring.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: storage-audit-script
data:
  audit.sh: |
    #!/bin/bash
    
    echo "=== Storage Security Audit ==="
    echo "Audit timestamp: $(date)"
    
    # Check for unencrypted PVCs
    echo "--- Unencrypted Storage Check ---"
    kubectl get pvc -o json | jq -r '
      .items[] | 
      select(.spec.storageClassName | test("encrypted") | not) |
      "\(.metadata.namespace)/\(.metadata.name): \(.spec.storageClassName)"
    '
    
    # Check for PVCs without proper labels
    echo "--- Missing Classification Labels ---"
    kubectl get pvc -o json | jq -r '
      .items[] |
      select(.metadata.labels["data-classification"] == null) |
      "\(.metadata.namespace)/\(.metadata.name): Missing data-classification label"
    '
    
    # Check storage quotas
    echo "--- Storage Quota Usage ---"
    kubectl get resourcequota -o json | jq -r '
      .items[] |
      select(.status.used["requests.storage"] != null) |
      "\(.metadata.namespace): \(.status.used["requests.storage"])/\(.status.hard["requests.storage"])"
    '
    
    # Check for privileged pods with storage access
    echo "--- Privileged Pods with Storage ---"
    kubectl get pods --all-namespaces -o json | jq -r '
      .items[] |
      select(.spec.securityContext.privileged == true and (.spec.volumes[]?.persistentVolumeClaim != null)) |
      "\(.metadata.namespace)/\(.metadata.name): Privileged pod with PVC access"
    '
    
    echo "=== Audit Complete ==="
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: storage-security-audit
spec:
  schedule: "0 */6 * * *"  # Every 6 hours
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: storage-readonly
          containers:
          - name: auditor
            image: bitnami/kubectl:latest
            command: ["/bin/bash", "/scripts/audit.sh"]
            volumeMounts:
            - name: audit-scripts
              mountPath: /scripts
          volumes:
          - name: audit-scripts
            configMap:
              name: storage-audit-script
              defaultMode: 0755
          restartPolicy: OnFailure
```

### Storage Performance Monitoring

```yaml
# Create file: storage-performance-monitoring.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: storage-performance-monitor
spec:
  selector:
    matchLabels:
      app: storage-perf-monitor
  template:
    metadata:
      labels:
        app: storage-perf-monitor
    spec:
      hostNetwork: true
      hostPID: true
      containers:
      - name: monitor
        image: busybox
        securityContext:
          privileged: true  # Needed for system monitoring
        command:
        - /bin/sh
        - -c
        - |
          while true; do
            echo "=== Storage Performance Report ==="
            echo "Node: $(hostname)"
            echo "Timestamp: $(date)"
            
            # Disk I/O statistics
            echo "--- Disk I/O ---"
            cat /proc/diskstats | grep -E "(sd|nvme)" | head -5
            
            # Mount points and usage
            echo "--- Storage Usage ---"
            df -h | grep -E "(kubelet|docker)"
            
            # Storage-related processes
            echo "--- Storage Processes ---"
            ps aux | grep -E "(kubelet|docker|containerd)" | head -3
            
            echo "=========================="
            sleep 300
          done
        volumeMounts:
        - name: proc
          mountPath: /proc
          readOnly: true
        - name: sys
          mountPath: /sys
          readOnly: true
      volumes:
      - name: proc
        hostPath:
          path: /proc
      - name: sys
        hostPath:
          path: /sys
      tolerations:
      - operator: Exists
```

---

## 9. Disaster Recovery and Backup Security

### Secure Backup System

```yaml
# Create file: secure-backup-system.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: secure-backup-job
spec:
  schedule: "0 1 * * *"  # Daily at 1 AM
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: storage-user
          securityContext:
            runAsNonRoot: true
            runAsUser: 1000
            fsGroup: 1000
          containers:
          - name: backup
            image: postgres:14
            command:
            - /bin/bash
            - -c
            - |
              set -euo pipefail
              
              echo "Starting secure backup process..."
              
              # Load credentials
              export AWS_ACCESS_KEY_ID=$(cat /backup-creds/aws-access-key)
              export AWS_SECRET_ACCESS_KEY=$(cat /backup-creds/aws-secret-key)
              ENCRYPTION_PASS=$(cat /backup-creds/encryption-passphrase)
              
              # Create database backup
              TIMESTAMP=$(date +%Y%m%d-%H%M%S)
              BACKUP_FILE="/tmp/backup-$TIMESTAMP.sql"
              
              echo "Creating database dump..."
              PGPASSWORD=$(cat /db-creds/password) pg_dump \
                -h secure-database-service.team-alpha.svc.cluster.local \
                -U $(cat /db-creds/username) \
                -d securedb \
                --no-password \
                > "$BACKUP_FILE"
              
              # Encrypt backup
              echo "Encrypting backup..."
              openssl enc -aes-256-cbc -salt -in "$BACKUP_FILE" \
                -out "${BACKUP_FILE}.enc" -pass pass:"$ENCRYPTION_PASS"
              
              # Generate checksum
              sha256sum "${BACKUP_FILE}.enc" > "${BACKUP_FILE}.enc.sha256"
              
              # Store encrypted backup
              echo "Storing encrypted backup..."
              cp "${BACKUP_FILE}.enc" /backup-storage/
              cp "${BACKUP_FILE}.enc.sha256" /backup-storage/
              
              # Cleanup old backups (keep 30 days)
              find /backup-storage -name "backup-*.sql.enc" -mtime +30 -delete
              find /backup-storage -name "backup-*.sql.enc.sha256" -mtime +30 -delete
              
              # Log success
              echo "$(date): Secure backup completed - $BACKUP_FILE.enc" >> /backup-storage/backup.log
              
              # Cleanup temporary files
              rm -f "$BACKUP_FILE" "${BACKUP_FILE}.enc"
              
              echo "Secure backup process completed"
            volumeMounts:
            - name: backup-storage
              mountPath: /backup-storage
            - name: backup-creds
              mountPath: /backup-creds
              readOnly: true
            - name: db-creds
              mountPath: /db-creds
              readOnly: true
            resources:
              requests:
                memory: 256Mi
                cpu: 200m
              limits:
                memory: 512Mi
                cpu: 500m
          volumes:
          - name: backup-storage
            persistentVolumeClaim:
              claimName: secure-backup-storage
          - name: backup-creds
            secret:
              secretName: backup-credentials
          - name: db-creds
            secret:
              secretName: secure-db-credentials
          restartPolicy: OnFailure
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: secure-backup-storage
  namespace: team-alpha
  labels:
    encryption: required
    backup: "true"
    retention: "long-term"
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
  storageClassName: premium-encrypted
```

---

## 10. Testing and Validation

### Comprehensive Security Testing

```bash
# Create comprehensive test script
cat > test-storage-security.sh << 'EOF'
#!/bin/bash

echo "=== Storage Security Testing Suite ==="

# Test 1: Encryption Verification
echo "Test 1: Verifying encrypted storage classes"
kubectl get storageclass -o json | jq -r '
.items[] | 
select(.parameters.encrypted == "true") | 
"\(.metadata.name): Encryption enabled"
'

# Test 2: RBAC Testing
echo -e "\nTest 2: Testing RBAC permissions"
# Test admin can create PVC
kubectl auth can-i create pvc --as=system:serviceaccount:default:storage-admin
# Test user cannot delete storageclass
kubectl auth can-i delete storageclass --as=system:serviceaccount:default:storage-user
# Test readonly cannot create pvc
kubectl auth can-i create pvc --as=system:serviceaccount:default:storage-readonly

# Test 3: Multi-tenant isolation
echo -e "\nTest 3: Testing namespace isolation"
for ns in team-alpha team-beta team-gamma; do
    quota=$(kubectl get resourcequota -n $ns -o jsonpath='{.items[0].status.hard.requests\.storage}' 2>/dev/null || echo "No quota")
    echo "Namespace $ns storage quota: $quota"
done

# Test 4: Security Context Validation
echo -e "\nTest 4: Checking security contexts"
kubectl get pods --all-namespaces -o json | jq -r '
.items[] | 
select(.spec.securityContext.runAsNonRoot == true) | 
"\(.metadata.namespace)/\(.metadata.name): Running as non-root"
'

# Test 5: Privileged Container Check
echo -e "\nTest 5: Identifying privileged containers with storage access"
kubectl get pods --all-namespaces -o json | jq -r '
.items[] |
select(
  (.spec.securityContext.privileged == true or 
   (.spec.containers[]?.securityContext.privileged == true)) and
  (.spec.volumes[]?.persistentVolumeClaim != null)
) |
"WARNING: \(.metadata.namespace)/\(.metadata.name) is privileged with PVC access"
'

# Test 6: Network Policy Verification
echo -e "\nTest 6: Network policy status"
kubectl get networkpolicy --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,POD-SELECTOR:.spec.podSelector"

echo -e "\n=== Security Testing Complete ==="
EOF

chmod +x test-storage-security.sh
```

### Deploy and Test All Components

```bash
# Deploy NFS infrastructure
kubectl apply -f nfs-storage-setup.yaml
kubectl apply -f nfs-provisioner.yaml

# Deploy encryption components
kubectl apply -f encrypted-storage-class.yaml
kubectl apply -f app-level-encryption.yaml

# Deploy RBAC configuration
kubectl apply -f storage-rbac.yaml
kubectl apply -f rbac-test-pods.yaml

# Deploy multi-tenant setup
kubectl apply -f multi-tenant-storage.yaml
kubectl apply -f storage-quotas.yaml
kubectl apply -f storage-network-policies.yaml

# Deploy secure database
kubectl apply -f secure-database-deployment.yaml

# Deploy monitoring
kubectl apply -f storage-security-monitoring.yaml
kubectl apply -f storage-performance-monitoring.yaml

# Deploy backup system
kubectl apply -f secure-backup-system.yaml

# Wait for critical components
kubectl wait deployment/nfs-client-provisioner --for=condition=available --timeout=120s
kubectl wait statefulset/secure-database -n team-alpha --for=condition=Ready --timeout=300s

# Run security tests
./test-storage-security.sh
```

---

## 11. Production Security Checklist

### Pre-Production Security Audit

```yaml
# Create file: security-audit-checklist.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: security-audit-checklist
data:
  checklist.md: |
    # Storage Security Audit Checklist
    
    ## Encryption
    - [ ] All sensitive data storage classes use encryption at rest
    - [ ] Encryption keys are properly managed (KMS/HSM)
    - [ ] Application-level encryption implemented for sensitive fields
    - [ ] Encryption in transit configured for storage communications
    
    ## Access Control
    - [ ] RBAC properly configured for storage resources
    - [ ] Service accounts follow principle of least privilege
    - [ ] Network policies restrict storage system access
    - [ ] Multi-tenant isolation implemented
    
    ## Authentication & Authorization
    - [ ] Strong authentication for storage admin access
    - [ ] Regular credential rotation policy in place
    - [ ] No hardcoded credentials in configurations
    - [ ] External storage systems use secure authentication
    
    ## Data Protection
    - [ ] Backup encryption enabled
    - [ ] Backup integrity verification implemented
    - [ ] Disaster recovery procedures tested
    - [ ] Data retention policies enforced
    
    ## Monitoring & Auditing
    - [ ] Storage access logging enabled
    - [ ] Security monitoring alerts configured
    - [ ] Regular security audit procedures
    - [ ] Compliance reporting automated
    
    ## Container Security
    - [ ] Containers run as non-root users
    - [ ] Security contexts properly configured
    - [ ] Resource limits enforced
    - [ ] Image security scanning enabled
    
    ## Network Security
    - [ ] Storage network traffic isolated
    - [ ] TLS/encryption for all storage communications
    - [ ] Firewall rules properly configured
    - [ ] VPN/private networking for external storage
---
apiVersion: batch/v1
kind: Job
metadata:
  name: security-audit-runner
spec:
  template:
    spec:
      serviceAccountName: storage-readonly
      containers:
      - name: auditor
        image: bitnami/kubectl:latest
        command:
        - /bin/bash
        - -c
        - |
          echo "Running comprehensive security audit..."
          
          # Load checklist
          cat /checklist/checklist.md
          
          echo -e "\n=== Automated Checks ==="
          
          # Check for unencrypted storage
          echo "Checking for unencrypted storage..."
          UNENCRYPTED=$(kubectl get storageclass -o json | jq -r '
            .items[] | 
            select(.parameters.encrypted != "true" and .metadata.name != "hostpath") | 
            .metadata.name
          ')
          
          if [ -n "$UNENCRYPTED" ]; then
            echo "WARNING: Unencrypted storage classes found: $UNENCRYPTED"
          else
            echo "✓ All storage classes properly encrypted"
          fi
          
          # Check for privileged containers
          PRIVILEGED=$(kubectl get pods --all-namespaces -o json | jq -r '
            .items[] |
            select(.spec.securityContext.privileged == true) |
            "\(.metadata.namespace)/\(.metadata.name)"
          ')
          
          if [ -n "$PRIVILEGED" ]; then
            echo "WARNING: Privileged containers found: $PRIVILEGED"
          else
            echo "✓ No privileged containers detected"
          fi
          
          # Check resource quotas
          echo "Checking resource quotas..."
          kubectl get resourcequota --all-namespaces
          
          echo -e "\n=== Audit Complete ==="
        volumeMounts:
        - name: checklist
          mountPath: /checklist
      volumes:
      - name: checklist
        configMap:
          name: security-audit-checklist
      restartPolicy: Never
```

---

## 12. Advanced Security Scenarios

### Zero-Trust Storage Architecture

```yaml
# Create file: zero-trust-storage.yaml
# Service mesh integration for storage security
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: storage-mtls
  namespace: team-alpha
spec:
  selector:
    matchLabels:
      app: secure-database
  mtls:
    mode: STRICT
---
# Authorization policy for storage access
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: storage-access-policy
  namespace: team-alpha
spec:
  selector:
    matchLabels:
      app: secure-database
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/team-alpha/sa/authorized-app"]
  - to:
    - operation:
        methods: ["GET", "POST"]
        ports: ["5432"]
```

### Storage Data Loss Prevention

```yaml
# Create file: data-loss-prevention.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: dlp-scanner
data:
  scan.py: |
    #!/usr/bin/env python3
    import os
    import re
    import json
    
    # Simple DLP patterns
    patterns = {
        'credit_card': r'\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b',
        'ssn': r'\b\d{3}-\d{2}-\d{4}\b',
        'email': r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'
    }
    
    def scan_directory(path):
        violations = []
        for root, dirs, files in os.walk(path):
            for file in files:
                if file.endswith(('.txt', '.log', '.sql')):
                    filepath = os.path.join(root, file)
                    with open(filepath, 'r', errors='ignore') as f:
                        content = f.read()
                        for pattern_name, pattern in patterns.items():
                            matches = re.findall(pattern, content)
                            if matches:
                                violations.append({
                                    'file': filepath,
                                    'pattern': pattern_name,
                                    'matches': len(matches)
                                })
        return violations
    
    if __name__ == "__main__":
        violations = scan_directory('/scan-data')
        print(json.dumps(violations, indent=2))
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: dlp-scanner
  namespace: team-alpha
spec:
  schedule: "0 */4 * * *"  # Every 4 hours
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: scanner
            image: python:3.9-slim
            command: ["python3", "/scripts/scan.py"]
            volumeMounts:
            - name: dlp-scripts
              mountPath: /scripts
            - name: scan-target
              mountPath: /scan-data
              readOnly: true
          volumes:
          - name: dlp-scripts
            configMap:
              name: dlp-scanner
          - name: scan-target
            persistentVolumeClaim:
              claimName: secure-backup-storage
          restartPolicy: OnFailure
```

---

## 13. Summary and Best Practices

### Key Security Principles Implemented

| Principle | Implementation | Benefit |
|-----------|----------------|---------|
| **Defense in Depth** | Multiple security layers (encryption, RBAC, network policies) | Comprehensive protection |
| **Least Privilege** | Minimal permissions for storage access | Reduced attack surface |
| **Zero Trust** | Verify all storage access regardless of source | Enhanced security posture |
| **Data Classification** | Different security levels based on data sensitivity | Appropriate protection levels |
| **Monitoring & Auditing** | Continuous security monitoring and regular audits | Early threat detection |

### Production-Ready Security Checklist

```bash
# Final validation script
cat > final-security-validation.sh << 'EOF'
#!/bin/bash

echo "=== Final Security Validation ==="

# Check all storage is encrypted
echo "1. Encryption Status:"
kubectl get pvc -o json | jq -r '
.items[] | 
"\(.metadata.namespace)/\(.metadata.name): \(.spec.storageClassName)"
' | while read line; do
    if echo "$line" | grep -q "encrypted"; then
        echo "✓ $line (Encrypted)"
    else
        echo "⚠ $line (Review encryption)"
    fi
done

# Check RBAC implementation
echo -e "\n2. RBAC Status:"
kubectl get rolebinding -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,ROLE:.roleRef.name,SUBJECTS:.subjects[*].name"

# Check security contexts
echo -e "\n3. Security Context Status:"
kubectl get pods --all-namespaces -o json | jq -r '
.items[] |
select(.spec.securityContext.runAsNonRoot == true) |
"✓ \(.metadata.namespace)/\(.metadata.name): Non-root"
'

# Check resource quotas
echo -e "\n4. Resource Quotas:"
kubectl get resourcequota --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,STORAGE:.status.used.requests\.storage,LIMIT:.status.hard.requests\.storage"

# Check backup encryption
echo -e "\n5. Backup Security:"
kubectl get cronjob secure-backup-job -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[0].command}' | grep -q "openssl" && echo "✓ Backup encryption enabled" || echo "⚠ Backup encryption not found"

echo -e "\n=== Validation Complete ==="
EOF

chmod +x final-security-validation.sh
```

---

## 14. Troubleshooting Security Issues

### Common Security Problems and Solutions

```bash
# Debug storage security issues
cat > debug-storage-security.sh << 'EOF'
#!/bin/bash

echo "=== Storage Security Debugging ==="

# Problem 1: PVC stuck due to encryption issues
echo "Debugging encryption issues:"
kubectl get pvc | grep Pending | while read pvc namespace rest; do
    echo "Checking PVC: $pvc"
    kubectl describe pvc "$pvc" | grep -A 5 -B 5 "encryption\|kms\|error"
done

# Problem 2: RBAC permission denied
echo -e "\nDebugging RBAC issues:"
kubectl get events --sort-by='.lastTimestamp' | grep -i "forbidden\|unauthorized" | tail -5

# Problem 3: Network policy blocking storage
echo -e "\nDebugging network policy issues:"
kubectl get networkpolicy --all-namespaces
kubectl describe networkpolicy nfs-server-access-policy 2>/dev/null || echo "NFS network policy not found"

# Problem 4: Security context conflicts
echo -e "\nDebugging security context issues:"
kubectl get pods --all-namespaces -o json | jq -r '
.items[] |
select(.status.phase != "Running") |
"\(.metadata.namespace)/\(.metadata.name): \(.status.phase)"
' | head -5

echo -e "\n=== Debug Complete ==="
EOF

chmod +x debug-storage-security.sh
```

---

## 15. Cleanup

```bash
# Comprehensive cleanup of Unit 4
echo "Cleaning up Unit 4 resources..."

# Delete NFS components
kubectl delete -f nfs-storage-setup.yaml 2>/dev/null || true
kubectl delete -f nfs-provisioner.yaml 2>/dev/null || true
kubectl delete -f nfs-shared-test.yaml 2>/dev/null || true

# Delete encryption components
kubectl delete -f app-level-encryption.yaml 2>/dev/null || true

# Delete RBAC components
kubectl delete -f storage-rbac.yaml 2>/dev/null || true
kubectl delete -f rbac-test-pods.yaml 2>/dev/null || true

# Delete multi-tenant components
kubectl delete -f multi-tenant-storage.yaml 2>/dev/null || true
kubectl delete -f storage-quotas.yaml 2>/dev/null || true
kubectl delete -f storage-network-policies.yaml 2>/dev/null || true

# Delete secure database
kubectl delete -f secure-database-deployment.yaml 2>/dev/null || true

# Delete monitoring components
kubectl delete -f storage-security-monitoring.yaml 2>/dev/null || true
kubectl delete -f storage-performance-monitoring.yaml 2>/dev/null || true

# Delete backup components
kubectl delete -f secure-backup-system.yaml 2>/dev/null || true

# Delete security audit components
kubectl delete -f security-audit-checklist.yaml 2>/dev/null || true
kubectl delete job security-audit-runner 2>/dev/null || true

# Delete advanced security components
kubectl delete -f zero-trust-storage.yaml 2>/dev/null || true
kubectl delete -f data-loss-prevention.yaml 2>/dev/null || true

# Delete CSI components
kubectl delete -f local-storage-csi.yaml 2>/dev/null || true
kubectl delete -f csi-snapshot-example.yaml 2>/dev/null || true

# Delete namespaces (this will cascade delete resources)
kubectl delete namespace team-alpha team-beta team-gamma 2>/dev/null || true

# Clean up remaining PVCs
kubectl delete pvc nfs-shared-pvc encrypted-app-pvc 2>/dev/null || true

# Clean up files
rm -f nfs-storage-setup.yaml nfs-provisioner.yaml nfs-shared-test.yaml
rm -f encrypted-storage-class.yaml app-level-encryption.yaml
rm -f storage-rbac.yaml rbac-test-pods.yaml
rm -f multi-tenant-storage.yaml storage-quotas.yaml storage-network-policies.yaml
rm -f secure-database-deployment.yaml
rm -f storage-security-monitoring.yaml storage-performance-monitoring.yaml
rm -f secure-backup-system.yaml
rm -f local-storage-csi.yaml csi-snapshot-example.yaml
rm -f security-audit-checklist.yaml zero-trust-storage.yaml data-loss-prevention.yaml
rm -f test-storage-security.sh final-security-validation.sh debug-storage-security.sh

echo "Unit 4 cleanup complete!"
```

---

## Next Steps

In Unit 5, we'll cover:
- **Backup and Disaster Recovery** strategies
- **Storage monitoring and alerting** systems
- **Performance optimization** techniques
- **Cost management** and optimization
- **Troubleshooting** complex storage issues

### Prerequisites for Unit 5
Before moving forward, ensure you understand:
- Different storage backend types and their use cases
- Storage encryption implementation (at rest and in transit)
- RBAC configuration for storage resources
- Multi-tenant storage isolation patterns
- Security monitoring and auditing approaches

**Key Takeaways from Unit 4:**
1. **Storage security is multi-layered** - encryption, access control, and monitoring work together
2. **Different backends have different security characteristics** - choose appropriately
3. **RBAC is crucial** for controlling storage resource access
4. **Multi-tenancy requires careful isolation** - use namespaces, quotas, and network policies
5. **Monitoring and auditing are essential** for maintaining security posture

The security patterns we've covered form the foundation for enterprise-grade storage implementations in production Kubernetes environments.