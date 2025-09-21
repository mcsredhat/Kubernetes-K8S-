# Automation and GitOps

These commands support automated workflows, CI/CD integration, and GitOps practices essential for modern Kubernetes operations.

## Modern kubectl Diff and Configuration Management
```bash
# Configuration diffing and comparison
kubectl diff -f deployment.yaml                         # Show differences before applying
kubectl diff -k ./kustomize/                           # Diff with Kustomize configuration
kubectl diff -f manifest.yaml --server-side            # Server-side diff
kubectl diff -R -f ./manifests/                        # Recursive directory diff

# Advanced diff operations
kubectl get deployment webapp -o yaml | kubectl diff -f -  # Compare with current state via stdin
kubectl diff -f new-config.yaml --field-manager=kubectl-client-side-apply  # Diff with specific field manager
kubectl diff --prune -l app=webapp -f ./configs/       # Diff with pruning preview
kubectl diff -f config.yaml --validate=false           # Skip validation during diff

# Three-way merge preview
kubectl apply -f deployment.yaml --dry-run=server      # Server-side dry run
kubectl apply -f deployment.yaml --dry-run=client      # Client-side dry run
kubectl apply -f deployment.yaml --server-side --dry-run=server  # Server-side apply preview
```

## Advanced Apply and Replace Operations
```bash
# Enhanced apply operations
kubectl apply -f deployment.yaml                         # Standard apply
kubectl apply -f ./manifests/ --recursive               # Apply directory recursively
kubectl apply -k ./kustomize/                           # Apply Kustomize configuration
kubectl apply --prune -l app=myapp -f ./configs/        # Apply with pruning of unlabeled resources
kubectl apply --dry-run=server -f deployment.yaml      # Server-side validation

# Strategic merge and replace operations
kubectl replace -f deployment.yaml                      # Replace existing resource
kubectl replace --force -f deployment.yaml              # Force replacement (delete and recreate)
kubectl patch deployment webapp --type='strategic' -p='{"spec":{"replicas":5}}'  # Strategic merge patch
kubectl patch deployment webapp --type='merge' -p='{"metadata":{"labels":{"version":"v2"}}}'  # Merge patch
kubectl patch deployment webapp --type='json' -p='[{"op": "replace", "path": "/spec/replicas", "value": 3}]'  # JSON patch

# Advanced apply patterns
kubectl apply -f deployment.yaml --validate=false       # Skip validation
kubectl apply -f deployment.yaml --force --grace-period=0  # Force apply
kubectl apply --record -f deployment.yaml               # Record command in annotations
kubectl apply --overwrite=true -f config.yaml           # Overwrite existing fields
kubectl apply --cascade=foreground -f deployment.yaml   # Foreground cascading deletion

# Server-side apply (recommended for automation)
kubectl apply --server-side -f deployment.yaml          # Server-side apply
kubectl apply --server-side --field-manager=ci-cd -f deployment.yaml  # Custom field manager
kubectl apply --server-side --force-conflicts -f deployment.yaml      # Force resolve conflicts
```

## Resource Generation and Templating
```bash
# YAML generation for various resources
kubectl create deployment webapp --image=nginx --dry-run=client -o yaml > deployment.yaml  # Generate deployment YAML
kubectl create service clusterip webapp --tcp=80:8080 --dry-run=client -o yaml > service.yaml  # Generate service YAML
kubectl create configmap app-config --from-file=config.properties --dry-run=client -o yaml > configmap.yaml  # ConfigMap from file
kubectl create secret generic app-secret --from-literal=key=value --dry-run=client -o yaml > secret.yaml  # Secret YAML

# Advanced resource generation
kubectl create ingress webapp --rule="example.com/api/*=api-service:80" --dry-run=client -o yaml > ingress.yaml
kubectl create job backup --image=busybox --dry-run=client -o yaml -- /bin/sh -c "echo backup complete" > job.yaml
kubectl create cronjob backup --image=busybox --schedule="0 2 * * *" --dry-run=client -o yaml -- /bin/sh -c "backup.sh" > cronjob.yaml

# Multi-resource generation
kubectl create namespace production --dry-run=client -o yaml > namespace.yaml
kubectl create deployment webapp --image=nginx:1.20 --replicas=3 --dry-run=client -o yaml >> multi-resource.yaml
echo "---" >> multi-resource.yaml
kubectl create service clusterip webapp --tcp=80 --dry-run=client -o yaml >> multi-resource.yaml

# Template customization
kubectl create deployment webapp --image=nginx --dry-run=client -o yaml | \
  sed 's/replicas: 1/replicas: 3/' | \
  kubectl apply -f -  # Modify and apply in pipeline
```

## ConfigMap and Secret Management
```bash
# ConfigMap creation and management
kubectl create configmap app-config --from-file=config.properties     # From single file
kubectl create configmap app-config --from-file=config/               # From directory
kubectl create configmap app-config --from-literal=key1=value1 --from-literal=key2=value2  # From literals
kubectl create configmap app-config --from-env-file=.env              # From environment file

# Advanced ConfigMap operations
kubectl get configmaps                                        # List ConfigMaps
kubectl describe configmap app-config                         # ConfigMap details
kubectl get configmap app-config -o yaml                      # Full ConfigMap content
kubectl patch configmap app-config -p '{"data":{"key1":"new-value"}}'  # Update ConfigMap

# Secret management and creation
kubectl create secret generic app-secret --from-file=secret.txt       # Secret from file
kubectl create secret generic app-secret --from-literal=username=admin --from-literal=password=secret123  # From literals
kubectl create secret tls tls-secret --cert=tls.crt --key=tls.key     # TLS secret
kubectl create secret docker-registry regcred --docker-server=registry.example.com --docker-username=user --docker-password=pass  # Docker registry secret

# Secret security and management
kubectl get secrets                                           # List secrets
kubectl describe secret app-secret                            # Secret metadata (no values)
kubectl get secret app-secret -o jsonpath='{.data}' | jq -r 'to_entries[] | "\(.key): \(.value | @base64d)"'  # Decode secret values

# ConfigMap and Secret usage validation
kubectl get pods -o json | jq '.items[] | select(.spec.containers[].env[]?.valueFrom.configMapKeyRef) | .metadata.name'  # Pods using ConfigMaps
kubectl get pods -o json | jq '.items[] | select(.spec.containers[].env[]?.valueFrom.secretKeyRef) | .metadata.name'    # Pods using Secrets
kubectl get deployments -o json | jq '.items[] | select(.spec.template.spec.volumes[]?.configMap) | .metadata.name'     # Deployments with ConfigMap volumes
```

## Batch Operations and Resource Cleanup
```bash
# Batch resource operations
kubectl delete pods --all -n <namespace>                     # Delete all pods in namespace
kubectl delete deployment,service,configmap -l app=<label>   # Delete multiple resource types by label
kubectl get pods --output name | grep <pattern> | xargs kubectl delete  # Pattern-based deletion
kubectl get pods --field-selector=status.phase=Failed --output name | xargs kubectl delete  # Delete failed pods
kubectl delete pods --all --field-selector=status.phase=Succeeded  # Delete completed pods

# Advanced batch operations with confirmation
kubectl get pods --field-selector=status.phase=Failed -o name --dry-run=client  # Preview deletion
kubectl delete pods --selector=app=old-version --wait=true --timeout=60s  # Delete with wait and timeout
kubectl get pods -l version=v1 --no-headers -o custom-columns=":metadata.name" | xargs -I {} kubectl delete pod {} --grace-period=30

# Resource export and backup strategies
kubectl get all -o yaml > cluster-backup-$(date +%Y%m%d).yaml               # Export all resources
kubectl get deployment <name> -o yaml > deployment-backup.yaml              # Export specific resource
kubectl get secrets,configmaps -o yaml > configs-backup-$(date +%Y%m%d).yaml    # Export configurations
kubectl get crd -o yaml > custom-resources-backup-$(date +%Y%m%d).yaml         # Export custom resource definitions

# Selective resource exports with filtering
kubectl get deployments -l environment=production -o yaml > prod-deployments.yaml
kubectl get services --field-selector spec.type=LoadBalancer -o yaml > loadbalancer-services.yaml
kubectl get pods --field-selector=status.phase=Running -o yaml > running-pods.yaml

# Wait operations for automation
kubectl wait --for=condition=ready pod -l app=<label> --timeout=300s      # Wait for pods ready
kubectl wait --for=condition=available deployment/<name> --timeout=300s   # Wait for deployment available
kubectl wait --for=delete pod/<pod-name> --timeout=60s                   # Wait for pod deletion
kubectl wait --for=condition=complete job/<job-name> --timeout=600s       # Wait for job completion
kubectl wait --for=jsonpath='{.status.replicas}'=3 deployment/<name>     # Wait for specific replica count
```

## Kustomize Integration and Advanced Configuration
```bash
# Basic Kustomize operations
kubectl apply -k <kustomization-directory>                # Apply Kustomize configuration
kubectl kustomize <kustomization-directory>               # Generate Kustomize output without applying
kubectl kustomize <kustomization-directory> | kubectl apply -f -  # Pipe to apply
kubectl diff -k <kustomization-directory>                 # Show differences with Kustomize
kubectl delete -k <kustomization-directory>               # Delete Kustomize resources

# Advanced Kustomize workflows
kubectl kustomize ./base > base-resources.yaml            # Generate base resources
kubectl kustomize ./overlays/production > prod-resources.yaml  # Generate overlay resources
kubectl kustomize --enable-helm ./chart-dir               # Kustomize with Helm integration

# Kustomize validation and testing
kubectl kustomize . --dry-run=client                      # Validate Kustomize configuration
kubectl apply -k . --dry-run=server --validate=true      # Server-side validation
kubectl diff -k . --server-side                          # Server-side diff with Kustomize

# Multi-environment management with Kustomize
kubectl apply -k ./overlays/development                   # Apply development environment
kubectl apply -k ./overlays/staging                       # Apply staging environment
kubectl apply -k ./overlays/production                    # Apply production environment
kubectl get all -l kustomize.component=frontend -o yaml   # Get resources by Kustomize component
```

## GitOps and CI/CD Pipeline Integration
```bash
# Git-based deployment workflows
kubectl apply -f https://raw.githubusercontent.com/user/repo/main/k8s/deployment.yaml  # Deploy from Git URL
kubectl delete -f https://raw.githubusercontent.com/user/repo/main/k8s/deployment.yaml # Delete from Git URL
kubectl diff -f https://raw.githubusercontent.com/user/repo/main/k8s/deployment.yaml   # Diff from remote

# Pipeline-friendly commands for CI/CD
kubectl set image deployment/<name> container=image:$BUILD_TAG  # Update image with build tag
kubectl rollout status deployment/<name> --timeout=300s        # Wait for rollout in pipeline
kubectl get deployment <name> -o jsonpath='{.spec.template.spec.containers[0].image}'  # Get current image
kubectl annotate deployment <name> deployment.kubernetes.io/revision="$(date +%s)"    # Add revision annotation

# Blue-green deployment automation
kubectl patch service <service-name> -p '{"spec":{"selector":{"version":"green"}}}'  # Switch traffic to green
kubectl scale deployment <name>-blue --replicas=0     # Scale down blue deployment
kubectl scale deployment <name>-green --replicas=3    # Scale up green deployment
kubectl wait --for=condition=available deployment/<name>-green --timeout=300s  # Wait for green ready

# Canary deployment patterns
kubectl patch deployment <name> -p '{"spec":{"replicas":1}}'   # Start with single canary replica
kubectl wait --for=condition=available deployment/<name> --timeout=120s  # Wait for canary ready
# Monitor metrics, then scale up if successful
kubectl scale deployment <name> --replicas=3                   # Scale up if canary successful

# Rollback automation
kubectl rollout undo deployment/<name> --to-revision=1         # Rollback to specific revision
kubectl wait --for=condition=available deployment/<name> --timeout=300s  # Wait for rollback complete
kubectl rollout status deployment/<name>                       # Verify rollback status

# Health check automation for pipelines
kubectl get pods -l app=<name> --field-selector=status.phase=Running --no-headers | wc -l  # Count running pods
kubectl get deployment <name> -o jsonpath='{.status.readyReplicas}'  # Get ready replica count
kubectl get service <name> -o jsonpath='{.status.loadBalancer.ingress[0].ip}'  # Get external IP
```

## Advanced Automation Scripts and Patterns
```bash
# Create deployment automation script
cat > deploy.sh << 'EOF'
#!/bin/bash
set -euo pipefail

APP_NAME=${1:-webapp}
IMAGE_TAG=${2:-latest}
NAMESPACE=${3:-default}

echo "Deploying $APP_NAME:$IMAGE_TAG to $NAMESPACE"

# Update deployment image
kubectl set image deployment/$APP_NAME container=$APP_NAME:$IMAGE_TAG -n $NAMESPACE

# Wait for rollout to complete
kubectl rollout status deployment/$APP_NAME -n $NAMESPACE --timeout=300s

# Verify deployment health
READY_REPLICAS=$(kubectl get deployment $APP_NAME -n $NAMESPACE -o jsonpath='{.status.readyReplicas}')
DESIRED_REPLICAS=$(kubectl get deployment $APP_NAME -n $NAMESPACE -o jsonpath='{.spec.replicas}')

if [ "$READY_REPLICAS" = "$DESIRED_REPLICAS" ]; then
  echo "Deployment successful: $READY_REPLICAS/$DESIRED_REPLICAS replicas ready"
else
  echo "Deployment failed: $READY_REPLICAS/$DESIRED_REPLICAS replicas ready"
  exit 1
fi
EOF
chmod +x deploy.sh

# Resource cleanup automation script
cat > cleanup.sh << 'EOF'
#!/bin/bash
set -euo pipefail

NAMESPACE=${1:-default}
DRY_RUN=${2:-false}

echo "Cleaning up resources in namespace: $NAMESPACE"

if [ "$DRY_RUN" = "true" ]; then
  DRY_RUN_FLAG="--dry-run=client"
else
  DRY_RUN_FLAG=""
fi

# Clean up failed pods
echo "Cleaning up failed pods..."
kubectl delete pods --field-selector=status.phase=Failed -n $NAMESPACE $DRY_RUN_FLAG

# Clean up completed jobs
echo "Cleaning up completed jobs..."
kubectl delete jobs --field-selector=status.successful=1 -n $NAMESPACE $DRY_RUN_FLAG

# Clean up empty replica sets
echo "Cleaning up empty replica sets..."
kubectl get rs -n $NAMESPACE -o json | \
  jq '.items[] | select(.spec.replicas == 0) | .metadata.name' | \
  xargs -r kubectl delete rs -n $NAMESPACE $DRY_RUN_FLAG

echo "Cleanup completed for namespace: $NAMESPACE"
EOF
chmod +x cleanup.sh

# Multi-environment deployment script
cat > multi-env-deploy.sh << 'EOF'
#!/bin/bash
set -euo pipefail

IMAGE_TAG=${1:-latest}
ENVIRONMENTS=("development" "staging" "production")

for ENV in "${ENVIRONMENTS[@]}"; do
  echo "Deploying to $ENV environment..."
  
  # Apply environment-specific configuration
  kubectl apply -k ./overlays/$ENV
  
  # Update image tags
  kubectl set image deployment/webapp webapp=myapp:$IMAGE_TAG -n $ENV
  
  # Wait for deployment
  kubectl rollout status deployment/webapp -n $ENV --timeout=300s
  
  # Run health checks
  kubectl wait --for=condition=available deployment/webapp -n $ENV --timeout=120s
  
  echo "$ENV deployment completed successfully"
  
  # Add approval gate for production
  if [ "$ENV" = "staging" ]; then
    read -p "Proceed to production? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Deployment stopped at staging"
      exit 0
    fi
  fi
done

echo "All environments deployed successfully"
EOF
chmod +x multi-env-deploy.sh
```