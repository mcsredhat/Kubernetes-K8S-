# 18. Resource Management
Managing resources in Kubernetes ensures efficient utilization and prevents overuse. Think of resource management as creating a fair and sustainable ecosystem where every application gets what it needs while preventing any single workload from monopolizing cluster resources. This section covers setting resource limits, monitoring usage, automating resource optimization, and advanced concepts for production-ready clusters.

## 18.1 Understanding Resource Requests and Limits
The foundation of resource management lies in understanding the difference between what your application needs (requests) and what it's allowed to consume (limits). Resource requests act like a reservation system - they guarantee your pod will find a node with enough available resources. Resource limits function as circuit breakers, preventing runaway processes from affecting other workloads.

### Basic Resource Configuration
Define CPU and memory constraints for pods to ensure fair resource allocation.

```bash
# Create a pod with resource limits - this demonstrates the request/limit pattern
# Request: 100m CPU (0.1 cores) and 128Mi memory - what we reserve
# Limit: 500m CPU (0.5 cores) and 512Mi memory - our maximum consumption
kubectl run nginx --image=nginx --requests=cpu=100m,memory=128Mi --limits=cpu=500m,memory=512Mi

# Examine the resource specifications that were applied
kubectl describe pod nginx | grep -A 10 "Containers:" | grep -A 5 "Limits\|Requests"

# Create a more complex deployment with multiple containers showing different resource patterns
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multi-container-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: multi-container
  template:
    metadata:
      labels:
        app: multi-container
    spec:
      containers:
      # Frontend container - CPU intensive during traffic spikes
      - name: frontend
        image: nginx:alpine
        resources:
          requests:
            cpu: 200m      # Reserve 0.2 CPU cores
            memory: 256Mi  # Reserve 256MB memory
          limits:
            cpu: 800m      # Allow bursting to 0.8 CPU cores
            memory: 512Mi  # Hard limit at 512MB memory
      # Background worker - memory intensive but steady CPU usage
      - name: worker
        image: busybox
        command: ["sleep", "3600"]
        resources:
          requests:
            cpu: 100m      # Minimal CPU reservation
            memory: 512Mi  # Higher memory reservation for processing
          limits:
            cpu: 300m      # Lower CPU ceiling - not CPU bound
            memory: 1Gi    # Higher memory limit for data processing
EOF

# Understanding Quality of Service (QoS) classes through examples
echo "Examining QoS classes for our pods..."
kubectl get pods -o custom-columns="NAME:.metadata.name,QOS:.status.qosClass"
```

### Namespace-Level Resource Governance
Apply resource quotas to prevent resource exhaustion at the namespace level.

```bash
# Apply a resource quota to a namespace - this acts as a namespace-wide budget
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: default
spec:
  hard:
    # Total resources that can be requested across all pods in this namespace
    requests.cpu: "2"        # 2 CPU cores worth of requests
    requests.memory: 4Gi     # 4GB of memory requests
    # Total resources that can be consumed (limits) across all pods
    limits.cpu: "4"          # 4 CPU cores maximum consumption
    limits.memory: 8Gi       # 8GB maximum memory consumption
    # Additional constraints
    pods: "10"               # Maximum number of pods
    persistentvolumeclaims: "4"  # Limit storage claims
    services: "5"            # Limit service objects
EOF

# Create a LimitRange to enforce minimum/maximum resource boundaries per pod
# This prevents both resource hogging and under-specification
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: resource-constraints
  namespace: default
spec:
  limits:
  # Constraints for individual containers
  - type: Container
    default:           # Default limits if none specified
      cpu: 200m
      memory: 256Mi
    defaultRequest:    # Default requests if none specified
      cpu: 100m
      memory: 128Mi
    min:              # Minimum allowed values
      cpu: 50m
      memory: 64Mi
    max:              # Maximum allowed values
      cpu: 2
      memory: 4Gi
  # Constraints for entire pods
  - type: Pod
    max:
      cpu: 4
      memory: 8Gi
EOF

# View and analyze resource quotas and their current usage
kubectl get resourcequota -n default -o yaml
kubectl describe resourcequota compute-quota -n default
kubectl describe limitrange resource-constraints -n default

# Check how much of your quota is currently consumed
kubectl get resourcequota compute-quota -n default -o jsonpath='{.status}' | jq '.'
```

## 18.2 Advanced Resource Monitoring and Analysis
Monitoring goes beyond just checking current usage - it involves understanding patterns, efficiency, and potential optimization opportunities.

