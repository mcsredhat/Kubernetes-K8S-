# Cluster Administration

These administrative commands help you maintain cluster health, manage nodes, and perform routine maintenance tasks essential for production operations.

## Cluster Information and Health Assessment
```bash
# Basic cluster information and status
kubectl cluster-info                                       # Cluster endpoints and services
kubectl cluster-info dump                                 # Comprehensive cluster state dump
kubectl cluster-info dump --output-directory=cluster-dump # Save cluster dump to directory
kubectl version --short                                   # Client and server version information
kubectl version --output=yaml                             # Detailed version information

# API resources and capabilities
kubectl api-resources                                     # Available API resources
kubectl api-resources --namespaced=true                  # Only namespaced resources
kubectl api-resources --namespaced=false                 # Only cluster-scoped resources
kubectl api-resources --verbs=create,update,patch        # Resources supporting modification
kubectl api-versions                                     # Supported API versions

# Control plane component health
kubectl get componentstatuses                             # Control plane component status (deprecated)
kubectl get --raw /healthz                               # API server health endpoint
kubectl get --raw /readyz                                # API server readiness endpoint
kubectl get --raw /livez                                 # API server liveness endpoint

# Advanced cluster health assessment
kubectl get nodes --no-headers | grep -c Ready           # Count of ready nodes
kubectl get pods --all-namespaces --field-selector=status.phase!=Running --no-headers | wc -l  # Non-running pods count
kubectl get events --field-selector type=Warning --since=1h --no-headers | wc -l  # Recent warnings count
```

## Node Management and Maintenance Operations
```bash
# Node information and status
kubectl get nodes                                         # List all nodes with basic info
kubectl get nodes -o wide                                 # Detailed node information
kubectl get nodes --show-labels                          # Node labels and roles
kubectl get nodes -o yaml
kubectl get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[?(@.type==\"Ready\")].status,ROLES:.metadata.labels,VERSION:.status.nodeInfo.kubeletVersion,OS:.status.nodeInfo.osImage,IMAGE:.status.images[*].names

# Detailed node analysis
kubectl describe node <node-name>                        # Comprehensive node information
kubectl describe nodes | grep -E "(Name:|Roles:|Labels:|Taints:|Conditions:)" # Node summary across cluster
kubectl get nodes -o json | jq '.items[] | {name: .metadata.name, conditions: .status.conditions}'  # Node conditions in JSON

# Node maintenance and lifecycle management
kubectl cordon <node-name>                               # Mark node as unschedulable
kubectl uncordon <node-name>                             # Mark node as schedulable
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data --force  # Safely drain node for maintenance
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data --grace-period=300 --timeout=600s  # Graceful drain with timeouts

# Advanced drain operations
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data --pod-selector='app!=critical'  # Selective pod drainage
kubectl drain <node-name> --dry-run=client --ignore-daemonsets  # Preview drain operation
kubectl get pods --all-namespaces --field-selector spec.nodeName=<node-name> --output name | xargs kubectl delete --grace-period=0 --force  # Force pod removal

# Node troubleshooting and diagnosis
kubectl describe node <node-name> | grep -A 10 "Conditions"      # Node health conditions
kubectl describe node <node-name> | grep -A 20 "Events"          # Node-related events
kubectl get pods --all-namespaces --field-selector spec.nodeName=<node-name>  # Pods scheduled on specific node
kubectl top node <node-name>                             # Node resource usage
kubectl get --raw /api/v1/nodes/<node-name>/proxy/stats/summary | jq .  # Node statistics via proxy

# Node capacity and resource analysis
kubectl describe node <node-name> | grep -A 10 "Allocatable"     # Available node resources
kubectl describe node <node-name> | grep -A 15 "Allocated resources"  # Resource allocation
kubectl get nodes -o custom-columns=NAME:.metadata.name,CPU-CAPACITY:.status.capacity.cpu,MEMORY-CAPACITY:.status.capacity.memory,CPU-ALLOCATABLE:.status.allocatable.cpu,MEMORY-ALLOCATABLE:.status.allocatable.memory
```

## Namespace Management and Organization
```bash
# Namespace operations and analysis
kubectl get namespaces                                    # List all namespaces
kubectl get namespaces --show-labels                     # Namespaces with their labels
kubectl get ns                                           # Shorthand for namespaces
kubectl describe namespace <namespace>                   # Namespace details and resource quotas
kubectl get namespaces -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,AGE:.metadata.creationTimestamp

# Namespace creation with advanced configuration
kubectl create namespace <namespace>                     # Basic namespace creation
kubectl create namespace <namespace> --dry-run=client -o yaml > namespace.yaml  # Generate namespace YAML
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    environment: production
    team: platform
  annotations:
    description: "Production workloads"
EOF

# Namespace resource analysis
kubectl get all -n <namespace>                           # All resources in namespace
kubectl get pods,services,deployments -n <namespace>     # Specific resource types
kubectl describe namespace <namespace> | grep -A 10 "Resource Quotas"  # Namespace quotas and limits
kubectl top pods -n <namespace> --sort-by=memory         # Resource usage within namespace

# Cross-namespace resource analysis
kubectl get pods --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATUS:.status.phase | sort
kubectl get services --all-namespaces --field-selector spec.type=LoadBalancer  # LoadBalancer services across namespaces
kubectl get networkpolicies --all-namespaces             # Network policies across namespaces

# Namespace cleanup and management
kubectl delete namespace <namespace> --timeout=300s      # Delete namespace with timeout
kubectl get namespace <namespace> -o json | jq '.spec.finalizers = []' | kubectl replace --raw /api/v1/namespaces/<namespace>/finalize -f -  # Force namespace deletion (if stuck)
```

## System Component Management and Monitoring
```bash
# System pod monitoring and analysis
kubectl get pods -n kube-system                          # System component pods
kubectl get pods -n kube-system -o wide                  # System pods with detailed info
kubectl get pods -n kube-system --sort-by=.metadata.creationTimestamp  # System pods by age
kubectl describe pods -n kube-system <system-pod-name>   # System pod detailed information

# Control plane component analysis
kubectl get pods -n kube-system -l component=kube-apiserver      # API server pods
kubectl get pods -n kube-system -l component=kube-controller-manager  # Controller manager pods
kubectl get pods -n kube-system -l component=kube-scheduler     # Scheduler pods
kubectl get pods -n kube-system -l component=etcd               # etcd pods

# System component logs and debugging
kubectl logs -n kube-system <system-pod-name>            # System component logs
kubectl logs -n kube-system -l component=kube-apiserver  # API server logs from all pods
kubectl logs -n kube-system <system-pod-name> --previous # Previous container logs
kubectl logs -n kube-system <system-pod-name> --since=1h # Recent system logs

# Kubernetes API server and control plane health
kubectl get endpoints kubernetes                          # Kubernetes API endpoints
kubectl get leases -n kube-system                        # Leader election leases
kubectl get events -n kube-system --sort-by=.lastTimestamp  # System events
kubectl get configmaps -n kube-system                    # System configuration maps

# Advanced control plane monitoring
kubectl get --raw /api/v1/componentstatuses              # Component status API
kubectl get --raw /metrics | grep apiserver              # API server metrics
kubectl proxy --port=8080 &                              # Start proxy for advanced API access
curl http://localhost:8080/api/v1/namespaces/kube-system/pods  # Access via proxy
```

## Cluster Backup and Disaster Recovery
```bash
# Resource backup and export
kubectl get all --all-namespaces -o yaml > cluster-backup-$(date +%Y%m%d).yaml  # Full cluster backup
kubectl get secrets,configmaps --all-namespaces -o yaml > configs-backup-$(date +%Y%m%d).yaml  # Configuration backup
kubectl get crd -o yaml > custom-resources-backup-$(date +%Y%m%d).yaml  # Custom resource definitions

# Namespace-specific backups
kubectl get all,secrets,configmaps -n <namespace> -o yaml > <namespace>-backup-$(date +%Y%m%d).yaml
kubectl get pv,pvc -o yaml > storage-backup-$(date +%Y%m%d).yaml  # Persistent storage backup

# ETCD backup procedures (if direct access available)
kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}'  # Find etcd pod
kubectl exec -n kube-system <etcd-pod> -- etcdctl snapshot save /tmp/etcd-backup-$(date +%Y%m%d).db  # Create etcd snapshot
kubectl cp kube-system/<etcd-pod>:/tmp/etcd-backup-$(date +%Y%m%d).db ./etcd-backup-$(date +%Y%m%d).db  # Copy backup locally

# Selective resource exports
kubectl get deployments --all-namespaces -o yaml > deployments-backup.yaml  # Only deployments
kubectl get services --all-namespaces -o yaml > services-backup.yaml        # Only services
kubectl get ingress --all-namespaces -o yaml > ingress-backup.yaml          # Only ingress resources
```

## Cluster Upgrades and Maintenance
```bash
# Pre-upgrade cluster assessment
kubectl version                                          # Current cluster version
kubectl get nodes -o custom-columns=NAME:.metadata.name,VERSION:.status.nodeInfo.kubeletVersion  # Node versions
kubectl get pods --all-namespaces --field-selector=status.phase!=Running  # Unhealthy pods before upgrade
kubectl get events --field-selector type=Warning --since=24h | wc -l  # Recent issues

# Upgrade preparation
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data  # Prepare nodes for upgrade
kubectl cordon <node-name>                               # Prevent new pods during upgrade
kubectl get pods --all-namespaces -o wide --field-selector spec.nodeName=<node-name>  # Verify pod movement

# Post-upgrade verification
kubectl get nodes                                        # Verify all nodes ready
kubectl get pods --all-namespaces --field-selector=status.phase!=Running  # Check for failed pods
kubectl rollout status deployment/<critical-deployment> -n <namespace>  # Verify critical deployments
kubectl get events --since=1h --field-selector type=Warning  # Recent warnings post-upgrade

# Rollback procedures
kubectl rollout undo deployment/<deployment-name>        # Rollback deployments if needed
kubectl uncordon <node-name>                            # Re-enable scheduling on nodes
kubectl describe nodes | grep -E "(Taints|Unschedulable)"  # Verify node scheduling status
```

## Advanced Cluster Administration Tasks
```bash
# Custom Resource Definition (CRD) management
kubectl get crd                                         # List custom resource definitions
kubectl describe crd <crd-name>                         # CRD details and schema
kubectl get <custom-resource-type>                      # List custom resources
kubectl get <custom-resource-type> -o yaml              # Custom resource specifications

# Admission controller and webhook management
kubectl get mutatingwebhookconfigurations               # Mutating admission webhooks
kubectl get validatingwebhookconfigurations            # Validating admission webhooks
kubectl describe mutatingwebhookconfiguration <name>   # Webhook configuration details

# Cluster-level security and policies
kubectl get clusterroles | grep -E "(admin|cluster-admin|view|edit)"  # Default cluster roles
kubectl get clusterrolebindings | grep cluster-admin   # Cluster admin bindings
kubectl get podsecuritypolicy                          # Pod security policies (if enabled)

# Resource cleanup and maintenance
kubectl delete pods --all --all-namespaces --field-selector=status.phase=Succeeded  # Clean up completed pods
kubectl delete pods --all --all-namespaces --field-selector=status.phase=Failed     # Clean up failed pods
kubectl get events --all-namespaces --sort-by=.lastTimestamp | tail -100           # Recent cluster events

# Cluster monitoring and alerting setup
kubectl create namespace monitoring                      # Create monitoring namespace
kubectl get pods -n monitoring                         # Check monitoring components
kubectl port-forward -n monitoring service/prometheus 9090:9090  # Access Prometheus (if installed)
kubectl port-forward -n monitoring service/grafana 3000:80     # Access Grafana (if installed)
```