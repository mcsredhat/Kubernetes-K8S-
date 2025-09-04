# 20. Configuration and Contexts - Enhanced Guide

Managing Kubernetes contexts and configurations is critical for multi-cluster and multi-environment workflows. This comprehensive guide covers `kubectl config` commands, advanced context management techniques, and a complete system for managing multiple clusters safely and efficiently.

## Table of Contents
- [20.1 Understanding Kubernetes Configuration](#201-understanding-kubernetes-configuration)
- [20.2 Basic Context Management](#202-basic-context-management)
- [20.3 Advanced Configuration Techniques](#203-advanced-configuration-techniques)
- [20.4 Security Best Practices](#204-security-best-practices)
- [20.5 Enhanced Multi-Cluster Management System](#205-enhanced-multi-cluster-management-system)
- [20.6 Troubleshooting Common Issues](#206-troubleshooting-common-issues)
- [20.7 Real-World Usage Patterns](#207-real-world-usage-patterns)

## 20.1 Understanding Kubernetes Configuration

### What is a Kubernetes Context?
A Kubernetes context is a combination of three elements:
- **Cluster**: The Kubernetes cluster endpoint and certificate information
- **User**: Authentication credentials (certificates, tokens, etc.)
- **Namespace**: The default namespace for operations

### Configuration File Structure
The kubeconfig file (`~/.kube/config`) contains:
```yaml
apiVersion: v1
kind: Config
clusters:          # List of cluster definitions
- cluster:
    server: https://kubernetes-api.example.com
    certificate-authority-data: LS0tLS1...
  name: production-cluster
contexts:           # List of context definitions
- context:
    cluster: production-cluster
    user: admin-user
    namespace: default
  name: prod-context
current-context: prod-context  # Active context
users:              # List of user credentials
- name: admin-user
  user:
    client-certificate-data: LS0tLS1...
    client-key-data: LS0tLS1...
```

## 20.2 Basic Context Management

### Essential kubectl config Commands

```bash
# View complete configuration (sanitized)
kubectl config view

# View raw configuration with sensitive data
kubectl config view --raw

# List all available contexts with details
kubectl config get-contexts

# Display current active context
kubectl config current-context

# Switch to a different context
kubectl config use-context my-dev-cluster

# Set default namespace for current context
kubectl config set-context --current --namespace=development

# Create a new context
kubectl config set-context dev-frontend \
  --cluster=development-cluster \
  --user=dev-user \
  --namespace=frontend

# Rename an existing context
kubectl config rename-context old-name new-name

# Delete a context (does not delete cluster or user)
kubectl config delete-context unwanted-context

# Set a different kubeconfig file
export KUBECONFIG=/path/to/different/config

# Temporarily use a different config for one command
kubectl --kubeconfig=/path/to/config get pods
```

### Context Information Commands
```bash
# Get cluster information for current context
kubectl cluster-info

# Get cluster information for specific context
kubectl cluster-info --context=my-context

# Check what permissions you have in current context
kubectl auth can-i --list

# Test specific permissions
kubectl auth can-i create pods --namespace=production
kubectl auth can-i get secrets --as=system:serviceaccount:default:my-sa
```

## 20.3 Advanced Configuration Techniques

### Merging Multiple Kubeconfig Files
```bash
# Temporarily merge configs
export KUBECONFIG=~/.kube/config:~/.kube/dev-config:~/.kube/prod-config

# View merged configuration
kubectl config view

# Make the merge permanent
kubectl config view --flatten > ~/.kube/merged-config
mv ~/.kube/merged-config ~/.kube/config
```

### Managing User Credentials
```bash
# Set user with certificate files
kubectl config set-credentials my-user \
  --client-certificate=/path/to/cert.pem \
  --client-key=/path/to/key.pem

# Set user with token
kubectl config set-credentials token-user --token=bearer-token-here

# Set user with username/password (not recommended)
kubectl config set-credentials basic-user \
  --username=myuser \
  --password=mypassword

# Remove user credentials
kubectl config unset users.my-user
```

### Cluster Configuration
```bash
# Add a new cluster
kubectl config set-cluster my-cluster \
  --server=https://k8s-api.example.com \
  --certificate-authority=/path/to/ca.crt

# Set cluster with embedded certificate
kubectl config set-cluster secure-cluster \
  --server=https://secure-k8s.example.com \
  --certificate-authority-data=$(cat /path/to/ca.crt | base64 -w 0)

# Skip TLS verification (not recommended for production)
kubectl config set-cluster test-cluster \
  --server=https://test-k8s.example.com \
  --insecure-skip-tls-verify=true
```

## 20.4 Security Best Practices

### Context Switching Safety
```bash
# Always verify context before destructive operations
echo "Current context: $(kubectl config current-context)"
kubectl config get-contexts $(kubectl config current-context)

# Use different terminal colors for different environments
# Add to ~/.bashrc:
set_k8s_prompt() {
  local context=$(kubectl config current-context 2>/dev/null || echo "none")
  if [[ "$context" == *"prod"* ]]; then
    export PS1="\[\033[41m\][PROD:$context]\[\033[0m\] \u@\h:\w\$ "
  elif [[ "$context" == *"staging"* ]]; then
    export PS1="\[\033[43m\][STAGING:$context]\[\033[0m\] \u@\h:\w\$ "
  else
    export PS1="\[\033[42m\][DEV:$context]\[\033[0m\] \u@\h:\w\$ "
  fi
}
PROMPT_COMMAND=set_k8s_prompt
```

### Credential Security
```bash
# Check for world-readable kubeconfig
ls -la ~/.kube/config
chmod 600 ~/.kube/config  # Ensure only owner can read

# Separate configs for different security levels
mkdir -p ~/.kube/environments
mv ~/.kube/prod-config ~/.kube/environments/
chmod 400 ~/.kube/environments/prod-config  # Read-only
```

## 20.5 Enhanced Multi-Cluster Management System

```bash
#!/bin/bash
# save as enhanced-multi-cluster-setup.sh
echo "🌐 Enhanced Multi-Cluster Kubernetes Management Setup"

# Configuration
KUBECONFIG_DIR="$HOME/.kube/clusters"
BACKUP_DIR="$HOME/.kube/backups"
LOG_FILE="$HOME/.kube/context-manager.log"

# Create necessary directories
mkdir -p "$KUBECONFIG_DIR" "$BACKUP_DIR"

# Logging function
log_action() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Function to create comprehensive cluster configurations
create_cluster_config() {
  local cluster_name=$1
  local environment=$2
  local endpoint=$3
  local ca_data=${4:-"LS0tLS1CRUdJTi1DRVJUSUZJQ0FURS0tLS0t"}  # Mock CA data
  local token=${5:-"mock-token-$(openssl rand -hex 16)"}
  
  cat << EOF > "$KUBECONFIG_DIR/$cluster_name-config"
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: $ca_data
    server: $endpoint
  name: $cluster_name
contexts:
- context:
    cluster: $cluster_name
    namespace: default
    user: $cluster_name-user
  name: $cluster_name-context
current-context: $cluster_name-context
preferences: {}
users:
- name: $cluster_name-user
  user:
    token: $token
EOF
  
  # Set appropriate permissions
  chmod 600 "$KUBECONFIG_DIR/$cluster_name-config"
  echo "✅ Created secure config for $cluster_name ($environment)"
  log_action "Created cluster config: $cluster_name"
}

# Create configurations for different environments with realistic endpoints
echo "📝 Creating cluster configurations..."
create_cluster_config "dev-cluster" "development" "https://dev-k8s.internal.company.com:6443"
create_cluster_config "staging-cluster" "staging" "https://staging-k8s.internal.company.com:6443"
create_cluster_config "prod-cluster" "production" "https://prod-k8s.company.com:6443"
create_cluster_config "local-minikube" "local" "https://127.0.0.1:8443"
create_cluster_config "test-cluster" "testing" "https://test-k8s.internal.company.com:6443"

# Create enhanced context management script
cat << 'EOF' > ~/.kube/enhanced-context-manager.sh
#!/bin/bash
# Enhanced Kubernetes Context Manager
# Version: 2.0

# Configuration
KUBECONFIG_DIR="$HOME/.kube/clusters"
BACKUP_DIR="$HOME/.kube/backups"
LOG_FILE="$HOME/.kube/context-manager.log"
CONFIG_FILE="$HOME/.kube/manager-config"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging function
log_action() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Function to display colored output
print_status() {
  local color=$1
  local message=$2
  echo -e "${color}${message}${NC}"
}

# Function to validate context exists
validate_context() {
  local context=$1
  if ! kubectl config get-contexts -o name | grep -q "^$context$"; then
    print_status $RED "❌ Context '$context' not found"
    return 1
  fi
  return 0
}

# Function to check if context is production
is_production_context() {
  local context=$1
  [[ "$context" == *"prod"* ]] || [[ "$context" == *"production"* ]]
}

# Function to display available contexts with enhanced formatting
show_contexts() {
  print_status $CYAN "📋 Available Kubernetes Contexts:"
  
  local current_context=$(kubectl config current-context 2>/dev/null || echo "none")
  
  kubectl config get-contexts --no-headers | while read -r marker context cluster user namespace; do
    local color=$GREEN
    local prefix="  "
    
    if [[ "$context" == "$current_context" ]]; then
      prefix="▶ "
      color=$YELLOW
    fi
    
    if is_production_context "$context"; then
      color=$RED
      context="🔥 $context"
    elif [[ "$context" == *"staging"* ]]; then
      color=$PURPLE
      context="🚧 $context"
    elif [[ "$context" == *"dev"* ]] || [[ "$context" == *"local"* ]]; then
      color=$GREEN
      context="🔧 $context"
    fi
    
    printf "${color}${prefix}%-30s %-20s %-15s %s${NC}\n" "$context" "$cluster" "$user" "$namespace"
  done
  
  echo
  print_status $BLUE "Current context: $current_context"
}

# Function to switch context with enhanced safety checks
switch_context() {
  local target_context=$1
  
  if [ -z "$target_context" ]; then
    print_status $RED "❌ Please specify a context name"
    show_contexts
    return 1
  fi
  
  if ! validate_context "$target_context"; then
    show_contexts
    return 1
  fi
  
  # Production safety check
  if is_production_context "$target_context"; then
    print_status $RED "⚠️  DANGER: You're about to switch to PRODUCTION context!"
    print_status $YELLOW "Current context: $(kubectl config current-context 2>/dev/null || echo 'none')"
    print_status $YELLOW "Target context: $target_context"
    echo
    read -p "Type 'I understand the risks' to proceed: " confirmation
    if [ "$confirmation" != "I understand the risks" ]; then
      print_status $RED "❌ Context switch cancelled for safety"
      log_action "SAFETY: Cancelled switch to production context: $target_context"
      return 1
    fi
  fi
  
  # Test connectivity before switching
  print_status $BLUE "🔍 Testing connectivity to target cluster..."
  if ! kubectl cluster-info --context="$target_context" >/dev/null 2>&1; then
    print_status $YELLOW "⚠️  Warning: Cannot connect to cluster (this might be expected for mock configs)"
  fi
  
  kubectl config use-context "$target_context"
  print_status $GREEN "✅ Switched to context: $target_context"
  
  # Set environment-specific prompt
  local prompt_color="42"  # Green for dev
  if is_production_context "$target_context"; then
    prompt_color="41"  # Red for production
  elif [[ "$target_context" == *"staging"* ]]; then
    prompt_color="43"  # Yellow for staging
  fi
  
  export PS1="\[\033[${prompt_color}m\][k8s:$target_context]\[\033[0m\] \u@\h:\w\$ "
  
  log_action "Switched to context: $target_context"
  
  # Show current namespace and basic info
  local namespace=$(kubectl config view --minify --output 'jsonpath={..namespace}' 2>/dev/null || echo "default")
  print_status $CYAN "🔍 Current namespace: ${namespace:-default}"
  
  # Show resource counts if cluster is accessible
  if kubectl get nodes >/dev/null 2>&1; then
    local node_count=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    local pod_count=$(kubectl get pods --all-namespaces --no-headers 2>/dev/null | wc -l)
    print_status $BLUE "📊 Cluster info: $node_count nodes, $pod_count pods"
  fi
}

# Function to create context aliases with validation
create_alias() {
  local alias_name=$1
  local context_name=$2
  
  if [ -z "$alias_name" ] || [ -z "$context_name" ]; then
    print_status $RED "Usage: create_alias <alias> <context>"
    return 1
  fi
  
  if ! validate_context "$context_name"; then
    return 1
  fi
  
  local alias_cmd="alias k-$alias_name='~/.kube/enhanced-context-manager.sh switch $context_name'"
  
  # Check if alias already exists
  if grep -q "alias k-$alias_name=" ~/.bashrc; then
    print_status $YELLOW "⚠️  Alias 'k-$alias_name' already exists. Updating..."
    sed -i "/alias k-$alias_name=/d" ~/.bashrc
  fi
  
  echo "$alias_cmd" >> ~/.bashrc
  print_status $GREEN "✅ Created alias 'k-$alias_name' for context '$context_name'"
  print_status $BLUE "💡 Run 'source ~/.bashrc' to activate, or use: $alias_cmd"
  
  log_action "Created alias: k-$alias_name -> $context_name"
}

# Function to backup current kubeconfig with metadata
backup_config() {
  local backup_name="kubeconfig-backup-$(date +%Y%m%d-%H%M%S)"
  local backup_path="$BACKUP_DIR/$backup_name"
  
  cp ~/.kube/config "$backup_path"
  
  # Create metadata file
  cat << METADATA > "$backup_path.meta"
Created: $(date)
Current context: $(kubectl config current-context 2>/dev/null || echo "none")
Contexts count: $(kubectl config get-contexts --no-headers | wc -l)
Size: $(ls -lh ~/.kube/config | awk '{print $5}')
METADATA
  
  print_status $GREEN "✅ Kubeconfig backed up to $backup_path"
  log_action "Backup created: $backup_name"
  
  # Clean old backups (keep last 10)
  ls -t "$BACKUP_DIR"/kubeconfig-backup-* 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
}

# Function to merge kubeconfig files with validation
merge_configs() {
  print_status $BLUE "🔀 Merging kubeconfig files from $KUBECONFIG_DIR/"
  
  if [ ! -d "$KUBECONFIG_DIR" ] || [ -z "$(ls -A $KUBECONFIG_DIR 2>/dev/null)" ]; then
    print_status $RED "❌ No config files found in $KUBECONFIG_DIR"
    return 1
  fi
  
  backup_config
  
  # Build KUBECONFIG environment variable
  local kubeconfig_list="$HOME/.kube/config"
  for config_file in "$KUBECONFIG_DIR"/*-config; do
    if [ -f "$config_file" ]; then
      kubeconfig_list="$kubeconfig_list:$config_file"
    fi
  done
  
  export KUBECONFIG="$kubeconfig_list"
  kubectl config view --flatten > ~/.kube/config-merged
  
  # Validate merged config
  if kubectl config view --validate ~/.kube/config-merged >/dev/null 2>&1; then
    mv ~/.kube/config-merged ~/.kube/config
    print_status $GREEN "✅ Configurations merged successfully"
    log_action "Configurations merged successfully"
  else
    print_status $RED "❌ Merged configuration is invalid. Restoring backup..."
    rm -f ~/.kube/config-merged
    return 1
  fi
  
  show_contexts
}

# Function to show detailed context information
show_context_details() {
  local context=${1:-$(kubectl config current-context 2>/dev/null)}
  
  if [ -z "$context" ]; then
    print_status $RED "❌ No context specified and no current context set"
    return 1
  fi
  
  print_status $CYAN "📋 Detailed information for context: $context"
  
  kubectl config get-contexts "$context" 2>/dev/null || {
    print_status $RED "❌ Context '$context' not found"
    return 1
  }
  
  echo
  local cluster=$(kubectl config view -o jsonpath="{.contexts[?(@.name=='$context')].context.cluster}")
  local user=$(kubectl config view -o jsonpath="{.contexts[?(@.name=='$context')].context.user}")
  local namespace=$(kubectl config view -o jsonpath="{.contexts[?(@.name=='$context')].context.namespace}")
  
  print_status $BLUE "🔗 Cluster: $cluster"
  print_status $BLUE "👤 User: $user"
  print_status $BLUE "📁 Namespace: ${namespace:-default}"
  
  # Show cluster endpoint if available
  local server=$(kubectl config view -o jsonpath="{.clusters[?(@.name=='$cluster')].cluster.server}")
  if [ -n "$server" ]; then
    print_status $BLUE "🌐 Server: $server"
  fi
  
  # Test connectivity
  echo
  print_status $BLUE "🔍 Testing connectivity..."
  if kubectl cluster-info --context="$context" >/dev/null 2>&1; then
    print_status $GREEN "✅ Cluster is accessible"
    kubectl version --context="$context" --short 2>/dev/null || true
  else
    print_status $YELLOW "⚠️  Cannot connect to cluster (may be normal for mock configs)"
  fi
}

# Function to list recent activities
show_history() {
  local lines=${1:-10}
  
  if [ ! -f "$LOG_FILE" ]; then
    print_status $YELLOW "📝 No history available yet"
    return 0
  fi
  
  print_status $CYAN "📜 Recent context manager activities (last $lines):"
  tail -n "$lines" "$LOG_FILE" | while read -r line; do
    echo "  $line"
  done
}

# Function to validate all contexts
validate_all_contexts() {
  print_status $BLUE "🔍 Validating all contexts..."
  
  local total=0
  local accessible=0
  local errors=0
  
  kubectl config get-contexts -o name | while read -r context; do
    total=$((total + 1))
    printf "Testing %-30s ... " "$context"
    
    if kubectl cluster-info --context="$context" >/dev/null 2>&1; then
      print_status $GREEN "✅ OK"
      accessible=$((accessible + 1))
    else
      print_status $YELLOW "⚠️  Unreachable"
      errors=$((errors + 1))
    fi
  done
  
  echo
  print_status $BLUE "📊 Summary: $total total, $accessible accessible, $errors unreachable"
}

# Main command handler with enhanced help
case "$1" in
  "list"|"ls")
    show_contexts
    ;;
  "switch"|"use")
    switch_context "$2"
    ;;
  "details"|"info")
    show_context_details "$2"
    ;;
  "alias")
    create_alias "$2" "$3"
    ;;
  "backup")
    backup_config
    ;;
  "merge")
    merge_configs
    ;;
  "current")
    show_context_details
    ;;
  "history"|"log")
    show_history "$2"
    ;;
  "validate")
    validate_all_contexts
    ;;
  "help"|"-h"|"--help")
    print_status $CYAN "🚀 Enhanced Kubernetes Context Manager v2.0"
    echo
    echo "USAGE:"
    echo "  $0 <command> [arguments]"
    echo
    echo "COMMANDS:"
    echo "  list, ls                    Show available contexts with status"
    echo "  switch, use <context>       Switch to specified context"
    echo "  details, info [context]     Show detailed context information"  
    echo "  alias <name> <context>      Create shell alias for context"
    echo "  backup                      Backup current kubeconfig"
    echo "  merge                       Merge configs from clusters directory"
    echo "  current                     Show current context details"
    echo "  history, log [lines]        Show recent activity log"
    echo "  validate                    Test connectivity to all contexts"
    echo "  help                        Show this help message"
    echo
    echo "EXAMPLES:"
    echo "  $0 list                     # Show all contexts"
    echo "  $0 switch dev-cluster       # Switch to development"
    echo "  $0 alias dev dev-cluster    # Create 'k-dev' alias"
    echo "  $0 details prod-cluster     # Show production details"
    echo
    print_status $YELLOW "💡 TIP: Use tab completion and create aliases for frequent contexts"
    ;;
  *)
    print_status $RED "❌ Unknown command: $1"
    echo "Use '$0 help' for usage information"
    exit 1
    ;;
esac
EOF

chmod +x ~/.kube/enhanced-context-manager.sh

# Create enhanced aliases and shell functions
cat << 'EOF' >> ~/.bashrc

# Enhanced Kubernetes context management
export KUBECONFIG_DIR="$HOME/.kube/clusters"

# Main alias for the context manager
alias kctx='~/.kube/enhanced-context-manager.sh'

# Quick context switching aliases
alias k-dev='kctx switch dev-cluster'
alias k-staging='kctx switch staging-cluster'
alias k-prod='kctx switch prod-cluster'
alias k-local='kctx switch local-minikube'
alias k-test='kctx switch test-cluster'

# Utility aliases
alias k-list='kctx list'
alias k-current='kctx current'
alias k-backup='kctx backup'

# Enhanced kubectl aliases with context awareness
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get services'
alias kgd='kubectl get deployments'
alias kgn='kubectl get nodes'

# Function to show current context in prompt
kube_ps1() {
  local context=$(kubectl config current-context 2>/dev/null)
  if [ -n "$context" ]; then
    if [[ "$context" == *"prod"* ]]; then
      echo -e "\033[41m[⚠️  $context]\033[0m"
    elif [[ "$context" == *"staging"* ]]; then
      echo -e "\033[43m[🚧 $context]\033[0m"
    else
      echo -e "\033[42m[🔧 $context]\033[0m"
    fi
  fi
}

# Function to safely execute kubectl commands with confirmation for prod
safe_kubectl() {
  local context=$(kubectl config current-context 2>/dev/null)
  if [[ "$context" == *"prod"* ]] && [[ "$*" == *"delete"* || "$*" == *"apply"* || "$*" == *"create"* ]]; then
    echo "⚠️  WARNING: You're about to run a potentially destructive command in PRODUCTION!"
    echo "Context: $context"
    echo "Command: kubectl $*"
    read -p "Are you sure? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
      echo "❌ Command cancelled"
      return 1
    fi
  fi
  kubectl "$@"
}

alias kubectl=safe_kubectl

EOF

# Create tab completion for the context manager (if bash-completion is available)
if [ -d /etc/bash_completion.d ] || [ -d /usr/share/bash-completion/completions ]; then
  cat << 'EOF' > ~/.kube/kctx-completion.bash
# Bash completion for enhanced context manager
_kctx_completion() {
  local cur prev commands contexts
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  commands="list ls switch use details info alias backup merge current history log validate help"
  
  case $prev in
    switch|use|details|info)
      contexts=$(kubectl config get-contexts -o name 2>/dev/null)
      COMPREPLY=($(compgen -W "$contexts" -- "$cur"))
      return 0
      ;;
    alias)
      # No completion for alias name
      return 0
      ;;
  esac
  
  if [[ $COMP_CWORD -eq 1 ]]; then
    COMPREPLY=($(compgen -W "$commands" -- "$cur"))
  fi
}

complete -F _kctx_completion kctx
complete -F _kctx_completion ~/.kube/enhanced-context-manager.sh
EOF

  echo "source ~/.kube/kctx-completion.bash" >> ~/.bashrc
  print_status $GREEN "✅ Tab completion configured"
fi

echo
print_status $GREEN "🎉 Enhanced multi-cluster setup complete!"
echo
print_status $CYAN "🔧 USAGE EXAMPLES:"
echo "  kctx list                    # Show all contexts with status"
echo "  kctx switch dev-cluster      # Switch to development cluster"
echo "  kctx details prod-cluster    # Show production cluster details"
echo "  kctx validate               # Test all cluster connections"
echo "  k-dev                       # Quick switch to development"
echo "  k-prod                      # Quick switch to production (with safety check)"
echo
print_status $CYAN "🛡️  SAFETY FEATURES:"
echo "  • Production context warnings and confirmations"
echo "  • Automatic config backups before major changes"
echo "  • Context validation before switching"
echo "  • Activity logging for audit trail"
echo "  • Color-coded prompts for different environments"
echo
print_status $YELLOW "📝 Next steps:"
echo "  1. Run 'source ~/.bashrc' to activate all aliases and functions"
echo "  2. Run 'kctx merge' to combine all cluster configurations"  
echo "  3. Run 'kctx list' to see all available contexts"
echo "  4. Use 'kctx help' for complete command reference"
```

## 20.6 Troubleshooting Common Issues

### Common Problems and Solutions

#### Issue: "error: You must be logged in to the server (Unauthorized)"
```bash
# Check current user and context
kubectl config view --minify

# Verify user credentials
kubectl config view --raw -o jsonpath='{.users[0].user}'

# Re-authenticate if using token-based auth
kubectl config set-credentials myuser --token=new-token-here
```

#### Issue: "The connection to the server localhost:8080 was refused"
```bash
# Check if KUBECONFIG environment variable is set
echo $KUBECONFIG

# Ensure kubectl is using the right config file
kubectl config view --kubeconfig ~/.kube/config

# Reset to default config location
unset KUBECONFIG
```

#### Issue: Context exists but cluster is unreachable
```bash
# Test specific context connectivity
kubectl cluster-info --context=problematic-context

# Check cluster server URL
kubectl config view -o jsonpath='{.clusters[?(@.name=="cluster-name")].cluster.server}'

# Verify network connectivity
curl -k https://your-cluster-endpoint/healthz
```

#### Issue: Permission denied errors
```bash
# Check file permissions
ls -la ~/.kube/config
chmod 600 ~/.kube/config

# Verify user permissions in cluster
kubectl auth can-i --list
kubectl auth whoami  # If supported by your cluster
```

### Configuration Validation
```bash
# Validate kubeconfig syntax
kubectl config view --validate

# Check for common issues
kubectl config get-contexts | grep -E "(CLUSTER|AUTHINFO|NAMESPACE)"

# Test all contexts
for context in $(kubectl config get-contexts -o name); do
  echo "Testing $context..."
  kubectl cluster-info --context=$context
done
```

## 20.7 Real-World Usage Patterns

### Development Workflow
```bash
# Morning routine: Check all environments
kctx validate
kctx switch dev-cluster
kubectl get pods -A --field-selector=status.phase!=Running

# Feature development
kctx switch dev-cluster
kubectl apply -f manifests/
kubectl logs -f deployment/my-app

# Testing phase
kctx switch staging-cluster  
kubectl get deployment my-app -o wide
```

### Production Deployment Workflow
```bash
# Pre-deployment checks
kctx switch staging-cluster
kubectl get deployment my-app -o yaml > staging-state.yaml

# Production deployment (with safety checks)
kctx switch prod-cluster  # Will prompt for confirmation
kubectl diff -f production-manifests/
kubectl apply -f production-manifests/ --dry-run=client
kubectl apply -f production-manifests/

# Post-deployment verification
kubectl rollout status deployment/my-app
kubectl get pods -l app=my-app -w
```

### Multi-Team Environment Setup
```bash
# Team-specific namespaces and contexts
kubectl config set-context frontend-dev \
  --cluster=dev-cluster \
  --user=frontend-team \
  --namespace=frontend-dev

kubectl config set-context backend-dev \
  --cluster=dev-cluster \
  --user=backend-team \
  --namespace=backend-dev

# Role-based context switching
alias k-frontend='kctx switch frontend-dev'
alias k-backend='kctx switch backend-dev'
alias k-ops='kctx switch ops-cluster'
```

### Emergency Response Procedures
```bash
# Quick incident response script
incident_response() {
  echo "🚨 Incident Response Mode"
  kctx switch prod-cluster
  
  # Quick cluster health check
  kubectl get nodes
  kubectl get pods --all-namespaces --field-selector=status.phase!=Running
  kubectl top nodes 2>/dev/null || echo "Metrics server unavailable"
  
  # Check recent events
  kubectl get events --sort-by='.lastTimestamp' | tail -20
  
  echo "Current context: $(kubectl config current-context)"
  echo "Ready for incident commands..."
}

# Add to ~/.bashrc
alias incident='incident_response'
```

## Key Concepts Explained

### Why Context Management Matters

**Separation of Environments**: Contexts prevent accidental operations on the wrong cluster. Without proper context management, it's easy to run `kubectl delete` on production when you meant to target development.

**Team Collaboration**: Multiple team members can share context configurations, ensuring everyone connects to the same clusters with consistent settings.

**Security Boundaries**: Different contexts can use different credentials, implementing least-privilege access across environments.

**Operational Safety**: The enhanced system includes safety checks, particularly for production environments, reducing the risk of costly mistakes.

### Understanding the Configuration Hierarchy

Kubernetes configuration follows this priority order:
1. Command-line flags (`--kubeconfig`, `--context`)
2. Environment variables (`KUBECONFIG`)
3. Default kubeconfig file (`~/.kube/config`)
4. In-cluster configuration (for pods)

### Best Practices Summary

**Security**:
- Keep production configs separate and more restricted
- Use different credentials for different environments
- Regularly rotate authentication tokens
- Monitor and log context switches

**Organization**:
- Use consistent naming conventions (environment-purpose-cluster)
- Group related contexts together
- Document context purposes and access levels
- Maintain backup copies of working configurations

**Safety**:
- Always verify context before destructive operations
- Use visual indicators (colored prompts) for different environments
- Implement confirmation steps for production changes
- Test configurations in development first

**Automation**:
- Script common context operations
- Create aliases for frequently used contexts
- Automate configuration validation
- Integrate with CI/CD pipelines for environment-specific deployments

This enhanced configuration management system provides a robust foundation for working with multiple Kubernetes clusters safely and efficiently. The safety features, comprehensive logging, and user-friendly interface make it suitable for both individual developers and large teams managing complex multi-environment infrastructures.