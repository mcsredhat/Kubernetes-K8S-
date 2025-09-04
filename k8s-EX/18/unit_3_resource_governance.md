# Unit 3: Resource Governance & Policies
**Duration**: 3-4 hours  
**Core Question**: "How do I prevent any single application from consuming all cluster resources?"

## 🎯 Learning Objectives
By the end of this unit, you will:
- Implement ResourceQuotas to control namespace-level resource consumption
- Configure LimitRanges to enforce pod-level resource constraints
- Design Pod Disruption Budgets for application availability
- Create comprehensive governance policies for multi-tenant clusters
- Troubleshoot resource policy conflicts and violations

## 🔗 Connecting from Previous Units

In Units 1 and 2, you learned to set and monitor resources for individual applications. But what happens when you have:
- Multiple teams sharing a cluster?
- Applications deployed without proper resource specifications?
- A need to guarantee availability during maintenance?

**🤔 Reflection Questions**: 
- What would happen if someone deployed 100 pods without resource limits on your cluster?
- How would you ensure critical applications get resources during peak demand?
- What policies would you implement to enforce your organization's resource standards?

Today we'll explore the governance layer that makes Kubernetes suitable for production multi-tenant environments.

---

## 🏛️ Foundation: The Governance Hierarchy

### Step 1: Understanding the Control Layers

Let's visualize how Kubernetes resource governance works:

```bash
# Set up our governance lab environment
kubectl create namespace governance-lab
kubectl config set-context --current --namespace=governance-lab

# Create a simple deployment to work with
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
    spec:
      containers:
      - name: app
        image: nginx:alpine
        # Notice: NO resource specifications yet
EOF

# Observe current behavior - pods without governance
kubectl get pods -o wide
kubectl describe deployment test-app
```

**🤔 Discovery Questions**:
1. Were the pods successfully scheduled?
2. What QoS class do they have?
3. What could go wrong with this deployment in a shared environment?

### Step 2: Your First Governance Policy - LimitRange

LimitRange acts as a "building code" - it enforces minimum and maximum standards for individual resources:

```bash
# Create a LimitRange to enforce resource standards
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: resource-standards
  namespace: governance-lab
spec:
  limits:
  # Rules for individual containers
  - type: Container
    default:           # Default limits applied if none specified
      cpu: 200m
      memory: 256Mi
    defaultRequest:    # Default requests applied if none specified
      cpu: 100m
      memory: 128Mi
    min:              # Minimum required values
      cpu: 50m
      memory: 64Mi
    max:              # Maximum allowed values
      cpu: 2
      memory: 4Gi
  # Rules for entire pods
  - type: Pod
    max:
      cpu: 4
      memory: 8Gi
  # Rules for persistent volume claims
  - type: PersistentVolumeClaim
    min:
      storage: 1Gi
    max:
      storage: 100Gi
EOF

# Check what was applied
kubectl describe limitrange resource-standards
```

Now let's see the LimitRange in action:

```bash
# Delete the existing deployment and recreate it
kubectl delete deployment test-app
kubectl apply -f - << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app-with-limits
spec:
  replicas: 2
  selector:
    matchLabels:
      app: test-app-limited
  template:
    metadata:
      labels:
        app: test-app-limited
    spec:
      containers:
      - name: app
        image: nginx:alpine
        # Still no resource specifications!
EOF

# Check what happened to the new pods
kubectl describe pod $(kubectl get pods -l app=test-app-limited -o jsonpath='{.items[0].metadata.name}') | grep -A 10 "Limits:\|Requests:"
```

**🎯 Discovery Challenge**:
1. What resources were automatically applied to the new pods?
2. Where did these values come from?
3. What happens if you try to create a pod that violates the LimitRange?

Let's test the boundaries:

```bash
# Try to create a pod that exceeds the maximum limits
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: resource-hog
spec:
  containers:
  - name: greedy
    image: nginx:alpine
    resources:
      requests:
        cpu: 3         # Exceeds max of 2
        memory: 6Gi    # Exceeds max of 4Gi
      limits:
        cpu: 5         # Way over the limit!
        memory: 10Gi   # Way over the limit!
EOF

# Check if it was accepted
kubectl get pod resource-hog
kubectl describe pod resource-hog
```

**🤔 What Happened?**: The pod creation should have been rejected. This demonstrates how LimitRange provides the first line of defense against resource abuse.

### Step 3: Namespace-Level Control - ResourceQuota

While LimitRange controls individual resources, ResourceQuota controls the total resources consumed across an entire namespace:

```bash
# Create a ResourceQuota for the namespace
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: namespace-quota
  namespace: governance-lab
spec:
  hard:
    # Compute quotas
    requests.cpu: "1"        # Total CPU requests across all pods
    requests.memory: 2Gi     # Total memory requests across all pods
    limits.cpu: "2"          # Total CPU limits across all pods
    limits.memory: 4Gi       # Total memory limits across all pods
    
    # Object count quotas
    pods: "10"               # Maximum number of pods
    persistentvolumeclaims: "4"  # Maximum PVCs
    services: "3"            # Maximum services
    secrets: "10"            # Maximum secrets
    configmaps: "10"         # Maximum configmaps
    
    # Storage quotas
    requests.storage: 20Gi   # Total storage requests
EOF

# Check the quota status
kubectl describe resourcequota namespace-quota
```

**🎯 Understanding the Output**:
- Used: How much is currently consumed
- Hard: The maximum allowed limits
- Used/Hard ratio shows remaining capacity

Now let's test the quota enforcement:

```bash
# Try to scale beyond the quota
kubectl scale deployment test-app-with-limits --replicas=8

# Check what happens
kubectl get pods
kubectl get events --field-selector reason=FailedCreate

# Check quota status again
kubectl describe resourcequota namespace-quota
```

**🤔 Analysis Questions**:
1. How many pods were actually created vs requested?
2. What error message explains why some pods couldn't be created?
3. How does the quota status reflect the current usage?

---

## 🧪 Guided Lab: Designing a Multi-Tenant Environment

Let's create a realistic scenario: a cluster shared between Development, Staging, and Production teams.

### Lab Setup: Creating Team Namespaces

```bash
# Create namespaces for different teams/environments
kubectl create namespace team-dev
kubectl create namespace team-staging  
kubectl create namespace team-prod

# Label them for easier management
kubectl label namespace team-dev environment=development team=devops
kubectl label namespace team-staging environment=staging team=devops
kubectl label namespace team-prod environment=production team=devops
```

### Lab Step 1: Environment-Specific Governance Policies

**Development Environment**: Flexible but with safety limits
```bash
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: dev-limits
  namespace: team-dev
spec:
  limits:
  - type: Container
    default:
      cpu: 500m        # Higher defaults for development
      memory: 512Mi
    defaultRequest:
      cpu: 100m
      memory: 128Mi
    min:
      cpu: 10m         # Very low minimums for experimentation
      memory: 16Mi
    max:
      cpu: 2           # Reasonable maximums
      memory: 4Gi
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: dev-quota
  namespace: team-dev
spec:
  hard:
    requests.cpu: "4"      # Generous CPU allocation
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    pods: "50"             # Allow many experimental pods
    services: "10"
EOF
```

**Production Environment**: Strict controls for stability
```bash
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: prod-limits
  namespace: team-prod
spec:
  limits:
  - type: Container
    default:
      cpu: 200m        # Conservative defaults
      memory: 256Mi
    defaultRequest:
      cpu: 100m
      memory: 128Mi
    min:
      cpu: 50m         # Higher minimums ensure reliability
      memory: 64Mi
    max:
      cpu: 1           # Controlled maximums
      memory: 2Gi
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: prod-quota
  namespace: team-prod
spec:
  hard:
    requests.cpu: "10"     # Large but controlled allocation
    requests.memory: 20Gi
    limits.cpu: "20"
    limits.memory: 40Gi
    pods: "30"             # Fewer pods, but more resources each
    services: "8"
    # Additional production-specific controls
    secrets: "20"
    configmaps: "15"
EOF
```

**Staging Environment**: Balanced approach
```bash
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: staging-limits
  namespace: team-staging
spec:
  limits:
  - type: Container
    default:
      cpu: 300m
      memory: 384Mi
    defaultRequest:
      cpu: 100m
      memory: 128Mi
    min:
      cpu: 25m
      memory: 32Mi
    max:
      cpu: 1500m
      memory: 3Gi
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: staging-quota
  namespace: team-staging
spec:
  hard:
    requests.cpu: "6"
    requests.memory: 12Gi
    limits.cpu: "12"
    limits.memory: 24Gi
    pods: "40"
    services: "8"
EOF
```

### Lab Step 2: Testing the Multi-Tenant Policies

Let's deploy the same application to each environment and observe the differences:

```bash
# Create identical deployments across environments
for env in dev staging prod; do
  cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: team-$env
spec:
  replicas: 3
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
        # No resource specs - let's see what each environment applies
EOF
done

# Wait for deployments
sleep 10
```

Now let's analyze the differences:

```bash
# Compare resource specifications applied by each environment
echo "=== DEVELOPMENT ENVIRONMENT ==="
kubectl describe pod $(kubectl get pods -n team-dev -l app=web-app -o jsonpath='{.items[0].metadata.name}') -n team-dev | grep -A 5 "Limits:\|Requests:"

echo -e "\n=== STAGING ENVIRONMENT ==="
kubectl describe pod $(kubectl get pods -n team-staging -l app=web-app -o jsonpath='{.items[0].metadata.name}') -n team-staging | grep -A 5 "Limits:\|Requests:"

echo -e "\n=== PRODUCTION ENVIRONMENT ==="
kubectl describe pod $(kubectl get pods -n team-prod -l app=web-app -o jsonpath='{.items[0].metadata.name}') -n team-prod | grep -A 5 "Limits:\|Requests:"

# Check quota utilization across environments
echo -e "\n=== QUOTA UTILIZATION ==="
for env in dev staging prod; do
  echo "--- team-$env ---"
  kubectl get resourcequota -n team-$env -o custom-columns="NAMESPACE:.metadata.namespace,CPU-USED:.status.used.requests\.cpu,CPU-HARD:.status.hard.requests\.cpu,MEMORY-USED:.status.used.requests\.memory,MEMORY-HARD:.status.hard.requests\.memory"
done
```

**🎯 Analysis Challenge**:
1. How do the applied resource specifications differ between environments?
2. Which environment has the most restrictive policies and why?
3. How much of each environment's quota is currently being used?

### Lab Step 3: Simulating Team Conflicts

Let's see what happens when teams try to exceed their allocations:

```bash
# Try to create a large deployment in development
kubectl create deployment resource-heavy -n team-dev --image=nginx:alpine --replicas=20

# Check what happens
kubectl get pods -n team-dev | grep resource-heavy
kubectl describe resourcequota dev-quota -n team-dev

# Try to create a resource-intensive pod in production
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: resource-intensive
  namespace: team-prod
spec:
  containers:
  - name: heavy
    image: nginx:alpine
    resources:
      requests:
        cpu: 1500m     # This exceeds prod LimitRange max
        memory: 3Gi
      limits:
        cpu: 2500m
        memory: 5Gi
EOF

# Check if it was accepted
kubectl get pod resource-intensive -n team-prod
kubectl describe pod resource-intensive -n team-prod
```

**🤔 Conflict Resolution Questions**:
1. What prevented each violation from succeeding?
2. How would you explain these failures to the development teams?
3. What process would you implement for requesting quota increases?

---

## 🛡️ Advanced Governance: Pod Disruption Budgets

Pod Disruption Budgets (PDBs) ensure application availability during voluntary disruptions like node maintenance or cluster upgrades.

### Step 1: Understanding Disruption Types

```bash
# Create a multi-replica application for PDB testing
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: critical-service
  namespace: governance-lab
spec:
  replicas: 5
  selector:
    matchLabels:
      app: critical-service
  template:
    metadata:
      labels:
        app: critical-service
    spec:
      containers:
      - name: service
        image: nginx:alpine
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
EOF

# Wait for all replicas to be ready
kubectl rollout status deployment/critical-service -n governance-lab
```

### Step 2: Implementing Pod Disruption Budgets

```bash
# Create a PDB that ensures high availability
cat << EOF | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: critical-service-pdb
  namespace: governance-lab
spec:
  minAvailable: 3        # Keep at least 3 pods running
  selector:
    matchLabels:
      app: critical-service
EOF

# Alternative approach: specify maximum unavailable
cat << EOF | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web-app-pdb
  namespace: governance-lab
spec:
  maxUnavailable: 1      # Allow at most 1 pod to be disrupted
  selector:
    matchLabels:
      app: web-app
EOF

# Check PDB status
kubectl get pdb -n governance-lab
kubectl describe pdb critical-service-pdb -n governance-lab
```

**🎯 Understanding PDB Status**:
- ALLOWED DISRUPTIONS: How many pods can currently be disrupted
- MIN AVAILABLE: Minimum pods that must remain running
- CURRENT: Currently healthy pods

### Step 3: Testing PDB Protection

```bash
# Simulate voluntary disruption (like node drain)
# First, let's see which node our pods are on
kubectl get pods -n governance-lab -o wide

# Get pod names for manual deletion simulation
pod_names=($(kubectl get pods -n governance-lab -l app=critical-service -o jsonpath='{.items[*].metadata.name}'))

echo "Attempting to disrupt pods one by one..."
for pod in "${pod_names[@]:0:3}"; do  # Try to delete first 3 pods
    echo "Attempting to delete $pod"
    kubectl delete pod $pod -n governance-lab --grace-period=1
    sleep 2
    
    # Check PDB status after each deletion
    kubectl get pdb critical-service-pdb -n governance-lab
    kubectl get pods -n governance-lab -l app=critical-service
    echo "---"
done
```

**🤔 Observation Questions**:
1. How many pods were successfully deleted before PDB protection kicked in?
2. What happens to the "ALLOWED DISRUPTIONS" count as pods are deleted?
3. How quickly do replacement pods get scheduled?

### Step 4: Advanced PDB Patterns

```bash
# Pattern 1: Percentage-based PDB for variable replica counts
cat << EOF | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: flexible-pdb
  namespace: governance-lab
spec:
  minAvailable: 60%      # Keep at least 60% of pods running
  selector:
    matchLabels:
      tier: web
EOF

# Pattern 2: Multiple PDBs for different disruption scenarios
cat << EOF | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: database-pdb
  namespace: governance-lab
spec:
  minAvailable: 1        # For single-master databases
  selector:
    matchLabels:
      app: database
      role: master
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: database-replica-pdb
  namespace: governance-lab  
spec:
  maxUnavailable: 2      # Can disrupt up to 2 read replicas
  selector:
    matchLabels:
      app: database
      role: replica
EOF

# Check all PDBs
kubectl get pdb -n governance-lab -o wide
```

---

## 🚀 Advanced Lab: Complete Governance Architecture

Let's build a comprehensive governance system for a realistic organization.

### Lab Scenario: TechCorp Kubernetes Platform

TechCorp has these requirements:
- **3 environments**: dev, staging, production
- **4 teams**: frontend, backend, data, platform
- **Service tiers**: critical, important, standard
- **Compliance**: Must prevent resource abuse and ensure availability

### Lab Step 1: Organization-Wide Policies

```bash
# Create the organizational structure
for env in dev staging prod; do
  for team in frontend backend data platform; do
    kubectl create namespace ${env}-${team}
    kubectl label namespace ${env}-${team} environment=$env team=$team
  done
done

# Create a policy template system
mkdir -p governance-policies
```

**Base Policy Templates**:

```bash
# Create base LimitRange template
cat << 'EOF' > governance-policies/limitrange-template.yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: ${ENVIRONMENT}-limits
  namespace: ${NAMESPACE}
spec:
  limits:
  - type: Container
    default:
      cpu: ${DEFAULT_CPU_LIMIT}
      memory: ${DEFAULT_MEMORY_LIMIT}
    defaultRequest:
      cpu: ${DEFAULT_CPU_REQUEST}
      memory: ${DEFAULT_MEMORY_REQUEST}
    min:
      cpu: ${MIN_CPU}
      memory: ${MIN_MEMORY}
    max:
      cpu: ${MAX_CPU}
      memory: ${MAX_MEMORY}
  - type: Pod
    max:
      cpu: ${POD_MAX_CPU}
      memory: ${POD_MAX_MEMORY}
EOF

# Create base ResourceQuota template
cat << 'EOF' > governance-policies/quota-template.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ${ENVIRONMENT}-quota
  namespace: ${NAMESPACE}
spec:
  hard:
    requests.cpu: "${QUOTA_CPU_REQUESTS}"
    requests.memory: ${QUOTA_MEMORY_REQUESTS}
    limits.cpu: "${QUOTA_CPU_LIMITS}"
    limits.memory: ${QUOTA_MEMORY_LIMITS}
    pods: "${QUOTA_PODS}"
    services: "${QUOTA_SERVICES}"
    secrets: "${QUOTA_SECRETS}"
    configmaps: "${QUOTA_CONFIGMAPS}"
EOF

# Create environment-specific configurations
cat << 'EOF' > governance-policies/apply-policies.sh
#!/bin/bash

# Environment-specific resource allocations
declare -A ENV_CONFIGS
ENV_CONFIGS[dev]="DEFAULT_CPU_LIMIT=500m DEFAULT_MEMORY_LIMIT=512Mi DEFAULT_CPU_REQUEST=100m DEFAULT_MEMORY_REQUEST=128Mi MIN_CPU=10m MIN_MEMORY=16Mi MAX_CPU=2 MAX_MEMORY=4Gi POD_MAX_CPU=4 POD_MAX_MEMORY=8Gi"
ENV_CONFIGS[staging]="DEFAULT_CPU_LIMIT=300m DEFAULT_MEMORY_LIMIT=384Mi DEFAULT_CPU_REQUEST=100m DEFAULT_MEMORY_REQUEST=128Mi MIN_CPU=50m MIN_MEMORY=32Mi MAX_CPU=1500m MAX_MEMORY=3Gi POD_MAX_CPU=3 POD_MAX_MEMORY=6Gi"
ENV_CONFIGS[prod]="DEFAULT_CPU_LIMIT=200m DEFAULT_MEMORY_LIMIT=256Mi DEFAULT_CPU_REQUEST=100m DEFAULT_MEMORY_REQUEST=128Mi MIN_CPU=50m MIN_MEMORY=64Mi MAX_CPU=1 MAX_MEMORY=2Gi POD_MAX_CPU=2 POD_MAX_MEMORY=4Gi"

# Team-specific quota allocations  
declare -A TEAM_QUOTAS
TEAM_QUOTAS[frontend]="QUOTA_CPU_REQUESTS=4 QUOTA_MEMORY_REQUESTS=8Gi QUOTA_CPU_LIMITS=8 QUOTA_MEMORY_LIMITS=16Gi QUOTA_PODS=30"
TEAM_QUOTAS[backend]="QUOTA_CPU_REQUESTS=6 QUOTA_MEMORY_REQUESTS=12Gi QUOTA_CPU_LIMITS=12 QUOTA_MEMORY_LIMITS=24Gi QUOTA_PODS=25"
TEAM_QUOTAS[data]="QUOTA_CPU_REQUESTS=3 QUOTA_MEMORY_REQUESTS=16Gi QUOTA_CPU_LIMITS=6 QUOTA_MEMORY_LIMITS=32Gi QUOTA_PODS=15"
TEAM_QUOTAS[platform]="QUOTA_CPU_REQUESTS=2 QUOTA_MEMORY_REQUESTS=4Gi QUOTA_CPU_LIMITS=4 QUOTA_MEMORY_LIMITS=8Gi QUOTA_PODS=20"

# Apply policies to all namespaces
for env in dev staging prod; do
  for team in frontend backend data platform; do
    namespace="${env}-${team}"
    echo "Applying policies to ${namespace}..."
    
    # Set environment variables
    export ENVIRONMENT=$env
    export NAMESPACE=$namespace
    eval "${ENV_CONFIGS[$env]}"
    eval "${TEAM_QUOTAS[$team]}"
    export QUOTA_SERVICES=5 QUOTA_SECRETS=10 QUOTA_CONFIGMAPS=10
    
    # Apply LimitRange
    envsubst < limitrange-template.yaml | kubectl apply -f -
    
    # Apply ResourceQuota  
    envsubst < quota-template.yaml | kubectl apply -f -
    
    echo "Applied policies to ${namespace}"
  done
done

echo "All governance policies applied!"
EOF

chmod +x governance-policies/apply-policies.sh
cd governance-policies && ./apply-policies.sh
cd ..
```

