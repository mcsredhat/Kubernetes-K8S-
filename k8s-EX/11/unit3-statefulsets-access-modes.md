# Unit 3: StatefulSets and Volume Access Modes

## Learning Objectives
By the end of this unit, you will:
- Understand when and why to use StatefulSets for storage-dependent applications
- Master the three volume access modes and their real-world implications
- Deploy clustered applications with individual persistent storage per instance
- Implement multi-container storage sharing patterns
- Use init containers for storage preparation and data migration

## Prerequisites
- Completed Unit 1: Understanding the Container Storage Problem
- Completed Unit 2: Dynamic Storage Provisioning with StorageClasses
- Understanding of Deployments and Services
- Familiarity with database concepts (helpful but not required)

---

## 1. The StatefulSet Storage Challenge

### Why Deployments Aren't Enough

Let's start by understanding the limitation of regular Deployments when it comes to stateful applications.

```bash
# Deploy a database with a regular Deployment (the wrong way)
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-db-storage
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: standard
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql-deployment
spec:
  replicas: 3  # Multiple database instances sharing storage - problems ahead!
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: rootpassword
        volumeMounts:
        - name: mysql-data
          mountPath: /var/lib/mysql
      volumes:
      - name: mysql-data
        persistentVolumeClaim:
          claimName: shared-db-storage
EOF

# Check what happens
kubectl get pods -l app=mysql
kubectl describe pods -l app=mysql
```

**Prediction Questions:**
- What problems do you expect with 3 database pods sharing the same storage?
- Why might ReadWriteOnce access mode cause issues here?
- How would the pods get scheduled across different nodes?

**Observation Exercise:**
Look at the pod status. What do you see? Why are some pods failing?

---

## 2. Introduction to StatefulSets

### StatefulSet Core Concepts

StatefulSets solve stateful application challenges by providing:
- **Ordered deployment and scaling** (pod-0, pod-1, pod-2)
- **Stable network identities** (predictable DNS names)
- **Individual persistent storage** per pod
- **Ordered rolling updates** and deletions

### Your First StatefulSet

```yaml
# Create file: first-statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql-cluster
spec:
  serviceName: mysql-headless  # Required for stable network identity
  replicas: 3
  selector:
    matchLabels:
      app: mysql-cluster
  template:
    metadata:
      labels:
        app: mysql-cluster
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: rootpassword
        - name: MYSQL_DATABASE
          value: testdb
        ports:
        - containerPort: 3306
        volumeMounts:
        - name: mysql-data
          mountPath: /var/lib/mysql
        resources:
          requests:
            memory: 512Mi
            cpu: 250m
          limits:
            memory: 1Gi
            cpu: 500m
  # This is the magic - automatic PVC creation per pod
  volumeClaimTemplates:
  - metadata:
      name: mysql-data
    spec:
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: 10Gi
      storageClassName: standard
---
# Headless service for stable network identity
apiVersion: v1
kind: Service
metadata:
  name: mysql-headless
spec:
  clusterIP: None  # Headless service
  selector:
    app: mysql-cluster
  ports:
  - port: 3306
    targetPort: 3306
```

```bash
# Clean up the problematic deployment first
kubectl delete deployment mysql-deployment
kubectl delete pvc shared-db-storage

# Deploy the StatefulSet
kubectl apply -f first-statefulset.yaml

# Watch the ordered creation
kubectl get pods -l app=mysql-cluster -w
# Press Ctrl+C after all pods are running
```

### Observing StatefulSet Behavior

```bash
# Check pod names and order
kubectl get pods -l app=mysql-cluster

# Check automatically created PVCs
kubectl get pvc

# Check the stable DNS names
kubectl run debug-pod --image=busybox --rm -it --restart=Never -- nslookup mysql-cluster-0.mysql-headless
```

**Analysis Questions:**
1. What pattern do you notice in the pod names?
2. How many PVCs were created? What are their names?
3. Did all pods start simultaneously or in sequence?

---

## 3. Deep Dive: Volume Access Modes

### Understanding the Three Access Modes

| Access Mode | Description | Use Cases | Limitations |
|-------------|-------------|-----------|-------------|
| **ReadWriteOnce (RWO)** | Single pod read-write access | Databases, single-instance apps | Cannot share between pods |
| **ReadOnlyMany (ROX)** | Multiple pods read-only access | Static content, configuration | No write access for pods |
| **ReadWriteMany (RWX)** | Multiple pods read-write access | Shared file systems, NFS | Requires special storage backend |

### Hands-On: Access Mode Experiments

#### Experiment 1: ReadWriteOnce Limitations

```yaml
# Create file: rwo-experiment.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: rwo-test-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: standard
---
# First pod uses the storage
apiVersion: v1
kind: Pod
metadata:
  name: rwo-writer-1
  labels:
    app: rwo-test
spec:
  containers:
  - name: writer
    image: busybox
    command: ["sleep", "3600"]
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: rwo-test-pvc
---
# Second pod tries to use the same storage
apiVersion: v1
kind: Pod
metadata:
  name: rwo-writer-2
  labels:
    app: rwo-test
spec:
  containers:
  - name: writer
    image: busybox
    command: ["sleep", "3600"]
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: rwo-test-pvc
```

```bash
# Apply and observe
kubectl apply -f rwo-experiment.yaml

# Check pod status
kubectl get pods -l app=rwo-test
kubectl describe pod rwo-writer-2

# What happened to the second pod?
kubectl get events --sort-by='.lastTimestamp' | grep rwo-writer-2
```

#### Experiment 2: ReadOnlyMany Pattern

```yaml
# Create file: rox-experiment.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: rox-config-pvc
spec:
  accessModes:
  - ReadOnlyMany
  resources:
    requests:
      storage: 1Gi
  storageClassName: standard
---
# Configuration manager pod (writes initial config)
apiVersion: v1
kind: Pod
metadata:
  name: config-manager
spec:
  containers:
  - name: manager
    image: busybox
    command:
    - /bin/sh
    - -c
    - |
      echo "Creating shared configuration..."
      echo "app.name=MyApp" > /config/app.properties
      echo "app.version=1.0.0" >> /config/app.properties
      echo "database.host=mysql-cluster-0.mysql-headless" >> /config/app.properties
      echo "Configuration created at $(date)" >> /config/app.properties
      sleep 10
      echo "Configuration setup complete"
    volumeMounts:
    - name: config-storage
      mountPath: /config
  volumes:
  - name: config-storage
    persistentVolumeClaim:
      claimName: rox-config-pvc
  restartPolicy: Never
---
# Multiple application pods reading the same config
apiVersion: apps/v1
kind: Deployment
metadata:
  name: config-readers
spec:
  replicas: 3
  selector:
    matchLabels:
      app: config-reader
  template:
    metadata:
      labels:
        app: config-reader
    spec:
      containers:
      - name: app
        image: busybox
        command:
        - /bin/sh
        - -c
        - |
          while true; do
            echo "=== Pod $(hostname) reading config ==="
            cat /shared-config/app.properties 2>/dev/null || echo "Config not ready yet"
            echo "================================="
            sleep 30
          done
        volumeMounts:
        - name: shared-config
          mountPath: /shared-config
          readOnly: true  # Explicitly read-only
      volumes:
      - name: shared-config
        persistentVolumeClaim:
          claimName: rox-config-pvc
```

```bash
# Apply and test
kubectl apply -f rox-experiment.yaml

# Wait for config to be created
kubectl wait pod/config-manager --for=condition=Ready --timeout=60s
kubectl logs config-manager

# Check that multiple pods can read
kubectl wait deployment/config-readers --for=condition=available --timeout=60s
kubectl logs deployment/config-readers --tail=10

# Try to write from a reader pod (should fail)
kubectl exec deployment/config-readers -- touch /shared-config/test-write.txt
```

#### Experiment 3: ReadWriteMany Use Case

**Note:** This experiment works best with NFS or cloud storage that supports RWX. For local testing, we'll simulate the concept.

```yaml
# Create file: rwx-experiment.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: rwx-shared-pvc
spec:
  accessModes:
  - ReadWriteMany  # This may not work with all storage providers
  resources:
    requests:
      storage: 2Gi
  storageClassName: standard
---
# Collaborative application pods
apiVersion: apps/v1
kind: Deployment
metadata:
  name: collaborative-writers
spec:
  replicas: 2
  selector:
    matchLabels:
      app: collaborative-app
  template:
    metadata:
      labels:
        app: collaborative-app
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
            echo "$(date): Message from $POD_NAME" >> /shared-data/collaborative.log
            echo "$POD_NAME wrote to shared log at $(date)"
            sleep 15
          done
        volumeMounts:
        - name: shared-storage
          mountPath: /shared-data
      volumes:
      - name: shared-storage
        persistentVolumeClaim:
          claimName: rwx-shared-pvc
```

```bash
# Try to apply (this may fail with many storage providers)
kubectl apply -f rwx-experiment.yaml

# Check if PVC binds
kubectl get pvc rwx-shared-pvc

# If it fails, check the error
kubectl describe pvc rwx-shared-pvc
```

---

## 4. Real-World StatefulSet Patterns

### Pattern 1: Distributed Database Cluster

Let's build a more realistic distributed database that demonstrates advanced StatefulSet concepts.

```yaml
# Create file: distributed-db-cluster.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: cassandra-cluster
spec:
  serviceName: cassandra
  replicas: 3
  selector:
    matchLabels:
      app: cassandra
  template:
    metadata:
      labels:
        app: cassandra
    spec:
      initContainers:
      # Init container prepares the storage and configuration
      - name: cassandra-init
        image: busybox
        command:
        - /bin/sh
        - -c
        - |
          echo "Initializing Cassandra node storage..."
          
          # Create necessary directories
          mkdir -p /var/lib/cassandra/data
          mkdir -p /var/lib/cassandra/commitlog
          mkdir -p /var/lib/cassandra/saved_caches
          
          # Set ownership (in real scenarios, match the cassandra user)
          chown -R 999:999 /var/lib/cassandra 2>/dev/null || true
          
          echo "Storage initialization complete"
        volumeMounts:
        - name: cassandra-data
          mountPath: /var/lib/cassandra
      containers:
      - name: cassandra
        image: cassandra:3.11
        env:
        - name: CASSANDRA_CLUSTER_NAME
          value: "K8sCluster"
        - name: CASSANDRA_DC
          value: "DC1"
        - name: CASSANDRA_RACK
          value: "Rack1"
        - name: CASSANDRA_SEEDS
          value: "cassandra-0.cassandra.default.svc.cluster.local,cassandra-1.cassandra.default.svc.cluster.local"
        - name: POD_IP
          valueFrom:
            fieldRef:
              fieldPath: status.podIP
        ports:
        - containerPort: 9042  # CQL port
        - containerPort: 7000  # Inter-node communication
        volumeMounts:
        - name: cassandra-data
          mountPath: /var/lib/cassandra
        resources:
          requests:
            memory: 1Gi
            cpu: 500m
          limits:
            memory: 2Gi
            cpu: 1000m
        livenessProbe:
          tcpSocket:
            port: 9042
          initialDelaySeconds: 90
          periodSeconds: 30
        readinessProbe:
          exec:
            command:
            - /bin/bash
            - -c
            - "nodetool status | grep $POD_IP | grep UN"
          initialDelaySeconds: 120
          periodSeconds: 30
  volumeClaimTemplates:
  - metadata:
      name: cassandra-data
    spec:
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: 20Gi
      storageClassName: standard
---
apiVersion: v1
kind: Service
metadata:
  name: cassandra
spec:
  clusterIP: None
  selector:
    app: cassandra
  ports:
  - port: 9042
```

