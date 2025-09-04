# 2. Prerequisites
Before diving into kubectl commands, ensure you have the following foundation:

- kubectl installed - Verify with `kubectl version --client` (this checks your local kubectl without needing cluster access)
- Cluster access - This could be Minikube for local development, or managed services like GKE, EKS, or AKS
- Command-line comfort - Basic terminal navigation and file editing skills
- YAML understanding - Kubernetes uses YAML extensively for configuration (see Appendix A for basics)

## Demo: Setting Up Your Learning Environment
Let's start by setting up a proper learning environment that you can use throughout this guide.

```bash
# Check if kubectl is installed and working
kubectl version --client

# If you don't have a cluster yet, install Minikube for local development
# On macOS:
brew install minikube

# On Linux:
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Start your local cluster
minikube start

# Verify your cluster is running
kubectl cluster-info
kubectl get nodes
```

## Example: First Cluster Interaction

```bash
# This command gives you an overview of your cluster's health
kubectl get componentstatuses

# See what's running in the system namespace
kubectl get pods -n kube-system

# Check available resources in your cluster
kubectl api-resources | head -20
```

## Mini-Project: Environment Validation Checklist
Create a simple script that validates your Kubernetes environment is ready for learning:

```bash
#!/bin/bash
# save as check-k8s-env.sh

echo "🔍 Checking Kubernetes Environment..."

# Check kubectl installation
if command -v kubectl &> /dev/null; then
     echo "✅ kubectl is installed"
     kubectl version --client --short
else
     echo "❌ kubectl not found"
     exit 1
fi

# Check cluster connectivity
if kubectl cluster-info &> /dev/null; then
     echo "✅ Cluster is accessible"
     kubectl get nodes --no-headers | wc -l | xargs echo "📊 Nodes available:"
else
     echo "❌ Cannot connect to cluster"
     exit 1
fi

# Check permissions
if kubectl auth can-i create pods &> /dev/null; then
     echo "✅ You have pod creation permissions"
else
     echo "⚠️ Limited permissions - some exercises may not work"
fi

echo "🎉 Environment ready for learning!"
```

Make it executable and run it: `chmod +x check-k8s-env.sh && ./check-k8s-env.sh`