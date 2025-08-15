# 21. Advanced Tips
This section covers advanced `kubectl` techniques, performance optimization, and production best practices for managing Kubernetes clusters.

## 21.1 Advanced kubectl Techniques
Use advanced `kubectl` commands for efficient resource management and debugging.

```bash
# JSONPath queries
kubectl get pods -o jsonpath='{.items[*].metadata.name}'
kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalIP")].address}'

# Custom columns
kubectl get pods -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName,IP:.status.podIP
kubectl get deployments -o custom-columns=NAME:.metadata.name,REPLICAS:.spec.replicas,READY:.status.readyReplicas

# Field selectors
kubectl get pods --field-selector=status.phase=Running
kubectl get events --field-selector=type=Warning

# Label selectors
kubectl get pods -l 'environment in (production,staging)'
kubectl get pods -l 'app=web,version!=v1'

# Sort resources
kubectl get pods --sort-by=.metadata.creationTimestamp
kubectl get nodes --sort-by=.metadata.name

# Watch with custom output
kubectl get pods -w -o custom-columns=NAME:.metadata.name,STATUS:.status.phase

# Server-side apply
kubectl apply --server-side -f deployment.yaml

# Dry-run with diff
kubectl diff -f deployment.yaml
kubectl apply --dry-run=server -f deployment.yaml

# Resource usage
kubectl describe nodes | grep -A 5 "Allocated resources"
kubectl top pods --sort-by=cpu --all-namespaces
```

# Advanced Kubernetes Management: A Comprehensive Guide

This comprehensive guide explores advanced kubectl techniques, automation strategies, and production-ready monitoring solutions for managing Kubernetes clusters at scale. Understanding these concepts will transform you from a basic Kubernetes user into someone who can efficiently troubleshoot, monitor, and optimize complex cluster environments.

## Understanding Advanced kubectl Query Techniques

Modern Kubernetes environments often contain hundreds or thousands of resources, making efficient querying and filtering essential skills. The techniques covered here allow you to extract precise information from your cluster without being overwhelmed by data.

### JSONPath: Extracting Structured Data

JSONPath is a query language that allows you to navigate JSON structures using a path notation similar to how you navigate file systems. In Kubernetes, every resource can be represented as JSON, making JSONPath incredibly powerful for data extraction.

```bash
# Basic JSONPath - extract just the pod names
# The '.items[*]' means "for all items in the array"
# The '.metadata.name' navigates to the name field of each item
kubectl get pods -o jsonpath='{.items[*].metadata.name}'

# Advanced JSONPath with filtering - find external IP addresses
# The '[?(@.type=="ExternalIP")]' is a filter expression
# '@' represents the current item being evaluated
kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalIP")].address}'

# Multiple field extraction with formatting
# The '\n' creates line breaks between results
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\n"}{end}'

# Extract specific container information
# This navigates through the pod spec to container details
kubectl get pods -o jsonpath='{.items[*].spec.containers[*].image}' | tr ' ' '\n' | sort -u
```

The power of JSONPath becomes evident when you need to extract specific information from complex nested structures. For example, when troubleshooting networking issues, you might need to correlate pod IPs with their node assignments, which JSONPath handles elegantly.

### Custom Columns: Creating Readable Output

Custom columns allow you to create table-like output with exactly the information you need, formatted in a human-readable way. This is particularly useful for creating dashboard-like views of your cluster state.

```bash
# Create a custom pod overview showing critical information
# Each column maps to a specific JSONPath in the resource structure
kubectl get pods -o custom-columns=\
NAME:.metadata.name,\
STATUS:.status.phase,\
NODE:.spec.nodeName,\
IP:.status.podIP,\
RESTARTS:.status.containerStatuses[0].restartCount

# Deployment readiness overview
# This helps quickly assess which deployments might have issues
kubectl get deployments -o custom-columns=\
NAME:.metadata.name,\
DESIRED:.spec.replicas,\
CURRENT:.status.replicas,\
READY:.status.readyReplicas,\
AGE:.metadata.creationTimestamp

# Node resource allocation view
# Understanding resource allocation is crucial for capacity planning
kubectl get nodes -o custom-columns=\
NAME:.metadata.name,\
STATUS:.status.conditions[-1].type,\
ROLES:.metadata.labels.'kubernetes\.io/role',\
VERSION:.status.nodeInfo.kubeletVersion,\
INTERNAL-IP:.status.addresses[0].address
```

Custom columns shine when you need to create repeatable reports or when onboarding new team members who need simplified views of complex cluster states.

### Field and Label Selectors: Precise Filtering

Selectors allow you to filter resources based on their current state or labels, enabling you to focus on exactly what matters for your current task.

```bash
# Field selectors filter based on resource fields
# This is server-side filtering, so it's efficient even with many resources
kubectl get pods --field-selector=status.phase=Running
kubectl get pods --field-selector=spec.nodeName=worker-node-1
kubectl get events --field-selector=type=Warning,reason=Failed

# Label selectors use the labels attached to resources
# The 'in' operator allows matching against multiple values
kubectl get pods -l 'environment in (production,staging)'
kubectl get pods -l 'app=web,version!=v1'
kubectl get services -l 'tier=frontend'

# Combining selectors for complex queries
# This finds all running pods in production that aren't version v1
kubectl get pods --field-selector=status.phase=Running -l 'environment=production,version!=v1'

# Existence checks - find resources with or without specific labels
kubectl get pods -l 'environment'  # Has environment label
kubectl get pods -l '!environment'  # Missing environment label
```

Understanding the difference between field and label selectors is crucial. Field selectors work with the actual resource state (like pod phase or node name), while label selectors work with the metadata tags you or your tools have applied to resources.

### Advanced Sorting and Watching

Sorting helps you identify outliers and trends in your cluster, while watching allows you to observe changes in real-time.

```bash
# Sort by creation time to find oldest/newest resources
# This is invaluable for understanding deployment patterns and troubleshooting
kubectl get pods --sort-by=.metadata.creationTimestamp
kubectl get deployments --sort-by=.metadata.creationTimestamp --reverse=true

# Sort by resource usage (requires metrics server)
# Identifying resource-hungry pods helps with optimization
kubectl top pods --sort-by=cpu --all-namespaces
kubectl top pods --sort-by=memory --containers

# Watch with custom formatting
# This creates a live dashboard of pod status changes
kubectl get pods -w -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName

# Watch specific events
# Critical for real-time troubleshooting during deployments
kubectl get events -w --field-selector=type=Warning
```

