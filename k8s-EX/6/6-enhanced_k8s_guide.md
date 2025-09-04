# Understanding Kubernetes Deployments and ReplicaSets: A Complete Hands-On Guide

Think of Kubernetes Deployments as the masterful orchestrators of your application fleet, while ReplicaSets serve as their dedicated lieutenants ensuring the right number of application instances are always running. This hierarchical relationship forms the backbone of scalable, resilient applications in Kubernetes.

In this enhanced guide, we'll progress through carefully designed labs that build your understanding from basic concepts to advanced production patterns. Each section includes practical exercises, troubleshooting scenarios, and real-world projects that reinforce your learning.

## Foundation: Understanding the Controller Hierarchy

Before diving into commands, let's establish the mental model that will guide your understanding. Kubernetes follows a clear hierarchy of responsibility:

**Deployment** → **ReplicaSet** → **Pods**

The Deployment acts as the high-level strategy planner, making decisions about how many instances you need, what version to run, and how to handle updates. The ReplicaSet serves as the tactical executor, maintaining the exact number of pod replicas specified. Finally, Pods represent your actual running applications.

This separation of concerns is crucial because it allows Kubernetes to handle complex scenarios like rolling updates, rollbacks, and scaling operations with remarkable elegance. When you update a Deployment, it creates a new ReplicaSet for the new version while gradually scaling down the old one, ensuring zero-downtime deployments.

### Lab 1: Exploring the Hierarchy (Foundation Level)

Let's start with a hands-on exploration that makes the controller hierarchy tangible and observable.

```bash
#!/bin/bash
# lab1-hierarchy-exploration.sh
# This lab demonstrates the three-tier relationship: Deployment → ReplicaSet → Pods

echo "🔍 Lab 1: Understanding the Controller Hierarchy"
echo "=============================================="

# Step 1: Create a simple deployment and observe the cascade effect
echo "Step 1: Creating deployment and watching the hierarchy emerge..."
kubectl create deployment hierarchy-demo --image=nginx:1.20 --replicas=3

# Give Kubernetes a moment to create resources
sleep 3

# Step 2: Examine each level of the hierarchy
echo -e "\n📋 DEPLOYMENT LEVEL (Strategy & Configuration)"
kubectl get deployments hierarchy-demo -o wide
echo "☝️  Notice: The deployment shows desired vs ready replicas"

echo -e "\n📋 REPLICASET LEVEL (Replica Management)"
kubectl get replicasets -l app=hierarchy-demo -o wide
echo "☝️  Notice: ReplicaSet name includes a hash suffix (pod template signature)"

echo -e "\n📋 POD LEVEL (Running Applications)"
kubectl get pods -l app=hierarchy-demo -o wide
echo "☝️  Notice: Pod names include both deployment and replicaset identifiers"

# Step 3: Demonstrate the ownership chain
echo -e "\n🔗 OWNERSHIP CHAIN DEMONSTRATION"
DEPLOYMENT_UID=$(kubectl get deployment hierarchy-demo -o jsonpath='{.metadata.uid}')
RS_NAME=$(kubectl get rs -l app=hierarchy-demo -o jsonpath='{.items[0].metadata.name}')
RS_OWNER=$(kubectl get rs $RS_NAME -o jsonpath='{.metadata.ownerReferences[0].uid}')

echo "Deployment UID: $DEPLOYMENT_UID"
echo "ReplicaSet Owner UID: $RS_OWNER"

if [ "$DEPLOYMENT_UID" = "$RS_OWNER" ]; then
    echo "✅ Confirmed: Deployment owns the ReplicaSet"
else
    echo "❌ Something's wrong with ownership chain"
fi

# Step 4: Interactive exploration
echo -e "\n🎯 YOUR TURN: Try these commands to deepen understanding"
echo "kubectl describe deployment hierarchy-demo  # See events and conditions"
echo "kubectl describe rs $RS_NAME  # See replica management details"
echo "kubectl get pods -l app=hierarchy-demo --show-labels  # Examine pod labels"

# Step 5: Cleanup prompt
echo -e "\n🧹 When ready to clean up:"
echo "kubectl delete deployment hierarchy-demo"
```

**Learning Checkpoint**: Before moving on, run this lab and answer these questions:

1. How does the ReplicaSet name relate to the Deployment name?
2. What labels are automatically applied to pods created by a Deployment?
3. What happens if you manually delete one of the pods?

### Lab 2: Self-Healing in Action (Foundation Level)

Now let's observe one of Kubernetes' most impressive features: automatic self-healing through the ReplicaSet controller.

```bash
#!/bin/bash
# lab2-self-healing-demo.sh
# This lab demonstrates Kubernetes self-healing capabilities

echo "🏥 Lab 2: Self-Healing Demonstration"
echo "=================================="

# Setup: Create a deployment we can experiment with
kubectl create deployment self-heal-demo --image=nginx:1.20 --replicas=4
echo "Created deployment with 4 replicas..."

# Wait for all pods to be ready
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=self-heal-demo --timeout=60s

# Show initial state
echo -e "\n📊 INITIAL STATE:"
kubectl get pods -l app=self-heal-demo -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName

# Simulate pod failure
echo -e "\n💥 SIMULATING POD FAILURE:"
POD_TO_DELETE=$(kubectl get pods -l app=self-heal-demo -o jsonpath='{.items[0].metadata.name}')
echo "Deleting pod: $POD_TO_DELETE"

# Start monitoring before deletion
kubectl get pods -l app=self-heal-demo -w &
WATCH_PID=$!

# Delete the pod
kubectl delete pod $POD_TO_DELETE

# Let the user observe for 30 seconds
echo "🔍 Observing self-healing for 30 seconds..."
sleep 30

# Stop the watch
kill $WATCH_PID 2>/dev/null

echo -e "\n📊 FINAL STATE:"
kubectl get pods -l app=self-heal-demo -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,AGE:.metadata.creationTimestamp

echo -e "\n🎯 WHAT YOU SHOULD OBSERVE:"
echo "1. One pod was terminated"
echo "2. ReplicaSet immediately created a replacement"
echo "3. Total pod count remained at desired level (4)"
echo "4. Service availability was maintained"

# Advanced exploration
echo -e "\n🔬 ADVANCED EXPLORATION:"
echo "Check ReplicaSet events:"
RS_NAME=$(kubectl get rs -l app=self-heal-demo -o jsonpath='{.items[0].metadata.name}')
echo "kubectl describe rs $RS_NAME | grep Events -A 10"

echo -e "\n🧹 Cleanup:"
echo "kubectl delete deployment self-heal-demo"
```

## Getting Started: Your First Deployment

Let's begin with the most straightforward way to create a Deployment and observe how Kubernetes automatically creates the supporting ReplicaSet structure.

### Lab 3: Your First Production-Style Deployment (Beginner Level)

Instead of just creating basic deployments, let's build something closer to what you'd use in production, but still simple enough to understand easily.

```yaml
# lab3-first-deployment.yaml
# Your first production-ready deployment with proper configuration
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-web-app
  labels:
    app: my-web-app
    environment: development
    version: "1.0"
  annotations:
    # Annotations help with tracking and automation
    kubernetes.io/change-cause: "Initial deployment - Lab 3"
spec:
  # Start with 3 replicas for basic high availability
  replicas: 3
  
  # Selector must match template labels - this is how Deployment finds its pods
  selector:
    matchLabels:
      app: my-web-app
  
  # Template defines what each pod will look like
  template:
    metadata:
      labels:
        app: my-web-app
        environment: development
    spec:
      containers:
      - name: nginx
        image: nginx:1.20
        ports:
        - containerPort: 80
          name: http
        
        # Resource requests help Kubernetes make good scheduling decisions
        resources:
          requests:
            memory: "64Mi"   # Minimum memory needed
            cpu: "50m"       # Minimum CPU needed (0.05 cores)
          limits:
            memory: "128Mi"  # Maximum memory allowed
            cpu: "100m"      # Maximum CPU allowed (0.1 cores)
        
        # Health checks ensure only healthy pods serve traffic
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
        
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 30
---
apiVersion: v1
kind: Service
metadata:
  name: $APP_NAME-service
  labels:
    app: $APP_NAME
spec:
  selector:
    app: $APP_NAME
    version: $env
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
YAML

    echo "✅ Blue environment initialized"
    kubectl wait --for=condition=available deployment/$APP_NAME-$env --timeout=120s
    show_status
}

deploy_to_inactive() {
    local image=$1
    local active_env=$(get_active_env)
    local inactive_env=$(get_inactive_env)
    
    echo "🟢 Deploying to $inactive_env environment with image: $image"
    
    # Create or update inactive deployment
    cat << YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $APP_NAME-$inactive_env
  labels:
    app: $APP_NAME
    version: $inactive_env
spec:
  replicas: 3
  selector:
    matchLabels:
      app: $APP_NAME
      version: $inactive_env
  template:
    metadata:
      labels:
        app: $APP_NAME
        version: $inactive_env
    spec:
      containers:
      - name: app
        image: $image
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 30
YAML

    echo "⏳ Waiting for $inactive_env deployment to be ready..."
    kubectl wait --for=condition=available deployment/$APP_NAME-$inactive_env --timeout=120s
    
    echo "🧪 Testing $inactive_env environment..."
    # In production, you would run comprehensive tests here
    kubectl get pods -l app=$APP_NAME,version=$inactive_env
    
    echo "✅ $inactive_env environment ready for traffic switch"
}

switch_traffic() {
    local active_env=$(get_active_env)
    local target_env=$(get_inactive_env)
    
    if [ "$active_env" = "none" ]; then
        echo "❌ No active environment found. Run 'init' first."
        return 1
    fi
    
    echo "🔄 Switching traffic from $active_env to $target_env"
    
    # Update service selector to point to new environment
    kubectl patch service $APP_NAME-service -p "{\"spec\":{\"selector\":{\"version\":\"$target_env\"}}}"
    
    echo "✅ Traffic switched to $target_env environment"
    echo "🔍 Monitoring new environment (press Ctrl+C to stop)..."
    
    # Monitor the switch for a few seconds
    timeout 10s kubectl get endpoints $APP_NAME-service -w 2>/dev/null || true
    
    show_status
}

rollback_traffic() {
    local current_env=$(get_active_env)
    local rollback_env
    
    if [ "$current_env" = "blue" ]; then
        rollback_env="green"
    elif [ "$current_env" = "green" ]; then
        rollback_env="blue"
    else
        echo "❌ Cannot determine rollback target"
        return 1
    fi
    
    echo "⏪ Rolling back traffic from $current_env to $rollback_env"
    
    kubectl patch service $APP_NAME-service -p "{\"spec\":{\"selector\":{\"version\":\"$rollback_env\"}}}"
    
    echo "✅ Traffic rolled back to $rollback_env environment"
    show_status
}

show_status() {
    local active_env=$(get_active_env)
    
    echo ""
    echo "📊 BLUE-GREEN DEPLOYMENT STATUS"
    echo "==============================="
    echo "Active Environment: $active_env"
    echo "Service: $APP_NAME-service"
    echo ""
    
    # Show deployments
    echo "🚀 Deployments:"
    kubectl get deployments -l app=$APP_NAME -o custom-columns=NAME:.metadata.name,READY:.status.readyReplicas,UP-TO-DATE:.status.updatedReplicas,AVAILABLE:.status.availableReplicas,IMAGE:.spec.template.spec.containers[0].image
    
    echo ""
    echo "🌐 Service Routing:"
    kubectl get service $APP_NAME-service -o custom-columns=NAME:.metadata.name,SELECTOR:.spec.selector
    
    echo ""
    echo "📦 Pods by Environment:"
    kubectl get pods -l app=$APP_NAME -o custom-columns=NAME:.metadata.name,VERSION:.metadata.labels.version,STATUS:.status.phase,NODE:.spec.nodeName
}

cleanup_inactive() {
    local active_env=$(get_active_env)
    local inactive_env=$(get_inactive_env)
    
    if [ "$active_env" = "none" ]; then
        echo "❌ No active environment found"
        return 1
    fi
    
    echo "🧹 Cleaning up inactive environment: $inactive_env"
    kubectl delete deployment $APP_NAME-$inactive_env --ignore-not-found=true
    echo "✅ Inactive environment cleaned up"
}

destroy_all() {
    echo "💥 Destroying entire blue-green setup"
    kubectl delete deployment,service -l app=$APP_NAME
    echo "✅ All resources destroyed"
}

# Main command dispatcher
case "$1" in
    init)
        if [ -z "$2" ]; then
            echo "❌ Usage: $0 init <image>"
            exit 1
        fi
        init_environment "$2"
        ;;
    deploy)
        if [ -z "$2" ]; then
            echo "❌ Usage: $0 deploy <image>"
            exit 1
        fi
        deploy_to_inactive "$2"
        ;;
    switch)
        switch_traffic
        ;;
    rollback)
        rollback_traffic
        ;;
    status)
        show_status
        ;;
    cleanup)
        cleanup_inactive
        ;;
    destroy)
        destroy_all
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "❌ Unknown command: $1"
        show_help
        exit 1
        ;;
esac
EOF

chmod +x blue-green-manager.sh

# Create a comprehensive demo script
cat << 'EOF' > demo-blue-green.sh
#!/bin/bash
# Comprehensive Blue-Green Deployment Demo

echo "🎬 Blue-Green Deployment System Demo"
echo "==================================="

# Demo configuration
export APP_NAME="web-demo"

echo "🏗️  Step 1: Initialize Blue Environment"
echo "======================================"
./blue-green-manager.sh init nginx:1.19
echo "Press Enter to continue..."; read

echo -e "\n🚀 Step 2: Deploy New Version to Green"
echo "====================================="
./blue-green-manager.sh deploy nginx:1.20
echo "Press Enter to continue..."; read

echo -e "\n📊 Step 3: Check Status Before Switch"
echo "===================================="
./blue-green-manager.sh status
echo "Press Enter to continue..."; read

echo -e "\n🔄 Step 4: Switch Traffic to Green"
echo "================================="
./blue-green-manager.sh switch
echo "Press Enter to continue..."; read

echo -e "\n🧪 Step 5: Simulate Issue and Rollback"
echo "====================================="
echo "Simulating issue with green environment..."
echo "Rolling back to blue..."
./blue-green-manager.sh rollback
echo "Press Enter to continue..."; read

echo -e "\n🧹 Step 6: Cleanup Demo"
echo "======================"
echo "Choose cleanup option:"
echo "1. Cleanup inactive environment only"
echo "2. Destroy entire setup"
read -p "Enter choice (1 or 2): " choice

case $choice in
    1)
        ./blue-green-manager.sh cleanup
        ;;
    2)
        ./blue-green-manager.sh destroy
        ;;
esac

echo "✅ Demo completed!"
EOF

chmod +x demo-blue-green.sh

# Create testing utilities
cat << 'EOF' > test-deployment.sh
#!/bin/bash
# Testing utilities for blue-green deployments

export APP_NAME="web-demo"

test_environment() {
    local env=$1
    echo "🧪 Testing $env environment"
    
    # Port forward to test the environment directly
    kubectl port-forward deployment/$APP_NAME-$env 8080:80 &
    PF_PID=$!
    
    sleep 3
    
    # Test the endpoint
    if curl -s http://localhost:8080 > /dev/null; then
        echo "✅ $env environment is responding"
    else
        echo "❌ $env environment is not responding"
    fi
    
    kill $PF_PID 2>/dev/null
}

load_test() {
    local duration=${1:-30}
    echo "🏋️  Running load test for $duration seconds"
    
    kubectl port-forward service/$APP_NAME-service 8080:80 &
    PF_PID=$!
    
    sleep 3
    
    # Simple load test
    for i in $(seq 1 10); do
        curl -s http://localhost:8080 &
    done
    
    sleep $duration
    
    kill $PF_PID 2>/dev/null
    echo "✅ Load test completed"
}

monitor_switch() {
    echo "📊 Monitoring service endpoints during switch"
    kubectl get endpoints $APP_NAME-service -w
}

echo "Blue-Green Testing Utilities Loaded"
echo "Available functions:"
echo "- test_environment [blue|green]"
echo "- load_test [duration_seconds]"
echo "- monitor_switch"
EOF

chmod +x test-deployment.sh

echo "✅ Blue-Green Deployment System Created!"
echo ""
echo "📁 Project Structure:"
echo "├── blue-green-manager.sh  # Main management script"
echo "├── demo-blue-green.sh     # Interactive demo"
echo "└── test-deployment.sh     # Testing utilities"
echo ""
echo "🚀 Quick Start:"
echo "1. Run the interactive demo: ./demo-blue-green.sh"
echo "2. Or use the manager directly:"
echo "   ./blue-green-manager.sh init nginx:1.19"
echo "   ./blue-green-manager.sh deploy nginx:1.20"
echo "   ./blue-green-manager.sh switch"

cd ..
```

### Mini-Project 2: Canary Deployment Framework (Advanced Level)

This project creates a sophisticated canary deployment system with gradual traffic shifting and automated rollback triggers.

```bash
#!/bin/bash
# mini-project-2-canary-framework.sh
# Advanced canary deployment framework

echo "🐦 Mini-Project 2: Canary Deployment Framework"
echo "=============================================="

PROJECT_NAME="canary-framework"
mkdir -p $PROJECT_NAME
cd $PROJECT_NAME

# Create the main canary controller
cat << 'EOF' > canary-controller.sh
#!/bin/bash
# Advanced Canary Deployment Controller
# Supports gradual traffic shifting with automated rollback

APP_NAME=${APP_NAME:-canary-demo}
NAMESPACE=${NAMESPACE:-default}

show_help() {
    echo "Canary Deployment Controller"
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  init <image> <replicas>    Initialize stable deployment"
    echo "  canary <image> <percent>   Deploy canary with traffic percentage"
    echo "  shift <percent>            Shift traffic percentage to canary"
    echo "  promote                    Promote canary to stable"
    echo "  rollback                   Rollback canary deployment"
    echo "  status                     Show current deployment status"
    echo "  cleanup                    Remove canary deployment"
    echo "  destroy                    Remove entire setup"
    echo ""
    echo "Examples:"
    echo "  $0 init nginx:1.19 5"
    echo "  $0 canary nginx:1.20 10    # 10% traffic to canary"
    echo "  $0 shift 25                # Increase to 25%"
    echo "  $0 promote                 # Make canary the new stable"
}

calculate_replicas() {
    local total_replicas=$1
    local canary_percent=$2
    
    # Calculate canary replicas (at least 1 if percentage > 0)
    local canary_replicas
    if [ $canary_percent -eq 0 ]; then
        canary_replicas=0
    else
        canary_replicas=$((($total_replicas * $canary_percent + 50) / 100))
        if [ $canary_replicas -eq 0 ]; then
            canary_replicas=1
        fi
    fi
    
    # Calculate stable replicas
    local stable_replicas=$(($total_replicas - $canary_replicas))
    
    echo "$stable_replicas $canary_replicas"
}

init_stable() {
    local image=$1
    local replicas=$2
    
    echo "🏗️  Initializing stable deployment: $image with $replicas replicas"
    
    # Create stable deployment
    cat << YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $APP_NAME-stable
  labels:
    app: $APP_NAME
    version: stable
spec:
  replicas: $replicas
  selector:
    matchLabels:
      app: $APP_NAME
      version: stable
  template:
    metadata:
      labels:
        app: $APP_NAME
        version: stable
    spec:
      containers:
      - name: app
        image: $image
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 30
        env:
        - name: VERSION
          value: "stable"
---
apiVersion: v1
kind: Service
metadata:
  name: $APP_NAME-service
  labels:
    app: $APP_NAME
spec:
  selector:
    app: $APP_NAME
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
YAML

    kubectl wait --for=condition=available deployment/$APP_NAME-stable --timeout=120s
    echo "✅ Stable deployment initialized"
    show_status
}

deploy_canary() {
    local canary_image=$1
    local traffic_percent=$2
    
    # Get current stable replica count
    local stable_replicas=$(kubectl get deployment $APP_NAME-stable -o jsonpath='{.spec.replicas}')
    local total_replicas=$stable_replicas
    
    # Calculate new replica distribution
    read new_stable_replicas canary_replicas < <(calculate_replicas $total_replicas $traffic_percent)
    
    echo "🐦 Deploying canary: $canary_image"
    echo "📊 Traffic distribution: ${traffic_percent}% canary (${canary_replicas} replicas), $((100-$traffic_percent))% stable (${new_stable_replicas} replicas)"
    
    # Create canary deployment
    cat << YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $APP_NAME-canary
  labels:
    app: $APP_NAME
    version: canary
  annotations:
    canary.traffic-percent: "$traffic_percent"
spec:
  replicas: $canary_replicas
  selector:
    matchLabels:
      app: $APP_NAME
      version: canary
  template:
    metadata:
      labels:
        app: $APP_NAME
        version: canary
    spec:
      containers:
      - name: app
        image: $canary_image
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 30
        env:
        - name: VERSION
          value: "canary"
YAML

    # Scale down stable deployment
    kubectl scale deployment $APP_NAME-stable --replicas=$new_stable_replicas
    
    # Wait for deployments to be ready
    kubectl wait --for=condition=available deployment/$APP_NAME-canary --timeout=120s
    kubectl wait --for=condition=available deployment/$APP_NAME-stable --timeout=60s
    
    echo "✅ Canary deployment ready"
    show_status
}

shift_traffic() {
    local new_percent=$1
    
    if ! kubectl get deployment $APP_NAME-canary >/dev/null 2>&1; then
        echo "❌ No canary deployment found"
        return 1
    fi
    
    # Get total replica count
    local stable_replicas=$(kubectl get deployment $APP_NAME-stable -o jsonpath='{.spec.replicas}')
    local canary_replicas=$(kubectl get deployment $APP_NAME-canary -o jsonpath='{.spec.replicas}')
    local total_replicas=$((stable_replicas + canary_replicas))
    
    # Calculate new distribution
    read new_stable_replicas new_canary_replicas < <(calculate_replicas $total_replicas $new_percent)
    
    echo "🔄 Shifting traffic to ${new_percent}% canary"
    echo "📊 New distribution: ${new_percent}% canary (${new_canary_replicas} replicas), $((100-$new_percent))% stable (${new_stable_replicas} replicas)"
    
    # Update deployments
    kubectl scale deployment $APP_NAME-stable --replicas=$new_stable_replicas
    kubectl scale deployment $APP_NAME-canary --replicas=$new_canary_replicas
    
    # Update annotation
    kubectl annotate deployment $APP_NAME-canary canary.traffic-percent="$new_percent" --overwrite
    
    # Wait for scaling to complete
    sleep 10
    
    echo "✅ Traffic shifted"
    show_status
}

promote_canary() {
    if ! kubectl get deployment $APP_NAME-canary >/dev/null 2>&1; then
        echo "❌ No canary deployment found"
        return 1
    fi
    
    echo "🎉 Promoting canary to stable"
    
    # Get canary image and total replicas
    local canary_image=$(kubectl get deployment $APP_NAME-canary -o jsonpath='{.spec.template.spec.containers[0].image}')
    local stable_replicas=$(kubectl get deployment $APP_NAME-stable -o jsonpath='{.spec.replicas}')
    local canary_replicas=$(kubectl get deployment $APP_NAME-canary -o jsonpath='{.spec.replicas}')
    local total_replicas=$((stable_replicas + canary_replicas))
    
    # Update stable deployment with canary image
    kubectl set image deployment/$APP_NAME-stable app=$canary_image
    kubectl scale deployment $APP_NAME-stable --replicas=$total_replicas
    
    # Wait for stable deployment to be ready
    kubectl wait --for=condition=available deployment/$APP_NAME-stable --timeout=120s
    
    # Remove canary deployment
    kubectl delete deployment $APP_NAME-canary
    
    echo "✅ Canary promoted to stable"
    show_status
}

rollback_canary() {
    if ! kubectl get deployment $APP_NAME-canary >/dev/null 2>&1; then
        echo "❌ No canary deployment found"
        return 1
    fi
    
    echo "⏪ Rolling back canary deployment"
    
    # Get total replicas and restore all to stable
    local stable_replicas=$(kubectl get deployment $APP_NAME-stable -o jsonpath='{.spec.replicas}')
    local canary_replicas=$(kubectl get deployment $APP_NAME-canary -o jsonpath='{.spec.replicas}')
    local total_replicas=$((stable_replicas + canary_replicas))
    
    # Scale up stable to handle all traffic
    kubectl scale deployment $APP_NAME-stable --replicas=$total_replicas
    
    # Remove canary deployment
    kubectl delete deployment $APP_NAME-canary
    
    echo "✅ Canary rolled back, all traffic on stable"
    show_status
}

show_status() {
    echo ""
    echo "📊 CANARY DEPLOYMENT STATUS"
    echo "=========================="
    
    # Show deployments
    echo "🚀 Deployments:"
    kubectl get deployments -l app=$APP_NAME -o custom-columns=NAME:.metadata.name,READY:.status.readyReplicas,IMAGE:.spec.template.spec.containers[0].image,REPLICAS:.spec.replicas
    
    # Calculate traffic distribution
    if kubectl get deployment $APP_NAME-canary >/dev/null 2>&1; then
        local stable_replicas=$(kubectl get deployment $APP_NAME-stable -o jsonpath='{.spec.replicas}')
        local canary_replicas=$(kubectl get deployment $APP_NAME-canary -o jsonpath='{.spec.replicas}')
        local total_replicas=$((stable_replicas + canary_replicas))
        
        if [ $total_replicas -gt 0 ]; then
            local stable_percent=$((stable_replicas * 100 / total_replicas))
            local canary_percent=$((canary_replicas * 100 / total_replicas))
            
            echo ""
            echo "📊 Traffic Distribution:"
            echo "  Stable: ${stable_percent}% (${stable_replicas} replicas)"
            echo "  Canary: ${canary_percent}% (${canary_replicas} replicas)"
        fi
    else
        echo ""
        echo "📊 Traffic Distribution:"
        echo "  Stable: 100% (no canary active)"
    fi
    
    # Show pods
    echo ""
    echo "📦 Pods:"
    kubectl get pods -l app=$APP_NAME -o custom-columns=NAME:.metadata.name,VERSION:.metadata.labels.version,STATUS:.status.phase,READY:.status.containerStatuses[0].ready
}

cleanup_canary() {
    echo "🧹 Cleaning up canary deployment"
    kubectl delete deployment $APP_NAME-canary --ignore-not-found=true
    
    # Restore stable to full capacity if needed
    local current_replicas=$(kubectl get deployment $APP_NAME-stable -o jsonpath='{.spec.replicas}')
    if [ $current_replicas -lt 3 ]; then
        kubectl scale deployment $APP_NAME-stable --replicas=3
    fi
    
    echo "✅ Canary cleanup complete"
}

destroy_all() {
    echo "💥 Destroying entire canary setup"
    kubectl delete deployment,service -l app=$APP_NAME
    echo "✅ All resources destroyed"
}

# Main command dispatcher
case "$1" in
    init)
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "❌ Usage: $0 init <image> <replicas>"
            exit 1
        fi
        init_stable "$2" "$3"
        ;;
    canary)
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "❌ Usage: $0 canary <image> <percent>"
            exit 1
        fi
        deploy_canary "$2" "$3"
        ;;
    shift)
        if [ -z "$2" ]; then
            echo "❌ Usage: $0 shift <percent>"
            exit 1
        fi
        shift_traffic "$2"
        ;;
    promote)
        promote_canary
        ;;
    rollback)
        rollback_canary
        ;;
    status)
        show_status
        ;;
    cleanup)
        cleanup_canary
        ;;
    destroy)
        destroy_all
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "❌ Unknown command: $1"
        show_help
        exit 1
        ;;
esac
EOF

chmod +x canary-controller.sh

# Create automated canary progression script
cat << 'EOF' > auto-canary-progression.sh
#!/bin/bash
# Automated canary progression with monitoring

export APP_NAME="auto-canary-demo"

run_automated_canary() {
    local stable_image=$1
    local canary_image=$2
    
    echo "🤖 Automated Canary Deployment"
    echo "=============================="
    echo "Stable: $stable_image"
    echo "Canary: $canary_image"
    
    # Initialize if needed
    if ! kubectl get deployment $APP_NAME-stable >/dev/null 2>&1; then
        echo "🏗️  Initializing stable deployment..."
        ./canary-controller.sh init $stable_image 6
        sleep 10
    fi
    
    # Phase 1: Deploy 10% canary
    echo -e "\n📊 Phase 1: Deploying 10% canary traffic"
    ./canary-controller.sh canary $canary_image 10
    
    echo "⏳ Monitoring for 30 seconds..."
    monitor_phase 30
    
    # Phase 2: Increase to 25%
    echo -e "\n📊 Phase 2: Increasing to 25% canary traffic"
    ./canary-controller.sh shift 25
    
    echo "⏳ Monitoring for 30 seconds..."
    monitor_phase 30
    
    # Phase 3: Increase to 50%
    echo -e "\n📊 Phase 3: Increasing to 50% canary traffic"
    ./canary-controller.sh shift 50
    
    echo "⏳ Monitoring for 30 seconds..."
    monitor_phase 30
    
    # Decision point
    echo -e "\n🤔 Decision Point"
    echo "Based on monitoring (simulated), deciding to promote canary"
    
    # Phase 4: Promote canary
    echo -e "\n🎉 Phase 4: Promoting canary to stable"
    ./canary-controller.sh promote
    
    echo "✅ Automated canary deployment completed successfully!"
}

monitor_phase() {
    local duration=$1
    local end_time=$(($(date +%s) + duration))
    
    while [ $(date +%s) -lt $end_time ]; do
        # Simulate monitoring checks
        echo "📈 Monitoring metrics: CPU, Memory, Error Rate, Response Time"
        
        # In real implementation, you would:
        # - Check Prometheus metrics
        # - Analyze error rates
        # - Monitor response times
        # - Check business metrics
        
        sleep 10
        
        # Simulated health check
        if kubectl get pods -l app=$APP_NAME,version=canary --no-headers 2>/dev/null | grep -q Running; then
            echo "✅ Canary pods healthy"
        fi
    done
}

simulate_rollback_scenario() {
    echo "🚨 Simulating Rollback Scenario"
    echo "==============================="
    
    ./canary-controller.sh init nginx:1.19 6
    sleep 10
    
    echo "Deploying problematic canary..."
    ./canary-controller.sh canary nginx:invalid-tag 20
    
    echo "⏳ Waiting for failure detection..."
    sleep 30
    
    echo "🚨 Failure detected! Rolling back..."
    ./canary-controller.sh rollback
    
    echo "✅ Rollback completed"
}

# Menu system
show_menu() {
    echo "🐦 Canary Deployment Options"
    echo "============================"
    echo "1. Run automated canary progression"
    echo "2. Simulate rollback scenario"
    echo "3. Interactive canary deployment"
    echo "4. Clean up all resources"
    echo "5. Exit"
}

case "$1" in
    auto)
        run_automated_canary nginx:1.19 nginx:1.20
        ;;
    rollback-sim)
        simulate_rollback_scenario
        ;;
    *)
        show_menu
        read -p "Choose option (1-5): " choice
        
        case $choice in
            1)
                run_automated_canary nginx:1.19 nginx:1.20
                ;;
            2)
                simulate_rollback_scenario
                ;;
            3)
                echo "Use ./canary-controller.sh for interactive deployment"
                ;;
            4)
                ./canary-controller.sh destroy
                ;;
            5)
                echo "Goodbye!"
                ;;
            *)
                echo "Invalid option"
                ;;
        esac
        ;;
esac
EOF

chmod +x auto-canary-progression.sh

# Create monitoring and testing utilities
cat << 'EOF' > canary-testing-suite.sh
#!/bin/bash
# Comprehensive testing suite for canary deployments

export APP_NAME="canary-demo"

# Load testing function
load_test_with_metrics() {
    local duration=${1:-60}
    local rps=${2:-10}  # requests per second
    
    echo "🏋️  Load Testing Canary Deployment"
    echo "Duration: ${duration}s, Rate: ${rps} req/s"
    
    # Port forward to service
    kubectl port-forward service/$APP_NAME-service 8080:80 &
    PF_PID=$!
    
    sleep 3
    
    # Create results directory
    mkdir -p test-results
    
    # Run load test with version tracking
    echo "timestamp,version,response_time,status" > test-results/load-test.csv
    
    local end_time=$(($(date +%s) + duration))
    local request_interval=$(echo "scale=2; 1 / $rps" | bc -l)
    
    while [ $(date +%s) -lt $end_time ]; do
        local start_time=$(date +%s.%N)
        local response=$(curl -s -w "%{http_code}" http://localhost:8080 2>/dev/null)
        local end_time_req=$(date +%s.%N)
        
        local response_time=$(echo "$end_time_req - $start_time" | bc -l)
        local status=${response: -3}
        local version="unknown"
        
        # Try to extract version from response (if app provides it)
        if command -v jq >/dev/null 2>&1; then
            version=$(echo "$response" | jq -r '.version // "unknown"' 2>/dev/null || echo "unknown")
        fi
        
        echo "$(date +%s),$version,$response_time,$status" >> test-results/load-test.csv
        
        sleep $request_interval
    done
    
    kill $PF_PID 2>/dev/null
    
    echo "✅ Load test completed. Results in test-results/load-test.csv"
    analyze_test_results
}

analyze_test_results() {
    if [ ! -f test-results/load-test.csv ]; then
        echo "❌ No test results found"
        return 1
    fi
    
    echo "📊 Test Results Analysis"
    echo "======================="
    
    # Basic statistics
    local total_requests=$(tail -n +2 test-results/load-test.csv | wc -l)
    local successful_requests=$(tail -n +2 test-results/load-test.csv | grep ",200$" | wc -l)
    local error_rate=$(echo "scale=2; ($total_requests - $successful_requests) * 100 / $total_requests" | bc -l)
    
    echo "Total Requests: $total_requests"
    echo "Successful: $successful_requests"
    echo "Error Rate: ${error_rate}%"
    
    # Average response time
    local avg_response_time=$(tail -n +2 test-results/load-test.csv | cut -d',' -f3 | awk '{sum+=$1; count++} END {if(count>0) print sum/count; else print 0}')
    echo "Average Response Time: ${avg_response_time}s"
    
    # Version distribution (if available)
    echo ""
    echo "Version Distribution:"
    tail -n +2 test-results/load-test.csv | cut -d',' -f2 | sort | uniq -c | while read count version; do
        local percentage=$(echo "scale=2; $count * 100 / $total_requests" | bc -l)
        echo "  $version: $count requests (${percentage}%)"
    done
}

# Traffic distribution validator
validate_traffic_distribution() {
    local expected_canary_percent=$1
    local tolerance=${2:-5}  # 5% tolerance by default
    
    echo "🔍 Validating Traffic Distribution"
    echo "Expected Canary: ${expected_canary_percent}%"
    
    # Count pods by version
    local stable_pods=$(kubectl get pods -l app=$APP_NAME,version=stable --no-headers 2>/dev/null | grep Running | wc -l)
    local canary_pods=$(kubectl get pods -l app=$APP_NAME,version=canary --no-headers 2>/dev/null | grep Running | wc -l)
    local total_pods=$((stable_pods + canary_pods))
    
    if [ $total_pods -eq 0 ]; then
        echo "❌ No running pods found"
        return 1
    fi
    
    local actual_canary_percent=$((canary_pods * 100 / total_pods))
    local difference=$(echo "$actual_canary_percent - $expected_canary_percent" | bc -l | tr -d '-')
    
    echo "Actual Distribution:"
    echo "  Stable: $stable_pods pods ($((stable_pods * 100 / total_pods))%)"
    echo "  Canary: $canary_pods pods (${actual_canary_percent}%)"
    
    if [ $(echo "$difference <= $tolerance" | bc -l) -eq 1 ]; then
        echo "✅ Traffic distribution within tolerance"
        return 0
    else
        echo "❌ Traffic distribution outside tolerance (±${tolerance}%)"
        return 1
    fi
}

# Health check for canary deployment
health_check_canary() {
    echo "🏥 Canary Deployment Health Check"
    echo "================================"
    
    # Check deployments
    local stable_status=$(kubectl get deployment $APP_NAME-stable -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null)
    local canary_status=$(kubectl get deployment $APP_NAME-canary -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null)
    
    echo "Deployment Health:"
    echo "  Stable: ${stable_status:-N/A}"
    echo "  Canary: ${canary_status:-N/A}"
    
    # Check pod readiness
    local stable_ready=$(kubectl get pods -l app=$APP_NAME,version=stable --no-headers 2>/dev/null | grep -c "Running.*1/1" || echo 0)
    local stable_total=$(kubectl get pods -l app=$APP_NAME,version=stable --no-headers 2>/dev/null | wc -l)
    local canary_ready=$(kubectl get pods -l app=$APP_NAME,version=canary --no-headers 2>/dev/null | grep -c "Running.*1/1" || echo 0)
    local canary_total=$(kubectl get pods -l app=$APP_NAME,version=canary --no-headers 2>/dev/null | wc -l)
    
    echo ""
    echo "Pod Readiness:"
    echo "  Stable: $stable_ready/$stable_total ready"
    echo "  Canary: $canary_ready/$canary_total ready"
    
    # Overall health assessment
    local overall_health="healthy"
    if [ "$stable_status" != "True" ] && [ $stable_total -gt 0 ]; then
        overall_health="unhealthy"
    fi
    if [ "$canary_status" != "True" ] && [ $canary_total -gt 0 ]; then
        overall_health="unhealthy"
    fi
    if [ $stable_ready -lt $stable_total ] || [ $canary_ready -lt $canary_total ]; then
        overall_health="degraded"
    fi
    
    echo ""
    echo "Overall Health: $overall_health"
    
    case $overall_health in
        healthy)
            echo "✅ All systems operational"
            return 0
            ;;
        degraded)
            echo "⚠️  Some pods not ready"
            return 1
            ;;
        unhealthy)
            echo "❌ Deployment issues detected"
            return 2
            ;;
    esac
}

# Continuous monitoring
monitor_canary_deployment() {
    local duration=${1:-300}  # 5 minutes default
    local check_interval=${2:-30}  # 30 seconds default
    
    echo "📊 Continuous Canary Monitoring"
    echo "Duration: ${duration}s, Check Interval: ${check_interval}s"
    
    local end_time=$(($(date +%s) + duration))
    local check_count=0
    
    while [ $(date +%s) -lt $end_time ]; do
        check_count=$((check_count + 1))
        echo ""
        echo "📈 Check #$check_count - $(date)"
        echo "=========================="
        
        # Health check
        health_check_canary
        local health_result=$?
        
        # Get current traffic distribution
        if kubectl get deployment $APP_NAME-canary >/dev/null 2>&1; then
            local canary_percent=$(kubectl get deployment $APP_NAME-canary -o jsonpath='{.metadata.annotations.canary\.traffic-percent}')
            validate_traffic_distribution $canary_percent
        fi
        
        # Check for any pod restarts
        local restarts=$(kubectl get pods -l app=$APP_NAME -o jsonpath='{.items[*].status.containerStatuses[*].restartCount}' | tr ' ' '\n' | awk '{sum+=$1} END {print sum+0}')
        echo "Total Pod Restarts: $restarts"
        
        # Decision logic (in real implementation, this would be more sophisticated)
        case $health_result in
            0)
                echo "✅ Continuing monitoring..."
                ;;
            1)
                echo "⚠️  Degraded performance detected, continuing monitoring..."
                ;;
            2)
                echo "🚨 Critical issues detected! Consider rollback."
                # In automated mode, you might trigger rollback here
                ;;
        esac
        
        sleep $check_interval
    done
    
    echo ""
    echo "📊 Monitoring completed after $check_count checks"
}

# Generate load test report
generate_report() {
    if [ ! -f test-results/load-test.csv ]; then
        echo "❌ No test data available for report generation"
        return 1
    fi
    
    echo "📋 Generating Canary Deployment Report"
    echo "====================================="
    
    cat << REPORT > test-results/canary-report.md
# Canary Deployment Test Report

Generated: $(date)

## Test Configuration
- Application: $APP_NAME
- Test Duration: $(tail -n +2 test-results/load-test.csv | wc -l) requests
- Test Date: $(date)

## Results Summary

$(analyze_test_results)

## Deployment Status

$(./canary-controller.sh status)

## Recommendations

Based on the test results:

$(if [ $(tail -n +2 test-results/load-test.csv | grep ",200$" | wc -l) -gt 0 ]; then
    echo "✅ Canary deployment appears stable"
    echo "- Consider increasing traffic percentage"
    echo "- Continue monitoring for extended period"
else
    echo "❌ Issues detected with canary deployment"
    echo "- Consider rolling back"
    echo "- Investigate error causes"
fi)

REPORT

    echo "✅ Report generated: test-results/canary-report.md"
}

# Testing menu
show_test_menu() {
    echo "🧪 Canary Testing Suite"
    echo "======================"
    echo "1. Run load test (60s)"
    echo "2. Validate traffic distribution"
    echo "3. Health check"
    echo "4. Continuous monitoring (5min)"
    echo "5. Generate report"
    echo "6. Clean test results"
    echo "7. Exit"
}

# Main testing interface
case "$1" in
    load-test)
        load_test_with_metrics ${2:-60} ${3:-10}
        ;;
    validate)
        validate_traffic_distribution ${2:-50}
        ;;
    health)
        health_check_canary
        ;;
    monitor)
        monitor_canary_deployment ${2:-300} ${3:-30}
        ;;
    report)
        generate_report
        ;;
    clean)
        rm -rf test-results
        echo "✅ Test results cleaned"
        ;;
    *)
        show_test_menu
        read -p "Choose option (1-7): " choice
        
        case $choice in
            1)
                load_test_with_metrics 60 10
                ;;
            2)
                read -p "Expected canary percentage: " percent
                validate_traffic_distribution $percent
                ;;
            3)
                health_check_canary
                ;;
            4)
                monitor_canary_deployment 300 30
                ;;
            5)
                generate_report
                ;;
            6)
                rm -rf test-results
                echo "✅ Test results cleaned"
                ;;
            7)
                echo "Goodbye!"
                ;;
            *)
                echo "Invalid option"
                ;;
        esac
        ;;
esac
EOF

chmod +x canary-testing-suite.sh

echo "✅ Advanced Canary Deployment Framework Created!"
echo ""
echo "📁 Project Structure:"
echo "├── canary-controller.sh         # Main canary management"
echo "├── auto-canary-progression.sh   # Automated progression"
echo "└── canary-testing-suite.sh      # Testing and monitoring"
echo ""
echo "🚀 Quick Start Guide:"
echo "1. Initialize: ./canary-controller.sh init nginx:1.19 5"
echo "2. Deploy canary: ./canary-controller.sh canary nginx:1.20 10"
echo "3. Run tests: ./canary-testing-suite.sh load-test"
echo "4. Or run automated: ./auto-canary-progression.sh auto"

cd ..
```

### Mini-Project 3: Multi-Environment Deployment Pipeline (Expert Level)

This project creates a complete CI/CD-style deployment pipeline that manages deployments across multiple environments with promotion workflows.

```bash
#!/bin/bash
# mini-project-3-pipeline-system.sh
# Complete multi-environment deployment pipeline

echo "🚀 Mini-Project 3: Multi-Environment Deployment Pipeline"
echo "======================================================="

PROJECT_NAME="deployment-pipeline"
mkdir -p $PROJECT_NAME
cd $PROJECT_NAME

# Create the pipeline controller
cat << 'EOF' > pipeline-controller.sh
#!/bin/bash
# Multi-Environment Deployment Pipeline Controller
# Manages deployments across dev, staging, and production environments

ENVIRONMENTS=("dev" "staging" "prod")
APP_NAME=${APP_NAME:-pipeline-app}

show_help() {
    echo "Multi-Environment Deployment Pipeline"
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  init                           Initialize all environments"
    echo "  deploy <env> <image> [tag]     Deploy to specific environment"
    echo "  promote <from_env> <to_env>    Promote deployment between environments"
    echo "  rollback <env> [revision]      Rollback environment"
    echo "  status [env]                   Show environment status"
    echo "  pipeline <image>               Run full pipeline (dev→staging→prod)"
    echo "  cleanup <env>                  Clean up environment"
    echo "  destroy                        Destroy all environments"
    echo ""
    echo "Environments: dev, staging, prod"
    echo ""
    echo "Examples:"
    echo "  $0 init"
    echo "  $0 deploy dev nginx:1.20"
    echo "  $0 promote dev staging"
    echo "  $0 pipeline nginx:1.21"
}

# Environment configuration
get_env_config() {
    local env=$1
    
    case $env in
        dev)
            echo "replicas=2 resources_cpu=100m resources_memory=128Mi hpa_enabled=false"
            ;;
        staging)
            echo "replicas=3 resources_cpu=200m resources_memory=256Mi hpa_enabled=true"
            ;;
        prod)
            echo "replicas=5 resources_cpu=500m resources_memory=512Mi hpa_enabled=true"
            ;;
        *)
            echo "❌ Unknown environment: $env"
            return 1
            ;;
    esac
}

# Create namespace for environment
create_namespace() {
    local env=$1
    local namespace="$APP_NAME-$env"
    
    if ! kubectl get namespace $namespace >/dev/null 2>&1; then
        kubectl create namespace $namespace
        kubectl label namespace $namespace environment=$env app=$APP_NAME
    fi
}

# Initialize all environments
init_environments() {
    echo "🏗️  Initializing Multi-Environment Pipeline"
    echo "==========================================="
    
    for env in "${ENVIRONMENTS[@]}"; do
        echo ""
        echo "📦 Setting up $env environment..."
        create_namespace $env
        
        # Get environment-specific configuration
        eval $(get_env_config $env)
        
        # Create environment-specific deployment
        cat << YAML | kubectl apply -n $APP_NAME-$env -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $APP_NAME
  labels:
    app: $APP_NAME
    environment: $env
  annotations:
    deployment.kubernetes.io/revision: "1"
    pipeline.environment: "$env"
spec:
  replicas: $replicas
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  selector:
    matchLabels:
      app: $APP_NAME
      environment: $env
  template:
    metadata:
      labels:
        app: $APP_NAME
        environment: $env
    spec:
      containers:
      - name: app
        image: nginx:1.19  # Default image
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: $resources_cpu
            memory: $resources_memory
          limits:
            cpu: $(echo "$resources_cpu" | sed 's/m/*2&/')
            memory: $(echo "$resources_memory" | sed 's/Mi/*2&/')
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 30
        env:
        - name: ENVIRONMENT
          value: "$env"
        - name: APP_VERSION
          value: "1.19"
---
apiVersion: v1
kind: Service
metadata:
  name: $APP_NAME-service
  labels:
    app: $APP_NAME
    environment: $env
spec:
  selector:
    app: $APP_NAME
    environment: $env
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
YAML

        # Create HPA for staging and prod
        if [ "$hpa_enabled" = "true" ]; then
            kubectl autoscale deployment $APP_NAME --cpu-percent=70 --min=$replicas --max=$((replicas * 2)) -n $APP_NAME-$env
        fi
        
        echo "✅ $env environment ready"
    done
    
    echo ""
    echo "🎉 All environments initialized successfully!"
    show_pipeline_status
}

# Deploy to specific environment
deploy_to_environment() {
    local env=$1
    local image=$2
    local tag=${3:-$(echo $image | cut -d':' -f2)}
    
    if [[ ! " ${ENVIRONMENTS[@]} " =~ " $env " ]]; then
        echo "❌ Invalid environment: $env"
        return 1
    fi
    
    echo "🚀 Deploying to $env environment"
    echo "Image: $image"
    
    local namespace="$APP_NAME-$env"
    
    # Update deployment image
    kubectl set image deployment/$APP_NAME app=$image -n $namespace
    kubectl annotate deployment/$APP_NAME kubernetes.io/change-cause="Deployed $image to $env" -n $namespace --overwrite
    
    # Update environment variable
    kubectl patch deployment/$APP_NAME -n $namespace -p "{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"app\",\"env\":[{\"name\":\"APP_VERSION\",\"value\":\"$tag\"}]}]}}}}"
    
    echo "⏳ Waiting for deployment to complete..."
    kubectl rollout status deployment/$APP_NAME -n $namespace --timeout=300s
    
    echo "✅ Deployment to $env completed successfully"
    show_environment_status $env
}

# Promote between environments
promote_deployment() {
    local from_env=$1
    local to_env=$2
    
    if [[ ! " ${ENVIRONMENTS[@]} " =~ " $from_env " ]] || [[ ! " ${ENVIRONMENTS[@]} " =~ " $to_env " ]]; then
        echo "❌ Invalid environment specified"
        return 1
    fi
    
    echo "🔄 Promoting from $from_env to $to_env"
    
    # Get current image from source environment
    local from_namespace="$APP_NAME-$from_env"
    local current_image=$(kubectl get deployment/$APP_NAME -n $from_namespace -o jsonpath='{.spec.template.spec.containers[0].image}')
    
    if [ -z "$current_image" ]; then
        echo "❌ Could not retrieve image from $from_env environment"
        return 1
    fi
    
    echo "Promoting image: $current_image"
    
    # Confirmation for production deployments
    if [ "$to_env" = "prod" ]; then
        echo "⚠️  You are about to promote to PRODUCTION"
        read -p "Are you sure? (yes/no): " confirm
        if [ "$confirm" != "yes" ]; then
            echo "Promotion cancelled"
            return 1
        fi
    fi
    
    # Deploy to target environment
    deploy_to_environment $to_env $current_image
    
    echo "✅ Promotion from $from_env to $to_env completed"
}

# Show environment status
show_environment_status() {
    local env=$1
    local namespace="$APP_NAME-$env"
    
    echo ""
    echo "📊 $env Environment Status"
    echo "=========================="
    
    # Deployment status
    echo "🚀 Deployment:"
    kubectl get deployment $APP_NAME -n $namespace -o custom-columns=NAME:.metadata.name,READY:.status.readyReplicas,UP-TO-DATE:.status.updatedReplicas,AVAILABLE:.status.availableReplicas,IMAGE:.spec.template.spec.containers[0].image
    
    # Pod status
    echo ""
    echo "📦 Pods:"
    kubectl get pods -l app=$APP_NAME -n $namespace -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[0].ready,NODE:.spec.nodeName
    
    # HPA status (if exists)
    if kubectl get hpa $APP_NAME -n $namespace >/dev/null 2>&1; then
        echo ""
        echo "📈 HPA:"
        kubectl get hpa $APP_NAME -n $namespace
    fi
    
    # Recent events
    echo ""
    echo "📋 Recent Events:"
    kubectl get events -n $namespace --sort-by=.metadata.creationTimestamp --limit=5
}

# Show complete pipeline status
show_pipeline_status() {
    echo ""
    echo "🏭 DEPLOYMENT PIPELINE STATUS"
    echo "============================"
    
    for env in "${ENVIRONMENTS[@]}"; do
        local namespace="$APP_NAME-$env"
        
        if kubectl get deployment $APP_NAME -n $namespace >/dev/null 2>&1; then
            local image=$(kubectl get deployment $APP_NAME -n $namespace -o jsonpath='{.spec.template.spec.containers[0].image}')
            local ready=$(kubectl get deployment $APP_NAME -n $namespace -o jsonpath='{.status.readyReplicas}')
            local desired=$(kubectl get deployment $APP_NAME -n $namespace -o jsonpath='{.spec.replicas}')
            
            printf "%-10s | %-20s | %s/%s ready\n" "$env" "$image" "$ready" "$desired"
        else
            printf "%-10s | %-20s | Not deployed\n" "$env" "N/A"
        fi
    done
}

# Run complete pipeline
run_pipeline() {
    local image=$1
    
    echo "🏭 Running Complete Deployment Pipeline"
    echo "======================================"
    echo "Image: $image"
    
    # Stage 1: Deploy to dev
    echo ""
    echo "🔵 Stage 1: Deploying to Development"
    deploy_to_environment dev $image
    
    echo "⏳ Waiting 30 seconds for dev validation..."
    sleep 30
    
    # Simulate dev tests
    echo "🧪 Running development tests..."
    simulate_tests dev
    local dev_result=$?
    
    if [ $dev_result -ne 0 ]; then
        echo "❌ Development tests failed. Pipeline stopped."
        return 1
    fi
    
    # Stage 2: Deploy to staging
    echo ""
    echo "🟡 Stage 2: Promoting to Staging"
    promote_deployment dev staging
    
    echo "⏳ Waiting 30 seconds for staging validation..."
    sleep 30
    
    # Simulate staging tests
    echo "🧪 Running staging tests..."
    simulate_tests staging
    local staging_result=$?
    
    if [ $staging_result -ne 0 ]; then
        echo "❌ Staging tests failed. Pipeline stopped."
        return 1
    fi
    
    # Stage 3: Manual approval for production
    echo ""
    echo "🟢 Stage 3: Production Deployment Approval"
    echo "Staging tests passed. Ready for production deployment."
    read -p "Deploy to production? (yes/no): " approval
    
    if [ "$approval" = "yes" ]; then
        promote_deployment staging prod
        echo ""
        echo "🎉 Pipeline completed successfully!"
        echo "All environments updated to: $image"
    else
        echo "Production deployment cancelled by user"
    fi
    
    show_pipeline_status
}

# Simulate testing
simulate_tests() {
    local env=$1
    local namespace="$APP_NAME-$env"
    
    echo "Running tests in $env environment..."
    
    # Check if deployment is healthy
    if ! kubectl get deployment $APP_NAME -n $namespace >/dev/null 2>&1; then
        echo "❌ Deployment not found"
        return 1
    fi
    
    # Check if pods are ready
    local ready=$(kubectl get deployment $APP_NAME -n $namespace -o jsonpath='{.status.readyReplicas}')
    local desired=$(kubectl get deployment $APP_NAME -n $namespace -o jsonpath='{.spec.replicas}')
    
    if [ "$ready" != "$desired" ]; then
        echo "❌ Not all pods are ready ($ready/$desired)"
        return 1
    fi
    
    # Simulate test execution time
    for i in {1..5}; do
        echo "  Running test suite $i/5..."
        sleep 2
    done
    
    # Simulate 90% success rate
    if [ $((RANDOM % 10)) -lt 9 ]; then
        echo "✅ All tests passed"
        return 0
    else
        echo "❌ Some tests failed"
        return 1
    fi
}

# Rollback environment
rollback_environment() {
    local env=$1
    local revision=${2:-""}
    local namespace="$APP_NAME-$env"
    
    echo "⏪ Rolling back $env environment"
    
    if [ -n "$revision" ]; then
        kubectl rollout undo deployment/$APP_NAME --to-revision=$revision -n $namespace
    else
        kubectl rollout undo deployment/$APP_NAME -n $namespace
    fi
    
    kubectl rollout status deployment/$APP_NAME -n $namespace
    echo "✅ Rollback completed"
    
    show_environment_status $env
}

# Cleanup environment
cleanup_environment() {
    local env=$1
    local namespace="$APP_NAME-$env"
    
    echo "🧹 Cleaning up $env environment"
    kubectl delete namespace $namespace --ignore-not-found=true
    echo "✅ $env environment cleaned up"
}

# Destroy all environments
destroy_all() {
    echo "💥 Destroying all pipeline environments"
    
    for env in "${ENVIRONMENTS[@]}"; do
        cleanup_environment $env
    done
    
    echo "✅ All environments destroyed"
}

# Main command dispatcher
case "$1" in
    init)
        init_environments
        ;;
    deploy)
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "❌ Usage: $0 deploy <env> <image> [tag]"
            exit 1
        fi
        deploy_to_environment "$2" "$3" "$4"
        ;;
    promote)
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "❌ Usage: $0 promote <from_env> <to_env>"
            exit 1
        fi
        promote_deployment "$2" "$3"
        ;;
    rollback)
        if [ -z "$2" ]; then
            echo "❌ Usage: $0 rollback <env> [revision]"
            exit 1
        fi
        rollback_environment "$2" "$3"
        ;;
    status)
        if [ -n "$2" ]; then
            show_environment_status "$2"
        else
            show_pipeline_status
        fi
        ;;
    pipeline)
        if [ -z "$2" ]; then
            echo "❌ Usage: $0 pipeline <image>"
            exit 1
        fi
        run_pipeline "$2"
        ;;
    cleanup)
        if [ -z "$2" ]; then
            echo "❌ Usage: $0 cleanup <env>"
            exit 1
        fi
        cleanup_environment "$2"
        ;;
    destroy)
        destroy_all
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "❌ Unknown command: $1"
        show_help
        exit 1
        ;;
esac
EOF

chmod +x pipeline-controller.sh

# Create pipeline monitoring dashboard
cat << 'EOF' > pipeline-monitor.sh
#!/bin/bash
# Pipeline monitoring and reporting dashboard

export APP_NAME="pipeline-app"

generate_pipeline_report() {
    echo "📊 DEPLOYMENT PIPELINE REPORT"
    echo "============================="
    echo "Generated: $(date)"
    echo "Application: $APP_NAME"
    echo ""
    
    # Environment summary
    echo "🏭 ENVIRONMENT SUMMARY"
    echo "====================="
    
    for env in dev staging prod; do
        local namespace="$APP_NAME-$env"
        
        echo ""
        echo "📦 $env Environment:"
        
        if kubectl get deployment $APP_NAME -n $namespace >/dev/null 2>&1; then
            local image=$(kubectl get deployment $APP_NAME -n $namespace -o jsonpath='{.spec.template.spec.containers[0].image}')
            local ready=$(kubectl get deployment $APP_NAME -n $namespace -o jsonpath='{.status.readyReplicas}')
            local desired=$(kubectl get deployment $APP_NAME -n $namespace -o jsonpath='{.spec.replicas}')
            local updated=$(kubectl get deployment $APP_NAME -n $namespace -o jsonpath='{.status.updatedReplicas}')
            
            echo "  Image: $image"
            echo "  Replicas: $ready/$desired ready, $updated updated"
            
            # Check health
            if [ "$ready" = "$desired" ] && [ "$updated" = "$desired" ]; then
                echo "  Status: ✅ Healthy"
            else
                echo "  Status: ⚠️  Degraded"
            fi
            
            # Get last deployment time
            local last_change=$(kubectl get deployment $APP_NAME -n $namespace -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/change-cause}')
            echo "  Last Change: ${last_change:-N/A}"
            
        else
            echo "  Status: ❌ Not Deployed"
        fi
    done
    
    # Resource usage summary
    echo ""
    echo "📊 RESOURCE USAGE"
    echo "================"
    
    for env in dev staging prod; do
        local namespace="$APP_NAME-$env"
        
        if kubectl get deployment $APP_NAME -n $namespace >/dev/null 2>&1; then
            echo ""
            echo "$env environment:"
            kubectl top pods -n $namespace --no-headers 2>/dev/null | while read line; do
                echo "  $line"
            done || echo "  Metrics not available"
        fi
    done
    
    # Deployment history
    echo ""
    echo "📚 DEPLOYMENT HISTORY"
    echo "===================="
    
    for env in dev staging prod; do
        local namespace="$APP_NAME-$env"
        
        if kubectl get deployment $APP_NAME -n $namespace >/dev/null 2>&1; then
            echo ""
            echo "$env environment:"
            kubectl rollout history deployment/$APP_NAME -n $namespace | tail -n +2 | head -5 | while read line; do
                echo "  $line"
            done
        fi
    done
}

monitor_pipeline_health() {
    local duration=${1:-300}  # 5 minutes default
    local interval=${2:-30}   # 30 seconds default
    
    echo "🔍 Pipeline Health Monitoring"
    echo "Duration: ${duration}s, Check Interval: ${interval}s"
    
    local end_time=$(($(date +%s) + duration))
    local check_count=0
    
    while [ $(date +%s) -lt $end_time ]; do
        check_count=$((check_count + 1))
        clear
        
        echo "📊 Pipeline Health Check #$check_count - $(date)"
        echo "================================================"
        
        local overall_health="healthy"
        
        for env in dev staging prod; do
            local namespace="$APP_NAME-$env"
            
            echo ""
            echo "🔍 $env Environment:"
            
            if kubectl get deployment $APP_NAME -n $namespace >/dev/null 2>&1; then
                local ready=$(kubectl get deployment $APP_NAME -n $namespace -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
                local desired=$(kubectl get deployment $APP_NAME -n $namespace -o jsonpath='{.spec.replicas}' 2>/dev/null)
                local available=$(kubectl get deployment $APP_NAME -n $namespace -o jsonpath='{.status.availableReplicas}' 2>/dev/null)
                
                echo "  Replicas: ${ready:-0}/${desired:-0} ready, ${available:-0} available"
                
                if [ "${ready:-0}" = "${desired:-0}" ] && [ "${available:-0}" = "${desired:-0}" ]; then
                    echo "  Status: ✅ Healthy"
                else
                    echo "  Status: ⚠️  Degraded"
                    overall_health="degraded"
                fi
                
                # Check for recent pod restarts
                local restarts=$(kubectl get pods -n $namespace --no-headers 2>/dev/null | awk '{print $4}' | awk '{sum+=$1} END {print sum+0}')
                echo "  Pod Restarts: $restarts"
                
                if [ $restarts -gt 5 ]; then
                    echo "  ⚠️  High restart count detected"
                    overall_health="unhealthy"
                fi
                
            else
                echo "  Status: ❌ Not Found"
                overall_health="unhealthy"
            fi
        done
        
        echo ""
        echo "🎯 Overall Pipeline Health: $overall_health"
        
        case $overall_health in
            healthy)
                echo "✅ All environments operating normally"
                ;;
            degraded)
                echo "⚠️  Some environments have issues - monitoring closely"
                ;;
            unhealthy)
                echo "🚨 Critical issues detected - intervention may be required"
                ;;
        esac
        
        sleep $interval
    done
    
    echo ""
    echo "📊 Monitoring completed after $check_count checks"
}

compare_environments() {
    echo "🔍 ENVIRONMENT COMPARISON"
    echo "========================"
    
    local dev_image=$(kubectl get deployment $APP_NAME -n $APP_NAME-dev -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "N/A")
    local staging_image=$(kubectl get deployment $APP_NAME -n $APP_NAME-staging -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "N/A")
    local prod_image=$(kubectl get deployment $APP_NAME -n $APP_NAME-prod -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "N/A")
    
    printf "%-10s | %-25s\n" "Environment" "Image"
    printf "%-10s | %-25s\n" "----------" "-------------------------"
    printf "%-10s | %-25s\n" "dev" "$dev_image"
    printf "%-10s | %-25s\n" "staging" "$staging_image"
    printf "%-10s | %-25s\n" "prod" "$prod_image"
    
    echo ""
    echo "🔄 Synchronization Status:"
    
    if [ "$dev_image" = "$staging_image" ] && [ "$staging_image" = "$prod_image" ]; then
        echo "✅ All environments synchronized"
    elif [ "$dev_image" = "$staging_image" ]; then
        echo "🟡 Dev and Staging synchronized, Production behind"
    elif [ "$staging_image" = "$prod_image" ]; then
        echo "🟡 Staging and Production synchronized, Development ahead"
    else
        echo "🔴 All environments are running different versions"
    fi
}

# Pipeline metrics collection
collect_metrics() {
    local output_file="pipeline-metrics-$(date +%Y%m%d-%H%M%S).json"
    
    echo "📊 Collecting pipeline metrics..."
    
    cat << JSON > $output_file
{
    "timestamp": "$(date -Iseconds)",
    "application": "$APP_NAME",
    "environments": {
JSON

    local first=true
    for env in dev staging prod; do
        local namespace="$APP_NAME-$env"
        
        if [ "$first" = true ]; then
            first=false
        else
            echo "," >> $output_file
        fi
        
        cat << JSON >> $output_file
        "$env": {
            "namespace": "$namespace",
            "deployment_exists": $(kubectl get deployment $APP_NAME -n $namespace >/dev/null 2>&1 && echo true || echo false)
JSON

        if kubectl get deployment $APP_NAME -n $namespace >/dev/null 2>&1; then
            local image=$(kubectl get deployment $APP_NAME -n $namespace -o jsonpath='{.spec.template.spec.containers[0].image}')
            local ready=$(kubectl get deployment $APP_NAME -n $namespace -o jsonpath='{.status.readyReplicas}')
            local desired=$(kubectl get deployment $APP_NAME -n $namespace -o jsonpath='{.spec.replicas}')
            local available=$(kubectl get deployment $APP_NAME -n $namespace -o jsonpath='{.status.availableReplicas}')
            local updated=$(kubectl get deployment $APP_NAME -n $namespace -o jsonpath='{.status.updatedReplicas}')
            
            cat << JSON >> $output_file
,
            "image": "$image",
            "replicas": {
                "desired": $desired,
                "ready": $ready,
                "available": $available,
                "updated": $updated
            }
JSON
        fi
        
        echo -e "\n        }" >> $output_file
    done
    
    echo -e "\n    }\n}" >> $output_file
    
    echo "✅ Metrics collected: $output_file"
}

# Interactive dashboard
run_dashboard() {
    while true; do
        clear
        echo "🎛️  DEPLOYMENT PIPELINE DASHBOARD"
        echo "================================="
        echo "$(date)"
        echo ""
        
        generate_pipeline_report
        
        echo ""
        echo "📋 MENU OPTIONS:"
        echo "1. Refresh (r)"
        echo "2. Compare Environments (c)"
        echo "3. Start Monitoring (m)"
        echo "4. Collect Metrics (x)"
        echo "5. Exit (q)"
        echo ""
        
        read -t 10 -p "Choose option (auto-refresh in 10s): " choice
        
        case $choice in
            1|r|R)
                continue
                ;;
            2|c|C)
                echo ""
                compare_environments
                read -p "Press Enter to continue..."
                ;;
            3|m|M)
                read -p "Monitoring duration (seconds, default 300): " duration
                monitor_pipeline_health ${duration:-300}
                read -p "Press Enter to continue..."
                ;;
            4|x|X)
                collect_metrics
                read -p "Press Enter to continue..."
                ;;
            5|q|Q)
                echo "Goodbye!"
                break
                ;;
            "")
                # Auto-refresh timeout
                continue
                ;;
            *)
                echo "Invalid option"
                sleep 2
                ;;
        esac
    done
}

# Command dispatcher
case "$1" in
    report)
        generate_pipeline_report
        ;;
    monitor)
        monitor_pipeline_health ${2:-300} ${3:-30}
        ;;
    compare)
        compare_environments
        ;;
    metrics)
        collect_metrics
        ;;
    dashboard)
        run_dashboard
        ;;
    *)
        echo "Pipeline Monitoring Tools"
        echo "========================"
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  report     Generate pipeline status report"
        echo "  monitor    Monitor pipeline health continuously"
        echo "  compare    Compare environments"
        echo "  metrics    Collect metrics to JSON file"
        echo "  dashboard  Interactive dashboard"
        ;;
esac
EOF

chmod +x pipeline-monitor.sh

# Create complete demo script
cat << 'EOF' > demo-complete-pipeline.sh
#!/bin/bash
# Complete pipeline demonstration

export APP_NAME="demo-pipeline"

echo "🎬 Complete Multi-Environment Pipeline Demo"
echo "=========================================="

echo "This demo will:"
echo "1. Initialize dev, staging, and production environments"
echo "2. Run a complete deployment pipeline"
echo "3. Demonstrate promotion workflows"
echo "4. Show monitoring and rollback capabilities"
echo ""
read -p "Press Enter to start..."

echo ""
echo "🏗️  Phase 1: Environment Initialization"
echo "======================================"
./pipeline-controller.sh init

echo ""
read -p "Press Enter to continue to pipeline execution..."

echo ""
echo "🚀 Phase 2: Pipeline Execution"
echo "============================="
echo "Running automated pipeline with nginx:1.21"
echo ""

# Run automated pipeline (will require user interaction for prod approval)
./pipeline-controller.sh pipeline nginx:1.21

echo ""
read -p "Press Enter to continue to monitoring demo..."

echo ""
echo "📊 Phase 3: Monitoring Demo"
echo "=========================="
echo "Starting 60-second monitoring session..."
./pipeline-monitor.sh monitor 60 15

echo ""
read -p "Press Enter to continue to rollback demo..."

echo ""
echo "⏪ Phase 4: Rollback Demo"
echo "======================="
echo "Demonstrating rollback in staging environment..."
./pipeline-controller.sh rollback staging

echo ""
echo "🎉 Demo completed!"
echo ""
echo "🧹 Cleanup options:"
echo "1. Keep environments for further exploration"
echo "2. Clean up all resources"
echo ""
read -p "Choose (1 or 2): " cleanup_choice

case $cleanup_choice in
    2)
        ./pipeline-controller.sh destroy
        echo "✅ All resources cleaned up"
        ;;
    *)
        echo "🏭 Environments preserved for exploration"
        echo ""
        echo "Available commands:"
        echo "  ./pipeline-controller.sh status    # Check status"
        echo "  ./pipeline-monitor.sh dashboard   # Interactive monitoring"
        echo "  ./pipeline-controller.sh destroy  # Cleanup when done"
        ;;
esac
EOF

chmod +x demo-complete-pipeline.sh

echo "✅ Multi-Environment Deployment Pipeline Created!"
echo ""
echo "📁 Project Structure:"
echo "├── pipeline-controller.sh     # Main pipeline management"
echo "├── pipeline-monitor.sh        # Monitoring and reporting"
echo "└── demo-complete-pipeline.sh  # Complete demo"
echo ""
echo "🚀 Quick Start Options:"
echo "1. Run complete demo: ./demo-complete-pipeline.sh"
echo "2. Initialize manually: ./pipeline-controller.sh init"
echo "3. Start monitoring: ./pipeline-monitor.sh dashboard"
echo ""
echo "📚 Available Commands:"
echo "  ./pipeline-controller.sh help    # See all pipeline commands"
echo "  ./pipeline-monitor.sh           # See monitoring options"

cd ..
```

## Production-Ready Deployments: Advanced Configuration Patterns

Building on your hands-on experience, let's explore sophisticated production patterns that combine multiple advanced concepts.

### Lab 7: Production Hardening Workshop (Expert Level)

This comprehensive lab teaches you to create bulletproof production deployments with all the enterprise-grade features.

```bash
#!/bin/bash
# lab7-production-hardening.sh
# Complete production hardening workshop

echo "🛡️ Lab 7: Production Hardening Workshop"
echo "======================================"

# Create hardened deployment templates
cat << 'EOF' > production-hardened-template.yaml
# production-hardened-template.yaml
# Enterprise-grade deployment template with all security and reliability features
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hardened-app
  labels:
    app: hardened-app
    environment: production
    version: "1.0"
    tier: frontend
  annotations:
    # Deployment tracking
    deployment.kubernetes.io/revision: "1"
    kubernetes.io/change-cause: "Initial hardened deployment"
    
    # Security annotations
    seccomp.security.alpha.kubernetes.io/pod: runtime/default
    
    # Compliance annotations
    compliance.company.com/reviewed: "true"
    compliance.company.com/reviewer: "security-team"
    
spec:
  replicas: 3
  
  # Advanced deployment strategy
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1        # Never more than 1 pod down
      maxSurge: 1              # Conservative surge to control resource usage
  
  # Precise pod selection
  selector:
    matchLabels:
      app: hardened-app
      environment: production
  
  template:
    metadata:
      labels:
        app: hardened-app
        environment: production
        version: "1.0"
        tier: frontend
      annotations:
        # Pod security
        container.apparmor.security.beta.kubernetes.io/app: runtime/default
        
    spec:
      # Security context at pod level
      securityContext:
        runAsNonRoot: true          # Never run as root
        runAsUser: 1001             # Specific non-root user
        runAsGroup: 1001            # Specific group
        fsGroup: 1001               # File system group
        seccompProfile:
          type: RuntimeDefault     # Apply seccomp profile
      
      # Service account with minimal permissions
      serviceAccountName: hardened-app-sa
      automountServiceAccountToken: false  # Don't auto-mount unless needed
      
      # Node selection and affinity
      nodeSelector:
        kubernetes.io/os: linux
        node.kubernetes.io/instance-type: "production"
      
      # Anti-affinity to spread across nodes
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - hardened-app
            topologyKey: kubernetes.io/hostname
        
        # Prefer nodes in different zones
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: topology.kubernetes.io/zone
                operator: In
                values:
                - zone-a
                - zone-b
                - zone-c
      
      # Tolerations for dedicated nodes
      tolerations:
      - key: "production-only"
        operator: "Equal"
        value: "true"
        effect: "NoSchedule"
      
      # DNS configuration
      dnsPolicy: ClusterFirst
      dnsConfig:
        options:
        - name: ndots
          value: "2"
        - name: edns0
      
      # Termination settings
      terminationGracePeriodSeconds: 30
      
      containers:
      - name: app
        image: nginx:1.21.6  # Pinned version for security
        
        # Security context at container level
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 1001
          capabilities:
            drop:
            - ALL              # Drop all capabilities
            add:
            - NET_BIND_SERVICE # Add only what's needed
        
        ports:
        - containerPort: 8080  # Non-privileged port
          name: http
          protocol: TCP
        
        # Resource management - critical for production
        resources:
          requests:
            memory: "256Mi"    # Guaranteed memory
            cpu: "200m"        # Guaranteed CPU
            ephemeral-storage: "1Gi"  # Guaranteed storage
          limits:
            memory: "512Mi"    # Memory limit
            cpu: "500m"        # CPU limit
            ephemeral-storage: "2Gi"  # Storage limit
        
        # Comprehensive health checks
        startupProbe:
          httpGet:
            path: /health/startup
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 30    # Allow 5 minutes for startup
          successThreshold: 1
        
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
          successThreshold: 1
        
        livenessProbe:
          httpGet:
            path: /health/live
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 30
          periodSeconds: 30
          timeoutSeconds: 5
          failureThreshold: 3
          successThreshold: 1
        
        # Environment variables with security considerations
        env:
        - name: ENVIRONMENT
          value: "production"
        - name: LOG_LEVEL
          value: "warn"        # Appropriate for production
        - name: TZ
          value: "UTC"         # Consistent timezone
        
        # Secret and ConfigMap references
        envFrom:
        - configMapRef:
            name: hardened-app-config
        - secretRef:
            name: hardened-app-secrets
        
        # Volume mounts with security
        volumeMounts:
        - name: tmp
          mountPath: /tmp
          readOnly: false
        - name: var-cache
          mountPath: /var/cache/nginx
          readOnly: false
        - name: var-run
          mountPath: /var/run
          readOnly: false
        - name: config
          mountPath: /etc/nginx/conf.d
          readOnly: true
        - name: secrets
          mountPath: /etc/ssl/certs
          readOnly: true
        
        # Lifecycle hooks for graceful handling
        lifecycle:
          preStop:
            exec:
              command:
              - /bin/sh
              - -c
              - "sleep 5; /usr/sbin/nginx -s quit"
      
      # Volumes with appropriate configurations
      volumes:
      - name: tmp
        emptyDir:
          sizeLimit: 100Mi
      - name: var-cache
        emptyDir:
          sizeLimit: 100Mi
      - name: var-run
        emptyDir:
          sizeLimit: 100Mi
      - name: config
        configMap:
          name: hardened-app-config
          defaultMode: 0644
      - name: secrets
        secret:
          secretName: hardened-app-secrets
          defaultMode: 0600
---
# Supporting resources
apiVersion: v1
kind: ServiceAccount
metadata:
  name: hardened-app-sa
  labels:
    app: hardened-app
automountServiceAccountToken: false
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: hardened-app-config
  labels:
    app: hardened-app
data:
  nginx.conf: |
    server {
        listen 8080;
        server_name _;
        
        # Security headers
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains";
        
        location /health/startup {
            access_log off;
            return 200 "startup ok\n";
        }
        
        location /health/ready {
            access_log off;
            return 200 "ready ok\n";
        }
        
        location /health/live {
            access_log off;
            return 200 "live ok\n";
        }
        
        location / {
            return 200 "Hardened Application Running\n";
        }
    }
---
apiVersion: v1
kind: Secret
metadata:
  name: hardened-app-secrets
  labels:
    app: hardened-app
type: Opaque
data:
  # Base64 encoded secrets
  api-key: bXktc2VjcmV0LWFwaS1rZXk=  # my-secret-api-key
  db-password: c3VwZXItc2VjcmV0LXBhc3N3b3Jk  # super-secret-password
---
apiVersion: v1
kind: Service
metadata:
  name: hardened-app-service
  labels:
    app: hardened-app
spec:
  selector:
    app: hardened-app
    environment: production
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
    name: http
  type: ClusterIP
EOF

# Create security hardening checklist script
cat << 'EOF' > security-hardening-checklist.sh
#!/bin/bash
# Security hardening validation checklist

APP_NAME="hardened-app"

echo "🔒 Security Hardening Checklist"
echo "==============================="

check_security_context() {
    echo "🔍 Checking Security Context..."
    
    local pod_name=$(kubectl get pods -l app=$APP_NAME -o jsonpath='{.items[0].metadata.name}')
    
    # Check runAsNonRoot
    local run_as_non_root=$(kubectl get pod $pod_name -o jsonpath='{.spec.securityContext.runAsNonRoot}')
    if [ "$run_as_non_root" = "true" ]; then
        echo "  ✅ Pod runs as non-root"
    else
        echo "  ❌ Pod may run as root"
    fi
    
    # Check readOnlyRootFilesystem
    local readonly_root=$(kubectl get pod $pod_name -o jsonpath='{.spec.containers[0].securityContext.readOnlyRootFilesystem}')
    if [ "$readonly_root" = "true" ]; then
        echo "  ✅ Root filesystem is read-only"
    else
        echo "  ❌ Root filesystem is writable"
    fi
    
    # Check capabilities
    local capabilities=$(kubectl get pod $pod_name -o jsonpath='{.spec.containers[0].securityContext.capabilities.drop}')
    if [[ "$capabilities" == *"ALL"* ]]; then
        echo "  ✅ All capabilities dropped"
    else
        echo "  ❌ Not all capabilities dropped"
    fi
}

check_resource_limits() {
    echo ""
    echo "🔍 Checking Resource Limits..."
    
    local deployment=$(kubectl get deployment $APP_NAME -o json)
    
    # Check CPU limits
    local cpu_limit=$(echo "$deployment" | jq -r '.spec.template.spec.containers[0].resources.limits.cpu')
    if [ "$cpu_limit" != "null" ]; then
        echo "  ✅ CPU limit set: $cpu_limit"
    else
        echo "  ❌ No CPU limit set"
    fi
    
    # Check memory limits
    local memory_limit=$(echo "$deployment" | jq -r '.spec.template.spec.containers[0].resources.limits.memory')
    if [ "$memory_limit" != "null" ]; then
        echo "  ✅ Memory limit set: $memory_limit"
    else
        echo "  ❌ No memory limit set"
    fi
    
    # Check requests
    local cpu_request=$(echo "$deployment" | jq -r '.spec.template.spec.containers[0].resources.requests.cpu')
    local memory_request=$(echo "$deployment" | jq -r '.spec.template.spec.containers[0].resources.requests.memory')
    
    if [ "$cpu_request" != "null" ] && [ "$memory_request" != "null" ]; then
        echo "  ✅ Resource requests set: CPU=$cpu_request, Memory=$memory_request"
    else
        echo "  ❌ Resource requests not properly set"
    fi
}

check_health_probes() {
    echo ""
    echo "🔍 Checking Health Probes..."
    
    local deployment=$(kubectl get deployment $APP_NAME -o json)
    
    # Check liveness probe
    local liveness=$(echo "$deployment" | jq -r '.spec.template.spec.containers[0].livenessProbe.httpGet.path')
    if [ "$liveness" != "null" ]; then
        echo "  ✅ Liveness probe configured: $liveness"
    else
        echo "  ❌ No liveness probe"
    fi
    
    # Check readiness probe
    local readiness=$(echo "$deployment" | jq -r '.spec.template.spec.containers[0].readinessProbe.httpGet.path')
    if [ "$readiness" != "null" ]; then
        echo "  ✅ Readiness probe configured: $readiness"
    else
        echo "  ❌ No readiness probe"
    fi
    
    # Check startup probe
    local startup=$(echo "$deployment" | jq -r '.spec.template.spec.containers[0].startupProbe.httpGet.path')
    if [ "$startup" != "null" ]; then
        echo "  ✅ Startup probe configured: $startup"
    else
        echo "  ⚠️  No startup probe (optional but recommended)"
    fi
}

check_network_policies() {
    echo ""
    echo "🔍 Checking Network Policies..."
    
    local policies=$(kubectl get networkpolicy -l app=$APP_NAME --no-headers 2>/dev/null | wc -l)
    if [ $policies -gt 0 ]; then
        echo "  ✅ Network policies found: $policies"
        kubectl get networkpolicy -l app=$APP_NAME
    else
        echo "  ⚠️  No network policies found (consider implementing)"
    fi
}

check_pod_security() {
    echo ""
    echo "🔍 Checking Pod Security Standards..."
    
    local pod_name=$(kubectl get pods -l app=$APP_NAME -o jsonpath='{.items[0].metadata.name}')
    
    # Check for privileged containers
    local privileged=$(kubectl get pod $pod_name -o jsonpath='{.spec.containers[0].securityContext.privileged}')
    if [ "$privileged" = "true" ]; then
        echo "  ❌ Container running in privileged mode"
    else
        echo "  ✅ Container not privileged"
    fi
    
    # Check for host network
    local host_network=$(kubectl get pod $pod_name -o jsonpath='{.spec.hostNetwork}')
    if [ "$host_network" = "true" ]; then
        echo "  ❌ Pod using host network"
    else
        echo "  ✅ Pod not using host network"
    fi
    
    # Check for host PID
    local host_pid=$(kubectl get pod $pod_name -o jsonpath='{.spec.hostPID}')
    if [ "$host_pid" = "true" ]; then
        echo "  ❌ Pod using host PID namespace"
    else
        echo "  ✅ Pod not using host PID namespace"
    fi
}

generate_security_report() {
    echo ""
    echo "📋 Generating Security Report..."
    
    cat << REPORT > security-report.md
# Security Hardening Report

Generated: $(date)
Application: $APP_NAME

## Security Checklist Results

### Security Context
$(check_security_context 2>&1)

### Resource Limits
$(check_resource_limits 2>&1)

### Health Probes
$(check_health_probes 2>&1)

### Network Policies
$(check_network_policies 2>&1)

### Pod Security
$(check_pod_security 2>&1)

## Recommendations

### Implemented Security Measures
- Non-root container execution
- Read-only root filesystem
- Dropped capabilities
- Resource limits and requests
- Comprehensive health checks
- Security contexts applied

### Additional Considerations
- Implement NetworkPolicies for network segmentation
- Consider Pod Security Standards/Pod Security Policies
- Regular security scanning of container images
- Secrets management with external systems (Vault, etc.)
- Service mesh for additional security (Istio, Linkerd)

## Next Steps

1. Implement NetworkPolicies
2. Set up image scanning pipeline
3. Configure external secrets management
4. Enable audit logging
5. Regular security assessments

REPORT

    echo "  ✅ Report generated: security-report.md"
}

# Run all checks
echo "Running comprehensive security audit..."
check_security_context
check_resource_limits
check_health_probes
check_network_policies
check_pod_security
generate_security_report

echo ""
echo "🎯 Security Audit Complete!"
echo "See security-report.md for detailed results and recommendations"
EOF

chmod +x security-hardening-checklist.sh

# Create production deployment workshop script
cat << 'EOF' > production-workshop.sh
#!/bin/bash
# Complete production hardening workshop

echo "🏭 Production Deployment Workshop"
echo "================================"

workshop_phase_1() {
    echo "📋 Phase 1: Security-First Deployment"
    echo "====================================="
    
    echo "Deploying hardened production application..."
    kubectl apply -f production-hardened-template.yaml
    
    echo "⏳ Waiting for deployment to be ready..."
    kubectl wait --for=condition=available deployment/hardened-app --timeout=120s
    
    echo "✅ Hardened application deployed!"
    kubectl get pods -l app=hardened-app -o wide
}

workshop_phase_2() {
    echo ""
    echo "🔒 Phase 2: Security Validation"
    echo "==============================="
    
    echo "Running comprehensive security audit..."
    ./security-hardening-checklist.sh
}

workshop_phase_3() {
    echo ""
    echo "🧪 Phase 3: Resilience Testing"
    echo "============================="
    
    echo "Testing pod self-healing..."
    POD_TO_DELETE=$(kubectl get pods -l app=hardened-app -o jsonpath='{.items[0].metadata.name}')
    echo "Deleting pod: $POD_TO_DELETE"
    kubectl delete pod $POD_TO_DELETE
    
    echo "⏳ Watching recovery (30 seconds)..."
    timeout 30s kubectl get pods -l app=hardened-app -w
    
    echo ""
    echo "Testing rolling update resilience..."
    kubectl set image deployment/hardened-app app=nginx:1.22
    kubectl rollout status deployment/hardened-app
    
    echo "✅ Application updated without downtime"
}

workshop_phase_4() {
    echo ""
    echo "📊 Phase 4: Production Monitoring Setup"
    echo "======================================="
    
    # Create monitoring resources
    cat << YAML | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: monitoring-config
  labels:
    app: hardened-app
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
    scrape_configs:
    - job_name: 'hardened-app'
      static_configs:
      - targets: ['hardened-app-service:80']
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: monitoring-stack
  labels:
    app: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: monitoring
  template:
    metadata:
      labels:
        app: monitoring
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:latest
        ports:
        - containerPort: 9090
        volumeMounts:
        - name: config
          mountPath: /etc/prometheus
      volumes:
      - name: config
        configMap:
          name: monitoring-config
---
apiVersion: v1
kind: Service
metadata:
  name: monitoring-service
  labels:
    app: monitoring
spec:
  selector:
    app: monitoring
  ports:
  - port: 9090
    targetPort: 9090
  type: ClusterIP
YAML

    echo "✅ Monitoring stack deployed"
    echo "💡 In production, you would use managed monitoring solutions"
}

workshop_phase_5() {
    echo ""
    echo "🚨 Phase 5: Disaster Recovery Testing"
    echo "====================================="
    
    echo "Creating backup of current deployment..."
    kubectl get deployment hardened-app -o yaml > hardened-app-backup.yaml
    
    echo "Simulating disaster (scaling to 0)..."
    kubectl scale deployment hardened-app --replicas=0
    
    echo "⏳ Waiting for pods to terminate..."
    sleep 10
    
    echo "🔄 Initiating disaster recovery..."
    kubectl scale deployment hardened-app --replicas=3
    kubectl wait --for=condition=available deployment/hardened-app --timeout=120s
    
    echo "✅ Disaster recovery completed successfully"
    echo "💾 Backup saved as: hardened-app-backup.yaml"
}

run_interactive_workshop() {
    echo "🎓 Interactive Production Workshop"
    echo "=================================="
    echo ""
    echo "This workshop covers:"
    echo "1. Security-first deployment practices"
    echo "2. Comprehensive security validation"
    echo "3. Resilience and self-healing testing"
    echo "4. Production monitoring setup"
    echo "5. Disaster recovery procedures"
    echo ""
    
    read -p "Ready to start? (y/n): " confirm
    if [ "$confirm" != "y" ]; then
        echo "Workshop cancelled"
        return
    fi
    
    workshop_phase_1
    read -p "Continue to security validation? (y/n): " confirm
    [ "$confirm" = "y" ] && workshop_phase_2
    
    read -p "Continue to resilience testing? (y/n): " confirm
    [ "$confirm" = "y" ] && workshop_phase_3
    
    read -p "Continue to monitoring setup? (y/n): " confirm
    [ "$confirm" = "y" ] && workshop_phase_4
    
    read -p "Continue to disaster recovery testing? (y/n): " confirm
    [ "$confirm" = "y" ] && workshop_phase_5
    
    echo ""
    echo "🎉 Production Workshop Completed!"
    echo "==============================="
    echo ""
    echo "📚 Key Learnings:"
    echo "• Security should be built-in from the start"
    echo "• Comprehensive health checks are essential"
    echo "• Resource limits prevent resource starvation"
    echo "• Anti-affinity rules improve availability"
    echo "• Regular security audits are crucial"
    echo ""
    echo "🧹 Cleanup:"
    echo "kubectl delete -f production-hardened-template.yaml"
    echo "kubectl delete deployment,service,configmap monitoring-stack monitoring-service monitoring-config"
    echo "rm -f hardened-app-backup.yaml security-report.md"
}

# Command dispatcher
case "$1" in
    interactive)
        run_interactive_workshop
        ;;
    phase1)
        workshop_phase_1
        ;;
    phase2)
        workshop_phase_2
        ;;
    phase3)
        workshop_phase_3
        ;;
    phase4)
        workshop_phase_4
        ;;
    phase5)
        workshop_phase_5
        ;;
    cleanup)
        echo "🧹 Cleaning up workshop resources..."
        kubectl delete -f production-hardened-template.yaml --ignore-not-found=true
        kubectl delete deployment,service,configmap monitoring-stack monitoring-service monitoring-config --ignore-not-found=true
        rm -f hardened-app-backup.yaml security-report.md
        echo "✅ Cleanup completed"
        ;;
    *)
        echo "Production Deployment Workshop"
        echo "============================="
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  interactive  Run complete interactive workshop"
        echo "  phase1       Security-first deployment"
        echo "  phase2       Security validation"
        echo "  phase3       Resilience testing"
        echo "  phase4       Monitoring setup"
        echo "  phase5       Disaster recovery"
        echo "  cleanup      Clean up all resources"
        ;;
esac
EOF

chmod +x production-workshop.sh

echo "✅ Production Hardening Workshop Created!"
echo ""
echo "📁 Workshop Files:"
echo "├── production-hardened-template.yaml  # Complete hardened deployment"
echo "├── security-hardening-checklist.sh   # Security validation tools"
echo "└── production-workshop.sh             # Interactive workshop"
echo ""
echo "🚀 Start the workshop:"
echo "./production-workshop.sh interactive"
```

## Final Integration: Complete Kubernetes Deployment Mastery

### Capstone Project: Enterprise Deployment Platform (Master Level)

This final project integrates everything you've learned into a complete enterprise-grade deployment platform.

```bash
#!/bin/bash
# capstone-project.sh
# Enterprise Deployment Platform - Integration of all concepts

echo "🏆 Capstone Project: Enterprise Deployment Platform"
echo "=================================================="

PROJECT_NAME="enterprise-platform"
mkdir -p $PROJECT_NAME
cd $PROJECT_NAME

# Create the main platform controller
cat << 'EOF' > platform-controller.sh
#!/bin/bash
# Enterprise Deployment Platform Controller
# Integrates all deployment patterns and best practices

PLATFORM_VERSION="1.0.0"
DEFAULT_NAMESPACE="enterprise-platform"

show_platform_help() {
    echo "🏢 Enterprise Deployment Platform v$PLATFORM_VERSION"
    echo "===================================================="
    echo ""
    echo "A comprehensive deployment platform integrating:"
    echo "• Multi-environment pipelines"
    echo "• Blue-Green and Canary deployments"
    echo "• Security hardening"
    echo "• Advanced monitoring"
    echo "• Automated rollbacks"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Platform Commands:"
    echo "  init                    Initialize platform"
    echo "  create-app <name>       Create new application"
    echo "  deploy <app> <strategy> Deploy with strategy (rolling|blue-green|canary)"
    echo "  promote <app>           Promote through environments"
    echo "  rollback <app> <env>    Rollback application"
    echo "  monitor <app>           Start monitoring dashboard"
    echo "  security-scan <app>     Run security assessment"
    echo "  status                  Show platform status"
    echo "  cleanup                 Clean up platform"
    echo ""
    echo "Deployment Strategies:"
    echo "  rolling     Standard rolling update"
    echo "  blue-green  Zero-downtime blue-green deployment"
    echo "  canary      Gradual traffic shifting"
    echo ""
    echo "Examples:"
    echo "  $0 init"
    echo "  $0 create-app my-web-service"
    echo "  $0 deploy my-web-service canary"
    echo "  $0 promote my-web-service"
}

# Initialize the platform
init_platform() {
    echo "🏗️  Initializing Enterprise Deployment Platform"
    echo "=============================================="
    
    # Create platform namespace
    kubectl create namespace $DEFAULT_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    kubectl label namespace $DEFAULT_NAMESPACE platform=enterprise-deployment
    
    # Create RBAC resources
    cat << YAML | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: platform-controller
  namespace: $DEFAULT_NAMESPACE
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: platform-controller
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["networking.k8s.io"]
  resources: ["networkpolicies"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["autoscaling"]
  resources: ["horizontalpodautoscalers"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: platform-controller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: platform-controller
subjects:
- kind: ServiceAccount
  name: platform-controller
  namespace: $DEFAULT_NAMESPACE
YAML

    # Create platform configuration
    cat << YAML | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: platform-config
  namespace: $DEFAULT_NAMESPACE
data:
  platform.yaml: |
    platform:
      version: "$PLATFORM_VERSION"
      default_strategy: "rolling"
      environments:
        - name: "dev"
          replicas: 2
          resources:
            cpu: "100m"
            memory: "128Mi"
        - name: "staging"
          replicas: 3
          resources:
            cpu: "200m"
            memory: "256Mi"
        - name: "prod"
          replicas: 5
          resources:
            cpu: "500m"
            memory: "512Mi"
      security:
        enforce_non_root: true
        require_resource_limits: true
        enable_network_policies: true
      monitoring:
        enabled: true
        metrics_retention: "30d"
        alerting: true
YAML

    # Deploy platform monitoring
    deploy_platform_monitoring
    
    echo "✅ Enterprise Platform initialized successfully"
    show_platform_status
}

# Deploy platform monitoring
deploy_platform_monitoring() {
    echo "📊 Deploying Platform Monitoring..."
    
    cat << YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: platform-dashboard
  namespace: $DEFAULT_NAMESPACE
  labels:
    app: platform-dashboard
    component: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: platform-dashboard
  template:
    metadata:
      labels:
        app: platform-dashboard
        component: monitoring
    spec:
      serviceAccountName: platform-controller
      containers:
      - name: dashboard
        image: nginx:1.21
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
        volumeMounts:
        - name: dashboard-config
          mountPath: /usr/share/nginx/html
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 30
      volumes:
      - name: dashboard-config
        configMap:
          name: dashboard-html
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: dashboard-html
  namespace: $DEFAULT_NAMESPACE
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>Enterprise Deployment Platform</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
            .header { background: #2196F3; color: white; padding: 20px; border-radius: 8px; }
            .dashboard { background: white; margin: 20px 0; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
            .status-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; }
            .metric-card { background: #f8f9fa; padding: 15px; border-radius: 5px; border-left: 4px solid #4CAF50; }
            .metric-value { font-size: 2em; font-weight: bold; color: #2196F3; }
            .metric-label { color: #666; margin-top: 5px; }
        </style>
    </head>
    <body>
        <div class="header">
            <h1>🏢 Enterprise Deployment Platform</h1>
            <p>Comprehensive deployment management and monitoring</p>
        </div>
        
        <div class="dashboard">
            <h2>📊 Platform Overview</h2>
            <div class="status-grid">
                <div class="metric-card">
                    <div class="metric-value">Active</div>
                    <div class="metric-label">Platform Status</div>
                </div>
                <div class="metric-card">
                    <div class="metric-value">v1.0.0</div>
                    <div class="metric-label">Platform Version</div>
                </div>
                <div class="metric-card">
                    <div class="metric-value">All Patterns</div>
                    <div class="metric-label">Deployment Strategies</div>
                </div>
                <div class="metric-card">
                    <div class="metric-value">Enabled</div>
                    <div class="metric-label">Security Hardening</div>
                </div>
            </div>
        </div>
        
        <div class="dashboard">
            <h2>🚀 Available Features</h2>
            <ul>
                <li><strong>Multi-Environment Pipelines:</strong> Dev → Staging → Production</li>
                <li><strong>Advanced Deployment Strategies:</strong> Rolling, Blue-Green, Canary</li>
                <li><strong>Security Hardening:</strong> Non-root containers, resource limits, network policies</li>
                <li><strong>Automated Monitoring:</strong> Health checks, metrics collection, alerting</li>
                <li><strong>Self-Healing:</strong> Automatic recovery and rollback capabilities</li>
            </ul>
        </div>
        
        <div class="dashboard">
            <h2>📝 Quick Commands</h2>
            <pre>
# Create a new application
./platform-controller.sh create-app my-service

# Deploy with canary strategy
./platform-controller.sh deploy my-service canary

# Promote through environments
./platform-controller.sh promote my-service

# Monitor application
./platform-controller.sh monitor my-service
            </pre>
        </div>
    </body>
    </html>
---
apiVersion: v1
kind: Service
metadata:
  name: platform-dashboard
  namespace: $DEFAULT_NAMESPACE
  labels:
    app: platform-dashboard
spec:
  selector:
    app: platform-dashboard
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
YAML

    echo "✅ Platform monitoring deployed"
}

# Create a new application
create_application() {
    local app_name=$1
    
    if [ -z "$app_name" ]; then
        echo "❌ Application name required"
        return 1
    fi
    
    echo "🆕 Creating application: $app_name"
    echo "================================"
    
    # Create application directory structure
    mkdir -p apps/$app_name/{dev,staging,prod}
    
    # Generate application templates
    for env in dev staging prod; do
        generate_app_template $app_name $env > apps/$app_name/$env/deployment.yaml
    done
    
    # Create application metadata
    cat << YAML > apps/$app_name/app.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: $app_name-metadata
  namespace: $DEFAULT_NAMESPACE
  labels:
    app: $app_name
    component: metadata
data:
  name: "$app_name"
  created: "$(date -Iseconds)"
  environments: "dev,staging,prod"
  strategies: "rolling,blue-green,canary"
  status: "created"
YAML

    kubectl apply -f apps/$app_name/app.yaml
    
    echo "✅ Application $app_name created"
    echo "📁 Templates generated in: apps/$app_name/"
    echo ""
    echo "Next steps:"
    echo "1. Review and customize deployment templates"
    echo "2. Deploy to dev: ./platform-controller.sh deploy $app_name rolling"
    echo "3. Promote through environments"
}

# Generate application template
generate_app_template() {
    local app_name=$1
    local env=$2
    
    # Get environment-specific configuration
    local replicas=2
    local cpu="100m"
    local memory="128Mi"
    
    case $env in
        staging)
            replicas=3
            cpu="200m"
            memory="256Mi"
            ;;
        prod)
            replicas=5
            cpu="500m"
            memory="512Mi"
            ;;
    esac
    
    cat << YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $app_name
  namespace: $app_name-$env
  labels:
    app: $app_name
    environment: $env
    managed-by: enterprise-platform
  annotations:
    platform.enterprise.com/version: "$PLATFORM_VERSION"
    platform.enterprise.com/environment: "$env"
spec:
  replicas: $replicas
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  selector:
    matchLabels:
      app: $app_name
      environment: $env
  template:
    metadata:
      labels:
        app: $app_name
        environment: $env
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
        fsGroup: 1001
      containers:
      - name: app
        image: nginx:1.21  # Default image
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: $cpu
            memory: $memory
          limits:
            cpu: $(echo "$cpu" | sed 's/m/*2&/')
            memory: $(echo "$memory" | sed 's/Mi/*2&/')
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 30
        env:
        - name: ENVIRONMENT
          value: "$env"
        - name: APP_NAME
          value: "$app_name"
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /var/cache
      volumes:
      - name: tmp
        emptyDir: {}
      - name: cache
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: $app_name
  namespace: $app_name-$env
  labels:
    app: $app_name
    environment: $env
spec:
  selector:
    app: $app_name
    environment: $env
  ports:
  - port: 80
    targetPort: 8080
  type: ClusterIP
---
apiVersion: v1
kind: Namespace
metadata:
  name: $app_name-$env
  labels:
    app: $app_name
    environment: $env
    managed-by: enterprise-platform
YAML
}

# Deploy application with strategy
deploy_application() {
    local app_name=$1
    local strategy=${2:-rolling}
    local env=${3:-dev}
    
    echo "🚀 Deploying $app_name with $strategy strategy to $env"
    echo "===================================================="
    
    if [ ! -f "apps/$app_name/app.yaml" ]; then
        echo "❌ Application $app_name not found. Create it first."
        return 1
    fi
    
    case $strategy in
        rolling)
            deploy_rolling $app_name $env
            ;;
        blue-green)
            deploy_blue_green $app_name $env
            ;;
        canary)
            deploy_canary $app_name $env
            ;;
        *)
            echo "❌ Unknown strategy: $strategy"
            echo "Available strategies: rolling, blue-green, canary"
            return 1
            ;;
    esac
}

deploy_rolling() {
    local app_name=$1
    local env=$2
    
    echo "📦 Rolling deployment to $env..."
    kubectl apply -f apps/$app_name/$env/deployment.yaml
    kubectl rollout status deployment/$app_name -n $app_name-$env
    echo "✅ Rolling deployment completed"
}

deploy_blue_green() {
    local app_name=$1
    local env=$2
    
    echo "🔵🟢 Blue-Green deployment to $env..."
    # Implementation would integrate with blue-green manager
    echo "🔄 Blue-Green deployment simulation completed"
}

deploy_canary() {
    local app_name=$1
    local env=$2
    
    echo "🐦 Canary deployment to $env..."
    # Implementation would integrate with canary controller
    echo "📊 Canary deployment simulation completed"
}

# Show platform status
show_platform_status() {
    echo ""
    echo "🏢 ENTERPRISE PLATFORM STATUS"
    echo "============================="
    echo "Version: $PLATFORM_VERSION"
    echo "Namespace: $DEFAULT_NAMESPACE"
    echo ""
    
    # Platform components
    echo "🔧 Platform Components:"
    kubectl get pods -n $DEFAULT_NAMESPACE -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[0].ready
    
    echo ""
    echo "📱 Applications:"
    if ls apps/* >/dev/null 2>&1; then
        for app_dir in apps/*/; do
            app_name=$(basename "$app_dir")
            echo "  • $app_name"
            
            for env in dev staging prod; do
                if kubectl get deployment $app_name -n $app_name-$env >/dev/null 2>&1; then
                    local ready=$(kubectl get deployment $app_name -n $app_name-$env -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
                    local desired=$(kubectl get deployment $app_name -n $app_name-$env -o jsonpath='{.spec.replicas}' 2>/dev/null)
                    echo "    $env: ${ready:-0}/${desired:-0} ready"
                fi
            done
        done
    else
        echo "  No applications created yet"
    fi
    
    echo ""
    echo "🌐 Access Platform Dashboard:"
    echo "kubectl port-forward -n $DEFAULT_NAMESPACE service/platform-dashboard 8080:80"
    echo "Then visit: http://localhost:8080"
}

# Integrated monitoring
start_monitoring() {
    local app_name=$1
    
    echo "📊 Starting integrated monitoring for $app_name"
    echo "=============================================="
    
    # Port forward to dashboard
    kubectl port-forward -n $DEFAULT_NAMESPACE service/platform-dashboard 8080:80 &
    DASHBOARD_PID=$!
    
    echo "🌐 Platform dashboard available at: http://localhost:8080"
    echo "📱 Monitoring $app_name across all environments"
    
    # Monitor application health
    while true; do
        clear
        echo "📊 Real-time Application Monitoring - $app_name"
        echo "=============================================="
        echo "$(date)"
        echo ""
        
        for env in dev staging prod; do
            echo "🔍 $env Environment:"
            if kubectl get deployment $app_name -n $app_name-$env >/dev/null 2>&1; then
                kubectl get deployment $app_name -n $app_name-$env -o custom-columns=READY:.status.readyReplicas,UP-TO-DATE:.status.updatedReplicas,AVAILABLE:.status.availableReplicas
                kubectl get pods -l app=$app_name -n $app_name-$env --no-headers | head -3
            else
                echo "  Not deployed"
            fi
            echo ""
        done
        
        echo "Press Ctrl+C to stop monitoring"
        sleep 10
    done
    
    kill $DASHBOARD_PID 2>/dev/null
}

# Main command dispatcher
case "$1" in
    init)
        init_platform
        ;;
    create-app)
        create_application "$2"
        ;;
    deploy)
        deploy_application "$2" "$3" "$4"
        ;;
    monitor)
        start_monitoring "$2"
        ;;
    status)
        show_platform_status
        ;;
    cleanup)
        echo "🧹 Cleaning up Enterprise Platform..."
        kubectl delete namespace $DEFAULT_NAMESPACE --ignore-not-found=true
        rm -rf apps/
        echo "✅ Platform cleanup completed"
        ;;
    help|--help|-h)
        show_platform_help
        ;;
    *)
        echo "❌ Unknown command: $1"
        show_platform_help
        exit 1
        ;;
esac
EOF

chmod +x platform-controller.sh

# Create integration demo
cat << 'EOF' > integration-demo.sh
#!/bin/bash
# Complete integration demonstration

echo "🎓 Enterprise Platform Integration Demo"
echo "======================================"

demo_phase_1() {
    echo "🏗️  Phase 1: Platform Initialization"
    echo "==================================="
    ./platform-controller.sh init
    echo "Press Enter to continue..."; read
}

demo_phase_2() {
    echo "🆕 Phase 2: Application Creation"
    echo "==============================="
    ./platform-controller.sh create-app web-service
    ./platform-controller.sh create-app api-service
    echo "Press Enter to continue..."; read
}

demo_phase_3() {
    echo "🚀 Phase 3: Multi-Strategy Deployments"
    echo "====================================="
    echo "Deploying web-service with rolling strategy..."
    ./platform-controller.sh deploy web-service rolling dev
    echo ""
    echo "Deploying api-service with canary strategy..."
    ./platform-controller.sh deploy api-service canary dev
    echo "Press Enter to continue..."; read
}

demo_phase_4() {
    echo "📊 Phase 4: Integrated Monitoring"
    echo "================================"
    ./platform-controller.sh status
    echo ""
    echo "Starting monitoring dashboard..."
    echo "Visit http://localhost:8080 to see the platform dashboard"
    kubectl port-forward -n enterprise-platform service/platform-dashboard 8080:80 &
    DASHBOARD_PID=$!
    echo "Dashboard PID: $DASHBOARD_PID"
    echo "Press Enter to continue..."; read
    kill $DASHBOARD_PID 2>/dev/null
}

demo_phase_5() {
    echo "🧹 Phase 5: Cleanup"
    echo "=================="
    echo "Demo completed! Choose cleanup option:"
    echo "1. Keep platform for exploration"
    echo "2. Clean up all resources"
    read -p "Choice (1 or 2): " choice
    
    case $choice in
        2)
            ./platform-controller.sh cleanup
            echo "✅ All resources cleaned up"
            ;;
        *)
            echo "🏢 Platform preserved for exploration"
            echo "Use: ./platform-controller.sh help for available commands"
            ;;
    esac
}

# Run complete demo
echo "This demo showcases the complete Enterprise Deployment Platform"
echo "integrating all concepts learned throughout this guide:"
echo ""
echo "• Multi-environment pipelines"
echo "• Advanced deployment strategies"
echo "• Security hardening"
echo "• Monitoring and observability"
echo "• Self-healing and resilience"
echo ""
read -p "Ready to start the integration demo? (y/n): " confirm

if [ "$confirm" = "y" ]; then
    demo_phase_1
    demo_phase_2
    demo_phase_3
    demo_phase_4
    demo_phase_5
else
    echo "Demo cancelled. Run again when ready!"
fi
EOF

chmod +x integration-demo.sh

echo "🏆 Enterprise Deployment Platform Created!"
echo ""
echo "📁 Capstone Project Structure:"
echo "├── platform-controller.sh    # Main platform controller"
echo "├── integration-demo.sh       # Complete integration demo"
echo "└── apps/                     # Application templates (created on demand)"
echo ""
echo "🚀 Quick Start:"
echo "1. Run integration demo: ./integration-demo.sh"
echo "2. Or initialize manually: ./platform-controller.sh init"
echo ""
echo "🎓 What You've Built:"
echo "• Complete enterprise deployment platform"
echo "• Integration of all deployment patterns"
echo "• Security-first approach"
echo "• Comprehensive monitoring"
echo "• Self-service application creation"

cd ..
```

