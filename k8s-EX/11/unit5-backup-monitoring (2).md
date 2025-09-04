              {
                "expr": "kubernetes_storage_pvc_total",
                "legendFormat": "Total PVCs"
              },
              {
                "expr": "kubernetes_storage_pvc_pending", 
                "legendFormat": "Pending PVCs"
              }
            ],
            "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
          },
          {
            "title": "Storage Capacity Utilization",
            "type": "graph",
            "targets": [
              {
                "expr": "100 - (node_filesystem_avail_bytes / node_filesystem_size_bytes * 100)",
                "legendFormat": "{{instance}} - {{mountpoint}}"
              }
            ],
            "yAxes": [
              {
                "label": "Usage %",
                "max": 100,
                "min": 0
              }
            ],
            "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
          },
          {
            "title": "PV Status Distribution",
            "type": "piechart",
            "targets": [
              {
                "expr": "kubernetes_storage_pv_available",
                "legendFormat": "Available"
              }
            ],
            "gridPos": {"h": 8, "w": 24, "x": 0, "y": 8}
          }
        ],
        "time": {
          "from": "now-1h",
          "to": "now"
        },
        "refresh": "30s"
      }
    }
```

---

## 5. Performance Optimization

### Storage Performance Testing Suite

```yaml
# Create file: storage-performance-tests.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: performance-test-scripts
data:
  benchmark-storage.sh: |
    #!/bin/bash
    set -euo pipefail
    
    TEST_TYPE="${1:-all}"
    TEST_SIZE="${2:-1G}"
    TEST_PATH="${3:-/test-storage}"
    
    echo "=== Storage Performance Benchmark ==="
    echo "Test Type: $TEST_TYPE"
    echo "Test Size: $TEST_SIZE"
    echo "Test Path: $TEST_PATH"
    echo "Started at: $(date)"
    
    # Create test directory
    mkdir -p "$TEST_PATH"
    cd "$TEST_PATH"
    
    # Sequential write test
    test_sequential_write() {
        echo "--- Sequential Write Test ---"
        sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
        dd if=/dev/zero of=test_write bs=1M count=${TEST_SIZE%G} oflag=direct 2>&1 | grep -E "(copied|MB/s)"
    }
    
    # Sequential read test  
    test_sequential_read() {
        echo "--- Sequential Read Test ---"
        sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
        dd if=test_write of=/dev/null bs=1M iflag=direct 2>&1 | grep -E "(copied|MB/s)"
    }
    
    # Random I/O test
    test_random_io() {
        echo "--- Random I/O Test ---"
        if command -v fio >/dev/null 2>&1; then
            fio --name=random-rw --ioengine=libaio --iodepth=4 --rw=randrw --bs=4k --size=100M --direct=1 --runtime=30 --numjobs=1
        else
            echo "fio not available, running basic random I/O test"
            for i in {1..100}; do
                dd if=/dev/zero of=random_$i bs=4k count=1 oflag=direct 2>/dev/null
            done
            echo "Created 100 4K random files"
            rm -f random_*
        fi
    }
    
    # IOPS test
    test_iops() {
        echo "--- IOPS Test ---"
        start_time=$(date +%s)
        for i in {1..1000}; do
            dd if=/dev/zero of=iops_test_$i bs=4k count=1 oflag=direct 2>/dev/null
        done
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        iops=$((1000 / duration))
        echo "IOPS: $iops (1000 operations in ${duration}s)"
        rm -f iops_test_*
    }
    
    # Latency test
    test_latency() {
        echo "--- Latency Test ---"
        for i in {1..10}; do
            start=$(date +%s.%N)
            dd if=/dev/zero of=latency_test bs=4k count=1 oflag=direct 2>/dev/null
            end=$(date +%s.%N)
            latency=$(echo "$end - $start" | bc -l 2>/dev/null || echo "0.001")
            echo "Write latency $i: ${latency}s"
            rm -f latency_test
        done
    }
    
    # Run tests based on type
    case "$TEST_TYPE" in
        "write")
            test_sequential_write
            ;;
        "read")
            test_sequential_write  # Need file first
            test_sequential_read
            ;;
        "random")
            test_random_io
            ;;
        "iops")
            test_iops
            ;;
        "latency")
            test_latency
            ;;
        "all")
            test_sequential_write
            test_sequential_read
            test_random_io
            test_iops
            test_latency
            ;;
        *)
            echo "Unknown test type: $TEST_TYPE"
            exit 1
            ;;
    esac
    
    # Cleanup
    rm -f test_write
    
    echo "=== Benchmark Complete at $(date) ==="
  
  storage-stress-test.sh: |
    #!/bin/bash
    set -euo pipefail
    
    DURATION="${1:-300}"  # 5 minutes default
    THREADS="${2:-4}"
    TEST_PATH="${3:-/stress-test}"
    
    echo "=== Storage Stress Test ==="
    echo "Duration: ${DURATION}s"
    echo "Threads: $THREADS"
    echo "Started at: $(date)"
    
    mkdir -p "$TEST_PATH"
    
    # Function for stress testing
    stress_worker() {
        local worker_id=$1
        local end_time=$(($(date +%s) + DURATION))
        
        while [ $(date +%s) -lt $end_time ]; do
            # Mixed workload
            dd if=/dev/zero of="$TEST_PATH/stress_${worker_id}_$(date +%s)" bs=1M count=10 2>/dev/null
            find "$TEST_PATH" -name "stress_${worker_id}_*" -mmin +1 -delete 2>/dev/null || true
            sleep 0.1
        done
        
        echo "Worker $worker_id completed"
    }
    
    # Start stress workers
    for i in $(seq 1 $THREADS); do
        stress_worker $i &
    done
    
    # Monitor during stress test
    monitor_start_time=$(date +%s)
    while [ $(($(date +%s) - monitor_start_time)) -lt $DURATION ]; do
        echo "--- Stress Monitor at $(date) ---"
        df -h "$TEST_PATH" | tail -1
        ls -la "$TEST_PATH" | wc -l | xargs echo "Active files:"
        sleep 10
    done
    
    # Wait for all workers
    wait
    
    # Cleanup
    rm -rf "$TEST_PATH"/stress_*
    
    echo "=== Stress Test Complete at $(date) ==="