### Pattern 2: Multi-Container Pod Storage Sharing

```yaml
# Create file: multi-container-storage.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web-app-with-sidecar
spec:
  serviceName: web-app
  replicas: 2
  selector:
    matchLabels:
      app: web-app-sidecar
  template:
    metadata:
      labels:
        app: web-app-sidecar
    spec:
      initContainers:
      # Init container sets up the shared storage structure
      - name: storage-init
        image: busybox
        command:
        - /bin/sh
        - -c
        - |
          echo "Setting up shared storage structure..."
          mkdir -p /shared-data/webapp-files
          mkdir -p /shared-data/logs
          mkdir -p /shared-data/cache
          mkdir -p /shared-data/backups
          
          # Create initial index file
          echo "<h1>Web App $(hostname)</h1>" > /shared-data/webapp-files/index.html
          echo "<p>Initialized at $(date)</p>" >> /shared-data/webapp-files/index.html
          
          echo "Storage structure created"
        volumeMounts:
        - name: shared-storage
          mountPath: /shared-data
      containers:
      # Main web application
      - name: webapp
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: shared-storage
          mountPath: /usr/share/nginx/html
          subPath: webapp-files
        - name: shared-storage
          mountPath: /var/log/nginx
          subPath: logs
        resources:
          requests:
            memory: 64Mi
            cpu: 50m
          limits:
            memory: 128Mi
            cpu: 100m
      # Log processing sidecar
      - name: log-processor
        image: busybox
        command:
        - /bin/sh
        - -c
        - |
          while true; do
            echo "Processing logs at $(date)"
            
            # Compress old logs
            find /logs -name "*.log" -mtime +1 -exec gzip {} \; 2>/dev/null || true
            
            # Archive very old logs
            find /logs -name "*.gz" -mtime +7 -exec mv {} /backups/ \; 2>/dev/null || true
            
            # Clean up ancient backups
            find /backups -name "*.gz" -mtime +30 -delete 2>/dev/null || true
            
            # Create log summary
            LOG_COUNT=$(find /logs -name "*.log" | wc -l)
            BACKUP_COUNT=$(find /backups -name "*.gz" | wc -l)
            echo "$(date): Active logs: $LOG_COUNT, Archived: $BACKUP_COUNT" >> /logs/processing-summary.log
            
            sleep 300  # Process every 5 minutes
          done
        volumeMounts:
        - name: shared-storage
          mountPath: /logs
          subPath: logs
        - name: shared-storage
          mountPath: /backups
          subPath: backups
        resources:
          requests:
            memory: 32Mi
            cpu: 25m
          limits:
            memory: 64Mi
            cpu: 50m
      # Cache management sidecar
      - name: cache-manager
        image: busybox
        command:
        - /bin/sh
        - -c
        - |
          while true; do
            echo "Managing cache at $(date)"
            
            # Create some sample cache entries
            echo "cache-entry-$(date +%s)" > /cache/temp-$(hostname)-$(date +%s).cache
            
            # Clean old cache files (older than 10 minutes for demo)
            find /cache -name "*.cache" -mmin +10 -delete 2>/dev/null || true
            
            # Cache statistics
            CACHE_COUNT=$(find /cache -name "*.cache" | wc -l)
            CACHE_SIZE=$(du -sh /cache 2>/dev/null | cut -f1)
            echo "$(date): Cache entries: $CACHE_COUNT, Size: $CACHE_SIZE" >> /cache/cache-stats.log
            
            sleep 180  # Manage every 3 minutes
          done
        volumeMounts:
        - name: shared-storage
          mountPath: /cache
          subPath: cache
        resources:
          requests:
            memory: 32Mi
            cpu: 25m
          limits:
            memory: 64Mi
            cpu: 50m
  volumeClaimTemplates:
  - metadata:
      name: shared-storage
    spec:
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: 5Gi
      storageClassName: standard
---
apiVersion: v1
kind: Service
metadata:
  name: web-app
spec:
  selector:
    app: web-app-sidecar
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
```

### Deploy and Test the Patterns

```bash
# Deploy the distributed database
kubectl apply -f distributed-db-cluster.yaml

# Deploy the multi-container application
kubectl apply -f multi-container-storage.yaml

# Monitor the StatefulSet deployments
kubectl get statefulsets
kubectl get pods -l app=cassandra
kubectl get pods -l app=web-app-sidecar

# Wait for services to be ready
kubectl wait statefulset/cassandra-cluster --for=jsonpath='{.status.readyReplicas}'=3 --timeout=300s
kubectl wait statefulset/web-app-with-sidecar --for=jsonpath='{.status.readyReplicas}'=2 --timeout=180s
```

---

