# Unit 2: Resource Monitoring & Analysis
**Duration**: 2-3 hours  
**Core Question**: "How do I know if my applications are using resources efficiently?"

## 🎯 Learning Objectives
By the end of this unit, you will:
- Monitor real-time resource usage across nodes and pods
- Identify patterns of resource waste and bottlenecks
- Create actionable insights from resource metrics
- Build your own resource analysis toolkit

## 🔄 Connecting from Unit 1

In Unit 1, you learned to set resource requests and limits. But how do you know if those specifications are optimal? 

**🤔 Reflection Question**: Think back to your mini-project in Unit 1. When you right-sized the "wasteful-app", how did you decide what the "correct" resource values should be? What information did you need but wish you had more of?

Today we'll explore the monitoring tools that help you make data-driven decisions about resource allocation.

---

## 📊 Foundation: Understanding Resource Metrics

### Step 1: The Kubernetes Metrics Landscape

Before diving into tools, let's understand what we're measuring:

```bash
# Set up our lab environment
kubectl create namespace monitoring-lab
kubectl config set-context --current --namespace=monitoring-lab

# First, let's see what metrics are available
kubectl top nodes
kubectl top pods --all-namespaces
```

**🤔 Discovery Questions**: 
- What information does `kubectl top` show you?
- What information is it NOT showing you that might be useful?
- Why might the command fail in some clusters?

Let's create some workload to monitor:

```bash
# Create a simple application that we can observe
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: monitoring-demo
  labels:
    purpose: monitoring-practice
spec:
  replicas: 3
  selector:
    matchLabels:
      app: demo-app
  template:
    metadata:
      labels:
        app: demo-app
    spec:
      containers:
      - name: app
        image: nginx:alpine
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
        ports:
        - containerPort: 80
EOF

# Wait for pods to be ready
kubectl rollout status deployment/monitoring-demo
```

### Step 2: Basic Resource Monitoring

Now let's explore the basic monitoring commands:

```bash
# Monitor node resources
kubectl top nodes --sort-by=cpu
kubectl top nodes --sort-by=memory

# Monitor pod resources
kubectl top pods
kubectl top pods --sort-by=cpu
kubectl top pods --sort-by=memory

# Get more detailed information
kubectl describe nodes | grep -A 5 "Allocated resources"
```

**🔍 Investigation Challenge**: Run these commands and then answer:
1. Which node has the highest CPU utilization percentage?
2. Are any of your demo pods using close to their CPU or memory limits?
3. How much total cluster capacity is currently unused?

### Step 3: Understanding Resource Efficiency

Let's create a more interesting workload to analyze:

```bash
# Create workloads with different resource patterns
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: workload-scripts
data:
  cpu-burster.sh: |
    #!/bin/sh
    while true; do
      echo "CPU burst starting..."
      yes > /dev/null &
      PID=\$!
      sleep 10
      kill \$PID
      echo "CPU burst ending, cooling down..."
      sleep 20
    done
  memory-grower.sh: |
    #!/bin/sh
    echo "Gradually increasing memory usage..."
    for i in 1 2 3 4 5; do
      echo "Allocation phase \$i"
      dd if=/dev/zero of=/tmp/memory\$i bs=1M count=20 2>/dev/null
      sleep 30
    done
    echo "Holding memory, sleeping..."
    sleep 300
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cpu-burster
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cpu-burster
  template:
    metadata:
      labels:
        app: cpu-burster
        pattern: bursty-cpu
    spec:
      containers:
      - name: burster
        image: alpine:latest
        command: ["/bin/sh"]
        args: ["/scripts/cpu-burster.sh"]
        resources:
          requests:
            cpu: 100m
            memory: 32Mi
          limits:
            cpu: 400m  # Allow significant bursting
            memory: 64Mi
        volumeMounts:
        - name: scripts
          mountPath: /scripts
      volumes:
      - name: scripts
        configMap:
          name: workload-scripts
          defaultMode: 0755
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: memory-grower
spec:
  replicas: 1
  selector:
    matchLabels:
      app: memory-grower
  template:
    metadata:
      labels:
        app: memory-grower
        pattern: growing-memory
    spec:
      containers:
      - name: grower
        image: alpine:latest
        command: ["/bin/sh"]
        args: ["/scripts/memory-grower.sh"]
        resources:
          requests:
            cpu: 50m
            memory: 32Mi
          limits:
            cpu: 100m
            memory: 150Mi
        volumeMounts:
        - name: scripts
          mountPath: /scripts
      volumes:
      - name: scripts
        configMap:
          name: workload-scripts
          defaultMode: 0755
EOF

# Wait for the workloads to start
sleep 10
```

Now let's monitor these different patterns:

```bash
# Monitor the workloads over time
echo "Monitoring resource patterns - press Ctrl+C to stop"
while true; do
  echo "=== $(date) ==="
  kubectl top pods -l pattern=bursty-cpu
  kubectl top pods -l pattern=growing-memory
  echo "---"
  sleep 15
done
```

**🤔 Pattern Recognition Questions**:
After observing for a few minutes:
1. How does the CPU usage of the burster compare to its requests and limits?
2. What trend do you see in the memory grower's usage?
3. Based on these patterns, how would you adjust their resource specifications?

---

## 🔬 Guided Lab: Building Your Resource Analysis Toolkit

Let's create a comprehensive analysis script that gives you deeper insights than basic `kubectl top` commands.

### Lab Step 1: Resource Utilization Analysis

```bash
# Create a comprehensive resource analysis script
cat << 'EOF' > resource-analyzer.sh
#!/bin/bash
echo "🔍 Kubernetes Resource Analysis Report"
echo "======================================"
echo "Report generated at: $(date)"
echo ""

# Node analysis
echo "📊 NODE RESOURCE OVERVIEW"
echo "-------------------------"
echo "Node resources (CPU/Memory):"
kubectl top nodes --no-headers | while read node cpu cpu_pct memory memory_pct; do
    echo "  $node: $cpu_pct CPU, $memory_pct Memory"
done
echo ""

# Cluster capacity analysis
echo "🏗️ CLUSTER CAPACITY ANALYSIS"
echo "-----------------------------"
total_cpu_requests=0
total_memory_requests=0

echo "Resource requests by namespace:"
kubectl get pods --all-namespaces -o json | jq -r '
  .items[] | 
  select(.spec.containers[0].resources.requests != null) |
  {
    namespace: .metadata.namespace,
    cpu: (.spec.containers[0].resources.requests.cpu // "0"),
    memory: (.spec.containers[0].resources.requests.memory // "0")
  }
' | while read line; do
    echo "  Processing: $line"
done

echo ""

# Pod efficiency analysis
echo "⚡ RESOURCE EFFICIENCY ANALYSIS"
echo "-------------------------------"
echo "Pods with concerning resource patterns:"

kubectl top pods --all-namespaces --no-headers 2>/dev/null | while read ns pod cpu memory; do
    if [ ! -z "$cpu" ] && [ ! -z "$memory" ]; then
        # Get resource specs
        cpu_request=$(kubectl get pod $pod -n $ns -o jsonpath='{.spec.containers[0].resources.requests.cpu}' 2>/dev/null || echo "none")
        cpu_limit=$(kubectl get pod $pod -n $ns -o jsonpath='{.spec.containers[0].resources.limits.cpu}' 2>/dev/null || echo "none")
        
        if [[ "$cpu_request" == "none" ]]; then
            echo "  ⚠️  $ns/$pod: No CPU request specified (using $cpu)"
        fi
    fi
done

echo ""
echo "📈 RECOMMENDATIONS"
echo "------------------"
echo "1. Check pods without resource specifications"
echo "2. Review high-usage pods for right-sizing opportunities"
echo "3. Consider resource quotas for namespaces with many unspecified pods"
echo ""
EOF

chmod +x resource-analyzer.sh
./resource-analyzer.sh
```

**🤔 Analysis Questions**:
1. What insights does this script provide that `kubectl top` alone doesn't?
2. Which pods in your cluster would you investigate further based on this report?
3. What additional metrics would make this analysis more complete?

### Lab Step 2: Deep-Dive Pod Investigation

Let's create tools to investigate specific pods in detail:

```bash
# Create a pod investigation script
cat << 'EOF' > investigate-pod.sh
#!/bin/bash
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <namespace> <pod-name>"
    exit 1
fi

NAMESPACE=$1
POD=$2

echo "🔍 Deep Analysis: $NAMESPACE/$POD"
echo "=================================="

# Basic info
echo "📋 POD STATUS"
kubectl get pod $POD -n $NAMESPACE -o wide

echo ""
echo "💾 RESOURCE SPECIFICATIONS"
kubectl get pod $POD -n $NAMESPACE -o json | jq -r '
  .spec.containers[] | 
  {
    name: .name,
    requests: .resources.requests,
    limits: .resources.limits
  }
' | jq .

echo ""
echo "📊 CURRENT USAGE"
kubectl top pod $POD -n $NAMESPACE --containers 2>/dev/null || echo "Metrics not available"

echo ""
echo "🎯 QOS CLASS"
kubectl get pod $POD -n $NAMESPACE -o jsonpath='{.status.qosClass}'
echo ""

echo ""
echo "📅 RECENT EVENTS"
kubectl describe pod $POD -n $NAMESPACE | grep -A 10 "Events:" || echo "No recent events"

echo ""
echo "💡 ANALYSIS"
echo "----------"

# Get resource specs for analysis
cpu_request=$(kubectl get pod $POD -n $NAMESPACE -o jsonpath='{.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
memory_request=$(kubectl get pod $POD -n $NAMESPACE -o jsonpath='{.spec.containers[0].resources.requests.memory}' 2>/dev/null)

if [ -z "$cpu_request" ]; then
    echo "⚠️  No CPU request specified - pod may be deprioritized"
else
    echo "✅ CPU request: $cpu_request"
fi

if [ -z "$memory_request" ]; then
    echo "⚠️  No memory request specified - scheduling may be unpredictable"
else
    echo "✅ Memory request: $memory_request"
fi
EOF

chmod +x investigate-pod.sh

# Test it on one of our demo pods
pod_name=$(kubectl get pods -l app=demo-app -o jsonpath='{.items[0].metadata.name}')
./investigate-pod.sh monitoring-lab $pod_name
```

**🎯 Challenge Question**: Based on the investigation output, if you had to explain this pod's resource configuration to a teammate, what would you tell them? What questions would you ask the application developer?

### Lab Step 3: Historical Pattern Analysis

```bash
# Create a script to track resource usage over time
cat << 'EOF' > resource-tracker.sh
#!/bin/bash
DURATION=${1:-300}  # Default 5 minutes
INTERVAL=${2:-30}   # Default 30 seconds

echo "📈 Resource Usage Tracker"
echo "========================"
echo "Tracking for $DURATION seconds, sampling every $INTERVAL seconds"
echo "Press Ctrl+C to stop early"
echo ""

END_TIME=$(($(date +%s) + $DURATION))
echo "Timestamp,Pod,CPU,Memory" > resource-usage.csv

while [ $(date +%s) -lt $END_TIME ]; do
    timestamp=$(date '+%H:%M:%S')
    echo "--- $timestamp ---"
    
    kubectl top pods --no-headers 2>/dev/null | while read pod cpu memory; do
        echo "  $pod: CPU=$cpu, Memory=$memory"
        echo "$timestamp,$pod,$cpu,$memory" >> resource-usage.csv
    done
    
    sleep $INTERVAL
done

echo ""
echo "📊 Data saved to resource-usage.csv"
echo "💡 You can analyze patterns with:"
echo "   - Sort by CPU: sort -t, -k3 -n resource-usage.csv"
echo "   - Filter by pod: grep '<pod-name>' resource-usage.csv"
EOF

chmod +x resource-tracker.sh

# Run a short tracking session (2 minutes)
./resource-tracker.sh 120 20
```

**🔍 Data Analysis Challenge**: 
1. Look at the generated CSV file. What patterns do you notice?
2. Which pods show the most variation in resource usage?
3. How would you use this data to improve resource specifications?

---

## 🧠 Advanced Monitoring Concepts

### Step 1: Resource Events and Troubleshooting

Let's create scenarios to understand resource-related events:

```bash
# Create a pod that will definitely hit memory limits
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: memory-limit-test
  labels:
    purpose: troubleshooting
spec:
  containers:
  - name: memory-hog
    image: polinux/stress
    command: ["stress"]
    args: ["--vm", "1", "--vm-bytes", "200M", "--timeout", "60s"]
    resources:
      requests:
        memory: 50Mi
      limits:
        memory: 100Mi  # Less than the 200M the app tries to allocate
EOF

# Monitor what happens
kubectl get events --field-selector involvedObject.name=memory-limit-test -w &
EVENT_PID=$!

# Wait and then kill the watcher
sleep 70
kill $EVENT_PID
```

**🤔 Forensic Questions**:
1. What events did you see for this pod?
2. How long did it take for Kubernetes to detect and respond to the limit violation?
3. How would you distinguish between an application bug and incorrect resource limits?

### Step 2: Node Resource Pressure

```bash
# Check node conditions related to resource pressure
kubectl describe nodes | grep -A 5 -B 5 "Conditions:"

# Look specifically for resource pressure indicators
kubectl get nodes -o json | jq -r '
  .items[] | 
  {
    node: .metadata.name,
    conditions: [
      .status.conditions[] | 
      select(.type == "MemoryPressure" or .type == "DiskPressure") |
      {type: .type, status: .status}
    ]
  }
'
```

**🎯 Prediction Exercise**: If a node shows "MemoryPressure=True", what do you think would happen to:
1. New pod scheduling requests?
2. Existing BestEffort pods?
3. Existing Guaranteed pods?

---

## 🚀 Mini-Project: Resource Optimization Dashboard

Your challenge is to create a comprehensive resource monitoring solution:

### Project Requirements

Create a monitoring dashboard that answers these business questions:
1. "Are we wasting money on over-provisioned resources?"
2. "Which applications are at risk of performance issues due to resource constraints?"
3. "How much more workload can our cluster handle before we need to scale?"

### Project Setup

```bash
# Create a mixed workload to optimize
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: optimization-project
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-frontend
  namespace: optimization-project
spec:
  replicas: 4
  selector:
    matchLabels:
      app: web-frontend
  template:
    metadata:
      labels:
        app: web-frontend
        tier: frontend
    spec:
      containers:
      - name: web
        image: nginx:alpine
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-backend
  namespace: optimization-project
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api-backend
  template:
    metadata:
      labels:
        app: api-backend
        tier: backend
    spec:
      containers:
      - name: api
        image: httpd:alpine
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 800m
            memory: 256Mi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: worker-queue
  namespace: optimization-project
spec:
  replicas: 2
  selector:
    matchLabels:
      app: worker-queue
  template:
    metadata:
      labels:
        app: