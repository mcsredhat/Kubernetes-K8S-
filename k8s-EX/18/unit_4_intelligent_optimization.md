# Unit 4: Intelligent Resource Optimization
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