---
# Performance testing job
apiVersion: batch/v1
kind: Job
metadata:
  name: storage-performance-test
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: performance-test
        image: ubuntu:20.04
        command: ["/bin/bash"]
        args: ["-c", "apt-get update && apt-get install -y fio bc && /scripts/benchmark-storage.sh all 2G /test-storage"]
        volumeMounts:
        - name: test-scripts
          mountPath: /scripts
        - name: test-storage
          mountPath: /test-storage
        resources:
          requests:
            memory: 256Mi
            cpu: 200m
          limits:
            memory: 512Mi
            cpu: 500m
      volumes:
      - name: test-scripts
        configMap:
          name: performance-test-scripts
          defaultMode: 0755
      - name: test-storage
        persistentVolumeClaim:
          claimName: performance-test-pvc
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

### Storage Optimization Recommendations

```yaml
# Create file: storage-optimization.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: storage-optimization-guide
data:
  optimization-recommendations.md: |
    # Storage Performance Optimization Guide
    
    ## Storage Class Optimization
    
    ### High Performance Applications (Databases)
    - Use premium SSD storage classes
    - Enable provisioned IOPS where available
    - Consider local NVMe storage for ultra-low latency
    - Set appropriate volume binding mode
    
    ### Standard Applications
    - Use general-purpose SSD (gp3) for balanced cost/performance
    - Enable volume expansion for growth
    - Consider regional replication for availability
    
    ### Archival/Backup Storage  
    - Use HDD-based storage classes for cost efficiency
    - Implement lifecycle policies for automatic tiering
    - Use compression and deduplication
    
    ## Application-Level Optimization
    
    ### Database Optimization
    ```yaml
    # Optimized database storage configuration
    volumeClaimTemplates:
    - metadata:
        name: database-storage
      spec:
        accessModes: [ReadWriteOnce]
        resources:
          requests:
            storage: 100Gi
        storageClassName: premium-ssd
    ```
    
    ### Container Optimization
    - Use separate volumes for different data types
    - Implement proper resource limits
    - Use init containers for data preparation
    - Configure proper security contexts
    
    ## Network and I/O Optimization
    
    ### Network Attached Storage
    - Use appropriate NFS versions (4.1 recommended)
    - Tune NFS mount options (hard, intr, timeo)
    - Consider network bandwidth limitations
    
    ### Block Storage
    - Align I/O patterns with storage block size
    - Use direct I/O for database workloads
    - Implement proper queuing strategies
    
    ## Monitoring and Tuning
    
    ### Key Metrics to Monitor
    - IOPS (Input/Output Operations Per Second)
    - Throughput (MB/s)
    - Latency (response time)
    - Queue depth
    - Error rates
    
    ### Performance Baselines
    - Establish baseline performance metrics
    - Regular performance testing
    - Capacity planning based on growth trends
    - Alerting on performance degradation
  
  tune-storage-performance.sh: |
    #!/bin/bash
    
    echo "=== Storage Performance Tuning ==="
    
    # Check current I/O scheduler
    echo "Current I/O schedulers:"
    for disk in /sys/block/sd*/queue/scheduler; do
        if [ -f "$disk" ]; then
            echo "$disk: $(cat $disk)"
        fi
    done
    
    # Check mount options
    echo -e "\nMount options:"
    mount | grep -E "(ext4|xfs|nfs)" | head -5
    
    # Check vm settings
    echo -e "\nVM settings:"
    echo "vm.dirty_ratio: $(cat /proc/sys/vm/dirty_ratio)"
    echo "vm.dirty_background_ratio: $(cat /proc/sys/vm/dirty_background_ratio)"
    echo "vm.swappiness: $(cat /proc/sys/vm/swappiness)"
    
    # Storage device information
    echo -e "\nStorage devices:"
    lsblk -d -o NAME,SIZE,ROTA,QUEUE-SIZE,RQ-SIZE 2>/dev/null || lsblk
    
    echo "=== Tuning Analysis Complete ==="
```

---

## 6. Cost Management and Optimization

### Storage Cost Analysis

```yaml
# Create file: storage-cost-management.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cost-analysis-scripts
data:
  analyze-storage-costs.sh: |
    #!/bin/bash
    
    echo "=== Storage Cost Analysis ==="
    echo "Analysis Date: $(date)"
    
    # Define cost per GB per month (adjust for your cloud provider)
    declare -A STORAGE_COSTS
    STORAGE_COSTS["premium-ssd"]=0.17
    STORAGE_COSTS["standard"]=0.10
    STORAGE_COSTS["cheap-storage"]=0.045
    STORAGE_COSTS["backup-storage"]=0.023
    
    # Calculate current costs
    echo "--- Current Storage Costs ---"
    total_monthly_cost=0
    
    kubectl get pvc --all-namespaces -o json | jq -r '
      .items[] |
      select(.status.phase == "Bound") |
      {
        namespace: .metadata.namespace,
        name: .metadata.name,
        size: .spec.resources.requests.storage,
        storageClass: .spec.storageClassName
      } |
      "\(.namespace) \(.name) \(.size) \(.storageClass)"
    ' | while read namespace name size storage_class; do
        # Extract numeric size (assumes Gi suffix)
        size_gb=$(echo "$size" | sed 's/Gi$//')
        cost_per_gb=${STORAGE_COSTS[$storage_class]:-0.10}
        monthly_cost=$(echo "$size_gb * $cost_per_gb" | bc -l)
        total_monthly_cost=$(echo "$total_monthly_cost + $monthly_cost" | bc -l)
        
        printf "%-20s %-30s %8s %-15s $%.2f\n" "$namespace" "$name" "$size" "$storage_class" "$monthly_cost"
    done
    
    echo -e "\nTotal estimated monthly cost: \$total_monthly_cost"
    
    # Optimization recommendations
    echo -e "\n--- Cost Optimization Recommendations ---"
    
    # Find oversized PVCs
    echo "Potentially oversized PVCs (>50Gi):"
    kubectl get pvc --all-namespaces -o json | jq -r '
      .items[] |
      select(.spec.resources.requests.storage | test("^[5-9][0-9]Gi|^[0-9]{3,}Gi")) |
      "\(.metadata.namespace)/\(.metadata.name): \(.spec.resources.requests.storage)"
    '
    
    # Find premium storage for non-critical apps
    echo -e "\nPremium storage usage review:"
    kubectl get pvc --all-namespaces -o json | jq -r '
      .items[] |
      select(.spec.storageClassName | test("premium|fast|ssd")) |
      "\(.metadata.namespace)/\(.metadata.name): \(.spec.storageClassName)"
    '
    
    echo "=== Cost Analysis Complete ==="
  
  optimize-storage-costs.sh: |
    #!/bin/bash
    set -euo pipefail
    
    ACTION="${1:-analyze}"
    
    echo "=== Storage Cost Optimization ==="
    echo "Action: $ACTION"
    
    case "$ACTION" in
        "analyze")
            echo "Analyzing storage for cost optimization opportunities..."
            
            # Find unused PVCs
            echo "--- Unused PVCs ---"
            kubectl get pvc --all-namespaces -o json | jq -r '
              .items[] |
              select(.status.phase == "Bound") |
              {namespace: .metadata.namespace, name: .metadata.name, volume: .spec.volumeName}
            ' | while read -r line; do
                namespace=$(echo "$line" | jq -r '.namespace')
                name=$(echo "$line" | jq -r '.name')
                
                # Check if any pods are using this PVC
                pods_using_pvc=$(kubectl get pods -n "$namespace" -o json | jq -r --arg pvc "$name" '
                  .items[] |
                  select(.spec.volumes[]?.persistentVolumeClaim.claimName == $pvc) |
                  .metadata.name
                ' | wc -l)
                
                if [ "$pods_using_pvc" -eq 0 ]; then
                    echo "Unused: $namespace/$name"
                fi
            done
            ;;
            
        "migrate")
            echo "Migration recommendations:"
            echo "1. Move backup data to cheaper storage classes"
            echo "2. Use lifecycle policies for automated tiering"
            echo "3. Implement compression for archival data"
            ;;
            
        "cleanup")
            echo "Cleanup recommendations:"
            echo "1. Remove unused PVCs (check unused list above)"
            echo "2. Archive old backup data"
            echo "3. Compress large log files"
            ;;
            
        *)
            echo "Unknown action: $ACTION"
            echo "Available actions: analyze, migrate, cleanup"
            exit 1
            ;;
    esac
    
    echo "=== Optimization Complete ==="
---
# Cost monitoring CronJob
apiVersion: batch/v1
kind: CronJob
metadata:
  name: storage-cost-monitor
spec:
  schedule: "0 8 * * 1"  # Weekly on Monday at 8 AM
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          serviceAccountName: storage-monitor
          containers:
          - name: cost-analyzer
            image: bitnami/kubectl:latest
            command: ["/bin/bash", "/scripts/analyze-storage-costs.sh"]
            volumeMounts:
            - name: cost-scripts
              mountPath: /scripts
          volumes:
          - name: cost-scripts
            configMap:
              name: cost-analysis-scripts
              defaultMode: 0755
```

### Automated Storage Lifecycle Management

```yaml
# Create file: storage-lifecycle-management.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: lifecycle-management-scripts
data:
  manage-storage-lifecycle.sh: |
    #!/bin/bash
    set -euo pipefail
    
    echo "=== Storage Lifecycle Management ==="
    echo "Started at: $(date)"
    
    # Configuration
    ARCHIVE_DAYS=90
    DELETE_DAYS=365
    BACKUP_RETENTION_DAYS=30
    
    # Archive old backup files
    archive_old_backups() {
        echo "Archiving backups older than $ARCHIVE_DAYS days..."
        
        find /backup-storage -name "*.sql.gz.enc" -mtime +$ARCHIVE_DAYS -type f | while read backup_file; do
            # Move to archive directory
            mkdir -p /backup-storage/archive/$(date +%Y/%m)
            mv "$backup_file" "/backup-storage/archive/$(date +%Y/%m)/"
            
            # Move corresponding checksum
            if [ -f "$backup_file.sha256" ]; then
                mv "$backup_file.sha256" "/backup-storage/archive/$(date +%Y/%m)/"
            fi
            
            echo "Archived: $(basename $backup_file)"
        done
    }
    
    # Delete very old archives
    cleanup_old_archives() {
        echo "Cleaning up archives older than $DELETE_DAYS days..."
        find /backup-storage/archive -type f -mtime +$DELETE_DAYS -delete
        
        # Remove empty directories
        find /backup-storage/archive -type d -empty -delete
    }
    
    # Compress log files
    compress_logs() {
        echo "Compressing log files..."
        find /app-data -name "*.log" -size +10M -mtime +7 | while read log_file; do
            if [ ! -f "$log_file.gz" ]; then
                gzip "$log_file"
                echo "Compressed: $log_file"
            fi
        done
    }
    
    # Clean temporary files
    cleanup_temp_files() {
        echo "Cleaning temporary files..."
        find /app-data -name "*.tmp" -mtime +1 -delete
        find /app-data -name "core.*" -mtime +7 -delete
        find /app-data -path "*/cache/*" -mtime +7 -delete
    }
    
    # Generate lifecycle report
    generate_report() {
        echo "=== Storage Lifecycle Report ==="
        echo "Report generated at: $(date)"
        
        echo "--- Backup Storage Usage ---"
        du -sh /backup-storage/{,archive/} 2>/dev/null || true
        
        echo "--- Application Data Usage ---"
        du -sh /app-data/* 2>/dev/null | head -10
        
        echo "--- Recent Cleanups ---"
        echo "Archived backups: $(find /backup-storage/archive -name "*.sql.gz.enc" -mtime -1 | wc -l)"
        echo "Compressed logs: $(find /app-data -name "*.log.gz" -mtime -1 | wc -l)"
        echo "Cleaned temp files: $(find /tmp -name "lifecycle-temp-*" -mtime -1 | wc -l)"
        
        echo "=== Report Complete ==="
    }
    
    # Execute lifecycle management
    archive_old_backups
    cleanup_old_archives  
    compress_logs
    cleanup_temp_files
    generate_report
    
    echo "=== Storage Lifecycle Management Complete ==="
---
# Storage lifecycle management CronJob
apiVersion: batch/v1
kind: CronJob
metadata:
  name: storage-lifecycle-manager
spec:
  schedule: "0 4 * * 0"  # Weekly on Sunday at 4 AM
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
          - name: lifecycle-manager
            image: busybox
            command: ["/bin/sh", "/scripts/manage-storage-lifecycle.sh"]
            volumeMounts:
            - name: lifecycle-scripts
              mountPath: /scripts
            - name: backup-storage
              mountPath: /backup-storage
            - name: app-data
              mountPath: /app-data
            resources:
              requests:
                memory: 64Mi
                cpu: 50m
              limits:
                memory: 128Mi
                cpu: 100m
          volumes:
          - name: lifecycle-scripts
            configMap:
              name: lifecycle-management-scripts
              defaultMode: 0755
          - name: backup-storage
            persistentVolumeClaim:
              claimName: backup-storage-pvc
          - name: app-data
            persistentVolumeClaim:
              claimName: app-data-pvc
```

---

## 7. Troubleshooting Complex Storage Issues

### Advanced Troubleshooting Tools

```yaml
# Create file: storage-troubleshooting-toolkit.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: troubleshooting-scripts
data:
  diagnose-storage-issues.sh: |
    #!/bin/bash
    
    ISSUE_TYPE="${1:-general}"
    NAMESPACE="${2:-default}"
    RESOURCE_NAME="${3:-}"
    
    echo "=== Storage Issue Diagnosis ==="
    echo "Issue Type: $ISSUE_TYPE"
    echo "Namespace: $NAMESPACE"
    echo "Resource: $RESOURCE_NAME"
    echo "Started at: $(date)"
    
    # General storage system health check
    general_diagnosis() {
        echo "--- General Storage Health ---"
        
        # Check storage classes
        echo "Available storage classes:"
        kubectl get storageclass
        
        # Check CSI drivers
        echo -e "\nCSI drivers:"
        kubectl get csidriver 2>/dev/null || echo "No CSI drivers found"
        
        # Check failed PVCs
        echo -e "\nFailed PVCs:"
        kubectl get pvc --all-namespaces | grep -v Bound || echo "No failed PVCs"
        
        # Check storage events
        echo -e "\nRecent storage events:"
        kubectl get events --all-namespaces --sort-by='.lastTimestamp' | grep -i "volume\|storage\|mount" | tail -10
    }
    
    # PVC-specific issues
    pvc_diagnosis() {
        local pvc_name="$1"
        
        echo "--- PVC Diagnosis: $pvc_name ---"
        
        # PVC details
        kubectl describe pvc "$pvc_name" -n "$NAMESPACE"
        
        # Associated PV
        pv_name=$(kubectl get pvc "$pvc_name" -n "$NAMESPACE" -o jsonpath='{.spec.volumeName}')
        if [ -n "$pv_name" ]; then
            echo -e "\nAssociated PV: $pv_name"
            kubectl describe pv "$pv_name"
        fi
        
        # Pods using this PVC
        echo -e "\nPods using this PVC:"
        kubectl get pods -n "$NAMESPACE" -o json | jq -r --arg pvc "$pvc_name" '
          .items[] |
          select(.spec.volumes[]?.persistentVolumeClaim.claimName == $pvc) |
          .metadata.name
        '
    }
    
    # Pod mounting issues
    pod_mount_diagnosis() {
        local pod_name="$1"
        
        echo "--- Pod Mount Diagnosis: $pod_name ---"
        
        # Pod details
        kubectl describe pod "$pod_name" -n "$NAMESPACE"
        
        # Check container logs
        echo -e "\nContainer logs:"
        kubectl logs "$pod_name" -n "$NAMESPACE" --tail=20
        
        # Check node events
        node_name=$(kubectl get pod "$pod_name" -n "$NAMESPACE" -o jsonpath='{.spec.nodeName}')
        if [ -n "$node_name" ]; then
            echo -e "\nNode events for $node_name:"
            kubectl get events --field-selector involvedObject.name="$node_name" --sort-by='.lastTimestamp' | tail -10
        fi
    }
    
    # Performance issues
    performance_diagnosis() {
        echo "--- Storage Performance Diagnosis ---"
        
        # Check I/O wait
        echo "System load and I/O wait:"
        uptime
        iostat -x 1 1 2>/dev/null || echo "iostat not available"
        
        # Check storage device stats
        echo -e "\nStorage device statistics:"
        cat /proc/diskstats | grep -E "(sd|nvme|xvd)" | head -5
        
        # Check mount points
        echo -e "\nMount point usage:"
        df -h | grep -E "(kubelet|docker|containerd)"
    }
    
    # Network storage issues
    network_storage_diagnosis() {
        echo "--- Network Storage Diagnosis ---"
        
        # Check NFS mounts
        echo "NFS mount status:"
        mount | grep nfs || echo "No NFS mounts found"
        
        # Check network connectivity to storage
        echo -e "\nNetwork connectivity tests:"
        # Add specific tests based on your storage backend
        
        # Check DNS resolution
        echo -e "\nDNS resolution test:"
        nslookup kubernetes.default.svc.cluster.local || echo "DNS test failed"
    }
    
    # Execute diagnosis based on issue type
    case "$ISSUE_TYPE" in
        "general")
            general_diagnosis
            ;;
        "pvc")
            if [ -z "$RESOURCE_NAME" ]; then
                echo "PVC name required for PVC diagnosis"
                exit 1
            fi
            pvc_diagnosis "$RESOURCE_NAME"
            ;;
        "pod")
            if [ -z "$RESOURCE_NAME" ]; then
                echo "Pod name required for pod diagnosis"
                exit 1
            fi
            pod_mount_diagnosis "$RESOURCE_NAME"
            ;;
        "performance")
            performance_diagnosis
            ;;
        "network")
            network_storage_diagnosis
            ;;
        *)
            echo "Unknown issue type: $ISSUE_TYPE"
            echo "Available types: general, pvc, pod, performance, network"
            exit 1
            ;;
    esac
    
    echo "=== Diagnosis Complete ==="
  
  fix-common-issues.sh: |
    #!/bin/bash
    set -euo pipefail
    
    FIX_TYPE="${1:-}"
    
    if [ -z "$FIX_TYPE" ]; then
        echo "Usage: $0 <fix-type>"
        echo "Available fixes:"
        echo "  pending-pvcs    - Attempt to resolve pending PVCs"
        echo "  node-cleanup    - Clean up node storage issues"
        echo "  restart-pods    - Restart pods with volume issues"
        echo "  csi-restart     - Restart CSI components"
        exit 1
    fi
    
    echo "=== Storage Issue Resolution ==="
    echo "Fix Type: $FIX_TYPE"
    echo "Started at: $(date)"
    
    case "$FIX_TYPE" in
        "pending-pvcs")
            echo "Attempting to resolve pending PVCs..."
            
            kubectl get pvc --all-namespaces | grep Pending | while read namespace pvc rest; do
                echo "Investigating pending PVC: $namespace/$pvc"
                kubectl describe pvc "$pvc" -n "$namespace"
                
                # Try to identify the issue
                error_msg=$(kubectl describe pvc "$pvc" -n "$namespace" | grep -A 5 "Events:" | tail -5)
                echo "Recent events: $error_msg"
            done
            ;;
            
        "node-cleanup")
            echo "Performing node storage cleanup..."
            
            # Clean up orphaned volumes (be very careful with this)
            echo "Checking for orphaned volumes..."
            find /var/lib/kubelet/pods -name "volumes" -type d 2>/dev/null | while read volume_dir; do
                pod_id=$(basename $(dirname "$volume_dir"))
                if ! kubectl get pod --all-namespaces -o jsonpath='{.items[*].metadata.uid}' | grep -q "$pod_id"; then
                    echo "Found orphaned volume directory: $volume_dir"
                    # Don't actually delete - just report
                fi
            done
            ;;
            
        "restart-pods")
            echo "Restarting pods with volume issues..."
            
            # Find pods with volume mount issues
            kubectl get pods --all-namespaces -o json | jq -r '
              .items[] |
              select(.status.containerStatuses[]?.state.waiting?.reason == "ContainerCreating") |
              "\(.metadata.namespace) \(.metadata.name)"
            ' | while read namespace pod; do
                echo "Restarting pod with volume issues: $namespace/$pod"
                kubectl delete pod "$pod" -n "$namespace" --grace-period=0
            done
            ;;
            
        "csi-restart")
            echo "Restarting CSI components..."
            
            # Restart CSI node driver pods
            kubectl get pods --all-namespaces | grep csi | while read namespace pod rest; do
                echo "Restarting CSI pod: $namespace/$pod"
                kubectl delete pod "$pod" -n "$namespace"
            done
            ;;
            
        *)
            echo "Unknown fix type: $FIX_TYPE"
            exit 1
            ;;
    esac
    
    echo "=== Issue Resolution Complete ==="
---
# Troubleshooting toolkit pod
apiVersion: v1
kind: Pod
metadata:
  name: storage-troubleshoot-toolkit
  labels:
    app: storage-troubleshoot
spec:
  serviceAccountName: storage-monitor
  containers:
  - name: toolkit
    image: ubuntu:20.04
    command: ["sleep", "86400"]
    env:
    - name: DEBIAN_FRONTEND
      value: noninteractive
    lifecycle:
      postStart:
        exec:
          command:
          - /bin/bash
          - -c
          - |
            apt-get update
            apt-get install -y curl wget jq bc iostat sysstat net-tools dnsutils
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
            chmod +x kubectl && mv kubectl /usr/local/bin/
    volumeMounts:
    - name: troubleshoot-scripts
      mountPath: /scripts
    - name: host-proc
      mountPath: /host/proc
      readOnly: true
    - name: host-sys
      mountPath: /host/sys
      readOnly: true
    securityContext:
      privileged: true
  volumes:
  - name: troubleshoot-scripts
    configMap:
      name: troubleshooting-scripts
      defaultMode: 0755
  - name: host-proc
    hostPath:
      path: /proc
  - name: host-sys
    hostPath:
      path: /sys
  restartPolicy: Never
```

