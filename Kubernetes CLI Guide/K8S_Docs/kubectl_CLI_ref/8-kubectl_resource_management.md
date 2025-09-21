# Resource Management and Monitoring

Effective resource management ensures optimal cluster performance and prevents resource exhaustion. These commands help you monitor, analyze, and optimize resource utilization.

## Resource Quota and Limit Management
```bash
# Resource quota operations and analysis
kubectl get resourcequotas --all-namespaces               # All resource quotas
kubectl get quota                                         # Shorthand for resourcequotas
kubectl describe resourcequota <quota-name>               # Detailed quota information
kubectl create quota <quota-name> --hard=pods=10,secrets=5,cpu=1000m,memory=2Gi  # Create resource quota
kubectl get resourcequota -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,PODS:.status.used.pods,CPU:.status.used.cpu,MEMORY:.status.used.memory

# Advanced quota analysis
kubectl get resourcequota -o json | jq '.items[] | {name: .metadata.name, namespace: .metadata.namespace, used: .status.used, hard: .spec.hard}'
kubectl get resourcequota --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,CPU-USED:.status.used.cpu,CPU-HARD:.spec.hard.cpu,MEMORY-USED:.status.used.memory,MEMORY-HARD:.spec.hard.memory

# Quota utilization monitoring
kubectl describe resourcequota <quota-name> | grep -E "(Used|Hard)"  # Usage summary
kubectl get pods -o custom-columns=NAME:.metadata.name,CPU-REQ:.spec.containers[0].resources.requests.cpu,MEM-REQ:.spec.containers[0].resources.requests.memory | grep -v "<none>"  # Pods with resource requests

# Limit range management and analysis
kubectl get limitranges --all-namespaces                  # All limit ranges
kubectl describe limitrange <limit-name>                  # Limit range details
kubectl create limitrange <limit-name> --max=cpu=500m,memory=1Gi --min=cpu=100m,memory=128Mi --default=cpu=200m,memory=256Mi
kubectl get limitrange -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,MAX-CPU:.spec.limits[0].max.cpu,MAX-MEM:.spec.limits[0].max.memory

# Resource constraint validation
kubectl get events --field-selector reason=LimitRangeViolation  # Limit range violations
kubectl get events --field-selector reason=ResourceQuotaExceeded  # Quota exceeded events
kubectl describe namespace <namespace> | grep -A 10 "Resource Limits"  # Namespace limits
```

## Node Resource Analysis and Capacity Planning
```bash
# Node capacity and resource allocation
kubectl describe nodes | grep -A 10 "Allocated resources" # Node resource allocation
kubectl top nodes --sort-by=memory                        # Node memory usage
kubectl top nodes --sort-by=cpu                          # Node CPU usage
kubectl describe node <node-name> | grep -E "(Capacity|Allocatable)"  # Node capacity info

# Advanced node resource analysis
kubectl get nodes -o custom-columns=NAME:.metadata.name,CAPACITY-CPU:.status.capacity.cpu,CAPACITY-MEMORY:.status.capacity.memory,ALLOCATABLE-CPU:.status.allocatable.cpu,ALLOCATABLE-MEMORY:.status.allocatable.memory
kubectl get nodes -o json | jq '.items[] | {name: .metadata.name, capacity: .status.capacity, allocatable: .status.allocatable}'

# Node resource utilization percentage
kubectl top nodes --no-headers | awk '{print $1 " CPU: " $3 " Memory: " $5}'  # Current usage percentages
kubectl describe nodes | grep -A 20 "Allocated resources" | grep -E "(cpu|memory)" | awk '{print $1 ": " $2 " (" $3 ")"}'  # Allocation details

# Pod resource distribution analysis
kubectl get pods --all-namespaces -o wide | awk '{print $8}' | sort | uniq -c  # Pods per node count
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' | sort | uniq -c  # Pod distribution
kubectl get pods --all-namespaces --field-selector spec.nodeName=<node-name> --no-headers | wc -l  # Pod count per node

# Resource pressure and node conditions
kubectl describe nodes | grep -A 5 "Conditions" | grep -E "(Ready|MemoryPressure|DiskPressure|PIDPressure)"  # Node conditions
kubectl get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[?(@.type==\"Ready\")].status,MEMORY-PRESSURE:.status.conditions[?(@.type==\"MemoryPressure\")].status,DISK-PRESSURE:.status.conditions[?(@.type==\"DiskPressure\")].status
```

