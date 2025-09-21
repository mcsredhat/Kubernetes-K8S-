# Quick Reference and Emergency Procedures

## Essential Command Patterns and Structure
```bash
# General command structure patterns
kubectl <action> <resource-type> <resource-name> [flags]           # Basic structure
kubectl <action> <resource-type> -l <label-selector> [flags]       # Label-based selection
kubectl <action> <resource-type> --field-selector=<field>=<value>  # Field-based selection
kubectl <action> <resource-type> -o <output-format> [flags]        # Custom output format

# Most common flag combinations for maximum efficiency
kubectl get <resource> --output wide --sort-by=<jsonpath> --show-labels     # Comprehensive view
kubectl get <resource> -w --output-watch-events --timestamp                 # Detailed watching
kubectl get <resource> --all-namespaces -l <selector> --field-selector=<field>=<value>  # Cross-namespace filtering
kubectl describe <resource> <name> | grep -A <N> -B <N> <pattern>          # Focused describe output

# Resource name patterns and shortcuts
kubectl get po,svc,deploy,ing -l app=<name>              # Multiple resources with labels
kubectl get all -l app=<name>                           # All standard resources
kubectl get pods/deployment/<name> -o yaml              # Specific resource with path syntax
```

## Advanced Aliases for Power Users
```bash
# Add these to your ~/.bashrc or ~/.zshrc for maximum productivity
alias k=kubectl
alias kaf='kubectl apply -f'
alias kdf='kubectl delete -f'
alias kcf='kubectl create -f'
alias kgp='kubectl get pods'
alias kgpa='kubectl get pods --all-namespaces'
alias kgpaw='kubectl get pods --all-namespaces -o wide'
alias kgpw='kubectl get pods -o wide'
alias kgpsl='kubectl get pods --show-labels'
alias kgpby='kubectl get pods --sort-by=.metadata.creationTimestamp'
alias kgd='kubectl get deployments'
alias kgdw='kubectl get deployments -o wide'
alias kgs='kubectl get services'
alias kgsw='kubectl get services -o wide'
alias kgn='kubectl get nodes'
alias kgnw='kubectl get nodes -o wide'
alias kgns='kubectl get namespaces'
alias kgi='kubectl get ingress'
alias kgall='kubectl get all'
alias kgh='kubectl get hpa'

# Resource description shortcuts
alias kdp='kubectl describe pod'
alias kdd='kubectl describe deployment'
alias kds='kubectl describe service'
alias kdn='kubectl describe node'
alias kdi='kubectl describe ingress'

# Node management aliases
alias kdrain='kubectl drain --ignore-daemonsets --delete-emptydir-data --force'
alias kuncordon='kubectl uncordon'
alias kcordon='kubectl cordon'

# Context and namespace management
alias kgc='kubectl config get-contexts'
alias kcc='kubectl config current-context'
alias kuc='kubectl config use-context'
alias kns='kubectl config set-context --current --namespace'

# Debugging and troubleshooting aliases
alias klo='kubectl logs'
alias klof='kubectl logs -f'
alias klop='kubectl logs --previous'
alias kex='kubectl exec -it'
alias kdebug='kubectl run debug-pod --image=busybox --rm -it --restart=Never -- sh'
alias knetdebug='kubectl run netdebug --image=nicolaka/netshoot --rm -it --restart=Never -- bash'
alias kcurl='kubectl run curl --image=curlimages/curl --rm -it --restart=Never -- sh'

# Resource monitoring aliases
alias ktop='kubectl top'
alias ktopn='kubectl top nodes'
alias ktopp='kubectl top pods'
alias ktoppall='kubectl top pods --all-namespaces'
alias ktoppn='kubectl top pods --all-namespaces --sort-by=memory | head -20'
alias kdes='kubectl describe'
alias kdel='kubectl delete'
alias kwait='kubectl wait --for=condition=ready'

# Output format shortcuts
alias kgy='kubectl get -o yaml'
alias kgj='kubectl get -o json'
alias kgw='kubectl get -o wide'
alias kgsl='kubectl get --show-labels'

# Port forwarding shortcuts
alias kpf='kubectl port-forward'
alias kpfs='kubectl port-forward service/'
alias kpfd='kubectl port-forward deployment/'

# Advanced resource management
alias kscale='kubectl scale deployment'
alias kpatch='kubectl patch'
alias krollout='kubectl rollout'
alias krs='kubectl rollout status'
alias kru='kubectl rollout undo'
alias krh='kubectl rollout history'
```

## Emergency Response Commands and Procedures
```bash
# Immediate cluster health assessment (run as single command)
echo "=== CLUSTER HEALTH CHECK ===" && \
kubectl get nodes && echo && \
kubectl get pods --all-namespaces --field-selector=status.phase!=Running && echo && \
kubectl get events --sort-by=.lastTimestamp | tail -10

# Critical resource pressure investigation
kubectl top nodes --sort-by=memory && echo "---" && \
kubectl top pods --all-namespaces --sort-by=memory | head -10 && echo "---" && \
kubectl get events --field-selector=reason=FailedScheduling --since=30m

# Network connectivity emergency test
kubectl run connectivity-test --image=busybox --rm -it --restart=Never -- sh -c "
nslookup kubernetes.default.svc.cluster.local && 
wget -qO- --timeout=5 http://kubernetes.default.svc.cluster.local:443 > /dev/null 2>&1 && echo 'API reachable' || echo 'API unreachable'"

# Quick deployment restart for service recovery
kubectl rollout restart deployment/<deployment-name>
kubectl rollout status deployment/<deployment-name> --timeout=300s

# Emergency pod deletion when stuck in terminating state
kubectl delete pod <pod-name> --grace-period=0 --force

# Cluster resource utilization emergency summary
kubectl describe nodes | grep -A 5 "Allocated resources" && echo "---" && \
kubectl get pods --all-namespaces --field-selector=status.phase=Pending

# Service endpoint emergency check
kubectl get endpoints --all-namespaces | grep -E "<none>|<unset>" && echo "Services without endpoints found"

# Storage emergency assessment  
kubectl get pvc --all-namespaces --field-selector=status.phase=Pending && echo "Pending PVCs found"
kubectl get events --field-selector reason=FailedMount --since=1h

# Certificate expiration emergency check
kubectl get secrets --all-namespaces --field-selector type=kubernetes.io/tls -o json | \
jq -r '.items[] | select(.data."tls.crt") | "\(.metadata.namespace)/\(.metadata.name)"' | \
xargs -I {} sh -c 'echo "Checking {}" && kubectl get secret {} -o jsonpath="{.data.tls\.crt}" | base64 -d | openssl x509 -enddate -noout'
```

## Emergency Troubleshooting Workflows
```bash
# Application Down Emergency Response
echo "=== APPLICATION DOWN RESPONSE ==="
APP_NAME="$1"
NAMESPACE="${2:-default}"

echo "1. Check deployment status:"
kubectl get deployment $APP_NAME -n $NAMESPACE

echo "2. Check pod status:"
kubectl get pods -l app=$APP_NAME -n $NAMESPACE

echo "3. Check recent events:"
kubectl get events -n $NAMESPACE --sort-by=.lastTimestamp | grep $APP_NAME | tail -5

echo "4. Check service endpoints:"
kubectl get endpoints $APP_NAME -n $NAMESPACE

echo "5. Quick restart if needed:"
echo "kubectl rollout restart deployment/$APP_NAME -n $NAMESPACE"

# Node Failure Emergency Response
NODE_NAME="$1"
echo "=== NODE FAILURE RESPONSE ==="
echo "1. Check node status:"
kubectl describe node $NODE_NAME | grep -A 10 "Conditions"

echo "2. List pods on failing node:"
kubectl get pods --all-namespaces --field-selector spec.nodeName=$NODE_NAME

echo "3. Cordon node to prevent new pods:"
echo "kubectl cordon $NODE_NAME"

echo "4. Drain node safely:"
echo "kubectl drain $NODE_NAME --ignore-daemonsets --delete-emptydir-data --force"

# Storage Full Emergency Response
echo "=== STORAGE EMERGENCY RESPONSE ==="
echo "1. Check node disk usage:"
kubectl describe nodes | grep -A 5 "Conditions" | grep -E "(DiskPressure|MemoryPressure)"

echo "2. Find large pods by storage requests:"
kubectl get pods --all-namespaces -o json | \
jq '.items[] | select(.spec.containers[0].resources.requests.storage) | {name: .metadata.name, namespace: .metadata.namespace, storage: .spec.containers[0].resources.requests.storage}'

echo "3. Check for evicted pods:"
kubectl get pods --all-namespaces --field-selector=status.phase=Failed | grep Evicted

echo "4. Clean up completed pods:"
echo "kubectl delete pods --all-namespaces --field-selector=status.phase=Succeeded"
```

## Best Practices Quick Reference
```bash
# Always verify before destructive operations
kubectl <command> --dry-run=client -o yaml    # Preview changes
kubectl delete <resource> --dry-run=client         # Preview deletions  
kubectl apply --dry-run=server -f <file>          # Server-side validation
kubectl diff -f <file>                            # Show differences before apply

# Use labels and selectors effectively
kubectl label pods -l app=old-app app=new-app     # Batch labeling
kubectl get all -l app=<app-name>                 # Application-centric view
kubectl delete all -l app=<app-name>              # Clean application removal

# Monitor and validate operations
kubectl rollout status deployment/<n>          # Verify deployments
kubectl wait --for=condition=ready pod -l app=<n> --timeout=300s  # Wait for readiness
kubectl get events --watch --field-selector involvedObject.name=<resource>  # Monitor specific resource

# Resource management best practices
kubectl set resources deployment/<n> --requests=cpu=100m,memory=128Mi --limits=cpu=500m,memory=512Mi  # Set resource constraints
kubectl autoscale deployment <n> --min=2 --max=10 --cpu-percent=70  # Enable autoscaling
kubectl create quota <quota-name> --hard=cpu=2,memory=4Gi,pods=10    # Set resource quotas

# Security best practices
kubectl auth can-i <verb> <resource> --as=<user>  # Test permissions
kubectl create serviceaccount <sa-name>           # Use dedicated service accounts
kubectl create rolebinding <binding> --role=<role> --serviceaccount=<ns>:<sa>  # Grant minimal permissions
kubectl get pods -o custom-columns=NAME:.metadata.name,SECURITY-CONTEXT:.spec.securityContext  # Review security contexts
```

## Essential Kubectl Plugin Recommendations
```bash
# Must-have plugins for production operations
kubectl krew install ctx        # Context switching (kubectx)
kubectl krew install ns         # Namespace switching (kubens)
kubectl krew install tree       # Resource hierarchy visualization
kubectl krew install neat       # Clean YAML output
kubectl krew install tail       # Multi-pod log tailing
kubectl krew install view-secret # Decode secrets easily
kubectl krew install who-can    # RBAC analysis
kubectl krew install resource-capacity  # Cluster resource analysis

# Usage examples
kubectl ctx                     # List contexts
kubectl ctx <context-name>      # Switch context
kubectl ns                      # List namespaces  
kubectl ns <namespace>          # Switch namespace
kubectl tree deployment <n> # Show resource tree
kubectl neat get pod <pod> -o yaml  # Clean YAML output
kubectl view-secret <secret> <key>  # View secret value
kubectl who-can create pods    # Show who can create pods
```

## Performance Tuning Quick Wins
```bash
# Enable kubectl completion and aliases (add to ~/.bashrc)
source <(kubectl completion bash)
alias k=kubectl
complete -F __start_kubectl k

# Use efficient queries for large clusters
kubectl get pods --chunk-size=500                          # Process in chunks
kubectl get events --limit=100 --sort-by=.lastTimestamp   # Limit results
kubectl get pods --field-selector=status.phase=Running --no-headers | wc -l  # Count without formatting

# Optimize resource requests and limits
kubectl get pods -o json | jq '.items[] | select(.spec.containers[0].resources.requests == null)'  # Find pods without requests
kubectl set resources deployment/<n> --requests=cpu=100m,memory=128Mi  # Add resource requests
kubectl autoscale deployment <n> --cpu-percent=70 --min=2 --max=10     # Enable HPA

# Use server-side apply for large manifests
kubectl apply --server-side -f large-manifest.yaml
kubectl diff -f manifest.yaml --server-side               # Server-side diff
```

## Common Error Resolution
```bash
# Pod stuck in Pending state
kubectl describe pod <pod-name> | grep -A 10 Events      # Check events
kubectl get events --field-selector reason=FailedScheduling  # Scheduling issues
kubectl describe nodes | grep -A 5 "Allocated resources" # Check resource availability

# Pod stuck in ContainerCreating
kubectl describe pod <pod-name>                          # Check for image pull issues
kubectl get events --field-selector reason=Failed        # Look for failures

# Service not accessible
kubectl get endpoints <service-name>                     # Check if service has endpoints
kubectl describe service <service-name>                  # Verify service configuration
kubectl get pods -l <service-selector>                   # Check if pods match service selector

# Deployment not rolling out
kubectl rollout status deployment/<n>                 # Check rollout status
kubectl describe deployment <n> | grep -A 10 Events   # Look for deployment events
kubectl get events --field-selector involvedObject.kind=ReplicaSet  # ReplicaSet events

# Node not ready
kubectl describe node <node-name> | grep -A 10 Conditions  # Check node conditions
kubectl get pods -n kube-system --field-selector spec.nodeName=<node-name>  # System pods on node
```

## Recovery and Backup Procedures
```bash
# Quick backup before major changes
kubectl get all,secrets,configmaps -o yaml > backup-$(date +%Y%m%d-%H%M).yaml

# Deployment rollback
kubectl rollout history deployment/<n>                # Check available revisions
kubectl rollout undo deployment/<n>                  # Rollback to previous
kubectl rollout undo deployment/<n> --to-revision=2  # Rollback to specific revision

# Cluster state export for troubleshooting
kubectl cluster-info dump --output-directory=cluster-state-$(date +%Y%m%d)

# Emergency cluster information collection
kubectl get all --all-namespaces > all-resources.yaml
kubectl get events --all-namespaces --sort-by=.lastTimestamp > all-events.txt
kubectl describe nodes > node-details.txt
kubectl top nodes > node-usage.txt
kubectl top pods --all-namespaces > pod-usage.txt
```

---

This comprehensive kubectl reference guide provides the essential tools and knowledge needed for effective Kubernetes operations. Each section builds upon previous concepts while serving as a standalone reference. Remember to always test commands in development environments first, use `--dry-run` flags when available, and maintain proper RBAC controls in production clusters.

The combination of these commands, aliases, and operational patterns will significantly improve your Kubernetes productivity and troubleshooting capabilities.