## Summary: Building Robust Applications

Understanding Deployments and ReplicaSets provides the foundation for running reliable applications in Kubernetes. Through this enhanced hands-on guide, you've progressed from basic concepts to enterprise-grade implementations. Here are the key insights and skills you've developed:

### **🎯 Core Concepts Mastered**

**Architectural Understanding**: You now understand how Deployments manage ReplicaSets, which manage Pods. This hierarchy enables sophisticated update strategies and self-healing behavior that you've observed in action through multiple labs.

**Declarative Management**: Through extensive hands-on practice, you've learned to specify your desired state and let Kubernetes figure out how to achieve it. This approach scales better than imperative commands and forms the foundation of GitOps practices.

**Production Readiness**: You've implemented resource limits, health checks, security contexts, and update strategies - all essential for production stability and reliability.

### **🛠️ Practical Skills Developed**

**Deployment Strategies**: You've built and operated three sophisticated deployment systems:
- **Blue-Green System**: Zero-downtime deployments with instant rollback capability
- **Canary Framework**: Gradual traffic shifting with automated monitoring and rollback triggers
- **Multi-Environment Pipeline**: Complete CI/CD-style promotion workflows across dev, staging, and production

**Security Hardening**: You've learned to implement enterprise-grade security from the ground up, including non-root containers, resource limits, security contexts, and comprehensive audit capabilities.

