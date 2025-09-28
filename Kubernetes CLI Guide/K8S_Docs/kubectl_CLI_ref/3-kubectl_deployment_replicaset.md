# Deployment and ReplicaSet Operations

Deployments provide declarative updates and rollback capabilities, making them essential for production workload management. Master these commands to handle application lifecycle management effectively.

## Deployment Creation and Management
```bash
# Basic deployment creation
kubectl create deployment <name> --image=<image>              # Simple deployment
kubectl create deployment <name> --image=<image> --replicas=3  # With replica count
kubectl create deployment <name> --image=nginx --port=80      # With exposed port

# Advanced deployment creation with dry-run
kubectl create deployment webapp \
  --image=nginx:1.21-alpine \
  --replicas=3 \
  --port=80 \
  --namespace=production \
  --dry-run=client -o yaml > webapp-base.yaml

# Deployment from YAML with configuration comparison
kubectl apply -f deployment.yaml              # Apply deployment configuration
kubectl diff -f deployment.yaml               # Show differences before applying
kubectl replace -f deployment.yaml            # Replace (recreate) deployment
kubectl create -f deployment.yaml             # Create new deployment (fails if exists)

# Deployment management operations
kubectl delete deployment <name>              # Delete deployment
kubectl get deployments.apps --namespace=dev                       # List all deployments
kubectl get deployments --namespace=dev  -o wide            # Extended deployment information
kubectl describe deployment <name> --namespace=dev          # Detailed deployment information
```

## Deployment Scaling Operations
```bash
# Manual scaling
kubectl scale deployment <name> --replicas=5                    # Scale to specific count
kubectl scale deployment <name> --replicas=0                    # Scale down to zero
kubectl scale deployments --all --replicas=2                    # Scale all deployments
kubectl scale deployment <name> --current-replicas=3 --replicas=5  # Conditional scaling

# Horizontal Pod Autoscaling (HPA)
kubectl autoscale deployment <name> --min=2 --max=10 --cpu-percent=70  # CPU-based autoscaling
kubectl autoscale deployment <name> --min=1 --max=5 --memory-percent=80  # Memory-based autoscaling
kubectl get hpa                                       # List horizontal pod autoscalers
kubectl get hpa -o wide                               # Extended HPA information
kubectl describe hpa <hpa-name>                       # HPA details and current status
kubectl delete hpa <hpa-name>                         # Remove autoscaling

# Advanced HPA configuration
kubectl patch hpa <hpa-name> -p '{"spec":{"maxReplicas":20}}'   # Update max replicas
kubectl get hpa <hpa-name> -o yaml                              # Full HPA configuration

# Advanced scaling scenarios
kubectl scale deployment <name> --replicas=3 --timeout=300s     # Scaling with timeout
kubectl patch deployment <name> -p '{"spec":{"replicas":5}}'    # Patch-based scaling
kubectl patch deployment <name> --type='merge' -p '{"spec":{"template":{"spec":{"containers":[{"name":"container-name","resources":{"requests":{"memory":"256Mi"}}}]}}}}'  # Resource-based scaling
```

## Deployment Updates and Rolling Updates
```bash
# Image updates
kubectl set image deployment/<name> <container-name>=<new-image>  # Update container image
kubectl set image deployment/webapp nginx=nginx:1.22             # Specific example
kubectl set image deployment/<name> *=<new-image>                # Update all containers
kubectl set image deployment/<name> container1=image1:v2,container2=image2:v2  # Multiple containers

# Rolling update control and monitoring
kubectl rollout status deployment/<name>              # Check rollout status
kubectl rollout status deployment/<name> --timeout=300s  # Status with timeout
kubectl rollout status deployment/<name> --watch      # Watch rollout progress
kubectl rollout pause deployment/<name>               # Pause ongoing rollout
kubectl rollout resume deployment/<name>              # Resume paused rollout
kubectl rollout restart deployment/<name>             # Force restart (recreate pods)

# Environment and configuration updates
kubectl set env deployment/<name> KEY=VALUE           # Set environment variable
kubectl set env deployment/<name> KEY-                # Remove environment variable
kubectl set env deployment/<name> --from=configmap/<config-name>  # From ConfigMap
kubectl set env deployment/<name> --from=secret/<secret-name>     # From Secret
kubectl set env deployment/<name> --list              # List current environment variables

# Resource limit updates
kubectl set resources deployment/<name> --limits=cpu=200m,memory=512Mi --requests=cpu=100m,memory=256Mi  # Resource limits
kubectl set resources deployment/<name> -c <container-name> --limits=cpu=500m  # Specific container
kubectl patch deployment <name> -p '{"spec":{"template":{"spec":{"containers":[{"name":"container-name","resources":{"limits":{"memory":"1Gi"}}}]}}}}'  # Patch resources

# Advanced update strategies
kubectl patch deployment <name> -p '{"spec":{"strategy":{"rollingUpdate":{"maxSurge":"50%","maxUnavailable":"25%"}}}}'  # Update strategy
kubectl patch deployment <name> -p '{"spec":{"progressDeadlineSeconds":600}}'  # Update timeout
```

## Rollback and History Management
```bash
# Rollback operations
kubectl rollout history deployment/<name>                        # View rollout history
kubectl rollout history deployment/<name> --revision=2           # Specific revision details
kubectl rollout history deployment/<name> --limit=5              # Limit history entries
kubectl rollout undo deployment/<name>                          # Rollback to previous revision
kubectl rollout undo deployment/<name> --to-revision=2          # Rollback to specific revision
kubectl rollout undo deployment/<name> --dry-run=client         # Preview rollback

# History analysis and annotation
kubectl rollout history deployment/<name> -o yaml               # Detailed history in YAML
kubectl annotate deployment <name> deployment.kubernetes.io/revision-history-limit=10  # Set history limit
kubectl describe deployment <name> | grep -A 10 Annotations     # Deployment annotations
kubectl get replicasets -l app=<name> --show-labels            # Related ReplicaSets

# Advanced rollback scenarios
kubectl patch deployment <name> -p '{"metadata":{"annotations":{"deployment.kubernetes.io/revision":"3"}}}'  # Manual revision update
kubectl get replicaset <rs-name> -o yaml | kubectl apply -f -   # Manual ReplicaSet restoration
```

## ReplicaSet Operations and Analysis
```bash
# ReplicaSet monitoring (usually managed by Deployments)
kubectl get replicasets                               # List all ReplicaSets
kubectl get replicasets -o wide                       # Extended ReplicaSet info
kubectl get rs                                        # Shorthand for replicasets
kubectl describe replicaset <rs-name>                 # Detailed ReplicaSet information
kubectl get rs --sort-by=.metadata.creationTimestamp # Sort ReplicaSets by age

# ReplicaSet relationships and debugging
kubectl get replicasets -l app=<app-name> --show-labels       # Show selector labels
kubectl get pods -l <replicaset-selector>                     # Pods managed by ReplicaSet
kubectl describe replicaset <rs-name> | grep -A 20 "Pod Template"  # Pod template details
kubectl get rs -o custom-columns=NAME:.metadata.name,DESIRED:.spec.replicas,CURRENT:.status.replicas,READY:.status.readyReplicas,SELECTOR:.spec.selector.matchLabels


# ReplicaSet selector analysis
kubectl get rs <rs-name> -o jsonpath='{.spec.selector.matchLabels}'  # Selector labels
kubectl get pods --selector="$(kubectl get rs <rs-name> -o jsonpath='{.spec.selector.matchLabels}' | tr -d '{}')"  # Matching pods

# Custom output for ReplicaSet analysis
kubectl get replicasets -o custom-columns=\
NAME:.metadata.name,\
DESIRED:.spec.replicas,\
CURRENT:.status.replicas,\
READY:.status.readyReplicas,\
AGE:.metadata.creationTimestamp,\
OWNER:.metadata.ownerReferences[0].name
```

## Deployment Strategy and Configuration Analysis
```bash
# Deployment strategy inspection
kubectl get deployment <name> -o jsonpath='{.spec.strategy}'  # Current strategy
kubectl describe deployment <name> | grep -A 10 "StrategyType"  # Strategy details
kubectl patch deployment <name> -p '{"spec":{"strategy":{"type":"Recreate"}}}'  # Change to Recreate strategy

# Resource and constraint analysis
kubectl get deployments.apps --namespace=dev -o yaml
kubectl get deployments.apps -n dev -o custom-columns=NAME:.metadata.name,NAMESPACE:.metadata.namespace,READY_REPLICAS:.status.readyReplicas,MAX_SURGE:.spec.strategy.rollingUpdate.maxSurge,PORT:.spec.template.spec.containers[*].ports[*].containerPort,RESTART-POLICY:.spec.template.spec.restartPolicy,REASON:.status.conditions[*].reason

# Pod template and specification analysis
kubectl get deployment <name> -o jsonpath='{.spec.template.spec.containers[*].image}'  # Container images
kubectl get deployment <name> -o jsonpath='{.spec.template.metadata.labels}'         # Pod labels
kubectl get deployment <name> -o yaml | grep -A 20 "template:"                       # Pod template section

# Deployment condition monitoring
kubectl get deployment <name> -o jsonpath='{.status.conditions[*].type}'     # Condition types
kubectl get deployment <name> -o jsonpath='{.status.conditions[?(@.type=="Progressing")].status}'  # Progress status
kubectl describe deployment <name> | grep -A 5 "Conditions"                  # Detailed conditions
```

## Advanced Deployment Patterns
```bash
# Blue-Green deployment simulation
kubectl patch deployment <name> -p '{"spec":{"selector":{"matchLabels":{"version":"green"}}}}'  # Switch selector
kubectl scale deployment <name>-blue --replicas=0    # Scale down old version
kubectl scale deployment <name>-green --replicas=3   # Scale up new version

# Canary deployment management
kubectl patch deployment <name> -p '{"metadata":{"labels":{"deployment":"canary"}}}'  # Mark as canary
kubectl scale deployment <name>-canary --replicas=1  # Single replica for testing
kubectl get pods -l deployment=canary -o wide        # Monitor canary pods

# Multi-environment deployment comparison
kubectl diff -k ./overlays/production/               # Compare with Kustomize overlay
kubectl get deployments -l environment=production -o custom-columns=NAME:.metadata.name,IMAGE:.spec.template.spec.containers[0].image,REPLICAS:.spec.replicas

# Deployment health and readiness validation
kubectl wait --for=condition=available --timeout=300s deployment/<name>  # Wait for availability
kubectl get deployment <name> -o jsonpath='{.status.readyReplicas}'/{.spec.replicas}  # Ready ratio
kubectl rollout status deployment/<name> | grep -q "successfully rolled out" && echo "Deployment successful" || echo "Deployment failed"
```