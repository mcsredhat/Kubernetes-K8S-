# Unit 5: Backup, Disaster Recovery, and Storage Monitoring

## Learning Objectives
By the end of this unit, you will:
- Design and implement comprehensive backup strategies for Kubernetes storage
- Build disaster recovery procedures for critical stateful applications
- Set up monitoring and alerting systems for storage health and performance
- Understand storage performance optimization techniques
- Implement cost management strategies for storage resources
- Master troubleshooting techniques for complex storage issues

## Prerequisites
- Completed Units 1-4: Storage fundamentals, StatefulSets, and security
- Understanding of backup and recovery concepts
- Basic knowledge of monitoring systems (Prometheus/Grafana helpful)
- Familiarity with cloud provider backup services

---

## 1. Backup Strategy Fundamentals

### Understanding Backup Types and Strategies

Before implementing backup solutions, let's understand the different approaches and their trade-offs:

| Backup Type | Description | Recovery Time | Storage Cost | Use Cases |
|-------------|-------------|---------------|--------------|-----------|
| **Full Backup** | Complete copy of all data | Fast | High | Weekly/Monthly |
| **Incremental** | Changes since last backup | Medium | Low | Daily |
| **Differential** | Changes since last full backup | Medium | Medium | Daily/Weekly |
| **Snapshot** | Point-in-time copy | Very Fast | Medium | Hourly/Daily |
| **Continuous** | Real-time replication | Instant | Highest | Critical systems |

### Backup Strategy Assessment

```yaml
# Create file: backup-strategy-assessment.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: backup-assessment-tool
data:
  assess.sh: |
    #!/bin/bash
    
    echo "=== Storage Backup Assessment ==="
    echo "Assessment Date: $(date)"
    
    # Analyze current storage landscape
    echo "--- Current Storage Analysis ---"
    kubectl get pvc --all-namespaces -o json | jq -r '
      .items[] |
      {
        namespace: .metadata.namespace,
        name: .metadata.name,
        size: .spec.resources.requests.storage,
        storageClass: .spec.storageClassName,
        accessModes: .spec.accessModes[0]
      } |
      "\(.namespace)/\(.name): \(.size) (\(.storageClass)) - \(.accessModes)"
    '
    
    # Calculate total storage
    echo -e "\n--- Storage Totals ---"
    kubectl get pv -o json | jq -r '
      [.items[].spec.capacity.storage | 
       sub("Gi$"; "") | tonumber] | 
      "Total Storage: \(add)Gi"
    '
    
    # Identify critical applications
    echo -e "\n--- Critical Applications (StatefulSets) ---"
    kubectl get statefulsets --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,REPLICAS:.spec.replicas,STORAGE:.spec.volumeClaimTemplates[0].spec.resources.requests.storage"
    
    # Check existing backup solutions
    echo -e "\n--- Existing Backup Jobs ---"
    kubectl get cronjobs --all-namespaces | grep -i backup || echo "No backup jobs found"
    
    echo -e "\n=== Assessment Complete ==="
---
apiVersion: batch/v1
kind: Job
metadata:
  name: backup-assessment
spec:
  template:
    spec:
      containers:
      - name: assessor
        image: bitnami/kubectl:latest
        command: ["/bin/bash", "/scripts/assess.sh"]
        volumeMounts:
        - name: scripts
          mountPath: /scripts
      volumes:
      - name: scripts
        configMap:
          name: backup-assessment-tool
          defaultMode: 0755
      restartPolicy: Never
```

---

## 2. Comprehensive Backup Implementation

### Database Backup System

```yaml
# Create file: comprehensive-database-backup.yaml
apiVersion: v1
kind: Secret
metadata:
  name: backup-config
type: Opaque
data:
  # Base64 encoded values - replace with actual values
  s3-access-key: YWNjZXNzLWtleS1leGFtcGxl
  s3-secret-key: c2VjcmV0LWtleS1leGFtcGxl
  encryption-key: ZW5jcnlwdGlvbi1rZXktZXhhbXBsZQ==
  db-password: ZGF0YWJhc2UtcGFzc3dvcmQ=
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: backup-scripts
data:
  backup-database.sh: |
    #!/bin/bash
    set -euo pipefail
    
    # Configuration
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    BACKUP_PREFIX="db-backup"
    BACKUP_FILE="${BACKUP_PREFIX}-${TIMESTAMP}"
    RETENTION_DAYS=30
    
    # Load secrets
    export AWS_ACCESS_KEY_ID=$(cat /backup-config/s3-access-key)
    export AWS_SECRET_ACCESS_KEY=$(cat /backup-config/s3-secret-key)
    ENCRYPTION_KEY=$(cat /backup-config/encryption-key)
    DB_PASSWORD=$(cat /backup-config/db-password)
    
    echo "Starting database backup process at $(date)"
    
    # Function to cleanup on exit
    cleanup() {
        echo "Cleaning up temporary files..."
        rm -f /tmp/${BACKUP_FILE}*
    }
    trap cleanup EXIT
    
    # Create database backup
    echo "Creating database dump..."
    PGPASSWORD="$DB_PASSWORD" pg_dump \
        -h postgres-service \
        -U postgres \
        -d myapp \
        --verbose \
        --no-owner \
        --no-privileges \
        > /tmp/${BACKUP_FILE}.sql
    
    # Verify backup
    if [ ! -s /tmp/${BACKUP_FILE}.sql ]; then
        echo "ERROR: Backup file is empty"
        exit 1
    fi
    
    echo "Database dump created: $(wc -l < /tmp/${BACKUP_FILE}.sql) lines"
    
    # Compress backup
    echo "Compressing backup..."
    gzip /tmp/${BACKUP_FILE}.sql
    
    # Encrypt backup
    echo "Encrypting backup..."
    openssl enc -aes-256-cbc -salt \
        -in /tmp/${BACKUP_FILE}.sql.gz \
        -out /tmp/${BACKUP_FILE}.sql.gz.enc \
        -pass pass:"$ENCRYPTION_KEY"
    
    # Create checksums
    echo "Creating checksums..."
    sha256sum /tmp/${BACKUP_FILE}.sql.gz.enc > /tmp/${BACKUP_FILE}.sql.gz.enc.sha256
    
    # Store locally first
    echo "Storing backup locally..."
    cp /tmp/${BACKUP_FILE}.sql.gz.enc /backup-storage/
    cp /tmp/${BACKUP_FILE}.sql.gz.enc.sha256 /backup-storage/
    
    # Upload to cloud storage (if configured)
    if command -v aws &> /dev/null && [ -n "${S3_BUCKET:-}" ]; then
        echo "Uploading to S3..."
        aws s3 cp /tmp/${BACKUP_FILE}.sql.gz.enc s3://${S3_BUCKET}/database-backups/
        aws s3 cp /tmp/${BACKUP_FILE}.sql.gz.enc.sha256 s3://${S3_BUCKET}/database-backups/
    fi
    
    # Cleanup old local backups
    echo "Cleaning up old local backups..."
    find /backup-storage -name "${BACKUP_PREFIX}-*.sql.gz.enc" -mtime +${RETENTION_DAYS} -delete
    find /backup-storage -name "${BACKUP_PREFIX}-*.sha256" -mtime +${RETENTION_DAYS} -delete
    
    # Update backup log
    echo "$(date): Backup completed successfully - ${BACKUP_FILE}.sql.gz.enc" >> /backup-storage/backup.log
    
    echo "Database backup completed successfully at $(date)"
  
  restore-database.sh: |
    #!/bin/bash
    set -euo pipefail
    
    # Configuration
    RESTORE_FILE="${1:-}"
    if [ -z "$RESTORE_FILE" ]; then
        echo "Usage: $0 <backup-file-name>"
        echo "Available backups:"
        ls -la /backup-storage/db-backup-*.sql.gz.enc 2>/dev/null || echo "No backups found"
        exit 1
    fi
    
    # Load secrets
    ENCRYPTION_KEY=$(cat /backup-config/encryption-key)
    DB_PASSWORD=$(cat /backup-config/db-password)
    
    echo "Starting database restore process at $(date)"
    echo "Restoring from: $RESTORE_FILE"
    
    # Verify backup exists
    if [ ! -f "/backup-storage/$RESTORE_FILE" ]; then
        echo "ERROR: Backup file not found: $RESTORE_FILE"
        exit 1
    fi
    
    # Verify checksum
    if [ -f "/backup-storage/$RESTORE_FILE.sha256" ]; then
        echo "Verifying backup integrity..."
        cd /backup-storage
        sha256sum -c "$RESTORE_FILE.sha256" || {
            echo "ERROR: Backup integrity check failed"
            exit 1
        }
        cd /tmp
    fi
    
    # Decrypt backup
    echo "Decrypting backup..."
    openssl enc -aes-256-cbc -d \
        -in "/backup-storage/$RESTORE_FILE" \
        -out "/tmp/restore.sql.gz" \
        -pass pass:"$ENCRYPTION_KEY"
    
    # Decompress backup
    echo "Decompressing backup..."
    gunzip /tmp/restore.sql.gz
    
    # Restore database
    echo "Restoring database..."
    PGPASSWORD="$DB_PASSWORD" psql \
        -h postgres-service \
        -U postgres \
        -d myapp \
        -f /tmp/restore.sql
    
    # Cleanup
    rm -f /tmp/restore.sql
    
    echo "Database restore completed successfully at $(date)"
---
# Database backup CronJob
apiVersion: batch/v1
kind: CronJob
metadata:
  name: database-backup
  labels:
    app: backup-system
    component: database-backup
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  successfulJobsHistoryLimit: 7
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      template:
        metadata:
          labels:
            app: backup-system
            component: database-backup
        spec:
          restartPolicy: OnFailure
          containers:
          - name: backup
            image: postgres:14
            command: ["/bin/bash", "/scripts/backup-database.sh"]
            env:
            - name: S3_BUCKET
              value: "your-backup-bucket"  # Configure your S3 bucket
            volumeMounts:
            - name: backup-scripts
              mountPath: /scripts
            - name: backup-config
              mountPath: /backup-config
            - name: backup-storage
              mountPath: /backup-storage
            resources:
              requests:
                memory: 256Mi
                cpu: 200m
              limits:
                memory: 512Mi
                cpu: 500m
          volumes:
          - name: backup-scripts
            configMap:
              name: backup-scripts
              defaultMode: 0755
          - name: backup-config
            secret:
              secretName: backup-config
          - name: backup-storage
            persistentVolumeClaim:
              claimName: backup-storage-pvc
---
# Backup storage PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: backup-storage-pvc
  labels:
    app: backup-system
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
  storageClassName: standard
```

### Application Data Backup System

```yaml
# Create file: application-data-backup.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-backup-scripts
data:
  backup-application.sh: |
    #!/bin/bash
    set -euo pipefail
    
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    APP_NAME="${APP_NAME:-myapp}"
    BACKUP_PREFIX="app-backup"
    
    echo "Starting application data backup for $APP_NAME at $(date)"
    
    # Create application-specific backup
    backup_application_data() {
        local app_name="$1"
        local backup_file="${BACKUP_PREFIX}-${app_name}-${TIMESTAMP}.tar.gz"
        
        echo "Backing up application data for: $app_name"
        
        # Find application data directories
        if [ -d "/app-data/$app_name" ]; then
            # Pre-backup hook - flush caches, create consistent snapshot
            echo "Running pre-backup hooks..."
            if [ -f "/app-data/$app_name/.backup-hooks/pre-backup.sh" ]; then
                /bin/bash "/app-data/$app_name/.backup-hooks/pre-backup.sh"
            fi
            
            # Create backup with exclusions
            tar --exclude='*.tmp' \
                --exclude='cache/*' \
                --exclude='logs/*.log' \
                --exclude='temp/*' \
                -czf "/backup-storage/$backup_file" \
                -C "/app-data" "$app_name"
            
            # Post-backup hook - resume normal operations
            echo "Running post-backup hooks..."
            if [ -f "/app-data/$app_name/.backup-hooks/post-backup.sh" ]; then
                /bin/bash "/app-data/$app_name/.backup-hooks/post-backup.sh"
            fi
            
            # Verify backup
            tar -tzf "/backup-storage/$backup_file" >/dev/null && \
                echo "Backup verification successful: $backup_file"
            
            # Create metadata
            cat > "/backup-storage/$backup_file.meta" << EOF
{
  "backup_date": "$(date -Iseconds)",
  "application": "$app_name",
  "backup_size": "$(du -h /backup-storage/$backup_file | cut -f1)",
  "file_count": $(tar -tzf /backup-storage/$backup_file | wc -l),
  "backup_type": "full"
}
EOF
        else
            echo "No data directory found for $app_name"
        fi
    }
    
    # Backup multiple applications
    for app in $(ls /app-data/ 2>/dev/null || echo "$APP_NAME"); do
        backup_application_data "$app"
    done
    
    # Cleanup old backups
    echo "Cleaning up old backups..."
    find /backup-storage -name "${BACKUP_PREFIX}-*.tar.gz" -mtime +14 -delete
    find /backup-storage -name "${BACKUP_PREFIX}-*.meta" -mtime +14 -delete
    
    echo "Application data backup completed at $(date)"
  
  restore-application.sh: |
    #!/bin/bash
    set -euo pipefail
    
    RESTORE_FILE="${1:-}"
    TARGET_APP="${2:-}"
    
    if [ -z "$RESTORE_FILE" ]; then
        echo "Usage: $0 <backup-file> [target-app-name]"
        echo "Available backups:"
        ls -la /backup-storage/app-backup-*.tar.gz 2>/dev/null || echo "No backups found"
        exit 1
    fi
    
    echo "Starting application restore process at $(date)"
    
    # Extract application name from backup if not specified
    if [ -z "$TARGET_APP" ]; then
        TARGET_APP=$(echo "$RESTORE_FILE" | sed -E 's/app-backup-([^-]+)-.*/\1/')
    fi
    
    echo "Restoring to application: $TARGET_APP"
    
    # Verify backup exists
    if [ ! -f "/backup-storage/$RESTORE_FILE" ]; then
        echo "ERROR: Backup file not found: $RESTORE_FILE"
        exit 1
    fi
    
    # Show backup metadata
    if [ -f "/backup-storage/$RESTORE_FILE.meta" ]; then
        echo "Backup metadata:"
        cat "/backup-storage/$RESTORE_FILE.meta"
    fi
    
    # Create restore directory
    mkdir -p "/app-data/$TARGET_APP"
    
    # Pre-restore hook
    if [ -f "/app-data/$TARGET_APP/.backup-hooks/pre-restore.sh" ]; then
        echo "Running pre-restore hooks..."
        /bin/bash "/app-data/$TARGET_APP/.backup-hooks/pre-restore.sh"
    fi
    
    # Restore data
    echo "Extracting backup..."
    tar -xzf "/backup-storage/$RESTORE_FILE" -C "/app-data/"
    
    # Post-restore hook
    if [ -f "/app-data/$TARGET_APP/.backup-hooks/post-restore.sh" ]; then
        echo "Running post-restore hooks..."
        /bin/bash "/app-data/$TARGET_APP/.backup-hooks/post-restore.sh"
    fi
    
    echo "Application restore completed at $(date)"
---
# Application backup CronJob
apiVersion: batch/v1
kind: CronJob
metadata:
  name: application-backup
spec:
  schedule: "0 3 * * *"  # Daily at 3 AM
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
          - name: backup
            image: busybox
            command: ["/bin/sh", "/scripts/backup-application.sh"]
            env:
            - name: APP_NAME
              value: "myapp"
            volumeMounts:
            - name: backup-scripts
              mountPath: /scripts
            - name: app-data
              mountPath: /app-data
            - name: backup-storage
              mountPath: /backup-storage
          volumes:
          - name: backup-scripts
            configMap:
              name: app-backup-scripts
              defaultMode: 0755
          - name: app-data
            persistentVolumeClaim:
              claimName: app-data-pvc
          - name: backup-storage
            persistentVolumeClaim:
              claimName: backup-storage-pvc
```

---

## 3. Disaster Recovery Implementation

### Multi-Zone Disaster Recovery

```yaml
# Create file: disaster-recovery-system.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: dr-scripts
data:
  dr-failover.sh: |
    #!/bin/bash
    set -euo pipefail
    
    DR_SCENARIO="${1:-manual}"
    PRIMARY_REGION="${PRIMARY_REGION:-us-west-2}"
    DR_REGION="${DR_REGION:-us-east-1}"
    
    echo "=== Disaster Recovery Failover ==="
    echo "Scenario: $DR_SCENARIO"
    echo "Primary Region: $PRIMARY_REGION"
    echo "DR Region: $DR_REGION"
    echo "Initiated at: $(date)"
    
    # Function to check primary region health
    check_primary_health() {
        echo "Checking primary region health..."
        
        # Check if primary database is accessible
        if timeout 10 kubectl get pods -l app=postgres --context=primary 2>/dev/null; then
            echo "Primary region appears healthy"
            return 0
        else
            echo "Primary region is not responding"
            return 1
        fi
    }
    
    # Function to promote DR region
    promote_dr_region() {
        echo "Promoting DR region to primary..."
        
        # Switch kubectl context to DR region
        kubectl config use-context dr-region
        
        # Scale up DR applications
        kubectl scale deployment myapp --replicas=3
        kubectl scale statefulset postgres-dr --replicas=1
        
        # Update DNS to point to DR region (implementation depends on your setup)
        echo "Updating DNS records..." 
        # aws route53 change-resource-record-sets --hosted-zone-id ZXXXXX --change-batch file://dns-change.json
        
        # Verify DR services are healthy
        kubectl wait deployment/myapp --for=condition=available --timeout=300s
        kubectl wait statefulset/postgres-dr --for=condition=Ready --timeout=300s
        
        echo "DR region promoted successfully"
    }
    
    # Function to replicate data to DR
    replicate_to_dr() {
        echo "Initiating data replication to DR region..."
        
        # Trigger cross-region backup replication
        kubectl create job --from=cronjob/database-backup dr-backup-$(date +%s)
        
        # Copy latest backup to DR region
        LATEST_BACKUP=$(ls -t /backup-storage/db-backup-*.sql.gz.enc | head -1)
        if [ -n "$LATEST_BACKUP" ]; then
            echo "Replicating backup: $LATEST_BACKUP"
            aws s3 cp "$LATEST_BACKUP" s3://dr-backup-bucket/
        fi
    }
    
    # Main failover logic
    case "$DR_SCENARIO" in
        "automatic")
            if ! check_primary_health; then
                echo "Automatic failover triggered due to primary region failure"
                promote_dr_region
            else
                echo "Primary region is healthy, no failover needed"
            fi
            ;;
        "manual")
            echo "Manual failover initiated"
            promote_dr_region
            ;;
        "test")
            echo "DR test mode - simulating failover"
            check_primary_health || true
            echo "Would promote DR region (test mode)"
            ;;
        *)
            echo "Unknown DR scenario: $DR_SCENARIO"
            exit 1
            ;;
    esac
    
    echo "=== DR Process Complete ==="
  
  dr-failback.sh: |
    #!/bin/bash
    set -euo pipefail
    
    echo "=== Disaster Recovery Failback ==="
    echo "Initiated at: $(date)"
    
    # Verify primary region is healthy
    echo "Verifying primary region health..."
    kubectl config use-context primary
    kubectl get nodes
    
    # Sync data from DR back to primary
    echo "Syncing data from DR to primary..."
    kubectl config use-context dr-region
    kubectl create job --from=cronjob/database-backup failback-backup-$(date +%s)
    
    # Wait for backup and restore to primary
    kubectl config use-context primary
    echo "Restoring data to primary region..."
    # Implementation depends on your backup system
    
    # Scale down DR region
    kubectl config use-context dr-region
    kubectl scale deployment myapp --replicas=0
    kubectl scale statefulset postgres-dr --replicas=0
    
    # Scale up primary region
    kubectl config use-context primary
    kubectl scale deployment myapp --replicas=3
    kubectl scale statefulset postgres --replicas=1
    
    # Update DNS back to primary
    echo "Updating DNS back to primary region..."
    
    # Verify primary is operational
    kubectl wait deployment/myapp --for=condition=available --timeout=300s
    
    echo "=== Failback Complete ==="
---
# DR monitoring and automation
apiVersion: batch/v1
kind: CronJob
metadata:
  name: dr-health-check
spec:
  schedule: "*/5 * * * *"  # Every 5 minutes
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
          - name: dr-monitor
            image: bitnami/kubectl:latest
            command: ["/bin/bash", "-c"]
            args:
            - |
              echo "DR Health Check at $(date)"
              
              # Check primary region
              PRIMARY_HEALTHY=true
              if ! timeout 30 kubectl get pods --context=primary 2>/dev/null; then
                PRIMARY_HEALTHY=false
                echo "WARNING: Primary region not responding"
              fi
              
              # Check DR region readiness
              DR_READY=true
              if ! timeout 30 kubectl get pods --context=dr-region 2>/dev/null; then
                DR_READY=false
                echo "WARNING: DR region not accessible"
              fi
              
              # Auto-failover logic (be very careful with this)
              if [ "$PRIMARY_HEALTHY" = "false" ] && [ "$DR_READY" = "true" ]; then
                echo "CRITICAL: Primary down, DR available - consider failover"
                # Uncomment for automatic failover (high risk)
                # /scripts/dr-failover.sh automatic
              fi
            volumeMounts:
            - name: dr-scripts
              mountPath: /scripts
          volumes:
          - name: dr-scripts
            configMap:
              name: dr-scripts
              defaultMode: 0755
```