## Cluster-Wide Resource Monitoring
```bash
# Comprehensive resource overview
kubectl top pods --all-namespaces --sort-by=memory | head -20    # Top memory consumers
kubectl top pods --all-namespaces --sort-by=cpu | head -20       # Top CPU consumers
kubectl get pods --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,CPU:.spec.containers[0].resources.requests.cpu,MEMORY:.spec.containers[0].resources.requests.memory

# Resource request vs limit analysis
kubectl get pods --all-namespaces -o custom-columns=NAME:.metadata.name,NAMESPACE:.metadata.namespace,CPU-REQ:.spec.containers[*].resources.requests.cpu,MEM-REQ:.spec.containers[*].resources.requests.memory,CPU-LIM:.spec.containers[*].resources.limits.cpu,MEM-LIM:.spec.containers[*].resources.limits.memory

# Quality of Service (QoS) analysis
kubectl get pods --all-namespaces -o custom-columns=NAME:.metadata.name,NAMESPACE:.metadata.namespace,QOS:.status.qosClass     # Pod QoS classes
kubectl get pods --all-namespaces --field-selector=status.qosClass=BestEffort                   # Best effort pods
kubectl get pods --all-namespaces --field-selector=status.qosClass=Guaranteed                   # Guaranteed pods
kubectl get pods --all-namespaces --field-selector=status.qosClass=Burstable                    # Burstable pods

# Resource efficiency calculations
kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.containers[0].resources.requests.cpu and .spec.containers[0].resources.limits.cpu) | "\(.metadata.namespace)/\(.metadata.name): CPU req/limit = \(.spec.containers[0].resources.requests.cpu)/\(.spec.containers[0].resources.limits.cpu)"'

# Namespace resource consumption summary
kubectl get pods --all-namespaces -o json | jq -r 'group_by(.metadata.namespace) | .[] | "\(.[0].metadata.namespace): \(length) pods"'
kubectl top pods --all-namespaces --no-headers | awk '{cpu+=$3; mem+=$4} END {print "Total CPU: " cpu "m, Total Memory: " mem "Mi"}'  # Rough totals
```

## Horizontal Pod Autoscaler (HPA) Management
```bash
# HPA creation and management
kubectl autoscale deployment <name> --cpu-percent=50 --min=1 --max=10    # CPU-based autoscaling
kubectl autoscale deployment <name> --memory-percent=70 --min=2 --max=8  # Memory-based autoscaling
kubectl create hpa <hpa-name> --cpu-percent=80 --memory-percent=80 --min=2 --max=15 --target-cpu-utilization-percentage=80
kubectl get hpa                                           # List autoscalers
kubectl get hpa -o wide                                   # Extended HPA information
kubectl describe hpa <hpa-name>                          # HPA details and current metrics

# Advanced HPA configuration and analysis
kubectl get hpa <hpa-name> -o yaml                        # Full HPA configuration
kubectl get hpa -o custom-columns=NAME:.metadata.name,TARGETS:.spec.targetCPUUtilizationPercentage,MIN:.spec.minReplicas,MAX:.spec.maxReplicas,CURRENT:.status.currentReplicas
kubectl patch hpa <hpa-name> -p '{"spec":{"maxReplicas":20}}'   # Update max replicas
kubectl patch hpa <hpa-name> -p '{"spec":{"targetCPUUtilizationPercentage":60}}'  # Update target CPU

# HPA status and metrics monitoring
kubectl get hpa <hpa-name> -o jsonpath='{.status.currentMetrics}'  # Current metrics
kubectl get hpa <hpa-name> -o jsonpath='{.status.conditions}'     # HPA conditions
kubectl describe hpa <hpa-name> | grep -A 10 "Metrics"            # Detailed metrics
kubectl get events --field-selector involvedObject.name=<hpa-name> # HPA scaling events

# Custom metrics HPA (if custom metrics API is available)
kubectl get hpa -o custom-columns=NAME:.metadata.name,METRICS:.spec.metrics[*].type,TARGET:.spec.metrics[*].resource.target.averageUtilization
kubectl describe hpa <hpa-name> | grep -A 5 "Metrics" | grep -E "(Resource|External|Pods|Object)"  # Metric types
```

## Vertical Pod Autoscaler (VPA) Operations
```bash
# VPA management (if VPA is installed)
kubectl get vpa                                          # List VPAs
kubectl get verticalpodautoscalers                       # Full name
kubectl describe vpa <vpa-name>                          # VPA recommendations
kubectl get vpa -o custom-columns=NAME:.metadata.name,MODE:.spec.updatePolicy.updateMode,TARGET:.spec.targetRef.name

# VPA recommendations analysis
kubectl get vpa <vpa-name> -o jsonpath='{.status.recommendation}'  # Resource recommendations
kubectl describe vpa <vpa-name> | grep -A 20 "Recommendation"     # Detailed recommendations
kubectl get pods -o custom-columns=NAME:.metadata.name,VPA-UPDATES:.metadata.annotations.vpaUpdater  # VPA-updated pods

# VPA policy configuration
kubectl patch vpa <vpa-name> -p '{"spec":{"updatePolicy":{"updateMode":"Auto"}}}'  # Enable auto-updates
kubectl patch vpa <vpa-name> -p '{"spec":{"updatePolicy":{"updateMode":"Off"}}}'   # Disable updates
kubectl get vpa -o custom-columns=NAME:.metadata.name,UPDATE-MODE:.spec.updatePolicy.updateMode,MIN-ALLOWED:.spec.resourcePolicy.containerPolicies[0].minAllowed
```

## Performance Monitoring and Optimization
```bash
# Advanced resource usage monitoring
kubectl top pods --use-protocol-buffers                   # More efficient resource queries
kubectl get --raw /metrics | grep -E "(cpu|memory)"      # Raw metrics from API server
kubectl get --raw /api/v1/nodes/<node-name>/proxy/metrics/cadvisor | grep container_cpu_usage_seconds_total  # Node-specific metrics

# Resource waste identification
kubectl get pods --all-namespaces -o custom-columns=NAME:.metadata.name,NAMESPACE:.metadata.namespace,CPU-REQ:.spec.containers[0].resources.requests.cpu,CPU-LIM:.spec.containers[0].resources.limits.cpu | grep -E "^[^[:space:]]+[[:space:]]+[^[:space:]]+[[:space:]]+<none>"  # Pods without CPU requests

# Efficiency analysis and recommendations
kubectl get pods --all-namespaces -o json | \
  jq '.items[] | select(.spec.containers[0].resources.requests.memory == null) | "\(.metadata.namespace)/\(.metadata.name) has no memory request"'

# Node efficiency and utilization calculations
kubectl describe nodes | grep -A 2 -B 2 "Allocated resources"    # Resource allocation summary
kubectl top nodes | awk 'NR>1 {print $1, "CPU:", $3, "Memory:", $5}'  # Node usage percentages
kubectl get nodes -o json | jq -r '.items[] | "\(.metadata.name): CPU \(.status.capacity.cpu) Memory \(.status.capacity.memory)"'  # Node capacities

# Cluster resource utilization trends
kubectl get pods --all-namespaces --field-selector=status.phase=Running -o json | \
  jq '[.items[] | select(.spec.containers[0].resources.requests.cpu)] | length' # Pods with CPU requests
kubectl get pods --all-namespaces --field-selector=status.phase=Running -o json | \
  jq '[.items[] | select(.spec.containers[0].resources.requests.memory)] | length' # Pods with memory requests

# Resource optimization recommendations
kubectl get deployments --all-namespaces -o json | \
  jq '.items[] | select(.spec.template.spec.containers[0].resources.requests.cpu == null) | "\(.metadata.namespace)/\(.metadata.name) deployment missing CPU requests"'
```

## Storage and Persistent Volume Management
```bash
# Persistent Volume (PV) and claim analysis
kubectl get pv,pvc                                        # All PVs and PVCs
kubectl get pv -o custom-columns=NAME:.metadata.name,CAPACITY:.spec.capacity.storage,ACCESS:.spec.accessModes,RECLAIM:.spec.persistentVolumeReclaimPolicy,STATUS:.status.phase,CLAIM:.spec.claimRef.name
kubectl get pvc -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,VOLUME:.spec.volumeName,CAPACITY:.status.capacity.storage,ACCESS:.spec.accessModes,STORAGECLASS:.spec.storageClassName

# Storage class analysis
kubectl get storageclass                                   # Available storage classes
kubectl get sc                                            # Shorthand
kubectl describe storageclass <sc-name>                   # Storage class details
kubectl get storageclass -o custom-columns=NAME:.metadata.name,PROVISIONER:.provisioner,RECLAIM:.reclaimPolicy,VOLUME-BINDING:.volumeBindingMode

# Storage usage and capacity monitoring
kubectl get pv -o json | jq '.items[] | {name: .metadata.name, capacity: .spec.capacity.storage, used: .status.phase}'
kubectl describe pvc <pvc-name> | grep -E "(Capacity|Used|Available)"  # PVC usage
kubectl get events --field-selector reason=VolumeResizeFailed          # Volume resize failures

# Storage performance and troubleshooting
kubectl describe pv <pv-name> | grep -A 5 "Source"        # PV source details
kubectl get events --field-selector reason=FailedMount    # Mount failures
kubectl get events --field-selector reason=VolumeFailedDelete  # Deletion failures
kubectl get pvc --field-selector=status.phase=Pending     # Pending PVCs
```

## Advanced Resource Monitoring Scripts
```bash
# Create comprehensive resource monitoring script
cat > resource-monitor.sh << 'EOF'
#!/bin/bash
echo "=== Cluster Resource Overview $(date) ==="
echo "Nodes:"
kubectl top nodes --no-headers | while read node cpu_pct cpu_abs mem_pct mem_abs; do
  echo "  $node: CPU ${cpu_pct} Memory ${mem_pct}"
done

echo -e "\nTop CPU Consumers:"
kubectl top pods --all-namespaces --sort-by=cpu --no-headers | head -5

echo -e "\nTop Memory Consumers:"
kubectl top pods --all-namespaces --sort-by=memory --no-headers | head -5

echo -e "\nResource Quota Status:"
kubectl get resourcequota --all-namespaces --no-headers | while read ns name; do
  echo "  $ns: $(kubectl describe resourcequota $name -n $ns | grep -E "Used.*Hard" | head -1)"
done

echo -e "\nPods without Resource Requests:"
kubectl get pods --all-namespaces -o json | \
  jq -r '.items[] | select(.spec.containers[0].resources.requests == null) | "\(.metadata.namespace)/\(.metadata.name)"' | head -10
EOF
chmod +x resource-monitor.sh

# Resource alert script
cat > resource-alerts.sh << 'EOF'
#!/bin/bash
echo "=== Resource Alerts $(date) ==="

# Check for high CPU nodes
kubectl top nodes --no-headers | awk '$3 > 80 {print "HIGH CPU: " $1 " at " $3}'

# Check for high memory nodes  
kubectl top nodes --no-headers | awk '$5 > 80 {print "HIGH MEMORY: " $1 " at " $5}'

# Check for failed pods
failed_pods=$(kubectl get pods --all-namespaces --field-selector=status.phase=Failed --no-headers | wc -l)
if [ $failed_pods -gt 0 ]; then
  echo "FAILED PODS: $failed_pods pods in failed state"
fi

# Check for pending pods
pending_pods=$(kubectl get pods --all-namespaces --field-selector=status.phase=Pending --no-headers | wc -l)
if [ $pending_pods -gt 0 ]; then
  echo "PENDING PODS: $pending_pods pods pending"
fi
EOF
chmod +x resource-alerts.sh
```