**Troubleshooting Mastery**: Through systematic workshops and real-world scenarios, you've developed the skills to diagnose and resolve common deployment issues quickly and effectively.

### **🏢 Enterprise Integration**

**Platform Thinking**: Your capstone project demonstrates how to integrate all concepts into a cohesive enterprise platform that provides self-service capabilities while maintaining security and operational excellence.

**Observability**: You've implemented comprehensive monitoring, logging, and alerting strategies that provide visibility into application health and performance across all environments.

**Automation**: You've built systems that reduce manual intervention through automated testing, progressive delivery, and intelligent rollback mechanisms.

### **🎓 Advanced Capabilities**

**Multi-Pattern Expertise**: You can now choose and implement the appropriate deployment strategy based on specific requirements:
- Rolling updates for standard deployments
- Blue-green for critical zero-downtime requirements  
- Canary for risk-averse gradual rollouts
- Custom strategies for unique business needs

**Recovery Planning**: You understand rollback mechanisms, disaster recovery procedures, and troubleshooting approaches, ensuring you're prepared for incident response.

**Scalability Design**: Your implementations consider resource management, node affinity, and horizontal scaling to handle varying loads effectively.

### **🚀 Next Steps for Continued Growth**

**Production Implementation**: Apply these patterns in your real-world environments, starting with non-critical applications and gradually expanding to production systems.

**Advanced Topics**: Explore complementary technologies like service meshes (Istio, Linkerd), advanced monitoring (Prometheus, Grafana), and GitOps workflows (ArgoCD, Flux).

**Team Enablement**: Share your knowledge and implement these patterns as organizational standards, creating reusable templates and documentation for your teams.

**Continuous Learning**: Kubernetes evolves rapidly. Stay current with new features, security updates, and community best practices through official documentation and community resources.

### **🔥 Key Differentiators**

This guide has transformed you from a basic Kubernetes user into a deployment expert capable of:

- **Designing resilient applications** that self-heal and scale appropriately
- **Implementing zero-downtime deployments** using multiple proven strategies  
- **Building secure-by-default systems** that follow enterprise security standards
- **Creating comprehensive monitoring** that provides actionable insights
- **Automating complex workflows** that reduce human error and increase velocity
- **Troubleshooting production issues** systematically and efficiently

The combination of Deployments and ReplicaSets represents one of Kubernetes' greatest innovations: transforming complex application lifecycle management into simple, declarative specifications. You've now mastered these concepts and can build scalable, resilient applications that evolve with your business needs.

Your journey from foundation concepts to enterprise expertise demonstrates the power of hands-on learning. The mini-projects, workshops, and integrated platform you've built serve as both learning exercises and production-ready templates for real-world implementation.

**Congratulations on completing this comprehensive journey through Kubernetes Deployments and ReplicaSets!** You now possess the knowledge and practical skills to implement enterprise-grade deployment solutions that drive business success while maintaining the highest standards of reliability, security, and operational excellence.

        
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 30
```

**Hands-On Exercise**: Apply this deployment and explore its behavior:

```bash
#!/bin/bash
# lab3-deployment-exploration.sh

echo "🚀 Lab 3: Your First Production-Style Deployment"
echo "==============================================="

# Apply the deployment
kubectl apply -f lab3-first-deployment.yaml

echo "📋 Deployment created! Let's explore what happened..."

# Function to show status with nice formatting
show_status() {
    echo -e "\n📊 CURRENT STATUS:"
    echo "Deployment:"
    kubectl get deployment my-web-app
    echo -e "\nReplicaSet:"
    kubectl get replicasets -l app=my-web-app
    echo -e "\nPods:"
    kubectl get pods -l app=my-web-app -o wide
}

# Show initial status
show_status

# Wait for deployment to be ready
echo -e "\n⏳ Waiting for deployment to be ready..."
kubectl wait --for=condition=available deployment/my-web-app --timeout=120s

# Show final status
show_status

# Create a service to expose the deployment
echo -e "\n🌐 Creating a service to expose our application..."
kubectl expose deployment my-web-app --type=ClusterIP --port=80 --target-port=80

# Test the application
echo -e "\n🧪 Testing the application..."
echo "Service created. In a new terminal, you can test with:"
echo "kubectl port-forward service/my-web-app 8080:80"
echo "Then visit http://localhost:8080"

# Show rollout history
echo -e "\n📚 ROLLOUT HISTORY:"
kubectl rollout history deployment/my-web-app

echo -e "\n🎯 EXPLORATION EXERCISES:"
echo "1. Try: kubectl describe deployment my-web-app"
echo "2. Try: kubectl get events --sort-by=.metadata.creationTimestamp"
echo "3. Try: kubectl top pods -l app=my-web-app  # (if metrics server installed)"

echo -e "\n🧹 To cleanup later:"
echo "kubectl delete deployment,service my-web-app"
```

## Exploring Deployment Operations: The Art of Application Management

Now that you understand the basic hierarchy, let's explore how Deployments provide sophisticated application management capabilities through practical exercises.

### Lab 4: Scaling Strategies Workshop (Intermediate Level)

This lab teaches you different scaling approaches and when to use each one.

```bash
#!/bin/bash
# lab4-scaling-workshop.sh
# Comprehensive scaling strategies demonstration

echo "📈 Lab 4: Scaling Strategies Workshop"
echo "===================================="

# Setup: Create a deployment for scaling experiments
kubectl create deployment scaling-demo --image=nginx:1.20 --replicas=2
kubectl wait --for=condition=available deployment/scaling-demo --timeout=60s

echo "Initial deployment created with 2 replicas"
kubectl get deployment scaling-demo

# Workshop Section 1: Manual Scaling
echo -e "\n🎯 SECTION 1: Manual Scaling Techniques"
echo "======================================="

# Technique 1: Imperative scaling
echo -e "\n📊 Technique 1: Imperative Scaling (kubectl scale)"
echo "Current replica count:"
kubectl get deployment scaling-demo -o jsonpath='{.spec.replicas}'

echo -e "\nScaling up to 5 replicas..."
kubectl scale deployment scaling-demo --replicas=5

# Monitor the scaling process
echo "Watching pods scale up (15 seconds)..."
timeout 15s kubectl get pods -l app=scaling-demo -w || true

echo -e "\nFinal state:"
kubectl get deployment scaling-demo

