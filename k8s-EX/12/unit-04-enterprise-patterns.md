# Unit 4: Enterprise Storage Patterns

## Learning Objectives
- Design multi-cloud storage strategies
- Implement disaster recovery for persistent storage
- Optimize storage costs at enterprise scale
- Configure storage for compliance and security requirements
- Build monitoring and alerting for storage systems

## Prerequisites
- Completed Units 1-3
- Understanding of volume expansion and snapshots
- Experience with cloud storage classes
- Basic knowledge of enterprise requirements (compliance, DR, cost management)

## Theory: Enterprise Storage Challenges

Enterprise environments introduce complexity beyond basic storage provisioning:

### Multi-Cloud Considerations
- **Vendor lock-in avoidance**: Portable storage configurations
- **Cross-region replication**: Data availability across geographic locations
- **Hybrid cloud**: On-premises integration with cloud storage
- **Cost optimization**: Balancing performance, availability, and cost

### Compliance and Security
- **Data encryption**: At-rest and in-transit
- **Access controls**: Fine-grained permissions and audit trails
- **Data residency**: Regulatory requirements for data location
- **Retention policies**: Automated data lifecycle management

## Hands-On Lab 1: Multi-Cloud Storage Architecture

### Challenge Setup
You're designing storage for a financial services application that must:
- Run in multiple AWS regions for disaster recovery
- Comply with data residency requirements
- Maintain 99.99% availability
- Support rapid failover between regions

### Step 1: Region-Specific Storage Classes

```yaml
# primary-region-storage.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: primary-region-storage
  labels:
    region: us-east-1
    tier: primary
    compliance: financial-services
provisioner: ebs.csi.aws.com
parameters:
  type: io2
  iops: "20000"
  fsType: ext4
  encrypted: "true"
  kmsKeyId: "arn:aws:kms:us-east-1:123456789:key/primary-key"
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain
allowVolumeExpansion: true
allowedTopologies:
- matchLabelExpressions:
  - key: topology.ebs.csi.aws.com/zone
    values:
    - us-east-1a
    - us-east-1b
    - us-east-1c
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: dr-region-storage
  labels:
    region: us-west-2
    tier: disaster-recovery
    compliance: financial-services
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "10000"  # Lower IOPS for cost optimization in DR
  fsType: ext4
  encrypted: "true"
  kmsKeyId: "arn:aws:kms:us-west-2:123456789:key/dr-key"
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain
allowVolumeExpansion: true
allowedTopologies:
- matchLabelExpressions:
  - key: topology.ebs.csi.aws.com/zone
    values:
    - us-west-2a
    - us-west-2b
```

### Step 2: Automated Cross-Region Backup Strategy

```bash
#!/bin/bash
# cross-region-backup.sh - Enterprise backup automation

set -euo pipefail

# Configuration
PRIMARY_REGION="us-east-1"
DR_REGION="us-west-2"
RETENTION_DAYS=90
LOG_FILE="/var/log/cross-region-backup.log"

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Create cross-region snapshot
create_cross_region_snapshot() {
    local pvc_name=$1
    local namespace=${2:-default}
    local snapshot_name="xregion-$(echo $pvc_name | tr '/' '-')-$(date +%Y%m%d-%H%M%S)"
    
    log "Creating cross-region snapshot: $snapshot_name for PVC: $namespace/$pvc_name"
    
    # Create snapshot in primary region
    kubectl apply -f - <<EOF
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: $snapshot_name
  namespace: $namespace
  labels:
    backup-type: cross-region
    source-pvc: $pvc_name
    created-date: $(date +%Y%m%d)
spec:
  source:
    persistentVolumeClaimName: $pvc_name
EOF

    # Wait for snapshot to be ready
    kubectl wait --for=condition=ReadyToUse volumesnapshot/$snapshot_name -n $namespace --timeout=1800s
    
    # Copy snapshot to DR region (this would typically use cloud provider tools)
    log "Snapshot created successfully: $snapshot_name"
    
    # Schedule cleanup
    echo "$snapshot_name $namespace $(date -d "+$RETENTION_DAYS days" +%s)" >> /var/lib/snapshots-to-cleanup.txt
}

# Cleanup old snapshots
cleanup_old_snapshots() {
    log "Starting snapshot cleanup process"
    
    if [[ ! -f /var/lib/snapshots-to-cleanup.txt ]]; then
        log "No snapshots scheduled for cleanup"
        return
    fi
    
    local current_time=$(date +%s)
    local temp_file=$(mktemp)
    
    while read -r snapshot_name namespace cleanup_time; do
        if [[ $current_time -gt $cleanup_time ]]; then
            log "Cleaning up expired snapshot: $snapshot_name"
            kubectl delete volumesnapshot $snapshot_name -n $namespace --ignore-not-found=true
        else
            echo "$snapshot_name $namespace $cleanup_time" >> "$temp_file"
        fi
    done < /var/lib/snapshots-to-cleanup.txt
    
    mv "$temp_file" /var/lib/snapshots-to-cleanup.txt
}

# Monitor and alert on backup failures
monitor_backup_health() {
    log "Monitoring backup health"
    
    # Check for failed snapshots
    local failed_snapshots=$(kubectl get volumesnapshots --all-namespaces -o json | jq -r '.items[] | select(.status.error != null) | "\(.metadata.namespace)/\(.metadata.name)"')
    
    if [[ -n "$failed_snapshots" ]]; then
        log "ALERT: Failed snapshots detected: $failed_snapshots"
        # Send alert to monitoring system
        curl -X POST "$WEBHOOK_URL" -d "{\"alert\": \"Backup failure detected\", \"snapshots\": \"$failed_snapshots\"}"
    fi
    
    # Check snapshot age
    local old_snapshots=$(kubectl get volumesnapshots --all-namespaces -o json | jq -r --arg days "$RETENTION_DAYS" '.items[] | select(.metadata.labels."backup-type" == "cross-region") | select((now - (.metadata.creationTimestamp | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime)) > ($days | tonumber * 86400)) | "\(.metadata.namespace)/\(.metadata.name)"')
    
    if [[ -n "$old_snapshots" ]]; then
        log "WARNING: Old snapshots found that should be cleaned up: $old_snapshots"
    fi
}

# Main execution
main() {
    log "Starting cross-region backup process"
    
    # Find all PVCs marked for backup
    kubectl get pvc --all-namespaces -l backup-enabled=true -o json | jq -r '.items[] | "\(.metadata.name) \(.metadata.namespace)"' | while read -r pvc_name namespace; do
        create_cross_region_snapshot "$pvc_name" "$namespace"
    done
    
    cleanup_old_snapshots
    monitor_backup_health
    
    log "Cross-region backup process completed"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

### Step 3: Disaster Recovery Testing

Create a comprehensive DR test to validate your backup strategy:

```yaml
# dr-test-scenario.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: dr-test
  labels:
    purpose: disaster-recovery-test
---
# Primary application with data
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: primary-app
  namespace: dr-test
spec:
  serviceName: primary-app
  replicas: 1
  selector:
    matchLabels:
      app: primary-app
  template:
    metadata:
      labels:
        app: primary-app
    spec:
      containers:
      - name: app
        image: postgres:13
        env:
        - name: POSTGRES_DB
          value: testdb
        - name: POSTGRES_USER
          value: testuser
        - name: POSTGRES_PASSWORD
          value: testpass
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: data
      labels:
        backup-enabled: "true"
    spec:
      accessModes: [ReadWriteOnce]
      resources:
        requests:
          storage: 10Gi
      storageClassName: primary-region-storage
```

### DR Test Procedure:

1. **Data Generation Phase**:
```bash
# Generate test data
kubectl exec -n dr-test primary-app-0 -- psql -U testuser -d testdb -c "
CREATE TABLE test_data (
    id SERIAL PRIMARY KEY,
    data TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO test_data (data) 
SELECT 'Test data ' || generate_series(1, 10000);
"

# Verify data
kubectl exec -n dr-test primary-app-0 -- psql -U testuser -d testdb -c "SELECT COUNT(*) FROM test_data;"
```

2. **Snapshot Creation**:
```bash
# Create snapshot
kubectl apply -f - <<EOF
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: dr-test-snapshot
  namespace: dr-test
spec:
  source:
    persistentVolumeClaimName: data-primary-app-0
EOF
```

3. **Disaster Simulation**:
```bash
# Simulate disaster by deleting primary resources
kubectl delete statefulset primary-app -n dr-test
kubectl delete pvc data-primary-app-0 -n dr-test
```

4. **Recovery Process**:
```yaml
# dr-recovery.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: recovered-data
  namespace: dr-test
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 10Gi
  storageClassName: dr-region-storage
  dataSource:
    name: dr-test-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: recovered-app
  namespace: dr-test
spec:
  serviceName: recovered-app
  replicas: 1
  selector:
    matchLabels:
      app: recovered-app
  template:
    metadata:
      labels:
        app: recovered-app
    spec:
      containers:
      - name: app
        image: postgres:13
        env:
        - name: POSTGRES_DB
          value: testdb
        - name: POSTGRES_USER
          value: testuser
        - name: POSTGRES_PASSWORD
          value: testpass
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: recovered-data
```

5. **Recovery Validation**:
```bash
kubectl apply -f dr-recovery.yaml
kubectl wait --for=condition=Ready pod -l app=recovered-app -n dr-test --timeout=300s

# Verify data recovery
kubectl exec -n dr-test recovered-app-0 -- psql -U testuser -d testdb -c "SELECT COUNT(*) FROM test_data;"
```

**Analysis Questions**:
- How long did the complete DR process take?
- What was the data loss window (RPO)?
- How long was the service unavailable (RTO)?
- What could be optimized?

## Hands-On Lab 2: Cost Optimization at Scale

### Enterprise Cost Challenge
You manage storage for 500+ applications across multiple teams. Current monthly storage costs are $50,000 and growing. How do you optimize without impacting performance?

### Step 1: Storage Cost Analysis Tool

```bash
#!/bin/bash
# storage-cost-analyzer.sh - Analyze and optimize storage costs

set -euo pipefail

# Cost per GB per month for different storage types (example AWS prices)
declare -A STORAGE_COSTS=(
    ["gp2"]="0.10"
    ["gp3"]="0.08"
    ["io1"]="0.125"
    ["io2"]="0.125"
    ["st1"]="0.045"
    ["sc1"]="0.025"
)

# IOPS costs (per provisioned IOPS per month)
declare -A IOPS_COSTS=(
    ["gp3"]="0.005"
    ["io1"]="0.065"
    ["io2"]="0.065"
)

analyze_storage_costs() {
    echo "Storage Cost Analysis Report"
    echo "=========================="
    echo "Generated: $(date)"
    echo ""
    
    local total_cost=0
    local total_storage=0
    
    # Analyze by storage class
    echo "Cost by Storage Class:"
    echo "---------------------"
    
    kubectl get pvc --all-namespaces -o json | jq -r '
        .items[] | 
        [.metadata.namespace, .metadata.name, .spec.storageClassName, (.spec.resources.requests.storage // "0Gi")] | 
        @tsv
    ' | while IFS=\t' read -r namespace name storageclass size_str; do
        
        # Convert size to GB
        local size_gb=$(echo "$size_str" | sed 's/[^0-9]*//g')
        if [[ "$size_str" == *"Mi"* ]]; then
            size_gb=$((size_gb / 1024))
        elif [[ "$size_str" == *"Ti"* ]]; then
            size_gb=$((size_gb * 1024))
        fi
        
        # Get storage class details
        local provisioner=$(kubectl get storageclass "$storageclass" -o jsonpath='{.provisioner}' 2>/dev/null || echo "unknown")
        local volume_type=$(kubectl get storageclass "$storageclass" -o jsonpath='{.parameters.type}' 2>/dev/null || echo "gp2")
        
        # Calculate cost
        local storage_cost_per_gb=${STORAGE_COSTS[$volume_type]:-"0.10"}
        local monthly_storage_cost=$(echo "$size_gb * $storage_cost_per_gb" | bc -l)
        
        # Calculate IOPS cost if applicable
        local iops_cost=0
        if [[ -n "${IOPS_COSTS[$volume_type]:-}" ]]; then
            local provisioned_iops=$(kubectl get storageclass "$storageclass" -o jsonpath='{.parameters.iops}' 2>/dev/null || echo "0")
            if [[ "$provisioned_iops" != "0" ]]; then
                iops_cost=$(echo "$provisioned_iops * ${IOPS_COSTS[$volume_type]}" | bc -l)
            fi
        fi
        
        local total_monthly_cost=$(echo "$monthly_storage_cost + $iops_cost" | bc -l)
        
        printf "%-30s %-20s %-10s %8s GB  $%8.2f\n" "$namespace/$name" "$storageclass" "$volume_type" "$size_gb" "$total_monthly_cost"
        
        total_cost=$(echo "$total_cost + $total_monthly_cost" | bc -l)
        total_storage=$((total_storage + size_gb))
    done
    
    echo ""
    echo "Summary:"
    echo "--------"
    printf "Total Storage: %d GB\n" "$total_storage"
    printf "Estimated Monthly Cost: $%.2f\n" "$total_cost"
    echo ""
    
    # Optimization recommendations
    echo "Cost Optimization Recommendations:"
    echo "---------------------------------"
    
    # Find over-provisioned IOPS
    kubectl get storageclass -o json | jq -r '
        .items[] | 
        select(.parameters.iops != null) | 
        select((.parameters.iops | tonumber) > 10000) |
        "High IOPS allocation: " + .metadata.name + " (" + .parameters.iops + " IOPS)"
    '
    
    # Find old volume types
    kubectl get storageclass -o json | jq -r '
        .items[] | 
        select(.parameters.type == "gp2") |
        "Consider upgrading to gp3: " + .metadata.name
    '
    
    echo ""
    echo "Potential Annual Savings from gp2 -> gp3 migration: $(echo \"$total_cost * 0.2 * 12\" | bc -l)"
}

# Generate cost optimization recommendations
generate_optimization_plan() {
    echo "Storage Optimization Plan"
    echo "========================"
    
    # Identify unused PVCs
    echo "1. Unused PVCs (not attached to any pod):"
    kubectl get pvc --all-namespaces -o json | jq -r '
        .items[] | 
        select(.status.phase == "Bound") |
        "\(.metadata.namespace)/\(.metadata.name)"
    ' | while read -r pvc; do
        namespace=$(echo "$pvc" | cut -d'/' -f1)
        name=$(echo "$pvc" | cut -d'/' -f2)
        
        # Check if any pod uses this PVC
        if ! kubectl get pods -n "$namespace" -o json | jq -e --arg pvc "$name" '.items[].spec.volumes[]?.persistentVolumeClaim.claimName == $pvc' >/dev/null 2>&1; then
            echo "   Unused: $pvc"
        fi
    done
    
    echo ""
    echo "2. Over-provisioned Storage Classes:"
    kubectl get storageclass -o json | jq -r '
        .items[] |
        select(.parameters.iops != null) |
        select((.parameters.iops | tonumber) > 16000) |
        "   High IOPS: " + .metadata.name + " (" + .parameters.iops + " IOPS) - Consider workload analysis"
    '
    
    echo ""
    echo "3. Storage Classes Using Legacy Types:"
    kubectl get storageclass -o json | jq -r '
        .items[] |
        select(.parameters.type == "gp2" or .parameters.type == "io1") |
        "   Legacy type: " + .metadata.name + " (" + .parameters.type + ") - Upgrade to " + (if .parameters.type == "gp2" then "gp3" else "io2" end)
    '
}

# Main execution
main() {
    analyze_storage_costs
    echo ""
    generate_optimization_plan
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

### Step 2: Tiered Storage Strategy Implementation

Design storage classes for different performance tiers:

```yaml
# tiered-storage-classes.yaml
# Tier 1: High Performance (Critical Applications)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: tier1-critical
  labels:
    cost-tier: high
    performance-tier: maximum
    sla: 99.99
provisioner: ebs.csi.aws.com
parameters:
  type: io2
  iops: "20000"
  fsType: ext4
  encrypted: "true"
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain
allowVolumeExpansion: true
---
# Tier 2: Standard Performance (Production Applications)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: tier2-standard
  labels:
    cost-tier: medium
    performance-tier: high
    sla: 99.9
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
---
# Tier 3: Cost-Optimized (Development/Testing)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: tier3-economy
  labels:
    cost-tier: low
    performance-tier: standard
    sla: 99.0
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "3000"
  fsType: ext4
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
allowVolumeExpansion: true
---
# Tier 4: Archive Storage (Logs, Backups)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: tier4-archive
  labels:
    cost-tier: minimal
    performance-tier: basic
    sla: 95.0
provisioner: ebs.csi.aws.com
parameters:
  type: st1  # Throughput Optimized HDD
  fsType: ext4
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
allowVolumeExpansion: true
```

### Step 3: Automated Storage Right-Sizing

```bash
#!/bin/bash
# storage-rightsizing.sh - Automated storage optimization

set -euo pipefail

# Analyze actual storage usage vs allocated
analyze_storage_utilization() {
    echo "Storage Utilization Analysis"
    echo "==========================="
    
    kubectl get pods --all-namespaces -o json | jq -r '
        .items[] | 
        select(.spec.volumes != null) |
        select(.spec.volumes[].persistentVolumeClaim != null) |
        "\(.metadata.namespace) \(.metadata.name) \(.spec.volumes[].persistentVolumeClaim.claimName)"
    ' | while read -r namespace pod_name pvc_name; do
        
        # Get PVC allocated size
        local allocated_size=$(kubectl get pvc "$pvc_name" -n "$namespace" -o jsonpath='{.spec.resources.requests.storage}' 2>/dev/null || echo "0")
        
        # Get actual usage (requires metrics-server or custom monitoring)
        local used_size=$(kubectl exec -n "$namespace" "$pod_name" -- df -h 2>/dev/null | grep -E '/data|/var/lib' | awk '{print $3}' | head -1 || echo "N/A")
        
        if [[ "$used_size" != "N/A" && "$allocated_size" != "0" ]]; then
            echo "PVC: $namespace/$pvc_name | Allocated: $allocated_size | Used: $used_size"
            
            # Calculate utilization percentage
            local allocated_gb=$(echo "$allocated_size" | sed 's/[^0-9]*//g')
            local used_gb=$(echo "$used_size" | sed 's/[^0-9.]*//g' | cut -d'.' -f1)
            
            if [[ -n "$allocated_gb" && -n "$used_gb" && "$allocated_gb" -gt 0 ]]; then
                local utilization=$((used_gb * 100 / allocated_gb))
                
                if [[ "$utilization" -lt 20 ]]; then
                    echo "  WARNING: Low utilization ($utilization%) - Consider downsizing"
                elif [[ "$utilization" -gt 80 ]]; then
                    echo "  INFO: High utilization ($utilization%) - Monitor for potential expansion"
                fi
            fi
        fi
    done
}

# Generate rightsizing recommendations
generate_rightsizing_recommendations() {
    echo ""
    echo "Rightsizing Recommendations"
    echo "=========================="
    
    # Find PVCs that could be downsized
    echo "Candidates for downsizing:"
    # This would integrate with your monitoring system to get actual usage metrics
    echo "(Integrate with Prometheus/monitoring system for accurate usage data)"
    
    # Find PVCs that need expansion
    echo ""
    echo "Candidates for expansion:"
    echo "(Based on utilization > 80%)"
}

main() {
    analyze_storage_utilization
    generate_rightsizing_recommendations
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

## Mini-Project: Compliance and Security Framework

Design a comprehensive storage security framework for a healthcare application that must comply with HIPAA requirements:

### Requirements:
- All data must be encrypted at rest and in transit
- Access must be logged and auditable
- Data must be retained for 7 years
- Must support secure data deletion
- Multi-factor authentication for administrative access

### Your Implementation Challenge:

```yaml
# hipaa-compliant-storage.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: hipaa-compliant
  labels:
    compliance: hipaa
    security-level: high
  annotations:
    security.policy/encryption: "required"
    security.policy/audit-logging: "enabled"
    compliance.policy/data-retention: "7-years"
provisioner: ebs.csi.aws.com
parameters:
  # Your security parameters here
  type: gp3
  encrypted: "true"
  kmsKeyId: "arn:aws:kms:region:account:key/hipaa-key"
  # Add additional security parameters
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain  # Required for compliance
allowVolumeExpansion: true
```

Design considerations:
1. How do you implement secure key management?
2. What audit logging is required?
3. How do you handle secure data deletion?
4. What backup encryption standards apply?

## Advanced Troubleshooting Lab

### Complex Scenario: Performance Degradation Investigation

Your production database is experiencing performance issues. Storage metrics show high latency. How do you investigate and resolve?

### Investigation Framework:

```bash
#!/bin/bash
# storage-performance-investigator.sh

investigate_storage_performance() {
    echo "Storage Performance Investigation"
    echo "==============================="
    
    # 1. Check current IOPS utilization
    echo "1. Current IOPS Configuration:"
    kubectl get storageclass -o json | jq -r '
        .items[] |
        select(.parameters.type != null) |
        "\(.metadata.name): \(.parameters.type) - \(.parameters.iops // "baseline") IOPS"
    '
    
    # 2. Check for throttling events
    echo ""
    echo "2. Recent Storage Events:"
    kubectl get events --all-namespaces --sort-by='.lastTimestamp' | grep -i -E "(storage|volume|iops|throttl)" | tail -10
    
    # 3. Check PVC status and conditions
    echo ""
    echo "3. PVC Health Check:"
    kubectl get pvc --all-namespaces -o json | jq -r '
        .items[] |
        select(.status.conditions != null) |
        select(.status.conditions[].type == "FileSystemResizePending" or .status.conditions[].type == "Resizing") |
        "\(.metadata.namespace)/\(.metadata.name): \(.status.conditions[].message)"
    '
    
    # 4. Check for over-allocated resources
    echo ""
    echo "4. Resource Allocation Analysis:"
    kubectl top nodes | grep -E "(cpu|memory)"
}

# Performance optimization suggestions
suggest_performance_optimizations() {
    echo ""
    echo "Performance Optimization Suggestions"
    echo "==================================="
    
    echo "1. Consider upgrading to newer volume types (gp2 -> gp3, io1 -> io2)"
    echo "2. Review IOPS allocation vs actual usage"
    echo "3. Check if workloads can benefit from provisioned throughput"
    echo "4. Consider node placement and availability zone optimization"
}

main() {
    investigate_storage_performance
    suggest_performance_optimizations
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

## Capstone Project: Complete Enterprise Storage Solution

Design and implement a complete storage solution for a multi-tenant SaaS platform with these requirements:

### Requirements:
- **Multi-tenancy**: Isolated storage per customer
- **Performance tiers**: Different SLA levels
- **Compliance**: SOC2, GDPR compliance
- **Cost optimization**: Automated right-sizing
- **Disaster recovery**: Cross-region backup
- **Monitoring**: Comprehensive observability

### Deliverables:
1. Storage class hierarchy design
2. Automated backup and DR strategy
3. Cost monitoring and optimization system
4. Security and compliance framework
5. Performance monitoring and alerting
6. Runbook for common operations

This project should demonstrate mastery of all concepts from Units 1-4.

## Assessment Checklist
- [ ] Can design multi-cloud storage architectures
- [ ] Can implement comprehensive disaster recovery strategies
- [ ] Can optimize storage costs at enterprise scale
- [ ] Can design for compliance and security requirements
- [ ] Can troubleshoot complex storage performance issues
- [ ] Can build monitoring and automation for storage systems

## Next Steps
Unit 5 will cover automation, GitOps for storage, and integration with CI/CD pipelines. Consider:
- How do you manage storage configurations as code?
- What's your strategy for automated testing of storage configurations?
- How do you integrate storage provisioning with application deployment pipelines?