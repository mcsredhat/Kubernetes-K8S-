# Deployment and ReplicaSet Operations

Deployments provide declarative updates and rollback capabilities, making them essential for production workload management. Master these commands to handle application lifecycle management effectively.

## Deployment Creation and Management
```bash
When you create a Kubernetes deployment, you're essentially telling the cluster "I want this many copies of my application running, and here's how they should look." A deployment is a declarative way to manage your application's lifecycle. You write a YAML file describing your desired state, and Kubernetes works continuously to make reality match that description.
The deployment acts as a supervisor that creates and manages ReplicaSets, which in turn manage your actual application pods. When you create a deployment, you specify things like the container image to use, how many replicas you want, resource limits, environment variables, and health checks. Kubernetes then takes this specification and begins orchestrating the necessary resources to bring your application to life.
The beauty of this declarative approach is that you describe what you want, not how to get there. If a pod crashes, the deployment controller notices the mismatch between desired state and actual state, then automatically creates a replacement pod. This self-healing capability is fundamental to Kubernetes' reliability.

# Basic deployment creation
kubectl create deployment <name> --image=<image>              # Simple deployment
kubectl create deployment <name> --image=<image> --replicas=3  # With replica coun
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
kubectl delete deployment <name> --namespace=<name-of-namespace>   # Delete deployment
kubectl get deployments.apps --namespace=dev                       # List all deployments
kubectl get deployments --namespace=dev  -o wide            # Extended deployment information
kubectl describe deployment <name> --namespace=dev          # Detailed deployment information
```

## Deployment Scaling Operations
```bash
Scaling is about adjusting the number of running instances of your application to meet demand. With Kubernetes deployments, scaling can happen in two ways: manually or automatically.
Manual scaling is straightforward. You update the replica count in your deployment specification, and Kubernetes adjusts the number of running pods accordingly. If you scale from three replicas to five, Kubernetes creates two additional pods. If you scale down from five to three, it gracefully terminates two pods, ensuring that traffic is drained properly before shutdown.
Horizontal Pod Autoscaling takes this further by automatically adjusting replicas based on metrics like CPU utilization, memory usage, or custom metrics from your application. The autoscaler watches these metrics and scales your deployment up when demand increases and back down when it decreases. This creates a responsive system that efficiently uses resources while maintaining performance.
The scaling operation itself is intelligent. When scaling up, new pods are created and must pass health checks before receiving traffic. When scaling down, Kubernetes selects which pods to terminate based on various factors, preferring to remove unhealthy or newer pods first, and it respects termination grace periods to allow graceful shutdown.
# Manual scaling
kubectl scale deployment <name> --namespace=<namespace> --replicas=5  # Scale to specific count
kubectl scale deployment <name> --replicas=0 --namespace=<namespace>     # Scale down to zero
kubectl scale deployments --all --replicas=2                    # Scale all deployments
kubectl scale deployment <name> --current-replicas=3 --replicas=5  --namespace=<namespace> 
# Conditional scaling

# Horizontal Pod Autoscaling (HPA)
kubectl autoscale deployment <name> --min=2 --max=10 --cpu-percent=70  # CPU-based autoscaling
  # Memory-based autoscaling
kubectl get hpa                                       # List horizontal pod autoscalers
kubectl get hpa -o wide                               # Extended HPA information
kubectl describe hpa <hpa-name>                       # HPA details and current status
kubectl delete hpa <hpa-name>                         # Remove autoscaling
kubectl get horizontalpodautoscalers.autoscaling --namespace=dev -o yaml #
kubectl get hpa -n dev -o custom-columns=NAME:.metadata.name,CPU_TARGET:.spec.metrics[0].resource.target.averageUtilization
kubectl get horizontalpodautoscalers.autoscaling --namespace=dev -o custom-columns=NAME:.metadata.name,UID:.metadata.uid,MAXREPLICAS:.spec.maxReplicas,AVGUTILISATION:.spec.metrics[0].resource.target.averageUtilization,MSQ:.status.conditions[0].message
# Advanced HPA configuration
kubectl patch hpa <hpa-name> -p '{"spec":{"maxReplicas":20}}'   # Update max replicas
kubectl get hpa <hpa-name> -o yaml                              # Full HPA configuration

# Advanced scaling scenarios
kubectl scale deployment <name> --replicas=3 --timeout=300s     # Scaling with timeout
kubectl patch deployment <name> -p '{"spec":{"replicas":5}}'    # Patch-based scaling
kubectl patch deployment <name> --type='merge' -p '{"spec":{"template":{"spec":{"containers":[{"name":"front-end-app","resources":{"requests":{"memory":"256Mi"}}}]}}}}'  # Resource-based scaling
```
kubectl patch deployment front-end-app -n dev --type='strategic' -p '{"spec": {"template": {"spec": {"containers": [ {"name": "front-end-app","image": "nginx:1.21","resources": {"requests": {clear"memory": "128Mi","cpu": "128m"}}}]}}}}'


## Deployment Updates and Rolling Updates
```bash
Updating applications without downtime is where deployments truly shine. When you update your deployment with a new container image or configuration change, Kubernetes performs a rolling update by default. This means it gradually replaces old pods with new ones, ensuring your application remains available throughout the process.
During a rolling update, Kubernetes creates new pods with the updated specification while keeping old pods running. As each new pod becomes ready and passes its health checks, Kubernetes begins routing traffic to it and terminates an old pod. This process continues until all pods are running the new version. The pace of this rollout is controlled by parameters like maximum surge, which determines how many extra pods can exist during the update, and maximum unavailable, which limits how many pods can be down simultaneously.
This approach provides a safety net. If the new version has problems, your old pods are still running, and you can quickly rollback. The deployment controller monitors the rollout progress and can automatically pause if it detects issues based on your readiness probes. You can also manually pause a rollout, observe the behavior of the new version with partial traffic, and then decide whether to continue or rollback.
# Image updates
kubectl set image deployment/<name> <container-name>=<new-image>  # Update container image
kubectl set image deployment/front-end-app --namespace=dev front-end-app=nginx:1.21             # Specific example
kubectl set image deployment/<name> *=<new-image>                # Update all containers
kubectl set image deployment/<name> container1=image1:v2,container2=image2:v2  # Multiple containers
kubectl set resources deployment front-end-app \
  -n dev \
  --containers=front-end-app \
  --requests=memory=256Mi,cpu=256m

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
 kubectl get deployment front-end-app -n dev   -o custom-columns=NAME:.metadata.name,ENV:.spec.template.spec.containers[0].env[0].value,LIMITS:.spec.template.spec.containers[0].resources.limits.cpu,REsourceMEM:spec.template.spec.containers[0].resources.requests.memory 
# Advanced update strategies
kubectl patch deployment <name> -p '{"spec":{"strategy":{"rollingUpdate":{"maxSurge":"50%","maxUnavailable":"25%"}}}}'  # Update strategy
kubectl patch deployment <name> -p '{"spec":{"progressDeadlineSeconds":600}}'  # Update timeout
```

## Rollback and History Management
```bash
Kubernetes maintains a revision history for your deployments, creating a time machine for your application state. Each time you update a deployment, Kubernetes saves the previous ReplicaSet rather than deleting it. This historical record allows you to rollback to any previous version quickly.
When you trigger a rollback, Kubernetes doesn't need to pull new images or create new configurations from scratch. It simply scales up the old ReplicaSet and scales down the current one, using the same rolling update mechanism but in reverse. This makes rollbacks fast and reliable.
The history depth is configurable through the revision history limit. By default, Kubernetes keeps the last ten revisions, but you can adjust this based on your needs. Each revision includes the complete pod template specification, so you can inspect exactly what configuration was running at any point in time. You can also annotate changes with descriptions using change-cause annotations, creating an audit trail of why changes were made.

# Rollback operations
kubectl rollout history deployment/<name> --namespace=dev            # View rollout history
kubectl rollout history deployment/<name> --namespace=dev --revision=2 # Specific revision details
kubectl rollout history deployment/<name> --namespace=dev --limit=5              # Limit history entries
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
Understanding ReplicaSets helps you grasp what's happening under the hood of deployments. A ReplicaSet ensures that a specified number of identical pod replicas are running at any given time. It continuously monitors the cluster and creates or deletes pods to maintain the desired count.
When you examine a deployment, you'll typically see multiple ReplicaSets associated with it. The active ReplicaSet has the current desired replica count, while previous ReplicaSets from earlier versions are scaled to zero but retained for rollback purposes. Each ReplicaSet has a unique pod template hash that identifies which version of your application it represents.
The ReplicaSet controller works through a reconciliation loop. It constantly compares the number of running pods matching its selector against the desired replica count. If there's a mismatch, it takes corrective action. This simple mechanism provides powerful reliability because the controller never stops checking and fixing discrepancies.
You can analyze ReplicaSet behavior by examining its status fields, which show how many replicas are desired, current, ready, and available. These distinctions matter because a pod might be current (created) but not ready (failing health checks) or not available (not ready for the minimum required time). Understanding these states helps you diagnose deployment issues.

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
kubectl get rs -o custom-columns=NAME:.metadata.name,DESIRED:.spec.replicas,CURRENT:.status.replicas,READY:.status.readyReplicas,SELECTOR:.spec.selector.matchLabels --namespace=dev 


# ReplicaSet selector analysis
kubectl get rs <rs-name> -o jsonpath='{.spec.selector.matchLabels}'  # Selector labels
kubectl get pods --selector="$(kubectl get rs <rs-name> -o jsonpath='{.spec.selector.matchLabels}' | tr -d '{}')" --namespace=dev # Matching pods

# Custom output for ReplicaSet analysis
kubectl get replicasets -o custom-columns=\
NAME:.metadata.name,\
DESIRED:.spec.replicas,\
CURRENT:.status.replicas,\
READY:.status.readyReplicas,\
AGE:.metadata.creationTimestamp,\
OWNER:.metadata.ownerReferences[0].name \
--namespace=dev
```

## Deployment Strategy and Configuration Analysis
```bash
Deployment strategies determine how updates roll out. The two primary strategies are RollingUpdate and Recreate, each with different tradeoffs.
RollingUpdate, the default strategy, provides zero-downtime deployments by gradually replacing pods as we discussed. You can fine-tune this behavior through maxSurge and maxUnavailable parameters. A maxSurge of one means Kubernetes can create one extra pod beyond your desired count during the update, speeding up the rollout. A maxUnavailable of one means one pod can be down during the update, which might be acceptable for non-critical applications but risky for services requiring high availability.
The Recreate strategy takes a simpler but more disruptive approach. It terminates all old pods before creating new ones, causing downtime but ensuring that old and new versions never run simultaneously. This strategy is useful when your application can't handle multiple versions running concurrently, perhaps due to database schema migrations or stateful operations that would conflict.
Configuration analysis involves examining your deployment's resource requests and limits, health check configurations, update parameters, and selector labels. These settings profoundly impact reliability and performance. Too-aggressive rolling update parameters might overwhelm your infrastructure, while too-conservative settings make deployments unnecessarily slow. Poorly configured health checks can cause endless restart loops or allow unhealthy pods to receive traffic.

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
Blue-green deployments maintain two complete environments. You run version one in the blue environment while preparing version two in the green environment. Once green is ready and tested, you switch traffic from blue to green instantaneously by updating a service selector. This provides instant rollback capability and allows thorough testing of the new version with production-like traffic before cutover, but it requires double the resources during the transition.
kubectl patch deployment <name> --namespace=dev -p '{"spec":{"selector":{"matchLabels":{"version":"green"}}}}'  # Switch selector
kubectl scale deployment <name>-blue --replicas=0 --namespace=dev   # Scale down old version
kubectl scale deployment <name>-green --replicas=3 --namespace=dev  # Scale up new version

# Canary deployment management
Canary deployments release new versions gradually to a subset of users before full rollout. You might deploy the new version to a single pod while keeping nine pods on the old version, sending ten percent of traffic to the canary. If metrics look good, you gradually increase the canary's percentage. This pattern catches problems before they affect all users, but it requires sophisticated traffic routing, often using service meshes or ingress controllers with weighted routing capabilities.

kubectl patch deployment <name> --namespace=dev -p '{"metadata":{"labels":{"deployment":"canary"}}}'  # Mark as canary
kubectl scale deployment <name>-canary --replicas=1  # Single replica for testing
kubectl get pods -l deployment=canary --namespace=dev -o wide        # Monitor canary pods

# Multi-environment deployment comparison
A/B testing deployments run multiple versions simultaneously to compare user behavior and business metrics. Unlike canaries, where the goal is validating stability, A/B tests validate feature effectiveness. You might route users based on geography, user attributes, or random selection, then measure conversion rates or engagement across versions.
Feature flag deployments decouple code deployment from feature release. You deploy new code with features hidden behind runtime flags, then gradually enable features for specific users without redeploying. This pattern maximizes deployment safety and allows instant rollback by toggling flags, though it adds complexity to your application code and requires a feature flag management system.

kubectl diff -k ./overlays/production/               # Compare with Kustomize overlay
kubectl get deployments -l environment=production -o custom-columns=NAME:.metadata.name,IMAGE:.spec.template.spec.containers[0].image,REPLICAS:.spec.replicas

# Deployment health and readiness validation
kubectl wait --for=condition=available --timeout=300s deployment/<name>  # Wait for availability
kubectl get deployment <name> -o jsonpath='{.status.readyReplicas}'/{.spec.replicas}  # Ready ratio
kubectl rollout status deployment/<name> | grep -q "successfully rolled out" && echo "Deployment successful" || echo "Deployment failed"
```