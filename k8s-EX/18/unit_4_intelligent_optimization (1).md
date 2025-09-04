      kill \$CPU_PID
      sleep 10
    done
    
    # Phase 3: Heavy load (10 minutes)
    echo "Phase 3: Heavy load pattern"
    for i in \$(seq 1 20); do
      echo "Heavy processing cycle \$i"
      # Simulate memory allocation
      dd if=/dev/zero of=/tmp/memory\$i bs=1M count=50 2>/dev/null &
      # Simulate CPU work
      yes > /dev/null &
      CPU_PID=\$!
      sleep 15
      kill \$CPU_PID
      rm -f /tmp/memory\$i
      sleep 15
    done
    
    # Phase 4: Return to light load
    echo "Phase 4: Cooling down..."
    for i in \$(seq 1 60); do
      echo "Cool down cycle \$i"
      sleep 10
    done
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: variable-workload
  labels:
    purpose: vpa-optimization
spec:
  replicas: 2
  selector:
    matchLabels:
      app: variable-workload
  template:
    metadata:
      labels:
        app: variable-workload
    spec:
      containers:
      - name: workload
        image: alpine:latest
        command: ["/bin/sh"]
        args: ["/scripts/simulate-load.sh"]
        resources:
          requests:
            cpu: 100m      # Starting conservative
            memory: 128Mi
          limits:
            cpu: 300m      # Room for growth
            memory: 512Mi
        volumeMounts:
        - name: scripts
          mountPath: /scripts
      volumes:
      - name: scripts
        configMap:
          name: workload-simulator
          defaultMode: 0755
EOF

# Wait for workload to start
kubectl rollout status deployment/variable-workload
```

### Lab Step 2: Implement Progressive VPA Strategy

```bash
# Strategy 1: Start with recommendation-only VPA
cat << EOF | kubectl apply -f -
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: variable-workload-vpa
  namespace: optimization-lab
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: variable-workload
  updatePolicy:
    updateMode: "Off"    # Recommendation mode only
  resourcePolicy:
    containerPolicies:
    - containerName: workload
      maxAllowed:
        cpu: 2
        memory: 4Gi
      minAllowed:
        cpu: 50m
        memory: 64Mi
      controlledResources: ["cpu", "memory"]
      # Configure how VPA interprets usage patterns
      controlledValues: RequestsAndLimits
EOF

# Monitor VPA learning over time
echo "VPA is now learning usage patterns..."
echo "Monitor recommendations with: kubectl describe vpa variable-workload-vpa"
```

Let's create a monitoring script to track VPA's learning:

```bash
cat << 'EOF' > monitor-vpa-learning.sh
#!/bin/bash
echo "📊 VPA Learning Progress Monitor"
echo "==============================="

DURATION=${1:-1200}  # Default 20 minutes
INTERVAL=60         # Check every minute

END_TIME=$(($(date +%s) + $DURATION))

while [ $(date +%s) -lt $END_TIME ]; do
  timestamp=$(date '+%H:%M:%S')
  echo "=== $timestamp ==="
  
  # Current resource usage
  echo "Current usage:"
  kubectl top pods -l app=variable-workload --no-headers 2>/dev/null | while read pod cpu memory; do
    echo "  $pod: CPU=$cpu, Memory=$memory"
  done
  
  # VPA recommendations
  echo "VPA recommendations:"
  kubectl get vpa variable-workload-vpa -o jsonpath='{.status.recommendation.containerRecommendations[0]}' 2>/dev/null | jq -r 'if . then "  Target: CPU=\(.target.cpu), Memory=\(.target.memory)" else "  No recommendations yet" end'
  
  # Current specifications
  echo "Current specs:"
  kubectl get deployment variable-workload -o jsonpath='{.spec.template.spec.containers[0].resources}' | jq -r '"  Requests: CPU=\(.requests.cpu), Memory=\(.requests.memory)"'
  
  echo "---"
  sleep $INTERVAL
done

echo "VPA learning monitoring complete"
EOF

chmod +x monitor-vpa-learning.sh

# Start monitoring (this will run for 20 minutes by default)
# ./monitor-vpa-learning.sh 600  # Run for 10 minutes
```

### Lab Step 3: Analyze VPA Recommendations

After VPA has collected data for a while (10-15 minutes), let's analyze its recommendations:

```bash
# Detailed VPA analysis
cat << 'EOF' > analyze-vpa-recommendations.sh
#!/bin/bash
VPA_NAME=${1:-variable-workload-vpa}
NAMESPACE=${2:-optimization-lab}

echo "🤖 VPA RECOMMENDATION ANALYSIS"
echo "==============================="

# Get current VPA status
echo "📊 VPA STATUS OVERVIEW"
echo "---------------------"
kubectl get vpa $VPA_NAME -n $NAMESPACE -o yaml | yq eval '.status' -

echo ""
echo "🎯 DETAILED RECOMMENDATIONS"
echo "---------------------------"
kubectl get vpa $VPA_NAME -n $NAMESPACE -o json | jq -r '
  if .status.recommendation then
    .status.recommendation.containerRecommendations[] | 
    "Container: \(.containerName)
     Target CPU: \(.target.cpu)
     Target Memory: \(.target.memory)
     Lower Bound CPU: \(.lowerBound.cpu)
     Lower Bound Memory: \(.lowerBound.memory)
     Upper Bound CPU: \(.upperBound.cpu)
     Upper Bound Memory: \(.upperBound.memory)"
  else
    "No recommendations available yet"
  end
'

# Compare with current specifications
echo ""
echo "📋 CURRENT vs RECOMMENDED"
echo "-------------------------"
current_cpu_req=$(kubectl get deployment variable-workload -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}')
current_mem_req=$(kubectl get deployment variable-workload -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}')

recommended_cpu=$(kubectl get vpa $VPA_NAME -n $NAMESPACE -o jsonpath='{.status.recommendation.containerRecommendations[0].target.cpu}' 2>/dev/null)
recommended_mem=$(kubectl get vpa $VPA_NAME -n $NAMESPACE -o jsonpath='{.status.recommendation.containerRecommendations[0].target.memory}' 2>/dev/null)

echo "Current CPU Request: $current_cpu_req"
echo "Recommended CPU: $recommended_cpu"
echo "Current Memory Request: $current_mem_req" 
echo "Recommended Memory: $recommended_mem"

echo ""
echo "💡 OPTIMIZATION INSIGHTS"
echo "------------------------"
if [[ ! -z "$recommended_cpu" ]]; then
  echo "✅ VPA has generated recommendations"
  echo "🔍 Review recommendations for optimization opportunities"
  echo "⚠️  Test changes in non-production first"
else
  echo "⏳ VPA still collecting data - check again in a few minutes"
fi
EOF

chmod +x analyze-vpa-recommendations.sh
./analyze-vpa-recommendations.sh
```

**🤔 Analysis Questions**:
1. How do VPA's recommendations compare to your initial resource specifications?
2. What patterns do you see in the upper bound, target, and lower bound recommendations?
3. Based on the workload phases, do the recommendations make sense?

### Lab Step 4: Implementing Auto-Scaling VPA

Once you're confident in VPA's recommendations, you can enable automatic updates:

```bash
# CAUTION: This will restart pods to apply new resource specifications
# Only use in development/testing environments initially

cat << EOF | kubectl apply -f -
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: variable-workload-vpa-auto
  namespace: optimization-lab
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: variable-workload
  updatePolicy:
    updateMode: "Auto"    # Enable automatic updates!
    # minReplicas: 2      # Ensure minimum availability during updates
  resourcePolicy:
    containerPolicies:
    - containerName: workload
      maxAllowed:
        cpu: 2
        memory: 4Gi
      minAllowed:
        cpu: 50m
        memory: 64Mi
      controlledResources: ["cpu", "memory"]
      controlledValues: RequestsAndLimits
EOF

# Monitor automatic updates
echo "⚡ VPA Auto-Update Enabled!"
echo "Monitor pod restarts and resource changes..."

# Watch for pod recreation
kubectl get events --field-selector reason=Killing -w &
EVENTS_PID=$!

# Monitor resource specification changes
watch -n 30 'kubectl describe deployment variable-workload | grep -A 5 "Limits:\|Requests:"' &
WATCH_PID=$!

echo "Monitoring automatic VPA updates..."
echo "Press Ctrl+C to stop monitoring"
sleep 300  # Monitor for 5 minutes

kill $EVENTS_PID $WATCH_PID 2>/dev/null
```

**⚠️ Important VPA Considerations**:
- VPA restarts pods to apply new resource specifications
- Consider using `updateMode: "Initial"` for workloads that can't handle restarts
- Always set resource boundaries to prevent excessive scaling
- Test VPA behavior in non-production environments first

---

## 🎯 Advanced Resource-Aware Scheduling

Beyond VPA, let's explore intelligent pod placement based on resource characteristics.

### Step 1: Node Resource Labeling Strategy

```bash
# Label nodes based on their resource characteristics
# (Adapt these commands to your actual nodes)

# Get node information to plan labeling
kubectl get nodes -o custom-columns="NAME:.metadata.name,CPU:.status.capacity.cpu,MEMORY:.status.capacity.memory,STORAGE:.status.capacity.ephemeral-storage"

# Label nodes based on resource profiles (example - adapt to your cluster)
# kubectl label nodes <node-name> node-type=cpu-optimized
# kubectl label nodes <node-name> node-type=memory-optimized  
# kubectl label nodes <node-name> node-type=balanced
# kubectl label nodes <node-name> storage-type=ssd
# kubectl label nodes <node-name> storage-type=hdd

# For demo purposes, we'll create a comprehensive scheduling example
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-aware-app
  namespace: optimization-lab
spec:
  replicas: 4
  selector:
    matchLabels:
      app: resource-aware-app
  template:
    metadata:
      labels:
        app: resource-aware-app
        workload-type: compute-intensive
    spec:
      # Advanced scheduling constraints
      affinity:
        nodeAffinity:
          # Prefer nodes with specific resource characteristics
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 80
            preference:
              matchExpressions:
              - key: node-type
                operator: In
                values: ["cpu-optimized", "balanced"]
          - weight: 60
            preference:
              matchExpressions:
              - key: storage-type
                operator: In
                values: ["ssd"]
        # Spread pods for resource distribution
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  workload-type: compute-intensive
              topologyKey: kubernetes.io/hostname
      # Advanced resource distribution
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: resource-aware-app
      containers:
      - name: app
        image: nginx:alpine
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 1
            memory: 512Mi
EOF

# Analyze the scheduling decisions
kubectl get pods -l app=resource-aware-app -o wide
```

**🤔 Scheduling Analysis Questions**:
1. How are the pods distributed across your nodes?
2. What would happen if you scaled this deployment to 10 replicas?
3. How do the scheduling constraints affect resource utilization?

### Step 2: Priority-Based Resource Allocation

```bash
# Create priority classes for different workload types
cat << EOF | kubectl apply -f -
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: critical-workload
value: 1000000
globalDefault: false
description: "Critical business workloads"
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: important-workload  
value: 100000
globalDefault: false
description: "Important business workloads"
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: standard-workload
value: 1000
globalDefault: true
description: "Standard workloads"
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: batch-workload
value: 100
globalDefault: false
description: "Batch processing workloads"
EOF

# Deploy applications with different priorities
cat << EOF | kubectl apply -f -
# Critical application - highest priority
apiVersion: apps/v1
kind: Deployment
metadata:
  name: critical-service
  namespace: optimization-lab
spec:
  replicas: 2
  selector:
    matchLabels:
      app: critical-service
  template:
    metadata:
      labels:
        app: critical-service
        priority: critical
    spec:
      priorityClassName: critical-workload
      containers:
      - name: service
        image: nginx:alpine
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            cpu: 1
            memory: 2Gi
---
# Batch processing - lowest priority  
apiVersion: apps/v1
kind: Deployment
metadata:
  name: batch-processor
  namespace: optimization-lab
spec:
  replicas: 3
  selector:
    matchLabels:
      app: batch-processor
  template:
    metadata:
      labels:
        app: batch-processor
        priority: batch
    spec:
      priorityClassName: batch-workload
      containers:
      - name: processor
        image: busybox
        command: ["sh", "-c", "while true; do echo 'Processing batch job...'; sleep 60; done"]
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 2
            memory: 4Gi
EOF

# Check scheduling behavior
kubectl get pods -o custom-columns="NAME:.metadata.name,PRIORITY:.spec.priorityClassName,NODE:.spec.nodeName,STATUS:.status.phase"
```

**🎯 Priority Scheduling Insights**:
- Higher priority pods can preempt lower priority pods if resources are scarce
- This ensures critical workloads get resources when needed
- Use sparingly - too many high-priority workloads defeats the purpose

---

## 🚀 Advanced Lab: Intelligent Resource Ecosystem

Let's build a complete intelligent resource management system that combines all the concepts.

### Lab Scenario: AI Platform Resource Management

You're building a Kubernetes platform for an AI company with these workload types:
- **Training Jobs**: Resource-intensive, bursty, can be preempted
- **Inference Services**: Steady resource needs, high availability required  
- **Data Processing**: Variable resource needs, cost-sensitive
- **Web Services**: User-facing, performance-critical

### Lab Step 1: Workload Classification System

```bash
# Create workload-specific optimization policies
mkdir -p intelligent-optimization
cd intelligent-optimization

# Training workload VPA configuration
cat << EOF > training-vpa-policy.yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: training-job-vpa
  namespace: optimization-lab
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: training-job
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
    - containerName: trainer
      maxAllowed:
        cpu: 8          # Allow high CPU for training
        memory: 32Gi    # Large memory for datasets
      minAllowed:
        cpu: 500m
        memory: 1Gi
      controlledResources: ["cpu", "memory"]
      # Training can handle restarts, so allow aggressive optimization
      controlledValues: RequestsAndLimits
EOF

# Inference service VPA configuration  
cat << EOF > inference-vpa-policy.yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: inference-service-vpa
  namespace: optimization-lab
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: inference-service
  updatePolicy:
    updateMode: "Initial"    # Only optimize on initial deployment
  resourcePolicy:
    containerPolicies:
    - containerName: inference
      maxAllowed:
        cpu: 4
        memory: 8Gi
      minAllowed:
        cpu: 200m
        memory: 512Mi
      controlledResources: ["cpu", "memory"]
      # Be conservative with inference services
      controlledValues: RequestsOnly
EOF

# Apply the VPA policies
kubectl apply -f training-vpa-policy.yaml
kubectl apply -f inference-vpa-policy.yaml
```

### Lab Step 2: Deploy Workload-Specific Applications

```bash
# Training job deployment
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: training-job
  namespace: optimization-lab
  labels:
    workload-type: training
spec:
  replicas: 1
  selector:
    matchLabels:
      app: training-job
  template:
    metadata:
      labels:
        app: training-job
        workload-type: training
    spec:
      priorityClassName: batch-workload
      # Training can run anywhere, prefer high-resource nodes
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: node-type
                operator: In
                values: ["cpu-optimized", "memory-optimized"]
      containers:
      - name: trainer
        image: python:3.9-slim
        command: ["python", "-c"]
        args:
        - |
          import time
          import random
          
          print("Starting AI training simulation...")
          for epoch in range(100):
            print(f"Training epoch {epoch+1}/100")
            # Simulate variable resource usage
            work_intensity = random.uniform(0.1, 2.0)
            time.sleep(30 * work_intensity)
            
            # Simulate memory allocation for batch processing
            data = [0] * (int(1000000 * work_intensity))
            time.sleep(10)
            del data
        resources:
          requests:
            cpu: 500m      # Conservative starting point
            memory: 1Gi
          limits:
            cpu: 4
            memory: 8Gi
---
# Inference service deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inference-service
  namespace: optimization-lab
  labels:
    workload-type: inference
spec:
  replicas: 3
  selector:
    matchLabels:
      app: inference-service
  template:
    metadata:
      labels:
        app: inference-service
        workload-type: inference
    spec:
      priorityClassName: important-workload
      # Inference needs consistent performance
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: inference-service
              topologyKey: kubernetes.io/hostname
      containers:
      - name: inference
        image: nginx:alpine
        resources:
          requests:
            cpu: 200m      # Steady, predictable load
            memory: 512Mi
          limits:
            cpu: 1
            memory: 2Gi
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /
            port: 80
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /
            port: 80
          periodSeconds: 30
EOF

# Wait for deployments
kubectl rollout status deployment/training-job -n optimization-lab
kubectl rollout status deployment/inference-service -n optimization-lab
```

### Lab Step 3: Comprehensive Resource Monitoring Dashboard

```bash
# Create an intelligent monitoring system
cat << 'EOF' > intelligent-resource-monitor.sh
#!/bin/bash
echo "🤖 INTELLIGENT RESOURCE OPTIMIZATION DASHBOARD"
echo "=============================================="
echo "Generated: $(date)"
echo ""

NAMESPACE="optimization-lab"

# VPA Status Analysis
echo "📊 VPA OPTIMIZATION STATUS"
echo "--------------------------"
kubectl get vpa -n $NAMESPACE -o custom-columns="NAME:.metadata.name,MODE:.spec.updatePolicy.updateMode,LAST-UPDATE:.status.lastUpdateTime" 2>/dev/null || echo "No VPA configurations found"

echo ""
echo "🎯 OPTIMIZATION RECOMMENDATIONS"
echo "------------------------------"
vpas=($(kubectl get vpa -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}' 2>/dev/null))

for vpa in "${vpas[@]}"; do
  echo "=== $vpa ==="
  kubectl get vpa $vpa -n $NAMESPACE -o json | jq -r '
    if .status.recommendation then
      .status.recommendation.containerRecommendations[] | 
      "Container: \(.containerName)
       Current CPU: \(.target.cpu)
       Current Memory: \(.target.memory)
       Confidence: \(.upperBound.cpu != .lowerBound.cpu | if . then "Variable" else "Stable" end)"
    else
      "No recommendations yet - VPA still learning"
    end
  '
  echo ""
done

# Resource efficiency analysis
echo "⚡ RESOURCE EFFICIENCY ANALYSIS"
echo "------------------------------"
echo "Workload resource utilization vs requests:"

kubectl top pods -n $NAMESPACE --no-headers 2>/dev/null | while read pod cpu memory; do
  if [ ! -z "$cpu" ] && [ ! -z "$memory" ]; then
    # Get workload type and resource requests
    workload_type=$(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.metadata.labels.workload-type}' 2>/dev/null)
    cpu_request=$(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
    memory_request=$(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.spec.containers[0].resources.requests.memory}' 2>/dev/null)
    
    echo "📱 $pod ($workload_type)"
    echo "   Usage: CPU=$cpu, Memory=$memory"
    echo "   Requests: CPU=$cpu_request, Memory=$memory_request"
    
    # Calculate efficiency (simplified)
    if [[ "$cpu" == *"m" ]] && [[ "$cpu_request" == *"m" ]]; then
      current_cpu=${cpu%m}
      requested_cpu=${cpu_request%m}
      if [ "$requested_cpu" -gt 0 ]; then
        efficiency=$((current_cpu * 100 / requested_cpu))
        if [ "$efficiency" -gt 80 ]; then
          echo "   🔥 High CPU utilization ($efficiency%)"
        elif [ "$efficiency" -lt 30 ]; then
          echo "   💡 Low CPU utilization ($efficiency%) - optimization opportunity"
        else
          echo "   ✅ Good CPU utilization ($efficiency%)"
        fi
      fi
    fi
    echo ""
  fi
done

# Scheduling optimization analysis
echo "🎲 SCHEDULING OPTIMIZATION STATUS"
echo "--------------------------------"
echo "Pod distribution across nodes:"
kubectl get pods -n $NAMESPACE -o custom-columns="POD:.metadata.name,NODE:.spec.nodeName,PRIORITY:.spec.priorityClassName" | sort -k2

echo ""
echo "💡 OPTIMIZATION RECOMMENDATIONS"
echo "------------------------------"
echo "1. Monitor VPA recommendations for 24-48 hours before applying"
echo "2. Consider workload patterns when choosing VPA update modes"
echo "3. Review scheduling constraints for optimal resource distribution"
echo "4. Validate that priority classes align with business requirements"
echo ""
EOF

chmod +x intelligent-resource-monitor.sh
./intelligent-resource-monitor.sh
```

### Lab Step 4: Automated Optimization Decisions

```bash
# Create a script that makes intelligent optimization decisions
cat << 'EOF' > auto-optimization-engine.sh
#!/bin/bash
echo "🤖 AUTOMATED RESOURCE OPTIMIZATION ENGINE"
echo "========================================"

NAMESPACE="optimization-lab"

# Function to analyze VPA recommendations and make decisions
analyze_vpa_recommendations() {
  local vpa_name=$1
  echo "Analyzing VPA: $vpa_name"
  
  # Get current recommendations
  local recommendation=$(kubectl get vpa $vpa_name -n $NAMESPACE -o json 2>/dev/null | jq -r '.status.recommendation.containerRecommendations[0] // empty')
  
  if [ ! -z "$recommendation" ]; then
    # Parse recommendations
    local target_cpu=$(echo $recommendation | jq -r '.target.cpu')
    local target_memory=$(echo $recommendation | jq -r '.target.memory')
    local lower_cpu=$(echo $recommendation | jq -r '.lowerBound.cpu')
    local upper_cpu=$(echo $recommendation | jq -r '.upperBound.cpu')
    
    echo "  Target: CPU=$target_cpu, Memory=$target_memory"
    echo "  CPU Range: $lower_cpu - $upper_cpu"
    
    # Calculate confidence based on range spread
    if [[ "$lower_cpu" == "$upper_cpu" ]]; then
      echo "  ✅ High confidence recommendation - stable usage pattern"
      return 0
    else
      echo "  ⚠️  Variable usage pattern - monitor longer before applying"
      return 1
    fi
  else
    echo "  ⏳ Insufficient data for recommendations"
    return 2
  fi
}

# Function to check resource waste
check_resource_waste() {
  echo ""
  echo "🔍 RESOURCE WASTE DETECTION"
  echo "---------------------------"
  
  kubectl top pods -n $NAMESPACE --no-headers 2>/dev/null | while read pod cpu memory; do
    if [ ! -z "$cpu" ] && [ ! -z "$memory" ]; then
      cpu_request=$(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
      
      # Simple waste detection logic
      if [[ "$cpu" == *"m" ]] && [[ "$cpu_request" == *"m" ]]; then
        current_cpu=${cpu%m}
        requested_cpu=${cpu_request%m}
        
        if [ "$requested_cpu" -gt 0 ]; then
          efficiency=$((current_cpu * 100 / requested_cpu))
          if [ "$efficiency" -lt 25 ]; then
            echo "  💰 WASTE DETECTED: $pod using only $efficiency% of requested CPU"
            echo "     Consider reducing CPU request from $cpu_request to ${current_cpu}m"
          fi
        fi
      fi
    fi
  done
}

# Function to suggest scheduling optimizations
suggest_scheduling_optimizations() {
  echo ""
  echo "🎯 SCHEDULING OPTIMIZATION SUGGESTIONS"
  echo "------------------------------------"
  
  # Check for uneven pod distribution
  node_counts=$(kubectl get pods -n $NAMESPACE -o custom-columns="NODE:.spec.nodeName" --no-headers | sort | uniq -c)
  echo "Current pod distribution:"
  echo "$node_counts"
  
  # Simple analysis - in production, you'd use more sophisticated logic
  max_pods=$(echo "$node_counts" | awk '{print $1}' | sort -nr | head -1)
  min_pods=$(echo "$node_counts" | awk '{print $1}' | sort -n | head -1)
  
  if [ $((max_pods - min_pods)) -gt 2 ]; then
    echo "  ⚖️  Uneven distribution detected - consider topology spread constraints"
  else
    echo "  ✅ Good pod distribution"
  fi
}

# Main optimization analysis
echo "Starting automated optimization analysis..."
echo ""

# Analyze all VPAs
echo "📊 VPA RECOMMENDATION ANALYSIS"
echo "-----------------------------"
vpas=($(kubectl get vpa -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}' 2>/dev/null))

high_confidence_count=0
for vpa in "${vpas[@]}"; do
  if analyze_vpa_recommendations $vpa; then
    ((high_confidence_count++))
  fi
  echo ""
done

# Check for resource waste
check_resource_waste

# Suggest scheduling improvements
suggest_scheduling_optimizations

# Summary and recommendations
echo ""
echo "🎯 AUTOMATED OPTIMIZATION SUMMARY"
echo "================================"
echo "VPAs with high-confidence recommendations: $high_confidence_count/${#vpas[@]}"
echo ""
echo "🤖 NEXT ACTIONS:"
if [ $high_confidence_count -gt 0 ]; then
  echo "✅ Apply VPA recommendations for stable workloads"
fi
echo "📊 Continue monitoring variable workloads"  
echo "💰 Investigate resource waste opportunities"
echo "⚖️  Review scheduling constraints for better distribution"
echo ""
EOF

chmod +x auto-optimization-engine.sh
./auto-optimization-engine.sh
```

**🎯 Advanced Challenge Questions**:
1. How would you validate that VPA's recommendations actually improve performance?
2. What metrics would you use to measure the success of your optimization efforts?
3. How would you handle workloads that have seasonal or time-based usage patterns?

---

## 🧠 Unit 4 Assessment

### Complex Scenario Challenges

**Scenario 1: The Black Friday Optimization**
Your e-commerce platform experiences 10x traffic during Black Friday. Your current VPA configurations optimized for normal traffic levels. How would you:
1. Prepare your VPA policies for the traffic spike?
2. Ensure critical services get resources during peak demand?
3. Automatically scale back resources after the event?

**Scenario 2: The Multi-Tenant AI Platform**
You're running an AI platform with training jobs, inference services, and batch processing. Different teams have different SLAs and cost budgets. Design an optimization strategy that:
1. Prioritizes inference services for real-time performance
2. Allows training jobs to use spare resources efficiently
3. Ensures fair resource allocation between teams

**Scenario 3: The Cost Optimization Challenge**
Your CFO wants to reduce Kubernetes costs by 40% without impacting performance. Using intelligent optimization, how would you:
1. Identify the biggest opportunities for resource savings?
2. Implement gradual optimization while monitoring performance impact?
3. Prove that your optimizations don't degrade user experience?

### Hands-On Skills Verification

Can you confidently:

✅ **VPA Management**
- [ ] Configure VPA in different modes (Off, Initial, Auto) appropriately
- [ ] Set proper resource boundaries and controlled values
- [ ] Interpret VPA recommendations and make optimization decisions
- [ ] Troubleshoot VPA issues and conflicts

✅ **Advanced Scheduling**  
- [ ] Design node affinity rules for optimal resource utilization
- [ ] Implement pod anti-affinity for resource distribution
- [ ] Use topology spread constraints effectively
- [ ] Configure priority classes for workload prioritization

✅ **Optimization Strategy**
- [ ] Build monitoring systems for resource optimization insights
- [ ] Create automated decision engines for resource adjustments
- [ ] Design workload-specific optimization policies
- [ ] Validate optimization results through performance metrics

---

## 🚀 Mini-Project: Complete Intelligent Platform

Your final challenge: Build a comprehensive intelligent resource optimization platform.

### Project Requirements

**Business Context**: TechScale Inc.
- Multi-tenant SaaS platform
- Mixed workload types (web, API, ML, batch)
- Cost optimization goals while maintaining performance
- Need for automated resource management

### Project Deliverables

**1. Workload Classification and VPA Strategy**
```bash
# Create a comprehensive VPA strategy document
cat << 'EOF' > vpa-strategy.md
# TechScale VPA Strategy

## Workload Classifications

### Tier 1: Mission Critical (updateMode: "Initial")
- **Web Frontend**: User-facing, can't tolerate restarts
- **API Gateway**: High availability requirement
- **Payment Processing**: Zero downtime tolerance

### Tier 2: Business Important (updateMode: "Auto" with constraints)  
- **Microservices**: Can handle rolling restarts
- **Data Processing**: Batch jobs that can restart
- **Analytics Services**: Important but not user-facing

### Tier 3: Development/Testing (updateMode: "Auto" aggressive)
- **Dev Environments**: Optimization over availability
- **Test Workloads**: Can handle frequent restarts
- **Experimental Services**: Cost optimization priority

## VPA Configuration Templates

### Template 1: Mission Critical
```yaml
spec:
  updatePolicy:
    updateMode: "Initial"
  resourcePolicy:
    containerPolicies:
    - controlledResources: ["memory"]  # Only optimize memory
      controlledValues: RequestsOnly   # Conservative approach
      maxAllowed:
        memory: 4Gi                   # Reasonable upper bound
      minAllowed:
        memory: 512Mi                 # Ensure minimum performance
```

### Template 2: Business Important
```yaml
spec:
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
    - controlledResources: ["cpu", "memory"]
      controlledValues: RequestsAndLimits
      maxAllowed:
        cpu: 2
        memory: 8Gi
      minAllowed:
        cpu: 100m
        memory: 128Mi
```

## Implementation Phases

### Phase 1: Observation (Week 1-2)
- Deploy VPAs in "Off" mode for all workloads
- Collect 2 weeks of usage data
- Analyze recommendation patterns

### Phase 2: Conservative Optimization (Week 3-4)
- Apply "Initial" mode VPAs to non-critical workloads
- Monitor impact on performance metrics
- Validate cost savings

### Phase 3: Advanced Optimization (Week 5-6)  
- Enable "Auto" mode for appropriate workloads
- Implement custom optimization logic
- Full automation with safety guardrails

EOF
```

**2. Advanced Scheduling Architecture**
```bash
# Create intelligent scheduling policies
cat << EOF > intelligent-scheduling.yaml
# Node classification labels (apply to your actual nodes)
# kubectl label nodes node-1 workload-optimized=web
# kubectl label nodes node-2 workload-optimized=compute
# kubectl label nodes node-3 workload-optimized=memory

---
# Priority Classes for different service tiers
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: mission-critical
value: 1000000
globalDefault: false
description: "Mission critical services - highest priority"
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: business-important
value: 100000
globalDefault: false
description: "Business important services"
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: development
value: 1000
globalDefault: true
description: "Development and testing workloads"
---
# Example: Web frontend with intelligent scheduling
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-frontend-optimized
  namespace: optimization-lab
spec:
  replicas: 6
  selector:
    matchLabels:
      app: web-frontend
  template:
    metadata:
      labels:
        app: web-frontend
        tier: mission-critical
    spec:
      priorityClassName: mission-critical
      # Intelligent node placement
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 80
            preference:
              matchExpressions:
              - key: workload-optimized
                operator: In
                values: ["web", "balanced"]
          - weight: 60
            preference:
              matchExpressions:
              - key: kubernetes.io/arch
                operator: In
                values: ["amd64"]
        # Spread across failure domains
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app: web-frontend
            topologyKey: kubernetes.io/hostname
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  tier: mission-critical
              topologyKey: failure-domain.beta.kubernetes.io/zone
      # Advanced topology spread
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: web-frontend
      - maxSkew: 2
        topologyKey: failure-domain.beta.kubernetes.io/zone
        whenUnsatisfiable: ScheduleAnyway
        labelSelector:
          matchLabels:
            tier: mission-critical
      containers:
      - name: web
        image: nginx:alpine
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 1
            memory: 1Gi
EOF

kubectl apply -f intelligent-scheduling.yaml
```

**3. Comprehensive Monitoring and Automation**
```bash
# Create the ultimate resource optimization monitoring system
cat << 'EOF' > ultimate-optimization-monitor.sh
#!/bin/bash

echo "🚀 TECHSCALE INTELLIGENT RESOURCE OPTIMIZATION PLATFORM"
echo "======================================================"
echo "Platform Status Report - $(date)"
echo ""

NAMESPACE="optimization-lab"

# Function to calculate cost savings
calculate_cost_savings() {
  echo "💰 COST OPTIMIZATION ANALYSIS"
  echo "----------------------------"
  
  local total_original_cpu=0
  local total_optimized_cpu=0
  local total_original_memory=0
  local total_optimized_memory=0
  
  # This would connect to your cloud provider's pricing API in production
  local cpu_cost_per_core_hour=0.05  # Example: $0.05 per CPU core hour
  local memory_cost_per_gb_hour=0.01 # Example: $0.01 per GB hour
  
  echo "Analyzing resource optimization impact..."
  
  # Get VPA recommendations vs current specs
  vpas=($(kubectl get vpa -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}' 2>/dev/null))
  
  for vpa in "${vpas[@]}"; do
    local target_ref=$(kubectl get vpa $vpa -n $NAMESPACE -o jsonpath='{.spec.targetRef.name}')
    local recommendation=$(kubectl get vpa $vpa -n $NAMESPACE -o json 2>/dev/null | jq -r '.status.recommendation.containerRecommendations[0] // empty')
    
    if [ ! -z "$recommendation" ]; then
      local current_cpu=$(kubectl get deployment $target_ref -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
      local recommended_cpu=$(echo $recommendation | jq -r '.target.cpu')
      
      echo "  $target_ref:"
      echo "    Current CPU: $current_cpu"  
      echo "    Recommended CPU: $recommended_cpu"
      
      # Calculate potential savings (simplified)
      if [[ "$current_cpu" == *"m" ]] && [[ "$recommended_cpu" == *"m" ]]; then
        local current_cpu_num=${current_cpu%m}
        local recommended_cpu_num=${recommended_cpu%m}
        local savings_cpu=$((current_cpu_num - recommended_cpu_num))
        
        if [ $savings_cpu -gt 0 ]; then
          echo "    💡 Potential CPU savings: ${savings_cpu}m per pod"
        fi
      fi
    fi
  done
  
  echo ""
  echo "📊 Estimated monthly savings: \$XXX (implement with real pricing data)"
}

# Function to analyze performance impact
analyze_performance_impact() {
  echo "📈 PERFORMANCE IMPACT ANALYSIS"
  echo "-----------------------------"
  
  # In production, this would connect to your APM/metrics system
  echo "Analyzing performance metrics after optimization..."
  
  # Check for any performance degradation indicators
  kubectl get events -n $NAMESPACE --field-selector type=Warning --field-selector reason=FailedScheduling | head -5
  
  echo "Performance metrics to monitor:"
  echo "  ✅ Response time: Baseline vs optimized"
  echo "  ✅ Error rate: Should remain stable"  
  echo "  ✅ Resource utilization: Should improve efficiency"
  echo "  ✅ Pod restart frequency: Monitor for stability"
  echo ""
}

# Function to provide intelligent recommendations
generate_recommendations() {
  echo "🤖 INTELLIGENT OPTIMIZATION RECOMMENDATIONS"
  echo "=========================================="
  
  # Analyze cluster resource utilization patterns
  echo "📊 Cluster Resource Analysis:"
  kubectl top nodes --no-headers | while read node cpu cpu_pct memory memory_pct; do
    cpu_num=$(echo $cpu_pct | tr -d '%')
    mem_num=$(echo $memory_pct | tr -d '%')
    
    if [ $cpu_num -lt 30 ] && [ $mem_num -lt 30 ]; then
      echo "  🔧 Node $node is underutilized - consider workload consolidation"
    elif [ $cpu_num -gt 80 ] || [ $mem_num -gt 80 ]; then
      echo "  ⚠️  Node $node is highly utilized - monitor for resource pressure"
    fi
  done
  
  echo ""
  echo "🎯 Strategic Recommendations:"
  echo "  1. Enable VPA 'Auto' mode for stable workloads showing consistent patterns"
  echo "  2. Implement HPA alongside VPA for workloads with traffic variations"
  echo "  3. Review priority classes to ensure critical workloads get resources first"
  echo "  4. Consider cluster autoscaling for dynamic resource provisioning"
  echo "  5. Implement resource quotas to prevent resource abuse"
  echo ""
  
  # Generate workload-specific recommendations
  echo "📱 Workload-Specific Recommendations:"
  kubectl get deployments -n $NAMESPACE -o json | jq -r '.items[] | "\(.metadata.name),\(.metadata.labels // {})"' | while IFS=',' read name labels; do
    echo "  $name:"
    
    # Check if VPA exists
    if kubectl get vpa ${name}-vpa -n $NAMESPACE >/dev/null 2>&1; then
      echo "    ✅ VPA configured"
    else
      echo "    💡 Consider implementing VPA for automated optimization"
    fi
    
    # Check for resource specifications
    local cpu_request=$(kubectl get deployment $name -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
    if [ -z "$cpu_request" ]; then
      echo "    ⚠️  No CPU requests specified - add resource specifications"
    fi
    
    echo ""
  done
}

# Function to generate executive summary
generate_executive_summary() {
  echo "📋 EXECUTIVE SUMMARY"
  echo "==================="
  
  local total_pods=$(kubectl get pods -n $NAMESPACE --no-headers | wc -l)
  local total_deployments=$(kubectl get deployments -n $NAMESPACE --no-headers | wc -l)
  local total_vpas=$(kubectl get vpa -n $NAMESPACE --no-headers 2>/dev/null | wc -l)
  
  echo "Platform Overview:"
  echo "  • Total Deployments: $total_deployments"
  echo "  • Total Pods: $total_pods"
  echo "  • VPA Configurations: $total_vpas"
  echo ""
  
  echo "Optimization Status:"
  if [ $total_vpas -gt 0 ]; then
    echo "  ✅ Intelligent optimization enabled"
    echo "  📊 VPA learning from usage patterns"
    echo "  💰 Cost optimization in progress"
  else
    echo "  ⚠️  No VPA configurations found"
    echo "  💡 Implement VPA for automated optimization"
  fi
  echo ""
  
  echo "Key Achievements:"
  echo "  • Automated resource right-sizing"
  echo "  • Intelligent workload placement"  
  echo "  • Performance-aware optimization"
  echo "  • Cost reduction through efficiency"
  echo ""
  
  echo "Next Steps:"
  echo "  1. Monitor VPA recommendations for 48 hours"
  echo "  2. Apply optimization to non-critical workloads first"  
  echo "  3. Measure performance impact and cost savings"
  echo "  4. Gradually expand optimization to all workloads"
}

# Main execution
calculate_cost_savings
echo ""
analyze_performance_impact
echo ""
generate_recommendations
echo ""
generate_executive_summary

echo ""
echo "🎯 Report completed - save for stakeholder review"
echo "Next analysis in 24 hours for trend monitoring"
EOF

chmod +x ultimate-optimization-monitor.sh
./ultimate-optimization-monitor.sh
```

**4. Project Validation and Testing**
```bash
# Create comprehensive testing scenarios
cat << 'EOF' > optimization-testing-suite.sh
#!/bin/bash
echo "🧪 INTELLIGENT OPTIMIZATION TESTING SUITE"
echo "========================================"

NAMESPACE="optimization-lab"

# Test 1: VPA Recommendation Accuracy
test_vpa_accuracy() {
  echo "TEST 1: VPA Recommendation Accuracy"
  echo "-----------------------------------"
  
  # Create a controlled workload with known resource patterns
  kubectl apply -f - << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-predictable-load
  namespace: $NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-predictable
  template:
    metadata:
      labels:
        app: test-predictable
    spec:
      containers:
      - name: load
        image: busybox
        command: ["sh", "-c", "while true; do echo 'Stable load'; sleep 1; done"]
        resources:
          requests:
            cpu: 500m    # Intentionally over-provisioned
            memory: 1Gi
          limits:
            cpu: 1
            memory: 2Gi
EOF

  # Create VPA for the test workload
  kubectl apply -f - << EOF
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: test-predictable-load-vpa
  namespace: $NAMESPACE
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: test-predictable-load
  updatePolicy:
    updateMode: "Off"
EOF

  echo "✅ Test workload created - monitor VPA recommendations"
  echo "Expected: VPA should recommend lower CPU/memory after learning"
}

# Test 2: Priority-based Scheduling
test_priority_scheduling() {
  echo ""
  echo "TEST 2: Priority-based Scheduling"
  echo "---------------------------------"
  
  # Create high and low priority workloads
  kubectl apply -f - << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: high-priority-test
  namespace: $NAMESPACE
spec:
  replicas: 2
  selector:
    matchLabels:
      app: high-priority-test
  template:
    metadata:
      labels:
        app: high-priority-test
    spec:
      priorityClassName: mission-critical
      containers:
      - name: app
        image: nginx:alpine
        resources:
          requests:
            cpu: 1
            memory: 2Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: low-priority-test
  namespace: $NAMESPACE
spec:
  replicas: 3
  selector:
    matchLabels:
      app: low-priority-test
  template:
    metadata:
      labels:
        app: low-priority-test
    spec:
      priorityClassName: development
      containers:
      - name: app
        image: nginx:alpine
        resources:
          requests:
            cpu: 1
            memory: 2Gi
EOF

  echo "✅ Priority test workloads created"
  echo "Expected: High priority pods should be scheduled first"
  
  # Check scheduling results
  sleep 10
  echo "Scheduling results:"
  kubectl get pods -n $NAMESPACE -l app=high-priority-test -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName"
  kubectl get pods -n $NAMESPACE -l app=low-priority-test -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName"
}

# Test 3: Resource Efficiency Validation
test_resource_efficiency() {
  echo ""
  echo "TEST 3: Resource Efficiency Validation"
  echo "--------------------------------------"
  
  echo "Measuring current resource efficiency..."
  
  # Calculate cluster-wide efficiency
  local total_requested_cpu=0
  local total_used_cpu=0
  
  kubectl get pods -n $NAMESPACE -o json | jq -r '.items[] | select(.spec.containers[0].resources.requests.cpu) | "\(.metadata.name),\(.spec.containers[0].resources.requests.cpu)"' | while IFS=',' read pod_name cpu_request; do
    if [[ "$cpu_request" == *"m" ]]; then
      requested_cpu=${cpu_request%m}
      echo "Pod $pod_name requests ${requested_cpu}m CPU"
      total_requested_cpu=$((total_requested_cpu + requested_cpu))
    fi
  done
  
  echo "Total CPU requested across test workloads: ${total_requested_cpu}m"
  echo "Monitor actual usage and compare for efficiency metrics"
}

# Test 4: Optimization Impact on Performance
test_performance_impact() {
  echo ""
  echo "TEST 4: Performance Impact Assessment"  
  echo "------------------------------------"
  
  # In a real environment, you'd measure actual application metrics
  echo "Performance metrics to validate:"
  echo "  • Application response times"
  echo "  • Request success rates"
  echo "  • Resource utilization efficiency"
  echo "  • Pod restart frequency"
  
  # Check for any performance-related events
  kubectl get events -n $NAMESPACE --field-selector type=Warning | grep -E "(FailedScheduling|Evicted|OOMKilled)" | head -5
  
  echo "✅ Monitor these metrics before and after optimization"
}

# Run all tests
test_vpa_accuracy
test_priority_scheduling
test_resource_efficiency
test_performance_impact

echo ""
echo "🎯 TESTING SUITE COMPLETED"
echo "========================="
echo "• All test workloads deployed"
echo "• Monitor for 24-48 hours to collect data"
echo "• Validate VPA recommendations match expectations"
echo "• Confirm priority scheduling works as designed"
echo "• Measure efficiency improvements"
echo ""
echo "Clean up test workloads:"
echo "kubectl delete deployment test-predictable-load high-priority-test low-priority-test -n $NAMESPACE"
EOF

chmod +x optimization-testing-suite.sh
./optimization-testing-suite.sh
```

### Project Success Metrics

Your intelligent optimization platform should achieve:

**Efficiency Metrics**:
- ✅ 30%+ reduction in over-provisioned resources
- ✅ <5% performance degradation from optimization
- ✅ 90%+ of workloads have appropriate resource specifications
- ✅ Automated optimization recommendations within 24 hours

**Operational Metrics**:  
- ✅ Zero manual resource tuning required for stable workloads
- ✅ Critical workloads always get resources during contention
- ✅ Resource violations detected and corrected automatically
- ✅ Cost optimization reports generated automatically

**Business Metrics**:
- ✅ 25%+ reduction in infrastructure costs
- ✅ No customer-facing performance issues from optimization
- ✅ Improved resource planning accuracy
- ✅ Faster time-to-market for new applications

---

## 📝 Unit 4 Wrap-Up

### Intelligent Optimization Mastery

**Reflect on your learning:**

1. **What's the most powerful aspect of intelligent resource optimization you discovered?**

2. **How would you explain VPA's value to a business stakeholder focused on costs?**

3. **What's one optimization insight that surprised you and will change how you manage resources?**

### Advanced Concepts Mastered

You can now:
- **Design VPA strategies** for different workload types and risk tolerances
- **Implement resource-aware scheduling** that optimizes for both performance and efficiency  
- **Build automation systems** that make intelligent optimization decisions
- **Measure and validate** optimization impact on both costs and performance
- **Create comprehensive platforms** that combine all optimization techniques

### Bridge to Unit 5

In Unit 5, we'll explore production patterns and troubleshooting - the real-world challenges you'll face when operating optimized systems at scale. Think about:

- How would you handle optimization failures in production?
- What happens when VPA conflicts with application behavior?
- How do you maintain optimization effectiveness as your cluster grows?

The intelligent systems you've built here will be the foundation for production-ready resource management.

---

## 🧹 Lab Cleanup

```bash
# Clean up optimization lab resources
kubectl delete namespace optimization-lab

# Clean up project files
rm -rf intelligent-optimization
rm -f monitor-vpa-learning.sh analyze-vpa-recommendations.sh intelligent-resource-monitor.sh
rm -f auto-optimization-engine.sh ultimate-optimization-monitor.sh optimization-testing-suite.sh
rm -f vpa-strategy.md intelligent-scheduling.yaml
```

**🎊 Incredible Achievement!** You've mastered intelligent resource optimization in Kubernetes. You can now build automated systems that continuously optimize resource allocation while maintaining performance and respecting governance policies.

Ready for Unit 5? We'll explore production patterns, advanced troubleshooting, and how to maintain optimized systems at enterprise scale!# Unit 4: Intelligent Resource Optimization
**Duration**: 3-4 hours  
**Core Question**: "How can I automate resource optimization based on actual usage patterns?"

## 🎯 Learning Objectives
By the end of this unit, you will:
- Configure and manage Vertical Pod Autoscaler (VPA) for automatic resource optimization
- Implement resource-aware scheduling with advanced node selection
- Use topology spread constraints for optimal resource distribution
- Design custom resource optimization strategies
- Build automated systems that adapt to changing resource patterns

## 🔄 Building on Previous Units

You've learned to set resources (Unit 1), monitor them (Unit 2), and govern them (Unit 3). But manually adjusting resources based on changing usage patterns is time-consuming and error-prone.

**🤔 Reflection Questions**:
- How often do you think you should review and adjust resource specifications?
- What if your application's resource needs change seasonally or based on user growth?
- How could you automatically right-size resources while maintaining the governance policies you've established?

Today we'll explore intelligent systems that can optimize resources automatically while respecting your governance boundaries.

---

## 🤖 Foundation: Understanding Automation Layers

### Step 1: The Resource Optimization Stack

```bash
# Set up our optimization lab environment
kubectl create namespace optimization-lab
kubectl config set-context --current --namespace=optimization-lab

# Create a baseline application that we'll optimize
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-app
  labels:
    purpose: vpa-demo
spec:
  replicas: 3
  selector:
    matchLabels:
      app: sample-app
  template:
    metadata:
      labels:
        app: sample-app
    spec:
      containers:
      - name: app
        image: nginx:alpine
        resources:
          requests:
            cpu: 100m      # Intentionally conservative starting point
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
        ports:
        - containerPort: 80
EOF

# Wait for deployment
kubectl rollout status deployment/sample-app
```

**🎯 Current State Analysis**:
Let's establish our baseline before implementing optimization:

```bash
# Check initial resource specifications
kubectl describe deployment sample-app | grep -A 10 "Containers:"

# Monitor current usage (we'll compare this after VPA)
kubectl top pods -l app=sample-app
```

### Step 2: Understanding VPA Components

Before implementing VPA, let's understand what it does:

```bash
# Check if VPA is available in your cluster
kubectl get crd | grep verticalpodautoscaler

# If VPA CRDs exist, check for VPA controller pods
kubectl get pods -n kube-system | grep vpa

# Note: If VPA isn't installed, you'll need to install it
# For learning purposes, we'll show you what VPA would do
```

**💡 VPA Overview**:
- **VPA Recommender**: Analyzes resource usage and generates recommendations
- **VPA Updater**: Implements resource changes by recreating pods  
- **VPA Admission Controller**: Applies updated resource specs to new pods

### Step 3: Your First VPA Configuration

```bash
# Create a VPA in recommendation-only mode first (safest approach)
cat << EOF | kubectl apply -f -
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: sample-app-vpa
  namespace: optimization-lab
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: sample-app
  updatePolicy:
    updateMode: "Off"    # Start with recommendations only
  resourcePolicy:
    containerPolicies:
    - containerName: app
      # Set boundaries for VPA recommendations
      maxAllowed:
        cpu: 1
        memory: 2Gi
      minAllowed:
        cpu: 50m
        memory: 32Mi
      # Control which resources VPA manages
      controlledResources: ["cpu", "memory"]
      # Set the percentile for recommendations (higher = more conservative)
      controlledValues: RequestsAndLimits
EOF

# Check VPA status and recommendations
kubectl describe vpa sample-app-vpa
```

**🤔 Understanding VPA Output**:
Look for the `Status` section in the VPA description:
- **Target**: Current resource recommendations
- **Last Recommendation Time**: When VPA last updated its suggestions
- **Conditions**: Any issues VPA encountered

---

## 🧪 Guided Lab: VPA Optimization Journey

Let's create a realistic workload with changing resource patterns and optimize it with VPA.

### Lab Step 1: Create a Variable Workload

```bash
# Create an application with variable resource usage patterns
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: workload-simulator
data:
  simulate-load.sh: |
    #!/bin/sh
    echo "Starting workload simulation..."
    
    # Phase 1: Light load (5 minutes)
    echo "Phase 1: Light load pattern"
    for i in \$(seq 1 30); do
      echo "Light processing cycle \$i"
      sleep 10
    done
    
    # Phase 2: Medium load (5 minutes)  
    echo "Phase 2: Medium load pattern"
    for i in \$(seq 1 15); do
      echo "Medium processing cycle \$i"
      # Simulate some CPU work
      yes > /dev/null &
      CPU_PID=\$!
      sleep 10
      kill \$CPU_