### Comprehensive Resource Monitoring
Use multiple approaches to understand resource consumption patterns.

```bash
# Monitor node resource usage with detailed analysis
kubectl top nodes
kubectl top nodes --sort-by=cpu    # Sort by CPU consumption
kubectl top nodes --sort-by=memory # Sort by memory consumption

# Get detailed node capacity and allocation information
kubectl describe nodes | grep -A 5 "Capacity:\|Allocatable:\|Allocated resources:"

# Monitor pod resource usage across the cluster
kubectl top pods --all-namespaces
kubectl top pods --all-namespaces --sort-by=cpu | head -10
kubectl top pods --all-namespaces --sort-by=memory | head -10

# Analyze pods by their resource efficiency (actual vs requested)
kubectl get pods --all-namespaces -o json | jq -r '
  .items[] | 
  select(.spec.containers[0].resources.requests != null) |
  "\(.metadata.namespace)/\(.metadata.name) - CPU Req: \(.spec.containers[0].resources.requests.cpu // "none") Memory Req: \(.spec.containers[0].resources.requests.memory // "none")"
'

# Check which pods lack resource specifications (potential resource risks)
echo "Pods without resource limits:"
kubectl get pods --all-namespaces -o json | jq -r '
  .items[] |
  select(.spec.containers[0].resources.limits == null) |
  "\(.metadata.namespace)/\(.metadata.name) - No limits set"
'

# Identify pods that might be resource-starved (hitting limits frequently)
kubectl get events --field-selector reason=FailedScheduling --all-namespaces
kubectl get events --field-selector reason=Evicted --all-namespaces

# Advanced resource analysis: Calculate resource request vs limit ratios
kubectl get pods --all-namespaces -o json | jq -r '
  .items[] |
  select(.spec.containers[0].resources != null) |
  select(.spec.containers[0].resources.requests != null and .spec.containers[0].resources.limits != null) |
  {
    pod: "\(.metadata.namespace)/\(.metadata.name)",
    cpu_request: .spec.containers[0].resources.requests.cpu,
    cpu_limit: .spec.containers[0].resources.limits.cpu,
    memory_request: .spec.containers[0].resources.requests.memory,
    memory_limit: .spec.containers[0].resources.limits.memory
  }
'
```

## 18.3 Pod Disruption Budgets and Availability Management
Pod Disruption Budgets ensure your applications maintain availability during voluntary disruptions like cluster maintenance, node upgrades, or scaling operations.

```bash
# Create a Pod Disruption Budget for high-availability applications
cat << EOF | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web-app-pdb
spec:
  minAvailable: 2        # Keep at least 2 pods running during disruptions
  # Alternative: maxUnavailable: 1  # Allow at most 1 pod to be unavailable
  selector:
    matchLabels:
      app: web-app
EOF

# Create a sample deployment to work with the PDB
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 4
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: web
        image: nginx:alpine
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 300m
            memory: 256Mi
EOF

# Test disruption scenarios to understand PDB behavior
echo "Testing voluntary disruption scenarios..."
kubectl get pdb web-app-pdb -o yaml
kubectl describe pdb web-app-pdb

# Simulate node drain to see PDB in action (use with caution in production)
# kubectl drain <node-name> --dry-run --ignore-daemonsets --delete-emptydir-data
```

## 18.4 Vertical Pod Autoscaling (VPA)
VPA automatically adjusts resource requests based on actual usage patterns, essentially automating the resource optimization process.

```bash
# Install VPA (if not already installed) - this is cluster-specific
# kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/vertical-pod-autoscaler/deploy/vpa-v1-crd-gen.yaml
# kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/vertical-pod-autoscaler/deploy/vpa-rbac.yaml
# kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/vertical-pod-autoscaler/deploy/vpa-deployment.yaml

# Create a VPA for automatic resource optimization
cat << EOF | kubectl apply -f -
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: web-app-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app
  updatePolicy:
    updateMode: "Auto"    # Auto, Off (recommendations only), or Initial
  resourcePolicy:
    containerPolicies:
    - containerName: web
      # Set boundaries for VPA recommendations
      maxAllowed:
        cpu: 1
        memory: 2Gi
      minAllowed:
        cpu: 50m
        memory: 64Mi
      # Control which resources VPA manages
      controlledResources: ["cpu", "memory"]
      # Set the percentile of usage that VPA should target
      # This affects how VPA interprets usage spikes vs steady-state needs
EOF

# Monitor VPA recommendations and status
kubectl describe vpa web-app-vpa
kubectl get vpa web-app-vpa -o yaml

# Create a VPA in recommendation-only mode for safe evaluation
cat << EOF | kubectl apply -f -
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: nginx-vpa-recommend
spec:
  targetRef:
    apiVersion: v1
    kind: Pod  # Can target individual pods for testing
    name: nginx
  updatePolicy:
    updateMode: "Off"     # Only provide recommendations, don't auto-update
EOF
```

## 18.5 Resource-Aware Scheduling and Advanced Placement
Control where pods are scheduled based on resource availability and application requirements.

```bash
# Create node labels for resource-aware scheduling
kubectl label nodes <node-name> node-type=compute-intensive
kubectl label nodes <node-name> storage-type=ssd
kubectl label nodes <node-name> network-tier=high-bandwidth

# Deploy an application with sophisticated scheduling constraints
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database-cluster
spec:
  replicas: 3
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
    spec:
      # Spread pods evenly across nodes to avoid resource hotspots
      topologySpreadConstraints:
      - maxSkew: 1                          # Maximum difference in pod count between nodes
        topologyKey: kubernetes.io/hostname # Spread across individual nodes
        whenUnsatisfiable: DoNotSchedule    # Strict enforcement
        labelSelector:
          matchLabels:
            app: database
      # Advanced node selection based on resource characteristics
      affinity:
        nodeAffinity:
          # Hard requirement: must be on storage-optimized nodes
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: storage-type
                operator: In
                values: ["ssd"]
          # Soft preference: prefer high-memory nodes
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 80
            preference:
              matchExpressions:
              - key: node-type
                operator: In
                values: ["memory-optimized"]
        # Avoid scheduling multiple database pods on the same node
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: database
              topologyKey: kubernetes.io/hostname
      containers:
      - name: database
        image: postgres:13
        resources:
          requests:
            cpu: 500m        # Higher CPU request for database workload
            memory: 1Gi      # Substantial memory for caching
          limits:
            cpu: 2           # Allow CPU bursting for complex queries
            memory: 4Gi      # Generous memory limit for large datasets
        env:
        - name: POSTGRES_DB
          value: testdb
        - name: POSTGRES_USER
          value: testuser
        - name: POSTGRES_PASSWORD
          value: testpass
EOF

# Analyze scheduling decisions and constraints
kubectl get pods -l app=database -o wide
kubectl describe pods -l app=database | grep -A 10 "Node-Selectors:\|Tolerations:"
```

## 18.6 Enhanced Resource Optimization Script
This comprehensive script provides deep insights into resource utilization patterns and actionable optimization recommendations.