### Lab Step 2: Service Tier-Based PDBs

```bash
# Create PDB templates for different service tiers
cat << EOF | kubectl apply -f -
# Critical services - must maintain 80% availability
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: critical-service-pdb
  namespace: prod-frontend
spec:
  minAvailable: 80%
  selector:
    matchLabels:
      tier: critical
---
# Important services - can handle some disruption
apiVersion: policy/v1  
kind: PodDisruptionBudget
metadata:
  name: important-service-pdb
  namespace: prod-backend
spec:
  maxUnavailable: 25%
  selector:
    matchLabels:
      tier: important
---
# Standard services - more flexible disruption tolerance
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: standard-service-pdb
  namespace: prod-data
spec:
  maxUnavailable: 50%
  selector:
    matchLabels:
      tier: standard
EOF
```

### Lab Step 3: Testing the Complete System

Let's deploy applications across the organization and test the governance:

```bash
# Deploy applications with different characteristics to test policies
cat << EOF | kubectl apply -f -
# Critical frontend service in production
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-portal
  namespace: prod-frontend
spec:
  replicas: 6
  selector:
    matchLabels:
      app: user-portal
  template:
    metadata:
      labels:
        app: user-portal
        tier: critical
    spec:
      containers:
      - name: portal
        image: nginx:alpine
        resources:
          requests:
            cpu: 150m
            memory: 200Mi
          limits:
            cpu: 300m
            memory: 400Mi
---
# Backend API service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-service
  namespace: prod-backend
spec:
  replicas: 4
  selector:
    matchLabels:
      app: api-service
  template:
    metadata:
      labels:
        app: api-service
        tier: important
    spec:
      containers:
      - name: api
        image: nginx:alpine
        resources:
          requests:
            cpu: 200m
            memory: 300Mi
          limits:
            cpu: 500m
            memory: 600Mi
---
# Development experimentation
apiVersion: apps/v1
kind: Deployment
metadata:
  name: experiment
  namespace: dev-frontend
spec:
  replicas: 10  # This might hit quota limits
  selector:
    matchLabels:
      app: experiment
  template:
    metadata:
      labels:
        app: experiment
        tier: standard
    spec:
      containers:
      - name: experiment
        image: nginx:alpine
        # No resource specs - will get defaults from LimitRange
EOF

# Wait and check deployment status
sleep 10
```

Now let's analyze what happened:

```bash
# Check deployment success across namespaces
echo "=== DEPLOYMENT STATUS ANALYSIS ==="
for namespace in prod-frontend prod-backend dev-frontend; do
  echo "--- $namespace ---"
  kubectl get deployments -n $namespace
  kubectl get pods -n $namespace | grep -v Running | head -5
  echo ""
done

# Check quota utilization
echo "=== QUOTA UTILIZATION ==="
for env in dev prod; do
  for team in frontend backend; do
    namespace="${env}-${team}"
    echo "--- $namespace ---"
    kubectl describe resourcequota ${env}-quota -n $namespace | grep -A 10 "Resource\|Used:"
    echo ""
  done
done

# Check PDB status for critical services
echo "=== PDB PROTECTION STATUS ==="
kubectl get pdb --all-namespaces
```

**🎯 Comprehensive Analysis Questions**:
1. Which deployments were successful and which hit resource constraints?
2. How did the different environment policies affect resource allocation?
3. What would happen if you tried to scale the critical service during maintenance?

---

## 🔧 Troubleshooting Governance Issues

Let's explore common governance problems and solutions:

### Common Issue 1: Resource Quota Exceeded

```bash
# Create a script to diagnose quota issues
cat << 'EOF' > diagnose-quota-issues.sh
#!/bin/bash
NAMESPACE=${1:-governance-lab}

echo "🔍 QUOTA TROUBLESHOOTING FOR: $NAMESPACE"
echo "========================================"

# Check current quota status
echo "📊 CURRENT QUOTA STATUS"
kubectl describe resourcequota -n $NAMESPACE 2>/dev/null || echo "No ResourceQuota found"

echo ""
echo "📋 RESOURCE CONSUMPTION BREAKDOWN"
echo "--------------------------------"

# Calculate actual resource consumption
echo "Current pod resource requests:"
kubectl get pods -n $NAMESPACE -o json | jq -r '
  .items[] | 
  select(.spec.containers[0].resources.requests != null) |
  "\(.metadata.name): CPU=\(.spec.containers[0].resources.requests.cpu), Memory=\(.spec.containers[0].resources.requests.memory)"
'

echo ""
echo "🚨 RECENT RESOURCE-RELATED EVENTS"
echo "--------------------------------"
kubectl get events -n $NAMESPACE --field-selector reason=FailedCreate | head -10

echo ""
echo "💡 TROUBLESHOOTING STEPS"
echo "----------------------"
echo "1. Check if quota limits are appropriate for workload needs"
echo "2. Look for pods that might be over-requesting resources"
echo "3. Consider if quota should be increased or workload optimized"
echo "4. Check for stuck/failed pods that might be consuming quota"
EOF

chmod +x diagnose-quota-issues.sh
./diagnose-quota-issues.sh prod-frontend
```

### Common Issue 2: LimitRange Conflicts

```bash
# Create a diagnostic for LimitRange issues
cat << 'EOF' > diagnose-limitrange-issues.sh
#!/bin/bash
NAMESPACE=${1:-governance-lab}

echo "🔍 LIMITRANGE TROUBLESHOOTING FOR: $NAMESPACE"
echo "============================================="

# Show current LimitRange configuration
echo "📋 CURRENT LIMITRANGE CONFIGURATION"
kubectl describe limitrange -n $NAMESPACE 2>/dev/null || echo "No LimitRange found"

echo ""
echo "🎯 TESTING COMMON SCENARIOS"
echo "---------------------------"

# Test minimum resource requirements
echo "Testing minimum resource pod creation..."
kubectl apply -f - << EOL
apiVersion: v1
kind: Pod
metadata:
  name: min-resource-test
  namespace: $NAMESPACE
spec:
  containers:
  - name: test
    image: nginx:alpine
    resources:
      requests:
        cpu: 1m      # Very low - might violate minimum
        memory: 1Mi
      limits:
        cpu: 1m
        memory: 1Mi
EOL

sleep 2
kubectl get pod min-resource-test -n $NAMESPACE 2>/dev/null || echo "Pod creation failed - check LimitRange minimums"
kubectl delete pod min-resource-test -n $NAMESPACE --ignore-not-found

echo ""
echo "💡 COMMON LIMITRANGE PROBLEMS"
echo "----------------------------"
echo "1. Pod requests below LimitRange minimum"
echo "2. Pod limits above LimitRange maximum"
echo "3. Default values conflicting with application needs"
echo "4. Missing resource specifications (relying on defaults)"
EOF

chmod +x diagnose-limitrange-issues.sh
./diagnose-limitrange-issues.sh prod-backend
```

### Common Issue 3: PDB Preventing Disruptions

```bash
# Test PDB behavior under different scenarios
cat << 'EOF' > test-pdb-scenarios.sh
#!/bin/bash
NAMESPACE=${1:-governance-lab}

echo "🛡️ PDB SCENARIO TESTING FOR: $NAMESPACE"
echo "======================================"

# Check current PDB status
echo "📋 CURRENT PDB STATUS"
kubectl get pdb -n $NAMESPACE
kubectl describe pdb -n $NAMESPACE

echo ""
echo "🧪 TESTING DISRUPTION SCENARIOS"
echo "------------------------------"

# Scenario 1: Try to disrupt more pods than PDB allows
echo "Scenario 1: Attempting controlled disruption..."
critical_pods=($(kubectl get pods -n $NAMESPACE -l tier=critical -o jsonpath='{.items[*].metadata.name}'))

if [ ${#critical_pods[@]} -gt 0 ]; then
    echo "Found ${#critical_pods[@]} critical pods"
    
    # Try to delete half the pods
    pods_to_delete=$((${#critical_pods[@]} / 2))
    echo "Attempting to delete $pods_to_delete pods simultaneously..."
    
    for pod in "${critical_pods[@]:0:$pods_to_delete}"; do
        kubectl delete pod $pod -n $NAMESPACE --grace-period=0 --force &
    done
    
    wait
    sleep 5
    
    echo "Post-disruption status:"
    kubectl get pdb -n $NAMESPACE
    kubectl get pods -n $NAMESPACE -l tier=critical
else
    echo "No critical pods found for testing"
fi

echo ""
echo "💡 PDB BEST PRACTICES"
echo "-------------------"
echo "1. Set PDB based on application's minimum viable replicas"
echo "2. Consider both planned and unplanned disruptions"
echo "3. Test PDB settings during maintenance windows"
echo "4. Monitor PDB events during cluster operations"
EOF

chmod +x test-pdb-scenarios.sh
./test-pdb-scenarios.sh prod-frontend
```