### Data Replication Setup

```yaml
# Create file: data-replication-setup.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: data-replication-service
spec:
  replicas: 1
  selector:
    matchLabels:
      app: data-replication
  template:
    metadata:
      labels:
        app: data-replication
    spec:
      containers:
      - name: replicator
        image: postgres:14
        command:
        - /bin/bash
        - -c
        - |
          echo "Starting continuous data replication..."
          
          while true; do
            echo "Replication cycle at $(date)"
            
            # Check primary database health
            if PGPASSWORD=$PRIMARY_DB_PASSWORD psql -h $PRIMARY_DB_HOST -U postgres -d myapp -c "SELECT 1;" >/dev/null 2>&1; then
              echo "Primary database is healthy"
              
              # Create incremental backup
              TIMESTAMP=$(date +%Y%m%d-%H%M%S)
              PGPASSWORD=$PRIMARY_DB_PASSWORD pg_dump \
                -h $PRIMARY_DB_HOST \
                -U postgres \
                -d myapp \
                --verbose \
                > /replication-storage/incremental-$TIMESTAMP.sql
              
              # Compress and encrypt
              gzip /replication-storage/incremental-$TIMESTAMP.sql
              
              # Replicate to DR region (implement based on your infrastructure)
              echo "Replicating to DR region..."
              # aws s3 sync /replication-storage/ s3://dr-replication-bucket/
              
              echo "Replication cycle completed"
            else
              echo "WARNING: Primary database not accessible"
            fi
            
            # Sleep for replication interval
            sleep 300  # 5 minutes
          done
        env:
        - name: PRIMARY_DB_HOST
          value: "postgres-service"
        - name: PRIMARY_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: backup-config
              key: db-password
        volumeMounts:
        - name: replication-storage
          mountPath: /replication-storage
        resources:
          requests:
            memory: 128Mi
            cpu: 100m
          limits:
            memory: 256Mi
            cpu: 200m
      volumes:
      - name: replication-storage
        persistentVolumeClaim:
          claimName: replication-storage-pvc
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: replication-storage-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
  storageClassName: standard
```

---

## 4. Storage Monitoring and Alerting

### Comprehensive Storage Monitoring

```yaml
# Create file: storage-monitoring-system.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: storage-monitoring-scripts
data:
  monitor-storage.sh: |
    #!/bin/bash
    
    echo "=== Storage Monitoring Report ==="
    echo "Timestamp: $(date)"
    
    # PVC Usage Analysis
    echo "--- PVC Usage Analysis ---"
    kubectl get pvc --all-namespaces -o json | jq -r '
      .items[] |
      select(.status.phase == "Bound") |
      {
        namespace: .metadata.namespace,
        name: .metadata.name,
        capacity: .status.capacity.storage,
        storageClass: .spec.storageClassName,
        accessModes: .spec.accessModes,
        volumeName: .spec.volumeName
      } |
      "\(.namespace)/\(.name): \(.capacity) (\(.storageClass)) - \(.accessModes[0])"
    '
    
    # Storage Class Analysis
    echo -e "\n--- Storage Class Analysis ---"
    kubectl get storageclass -o custom-columns="NAME:.metadata.name,PROVISIONER:.provisioner,RECLAIM_POLICY:.reclaimPolicy,VOLUME_BINDING_MODE:.volumeBindingMode"
    
    # PV Status Check
    echo -e "\n--- PV Status Check ---"
    kubectl get pv -o custom-columns="NAME:.metadata.name,CAPACITY:.spec.capacity.storage,ACCESS_MODES:.spec.accessModes,RECLAIM_POLICY:.spec.persistentVolumeReclaimPolicy,STATUS:.status.phase,CLAIM:.spec.claimRef.name"
    
    # Failed PVCs
    echo -e "\n--- Failed PVCs ---"
    kubectl get pvc --all-namespaces -o json | jq -r '
      .items[] |
      select(.status.phase != "Bound") |
      "\(.metadata.namespace)/\(.metadata.name): \(.status.phase)"
    '
    
    # Storage Events
    echo -e "\n--- Recent Storage Events ---"
    kubectl get events --all-namespaces --field-selector reason=FailedMount,reason=VolumeFailedMount,reason=FailedAttachVolume --sort-by='.lastTimestamp' | tail -10
    
    echo "=== Monitoring Complete ==="
  
  check-storage-health.sh: |
    #!/bin/bash
    
    # Storage health check with alerting thresholds
    WARN_THRESHOLD=80
    CRITICAL_THRESHOLD=90
    
    echo "=== Storage Health Check ==="
    
    # Function to get PVC usage percentage
    get_pvc_usage() {
        local namespace="$1"
        local pvc_name="$2"
        
        # Get pod using the PVC
        local pod=$(kubectl get pods -n "$namespace" -o json | jq -r --arg pvc "$pvc_name" '
          .items[] |
          select(.spec.volumes[]?.persistentVolumeClaim.claimName == $pvc) |
          .metadata.name
        ' | head -1)
        
        if [ -n "$pod" ]; then
            # Get usage from inside the pod
            local usage=$(kubectl exec -n "$namespace" "$pod" -- df -h | grep -v Filesystem | awk '{print $5}' | sed 's/%//' | sort -n | tail -1 2>/dev/null || echo "0")
            echo "$usage"
        else
            echo "0"
        fi
    }
    
    # Check all PVCs
    kubectl get pvc --all-namespaces -o json | jq -r '.items[] | "\(.metadata.namespace) \(.metadata.name)"' | while read namespace pvc_name; do
        usage=$(get_pvc_usage "$namespace" "$pvc_name")
        
        if [ "$usage" -ge "$CRITICAL_THRESHOLD" ]; then
            echo "CRITICAL: $namespace/$pvc_name usage at ${usage}%"
        elif [ "$usage" -ge "$WARN_THRESHOLD" ]; then
            echo "WARNING: $namespace/$pvc_name usage at ${usage}%"
        else
            echo "OK: $namespace/$pvc_name usage at ${usage}%"
        fi
    done
---
# Storage monitoring DaemonSet
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: storage-node-monitor
spec:
  selector:
    matchLabels:
      app: storage-monitor
  template:
    metadata:
      labels:
        app: storage-monitor
    spec:
      hostNetwork: true
      hostPID: true
      containers:
      - name: monitor
        image: busybox
        securityContext:
          privileged: true
        command:
        - /bin/sh
        - -c
        - |
          while true; do
            echo "=== Node Storage Report ==="
            echo "Node: $(hostname)"
            echo "Timestamp: $(date)"
            
            # Disk usage
            echo "--- Disk Usage ---"
            df -h | grep -E "(sda|nvme|xvd)"
            
            # Kubelet volume usage
            echo "--- Kubelet Volumes ---"
            du -sh /var/lib/kubelet/pods/*/volumes/* 2>/dev/null | head -10
            
            # I/O statistics
            echo "--- I/O Stats ---"
            cat /proc/diskstats | awk '{print $3, $4, $8}' | grep -E "(sda|nvme|xvd)" | head -5
            
            echo "=========================="
            sleep 300
          done
        volumeMounts:
        - name: proc
          mountPath: /proc
          readOnly: true
        - name: kubelet
          mountPath: /var/lib/kubelet
          readOnly: true
      volumes:
      - name: proc
        hostPath:
          path: /proc
      - name: kubelet
        hostPath:
          path: /var/lib/kubelet
      tolerations:
      - operator: Exists
```