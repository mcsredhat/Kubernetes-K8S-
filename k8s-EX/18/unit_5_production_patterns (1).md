      volumes:
      - name: scripts
        configMap:
          name: production-scenarios
          defaultMode: 0755
EOF

# Wait for deployments to stabilize
kubectl rollout status deployment/web-frontend -n prod-simulation
kubectl rollout status deployment/api-backend -n prod-simulation
kubectl rollout status deployment/database-service -n prod-simulation
```

**🎯 Production Baseline Assessment**:
```bash
# Create a production health check script
cat << 'EOF' > prod-health-check.sh
#!/bin/bash
echo "🏥 PRODUCTION HEALTH CHECK"
echo "========================="
echo "Timestamp: $(date)"
echo ""

NAMESPACE="prod-simulation"

# Check deployment status
echo "📊 DEPLOYMENT STATUS"
echo "-------------------"
kubectl get deployments -n $NAMESPACE -o custom-columns="NAME:.metadata.name,READY:.status.readyReplicas/.spec.replicas,UPDATED:.status.updatedReplicas,AVAILABLE:.status.availableReplicas"

echo ""
echo "🔍 RESOURCE UTILIZATION"
echo "----------------------"
kubectl top pods -n $NAMESPACE 2>/dev/null || echo "Metrics not available yet"

echo ""
echo "⚠️  RECENT EVENTS"
echo "----------------"
kubectl get events -n $NAMESPACE --field-selector type=Warning --sort-by='.lastTimestamp' | tail -10

echo ""
echo "💡 QUICK INSIGHTS"
echo "----------------"
# Check for resource pressure indicators
warning_events=$(kubectl get events -n $NAMESPACE --field-selector type=Warning --no-headers | wc -l)
if [ $warning_events -gt 5 ]; then
  echo "  🚨 High warning event count: $warning_events"
else
  echo "  ✅ Warning event count acceptable: $warning_events"
fi

# Check pod restart counts
high_restarts=$(kubectl get pods -n $NAMESPACE --no-headers | awk '$4 > 3 {print $1}')
if [ ! -z "$high_restarts" ]; then
  echo "  🔄 Pods with high restart counts:"
  echo "$high_restarts" | sed 's/^/    /'
else
  echo "  ✅ Pod restart counts normal"
fi
EOF

chmod +x prod-health-check.sh
./prod-health-check.sh
```

---

## 🔧 Production Troubleshooting Patterns

### Pattern 1: The Resource Starvation Detective

When applications perform poorly, resource constraints are often the culprit. Let's build a systematic approach to diagnose resource starvation:

```bash
# Create a comprehensive resource starvation diagnostic tool
cat << 'EOF' > resource-starvation-detective.sh
#!/bin/bash
echo "🕵️ RESOURCE STARVATION DETECTIVE"
echo "==============================="

NAMESPACE=${1:-prod-simulation}
POD_NAME=${2}

if [ -z "$POD_NAME" ]; then
  echo "Usage: $0 <namespace> [pod-name]"
  echo "If no pod name provided, will analyze entire namespace"
fi