```bash
#!/bin/bash
# save as advanced-resource-optimizer.sh
echo "🚀 Advanced Resource Optimization Script"
echo "=========================================="

# Configuration - adjust these thresholds based on your cluster characteristics
CPU_THRESHOLD=80
MEMORY_THRESHOLD=85
EFFICIENCY_THRESHOLD=20  # Minimum efficiency percentage for resource utilization

# Function to convert resource units to comparable numbers
convert_cpu() {
    local cpu=$1
    if [[ $cpu == *"m" ]]; then
        echo ${cpu%m}
    elif [[ $cpu == *"."* ]]; then
        echo $(echo "$cpu * 1000" | bc)
    else
        echo $(echo "$cpu * 1000" | bc)
    fi
}

convert_memory() {
    local mem=$1
    if [[ $mem == *"Mi" ]]; then
        echo ${mem%Mi}
    elif [[ $mem == *"Gi" ]]; then
        echo $(echo "${mem%Gi} * 1024" | bc)
    elif [[ $mem == *"Ki" ]]; then
        echo $(echo "${mem%Ki} / 1024" | bc)
    else
        echo $mem
    fi
}

# Comprehensive node analysis
echo "🔍 Analyzing Node Resource Utilization..."
echo "----------------------------------------"
kubectl top nodes --no-headers | while read node cpu_usage cpu_percent memory_usage memory_percent; do
    cpu_num=$(echo $cpu_percent | tr -d '%')
    mem_num=$(echo $memory_percent | tr -d '%')
    
    if [ "$cpu_num" -gt "$CPU_THRESHOLD" ]; then
        echo "⚠️  HIGH CPU: Node $node is at $cpu_percent CPU usage"
        # Show top CPU consumers on this node
        kubectl top pods --all-namespaces --field-selector spec.nodeName=$node --sort-by=cpu --no-headers | head -3 | while read ns pod cpu mem; do
            echo "    └─ Top consumer: $ns/$pod ($cpu CPU)"
        done
    fi
    
    if [ "$mem_num" -gt "$MEMORY_THRESHOLD" ]; then
        echo "⚠️  HIGH MEMORY: Node $node is at $memory_percent memory usage"
        kubectl top pods --all-namespaces --field-selector spec.nodeName=$node --sort-by=memory --no-headers | head -3 | while read ns pod cpu mem; do
            echo "    └─ Top consumer: $ns/$pod ($mem memory)"
        done
    fi
    
    if [ "$cpu_num" -lt 30 ] && [ "$mem_num" -lt 30 ]; then
        echo "💡 OPTIMIZATION: Node $node is underutilized ($cpu_percent CPU, $memory_percent memory)"
        echo "    └─ Consider consolidating workloads or scaling down"
    fi
done

echo ""
echo "📊 Quality of Service Analysis..."
echo "--------------------------------"
# Analyze QoS distribution across the cluster
echo "QoS Class Distribution:"
kubectl get pods --all-namespaces -o json | jq -r '.items[] | "\(.status.qosClass // "Unknown")"' | sort | uniq -c | while read count qos; do
    echo "  $qos: $count pods"
done

echo ""
echo "🎯 Resource Efficiency Analysis..."
echo "---------------------------------"
# Identify pods with poor resource efficiency (low actual usage vs requests)
kubectl get pods --all-namespaces -o json | jq -r '
  .items[] |
  select(.spec.containers[0].resources.requests != null) |
  {
    namespace: .metadata.namespace,
    name: .metadata.name,
    cpu_request: .spec.containers[0].resources.requests.cpu,
    memory_request: .spec.containers[0].resources.requests.memory,
    node: .spec.nodeName
  } | @json
' | while read pod_data; do
    # This is a simplified efficiency calculation - in production, you'd want
    # to collect historical usage data over time for more accurate analysis
    namespace=$(echo $pod_data | jq -r '.namespace')
    name=$(echo $pod_data | jq -r '.name')
    if kubectl top pod $name -n $namespace --no-headers >/dev/null 2>&1; then
        actual_usage=$(kubectl top pod $name -n $namespace --no-headers 2>/dev/null)
        if [ ! -z "$actual_usage" ]; then
            echo "📈 Analyzing $namespace/$name efficiency..."
        fi
    fi
done

echo ""
echo "🔧 Resource Limit Recommendations..."
echo "-----------------------------------"
# Enhanced resource limit suggestions based on actual usage patterns
kubectl top pods --all-namespaces --sort-by=cpu --no-headers | head -10 | while read ns pod cpu mem node; do
    if [ ! -z "$cpu" ] && [ ! -z "$mem" ]; then
        # Get current resource specifications
        cpu_request=$(kubectl get pod $pod -n $ns -o jsonpath='{.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
        cpu_limit=$(kubectl get pod $pod -n $ns -o jsonpath='{.spec.containers[0].resources.limits.cpu}' 2>/dev/null)
        mem_request=$(kubectl get pod $pod -n $ns -o jsonpath='{.spec.containers[0].resources.requests.memory}' 2>/dev/null)
        mem_limit=$(kubectl get pod $pod -n $ns -o jsonpath='{.spec.containers[0].resources.limits.memory}' 2>/dev/null)
        
        # Extract numeric values for calculations
        cpu_num=$(echo $cpu | sed 's/m//')
        mem_num=$(echo $mem | sed 's/Mi//')
        
        # Calculate suggested values with safety margins
        suggested_cpu_request=$((cpu_num + 50))m
        suggested_cpu_limit=$((cpu_num * 2 + 100))m
        suggested_mem_request=$((mem_num + 50))Mi
        suggested_mem_limit=$((mem_num * 2 + 100))Mi
        
        echo "🔧 Pod $ns/$pod (Current: $cpu CPU, $mem memory)"
        if [ -z "$cpu_request" ]; then
            echo "    └─ Add CPU request: $suggested_cpu_request"
        fi
        if [ -z "$cpu_limit" ]; then
            echo "    └─ Add CPU limit: $suggested_cpu_limit"
        fi
        if [ -z "$mem_request" ]; then
            echo "    └─ Add memory request: $suggested_mem_request"
        fi
        if [ -z "$mem_limit" ]; then
            echo "    └─ Add memory limit: $suggested_mem_limit"
        fi
    fi
done

echo ""
echo "🛡️  Pod Disruption Budget Analysis..."
echo "------------------------------------"
# Check for deployments without PDBs
kubectl get deployments --all-namespaces -o json | jq -r '.items[] | "\(.metadata.namespace)/\(.metadata.name)"' | while read deployment; do
    ns=$(echo $deployment | cut -d'/' -f1)
    name=$(echo $deployment | cut -d'/' -f2)
    replicas=$(kubectl get deployment $name -n $ns -o jsonpath='{.spec.replicas}')
    
    if [ "$replicas" -gt 1 ]; then
        # Check if PDB exists for this deployment
        pdb_exists=$(kubectl get pdb -n $ns --no-headers 2>/dev/null | grep -E "app=$name|app\.kubernetes\.io/name=$name" | wc -l)
        if [ "$pdb_exists" -eq 0 ]; then
            echo "⚠️  Missing PDB: Deployment $ns/$name has $replicas replicas but no Pod Disruption Budget"
            echo "    └─ Recommended: Create PDB with minAvailable: $((replicas - 1))"
        fi
    fi
done

echo ""
echo "📈 Resource Quota Status..."
echo "--------------------------"
# Check resource quota utilization across namespaces
kubectl get namespaces --no-headers | while read ns status age; do
    quota_count=$(kubectl get resourcequota -n $ns --no-headers 2>/dev/null | wc -l)
    if [ "$quota_count" -eq 0 ]; then
        pod_count=$(kubectl get pods -n $ns --no-headers 2>/dev/null | wc -l)
        if [ "$pod_count" -gt 0 ]; then
            echo "⚠️  Missing ResourceQuota: Namespace $ns has $pod_count pods but no resource quota"
        fi
    else
        echo "✅ Namespace $ns has resource quotas configured"
        kubectl get resourcequota -n $ns -o custom-columns="NAME:.metadata.name,CPU-USED:.status.used.requests\.cpu,CPU-HARD:.status.hard.requests\.cpu,MEM-USED:.status.used.requests\.memory,MEM-HARD:.status.hard.requests\.memory" --no-headers 2>/dev/null
    fi
done

echo ""
echo "🎨 Optimization Summary and Next Steps..."
echo "========================================="
echo "1. Review high-usage nodes and consider workload redistribution"
echo "2. Add resource requests and limits to pods without them"
echo "3. Implement Pod Disruption Budgets for multi-replica deployments"
echo "4. Consider Vertical Pod Autoscaling for dynamic optimization"
echo "5. Add ResourceQuotas to namespaces without governance"
echo ""
echo "🧹 Cleanup commands:"
echo "kubectl delete resourcequota compute-quota -n default"
echo "kubectl delete limitrange resource-constraints -n default"
echo "kubectl delete pdb web-app-pdb"
echo "kubectl delete vpa web-app-vpa nginx-vpa-recommend"
echo ""
echo "✅ Resource optimization analysis complete!"
```

