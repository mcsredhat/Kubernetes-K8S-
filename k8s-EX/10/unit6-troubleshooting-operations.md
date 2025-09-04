# Unit 6: Troubleshooting and Operational Excellence

## Learning Objectives
- Master systematic approaches to troubleshooting secret-related issues
- Develop operational runbooks for common secret problems
- Implement monitoring and alerting for secret management
- Build resilient secret management workflows
- Create disaster recovery procedures for secret-related failures

## Pre-Unit Diagnostic Challenge

Before we dive into troubleshooting techniques, let's test your problem-solving instincts with some real-world scenarios. For each scenario, think through:
1. What questions would you ask first?
2. What commands would you run to investigate?
3. What are the most likely root causes?
4. How would you verify your fix?

**Scenario 1**: A production pod keeps restarting with exit code 1. The logs show "database connection failed - access denied for user 'app_user'". The database admin confirms the credentials are correct and the user exists.

**Scenario 2**: After a recent deployment, your application can't access its API secrets. Running `kubectl get secrets` shows the secret exists, but pods are logging "secret not found" errors.

**Scenario 3**: Your automated secret rotation script ran successfully, but half of your application pods are now failing with authentication errors while the other half work fine.

Take a moment to think through these scenarios. What patterns do you notice? What systematic approach would you use?

## The Troubleshooting Methodology

Effective troubleshooting follows a systematic approach. Let's build a methodology specifically tailored for Kubernetes secrets:

### The SECRETS Framework

**S** - Scope the problem (What's affected? When did it start?)
**E** - Examine the evidence (Logs, events, configurations)
**C** - Check dependencies (RBAC, network, storage)
**R** - Review recent changes (Deployments, updates, rotations)
**E** - Eliminate possibilities (Isolate variables systematically)
**T** - Test hypotheses (Make targeted changes)
**S** - Stabilize and document (Fix, monitor, learn)

Let's apply this framework to real scenarios.

## Scenario Deep Dive 1: Secret Access Failures

Let's work through the database connection scenario step by step:

### Step S: Scope the Problem

```bash
#!/bin/bash
# scope-secret-problem.sh

echo "🔍 SCOPING: Secret Access Problem Investigation"

NAMESPACE=${1:-production}
APP_LABEL=${2:-app=web-app}

echo "Investigating namespace: $NAMESPACE"
echo "Application selector: $APP_LABEL"

# Quick health overview
echo "📊 Current pod status:"
kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL" -o wide

echo "📊 Recent pod events:"
kubectl get events -n "$NAMESPACE" --field-selector involvedObject.kind=Pod --sort-by='.lastTimestamp' | tail -10

echo "📊 Secret availability:"
kubectl get secrets -n "$NAMESPACE"
```

**Practice Exercise**: Run this scoping script. What immediate insights does it provide? What questions does it raise?

### Step E: Examine the Evidence

```bash
#!/bin/bash
# examine-secret-evidence.sh

NAMESPACE=${1:-production}
POD_NAME=${2:-$(kubectl get pods -n "$NAMESPACE" -l app=web-app -o jsonpath='{.items[0].metadata.name}')}

echo "🔬 EXAMINING: Evidence Collection for $POD_NAME"

# Pod configuration analysis
echo "📋 Pod secret configuration:"
kubectl describe pod "$POD_NAME" -n "$NAMESPACE" | grep -A 20 -B 5 -i secret

# Environment variable verification
echo "📋 Environment variables in pod:"
kubectl exec "$POD_NAME" -n "$NAMESPACE" -- env | grep -E "(DB_|DATABASE|SECRET)" || echo "No database-related env vars found"

# Volume mount verification
echo "📋 Volume mounts:"
kubectl exec "$POD_NAME" -n "$NAMESPACE" -- df | grep -E "(secret|tmpfs)" || echo "No secret volumes mounted"

# Secret content verification (be careful in production!)
echo "📋 Secret content analysis:"
SECRET_NAME=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].envFrom[0].secretRef.name}' 2>/dev/null || echo "no-secret-ref")
if [[ "$SECRET_NAME" != "no-secret-ref" ]]; then
    echo "Secret name: $SECRET_NAME"
    kubectl describe secret "$SECRET_NAME" -n "$NAMESPACE"
else
    echo "No secretRef found in pod spec"
fi
```

**Critical Thinking**: What evidence would be most valuable for diagnosing the database connection issue? What evidence might be misleading?

### Step C: Check Dependencies

Secret problems often involve dependencies. Let's systematically check them:

```bash
#!/bin/bash
# check-secret-dependencies.sh

NAMESPACE=${1:-production}
SERVICE_ACCOUNT=${2:-default}

echo "🔗 CHECKING: Secret Dependencies"

# RBAC verification
echo "📋 RBAC Analysis:"
echo "Service Account: $SERVICE_ACCOUNT"
kubectl get serviceaccount "$SERVICE_ACCOUNT" -n "$NAMESPACE" -o yaml

echo "📋 Role Bindings:"
kubectl get rolebindings,clusterrolebindings --all-namespaces -o yaml | grep -A 10 -B 10 "$SERVICE_ACCOUNT" || echo "No explicit role bindings found"

echo "📋 Permission Check:"
kubectl auth can-i get secrets --as="system:serviceaccount:$NAMESPACE:$SERVICE_ACCOUNT" -n "$NAMESPACE"
kubectl auth can-i list secrets --as="system:serviceaccount:$NAMESPACE:$SERVICE_ACCOUNT" -n "$NAMESPACE"

# Network connectivity (if applicable)
echo "📋 Network Analysis:"
kubectl get networkpolicies -n "$NAMESPACE" || echo "No network policies found"

# Node and cluster health
echo "📋 Infrastructure Health:"
kubectl top nodes 2>/dev/null || echo "Metrics server not available"
kubectl get nodes -o wide
```

**Diagnostic Questions**: 
1. How do RBAC failures typically manifest in secret access issues?
2. What network issues could affect secret access?
3. How might node resource constraints impact secret operations?

## Common Problem Patterns and Solutions

Let's build a troubleshooting playbook for the most common secret-related issues:

### Pattern 1: "Secret Not Found" Errors

**Symptoms**: Pods fail to start, logs show secret not found
**Common Causes**: Typos in secret names, namespace mismatches, timing issues

```bash
# Debug script for secret not found issues
debug_secret_not_found() {
    local namespace=$1
    local secret_name=$2
    local pod_name=$3
    
    echo "🔍 Debugging 'Secret Not Found' for $secret_name"
    
    # Verify secret exists
    if ! kubectl get secret "$secret_name" -n "$namespace" &>/dev/null; then
        echo "❌ Secret '$secret_name' does not exist in namespace '$namespace'"
        echo "Available secrets:"
        kubectl get secrets -n "$namespace" -o name
        return 1
    fi
    
    # Check secret keys
    echo "📋 Secret keys available:"
    kubectl get secret "$secret_name" -n "$namespace" -o jsonpath='{.data}' | jq -r 'keys[]'
    
    # Check pod secret reference
    echo "📋 Pod secret references:"
    kubectl get pod "$pod_name" -n "$namespace" -o yaml | grep -A 5 -B 5 secretKeyRef || echo "No secretKeyRef found"
    
    # Check for case sensitivity issues
    echo "📋 Case sensitivity check:"
    kubectl get secrets -n "$namespace" -o name | grep -i "$secret_name"
}

# Example usage
# debug_secret_not_found "production" "database-secrets" "web-app-pod-123"
```

### Pattern 2: Permission Denied Errors

**Symptoms**: Applications can't access secret data, RBAC-related errors
**Common Causes**: Insufficient RBAC permissions, wrong service account

```bash
# Debug RBAC issues with secrets
debug_secret_permissions() {
    local namespace=$1
    local service_account=$2
    local secret_name=$3
    
    echo "🔐 Debugging Secret Permissions"
    echo "Namespace: $namespace, SA: $service_account, Secret: $secret_name"
    
    # Check if service account exists
    if ! kubectl get serviceaccount "$service_account" -n "$namespace" &>/dev/null; then
        echo "❌ Service account '$service_account' does not exist"
        return 1
    fi
    
    # Test specific permissions
    echo "📋 Permission tests:"
    kubectl auth can-i get secret "$secret_name" --as="system:serviceaccount:$namespace:$service_account" -n "$namespace"
    kubectl auth can-i list secrets --as="system:serviceaccount:$namespace:$service_account" -n "$namespace"
    
    # Show what permissions the SA actually has
    echo "📋 Actual permissions for $service_account:"
    kubectl auth can-i --list --as="system:serviceaccount:$namespace:$service_account" -n "$namespace" | grep secrets
    
    # Find relevant role bindings
    echo "📋 Relevant role bindings:"
    kubectl get rolebindings,clusterrolebindings --all-namespaces -o yaml | \
        grep -A 15 -B 5 "system:serviceaccount:$namespace:$service_account"
}
```

### Pattern 3: Secret Data Corruption/Encoding Issues

**Symptoms**: Applications receive malformed data, authentication failures with correct passwords
**Common Causes**: Base64 encoding issues, newline characters, character encoding problems

```bash
# Debug secret data integrity
debug_secret_data() {
    local namespace=$1
    local secret_name=$2
    local key=$3
    
    echo "🔬 Debugging Secret Data Integrity"
    echo "Secret: $namespace/$secret_name, Key: $key"
    
    # Extract and examine the raw base64 data
    local encoded_value=$(kubectl get secret "$secret_name" -n "$namespace" -o jsonpath="{.data.$key}")
    
    if [[ -z "$encoded_value" ]]; then
        echo "❌ Key '$key' not found in secret"
        echo "Available keys:"
        kubectl get secret "$secret_name" -n "$namespace" -o jsonpath='{.data}' | jq -r 'keys[]'
        return 1
    fi
    
    echo "📋 Raw base64 value (first 50 chars): ${encoded_value:0:50}..."
    
    # Decode and analyze
    local decoded_value=$(echo "$encoded_value" | base64 -d)
    echo "📋 Decoded length: ${#decoded_value} characters"
    
    # Check for common issues
    if [[ "$decoded_value" == *$'\n' ]]; then
        echo "⚠️  WARNING: Value contains newline character(s)"
    fi
    
    if [[ "$decoded_value" == *$'\r' ]]; then
        echo "⚠️  WARNING: Value contains carriage return character(s)"
    fi
    
    # Check for non-printable characters
    if [[ "$decoded_value" =~ [^[:print:]] ]]; then
        echo "⚠️  WARNING: Value contains non-printable characters"
        echo "Hex dump of first 32 bytes:"
        echo "$decoded_value" | xxd | head -2
    fi
    
    echo "✅ Data integrity check completed"
}
```

**Hands-On Exercise**: Create a secret with a trailing newline and test how it affects your application. How would you detect and fix this issue?

## Advanced Troubleshooting Techniques

### Technique 1: Secret Lifecycle Tracing

Sometimes you need to trace the entire lifecycle of a secret to understand issues:

```bash
#!/bin/bash
# secret-lifecycle-tracer.sh

trace_secret_lifecycle() {
    local namespace=$1
    local secret_name=$2
    
    echo "🕵️ Tracing Secret Lifecycle: $namespace/$secret_name"
    
    # Creation history
    echo "📋 Creation Information:"
    kubectl get secret "$secret_name" -n "$namespace" -o yaml | grep -E "(creationTimestamp|generation|resourceVersion)"
    
    # Ownership and relationships
    echo "📋 Ownership and References:"
    kubectl get secret "$secret_name" -n "$namespace" -o yaml | grep -E "(ownerReferences|labels|annotations)" -A 10
    
    # Usage tracking
    echo "📋 Current Usage:"
    echo "Pods using this secret:"
    kubectl get pods -n "$namespace" -o yaml | grep -B 5 -A 5 "$secret_name" | grep -E "(name:|secretName|secretKeyRef)"
    
    # Events related to this secret
    echo "📋 Related Events:"
    kubectl get events -n "$namespace" --field-selector involvedObject.name="$secret_name" --sort-by='.lastTimestamp'
    
    # Modification history (if audit logging is enabled)
    echo "📋 Recent Modifications:"
    kubectl get events -n "$namespace" --field-selector involvedObject.kind=Secret,involvedObject.name="$secret_name" | grep -E "(UPDATE|PATCH|DELETE)"
}
```

### Technique 2: Cross-Reference Validation

Validate secrets against their intended usage:

```bash
#!/bin/bash
# cross-reference-validator.sh

validate_secret_usage() {
    local namespace=$1
    local app_label=$2
    
    echo "🔍 Cross-Reference Validation for $app_label in $namespace"
    
    # Find all secrets referenced by the application
    echo "📋 Secrets referenced by application:"
    local referenced_secrets=$(kubectl get pods -n "$namespace" -l "$app_label" -o yaml | \
        grep -E "(secretName|name.*secretRef)" | sort -u)
    
    echo "$referenced_secrets"
    
    # Check if all referenced secrets exist
    echo "📋 Existence validation:"
    while read -r line; do
        if [[ $line =~ secretName:.*([a-zA-Z0-9-]+) ]]; then
            local secret_name="${BASH_REMATCH[1]}"
            if kubectl get secret "$secret_name" -n "$namespace" &>/dev/null; then
                echo "✅ Secret '$secret_name' exists"
            else
                echo "❌ Secret '$secret_name' is missing"
            fi
        fi
    done <<< "$referenced_secrets"
    
    # Check for unused secrets
    echo "📋 Unused secrets analysis:"
    kubectl get secrets -n "$namespace" -o name | while read secret_path; do
        local secret_name=$(basename "$secret_path")
        if [[ "$secret_name" != "default-token"* ]]; then
            if ! kubectl get pods -n "$namespace" -o yaml | grep -q "$secret_name"; then
                echo "⚠️  Potentially unused secret: $secret_name"
            fi
        fi
    done
}
```

## Building Operational Excellence

### Monitoring and Alerting

Let's implement comprehensive monitoring for secret operations:

```yaml
# secret-monitoring-stack.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: secret-monitor
  namespace: monitoring
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: secret-monitor
rules:
- apiGroups: [""]
  resources: ["secrets", "pods", "events"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: secret-monitor
subjects:
- kind: ServiceAccount
  name: secret-monitor
  namespace: monitoring
roleRef:
  kind: ClusterRole
  name: secret-monitor
  apiGroup: rbac.authorization.k8s.io
---
# Monitoring deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secret-monitor
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: secret-monitor
  template:
    metadata:
      labels:
        app: secret-monitor
    spec:
      serviceAccountName: secret-monitor
      containers:
      - name: monitor
        image: alpine:latest
        command:
        - /bin/sh
        - -c
        - |
          apk add --no-cache curl jq
          
          while true; do
            echo "$(date): Running secret health checks..."
            
            # Check for secrets without corresponding pods
            echo "Checking for orphaned secrets..."
            kubectl get secrets --all-namespaces -o json | jq -r '
              .items[] | 
              select(.metadata.name | startswith("default-token") | not) |
              "\(.metadata.namespace) \(.metadata.name)"
            ' | while read namespace secret_name; do
              if ! kubectl get pods -n "$namespace" -o yaml | grep -q "$secret_name"; then
                echo "WARNING: Orphaned secret detected: $namespace/$secret_name"
              fi
            done
            
            # Check for pods failing due to secret issues
            echo "Checking for secret-related pod failures..."
            kubectl get pods --all-namespaces --field-selector=status.phase=Failed -o json | jq -r '
              .items[] | 
              select(.status.containerStatuses[]?.state.waiting.reason == "CreateContainerConfigError") |
              "\(.metadata.namespace) \(.metadata.name)"
            ' | while read namespace pod_name; do
              echo "ALERT: Pod $namespace/$pod_name failed with container config error (possible secret issue)"
            done
            
            # Check secret age and rotation requirements
            echo "Checking secret rotation requirements..."
            kubectl get secrets --all-namespaces -o json | jq -r '
              .items[] |
              select(.metadata.name | startswith("default-token") | not) |
              select(.metadata.creationTimestamp != null) |
              "\(.metadata.namespace) \(.metadata.name) \(.metadata.creationTimestamp)"
            ' | while read namespace secret_name created; do
              created_epoch=$(date -d "$created" +%s)
              current_epoch=$(date +%s)
              age_days=$(( (current_epoch - created_epoch) / 86400 ))
              
              if [[ $age_days -gt 90 ]]; then
                echo "WARNING: Secret $namespace/$secret_name is $age_days days old (rotation recommended)"
              fi
            done
            
            sleep 300  # Check every 5 minutes
          done
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
```

**Implementation Challenge**: Deploy this monitoring solution and observe its output. What additional checks would be valuable in your environment?

### Operational Runbooks

Let's create comprehensive runbooks for common secret operations:

```bash
#!/bin/bash
# secret-operations-runbook.sh

# Runbook: Emergency Secret Rotation
emergency_secret_rotation() {
    local namespace=$1
    local secret_name=$2
    local incident_id=${3:-"INC-$(date +%Y%m%d-%H%M%S)"}
    
    echo "🚨 EMERGENCY SECRET ROTATION INITIATED"
    echo "Incident ID: $incident_id"
    echo "Secret: $namespace/$secret_name"
    echo "Operator: $(whoami)"
    echo "Timestamp: $(date)"
    
    # Step 1: Document current state
    echo "📋 Step 1: Documenting current state"
    local backup_file="secret-backup-$incident_id.yaml"
    kubectl get secret "$secret_name" -n "$namespace" -o yaml > "$backup_file"
    echo "Current state backed up to: $backup_file"
    
    # Step 2: Identify affected applications
    echo "📋 Step 2: Identifying affected applications"
    local affected_pods=$(kubectl get pods -n "$namespace" -o yaml | grep -l "$secret_name" | wc -l)
    echo "Potentially affected pods: $affected_pods"
    
    kubectl get pods -n "$namespace" -o jsonpath='{range .items[*]}{.metadata.name}{" uses: "}{.spec.containers[*].envFrom[*].secretRef.name}{" "}{.spec.volumes[*].secret.secretName}{"\n"}{end}' | \
        grep "$secret_name" > "affected-pods-$incident_id.txt"
    
    # Step 3: Create new secret with rotated values
    echo "📋 Step 3: Creating rotated secret"
    echo "⚠️  MANUAL ACTION REQUIRED: Generate new secret values"
    echo "Example commands:"
    echo "  kubectl create secret generic $secret_name-new \\"
    echo "    --from-literal=key1=new_rotated_value_1 \\"
    echo "    --from-literal=key2=new_rotated_value_2 \\"
    echo "    --namespace=$namespace"
    
    read -p "Press Enter after creating the new secret ($secret_name-new)..."
    
    # Step 4: Update applications to use new secret
    echo "📋 Step 4: Updating applications"
    echo "⚠️  MANUAL ACTION REQUIRED: Update deployment specifications"
    echo "Use commands like:"
    echo "  kubectl patch deployment <app-name> -n $namespace -p '{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"<container>\",\"envFrom\":[{\"secretRef\":{\"name\":\"$secret_name-new\"}}]}]}}}}'"
    
    read -p "Press Enter after updating all applications..."
    
    # Step 5: Verify deployment
    echo "📋 Step 5: Verifying deployment"
    kubectl get pods -n "$namespace" -o wide
    
    echo "📋 Step 6: Health check"
    echo "⚠️  MANUAL ACTION REQUIRED: Verify application functionality"
    echo "Check application logs, endpoints, and functionality"
    
    read -p "Press Enter after verifying application health..."
    
    # Step 7: Cleanup old secret
    echo "📋 Step 7: Cleanup"
    echo "Safe to remove old secret? This action cannot be undone."
    read -p "Type 'yes' to confirm: " confirmation
    
    if [[ "$confirmation" == "yes" ]]; then
        kubectl delete secret "$secret_name" -n "$namespace"
        kubectl get secret "$secret_name-new" -n "$namespace" -o yaml | \
            sed "s/$secret_name-new/$secret_name/g" | \
            kubectl apply -f -
        kubectl delete secret "$secret_name-new" -n "$namespace"
        echo "✅ Secret rotation completed successfully"
    else
        echo "⚠️  Cleanup skipped. Manual cleanup required."
    fi
    
    echo "📋 Incident Summary:"
    echo "Incident ID: $incident_id"
    echo "Secret rotated: $namespace/$secret_name"
    echo "Backup location: $backup_file"
    echo "Affected pods list: affected-pods-$incident_id.txt"
    echo "Completed at: $(date)"
}

# Runbook: Secret Disaster Recovery
secret_disaster_recovery() {
    local namespace=$1
    local recovery_scope=${2:-"namespace"}  # namespace, cluster, or specific-secret
    
    echo "🆘 SECRET DISASTER RECOVERY INITIATED"
    echo "Scope: $recovery_scope"
    echo "Namespace: $namespace"
    
    case $recovery_scope in
        "namespace")
            echo "📋 Recovering all secrets in namespace: $namespace"
            # Check for backup sources
            echo "Available backup sources:"
            echo "1. etcd snapshots"
            echo "2. GitOps repository"
            echo "3. External secret manager"
            echo "4. Manual backup files"
            
            echo "⚠️  MANUAL ACTION REQUIRED: Choose recovery method and execute"
            ;;
        "cluster")
            echo "📋 Cluster-wide secret recovery"
            echo "This requires cluster administrator access and etcd recovery procedures"
            echo "⚠️  ESCALATION REQUIRED: Contact cluster administrators"
            ;;
        "specific-secret")
            local secret_name=$3
            echo "📋 Recovering specific secret: $secret_name"
            
            # Look for recent backups
            ls -la secret-backup-*"$secret_name"* 2>/dev/null | head -5
            echo "Recent backup files shown above"
            
            echo "Recovery options:"
            echo "1. Restore from backup file: kubectl apply -f <backup-file>"
            echo "2. Recreate from external source"
            echo "3. Trigger automated sync (if external secret operator is used)"
            ;;
    esac
    
    echo "📋 Post-recovery verification checklist:"
    echo "□ All secrets are accessible"
    echo "□ Applications can authenticate successfully"
    echo "□ No pods are in CrashLoopBackOff state"
    echo "□ External service connectivity verified"
    echo "□ Monitoring and alerting systems operational"
}

# Usage examples:
# emergency_secret_rotation "production" "database-secrets"
# secret_disaster_recovery "production" "specific-secret" "api-keys"
```

### Performance Optimization

Secret operations can impact cluster performance. Let's implement optimization strategies:

```bash
#!/bin/bash
# secret-performance-optimizer.sh

analyze_secret_performance() {
    echo "🚀 Secret Performance Analysis"
    
    # Secret size analysis
    echo "📊 Secret Size Analysis:"
    kubectl get secrets --all-namespaces -o json | jq -r '
      .items[] | 
      select(.metadata.name | startswith("default-token") | not) |
      {
        namespace: .metadata.namespace,
        name: .metadata.name,
        size: (.data | to_entries | map(.value | length) | add // 0),
        keys: (.data | keys | length)
      } | 
      "\(.namespace) \(.name) \(.size) \(.keys)"
    ' | sort -k3 -nr | head -20
    
    # Secret usage patterns
    echo "📊 Secret Usage Patterns:"
    kubectl get pods --all-namespaces -o json | jq -r '
      .items[] | 
      {
        namespace: .metadata.namespace,
        name: .metadata.name,
        secret_env_count: ([.spec.containers[]?.env[]? | select(.valueFrom.secretKeyRef)] | length),
        secret_volume_count: ([.spec.volumes[]? | select(.secret)] | length),
        envFrom_count: ([.spec.containers[]?.envFrom[]? | select(.secretRef)] | length)
      } |
      select(.secret_env_count > 0 or .secret_volume_count > 0 or .envFrom_count > 0) |
      "\(.namespace) \(.name) env:\(.secret_env_count) vol:\(.secret_volume_count) envFrom:\(.envFrom_count)"
    '
    
    # Performance recommendations
    echo "📋 Performance Recommendations:"
    echo "1. Large secrets (>1MB) should be split or moved to external storage"
    echo "2. Secrets with many keys (>20) may benefit from restructuring"
    echo "3. Consider using envFrom instead of individual secretKeyRef for bulk loading"
    echo "4. Monitor secret update frequency to optimize caching"
}

optimize_secret_structure() {
    local namespace=$1
    local secret_name=$2
    
    echo "🔧 Optimizing Secret Structure: $namespace/$secret_name"
    
    # Analyze current structure
    local key_count=$(kubectl get secret "$secret_name" -n "$namespace" -o json | jq '.data | keys | length')
    local total_size=$(kubectl get secret "$secret_name" -n "$namespace" -o json | jq '.data | to_entries | map(.value | length) | add')
    
    echo "Current structure:"
    echo "  Keys: $key_count"
    echo "  Total size: $total_size bytes"
    
    if [[ $key_count -gt 20 ]]; then
        echo "⚠️  Recommendation: Consider splitting into multiple secrets by function"
        kubectl get secret "$secret_name" -n "$namespace" -o json | jq -r '.data | keys[]' | head -10
        echo "... and $(($key_count - 10)) more keys"
    fi
    
    if [[ $total_size -gt 1048576 ]]; then  # 1MB
        echo "⚠️  Recommendation: Secret is large (>1MB), consider external storage"
        kubectl get secret "$secret_name" -n "$namespace" -o json | jq -r '
          .data | to_entries | 
          map({key: .key, size: (.value | length)}) | 
          sort_by(.size) | reverse | 
          .[:5][]
        '
    fi
}
```

## Mini-Project 7: Complete Troubleshooting System

Let's build a comprehensive troubleshooting and operational excellence system:

**Project Requirements**:
1. **Automated Diagnostics**: Scripts that can quickly identify common issues
2. **Performance Monitoring**: Track secret-related performance metrics
3. **Operational Runbooks**: Step-by-step procedures for common operations
4. **Disaster Recovery**: Automated backup and recovery procedures
5. **Health Dashboards**: Visual monitoring of secret system health

### Implementation Framework

```yaml
# troubleshooting-system.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: secret-ops
  labels:
    purpose: operations
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: troubleshooting-scripts
  namespace: secret-ops
data:
  quick-diagnose.sh: |
    #!/bin/bash
    echo "🔍 Quick Secret System Diagnosis"
    
    # System health
    kubectl get nodes -o wide
    kubectl get pods --all-namespaces | grep -E "(Error|CrashLoop|Pending)" | head -10
    
    # Secret system health
    kubectl get secrets --all-namespaces | wc -l
    kubectl get events --all-namespaces --field-selector involvedObject.kind=Secret | tail -10
    
    # Common issues check
    echo "Checking for common secret issues..."
    kubectl get pods --all-namespaces --field-selector=status.phase=Failed | \
      grep -E "(secret|Secret)" || echo "No obvious secret-related failures"
  
  performance-check.sh: |
    #!/bin/bash
    echo "📊 Secret Performance Check"
    
    # Large secrets
    echo "Top 10 largest secrets:"
    kubectl get secrets --all-namespaces -o json | jq -r '
      .items[] | 
      select(.metadata.name | startswith("default-token") | not) |
      "\(.metadata.namespace) \(.metadata.name) \((.data | to_entries | map(.value | length) | add // 0))"
    ' | sort -k3 -nr | head -10
    
    # Secret access patterns
    echo "Heavy secret users:"
    kubectl get pods --all-namespaces -o json | jq -r '
      .items[] | 
      "\(.metadata.namespace) \(.metadata.name) \(([.spec.containers[]?.env[]? | select(.valueFrom.secretKeyRef)] | length))"
    ' | awk '$3 > 5' | sort -k3 -nr
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secret-troubleshooter
  namespace: secret-ops
spec:
  replicas: 1
  selector:
    matchLabels:
      app: secret-troubleshooter
  template:
    metadata:
      labels:
        app: secret-troubleshooter
    spec:
      serviceAccountName: secret-monitor
      containers:
      - name: troubleshooter
        image: alpine:latest
        command: ["/bin/sh", "-c", "tail -f /dev/null"]
        volumeMounts:
        - name: scripts
          mountPath: /scripts
          readOnly: true
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
      volumes:
      - name: scripts
        configMap:
          name: troubleshooting-scripts
          defaultMode: 0755
```

**Implementation Challenge**: Deploy this system and use it to diagnose issues in your cluster. What additional diagnostic capabilities would you add?

### Advanced Troubleshooting Techniques

#### Technique 1: Secret Event Correlation

```bash
#!/bin/bash
# secret-event-correlator.sh

correlate_secret_events() {
    local time_window=${1:-"1h"}
    
    echo "🔗 Correlating Secret Events (last $time_window)"
    
    # Get secret-related events
    kubectl get events --all-namespaces --sort-by='.lastTimestamp' | \
        grep -i secret | \
        while read line; do
            echo "$line"
        done > /tmp/secret-events.log
    
    # Get pod events around the same time
    kubectl get events --all-namespaces --sort-by='.lastTimestamp' | \
        grep -E "(Failed|Error|Warning)" | \
        while read line; do
            echo "$line"
        done > /tmp/pod-events.log
    
    echo "📊 Event correlation analysis:"
    echo "Secret events: $(wc -l < /tmp/secret-events.log)"
    echo "Pod error events: $(wc -l < /tmp/pod-events.log)"
    
    # Look for temporal correlations
    echo "📋 Potential correlations:"
    join -t' ' -1 1 -2 1 <(sort /tmp/secret-events.log) <(sort /tmp/pod-events.log) | head -5
}
```

#### Technique 2: Secret Dependency Mapping

```bash
#!/bin/bash
# secret-dependency-mapper.sh

map_secret_dependencies() {
    local namespace=${1:-"--all-namespaces"}
    
    echo "🗺️ Mapping Secret Dependencies"
    
    # Create dependency graph
    echo "digraph secret_dependencies {" > /tmp/secret-deps.dot
    echo "  rankdir=TB;" >> /tmp/secret-deps.dot
    
    if [[ "$namespace" == "--all-namespaces" ]]; then
        kubectl get secrets --all-namespaces -o json
    else
        kubectl get secrets -n "$namespace" -o json
    fi | jq -r '
      .items[] | 
      select(.metadata.name | startswith("default-token") | not) |
      "\(.metadata.namespace) \(.metadata.name)"
    ' | while read ns secret_name; do
        echo "  \"$ns/$secret_name\" [shape=box, color=blue];" >> /tmp/secret-deps.dot
        
        # Find pods that use this secret
        kubectl get pods -n "$ns" -o json | jq -r --arg secret "$secret_name" '
          .items[] | 
          select(.spec.containers[]?.env[]?.valueFrom.secretKeyRef.name == $secret or
                 .spec.containers[]?.envFrom[]?.secretRef.name == $secret or
                 .spec.volumes[]?.secret.secretName == $secret) |
          "\(.metadata.name)"
        ' | while read pod_name; do
            echo "  \"$ns/$pod_name\" [shape=ellipse, color=green];" >> /tmp/secret-deps.dot
            echo "  \"$ns/$secret_name\" -> \"$ns/$pod_name\";" >> /tmp/secret-deps.dot
        done
    done
    
    echo "}" >> /tmp/secret-deps.dot
    
    echo "📊 Dependency graph created: /tmp/secret-deps.dot"
    echo "To visualize: dot -Tpng /tmp/secret-deps.dot > secret-deps.png"
}
```

## Disaster Recovery and Business Continuity

### Automated Backup System

```bash
#!/bin/bash
# secret-backup-system.sh

backup_secrets() {
    local backup_type=${1:-"full"}  # full, incremental, or differential
    local retention_days=${2:-30}
    local backup_location=${3:-"/backups/secrets"}
    
    echo "💾 Secret Backup System - Type: $backup_type"
    
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_dir="$backup_location/$backup_type-$timestamp"
    
    mkdir -p "$backup_dir"
    
    case $backup_type in
        "full")
            echo "Performing full backup..."
            kubectl get secrets --all-namespaces -o yaml > "$backup_dir/all-secrets.yaml"
            
            # Backup RBAC related to secrets
            kubectl get roles,rolebindings,clusterroles,clusterrolebindings --all-namespaces -o yaml | \
                grep -A 50 -B 10 secrets > "$backup_dir/secret-rbac.yaml"
            ;;
        "incremental")
            echo "Performing incremental backup..."
            # Only backup secrets modified in the last 24 hours
            kubectl get secrets --all-namespaces -o json | jq -r '
              .items[] | 
              select(.metadata.creationTimestamp >= (now - 86400 | strftime("%Y-%m-%dT%H:%M:%SZ"))) |
              "kubectl get secret \(.metadata.name) -n \(.metadata.namespace) -o yaml"
            ' | bash > "$backup_dir/recent-secrets.yaml"
            ;;
    esac
    
    # Create manifest of what was backed up
    cat > "$backup_dir/backup-manifest.json" <<EOF
{
  "timestamp": "$timestamp",
  "type": "$backup_type",
  "retention_days": $retention_days,
  "secret_count": $(kubectl get secrets --all-namespaces | wc -l),
  "operator": "$(whoami)",
  "cluster_version": "$(kubectl version --short | head -1)"
}
EOF
    
    # Cleanup old backups
    find "$backup_location" -type d -name "*-*" -mtime +$retention_days -exec rm -rf {} \;
    
    echo "✅ Backup completed: $backup_dir"
}

restore_secrets() {
    local backup_path=$1
    local restoration_scope=${2:-"dry-run"}  # dry-run, namespace, or full
    local target_namespace=${3:-""}
    
    echo "🔄 Secret Restoration - Scope: $restoration_scope"
    
    if [[ ! -d "$backup_path" ]]; then
        echo "❌ Backup path not found: $backup_path"
        return 1
    fi
    
    # Validate backup
    if [[ ! -f "$backup_path/backup-manifest.json" ]]; then
        echo "❌ Invalid backup: manifest not found"
        return 1
    fi
    
    echo "📋 Backup Information:"
    cat "$backup_path/backup-manifest.json" | jq .
    
    case $restoration_scope in
        "dry-run")
            echo "🔍 Dry-run: Analyzing what would be restored"
            if [[ -f "$backup_path/all-secrets.yaml" ]]; then
                grep -E "^  name:|^  namespace:" "$backup_path/all-secrets.yaml" | paste - -
            fi
            ;;
        "namespace")
            if [[ -z "$target_namespace" ]]; then
                echo "❌ Target namespace required for namespace restoration"
                return 1
            fi
            echo "Restoring secrets to namespace: $target_namespace"
            kubectl apply -f "$backup_path/all-secrets.yaml" -n "$target_namespace" --dry-run=client
            ;;
        "full")
            echo "⚠️  DANGER: Full cluster secret restoration"
            read -p "Type 'I understand the risks' to proceed: " confirmation
            if [[ "$confirmation" == "I understand the risks" ]]; then
                kubectl apply -f "$backup_path/all-secrets.yaml"
            else
                echo "Restoration cancelled"
            fi
            ;;
    esac
}
```

## Final Assessment: Operational Excellence Challenge

**Capstone Project**: Build a complete operational excellence system for secret management that demonstrates mastery of troubleshooting and operations.

**Scenario**: You're the platform engineer responsible for a Kubernetes cluster running 200+ microservices across 50+ namespaces. You need to implement a comprehensive operational system that can handle:

1. **Proactive Monitoring**: Detect issues before they cause outages
2. **Rapid Troubleshooting**: Diagnose and resolve issues quickly
3. **Automated Recovery**: Handle common issues automatically
4. **Business Continuity**: Ensure secrets are backed up and recoverable
5. **Performance Optimization**: Keep the system running efficiently

**Deliverables**:

1. **Monitoring System**: Comprehensive monitoring with alerting
2. **Diagnostic Tools**: Automated troubleshooting scripts
3. **Operational Runbooks**: Step-by-step procedures for common scenarios
4. **Backup/Recovery System**: Automated backup and recovery procedures
5. **Performance Dashboard**: Metrics and optimization recommendations
6. **Documentation**: Complete operational documentation

**Success Criteria**:
- Detect secret-related issues within 5 minutes
- Resolve 80% of common issues automatically
- Complete disaster recovery within 30 minutes
- Maintain 99.9% secret availability
- Document all procedures with runbooks

**Advanced Extensions**:
- Integrate with external monitoring systems (Prometheus, Grafana)
- Implement predictive analytics for secret issues
- Create self-healing capabilities for common problems
- Build compliance reporting for audit requirements

## Reflection and Continuous Improvement

Congratulations on completing the troubleshooting and operational excellence unit! Let's reflect on your journey:

**Technical Mastery Validation**:
1. Can you quickly diagnose the root cause of a "secret not found" error?
2. Do you understand the performance implications of different secret usage patterns?
3. Can you implement a comprehensive monitoring solution for secrets?
4. Are you prepared to handle disaster recovery scenarios?

**Operational Thinking**:
1. How would you measure the success of your secret operations?
2. What would your escalation procedures look like for critical secret failures?
3. How would you balance automation with human oversight in secret operations?
4. What metrics would you track to continuously improve your secret management?

**Strategic Planning**:
1. How would you evolve your operational practices as your organization scales?
2. What investments would you prioritize to improve operational excellence?
3. How would you build a culture of operational excellence around secret management?

## What's Next?

You've now mastered the complete lifecycle of Kubernetes secret management, from fundamentals through operational excellence. Here are your next steps:

**Immediate Applications**:
- Implement these operational practices in your current environment
- Conduct operational readiness assessments
- Build and train your team on these procedures

**Advanced Specializations**:
- Platform engineering and infrastructure automation
- Site Reliability Engineering (SRE) practices
- Security operations and incident response
- Multi-cloud and hybrid cloud secret management

**Leadership and Mentorship**:
- Share your knowledge through documentation and training
- Lead operational excellence initiatives
- Mentor others in Kubernetes secret management
- Contribute to operational best practices in your organization

**Community Engagement**:
- Contribute to open-source operational tools
- Share your operational patterns and lessons learned
- Participate in SRE and platform engineering communities

You're now equipped with production-grade Kubernetes secret management expertise that spans from basic concepts to advanced operational practices. The systematic approaches, troubleshooting methodologies, and operational frameworks you've learned will serve you well in any Kubernetes environment, from small startups to large enterprises.

Remember: Operational excellence is not a destination but a continuous journey of learning, improving, and adapting to new challenges and requirements.