---

## 🚀 Mini-Project: Governance Policy Designer

Your challenge: Design a complete governance system for a new organization.

### Project Scenario: CloudStart Inc.

CloudStart is launching a new Kubernetes platform with these requirements:

**Organizational Structure**:
- 3 environments: development, staging, production
- 5 teams: web, mobile-api, data-analytics, ml-platform, devops
- 3 service criticality levels: mission-critical, business-important, development

**Business Requirements**:
- Prevent resource abuse while allowing innovation
- Ensure 99.9% uptime for mission-critical services
- Support experimentation in development
- Fair resource allocation between teams
- Cost optimization through governance

### Project Deliverables

**1. Complete Policy Framework**
```bash
mkdir -p cloudstart-governance
cd cloudstart-governance

# Create your policy framework
cat << 'EOF' > policy-framework.md
# CloudStart Kubernetes Governance Framework

## Policy Categories

### 1. Resource Allocation Policies
- Environment-specific resource boundaries
- Team-based quota allocations
- Service-tier resource guarantees

### 2. Availability Policies  
- Mission-critical: 99.9% uptime requirement
- Business-important: 99% uptime requirement
- Development: No uptime guarantee

### 3. Security and Compliance Policies
- Resource isolation between teams
- Audit trail for policy violations
- Emergency override procedures

## Implementation Plan

### Phase 1: Core Policies (Week 1)
- [ ] LimitRange for all namespaces
- [ ] Basic ResourceQuota per team
- [ ] Critical service PDBs

### Phase 2: Advanced Governance (Week 2)  
- [ ] Environment-specific policies
- [ ] Service-tier differentiation
- [ ] Monitoring and alerting

### Phase 3: Optimization (Week 3)
- [ ] Usage analysis and tuning
- [ ] Automated policy adjustment
- [ ] Team self-service tools

EOF
```

**2. Environment-Specific Configurations**
Design resource policies for each environment:

```bash
# Development environment - Innovation focused
cat << EOF > dev-environment-policy.yaml
# Development: Encourage experimentation
# - Higher resource limits for testing
# - More flexible quotas
# - Minimal PDB restrictions
# 
# Your task: Design appropriate values based on:
# - Team needs for experimentation
# - Protection against runaway processes
# - Fair sharing between 5 teams

apiVersion: v1
kind: LimitRange
metadata:
  name: dev-limits
spec:
  limits:
  - type: Container
    default:
      cpu: ???m        # What should this be?
      memory: ???Mi
    defaultRequest:
      cpu: ???m
      memory: ???Mi
    min:
      cpu: ???m        # How low to allow experimentation?
      memory: ???Mi
    max:
      cpu: ???        # Prevent single container abuse
      memory: ???Gi
EOF
```

**3. Service Criticality Matrix**
Create PDB policies based on criticality:

```bash
cat << 'EOF' > service-criticality-matrix.md
# Service Criticality and PDB Design

| Service Level | Uptime Target | PDB Strategy | Justification |
|---------------|---------------|--------------|---------------|
| Mission-Critical | 99.9% | ??? | ??? |
| Business-Important | 99% | ??? | ??? |  
| Development | Best Effort | ??? | ??? |

Your task: Fill in the PDB strategies and justify each choice.

Consider:
- How many replicas typical services have
- Maintenance window requirements  
- Recovery time objectives
- Business impact of downtime
EOF
```

**4. Monitoring and Compliance Dashboard**
```bash
cat << 'EOF' > governance-monitor.sh
#!/bin/bash
echo "🏢 CLOUDSTART GOVERNANCE COMPLIANCE DASHBOARD"
echo "============================================="

# Your task: Create comprehensive governance monitoring
# Include:
# 1. Policy compliance checking
# 2. Resource utilization analysis  
# 3. SLA adherence tracking
# 4. Cost optimization opportunities
# 5. Security policy violations

# Compliance Checks
echo "📊 POLICY COMPLIANCE OVERVIEW"
echo "----------------------------"
# Check: Are all namespaces protected by governance policies?
# Check: Are critical services protected by appropriate PDBs?
# Check: Are teams staying within resource quotas?

echo "💰 COST OPTIMIZATION INSIGHTS"  
echo "----------------------------"
# Calculate: Resource waste across teams
# Identify: Over-provisioned services
# Recommend: Right-sizing opportunities

echo "🚨 SLA COMPLIANCE STATUS"
echo "----------------------"
# Track: Service availability vs targets
# Alert: Services at risk of SLA violations
# Report: Historical compliance trends

echo "🔧 RECOMMENDATIONS"
echo "-----------------"
# Generate actionable recommendations for:
# - Policy adjustments
# - Resource optimization  
# - SLA improvements
EOF
```

### Project Success Criteria

Your governance system should:
- ✅ Prevent any single service from consuming >20% of cluster resources
- ✅ Ensure mission-critical services maintain 99.9% availability
- ✅ Allow development teams to experiment within reasonable boundaries
- ✅ Provide clear feedback when policies are violated
- ✅ Enable cost optimization through resource visibility

### Project Validation Tests

```bash
# Test 1: Resource Abuse Prevention
# Try to create a deployment that would consume excessive resources

# Test 2: Availability Protection
# Simulate node maintenance during peak load

# Test 3: Fair Resource Allocation
# Deploy competing workloads from different teams

# Test 4: Policy Violation Handling
# Attempt various policy violations and verify appropriate responses

# Test 5: Emergency Procedures
# Test ability to override policies during incidents
```

---

## 🧠 Unit 3 Assessment

### Scenario-Based Challenges

**Scenario 1: The Resource Quota Crisis**
A development team reports they can't deploy new features because they're hitting resource quotas, but the staging team's namespace appears mostly empty. How would you:
1. Investigate the actual resource utilization?
2. Determine if the quotas are appropriate?
3. Rebalance resources between teams if needed?

**Scenario 2: The Maintenance Window Dilemma**
You need to perform node maintenance during business hours, but you have services with strict uptime requirements. Your PDBs are preventing you from draining nodes. How would you:
1. Analyze which services are blocking the maintenance?
2. Safely perform the maintenance without violating SLAs?
3. Improve your PDB strategy for future maintenance?

**Scenario 3: The Multi-Tenant Conflict**
Two teams are blaming each other for application performance issues, claiming the other team's workloads are consuming too many resources. How would you:
1. Investigate resource consumption patterns?
2. Implement fair resource allocation?
3. Prevent future conflicts through governance?

### Practical Skills Verification

Can you confidently:

✅ **Design Resource Policies**
- [ ] Create appropriate LimitRanges for different environments
- [ ] Calculate ResourceQuota allocations based on team needs
- [ ] Design PDBs that balance availability with operational flexibility

✅ **Implement Governance**
- [ ] Deploy policies across multiple namespaces efficiently
- [ ] Test policy effectiveness through controlled violations
- [ ] Monitor compliance and usage patterns

✅ **Troubleshoot Policy Issues**
- [ ] Diagnose why pods fail to schedule due to resource constraints
- [ ] Resolve quota exhaustion without compromising other teams
- [ ] Handle PDB conflicts during emergency situations

---

## 📝 Unit 3 Wrap-Up

### Key Governance Principles

**Write your key insights:**

1. **What's the most important lesson about resource governance you learned?**

2. **How would you explain the relationship between LimitRange, ResourceQuota, and PDB to someone new?**

3. **What governance mistake do you think is most common and how would you avoid it?**

### Bridge to Unit 4

In Unit 4, we'll explore intelligent resource optimization through automation. Think about:
- How could you automatically adjust resource specifications based on usage patterns?
- What if Kubernetes could optimize resource allocation without manual intervention?
- How would you implement resource policies that adapt to changing conditions?

The governance foundation you've built here will be essential for safely implementing automated optimization.

---

## 🧹 Lab Cleanup

```bash
# Clean up all governance lab resources
kubectl delete namespace governance-lab

# Clean up CloudStart namespaces (if created)
for env in dev staging prod; do
  for team in frontend backend data platform; do
    kubectl delete namespace ${env}-${team} --ignore-not-found
  done
done

# Clean up CloudStart project namespaces (if created)
for env in development staging production; do
  for team in web mobile-api data-analytics ml-platform devops; do
    kubectl delete namespace ${env}-${team} --ignore-not-found
  done
done

# Clean up scripts and policies
rm -rf governance-policies cloudstart-governance
rm -f diagnose-quota-issues.sh diagnose-limitrange-issues.sh test-pdb-scenarios.sh
```

**🎊 Outstanding Achievement!** You've mastered Kubernetes resource governance. You can now design, implement, and troubleshoot comprehensive resource policies that ensure fair allocation, prevent abuse, and maintain availability in multi-tenant environments.

Ready for Unit 4? We'll explore how to automate resource optimization using Vertical Pod Autoscaling and intelligent scheduling!