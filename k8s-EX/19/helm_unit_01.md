# Unit 1: Helm Fundamentals and Installation

## Learning Objectives
By the end of this unit, you will:
- Understand what Helm is and why it's essential for Kubernetes
- Successfully install and configure Helm
- Navigate Helm repositories and discover charts
- Perform basic chart operations with confidence

## What is Helm?

Think of Helm as the "npm for Kubernetes" - it's a package manager that transforms complex Kubernetes deployments into manageable, reusable packages called **charts**. Instead of maintaining dozens of YAML files for each application, you work with a single chart that can be configured for different environments.

### Core Concepts

**Charts**: Templates for Kubernetes applications (like a blueprint)
**Releases**: Running instances of charts in your cluster (like deployed applications)  
**Repositories**: Collections of charts that can be shared (like package registries)

## Installation and Setup

### Installing Helm

```bash
# Option 1: Using the install script (recommended for Linux/macOS)
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Option 2: Using package managers
# macOS with Homebrew
brew install helm

# Ubuntu/Debian
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm

# Windows with Chocolatey
choco install kubernetes-helm
```

### Verification and Initial Configuration

```bash
# Verify installation
helm version

# Expected output:
# version.BuildInfo{Version:"v3.14.0", GitCommit:"...", GitTreeState:"clean", GoVersion:"go1.21.5"}

# Check if kubectl is configured (Helm requires cluster access)
kubectl cluster-info

# Initialize Helm (this happens automatically in Helm 3)
# No initialization required - Helm 3 removed Tiller
```

## Working with Repositories

### Adding Popular Repositories

```bash
# Add the official Bitnami repository (most comprehensive collection)
helm repo add bitnami https://charts.bitnami.com/bitnami

# Add other popular repositories
helm repo add stable https://charts.helm.sh/stable
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# Update repository information (always do this after adding repos)
helm repo update

# List configured repositories
helm repo list
```

### Discovering Charts

```bash
# Search for nginx charts across all repositories
helm search repo nginx

# Search with version information
helm search repo nginx --versions | head -10

# Search for specific functionality
helm search repo database
helm search repo monitoring
helm search repo ingress

# Get detailed information about a specific chart
helm show chart bitnami/nginx
helm show values bitnami/nginx
helm show readme bitnami/nginx
```

## Mini-Project 1: Your First Helm Deployment

Let's deploy a web application using Helm to understand the complete workflow.

### Step 1: Explore the Chart

```bash
# First, let's understand what we're about to deploy
helm show values bitnami/nginx > nginx-values.yaml

# Examine the default configuration
cat nginx-values.yaml | head -20
```

**Question for exploration**: What configuration options do you see that might be important for a production deployment?

### Step 2: Deploy with Default Settings

```bash
# Create a test namespace
kubectl create namespace helm-demo

# Install nginx with default values
helm install my-first-app bitnami/nginx --namespace helm-demo

# Check the deployment status
helm status my-first-app -n helm-demo

# See what Kubernetes resources were created
kubectl get all -n helm-demo
```

### Step 3: Access Your Application

```bash
# Forward a port to access the application locally
kubectl port-forward -n helm-demo svc/my-first-app-nginx 8080:80

# In another terminal, test the connection
curl http://localhost:8080
# You should see the nginx welcome page HTML
```

### Step 4: Understand the Release

```bash
# List all releases
helm list -n helm-demo

# Get the values that were used
helm get values my-first-app -n helm-demo

# See the complete manifest that was deployed
helm get manifest my-first-app -n helm-demo

# View the release history
helm history my-first-app -n helm-demo
```

## Practice Exercise 1: Chart Discovery

Explore different types of applications available through Helm:

```bash
# Find charts for these categories and note interesting options:

# 1. Databases
helm search repo postgres
helm search repo mysql
helm search repo mongodb

# 2. Monitoring tools
helm search repo prometheus
helm search repo grafana

# 3. Web servers
helm search repo apache
helm search repo nginx

# For each category, pick one chart and examine its values:
helm show values bitnami/postgresql | head -30
```

**Reflection Questions:**
1. What patterns do you notice in how charts are structured?
2. Which configuration options appear most frequently across different charts?
3. How do the charts handle secrets and sensitive data?

## Common Helm Commands Reference

```bash
# Repository management
helm repo add <name> <url>     # Add a repository
helm repo update               # Update repo information
helm repo list                 # List repositories
helm repo remove <name>        # Remove a repository

# Chart discovery
helm search repo <term>        # Search repositories
helm search hub <term>         # Search Helm Hub
helm show chart <chart>        # Show chart information
helm show values <chart>       # Show default values
helm show readme <chart>       # Show chart documentation

# Release management
helm install <name> <chart>    # Install a chart
helm upgrade <name> <chart>    # Upgrade a release
helm rollback <name> <version> # Rollback to previous version
helm uninstall <name>          # Remove a release
helm list                      # List releases
helm status <name>             # Show release status
helm history <name>            # Show release history

# Values and configuration
helm get values <name>         # Get current values
helm get manifest <name>       # Get deployed manifest
```

## Troubleshooting Common Issues

### Issue 1: Repository Not Found
```bash
# Error: repository name (stable) not found
# Solution: Add the repository first
helm repo add stable https://charts.helm.sh/stable
helm repo update
```

### Issue 2: Namespace Issues
```bash
# Error: namespace "default" not found
# Solution: Create namespace or specify existing one
kubectl create namespace my-app
helm install my-app chart-name -n my-app
```

### Issue 3: Permission Errors
```bash
# Error: Kubernetes cluster unreachable
# Solution: Check kubectl configuration
kubectl config current-context
kubectl cluster-info
```

## Unit 1 Assessment

Deploy a complete web application stack to demonstrate your understanding:

```bash
# Deploy a WordPress blog with the following requirements:
# 1. Use the bitnami/wordpress chart
# 2. Deploy in namespace "wordpress-demo"  
# 3. Set the blog name to "My Helm Demo"
# 4. Enable persistence for data storage
# 5. Verify the deployment is successful

# Your commands here:
helm repo add bitnami https://charts.bitnami.com/bitnami
kubectl create namespace wordpress-demo
helm install wordpress-demo bitnami/wordpress \
  --set wordpressBlogName="My Helm Demo" \
  --set persistence.enabled=true \
  --namespace wordpress-demo

# Verification steps:
helm status wordpress-demo -n wordpress-demo
kubectl get all -n wordpress-demo
```

## Cleanup

```bash
# Remove the deployments we created
helm uninstall my-first-app -n helm-demo
helm uninstall wordpress-demo -n wordpress-demo

# Remove the namespaces
kubectl delete namespace helm-demo
kubectl delete namespace wordpress-demo
```

## Next Steps

In Unit 2, you'll learn how to customize chart configurations using values files and command-line parameters, enabling you to adapt charts for different environments and use cases.

**Preview Question**: If you needed to deploy the same application in development, staging, and production environments, what aspects would need to be different in each environment?