---

## 8. Testing and Validation

### Comprehensive Testing Suite

```bash
# Create comprehensive test script for Unit 5
cat > test-unit5-complete.sh << 'EOF'
#!/bin/bash

echo "=== Unit 5 Comprehensive Testing ==="

# Test 1: Backup System Validation
echo "Test 1: Backup System Validation"
kubectl get cronjob database-backup backup-storage-pvc 2>/dev/null && echo "✓ Backup system deployed" || echo "✗ Backup system missing"

# Test 2: Disaster Recovery Readiness
echo -e "\nTest 2: Disaster Recovery Readiness"
kubectl get configmap dr-scripts 2>/dev/null && echo "✓ DR scripts available" || echo "✗ DR scripts missing"

# Test 3: Monitoring System Health
echo -e "\nTest 3: Monitoring System Health"
kubectl get servicemonitor storage-metrics 2>/dev/null && echo "✓ Storage monitoring configured" || echo "✗ Storage monitoring missing"

# Test 4: Performance Testing Capability
echo -e "\nTest 4: Performance Testing Capability"
kubectl get configmap performance-test-scripts 2>/dev/null && echo "✓ Performance tests available" || echo "✗ Performance tests missing"

# Test 5: Cost Management Tools
echo -e "\nTest 5: Cost Management Tools"
kubectl get cronjob storage-cost-monitor 2>/dev/null && echo "✓ Cost monitoring active" || echo "✗ Cost monitoring missing"

# Test 6: Troubleshooting Tools
echo -e "\nTest 6: Troubleshooting Tools"
kubectl get configmap troubleshooting-scripts 2>/dev/null && echo "✓ Troubleshooting toolkit ready" || echo "✗ Troubleshooting toolkit missing"

# Test 7: Storage Health Check
echo -e "\nTest 7: Storage Health Check"
PENDING_PVCS=$(kubectl get pvc --all-namespaces | grep Pending | wc -l)
echo "Pending PVCs: $PENDING_PVCS"
[ "$PENDING_PVCS" -eq 0 ] && echo "✓ No pending PVCs" || echo "⚠ $PENDING_PVCS pending PVCs found"

# Test 8: Backup Encryption Verification
echo -e "\nTest 8: Backup Encryption Verification"
if kubectl get secret backup-config >/dev/null 2>&1; then
    echo "✓ Backup encryption secrets configured"
else
    echo "✗ Backup encryption secrets missing"
fi

echo -e "\n=== Testing Complete ==="
EOF

chmod +x test-unit5-complete.sh
```

### Deploy and Validate All Components

```bash
# Deploy all Unit 5 components
echo "Deploying Unit 5 components..."

# Deploy backup assessment
kubectl apply -f backup-strategy-assessment.yaml

# Deploy backup systems
kubectl apply -f comprehensive-database-backup.yaml
kubectl apply -f application-data-backup.yaml

# Deploy disaster recovery
kubectl apply -f disaster-recovery-system.yaml
kubectl apply -f data-replication-setup.yaml

# Deploy monitoring
kubectl apply -f storage-monitoring-system.yaml
kubectl apply -f prometheus-storage-monitoring.yaml

# Deploy performance testing
kubectl apply -f storage-performance-tests.yaml

# Deploy cost management
kubectl apply -f storage-cost-management.yaml
kubectl apply -f storage-lifecycle-management.yaml

# Deploy troubleshooting tools
kubectl apply -f storage-troubleshooting-toolkit.yaml

# Wait for critical components
kubectl wait job/backup-assessment --for=condition=complete --timeout=120s
kubectl wait deployment/storage-metrics-exporter --for=condition=available --timeout=120s

# Run comprehensive tests
./test-unit5-complete.sh
```

---

## 9. Production Deployment Checklist

### Pre-Production Validation

```yaml
# Create file: production-readiness-checklist.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: production-readiness-checklist
data:
  checklist.md: |
    # Storage Production Readiness Checklist
    
    ## Backup and Recovery
    - [ ] Automated database backups scheduled and tested
    - [ ] Backup encryption implemented and keys secured
    - [ ] Backup restoration procedures documented and tested
    - [ ] Cross-region backup replication configured
    - [ ] Backup retention policies defined and automated
    - [ ] Recovery time objectives (RTO) and recovery point objectives (RPO) met
    
    ## Disaster Recovery
    - [ ] Disaster recovery plan documented and tested
    - [ ] Failover procedures automated where possible
    - [ ] Data replication to DR site configured
    - [ ] DR testing schedule established
    - [ ] Failback procedures tested
    - [ ] Communication plan for DR events
    
    ## Monitoring and Alerting
    - [ ] Storage capacity monitoring implemented
    - [ ] Performance monitoring and alerting active
    - [ ] Backup success/failure alerting configured
    - [ ] Storage health checks automated
    - [ ] Dashboard for storage metrics available
    - [ ] On-call procedures for storage issues defined
    
    ## Cost Management
    - [ ] Storage cost tracking implemented
    - [ ] Cost optimization strategies identified
    - [ ] Storage lifecycle policies automated
    - [ ] Regular cost review process established
    - [ ] Unused resource cleanup automated
    
    ## Security and Compliance
    - [ ] Data encryption at rest implemented
    - [ ] Access controls properly configured
    - [ ] Audit logging enabled for storage operations
    - [ ] Compliance requirements met (GDPR, HIPAA, etc.)
    - [ ] Data retention policies implemented
    - [ ] Security scanning of storage configurations
    
    ## Performance and Scalability
    - [ ] Performance baselines established
    - [ ] Storage capacity planning completed
    - [ ] Auto-scaling policies configured where applicable
    - [ ] Performance testing completed
    - [ ] Bottleneck identification and remediation
    
    ## Operational Procedures
    - [ ] Storage operations runbooks created
    - [ ] Troubleshooting procedures documented
    - [ ] Change management process for storage
    - [ ] Storage provisioning workflows automated
    - [ ] Capacity management procedures defined
    - [ ] Incident response procedures tested
---
apiVersion: batch/v1
kind: Job
metadata:
  name: production-readiness-check
spec:
  template:
    spec:
      serviceAccountName: storage-monitor
      containers:
      - name: readiness-checker
        image: bitnami/kubectl:latest
        command:
        - /bin/bash
        - -c
        - |
          echo "=== Production Readiness Assessment ==="
          
          # Check backup systems
          echo "Backup Systems:"
          kubectl get cronjob | grep backup | wc -l | xargs echo "  Backup jobs:"
          
          # Check monitoring
          echo "Monitoring:"
          kubectl get servicemonitor | wc -l | xargs echo "  Service monitors:"
          
          # Check storage classes
          echo "Storage Configuration:"
          kubectl get storageclass | wc -l | xargs echo "  Storage classes:"
          
          # Check PVC health
          echo "PVC Health:"
          kubectl get pvc --all-namespaces | grep -v Bound | wc -l | xargs echo "  Non-bound PVCs:"
          
          # Check disaster recovery
          echo "Disaster Recovery:"
          kubectl get configmap dr-scripts >/dev/null 2>&1 && echo "  ✓ DR scripts configured" || echo "  ✗ DR scripts missing"
          
          echo "=== Assessment Complete ==="
        volumeMounts:
        - name: checklist
          mountPath: /checklist
      volumes:
      - name: checklist
        configMap:
          name: production-readiness-checklist
      restartPolicy: Never
```

---

## 10. Summary and Best Practices

### Key Concepts Mastered

| Component | Implementation | Production Impact |
|-----------|----------------|------------------|
| **Backup Strategy** | Automated, encrypted, multi-tier backups | Data protection and compliance |
| **Disaster Recovery** | Cross-region replication and failover | Business continuity |
| **Monitoring** | Comprehensive metrics and alerting | Proactive issue resolution |
| **Performance Optimization** | Benchmarking and tuning | Application responsiveness |
| **Cost Management** | Usage analysis and optimization | Cost control |
| **Troubleshooting** | Systematic diagnosis and resolution | Operational efficiency |

### Production-Ready Architecture

```yaml
# Create file: production-storage-architecture.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: production-architecture-guide
data:
  architecture-overview.md: |
    # Production Storage Architecture
    
    ## Multi-Tier Storage Strategy
    
    ### Tier 1: Critical Data (Databases)
    - Premium SSD storage classes
    - Cross-zone replication
    - Continuous backups with encryption
    - Sub-second RTO/RPO requirements
    
    ### Tier 2: Application Data
    - Standard SSD storage classes
    - Daily encrypted backups
    - Regional availability
    - Minute-level RTO/RPO
    
    ### Tier 3: Log and Cache Data  
    - General purpose storage classes
    - Weekly backups
    - Single zone acceptable
    - Hour-level RTO/RPO
    
    ### Tier 4: Archive and Backup
    - Cold storage classes
    - Long-term retention
    - Cost-optimized
    - Day-level RTO/RPO
    
    ## Implementation Pattern
    
    ```yaml
    # Production StatefulSet with full backup/monitoring
    apiVersion: apps/v1
    kind: StatefulSet
    metadata:
      name: production-database
      labels:
        tier: critical
        backup: required
        monitoring: enabled
    spec:
      serviceName: production-db
      replicas: 3
      selector:
        matchLabels:
          app: production-database
      template:
        metadata:
          labels:
            app: production-database
          annotations:
            backup.schedule: "0 */6 * * *"
            monitoring.enabled: "true"
        spec:
          securityContext:
            runAsNonRoot: true
            fsGroup: 999
          containers:
          - name: database
            image: postgres:14
            # Full production configuration
            resources:
              requests:
                memory: 2Gi
                cpu: 1000m
              limits:
                memory: 4Gi
                cpu: 2000m
      volumeClaimTemplates:
      - metadata:
          name: database-storage
          labels:
            tier: critical
            backup: required
        spec:
          accessModes: [ReadWriteOnce]
          storageClassName: premium-encrypted-replicated
          resources:
            requests:
              storage: 500Gi
    ```
```

---

## 11. Cleanup

```bash
# Comprehensive cleanup of Unit 5 resources
echo "Cleaning up Unit 5 resources..."

# Delete jobs and cronjobs
kubectl delete job backup-assessment production-readiness-check storage-performance-test 2>/dev/null || true
kubectl delete cronjob database-backup application-backup dr-health-check storage-cost-monitor storage-lifecycle-manager 2>/dev/null || true

# Delete deployments and daemonsets
kubectl delete deployment data-replication-service storage-metrics-exporter 2>/dev/null || true
kubectl delete daemonset storage-node-monitor 2>/dev/null || true

# Delete pods
kubectl delete pod storage-troubleshoot-toolkit 2>/dev/null || true

# Delete services and service monitors
kubectl delete service storage-metrics-service 2>/dev/null || true
kubectl delete servicemonitor storage-metrics 2>/dev/null || true

# Delete PVCs
kubectl delete pvc backup-storage-pvc replication-storage-pvc performance-test-pvc app-data-pvc 2>/dev/null || true

# Delete secrets and configmaps
kubectl delete secret backup-config 2>/dev/null || true
kubectl delete configmap backup-assessment-tool backup-scripts app-backup-scripts dr-scripts 2>/dev/null || true
kubectl delete configmap storage-monitoring-scripts prometheus-storage-monitoring grafana-storage-dashboard 2>/dev/null || true
kubectl delete configmap performance-test-scripts storage-optimization-guide cost-analysis-scripts 2>/dev/null || true
kubectl delete configmap lifecycle-management-scripts troubleshooting-scripts production-readiness-checklist 2>/dev/null || true
kubectl delete configmap production-architecture-guide 2>/dev/null || true

# Delete RBAC resources specific to Unit 5
kubectl delete clusterrolebinding storage-monitor 2>/dev/null || true
kubectl delete clusterrole storage-monitor 2>/dev/null || true
kubectl delete serviceaccount storage-monitor 2>/dev/null || true

# Clean up files
rm -f backup-strategy-assessment.yaml comprehensive-database-backup.yaml application-data-backup.yaml
rm -f disaster-recovery-system.yaml data-replication-setup.yaml
rm -f storage-monitoring-system.yaml prometheus-storage-monitoring.yaml grafana-storage-dashboard.yaml
rm -f storage-performance-tests.yaml storage-optimization.yaml
rm -f storage-cost-management.yaml storage-lifecycle-management.yaml
rm -f storage-troubleshooting-toolkit.yaml production-readiness-checklist.yaml
rm -f production-storage-architecture.yaml test-unit5-complete.sh

echo "Unit 5 cleanup complete!"
```