## 5. Storage Initialization and Migration Patterns

### Advanced Init Container Usage

```yaml
# Create file: storage-migration-example.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: migration-scripts
data:
  migrate.sh: |
    #!/bin/bash
    set -e
    
    echo "Starting storage migration at $(date)"
    
    # Check if this is a fresh installation
    if [ ! -f /data/version.txt ]; then
        echo "Fresh installation detected"
        echo "1.0.0" > /data/version.txt
        
        # Create initial directory structure
        mkdir -p /data/uploads
        mkdir -p /data/user-data
        mkdir -p /data/cache
        
        echo "Initial setup complete"
        exit 0
    fi
    
    # Read current version
    CURRENT_VERSION=$(cat /data/version.txt)
    TARGET_VERSION="2.0.0"
    
    echo "Current version: $CURRENT_VERSION"
    echo "Target version: $TARGET_VERSION"
    
    # Perform migration based on version
    case $CURRENT_VERSION in
        "1.0.0")
            echo "Migrating from 1.0.0 to 2.0.0"
            
            # Backup existing data
            if [ -d /data/uploads ]; then
                cp -r /data/uploads /data/uploads.backup.$(date +%Y%m%d)
            fi
            
            # Restructure directories
            mkdir -p /data/media/images
            mkdir -p /data/media/documents
            
            # Move existing uploads to new structure
            if [ -d /data/uploads ]; then
                mv /data/uploads/* /data/media/images/ 2>/dev/null || true
            fi
            
            # Update version
            echo "2.0.0" > /data/version.txt
            echo "Migration to 2.0.0 complete"
            ;;
        "2.0.0")
            echo "Already at target version"
            ;;
        *)
            echo "Unknown version: $CURRENT_VERSION"
            exit 1
            ;;
    esac
    
    echo "Migration completed at $(date)"
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: app-with-migration
spec:
  serviceName: migrated-app
  replicas: 1
  selector:
    matchLabels:
      app: migrated-app
  template:
    metadata:
      labels:
        app: migrated-app
    spec:
      initContainers:
      - name: storage-migrator
        image: busybox
        command: ["/bin/sh", "/scripts/migrate.sh"]
        volumeMounts:
        - name: app-data
          mountPath: /data
        - name: migration-scripts
          mountPath: /scripts
        resources:
          requests:
            memory: 64Mi
            cpu: 100m
          limits:
            memory: 128Mi
            cpu: 200m
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: app-data
          mountPath: /usr/share/nginx/html
          subPath: media
        command:
        - /bin/sh
        - -c
        - |
          # Create a simple status page showing migration info
          cat > /usr/share/nginx/html/index.html << EOF
          <h1>Migrated Application</h1>
          <p>Pod: $(hostname)</p>
          <p>Started at: $(date)</p>
          <p>Data version: $(cat /data/version.txt 2>/dev/null || echo 'unknown')</p>
          <h2>Data Structure:</h2>
          <pre>$(ls -la /data/ 2>/dev/null || echo 'No data directory')</pre>
          EOF
          
          exec nginx -g 'daemon off;'
        lifecycle:
          preStop:
            exec:
              command:
              - /bin/sh
              - -c
              - |
                echo "Pod shutting down at $(date)" >> /data/shutdown.log
      volumes:
      - name: migration-scripts
        configMap:
          name: migration-scripts
          defaultMode: 0755
  volumeClaimTemplates:
  - metadata:
      name: app-data
    spec:
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: 3Gi
      storageClassName: standard
```

```bash
# Deploy the migration example
kubectl apply -f storage-migration-example.yaml

# Watch the migration process
kubectl logs -f statefulset/app-with-migration -c storage-migrator

# Check the application after migration
kubectl wait statefulset/app-with-migration --for=condition=Ready --timeout=120s

# View the migration results
kubectl exec app-with-migration-0 -- ls -la /data/
kubectl exec app-with-migration-0 -- cat /data/version.txt

# Test the web interface
kubectl port-forward app-with-migration-0 8080:80 &
curl http://localhost:8080
pkill -f "port-forward"
```

---

## 6. StatefulSet Scaling and Management

### Scaling Operations

```bash
# Scale the Cassandra cluster
kubectl scale statefulset cassandra-cluster --replicas=5

# Observe the ordered scaling
kubectl get pods -l app=cassandra -w
# Press Ctrl+C when scaling completes

# Check PVC creation during scaling
kubectl get pvc | grep cassandra

# Scale down (notice the reverse order)
kubectl scale statefulset cassandra-cluster --replicas=3

# Check what happens to PVCs when scaling down
kubectl get pvc | grep cassandra
```

**Important Observation:** StatefulSet PVCs are **not** deleted when scaling down. Why is this behavior important?

### Rolling Updates

```bash
# Update the Cassandra image version
kubectl patch statefulset cassandra-cluster -p '{"spec":{"template":{"spec":{"containers":[{"name":"cassandra","image":"cassandra:4.0"}]}}}}'

# Watch the rolling update (ordered, one by one)
kubectl rollout status statefulset/cassandra-cluster

# Check the update strategy
kubectl describe statefulset cassandra-cluster | grep -A 5 "Update Strategy"
```

---

## 7. Troubleshooting StatefulSets and Storage

### Common Issues and Diagnostics

#### Issue 1: Pod Stuck in Pending Due to Storage

