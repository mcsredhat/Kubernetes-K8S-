# Enhanced kubectl Commands Guide - From Beginner to Power User

Mastering kubectl is like learning to speak Kubernetes fluently. While you could memorize individual commands, true proficiency comes from understanding the patterns, logic, and philosophy behind how kubectl works. This guide will transform you from someone who looks up every command to someone who can intuitively construct the right kubectl command for any situation.

## Understanding kubectl's Mental Model

Before diving into specific commands, it's crucial to understand how kubectl thinks about the world. Every kubectl command follows a consistent pattern that mirrors how you naturally think about managing resources. Once you internalize this pattern, you'll find that even commands you've never seen before become predictable and logical.

The fundamental structure follows this format: `kubectl <verb> <resource-type> <resource-name> [options]`. This mirrors natural language - you tell kubectl what action to take, on what type of thing, specifically which one, and how you want it done. For example, "kubectl get pods my-app" translates to "show me the pod named my-app," while "kubectl delete service web-server" means "remove the service called web-server."

### Foundation Examples: Learning the Pattern

Let's start with the most basic examples to internalize the command structure:

```bash
# Pattern: kubectl <verb> <resource-type>
kubectl get pods                    # "Show me all pods"
kubectl get services               # "Show me all services"
kubectl get deployments           # "Show me all deployments"
kubectl get nodes                 # "Show me all nodes"

# Pattern: kubectl <verb> <resource-type> <name>
kubectl get pod nginx-pod          # "Show me the specific pod named nginx-pod"
kubectl describe service my-web   # "Give me details about the service named my-web"
kubectl delete deployment old-app # "Remove the deployment named old-app"

# Pattern: kubectl <verb> <resource-type> <name> [options]
kubectl get pod nginx-pod -o yaml         # "Show me nginx-pod in YAML format"
kubectl logs nginx-pod --follow           # "Show me nginx-pod logs and keep following"
kubectl delete deployment old-app --cascade=false # "Delete old-app but keep its pods"
```

### Demo 1: Your First kubectl Interaction

Let's create a complete demonstration that shows the pattern in action:

```bash
# Step 1: Check where you are (context awareness)
kubectl config current-context
# Output: Shows your current cluster context

# Step 2: See what's available (resource discovery)
kubectl get all
# This shows all common resources in your current namespace
# Notice the different resource types: pods, services, deployments, etc.

# Step 3: Create your first resource (imperative creation)
kubectl create deployment hello-world --image=nginx:1.21
# Creates a deployment named 'hello-world' using nginx image

# Step 4: Observe what happened (resource inspection)
kubectl get deployments
# Shows your new deployment
kubectl get pods
# Shows the pod(s) created by your deployment
kubectl get replicasets
# Shows the ReplicaSet managing your pods

# Step 5: Access your application (service creation)
kubectl expose deployment hello-world --port=80 --type=NodePort
# Creates a service to access your deployment

# Step 6: See the complete picture
kubectl get all
# Now you see deployments, pods, services, and replicasets working together
```

## Setting Up Your kubectl Environment for Success

Your kubectl environment setup determines whether working with Kubernetes feels smooth and intuitive or frustrating and error-prone. The difference between a well-configured and poorly-configured kubectl setup can mean the difference between confidently managing clusters and constantly fighting with typos and forgotten syntax.

### Foundation Setup Examples

```bash
# Enable bash completion - this single command will dramatically improve your kubectl experience
source <(kubectl completion bash)
echo "source <(kubectl completion bash)" >> ~/.bashrc

# For zsh users
source <(kubectl completion zsh)
echo "source <(kubectl completion zsh)" >> ~/.zshrc

# Create useful aliases that save time and reduce typing
echo 'alias k=kubectl' >> ~/.bashrc
echo 'alias kgp="kubectl get pods"' >> ~/.bashrc
echo 'alias kgs="kubectl get services"' >> ~/.bashrc
echo 'alias kgd="kubectl get deployments"' >> ~/.bashrc
echo 'alias kdp="kubectl describe pod"' >> ~/.bashrc
echo 'alias kl="kubectl logs"' >> ~/.bashrc

# Source your bashrc to use aliases immediately
source ~/.bashrc
```

### Environment Verification Demo

```bash
# Comprehensive environment check sequence
echo "=== kubectl Environment Verification ==="

# 1. Check kubectl version and cluster connectivity
echo "1. kubectl and Cluster Versions:"
kubectl version --short 2>/dev/null || echo "❌ Cluster connection failed"

# 2. Show current context and available contexts
echo -e "\n2. Current Context:"
kubectl config current-context

echo -e "\n3. Available Contexts:"
kubectl config get-contexts

# 4. Check cluster health
echo -e "\n4. Cluster Health:"
kubectl cluster-info

# 5. Verify node status
echo -e "\n5. Node Status:"
kubectl get nodes

# 6. Check current namespace
echo -e "\n6. Current Namespace:"
kubectl config view --minify --output 'jsonpath={..namespace}'; echo

# 7. Test basic operations
echo -e "\n7. Basic Operation Test:"
kubectl get namespaces > /dev/null && echo "✅ Basic operations working" || echo "❌ Basic operations failed"

echo -e "\n=== Environment Check Complete ==="
```

### Advanced Environment Configuration

```bash
# Create a comprehensive kubectl configuration script
cat > ~/setup-kubectl-env.sh << 'EOF'
#!/bin/bash

# kubectl Environment Setup Script

echo "Setting up enhanced kubectl environment..."

# 1. Enable completion for kubectl
if command -v kubectl > /dev/null; then
    source <(kubectl completion bash)
    echo "source <(kubectl completion bash)" >> ~/.bashrc
    echo "✅ kubectl completion enabled"
fi

# 2. Create comprehensive aliases
cat >> ~/.bashrc << 'ALIASES'
# kubectl aliases
alias k='kubectl'
alias kaf='kubectl apply -f'
alias kdel='kubectl delete'
alias kdes='kubectl describe'
alias ked='kubectl edit'
alias kex='kubectl exec -it'
alias klo='kubectl logs'
alias klof='kubectl logs -f'
alias kp='kubectl proxy'
alias kpf='kubectl port-forward'

# Get commands
alias kga='kubectl get all'
alias kgp='kubectl get pods'
alias kgd='kubectl get deployments'
alias kgs='kubectl get services'
alias kgn='kubectl get nodes'
alias kgns='kubectl get namespaces'

# Describe commands
alias kdp='kubectl describe pod'
alias kdd='kubectl describe deployment'
alias kdsvc='kubectl describe service'
alias kdn='kubectl describe node'

# Logs and exec
alias kl='kubectl logs'
alias klf='kubectl logs -f'
alias ke='kubectl exec -it'

# Namespace operations
alias kn='kubectl config set-context --current --namespace'
alias kgcn='kubectl config view --minify --output "jsonpath={..namespace}"'
ALIASES

# 3. Create useful functions
cat >> ~/.bashrc << 'FUNCTIONS'
# kubectl utility functions

# Quick pod shell access
ksh() {
    kubectl exec -it $1 -- /bin/bash
}

# Quick context switching
kctx() {
    if [ -z "$1" ]; then
        kubectl config get-contexts
    else
        kubectl config use-context $1
    fi
}

# Quick namespace switching
kns() {
    if [ -z "$1" ]; then
        kubectl get namespaces
    else
        kubectl config set-context --current --namespace=$1
    fi
}

# Get pod by partial name
kgpn() {
    kubectl get pods | grep $1
}

# Port forward with common ports
kpf8080() {
    kubectl port-forward $1 8080:8080
}

kpf3000() {
    kubectl port-forward $1 3000:3000
}
FUNCTIONS

# 4. Set up kubectl plugins directory
mkdir -p ~/.local/bin/kubectl-plugins
export PATH="${HOME}/.local/bin/kubectl-plugins:$PATH"
echo 'export PATH="${HOME}/.local/bin/kubectl-plugins:$PATH"' >> ~/.bashrc

echo "✅ kubectl environment setup complete!"
echo "Please run: source ~/.bashrc"
EOF

chmod +x ~/setup-kubectl-env.sh
~/setup-kubectl-env.sh
```

## Mastering kubectl's Help System - Your Path to Self-Sufficiency

The true power of kubectl lies not in memorizing every command, but in understanding how to discover and explore its capabilities.

### Foundation Help Examples

```bash
# Start with basic help exploration
kubectl --help | head -20                    # Get overview without overwhelming output
kubectl get --help | head -30               # Understand get command basics
kubectl create --help | grep "Available Commands" -A 10  # See what you can create

# Practice help navigation for common scenarios
kubectl create deployment --help | less     # Learn deployment creation options
kubectl expose --help | less               # Understand service creation
kubectl logs --help | less                 # Master log viewing options
```

### Demo 2: Interactive Help Exploration

Let's create an interactive session that teaches help system navigation:

```bash
#!/bin/bash
# kubectl Help System Explorer

echo "=== kubectl Help System Interactive Demo ==="
echo

echo "1. Let's start with the overall kubectl structure:"
echo "Command: kubectl --help | head -20"
kubectl --help | head -20
echo
read -p "Press Enter to continue..."

echo "2. Now let's explore the 'get' command in detail:"
echo "Command: kubectl get --help | head -30"
kubectl get --help | head -30
echo
read -p "Press Enter to continue..."

echo "3. Let's see what resources we can 'get':"
echo "Command: kubectl api-resources --output=name | head -10"
kubectl api-resources --output=name | head -10
echo
read -p "Press Enter to continue..."

echo "4. Let's explore creating resources:"
echo "Command: kubectl create --help | grep 'Available Commands' -A 15"
kubectl create --help | grep "Available Commands" -A 15
echo
read -p "Press Enter to continue..."

echo "5. Let's dive into deployment creation:"
echo "Command: kubectl create deployment --help | head -20"
kubectl create deployment --help | head -20
echo

echo "🎉 Help system exploration complete!"
echo "Practice: Try 'kubectl explain pod' to understand pod structure"
```

### Advanced Help System Patterns

```bash
# Create a help discovery script
cat > ~/kubectl-help-explorer.sh << 'EOF'
#!/bin/bash

# kubectl Help Explorer - Advanced patterns

help_command() {
    local cmd="$1"
    echo "=== Help for: $cmd ==="
    eval "$cmd --help" | head -30
    echo
}

explain_resource() {
    local resource="$1"
    echo "=== Explaining: $resource ==="
    kubectl explain $resource | head -20
    echo
}

# Interactive help exploration
echo "kubectl Help Explorer"
echo "====================="

# Menu system
while true; do
    echo
    echo "Choose an option:"
    echo "1) Explore basic commands"
    echo "2) Understand resource types"
    echo "3) Learn about specific resource"
    echo "4) Exit"
    echo
    read -p "Enter choice (1-4): " choice

    case $choice in
        1)
            echo "Basic Commands Help:"
            for cmd in "kubectl get" "kubectl create" "kubectl delete" "kubectl describe"; do
                help_command "$cmd"
            done
            ;;
        2)
            echo "Available Resource Types:"
            kubectl api-resources --output=wide | head -20
            ;;
        3)
            read -p "Enter resource type to explain: " resource
            explain_resource "$resource"
            ;;
        4)
            echo "Happy kubectling!"
            break
            ;;
        *)
            echo "Invalid choice. Please try again."
            ;;
    esac
done
EOF

chmod +x ~/kubectl-help-explorer.sh
```

## Discovering and Understanding Kubernetes Resources

One of kubectl's most powerful features is its ability to teach you about Kubernetes itself.

### Foundation Resource Discovery

```bash
# Basic resource discovery sequence
echo "=== Resource Discovery Demo ==="

# 1. See all available resource types
echo "1. All resource types:"
kubectl api-resources | head -10

# 2. Focus on common resources
echo -e "\n2. Common namespaced resources:"
kubectl api-resources --namespaced=true | grep -E "(pods|services|deployments|configmaps|secrets)"

# 3. See cluster-wide resources
echo -e "\n3. Cluster-wide resources:"
kubectl api-resources --namespaced=false | head -10

# 4. Understand resource shortcuts
echo -e "\n4. Useful resource shortcuts:"
echo "po = pods"
echo "svc = services"
echo "deploy = deployments"
echo "cm = configmaps"
echo "ns = namespaces"
```

### Demo 3: Resource Explanation Workshop

```bash
# Interactive resource explanation demo
cat > ~/resource-explorer.sh << 'EOF'
#!/bin/bash

echo "=== Kubernetes Resource Explorer ==="

# Function to explain a resource with examples
explain_with_examples() {
    local resource=$1
    echo "=========================================="
    echo "Exploring: $resource"
    echo "=========================================="
    
    echo -e "\n📚 Resource Definition:"
    kubectl explain $resource | head -10
    
    echo -e "\n🔍 Resource Structure:"
    kubectl explain $resource.spec 2>/dev/null | head -8 || echo "No spec available"
    
    echo -e "\n📋 Examples in cluster:"
    kubectl get $resource 2>/dev/null | head -5 || echo "No $resource found"
    
    echo -e "\n" && read -p "Press Enter to continue..."
}

# Explore common resources
resources=("pod" "service" "deployment" "configmap" "secret" "namespace")

for resource in "${resources[@]}"; do
    explain_with_examples $resource
done

echo "🎉 Resource exploration complete!"
EOF

chmod +x ~/resource-explorer.sh
```

### Advanced Resource Discovery Patterns

```bash
# Advanced resource discovery and analysis
cat > ~/advanced-resource-discovery.sh << 'EOF'
#!/bin/bash

echo "=== Advanced Resource Discovery ==="

# 1. Group resources by API version
echo "1. Resources by API Group:"
kubectl api-resources --output=wide | awk 'NR>1 {print $3}' | sort | uniq -c | sort -nr

echo -e "\n2. Core vs Extension Resources:"
echo "Core resources (no API group):"
kubectl api-resources | awk '$3==""' | head -10

echo -e "\nExtension resources (with API groups):"
kubectl api-resources | awk '$3!="" && NR>1' | head -10

# 3. Analyze resource capabilities
echo -e "\n3. Resource Capabilities Analysis:"
echo "Namespaced resources: $(kubectl api-resources --namespaced=true | wc -l)"
echo "Cluster-wide resources: $(kubectl api-resources --namespaced=false | wc -l)"

# 4. Find resources with specific verbs
echo -e "\n4. Resources supporting different operations:"
echo "Resources you can 'create':"
kubectl api-resources --verbs=create | head -5

echo -e "\nResources you can 'patch':"
kubectl api-resources --verbs=patch | head -5

# 5. Custom resources detection
echo -e "\n5. Custom Resource Detection:"
custom_resources=$(kubectl api-resources | grep -v "^NAME" | awk '$3 ~ /\./ && $3 !~ /(k8s\.io|kubernetes\.io)/')
if [ -n "$custom_resources" ]; then
    echo "Custom resources found:"
    echo "$custom_resources"
else
    echo "No custom resources detected"
fi
EOF

chmod +x ~/advanced-resource-discovery.sh
```

## Essential Information Retrieval Patterns

Retrieving information effectively with kubectl requires understanding the various ways to filter, format, and focus the output.

### Foundation Information Retrieval

```bash
# Basic information patterns every user should know
echo "=== Foundation Information Retrieval ==="

# 1. Basic listing
kubectl get pods
kubectl get services
kubectl get deployments

# 2. Wide output for more details
kubectl get pods -o wide
kubectl get nodes -o wide

# 3. Multiple resource types at once
kubectl get pods,services,deployments

# 4. All resources overview
kubectl get all

# 5. Cross-namespace visibility
kubectl get pods --all-namespaces
kubectl get pods -A  # Short form
```

### Demo 4: Information Retrieval Workshop

```bash
# Comprehensive information retrieval demo
cat > ~/info-retrieval-demo.sh << 'EOF'
#!/bin/bash

echo "=== kubectl Information Retrieval Workshop ==="

# Setup: Create some sample resources for demonstration
setup_demo_resources() {
    echo "Setting up demo resources..."
    kubectl create deployment demo-app --image=nginx:1.21
    kubectl create deployment demo-db --image=postgres:13
    kubectl scale deployment demo-app --replicas=3
    kubectl expose deployment demo-app --port=80
    kubectl create configmap demo-config --from-literal=key=value
    echo "✅ Demo resources created"
}

# Demo 1: Basic retrieval patterns
demo_basic_retrieval() {
    echo -e "\n=== Demo 1: Basic Retrieval Patterns ==="
    
    echo "1. List all pods:"
    kubectl get pods
    
    echo -e "\n2. List with more details:"
    kubectl get pods -o wide
    
    echo -e "\n3. Multiple resource types:"
    kubectl get pods,services,deployments
    
    echo -e "\n4. Everything at once:"
    kubectl get all
    
    read -p "Press Enter to continue..."
}

# Demo 2: Output formatting
demo_output_formatting() {
    echo -e "\n=== Demo 2: Output Formatting ==="
    
    echo "1. YAML output (first pod):"
    pod_name=$(kubectl get pods -o jsonpath='{.items[0].metadata.name}')
    kubectl get pod $pod_name -o yaml | head -20
    
    echo -e "\n2. JSON output (summary):"
    kubectl get pods -o json | jq '.items | length' 2>/dev/null || echo "jq not available"
    
    echo -e "\n3. Custom columns:"
    kubectl get pods -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName
    
    echo -e "\n4. JSONPath queries:"
    kubectl get pods -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n'
    
    read -p "Press Enter to continue..."
}

# Demo 3: Filtering and selection
demo_filtering() {
    echo -e "\n=== Demo 3: Filtering and Selection ==="
    
    echo "1. Label-based filtering:"
    kubectl get pods -l app=demo-app
    
    echo -e "\n2. Field-based filtering:"
    kubectl get pods --field-selector=status.phase=Running
    
    echo -e "\n3. Resource-specific queries:"
    kubectl get pods --field-selector=spec.nodeName!=''
    
    echo -e "\n4. Combining filters:"
    kubectl get pods -l app=demo-app --field-selector=status.phase=Running
    
    read -p "Press Enter to continue..."
}

# Demo 4: Advanced patterns
demo_advanced_patterns() {
    echo -e "\n=== Demo 4: Advanced Patterns ==="
    
    echo "1. Sort by creation time:"
    kubectl get pods --sort-by=.metadata.creationTimestamp
    
    echo -e "\n2. Resource usage overview:"
    kubectl top pods 2>/dev/null || echo "Metrics server not available"
    
    echo -e "\n3. Watch mode (showing for 5 seconds):"
    timeout 5s kubectl get pods --watch || true
    
    echo -e "\n4. Export resources (without cluster-specific info):"
    kubectl get deployment demo-app -o yaml --export 2>/dev/null | head -10 || \
    kubectl get deployment demo-app -o yaml | head -10
    
    read -p "Press Enter to continue..."
}

# Cleanup
cleanup_demo() {
    echo -e "\n=== Cleaning up demo resources ==="
    kubectl delete deployment demo-app demo-db
    kubectl delete service demo-app
    kubectl delete configmap demo-config
    echo "✅ Cleanup complete"
}

# Run the complete demo
echo "Starting Information Retrieval Workshop..."
read -p "Create demo resources? (y/n): " create_resources

if [[ $create_resources =~ ^[Yy] ]]; then
    setup_demo_resources
fi

demo_basic_retrieval
demo_output_formatting
demo_filtering
demo_advanced_patterns

read -p "Clean up demo resources? (y/n): " cleanup
if [[ $cleanup =~ ^[Yy] ]]; then
    cleanup_demo
fi

echo "🎉 Information Retrieval Workshop Complete!"
EOF

chmod +x ~/info-retrieval-demo.sh
```

### Advanced Information Patterns

```bash
# Advanced information retrieval patterns
cat > ~/advanced-info-patterns.sh << 'EOF'
#!/bin/bash

echo "=== Advanced kubectl Information Patterns ==="

# Pattern 1: Resource relationship mapping
map_resource_relationships() {
    echo "1. Resource Relationship Mapping:"
    
    # Get deployments and their related resources
    for deployment in $(kubectl get deployments -o jsonpath='{.items[*].metadata.name}'); do
        echo "Deployment: $deployment"
        
        # Find related ReplicaSets
        kubectl get replicasets -l app=$deployment -o jsonpath='{.items[*].metadata.name}' | \
        tr ' ' '\n' | sed 's/^/  ReplicaSet: /'
        
        # Find related Pods
        kubectl get pods -l app=$deployment -o jsonpath='{.items[*].metadata.name}' | \
        tr ' ' '\n' | sed 's/^/    Pod: /'
        
        # Find related Services
        kubectl get services -l app=$deployment -o jsonpath='{.items[*].metadata.name}' | \
        tr ' ' '\n' | sed 's/^/  Service: /'
        
        echo
    done
}

# Pattern 2: Resource health analysis
analyze_resource_health() {
    echo "2. Resource Health Analysis:"
    
    echo "Deployment Health:"
    kubectl get deployments -o custom-columns=\
NAME:.metadata.name,\
DESIRED:.spec.replicas,\
CURRENT:.status.replicas,\
READY:.status.readyReplicas,\
UPDATED:.status.updatedReplicas,\
AVAILABLE:.status.availableReplicas

    echo -e "\nPod Health Summary:"
    kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}' | \
    sort | uniq -c

    echo -e "\nNode Resource Usage:"
    kubectl top nodes 2>/dev/null || echo "Metrics server not available"
}

# Pattern 3: Configuration analysis
analyze_configurations() {
    echo "3. Configuration Analysis:"
    
    echo "Image versions in use:"
    kubectl get pods -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.image}{"\n"}{end}{end}' | \
    sort | uniq -c
    
    echo -e "\nResource limits and requests:"
    kubectl get pods -o custom-columns=\
POD:.metadata.name,\
LIMITS:.spec.containers[0].resources.limits,\
REQUESTS:.spec.containers[0].resources.requests
}

# Pattern 4: Event analysis
analyze_events() {
    echo "4. Recent Events Analysis:"
    
    echo "Recent warning events:"
    kubectl get events --field-selector type=Warning --sort-by=.metadata.creationTimestamp
    
    echo -e "\nEvents by reason:"
    kubectl get events -o jsonpath='{range .items[*]}{.reason}{"\n"}{end}' | \
    sort | uniq -c | sort -nr
}

# Pattern 5: Storage analysis
analyze_storage() {
    echo "5. Storage Analysis:"
    
    echo "Persistent Volumes:"
    kubectl get pv -o custom-columns=\
NAME:.metadata.name,\
CAPACITY:.spec.capacity.storage,\
ACCESS:.spec.accessModes,\
RECLAIM:.spec.persistentVolumeReclaimPolicy,\
STATUS:.status.phase

    echo -e "\nPersistent Volume Claims:"
    kubectl get pvc --all-namespaces -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
STATUS:.status.phase,\
VOLUME:.spec.volumeName,\
CAPACITY:.status.capacity.storage
}

# Execute all analyses
echo "Running comprehensive cluster analysis..."
echo "========================================"

map_resource_relationships
echo -e "\n" && read -p "Press Enter to continue to health analysis..."

analyze_resource_health
echo -e "\n" && read -p "Press Enter to continue to configuration analysis..."

analyze_configurations
echo -e "\n" && read -p "Press Enter to continue to event analysis..."

analyze_events
echo -e "\n" && read -p "Press Enter to continue to storage analysis..."

analyze_storage

echo -e "\n🎉 Advanced analysis complete!"
EOF

chmod +x ~/advanced-info-patterns.sh
```

## Resource Creation and Management Patterns

Creating and managing resources with kubectl involves understanding when to use imperative commands versus declarative configurations.

### Foundation Creation Patterns

```bash
# Basic resource creation examples
echo "=== Foundation Resource Creation ==="

# 1. Simple pod creation
kubectl run test-pod --image=nginx:1.21 --restart=Never

# 2. Deployment creation
kubectl create deployment web-app --image=nginx:1.21

# 3. Service creation
kubectl expose deployment web-app --port=80 --type=ClusterIP

# 4. ConfigMap creation
kubectl create configmap app-config --from-literal=database_url=postgresql://localhost:5432

# 5. Secret creation
kubectl create secret generic app-secret --from-literal=password=super-secret

# 6. Namespace creation
kubectl create namespace development
```

### Demo 5: Complete Application Deployment

```bash
# Complete application deployment demonstration
cat > ~/complete-app-deployment.sh << 'EOF'
#!/bin/bash

echo "=== Complete Application Deployment Demo ==="

# Configuration variables
APP_NAME="demo-webapp"
NAMESPACE="demo-app"
IMAGE="nginx:1.21"

# Phase 1: Environment preparation
prepare_environment() {
    echo "Phase 1: Environment Preparation"
    echo "================================"
    
    # Create namespace
    echo "Creating namespace: $NAMESPACE"
    kubectl create namespace $NAMESPACE || echo "Namespace already exists"
    
    # Set current namespace context
    echo "Setting namespace context..."
    kubectl config set-context --current --namespace=$NAMESPACE
    
    echo "✅ Environment prepared"
    echo
}

# Phase 2: Application deployment
deploy_application() {
    echo "Phase 2: Application Deployment"
    echo "==============================="
    
    # Create deployment
    echo "Creating deployment: $APP_NAME"
    kubectl create deployment $APP_NAME --image=$IMAGE
    
    # Scale deployment
    echo "Scaling deployment to 3 replicas..."
    kubectl scale deployment $APP_NAME --replicas=3
    
    # Wait for rollout
    echo "Waiting for deployment to be ready..."
    kubectl rollout status deployment/$APP_NAME
    
    echo "✅ Application deployed"
    echo
}

# Phase 3: Configuration management
setup_configuration() {
    echo "Phase 3: Configuration Management"
    echo "================================"
    
    # Create ConfigMap
    echo "Creating configuration..."
    kubectl create configmap ${APP_NAME}-config \
        --from-literal=app_name=$APP_NAME \
        --from-literal=environment=demo \
        --from-literal=version=1.0.0
    
    # Create Secret
    echo "Creating secrets..."
    kubectl create secret generic ${APP_NAME}-secret \
        --from-literal=database_password=demo-password \
        --from-literal=api_key=demo-api-key-12345
    
    echo "✅ Configuration created"
    echo
}

# Phase 4: Networking setup
setup_networking() {
    echo "Phase 4: Networking Setup"
    echo "========================"
    
    # Expose as ClusterIP service
    echo "Creating ClusterIP service..."
    kubectl expose deployment $APP_NAME --port=80 --target-port=80 --name=${APP_NAME}-service
    
    # Create NodePort service for external access
    echo "Creating NodePort service for external access..."
    kubectl expose deployment $APP_NAME --port=80 --type=NodePort --name=${APP_NAME}-external
    
    echo "✅ Networking configured"
    echo
}

# Phase 5: Verification
verify_deployment() {
    echo "Phase 5: Deployment Verification"
    echo "==============================="
    
    # Show all resources
    echo "All created resources:"
    kubectl get all
    
    echo -e "\nConfigMaps and Secrets:"
    kubectl get configmaps,secrets
    
    echo -e "\nDetailed service information:"
    kubectl get services -o wide
    
    echo -e "\nPod status:"
    kubectl get pods -o custom-columns=\
NAME:.metadata.name,\
STATUS:.status.phase,\
NODE:.spec.nodeName,\
IP:.status.podIP
    
    echo -e "\nDeployment events:"
    kubectl describe deployment $APP_NAME | tail -20
    
    echo "✅ Deployment verified"
    echo
}

# Phase 6: Testing
test_application() {
    echo "Phase 6: Application Testing"
    echo "=========================="
    
    # Get service details
    SERVICE_IP=$(kubectl get service ${APP_NAME}-service -o jsonpath='{.spec.clusterIP}')
    NODE_PORT=$(kubectl get service ${APP_NAME}-external -o jsonpath='{.spec.ports[0].nodePort}')
    
    echo "Service IP: $SERVICE_IP"
    echo "NodePort: $NODE_PORT"
    
    # Test internal connectivity
    echo -e "\nTesting internal connectivity..."
    kubectl run test-pod --image=curlimages/curl:latest --rm -it --restart=Never -- \
        curl -s http://${SERVICE_IP}:80 | head -10 || echo "Internal test completed"
    
    echo "✅ Testing completed"
    echo
}

# Cleanup function
cleanup_deployment() {
    echo "Cleanup: Removing Demo Resources"
    echo "==============================="
    
    # Delete all resources in namespace
    kubectl delete all --all -n $NAMESPACE
    kubectl delete configmap,secret --all -n $NAMESPACE
    
    # Delete namespace
    kubectl delete namespace $NAMESPACE
    
    # Reset namespace context
    kubectl config set-context --current --namespace=default
    
    echo "✅ Cleanup completed"
}

# Main execution
echo "Starting Complete Application Deployment Demo"
echo "============================================="

prepare_environment
deploy_application
setup_configuration
setup_networking
verify_deployment
test_application

echo -e "\n🎉 Demo completed successfully!"
echo -e "\nResources created in namespace: $NAMESPACE"
echo "To access your application:"
echo "1. Internal: http://$(kubectl get service ${APP_NAME}-service -n $NAMESPACE -o jsonpath='{.spec.clusterIP}'):80"
echo "2. External: Use NodePort $(kubectl get service ${APP_NAME}-external -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}')"

echo -e "\nCommands to explore:"
echo "kubectl get all -n $NAMESPACE"
echo "kubectl logs deployment/$APP_NAME -n $NAMESPACE"
echo "kubectl describe service ${APP_NAME}-service -n $NAMESPACE"

read -p "Would you like to clean up the demo resources? (y/n): " cleanup_choice
if [[ $cleanup_choice =~ ^[Yy] ]]; then
    cleanup_deployment
fi
EOF

chmod +x ~/complete-app-deployment.sh
```

### Advanced Creation and Management Patterns

```bash
# Advanced resource management patterns
cat > ~/advanced-resource-management.sh << 'EOF'
#!/bin/bash

echo "=== Advanced Resource Management Patterns ==="

# Pattern 1: Blue-Green Deployment Simulation
demonstrate_blue_green_deployment() {
    echo "1. Blue-Green Deployment Pattern"
    echo "==============================="
    
    APP_NAME="bg-demo"
    
    # Deploy Blue version
    echo "Deploying Blue version (v1.0)..."
    kubectl create deployment ${APP_NAME}-blue --image=nginx:1.20
    kubectl label deployment ${APP_NAME}-blue version=blue
    kubectl scale deployment ${APP_NAME}-blue --replicas=3
    
    # Create service pointing to blue
    kubectl expose deployment ${APP_NAME}-blue --port=80 --name=${APP_NAME}-service --selector=version=blue
    
    echo "Blue deployment ready, service points to blue"
    kubectl get pods -l version=blue
    
    # Deploy Green version
    echo -e "\nDeploying Green version (v2.0)..."
    kubectl create deployment ${APP_NAME}-green --image=nginx:1.21
    kubectl label deployment ${APP_NAME}-green version=green
    kubectl scale deployment ${APP_NAME}-green --replicas=3
    kubectl rollout status deployment/${APP_NAME}-green
    
    echo "Green deployment ready"
    kubectl get pods -l version=green
    
    # Switch service to green (simulating traffic switch)
    echo -e "\nSwitching traffic to Green version..."
    kubectl patch service ${APP_NAME}-service -p '{"spec":{"selector":{"version":"green"}}}'
    
    echo "Traffic switched to Green. Blue version still running for rollback."
    
    # Cleanup old blue version (after verification)
    echo -e "\nCleaning up Blue version..."
    kubectl delete deployment ${APP_NAME}-blue
    
    echo "✅ Blue-Green deployment pattern demonstrated"
    echo
}

# Pattern 2: Canary Deployment
demonstrate_canary_deployment() {
    echo "2. Canary Deployment Pattern"
    echo "=========================="
    
    APP_NAME="canary-demo"
    
    # Deploy stable version
    echo "Deploying stable version..."
    kubectl create deployment ${APP_NAME}-stable --image=nginx:1.20
    kubectl label deployment ${APP_NAME}-stable version=stable
    kubectl scale deployment ${APP_NAME}-stable --replicas=8
    
    # Deploy canary version (smaller scale)
    echo "Deploying canary version (10% traffic)..."
    kubectl create deployment ${APP_NAME}-canary --image=nginx:1.21
    kubectl label deployment ${APP_NAME}-canary version=canary
    kubectl scale deployment ${APP_NAME}-canary --replicas=2
    
    # Create service that balances between both
    kubectl create service clusterip ${APP_NAME}-service --tcp=80:80
    kubectl patch service ${APP_NAME}-service -p '{"spec":{"selector":{"app":"'${APP_NAME}'"}}}'
    
    # Label both deployments with common app label
    kubectl label deployment ${APP_NAME}-stable app=${APP_NAME}
    kubectl label deployment ${APP_NAME}-canary app=${APP_NAME}
    
    echo "Canary deployment ready:"
    echo "Stable pods (80% traffic):"
    kubectl get pods -l version=stable
    echo "Canary pods (20% traffic):"
    kubectl get pods -l version=canary
    
    # Simulate successful canary - promote to full deployment
    echo -e "\nPromoting canary to full deployment..."
    kubectl delete deployment ${APP_NAME}-stable
    kubectl scale deployment ${APP_NAME}-canary --replicas=10
    
    echo "✅ Canary deployment pattern demonstrated"
    echo
}

# Pattern 3: Rolling Update with Verification
demonstrate_rolling_update() {
    echo "3. Rolling Update with Verification"
    echo "================================="
    
    APP_NAME="rolling-demo"
    
    # Create initial deployment
    echo "Creating initial deployment (v1.0)..."
    kubectl create deployment $APP_NAME --image=nginx:1.20
    kubectl scale deployment $APP_NAME --replicas=6
    kubectl rollout status deployment/$APP_NAME
    
    # Configure rolling update strategy
    echo "Configuring rolling update strategy..."
    kubectl patch deployment $APP_NAME -p '{
        "spec": {
            "strategy": {
                "type": "RollingUpdate",
                "rollingUpdate": {
                    "maxUnavailable": 1,
                    "maxSurge": 2
                }
            }
        }
    }'
    
    # Perform rolling update
    echo "Starting rolling update to v2.0..."
    kubectl set image deployment/$APP_NAME nginx=nginx:1.21
    
    # Monitor the rollout
    echo "Monitoring rollout progress..."
    kubectl rollout status deployment/$APP_NAME --watch=true
    
    # Verify update
    echo -e "\nVerifying update:"
    kubectl get pods -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image
    
    # Demonstrate rollback
    echo -e "\nDemonstrating rollback capability..."
    kubectl rollout undo deployment/$APP_NAME
    kubectl rollout status deployment/$APP_NAME
    
    echo "✅ Rolling update pattern demonstrated"
    echo
}

# Pattern 4: Configuration Hot-Reload
demonstrate_config_hot_reload() {
    echo "4. Configuration Hot-Reload Pattern"
    echo "================================="
    
    APP_NAME="config-demo"
    
    # Create initial ConfigMap
    echo "Creating initial configuration..."
    kubectl create configmap ${APP_NAME}-config \
        --from-literal=message="Hello v1" \
        --from-literal=color="blue" \
        --from-literal=debug="false"
    
    # Create deployment that uses the ConfigMap
    cat << YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: global-load-balancer
  namespace: cluster-management
  labels:
    app: global-lb
    component: load-balancer
spec:
  replicas: 2
  selector:
    matchLabels:
      app: global-lb
  template:
    metadata:
      labels:
        app: global-lb
        component: load-balancer
    spec:
      containers:
      - name: load-balancer
        image: nginx:1.21
        ports:
        - containerPort: 80
        volumeMounts:
        - name: lb-config
          mountPath: /etc/nginx/conf.d
      volumes:
      - name: lb-config
        configMap:
          name: global-lb-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: global-lb-config
  namespace: cluster-management
data:
  default.conf: |
    upstream east-cluster {
        server global-app-service.cluster-east-prod.svc.cluster.local:80 weight=3;
    }
    
    upstream west-cluster {
        server global-app-service.cluster-west-prod.svc.cluster.local:80 weight=3;
    }
    
    upstream dev-cluster {
        server global-app-service.cluster-dev.svc.cluster.local:80 weight=1;
    }
    
    upstream staging-cluster {
        server global-app-service.cluster-staging.svc.cluster.local:80 weight=2;
    }
    
    # Health check endpoint
    map $request_uri $backend_pool {
        ~*/east     east-cluster;
        ~*/west     west-cluster;
        ~*/dev      dev-cluster;
        ~*/staging  staging-cluster;
        default     east-cluster;
    }
    
    server {
        listen 80;
        server_name global-lb;
        
        # Global load balancing with failover
        location / {
            proxy_pass http://east-cluster;
            proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            
            # Add cluster identification header
            add_header X-Served-By "Global-Load-Balancer";
            add_header X-Cluster-Pool "east-production";
        }
        
        # Region-specific routing
        location /east {
            proxy_pass http://east-cluster/;
            proxy_set_header Host $host;
            add_header X-Cluster-Pool "east-production";
        }
        
        location /west {
            proxy_pass http://west-cluster/;
            proxy_set_header Host $host;
            add_header X-Cluster-Pool "west-production";
        }
        
        location /dev {
            proxy_pass http://dev-cluster/;
            proxy_set_header Host $host;
            add_header X-Cluster-Pool "development";
        }
        
        location /staging {
            proxy_pass http://staging-cluster/;
            proxy_set_header Host $host;
            add_header X-Cluster-Pool "staging";
        }
        
        # Health check and status
        location /lb-health {
            return 200 '{"status":"healthy","service":"global-load-balancer","timestamp":"$(date -u +%Y-%m-%dT%H:%M:%SZ)"}';
            add_header Content-Type application/json;
        }
        
        # Load balancer statistics
        location /lb-stats {
            return 200 '{"active_clusters":4,"total_backends":15,"health":"all_healthy"}';
            add_header Content-Type application/json;
        }
    }
---
apiVersion: v1
kind: Service
metadata:
  name: global-load-balancer
  namespace: cluster-management
  labels:
    app: global-lb
spec:
  type: NodePort
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30100
  selector:
    app: global-lb
YAML

    kubectl rollout status deployment/global-load-balancer -n cluster-management
    
    echo "✅ Global load balancer deployed"
}

# Phase 6: Cross-Cluster Data Replication
setup_data_replication() {
    echo -e "\nPhase 6: Setting up cross-cluster data replication"
    echo "=============================================="
    
    # Deploy data synchronization service
    cat << YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: data-sync
  namespace: cluster-management
  labels:
    app: data-sync
    component: replication
spec:
  replicas: 1
  selector:
    matchLabels:
      app: data-sync
  template:
    metadata:
      labels:
        app: data-sync
        component: replication
    spec:
      containers:
      - name: sync-manager
        image: busybox:1.35
        command: ["sh", "-c"]
        args:
          - |
            echo "Starting cross-cluster data synchronization..."
            while true; do
              echo "[$(date)] Syncing data across clusters..."
              echo "  - East cluster: Syncing user data..."
              echo "  - West cluster: Syncing transaction data..." 
              echo "  - Dev cluster: Syncing test data..."
              echo "  - Staging cluster: Syncing staging data..."
              echo "  - Synchronization complete"
              sleep 30
            done
        env:
        - name: SYNC_INTERVAL
          value: "30"
        - name: CLUSTERS
          value: "east-prod,west-prod,dev,staging"
      - name: sync-monitor
        image: nginx:1.21
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: monitor-config
          mountPath: /etc/nginx/conf.d
      volumes:
      - name: monitor-config
        configMap:
          name: data-sync-monitor-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: data-sync-monitor-config
  namespace: cluster-management
data:
  default.conf: |
    server {
        listen 8080;
        server_name data-sync-monitor;
        
        location /api/sync-status {
            return 200 '{
                "status": "active",
                "last_sync": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
                "clusters_synced": 4,
                "data_consistency": "100%",
                "replication_lag": "< 1s"
            }';
            add_header Content-Type application/json;
        }
        
        location /health {
            return 200 '{"status":"healthy","service":"data-sync"}';
            add_header Content-Type application/json;
        }
    }
---
apiVersion: v1
kind: Service
metadata:
  name: data-sync-service
  namespace: cluster-management
  labels:
    app: data-sync
spec:
  ports:
  - port: 8080
    targetPort: 8080
  selector:
    app: data-sync
YAML

    # Create ConfigMaps in each cluster to simulate shared data
    for cluster in cluster-east-prod cluster-west-prod cluster-dev cluster-staging; do
        echo "Setting up shared data in $cluster..."
        kubectl create configmap shared-data -n $cluster \
            --from-literal=database_config="replicated_across_clusters" \
            --from-literal=sync_timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            --from-literal=cluster_id="$cluster" \
            --from-literal=replication_status="active" \
            2>/dev/null || \
        kubectl patch configmap shared-data -n $cluster --patch '{
            "data": {
                "sync_timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
                "replication_status": "active"
            }
        }'
    done

    kubectl rollout status deployment/data-sync -n cluster-management
    
    echo "✅ Cross-cluster data replication setup complete"
}

# Phase 7: Disaster Recovery Testing
simulate_disaster_recovery() {
    echo -e "\nPhase 7: Disaster recovery simulation"
    echo "===================================="
    
    echo "Simulating disaster scenario: East cluster failure..."
    
    # Scale down east cluster application (simulate failure)
    kubectl scale deployment global-app --replicas=0 -n cluster-east-prod
    
    echo "East cluster is down. Testing failover..."
    
    # Update load balancer configuration to remove failed cluster
    kubectl patch configmap global-lb-config -n cluster-management --patch '{
        "data": {
            "default.conf": "upstream west-cluster {\n    server global-app-service.cluster-west-prod.svc.cluster.local:80 weight=5;\n}\n\nupstream dev-cluster {\n    server global-app-service.cluster-dev.svc.cluster.local:80 weight=2;\n}\n\nupstream staging-cluster {\n    server global-app-service.cluster-staging.svc.cluster.local:80 weight=3;\n}\n\nserver {\n    listen 80;\n    server_name global-lb;\n    \n    location / {\n        proxy_pass http://west-cluster;\n        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;\n        proxy_set_header Host $host;\n        proxy_set_header X-Real-IP $remote_addr;\n        \n        add_header X-Served-By \"Global-Load-Balancer-Failover\";\n        add_header X-Cluster-Pool \"west-production-failover\";\n    }\n    \n    location /west {\n        proxy_pass http://west-cluster/;\n        proxy_set_header Host $host;\n        add_header X-Cluster-Pool \"west-production\";\n    }\n    \n    location /dev {\n        proxy_pass http://dev-cluster/;\n        proxy_set_header Host $host;\n        add_header X-Cluster-Pool \"development\";\n    }\n    \n    location /staging {\n        proxy_pass http://staging-cluster/;\n        proxy_set_header Host $host;\n        add_header X-Cluster-Pool \"staging\";\n    }\n    \n    location /lb-health {\n        return 200 \"{\\\"status\\\":\\\"degraded\\\",\\\"service\\\":\\\"global-load-balancer\\\",\\\"failed_clusters\\\":[\\\"east\\\"],\\\"active_clusters\\\":3}\";\n        add_header Content-Type application/json;\n    }\n}"
        }
    }'
    
    # Restart load balancer to pick up new configuration
    kubectl rollout restart deployment/global-load-balancer -n cluster-management
    kubectl rollout status deployment/global-load-balancer -n cluster-management
    
    # Scale up west cluster to handle additional load
    kubectl scale deployment global-app --replicas=8 -n cluster-west-prod
    kubectl rollout status deployment/global-app -n cluster-west-prod
    
    echo "Disaster recovery actions taken:"
    echo "✅ Failed east cluster detected and removed from load balancer"
    echo "✅ Traffic redirected to healthy west cluster"
    echo "✅ West cluster scaled up to handle additional load"
    
    echo -e "\nTesting recovery - bringing east cluster back online..."
    
    # Restore east cluster
    kubectl scale deployment global-app --replicas=5 -n cluster-east-prod
    kubectl rollout status deployment/global-app -n cluster-east-prod
    
    # Restore original load balancer configuration
    kubectl patch configmap global-lb-config -n cluster-management --patch '{
        "data": {
            "default.conf": "upstream east-cluster {\n    server global-app-service.cluster-east-prod.svc.cluster.local:80 weight=3;\n}\n\nupstream west-cluster {\n    server global-app-service.cluster-west-prod.svc.cluster.local:80 weight=3;\n}\n\nupstream dev-cluster {\n    server global-app-service.cluster-dev.svc.cluster.local:80 weight=1;\n}\n\nupstream staging-cluster {\n    server global-app-service.cluster-staging.svc.cluster.local:80 weight=2;\n}\n\nserver {\n    listen 80;\n    server_name global-lb;\n    \n    location / {\n        proxy_pass http://east-cluster;\n        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;\n        proxy_set_header Host $host;\n        proxy_set_header X-Real-IP $remote_addr;\n        \n        add_header X-Served-By \"Global-Load-Balancer\";\n        add_header X-Cluster-Pool \"east-production\";\n    }\n    \n    location /east {\n        proxy_pass http://east-cluster/;\n        proxy_set_header Host $host;\n        add_header X-Cluster-Pool \"east-production\";\n    }\n    \n    location /west {\n        proxy_pass http://west-cluster/;\n        proxy_set_header Host $host;\n        add_header X-Cluster-Pool \"west-production\";\n    }\n    \n    location /dev {\n        proxy_pass http://dev-cluster/;\n        proxy_set_header Host $host;\n        add_header X-Cluster-Pool \"development\";\n    }\n    \n    location /staging {\n        proxy_pass http://staging-cluster/;\n        proxy_set_header Host $host;\n        add_header X-Cluster-Pool \"staging\";\n    }\n    \n    location /lb-health {\n        return 200 \"{\\\"status\\\":\\\"healthy\\\",\\\"service\\\":\\\"global-load-balancer\\\",\\\"active_clusters\\\":4}\";\n        add_header Content-Type application/json;\n    }\n}"
        }
    }'
    
    kubectl rollout restart deployment/global-load-balancer -n cluster-management
    kubectl rollout status deployment/global-load-balancer -n cluster-management
    
    # Scale west cluster back to normal
    kubectl scale deployment global-app --replicas=5 -n cluster-west-prod
    
    echo "✅ Disaster recovery simulation complete"
    echo "✅ East cluster restored and back in rotation"
}

# Phase 8: Multi-Cluster Monitoring
setup_global_monitoring() {
    echo -e "\nPhase 8: Setting up multi-cluster monitoring"
    echo "=========================================="
    
    # Deploy global monitoring system
    cat << YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: global-monitoring
  namespace: cluster-management
  labels:
    app: global-monitoring
    component: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: global-monitoring
  template:
    metadata:
      labels:
        app: global-monitoring
        component: monitoring
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:latest
        ports:
        - containerPort: 9090
        args:
          - '--config.file=/etc/prometheus/prometheus.yml'
          - '--storage.tsdb.path=/prometheus/'
          - '--web.console.libraries=/etc/prometheus/console_libraries'
          - '--web.console.templates=/etc/prometheus/consoles'
        volumeMounts:
        - name: prometheus-config
          mountPath: /etc/prometheus/
        - name: prometheus-storage
          mountPath: /prometheus/
      - name: grafana
        image: grafana/grafana:latest
        ports:
        - containerPort: 3000
        env:
        - name: GF_SECURITY_ADMIN_PASSWORD
          value: admin123
        volumeMounts:
        - name: grafana-storage
          mountPath: /var/lib/grafana
      volumes:
      - name: prometheus-config
        configMap:
          name: global-prometheus-config
      - name: prometheus-storage
        emptyDir: {}
      - name: grafana-storage
        emptyDir: {}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: global-prometheus-config
  namespace: cluster-management
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
    
    rule_files:
      - "alert_rules.yml"
    
    scrape_configs:
      - job_name: 'global-apps'
        static_configs:
          - targets: ['global-app-service.cluster-east-prod.svc.cluster.local:80']
            labels:
              cluster: 'east-production'
              region: 'east'
          - targets: ['global-app-service.cluster-west-prod.svc.cluster.local:80']
            labels:
              cluster: 'west-production'  
              region: 'west'
          - targets: ['global-app-service.cluster-dev.svc.cluster.local:80']
            labels:
              cluster: 'development'
              region: 'central'
          - targets: ['global-app-service.cluster-staging.svc.cluster.local:80']
            labels:
              cluster: 'staging'
              region: 'central'
      
      - job_name: 'infrastructure'
        static_configs:
          - targets: ['global-load-balancer.cluster-management.svc.cluster.local:80']
            labels:
              service: 'load-balancer'
          - targets: ['service-registry.cluster-management.svc.cluster.local:80']
            labels:
              service: 'service-registry'
          - targets: ['data-sync-service.cluster-management.svc.cluster.local:8080']
            labels:
              service: 'data-sync'

  alert_rules.yml: |
    groups:
      - name: multi-cluster-alerts
        rules:
          - alert: ClusterDown
            expr: up{job="global-apps"} == 0
            for: 1m
            labels:
              severity: critical
            annotations:
              summary: "Cluster {{ $labels.cluster }} in region {{ $labels.region }} is down"
              
          - alert: LoadBalancerUnhealthy
            expr: up{service="load-balancer"} == 0
            for: 30s
            labels:
              severity: critical
            annotations:
              summary: "Global load balancer is unhealthy"
---
apiVersion: v1
kind: Service
metadata:
  name: global-monitoring-service
  namespace: cluster-management
  labels:
    app: global-monitoring
spec:
  type: NodePort
  ports:
  - port: 9090
    targetPort: 9090
    nodePort: 30090
    name: prometheus
  - port: 3000
    targetPort: 3000
    nodePort: 30030
    name: grafana
  selector:
    app: global-monitoring
YAML

    kubectl rollout status deployment/global-monitoring -n cluster-management
    
    echo "✅ Global monitoring system deployed"
    echo "📊 Prometheus: http://localhost:30090"
    echo "📈 Grafana: http://localhost:30030 (admin/admin123)"
}

# Phase 9: Multi-Cluster Analytics and Reporting
generate_cluster_analytics() {
    echo -e "\nPhase 9: Generating multi-cluster analytics"
    echo "========================================"
    
    echo "Collecting analytics from all clusters..."
    
    # Generate comprehensive multi-cluster report
    cat > ~/multi-cluster-analytics.md << REPORT
# Multi-Cluster Management Analytics Report

## Executive Summary
- **Project**: $PROJECT_NAME  
- **Total Clusters**: 4 (2 Production, 1 Staging, 1 Development)
- **Report Generated**: $(date)
- **Overall Status**: Healthy

## Cluster Overview

### Production Clusters

#### East Production Cluster
- **Region**: East US
- **Status**: Healthy
- **Applications**: $(kubectl get deployments -n cluster-east-prod --no-headers 2>/dev/null | wc -l)
- **Pods**: $(kubectl get pods -n cluster-east-prod --no-headers 2>/dev/null | wc -l)

#### West Production Cluster  
- **Region**: West US
- **Status**: Healthy
- **Applications**: $(kubectl get deployments -n cluster-west-prod --no-headers 2>/dev/null | wc -l)
- **Pods**: $(kubectl get pods -n cluster-west-prod --no-headers 2>/dev/null | wc -l)

### Non-Production Clusters

#### Development Cluster
- **Region**: Central
- **Status**: Healthy
- **Applications**: $(kubectl get deployments -n cluster-dev --no-headers 2>/dev/null | wc -l)
- **Pods**: $(kubectl get pods -n cluster-dev --no-headers 2>/dev/null | wc -l)

#### Staging Cluster
- **Region**: Central  
- **Status**: Healthy
- **Applications**: $(kubectl get deployments -n cluster-staging --no-headers 2>/dev/null | wc -l)
- **Pods**: $(kubectl get pods -n cluster-staging --no-headers 2>/dev/null | wc -l)

## Infrastructure Components

### Management Services
\`\`\`bash
$(kubectl get all -n cluster-management 2>/dev/null || echo "No management services found")
\`\`\`

### Global Services Status
- **Load Balancer**: $(kubectl get deployment global-load-balancer -n cluster-management -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")/$(kubectl get deployment global-load-balancer -n cluster-management -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0") replicas ready
- **Service Registry**: $(kubectl get deployment service-registry -n cluster-management -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")/$(kubectl get deployment service-registry -n cluster-management -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0") replicas ready  
- **Data Synchronization**: $(kubectl get deployment data-sync -n cluster-management -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")/$(kubectl get deployment data-sync -n cluster-management -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0") replicas ready

## Application Distribution

### Global Application Deployment
\`\`\`
Cluster                | Replicas | Status
----------------------|----------|--------
East Production       | $(kubectl get deployment global-app -n cluster-east-prod -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")        | $(kubectl get deployment global-app -n cluster-east-prod -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "Unknown")
West Production       | $(kubectl get deployment global-app -n cluster-west-prod -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")        | $(kubectl get deployment global-app -n cluster-west-prod -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "Unknown")  
Development           | $(kubectl get deployment global-app -n cluster-dev -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")        | $(kubectl get deployment global-app -n cluster-dev -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "Unknown")
Staging               | $(kubectl get deployment global-app -n cluster-staging -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")        | $(kubectl get deployment global-app -n cluster-staging -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "Unknown")
\`\`\`

## Operational Procedures

### Multi-Cluster Management Commands

#### Global Operations
\`\`\`bash
# View all clusters
kubectl get namespaces -l cluster-type

# Check global application status
kubectl get deployments --all-namespaces -l app=global-app

# Monitor global load balancer
kubectl logs deployment/global-load-balancer -n cluster-management
\`\`\`

#### Cluster-Specific Operations  
\`\`\`bash
# Scale application in specific cluster
kubectl scale deployment global-app --replicas=10 -n cluster-east-prod

# Deploy to specific region
kubectl apply -f app-config.yaml -n cluster-west-prod

# Check cluster health
kubectl get pods -n cluster-east-prod
kubectl get services -n cluster-west-prod
\`\`\`

#### Disaster Recovery
\`\`\`bash
# Simulate cluster failure
kubectl scale deployment global-app --replicas=0 -n cluster-east-prod

# Redirect traffic to healthy clusters
kubectl patch configmap global-lb-config -n cluster-management --patch '...'

# Scale up remaining clusters
kubectl scale deployment global-app --replicas=8 -n cluster-west-prod
\`\`\`

## Monitoring and Observability

### Key Metrics
- **Total Applications**: $(kubectl get deployments --all-namespaces -l app=global-app --no-headers 2>/dev/null | wc -l)
- **Total Pods**: $(kubectl get pods --all-namespaces -l app=global-app --no-headers 2>/dev/null | wc -l)  
- **Healthy Services**: $(kubectl get services --all-namespaces -l app=global-app --no-headers 2>/dev/null | wc -l)

### Access Points
- **Cluster Dashboard**: http://localhost:30095
- **Global Load Balancer**: http://localhost:30100
- **Prometheus Monitoring**: http://localhost:30090
- **Grafana Dashboards**: http://localhost:30030

## Cleanup Procedures
\`\`\`bash
# Clean up all clusters and management infrastructure
kubectl delete namespace cluster-east-prod cluster-west-prod cluster-dev cluster-staging cluster-management

# Remove analytics reports
rm -f ~/multi-cluster-analytics.md
\`\`\`

---
**Report Generated**: $(date)  
**kubectl Version**: $(kubectl version --client --short 2>/dev/null || echo "Unknown")
REPORT

    echo "📊 Multi-cluster analytics report generated: ~/multi-cluster-analytics.md"
}

# Phase 10: Final Status and Demonstration
show_final_status() {
    echo -e "\n=== Multi-Cluster Management Final Status ==="
    echo "============================================"
    
    echo "🌐 Global Infrastructure Status:"
    kubectl get deployments -n cluster-management -o custom-columns=\
NAME:.metadata.name,\
READY:.status.readyReplicas,\
AVAILABLE:.status.availableReplicas,\
AGE:.metadata.creationTimestamp

    echo -e "\n🏢 Cluster Application Distribution:"
    for cluster in cluster-east-prod cluster-west-prod cluster-dev cluster-staging; do
        echo "Cluster: $cluster"
        kubectl get deployments -n $cluster -o custom-columns=\
NAME:.metadata.name,\
REPLICAS:.spec.replicas,\
READY:.status.readyReplicas,\
LABELS:.metadata.labels 2>/dev/null || echo "  No deployments"
        echo
    done
    
    echo "🔗 Service Connectivity:"
    kubectl get services --all-namespaces -l app=global-app -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
TYPE:.spec.type,\
CLUSTER-IP:.spec.clusterIP,\
EXTERNAL-IP:.status.loadBalancer.ingress[0].ip
    
    echo -e "\n📊 Resource Summary:"
    echo "Total Namespaces (Clusters): $(kubectl get namespaces | grep cluster- | wc -l)"
    echo "Total Applications: $(kubectl get deployments --all-namespaces -l app=global-app --no-headers 2>/dev/null | wc -l)"
    echo "Total Pods: $(kubectl get pods --all-namespaces -l app=global-app --no-headers 2>/dev/null | wc -l)"
    echo "Management Services: $(kubectl get deployments -n cluster-management --no-headers 2>/dev/null | wc -l)"
    
    echo -e "\n🌍 Access Points:"
    echo "Cluster Dashboard: http://localhost:30095 (if accessible)"
    echo "Global Load Balancer: http://localhost:30100 (if accessible)"  
    echo "Prometheus: http://localhost:30090 (if accessible)"
    echo "Grafana: http://localhost:30030 (admin/admin123) (if accessible)"
}

# Cleanup function
cleanup_multi_cluster_project() {
    echo -e "\n=== Multi-Cluster Project Cleanup ==="
    
    # Delete all cluster namespaces
    kubectl delete namespace cluster-east-prod cluster-west-prod cluster-dev cluster-staging cluster-management
    
    # Clean up reports
    rm -f ~/multi-cluster-analytics.md
    
    echo "✅ Multi-cluster project cleanup complete"
}

# Main execution
echo "Starting Multi-Cluster Management and Federation Project"
echo "======================================================"

setup_cluster_contexts
deploy_cluster_management
deploy_applications_across_clusters
setup_service_discovery
setup_global_load_balancer
setup_data_replication
simulate_disaster_recovery
setup_global_monitoring
generate_cluster_analytics
show_final_status

echo -e "\n🎉 Multi-Cluster Management Project Complete!"
echo "============================================="
echo "✅ Multi-cluster infrastructure deployed"
echo "✅ Cross-cluster service discovery implemented"
echo "✅ Global load balancing configured"
echo "✅ Data replication and synchronization active"
echo "✅ Disaster recovery procedures tested"
echo "✅ Comprehensive monitoring and observability"
echo "✅ Analytics and reporting generated"

echo -e "\nProject Features Demonstrated:"
echo "🌐 Global application deployment across 4 clusters"
echo "⚖️  Intelligent load balancing with failover"
echo "🔄 Cross-cluster data synchronization"
echo "🚨 Automated disaster recovery"
echo "📊 Multi-cluster monitoring and analytics"
echo "🔧 Centralized management dashboard"

echo -e "\nProject Artifacts:"
echo "📊 ~/multi-cluster-analytics.md - Comprehensive cluster analytics"

echo -e "\nExplore your multi-cluster deployment:"
echo "kubectl get all -n cluster-management"
echo "kubectl get deployments --all-namespaces -l app=global-app"

read -p "Would you like to clean up the entire multi-cluster project? (y/n): " cleanup
if [[ $cleanup =~ ^[Yy] ]]; then
    cleanup_multi_cluster_project
fi
EOF

chmod +x ~/multi-cluster-project.sh
```

## Building Your kubectl Proficiency - Putting It All Together

The journey to kubectl mastery is complete! You now have comprehensive examples, practical demos, and real-world mini-projects that demonstrate kubectl usage from basic concepts to advanced enterprise scenarios.

### Summary of What You've Learned

Your enhanced kubectl guide now includes:

**📚 Foundation Knowledge:**
- Command structure and patterns
- Environment setup and configuration
- Help system navigation
- Resource discovery and explanation

**🔧 Practical Skills:**
- Information retrieval and filtering
- Resource creation and management
- Troubleshooting and debugging
- Advanced selection techniques

**🏗️ Real-World Applications:**
- Complete microservices deployment
- CI/CD pipeline simulation
- Multi-cluster management
- Enterprise-grade scenarios

**🎯 Advanced Techniques:**
- Blue-green and canary deployments
- Cross-cluster service discovery
- Disaster recovery procedures
- Performance monitoring and analytics

### Practice Recommendations

To truly master kubectl, follow this progressive practice approach:

**Week 1-2: Foundation Building**
```bash
# Run these daily practice sessions
~/setup-kubectl-env.sh
~/kubectl-help-explorer.sh
~/resource-explorer.sh
~/info-retrieval-demo.sh
```

**Week 3-4: Intermediate Skills**
```bash
# Practice troubleshooting and filtering
~/troubleshooting-workflow.sh
~/advanced-filtering-workshop.sh
~/advanced-troubleshooting.sh
```

**Week 5-6: Real-World Projects**
```bash
# Complete the mini-projects
~/complete-app-deployment.sh
~/microservices-project.sh
~/devops-pipeline-project.sh
```

**Week 7-8: Advanced Scenarios**
```bash
# Master complex deployments
~/advanced-resource-management.sh
~/multi-cluster-project.sh
```

### kubectl Mastery Checklist

Use this checklist to track your progress:

**✅ Basic Proficiency**
- [ ] Can navigate kubectl help system without external documentation
- [ ] Comfortable with basic resource operations (get, create, delete, describe)
- [ ] Understands output formatting and filtering
- [ ] Can troubleshoot common pod and service issues

**✅ Intermediate Proficiency**
- [ ] Masters advanced selection with labels and field selectors
- [ ] Can use JSONPath and custom columns effectively
- [ ] Comfortable with imperative and declarative resource management
- [ ] Understands resource relationships and dependencies

**✅ Advanced Proficiency**
- [ ] Can design and implement complex deployment strategies
- [ ] Masters cross-namespace and cross-cluster operations
- [ ] Comfortable with automation and scripting
- [ ] Can troubleshoot complex multi-component issues

**✅ Expert Level**
- [ ] Can architect complete multi-tier applications
- [ ] Masters CI/CD pipeline integration
- [ ] Comfortable with disaster recovery procedures
- [ ] Can optimize performance and resource utilization

### Continued Learning Path

Your kubectl journey doesn't end here. Consider these next steps:

**🎓 Advanced Topics to Explore:**
- Custom Resource Definitions (CRDs)
- Operators and controller patterns
- Service mesh integration
- Security and RBAC deep dive
- Performance optimization
- Kubernetes networking

**🛠️ Tool Integration:**
- Helm for package management
- Kustomize for configuration management
- Istio for service mesh
- ArgoCD for GitOps
- Prometheus for monitoring

**🏢 Enterprise Scenarios:**
- Multi-tenancy patterns
- Compliance and governance
- Cost optimization
- Platform engineering

### Final Words

Remember that kubectl proficiency comes from consistent practice and real-world application. The examples and projects in this enhanced guide provide you with a solid foundation, but the key to mastery is:

1. **Regular Practice**: Use kubectl daily, even for simple tasks
2. **Experimentation**: Try new commands and options in safe environments
3. **Problem Solving**: Use kubectl to solve real problems you encounter
4. **Teaching Others**: Share your knowledge to reinforce your understanding
5. **Staying Current**: Keep up with new kubectl features and Kubernetes developments

The path to kubectl mastery is a journey of continuous learning. With the comprehensive foundation provided in this guide, you're well-equipped to handle any Kubernetes challenge that comes your way.

**🎉 Congratulations on completing your comprehensive kubectl mastery journey!**

Your enhanced guide now contains:
- **50+ practical examples** from basic to advanced
- **6 comprehensive demos** with step-by-step instructions  
- **3 real-world mini-projects** simulating enterprise scenarios
- **15+ interactive scripts** for hands-on learning
- **Complete troubleshooting workflows** for common issues
- **Advanced patterns** for professional Kubernetes management

Keep this guide as your kubectl reference and continue building on the solid foundation you've established. The journey to Kubernetes mastery is ongoing, and kubectl proficiency is your key to unlocking the full potential of container orchestration.

Happy kubectling! 🚀
kind: Deployment
metadata:
  name: $APP_NAME
spec:
  replicas: 3
  selector:
    matchLabels:
      app: $APP_NAME
  template:
    metadata:
      labels:
        app: $APP_NAME
    spec:
      containers:
      - name: app
        image: nginx:1.21
        env:
        - name: MESSAGE
          valueFrom:
            configMapKeyRef:
              name: ${APP_NAME}-config
              key: message
        - name: COLOR
          valueFrom:
            configMapKeyRef:
              name: ${APP_NAME}-config
              key: color
        volumeMounts:
        - name: config-volume
          mountPath: /etc/config
      volumes:
      - name: config-volume
        configMap:
          name: ${APP_NAME}-config
YAML

    kubectl rollout status deployment/$APP_NAME
    
    # Update configuration
    echo "Updating configuration..."
    kubectl create configmap ${APP_NAME}-config \
        --from-literal=message="Hello v2 Updated" \
        --from-literal=color="green" \
        --from-literal=debug="true" \
        --dry-run=client -o yaml | kubectl replace -f -
    
    # Trigger pod restart to pick up new config
    echo "Triggering configuration reload..."
    kubectl rollout restart deployment/$APP_NAME
    kubectl rollout status deployment/$APP_NAME
    
    echo "✅ Configuration hot-reload demonstrated"
    echo
}

# Pattern 5: Multi-Container Pod Management
demonstrate_multi_container_patterns() {
    echo "5. Multi-Container Pod Patterns"
    echo "============================="
    
    # Sidecar pattern
    echo "Creating sidecar pattern pod..."
    cat << YAML | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: sidecar-demo
  labels:
    pattern: sidecar
spec:
  containers:
  - name: main-app
    image: nginx:1.21
    ports:
    - containerPort: 80
    volumeMounts:
    - name: shared-logs
      mountPath: /var/log/nginx
  - name: log-shipper
    image: busybox:1.35
    command: ['sh', '-c', 'tail -f /var/log/nginx/access.log']
    volumeMounts:
    - name: shared-logs
      mountPath: /var/log/nginx
  volumes:
  - name: shared-logs
    emptyDir: {}
YAML

    # Init container pattern
    echo "Creating init container pattern pod..."
    cat << YAML | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: init-demo
  labels:
    pattern: init-container
spec:
  initContainers:
  - name: init-setup
    image: busybox:1.35
    command: ['sh', '-c', 'echo "Setup complete" > /shared/setup.txt']
    volumeMounts:
    - name: shared-data
      mountPath: /shared
  containers:
  - name: main-app
    image: nginx:1.21
    command: ['sh', '-c', 'cat /shared/setup.txt && nginx -g "daemon off;"']
    volumeMounts:
    - name: shared-data
      mountPath: /shared
  volumes:
  - name: shared-data
    emptyDir: {}
YAML

    # Wait for pods to be ready
    kubectl wait --for=condition=Ready pod/sidecar-demo --timeout=60s
    kubectl wait --for=condition=Ready pod/init-demo --timeout=60s
    
    echo "Multi-container pods created:"
    kubectl get pods -l pattern
    
    # Demonstrate container-specific operations
    echo -e "\nDemonstrating container-specific operations:"
    echo "Logs from main container:"
    kubectl logs sidecar-demo -c main-app | head -5
    
    echo -e "\nLogs from sidecar container:"
    kubectl logs sidecar-demo -c log-shipper | head -5
    
    echo -e "\nExec into specific container:"
    kubectl exec sidecar-demo -c main-app -- nginx -v
    
    echo "✅ Multi-container patterns demonstrated"
    echo
}

# Cleanup function for advanced patterns
cleanup_advanced_patterns() {
    echo "Cleaning up advanced pattern resources..."
    
    # Clean up deployments and services
    kubectl delete deployment --all
    kubectl delete service --all
    kubectl delete configmap --all
    kubectl delete pod --all
    
    echo "✅ Advanced patterns cleanup completed"
}

# Execute all patterns
echo "Starting Advanced Resource Management Demonstration"
echo "================================================="

demonstrate_blue_green_deployment
read -p "Press Enter to continue to canary deployment demo..."

demonstrate_canary_deployment  
read -p "Press Enter to continue to rolling update demo..."

demonstrate_rolling_update
read -p "Press Enter to continue to config hot-reload demo..."

demonstrate_config_hot_reload
read -p "Press Enter to continue to multi-container demo..."

demonstrate_multi_container_patterns

echo -e "\n🎉 Advanced Resource Management Demo Complete!"

read -p "Would you like to clean up all demo resources? (y/n): " cleanup_choice
if [[ $cleanup_choice =~ ^[Yy] ]]; then
    cleanup_advanced_patterns
fi
EOF

chmod +x ~/advanced-resource-management.sh
```

## Resource Inspection and Troubleshooting

Effective troubleshooting with kubectl requires understanding how to gather detailed information about resource states, events, and logs.

### Foundation Troubleshooting Examples

```bash
# Basic troubleshooting patterns
echo "=== Foundation Troubleshooting ==="

# 1. Get resource status overview
kubectl get pods                    # Quick status check
kubectl get pods -o wide           # More detailed view
kubectl get events --sort-by=.metadata.creationTimestamp  # Recent events

# 2. Detailed resource inspection
kubectl describe pod <pod-name>     # Comprehensive pod info
kubectl describe service <svc-name> # Service configuration and endpoints

# 3. Log examination
kubectl logs <pod-name>             # Container logs
kubectl logs <pod-name> --previous  # Previous container instance logs
kubectl logs -f <pod-name>          # Follow logs in real-time

# 4. Interactive debugging
kubectl exec -it <pod-name> -- /bin/bash  # Shell into container
kubectl port-forward <pod-name> 8080:80   # Forward ports for testing
```

### Demo 6: Systematic Troubleshooting Workflow

```bash
# Comprehensive troubleshooting workflow demonstration
cat > ~/troubleshooting-workflow.sh << 'EOF'
#!/bin/bash

echo "=== kubectl Troubleshooting Workflow Demo ==="

# Setup problematic scenarios for demonstration
setup_problematic_scenarios() {
    echo "Setting up problematic scenarios for troubleshooting demo..."
    
    # Scenario 1: Image pull error
    kubectl create deployment broken-image --image=nonexistent:latest
    
    # Scenario 2: Resource limits causing issues
    cat << YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-limited
spec:
  replicas: 1
  selector:
    matchLabels:
      app: resource-limited
  template:
    metadata:
      labels:
        app: resource-limited
    spec:
      containers:
      - name: memory-hog
        image: nginx:1.21
        resources:
          limits:
            memory: "10Mi"
          requests:
            memory: "5Mi"
YAML

    # Scenario 3: Service with no endpoints
    kubectl create service clusterip orphaned-service --tcp=80:80
    # No deployment to back this service
    
    # Scenario 4: ConfigMap dependency missing
    cat << YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: missing-config
spec:
  replicas: 1
  selector:
    matchLabels:
      app: missing-config
  template:
    metadata:
      labels:
        app: missing-config
    spec:
      containers:
      - name: app
        image: nginx:1.21
        env:
        - name: CONFIG_VALUE
          valueFrom:
            configMapKeyRef:
              name: nonexistent-config
              key: value
YAML
    
    echo "✅ Problematic scenarios set up"
    sleep 5  # Allow time for resources to be created and fail
}

# Troubleshooting Phase 1: Initial Assessment
phase1_initial_assessment() {
    echo -e "\n=== Phase 1: Initial Assessment ==="
    echo "Goal: Get overall cluster and resource health overview"
    
    echo -e "\n1. Check overall resource status:"
    kubectl get all
    
    echo -e "\n2. Look for obvious problems:"
    kubectl get pods | grep -E "(Error|CrashLoopBackOff|ImagePullBackOff|Pending)"
    
    echo -e "\n3. Check recent events:"
    kubectl get events --sort-by=.metadata.creationTimestamp | tail -10
    
    echo -e "\n4. Node health check:"
    kubectl get nodes
    kubectl describe nodes | grep -E "(Conditions:|Memory|CPU)" -A 10
    
    read -p "Press Enter to continue to detailed diagnosis..."
}

# Troubleshooting Phase 2: Detailed Diagnosis
phase2_detailed_diagnosis() {
    echo -e "\n=== Phase 2: Detailed Diagnosis ==="
    echo "Goal: Drill down into specific problem areas"
    
    # Analyze each problematic pod
    echo -e "\n1. Analyzing problematic pods:"
    problematic_pods=$(kubectl get pods --no-headers | grep -E "(Error|CrashLoopBackOff|ImagePullBackOff|Pending)" | awk '{print $1}')
    
    for pod in $problematic_pods; do
        echo -e "\n--- Analyzing pod: $pod ---"
        
        echo "Pod status and recent events:"
        kubectl describe pod $pod | grep -E "(Status|Events:)" -A 15
        
        echo -e "\nPod logs (last 10 lines):"
        kubectl logs $pod --tail=10 2>/dev/null || echo "No logs available"
        
        echo -e "\nPrevious container logs (if restarted):"
        kubectl logs $pod --previous --tail=5 2>/dev/null || echo "No previous logs"
        
        echo -e "\n" && read -p "Press Enter to continue to next pod..."
    done
}

# Troubleshooting Phase 3: Service and Network Diagnosis
phase3_service_diagnosis() {
    echo -e "\n=== Phase 3: Service and Network Diagnosis ==="
    echo "Goal: Verify service connectivity and network issues"
    
    echo -e "\n1. Service status overview:"
    kubectl get services -o wide
    
    echo -e "\n2. Checking service endpoints:"
    for service in $(kubectl get services --no-headers | awk '{print $1}' | grep -v kubernetes); do
        echo -e "\n--- Service: $service ---"
        kubectl describe service $service | grep -E "(Endpoints:|Selector:)" -A 3
        
        # Check if there are matching pods for the selector
        selector=$(kubectl get service $service -o jsonpath='{.spec.selector}' 2>/dev/null)
        if [ -n "$selector" ]; then
            echo "Matching pods for selector:"
            kubectl get pods --selector="app=$(kubectl get service $service -o jsonpath='{.spec.selector.app}' 2>/dev/null)" 2>/dev/null || echo "No matching pods found"
        fi
    done
    
    read -p "Press Enter to continue to configuration diagnosis..."
}

# Troubleshooting Phase 4: Configuration Diagnosis
phase4_configuration_diagnosis() {
    echo -e "\n=== Phase 4: Configuration Diagnosis ==="
    echo "Goal: Check configuration issues (ConfigMaps, Secrets, etc.)"
    
    echo -e "\n1. ConfigMaps and Secrets status:"
    kubectl get configmaps,secrets
    
    echo -e "\n2. Checking for missing configuration references:"
    # Check deployments for ConfigMap/Secret references
    for deployment in $(kubectl get deployments --no-headers | awk '{print $1}'); do
        echo -e "\n--- Deployment: $deployment ---"
        
        echo "ConfigMap references:"
        kubectl get deployment $deployment -o yaml | grep -E "(configMapKeyRef|configMap:)" -B2 -A2 || echo "No ConfigMap references"
        
        echo "Secret references:"
        kubectl get deployment $deployment -o yaml | grep -E "(secretKeyRef|secret:)" -B2 -A2 || echo "No Secret references"
    done
    
    read -p "Press Enter to continue to resource diagnosis..."
}

# Troubleshooting Phase 5: Resource Diagnosis
phase5_resource_diagnosis() {
    echo -e "\n=== Phase 5: Resource Diagnosis ==="
    echo "Goal: Check resource constraints and limits"
    
    echo -e "\n1. Pod resource requests and limits:"
    kubectl get pods -o custom-columns=\
NAME:.metadata.name,\
CPU_REQ:.spec.containers[0].resources.requests.cpu,\
CPU_LIM:.spec.containers[0].resources.limits.cpu,\
MEM_REQ:.spec.containers[0].resources.requests.memory,\
MEM_LIM:.spec.containers[0].resources.limits.memory
    
    echo -e "\n2. Node resource utilization:"
    kubectl top nodes 2>/dev/null || echo "Metrics server not available"
    
    echo -e "\n3. Pod resource utilization:"
    kubectl top pods 2>/dev/null || echo "Metrics server not available"
    
    echo -e "\n4. Check for resource quota issues:"
    kubectl describe quota 2>/dev/null || echo "No resource quotas found"
    
    read -p "Press Enter to continue to resolution strategies..."
}

# Troubleshooting Phase 6: Resolution Strategies
phase6_resolution_strategies() {
    echo -e "\n=== Phase 6: Resolution Strategies ==="
    echo "Goal: Apply fixes based on diagnosed issues"
    
    echo -e "\n1. Fixing image pull errors:"
    echo "Correcting broken-image deployment..."
    kubectl set image deployment/broken-image nonexistent=nginx:1.21
    kubectl rollout status deployment/broken-image
    
    echo -e "\n2. Adjusting resource limits:"
    echo "Increasing memory limit for resource-limited deployment..."
    kubectl patch deployment resource-limited -p '{
        "spec": {
            "template": {
                "spec": {
                    "containers": [{
                        "name": "memory-hog",
                        "resources": {
                            "limits": {"memory": "128Mi"},
                            "requests": {"memory": "64Mi"}
                        }
                    }]
                }
            }
        }
    }'
    kubectl rollout status deployment/resource-limited
    
    echo -e "\n3. Creating missing ConfigMap:"
    echo "Creating the missing configuration..."
    kubectl create configmap nonexistent-config --from-literal=value="demo-value"
    kubectl rollout restart deployment/missing-config
    kubectl rollout status deployment/missing-config
    
    echo -e "\n4. Fixing service endpoints:"
    echo "Creating deployment to back the orphaned service..."
    kubectl create deployment orphaned-service --image=nginx:1.21
    kubectl patch service orphaned-service -p '{"spec":{"selector":{"app":"orphaned-service"}}}'
    
    echo "✅ Resolution strategies applied"
}

# Final verification
final_verification() {
    echo -e "\n=== Final Verification ==="
    echo "Checking if all issues have been resolved..."
    
    echo -e "\n1. Overall resource status:"
    kubectl get all
    
    echo -e "\n2. Pod health check:"
    kubectl get pods | grep -E "(Error|CrashLoopBackOff|ImagePullBackOff|Pending)" || echo "✅ No problematic pods found"
    
    echo -e "\n3. Service endpoints:"
    kubectl get endpoints
    
    echo "✅ Troubleshooting workflow complete!"
}

# Cleanup function
cleanup_troubleshooting_demo() {
    echo -e "\nCleaning up troubleshooting demo resources..."
    kubectl delete deployment broken-image resource-limited missing-config orphaned-service
    kubectl delete service orphaned-service
    kubectl delete configmap nonexistent-config
    echo "✅ Cleanup complete"
}

# Main execution flow
echo "Starting Comprehensive Troubleshooting Workflow"
echo "=============================================="

setup_problematic_scenarios
phase1_initial_assessment
phase2_detailed_diagnosis
phase3_service_diagnosis
phase4_configuration_diagnosis
phase5_resource_diagnosis
phase6_resolution_strategies
final_verification

read -p "Would you like to clean up the troubleshooting demo resources? (y/n): " cleanup
if [[ $cleanup =~ ^[Yy] ]]; then
    cleanup_troubleshooting_demo
fi

echo -e "\n🎉 Troubleshooting Workflow Demo Complete!"
echo -e "\nKey troubleshooting commands to remember:"
echo "kubectl get events --sort-by=.metadata.creationTimestamp"
echo "kubectl describe pod <pod-name>"
echo "kubectl logs <pod-name> --previous"
echo "kubectl top nodes && kubectl top pods"
echo "kubectl get all -o wide"
EOF

chmod +x ~/troubleshooting-workflow.sh
```

### Advanced Troubleshooting Patterns

```bash
# Advanced troubleshooting and debugging patterns
cat > ~/advanced-troubleshooting.sh << 'EOF'
#!/bin/bash

echo "=== Advanced kubectl Troubleshooting Patterns ==="

# Advanced Pattern 1: Network Troubleshooting
demonstrate_network_troubleshooting() {
    echo "1. Network Troubleshooting Patterns"
    echo "================================="
    
    # Create test deployment
    kubectl create deployment network-test --image=nginx:1.21
    kubectl expose deployment network-test --port=80
    kubectl scale deployment network-test --replicas=3
    
    echo "Setting up network troubleshooting scenario..."
    kubectl rollout status deployment/network-test
    
    # Network diagnostic commands
    echo -e "\nNetwork Diagnostic Commands:"
    
    echo -e "\n1. Check service endpoints:"
    kubectl get endpoints network-test -o wide
    
    echo -e "\n2. Check pod IPs and node placement:"
    kubectl get pods -l app=network-test -o custom-columns=\
NAME:.metadata.name,\
STATUS:.status.phase,\
IP:.status.podIP,\
NODE:.spec.nodeName
    
    echo -e "\n3. Check service configuration:"
    kubectl describe service network-test
    
    echo -e "\n4. Test internal DNS resolution:"
    kubectl run dns-test --image=busybox:1.35 --rm -it --restart=Never -- \
        nslookup network-test.default.svc.cluster.local
    
    echo -e "\n5. Test connectivity between pods:"
    POD1=$(kubectl get pods -l app=network-test -o jsonpath='{.items[0].metadata.name}')
    POD2=$(kubectl get pods -l app=network-test -o jsonpath='{.items[1].metadata.name}')
    if [ -n "$POD1" ] && [ -n "$POD2" ]; then
        echo "Testing connectivity from $POD1 to $POD2"
        kubectl exec $POD1 -- ping -c 3 $(kubectl get pod $POD2 -o jsonpath='{.status.podIP}') || true
    fi
    
    echo "✅ Network troubleshooting patterns demonstrated"
    echo
}

# Advanced Pattern 2: Performance Troubleshooting
demonstrate_performance_troubleshooting() {
    echo "2. Performance Troubleshooting Patterns"
    echo "====================================="
    
    # Create resource-intensive deployment
    cat << YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: perf-test
spec:
  replicas: 2
  selector:
    matchLabels:
      app: perf-test
  template:
    metadata:
      labels:
        app: perf-test
    spec:
      containers:
      - name: app
        image: nginx:1.21
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
YAML

    kubectl rollout status deployment/perf-test
    
    echo -e "\nPerformance Diagnostic Commands:"
    
    echo -e "\n1. Check resource usage:"
    kubectl top pods -l app=perf-test || echo "Metrics server not available"
    
    echo -e "\n2. Check resource requests vs limits:"
    kubectl get pods -l app=perf-test -o custom-columns=\
NAME:.metadata.name,\
CPU_REQ:.spec.containers[0].resources.requests.cpu,\
CPU_LIM:.spec.containers[0].resources.limits.cpu,\
MEM_REQ:.spec.containers[0].resources.requests.memory,\
MEM_LIM:.spec.containers[0].resources.limits.memory
    
    echo -e "\n3. Check node resource availability:"
    kubectl describe nodes | grep -E "(Allocatable|Allocated resources)" -A 10
    
    echo -e "\n4. Check for resource pressure events:"
    kubectl get events --field-selector reason=FailedScheduling,reason=Unhealthy | head -10
    
    echo -e "\n5. Analyze pod restart patterns:"
    kubectl get pods -l app=perf-test -o custom-columns=\
NAME:.metadata.name,\
RESTARTS:.status.containerStatuses[0].restartCount,\
LAST_STATE:.status.containerStatuses[0].lastState.terminated.reason
    
    echo "✅ Performance troubleshooting patterns demonstrated"
    echo
}

# Advanced Pattern 3: Storage Troubleshooting
demonstrate_storage_troubleshooting() {
    echo "3. Storage Troubleshooting Patterns"
    echo "================================="
    
    # Create deployment with storage issues
    cat << YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: storage-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: storage-test
  template:
    metadata:
      labels:
        app: storage-test
    spec:
      containers:
      - name: app
        image: nginx:1.21
        volumeMounts:
        - name: data-volume
          mountPath: /data
      volumes:
      - name: data-volume
        persistentVolumeClaim:
          claimName: nonexistent-pvc
YAML

    # Create a working storage example
    cat << YAML | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: working-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: storage-working
spec:
  replicas: 1
  selector:
    matchLabels:
      app: storage-working
  template:
    metadata:
      labels:
        app: storage-working
    spec:
      containers:
      - name: app
        image: nginx:1.21
        volumeMounts:
        - name: data-volume
          mountPath: /data
      volumes:
      - name: data-volume
        persistentVolumeClaim:
          claimName: working-pvc
YAML

    sleep 10  # Allow time for resources to be created
    
    echo -e "\nStorage Diagnostic Commands:"
    
    echo -e "\n1. Check PVC status:"
    kubectl get pvc
    
    echo -e "\n2. Check PV availability:"
    kubectl get pv
    
    echo -e "\n3. Check storage class:"
    kubectl get storageclass
    
    echo -e "\n4. Analyze storage-related events:"
    kubectl get events --field-selector involvedObject.kind=PersistentVolumeClaim
    
    echo -e "\n5. Check pod mount issues:"
    kubectl describe pod -l app=storage-test | grep -E "(Volumes|Mounts|Events)" -A 10
    
    echo -e "\n6. Check successful storage mount:"
    kubectl describe pod -l app=storage-working | grep -E "(Volumes|Mounts)" -A 5
    
    echo "✅ Storage troubleshooting patterns demonstrated"
    echo
}

# Advanced Pattern 4: Security and RBAC Troubleshooting
demonstrate_security_troubleshooting() {
    echo "4. Security and RBAC Troubleshooting"
    echo "=================================="
    
    echo -e "\nSecurity Diagnostic Commands:"
    
    echo -e "\n1. Check current user permissions:"
    kubectl auth can-i --list
    
    echo -e "\n2. Test specific permissions:"
    kubectl auth can-i create pods
    kubectl auth can-i delete services
    kubectl auth can-i get secrets
    
    echo -e "\n3. Check service account permissions:"
    kubectl get serviceaccounts
    kubectl describe serviceaccount default
    
    echo -e "\n4. Check role bindings:"
    kubectl get rolebindings,clusterrolebindings | head -10
    
    echo -e "\n5. Check security contexts:"
    kubectl get pods -o custom-columns=\
NAME:.metadata.name,\
USER:.spec.securityContext.runAsUser,\
GROUP:.spec.securityContext.runAsGroup,\
PRIVILEGED:.spec.containers[0].securityContext.privileged
    
    echo -e "\n6. Check for security policy violations:"
    kubectl get events --field-selector reason=FailedCreate | grep -i security || echo "No security-related failures found"
    
    echo "✅ Security troubleshooting patterns demonstrated"
    echo
}

# Advanced Pattern 5: Application-Level Debugging
demonstrate_application_debugging() {
    echo "5. Application-Level Debugging Patterns"
    echo "====================================="
    
    # Create a problematic application
    cat << YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: debug-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: debug-app
  template:
    metadata:
      labels:
        app: debug-app
    spec:
      containers:
      - name: app
        image: nginx:1.21
        ports:
        - containerPort: 80
        env:
        - name: DEBUG_MODE
          value: "true"
        - name: LOG_LEVEL
          value: "debug"
        readinessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 15
          periodSeconds: 20
YAML

    kubectl rollout status deployment/debug-app
    
    echo -e "\nApplication Debugging Commands:"
    
    echo -e "\n1. Check application logs with context:"
    POD_NAME=$(kubectl get pods -l app=debug-app -o jsonpath='{.items[0].metadata.name}')
    kubectl logs $POD_NAME --timestamps=true --tail=20
    
    echo -e "\n2. Follow logs in real-time with grep filtering:"
    echo "Would run: kubectl logs -f $POD_NAME | grep ERROR"
    
    echo -e "\n3. Check environment variables:"
    kubectl exec $POD_NAME -- env | grep -E "(DEBUG|LOG)"
    
    echo -e "\n4. Check application health endpoints:"
    kubectl exec $POD_NAME -- curl -s localhost/health 2>/dev/null || echo "Health endpoint not available"
    
    echo -e "\n5. Debug container filesystem:"
    kubectl exec $POD_NAME -- ls -la /etc/nginx/
    
    echo -e "\n6. Check probe failures:"
    kubectl describe pod $POD_NAME | grep -E "(Readiness|Liveness)" -A 5
    
    echo -e "\n7. Interactive debugging session:"
    echo "Would run: kubectl exec -it $POD_NAME -- /bin/bash"
    
    echo -e "\n8. Copy files for local analysis:"
    echo "Would run: kubectl cp $POD_NAME:/var/log/nginx/access.log ./access.log"
    
    echo "✅ Application debugging patterns demonstrated"
    echo
}

# Cleanup function
cleanup_advanced_troubleshooting() {
    echo "Cleaning up advanced troubleshooting resources..."
    kubectl delete deployment network-test perf-test storage-test storage-working debug-app
    kubectl delete service network-test
    kubectl delete pvc working-pvc
    echo "✅ Advanced troubleshooting cleanup complete"
}

# Execute all advanced patterns
echo "Starting Advanced Troubleshooting Patterns Demo"
echo "=============================================="

demonstrate_network_troubleshooting
read -p "Press Enter to continue to performance troubleshooting..."

demonstrate_performance_troubleshooting
read -p "Press Enter to continue to storage troubleshooting..."

demonstrate_storage_troubleshooting
read -p "Press Enter to continue to security troubleshooting..."

demonstrate_security_troubleshooting
read -p "Press Enter to continue to application debugging..."

demonstrate_application_debugging

echo -e "\n🎉 Advanced Troubleshooting Patterns Complete!"

read -p "Would you like to clean up all advanced troubleshooting resources? (y/n): " cleanup
if [[ $cleanup =~ ^[Yy] ]]; then
    cleanup_advanced_troubleshooting
fi
EOF

chmod +x ~/advanced-troubleshooting.sh
```

## Advanced Selection and Filtering Techniques

As your Kubernetes usage grows more sophisticated, you'll need advanced techniques for finding and working with specific subsets of resources.

### Foundation Filtering Examples

```bash
# Basic filtering patterns
echo "=== Foundation Filtering Examples ==="

# 1. Label-based filtering
kubectl get pods -l app=nginx                    # Single label
kubectl get pods -l app=nginx,version=v1.0      # Multiple labels
kubectl get pods -l 'environment in (prod,staging)'  # Set-based selectors

# 2. Field-based filtering
kubectl get pods --field-selector=status.phase=Running
kubectl get events --field-selector=involvedObject.kind=Pod
kubectl get nodes --field-selector=spec.unschedulable=false

# 3. Output formatting
kubectl get pods -o wide                         # Extended columns
kubectl get pods -o yaml                         # Full YAML
kubectl get pods -o json                         # Full JSON
kubectl get pods -o name                         # Just names

# 4. Namespace operations
kubectl get pods --all-namespaces               # All namespaces
kubectl get pods -A                             # Short form
kubectl get pods -n production                  # Specific namespace
```

### Demo 7: Advanced Filtering Workshop

```bash
# Advanced filtering and selection workshop
cat > ~/advanced-filtering-workshop.sh << 'EOF'
#!/bin/bash

echo "=== Advanced kubectl Filtering Workshop ==="

# Setup diverse resources for filtering demonstration
setup_filtering_demo() {
    echo "Setting up diverse resources for filtering demo..."
    
    # Create multiple namespaces
    kubectl create namespace production
    kubectl create namespace staging  
    kubectl create namespace development
    
    # Create resources with various labels in different namespaces
    for ns in production staging development; do
        # Create deployments with different labels
        kubectl create deployment web-app-${ns} --image=nginx:1.21 -n $ns
        kubectl create deployment api-server-${ns} --image=node:16 -n $ns
        kubectl create deployment database-${ns} --image=postgres:13 -n $ns
        
        # Add labels
        kubectl label deployment web-app-${ns} app=web tier=frontend environment=$ns -n $ns
        kubectl label deployment api-server-${ns} app=api tier=backend environment=$ns -n $ns
        kubectl label deployment database-${ns} app=db tier=data environment=$ns -n $ns
        
        # Scale deployments differently
        kubectl scale deployment web-app-${ns} --replicas=3 -n $ns
        kubectl scale deployment api-server-${ns} --replicas=2 -n $ns
        kubectl scale deployment database-${ns} --replicas=1 -n $ns
        
        # Create services
        kubectl expose deployment web-app-${ns} --port=80 -n $ns
        kubectl expose deployment api-server-${ns} --port=3000 -n $ns
    done
    
    # Create ConfigMaps and Secrets with labels
    for ns in production staging development; do
        kubectl create configmap app-config --from-literal=env=$ns -n $ns
        kubectl create secret generic app-secret --from-literal=key=secret-$ns -n $ns
        kubectl label configmap app-config environment=$ns -n $ns
        kubectl label secret app-secret environment=$ns -n $ns
    done
    
    # Wait for resources to be ready
    echo "Waiting for resources to be ready..."
    sleep 10
    
    echo "✅ Demo resources created"
}

# Workshop 1: Basic Label Selectors
workshop_basic_selectors() {
    echo -e "\n=== Workshop 1: Basic Label Selectors ==="
    
    echo "1. Single label selection:"
    echo "Command: kubectl get pods -l app=web --all-namespaces"
    kubectl get pods -l app=web --all-namespaces
    
    echo -e "\n2. Multiple label selection (AND logic):"
    echo "Command: kubectl get pods -l app=web,tier=frontend --all-namespaces"
    kubectl get pods -l app=web,tier=frontend --all-namespaces
    
    echo -e "\n3. Label existence check:"
    echo "Command: kubectl get pods -l environment --all-namespaces"
    kubectl get pods -l environment --all-namespaces
    
    echo -e "\n4. Label non-existence check:"
    echo "Command: kubectl get pods -l '!version' --all-namespaces | head -10"
    kubectl get pods -l '!version' --all-namespaces | head -10
    
    read -p "Press Enter to continue to advanced selectors..."
}

# Workshop 2: Advanced Label Selectors
workshop_advanced_selectors() {
    echo -e "\n=== Workshop 2: Advanced Label Selectors ==="
    
    echo "1. Set-based selection (IN operator):"
    echo "Command: kubectl get pods -l 'environment in (production,staging)' --all-namespaces"
    kubectl get pods -l 'environment in (production,staging)' --all-namespaces
    
    echo -e "\n2. Set-based selection (NOTIN operator):"
    echo "Command: kubectl get pods -l 'tier notin (data)' --all-namespaces | head -10"
    kubectl get pods -l 'tier notin (data)' --all-namespaces | head -10
    
    echo -e "\n3. Inequality selection:"
    echo "Command: kubectl get pods -l 'environment!=development' --all-namespaces | head -10"
    kubectl get pods -l 'environment!=development' --all-namespaces | head -10
    
    echo -e "\n4. Complex combined selectors:"
    echo "Command: kubectl get pods -l 'app=web,environment in (production,staging)' --all-namespaces"
    kubectl get pods -l 'app=web,environment in (production,staging)' --all-namespaces
    
    read -p "Press Enter to continue to field selectors..."
}

# Workshop 3: Field Selectors
workshop_field_selectors() {
    echo -e "\n=== Workshop 3: Field Selectors ==="
    
    echo "1. Filter by pod phase:"
    echo "Command: kubectl get pods --field-selector=status.phase=Running --all-namespaces | head -10"
    kubectl get pods --field-selector=status.phase=Running --all-namespaces | head -10
    
    echo -e "\n2. Filter by node assignment:"
    echo "Command: kubectl get pods --field-selector=spec.nodeName!='' --all-namespaces | head -10"
    kubectl get pods --field-selector=spec.nodeName!='' --all-namespaces | head -10
    
    echo -e "\n3. Filter events by object kind:"
    echo "Command: kubectl get events --field-selector=involvedObject.kind=Deployment | head -5"
    kubectl get events --field-selector=involvedObject.kind=Deployment | head -5
    
    echo -e "\n4. Filter services by type:"
    echo "Command: kubectl get services --field-selector=spec.type=ClusterIP --all-namespaces"
    kubectl get services --field-selector=spec.type=ClusterIP --all-namespaces
    
    echo -e "\n5. Combine field and label selectors:"
    echo "Command: kubectl get pods --field-selector=status.phase=Running -l environment=production"
    kubectl get pods --field-selector=status.phase=Running -l environment=production
    
    read -p "Press Enter to continue to output formatting..."
}

# Workshop 4: Advanced Output Formatting
workshop_output_formatting() {
    echo -e "\n=== Workshop 4: Advanced Output Formatting ==="
    
    echo "1. Custom columns:"
    echo "Command: Custom deployment overview"
    kubectl get deployments --all-namespaces -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
REPLICAS:.spec.replicas,\
READY:.status.readyReplicas,\
IMAGES:.spec.template.spec.containers[0].image
    
    echo -e "\n2. JSONPath queries - Extract specific data:"
    echo "Command: Get all deployment names"
    kubectl get deployments --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}'
    
    echo -e "\n3. Complex JSONPath - Resource summary:"
    echo "Command: Environment and replica summary"
    kubectl get deployments --all-namespaces -o jsonpath='{range .items[*]}{.metadata.labels.environment}{"\t"}{.spec.replicas}{"\n"}{end}' | sort
    
    echo -e "\n4. Sort by different fields:"
    echo "Command: Sort pods by creation time"
    kubectl get pods --all-namespaces --sort-by=.metadata.creationTimestamp | tail -10
    
    echo -e "\n5. Wide output with additional columns:"
    echo "Command: Extended pod information"
    kubectl get pods --all-namespaces -o wide | head -10
    
    read -p "Press Enter to continue to automation patterns..."
}

# Workshop 5: Automation and Scripting Patterns
workshop_automation_patterns() {
    echo -e "\n=== Workshop 5: Automation and Scripting Patterns ==="
    
    echo "1. Loop through resources with specific labels:"
    echo "Script: Scale all frontend deployments"
    for deployment in $(kubectl get deployments --all-namespaces -l tier=frontend -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{" "}{end}'); do
        ns=$(echo $deployment | cut -d'/' -f1)
        name=$(echo $deployment | cut -d'/' -f2)
        echo "Scaling $name in $ns to 4 replicas"
        kubectl scale deployment $name --replicas=4 -n $ns
    done
    
    echo -e "\n2. Generate report of resources by environment:"
    echo "Script: Environment resource summary"
    for env in production staging development; do
        echo "Environment: $env"
        echo "  Deployments: $(kubectl get deployments -l environment=$env --all-namespaces --no-headers | wc -l)"
        echo "  Pods: $(kubectl get pods -l environment=$env --all-namespaces --no-headers | wc -l)"
        echo "  Services: $(kubectl get services -l environment=$env --all-namespaces --no-headers | wc -l)"
        echo
    done
    
    echo -e "\n3. Find resources with specific patterns:"
    echo "Script: Find all web-related resources"
    echo "Deployments with 'web' in name:"
    kubectl get deployments --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name --no-headers | grep web
    
    echo -e "\nServices with 'web' in name:"
    kubectl get services --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name --no-headers | grep web
    
    echo -e "\n4. Resource utilization summary:"
    echo "Script: Deployment replica summary"
    kubectl get deployments --all-namespaces -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
DESIRED:.spec.replicas,\
READY:.status.readyReplicas | \
awk 'NR>1 {desired+=$3; ready+=$4} END {print "Total Desired: " desired ", Total Ready: " ready}'
    
    read -p "Press Enter to continue to watch and monitoring patterns..."
}

# Workshop 6: Watch and Monitoring Patterns
workshop_watch_patterns() {
    echo -e "\n=== Workshop 6: Watch and Monitoring Patterns ==="
    
    echo "1. Watch specific resources (5 seconds demonstration):"
    echo "Command: kubectl get pods -l app=web --all-namespaces --watch"
    timeout 5s kubectl get pods -l app=web --all-namespaces --watch || true
    
    echo -e "\n2. Watch with output formatting:"
    echo "Command: Watch deployments with custom columns (5 seconds)"
    timeout 5s kubectl get deployments --all-namespaces --watch -o custom-columns=\
NAMESPACE:.metadata.namespace,NAME:.metadata.name,REPLICAS:.spec.replicas,READY:.status.readyReplicas || true
    
    echo -e "\n3. Monitor events in real-time:"
    echo "Command: Watch recent events (5 seconds)"
    timeout 5s kubectl get events --watch --sort-by=.metadata.creationTimestamp || true
    
    echo -e "\n4. Resource comparison over time:"
    echo "Script: Before and after comparison"
    echo "Before scaling:"
    kubectl get deployments -l tier=frontend --all-namespaces -o custom-columns=NAME:.metadata.name,REPLICAS:.spec.replicas
    
    echo -e "\nScaling frontend deployments to 2 replicas..."
    kubectl get deployments -l tier=frontend --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{" "}{end}' | \
    xargs -n1 -I{} bash -c 'ns=$(echo {} | cut -d/ -f1); name=$(echo {} | cut -d/ -f2); kubectl scale deployment $name --replicas=2 -n $ns'
    
    sleep 5
    echo "After scaling:"
    kubectl get deployments -l tier=frontend --all-namespaces -o custom-columns=NAME:.metadata.name,REPLICAS:.spec.replicas
    
    read -p "Press Enter to finish the workshop..."
}

# Cleanup function
cleanup_filtering_workshop() {
    echo -e "\nCleaning up filtering workshop resources..."
    kubectl delete namespace production staging development
    echo "✅ Filtering workshop cleanup complete"
}

# Execute the complete workshop
echo "Starting Advanced Filtering Workshop"
echo "==================================="

setup_filtering_demo
workshop_basic_selectors
workshop_advanced_selectors
workshop_field_selectors
workshop_output_formatting
workshop_automation_patterns
workshop_watch_patterns

echo -e "\n🎉 Advanced Filtering Workshop Complete!"

read -p "Would you like to clean up all workshop resources? (y/n): " cleanup
if [[ $cleanup =~ ^[Yy] ]]; then
    cleanup_filtering_workshop
fi
EOF

chmod +x ~/advanced-filtering-workshop.sh
```

## Mini-Projects: Real-World kubectl Applications

Let's create comprehensive mini-projects that demonstrate kubectl usage in realistic scenarios.

### Mini-Project 1: Complete Microservices Application

```bash
# Mini-Project 1: Deploy and manage a complete microservices application
cat > ~/microservices-project.sh << 'EOF'
#!/bin/bash

echo "=== Mini-Project 1: Complete Microservices Application ==="

PROJECT_NAME="ecommerce-microservices"
BASE_NAMESPACE="ecommerce"

# Project Phase 1: Environment Setup
setup_project_environment() {
    echo "Phase 1: Setting up project environment"
    echo "======================================"
    
    # Create namespaces for different environments
    for env in production staging development; do
        kubectl create namespace ${BASE_NAMESPACE}-${env}
        
        # Add labels for organization
        kubectl label namespace ${BASE_NAMESPACE}-${env} project=$PROJECT_NAME
        kubectl label namespace ${BASE_NAMESPACE}-${env} environment=$env
    done
    
    # Set context to development for initial work
    kubectl config set-context --current --namespace=${BASE_NAMESPACE}-development
    
    echo "✅ Project environment ready"
    echo "Working namespace: ${BASE_NAMESPACE}-development"
}

# Project Phase 2: Deploy Core Infrastructure
deploy_infrastructure() {
    echo -e "\nPhase 2: Deploying core infrastructure"
    echo "====================================="
    
    # Deploy MongoDB database
    echo "Deploying MongoDB database..."
    cat << YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mongodb
  labels:
    app: mongodb
    tier: database
    component: storage
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mongodb
  template:
    metadata:
      labels:
        app: mongodb
        tier: database
        component: storage
    spec:
      containers:
      - name: mongodb
        image: mongo:5.0
        ports:
        - containerPort: 27017
        env:
        - name: MONGO_INITDB_ROOT_USERNAME
          value: admin
        - name: MONGO_INITDB_ROOT_PASSWORD
          value: password123
        volumeMounts:
        - name: mongodb-storage
          mountPath: /data/db
      volumes:
      - name: mongodb-storage
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: mongodb-service
  labels:
    app: mongodb
spec:
  ports:
  - port: 27017
    targetPort: 27017
  selector:
    app: mongodb
YAML

    # Deploy Redis cache
    echo "Deploying Redis cache..."
    cat << YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  labels:
    app: redis
    tier: cache
    component: cache
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
        tier: cache
        component: cache
    spec:
      containers:
      - name: redis
        image: redis:6.2
        ports:
        - containerPort: 6379
        command: ["redis-server"]
        args: ["--requirepass", "redis123"]
---
apiVersion: v1
kind: Service
metadata:
  name: redis-service
  labels:
    app: redis
spec:
  ports:
  - port: 6379
    targetPort: 6379
  selector:
    app: redis
YAML

    # Wait for infrastructure to be ready
    echo "Waiting for infrastructure to be ready..."
    kubectl rollout status deployment/mongodb
    kubectl rollout status deployment/redis
    
    echo "✅ Core infrastructure deployed"
}

# Project Phase 3: Deploy Microservices
deploy_microservices() {
    echo -e "\nPhase 3: Deploying microservices"
    echo "==============================="
    
    # Deploy User Service
    echo "Deploying User Service..."
    cat << YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
  labels:
    app: user-service
    tier: backend
    component: microservice
spec:
  replicas: 2
  selector:
    matchLabels:
      app: user-service
  template:
    metadata:
      labels:
        app: user-service
        tier: backend
        component: microservice
    spec:
      containers:
      - name: user-service
        image: node:16-alpine
        ports:
        - containerPort: 3000
        env:
        - name: SERVICE_NAME
          value: "user-service"
        - name: DATABASE_URL
          value: "mongodb://admin:password123@mongodb-service:27017/userdb"
        - name: REDIS_URL
          value: "redis://:redis123@redis-service:6379"
        - name: PORT
          value: "3000"
        command: ["node"]
        args: ["-e", "const express = require('express'); const app = express(); app.get('/health', (req, res) => res.json({service: process.env.SERVICE_NAME, status: 'healthy'})); app.get('/users', (req, res) => res.json({users: ['alice', 'bob', 'charlie']})); app.listen(process.env.PORT, () => console.log('User service running on port', process.env.PORT));"]
        readinessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 15
          periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: user-service
  labels:
    app: user-service
spec:
  ports:
  - port: 3000
    targetPort: 3000
  selector:
    app: user-service
YAML

    # Deploy Product Service
    echo "Deploying Product Service..."
    cat << YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: product-service
  labels:
    app: product-service
    tier: backend
    component: microservice
spec:
  replicas: 3
  selector:
    matchLabels:
      app: product-service
  template:
    metadata:
      labels:
        app: product-service
        tier: backend
        component: microservice
    spec:
      containers:
      - name: product-service
        image: node:16-alpine
        ports:
        - containerPort: 3001
        env:
        - name: SERVICE_NAME
          value: "product-service"
        - name: DATABASE_URL
          value: "mongodb://admin:password123@mongodb-service:27017/productdb"
        - name: REDIS_URL
          value: "redis://:redis123@redis-service:6379"
        - name: PORT
          value: "3001"
        command: ["node"]
        args: ["-e", "const express = require('express'); const app = express(); app.get('/health', (req, res) => res.json({service: process.env.SERVICE_NAME, status: 'healthy'})); app.get('/products', (req, res) => res.json({products: [{id: 1, name: 'laptop'}, {id: 2, name: 'phone'}]})); app.listen(process.env.PORT, () => console.log('Product service running on port', process.env.PORT));"]
        readinessProbe:
          httpGet:
            path: /health
            port: 3001
          initialDelaySeconds: 10
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /health
            port: 3001
          initialDelaySeconds: 15
          periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: product-service
  labels:
    app: product-service
spec:
  ports:
  - port: 3001
    targetPort: 3001
  selector:
    app: product-service
YAML

    # Deploy API Gateway
    echo "Deploying API Gateway..."
    cat << YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
  labels:
    app: api-gateway
    tier: frontend
    component: gateway
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api-gateway
  template:
    metadata:
      labels:
        app: api-gateway
        tier: frontend
        component: gateway
    spec:
      containers:
      - name: api-gateway
        image: nginx:1.21
        ports:
        - containerPort: 80
        volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/conf.d
      volumes:
      - name: nginx-config
        configMap:
          name: nginx-gateway-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-gateway-config
data:
  default.conf: |
    upstream user-service {
        server user-service:3000;
    }
    
    upstream product-service {
        server product-service:3001;
    }
    
    server {
        listen 80;
        
        location /api/users {
            proxy_pass http://user-service/users;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
        }
        
        location /api/products {
            proxy_pass http://product-service/products;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
        }
        
        location /health {
            return 200 '{"status":"healthy","service":"api-gateway"}';
            add_header Content-Type application/json;
        }
    }
---
apiVersion: v1
kind: Service
metadata:
  name: api-gateway
  labels:
    app: api-gateway
spec:
  type: NodePort
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
  selector:
    app: api-gateway
YAML

    # Wait for services to be ready
    echo "Waiting for microservices to be ready..."
    kubectl rollout status deployment/user-service
    kubectl rollout status deployment/product-service
    kubectl rollout status deployment/api-gateway
    
    echo "✅ Microservices deployed"
}

# Project Phase 4: Configuration Management
setup_configuration() {
    echo -e "\nPhase 4: Setting up configuration management"
    echo "==========================================="
    
    # Create application configuration
    kubectl create configmap app-config \
        --from-literal=log_level=info \
        --from-literal=database_pool_size=10 \
        --from-literal=cache_ttl=300 \
        --from-literal=api_version=v1.0.0
    
    # Create secrets for sensitive data
    kubectl create secret generic app-secrets \
        --from-literal=jwt_secret=super-secret-jwt-key \
        --from-literal=encryption_key=my-encryption-key-32-chars \
        --from-literal=external_api_key=external-service-api-key
    
    # Create TLS secret for HTTPS (dummy cert)
    kubectl create secret tls tls-secret \
        --cert=/dev/null \
        --key=/dev/null \
        --dry-run=client -o yaml | \
        kubectl apply -f - 2>/dev/null || echo "TLS secret creation skipped"
    
    echo "✅ Configuration management setup complete"
}

# Project Phase 5: Monitoring and Observability
setup_monitoring() {
    echo -e "\nPhase 5: Setting up monitoring and observability"
    echo "=============================================="
    
    # Deploy Prometheus monitoring (simplified)
    cat << YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  labels:
    app: prometheus
    component: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
        component: monitoring
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:latest
        ports:
        - containerPort: 9090
        args:
          - '--config.file=/etc/prometheus/prometheus.yml'
          - '--storage.tsdb.path=/prometheus/'
        volumeMounts:
        - name: prometheus-config
          mountPath: /etc/prometheus/
        - name: prometheus-storage
        emptyDir: {}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
    scrape_configs:
      - job_name: 'kubernetes-pods'
        kubernetes_sd_configs:
        - role: pod
        relabel_configs:
        - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
          action: keep
          regex: true
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus-service
  labels:
    app: prometheus
spec:
  ports:
  - port: 9090
    targetPort: 9090
  selector:
    app: prometheus
YAML

    kubectl rollout status deployment/prometheus
    echo "✅ Monitoring setup complete"
}

# Project Phase 6: Testing and Validation
test_application() {
    echo -e "\nPhase 6: Testing and validation"
    echo "=============================="
    
    echo "1. Testing service connectivity..."
    
    # Test internal service connectivity
    kubectl run test-pod --image=curlimages/curl:latest --rm -it --restart=Never -- \
        sh -c "
        echo 'Testing User Service:';
        curl -s http://user-service:3000/health | head -3;
        echo '';
        echo 'Testing Product Service:';
        curl -s http://product-service:3001/health | head -3;
        echo '';
        echo 'Testing API Gateway:';
        curl -s http://api-gateway/health | head -3;
        " || echo "Internal connectivity test completed"
    
    echo -e "\n2. Service discovery verification..."
    kubectl get endpoints
    
    echo -e "\n3. DNS resolution test..."
    kubectl run dns-test --image=busybox:1.35 --rm -it --restart=Never -- \
        sh -c "
        nslookup user-service;
        nslookup product-service;
        nslookup api-gateway;
        " || echo "DNS test completed"
    
    echo -e "\n4. Application health check..."
    for service in user-service product-service api-gateway; do
        echo "Checking $service health..."
        kubectl exec deployment/$service -- curl -s http://localhost/health 2>/dev/null || \
        kubectl exec deployment/$service -- wget -q -O- http://localhost:3000/health 2>/dev/null || \
        kubectl exec deployment/$service -- wget -q -O- http://localhost:3001/health 2>/dev/null || \
        echo "$service health check completed"
    done
    
    echo "✅ Testing and validation complete"
}

# Project Phase 7: Scaling and Performance
demonstrate_scaling() {
    echo -e "\nPhase 7: Scaling and performance demonstration"
    echo "============================================="
    
    echo "1. Current resource status:"
    kubectl get deployments -o custom-columns=\
NAME:.metadata.name,\
REPLICAS:.spec.replicas,\
READY:.status.readyReplicas,\
AVAILABLE:.status.availableReplicas
    
    echo -e "\n2. Scaling services based on demand..."
    
    # Scale product service for high demand
    echo "Scaling product service for high demand..."
    kubectl scale deployment product-service --replicas=5
    kubectl rollout status deployment/product-service
    
    # Scale user service moderately
    echo "Scaling user service..."
    kubectl scale deployment user-service --replicas=3
    kubectl rollout status deployment/user-service
    
    # Scale API gateway for load balancing
    echo "Scaling API gateway..."
    kubectl scale deployment api-gateway --replicas=4
    kubectl rollout status deployment/api-gateway
    
    echo -e "\n3. After scaling status:"
    kubectl get deployments -o custom-columns=\
NAME:.metadata.name,\
REPLICAS:.spec.replicas,\
READY:.status.readyReplicas,\
AVAILABLE:.status.availableReplicas
    
    echo -e "\n4. Resource distribution across nodes:"
    kubectl get pods -o custom-columns=\
NAME:.metadata.name,\
NODE:.spec.nodeName,\
STATUS:.status.phase | sort -k2
    
    echo "✅ Scaling demonstration complete"
}

# Project Phase 8: Environment Promotion
promote_to_staging() {
    echo -e "\nPhase 8: Environment promotion to staging"
    echo "========================================"
    
    echo "Promoting application to staging environment..."
    
    # Switch to staging namespace
    kubectl config set-context --current --namespace=${BASE_NAMESPACE}-staging
    
    # Export development resources and modify for staging
    echo "Exporting development configuration..."
    
    # Get all deployments from development and apply to staging with modifications
    for deployment in mongodb redis user-service product-service api-gateway; do
        echo "Promoting $deployment to staging..."
        
        # Export from development
        kubectl get deployment $deployment -n ${BASE_NAMESPACE}-development -o yaml | \
        # Remove cluster-specific fields
        grep -v '^\s*uid:\|^\s*resourceVersion:\|^\s*selfLink:\|^\s*creationTimestamp:\|^\s*generation:\|^\s*status:' | \
        # Update namespace references
        sed "s/${BASE_NAMESPACE}-development/${BASE_NAMESPACE}-staging/g" | \
        # Apply to staging
        kubectl apply -f -
        
        # Export and promote services
        kubectl get service $deployment -n ${BASE_NAMESPACE}-development -o yaml 2>/dev/null | \
        grep -v '^\s*uid:\|^\s*resourceVersion:\|^\s*selfLink:\|^\s*creationTimestamp:\|^\s*clusterIP:\|^\s*clusterIPs:' | \
        sed "s/${BASE_NAMESPACE}-development/${BASE_NAMESPACE}-staging/g" | \
        kubectl apply -f - 2>/dev/null || true
    done
    
    # Export ConfigMaps and Secrets
    for resource in configmap secret; do
        for name in $(kubectl get $resource -n ${BASE_NAMESPACE}-development --no-headers -o custom-columns=NAME:.metadata.name); do
            if [[ ! $name =~ ^default-token ]]; then
                echo "Promoting $resource $name to staging..."
                kubectl get $resource $name -n ${BASE_NAMESPACE}-development -o yaml | \
                grep -v '^\s*uid:\|^\s*resourceVersion:\|^\s*selfLink:\|^\s*creationTimestamp:' | \
                sed "s/${BASE_NAMESPACE}-development/${BASE_NAMESPACE}-staging/g" | \
                kubectl apply -f -
            fi
        done
    done
    
    echo "Waiting for staging deployment to be ready..."
    sleep 10
    
    echo -e "\nStaging environment status:"
    kubectl get all -n ${BASE_NAMESPACE}-staging
    
    echo "✅ Environment promotion complete"
}

# Project Phase 9: Backup and Disaster Recovery
demonstrate_backup_recovery() {
    echo -e "\nPhase 9: Backup and disaster recovery"
    echo "===================================="
    
    # Create backup directory
    mkdir -p ~/microservices-backup
    
    echo "Creating backup of application configuration..."
    
    # Backup all resources from all environments
    for env in development staging production; do
        echo "Backing up ${BASE_NAMESPACE}-${env}..."
        
        # Create environment backup directory
        mkdir -p ~/microservices-backup/${env}
        
        # Backup different resource types
        for resource in deployment service configmap secret; do
            echo "  Backing up ${resource}s..."
            kubectl get $resource -n ${BASE_NAMESPACE}-${env} -o yaml > ~/microservices-backup/${env}/${resource}s.yaml 2>/dev/null || true
        done
        
        # Backup namespace definition
        kubectl get namespace ${BASE_NAMESPACE}-${env} -o yaml > ~/microservices-backup/${env}/namespace.yaml 2>/dev/null || true
    done
    
    echo -e "\nBackup created in ~/microservices-backup/"
    ls -la ~/microservices-backup/
    
    echo -e "\nDemonstrating disaster recovery..."
    
    # Simulate disaster - delete staging environment
    echo "Simulating disaster - deleting staging environment..."
    kubectl delete namespace ${BASE_NAMESPACE}-staging
    
    # Wait for deletion
    sleep 10
    
    # Recover from backup
    echo "Recovering staging environment from backup..."
    
    # Recreate namespace
    kubectl apply -f ~/microservices-backup/staging/namespace.yaml
    
    # Restore resources
    for resource in configmap secret deployment service; do
        if [ -f ~/microservices-backup/staging/${resource}s.yaml ]; then
            echo "Restoring ${resource}s..."
            kubectl apply -f ~/microservices-backup/staging/${resource}s.yaml
        fi
    done
    
    echo "Waiting for recovery to complete..."
    sleep 15
    
    echo -e "\nRecovered staging environment:"
    kubectl get all -n ${BASE_NAMESPACE}-staging
    
    echo "✅ Backup and recovery demonstration complete"
}

# Project Phase 10: Cleanup and Documentation
project_documentation() {
    echo -e "\nPhase 10: Project documentation and cleanup"
    echo "=========================================="
    
    # Generate comprehensive project report
    cat > ~/microservices-project-report.md << DOC
# E-commerce Microservices Project Report

## Project Overview
- **Project Name**: $PROJECT_NAME
- **Environments**: Development, Staging, Production
- **Architecture**: Microservices with API Gateway
- **Database**: MongoDB
- **Cache**: Redis
- **Monitoring**: Prometheus

## Deployed Services

### Infrastructure Components
\`\`\`bash
# Database
kubectl get deployment mongodb --all-namespaces
kubectl get service mongodb-service --all-namespaces

# Cache
kubectl get deployment redis --all-namespaces  
kubectl get service redis-service --all-namespaces
\`\`\`

### Microservices
\`\`\`bash
# User Service
kubectl get deployment user-service --all-namespaces
kubectl get service user-service --all-namespaces

# Product Service  
kubectl get deployment product-service --all-namespaces
kubectl get service product-service --all-namespaces

# API Gateway
kubectl get deployment api-gateway --all-namespaces
kubectl get service api-gateway --all-namespaces
\`\`\`

## Resource Summary
DOC

    echo -e "\nGenerating resource summary..."
    
    for env in development staging; do
        echo -e "\n### ${env^} Environment" >> ~/microservices-project-report.md
        echo '```' >> ~/microservices-project-report.md
        kubectl get all -n ${BASE_NAMESPACE}-${env} >> ~/microservices-project-report.md 2>/dev/null || true
        echo '```' >> ~/microservices-project-report.md
    done
    
    cat >> ~/microservices-project-report.md << DOC

## Management Commands

### Scaling Commands
\`\`\`bash
# Scale individual services
kubectl scale deployment user-service --replicas=3 -n ${BASE_NAMESPACE}-development
kubectl scale deployment product-service --replicas=5 -n ${BASE_NAMESPACE}-development
kubectl scale deployment api-gateway --replicas=4 -n ${BASE_NAMESPACE}-development
\`\`\`

### Monitoring Commands
\`\`\`bash
# Check service health
kubectl get pods --all-namespaces -l component=microservice
kubectl get services --all-namespaces -l app in (user-service,product-service,api-gateway)

# View logs
kubectl logs deployment/user-service -n ${BASE_NAMESPACE}-development
kubectl logs deployment/product-service -n ${BASE_NAMESPACE}-development
kubectl logs deployment/api-gateway -n ${BASE_NAMESPACE}-development
\`\`\`

### Troubleshooting Commands
\`\`\`bash
# Check pod status
kubectl get pods --all-namespaces -l project=$PROJECT_NAME

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp --all-namespaces

# Debug connectivity
kubectl run debug-pod --image=curlimages/curl:latest --rm -it --restart=Never -- sh
\`\`\`

## Cleanup Commands
\`\`\`bash
# Clean up all environments
kubectl delete namespace ${BASE_NAMESPACE}-development
kubectl delete namespace ${BASE_NAMESPACE}-staging  
kubectl delete namespace ${BASE_NAMESPACE}-production

# Remove backup
rm -rf ~/microservices-backup
\`\`\`
DOC

    echo "📖 Project documentation created: ~/microservices-project-report.md"
    
    # Display final project status
    echo -e "\n=== Final Project Status ==="
    echo "Namespaces:"
    kubectl get namespaces -l project=$PROJECT_NAME
    
    echo -e "\nAll project resources:"
    kubectl get all --all-namespaces -l project=$PROJECT_NAME 2>/dev/null || \
    kubectl get all -n ${BASE_NAMESPACE}-development -n ${BASE_NAMESPACE}-staging 2>/dev/null || \
    echo "Project resources summary not available"
    
    echo "✅ Project documentation complete"
}

# Cleanup function
cleanup_microservices_project() {
    echo -e "\n=== Project Cleanup ==="
    
    # Reset context
    kubectl config set-context --current --namespace=default
    
    # Delete all project namespaces
    kubectl delete namespace ${BASE_NAMESPACE}-development ${BASE_NAMESPACE}-staging ${BASE_NAMESPACE}-production 2>/dev/null || true
    
    # Clean up backup
    rm -rf ~/microservices-backup
    
    echo "✅ Microservices project cleanup complete"
}

# Main project execution
echo "Starting Complete Microservices Application Project"
echo "=================================================="

setup_project_environment
deploy_infrastructure
deploy_microservices
setup_configuration
setup_monitoring
test_application
demonstrate_scaling
promote_to_staging
demonstrate_backup_recovery
project_documentation

echo -e "\n🎉 Microservices Project Complete!"
echo "=================================================="
echo "✅ Multi-environment setup (dev, staging, production)"
echo "✅ Complete microservices architecture deployed"
echo "✅ Infrastructure components (MongoDB, Redis, Prometheus)"
echo "✅ API Gateway with service routing"
echo "✅ Configuration and secrets management"
echo "✅ Scaling demonstrations"
echo "✅ Environment promotion workflow"
echo "✅ Backup and disaster recovery"
echo "✅ Comprehensive documentation"

echo -e "\nProject artifacts created:"
echo "📖 ~/microservices-project-report.md - Complete project documentation"
echo "💾 ~/microservices-backup/ - Configuration backups"

echo -e "\nExplore your deployment:"
echo "kubectl get all -n ${BASE_NAMESPACE}-development"
echo "kubectl get all -n ${BASE_NAMESPACE}-staging"

read -p "Would you like to clean up the entire project? (y/n): " cleanup
if [[ $cleanup =~ ^[Yy] ]]; then
    cleanup_microservices_project
fi
EOF

chmod +x ~/microservices-project.sh
```

### Mini-Project 2: DevOps CI/CD Pipeline Simulation

```bash
# Mini-Project 2: DevOps CI/CD Pipeline with kubectl
cat > ~/devops-pipeline-project.sh << 'EOF'
#!/bin/bash

echo "=== Mini-Project 2: DevOps CI/CD Pipeline Simulation ==="

PIPELINE_PROJECT="devops-pipeline"
APP_NAME="web-application"

# Phase 1: Pipeline Infrastructure Setup
setup_pipeline_infrastructure() {
    echo "Phase 1: Setting up CI/CD pipeline infrastructure"
    echo "=============================================="
    
    # Create namespaces for different stages
    kubectl create namespace cicd-tools
    kubectl create namespace development
    kubectl create namespace staging
    kubectl create namespace production
    
    # Label namespaces for organization
    kubectl label namespace cicd-tools purpose=cicd project=$PIPELINE_PROJECT
    kubectl label namespace development environment=dev project=$PIPELINE_PROJECT
    kubectl label namespace staging environment=staging project=$PIPELINE_PROJECT
    kubectl label namespace production environment=prod project=$PIPELINE_PROJECT
    
    # Deploy Jenkins (simulated CI/CD server)
    echo "Deploying CI/CD server (Jenkins simulation)..."
    cat << YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jenkins
  namespace: cicd-tools
  labels:
    app: jenkins
    component: ci-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jenkins
  template:
    metadata:
      labels:
        app: jenkins
        component: ci-server
    spec:
      containers:
      - name: jenkins
        image: jenkins/jenkins:lts
        ports:
        - containerPort: 8080
        - containerPort: 50000
        env:
        - name: JAVA_OPTS
          value: "-Djenkins.install.runSetupWizard=false"
        volumeMounts:
        - name: jenkins-data
          mountPath: /var/jenkins_home
      volumes:
      - name: jenkins-data
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: jenkins-service
  namespace: cicd-tools
  labels:
    app: jenkins
spec:
  type: NodePort
  ports:
  - port: 8080
    targetPort: 8080
    nodePort: 30808
    name: web
  - port: 50000
    targetPort: 50000
    name: slave
  selector:
    app: jenkins
YAML

    # Deploy Artifactory (simulated artifact repository)
    echo "Deploying artifact repository..."
    cat << YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: artifactory
  namespace: cicd-tools
  labels:
    app: artifactory
    component: artifact-repo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: artifactory
  template:
    metadata:
      labels:
        app: artifactory
        component: artifact-repo
    spec:
      containers:
      - name: artifactory
        image: nginx:1.21
        ports:
        - containerPort: 80
        volumeMounts:
        - name: artifacts
          mountPath: /usr/share/nginx/html
        - name: nginx-config
          mountPath: /etc/nginx/conf.d
      volumes:
      - name: artifacts
        emptyDir: {}
      - name: nginx-config
        configMap:
          name: artifactory-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: artifactory-config
  namespace: cicd-tools
data:
  default.conf: |
    server {
        listen 80;
        server_name artifactory;
        
        location / {
            autoindex on;
            autoindex_exact_size off;
            autoindex_localtime on;
        }
        
        location /health {
            return 200 '{"status":"healthy","service":"artifactory"}';
            add_header Content-Type application/json;
        }
    }
---
apiVersion: v1
kind: Service
metadata:
  name: artifactory-service
  namespace: cicd-tools
  labels:
    app: artifactory
spec:
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: artifactory
YAML

    kubectl rollout status deployment/jenkins -n cicd-tools
    kubectl rollout status deployment/artifactory -n cicd-tools
    
    echo "✅ Pipeline infrastructure ready"
}

# Phase 2: Application Version Management
setup_version_management() {
    echo -e "\nPhase 2: Application version management"
    echo "====================================="
    
    # Create version tracking ConfigMap
    kubectl create configmap version-tracker -n cicd-tools \
        --from-literal=current_version=1.0.0 \
        --from-literal=build_number=1 \
        --from-literal=git_commit=abc123def \
        --from-literal=release_notes="Initial release"
    
    # Create deployment template for different versions
    create_app_version() {
        local version=$1
        local environment=$2
        local replicas=$3
        local namespace=$4
        
        cat << YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${APP_NAME}-${version}
  namespace: $namespace
  labels:
    app: $APP_NAME
    version: $version
    environment: $environment
spec:
  replicas: $replicas
  selector:
    matchLabels:
      app: $APP_NAME
      version: $version
  template:
    metadata:
      labels:
        app: $APP_NAME
        version: $version
        environment: $environment
    spec:
      containers:
      - name: web-app
        image: nginx:1.21
        ports:
        - containerPort: 80
        env:
        - name: APP_VERSION
          value: "$version"
        - name: ENVIRONMENT
          value: "$environment"
        volumeMounts:
        - name: app-content
          mountPath: /usr/share/nginx/html
      volumes:
      - name: app-content
        configMap:
          name: app-content-$version
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-content-$version
  namespace: $namespace
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>Web Application v$version</title>
        <style>
            body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
            .version { color: #007acc; font-size: 2em; }
            .environment { color: #28a745; font-size: 1.5em; }
        </style>
    </head>
    <body>
        <h1>Web Application</h1>
        <p class="version">Version: $version</p>
        <p class="environment">Environment: $environment</p>
        <p>Build: $(date)</p>
        <p>Features in this version:</p>
        <ul>
            <li>Basic web interface</li>
            <li>Health monitoring</li>
            <li>Version tracking</li>
        </ul>
    </body>
    </html>
  health.html: |
    {"status":"healthy","version":"$version","environment":"$environment"}
YAML

        # Create service for the version
        cat << YAML | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: ${APP_NAME}-service
  namespace: $namespace
  labels:
    app: $APP_NAME
spec:
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: $APP_NAME
YAML
    }
    
    echo "✅ Version management setup complete"
}

# Phase 3: Development Environment Deployment
deploy_to_development() {
    echo -e "\nPhase 3: Deploying to development environment"
    echo "==========================================="
    
    echo "Deploying version 1.0.0 to development..."
    create_app_version "1.0.0" "development" 2 "development"
    
    kubectl rollout status deployment/${APP_NAME}-1.0.0 -n development
    
    echo "✅ Development deployment complete"
}

# Phase 4: Automated Testing Simulation
simulate_automated_testing() {
    echo -e "\nPhase 4: Automated testing simulation"
    echo "===================================="
    
    # Deploy test runner
    cat << YAML | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-runner
  namespace: development
  labels:
    component: testing
spec:
  containers:
  - name: test-runner
    image: curlimages/curl:latest
    command: ["sleep", "3600"]
  restartPolicy: Never
YAML

    kubectl wait --for=condition=Ready pod/test-runner -n development --timeout=60s
    
    echo "Running automated tests..."
    
    # Simulate different types of tests
    echo "1. Health check test:"
    kubectl exec test-runner -n development -- curl -s http://${APP_NAME}-service/health.html
    
    echo -e "\n2. Load test simulation:"
    kubectl exec test-runner -n development -- sh -c "
        for i in \$(seq 1 5); do
            echo \"Request \$i:\";
            curl -s http://${APP_NAME}-service/ | grep Version;
            sleep 1;
        done
    "
    
    echo -e "\n3. Security test simulation:"
    kubectl exec test-runner -n development -- curl -s -I http://${APP_NAME}-service/
    
    # Create test results
    kubectl create configmap test-results -n cicd-tools \
        --from-literal=health_test=PASSED \
        --from-literal=load_test=PASSED \
        --from-literal=security_test=PASSED \
        --from-literal=test_timestamp="$(date)" \
        --from-literal=test_environment=development
    
    echo "✅ Automated testing complete - All tests PASSED"
}

# Phase 5: Staging Deployment with Blue-Green Strategy
deploy_to_staging() {
    echo -e "\nPhase 5: Blue-Green deployment to staging"
    echo "======================================="
    
    # Deploy Blue version (current)
    echo "Deploying Blue version (1.0.0) to staging..."
    create_app_version "1.0.0" "staging" 3 "staging"
    
    kubectl rollout status deployment/${APP_NAME}-1.0.0 -n staging
    
    # Simulate new version development
    echo -e "\nSimulating new version development (1.1.0)..."
    
    # Update version tracker
    kubectl patch configmap version-tracker -n cicd-tools --patch '{
        "data": {
            "current_version": "1.1.0",
            "build_number": "2",
            "git_commit": "def456ghi",
            "release_notes": "Added new features and bug fixes"
        }
    }'
    
    # Deploy Green version (new)
    echo "Deploying Green version (1.1.0) to staging..."
    create_app_version "1.1.0" "staging" 3 "staging"
    
    kubectl rollout status deployment/${APP_NAME}-1.1.0 -n staging
    
    echo "Both Blue and Green versions running in staging"
    kubectl get deployments -n staging
    
    # Simulate traffic switching
    echo -e "\nSwitching traffic from Blue to Green..."
    kubectl patch service ${APP_NAME}-service -n staging --patch '{
        "spec": {
            "selector": {
                "app": "'${APP_NAME}'",
                "version": "1.1.0"
            }
        }
    }'
    
    echo "Traffic switched to Green (1.1.0)"
    
    # Keep Blue version for quick rollback capability
    echo "Blue version kept for quick rollback"
    
    echo "✅ Blue-Green deployment to staging complete"
}

# Phase 6: Production Deployment with Canary Strategy
deploy_to_production() {
    echo -e "\nPhase 6: Canary deployment to production"
    echo "======================================"
    
    # Deploy current stable version (1.0.0) to production
    echo "Deploying stable version (1.0.0) to production..."
    create_app_version "1.0.0" "production" 8 "production"
    
    kubectl rollout status deployment/${APP_NAME}-1.0.0 -n production
    
    # Deploy canary version (1.1.0) with limited replicas
    echo "Deploying canary version (1.1.0) to production..."
    create_app_version "1.1.0" "production" 2 "production"
    
    kubectl rollout status deployment/${APP_NAME}-1.1.0 -n production
    
    echo "Canary deployment active:"
    echo "- Stable version (1.0.0): 8 replicas (80% traffic)"
    echo "- Canary version (1.1.0): 2 replicas (20% traffic)"
    
    kubectl get deployments -n production
    
    # Monitor canary for issues
    echo -e "\nMonitoring canary deployment..."
    sleep 10
    
    # Simulate successful canary validation
    echo "Canary validation successful - promoting to full deployment"
    
    # Scale down old version
    kubectl scale deployment ${APP_NAME}-1.0.0 --replicas=0 -n production
    
    # Scale up new version
    kubectl scale deployment ${APP_NAME}-1.1.0 --replicas=10 -n production
    kubectl rollout status deployment/${APP_NAME}-1.1.0 -n production
    
    # Update service to point to new version
    kubectl patch service ${APP_NAME}-service -n production --patch '{
        "spec": {
            "selector": {
                "app": "'${APP_NAME}'",
                "version": "1.1.0"
            }
        }
    }'
    
    echo "✅ Canary deployment promoted to full production"
}

# Phase 7: Monitoring and Observability
setup_pipeline_monitoring() {
    echo -e "\nPhase 7: Pipeline monitoring and observability"
    echo "============================================"
    
    # Deploy monitoring dashboard
    cat << YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pipeline-dashboard
  namespace: cicd-tools
  labels:
    app: dashboard
    component: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dashboard
  template:
    metadata:
      labels:
        app: dashboard
        component: monitoring
    spec:
      containers:
      - name: dashboard
        image: nginx:1.21
        ports:
        - containerPort: 80
        volumeMounts:
        - name: dashboard-content
          mountPath: /usr/share/nginx/html
      volumes:
      - name: dashboard-content
        configMap:
          name: dashboard-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: dashboard-config
  namespace: cicd-tools
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>CI/CD Pipeline Dashboard</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 20px; }
            .environment { border: 1px solid #ccc; margin: 10px; padding: 15px; }
            .dev { background: #e8f4f8; }
            .staging { background: #fff3cd; }
            .prod { background: #d4edda; }
            .metric { display: inline-block; margin: 10px; padding: 10px; border: 1px solid #ddd; }
        </style>
        <script>
            function refreshData() {
                fetch('/api/status')
                    .then(response => response.json())
                    .then(data => {
                        document.getElementById('status').innerHTML = JSON.stringify(data, null, 2);
                    })
                    .catch(error => console.error('Error:', error));
            }
            setInterval(refreshData, 30000);
        </script>
    </head>
    <body>
        <h1>CI/CD Pipeline Dashboard</h1>
        
        <div class="environment dev">
            <h2>Development Environment</h2>
            <div class="metric">Health: OK</div>
        </div>
        
        <div class="environment staging">
            <h2>Staging Environment</h2>
            <div class="metric">Deployment Status: Blue-Green Active</div>
            <div class="metric">Blue Version: 1.0.0 (Standby)</div>
            <div class="metric">Green Version: 1.1.0 (Active)</div>
            <div class="metric">Health: OK</div>
        </div>
        
        <div class="environment prod">
            <h2>Production Environment</h2>
            <div class="metric">Deployment Status: Canary Complete</div>
            <div class="metric">Version: 1.1.0</div>
            <div class="metric">Replicas: 10</div>
            <div class="metric">Health: OK</div>
        </div>
        
        <h2>Pipeline Metrics</h2>
        <div id="status">Loading...</div>
    </body>
    </html>
---
apiVersion: v1
kind: Service
metadata:
  name: dashboard-service
  namespace: cicd-tools
  labels:
    app: dashboard
spec:
  type: NodePort
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30090
  selector:
    app: dashboard
YAML

    kubectl rollout status deployment/pipeline-dashboard -n cicd-tools
    
    # Create pipeline status tracking
    kubectl create configmap pipeline-status -n cicd-tools \
        --from-literal=last_build="$(date)" \
        --from-literal=build_status=SUCCESS \
        --from-literal=deployment_status=COMPLETE \
        --from-literal=test_coverage=95% \
        --from-literal=security_scan=PASSED
    
    echo "✅ Pipeline monitoring setup complete"
}

# Phase 8: Rollback Simulation
simulate_rollback() {
    echo -e "\nPhase 8: Rollback simulation"
    echo "=========================="
    
    echo "Simulating critical issue in production..."
    
    # Update pipeline status to show issue
    kubectl patch configmap pipeline-status -n cicd-tools --patch '{
        "data": {
            "last_build": "'$(date)'",
            "build_status": "FAILED",
            "deployment_status": "ROLLING_BACK",
            "alert_status": "CRITICAL_ISSUE_DETECTED"
        }
    }'
    
    echo "Critical issue detected! Initiating rollback..."
    
    # Rollback production to previous stable version
    echo "Rolling back production from 1.1.0 to 1.0.0..."
    
    # Scale up old version quickly
    kubectl scale deployment ${APP_NAME}-1.0.0 --replicas=10 -n production
    kubectl rollout status deployment/${APP_NAME}-1.0.0 -n production
    
    # Update service to point back to stable version
    kubectl patch service ${APP_NAME}-service -n production --patch '{
        "spec": {
            "selector": {
                "app": "'${APP_NAME}'",
                "version": "1.0.0"
            }
        }
    }'
    
    # Scale down problematic version
    kubectl scale deployment ${APP_NAME}-1.1.0 --replicas=0 -n production
    
    echo "Production rollback complete:"
    kubectl get deployments -n production
    
    # Update pipeline status
    kubectl patch configmap pipeline-status -n cicd-tools --patch '{
        "data": {
            "deployment_status": "ROLLBACK_COMPLETE",
            "current_production_version": "1.0.0",
            "rollback_timestamp": "'$(date)'"
        }
    }'
    
    echo "✅ Rollback simulation complete"
}

# Phase 9: Pipeline Analytics and Reporting
generate_pipeline_analytics() {
    echo -e "\nPhase 9: Pipeline analytics and reporting"
    echo "======================================="
    
    echo "Generating comprehensive pipeline report..."
    
    # Collect deployment statistics
    cat > ~/pipeline-analytics-report.md << REPORT
# DevOps Pipeline Analytics Report

## Pipeline Overview
- **Project**: $PIPELINE_PROJECT
- **Application**: $APP_NAME
- **Report Generated**: $(date)

## Environment Status

### Development Environment
\`\`\`bash
$(kubectl get all -n development 2>/dev/null || echo "No resources in development")
\`\`\`

### Staging Environment
\`\`\`bash
$(kubectl get all -n staging 2>/dev/null || echo "No resources in staging")
\`\`\`

### Production Environment
\`\`\`bash
$(kubectl get all -n production 2>/dev/null || echo "No resources in production")
\`\`\`

## Deployment History

### Version Timeline
- **v1.0.0**: Initial release (Deployed to all environments)
- **v1.1.0**: Feature update (Blue-Green in staging, Canary in production)
- **Rollback**: Critical issue detected, rolled back to v1.0.0

### Deployment Strategies Used
1. **Development**: Standard deployment
2. **Staging**: Blue-Green deployment
3. **Production**: Canary deployment with rollback

## Pipeline Metrics
REPORT

    # Add pipeline status to report
    echo -e "\n### Current Pipeline Status" >> ~/pipeline-analytics-report.md
    echo '```yaml' >> ~/pipeline-analytics-report.md
    kubectl get configmap pipeline-status -n cicd-tools -o yaml >> ~/pipeline-analytics-report.md 2>/dev/null
    echo '```' >> ~/pipeline-analytics-report.md
    
    # Add resource utilization
    echo -e "\n### Resource Utilization" >> ~/pipeline-analytics-report.md
    echo '```bash' >> ~/pipeline-analytics-report.md
    echo "# Pod distribution across environments:" >> ~/pipeline-analytics-report.md
    kubectl get pods --all-namespaces -l project=$PIPELINE_PROJECT -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATUS:.status.phase >> ~/pipeline-analytics-report.md 2>/dev/null
    echo '```' >> ~/pipeline-analytics-report.md
    
    # Add operational commands
    cat >> ~/pipeline-analytics-report.md << 'COMMANDS'

## Operational Commands

### Monitoring Commands
```bash
# Check pipeline infrastructure
kubectl get all -n cicd-tools

# Monitor application across environments
kubectl get deployments --all-namespaces -l app=web-application

# Check pipeline status
kubectl get configmap pipeline-status -n cicd-tools -o yaml
```

### Deployment Commands
```bash
# Deploy new version to development
kubectl set image deployment/web-application-1.0.0 web-app=nginx:1.22 -n development

# Scale applications
kubectl scale deployment web-application-1.0.0 --replicas=5 -n production

# Rollback deployment
kubectl rollout undo deployment/web-application-1.1.0 -n production
```

### Troubleshooting Commands
```bash
# Check deployment status
kubectl rollout status deployment/web-application-1.0.0 -n production

# View deployment history
kubectl rollout history deployment/web-application-1.0.0 -n production

# Debug pods
kubectl logs -l app=web-application -n production
kubectl describe pods -l app=web-application -n production
```
COMMANDS

    echo "📊 Pipeline analytics report generated: ~/pipeline-analytics-report.md"
}

# Phase 10: Advanced Pipeline Features
demonstrate_advanced_features() {
    echo -e "\nPhase 10: Advanced pipeline features"
    echo "==================================="
    
    # Feature 1: Multi-environment resource quotas
    echo "1. Setting up resource quotas per environment..."
    
    for env in development staging production; do
        cat << YAML | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ${env}-quota
  namespace: $env
spec:
  hard:
    requests.cpu: $([ "$env" = "production" ] && echo "2000m" || echo "1000m")
    requests.memory: $([ "$env" = "production" ] && echo "4Gi" || echo "2Gi")
    limits.cpu: $([ "$env" = "production" ] && echo "4000m" || echo "2000m")
    limits.memory: $([ "$env" = "production" ] && echo "8Gi" || echo "4Gi")
    persistentvolumeclaims: 5
    pods: $([ "$env" = "production" ] && echo "20" || echo "10")
YAML
    done
    
    # Feature 2: Network policies for security
    echo "2. Implementing network security policies..."
    
    cat << YAML | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: production-isolation
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: cicd-tools
    - namespaceSelector:
        matchLabels:
          name: staging
  egress:
  - {}
YAML
    
    # Feature 3: Automated backup strategy
    echo "3. Setting up automated backup strategy..."
    
    cat << YAML | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: backup-strategy
  namespace: cicd-tools
data:
  backup-script.sh: |
    #!/bin/bash
    # Automated backup script
    
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    BACKUP_DIR="/backups/pipeline-backup-\$TIMESTAMP"
    
    mkdir -p \$BACKUP_DIR
    
    # Backup all environments
    for namespace in development staging production; do
        echo "Backing up \$namespace..."
        kubectl get all -n \$namespace -o yaml > \$BACKUP_DIR/\$namespace-resources.yaml
        kubectl get configmap,secret -n \$namespace -o yaml > \$BACKUP_DIR/\$namespace-config.yaml
    done
    
    # Backup CI/CD tools
    kubectl get all -n cicd-tools -o yaml > \$BACKUP_DIR/cicd-tools.yaml
    
    echo "Backup completed: \$BACKUP_DIR"
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: pipeline-backup
  namespace: cicd-tools
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: bitnami/kubectl:latest
            command: ["/bin/bash"]
            args: ["/scripts/backup-script.sh"]
            volumeMounts:
            - name: backup-script
              mountPath: /scripts
            - name: backup-storage
              mountPath: /backups
          volumes:
          - name: backup-script
            configMap:
              name: backup-strategy
              defaultMode: 0755
          - name: backup-storage
            emptyDir: {}
          restartPolicy: OnFailure
YAML
    
    # Feature 4: Performance monitoring
    echo "4. Setting up performance monitoring..."
    
    cat << YAML | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: performance-monitor
  namespace: cicd-tools
  labels:
    app: performance-monitor
spec:
  selector:
    matchLabels:
      app: performance-monitor
  template:
    metadata:
      labels:
        app: performance-monitor
    spec:
      containers:
      - name: monitor
        image: busybox:1.35
        command: ["sh", "-c", "while true; do echo 'Monitoring performance at $(date)'; sleep 60; done"]
        resources:
          requests:
            cpu: 10m
            memory: 16Mi
          limits:
            cpu: 50m
            memory: 64Mi
      hostNetwork: true
      tolerations:
      - key: node-role.kubernetes.io/master
        effect: NoSchedule
YAML
    
    echo "✅ Advanced pipeline features implemented"
}

# Pipeline Status Dashboard
show_pipeline_status() {
    echo -e "\n=== DevOps Pipeline Status Dashboard ==="
    echo "======================================="
    
    echo "📊 Infrastructure Status:"
    kubectl get deployments -n cicd-tools -o custom-columns=\
NAME:.metadata.name,\
READY:.status.readyReplicas,\
AVAILABLE:.status.availableReplicas
    
    echo -e "\n🚀 Application Deployments:"
    for env in development staging production; do
        echo "Environment: $env"
        kubectl get deployments -n $env -o custom-columns=\
NAME:.metadata.name,\
REPLICAS:.spec.replicas,\
READY:.status.readyReplicas,\
VERSION:.metadata.labels.version 2>/dev/null || echo "  No deployments"
        echo
    done
    
    echo "📈 Resource Quotas:"
    for env in development staging production; do
        echo "Environment: $env"
        kubectl describe resourcequota ${env}-quota -n $env 2>/dev/null | grep -E "(Name|Used|Hard)" || echo "  No quota defined"
        echo
    done
    
    echo "🔍 Recent Pipeline Events:"
    kubectl get events --all-namespaces --sort-by=.metadata.creationTimestamp | tail -10
}

# Cleanup function
cleanup_pipeline_project() {
    echo -e "\n=== Pipeline Project Cleanup ==="
    
    # Delete all namespaces
    kubectl delete namespace cicd-tools development staging production
    
    # Clean up reports
    rm -f ~/pipeline-analytics-report.md
    
    echo "✅ DevOps pipeline project cleanup complete"
}

# Main pipeline execution
echo "Starting DevOps CI/CD Pipeline Simulation Project"
echo "================================================"

setup_pipeline_infrastructure
setup_version_management
deploy_to_development
simulate_automated_testing
deploy_to_staging
deploy_to_production
setup_pipeline_monitoring
simulate_rollback
generate_pipeline_analytics
demonstrate_advanced_features
show_pipeline_status

echo -e "\n🎉 DevOps CI/CD Pipeline Project Complete!"
echo "=========================================="
echo "✅ Complete CI/CD infrastructure deployed"
echo "✅ Multi-environment application deployment"
echo "✅ Blue-Green deployment strategy in staging"
echo "✅ Canary deployment strategy in production"
echo "✅ Automated testing simulation"
echo "✅ Rollback procedures demonstrated"
echo "✅ Pipeline monitoring and dashboards"
echo "✅ Advanced features (quotas, security, backups)"
echo "✅ Comprehensive analytics and reporting"

echo -e "\nProject artifacts:"
echo "📊 ~/pipeline-analytics-report.md - Complete pipeline analytics"
echo "🖥️  Jenkins Dashboard: http://localhost:30808 (if accessible)"
echo "📈 Pipeline Dashboard: http://localhost:30090 (if accessible)"

echo -e "\nExplore your pipeline:"
echo "kubectl get all -n cicd-tools"
echo "kubectl get all --all-namespaces -l project=$PIPELINE_PROJECT"

read -p "Would you like to clean up the entire pipeline project? (y/n): " cleanup
if [[ $cleanup =~ ^[Yy] ]]; then
    cleanup_pipeline_project
fi
EOF

chmod +x ~/devops-pipeline-project.sh
```

### Mini-Project 3: Multi-Cluster Management

```bash
# Mini-Project 3: Multi-Cluster Management and Federation
cat > ~/multi-cluster-project.sh << 'EOF'
#!/bin/bash

echo "=== Mini-Project 3: Multi-Cluster Management and Federation ==="

PROJECT_NAME="multi-cluster-demo"

# Phase 1: Cluster Context Management
setup_cluster_contexts() {
    echo "Phase 1: Setting up multi-cluster context management"
    echo "================================================="
    
    # Simulate multiple cluster contexts
    echo "Setting up cluster contexts (simulated)..."
    
    # In a real scenario, you would have actual cluster contexts
    # We'll simulate this by creating different namespaces that represent clusters
    
    # Create "clusters" as namespaces
    kubectl create namespace cluster-east-prod
    kubectl create namespace cluster-west-prod  
    kubectl create namespace cluster-dev
    kubectl create namespace cluster-staging
    
    # Label them to simulate different clusters
    kubectl label namespace cluster-east-prod cluster-region=east cluster-type=production
    kubectl label namespace cluster-west-prod cluster-region=west cluster-type=production
    kubectl label namespace cluster-dev cluster-region=central cluster-type=development
    kubectl label namespace cluster-staging cluster-region=central cluster-type=staging
    
    # Create cluster management namespace
    kubectl create namespace cluster-management
    kubectl label namespace cluster-management purpose=management project=$PROJECT_NAME
    
    echo "✅ Multi-cluster context setup complete"
}

# Phase 2: Cluster Management Dashboard
deploy_cluster_management() {
    echo -e "\nPhase 2: Deploying cluster management infrastructure"
    echo "=================================================="
    
    # Deploy cluster management dashboard
    cat << YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-dashboard
  namespace: cluster-management
  labels:
    app: cluster-dashboard
    component: management
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cluster-dashboard
  template:
    metadata:
      labels:
        app: cluster-dashboard
        component: management
    spec:
      containers:
      - name: dashboard
        image: nginx:1.21
        ports:
        - containerPort: 80
        volumeMounts:
        - name: dashboard-content
          mountPath: /usr/share/nginx/html
      volumes:
      - name: dashboard-content
        configMap:
          name: cluster-dashboard-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-dashboard-config
  namespace: cluster-management
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>Multi-Cluster Management Dashboard</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
            .cluster { border: 2px solid #007acc; margin: 15px; padding: 20px; background: white; border-radius: 8px; }
            .cluster h2 { color: #007acc; margin-top: 0; }
            .metric { display: inline-block; margin: 8px; padding: 12px; background: #e8f4f8; border-radius: 4px; min-width: 120px; }
            .status-healthy { color: #28a745; font-weight: bold; }
            .status-warning { color: #ffc107; font-weight: bold; }
            .cluster-east { border-color: #28a745; }
            .cluster-west { border-color: #dc3545; }
            .cluster-dev { border-color: #17a2b8; }
            .cluster-staging { border-color: #ffc107; }
        </style>
    </head>
    <body>
        <h1>🌐 Multi-Cluster Management Dashboard</h1>
        <p>Managing distributed Kubernetes clusters across regions</p>
        
        <div class="cluster cluster-east">
            <h2>🌍 East Production Cluster</h2>
            <div class="metric">Region: East US</div>
            <div class="metric">Status: <span class="status-healthy">Healthy</span></div>
            <div class="metric">Nodes: 12</div>
            <div class="metric">Pods: 156</div>
            <div class="metric">CPU Usage: 65%</div>
            <div class="metric">Memory: 78%</div>
        </div>
        
        <div class="cluster cluster-west">
            <h2>🌎 West Production Cluster</h2>
            <div class="metric">Region: West US</div>
            <div class="metric">Status: <span class="status-healthy">Healthy</span></div>
            <div class="metric">Nodes: 10</div>
            <div class="metric">Pods: 134</div>
            <div class="metric">CPU Usage: 72%</div>
            <div class="metric">Memory: 81%</div>
        </div>
        
        <div class="cluster cluster-dev">
            <h2>🔧 Development Cluster</h2>
            <div class="metric">Region: Central</div>
            <div class="metric">Status: <span class="status-healthy">Healthy</span></div>
            <div class="metric">Nodes: 5</div>
            <div class="metric">Pods: 67</div>
            <div class="metric">CPU Usage: 45%</div>
            <div class="metric">Memory: 52%</div>
        </div>
        
        <div class="cluster cluster-staging">
            <h2>🧪 Staging Cluster</h2>
            <div class="metric">Region: Central</div>
            <div class="metric">Status: <span class="status-warning">Updating</span></div>
            <div class="metric">Nodes: 3</div>
            <div class="metric">Pods: 45</div>
            <div class="metric">CPU Usage: 38%</div>
            <div class="metric">Memory: 44%</div>
        </div>
        
        <div style="margin-top: 30px; padding: 20px; background: white; border-radius: 8px;">
            <h2>📊 Global Statistics</h2>
            <div class="metric">Total Clusters: 4</div>
            <div class="metric">Total Nodes: 30</div>
            <div class="metric">Total Pods: 402</div>
            <div class="metric">Global Status: <span class="status-healthy">Operational</span></div>
        </div>
    </body>
    </html>
---
apiVersion: v1
kind: Service
metadata:
  name: cluster-dashboard-service
  namespace: cluster-management
  labels:
    app: cluster-dashboard
spec:
  type: NodePort
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30095
  selector:
    app: cluster-dashboard
YAML

    kubectl rollout status deployment/cluster-dashboard -n cluster-management
    
    echo "✅ Cluster management dashboard deployed"
}

# Phase 3: Application Deployment Across Clusters
deploy_applications_across_clusters() {
    echo -e "\nPhase 3: Deploying applications across multiple clusters"
    echo "===================================================="
    
    # Function to deploy application to a "cluster" (namespace)
    deploy_to_cluster() {
        local cluster_ns=$1
        local region=$2
        local cluster_type=$3
        local replicas=$4
        
        echo "Deploying application to $cluster_ns ($region - $cluster_type)..."
        
        cat << YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: global-app
  namespace: $cluster_ns
  labels:
    app: global-app
    cluster-region: $region
    cluster-type: $cluster_type
spec:
  replicas: $replicas
  selector:
    matchLabels:
      app: global-app
  template:
    metadata:
      labels:
        app: global-app
        cluster-region: $region
        cluster-type: $cluster_type
    spec:
      containers:
      - name: app
        image: nginx:1.21
        ports:
        - containerPort: 80
        env:
        - name: CLUSTER_REGION
          value: "$region"
        - name: CLUSTER_TYPE
          value: "$cluster_type"
        - name: DEPLOYMENT_ID
          value: "$(date +%Y%m%d-%H%M%S)"
        volumeMounts:
        - name: app-content
          mountPath: /usr/share/nginx/html
      volumes:
      - name: app-content
        configMap:
          name: global-app-config-$region
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: global-app-config-$region
  namespace: $cluster_ns
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>Global Application - $region</title>
        <style>
            body { 
                font-family: Arial, sans-serif; 
                text-align: center; 
                padding: 50px; 
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                color: white;
            }
            .info { background: rgba(255,255,255,0.1); padding: 20px; border-radius: 10px; margin: 20px auto; max-width: 600px; }
        </style>
    </head>
    <body>
        <h1>🌍 Global Application</h1>
        <div class="info">
            <h2>Cluster Information</h2>
            <p><strong>Region:</strong> $region</p>
            <p><strong>Type:</strong> $cluster_type</p>
            <p><strong>Deployment Time:</strong> $(date)</p>
            <p><strong>Status:</strong> Running</p>
        </div>
        <div class="info">
            <h2>Application Features</h2>
            <ul style="text-align: left;">
                <li>Multi-region deployment</li>
                <li>High availability</li>
                <li>Load balancing</li>
                <li>Automatic failover</li>
            </ul>
        </div>
    </body>
    </html>
---
apiVersion: v1
kind: Service
metadata:
  name: global-app-service
  namespace: $cluster_ns
  labels:
    app: global-app
    cluster-region: $region
spec:
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: global-app
YAML
    }
    
    # Deploy to each "cluster"
    deploy_to_cluster "cluster-east-prod" "east" "production" 5
    deploy_to_cluster "cluster-west-prod" "west" "production" 5
    deploy_to_cluster "cluster-dev" "central" "development" 2
    deploy_to_cluster "cluster-staging" "central" "staging" 3
    
    # Wait for deployments
    for cluster in cluster-east-prod cluster-west-prod cluster-dev cluster-staging; do
        kubectl rollout status deployment/global-app -n $cluster
    done
    
    echo "✅ Applications deployed across all clusters"
}

# Phase 4: Cross-Cluster Service Discovery
setup_service_discovery() {
    echo -e "\nPhase 4: Setting up cross-cluster service discovery"
    echo "==============================================="
    
    # Deploy service registry
    cat << YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: service-registry
  namespace: cluster-management
  labels:
    app: service-registry
    component: discovery
spec:
  replicas: 2
  selector:
    matchLabels:
      app: service-registry
  template:
    metadata:
      labels:
        app: service-registry
        component: discovery
    spec:
      containers:
      - name: registry
        image: nginx:1.21
        ports:
        - containerPort: 80
        volumeMounts:
        - name: registry-config
          mountPath: /etc/nginx/conf.d
        - name: registry-data
          mountPath: /usr/share/nginx/html
      volumes:
      - name: registry-config
        configMap:
          name: service-registry-config
      - name: registry-data
        configMap:
          name: service-registry-data
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: service-registry-config
  namespace: cluster-management
data:
  default.conf: |
    server {
        listen 80;
        server_name service-registry;
        
        location /api/services {
            add_header Content-Type application/json;
            alias /usr/share/nginx/html/services.json;
        }
        
        location /api/health {
            return 200 '{"status":"healthy","service":"service-registry"}';
            add_header Content-Type application/json;
        }
        
        location / {
            root /usr/share/nginx/html;
            index index.html;
        }
    }
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: service-registry-data
  namespace: cluster-management
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>Service Registry</title>
    </head>
    <body>
        <h1>Cross-Cluster Service Registry</h1>
        <p>Discovering services across multiple clusters</p>
        <ul>
            <li><a href="/api/services">Service Endpoints</a></li>
            <li><a href="/api/health">Health Check</a></li>
        </ul>
    </body>
    </html>
  services.json: |
    {
      "clusters": {
        "east-production": {
          "region": "east",
          "endpoints": [
            {
              "service": "global-app",
              "url": "http://global-app-service.cluster-east-prod.svc.cluster.local",
              "health": "healthy",
              "replicas": 5
            }
          ]
        },
        "west-production": {
          "region": "west", 
          "endpoints": [
            {
              "service": "global-app",
              "url": "http://global-app-service.cluster-west-prod.svc.cluster.local",
              "health": "healthy",
              "replicas": 5
            }
          ]
        },
        "development": {
          "region": "central",
          "endpoints": [
            {
              "service": "global-app",
              "url": "http://global-app-service.cluster-dev.svc.cluster.local",
              "health": "healthy",
              "replicas": 2
            }
          ]
        },
        "staging": {
          "region": "central",
          "endpoints": [
            {
              "service": "global-app",
              "url": "http://global-app-service.cluster-staging.svc.cluster.local",
              "health": "healthy",
              "replicas": 3
            }
          ]
        }
      },
      "updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    }
---
apiVersion: v1
kind: Service
metadata:
  name: service-registry
  namespace: cluster-management
  labels:
    app: service-registry
spec:
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: service-registry
YAML

    kubectl rollout status deployment/service-registry -n cluster-management
    
    echo "✅ Cross-cluster service discovery setup complete"
}

# Phase 5: Global Load Balancing
setup_global_load_balancer() {
    echo -e "\nPhase 5: Setting up global load balancing"
    echo "======================================="
    
    # Deploy global load balancer
    cat << YAML | kubectl apply -f -
apiVersion: apps/v1">Deployment Status: Active</div>
            <div class="metric">Version: 1.1.0</div>
            <div class="metric
          mountPath: /prometheus/
      volumes:
      - name: prometheus-config
        configMap:
          name: prometheus-config
      - name: prometheus-storage