# Technique 2: Declarative scaling
echo -e "\n📊 Technique 2: Declarative Scaling (kubectl patch)"
echo "Using patch to scale down to 3 replicas..."
kubectl patch deployment scaling-demo -p '{"spec":{"replicas":3}}'

# Show the change
sleep 5
kubectl get deployment scaling-demo

# Workshop Section 2: Conditional Scaling
echo -e "\n🎯 SECTION 2: Conditional and Smart Scaling"
echo "=========================================="

# Smart scaling function
scale_with_check() {
    local target_replicas=$1
    local max_replicas=$2
    
    if [ $target_replicas -gt $max_replicas ]; then
        echo "⚠️  Requested $target_replicas replicas exceeds maximum $max_replicas"
        echo "Scaling to maximum instead..."
        target_replicas=$max_replicas
    fi
    
    echo "Scaling to $target_replicas replicas..."
    kubectl scale deployment scaling-demo --replicas=$target_replicas
}

# Demo conditional scaling
scale_with_check 8 6
sleep 3
kubectl get deployment scaling-demo

# Workshop Section 3: Resource-Aware Scaling
echo -e "\n🎯 SECTION 3: Resource-Aware Scaling Simulation"
echo "=============================================="

# Simulate checking node resources before scaling
echo "Checking node capacity..."
echo "Available nodes:"
kubectl get nodes -o custom-columns=NAME:.metadata.name,CAPACITY-CPU:.status.capacity.cpu,CAPACITY-MEM:.status.capacity.memory

echo -e "\n💡 In production, you would check:"
echo "- Available CPU and memory on nodes"
echo "- Current resource usage"
echo "- Pod resource requirements"
echo "- Cluster autoscaling limits"

# Workshop Section 4: Scaling Patterns
echo -e "\n🎯 SECTION 4: Common Scaling Patterns"
echo "===================================="

# Pattern 1: Scale to zero (maintenance mode)
echo -e "\n📊 Pattern 1: Maintenance Mode (Scale to 0)"
kubectl scale deployment scaling-demo --replicas=0
echo "Application scaled to 0 - maintenance mode activated"
sleep 3
kubectl get pods -l app=scaling-demo

# Pattern 2: Rapid scale-up from zero
echo -e "\n📊 Pattern 2: Rapid Recovery"
kubectl scale deployment scaling-demo --replicas=4
echo "Rapidly scaling back up to 4 replicas..."
sleep 10
kubectl get deployment scaling-demo

# Interactive challenge
echo -e "\n🏆 CHALLENGE: Try these scaling scenarios"
echo "1. Scale to exactly match the number of worker nodes in your cluster"
echo "2. Scale to 1, then immediately to 10, and observe the rollout"
echo "3. Scale to 0, wait 30 seconds, then scale to 3"

echo -e "\n🧹 Cleanup:"
echo "kubectl delete deployment scaling-demo"
```

### Lab 5: Rolling Updates Masterclass (Intermediate Level)

This comprehensive lab teaches you everything about rolling updates, from basic updates to advanced strategies.

```bash
#!/bin/bash
# lab5-rolling-updates-masterclass.sh
# Complete rolling updates workshop with multiple scenarios

echo "🔄 Lab 5: Rolling Updates Masterclass"
echo "===================================="

# Setup: Create deployment with specific configuration for update demos
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: update-demo
  annotations:
    kubernetes.io/change-cause: "Initial version - nginx:1.19"
spec:
  replicas: 6
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 2
  selector:
    matchLabels:
      app: update-demo
  template:
    metadata:
      labels:
        app: update-demo
    spec:
      containers:
      - name: nginx
        image: nginx:1.19
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
EOF

echo "Deployment created with nginx:1.19"
kubectl wait --for=condition=available deployment/update-demo --timeout=60s

# Show initial state
echo -e "\n📊 INITIAL STATE:"
kubectl get deployment update-demo
kubectl get pods -l app=update-demo -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase

# Masterclass Section 1: Basic Rolling Update
echo -e "\n🎯 SECTION 1: Basic Rolling Update"
echo "================================="

echo "Starting update to nginx:1.20..."
kubectl set image deployment/update-demo nginx=nginx:1.20
kubectl annotate deployment/update-demo kubernetes.io/change-cause="Updated to nginx:1.20"

# Monitor the rollout in real-time
echo -e "\n🔍 Monitoring rollout progress..."
kubectl rollout status deployment/update-demo

echo -e "\n📊 ROLLOUT COMPLETED:"
kubectl get deployment update-demo
kubectl get replicasets -l app=update-demo

# Masterclass Section 2: Rollout History and Rollbacks
echo -e "\n🎯 SECTION 2: Rollout History Management"
echo "======================================"

# Show rollout history
echo "Rollout history:"
kubectl rollout history deployment/update-demo

# Perform another update to create more history
echo -e "\nPerforming update to nginx:1.21..."
kubectl set image deployment/update-demo nginx=nginx:1.21
kubectl annotate deployment/update-demo kubernetes.io/change-cause="Updated to nginx:1.21 - latest stable"
kubectl rollout status deployment/update-demo

# Show updated history
echo -e "\nUpdated rollout history:"
kubectl rollout history deployment/update-demo

# Demonstrate rollback
echo -e "\n🔄 ROLLBACK DEMONSTRATION:"
echo "Rolling back to previous version..."
kubectl rollout undo deployment/update-demo
kubectl rollout status deployment/update-demo

# Masterclass Section 3: Advanced Update Strategies
echo -e "\n🎯 SECTION 3: Advanced Update Strategies"
echo "======================================"

# Strategy 1: Controlled rollout with pause
echo -e "\n📊 Strategy 1: Controlled Rollout with Pause"
kubectl set image deployment/update-demo nginx=nginx:1.22
kubectl annotate deployment/update-demo kubernetes.io/change-cause="Controlled update to nginx:1.22"

# Pause the rollout immediately
kubectl rollout pause deployment/update-demo
echo "Rollout paused. Checking partial deployment..."

sleep 5
kubectl get pods -l app=update-demo -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase

echo -e "\n🔬 Simulate testing the new version..."
echo "In production, you would:"
echo "- Run smoke tests against new pods"
echo "- Check metrics and logs"
echo "- Validate performance"

echo -e "\nResuming rollout after validation..."
kubectl rollout resume deployment/update-demo
kubectl rollout status deployment/update-demo

# Masterclass Section 4: Update Strategy Comparison
echo -e "\n🎯 SECTION 4: Update Strategy Comparison"
echo "====================================="

# Create different deployments with different strategies
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: recreate-demo
spec:
  replicas: 3
  strategy:
    type: Recreate  # All pods killed before new ones created
  selector:
    matchLabels:
      app: recreate-demo
  template:
    metadata:
      labels:
        app: recreate-demo
    spec:
      containers:
      - name: nginx
        image: nginx:1.19
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aggressive-rolling
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 100%  # Very aggressive rolling update
  selector:
    matchLabels:
      app: aggressive-rolling
  template:
    metadata:
      labels:
        app: aggressive-rolling
    spec:
      containers:
      - name: nginx
        image: nginx:1.19
EOF

echo "Created deployments with different update strategies"

# Demonstrate the differences
echo -e "\n📊 STRATEGY COMPARISON:"
echo "1. Recreate Strategy - All pods replaced at once"
echo "2. Rolling Update (Conservative) - Max 1 unavailable, 2 surge"
echo "3. Rolling Update (Aggressive) - 0 unavailable, 100% surge"

echo -e "\n🎯 INTERACTIVE EXERCISES:"
echo "Try updating each deployment and observe the differences:"
echo "kubectl set image deployment/recreate-demo nginx=nginx:1.20"
echo "kubectl set image deployment/aggressive-rolling nginx=nginx:1.20"
echo "kubectl set image deployment/update-demo nginx=nginx:1.20"

echo -e "\n🧹 Cleanup:"
echo "kubectl delete deployment update-demo recreate-demo aggressive-rolling"
```

### Lab 6: Troubleshooting Workshop (Intermediate Level)

Real-world deployments face various issues. This lab simulates common problems and teaches systematic troubleshooting.

```bash
#!/bin/bash
# lab6-troubleshooting-workshop.sh
# Systematic approach to deployment troubleshooting

echo "🔧 Lab 6: Deployment Troubleshooting Workshop"
echo "============================================="

echo "This workshop will create problematic deployments and guide you through troubleshooting"

# Problem Scenario 1: Image Pull Errors
echo -e "\n🚨 SCENARIO 1: Image Pull Failures"
echo "=================================="

kubectl create deployment image-problem --image=nginx:nonexistent-tag --replicas=2
echo "Created deployment with invalid image tag"

sleep 10

echo -e "\n🔍 DIAGNOSTIC STEPS:"
echo "1. Check deployment status:"
kubectl get deployment image-problem

echo -e "\n2. Check ReplicaSet status:"
kubectl get replicasets -l app=image-problem

echo -e "\n3. Check pod status:"
kubectl get pods -l app=image-problem

echo -e "\n4. Describe problematic pod for detailed error:"
POD_NAME=$(kubectl get pods -l app=image-problem -o jsonpath='{.items[0].metadata.name}')
kubectl describe pod $POD_NAME | grep -A 5 -B 5 "Failed\|Error\|Warning"

echo -e "\n💡 SOLUTION:"
echo "Fix the image tag:"
echo "kubectl set image deployment/image-problem nginx=nginx:1.20"

# Problem Scenario 2: Resource Constraints
echo -e "\n🚨 SCENARIO 2: Resource Constraints"
echo "==================================="

cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-problem
spec:
  replicas: 3
  selector:
    matchLabels:
      app: resource-problem
  template:
    metadata:
      labels:
        app: resource-problem
    spec:
      containers:
      - name: nginx
        image: nginx:1.20
        resources:
          requests:
            memory: "16Gi"  # Deliberately excessive
            cpu: "8000m"
EOF

echo "Created deployment with excessive resource requests"
sleep 15

echo -e "\n🔍 DIAGNOSTIC STEPS:"
echo "1. Check pod status:"
kubectl get pods -l app=resource-problem

echo -e "\n2. Describe pending pod:"
PENDING_POD=$(kubectl get pods -l app=resource-problem -o jsonpath='{.items[0].metadata.name}')
kubectl describe pod $PENDING_POD | grep -A 10 "Events:"

echo -e "\n3. Check node resources:"
kubectl describe nodes | grep -E "Allocatable|Allocated resources"

# Problem Scenario 3: Configuration Errors
echo -e "\n🚨 SCENARIO 3: Configuration Errors"
echo "==================================="

cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: config-problem
spec:
  replicas: 2
  selector:
    matchLabels:
      app: config-problem
  template:
    metadata:
      labels:
        app: config-problem
    spec:
      containers:
      - name: nginx
        image: nginx:1.20
        env:
        - name: INVALID_CONFIG
          valueFrom:
            configMapKeyRef:
              name: nonexistent-config
              key: some-key
EOF

echo "Created deployment with invalid ConfigMap reference"
sleep 10

echo -e "\n🔍 DIAGNOSTIC STEPS:"
echo "1. Check pod status:"
kubectl get pods -l app=config-problem

echo -e "\n2. Describe pod for configuration errors:"
CONFIG_POD=$(kubectl get pods -l app=config-problem -o jsonpath='{.items[0].metadata.name}')
kubectl describe pod $CONFIG_POD | grep -A 5 -B 5 "ConfigMap"

# Troubleshooting Toolkit
echo -e "\n🛠️  TROUBLESHOOTING TOOLKIT"
echo "=========================="

cat << 'EOF' > troubleshooting-toolkit.sh
#!/bin/bash
# Troubleshooting toolkit for Kubernetes deployments

deployment_health_check() {
    local deployment_name=$1
    
    echo "🏥 HEALTH CHECK FOR DEPLOYMENT: $deployment_name"
    echo "============================================="
    
    # Basic status
    echo "📊 Deployment Status:"
    kubectl get deployment $deployment_name -o wide
    
    # ReplicaSet status
    echo -e "\n📊 ReplicaSet Status:"
    kubectl get replicasets -l app=$deployment_name -o wide
    
    # Pod status
    echo -e "\n📊 Pod Status:"
    kubectl get pods -l app=$deployment_name -o wide
    
    # Recent events
    echo -e "\n📋 Recent Events:"
    kubectl get events --sort-by=.metadata.creationTimestamp --field-selector involvedObject.name=$deployment_name
    
    # Check for common issues
    echo -e "\n🔍 Common Issue Checks:"
    
    # Check for pending pods
    PENDING_PODS=$(kubectl get pods -l app=$deployment_name --field-selector=status.phase=Pending -o name | wc -l)
    if [ $PENDING_PODS -gt 0 ]; then
        echo "⚠️  Found $PENDING_PODS pending pods"
        kubectl get pods -l app=$deployment_name --field-selector=status.phase=Pending
    fi
    
    # Check for failed pods
    FAILED_PODS=$(kubectl get pods -l app=$deployment_name --field-selector=status.phase=Failed -o name | wc -l)
    if [ $FAILED_PODS -gt 0 ]; then
        echo "❌ Found $FAILED_PODS failed pods"
        kubectl get pods -l app=$deployment_name --field-selector=status.phase=Failed
    fi
    
    # Check for image pull errors
    IMAGE_ERRORS=$(kubectl describe pods -l app=$deployment_name | grep -c "Failed to pull image\|ErrImagePull\|ImagePullBackOff")
    if [ $IMAGE_ERRORS -gt 0 ]; then
        echo "🖼️  Image pull errors detected"
    fi
    
    echo -e "\n✅ Health check complete"
}

# Make the function available
export -f deployment_health_check
EOF

chmod +x troubleshooting-toolkit.sh
echo "Created troubleshooting toolkit: troubleshooting-toolkit.sh"

echo -e "\n🎯 PRACTICE EXERCISES:"
echo "1. Use the toolkit on the problematic deployments:"
echo "   source troubleshooting-toolkit.sh"
echo "   deployment_health_check image-problem"
echo "   deployment_health_check resource-problem"
echo "   deployment_health_check config-problem"

echo -e "\n2. Fix each deployment and verify the fixes work"

echo -e "\n🧹 Cleanup:"
echo "kubectl delete deployment image-problem resource-problem config-problem"
echo "rm troubleshooting-toolkit.sh"
```

## Advanced Deployment Patterns and Strategies

Now that you understand the fundamentals, let's explore sophisticated deployment patterns that leverage the Deployment and ReplicaSet architecture through practical mini-projects.

### Mini-Project 1: Blue-Green Deployment System (Advanced Level)

This project builds a complete blue-green deployment system with automated traffic switching and rollback capabilities.

```bash
#!/bin/bash
# mini-project-1-blue-green-system.sh
# Complete blue-green deployment system implementation

echo "🔵🟢 Mini-Project 1: Blue-Green Deployment System"
echo "================================================"

# Project setup
PROJECT_NAME="blue-green-system"
mkdir -p $PROJECT_NAME
cd $PROJECT_NAME

# Create the blue-green deployment manager
cat << 'EOF' > blue-green-manager.sh
#!/bin/bash
# Blue-Green Deployment Manager
# Provides complete blue-green deployment functionality

NAMESPACE=${NAMESPACE:-default}
APP_NAME=${APP_NAME:-demo-app}

show_help() {
    echo "Blue-Green Deployment Manager"
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  init <image>           Initialize blue environment"
    echo "  deploy <image>         Deploy to green environment"
    echo "  switch                 Switch traffic from blue to green"
    echo "  rollback               Rollback traffic to blue"
    echo "  status                 Show current status"
    echo "  cleanup                Remove inactive environment"
    echo "  destroy                Remove entire setup"
    echo ""
    echo "Environment Variables:"
    echo "  APP_NAME (default: demo-app)"
    echo "  NAMESPACE (default: default)"
}

get_active_env() {
    kubectl get service $APP_NAME-service -o jsonpath='{.spec.selector.version}' 2>/dev/null || echo "none"
}

get_inactive_env() {
    local active=$(get_active_env)
    if [ "$active" = "blue" ]; then
        echo "green"
    elif [ "$active" = "green" ]; then
        echo "blue"
    else
        echo "blue"  # Default to blue for initial setup
    fi
}

init_environment() {
    local image=$1
    local env="blue"
    
    echo "🔵 Initializing blue environment with image: $image"
    
    # Create blue deployment
    cat << YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $APP_NAME-$env
  labels:
    app: $APP_NAME
    version: $env
spec:
  replicas: 3
  selector:
    matchLabels:
      app: $APP_NAME
      version: $env
  template:
    metadata:
      labels:
        app: $APP_NAME
        version: $env
    spec:
      containers:
      - name: app
        image: $image
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /