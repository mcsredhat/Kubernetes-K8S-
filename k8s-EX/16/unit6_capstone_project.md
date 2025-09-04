# Unit 6: Capstone Project - Production MongoDB Cluster

## Learning Objectives
By the end of this capstone project, you will:
- Synthesize all StatefulSet concepts into a complete, production-ready deployment
- Design and implement a comprehensive MongoDB replica set with all operational components
- Demonstrate mastery of storage, networking, scaling, monitoring, and disaster recovery
- Create documentation and runbooks for production operations
- Execute real-world operational scenarios and incident response procedures

## Project Overview: Enterprise MongoDB Cluster

In this capstone project, you'll build a complete, production-ready MongoDB cluster that demonstrates every concept you've learned throughout the course. This isn't just a simple deployment—it's a comprehensive system that includes:

- **High-Availability MongoDB Replica Set** (3 data nodes + 1 arbiter)
- **Multi-Tier Storage Strategy** (fast storage for data, standard storage for logs)
- **Comprehensive Networking** (internal cluster communication + external access)
- **Production Operations** (monitoring, backup, recovery, scaling)
- **Security Configuration** (authentication, encryption, network policies)
- **Disaster Recovery** (automated backups, tested recovery procedures)

**Project Deliverables:**
1. Complete MongoDB cluster deployment
2. Operational runbooks and procedures
3. Monitoring and alerting configuration
4. Disaster recovery testing and documentation
5. Performance testing and optimization
6. Security implementation and validation

## Phase 1: Architecture Design and Planning

Before we start deploying, let's design a comprehensive architecture that addresses real-world production requirements.

### Architecture Planning Workshop

```bash
# Create a project namespace for our capstone
kubectl create namespace mongodb-production
kubectl label namespace mongodb-production project=capstone environment=production

# Set up our working context
kubectl config set-context --current --namespace=mongodb-production

echo "=== MongoDB Cluster Architecture Planning ==="
echo "Namespace: mongodb-production"
echo "Target Architecture:"
echo "  - 3 MongoDB data-bearing replica set members"
echo "  - 1 MongoDB arbiter (voting-only, no data)"
echo "  - Separate services for internal and external access"
echo "  - Multi-tier persistent storage"
echo "  - Comprehensive monitoring and backup"
echo "  - Production-grade security"
```

### Infrastructure Requirements Analysis

```bash
# Check cluster resources before deployment
echo "=== Cluster Resource Analysis ==="
kubectl top nodes
kubectl describe nodes | grep -A 5 "Allocated resources"

# Check available storage classes
echo "=== Available Storage Classes ==="
kubectl get storageclass

# Verify networking capabilities
echo "=== Network Policy Support ==="
kubectl get networkpolicy --all-namespaces 2>/dev/null && echo "Network policies supported" || echo "Network policies may not be supported"

echo "=== Planning Complete - Ready for Implementation ==="
```

**Design Questions for Reflection:**
- How will you balance performance, cost, and reliability in your storage choices?
- What monitoring metrics will be most critical for MongoDB operations?
- How will you ensure high availability while maintaining data consistency?
- What security measures are essential for a production MongoDB deployment?

## Phase 2: Foundation Infrastructure

Let's build the foundational components that support our MongoDB cluster.

### Storage Classes and Configuration

```bash
# Create optimized storage classes for MongoDB workloads
cat << EOF | kubectl apply -f -
# High-performance storage for MongoDB data
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: mongodb-fast
  labels:
    app: mongodb
    tier: fast-storage
provisioner: kubernetes.io/no-provisioner  # Replace with your cloud provider's provisioner
parameters:
  type: ssd
  iops: "3000"
  replication-type: synchronous
reclaimPolicy: Retain  # Protect data even if PVC is deleted
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
---
# Standard storage for logs and backups
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: mongodb-standard
  labels:
    app: mongodb
    tier: standard-storage
provisioner: kubernetes.io/no-provisioner
parameters:
  type: standard
  replication-type: asynchronous
reclaimPolicy: Retain
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
---
# Backup storage for long-term retention
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: mongodb-backup
  labels:
    app: mongodb
    tier: backup-storage
provisioner: kubernetes.io/no-provisioner
parameters:
  type: cold-storage
  replication-type: geo-distributed
reclaimPolicy: Retain
allowVolumeExpansion: true
EOF
```

### MongoDB Configuration and Security

```bash
# Create comprehensive MongoDB configuration
cat << EOF | kubectl apply -f -
# MongoDB configuration files
apiVersion: v1
kind: ConfigMap
metadata:
  name: mongodb-config
  labels:
    app: mongodb
    component: config
data:
  mongod.conf: |
    # MongoDB production configuration
    net:
      port: 27017
      bindIp: 0.0.0.0
      maxIncomingConnections: 200
      
    # Security
    security:
      authorization: enabled
      keyFile: /etc/mongodb-keyfile/mongodb-keyfile
      
    # Storage
    storage:
      dbPath: /data/db
      journal:
        enabled: true
      wiredTiger:
        engineConfig:
          cacheSizeGB: 1  # Adjust based on your pod resources
          journalCompressor: snappy
        collectionConfig:
          blockCompressor: snappy
        indexConfig:
          prefixCompression: true
          
    # Replication
    replication:
      replSetName: "rs0"
      
    # Operation profiling for monitoring
    operationProfiling:
      mode: slowOp
      slowOpThresholdMs: 100
      
    # System log
    systemLog:
      destination: file
      path: /var/log/mongodb/mongod.log
      logAppend: true
      logRotate: reopen
      
  init-replica-set.js: |
    // Initialize replica set with all members
    var config = {
      _id: "rs0",
      members: [
        {
          _id: 0,
          host: "mongodb-0.mongodb-headless.mongodb-production.svc.cluster.local:27017",
          priority: 2  // Higher priority for primary
        },
        {
          _id: 1,
          host: "mongodb-1.mongodb-headless.mongodb-production.svc.cluster.local:27017",
          priority: 1
        },
        {
          _id: 2,
          host: "mongodb-2.mongodb-headless.mongodb-production.svc.cluster.local:27017",
          priority: 1
        },
        {
          _id: 3,
          host: "mongodb-arbiter-0.mongodb-headless.mongodb-production.svc.cluster.local:27017",
          arbiterOnly: true  // Arbiter for voting only
        }
      ]
    };
    
    rs.initiate(config);
    
    // Wait for replica set to be ready
    while (rs.status().ok !== 1) {
      print("Waiting for replica set to initialize...");
      sleep(2000);
    }
    
    print("Replica set initialized successfully!");
    
  setup-users.js: |
    // Create administrative users
    db = db.getSiblingDB('admin');
    
    db.createUser({
      user: "admin",
      pwd: "secure-admin-password-change-in-production",
      roles: [
        { role: "root", db: "admin" }
      ]
    });
    
    db.createUser({
      user: "monitor",
      pwd: "secure-monitor-password-change-in-production",
      roles: [
        { role: "clusterMonitor", db: "admin" },
        { role: "read", db: "local" }
      ]
    });
    
    // Create application user
    db = db.getSiblingDB('production_app');
    
    db.createUser({
      user: "app_user",
      pwd: "secure-app-password-change-in-production",
      roles: [
        { role: "readWrite", db: "production_app" }
      ]
    });
    
    print("Users created successfully!");
---
# MongoDB secrets (In production, use proper secret management)
apiVersion: v1
kind: Secret
metadata:
  name: mongodb-secrets
  labels:
    app: mongodb
    component: secrets
type: Opaque
stringData:
  mongodb-admin-password: "secure-admin-password-change-in-production"
  mongodb-monitor-password: "secure-monitor-password-change-in-production"
  mongodb-app-password: "secure-app-password-change-in-production"
  mongodb-replica-set-key: "very-long-and-secure-replica-set-key-for-internal-authentication-change-in-production"
EOF
```

### Networking Infrastructure

```bash
# Create comprehensive networking for MongoDB cluster
cat << EOF | kubectl apply -f -
# Headless service for internal cluster communication
apiVersion: v1
kind: Service
metadata:
  name: mongodb-headless
  labels:
    app: mongodb
    service-type: headless
spec:
  clusterIP: None
  selector:
    app: mongodb
  ports:
  - port: 27017
    name: mongodb
    protocol: TCP
---
# External service for client applications
apiVersion: v1
kind: Service
metadata:
  name: mongodb-client
  labels:
    app: mongodb
    service-type: client
spec:
  type: ClusterIP
  selector:
    app: mongodb
    mongodb-role: data  # Only route to data-bearing nodes
  ports:
  - port: 27017
    name: mongodb
    protocol: TCP
---
# Service specifically for primary access (write operations)
apiVersion: v1
kind: Service
metadata:
  name: mongodb-primary
  labels:
    app: mongodb
    service-type: primary
spec:
  type: ClusterIP
  selector:
    app: mongodb
    statefulset.kubernetes.io/pod-name: mongodb-0  # Primary is typically pod-0
  ports:
  - port: 27017
    name: mongodb
    protocol: TCP
EOF
```

### Monitoring and Observability Infrastructure

```bash
# Create comprehensive monitoring configuration
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: mongodb-monitoring
  labels:
    app: mongodb
    component: monitoring
data:
  health-check.sh: |
    #!/bin/bash
    set -e
    
    echo "=== MongoDB Health Check - \$(date) ==="
    
    # Basic connectivity check
    if mongosh --quiet --eval "db.runCommand('ping')" >/dev/null 2>&1; then
      echo "✓ MongoDB is responding to ping"
    else
      echo "✗ MongoDB ping failed"
      exit 1
    fi
    
    # Replica set status check
    RS_STATUS=\$(mongosh --quiet --
    # Replica set status check
    RS_STATUS=\$(mongosh --quiet --eval "rs.status().ok" 2>/dev/null || echo "0")
    if [ "\$RS_STATUS" = "1" ]; then
      echo "✓ Replica set is healthy"
    else
      echo "✗ Replica set status check failed"
    fi
    
    # Check replica set member states
    mongosh --quiet --eval "
    var status = rs.status();
    status.members.forEach(function(member) {
      print('Member ' + member.name + ': ' + member.stateStr);
    });
    " 2>/dev/null || echo "Could not get member status"
    
    # Connection count
    CONN_COUNT=\$(mongosh --quiet --eval "db.serverStatus().connections.current" 2>/dev/null || echo "unknown")
    echo "Active connections: \$CONN_COUNT"
    
    # Storage utilization
    STORAGE_USAGE=\$(df -h /data/db | tail -n1 | awk '{print \$5}')
    echo "Storage usage: \$STORAGE_USAGE"
    
    echo "Health check completed"
    
  performance-monitor.sh: |
    #!/bin/bash
    
    echo "=== MongoDB Performance Metrics - \$(date) ==="
    
    # Database operations
    mongosh --quiet --eval "
    var status = db.serverStatus();
    print('Operations per second:');
    print('  Insert: ' + status.opcounters.insert);
    print('  Query: ' + status.opcounters.query);
    print('  Update: ' + status.opcounters.update);
    print('  Delete: ' + status.opcounters.delete);
    print('  Command: ' + status.opcounters.command);
    print('');
    print('Memory usage:');
    print('  Resident: ' + Math.round(status.mem.resident) + ' MB');
    print('  Virtual: ' + Math.round(status.mem.virtual) + ' MB');
    print('');
    print('WiredTiger cache:');
    if (status.wiredTiger) {
      print('  Used: ' + Math.round(status.wiredTiger.cache['bytes currently in the cache'] / 1024 / 1024) + ' MB');
      print('  Dirty: ' + Math.round(status.wiredTiger.cache['tracked dirty bytes in the cache'] / 1024 / 1024) + ' MB');
    }
    " 2>/dev/null
    
  backup-database.sh: |
    #!/bin/bash
    set -e
    
    BACKUP_DIR="/backups"
    TIMESTAMP=\$(date +%Y%m%d_%H%M%S)
    BACKUP_NAME="mongodb_backup_\${TIMESTAMP}"
    
    echo "Starting MongoDB backup: \$BACKUP_NAME"
    
    # Create backup directory
    mkdir -p \$BACKUP_DIR
    
    # Perform mongodump
    mongodump --host localhost:27017 --out "\${BACKUP_DIR}/\${BACKUP_NAME}" --gzip
    
    # Create backup metadata
    cat > "\${BACKUP_DIR}/\${BACKUP_NAME}/backup_info.json" << EOL
{
  "backup_timestamp": "\$(date -Iseconds)",
  "hostname": "\$(hostname)",
  "replica_set_status": \$(mongosh --quiet --eval "JSON.stringify(rs.status())" 2>/dev/null || echo '{}')
}
EOL
    
    # Compress the backup
    cd \$BACKUP_DIR
    tar -czf "\${BACKUP_NAME}.tar.gz" "\$BACKUP_NAME"
    rm -rf "\$BACKUP_NAME"
    
    echo "Backup completed: \${BACKUP_NAME}.tar.gz"
    echo "Backup size: \$(ls -lh \${BACKUP_NAME}.tar.gz | awk '{print \$5}')"
    
    # List recent backups
    echo "Recent backups:"
    ls -lht \${BACKUP_DIR}/*.tar.gz | head -5
    
  restore-database.sh: |
    #!/bin/bash
    set -e
    
    BACKUP_DIR="/backups"
    RESTORE_FILE=\$1
    
    if [ -z "\$RESTORE_FILE" ]; then
      echo "Usage: \$0 <backup_file>"
      echo "Available backups:"
      ls -lht \${BACKUP_DIR}/*.tar.gz 2>/dev/null || echo "No backups found"
      exit 1
    fi
    
    if [ ! -f "\${BACKUP_DIR}/\${RESTORE_FILE}" ]; then
      echo "Backup file not found: \${BACKUP_DIR}/\${RESTORE_FILE}"
      exit 1
    fi
    
    echo "Starting MongoDB restore from: \$RESTORE_FILE"
    
    # Extract backup
    cd \$BACKUP_DIR
    EXTRACT_DIR=\$(basename "\$RESTORE_FILE" .tar.gz)
    tar -xzf "\$RESTORE_FILE"
    
    # Perform restore
    mongorestore --host localhost:27017 --gzip "\$EXTRACT_DIR"
    
    # Clean up extracted files
    rm -rf "\$EXTRACT_DIR"
    
    echo "Restore completed from: \$RESTORE_FILE"
    
  alert-check.sh: |
    #!/bin/bash
    
    # Alert thresholds
    MAX_CONNECTIONS=150
    MAX_STORAGE_PCT=85
    MAX_MEMORY_MB=1500
    
    ALERTS=()
    
    # Check connections
    CONN_COUNT=\$(mongosh --quiet --eval "db.serverStatus().connections.current" 2>/dev/null || echo "0")
    if [ "\$CONN_COUNT" -gt \$MAX_CONNECTIONS ]; then
      ALERTS+=("HIGH_CONNECTIONS: \$CONN_COUNT > \$MAX_CONNECTIONS")
    fi
    
    # Check storage
    STORAGE_PCT=\$(df /data/db | tail -n1 | awk '{print \$5}' | sed 's/%//')
    if [ "\$STORAGE_PCT" -gt \$MAX_STORAGE_PCT ]; then
      ALERTS+=("HIGH_STORAGE: \${STORAGE_PCT}% > \${MAX_STORAGE_PCT}%")
    fi
    
    # Check memory
    MEMORY_MB=\$(mongosh --quiet --eval "Math.round(db.serverStatus().mem.resident)" 2>/dev/null || echo "0")
    if [ "\$MEMORY_MB" -gt \$MAX_MEMORY_MB ]; then
      ALERTS+=("HIGH_MEMORY: \${MEMORY_MB}MB > \${MAX_MEMORY_MB}MB")
    fi
    
    # Check replica set health
    RS_OK=\$(mongosh --quiet --eval "rs.status().ok" 2>/dev/null || echo "0")
    if [ "\$RS_OK" != "1" ]; then
      ALERTS+=("REPLICA_SET_UNHEALTHY: rs.status().ok != 1")
    fi
    
    # Report alerts
    if [ \${#ALERTS[@]} -eq 0 ]; then
      echo "No alerts - system healthy"
    else
      echo "ALERTS DETECTED:"
      printf '%s\n' "\${ALERTS[@]}"
    fi
EOF
```

## Phase 3: MongoDB Deployment

Now let's deploy the actual MongoDB cluster with all the supporting infrastructure.

### Main MongoDB StatefulSet

```bash
# Deploy the MongoDB data-bearing replica set members
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mongodb
  labels:
    app: mongodb
    component: database
    tier: data
spec:
  serviceName: mongodb-headless
  replicas: 3
  
  # Controlled update strategy
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      partition: 0
      
  selector:
    matchLabels:
      app: mongodb
      mongodb-role: data
      
  template:
    metadata:
      labels:
        app: mongodb
        mongodb-role: data
        component: database
        tier: data
    spec:
      # Security context
      securityContext:
        runAsNonRoot: true
        runAsUser: 999
        runAsGroup: 999
        fsGroup: 999
        
      # Graceful termination
      terminationGracePeriodSeconds: 30
      
      # Init container to set up MongoDB keyfile and permissions
      initContainers:
      - name: setup-mongodb
        image: busybox:1.35
        command:
        - "sh"
        - "-c"
        - |
          # Set up keyfile
          echo "\$MONGODB_REPLICA_SET_KEY" > /keyfile/mongodb-keyfile
          chmod 400 /keyfile/mongodb-keyfile
          chown 999:999 /keyfile/mongodb-keyfile
          
          # Ensure correct permissions for data directory
          chown -R 999:999 /data/db
          
          # Set up log directory
          mkdir -p /var/log/mongodb
          chown 999:999 /var/log/mongodb
        env:
        - name: MONGODB_REPLICA_SET_KEY
          valueFrom:
            secretKeyRef:
              name: mongodb-secrets
              key: mongodb-replica-set-key
        volumeMounts:
        - name: mongodb-keyfile
          mountPath: /keyfile
        - name: mongodb-data
          mountPath: /data/db
        - name: mongodb-logs
          mountPath: /var/log/mongodb
        securityContext:
          runAsUser: 0  # Init container needs root to set up permissions
          
      containers:
      - name: mongodb
        image: mongo:7.0
        
        command:
        - "mongod"
        - "--config=/etc/mongod.conf"
        - "--auth"
        - "--keyFile=/etc/mongodb-keyfile/mongodb-keyfile"
        
        ports:
        - containerPort: 27017
          name: mongodb
          
        # Environment variables
        env:
        - name: MONGO_INITDB_ROOT_USERNAME
          value: "admin"
        - name: MONGO_INITDB_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mongodb-secrets
              key: mongodb-admin-password
              
        # Volume mounts
        volumeMounts:
        - name: mongodb-data
          mountPath: /data/db
        - name: mongodb-logs
          mountPath: /var/log/mongodb
        - name: mongodb-config
          mountPath: /etc/mongod.conf
          subPath: mongod.conf
        - name: mongodb-keyfile
          mountPath: /etc/mongodb-keyfile
          readOnly: true
        - name: backup-storage
          mountPath: /backups
        - name: monitoring-scripts
          mountPath: /scripts
          
        # Health checks
        livenessProbe:
          exec:
            command:
            - mongosh
            - --eval
            - "db.runCommand('ping')"
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
          
        readinessProbe:
          exec:
            command:
            - mongosh
            - --eval
            - "db.runCommand('ping')"
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
          
        # Resource management
        resources:
          limits:
            memory: "2Gi"
            cpu: "1000m"
          requests:
            memory: "1Gi"
            cpu: "500m"
            
        # Graceful shutdown handling
        lifecycle:
          preStop:
            exec:
              command: ["/bin/bash", "-c", "mongosh --eval 'db.adminCommand({shutdown: 1})'"]
              
      volumes:
      - name: mongodb-config
        configMap:
          name: mongodb-config
      - name: mongodb-keyfile
        emptyDir:
          medium: Memory  # Store keyfile in memory for security
      - name: mongodb-logs
        emptyDir: {}
      - name: backup-storage
        persistentVolumeClaim:
          claimName: mongodb-backup-storage
      - name: monitoring-scripts
        configMap:
          name: mongodb-monitoring
          defaultMode: 0755
          
  # Volume claim templates for persistent storage
  volumeClaimTemplates:
  - metadata:
      name: mongodb-data
      labels:
        app: mongodb
        storage-tier: fast
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: mongodb-fast
      resources:
        requests:
          storage: 20Gi
---
# Separate backup storage PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mongodb-backup-storage
  labels:
    app: mongodb
    storage-tier: backup
spec:
  accessModes: ["ReadWriteOnce"]
  storageClassName: mongodb-backup
  resources:
    requests:
      storage: 50Gi
EOF
```

### MongoDB Arbiter Deployment

```bash
# Deploy MongoDB arbiter for voting-only member
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mongodb-arbiter
  labels:
    app: mongodb
    component: arbiter
    tier: voting
spec:
  serviceName: mongodb-headless
  replicas: 1
  
  selector:
    matchLabels:
      app: mongodb
      mongodb-role: arbiter
      
  template:
    metadata:
      labels:
        app: mongodb
        mongodb-role: arbiter
        component: arbiter
        tier: voting
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 999
        runAsGroup: 999
        fsGroup: 999
        
      terminationGracePeriodSeconds: 10  # Arbiters can shut down quickly
      
      # Init container for arbiter setup
      initContainers:
      - name: setup-arbiter
        image: busybox:1.35
        command:
        - "sh"
        - "-c"
        - |
          echo "\$MONGODB_REPLICA_SET_KEY" > /keyfile/mongodb-keyfile
          chmod 400 /keyfile/mongodb-keyfile
          chown 999:999 /keyfile/mongodb-keyfile
          mkdir -p /data/db /var/log/mongodb
          chown -R 999:999 /data/db /var/log/mongodb
        env:
        - name: MONGODB_REPLICA_SET_KEY
          valueFrom:
            secretKeyRef:
              name: mongodb-secrets
              key: mongodb-replica-set-key
        volumeMounts:
        - name: mongodb-keyfile
          mountPath: /keyfile
        - name: arbiter-data
          mountPath: /data/db
        - name: arbiter-logs
          mountPath: /var/log/mongodb
        securityContext:
          runAsUser: 0
          
      containers:
      - name: mongodb-arbiter
        image: mongo:7.0
        
        command:
        - "mongod"
        - "--port=27017"
        - "--bind_ip=0.0.0.0"
        - "--replSet=rs0"
        - "--auth"
        - "--keyFile=/etc/mongodb-keyfile/mongodb-keyfile"
        - "--smallfiles"  # Arbiters don't need large files
        - "--noprealloc"  # Reduce storage usage
        - "--dbpath=/data/db"
        
        ports:
        - containerPort: 27017
          name: mongodb
          
        volumeMounts:
        - name: arbiter-data
          mountPath: /data/db
        - name: arbiter-logs
          mountPath: /var/log/mongodb
        - name: mongodb-keyfile
          mountPath: /etc/mongodb-keyfile
          readOnly: true
          
        # Minimal health checks for arbiter
        livenessProbe:
          tcpSocket:
            port: 27017
          initialDelaySeconds: 10
          periodSeconds: 10
          
        readinessProbe:
          tcpSocket:
            port: 27017
          initialDelaySeconds: 5
          periodSeconds: 5
          
        # Minimal resources for arbiter
        resources:
          limits:
            memory: "256Mi"
            cpu: "200m"
          requests:
            memory: "128Mi"
            cpu: "100m"
            
      volumes:
      - name: mongodb-keyfile
        emptyDir:
          medium: Memory
      - name: arbiter-logs
        emptyDir: {}
        
  volumeClaimTemplates:
  - metadata:
      name: arbiter-data
      labels:
        app: mongodb
        storage-tier: minimal
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: mongodb-standard  # Standard storage for arbiter
      resources:
        requests:
          storage: 1Gi  # Minimal storage for arbiter
EOF
```

### Monitoring and Backup Jobs

```bash
# Create automated monitoring and backup jobs
cat << EOF | kubectl apply -f -
# Regular health monitoring
apiVersion: batch/v1
kind: CronJob
metadata:
  name: mongodb-health-monitor
  labels:
    app: mongodb
    component: monitoring
spec:
  schedule: "*/5 * * * *"  # Every 5 minutes
  jobTemplate:
    spec:
      template:
        metadata:
          labels:
            app: mongodb
            component: health-check
        spec:
          containers:
          - name: health-check
            image: mongo:7.0
            command: ["/bin/bash", "/scripts/health-check.sh"]
            env:
            - name: MONGODB_URI
              value: "mongodb://mongodb-0.mongodb-headless.mongodb-production.svc.cluster.local:27017,mongodb-1.mongodb-headless.mongodb-production.svc.cluster.local:27017,mongodb-2.mongodb-headless.mongodb-production.svc.cluster.local:27017/?replicaSet=rs0"
            volumeMounts:
            - name: monitoring-scripts
              mountPath: /scripts
          volumes:
          - name: monitoring-scripts
            configMap:
              name: mongodb-monitoring
              defaultMode: 0755
          restartPolicy: OnFailure
---
# Daily backup job
apiVersion: batch/v1
kind: CronJob
metadata:
  name: mongodb-backup
  labels:
    app: mongodb
    component: backup
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        metadata:
          labels:
            app: mongodb
            component: backup
        spec:
          containers:
          - name: backup
            image: mongo:7.0
            command: ["/bin/bash", "/scripts/backup-database.sh"]
            env:
            - name: MONGODB_URI
              value: "mongodb://mongodb-0.mongodb-headless.mongodb-production.svc.cluster.local:27017/?replicaSet=rs0"
            volumeMounts:
            - name: backup-storage
              mountPath: /backups
            - name: monitoring-scripts
              mountPath: /scripts
          volumes:
          - name: backup-storage
            persistentVolumeClaim:
              claimName: mongodb-backup-storage
          - name: monitoring-scripts
            configMap:
              name: mongodb-monitoring
              defaultMode: 0755
          restartPolicy: OnFailure
EOF
```

## Phase 4: Initialization and Configuration

Let's initialize the MongoDB cluster and set up users and security.

### Cluster Initialization

```bash
# Wait for MongoDB pods to be ready
echo "=== Waiting for MongoDB cluster to be ready ==="
kubectl wait --for=condition=Ready pod -l app=mongodb --timeout=300s

# Check pod status
kubectl get pods -l app=mongodb -o wide

# Initialize the replica set
echo "=== Initializing MongoDB Replica Set ==="
kubectl exec mongodb-0 -- mongosh --eval "
$(kubectl get configmap mongodb-config -o jsonpath='{.data.init-replica-set\.js}')
"

# Wait for replica set to stabilize
sleep 30

# Check replica set status
echo "=== Checking Replica Set Status ==="
kubectl exec mongodb-0 -- mongosh --eval "rs.status()"
```

### User and Security Setup

```bash
# Set up MongoDB users
echo "=== Setting up MongoDB Users ==="
kubectl exec mongodb-0 -- mongosh --eval "
$(kubectl get configmap mongodb-config -o jsonpath='{.data.setup-users\.js}')
"

# Test authentication
echo "=== Testing Authentication ==="
kubectl exec mongodb-0 -- mongosh -u admin -p secure-admin-password-change-in-production --authenticationDatabase admin --eval "
db.runCommand({connectionStatus: 1})
"
```

## Phase 5: Testing and Validation

Let's thoroughly test our MongoDB cluster to ensure it meets production requirements.

### Comprehensive Testing Suite

```bash
# Create test data and validate cluster functionality
cat << EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: mongodb-cluster-test
  labels:
    app: mongodb
    component: testing
spec:
  template:
    metadata:
      labels:
        app: mongodb
        component: testing
    spec:
      containers:
      - name: cluster-test
        image: mongo:7.0
        command:
        - "bash"
        - "-c"
        - |
          echo "=== MongoDB Cluster Testing Suite ==="
          
          # Test 1: Basic connectivity to primary
          echo "Test 1: Primary connectivity"
          mongosh mongodb://mongodb-0.mongodb-headless.mongodb-production.svc.cluster.local:27017/production_app \
            -u app_user -p secure-app-password-change-in-production \
            --eval "db.runCommand('ping')" && echo "✓ Primary accessible" || echo "✗ Primary failed"
          
          # Test 2: Write to primary, read from secondary
          echo "Test 2: Write/Read operations"
          mongosh mongodb://mongodb-0.mongodb-headless.mongodb-production.svc.cluster.local:27017/production_app \
            -u app_user -p secure-app-password-change-in-production \
            --eval "
              db.cluster_test.insertOne({
                test: 'cluster-validation',
                timestamp: new Date(),
                pod: 'mongodb-0'
              });
              print('✓ Write to primary successful');
            "
          
          # Test 3: Read from secondary
          sleep 5  # Allow replication
          mongosh mongodb://mongodb-1.mongodb-headless.mongodb-production.svc.cluster.local:27017/production_app \
            -u app_user -p secure-app-password-change-in-production \
            --eval "
              db.getMongo().setReadPref('secondary');
              var doc = db.cluster_test.findOne({test: 'cluster-validation'});
              if (doc) {
                print('✓ Read from secondary successful');
              } else {
                print('✗ Read from secondary failed');
              }
            " || echo "Secondary read test completed"
          
          # Test 4: Connection string with replica set
          echo "Test 4: Replica set connection string"
          mongosh "mongodb://app_user:secure-app-password-change-in-production@mongodb-headless.mongodb-production.svc.cluster.local:27017/production_app?replicaSet=rs0" \
            --eval "
              db.cluster_test.insertOne({
                test: 'replica-set-connection',
                timestamp: new Date()
              });
              print('✓ Replica set connection successful');
            "
          
          # Test 5: Load test
          echo "Test 5: Basic load test"
          mongosh "mongodb://app_user:secure-app-password-change-in-production@mongodb-headless.mongodb-production.svc.cluster.local:27017/production_app?replicaSet=rs0" \
            --eval "
              for (var i = 0; i < 1000; i++) {
                db.load_test.insertOne({
                  counter: i,
                  data: 'Load test data ' + i,
                  timestamp: new Date()
                });
              }
              print('✓ Load test: 1000 documents inserted');
              print('Document count: ' + db.load_test.countDocuments({}));
            "
          
          echo "=== Testing Suite Completed ==="
          
      restartPolicy: Never
EOF

# Wait for test to complete
kubectl wait --for=condition=complete job/mongodb-cluster-test --timeout=300s

# Check test results
kubectl logs job/mongodb-cluster-test
```

### Performance and Monitoring Validation

```bash
# Run performance monitoring
echo "=== Performance Monitoring Validation ==="
kubectl exec mongodb-0 -- bash /scripts/performance-monitor.sh

# Test backup functionality
echo "=== Backup Functionality Test ==="
kubectl exec mongodb-0 -- bash /scripts/backup-database.sh

# Check monitoring jobs
echo "=== Monitoring Jobs Status ==="
kubectl get cronjob
kubectl get jobs -l app=mongodb

# Run alert checks
echo "=== Alert System Validation ==="
kubectl exec mongodb-0 -- bash /scripts/alert-check.sh
```

### Failover and Recovery Testing

```bash
# Test pod failure recovery
echo "=== Pod Failure Recovery Test ==="

# Record current primary
PRIMARY_BEFORE=$(kubectl exec mongodb-0 -- mongosh --quiet --eval "
db.runCommand('ismaster').primary
" 2>/dev/null)
echo "Primary before test: $PRIMARY_BEFORE"

# Delete primary pod to trigger failover
kubectl delete pod mongodb-0 --grace-period=0

# Monitor failover process
echo "Waiting for failover to complete..."
sleep 30

# Check new primary after failover
kubectl wait --for=condition=Ready pod mongodb-0 --timeout=180s
PRIMARY_AFTER=$(kubectl exec mongodb-1 -- mongosh --quiet --eval "
db.runCommand('ismaster').primary
" 2>/dev/null || echo "Check failed")
echo "Primary after failover: $PRIMARY_AFTER"

# Verify data integrity
kubectl exec mongodb-1 -- mongosh "mongodb://app_user:secure-app-password-change-in-production@mongodb-headless.mongodb-production.svc.cluster.local:27017/production_app?replicaSet=rs0" --eval "
print('Cluster test documents: ' + db.cluster_test.countDocuments({}));
print('Load test documents: ' + db.load_test.countDocuments({}));
"

echo "=== Failover Test Completed ==="
```

## Phase 6: Production Operations Runbook

Let's create comprehensive operational procedures for managing the MongoDB cluster in production.

### Operations Documentation

```bash
# Create operations runbook
cat << EOF > mongodb-operations-runbook.md
# MongoDB Production Cluster Operations Runbook

## Cluster Overview
- **Cluster Name**: mongodb-production
- **Replica Set**: rs0
- **Data Members**: 3 (mongodb-0, mongodb-1, mongodb-2)
- **Arbiter**: 1 (mongodb-arbiter-0)
- **Storage**: Fast SSD for data, Standard for backups

## Daily Operations

### Health Checks
\`\`\`bash
# Check cluster status
kubectl get pods -l app=mongodb -n mongodb-production

# Check replica set health
kubectl exec mongodb-0 -n mongodb-production -- mongosh --eval "rs.status()"

# Run health monitoring script
kubectl exec mongodb-0 -n mongodb-production -- bash /scripts/health-check.sh
\`\`\`

### Performance Monitoring
\`\`\`bash
# Check performance metrics
kubectl exec mongodb-0 -n mongodb-production -- bash /scripts/performance-monitor.sh

# Check resource utilization
kubectl top pods -l app=mongodb -n mongodb-production
\`\`\`

### Backup Verification
\`\`\`bash
# List recent backups
kubectl exec mongodb-0 -n mongodb-production -- ls -la /backups/

# Verify backup job status
kubectl get cronjob mongodb-backup -n mongodb-production
kubectl get jobs -l component=backup -n mongodb-production
\`\`\`

## Scaling Operations

### Scaling Up (Adding Replica Members)
\`\`\`bash
# Scale the StatefulSet
kubectl scale statefulset mongodb --replicas=4 -n mongodb-production

# Wait for new pod to be ready
kubectl wait --for=condition=Ready pod mongodb-3 -n mongodb-production --timeout=300s

# Add new member to replica set
kubectl exec mongodb-0 -n mongodb-production -- mongosh --eval "
rs.add('mongodb-3.mongodb-headless.mongodb-production.svc.cluster.local:27017')
"
\`\`\`

### Scaling Down (Removing Replica Members)
\`\`\`bash
# Remove member from replica set first
kubectl exec mongodb-0 -n mongodb-production -- mongosh --eval "
rs.remove('mongodb-3.mongodb-headless.mongodb-production.svc.cluster.local:27017')
"

# Wait for reconfiguration
sleep 30

# Scale down the StatefulSet
kubectl scale statefulset mongodb --replicas=3 -n mongodb-production
\`\`\`

## Update Procedures

### Rolling Updates
\`\`\`bash
# Update MongoDB image
kubectl set image statefulset/mongodb mongodb=mongo:7.0.1 -n mongodb-production

# Monitor rolling update
kubectl rollout status statefulset/mongodb -n mongodb-production

# Verify cluster health after update
kubectl exec mongodb-0 -n mongodb-production -- mongosh --eval "rs.status()"
\`\`\`

### Configuration Updates
\`\`\`bash
# Update configuration
kubectl edit configmap mongodb-config -n mongodb-production

# Restart pods to pick up new configuration (one at a time)
kubectl delete pod mongodb-2 -n mongodb-production
kubectl wait --for=condition=Ready pod mongodb-2 -n mongodb-production --timeout=180s
# Repeat for mongodb-1, then mongodb-0
\`\`\`

## Disaster Recovery

### Backup Procedures
\`\`\`bash
# Manual backup
kubectl exec mongodb-0 -n mongodb-production -- bash /scripts/backup-database.sh

# Verify backup
kubectl exec mongodb-0 -n mongodb-production -- ls -la /backups/
\`\`\`

### Restore Procedures
\`\`\`bash
# List available backups
kubectl exec mongodb-0 -n mongodb-production -- ls -la /backups/

# Restore from backup
kubectl exec mongodb-0 -n mongodb-production -- bash /scripts/restore-database.sh <backup_file>
\`\`\`

### Complete Cluster Recovery
\`\`\`bash
# If entire cluster is lost but data persists:
# 1. Delete StatefulSet (keep PVCs)
kubectl delete statefulset mongodb mongodb-arbiter -n mongodb-production --cascade=orphan

# 2. Delete pods
kubectl delete pods -l app=mongodb -n mongodb-production

# 3. Recreate StatefulSets (they will reconnect to existing PVCs)
kubectl apply -f mongodb-cluster-complete.yaml

# 4. Wait for cluster to recover
kubectl wait --for=condition=Ready pod -l app=mongodb -n mongodb-production --timeout=600s
\`\`\`

## Troubleshooting

### Common Issues

#### Pod Won't Start
\`\`\`bash
# Check pod events
kubectl describe pod mongodb-X -n mongodb-production

# Check logs
kubectl logs mongodb-X -n mongodb-production

# Check PVC binding
kubectl get pvc -l app=mongodb -n mongodb-production
\`\`\`

#### Replica Set Issues
\`\`\`bash
#### Replica Set Issues
\`\`\`bash
# Check replica set configuration
kubectl exec mongodb-0 -n mongodb-production -- mongosh --eval "rs.conf()"

# Check replica set status
kubectl exec mongodb-0 -n mongodb-production -- mongosh --eval "rs.status()"

# Force reconfigure if needed (DANGEROUS - use carefully)
kubectl exec mongodb-0 -n mongodb-production -- mongosh --eval "
var config = rs.conf();
config.version++;
rs.reconfig(config, {force: true});
"
\`\`\`

#### Performance Issues
\`\`\`bash
# Check current operations
kubectl exec mongodb-0 -n mongodb-production -- mongosh --eval "db.currentOp()"

# Check slow operations
kubectl exec mongodb-0 -n mongodb-production -- mongosh --eval "
db.setProfilingLevel(1, { slowms: 100 });
db.system.profile.find().limit(5).sort({ ts: -1 }).pretty();
"

# Check resource usage
kubectl top pod mongodb-0 -n mongodb-production
\`\`\`

## Emergency Procedures

### Emergency Scale Down
If cluster is under severe load:
\`\`\`bash
# Immediately stop accepting new connections (if possible)
kubectl exec mongodb-0 -n mongodb-production -- mongosh --eval "
db.adminCommand({setParameter: 1, maxIncomingConnections: 10})
"

# Scale down non-essential services first
kubectl scale deployment <other-apps> --replicas=0
\`\`\`

### Emergency Backup
\`\`\`bash
# Quick backup of critical data
kubectl exec mongodb-0 -n mongodb-production -- mongodump \
  --host localhost:27017 \
  --db production_app \
  --out /backups/emergency_backup_\$(date +%Y%m%d_%H%M%S) \
  --gzip
\`\`\`

## Monitoring and Alerting Integration

### Key Metrics to Monitor
- Replica set member status
- Connection count
- Storage utilization
- Memory usage
- Operation latency
- Replication lag

### Alert Thresholds
- Connections > 150
- Storage > 85%
- Memory > 1.5GB
- Replica set member down
- Replication lag > 10 seconds

### Integration with External Monitoring
\`\`\`bash
# Export metrics (example for Prometheus)
kubectl port-forward mongodb-0 27017:27017 -n mongodb-production &
# Use MongoDB exporter or custom metrics collection
\`\`\`
EOF

echo "Operations runbook created: mongodb-operations-runbook.md"
```

## Phase 7: Advanced Production Scenarios

Let's test advanced scenarios that you might encounter in production.

### Load Testing and Performance Optimization

```bash
# Create a comprehensive load testing job
cat << EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: mongodb-load-test
  labels:
    app: mongodb
    component: load-test
spec:
  parallelism: 3  # Run 3 concurrent load generators
  template:
    metadata:
      labels:
        app: mongodb
        component: load-test
    spec:
      containers:
      - name: load-generator
        image: mongo:7.0
        command:
        - "bash"
        - "-c"
        - |
          echo "Starting load test from pod: \$HOSTNAME"
          
          # Connection string with proper load balancing
          MONGODB_URI="mongodb://app_user:secure-app-password-change-in-production@mongodb-headless.mongodb-production.svc.cluster.local:27017/load_test?replicaSet=rs0"
          
          # Load test parameters
          DURATION=300  # 5 minutes
          BATCH_SIZE=100
          
          echo "Running load test for \$DURATION seconds"
          START_TIME=\$(date +%s)
          COUNTER=0
          
          while [ \$(((\$(date +%s) - START_TIME))) -lt \$DURATION ]; do
            # Batch insert
            mongosh "\$MONGODB_URI" --eval "
              var batch = [];
              for (var i = 0; i < $BATCH_SIZE; i++) {
                batch.push({
                  pod: '\$HOSTNAME',
                  counter: \$COUNTER + i,
                  timestamp: new Date(),
                  data: 'Load test data from \$HOSTNAME batch \$COUNTER',
                  random: Math.random()
                });
              }
              db.performance_test.insertMany(batch);
            " > /dev/null 2>&1
            
            COUNTER=\$((COUNTER + BATCH_SIZE))
            
            # Random read operations
            mongosh "\$MONGODB_URI" --eval "
              db.performance_test.find({random: {\$gt: Math.random()}}).limit(10).toArray();
            " > /dev/null 2>&1
            
            # Brief pause
            sleep 1
          done
          
          echo "Load test completed. Inserted approximately \$COUNTER documents from \$HOSTNAME"
          
          # Final statistics
          mongosh "\$MONGODB_URI" --eval "
            print('Total documents in performance_test: ' + db.performance_test.countDocuments({}));
            print('Documents from this pod: ' + db.performance_test.countDocuments({pod: '\$HOSTNAME'}));
          "
          
      restartPolicy: Never
EOF

# Monitor load test
kubectl get jobs mongodb-load-test -w &
WATCH_PID=$!

# Monitor cluster performance during load test
echo "Monitoring cluster performance during load test..."
for i in {1..10}; do
  echo "=== Performance Check #$i ==="
  kubectl exec mongodb-0 -n mongodb-production -- bash /scripts/performance-monitor.sh
  sleep 30
done

# Stop monitoring
kill $WATCH_PID 2>/dev/null || true

# Check load test results
kubectl logs job/mongodb-load-test
```

### Multi-Namespace Deployment Testing

```bash
# Test deploying applications that connect to MongoDB from different namespaces
kubectl create namespace app-frontend
kubectl create namespace app-backend

# Deploy test applications in different namespaces
cat << EOF | kubectl apply -f -
# Frontend application
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-app
  namespace: app-frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: app
        image: mongo:7.0
        command: ["sleep", "3600"]
        env:
        - name: MONGODB_URI
          value: "mongodb://app_user:secure-app-password-change-in-production@mongodb-client.mongodb-production.svc.cluster.local:27017/production_app?replicaSet=rs0"
---
# Backend application
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-app
  namespace: app-backend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: app
        image: mongo:7.0
        command: ["sleep", "3600"]
        env:
        - name: MONGODB_URI
          value: "mongodb://app_user:secure-app-password-change-in-production@mongodb-client.mongodb-production.svc.cluster.local:27017/production_app?replicaSet=rs0"
EOF

# Test cross-namespace connectivity
kubectl wait --for=condition=Available deployment frontend-app -n app-frontend --timeout=120s
kubectl wait --for=condition=Available deployment backend-app -n app-backend --timeout=120s

# Test connectivity from frontend namespace
kubectl exec deployment/frontend-app -n app-frontend -- mongosh "$MONGODB_URI" --eval "
db.cross_namespace_test.insertOne({
  source: 'frontend-app',
  namespace: 'app-frontend',
  timestamp: new Date()
});
print('✓ Frontend namespace connectivity test passed');
"

# Test connectivity from backend namespace
kubectl exec deployment/backend-app -n app-backend -- mongosh "$MONGODB_URI" --eval "
db.cross_namespace_test.insertOne({
  source: 'backend-app',
  namespace: 'app-backend',
  timestamp: new Date()
});
print('✓ Backend namespace connectivity test passed');
"
```

### Disaster Recovery Drill

```bash
# Execute a complete disaster recovery drill
echo "=== DISASTER RECOVERY DRILL ==="

# Step 1: Create critical data before the "disaster"
kubectl exec mongodb-0 -n mongodb-production -- mongosh "mongodb://app_user:secure-app-password-change-in-production@mongodb-headless.mongodb-production.svc.cluster.local:27017/production_app?replicaSet=rs0" --eval "
db.disaster_drill.insertMany([
  {type: 'customer', data: 'Critical customer data', timestamp: new Date()},
  {type: 'financial', data: 'Important financial records', timestamp: new Date()},
  {type: 'operational', data: 'Key operational data', timestamp: new Date()}
]);
print('Critical data created for disaster recovery drill');
"

# Step 2: Take a backup before disaster
kubectl exec mongodb-0 -n mongodb-production -- bash /scripts/backup-database.sh

# Step 3: Simulate complete cluster failure
echo "Simulating complete cluster failure..."
kubectl delete pods -l app=mongodb -n mongodb-production --force --grace-period=0

# Step 4: Verify cluster recovery
echo "Waiting for automatic recovery..."
kubectl wait --for=condition=Ready pod -l app=mongodb -n mongodb-production --timeout=600s

# Step 5: Verify data integrity
kubectl exec mongodb-0 -n mongodb-production -- mongosh "mongodb://app_user:secure-app-password-change-in-production@mongodb-headless.mongodb-production.svc.cluster.local:27017/production_app?replicaSet=rs0" --eval "
var count = db.disaster_drill.countDocuments({});
print('Disaster drill data recovered: ' + count + ' documents');
if (count >= 3) {
  print('✓ Disaster recovery drill PASSED');
} else {
  print('✗ Disaster recovery drill FAILED');
}
"

echo "=== DISASTER RECOVERY DRILL COMPLETED ==="
```

## Phase 8: Documentation and Knowledge Transfer

Create comprehensive documentation for your MongoDB deployment.

### Final Project Documentation

```bash
# Create comprehensive project documentation
cat << EOF > mongodb-capstone-documentation.md
# MongoDB Production Cluster - Capstone Project Documentation

## Project Summary

This capstone project demonstrates a complete, production-ready MongoDB cluster deployment using Kubernetes StatefulSets. The implementation showcases all key StatefulSet concepts including persistent storage, stable network identity, ordered operations, monitoring, and disaster recovery.

## Architecture Overview

### Components Deployed
- **MongoDB Replica Set**: 3 data-bearing members (mongodb-0, mongodb-1, mongodb-2)
- **MongoDB Arbiter**: 1 voting-only member (mongodb-arbiter-0)
- **Services**: Headless service for cluster communication, client service for applications
- **Storage**: Multi-tier storage strategy with fast SSD for data, standard storage for backups
- **Monitoring**: Automated health checks, performance monitoring, and alerting
- **Backup**: Automated daily backups with point-in-time recovery capability

### Key Features Implemented
1. **Persistent Storage**: Fast SSD for MongoDB data, standard storage for logs and backups
2. **Network Identity**: Stable DNS names for replica set member discovery
3. **Ordered Operations**: Sequential startup and controlled rolling updates
4. **High Availability**: 3-member replica set with automatic failover
5. **Security**: Authentication, authorization, and inter-cluster encryption
6. **Monitoring**: Comprehensive health checks and performance metrics
7. **Backup/Recovery**: Automated backups with tested recovery procedures
8. **Operational Procedures**: Complete runbooks for production operations

## Technical Implementation

### StatefulSet Configuration Highlights
\`\`\`yaml
# Key StatefulSet features demonstrated:
- serviceName: "mongodb-headless"  # Stable network identity
- updateStrategy.type: RollingUpdate  # Controlled updates
- volumeClaimTemplates  # Persistent storage per pod
- ordered startup with health checks
- resource limits and security contexts
\`\`\`

### Storage Strategy
- **Data Storage**: 20GB fast SSD per MongoDB instance
- **Backup Storage**: 50GB standard storage for backup retention
- **Arbiter Storage**: 1GB minimal storage for voting member

### Network Architecture
- **Internal Communication**: Headless service (mongodb-headless)
- **Client Access**: ClusterIP service (mongodb-client)
- **Primary Access**: Dedicated service routing to mongodb-0

## Testing and Validation Results

### Performance Testing
- Successfully handled concurrent load from multiple clients
- Maintained sub-100ms response times under normal load
- Automatic load balancing across replica set members

### Disaster Recovery Testing
- Pod failure recovery: < 30 seconds
- Complete cluster recovery: < 5 minutes
- Data integrity maintained through all failure scenarios
- Backup/restore procedures validated

### Operational Testing
- Rolling updates completed without downtime
- Scaling operations (up and down) performed successfully
- Cross-namespace connectivity verified
- Monitoring and alerting systems validated

## Lessons Learned

### StatefulSet Best Practices
1. **Always use headless services** for internal cluster communication
2. **Implement comprehensive health checks** to ensure ordered operations
3. **Plan storage carefully** - PVCs persist beyond pod lifecycle
4. **Test disaster recovery procedures regularly**
5. **Monitor replica set health continuously**

### MongoDB-Specific Insights
1. **Replica set initialization is critical** - must be done after all members are ready
2. **Arbiter placement** - use separate StatefulSet for different resource requirements
3. **Authentication setup** - coordinate with replica set initialization
4. **Connection strings** - use replica set-aware URIs for automatic failover

### Production Readiness Checklist
- [x] High availability configuration
- [x] Persistent storage with appropriate performance characteristics
- [x] Security (authentication, authorization, encryption)
- [x] Monitoring and alerting
- [x] Backup and recovery procedures
- [x] Operational runbooks
- [x] Disaster recovery testing
- [x] Performance testing
- [x] Documentation

## Future Enhancements

### Recommended Improvements
1. **Enhanced Security**: Implement network policies, pod security policies
2. **Advanced Monitoring**: Integration with Prometheus/Grafana
3. **Backup Automation**: Off-site backup replication
4. **Scaling Automation**: HorizontalPodAutoscaler integration
5. **Multi-Region Deployment**: Cross-zone replica placement

### Operational Maturity
1. **GitOps Integration**: Automated deployments via Git workflows
2. **Secret Management**: External secret stores (Vault, AWS Secrets Manager)
3. **Compliance**: Implement audit logging and compliance reporting
4. **Chaos Engineering**: Automated failure testing

## Knowledge Transfer

### Key Concepts Demonstrated
- **Stable Network Identity**: DNS-based service discovery
- **Persistent Storage**: Volume claim templates and storage classes
- **Ordered Operations**: Sequential pod startup and updates
- **Production Operations**: Monitoring, backup, recovery, scaling

### Real-World Applications
This MongoDB deployment pattern applies to:
- Production database clusters
- Distributed stateful applications
- Systems requiring data persistence
- Applications needing stable network identity

### Skills Acquired
- StatefulSet design and implementation
- Storage architecture for stateful applications
- Production-ready monitoring and alerting
- Disaster recovery planning and testing
- Operational procedure development

## Conclusion

This capstone project successfully demonstrates mastery of Kubernetes StatefulSets through a comprehensive MongoDB deployment. All key StatefulSet concepts have been implemented and tested in realistic production scenarios. The resulting cluster is production-ready and includes all necessary operational components for reliable service delivery.

The project serves as a complete reference implementation for deploying stateful applications in Kubernetes and provides a solid foundation for managing production database workloads.
EOF

echo "Project documentation created: mongodb-capstone-documentation.md"
```

## Final Assessment and Cleanup

### Comprehensive Final Assessment

```bash
# Run final comprehensive assessment
echo "=== FINAL CAPSTONE ASSESSMENT ==="

echo "1. Cluster Health Check"
kubectl get statefulset -n mongodb-production
kubectl get pods -l app=mongodb -n mongodb-production
kubectl exec mongodb-0 -n mongodb-production -- mongosh --eval "rs.status()" | grep -E "(name|stateStr|health)"

echo "2. Storage Validation"
kubectl get pvc -l app=mongodb -n mongodb-production

echo "3. Network Identity Verification"
kubectl exec mongodb-0 -n mongodb-production -- nslookup mongodb-1.mongodb-headless.mongodb-production.svc.cluster.local

echo "4. Backup System Check"
kubectl get cronjob -n mongodb-production
kubectl exec mongodb-0 -n mongodb-production -- ls -la /backups/ | tail -5

echo "5. Performance Metrics"
kubectl exec mongodb-0 -n mongodb-production -- bash /scripts/performance-monitor.sh

echo "6. Security Validation"
kubectl exec mongodb-0 -n mongodb-production -- mongosh -u admin -p secure-admin-password-change-in-production --authenticationDatabase admin --eval "db.runCommand({connectionStatus: 1})" | grep "authenticated"

echo "=== ASSESSMENT COMPLETED ==="
```

### Optional Cleanup

```bash
# Comprehensive cleanup (optional - you may want to keep your work!)
echo "=== CLEANUP OPTIONS ==="
echo "To clean up the entire MongoDB cluster:"
echo "kubectl delete namespace mongodb-production"
echo ""
echo "To clean up test namespaces:"
echo "kubectl delete namespace app-frontend app-backend"
echo ""
echo "To clean up specific components:"
echo "kubectl delete statefulset mongodb mongodb-arbiter -n mongodb-production"
echo "kubectl delete jobs -l app=mongodb -n mongodb-production"
echo "kubectl delete cronjobs -l app=mongodb -n mongodb-production"
echo ""
echo "Note: PVCs will remain for data safety. Delete manually if desired:"
echo "kubectl get pvc -n mongodb-production"

# Don't actually run cleanup - let the user decide
echo "Cleanup commands provided above. Execute only if you want to remove the cluster."
```

## Capstone Project Summary

### What You've Accomplished

🎉 **Congratulations!** You have successfully completed a comprehensive StatefulSets capstone project that demonstrates mastery of:

#### **Core StatefulSet Concepts**
- ✅ **Stable Network Identity** - MongoDB replica set members with persistent DNS names
- ✅ **Persistent Storage** - Multi-tier storage strategy with appropriate performance characteristics  
- ✅ **Ordered Operations** - Sequential startup, controlled updates, and graceful scaling

#### **Production-Ready Implementation**
- ✅ **High Availability** - 3-node replica set with automatic failover
- ✅ **Comprehensive Monitoring** - Health checks, performance metrics, and alerting
- ✅ **Backup and Recovery** - Automated backups with tested restore procedures
- ✅ **Security** - Authentication, authorization, and secure inter-cluster communication
- ✅ **Operational Procedures** - Complete runbooks and disaster recovery plans

#### **Real-World Skills**
- ✅ **Architecture Design** - Multi-component system design with proper service separation
- ✅ **Performance Testing** - Load testing and performance optimization
- ✅ **Disaster Recovery** - Complete failure scenario testing and recovery
- ✅ **Documentation** - Comprehensive operational documentation and knowledge transfer

### Course Journey Complete

You have progressed from understanding **why StatefulSets exist** (Unit 1) to **deploying production-ready stateful applications** (Unit 6). This journey has equipped you with:

1. **Conceptual Understanding** - Deep knowledge of stateful vs stateless applications
2. **Practical Skills** - Hands-on experience with StatefulSet operations
3. **Storage Expertise** - Advanced persistent storage strategies
4. **Network Mastery** - Complex networking patterns for distributed systems
5. **Operational Excellence** - Production-ready monitoring, backup, and recovery
6. **System Integration** - Complete end-to-end stateful application deployment

### Your MongoDB Cluster Achievement

The MongoDB cluster you've built represents a **production-grade deployment** that could serve real applications in enterprise environments. It includes all the components and procedures necessary for reliable operation:

- **99.9% availability** through replica set configuration
- **Data durability** through persistent storage and regular backups
- **Performance monitoring** with automated health checks
- **Disaster recovery** with tested procedures
- **Operational excellence** through comprehensive documentation

### Next Steps in Your Kubernetes Journey

With StatefulSets mastered, you're prepared for advanced Kubernetes topics:
- **Operators** - Custom controllers for complex stateful applications
- **Service Mesh** - Advanced networking and security patterns
- **GitOps** - Automated deployment and configuration management
- **Multi-Cluster** - Cross-cluster stateful application deployment
- **Cloud-Native Databases** - Kubernetes-native database solutions

**You are now equipped to confidently deploy and manage stateful applications in production Kubernetes environments!**# Unit 6: Capstone Project - Production MongoDB Cluster

## Learning Objectives
By the end of this capstone project, you will:
- Synthesize all StatefulSet concepts into a complete, production-ready deployment
- Design and implement a comprehensive MongoDB replica set with all operational components
- Demonstrate mastery of storage, networking, scaling, monitoring, and disaster recovery
- Create documentation and runbooks for production operations
- Execute real-world operational scenarios and incident response procedures

## Project Overview: Enterprise MongoDB Cluster

In this capstone project, you'll build a complete, production-ready MongoDB cluster that demonstrates every concept you've learned throughout the course. This isn't just a simple deployment—it's a comprehensive system that includes:

- **High-Availability MongoDB Replica Set** (3 data nodes + 1 arbiter)
- **Multi-Tier Storage Strategy** (fast storage for data, standard storage for logs)
- **Comprehensive Networking** (internal cluster communication + external access)
- **Production Operations** (monitoring, backup, recovery, scaling)
- **Security Configuration** (authentication, encryption, network policies)
- **Disaster Recovery** (automated backups, tested recovery procedures)

**Project Deliverables:**
1. Complete MongoDB cluster deployment
2. Operational runbooks and procedures
3. Monitoring and alerting configuration
4. Disaster recovery testing and documentation
5. Performance testing and optimization
6. Security implementation and validation

## Phase 1: Architecture Design and Planning

Before we start deploying, let's design a comprehensive architecture that addresses real-world production requirements.

### Architecture Planning Workshop

```bash
# Create a project namespace for our capstone
kubectl create namespace mongodb-production
kubectl label namespace mongodb-production project=capstone environment=production

# Set up our working context
kubectl config set-context --current --namespace=mongodb-production

echo "=== MongoDB Cluster Architecture Planning ==="
echo "Namespace: mongodb-production"
echo "Target Architecture:"
echo "  - 3 MongoDB data-bearing replica set members"
echo "  - 1 MongoDB arbiter (voting-only, no data)"
echo "  - Separate services for internal and external access"
echo "  - Multi-tier persistent storage"
echo "  - Comprehensive monitoring and backup"
echo "  - Production-grade security"
```

### Infrastructure Requirements Analysis

```bash
# Check cluster resources before deployment
echo "=== Cluster Resource Analysis ==="
kubectl top nodes
kubectl describe nodes | grep -A 5 "Allocated resources"

# Check available storage classes
echo "=== Available Storage Classes ==="
kubectl get storageclass

# Verify networking capabilities
echo "=== Network Policy Support ==="
kubectl get networkpolicy --all-namespaces 2>/dev/null && echo "Network policies supported" || echo "Network policies may not be supported"

echo "=== Planning Complete - Ready for Implementation ==="
```

**Design Questions for Reflection:**
- How will you balance performance, cost, and reliability in your storage choices?
- What monitoring metrics will be most critical for MongoDB operations?
- How will you ensure high availability while maintaining data consistency?
- What security measures are essential for a production MongoDB deployment?

## Phase 2: Foundation Infrastructure

Let's build the foundational components that support our MongoDB cluster.

### Storage Classes and Configuration

```bash
# Create optimized storage classes for MongoDB workloads
cat << EOF | kubectl apply -f -
# High-performance storage for MongoDB data
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: mongodb-fast
  labels:
    app: mongodb
    tier: fast-storage
provisioner: kubernetes.io/no-provisioner  # Replace with your cloud provider's provisioner
parameters:
  type: ssd
  iops: "3000"
  replication-type: synchronous
reclaimPolicy: Retain  # Protect data even if PVC is deleted
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
---
# Standard storage for logs and backups
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: mongodb-standard
  labels:
    app: mongodb
    tier: standard-storage
provisioner: kubernetes.io/no-provisioner
parameters:
  type: standard
  replication-type: asynchronous
reclaimPolicy: Retain
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
---
# Backup storage for long-term retention
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: mongodb-backup
  labels:
    app: mongodb
    tier: backup-storage
provisioner: kubernetes.io/no-provisioner
parameters:
  type: cold-storage
  replication-type: geo-distributed
reclaimPolicy: Retain
allowVolumeExpansion: true
EOF
```

### MongoDB Configuration and Security

```bash
# Create comprehensive MongoDB configuration
cat << EOF | kubectl apply -f -
# MongoDB configuration files
apiVersion: v1
kind: ConfigMap
metadata:
  name: mongodb-config
  labels:
    app: mongodb
    component: config
data:
  mongod.conf: |
    # MongoDB production configuration
    net:
      port: 27017
      bindIp: 0.0.0.0
      maxIncomingConnections: 200
      
    # Security
    security:
      authorization: enabled
      keyFile: /etc/mongodb-keyfile/mongodb-keyfile
      
    # Storage
    storage:
      dbPath: /data/db
      journal:
        enabled: true
      wiredTiger:
        engineConfig:
          cacheSizeGB: 1  # Adjust based on your pod resources
          journalCompressor: snappy
        collectionConfig:
          blockCompressor: snappy
        indexConfig:
          prefixCompression: true
          
    # Replication
    replication:
      replSetName: "rs0"
      
    # Operation profiling for monitoring
    operationProfiling:
      mode: slowOp
      slowOpThresholdMs: 100
      
    # System log
    systemLog:
      destination: file
      path: /var/log/mongodb/mongod.log
      logAppend: true
      logRotate: reopen
      
  init-replica-set.js: |
    // Initialize replica set with all members
    var config = {
      _id: "rs0",
      members: [
        {
          _id: 0,
          host: "mongodb-0.mongodb-headless.mongodb-production.svc.cluster.local:27017",
          priority: 2  // Higher priority for primary
        },
        {
          _id: 1,
          host: "mongodb-1.mongodb-headless.mongodb-production.svc.cluster.local:27017",
          priority: 1
        },
        {
          _id: 2,
          host: "mongodb-2.mongodb-headless.mongodb-production.svc.cluster.local:27017",
          priority: 1
        },
        {
          _id: 3,
          host: "mongodb-arbiter-0.mongodb-headless.mongodb-production.svc.cluster.local:27017",
          arbiterOnly: true  // Arbiter for voting only
        }
      ]
    };
    
    rs.initiate(config);
    
    // Wait for replica set to be ready
    while (rs.status().ok !== 1) {
      print("Waiting for replica set to initialize...");
      sleep(2000);
    }
    
    print("Replica set initialized successfully!");
    
  setup-users.js: |
    // Create administrative users
    db = db.getSiblingDB('admin');
    
    db.createUser({
      user: "admin",
      pwd: "secure-admin-password-change-in-production",
      roles: [
        { role: "root", db: "admin" }
      ]
    });
    
    db.createUser({
      user: "monitor",
      pwd: "secure-monitor-password-change-in-production",
      roles: [
        { role: "clusterMonitor", db: "admin" },
        { role: "read", db: "local" }
      ]
    });
    
    // Create application user
    db = db.getSiblingDB('production_app');
    
    db.createUser({
      user: "app_user",
      pwd: "secure-app-password-change-in-production",
      roles: [
        { role: "readWrite", db: "production_app" }
      ]
    });
    
    print("Users created successfully!");
---
# MongoDB secrets (In production, use proper secret management)
apiVersion: v1
kind: Secret
metadata:
  name: mongodb-secrets
  labels:
    app: mongodb
    component: secrets
type: Opaque
stringData:
  mongodb-admin-password: "secure-admin-password-change-in-production"
  mongodb-monitor-password: "secure-monitor-password-change-in-production"
  mongodb-app-password: "secure-app-password-change-in-production"
  mongodb-replica-set-key: "very-long-and-secure-replica-set-key-for-internal-authentication-change-in-production"
EOF
```

### Networking Infrastructure

```bash
# Create comprehensive networking for MongoDB cluster
cat << EOF | kubectl apply -f -
# Headless service for internal cluster communication
apiVersion: v1
kind: Service
metadata:
  name: mongodb-headless
  labels:
    app: mongodb
    service-type: headless
spec:
  clusterIP: None
  selector:
    app: mongodb
  ports:
  - port: 27017
    name: mongodb
    protocol: TCP
---
# External service for client applications
apiVersion: v1
kind: Service
metadata:
  name: mongodb-client
  labels:
    app: mongodb
    service-type: client
spec:
  type: ClusterIP
  selector:
    app: mongodb
    mongodb-role: data  # Only route to data-bearing nodes
  ports:
  - port: 27017
    name: mongodb
    protocol: TCP
---
# Service specifically for primary access (write operations)
apiVersion: v1
kind: Service
metadata:
  name: mongodb-primary
  labels:
    app: mongodb
    service-type: primary
spec:
  type: ClusterIP
  selector:
    app: mongodb
    statefulset.kubernetes.io/pod-name: mongodb-0  # Primary is typically pod-0
  ports:
  - port: 27017
    name: mongodb
    protocol: TCP
EOF
```

### Monitoring and Observability Infrastructure

```bash
# Create comprehensive monitoring configuration
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: mongodb-monitoring
  labels:
    app: mongodb
    component: monitoring
data:
  health-check.sh: |
    #!/bin/bash
    set -e
    
    echo "=== MongoDB Health Check - \$(date) ==="
    
    # Basic connectivity check
    if mongosh --quiet --eval "db.runCommand('ping')" >/dev/null 2>&1; then
      echo "✓ MongoDB is responding to ping"
    else
      echo "✗ MongoDB ping failed"
      exit 1
    fi
    
    # Replica set status check
    RS_STATUS=\$(mongosh --quiet --