---

## Next Steps

**Congratulations!** You've completed a comprehensive journey through Kubernetes persistent storage, from basic concepts to production-ready implementations.

### What You've Accomplished

1. **Unit 1**: Understood the fundamental storage problem in containers
2. **Unit 2**: Mastered dynamic provisioning with StorageClasses  
3. **Unit 3**: Implemented StatefulSets and complex access patterns
4. **Unit 4**: Secured storage with encryption and access controls
5. **Unit 5**: Built production-grade backup, monitoring, and optimization systems

### Advanced Topics for Further Learning

- **Service Mesh Integration**: Integrating storage with Istio/Linkerd for advanced security
- **Multi-Cloud Storage**: Implementing storage that spans multiple cloud providers
- **Container Storage Interface (CSI) Development**: Building custom storage drivers
- **Storage Operator Development**: Creating Kubernetes operators for storage management
- **Advanced Disaster Recovery**: Implementing zero-downtime failover strategies

### Production Implementation Strategy

1. **Start Small**: Begin with non-critical workloads to gain experience
2. **Implement Security First**: Always prioritize encryption and access controls
3. **Plan for Scale**: Design storage architecture that can grow with your needs
4. **Automate Everything**: Backup, monitoring, and lifecycle management should be automated
5. **Test Regularly**: Disaster recovery and backup restoration must be tested frequently
6. **Monitor Continuously**: Proactive monitoring prevents issues before they impact users

The storage patterns and practices you've learned form the foundation for running production Kubernetes workloads with confidence, knowing your data is protected, performant, and cost-effective.### Prometheus-based Storage Metrics

```yaml
# Create file: prometheus-storage-monitoring.yaml
apiVersion: v1
kind: ServiceMonitor
metadata:
  name: storage-metrics
  labels:
    app: storage-monitoring
spec:
  selector:
    matchLabels:
      app: storage-exporter
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: storage-metrics-exporter
spec:
  replicas: 1
  selector:
    matchLabels:
      app: storage-exporter
  template:
    metadata:
      labels:
        app: storage-exporter
    spec:
      serviceAccountName: storage-monitor
      containers:
      - name: exporter
        image: prom/node-exporter:latest
        ports:
        - containerPort: 9100
          name: metrics
        args:
        - '--path.procfs=/host/proc'
        - '--path.sysfs=/host/sys'
        - '--collector.filesystem.ignored-mount-points=^/(dev|proc|sys|var/lib/docker/.+)($|/)'
        - '--collector.filesystem.ignored-fs-types=^(autofs|binfmt_misc|cgroup|configfs|debugfs|devpts|devtmpfs|fusectl|hugetlbfs|mqueue|overlay|proc|procfs|pstore|rpc_pipefs|securityfs|sysfs|tracefs)# Unit 5: Backup, Disaster Recovery, and Storage Monitoring

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
        volumeMounts:
        - name: proc
          mountPath: /host/proc
          readOnly: true
        - name: sys
          mountPath: /host/sys
          readOnly: true
        - name: rootfs
          mountPath: /rootfs
          readOnly: true
        resources:
          requests:
            memory: 64Mi
            cpu: 50m
          limits:
            memory: 128Mi
            cpu: 100m
      - name: custom-storage-exporter
        image: busybox
        command:
        - /bin/sh
        - -c
        - |
          # Simple custom metrics exporter for storage
          while true; do
            cat > /tmp/storage_metrics.prom << EOF
          # HELP kubernetes_storage_pvc_total Total number of PVCs
          # TYPE kubernetes_storage_pvc_total gauge
          kubernetes_storage_pvc_total $(kubectl get pvc --all-namespaces --no-headers | wc -l)
          
          # HELP kubernetes_storage_pvc_pending Number of pending PVCs  
          # TYPE kubernetes_storage_pvc_pending gauge
          kubernetes_storage_pvc_pending $(kubectl get pvc --all-namespaces --no-headers | grep Pending | wc -l)
          
          # HELP kubernetes_storage_pv_available Number of available PVs
          # TYPE kubernetes_storage_pv_available gauge
          kubernetes_storage_pv_available $(kubectl get pv --no-headers | grep Available | wc -l)
          EOF
            
            # Serve metrics on port 8080
            while true; do
              echo -e "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\n$(cat /tmp/storage_metrics.prom)" | nc -l -p 8080 -q 1 2>/dev/null || true
            done &
            
            sleep 60
          done
        ports:
        - containerPort: 8080
          name: custom-metrics
      volumes:
      - name: proc
        hostPath:
          path: /proc
      - name: sys
        hostPath:
          path: /sys
      - name: rootfs
        hostPath:
          path: /
---
apiVersion: v1
kind: Service
metadata:
  name: storage-metrics-service
  labels:
    app: storage-exporter
spec:
  selector:
    app: storage-exporter
  ports:
  - port: 9100
    name: metrics
    targetPort: 9100
  - port: 8080
    name: custom-metrics
    targetPort: 8080
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: storage-monitor
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: storage-monitor
rules:
- apiGroups: [""]
  resources: ["persistentvolumes", "persistentvolumeclaims", "pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["storage.k8s.io"]
  resources: ["storageclasses"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: storage-monitor
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: storage-monitor
subjects:
- kind: ServiceAccount
  name: storage-monitor
  namespace: default
```

### Grafana Dashboard Configuration

```yaml
# Create file: grafana-storage-dashboard.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: storage-dashboard
  labels:
    grafana_dashboard: "1"
data:
  storage-overview.json: |
    {
      "dashboard": {
        "id": null,
        "title": "Kubernetes Storage Overview",
        "tags": ["kubernetes", "storage"],
        "timezone": "browser",
        "panels": [
          {
            "title": "PVC Status Overview",
            "type": "stat",
            "targets": [
              {
                "expr# Unit 5: Backup, Disaster Recovery, and Storage Monitoring

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