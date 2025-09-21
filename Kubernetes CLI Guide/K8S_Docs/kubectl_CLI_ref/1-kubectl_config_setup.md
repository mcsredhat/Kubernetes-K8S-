# Essential Configuration and Setup

Master these foundational commands to establish an efficient kubectl workflow. Proper setup saves hours of repetitive typing and reduces errors in production environments.

## Context and Namespace Management
```bash
# Context operations - essential for multi-cluster management
kubectl config current-context                    # Display current context
kubectl config get-contexts                       # List all available contexts
kubectl config use-context <context-name>         # Switch between contexts
kubectl config rename-context <old-name> <new-name>  # Rename context
kubectl config delete-context <context-name>      # Remove context

# Namespace operations - critical for environment isolation
kubectl config set-context --current --namespace=<namespace>  # Set default namespace
kubectl config view --minify                      # View current context configuration
kubectl get namespaces                           # List all namespaces
kubectl create namespace <namespace>              # Create new namespace
kubectl delete namespace <namespace>              # Delete namespace (careful!)

# Advanced context creation for different environments
kubectl config set-context prod --cluster=prod-cluster --user=prod-user --namespace=production
kubectl config set-context staging --cluster=staging-cluster --user=staging-user --namespace=staging
kubectl config set-context dev --cluster=dev-cluster --user=dev-user --namespace=development
```

## Productivity Enhancements
```bash
# Essential aliases for productivity (add to ~/.bashrc or ~/.zshrc)
alias k=kubectl
alias kgp='kubectl get pods'
alias kgpa='kubectl get pods --all-namespaces'
alias kgs='kubectl get services'
alias kgd='kubectl get deployments'
alias kgn='kubectl get nodes'
alias kgh='kubectl get hpa'
alias kgi='kubectl get ingress'
alias kdp='kubectl describe pod'
alias kdd='kubectl describe deployment'
alias kds='kubectl describe service'
alias kdn='kubectl describe node'
alias kaf='kubectl apply -f'
alias kdel='kubectl delete'
alias klo='kubectl logs'
alias kex='kubectl exec -it'
alias kpf='kubectl port-forward'

# Advanced aliases for common operations
alias kgpw='kubectl get pods -o wide'
alias kgdw='kubectl get deployments -o wide'
alias kgsw='kubectl get services -o wide'
alias kgpsl='kubectl get pods --show-labels'
alias kgpby='kubectl get pods --sort-by=.metadata.creationTimestamp'
alias kgpbycpu='kubectl top pods --sort-by=cpu'
alias kgpbymem='kubectl top pods --sort-by=memory'

# Enable kubectl autocompletion
source <(kubectl completion bash)        # For bash users
source <(kubectl completion zsh)         # For zsh users
complete -F __start_kubectl k            # Enable completion for 'k' alias

# One-time setup for persistent configuration
echo 'source <(kubectl completion bash)' >> ~/.bashrc
echo 'alias k=kubectl' >> ~/.bashrc
echo 'complete -F __start_kubectl k' >> ~/.bashrc
```

## Configuration Validation and Troubleshooting
```bash
# Verify cluster connectivity and permissions
kubectl cluster-info                      # Basic cluster information
kubectl auth can-i create deployments    # Test permissions
kubectl auth can-i '*' '*' --all-namespaces  # Test cluster admin access
kubectl version --short                  # Client and server versions
kubectl api-resources --verbs=list,get   # Available resources you can list

# Configuration debugging
kubectl config view --raw                # Raw configuration (includes secrets)
kubectl config get-contexts -o name      # Context names only
kubectl get nodes --output wide          # Verify cluster nodes
```

## API Discovery and Resource Understanding
```bash
# Discover available resources and their capabilities
kubectl api-resources                     # List all resource types
kubectl api-resources --namespaced=true  # Only namespaced resources
kubectl api-resources --namespaced=false # Only cluster-scoped resources
kubectl api-resources --api-group=apps   # Resources in specific API group
kubectl api-resources --verbs=create     # Resources that support creation

# Resource documentation and schema
kubectl explain pods                      # Get pod resource documentation
kubectl explain pod.spec                 # Explain specific fields
kubectl explain pod.spec.containers      # Deep dive into nested fields
kubectl explain deployment.spec.strategy # Understand deployment strategies
kubectl explain --recursive pod.spec     # Full recursive field explanation

# API version exploration
kubectl api-versions                      # List all API versions
kubectl get pods -v=8                    # Verbose API calls (debugging)
kubectl proxy --port=8080 &             # Start API proxy for direct access
# Then access: http://localhost:8080/api/v1
```

## Plugin Management and Extensions
```bash
# Plugin discovery and management
kubectl plugin list                      # List installed plugins
kubectl krew install <plugin-name>       # Install plugin via Krew (if available)
kubectl krew list                        # List Krew-managed plugins
kubectl krew search                      # Search available plugins

# Popular community plugins worth installing:
kubectl krew install ctx               # Context switching (kubectx)
kubectl krew install ns                # Namespace switching (kubens)
kubectl krew install tree              # Resource hierarchy visualization
kubectl krew install neat              # Clean resource output
kubectl krew install resource-capacity # Cluster resource capacity analysis
kubectl krew install whoami            # Current user information
```