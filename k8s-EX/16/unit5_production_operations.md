# Unit 5: Production Operations - Advanced StatefulSet Management

## Learning Objectives
By the end of this unit, you will:
- Master advanced scaling strategies for stateful applications
- Implement safe rolling update procedures for mission-critical workloads
- Design comprehensive backup and recovery strategies
- Configure effective monitoring and alerting for stateful applications
- Troubleshoot complex operational scenarios and outages
- Plan and execute disaster recovery procedures

## Pre-Unit Operations Assessment

Let's establish your current operational experience and identify areas for growth:

**Operational Readiness Check:**
1. **Previous Experience**: Have you managed any production databases or stateful services? What operational challenges did you encounter?

2. **Risk Assessment**: What concerns would you have about updating a live database cluster serving production traffic?

3. **Monitoring Mindset**: If a StatefulSet pod keeps crashing, what information would you need to diagnose the problem?

4. **Recovery Planning**: How would you recover if you accidentally deleted a StatefulSet and lost some data?

Think through these scenarios—they represent real operational challenges you'll learn to handle.

## Advanced Scaling Strategies

Unlike stateless applications, scaling stateful applications requires careful planning and coordination. Let's explore production-ready scaling approaches.

### Lab: Safe Scaling Procedures

First, let's set up a realistic stateful application to practice scaling operations:

```bash
# Create a PostgreSQL cluster for scaling experiments
cat << EOF | kubectl apply -f -
# PostgreSQL configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-config
data:
  postgresql.conf: |
    listen_addresses = '*'
    max_connections = 100
    shared_buffers = 128MB
    effective_cache_size = 256MB
    maintenance_work_mem = 64MB
    checkpoint_completion_target = 0.9
    wal_buffers = 16MB
    default_statistics_target = 100
    random_page_cost = 4
    effective_io_concurrency = 2
    
  setup-replica.sql: |
    -- Script to configure replication (simplified for demo)
    SELECT pg_create_physical_replication_slot('replica_1_slot');
    SELECT pg_create_physical_replication_slot('replica_2_slot');
---
# Headless service for cluster communication
apiVersion: v1
kind: Service
metadata:
  name: postgres-cluster
  labels:
    app: postgres-cluster
spec:
  clusterIP: None
  selector:
    app: postgres-cluster
  ports:
  - port: 5432
    name: postgres
---
# Primary service for write operations
apiVersion: v1
kind: Service
metadata:
  name: postgres-primary
  labels:
    app: postgres-cluster
    role: primary
spec:
  selector:
    app: postgres-cluster
    statefulset.kubernetes.io/pod-name: postgres-cluster-0
  ports:
  - port: 5432
    name: postgres
---
# PostgreSQL StatefulSet
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres-cluster
  labels:
    app: postgres-cluster
spec:
  serviceName: postgres-cluster
  replicas: 1  # Start with single instance
  selector:
    matchLabels:
      app: postgres-cluster
  template:
    metadata:
      labels:
        app: postgres-cluster
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        ports:
        - containerPort: 5432
          name: postgres
        env:
        - name: POSTGRES_DB
          value: "production_db"
        - name: POSTGRES_USER
          value: "admin"
        - name: POSTGRES_PASSWORD
          value: "secure-password"
        - name: PGDATA
          value: "/var/lib/postgresql/data/pgdata"
        volumeMounts:
        - name: postgres-data
          mountPath: /var/lib/postgresql/data
        - name: postgres-config
          mountPath: /etc/postgresql
        # Health checks for safe scaling
        livenessProbe:
          exec:
            command:
            - pg_isready
            - -h
            - localhost
            - -U
            - admin
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          exec:
            command:
            - pg_isready
            - -h
            - localhost
            - -U
            - admin
          initialDelaySeconds: 5
          periodSeconds: 2
          timeoutSeconds: 1
          failureThreshold: 3
        resources:
          limits:
            memory: "512Mi"
            cpu: "500m"
          requests:
            memory: "256Mi"
            cpu: "250m"
      volumes:
      - name: postgres-config
        configMap:
          name: postgres-config
  volumeClaimTemplates:
  - metadata:
      name: postgres-data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 5Gi
EOF

# Wait for the initial pod to be ready
kubectl wait --for=condition=Ready pod postgres-cluster-0 --timeout=120s
echo "PostgreSQL primary is ready"
```

### Scaling Strategy 1: Gradual Scale-Out

```bash
# Before scaling, let's create some test data
kubectl exec postgres-cluster-0 -- psql -U admin -d production_db -c "
CREATE TABLE scaling_test (
  id SERIAL PRIMARY KEY,
  created_at TIMESTAMP DEFAULT NOW(),
  data TEXT
);

INSERT INTO scaling_test (data) VALUES 
  ('Initial data - before scaling'),
  ('More test data'),
  ('Data consistency test');

SELECT COUNT(*) FROM scaling_test;
"

echo "Test data created. Starting scale-out process..."

# Scale to 2 replicas with monitoring
kubectl scale statefulset postgres-cluster --replicas=2

# Monitor the scaling process
echo "Watching scaling process..."
kubectl get pods -l app=postgres-cluster -w &
WATCH_PID=$!

# Wait for new pod to be ready
kubectl wait --for=condition=Ready pod postgres-cluster-1 --timeout=180s

# Stop the watch
kill $WATCH_PID 2>/dev/null || true

# Verify data consistency
echo "Verifying data consistency across instances..."
kubectl exec postgres-cluster-0 -- psql -U admin -d production_db -c "SELECT COUNT(*) FROM scaling_test;"
```

**Analysis Questions:**
- How long did it take for postgres-cluster-1 to become ready?
- What steps would be needed to set up replication between the instances?
- How does this compare to scaling a stateless web application?

### Scaling Strategy 2: Pre-planned Scale Events

```bash
# Simulate a planned scaling event with preparation steps
echo "=== Planned Scaling Event ==="

# Step 1: Pre-scaling health check
echo "1. Pre-scaling health verification..."
kubectl describe statefulset postgres-cluster | grep -A 5 "Conditions"
kubectl get pvc -l app=postgres-cluster

# Step 2: Resource verification
echo "2. Checking cluster resources before scaling..."
kubectl top nodes
kubectl describe nodes | grep -A 5 "Allocated resources"

# Step 3: Execute scaling with monitoring
echo "3. Scaling to 3 replicas with monitoring..."
kubectl scale statefulset postgres-cluster --replicas=3

# Monitor resource usage during scaling
kubectl get pods -l app=postgres-cluster -o wide
kubectl wait --for=condition=Ready pod postgres-cluster-2 --timeout=180s

# Step 4: Post-scaling verification
echo "4. Post-scaling verification..."
kubectl get statefulset postgres-cluster
kubectl get pvc -l app=postgres-cluster
kubectl exec postgres-cluster-2 -- pg_isready -U admin
```

**Production Considerations:**
- What preparation steps should you take before scaling in production?
- How might you automate health checks during scaling operations?
- What rollback plan would you have if scaling fails?

### Scaling Strategy 3: Emergency Scale-Down

```bash
# Simulate an emergency where you need to scale down quickly
echo "=== Emergency Scale-Down Scenario ==="

# Current state check
kubectl get pods -l app=postgres-cluster

# Emergency scale-down to 1 replica
echo "Emergency: Scaling down to 1 replica..."
kubectl scale statefulset postgres-cluster --replicas=1

# Monitor which pods are terminated
kubectl get pods -l app=postgres-cluster -w &
WATCH_PID=$!
sleep 30
kill $WATCH_PID 2>/dev/null || true

# Verify remaining pod health
kubectl wait --for=condition=Ready pod postgres-cluster-0 --timeout=60s
kubectl exec postgres-cluster-0 -- pg_isready -U admin

# Check what happened to the PVCs
echo "Checking PVC status after scale-down..."
kubectl get pvc -l app=postgres-cluster
```

**Critical Thinking:**
- Which pods were terminated during scale-down?
- What happened to the data in the terminated pods?
- How might this behavior be beneficial for emergency situations?

## Rolling Update Strategies

Rolling updates for stateful applications require special consideration because of data consistency and service availability requirements.

### Lab: Safe Rolling Update Procedures

```bash
# First, let's add some monitoring to track update progress
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-monitoring
data:
  monitor-updates.sh: |
    #!/bin/bash
    echo "=== Rolling Update Monitor ==="
    echo "Timestamp: \$(date)"
    echo "Pod Status:"
    kubectl get pods -l app=postgres-cluster -o wide
    echo ""
    echo "StatefulSet Status:"
    kubectl get statefulset postgres-cluster -o wide
    echo ""
    echo "Database Connectivity Test:"
    if kubectl exec postgres-cluster-0 -- pg_isready -U admin >/dev/null 2>&1; then
      echo "✓ Database is accessible"
      kubectl exec postgres-cluster-0 -- psql -U admin -d production_db -c "SELECT COUNT(*) FROM scaling_test;" 2>/dev/null | tail -n1
    else
      echo "✗ Database connection failed"
    fi
    echo "=========================="
EOF
```

### Update Strategy 1: Configuration Updates

```bash
# Test a configuration change (low-risk update)
echo "=== Configuration Update Test ==="

# Update the PostgreSQL configuration
kubectl patch configmap postgres-config --patch '
data:
  postgresql.conf: |
    listen_addresses = '"'"'*'"'"'
    max_connections = 150  # Increased from 100
    shared_buffers = 256MB  # Increased from 128MB
    effective_cache_size = 512MB  # Increased from 256MB
    maintenance_work_mem = 128MB  # Increased from 64MB
    checkpoint_completion_target = 0.9
    wal_buffers = 16MB
    default_statistics_target = 100
    random_page_cost = 4
    effective_io_concurrency = 2
    log_statement = '"'"'all'"'"'  # Added logging
'

# Trigger a rolling restart to pick up the config changes
kubectl rollout restart statefulset postgres-cluster

# Monitor the rolling update
echo "Monitoring rolling update progress..."
kubectl rollout status statefulset postgres-cluster --timeout=300s
```

### Update Strategy 2: Image Updates

```bash
# Perform a PostgreSQL version update
echo "=== PostgreSQL Version Update ==="

# Check current version
echo "Current PostgreSQL version:"
kubectl exec postgres-cluster-0 -- psql -U admin -d production_db -c "SELECT version();"

# Update to a newer patch version
kubectl set image statefulset postgres-cluster postgres=postgres:15.3-alpine

# Monitor the rolling update with detailed tracking
echo "Starting rolling update monitoring..."
kubectl get pods -l app=postgres-cluster -w &
WATCH_PID=$!

# Run periodic connectivity tests during update
for i in {1..10}; do
  sleep 15
  echo "Update check #$i:"
  kubectl exec postgres-monitoring -- bash /monitor-updates.sh 2>/dev/null || echo "Monitoring temporarily unavailable"
done

kill $WATCH_PID 2>/dev/null || true

# Verify the update completed successfully
kubectl wait --for=condition=Ready pod -l app=postgres-cluster --timeout=300s
echo "Post-update PostgreSQL version:"
kubectl exec postgres-cluster-0 -- psql -U admin -d production_db -c "SELECT version();"
```

**Update Analysis Questions:**
- In what order were the pods updated?
- Was there any downtime during the update?
- How did StatefulSet updates differ from Deployment updates you've seen?

### Update Strategy 3: Controlled Update with Partitioning

```bash
# Demonstrate partition-based updates for extra control
echo "=== Partition-Based Rolling Update ==="

# Scale up to 3 replicas for this demonstration
kubectl scale statefulset postgres-cluster --replicas=3
kubectl wait --for=condition=Ready pod -l app=postgres-cluster --timeout=180s

# Set partition to 2 (only update pods with index >= 2)
kubectl patch statefulset postgres-cluster -p '{"spec":{"updateStrategy":{"rollingUpdate":{"partition":2}}}}'

# Trigger an update - only postgres-cluster-2 should update
kubectl set env statefulset postgres-cluster POSTGRES_SHARED_PRELOAD_LIBRARIES=pg_stat_statements

echo "Watching partitioned update (only postgres-cluster-2 should update):"
kubectl get pods -l app=postgres-cluster -w &
WATCH_PID=$!
sleep 60
kill $WATCH_PID 2>/dev/null || true

# Check which pods were updated
kubectl describe pods -l app=postgres-cluster | grep -A 5 "Environment"

# Now update partition to 1 to continue the update
kubectl patch statefulset postgres-cluster -p '{"spec":{"updateStrategy":{"rollingUpdate":{"partition":1}}}}'
sleep 30

# Finally, set partition to 0 to update all pods
kubectl patch statefulset postgres-cluster -p '{"spec":{"updateStrategy":{"rollingUpdate":{"partition":0}}}}'
kubectl wait --for=condition=Ready pod -l app=postgres-cluster --timeout=300s
```

**Partition Strategy Benefits:**
- Why might you want to control update progression this carefully?
- In what scenarios would partitioned updates be especially valuable?
- How does this compare to blue-green deployment strategies?

## Backup and Recovery Strategies

Stateful applications require comprehensive backup and recovery planning. Let's implement production-ready backup strategies.

### Lab: Implementing Backup Procedures

```bash
# Create a backup strategy for our PostgreSQL cluster
cat << EOF | kubectl apply -f -
# Backup storage configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: backup-scripts
data:
  backup-database.sh: |
    #!/bin/bash
    set -e
    
    BACKUP_DIR="/backups"
    TIMESTAMP=\$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="postgres_backup_\${TIMESTAMP}.sql"
    
    echo "Starting database backup at \$(date)"
    echo "Backup file: \${BACKUP_FILE}"
    
    # Create backup directory
    mkdir -p \$BACKUP_DIR
    
    # Perform database dump
    pg_dump -U admin -h localhost production_db > "\${BACKUP_DIR}/\${BACKUP_FILE}"
    
    # Compress the backup
    gzip "\${BACKUP_DIR}/\${BACKUP_FILE}"
    
    echo "Backup completed: \${BACKUP_FILE}.gz"
    echo "Backup size: \$(ls -lh \${BACKUP_DIR}/\${BACKUP_FILE}.gz)"
    
    # List all backups
    echo "All backups:"
    ls -lh \$BACKUP_DIR/
    
  restore-database.sh: |
    #!/bin/bash
    set -e
    
    BACKUP_DIR="/backups"
    RESTORE_FILE=\$1
    
    if [ -z "\$RESTORE_FILE" ]; then
      echo "Usage: \$0 <backup_file>"
      echo "Available backups:"
      ls -lh \$BACKUP_DIR/
      exit 1
    fi
    
    echo "Starting database restore from \$RESTORE_FILE"
    
    # Stop accepting connections (would be more sophisticated in production)
    psql -U admin -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='production_db';"
    
    # Drop and recreate database
    psql -U admin -d postgres -c "DROP DATABASE IF EXISTS production_db;"
    psql -U admin -d postgres -c "CREATE DATABASE production_db;"
    
    # Restore from backup
    gunzip -c "\${BACKUP_DIR}/\${RESTORE_FILE}" | psql -U admin -d production_db
    
    echo "Database restore completed from \$RESTORE_FILE"
---
# Persistent storage for backups
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-backups
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 10Gi
EOF

# Mount backup storage to the primary pod
kubectl patch statefulset postgres-cluster --patch '
spec:
  template:
    spec:
      containers:
      - name: postgres
        volumeMounts:
        - name: postgres-data
          mountPath: /var/lib/postgresql/data
        - name: postgres-config
          mountPath: /etc/postgresql
        - name: backup-storage
          mountPath: /backups
        - name: backup-scripts
          mountPath: /scripts
      volumes:
      - name: postgres-config
        configMap:
          name: postgres-config
      - name: backup-storage
        persistentVolumeClaim:
          claimName: postgres-backups
      - name: backup-scripts
        configMap:
          name: backup-scripts
          defaultMode: 0755
'

# Wait for the patch to take effect
kubectl wait --for=condition=Ready pod postgres-cluster-0 --timeout=180s
```

### Backup Procedure Testing

```bash
# First, create more test data to make backups meaningful
kubectl exec postgres-cluster-0 -- psql -U admin -d production_db -c "
INSERT INTO scaling_test (data) 
SELECT 'Backup test data - batch ' || generate_series(1, 1000);

CREATE TABLE backup_verification (
  id SERIAL PRIMARY KEY,
  backup_timestamp TIMESTAMP DEFAULT NOW(),
  verification_data TEXT
);

INSERT INTO backup_verification (verification_data) VALUES 
  ('Pre-backup verification record'),
  ('Data integrity checkpoint'),
  ('Backup completeness test');
"

# Perform a backup
echo "=== Creating Database Backup ==="
kubectl exec postgres-cluster-0 -- bash /scripts/backup-database.sh

# Verify backup was created
kubectl exec postgres-cluster-0 -- ls -la /backups/

# Add more data after backup (to verify restore point)
kubectl exec postgres-cluster-0 -- psql -U admin -d production_db -c "
INSERT INTO backup_verification (verification_data) VALUES ('Post-backup data - should not appear after restore');
"

# Check current data state
echo "=== Current Data State ==="
kubectl exec postgres-cluster-0 -- psql -U admin -d production_db -c "
SELECT COUNT(*) as scaling_test_count FROM scaling_test;
SELECT * FROM backup_verification ORDER BY id;
"
```

### Recovery Procedure Testing

```bash
# Test the recovery procedure
echo "=== Testing Database Recovery ==="

# First, identify the backup file to restore
BACKUP_FILE=$(kubectl exec postgres-cluster-0 -- ls /backups/ | grep postgres_backup | head -n1)
echo "Restoring from backup: $BACKUP_FILE"

# Perform the restore
kubectl exec postgres-cluster-0 -- bash /scripts/restore-database.sh "$BACKUP_FILE"

# Verify the restore
echo "=== Post-Restore Data Verification ==="
kubectl exec postgres-cluster-0 -- psql -U admin -d production_db -c "
SELECT COUNT(*) as scaling_test_count FROM scaling_test;
SELECT * FROM backup_verification ORDER BY id;
"

echo "=== Recovery Test Complete ==="
echo "Note: Post-backup data should not be present after restore"
```

**Backup Strategy Analysis:**
- What data was preserved vs lost during the restore?
- How long did the backup and restore procedures take?
- What improvements would you make for a production backup strategy?

### Advanced Backup: Point-in-Time Recovery Setup

```bash
# Configure Write-Ahead Log (WAL) archiving for point-in-time recovery
kubectl patch configmap postgres-config --patch '
data:
  postgresql.conf: |
    listen_addresses = '"'"'*'"'"'
    max_connections = 150
    shared_buffers = 256MB
    effective_cache_size = 512MB
    maintenance_work_mem = 128MB
    checkpoint_completion_target = 0.9
    wal_buffers = 16MB
    default_statistics_target = 100
    random_page_cost = 4
    effective_io_concurrency = 2
    log_statement = '"'"'all'"'"'
    
    # WAL archiving for point-in-time recovery
    wal_level = replica
    archive_mode = on
    archive_command = '"'"'cp %p /backups/wal_archive/%f'"'"'
    max_wal_senders = 3
    wal_keep_size = 1GB
'

# Restart PostgreSQL to apply WAL settings
kubectl rollout restart statefulset postgres-cluster
kubectl wait --for=condition=Ready pod postgres-cluster-0 --timeout=180s

# Create WAL archive directory
kubectl exec postgres-cluster-0 -- mkdir -p /backups/wal_archive

# Test WAL archiving
kubectl exec postgres-cluster-0 -- psql -U admin -d production_db -c "
INSERT INTO backup_verification (verification_data) VALUES ('WAL archiving test');
SELECT pg_switch_wal();  -- Force WAL file switch
"

# Check WAL archive
kubectl exec postgres-cluster-0 -- ls -la /backups/wal_archive/
```

## Monitoring and Alerting

Effective monitoring is crucial for maintaining healthy stateful applications in production.

### Lab: Comprehensive Monitoring Setup

```bash
# Create monitoring configuration
cat << EOF | kubectl apply -f -
# Monitoring ConfigMap with health check scripts
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-monitoring-advanced
data:
  health-check.sh: |
    #!/bin/bash
    
    echo "=== PostgreSQL Health Check ==="
    echo "Timestamp: \$(date)"
    
    # Basic connectivity
    if pg_isready -h localhost -U admin; then
      echo "✓ PostgreSQL is accepting connections"
    else
      echo "✗ PostgreSQL connection failed"
      exit 1
    fi
    
    # Database-specific checks
    CONN_COUNT=\$(psql -U admin -d production_db -t -c "SELECT count(*) FROM pg_stat_activity;")
    echo "Active connections: \$CONN_COUNT"
    
    # Check for replication lag (if replicas exist)
    REPLICA_COUNT=\$(kubectl get pods -l app=postgres-cluster --no-headers | wc -l)
    if [ \$REPLICA_COUNT -gt 1 ]; then
      echo "Cluster has \$REPLICA_COUNT instances"
    fi
    
    # Storage utilization
    STORAGE_USAGE=\$(df -h /var/lib/postgresql/data | tail -n1 | awk '{print \$5}')
    echo "Storage usage: \$STORAGE_USAGE"
    
    # Recent errors in logs
    ERROR_COUNT=\$(tail -n 100 /var/lib/postgresql/data/pgdata/log/* 2>/dev/null | grep -c "ERROR" || echo "0")
    echo "Recent errors: \$ERROR_COUNT"
    
    echo "Health check completed successfully"
    
  performance-metrics.sh: |
    #!/bin/bash
    
    echo "=== PostgreSQL Performance Metrics ==="
    
    # Connection statistics
    psql -U admin -d production_db -c "
    SELECT 
      datname,
      numbackends as active_connections,
      xact_commit as transactions_committed,
      xact_rollback as transactions_rolled_back,
      blks_read as blocks_read,
      blks_hit as blocks_hit,
      round((blks_hit::float / (blks_hit + blks_read) * 100), 2) as cache_hit_ratio
    FROM pg_stat_database 
    WHERE datname = 'production_db';
    "
    
    # Table statistics
    psql -U admin -d production_db -c "
    SELECT 
      schemaname,
      tablename,
      n_live_tup as live_rows,
      n_dead_tup as dead_rows,
      n_tup_ins as inserts,
      n_tup_upd as updates,
      n_tup_del as deletes
    FROM pg_stat_user_tables;
    "
    
  alert-check.sh: |
    #!/bin/bash
    
    ALERT_THRESHOLD_CONNECTIONS=80
    ALERT_THRESHOLD_STORAGE=85
    
    # Check connection count
    CONN_COUNT=\$(psql -U admin -d production_db -t -c "SELECT count(*) FROM pg_stat_activity;" | tr -d ' ')
    if [ \$CONN_COUNT -gt \$ALERT_THRESHOLD_CONNECTIONS ]; then
      echo "ALERT: High connection count: \$CONN_COUNT"
    fi
    
    # Check storage usage
    STORAGE_PCT=\$(df /var/lib/postgresql/data | tail -n1 | awk '{print \$5}' | sed 's/%//')
    if [ \$STORAGE_PCT -gt \$ALERT_THRESHOLD_STORAGE ]; then
      echo "ALERT: High storage usage: \${STORAGE_PCT}%"
    fi
    
    # Check for database errors
    ERROR_COUNT=\$(tail -n 50 /var/lib/postgresql/data/pgdata/log/* 2>/dev/null | grep -c "ERROR" || echo "0")
    if [ \$ERROR_COUNT -gt 5 ]; then
      echo "ALERT: Multiple recent errors: \$ERROR_COUNT"
    fi
    
    echo "Alert check completed"
---
# CronJob for regular health checks
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-health-monitor
spec:
  schedule: "*/5 * * * *"  # Every 5 minutes
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: health-check
            image: postgres:15-alpine
            command: ["/bin/bash"]
            args: ["/scripts/health-check.sh"]
            env:
            - name: PGPASSWORD
              value: "secure-password"
            volumeMounts:
            - name: monitoring-scripts
              mountPath: /scripts
          volumes:
          - name: monitoring-scripts
            configMap:
              name: postgres-monitoring-advanced
              defaultMode: 0755
          restartPolicy: OnFailure
          # Run health check against the primary pod
          serviceAccountName: default
EOF

# Add the monitoring scripts to the existing StatefulSet
kubectl patch statefulset postgres-cluster --patch '
spec:
  template:
    spec:
      containers:
      - name: postgres
        volumeMounts:
        - name: postgres-data
          mountPath: /var/lib/postgresql/data
        - name: postgres-config
          mountPath: /etc/postgresql
        - name: backup-storage
          mountPath: /backups
        - name: backup-scripts
          mountPath: /scripts
        - name: monitoring-scripts
          mountPath: /monitoring
      volumes:
      - name: postgres-config
        configMap:
          name: postgres-config
      - name: backup-storage
        persistentVolumeClaim:
          claimName: postgres-backups
      - name: backup-scripts
        configMap:
          name: backup-scripts
          defaultMode: 0755
      - name: monitoring-scripts
        configMap:
          name: postgres-monitoring-advanced
          defaultMode: 0755
'

kubectl wait --for=condition=Ready pod postgres-cluster-0 --timeout=180s
```

### Testing Monitoring Systems

```bash
# Test the monitoring scripts manually
echo "=== Testing Health Check ==="
kubectl exec postgres-cluster-0 -- bash /monitoring/health-check.sh

echo "=== Testing Performance Metrics ==="
kubectl exec postgres-cluster-0 -- bash /monitoring/performance-metrics.sh

echo "=== Testing Alert Check ==="
kubectl exec postgres-cluster-0 -- bash /monitoring/alert-check.sh

# Check the CronJob for automated monitoring
kubectl get cronjob postgres-health-monitor
kubectl get jobs -l job-name=postgres-health-monitor

# View recent monitoring job logs
LATEST_JOB=$(kubectl get jobs -l job-name=postgres-health-monitor --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}')
if [ ! -z "$LATEST_JOB" ]; then
  kubectl logs "job/$LATEST_JOB"
fi
```

### Stress Testing and Alert Validation

```bash
# Generate load to test monitoring alerts
echo "=== Generating Load to Test Alerts ==="

# Create multiple connections to test connection alerts
kubectl exec postgres-cluster-0 -- bash -c "
for i in {1..10}; do
  psql -U admin -d production_db -c 'SELECT pg_sleep(30);' &
done
wait
"

# Run alert check during high load
kubectl exec postgres-cluster-0 -- bash /monitoring/alert-check.sh