### Server-Side Operations and Dry Runs

These advanced features help you safely plan and execute changes to your cluster.

```bash
# Server-side apply for better conflict resolution
# This allows multiple controllers to manage the same resource
kubectl apply --server-side -f deployment.yaml --field-manager=my-tool

# Preview changes before applying them
# The diff shows exactly what would change
kubectl diff -f updated-deployment.yaml

# Test deployments without actually applying them
# Server-side dry run validates against admission controllers
kubectl apply --dry-run=server -f deployment.yaml

# Client-side dry run for syntax validation
kubectl apply --dry-run=client -f deployment.yaml
```

## Comprehensive Cluster Analysis and Automation

Now let's dive into the advanced automation scripts that transform manual cluster management into systematic, repeatable processes.

### Resource Analysis Engine

This script provides deep insights into how your cluster resources are being utilized, helping you make informed decisions about scaling, optimization, and capacity planning.

```bash
#!/bin/bash
# Advanced Kubernetes Resource Analyzer
# This script provides comprehensive cluster resource analysis

echo "🚀 Advanced Kubernetes Automation and Management"

# The resource analyzer examines multiple dimensions of cluster health
cat << 'EOF' > k8s-resource-analyzer.sh
#!/bin/bash

# Function to analyze cluster-wide resource allocation
# Understanding resource allocation is critical for cluster efficiency
analyze_cluster_resources() {
  echo "📊 Comprehensive Cluster Resource Analysis"
  echo "=========================================="
  
  echo "🖥️ Node Resources:"
  # This complex awk script parses kubectl describe nodes output
  # It extracts and calculates resource utilization percentages
  kubectl describe nodes | awk '
  /^Name:/ { node=$2 }
  /cpu:/ {
    # When we find CPU allocation information
    if ($1 ~ /Allocated/) {
      allocated_cpu=$4    # Extract allocated CPU
      total_cpu=$6        # Extract total CPU
      cpu_percent=$7      # Extract percentage
      gsub(/[()%]/, "", cpu_percent)  # Clean up percentage formatting
    }
  }
  /memory:/ {
    # When we find memory allocation information
    if ($1 ~ /Allocated/) {
      allocated_mem=$4
      total_mem=$6
      mem_percent=$7
      gsub(/[()%]/, "", mem_percent)
      # Print formatted output showing resource utilization per node
      printf " %s: CPU %s/%s (%s%%), Memory %s/%s (%s%%)\n",
        node, allocated_cpu, total_cpu, cpu_percent,
        allocated_mem, total_mem, mem_percent
    }
  }'
  
  echo ""
  echo "📦 Pod Resource Distribution:"
  # This jq query examines pod resource requests
  # Resource requests are crucial for proper scheduling
  kubectl get pods --all-namespaces -o json | jq -r '
  .items[] |
  select(.spec.containers[]?.resources.requests) |
  "\(.metadata.namespace)/\(.metadata.name): CPU=\(.spec.containers[0].resources.requests.cpu // "none"), Memory=\(.spec.containers[0].resources.requests.memory // "none")"
  ' | head -10
  
  echo ""
  echo "⚠️ Pods Without Resource Limits:"
  # Pods without limits can consume unlimited resources, potentially impacting other workloads
  kubectl get pods --all-namespaces -o json | jq -r '
  .items[] |
  select(.spec.containers[0].resources.limits == null) |
  "\(.metadata.namespace)/\(.metadata.name)"
  ' | head -10
  
  echo ""
  echo "🔥 High Resource Usage Pods:"
  # Real-time resource usage requires metrics server
  if kubectl top pods --all-namespaces >/dev/null 2>&1; then
    echo " Top CPU consumers:"
    kubectl top pods --all-namespaces --sort-by=cpu | head -5
    echo ""
    echo " Top Memory consumers:"
    kubectl top pods --all-namespaces --sort-by=memory | head -5
  else
    echo " ⚠️ Metrics server not available - install metrics-server for real-time usage data"
    echo " kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
  fi
  
  echo ""
  echo "📈 Resource Efficiency Analysis:"
  # Compare requests vs actual usage to identify over/under-provisioning
  if kubectl top pods --all-namespaces >/dev/null 2>&1; then
    echo " Analyzing request vs usage efficiency..."
    kubectl get pods --all-namespaces -o json | jq -r '
    .items[] |
    select(.spec.containers[0].resources.requests.cpu) |
    "\(.metadata.namespace)/\(.metadata.name) requests \(.spec.containers[0].resources.requests.cpu // "unknown") CPU"
    ' | head -5
  fi
}

# Network analysis reveals connectivity and service mesh health
analyze_network() {
  echo ""
  echo "🌐 Network Analysis:"
  echo "==================="
  
  echo "📡 Services and Endpoints:"
  # Services without endpoints indicate connectivity issues
  kubectl get services --all-namespaces -o wide | head -10
  
  echo ""
  echo "🔍 Service Endpoint Health:"
  # Check which services have healthy endpoints
  kubectl get endpoints --all-namespaces -o json | jq -r '
  .items[] |
  if .subsets then
    "\(.metadata.namespace)/\(.metadata.name): \(.subsets[0].addresses | length) ready endpoints"
  else
    "\(.metadata.namespace)/\(.metadata.name): NO ENDPOINTS"
  end
  ' | head -10
  
  echo ""
  echo "🔗 Ingress Resources:"
  # Ingress controllers manage external access to services
  if kubectl get ingress --all-namespaces >/dev/null 2>&1; then
    kubectl get ingress --all-namespaces -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
HOSTS:.spec.rules[*].host,\
PORTS:.spec.tls[*].secretName | head -5
  else
    echo " No ingress resources found"
  fi
  
  echo ""
  echo "🔒 Network Policies:"
  # Network policies control pod-to-pod communication
  if kubectl get networkpolicies --all-namespaces >/dev/null 2>&1; then
    kubectl get networkpolicies --all-namespaces -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
POD-SELECTOR:.spec.podSelector
  else
    echo " No network policies found - consider implementing network segmentation"
  fi
  
  echo ""
  echo "🌐 DNS and Service Discovery:"
  # Check core DNS health and service discovery
  kubectl get pods -n kube-system -l k8s-app=kube-dns -o custom-columns=\
NAME:.metadata.name,\
STATUS:.status.phase,\
RESTARTS:.status.containerStatuses[0].restartCount
}

# Storage analysis is crucial for stateful applications
analyze_storage() {
  echo ""
  echo "💾 Storage Analysis:"
  echo "==================="
  
  echo "📀 Persistent Volumes:"
  kubectl get pv -o custom-columns=\
NAME:.metadata.name,\
CAPACITY:.spec.capacity.storage,\
ACCESS-MODE:.spec.accessModes[0],\
RECLAIM-POLICY:.spec.persistentVolumeReclaimPolicy,\
STATUS:.status.phase,\
CLAIM:.spec.claimRef.name
  
  echo ""
  echo "📋 Persistent Volume Claims:"
  kubectl get pvc --all-namespaces -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
STATUS:.status.phase,\
VOLUME:.spec.volumeName,\
CAPACITY:.status.capacity.storage,\
ACCESS-MODE:.status.accessModes[0]
  
  echo ""
  echo "🏪 Storage Classes:"
  kubectl get storageclass -o custom-columns=\
NAME:.metadata.name,\
PROVISIONER:.provisioner,\
RECLAIM-POLICY:.reclaimPolicy,\
VOLUME-BINDING:.volumeBindingMode,\
DEFAULT:.metadata.annotations.'storageclass\.kubernetes\.io/is-default-class'
  
  echo ""
  echo "⚠️ Storage Issues:"
  # Identify common storage problems
  echo " Pending PVCs (may indicate provisioning issues):"
  kubectl get pvc --all-namespaces --field-selector=status.phase=Pending
  
  echo " Available PVs (unused storage capacity):"
  kubectl get pv --field-selector=status.phase=Available | wc -l | xargs echo " Count:"
}

# Security analysis helps identify potential vulnerabilities
analyze_security() {
  echo ""
  echo "🔐 Security Analysis:"
  echo "===================="
  
  echo "👥 Service Accounts:"
  # Service accounts define pod permissions
  kubectl get serviceaccounts --all-namespaces -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
SECRETS:.secrets[*].name | head -10
  
  echo ""
  echo "🛡️ RBAC Analysis:"
  echo " Roles and ClusterRoles:"
  kubectl get roles,clusterroles --all-namespaces -o custom-columns=\
KIND:.kind,\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name | head -10
  
  echo " RoleBindings and ClusterRoleBindings:"
  kubectl get rolebindings,clusterrolebindings --all-namespaces -o custom-columns=\
KIND:.kind,\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
ROLE:.roleRef.name | head -10
  
  echo ""
  echo "🔑 Secrets Analysis:"
  kubectl get secrets --all-namespaces -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
TYPE:.type,\
DATA:.data | head -10
  
  echo ""
  echo "🚨 Security Concerns:"
  # Check for common security issues
  echo " Pods running as root:"
  kubectl get pods --all-namespaces -o json | jq -r '
  .items[] |
  select(.spec.securityContext.runAsUser == 0 or .spec.containers[].securityContext.runAsUser == 0) |
  "\(.metadata.namespace)/\(.metadata.name)"
  ' | head -5
  
  echo " Pods with privileged containers:"
  kubectl get pods --all-namespaces -o json | jq -r '
  .items[] |
  select(.spec.containers[].securityContext.privileged == true) |
  "\(.metadata.namespace)/\(.metadata.name)"
  ' | head -5
}

# Performance analysis identifies bottlenecks and issues
analyze_performance() {
  echo ""
  echo "⚡ Performance Analysis:"
  echo "======================="
  
  echo "🎯 Pod Restart Analysis:"
  # High restart counts often indicate application or infrastructure issues
  kubectl get pods --all-namespaces -o json | jq -r '
  .items[] |
  select(.status.containerStatuses[]?.restartCount > 0) |
  "\(.metadata.namespace)/\(.metadata.name): \(.status.containerStatuses[0].restartCount) restarts - \(.status.containerStatuses[0].lastState.terminated.reason // "unknown reason")"
  ' | sort -k2 -nr | head -10
  
  echo ""
  echo "⏱️ Long-running Pods (oldest first):"
  # Understanding pod age helps with maintenance and updates
  kubectl get pods --all-namespaces --sort-by=.metadata.creationTimestamp -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
AGE:.metadata.creationTimestamp,\
STATUS:.status.phase | head -10
  
  echo ""
  echo "🚨 Failed and Problematic Pods:"
  # Identify pods that need attention
  kubectl get pods --all-namespaces --field-selector=status.phase=Failed -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
REASON:.status.containerStatuses[0].state.terminated.reason | head -5
  
  echo ""
  echo "🔄 Recent Events (last 1 hour):"
  # Recent events provide context for current issues
  kubectl get events --all-namespaces --sort-by=.metadata.creationTimestamp | \
  awk 'NR==1 || /[0-9]+m/ && $6+0 <= 60' | tail -10
  
  echo ""
  echo "📊 Resource Pressure Analysis:"
  # Check for resource pressure on nodes
  kubectl describe nodes | grep -A 5 -B 5 "pressure\|OutOf" | head -20
}

# Enhanced reporting with recommendations
generate_recommendations() {
  echo ""
  echo "💡 Cluster Optimization Recommendations:"
  echo "========================================"
  
  # Check for over-provisioned resources
  echo "🎯 Resource Optimization:"
  if kubectl top pods --all-namespaces >/dev/null 2>&1; then
    echo " • Consider implementing Vertical Pod Autoscaler (VPA) for automatic resource optimization"
    echo " • Review pods without resource limits - they can impact cluster stability"
    echo " • Monitor resource usage trends to right-size your workloads"
  else
    echo " • Install metrics-server to enable resource monitoring and optimization"
  fi
  
  echo ""
  echo "🔒 Security Hardening:"
  echo " • Implement Pod Security Standards to enforce security policies"
  echo " • Review service accounts and RBAC permissions regularly"
  echo " • Consider using network policies to segment pod communication"
  echo " • Scan container images for vulnerabilities"
  
  echo ""
  echo "🏗️ Infrastructure Best Practices:"
  echo " • Implement node affinity and anti-affinity rules for critical workloads"
  echo " • Use multiple availability zones for high availability"
  echo " • Regular backup and disaster recovery testing"
  echo " • Monitor cluster components health (etcd, API server, scheduler)"
}

# Main execution logic with command-line interface
case "$1" in
  "resources")
    analyze_cluster_resources
    ;;
  "network")
    analyze_network
    ;;
  "storage")
    analyze_storage
    ;;
  "security")
    analyze_security
    ;;
  "performance")
    analyze_performance
    ;;
  "recommendations")
    generate_recommendations
    ;;
  "all"|"")
    analyze_cluster_resources
    analyze_network
    analyze_storage
    analyze_security
    analyze_performance
    generate_recommendations
    ;;
  *)
    echo "Usage: $0 {resources|network|storage|security|performance|recommendations|all}"
    echo ""
    echo "Commands:"
    echo "  resources       - Analyze CPU, memory, and resource allocation"
    echo "  network        - Examine services, ingress, and network policies"
    echo "  storage        - Review persistent volumes and storage classes"
    echo "  security       - Audit RBAC, service accounts, and security settings"
    echo "  performance    - Identify bottlenecks and performance issues"
    echo "  recommendations - Generate optimization suggestions"
    echo "  all            - Run complete cluster analysis"
    ;;
esac
EOF

chmod +x k8s-resource-analyzer.sh

# Advanced Health Monitoring System
# This creates a comprehensive monitoring solution
cat << 'EOF' > k8s-health-monitor.sh
#!/bin/bash
# Advanced Kubernetes Health Monitoring System
# This system provides continuous monitoring with intelligent alerting

# Configuration - adjust these thresholds based on your environment
ALERT_THRESHOLD_CPU=80      # CPU usage percentage that triggers alerts
ALERT_THRESHOLD_MEMORY=80   # Memory usage percentage that triggers alerts
ALERT_THRESHOLD_DISK=85     # Disk usage percentage that triggers alerts
ALERT_THRESHOLD_RESTARTS=5  # Number of restarts that triggers concern
LOG_FILE="/tmp/k8s-health-monitor.log"
ALERT_LOG="/tmp/k8s-alerts.log"

# Logging function with structured output
log_message() {
  local level="$1"
  local message="$2"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "$timestamp [$level] - $message" | tee -a "$LOG_FILE"
  
  # Also log alerts separately for easy filtering
  if [[ "$level" == "ALERT" || "$level" == "CRITICAL" ]]; then
    echo "$timestamp [$level] - $message" >> "$ALERT_LOG"
  fi
}

# Comprehensive node health assessment
check_node_health() {
  log_message "INFO" "🏥 Starting Comprehensive Node Health Check"
  
  # Check basic node status
  while read -r node status conditions; do
    if [[ "$status" != "Ready" ]]; then
      log_message "ALERT" "❌ Node $node is not ready (Status: $status)"
      # Get detailed node information for troubleshooting
      kubectl describe node "$node" | grep -A 10 "Conditions:" | while read line; do
        log_message "INFO" "  Node details: $line"
      done
    else
      log_message "INFO" "✅ Node $node is healthy"
    fi
  done < <(kubectl get nodes --no-headers -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type,CONDITIONS:.status.conditions[*].type)
  
  # Check node resource pressure
  log_message "INFO" "🔍 Checking node resource pressure..."
  kubectl describe nodes | grep -E "(MemoryPressure|DiskPressure|PIDPressure)" | while read line; do
    if echo "$line" | grep -q "True"; then
      log_message "ALERT" "⚠️ Resource pressure detected: $line"
    fi
  done
  
  # Check node capacity and allocatable resources
  log_message "INFO" "📊 Node capacity analysis:"
  kubectl get nodes -o json | jq -r '
  .items[] |
  "\(.metadata.name): CPU \(.status.allocatable.cpu)/\(.status.capacity.cpu), Memory \(.status.allocatable.memory)/\(.status.capacity.memory)"
  ' | while read line; do
    log_message "INFO" "  $line"
  done
}

# Advanced pod health monitoring with root cause analysis
check_pod_health() {
  log_message "INFO" "🔍 Starting Advanced Pod Health Analysis"
  
  # Check for pods in problematic states
  local problematic_pods=$(kubectl get pods --all-namespaces --no-headers | grep -E "(Error|CrashLoopBackOff|ImagePullBackOff|Pending|Terminating)" | wc -l)
  
  if [ "$problematic_pods" -gt 0 ]; then
    log_message "ALERT" "⚠️ Found $problematic_pods pods in problematic states"
    
    # Detailed analysis of each problematic pod
    kubectl get pods --all-namespaces -o json | jq -r '
    .items[] |
    select(.status.phase != "Running" and .status.phase != "Succeeded") |
    "\(.metadata.namespace)/\(.metadata.name): \(.status.phase) - \(.status.containerStatuses[0].state | keys[0])"
    ' | while read pod_info; do
      log_message "ALERT" "  📦 $pod_info"
      
      # Get the pod name and namespace for detailed analysis
      namespace=$(echo "$pod_info" | cut -d'/' -f1)
      pod_name=$(echo "$pod_info" | cut -d'/' -f2 | cut -d':' -f1)
      
      # Get recent events for this pod
      kubectl get events --namespace="$namespace" --field-selector=involvedObject.name="$pod_name" --sort-by='.metadata.creationTimestamp' | tail -3 | while read event; do
        log_message "INFO" "    Event: $event"
      done
    done
  else
    log_message "INFO" "✅ All pods are in healthy states"
  fi
  
  # Check for pods with high restart counts
  log_message "INFO" "🔄 Analyzing pod restart patterns..."
  kubectl get pods --all-namespaces -o json | jq -r '
  .items[] |
  select(.status.containerStatuses[]?.restartCount > '$ALERT_THRESHOLD_RESTARTS') |
  "\(.metadata.namespace)/\(.metadata.name): \(.status.containerStatuses[0].restartCount) restarts"
  ' | while read restart_info; do
    log_message "ALERT" "🚨 High restart count: $restart_info"
  done
  
  # Check pod resource usage vs requests
  if kubectl top pods --all-namespaces >/dev/null 2>&1; then
    log_message "INFO" "📈 Analyzing resource usage patterns..."
    kubectl top pods --all-namespaces --sort-by=cpu | head -5 | while read pod_usage; do
      log_message "INFO" "  High CPU: $pod_usage"
    done
  fi
}

# Intelligent resource usage monitoring with trend analysis
check_resource_usage() {
  log_message "INFO" "📊 Starting Intelligent Resource Usage Analysis"
  
  if kubectl top nodes >/dev/null 2>&1; then
    # Analyze node resource usage with intelligent thresholds
    kubectl top nodes --no-headers | while read node cpu_usage cpu_percent memory_usage memory_percent; do
      cpu_num=$(echo $cpu_percent | tr -d '%')
      mem_num=$(echo $memory_percent | tr -d '%')
      
      # Dynamic alerting based on node role and criticality
      if [ "$cpu_num" -gt "$ALERT_THRESHOLD_CPU" ]; then
        log_message "ALERT" "🚨 HIGH CPU: Node $node using $cpu_percent CPU"
        # Identify top CPU consuming pods on this node
        kubectl get pods --all-namespaces --field-selector=spec.nodeName="$node" -o json | \
        jq -r '.items[] | "\(.metadata.namespace)/\(.metadata.name)"' | head -3 | while read pod; do
          log_message "INFO" "  Top pod on $node: $pod"
        done
      fi
      
      if [ "$mem_num" -gt "$ALERT_THRESHOLD_MEMORY" ]; then
        log_message "ALERT" "🚨 HIGH MEMORY: Node $node using $memory_percent memory"
      fi
      
      log_message "INFO" "📊 $node: CPU $cpu_percent, Memory $memory_percent"
    done
    
    # Cluster-wide resource analysis
    log_message "INFO" "🌐 Cluster-wide resource summary:"
    kubectl top nodes --no-headers | awk '
    {
      cpu_total += $2; cpu_percent_total += $3;
      mem_total += $4; mem_percent_total += $5;
      count++
    }
    END {
      printf "Average CPU: %.1f%%, Average Memory: %.1f%%\n", 
      cpu_percent_total/count, mem_percent_total/count
    }' | while read summary; do
      log_message "INFO" "  $summary"
    done
  else
    log_message "ALERT" "⚠️ Metrics server not available"
    log_message "INFO" "💡 Install metrics-server: kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
  fi
}

# Advanced storage health monitoring
check_storage_health() {
  log_message "INFO" "💾 Starting Advanced Storage Health Analysis"
  
  # Check PVC status
  local pending_pvcs=$(kubectl get pvc --all-namespaces --no-headers | grep -c "Pending" || echo "0")
  if [ "$pending_pvcs" -gt 0 ]; then
    log_message "ALERT" "⚠️ $pending_pvcs PVCs in Pending state"
    kubectl get pvc --all-namespaces --field-selector=status.phase=Pending -o custom-columns=\
NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATUS:.status.phase,STORAGE-CLASS:.spec.storageClassName | while read pvc_info; do
      log_message "INFO" "  Pending PVC: $pvc_info"
    done
  fi
  
  # Check PV availability
  local available_pvs=$(kubectl get pv --no-headers | grep -c "Available" || echo "0")
  local bound_pvs=$(kubectl get pv --no-headers | grep -c "Bound" || echo "0")
  log_message "INFO" "📊 Storage overview: $available_pvs available PVs, $bound_pvs bound PVs"
  
  # Check storage class health
  log_message "INFO" "🏪 Storage class analysis:"
  kubectl get storageclass -o json | jq -r '
  .items[] |
  "\(.metadata.name): \(.provisioner) - Default: \(.metadata.annotations."storageclass.kubernetes.io/is-default-class" // "false")"
  ' | while read sc_info; do
    log_message "INFO" "  $sc_info"
  done
  
  # Check for storage-related events
  kubectl get events --all-namespaces | grep -i "storage\|volume\|mount" | tail -5 | while read storage_event; do
    log_message "INFO" "  Storage event: $storage_event"
  done
}

# Comprehensive service and network health monitoring
check_service_health() {
  log_message "INFO" "🌐 Starting Comprehensive Service Health Analysis"
  
  # Check services without endpoints
  local services_without_endpoints=0
  kubectl get endpoints --all-namespaces -o json | jq -r '
  .items[] |
  select(.subsets == null or .subsets == []) |
  "\(.metadata.namespace)/\(.metadata.name)"
  ' | while read service; do
    if [ ! -z "$service" ]; then
      log_message "ALERT" "⚠️ Service $service has no healthy endpoints"
      services_without_endpoints=$((services_without_endpoints + 1))
      
      # Get more details about why endpoints are missing
      namespace=$(echo "$service" | cut -d'/' -f1)
      service_name=$(echo "$service" | cut -d'/' -f2)
      
      # Check if corresponding pods exist
      kubectl get pods -n "$namespace" -o json | jq -r --arg svc "$service_name" '
      .items[] |
      select(.metadata.labels.app == $svc or .metadata.labels."app.kubernetes.io/name" == $svc) |
      "\(.metadata.name): \(.status.phase)"
      ' | while read pod_info; do
        log_message "INFO" "    Related pod: $pod_info"
      done
    fi
  done
  
  if [ "$services_without_endpoints" -eq 0 ]; then
    log_message "INFO" "✅ All services have healthy endpoints"
  fi
  
  # Check ingress controller health
  log_message "INFO" "🔗 Checking ingress controller status..."
  kubectl get pods --all-namespaces -l app.kubernetes.io/component=controller -o custom-columns=\
NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATUS:.status.phase,RESTARTS:.status.containerStatuses[0].restartCount | while read ingress_info; do
    log_message "INFO" "  Ingress controller: $ingress_info"
  done
  
  # Check DNS resolution health
  log_message "INFO" "🔍 Checking DNS health..."
  kubectl get pods -n kube-system -l k8s-app=kube-dns -o json | jq -r '
  .items[] |
  "\(.metadata.name): \(.status.phase) - Restarts: \(.status.containerStatuses[0].restartCount)"
  ' | while read dns_info; do
    log_message "INFO" "  DNS pod: $dns_info"
  done
  
  # Network policy impact analysis
  local netpol_count=$(kubectl get networkpolicies --all-namespaces --no-headers | wc -l)
  log_message "INFO" "🔒 Network policies active: $netpol_count"
  
  if [ "$netpol_count" -gt 0 ]; then
    kubectl get networkpolicies --all-namespaces -o json | jq -r '
    .items[] |
    "\(.metadata.namespace)/\(.metadata.name): affects \(.spec.podSelector.matchLabels | keys | join(",")) pods"
    ' | head -3 | while read netpol_info; do
      log_message "INFO" "  $netpol_info"
    done
  fi
}

# Enhanced cluster component health monitoring
check_cluster_components() {
  log_message "INFO" "🏗️ Starting Cluster Component Health Check"
  
  # Check control plane components
  log_message "INFO" "🎛️ Control plane component status:"
  kubectl get componentstatuses 2>/dev/null | while read comp_status; do
    log_message "INFO" "  $comp_status"
  done
  
  # Check system pods in kube-system namespace
  log_message "INFO" "🔧 System pod health:"
  kubectl get pods -n kube-system -o json | jq -r '
  .items[] |
  select(.status.phase != "Running") |
  "\(.metadata.name): \(.status.phase) - \(.status.containerStatuses[0].state | keys[0])"
  ' | while read system_pod; do
    if [ ! -z "$system_pod" ]; then
      log_message "ALERT" "🚨 System pod issue: $system_pod"
    fi
  done
  
  # Check API server responsiveness
  log_message "INFO" "🌐 Testing API server responsiveness..."
  start_time=$(date +%s%3N)
  kubectl get nodes >/dev/null 2>&1
  end_time=$(date +%s%3N)
  api_response_time=$((end_time - start_time))
  
  if [ "$api_response_time" -gt 5000 ]; then
    log_message "ALERT" "🐌 Slow API server response: ${api_response_time}ms"
  else
    log_message "INFO" "✅ API server responsive: ${api_response_time}ms"
  fi
  
  # Check etcd health (if accessible)
  log_message "INFO" "🗄️ Checking etcd health..."
  kubectl get pods -n kube-system -l component=etcd -o json | jq -r '
  .items[] |
  "\(.metadata.name): \(.status.phase) - Ready: \(.status.conditions[] | select(.type=="Ready") | .status)"
  ' | while read etcd_info; do
    log_message "INFO" "  etcd: $etcd_info"
  done
}

# Advanced alerting and notification system
send_alert() {
  local severity="$1"
  local message="$2"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  
  # Log the alert
  log_message "$severity" "$message"
  
  # Here you can integrate with external alerting systems
  # Examples:
  # - Slack webhook
  # - PagerDuty API
  # - Email notifications
  # - Prometheus Alertmanager
  
  case "$severity" in
    "CRITICAL")
      echo "🚨 CRITICAL ALERT: $message" | tee -a "$ALERT_LOG"
      # send_to_pagerduty "$message"
      ;;
    "ALERT")
      echo "⚠️ ALERT: $message" | tee -a "$ALERT_LOG"
      # send_to_slack "$message"
      ;;
    "WARNING")
      echo "⚠️ WARNING: $message" | tee -a "$ALERT_LOG"
      ;;
  esac
}

# Comprehensive health report generation
generate_health_report() {
  local report_file="/tmp/k8s-health-report-$(date +%Y%m%d-%H%M%S).html"
  
  log_message "INFO" "📋 Generating comprehensive health report..."
  
  cat << 'HTML' > "$report_file"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Kubernetes Cluster Health Report</title>
  <style>
    body { 
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
      margin: 0; 
      padding: 20px; 
      background-color: #f5f7fa;
    }
    .container { max-width: 1200px; margin: 0 auto; }
    .header { 
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white; 
      padding: 20px; 
      border-radius: 10px; 
      margin-bottom: 20px;
      text-align: center;
    }
    .healthy { color: #28a745; font-weight: bold; }
    .warning { color: #ffc107; font-weight: bold; }
    .error { color: #dc3545; font-weight: bold; }
    .section { 
      background: white;
      margin: 15px 0; 
      padding: 20px; 
      border-radius: 8px;
      box-shadow: 0 2px 10px rgba(0,0,0,0.1);
    }
    .section h2 {
      border-bottom: 2px solid #e9ecef;
      padding-bottom: 10px;
      margin-top: 0;
    }
    pre { 
      background: #f8f9fa; 
      padding: 15px; 
      border-radius: 5px;
      overflow-x: auto; 
      border-left: 4px solid #007bff;
    }
    .metric-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
      gap: 15px;
      margin: 15px 0;
    }
    .metric-card {
      background: #f8f9fa;
      padding: 15px;
      border-radius: 8px;
      border-left: 4px solid #28a745;
    }
    .metric-card.warning { border-left-color: #ffc107; }
    .metric-card.error { border-left-color: #dc3545; }
    .footer {
      text-align: center;
      margin-top: 30px;
      padding: 20px;
      background: #e9ecef;
      border-radius: 8px;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>🏥 Kubernetes Cluster Health Report</h1>
      <p>Generated: $(date)</p>
      <p>Cluster: $(kubectl config current-context)</p>
    </div>
HTML

  # Add cluster overview section
  cat << 'HTML' >> "$report_file"
    <div class="section">
      <h2>📊 Cluster Overview</h2>
      <div class="metric-grid">
        <div class="metric-card">
          <h4>Nodes</h4>
          <pre>$(kubectl get nodes --no-headers | wc -l) total nodes</pre>
        </div>
        <div class="metric-card">
          <h4>Namespaces</h4>
          <pre>$(kubectl get namespaces --no-headers | wc -l) namespaces</pre>
        </div>
        <div class="metric-card">
          <h4>Pods</h4>
          <pre>$(kubectl get pods --all-namespaces --no-headers | wc -l) total pods</pre>
        </div>
        <div class="metric-card">
          <h4>Services</h4>
          <pre>$(kubectl get services --all-namespaces --no-headers | wc -l) services</pre>
        </div>
      </div>
      <pre>$(kubectl get nodes -o wide)</pre>
    </div>
HTML

  # Add pod status section
  cat << 'HTML' >> "$report_file"
    <div class="section">
      <h2>🔍 Pod Status Summary</h2>
      <pre>$(kubectl get pods --all-namespaces | head -20)</pre>
      
      <h3>Pod Phase Distribution</h3>
      <pre>$(kubectl get pods --all-namespaces --no-headers | awk '{print $4}' | sort | uniq -c)</pre>
    </div>
HTML

  # Add alerts section
  cat << 'HTML' >> "$report_file"
    <div class="section">
      <h2>⚠️ Recent Alerts and Issues</h2>
      <pre>$(tail -20 "$LOG_FILE" 2>/dev/null | grep -E "(ALERT|CRITICAL|ERROR)" || echo "No recent alerts")</pre>
    </div>
HTML

  # Add resource usage section
  if kubectl top nodes >/dev/null 2>&1; then
    cat << 'HTML' >> "$report_file"
    <div class="section">
      <h2>📈 Resource Usage</h2>
      <h3>Node Resource Usage</h3>
      <pre>$(kubectl top nodes 2>/dev/null)</pre>
      
      <h3>Top Resource Consuming Pods</h3>
      <pre>$(kubectl top pods --all-namespaces --sort-by=cpu 2>/dev/null | head -10)</pre>
    </div>
HTML
  fi

  # Add events section
  cat << 'HTML' >> "$report_file"
    <div class="section">
      <h2>📅 Recent Events</h2>
      <pre>$(kubectl get events --all-namespaces --sort-by=.metadata.creationTimestamp | tail -15)</pre>
    </div>
HTML

  # Add storage section
  cat << 'HTML' >> "$report_file"
    <div class="section">
      <h2>💾 Storage Status</h2>
      <h3>Persistent Volumes</h3>
      <pre>$(kubectl get pv 2>/dev/null || echo "No persistent volumes")</pre>
      
      <h3>Persistent Volume Claims</h3>
      <pre>$(kubectl get pvc --all-namespaces 2>/dev/null | head -10 || echo "No PVCs")</pre>
    </div>
HTML

  # Add footer
  cat << 'HTML' >> "$report_file"
    <div class="footer">
      <p>This report was generated by the Advanced Kubernetes Health Monitor</p>
      <p>For more details, check the logs at: <code>/tmp/k8s-health-monitor.log</code></p>
    </div>
  </div>
</body>
</html>
HTML

  log_message "INFO" "📋 Health report generated: $report_file"
  echo "📋 Comprehensive health report: $report_file"
}

# Intelligent monitoring loop with adaptive intervals
monitor_cluster() {
  log_message "INFO" "🚀 Starting Advanced Kubernetes Health Monitor"
  log_message "INFO" "📊 Monitoring configuration:"
  log_message "INFO" "  CPU Alert Threshold: ${ALERT_THRESHOLD_CPU}%"
  log_message "INFO" "  Memory Alert Threshold: ${ALERT_THRESHOLD_MEMORY}%"
  log_message "INFO" "  Restart Alert Threshold: ${ALERT_THRESHOLD_RESTARTS}"
  
  local check_interval=60
  local extended_check_counter=0
  
  while true; do
    log_message "INFO" "🔄 Starting monitoring cycle..."
    
    # Basic health checks every cycle
    check_node_health
    check_pod_health
    check_resource_usage
    check_service_health
    
    # Extended checks every 5 cycles (5 minutes)
    if [ $((extended_check_counter % 5)) -eq 0 ]; then
      log_message "INFO" "🔍 Running extended health checks..."
      check_storage_health
      check_cluster_components
      
      # Generate report every hour
      if [ $((extended_check_counter % 60)) -eq 0 ]; then
        generate_health_report
      fi
    fi
    
    extended_check_counter=$((extended_check_counter + 1))
    
    # Adaptive sleep based on cluster health
    local alert_count=$(grep -c "ALERT\|CRITICAL" "$LOG_FILE" 2>/dev/null || echo "0")
    if [ "$alert_count" -gt 10 ]; then
      check_interval=30  # Check more frequently if issues detected
      log_message "INFO" "⚡ Increased monitoring frequency due to alerts"
    else
      check_interval=60  # Normal interval
    fi
    
    log_message "INFO" "😴 Sleeping for $check_interval seconds..."
    sleep $check_interval
  done
}

# Command dispatcher with enhanced help
case "$1" in
  "nodes")
    check_node_health
    ;;
  "pods")
    check_pod_health
    ;;
  "resources")
    check_resource_usage
    ;;
  "storage")
    check_storage_health
    ;;
  "services")
    check_service_health
    ;;
  "components")
    check_cluster_components
    ;;
  "report")
    generate_health_report
    ;;
  "monitor")
    monitor_cluster
    ;;
  "quick")
    # Quick health check - all basic checks
    check_node_health
    check_pod_health
    check_service_health
    ;;
  "alerts")
    # Show recent alerts
    echo "📊 Recent Alerts:"
    tail -20 "$ALERT_LOG" 2>/dev/null || echo "No alerts logged"
    ;;
  *)
    echo "🏥 Advanced Kubernetes Health Monitor"
    echo "======================================"
    echo "Usage: $0 {nodes|pods|resources|storage|services|components|report|monitor|quick|alerts}"
    echo ""
    echo "Commands:"
    echo "  nodes       - Check node health and resource pressure"
    echo "  pods        - Analyze pod health and restart patterns"
    echo "  resources   - Monitor CPU, memory, and resource usage"
    echo "  storage     - Check persistent volumes and storage health"
    echo "  services    - Verify service endpoints and network health"
    echo "  components  - Check cluster components and system pods"
    echo "  report      - Generate comprehensive HTML health report"
    echo "  monitor     - Start continuous monitoring with alerts"
    echo "  quick       - Run essential health checks quickly"
    echo "  alerts      - Display recent alerts and issues"
    echo ""
    echo "Configuration:"
    echo "  CPU Alert Threshold: ${ALERT_THRESHOLD_CPU}%"
    echo "  Memory Alert Threshold: ${ALERT_THRESHOLD_MEMORY}%"
    echo "  Restart Alert Threshold: ${ALERT_THRESHOLD_RESTARTS}"
    echo ""
    echo "Log Files:"
    echo "  Main Log: $LOG_FILE"
    echo "  Alert Log: $ALERT_LOG"
    ;;
esac
EOF

chmod +x k8s-health-monitor.sh

# Create additional utility scripts for cluster management
cat << 'EOF' > k8s-troubleshooting-toolkit.sh
#!/bin/bash
# Kubernetes Troubleshooting Toolkit
# Advanced diagnostic and troubleshooting utilities

echo "🔧 Kubernetes Troubleshooting Toolkit"
echo "======================================"

# Function to troubleshoot a specific pod
troubleshoot_pod() {
  local namespace="$1"
  local pod_name="$2"
  
  if [[ -z "$namespace" || -z "$pod_name" ]]; then
    echo "Usage: troubleshoot_pod <namespace> <pod_name>"
    return 1
  fi
  
  echo "🔍 Troubleshooting pod: $namespace/$pod_name"
  echo "=============================================="
  
  # Pod basic information
  echo "📋 Pod Information:"
  kubectl get pod "$pod_name" -n "$namespace" -o wide
  echo ""
  
  # Pod status and conditions
  echo "📊 Pod Status Details:"
  kubectl describe pod "$pod_name" -n "$namespace" | grep -A 20 "Conditions:"
  echo ""
  
  # Recent events
  echo "📅 Recent Events:"
  kubectl get events -n "$namespace" --field-selector=involvedObject.name="$pod_name" --sort-by='.metadata.creationTimestamp' | tail -10
  echo ""
  
  # Container logs
  echo "📝 Container Logs (last 50 lines):"
  kubectl logs "$pod_name" -n "$namespace" --tail=50 | head -20
  echo ""
  
  # Resource usage if available
  if kubectl top pod "$pod_name" -n "$namespace" >/dev/null 2>&1; then
    echo "📈 Current Resource Usage:"
    kubectl top pod "$pod_name" -n "$namespace"
    echo ""
  fi
  
  # Network troubleshooting
  echo "🌐 Network Information:"
  kubectl get pod "$pod_name" -n "$namespace" -o jsonpath='{.status.podIP}' | xargs echo "Pod IP:"
  kubectl get pod "$pod_name" -n "$namespace" -o jsonpath='{.spec.nodeName}' | xargs echo "Node:"
  echo ""
}

# Function to analyze networking issues
analyze_network_issues() {
  echo "🌐 Network Connectivity Analysis"
  echo "================================"
  
  # Check DNS resolution
  echo "🔍 DNS Resolution Test:"
  kubectl run network-test --image=busybox --rm -it --restart=Never -- nslookup kubernetes.default.svc.cluster.local
  echo ""
  
  # Check service connectivity
  echo "📡 Service Connectivity:"
  kubectl get services --all-namespaces -o custom-columns=\
NAMESPACE:.metadata.namespace,NAME:.metadata.name,TYPE:.spec.type,CLUSTER-IP:.spec.clusterIP,EXTERNAL-IP:.status.loadBalancer.ingress[0].ip
  echo ""
  
  # Check ingress status
  echo "🔗 Ingress Status:"
  kubectl get ingress --all-namespaces -o wide
  echo ""
}

# Function to diagnose resource issues
diagnose_resource_issues() {
  echo "📊 Resource Diagnosis"
  echo "===================="
  
  # Find resource-constrained pods
  echo "🚨 Pods with Resource Constraints:"
  kubectl get pods --all-namespaces -o json | jq -r '
  .items[] |
  select(.status.conditions[]? | select(.type == "PodReadyCondition" and .status == "False" and .reason == "ContainersNotReady")) |
  "\(.metadata.namespace)/\(.metadata.name): \(.status.conditions[] | select(.type == "PodReadyCondition") | .message)"
  '
  echo ""
  
  # Check node resource pressure
  echo "⚠️ Node Resource Pressure:"
  kubectl describe nodes | grep -A 3 -B 3 "pressure\|OutOf"
  echo ""
  
  # Resource requests vs limits analysis
  echo "⚖️ Resource Requests vs Limits:"
  kubectl get pods --all-namespaces -o json | jq -r '
  .items[] |
  select(.spec.containers[0].resources.requests or .spec.containers[0].resources.limits) |
  "\(.metadata.namespace)/\(.metadata.name): CPU req=\(.spec.containers[0].resources.requests.cpu // "none"), limit=\(.spec.containers[0].resources.limits.cpu // "none")"
  ' | head -10
  echo ""
}

# Main command dispatcher
case "$1" in
  "pod")
    troubleshoot_pod "$2" "$3"
    ;;
  "network")
    analyze_network_issues
    ;;
  "resources")
    diagnose_resource_issues
    ;;
  *)
    echo "🔧 Troubleshooting Commands:"
    echo "  pod <namespace> <pod_name> - Deep dive into pod issues"
    echo "  network                    - Analyze network connectivity"
    echo "  resources                  - Diagnose resource constraints"
    echo ""
    echo "Example usage:"
    echo "  $0 pod default my-app-pod"
    echo "  $0 network"
    echo "  $0 resources"
    ;;
esac
EOF

chmod +x k8s-troubleshooting-toolkit.sh

echo "✅ Enhanced Advanced Kubernetes Management System Created!"
echo ""
echo "📁 Created Files:"
echo "  🔍 k8s-resource-analyzer.sh     - Comprehensive cluster analysis"
echo "  🏥 k8s-health-monitor.sh        - Advanced health monitoring"
echo "  🔧 k8s-troubleshooting-toolkit.sh - Diagnostic utilities"
echo ""
echo "🚀 Quick Start Guide:"
echo "1. Run complete cluster analysis:"
echo "   ./k8s-resource-analyzer.sh all"
echo ""
echo "2. Start health monitoring:"
echo "   ./k8s-health-monitor.sh monitor"
echo ""
echo "3. Generate health report:"
echo "   ./k8s-health-monitor.sh report"
echo ""
echo "4. Troubleshoot specific issues:"
echo "   ./k8s-troubleshooting-toolkit.sh pod default my-pod"
echo ""
echo "💡 Pro Tips:"
echo "• Customize alert thresholds by editing variables at the top of scripts"
echo "• Use 'quick' command for fast health checks during incidents"
echo "• Generated HTML reports can be shared with team members"
echo "• Set up cron jobs for automated monitoring and reporting"
echo ""
echo "🔍 Running sample analysis..."
./k8s-resource-analyzer.sh resources
echo ""
echo "🏥 Running health check..."
./k8s-health-monitor.sh quick
```

## Advanced Monitoring and Alerting Integration

The scripts above provide a foundation for cluster monitoring, but in production environments, you'll want to integrate with external monitoring systems. Here's how these tools fit into a comprehensive monitoring strategy:

### Integration with Popular Monitoring Stacks

**Prometheus Integration:**
- Export metrics using custom exporters
- Create Grafana dashboards from the collected data
- Set up AlertManager rules based on the health check results

**ELK Stack Integration:**
- Forward logs to Elasticsearch for centralized logging
- Create Kibana dashboards for visual analysis
- Set up Watcher alerts based on log patterns

**External Alerting:**
- Integrate with PagerDuty for critical alerts
- Send Slack notifications for team awareness
- Create email reports for management visibility

### Best Practices for Production Use

1. **Customize Thresholds:** Adjust alert thresholds based on your specific workload patterns and SLAs.

2. **Staged Rollouts:** Test monitoring changes in staging environments before applying to production.

3. **Alert Fatigue Prevention:** Implement intelligent alerting to avoid overwhelming operators with false positives.

4. **Documentation:** Maintain runbooks that correspond to each type of alert generated by the system.

5. **Regular Reviews:** Periodically review and update monitoring rules based on operational experience.

This enhanced guide provides not just the tools, but the understanding needed to implement sophisticated Kubernetes cluster management practices. The combination of advanced kubectl techniques with comprehensive automation creates a robust foundation for managing Kubernetes at scale.