## 18.7 Production Best Practices and Advanced Patterns
Understanding these patterns will help you design resilient, efficient resource management strategies for production environments.

### Resource Management Anti-Patterns to Avoid
Learn what not to do by understanding common mistakes that can destabilize clusters.

```bash
# ANTI-PATTERN: No resource specifications (avoid this!)
# This pod can consume unlimited resources, potentially starving other workloads
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: resource-hog-example
spec:
  containers:
  - name: app
    image: nginx
    # NO resources specified - this is dangerous!
EOF

# BETTER PATTERN: Always specify at minimum resource requests
kubectl delete pod resource-hog-example
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: well-behaved-pod
spec:
  containers:
  - name: app
    image: nginx
    resources:
      requests:        # Minimum guaranteed resources
        cpu: 100m
        memory: 128Mi
      limits:          # Maximum allowed consumption
        cpu: 300m
        memory: 256Mi
EOF

# Monitor the difference in scheduling behavior
kubectl describe pod well-behaved-pod | grep -A 5 "QoS Class"
```

This enhanced guide transforms basic resource management into a comprehensive understanding of how Kubernetes orchestrates resources across your cluster. The key insight is that resource management isn't just about setting numbers - it's about creating a sustainable ecosystem where applications can coexist efficiently while maintaining reliability and performance under various conditions.

Each concept builds upon the others: resource requests and limits provide the foundation, monitoring helps you understand actual behavior, Pod Disruption Budgets ensure availability during maintenance, VPA automates optimization based on real usage patterns, and advanced scheduling ensures optimal placement across your infrastructure.

The enhanced script provides actionable insights that go beyond simple threshold monitoring - it helps you understand efficiency patterns, identify governance gaps, and make data-driven decisions about resource allocation strategies.