```bash
# Create a diagnostic script
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: storage-diagnostic
spec:
  containers:
  - name: diagnostics
    image: busybox
    command:
    - /bin/sh
    - -c
    - |
      echo "=== Storage Diagnostics ==="
      echo "Node: \$(hostname)"
      echo "Available space:"
      df -h
      echo "=========================="
      sleep 3600
    volumeMounts:
    - name: test-storage
      mountPath: /test
  volumes:
  - name: test-storage
    persistentVolumeClaim:
      claimName: diagnostic-pvc
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: diagnostic-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi  # Intentionally large to potentially cause issues
  storageClassName: standard
EOF

# Check the status
kubectl get pvc diagnostic-pvc
kubectl describe pvc diagnostic-pvc
kubectl get events --sort-by='.lastTimestamp' | grep diagnostic
```

#### Issue 2: StatefulSet Pod Restart Loop

```bash
# Check pod logs for restart issues
kubectl logs cassandra-cluster-0 --previous  # Logs from previous container

# Check persistent volume mounting issues
kubectl describe pod cassandra-cluster-0 | grep -A 10 -B 10 "Volume\|Mount"

# Check storage capacity and usage
kubectl exec cassandra-cluster-0 -- df -h /var/lib/cassandra
```

#### Issue 3: Access Mode Conflicts

```bash
# Create a diagnostic tool for access mode testing
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: access-mode-tester
spec:
  containers:
  - name: tester
    image: busybox
    command:
    - /bin/sh
    - -c
    - |
      while true; do
        echo "Testing access modes..."
        
        # Test write access
        if echo "test-write-\$(date)" > /test-rwo/write-test.txt 2>/dev/null; then
          echo "RWO write: SUCCESS"
        else
          echo "RWO write: FAILED"
        fi
        
        # Test read access
        if cat /test-rox/config.txt > /dev/null 2>/dev/null; then
          echo "ROX read: SUCCESS"
        else
          echo "ROX read: FAILED"
        fi
        
        sleep 30
      done
    volumeMounts:
    - name: rwo-volume
      mountPath: /test-rwo
    - name: rox-volume
      mountPath: /test-rox
      readOnly: true
  volumes:
  - name: rwo-volume
    persistentVolumeClaim:
      claimName: rwo-test-pvc
  - name: rox-volume
    persistentVolumeClaim:
      claimName: rox-config-pvc
EOF

kubectl logs access-mode-tester -f
```

---

## 8. Production Best Practices

### StatefulSet Production Checklist

```yaml
# Create file: production-statefulset-template.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: production-database
  labels:
    app: production-database
    version: v1.0.0
    environment: production
spec:
  serviceName: production-db-headless
  replicas: 3
  selector:
    matchLabels:
      app: production-database
  # Production-grade update strategy
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1  # Only one pod down during updates
  template:
    metadata:
      labels:
        app: production-database
        version: v1.0.0
      annotations:
        # Monitoring and logging annotations
        prometheus.io/scrape: "true"
        prometheus.io/port: "9090"
    spec:
      # Security context
      securityContext:
        runAsNonRoot: true
        runAsUser: 999
        fsGroup: 999
      
      # Anti-affinity to spread pods across nodes
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - production-database
              topologyKey: kubernetes.io/hostname
      
      initContainers:
      - name: storage-init
        image: busybox
        securityContext:
          runAsNonRoot: false  # May need root for directory creation
        command:
        - /bin/sh
        - -c
        - |
          echo "Initializing production storage..."
          mkdir -p /var/lib/postgresql/data
          chown -R 999:999 /var/lib/postgresql
          echo "Production storage ready"
        volumeMounts:
        - name: database-data
          mountPath: /var/lib/postgresql
      
      containers:
      - name: database
        image: postgres:14
        env:
        - name: POSTGRES_DB
          value: proddb
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: username
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: password
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        
        ports:
        - containerPort: 5432
          name: postgresql
        
        # Production-grade resource limits
        resources:
          requests:
            memory: 1Gi
            cpu: 500m
          limits:
            memory: 2Gi
            cpu: 1000m
        
        # Comprehensive health checks
        livenessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - pg_isready -U $POSTGRES_USER -d $POSTGRES_DB
          initialDelaySeconds: 60
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        
        readinessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - pg_isready -U $POSTGRES_USER -d $POSTGRES_DB
          initialDelaySeconds: 30
          periodSeconds: 5
          timeoutSeconds: 3
          successThreshold: 1
          failureThreshold: 3
        
        # Graceful shutdown
        lifecycle:
          preStop:
            exec:
              command:
              - /bin/sh
              - -c
              - |
                echo "Initiating graceful shutdown..."
                pg_ctl stop -D $PGDATA -m smart -w -t 60
        
        volumeMounts:
        - name: database-data
          mountPath: /var/lib/postgresql/data
        - name: config
          mountPath: /etc/postgresql/postgresql.conf
          subPath: postgresql.conf
          readOnly: true
      
      volumes:
      - name: config
        configMap:
          name: postgres-config
  
  # Production storage requirements
  volumeClaimTemplates:
  - metadata:
      name: database-data
      labels:
        app: production-database
        component: data
      annotations:
        volume.kubernetes.io/storage-provisioner: kubernetes.io/aws-ebs
    spec:
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: 100Gi
      storageClassName: production-premium
---
# Headless service for StatefulSet
apiVersion: v1
kind: Service
metadata:
  name: production-db-headless
  labels:
    app: production-database
spec:
  clusterIP: None
  selector:
    app: production-database
  ports:
  - port: 5432
    name: postgresql
---
# Regular service for client connections
apiVersion: v1
kind: Service
metadata:
  name: production-db-service
  labels:
    app: production-database
spec:
  selector:
    app: production-database
  ports:
  - port: 5432
    name: postgresql
  type: ClusterIP
```

---

## 9. Performance Optimization and Monitoring

### Storage Performance Testing

```yaml
# Create file: storage-performance-test.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: storage-performance-test
spec:
  template:
    spec:
      containers:
      - name: performance-tester
        image: busybox
        command:
        - /bin/sh
        - -c
        - |
          echo "=== Storage Performance Test ==="
          echo "Test started at: $(date)"
          echo "Node: $(hostname)"
          
          # Test write performance
          echo "Testing write performance..."
          time dd if=/dev/zero of=/test-data/write-test.dat bs=1M count=100 oflag=direct
          
          # Test read performance
          echo "Testing read performance..."
          time dd if=/test-data/write-test.dat of=/dev/null bs=1M iflag=direct
          
          # Test random I/O (simplified)
          echo "Testing random write performance..."
          for i in $(seq 1 100); do
            dd if=/dev/zero of=/test-data/random-$i.dat bs=4k count=1 oflag=direct 2>/dev/null
          done
          
          # Cleanup
          rm -f /test-data/write-test.dat /test-data/random-*.dat
          
          echo "Performance test completed at: $(date)"
        volumeMounts:
        - name: test-storage
          mountPath: /test-data
        resources:
          requests:
            memory: 128Mi
            cpu: 100m
          limits:
            memory: 256Mi
            cpu: 500m
      volumes:
      - name: test-storage
        persistentVolumeClaim:
          claimName: performance-test-pvc
      restartPolicy: Never
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: performance-test-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: standard
```

```bash
# Run the performance test
kubectl apply -f storage-performance-test.yaml

# Wait for completion and check results
kubectl wait job/storage-performance-test --for=condition=complete --timeout=300s
kubectl logs job/storage-performance-test
```

### Storage Monitoring Setup

```yaml
# Create file: storage-monitoring.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: storage-monitor
  labels:
    app: storage-monitor
spec:
  selector:
    matchLabels:
      app: storage-monitor
  template:
    metadata:
      labels:
        app: storage-monitor
    spec:
      containers:
      - name: monitor
        image: busybox
        command:
        - /bin/sh
        - -c
        - |
          while true; do
            echo "=== Storage Monitoring Report ==="
            echo "Node: $(hostname)"
            echo "Timestamp: $(date)"
            
            # Disk usage
            echo "--- Disk Usage ---"
            df -h | grep -E "(Filesystem|/dev/)"
            
            # PV usage on this node (if any)
            echo "--- Local PV Usage ---"
            find /var/lib/kubelet/pods -name "pvc-*" -type d 2>/dev/null | while read pvc_dir; do
              if [ -d "$pvc_dir" ]; then
                echo "PVC: $(basename $pvc_dir)"
                du -sh "$pvc_dir" 2>/dev/null || echo "  Could not read size"
              fi
            done
            
            echo "=========================="
            sleep 300  # Report every 5 minutes
          done
        volumeMounts:
        - name: kubelet-pods
          mountPath: /var/lib/kubelet/pods
          readOnly: true
        - name: dev
          mountPath: /dev
          readOnly: true
        resources:
          requests:
            memory: 32Mi
            cpu: 25m
          limits:
            memory: 64Mi
            cpu: 50m
      volumes:
      - name: kubelet-pods
        hostPath:
          path: /var/lib/kubelet/pods
      - name: dev
        hostPath:
          path: /dev
      hostNetwork: false
      tolerations:
      - operator: Exists  # Run on all nodes including master
```

---

## 10. Advanced Scenarios and Edge Cases

### Scenario 1: Storage Expansion

```bash
# Check current PVC size
kubectl get pvc cassandra-data-cassandra-cluster-0 -o yaml | grep storage

# Expand the storage (requires allowVolumeExpansion: true in StorageClass)
kubectl patch pvc cassandra-data-cassandra-cluster-0 -p '{"spec":{"resources":{"requests":{"storage":"30Gi"}}}}'

# Monitor the expansion process
kubectl describe pvc cassandra-data-cassandra-cluster-0
kubectl get events --field-selector involvedObject.name=cassandra-data-cassandra-cluster-0

# Check file system expansion inside the pod
kubectl exec cassandra-cluster-0 -- df -h /var/lib/cassandra
```

### Scenario 2: Data Recovery and PVC Replacement

```yaml
# Create file: data-recovery-scenario.yaml
apiVersion: v1
kind: Pod
metadata:
  name: data-recovery-pod
spec:
  containers:
  - name: recovery
    image: busybox
    command:
    - /bin/sh
    - -c
    - |
      echo "=== Data Recovery Simulation ==="
      
      # Check existing data
      echo "Current data:"
      ls -la /data/ || echo "No data directory"
      
      # Simulate data corruption detection
      if [ -f /data/version.txt ]; then
        echo "Found existing data version: $(cat /data/version.txt)"
        echo "Simulating data corruption..."
        
        # Create backup
        tar -czf /recovery/backup-$(date +%Y%m%d-%H%M%S).tar.gz -C /data . 2>/dev/null || true
        
        # Simulate recovery process
        echo "Performing recovery..."
        echo "Data recovered at $(date)" > /data/recovery.log
      else
        echo "No existing data found - fresh start"
        echo "1.0.0" > /data/version.txt
      fi
      
      echo "Recovery simulation complete"
      sleep 3600
    volumeMounts:
    - name: data-volume
      mountPath: /data
    - name: recovery-volume
      mountPath: /recovery
  volumes:
  - name: data-volume
    persistentVolumeClaim:
      claimName: app-with-migration-data-app-with-migration-0  # Reference existing PVC
  - name: recovery-volume
    persistentVolumeClaim:
      claimName: recovery-backup-pvc
  restartPolicy: Never
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: recovery-backup-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: standard
```

### Scenario 3: Cross-Zone Data Replication

```yaml
# Create file: multi-zone-statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: multi-zone-app
spec:
  serviceName: multi-zone
  replicas: 3
  selector:
    matchLabels:
      app: multi-zone-app
  template:
    metadata:
      labels:
        app: multi-zone-app
    spec:
      # Force pods to different zones
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - multi-zone-app
            topologyKey: topology.kubernetes.io/zone
      
      containers:
      - name: app
        image: busybox
        command:
        - /bin/sh
        - -c
        - |
          POD_NAME=$(hostname)
          ZONE=$(cat /etc/zone-info/zone 2>/dev/null || echo "unknown")
          
          echo "Pod $POD_NAME starting in zone: $ZONE"
          
          while true; do
            # Write zone-specific data
            echo "$(date): $POD_NAME in zone $ZONE" >> /data/zone-log.txt
            
            # Simulate cross-zone synchronization check
            echo "Checking cross-zone data sync..."
            OTHER_ZONES=$(find /shared -name "zone-*.sync" -not -name "zone-$ZONE.sync" 2>/dev/null | wc -l)
            echo "$(date): Found $OTHER_ZONES other zone sync files" >> /data/sync-status.txt
            
            # Create sync marker for this zone
            echo "$(date): $POD_NAME active" > /shared/zone-$ZONE.sync
            
            sleep 30
          done
        volumeMounts:
        - name: local-data
          mountPath: /data
        - name: shared-sync
          mountPath: /shared
        - name: zone-info
          mountPath: /etc/zone-info
          readOnly: true
      
      volumes:
      - name: shared-sync
        persistentVolumeClaim:
          claimName: cross-zone-sync-pvc
      - name: zone-info
        downwardAPI:
          items:
          - path: zone
            fieldRef:
              fieldPath: metadata.labels['topology.kubernetes.io/zone']
  
  volumeClaimTemplates:
  - metadata:
      name: local-data
    spec:
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: 2Gi
      storageClassName: standard
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: cross-zone-sync-pvc
spec:
  accessModes:
  - ReadWriteMany  # Shared across zones
  resources:
    requests:
      storage: 1Gi
  storageClassName: standard  # May need NFS or similar for RWX
```

---

## 11. Testing and Validation

### Comprehensive Test Suite

```bash
# Create a test script to validate all concepts
cat > test-unit3-concepts.sh << 'EOF'
#!/bin/bash

echo "=== Unit 3 Concepts Validation ==="

# Test 1: StatefulSet Ordered Creation
echo "Test 1: StatefulSet Ordered Creation"
kubectl get pods -l app=cassandra --sort-by='.metadata.name' -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,AGE:.metadata.creationTimestamp"

# Test 2: Individual PVC Creation
echo -e "\nTest 2: Individual PVC Creation"
kubectl get pvc | grep cassandra | wc -l
echo "Expected: 3 PVCs for 3-replica StatefulSet"

# Test 3: Access Mode Verification
echo -e "\nTest 3: Access Mode Verification"
kubectl get pvc -o custom-columns="NAME:.metadata.name,ACCESS_MODES:.spec.accessModes"

# Test 4: Storage Class Usage
echo -e "\nTest 4: Storage Class Usage"
kubectl get pvc -o custom-columns="NAME:.metadata.name,STORAGE_CLASS:.spec.storageClassName,SIZE:.spec.resources.requests.storage"

# Test 5: Pod-to-Storage Binding
echo -e "\nTest 5: Pod-to-Storage Binding"
for pod in $(kubectl get pods -l app=cassandra -o jsonpath='{.items[*].metadata.name}'); do
    echo "Pod: $pod"
    kubectl get pod $pod -o jsonpath='{.spec.volumes[*].persistentVolumeClaim.claimName}' && echo
done

# Test 6: Multi-Container Storage Sharing
echo -e "\nTest 6: Multi-Container Storage Sharing"
if kubectl get statefulset web-app-with-sidecar >/dev/null 2>&1; then
    kubectl exec web-app-with-sidecar-0 -c webapp -- ls -la /usr/share/nginx/html/
    kubectl exec web-app-with-sidecar-0 -c log-processor -- ls -la /logs/
    kubectl exec web-app-with-sidecar-0 -c cache-manager -- ls -la /cache/
fi

echo -e "\n=== Validation Complete ==="
EOF

chmod +x test-unit3-concepts.sh
./test-unit3-concepts.sh
```

### Performance Comparison Test

```bash
# Compare performance between different access patterns
cat > storage-performance-comparison.sh << 'EOF'
#!/bin/bash

echo "=== Storage Performance Comparison ==="

# Test ReadWriteOnce performance
echo "Testing RWO Performance..."
kubectl apply -f - <<YAML
apiVersion: v1
kind: Pod
metadata:
  name: rwo-perf-test
spec:
  containers:
  - name: test
    image: busybox
    command: ["sh", "-c", "time dd if=/dev/zero of=/data/test bs=1M count=50; sleep 10"]
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: rwo-test-pvc
  restartPolicy: Never
YAML

kubectl wait pod/rwo-perf-test --for=condition=Ready --timeout=60s
kubectl logs rwo-perf-test

# Cleanup
kubectl delete pod rwo-perf-test

echo "Performance testing complete"
EOF

chmod +x storage-performance-comparison.sh
```

---

## 12. Summary and Key Concepts

### What We Accomplished

1. **StatefulSet Mastery**: Created ordered, scalable applications with individual storage
2. **Access Mode Expertise**: Understood RWO, ROX, and RWX patterns and limitations
3. **Multi-Container Patterns**: Implemented shared storage between containers in pods
4. **Production Patterns**: Built production-ready StatefulSets with proper resource management
5. **Advanced Scenarios**: Handled storage expansion, data recovery, and multi-zone deployments

### Key Takeaways

| Concept | Key Insight | Production Impact |
|---------|-------------|------------------|
| **StatefulSet vs Deployment** | StatefulSets provide ordered pods with individual storage | Essential for databases, queues, and stateful services |
| **volumeClaimTemplates** | Automatically creates PVCs for each pod | Eliminates manual PVC management for scaled stateful apps |
| **Access Modes** | RWO = exclusive, ROX = shared read, RWX = shared write | Choose based on application sharing requirements |
| **Init Containers** | Prepare storage before main containers start | Critical for migrations and data initialization |
| **Ordered Operations** | StatefulSets maintain order for scaling and updates | Prevents data corruption in clustered applications |

### Decision Framework

**Use StatefulSet when:**
- Application needs stable, persistent storage per instance
- Pod identity matters (databases, distributed systems)
- Ordered startup/shutdown is required
- Each replica needs unique configuration or data

**Use Deployment when:**
- Application is stateless or shares storage
- Pod identity doesn't matter
- Parallel scaling is preferred
- Storage is external or not required

---

## 13. Practice Exercises

### Exercise 1: Build a Distributed File System
Create a StatefulSet that simulates a distributed file system with:
- 3 replicas, each with its own storage
- Cross-replica file synchronization using an init container
- Health checks that verify file consistency

### Exercise 2: Database Migration Scenario
Implement a database migration pattern that:
- Checks current schema version
- Applies necessary migrations during init
- Handles rollback scenarios
- Maintains data integrity throughout

### Exercise 3: Multi-Tier Storage Application
Design an e-commerce application with:
- Database tier (StatefulSet with premium storage)
- Cache tier (StatefulSet with fast storage) 
- File storage tier (shared storage for product images)
- Log processing (sidecar containers)

---

## 14. Cleanup

```bash
# Clean up all Unit 3 resources
echo "Cleaning up Unit 3 resources..."

# Delete StatefulSets
kubectl delete statefulset cassandra-cluster web-app-with-sidecar app-with-migration multi-zone-app production-database 2>/dev/null || true

# Delete standalone pods
kubectl delete pod rwo-writer-1 rwo-writer-2 config-manager access-mode-tester data-recovery-pod storage-diagnostic 2>/dev/null || true

# Delete deployments
kubectl delete deployment config-readers collaborative-writers 2>/dev/null || true

# Delete jobs and cronjobs
kubectl delete job storage-performance-test manual-backup-test 2>/dev/null || true

# Delete services
kubectl delete service cassandra mysql-headless web-app production-db-headless production-db-service migrated-app multi-zone 2>/dev/null || true

# Delete PVCs (be careful - this deletes data!)
kubectl delete pvc rwo-test-pvc rox-config-pvc rwx-shared-pvc performance-test-pvc diagnostic-pvc recovery-backup-pvc cross-zone-sync-pvc 2>/dev/null || true

# Delete StatefulSet PVCs (these have longer names)
kubectl get pvc | grep -E "(cassandra-data|mysql-data|shared-storage|app-data|local-data|database-data)" | awk '{print $1}' | xargs -r kubectl delete pvc

# Delete ConfigMaps
kubectl delete configmap migration-scripts postgres-config 2>/dev/null || true

# Delete DaemonSet
kubectl delete daemonset storage-monitor 2>/dev/null || true

# Clean up files
rm -f first-statefulset.yaml rwo-experiment.yaml rox-experiment.yaml rwx-experiment.yaml
rm -f distributed-db-cluster.yaml multi-container-storage.yaml storage-migration-example.yaml
rm -f production-statefulset-template.yaml storage-performance-test.yaml storage-monitoring.yaml
rm -f data-recovery-scenario.yaml multi-zone-statefulset.yaml
rm -f test-unit3-concepts.sh storage-performance-comparison.sh

echo "Unit 3 cleanup complete!"
```

---

## Next Steps

In Unit 4, we'll explore:
- **Advanced storage backends** (NFS, Ceph, cloud-native solutions)
- **Storage security** (encryption, access controls, secrets)
- **Backup and disaster recovery** strategies
- **Storage cost optimization** techniques
- **Monitoring and alerting** for storage systems

### Prerequisites for Unit 4
Before moving forward, ensure you can:
- Explain when to use StatefulSet vs Deployment for storage
- Describe the three access modes and their use cases
- Create StatefulSets with proper volume claim templates
- Implement multi-container storage sharing patterns
- Troubleshoot common StatefulSet and storage issues

**Reflection Questions:**
1. How would you design storage for a microservices architecture with 20+ services?
2. What storage patterns would you use for a chat application that needs message persistence?
3. How would you handle database backups in a Kubernetes environment?

These concepts form the foundation for advanced storage topics we'll cover in Unit 4!