# Function to analyze a specific pod
analyze_pod() {
  local pod=$1
  local ns=$2
  
  echo "🔍 ANALYZING POD: $pod"
  echo "------------------------"
  
  # Get basic pod info
  local status=$(kubectl get pod $pod -n $ns -o jsonpath='{.status.phase}')
  local qos=$(kubectl get pod $pod -n $ns -o jsonpath='{.status.qosClass}')
  local node=$(kubectl get pod $pod -n $ns -o jsonpath='{.spec.nodeName}')
  
  echo "Status: $status | QoS: $qos | Node: $node"
  
  # Check resource specifications
  echo ""
  echo "📋 RESOURCE SPECIFICATIONS"
  kubectl get pod $pod -n $ns -o json | jq -r '
    .spec.containers[] | 
    "Container: \(.name)
     CPU Request: \(.resources.requests.cpu // "none")
     CPU Limit: \(.resources.limits.cpu // "none")
     Memory Request: \(.resources.requests.memory // "none")
     Memory Limit: \(.resources.limits.memory // "none")"
  '
  
  # Check current resource usage
  echo ""
  echo "📊 CURRENT USAGE"
  kubectl top pod $pod -n $ns --containers 2>/dev/null || echo "Usage metrics not available"
  
  # Check for resource-related events
  echo ""
  echo "⚠️  RESOURCE-RELATED EVENTS"
  kubectl describe pod $pod -n $ns | grep -A 5 -B 5 -i "insufficient\|evicted\|oom\|failed\|resource"
  
  # Check node resource availability
  echo ""
  echo "🖥️  NODE RESOURCE STATUS"
  if [ ! -z "$node" ]; then
    kubectl describe node $node | grep -A 10 "Allocated resources:"
  fi
  
  # Analysis and recommendations
  echo ""
  echo "💡 ANALYSIS & RECOMMENDATIONS"
  echo "----------------------------"
  
  # Check if pod has no resource requests
  local cpu_request=$(kubectl get pod $pod -n $ns -o jsonpath='{.spec.containers[0].resources.requests.cpu}')
  if [ -z "$cpu_request" ]; then
    echo "  🚨 CRITICAL: No CPU requests specified"
    echo "     Impact: Pod may be deprioritized during resource contention"
    echo "     Action: Add appropriate CPU requests"
  fi
  
  # Check for potential memory issues
  if kubectl describe pod $pod -n $ns | grep -q "OOMKilled"; then
    echo "  🚨 MEMORY ISSUE: Pod was killed due to out-of-memory"
    echo "     Impact: Application crashes, data loss possible"
    echo "     Action: Increase memory limits or investigate memory leaks"
  fi
  
  # Check for scheduling issues
  if kubectl describe pod $pod -n $ns | grep -q "FailedScheduling"; then
    echo "  🚨 SCHEDULING ISSUE: Pod cannot be scheduled"
    echo "     Impact: Application unavailable"
    echo "     Action: Check node resources, taints, and affinity rules"
  fi
  
  echo ""
}

# Function to analyze namespace-wide issues
analyze_namespace() {
  local ns=$1
  
  echo "🌐 NAMESPACE-WIDE ANALYSIS: $ns"
  echo "================================"
  
  # Get resource quota status
  echo "📊 RESOURCE QUOTA STATUS"
  kubectl describe resourcequota -n $ns 2>/dev/null || echo "No resource quotas configured"
  
  echo ""
  echo "🎯 TOP RESOURCE CONSUMERS"
  echo "------------------------"
  kubectl top pods -n $ns --sort-by=cpu --no-headers 2>/dev/null | head -5 | while read pod cpu memory; do
    echo "CPU: $pod ($cpu)"
  done
  
  echo ""
  kubectl top pods -n $ns --sort-by=memory --no-headers 2>/dev/null | head -5 | while read pod cpu memory; do
    echo "Memory: $pod ($memory)"
  done
  
  echo ""
  echo "🚨 PROBLEMATIC PODS"
  echo "------------------"
  
  # Find pods in problematic states
  kubectl get pods -n $ns --field-selector=status.phase!=Running --no-headers 2>/dev/null | while read pod ready status restarts age; do
    echo "❌ $pod: $status (restarts: $restarts)"
  done
  
  # Find pods with high restart counts
  kubectl get pods -n $ns --no-headers | awk '$4 > 5 {print "🔄 " $1 ": " $4 " restarts"}'
  
  # Check for evicted pods
  kubectl get pods -n $ns --field-selector=status.phase=Failed --no-headers 2>/dev/null | while read pod ready status restarts age; do
    reason=$(kubectl get pod $pod -n $ns -o jsonpath='{.status.reason}')
    if [ "$reason" = "Evicted" ]; then
      echo "🚫 $pod: Evicted (check node resources)"
    fi
  done
}

# Main analysis logic
if [ ! -z "$POD_NAME" ]; then
  analyze_pod $POD_NAME $NAMESPACE
else
  analyze_namespace $NAMESPACE
  
  echo ""
  echo "🔍 DETAILED POD ANALYSIS"
  echo "========================"
  kubectl get pods -n $NAMESPACE --no-headers | while read pod ready status restarts age; do
    if [[ "$status" != "Running" ]] || [[ "$restarts" -gt "3" ]]; then
      analyze_pod $pod $NAMESPACE
      echo "----------------------------------------"
    fi
  done
fi

echo ""
echo "✅ RESOURCE STARVATION ANALYSIS COMPLETE"
echo "======================================="
echo "Next steps:"
echo "1. Address critical issues identified above"
echo "2. Monitor resource usage trends over 24-48 hours"  
echo "3. Consider implementing resource quotas and limits if not present"
echo "4. Review application resource requirements with development teams"
EOF

chmod +x resource-starvation-detective.sh

# Test the detective tool
./resource-starvation-detective.sh prod-simulation
```

### Pattern 2: The VPA Conflict Resolver

VPA doesn't always play nicely with applications. Let's create tools to detect and resolve VPA-related issues:

```bash
# Create VPA conflict detection and resolution tools
cat << 'EOF' > vpa-conflict-resolver.sh
#!/bin/bash
echo "⚖️ VPA CONFLICT RESOLVER"
echo "======================"

NAMESPACE=${1:-prod-simulation}

# Function to detect VPA conflicts
detect_vpa_conflicts() {
  echo "🔍 DETECTING VPA CONFLICTS"
  echo "-------------------------"
  
  vpas=($(kubectl get vpa -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}' 2>/dev/null))
  
  if [ ${#vpas[@]} -eq 0 ]; then
    echo "No VPA configurations found in namespace $NAMESPACE"
    return
  fi
  
  for vpa in "${vpas[@]}"; do
    echo "=== VPA: $vpa ==="
    
    # Get target deployment
    local target_ref=$(kubectl get vpa $vpa -n $NAMESPACE -o jsonpath='{.spec.targetRef.name}')
    local update_mode=$(kubectl get vpa $vpa -n $NAMESPACE -o jsonpath='{.spec.updatePolicy.updateMode}')
    
    echo "Target: $target_ref | Mode: $update_mode"
    
    # Check for conflicting configurations
    echo "🚨 POTENTIAL CONFLICTS:"
    
    # Conflict 1: VPA with HPA
    if kubectl get hpa -n $NAMESPACE --no-headers 2>/dev/null | grep -q $target_ref; then
      echo "  ❌ CRITICAL: VPA conflicts with HPA on $target_ref"
      echo "     Impact: Unpredictable scaling behavior"
      echo "     Resolution: Use VPA for vertical scaling OR HPA for horizontal scaling, not both"
    fi
    
    # Conflict 2: VPA recommendations outside LimitRange bounds
    local recommendation=$(kubectl get vpa $vpa -n $NAMESPACE -o json 2>/dev/null | jq -r '.status.recommendation.containerRecommendations[0] // empty')
    if [ ! -z "$recommendation" ]; then
      local target_cpu=$(echo $recommendation | jq -r '.target.cpu')
      local target_memory=$(echo $recommendation | jq -r '.target.memory')
      
      # Check against LimitRange (simplified check)
      if kubectl get limitrange -n $NAMESPACE --no-headers 2>/dev/null | grep -q .; then
        echo "  ⚠️  WARNING: Check VPA recommendations against LimitRange constraints"
        echo "     VPA recommends: CPU=$target_cpu, Memory=$target_memory"
        echo "     Verify these values are within LimitRange bounds"
      fi
    fi
    
    # Conflict 3: VPA with applications that don't handle restarts well
    local restart_count=$(kubectl get pods -l app=$target_ref -n $NAMESPACE --no-headers 2>/dev/null | awk '{sum+=$4} END {print sum}')
    if [ ! -z "$restart_count" ] && [ "$restart_count" -gt 20 ]; then
      echo "  ⚠️  WARNING: High restart count ($restart_count) detected"
      echo "     Cause: VPA 'Auto' mode restarts pods to apply resource changes"
      echo "     Resolution: Consider 'Initial' mode for restart-sensitive applications"
    fi
    
    # Conflict 4: VPA recommendations not being applied
    if [ "$update_mode" = "Auto" ]; then
      # Check if recommendations match current specs
      local current_cpu=$(kubectl get deployment $target_ref -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
      if [ ! -z "$recommendation" ] && [ ! -z "$current_cpu" ]; then
        local target_cpu=$(echo $recommendation | jq -r '.target.cpu')
        if [ "$current_cpu" != "$target_cpu" ]; then
          echo "  ⚠️  WARNING: VPA recommendations not being applied"
          echo "     Current: $current_cpu | Recommended: $target_cpu"
          echo "     Check: VPA admission controller status, resource policies"
        fi
      fi
    fi
    
    echo ""
  done
}

# Function to provide VPA optimization recommendations
provide_vpa_recommendations() {
  echo "💡 VPA OPTIMIZATION RECOMMENDATIONS"
  echo "====================================="
  
  # Analyze deployment patterns
  kubectl get deployments -n $NAMESPACE --no-headers | while read deployment ready uptodate available age; do
    echo "=== DEPLOYMENT: $deployment ==="
    
    # Check if VPA exists
    if kubectl get vpa ${deployment}-vpa -n $NAMESPACE >/dev/null 2>&1; then
      echo "  ✅ VPA configured"
      
      # Analyze VPA effectiveness
      local recommendation=$(kubectl get vpa ${deployment}-vpa -n $NAMESPACE -o json 2>/dev/null | jq -r '.status.recommendation.containerRecommendations[0] // empty')
      if [ ! -z "$recommendation" ]; then
        local confidence=$(echo $recommendation | jq -r 'if .upperBound.cpu == .lowerBound.cpu then "High" else "Variable" end')
        echo "  📊 Recommendation confidence: $confidence"
        
        if [ "$confidence" = "High" ]; then
          echo "     ✅ Safe to apply recommendations"
        else
          echo "     ⚠️  Monitor longer before applying - usage patterns vary"
        fi
      else
        echo "  ⏳ Still collecting usage data"
      fi
    else
      echo "  💡 OPPORTUNITY: Consider implementing VPA"
      
      # Check if deployment has resource specs
      local cpu_request=$(kubectl get deployment $deployment -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
      if [ -z "$cpu_request" ]; then
        echo "     🚨 CRITICAL: No resource requests specified"
        echo "     Action: Add resource specifications before implementing VPA"
      else
        echo "     Suggested VPA mode: 'Off' (recommendation only) initially"
      fi
    fi
    echo ""
  done
}

# Function to create VPA remediation plans
create_remediation_plan() {
  echo "🛠️ VPA REMEDIATION PLAN"
  echo "======================="
  
  echo "Immediate Actions (0-24 hours):"
  echo "1. Resolve HPA/VPA conflicts by choosing one scaling method per deployment"
  echo "2. Set appropriate resource boundaries in VPA resourcePolicy"
  echo "3. Switch restart-sensitive applications to VPA 'Initial' mode"
  echo ""
  
  echo "Short-term Actions (1-7 days):"
  echo "1. Monitor VPA recommendation stability for 48+ hours"
  echo "2. Validate VPA recommendations against application performance"
  echo "3. Implement gradual rollout: Off -> Initial -> Auto modes"
  echo ""
  
  echo "Long-term Actions (1+ weeks):"
  echo "1. Establish VPA governance policies and approval processes"
  echo "2. Integrate VPA monitoring into existing observability stack"
  echo "3. Train teams on VPA best practices and troubleshooting"
  echo ""
  
  echo "Emergency Procedures:"
  echo "• If VPA causes performance issues: kubectl patch vpa <name> -p '{\"spec\":{\"updatePolicy\":{\"updateMode\":\"Off\"}}}'"
  echo "• If pods stuck in restart loop: Scale deployment to 0, disable VPA, scale back up"
  echo "• If resource starvation occurs: Temporarily increase resource quotas while investigating"
}

# Main execution
detect_vpa_conflicts
echo ""
provide_vpa_recommendations  
echo ""
create_remediation_plan
EOF

chmod +x vpa-conflict-resolver.sh
./vpa-conflict-resolver.sh prod-simulation
```

### Pattern 3: The Capacity Planning Oracle

Production requires accurate capacity planning. Let's build predictive capacity analysis:

```bash
# Create advanced capacity planning tools
cat << 'EOF' > capacity-planning-oracle.sh
#!/bin/bash
echo "🔮 CAPACITY PLANNING ORACLE"
echo "=========================="

NAMESPACE=${1:-prod-simulation}

# Function to analyze current capacity utilization
analyze_current_capacity() {
  echo "📊 CURRENT CAPACITY ANALYSIS"
  echo "---------------------------"
  
  # Get cluster-wide resource capacity
  echo "Cluster Resource Capacity:"
  kubectl describe nodes | grep -A 2 "Capacity:" | grep -E "(cpu|memory)" | awk '
    /cpu/ { total_cpu += $2 } 
    /memory/ { 
      gsub(/Ki$/, "", $2); 
      total_memory += $2/1024/1024 
    } 
    END { 
      printf "  Total CPU: %.1f cores\n  Total Memory: %.1f GB\n", total_cpu, total_memory 
    }'
  
  echo ""
  echo "Current Resource Allocation:"
  
  # Calculate total requested resources
  local total_cpu_requests=0
  local total_memory_requests=0
  
  kubectl get pods --all-namespaces -o json | jq -r '
    .items[] | 
    select(.spec.containers[0].resources.requests != null) |
    "\(.spec.containers[0].resources.requests.cpu // "0"),\(.spec.containers[0].resources.requests.memory // "0")"
  ' | while IFS=',' read cpu memory; do
    # Convert CPU to millicores
    if [[ "$cpu" == *"m" ]]; then
      cpu_num=${cpu%m}
    elif [[ "$cpu" =~ ^[0-9]*\.?[0-9]*$ ]]; then
      cpu_num=$((${cpu%.*} * 1000))
    else
      cpu_num=0
    fi
    
    # Convert memory to MB
    if [[ "$memory" == *"Mi" ]]; then
      memory_num=${memory%Mi}
    elif [[ "$memory" == *"Gi" ]]; then
      memory_num=$((${memory%Gi} * 1024))
    else
      memory_num=0
    fi
    
    echo "CPU: ${cpu_num}m, Memory: ${memory_num}Mi"
  done | awk '
    { 
      gsub(/CPU: |m,.*/, "", $1); cpu_total += $1;
      gsub(/.*Memory: |Mi/, "", $2); memory_total += $2;
    } 
    END { 
      printf "  Total CPU Requests: %.1f cores\n  Total Memory Requests: %.1f GB\n", 
      cpu_total/1000, memory_total/1024 
    }'
}

# Function to predict scaling requirements
predict_scaling_requirements() {
  echo ""
  echo "📈 SCALING PREDICTION ANALYSIS"
  echo "-----------------------------"
  
  # Get current deployment scales
  echo "Current Deployment Scales:"
  kubectl get deployments -n $NAMESPACE -o custom-columns="NAME:.metadata.name,REPLICAS:.spec.replicas,CPU_REQUEST:.spec.template.spec.containers[0].resources.requests.cpu,MEMORY_REQUEST:.spec.template.spec.containers[0].resources.requests.memory" --no-headers | while read name replicas cpu memory; do
    echo "  $name: $replicas replicas (CPU: $cpu, Memory: $memory each)"
    
    # Calculate resource requirements for different scaling scenarios
    if [[ "$cpu" == *"m" ]] && [[ "$memory" == *"Mi" ]]; then
      cpu_num=${cpu%m}
      memory_num=${memory%Mi}
      
      echo "    2x scale: $((replicas * 2)) replicas = $((cpu_num * replicas * 2))m CPU, $((memory_num * replicas * 2))Mi memory total"
      echo "    5x scale: $((replicas * 5)) replicas = $((cpu_num * replicas * 5))m CPU, $((memory_num * replicas * 5))Mi memory total"
      echo "    10x scale: $((replicas * 10)) replicas = $((cpu_num * replicas * 10))m CPU, $((memory_num * replicas * 10))Mi memory total"
    fi
    echo ""
  done
}

# Function to analyze resource trends
analyze_resource_trends() {
  echo "📊 RESOURCE TREND ANALYSIS"
  echo "-------------------------"
  
  # In production, this would connect to your metrics system (Prometheus, CloudWatch, etc.)
  echo "Historical Usage Patterns (simulation):"
  echo "  • CPU utilization: 40% baseline, 80% peak (business hours)"
  echo "  • Memory utilization: 60% steady, 75% during batch processing"
  echo "  • Network I/O: 2x increase during business hours"
  echo ""
  
  echo "Growth Predictions:"
  echo "  • User base growth: 25% quarterly"
  echo "  • Data volume growth: 40% quarterly"  
  echo "  • Request volume growth: 30% quarterly"
  echo ""
  
  echo "Seasonal Patterns:"
  echo "  • Black Friday: 10x traffic spike"
  echo "  • End of quarter: 3x batch processing load"
  echo "  • Holiday periods: 50% reduced usage"
}

# Function to generate capacity recommendations
generate_capacity_recommendations() {
  echo "💡 CAPACITY RECOMMENDATIONS"
  echo "============================"
  
  echo "Short-term Capacity (1-3 months):"
  echo "  ✅ Current capacity appears adequate for normal operations"
  echo "  ⚠️  Monitor memory usage trends - approaching 75% utilization"
  echo "  💡 Consider adding 2 more nodes for redundancy and growth buffer"
  echo ""
  
  echo "Medium-term Capacity (3-12 months):"
  echo "  📈 Plan for 50% capacity increase based on growth projections"
  echo "  🎯 Target utilization: 60-70% CPU, 50-60% memory for optimal efficiency"
  echo "  🔄 Implement cluster autoscaling for dynamic capacity management"
  echo ""
  
  echo "Long-term Strategy (12+ months):"
  echo "  🏗️  Consider multi-zone deployment for high availability"
  echo "  💰 Evaluate reserved instances vs on-demand for cost optimization"
  echo "  🤖 Implement predictive scaling based on historical patterns"
  echo ""
  
  echo "Emergency Capacity Planning:"
  echo "  🚨 Black Friday preparation: Pre-scale to 5x capacity 1 week before"
  echo "  ⚡ Have emergency node pools ready for immediate activation"
  echo "  📋 Maintain runbooks for rapid capacity scaling procedures"
}

# Function to create capacity alerts
create_capacity_alerts() {
  echo ""
  echo "⚠️ CAPACITY ALERTING RECOMMENDATIONS"
  echo "====================================="
  
  echo "Critical Alerts (immediate action required):"
  echo "  🚨 CPU utilization > 90% cluster-wide"
  echo "  🚨 Memory utilization > 95% cluster-wide"
  echo "  🚨 Disk space < 10% available on any node"
  echo "  🚨 More than 20% of pods in Pending state"
  echo ""
  
  echo "Warning Alerts (action needed within 4 hours):"
  echo "  ⚠️  CPU utilization > 80% for 30+ minutes"
  echo "  ⚠️  Memory utilization > 85% for 15+ minutes"
  echo "  ⚠️  Pod density > 80% on any node"
  echo "  ⚠️  Resource quota utilization > 90%"
  echo ""
  
  echo "Informational Alerts (review within 24 hours):"
  echo "  📊 Sustained CPU utilization < 30% (over-provisioning)"
  echo "  📊 Memory utilization growth rate > 5% per week"
  echo "  📊 Failed scheduling events increasing trend"
}

# Main execution
analyze_current_capacity
echo ""
predict_scaling_requirements
echo ""
analyze_resource_trends
echo ""
generate_capacity_recommendations
echo ""
create_capacity_alerts

echo ""
echo "🎯 CAPACITY PLANNING SUMMARY"
echo "============================="
echo "• Current capacity: Adequate for normal operations"
echo "• Growth planning: Prepare for 50% increase in 12 months"
echo "• Monitoring: Implement comprehensive capacity alerting"
echo "• Emergency preparedness: Maintain rapid scaling procedures"
echo ""
echo "📅 Next Review: Schedule monthly capacity planning reviews"
EOF

chmod +x capacity-planning-oracle.sh
./capacity-planning-oracle.sh prod-simulation
```

---

## 🛠️ Advanced Production Patterns

### Pattern 1: Multi-Environment Resource Consistency

```bash
# Create a tool to ensure resource consistency across environments
cat << 'EOF' > multi-env-consistency-checker.sh
#!/bin/bash
echo "🔄 MULTI-ENVIRONMENT CONSISTENCY CHECKER"
echo "========================================"

# Function to extract resource specifications from a deployment
extract_resources() {
  local deployment=$1
  local namespace=$2
  
  kubectl get deployment $deployment -n $namespace -o json 2>/dev/null | jq -r '
    .spec.template.spec.containers[0] | 
    {
      cpu_request: .resources.requests.cpu,
      memory_request: .resources.requests.memory,
      cpu_limit: .resources.limits.cpu,
      memory_limit: .resources.limits.memory
    } | @json
  '
}

# Function to compare resources between environments
compare_environments() {
  local app_name=$1
  
  echo "=== COMPARING: $app_name ==="
  
  # Define environments (adjust for your setup)
  declare -A environments
  environments[dev]="dev-namespace"
  environments[staging]="staging-namespace"  
  environments[prod]="prod-simulation"
  
  declare -A app_resources
  
  # Extract resources from each environment
  for env in "${!environments[@]}"; do
    local namespace=${environments[$env]}
    local resources=$(extract_resources $app_name $namespace)
    
    if [ "$resources" != "null" ] && [ ! -z "$resources" ]; then
      app_resources[$env]=$resources
      echo "$env: Found deployment"
    else
      echo "$env: ❌ Deployment not found"
      app_resources[$env]="null"
    fi
  done
  
  # Compare resource specifications
  echo "Resource Comparison:"
  
  local inconsistencies=0
  
  # Compare dev vs staging
  if [ "${app_resources[dev]}" != "null" ] && [ "${app_resources[staging]}" != "null" ]; then
    local dev_cpu=$(echo "${app_resources[dev]}" | jq -r '.cpu_request')
    local staging_cpu=$(echo "${app_resources[staging]}" | jq -r '.cpu_request')
    
    if [ "$dev_cpu" != "$staging_cpu" ]; then
      echo "  ⚠️  CPU Request mismatch: dev=$dev_cpu, staging=$staging_cpu"
      ((inconsistencies++))
    fi
  fi
  
  # Compare staging vs prod
  if [ "${app_resources[staging]}" != "null" ] && [ "${app_resources[prod]}" != "null" ]; then
    local staging_memory=$(echo "${app_resources[staging]}" | jq -r '.memory_request')
    local prod_memory=$(echo "${app_resources[prod]}" | jq -r '.memory_request')
    
    if [ "$staging_memory" != "$prod_memory" ]; then
      echo "  ⚠️  Memory Request mismatch: staging=$staging_memory, prod=$prod_memory"
      ((inconsistencies++))
    fi
  fi
  
  if [ $inconsistencies -eq 0 ]; then
    echo "  ✅ Resource specifications consistent across environments"
  else
    echo "  🚨 Found $inconsistencies inconsistencies - review and align"
  fi
  
  echo ""
}

# Check common applications
echo "Checking resource consistency for common applications..."
echo ""

# List of applications to check (adjust for your applications)
apps=("web-frontend" "api-backend" "database-service")

for app in "${apps[@]}"; do
  compare_environments $app
done

echo "💡 CONSISTENCY RECOMMENDATIONS"
echo "==============================="
echo "1. Maintain identical resource specs between staging and production"
echo "2. Development can have lower resource allocations for cost savings"
echo "3. Use GitOps or Helm to ensure consistent deployments"
echo "4. Implement automated testing of resource specifications"
echo "5. Regular audits to catch configuration drift"
EOF

chmod +x multi-env-consistency-checker.sh
./multi-env-consistency-checker.sh
```

### Pattern 2: Resource Management During Incidents

```bash
# Create incident response tools for resource management
cat << 'EOF' > incident-resource-manager.sh
#!/bin/bash
echo "🚨 INCIDENT RESOURCE MANAGER"
echo "=========================="

INCIDENT_TYPE=${1}
NAMESPACE=${2:-prod-simulation}

if [ -z "$INCIDENT_TYPE" ]; then
  echo "Usage: $0 <incident-type> [namespace]"
  echo ""
  echo "Available incident types:"
  echo "  traffic-spike    - Handle sudden traffic increase"
  echo "  resource-leak    - Handle memory/resource leaks"
  echo "  node-failure     - Handle node failures"
  echo "  oom-crisis      - Handle out-of-memory situations"
  echo "  capacity-crisis  - Handle cluster capacity issues"
  exit 1
fi

# Function to handle traffic spikes
handle_traffic_spike() {
  echo "🚀 TRAFFIC SPIKE INCIDENT RESPONSE"
  echo "=================================="
  
  echo "Step 1: Immediate Assessment"
  echo "----------------------------"
  
  # Check current resource utilization
  echo "Current cluster utilization:"
  kubectl top nodes
  
  echo ""
  echo "Top resource consumers:"
  kubectl top pods -n $NAMESPACE --sort-by=cpu | head -5
  
  echo ""
  echo "Step 2: Emergency Scaling Actions"
  echo "---------------------------------"
  
  # Find deployments that might need scaling
  kubectl get deployments -n $NAMESPACE --no-headers | while read deployment ready uptodate available age; do
    current_replicas=$(kubectl get deployment $deployment -n $NAMESPACE -o jsonpath='{.spec.replicas}')
    
    # Suggest scaling for frontend/API services during traffic spikes
    if [[ "$deployment" == *"frontend"* ]] || [[ "$deployment" == *"api"* ]] || [[ "$deployment" == *"web"* ]]; then
      suggested_replicas=$((current_replicas * 3))
      echo "🔧 SUGGESTED: Scale $deployment from $current_replicas to $suggested_replicas replicas"
      echo "   Command: kubectl scale deployment $deployment -n $NAMESPACE --replicas=$suggested_replicas"
    fi
  done
  
  echo ""
  echo "Step 3: Resource Limit Adjustments"
  echo "----------------------------------"
  echo "Consider temporarily increasing resource limits for critical services:"
  echo "• Increase CPU limits by 50-100% for web/API services"
  echo "• Monitor memory usage and increase limits if approaching thresholds"
  echo "• Disable non-essential services to free up resources"
  
  echo ""
  echo "Step 4: Monitoring and Validation"
  echo "--------------------------------"
  echo "• Monitor response times and error rates"
  echo "• Watch for pod evictions or resource starvation"
  echo "• Prepare to scale back after traffic normalizes"
}

# Function to handle resource leaks
handle_resource_leak() {
  echo "🔧 RESOURCE LEAK INCIDENT RESPONSE"
  echo "=================================="
  
  echo "Step 1: Identify Leak Sources"
  echo "-----------------------------"
  
  # Find pods with high memory growth
  echo "Pods with potentially high memory usage:"
  kubectl top pods -n $NAMESPACE --sort-by=memory | head -10
  
  echo ""
  echo "Step 2: Immediate Containment"
  echo "----------------------------"
  
  # Find pods approaching memory limits
  kubectl get pods -n $NAMESPACE -o json | jq -r '
    .items[] | 
    select(.spec.containers[0].resources.limits.memory != null) |
    "\(.metadata.name),\(.spec.containers[0].resources.limits.memory)"
  ' | while IFS=',' read pod memory_limit; do
    echo "🔍 Checking $pod (limit: $memory_limit)"
    
    # In production, you'd get actual usage and compare
    echo "   Command to restart if leaking: kubectl delete pod $pod -n $NAMESPACE"
  done
  
  echo ""
  echo "Step 3: Emergency Actions"
  echo "------------------------"
  echo "🚨 If memory leak confirmed:"
  echo "  1. Restart affected pods immediately"
  echo "  2. Reduce replica count to minimize impact"  
  echo "  3. Temporarily increase memory limits to buy time"
  echo "  4. Enable more aggressive garbage collection if applicable"
  
  echo ""
  echo "Step 4: Investigation Commands"
  echo "-----------------------------"
  echo "• Check pod events: kubectl describe pod <pod-name> -n $NAMESPACE"
  echo "• Monitor memory usage: watch kubectl top pods -n $NAMESPACE"
  echo "• Check application logs for memory allocation patterns"
}

# Function to handle node failures
handle_node_failure() {
  echo "🖥️ NODE FAILURE INCIDENT RESPONSE"
  echo "================================="
  
  echo "Step 1: Assess Impact"
  echo "--------------------"
  
  # Check node status
  kubectl get nodes --no-headers | grep -v Ready | while read node status roles age version; do
    echo "❌ Failed node: $node ($status)"
    
    # Find pods on failed node
    kubectl get pods --all-namespaces --field-selector spec.nodeName=$node --no-headers | wc -l | while read count; do
      echo "   Affected pods: $count"
    done
  done
  
  echo ""
  echo "Step 2: Emergency Pod Recovery"
  echo "-----------------------------"
  
  # Find pods stuck on failed nodes
  kubectl get pods -n $NAMESPACE --field-selector status.phase=Pending --no-headers | while read pod ready status restarts age; do
    echo "🔄 Pending pod: $pod"
    echo "   Check if stuck due to node failure or resource constraints"
  done
  
  echo ""
  echo "Step 3: Capacity Management"
  echo "--------------------------"
  echo "• Verify remaining nodes have capacity for displaced workloads"
  echo "• Consider temporarily reducing replica counts if capacity limited"
  echo "• Monitor resource utilization on remaining nodes"
  
  echo ""
  echo "Step 4: Recovery Actions"
  echo "-----------------------"
  echo "🔧 Commands to execute:"
  echo "  # Cordon failed node: kubectl cordon <node-name>"
  echo "  # Drain failed node: kubectl drain <node-name> --ignore-daemonsets"
  echo "  # Force delete stuck pods: kubectl delete pod <pod-name> --force --grace-period=0"
}

# Function to handle OOM crisis
handle_oom_crisis() {
  echo "💥 OUT-OF-MEMORY CRISIS RESPONSE"
  echo "==============================="
  
  echo "Step 1: Identify OOM Victims"
  echo "---------------------------"
  
  # Check for OOMKilled pods
  kubectl get events -n $NAMESPACE --field-selector reason=Killing | grep OOM | while read line; do
    echo "💀 OOM Event: $line"
  done
  
  # Find pods that were recently restarted (potential OOM victims)
  kubectl get pods -n $NAMESPACE --no-headers | awk '$4 > 0 {print $1 ": " $4 " restarts"}' | while read pod_info; do
    pod_name=$(echo $pod_info | cut -d':' -f1)
    echo "🔄 $pod_info"
    
    # Check if last termination was due to OOM
    termination_reason=$(kubectl get pod $pod_name -n $NAMESPACE -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}' 2>/dev/null)
    if [ "$termination_reason" = "OOMKilled" ]; then
      echo "   💀 Confirmed OOM kill"
    fi
  done
  
  echo ""
  echo "Step 2: Emergency Memory Relief"
  echo "------------------------------"
  
  # Increase memory limits for OOM-prone pods
  kubectl get deployments -n $NAMESPACE --no-headers | while read deployment ready uptodate available age; do
    current_memory=$(kubectl get deployment $deployment -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}')
    if [ ! -z "$current_memory" ]; then
      echo "📊 $deployment current memory limit: $current_memory"
      echo "   Consider increasing to prevent OOM kills"
    fi
  done
  
  echo ""
  echo "Step 3: Immediate Actions"
  echo "------------------------"
  echo "🚨 Execute immediately:"
  echo "  1. Increase memory limits for critical services by 50-100%"
  echo "  2. Scale down non-essential services to free memory"
  echo "  3. Restart services with memory leaks"
  echo "  4. Monitor for continued OOM events"
}

# Function to handle capacity crisis
handle_capacity_crisis() {
  echo "⚡ CAPACITY CRISIS RESPONSE"
  echo "=========================="
  
  echo "Step 1: Rapid Assessment"
  echo "-----------------------"
  
  # Check cluster capacity utilization
  echo "Node resource utilization:"
  kubectl top nodes
  
  echo ""
  echo "Pending pods (resource constrained):"
  kubectl get pods --all-namespaces --field-selector status.phase=Pending --no-headers | wc -l | while read count; do
    echo "Total pending pods: $count"
  done
  
  echo ""
  echo "Step 2: Emergency Resource Liberation"
  echo "-----------------------------------"
  
  # Find pods that can be safely terminated
  echo "🎯 Candidates for termination (free up resources):"
  
  # Find development/testing pods
  kubectl get pods --all-namespaces -l environment=dev --no-headers 2>/dev/null | head -5 | while read ns pod ready status restarts age; do
    echo "  Dev pod: $ns/$pod"
  done
  
  # Find pods with low priority
  kubectl get pods --all-namespaces --no-headers | while read ns pod ready status restarts age; do
    priority=$(kubectl get pod $pod -n $ns -o jsonpath='{.spec.priorityClassName}' 2>/dev/null)
    if [[ "$priority" == *"low"* ]] || [[ "$priority" == *"batch"* ]]; then
      echo "  Low priority pod: $ns/$pod ($priority)"
    fi
  done | head -5
  
  echo ""
  echo "Step 3: Capacity Expansion"
  echo "-------------------------"
  echo "🚀 Scale cluster immediately:"
  echo "  # Add nodes manually or trigger autoscaling"
  echo "  # Consider spot instances for temporary capacity"
  echo "  # Request emergency quota increase from cloud provider"
  
  echo ""
  echo "Step 4: Load Shedding"
  echo "--------------------"
  echo "🔧 Temporary measures:"
  echo "  • Scale down non-critical services by 50%"
  echo "  • Enable request throttling/rate limiting"
  echo "  • Redirect traffic to alternate regions if available"
  echo "  • Activate maintenance mode for non-essential features"
}

# Main incident handler
case $INCIDENT_TYPE in
  traffic-spike)
    handle_traffic_spike
    ;;
  resource-leak)
    handle_resource_leak
    ;;
  node-failure)
    handle_node_failure
    ;;
  oom-crisis)
    handle_oom_crisis
    ;;
  capacity-crisis)
    handle_capacity_crisis
    ;;
  *)
    echo "❌ Unknown incident type: $INCIDENT_TYPE"
    echo "Use one of: traffic-spike, resource-leak, node-failure, oom-crisis, capacity-crisis"
    exit 1
    ;;
esac

echo ""
echo "📋 POST-INCIDENT CHECKLIST"
echo "=========================="
echo "□ Document incident timeline and actions taken"
echo "□ Analyze root cause and implement preventive measures"  
echo "□ Review and update resource specifications based on learnings"
echo "□ Test incident response procedures in staging environment"
echo "□ Update monitoring/alerting to catch similar issues earlier"
echo "□ Conduct post-mortem with team to improve response procedures"
EOF

chmod +x incident-resource-manager.sh

# Test the incident manager
echo "Testing incident response tools..."
./incident-resource-manager.sh traffic-spike prod-simulation
```

---

## 🚀 Ultimate Production Challenge: Complete Resource Management Platform

Let's build a comprehensive production-ready resource management system that combines everything you've learned.

### Challenge: Enterprise Resource Management Platform

**Scenario**: You're the Principal Platform Engineer at GlobalTech, responsible for managing Kubernetes resources across 5 regions, 15 clusters, serving 100+ microservices with 99.99% uptime requirements.

### Challenge Requirements

**Business Requirements**:
- Support 10,000+ pods across multiple clusters
- Maintain 99.99% uptime during optimization changes
- Reduce infrastructure costs by 30% while improving performance
- Provide self-service resource management for 20+ development teams
- Ensure compliance with enterprise governance policies

**Technical Requirements**:
- Automated resource optimization across all environments
- Real-time capacity planning and forecasting
- Comprehensive monitoring and alerting
- Incident response automation
- Multi-cluster resource coordination

### Challenge Implementation

```bash
# Create the ultimate enterprise resource management platform
mkdir -p enterprise-resource-platform
cd enterprise-resource-platform

# Create the master control system
cat << 'EOF' > enterprise-resource-controller.sh
#!/bin/bash
echo "🏢 GLOBALTECH ENTERPRISE RESOURCE MANAGEMENT PLATFORM"
echo "====================================================="
echo "Platform Status Dashboard - $(date)"
echo ""

# Configuration - adapt to your environment
declare -A CLUSTERS
CLUSTERS[us-east-prod]="us-east-1-prod-cluster"
CLUSTERS[us-west-prod]="us-west-1-prod-cluster"  
CLUSTERS[eu-prod]="eu-central-1-prod-cluster"
CLUSTERS[asia-prod]="asia-southeast-1-prod-cluster"
CLUSTERS[global-staging]="global-staging-cluster"

declare -A CRITICAL_SERVICES
CRITICAL_SERVICES[user-auth]="authentication,authorization"
CRITICAL_SERVICES[payment-gateway]="payments,billing"
CRITICAL_SERVICES[core-api]="api,core-services"
CRITICAL_SERVICES[web-frontend]="frontend,ui"

# Function to get cluster health status
check_cluster_health() {
  local cluster_name=$1
  local cluster_context=$2
  
  echo "=== CLUSTER: $cluster_name ==="
  
  # In production, you'd switch kubectl context
  # kubectl config use-context $cluster_context
  
  # Simulate cluster health check
  local node_count=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
  local ready_nodes=$(kubectl get nodes --no-headers 2>/dev/null | grep " Ready " | wc -l)
  local total_pods=$(kubectl get pods --all-namespaces --no-headers 2>/dev/null | wc -l)
  
  echo "Nodes: $ready_nodes/$node_count ready"
  echo "Total Pods: $total_pods"
  
  # Check resource utilization
  echo "Resource Utilization:"
  kubectl top nodes 2>/dev/null | tail -n +2 | while read node cpu cpu_pct memory memory_pct; do
    cpu_num=$(echo $cpu_pct | tr -d '%')
    mem_num=$(echo $memory_pct | tr -d '%')
    
    local status="✅ Normal"
    if [ $cpu_num -gt 80 ] || [ $mem_num -gt 85 ]; then
      status="⚠️  High utilization"
    elif [ $cpu_num -gt 90 ] || [ $mem_num -gt 95 ]; then
      status="🚨 Critical"
    fi
    
    echo "  $node: $status (CPU: $cpu_pct, Memory: $memory_pct)"
  done
  
  # Check critical services
  echo "Critical Services Status:"
  for service in "${!CRITICAL_SERVICES[@]}"; do
    # Simulate service health check
    local replicas=$(kubectl get deployment $service -o jsonpath='{.status.readyReplicas}/{.spec.replicas}' 2>/dev/null)
    if [ ! -z "$replicas" ]; then
      echo "  $service: $replicas replicas ready"
    else
      echo "  $service: ❌ Not found or unavailable"
    fi
  done
  
  echo ""
}

# Function to analyze resource efficiency across clusters
analyze_global_efficiency() {
  echo "🌐 GLOBAL RESOURCE EFFICIENCY ANALYSIS"
  echo "======================================"
  
  local total_cpu_waste=0
  local total_memory_waste=0
  local total_cost_impact=0
  
  echo "Cluster-by-cluster efficiency analysis:"
  
  for cluster in "${!CLUSTERS[@]}"; do
    echo "--- $cluster ---"
    
    # Simulate efficiency calculations
    local cpu_efficiency=$((60 + RANDOM % 30))  # 60-90% efficiency
    local memory_efficiency=$((50 + RANDOM % 40))  # 50-90% efficiency
    local estimated_waste=$((100 + RANDOM % 500))  # $100-600 daily waste
    
    echo "  CPU Efficiency: ${cpu_efficiency}%"
    echo "  Memory Efficiency: ${memory_efficiency}%"
    echo "  Estimated Daily Waste: \${estimated_waste}"
    
    total_cost_impact=$((total_cost_impact + estimated_waste))
    
    # Recommendations based on efficiency
    if [ $cpu_efficiency -lt 70 ]; then
      echo "  💡 RECOMMENDATION: Implement VPA for CPU optimization"
    fi
    if [ $memory_efficiency -lt 60 ]; then
      echo "  💡 RECOMMENDATION: Review memory allocations and limits"
    fi
    
    echo ""
  done
  
  echo "📊 GLOBAL SUMMARY:"
  echo "Total estimated daily waste: \${total_cost_impact}"
  echo "Annual waste projection: \$(($total_cost_impact * 365))"
  echo "Target savings with optimization: \$(($total_cost_impact * 365 * 30 / 100))"
}

# Function to generate executive dashboard
generate_executive_dashboard() {
  echo "📋 EXECUTIVE DASHBOARD"
  echo "====================="
  
  local total_clusters=${#CLUSTERS[@]}
  local healthy_clusters=$((total_clusters - 1))  # Simulate one cluster with issues
  local total_services=${#CRITICAL_SERVICES[@]}
  local healthy_services=$total_services
  
  echo "📊 PLATFORM OVERVIEW"
  echo "Clusters: $healthy_clusters/$total_clusters healthy"
  echo "Critical Services: $healthy_services/$total_services operational"
  echo "Overall Platform Health: 99.2% (within SLA)"
  echo ""
  
  echo "💰 COST OPTIMIZATION STATUS"
  echo "Year-to-date savings: \$1.2M (24% of target)"
  echo "Monthly optimization trend: +3.2%"
  echo "Projected annual savings: \$2.8M"
  echo ""
  
  echo "🎯 KEY PERFORMANCE INDICATORS"
  echo "Average resource utilization: 68%"
  echo "Resource waste reduction: 22% YTD"
  echo "Incident response time: 4.2 minutes (target: <5 minutes)"
  echo "Automated optimization coverage: 78% of workloads"
  echo ""
  
  echo "⚠️  ATTENTION REQUIRED"
  echo "• Asia-prod cluster showing high memory utilization"
  echo "• 3 development teams exceeding resource quotas"
  echo "• VPA recommendations pending review for 12 services"
  echo "• Capacity planning needed for Q4 traffic projections"
}

# Function to provide strategic recommendations
provide_strategic_recommendations() {
  echo ""
  echo "🎯 STRATEGIC RECOMMENDATIONS"
  echo "============================"
  
  echo "Immediate Actions (0-24 hours):"
  echo "✅ Review and approve pending VPA recommendations"
  echo "✅ Address high memory utilization in Asia-prod cluster"
  echo "✅ Investigate teams exceeding resource quotas"
  echo ""
  
  echo "Short-term Initiatives (1-4 weeks):"
  echo "🔄 Implement cross-cluster resource balancing"
  echo "🔄 Deploy advanced monitoring for predictive scaling"
  echo "🔄 Conduct resource optimization training for development teams"
  echo "🔄 Establish automated incident response for resource events"
  echo ""
  
  echo "Long-term Strategy (1-6 months):"
  echo "🚀 Implement multi-cluster resource federation"
  echo "🚀 Deploy machine learning-based capacity forecasting"
  echo "🚀 Establish self-service resource management portal"
  echo "🚀 Create comprehensive cost attribution and chargeback system"
  echo ""
  
  echo "Innovation Opportunities:"
  echo "💡 Explore serverless migration for batch workloads"
  echo "💡 Implement AI-driven resource optimization"
  echo "💡 Develop custom resource schedulers for specialized workloads"
  echo "💡 Create resource efficiency gamification for development teams"
}

# Main execution
echo "Initializing platform health check..."
echo ""

# Check all clusters
for cluster in "${!CLUSTERS[@]}"; do
  check_cluster_health $cluster ${CLUSTERS[$cluster]}
done

echo ""
analyze_global_efficiency

echo ""
generate_executive_dashboard

echo ""
provide_strategic_recommendations

echo ""
echo "🎯 PLATFORM MANAGEMENT COMPLETE"
echo "==============================="
echo "Next automated check in 15 minutes"
echo "Emergency contact: platform-team@globaltech.com"
echo "Dashboard URL: https://resource-management.globaltech.com"
EOF

chmod +x enterprise-resource-controller.sh
./enterprise-resource-controller.sh
```

### Challenge Success Metrics

Your enterprise platform should demonstrate:

**Operational Excellence**:
- ✅ 99.99% uptime maintained during all optimization activities
- ✅ <5 minute mean time to detection for resource issues
- ✅ <15 minute mean time to resolution for resource incidents
- ✅ Zero manual resource tuning for stable workloads

**Cost Optimization**:
- ✅ 30% reduction in infrastructure costs year-over-year
- ✅ <10% resource waste across all clusters
- ✅ ROI of >300% on resource management platform investment
- ✅ Complete cost attribution to business units

**Developer Experience**:
- ✅ Self-service resource management for all development teams
- ✅ <2 hour resource request approval cycle
- ✅ Comprehensive resource usage visibility for teams
- ✅ Automated optimization recommendations

**Business Impact**:
- ✅ Support for 10x traffic growth without proportional cost increase
- ✅ Enable faster time-to-market through efficient resource allocation
- ✅ Compliance with all enterprise governance requirements
- ✅ Strategic advantage through advanced resource management capabilities

---

## 📝 Unit 5 & Complete Learning Path Wrap-Up

### Production Mastery Achieved

**Reflect on your complete journey:**

1. **What's the most valuable production insight you've gained about resource management?**

2. **How has your understanding of Kubernetes resource management evolved from Unit 1 to Unit 5?**

3. **What's one thing you'll implement immediately in your production environment?**

### Complete Skill Set Mastered

You can now confidently:

**Foundation Skills (Unit 1)**:
- Design appropriate resource specifications for any workload
- Understand and predict Kubernetes scheduling behavior
- Optimize resource allocation for different application patterns

**Monitoring & Analysis (Unit 2)**:
- Build comprehensive resource monitoring systems
- Identify optimization opportunities through data analysis
- Create actionable insights from resource usage patterns

**Governance & Policy (Unit 3)**:
- Design and implement enterprise-grade resource policies
- Ensure fair resource allocation in multi-tenant environments
- Maintain availability during disruptions through proper planning

**Intelligent Optimization (Unit 4)**:
- Configure and manage automated resource optimization systems
- Implement resource-aware scheduling strategies
- Build custom optimization logic for specific use cases

**Production Operations (Unit 5)**:
- Operate resource management systems at enterprise scale
- Troubleshoot complex production resource issues
- Design resilient architectures that handle failures gracefully
- Create comprehensive incident response procedures

### Your Next Steps

**Immediate Actions**:
- Implement monitoring and governance in your current clusters
- Start with VPA in "Off" mode to collect baseline data
- Establish resource efficiency metrics and targets

**Medium-term Goals**:
- Build comprehensive resource management automation
- Implement cross-team resource governance policies
- Create self-service resource management capabilities

**Long-term Vision**:
- Become the resource management expert in your organization
- Contribute to open-source resource management tools
- Mentor others in advanced Kubernetes resource management

---

## 🧹 Final Cleanup

```bash
# Clean up all learning lab resources
kubectl delete namespace prod-simulation

# Clean up all scripts and tools
cd ..
rm -rf enterprise-resource-platform
rm -f prod-health-check.sh resource-starvation-detective.sh
rm -f vpa-conflict-resolver.sh capacity-planning-oracle.sh
rm -f multi-env-consistency-checker.sh incident-resource-manager.sh

echo "🎓 Kubernetes Resource Management Mastery Program Complete!"
echo ""
echo "You've successfully completed all 5 units and are now equipped to:"
echo "• Design resource-efficient Kubernetes applications"
echo "• Monitor and optimize resource usage at scale"
echo "• Implement comprehensive governance policies"
echo "• Automate resource optimization with VPA and intelligent scheduling"
echo "• Operate production resource management systems"
echo ""
echo "Congratulations on your mastery of Kubernetes Resource Management! 🎊"
```

**🏆 MASTERY ACHIEVED!** You've completed a comprehensive journey from basic resource concepts to enterprise-scale production operations. You now possess the skills to design, implement, and operate sophisticated resource management systems that can handle real-world production challenges while optimizing for both cost and performance.

The knowledge and tools you've built throughout this learning path will serve you well as you apply these concepts in your own Kubernetes environments. Remember: great resource management is not just about setting the right numbers—it's about creating sustainable, efficient, and resilient systems that enable your organization to innovate and scale.

Welcome to the ranks of Kubernetes Resource Management experts! 🎓# Unit 5: Production Patterns & Troubleshooting
**Duration**: 4-5 hours  
**Core Question**: "How do I maintain optimal resource utilization in a production environment at scale?"

## 🎯 Learning Objectives
By the end of this unit, you will:
- Implement production-ready resource management patterns
- Troubleshoot complex resource-related issues in live environments
- Design resilient resource architectures that handle failures gracefully
- Create comprehensive monitoring and alerting for resource management
- Build runbooks for common resource management scenarios
- Operate resource optimization systems at enterprise scale

## 🏗️ Building on Your Complete Foundation

You've mastered the fundamentals (Unit 1), monitoring (Unit 2), governance (Unit 3), and intelligent optimization (Unit 4). Now it's time for the reality of production operations.

**🤔 Production Reality Check**:
- What happens when VPA recommendations conflict with application performance?
- How do you handle resource management during a major incident?
- What's your strategy when intelligent optimization goes wrong?
- How do you maintain resource efficiency as your cluster grows from 100 to 10,000 pods?

Today we'll explore the battle-tested patterns and troubleshooting techniques that keep production Kubernetes clusters running optimally under real-world conditions.

---

## 🚨 Foundation: Production Resource Management Challenges

### Step 1: Understanding Production Complexity

```bash
# Set up a realistic production-simulation environment
kubectl create namespace prod-simulation
kubectl config set-context --current --namespace=prod-simulation

# Create a realistic production-like setup with common issues
cat << EOF | kubectl apply -f -
# Simulate a production environment with various resource patterns
apiVersion: v1
kind: ConfigMap
metadata:
  name: production-scenarios
data:
  # Traffic spike simulation
  traffic-spike.sh: |
    #!/bin/sh
    echo "Simulating traffic spike pattern..."
    for hour in \$(seq 1 24); do
      if [ \$hour -ge 9 ] && [ \$hour -le 17 ]; then
        # Business hours - high load
        stress_level=\$(((hour - 8) * 10))
        echo "Hour \$hour: Business hours - stress level \$stress_level"
        yes > /dev/null &
        PID=\$!
        sleep 300  # 5 minutes
        kill \$PID
      elif [ \$hour -ge 18 ] && [ \$hour -le 22 ]; then
        # Evening - medium load  
        echo "Hour \$hour: Evening traffic"
        sleep 150
        yes > /dev/null &
        PID=\$!
        sleep 150
        kill \$PID
      else
        # Night/early morning - low load
        echo "Hour \$hour: Low traffic period"
        sleep 300
      fi
    done
  
  # Memory leak simulation
  memory-leak.sh: |
    #!/bin/sh
    echo "Simulating gradual memory leak..."
    counter=0
    while true; do
      counter=\$((counter + 1))
      # Allocate memory that doesn't get freed
      dd if=/dev/zero of=/tmp/leak\$counter bs=1M count=10 2>/dev/null
      echo "Memory allocation cycle \$counter completed"
      sleep 60
      
      # Simulate occasional cleanup (imperfect leak)
      if [ \$((counter % 10)) -eq 0 ]; then
        rm -f /tmp/leak\$((counter - 5))
        echo "Partial cleanup performed"
      fi
    done
  
  # Database connection pool simulation
  db-connection-spike.sh: |
    #!/bin/sh
    echo "Simulating database connection pool behavior..."
    while true; do
      # Simulate connection pool growth
      for i in \$(seq 1 50); do
        echo "DB connection \$i established" 
        sleep 0.1
      done
      
      # Hold connections and consume CPU
      yes > /dev/null &
      CPU_PID=\$!
      sleep 30
      kill \$CPU_PID
      
      # Release connections  
      echo "Releasing database connections"
      sleep 10
    done
EOF
```

### Step 2: Deploy Production-Realistic Workloads

```bash
# Create workloads that represent common production patterns
cat << EOF | kubectl apply -f -
# Web frontend with variable traffic patterns
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-frontend
  labels:
    tier: frontend
    criticality: high
spec:
  replicas: 5
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
        command: ["/bin/sh"]
        args: ["/scripts/traffic-spike.sh"]
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 1
            memory: 1Gi
        volumeMounts:
        - name: scripts
          mountPath: /scripts
      volumes:
      - name: scripts
        configMap:
          name: production-scenarios
          defaultMode: 0755
---
# API backend with potential memory leaks
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-backend
  labels:
    tier: backend
    criticality: high
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
        image: alpine:latest
        command: ["/bin/sh"]
        args: ["/scripts/memory-leak.sh"]
        resources:
          requests:
            cpu: 300m
            memory: 512Mi
          limits:
            cpu: 1
            memory: 2Gi
        volumeMounts:
        - name: scripts
          mountPath: /scripts
      volumes:
      - name: scripts
        configMap:
          name: production-scenarios
          defaultMode: 0755
---
# Database with connection pooling
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database-service
  labels:
    tier: data
    criticality: critical
spec:
  replicas: 2
  selector:
    matchLabels:
      app: database-service
  template:
    metadata:
      labels:
        app: database-service
        tier: data
    spec:
      containers:
      - name: database
        image: postgres:13-alpine
        env:
        - name: POSTGRES_DB
          value: proddb
        - name: POSTGRES_USER
          value: dbuser
        - name: POSTGRES_PASSWORD
          value: dbpass123
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            cpu: 2
            memory: 4Gi
      - name: connection-monitor
        image: alpine:latest
        command: ["/bin/sh"]
        args: ["/scripts/db-connection-spike.sh"]
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        volumeMounts:
        - name: scripts
          mountPath: /scripts
      volumes: