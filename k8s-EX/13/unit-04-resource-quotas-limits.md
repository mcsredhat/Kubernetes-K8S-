# Unit 4: Resource Quotas and Limits

## Learning Objectives
By the end of this unit, you will:
- Understand the difference between requests, limits, and quotas
- Implement ResourceQuotas to control namespace resource consumption
- Design LimitRanges for consistent resource defaults
- Monitor and troubleshoot resource allocation issues
- Create fair resource sharing policies across teams

## Pre-Unit Reflection
Before diving into technical implementation, consider these scenarios:
1. If your apartment building had unlimited utilities but limited capacity, what problems might arise?
2. How would you fairly distribute parking spaces among residents?
3. What happens in software systems when one process consumes all available memory?

## Part 1: Understanding Resource Management

### Discovery Exercise: The Resource Crisis Simulation

Let's start by experiencing what happens without resource controls:

**Step 1: Create an Uncontrolled Environment**
```bash
# Create a test namespace without any limits
kubectl create namespace resource-chaos
```

**Step 2: Deploy a "Greedy" Application**
```yaml
# resource-hog.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-hog
  namespace: resource-chaos
spec:
  replicas: 3
  selector:
    matchLabels:
      app: resource-hog
  template:
    metadata:
      labels:
        app: resource-hog
    spec:
      containers:
      - name: hog
        image: nginx
        # Notice: No resource requests or limits!
```

**Investigation Questions:**
Before applying this deployment, predict:
1. How much memory and CPU will each pod be allowed to use?
2. What happens if this application actually needed 8GB of RAM per pod?
3. How would this affect other applications in your cluster?

**Step 3: Deploy and Observe**
```bash
kubectl apply -f resource-hog.yaml
kubectl describe pods -n resource-chaos
kubectl top pods -n resource-chaos  # If metrics-server is available
```

**Discovery Questions:**
1. What default resource values do you see in the pod description?
2. If you check `kubectl top nodes`, how much capacity is being "reserved"?
3. What would happen if you scaled this deployment to 10 replicas?

### Understanding the Three Layers of Resource Control

**Investigation Exercise: The Resource Hierarchy**

Let's understand how Kubernetes manages resources at different levels:

```bash
# Layer 1: Node Capacity (What's actually available)
kubectl describe nodes | grep -A5 -B5 "Allocatable"

# Layer 2: Namespace Quotas (What the namespace can use)  
kubectl describe resourcequota -n kube-system  # If any exist

# Layer 3: Pod Requests/Limits (What each pod declares/is limited to)
kubectl describe pods -n kube-system | grep -A10 -B2 "Limits\|Requests"
```

**Analysis Challenge:**
1. How do these three layers work together?
2. What happens when they conflict?
3. Why might you want control at each level?

## Part 2: Implementing ResourceQuotas

### Discovery Exercise: Quota Design Thinking

**Scenario Setup:**
You manage a cluster shared by three teams:
- **Frontend Team:** Runs web applications (typically lightweight)
- **Data Team:** Runs analytics jobs (memory-intensive, batch processing)
- **API Team:** Runs microservices (steady CPU usage, moderate memory)

**Design Challenge:**
Before looking at implementation, consider:
1. How would you divide cluster resources fairly among these teams?
2. Should all teams get equal resources, or should allocation vary based on needs?
3. What happens when a team needs more resources temporarily?

### Mini-Project 1: Basic ResourceQuota Implementation

**Step 1: Create Team Namespaces with Quotas**

```yaml
# frontend-namespace-with-quota.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: frontend-team
  labels:
    team: frontend
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: frontend-quota
  namespace: frontend-team
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 4Gi
    limits.cpu: "4"
    limits.memory: 8Gi
    pods: "10"
    services: "5"
```

**Step 2: Test the Quota**
Deploy applications that test the boundaries:

```yaml
# quota-test-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: quota-test
  namespace: frontend-team
spec:
  replicas: 2
  selector:
    matchLabels:
      app: quota-test
  template:
    metadata:
      labels:
        app: quota-test
    spec:
      containers:
      - name: web
        image: nginx
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"  
            cpu: "1000m"
```

**Experimentation Tasks:**
1. Deploy the application and check quota usage:
```bash
kubectl describe resourcequota frontend-quota -n frontend-team
```

2. Try to exceed the quota by scaling up:
```bash
kubectl scale deployment quota-test --replicas=5 -n frontend-team
kubectl describe resourcequota frontend-quota -n frontend-team
kubectl get events -n frontend-team --sort-by='.lastTimestamp'
```

**Analysis Questions:**
1. What happened when you tried to exceed the quota?
2. Which resources are being tracked and which aren't?
3. How can you tell how much quota is remaining?

### Mini-Project 2: Advanced Quota Strategies

**Challenge:** Design quotas for different use cases:

**Scenario A: Development Environment**
```yaml
# development-quota.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: dev-quota
  namespace: development
spec:
  hard:
    # What quotas would you set for development?
    # Consider: experimentation needs vs resource waste
```

**Scenario B: Production Environment**
```yaml
# production-quota.yaml  
apiVersion: v1
kind: ResourceQuota
metadata:
  name: prod-quota
  namespace: production
spec:
  hard:
    # What quotas would you set for production?
    # Consider: reliability vs resource efficiency
```

**Design Questions:**
1. Should development have higher or lower limits than production? Why?
2. What non-compute resources should be included in quotas?
3. How would you handle seasonal traffic spikes?

**Advanced Quota Exercise:**
```yaml
# comprehensive-quota.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: comprehensive-quota
  namespace: test-comprehensive
spec:
  hard:
    # Compute resources
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    
    # Object counts
    pods: "20"
    services: "10"
    secrets: "10"
    configmaps: "10"
    persistentvolumeclaims: "5"
    
    # Storage
    requests.storage: 100Gi
    
    # Networking
    services.loadbalancers: "2"
    services.nodeports: "2"
```

**Testing Challenge:**
Create applications that test each quota type. What creative ways can you find to hit different limits?

## Part 3: LimitRanges for Default Values

### Discovery Exercise: The Default Resource Problem

**Problem Setup:**
```yaml
# no-resources-specified.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: no-limits
  namespace: frontend-team
spec:
  replicas: 3
  selector:
    matchLabels:
      app: no-limits
  template:
    metadata:
      labels:
        app: no-limits
    spec:
      containers:
      - name: app
        image: nginx
        # No resources specified!
```

**Investigation Questions:**
1. Will this deployment succeed in your quota-enabled namespace?
2. What resource values will the pods actually get?
3. How does this affect your quota calculations?

### Mini-Project 3: LimitRange Implementation

**Step 1: Create a LimitRange**
```yaml
# frontend-limitrange.yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: frontend-limits
  namespace: frontend-team
spec:
  limits:
  - type: "Container"
    default:
      cpu: "200m"
      memory: "256Mi"
    defaultRequest:
      cpu: "100m"
      memory: "128Mi"
    max:
      cpu: "1000m"
      memory: "2Gi"
    min:
      cpu: "50m"
      memory: "64Mi"
  - type: "Pod"
    max:
      cpu: "2000m"
      memory: "4Gi"
```

**Step 2: Test Default Behavior**
```bash
# Deploy the no-limits application from above
kubectl apply -f no-resources-specified.yaml

# Examine what resources were assigned
kubectl describe pods -n frontend-team -l app=no-limits
```

**Step 3: Test Limit Enforcement**
```yaml
# limit-test.yaml
apiVersion: v1
kind: Pod
metadata:
  name: limit-test
  namespace: frontend-team
spec:
  containers:
  - name: test
    image: nginx
    resources:
      requests:
        cpu: "2000m"  # This exceeds our max!
        memory: "3Gi"
```

**Analysis Tasks:**
1. What happened when you applied the limit-test pod?
2. How do LimitRanges interact with ResourceQuotas?
3. What would happen if you deployed a pod with no resource specification?

### Discovery Exercise: LimitRange Strategies

**Design Challenge:**
Create different LimitRange strategies for different scenarios:

**Strategy A: Conservative Defaults**
```yaml
# For cost-conscious environments
spec:
  limits:
  - type: "Container"
    default:
      cpu: "100m"
      memory: "128Mi"
    # Small defaults, force explicit resource requests for more
```

**Strategy B: Performance-Oriented Defaults**
```yaml
# For performance-critical environments
spec:
  limits:  
  - type: "Container"
    default:
      cpu: "500m"
      memory: "512Mi"
    # Higher defaults, optimize for performance over cost
```

**Analysis Questions:**
1. When would you choose each strategy?
2. How do these decisions affect development vs production environments?
3. What's the relationship between defaults and maximum values?

## Part 4: Monitoring and Troubleshooting

### Discovery Exercise: Resource Monitoring

**Monitoring Setup:**
```bash
# Check current resource usage
kubectl top nodes
kubectl top pods --all-namespaces --sort-by=cpu
kubectl top pods --all-namespaces --sort-by=memory

# Monitor quota usage across namespaces
kubectl get resourcequota --all-namespaces
kubectl describe resourcequota --all-namespaces
```

**Investigation Questions:**
1. Which namespaces are using the most resources?
2. How close are any namespaces to hitting their quotas?
3. Are there pods using significantly more resources than others?

### Mini-Project 4: Resource Monitoring Dashboard

**Challenge:** Create scripts to monitor resource usage and quota consumption.

**Implementation:**
```bash
#!/bin/bash
# resource-monitor.sh

echo "=== Cluster Resource Overview ==="
kubectl top nodes

echo "=== Namespace Quota Usage ==="
for ns in $(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}'); do
    echo "--- Namespace: $ns ---"
    kubectl describe resourcequota -n $ns 2>/dev/null || echo "No quotas defined"
done

echo "=== High Resource Usage Pods ==="
kubectl top pods --all-namespaces --sort-by=memory | head -10

# Your additional monitoring logic here
```

**Enhancement Ideas:**
1. Add alerts when namespaces approach quota limits
2. Identify pods without resource specifications
3. Find unused or over-allocated resources
4. Track resource trends over time

### Discovery Exercise: Common Troubleshooting Scenarios

**Scenario A: Pods Won't Schedule**
```bash
# Create this problem:
kubectl create namespace quota-problem
kubectl apply -f - <<EOF
apiVersion: v1
kind: ResourceQuota
metadata:
  name: tiny-quota
  namespace: quota-problem
spec:
  hard:
    requests.memory: "100Mi"
    limits.memory: "200Mi"
EOF

# Try to deploy something larger
kubectl create deployment big-app --image=nginx --namespace=quota-problem
kubectl patch deployment big-app -n quota-problem -p '{"spec":{"template":{"spec":{"containers":[{"name":"nginx","resources":{"requests":{"memory":"500Mi"}}}]}}}}'
```

**Troubleshooting Exercise:**
1. What symptoms would you see?
2. What commands would you use to diagnose the issue?
3. How would you resolve it?

**Scenario B: Quota Exceeded Unexpectedly**
```bash
# Create a scenario where quota is mysteriously consumed
kubectl create namespace mystery-quota
# Set up quota and test applications
# Challenge: Find what's consuming the quota
```

**Diagnostic Process:**
1. How would you inventory all resources in the namespace?
2. What might consume quota besides obvious deployments?
3. How do you handle resources that are stuck or failed?

## Part 5: Real-World Application

### Comprehensive Scenario: Multi-Team Resource Management

**Your Challenge:**
Design and implement resource management for a realistic multi-team environment:

**Organization Setup:**
- **3 Teams:** Frontend, Backend, Data Science
- **3 Environments per team:** Development, Staging, Production
- **Cluster Resources:** 64 CPU cores, 256GB RAM
- **Business Requirements:**
  - Production gets priority over dev/staging
  - Data Science needs burst capability for training jobs
  - Frontend needs consistent performance
  - Cost optimization is important

**Design Phase Questions:**
1. How will you allocate resources across 9 namespaces?
2. What quota strategy handles both steady-state and burst needs?
3. How will you ensure production workloads aren't impacted by development?

**Implementation Challenge:**

**Step 1: Resource Allocation Strategy**
```yaml
# Create your allocation plan
# Production: Frontend(4 CPU, 16GB), Backend(8 CPU, 32GB), Data(12 CPU, 48GB)  
# Staging: 50% of production
# Development: 25% of production
# How will you implement this with quotas?
```

**Step 2: LimitRange Strategy**
```yaml
# Design LimitRanges that:
# - Prevent resource waste in development
# - Allow flexibility in production  
# - Handle data science workload patterns
```

**Step 3: Monitoring and Alerting**
```bash
# Create monitoring that:
# - Tracks quota utilization trends
# - Alerts on approaching limits
# - Identifies resource waste
```

### Advanced Challenge: Dynamic Resource Management

**Scenario:** Your resource needs vary significantly:
- Data science runs large training jobs monthly
- Frontend has traffic spikes during business hours
- Backend load varies with business cycles

**Questions to Address:**
1. How can quotas adapt to changing needs?
2. What tools could automate quota adjustments?
3. How do you balance fairness with efficiency?

**Research Exercise:**
Investigate these advanced patterns:
- Vertical Pod Autoscaler (VPA) impact on quotas
- Horizontal Pod Autoscaler (HPA) interaction with limits
- Cluster autoscaling in quota-constrained environments

## Unit Assessment

### Practical Skills Verification

**Assessment Challenge:**
Implement a complete resource management solution:

1. **Design Phase:**
   - Plan resource allocation for a multi-team scenario
   - Design quota and limit strategies
   - Create monitoring and alerting approach

2. **Implementation Phase:**
   - Deploy ResourceQuotas and LimitRanges
   - Create test applications that validate your design
   - Implement monitoring scripts or dashboards

3. **Testing Phase:**
   - Demonstrate quota enforcement working correctly
   - Show how your solution handles resource contention
   - Prove monitoring detects and alerts on issues

### Troubleshooting Scenarios

**Scenario-Based Assessment:**
1. **Mystery Resource Consumption:** A namespace is hitting quota limits but deployed applications don't account for all usage. Diagnose and resolve.

2. **Scheduling Failures:** Pods are failing to schedule with "Insufficient resources" errors despite apparent node capacity. Investigate and fix.

3. **Performance Degradation:** Applications are running slower than expected in a quota-constrained environment. Optimize resource allocation.

### Knowledge Integration Questions

1. **Design Question:** You need to migrate from unlimited resource usage to quota-based management. What's your migration strategy?

2. **Scaling Question:** Your cluster is growing from 3 to 30 namespaces. How does this change your resource management approach?

3. **Economics Question:** Balance cost optimization with performance requirements in your quota design.

### Preparation for Unit 5

**Preview Considerations:**
1. How do resource quotas interact with security policies?
2. What happens when you need to restrict not just resources, but actions?
3. How would you ensure that only authorized users can modify resource quotas?

**Coming Next:** In Unit 5, we'll explore security and RBAC (Role-Based Access Control), learning to implement fine-grained permissions, secure namespace boundaries, and integrate with organizational security policies.

## Quick Reference

### ResourceQuota Examples
```yaml
# Basic compute quota
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"  
    limits.memory: 16Gi

# Comprehensive quota
spec:
  hard:
    pods: "10"
    services: "5"
    secrets: "10"
    configmaps: "10"
    persistentvolumeclaims: "5"
    requests.storage: 100Gi
```

### LimitRange Examples
```yaml
# Container limits
spec:
  limits:
  - type: "Container"
    default:
      cpu: "200m"
      memory: "256Mi"
    defaultRequest:
      cpu: "100m"
      memory: "128Mi"
    max:
      cpu: "1000m"
      memory: "2Gi"
    min:
      cpu: "50m"
      memory: "64Mi"
```

### Monitoring Commands
```bash
# Resource usage
kubectl top nodes
kubectl top pods -A --sort-by=memory

# Quota status
kubectl describe resourcequota -A
kubectl get limitrange -A

# Troubleshooting
kubectl describe pod <pod-name> | grep -A10 "Conditions\|Events"
kubectl get events --sort-by='.lastTimestamp' -n <namespace>
```