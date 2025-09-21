# Performance and Optimization

These advanced commands help you analyze performance bottlenecks, optimize resource usage, and maintain cluster efficiency at scale.

## Performance Analysis and Metrics Collection
```bash
# Resource usage monitoring and trends
kubectl top nodes --sort-by=memory --no-headers           # Memory usage without headers for parsing
kubectl top nodes --sort-by=cpu --no-headers              # CPU usage for automation scripts
kubectl top pods --all-namespaces --sort-by=memory | head -20  # Top memory consumers cluster-wide
kubectl top pods --all-namespaces --sort-by=cpu | head -20     # Top CPU consumers cluster-wide
kubectl top pods --containers --all-namespaces             # Per-container resource usage

# Advanced performance metrics collection
kubectl get --raw /api/v1/nodes/<node-name>/proxy/metrics/cadvisor | grep container_cpu_usage_seconds_total  # Raw CPU metrics
kubectl get --raw /api/v1/nodes/<node-name>/proxy/stats/summary  # Node summary statistics
kubectl get --raw /metrics | grep -E "(apiserver|etcd|kubelet)"  # Control plane metrics
kubectl get --raw /api/v1/nodes/<node-name>/proxy/metrics/resource  # Node resource metrics

# Historical and trend analysis
kubectl top pods --all-namespaces --containers | grep -v "0m.*0Mi" | sort -k4 -nr  # Active containers by memory
kubectl top nodes | awk 'NR>1 {cpu+=$3; mem+=$5} END {print "Cluster total approx: CPU " cpu "% Memory " mem "%"}'  # Rough cluster totals

# Pod performance analysis with custom metrics
kubectl get pods -o custom-columns=NAME:.metadata.name,CPU-REQ:.spec.containers[0].resources.requests.cpu,MEM-REQ:.spec.containers[0].resources.requests.memory,CPU-LIM:.spec.containers[0].resources.limits.cpu,MEM-LIM:.spec.containers[0].resources.limits.memory | grep -v "<none>"
kubectl top pods --sort-by=memory | head -10 | while read name cpu mem; do kubectl describe pod $name | grep -A 5 "Limits\|Requests"; done

# Network performance analysis
kubectl get services -o custom-columns=NAME:.metadata.name,TYPE:.spec.type,ENDPOINTS:.status.loadBalancer.ingress[*].ip | grep LoadBalancer
kubectl get endpoints --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,ADDRESSES:.subsets[*].addresses[*].ip,PORTS:.subsets[*].ports[*].port
kubectl describe endpoints <service-name> | grep -A 10 "Addresses"  # Service endpoint health
```

## Scaling Analysis and Optimization
```bash
# Horizontal Pod Autoscaler (HPA) performance analysis
kubectl get hpa -o custom-columns=NAME:.metadata.name,TARGETS:.spec.metrics[*].resource.name,MIN:.spec.minReplicas,MAX:.spec.maxReplicas,CURRENT:.status.currentReplicas,TARGET:.status.currentMetrics[*].resource.current.averageUtilization
kubectl describe hpa <hpa-name> | grep -A 10 "Metrics"            # Current vs target metrics
kubectl get hpa <hpa-name> -o jsonpath='{.status.conditions}'     # HPA scaling conditions

# Advanced HPA monitoring and tuning
kubectl get events --field-selector involvedObject.kind=HorizontalPodAutoscaler  # HPA scaling events
kubectl get hpa -o json | jq '.items[] | {name: .metadata.name, current_replicas: .status.currentReplicas, desired_replicas: .status.desiredReplicas, metrics: .status.currentMetrics}'

# Vertical Pod Autoscaler (VPA) analysis (if installed)
kubectl get vpa -o custom-columns=NAME:.metadata.name,MODE:.spec.updatePolicy.updateMode,TARGET:.spec.targetRef.name,CPU-REQ:.status.recommendation.containerRecommendations[0].target.cpu,MEM-REQ:.status.recommendation.containerRecommendations[0].target.memory
kubectl describe vpa <vpa-name> | grep -A 20 "Container Recommendations"  # Resource recommendations

# Cluster Autoscaler analysis
kubectl get nodes -l node.kubernetes.io/instance-type -o custom-columns=NAME:.metadata.name,INSTANCE-TYPE:.metadata.labels.node\.kubernetes\.io/instance-type,ZONE:.metadata.labels.topology\.kubernetes\.io/zone
kubectl get pods --all-namespaces --field-selector=status.phase=Pending -o custom-columns=NAME:.metadata.name,NAMESPACE:.metadata.namespace,NODE:.spec.nodeName,REASON:.status.conditions[?(@.type==\"PodScheduled\")].message
kubectl describe nodes | grep -A 5 "Taints" | grep -v "^--$"      # Node taints affecting scheduling

# Resource utilization efficiency
kubectl get deployments --all-namespaces -o json | jq '.items[] | select(.spec.replicas > (.status.readyReplicas // 0)) | {namespace: .metadata.namespace, name: .metadata.name, desired: .spec.replicas, ready: .status.readyReplicas}'
```

## Resource Optimization and Right-Sizing
```bash
# Resource waste identification
kubectl get pods --all-namespaces -o json | \
  jq '.items[] | select(.spec.containers[0].resources.requests == null) | "\(.metadata.namespace)/\(.metadata.name) has no resource requests"'

# Over-provisioned resource detection
kubectl get pods --all-namespaces -o json | \
  jq '.items[] | select(.spec.containers[0].resources.limits.cpu and .spec.containers[0].resources.requests.cpu) | select((.spec.containers[0].resources.limits.cpu | rtrimstr("m") | tonumber) > ((.spec.containers[0].resources.requests.cpu | rtrimstr("m") | tonumber) * 2)) | "\(.metadata.namespace)/\(.metadata.name) has high CPU limit/request ratio"'

# QoS class optimization analysis
kubectl get pods --all-namespaces --field-selector=status.qosClass=BestEffort -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,CPU-REQ:.spec.containers[0].resources.requests.cpu,MEM-REQ:.spec.containers[0].resources.requests.memory
kubectl get pods --all-namespaces -o json | jq '[.items[] | {namespace: .metadata.namespace, name: .metadata.name, qos: .status.qosClass}] | group_by(.qos) | map({qos: .[0].qos, count: length})'

# Node resource utilization analysis
kubectl describe nodes | grep -A 20 "Allocated resources" | grep -E "(Resource|Requests|Limits)" | awk '/Resource/{node=$2} /cpu/{cpu=$2" "$3} /memory/{mem=$2" "$3; print node ": CPU " cpu " Memory " mem}'
kubectl get nodes -o json | jq '.items[] | {name: .metadata.name, allocatable_cpu: .status.allocatable.cpu, allocatable_memory: .status.allocatable.memory, capacity_cpu: .status.capacity.cpu, capacity_memory: .status.capacity.memory}'

# Storage optimization
kubectl get pvc --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,SIZE:.spec.resources.requests.storage,USED:.status.capacity.storage,STORAGECLASS:.spec.storageClassName
kubectl get pv -o json | jq '.items[] | select(.status.phase == "Available") | {name: .metadata.name, capacity: .spec.capacity.storage, policy: .spec.persistentVolumeReclaimPolicy}'
```

## Performance Monitoring Scripts and Automation
```bash
# Create comprehensive performance monitoring script
cat > performance-monitor.sh << 'EOF'
#!/bin/bash
set -euo pipefail

echo "=== Kubernetes Performance Monitor $(date) ==="

echo -e "\n1. Node Resource Utilization:"
kubectl top nodes --no-headers | while read node cpu cpu_pct mem mem_pct; do
  cpu_val=$(echo $cpu_pct | sed 's/%//')
  mem_val=$(echo $mem_pct | sed 's/%//')
  
  if (( $(echo "$cpu_val > 80" | bc -l) )); then
    echo "  🔴 $node: CPU ${cpu_pct} (HIGH)"
  elif (( $(echo "$cpu_val > 60" | bc -l) )); then
    echo "  🟡 $node: CPU ${cpu_pct} (MEDIUM)"
  else
    echo "  🟢 $node: CPU ${cpu_pct}"
  fi
done

echo -e "\n2. Top Resource Consumers:"
echo "  CPU:"
kubectl top pods --all-namespaces --sort-by=cpu --no-headers | head -5 | while read ns name cpu mem; do
  echo "    $ns/$name: ${cpu}"
done

echo "  Memory:"
kubectl top pods --all-namespaces --sort-by=memory --no-headers | head -5 | while read ns name cpu mem; do
  echo "    $ns/$name: ${mem}"
done

echo -e "\n3. HPA Status:"
if kubectl get hpa --all-namespaces --no-headers 2>/dev/null | wc -l | grep -q "^0$"; then
  echo "  No HPAs configured"
else
  kubectl get hpa --all-namespaces --no-headers | while read ns name ref min max replicas target; do
    echo "    $ns/$name: ${replicas} replicas (${min}-${max})"
  done
fi

echo -e "\n4. Resource Requests vs Limits:"
pods_no_requests=$(kubectl get pods --all-namespaces -o json | jq '[.items[] | select(.spec.containers[0].resources.requests == null)] | length')
echo "  Pods without resource requests: $pods_no_requests"

echo -e "\n5. Pod Distribution:"
echo "  Pods per node:"
kubectl get pods --all-namespaces -o wide --no-headers | awk '{print $8}' | sort | uniq -c | sort -nr | head -10

echo -e "\nPerformance monitoring completed."
EOF
chmod +x performance-monitor.sh

# Resource optimization recommendation script
cat > optimize-resources.sh << 'EOF'
#!/bin/bash
set -euo pipefail

echo "=== Resource Optimization Recommendations ==="

echo -e "\n1. Pods without resource requests:"
kubectl get pods --all-namespaces -o json | \
  jq -r '.items[] | select(.spec.containers[0].resources.requests == null) | "\(.metadata.namespace)/\(.metadata.name)"' | \
  head -10

echo -e "\n2. Best Effort QoS pods (potential candidates for resource requests):"
kubectl get pods --all-namespaces --field-selector=status.qosClass=BestEffort -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name --no-headers | head -10

echo -e "\n3. Nodes with high resource allocation:"
kubectl describe nodes | grep -A 20 "Allocated resources" | \
  awk '/Node:/{node=$2} /cpu.*[8-9][0-9]%|cpu.*100%/{print node " has high CPU allocation: " $0}' | \
  head -5

echo -e "\n4. Underutilized LoadBalancer services:"
kubectl get services --all-namespaces --field-selector spec.type=LoadBalancer -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,EXTERNAL-IP:.status.loadBalancer.ingress[0].ip --no-headers | \
  while read ns name ip; do
    endpoint_count=$(kubectl get endpoints $name -n $ns -o jsonpath='{.subsets[*].addresses}' | wc -w)
    if [ "$endpoint_count" -eq 0 ]; then
      echo "  $ns/$name: No endpoints (consider cleanup)"
    fi
  done

echo -e "\n5. Large PVCs that might be oversized:"
kubectl get pvc --all-namespaces -o json | \
  jq -r '.items[] | select(.spec.resources.requests.storage | test("^[0-9]+[GT]i$")) | "\(.metadata.namespace)/\(.metadata.name): \(.spec.resources.requests.storage)"' | \
  head -10

echo -e "\nOptimization analysis completed."
EOF
chmod +x optimize-resources.sh

# Cluster efficiency report generator
cat > efficiency-report.sh << 'EOF'
#!/bin/bash
set -euo pipefail

OUTPUT_FILE="cluster-efficiency-$(date +%Y%m%d-%H%M).md"

cat > $OUTPUT_FILE << REPORT_EOF
# Cluster Efficiency Report - $(date)

## Executive Summary
- **Total Nodes**: $(kubectl get nodes --no-headers | wc -l)
- **Total Pods**: $(kubectl get pods --all-namespaces --no-headers | wc -l)
- **Running Pods**: $(kubectl get pods --all-namespaces --field-selector=status.phase=Running --no-headers | wc -l)
- **Failed Pods**: $(kubectl get pods --all-namespaces --field-selector=status.phase=Failed --no-headers | wc -l)

## Resource Utilization

### Node CPU/Memory Usage
\`\`\`
$(kubectl top nodes)
\`\`\`

### Top Resource Consumers
\`\`\`
$(kubectl top pods --all-namespaces --sort-by=memory | head -10)
\`\`\`

## Efficiency Metrics

### QoS Class Distribution
- **Guaranteed**: $(kubectl get pods --all-namespaces --field-selector=status.qosClass=Guaranteed --no-headers | wc -l) pods
- **Burstable**: $(kubectl get pods --all-namespaces --field-selector=status.qosClass=Burstable --no-headers | wc -l) pods  
- **BestEffort**: $(kubectl get pods --all-namespaces --field-selector=status.qosClass=BestEffort --no-headers | wc -l) pods

### Autoscaling Status
\`\`\`
$(kubectl get hpa --all-namespaces 2>/dev/null || echo "No HPAs configured")
\`\`\`

## Recommendations
1. Review pods without resource requests
2. Consider implementing HPA for variable workloads
3. Monitor and right-size resource allocations
4. Clean up failed/completed pods regularly

---
Generated: $(date)
REPORT_EOF

echo "Efficiency report generated: $OUTPUT_FILE"
EOF
chmod +x efficiency-report.sh
```