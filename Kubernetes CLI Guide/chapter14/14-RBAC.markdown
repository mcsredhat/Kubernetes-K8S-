# 14. RBAC (Role-Based Access Control) - Complete Guide

## Understanding RBAC: The Foundation of Kubernetes Security

RBAC controls who can do what in your Kubernetes cluster, implementing the principle of least privilege. Think of RBAC like a sophisticated building security system where different people get different keycards based on their job responsibilities. A janitor doesn't need access to the executive floor, and an executive doesn't need access to the server room - everyone gets exactly the permissions they need, nothing more.

### The Four Pillars of RBAC

Before diving into commands, let's understand the four key components that work together to create a complete security system:

1. **Service Accounts**: These are like identity badges for applications and automated systems
2. **Roles**: These define what actions can be performed (like "can read files" or "can delete pods")
3. **RoleBindings**: These connect identities to roles (like giving someone a keycard)
4. **Resources**: These are the things being protected (pods, services, secrets, etc.)

## Service Accounts: Digital Identities

Service accounts are how Kubernetes identifies who or what is making a request. Every pod runs with a service account, and every kubectl command is executed by a user or service account.

```bash
# Create Service Account - identity for applications and users
kubectl create serviceaccount app-sa # Service account for applications
kubectl create sa monitoring-sa # 'sa' is shorthand for serviceaccount

# List Service Accounts to see what identities exist
kubectl get serviceaccounts
kubectl get sa
kubectl describe sa app-sa # Shows associated secrets and tokens - these are like digital certificates

# Every namespace gets a 'default' service account automatically
# This is like having a basic visitor badge that every pod gets if you don't specify otherwise
kubectl get sa default
```

Think of service accounts as employee ID badges. Each badge has a unique identifier and can be granted different levels of access throughout the building.

## Roles: Defining What Actions Are Allowed

Roles are permission templates that define what actions can be performed on which resources. There are two types of roles, and understanding the difference is crucial:

### Namespace-Scoped Roles
These work like department-specific permissions - they only apply within a single namespace (department).

```bash
# Create Role - permissions within a namespace
kubectl create role pod-reader \
  --verb=get,list,watch \
  --resource=pods \
  --namespace=development
# This creates a role that can read pods, but only in the 'development' namespace

# You can also specify resource names for granular control
kubectl create role specific-pod-reader \
  --verb=get,list \
  --resource=pods \
  --resource-name=my-important-pod \
  --namespace=development
# This role can only read one specific pod named 'my-important-pod'
```

### Cluster-Wide Roles
These are like company-wide permissions that work across all departments (namespaces).

```bash
# Create ClusterRole - cluster-wide permissions
kubectl create clusterrole cluster-reader \
  --verb=get,list,watch \
  --resource=nodes,namespaces
# This creates permissions that work across the entire cluster
# Nodes and namespaces are cluster-level resources (they don't belong to any specific namespace)

# ClusterRoles can also be bound to work within specific namespaces
# This gives you flexibility in how you apply permissions
```

## RoleBindings: Connecting Identities to Permissions

RoleBindings are like the process of actually giving someone their keycard. You take an identity (service account) and give it a role (set of permissions).

```bash
# Create RoleBinding - assigns role to service account within a namespace
kubectl create rolebinding pod-reader-binding \
  --role=pod-reader \
  --serviceaccount=development:app-sa \
  --namespace=development
# This says: "Give the app-sa service account the pod-reader permissions, but only in the development namespace"

# Create ClusterRoleBinding - assigns cluster-wide permissions
kubectl create clusterrolebinding cluster-reader-binding \
  --clusterrole=cluster-reader \
  --serviceaccount=development:app-sa
# This says: "Give the app-sa service account cluster-reader permissions across the entire cluster"

# You can bind roles to users and groups too, not just service accounts
kubectl create rolebinding user-pod-reader \
  --role=pod-reader \
  --user=jane@company.com \
  --namespace=development

kubectl create rolebinding group-pod-reader \
  --role=pod-reader \
  --group=developers \
  --namespace=development
```

## Testing Your Security: The Critical Step

The most important command in RBAC is testing whether your permissions work as expected. This prevents security holes and access denials.

```bash
# Test permissions - verify RBAC configuration
kubectl auth can-i get pods \
  --as=system:serviceaccount:development:app-sa \
  --namespace=development
# Returns 'yes' or 'no' - essential for debugging access issues

# Test multiple scenarios to ensure your RBAC is working correctly
kubectl auth can-i create pods --as=system:serviceaccount:development:app-sa --namespace=development
kubectl auth can-i delete pods --as=system:serviceaccount:development:app-sa --namespace=development
kubectl auth can-i get pods --as=system:serviceaccount:development:app-sa --namespace=production

# You can also test what YOU can do (useful when setting up your own access)
kubectl auth can-i create deployments
kubectl auth can-i "*" "*" # Check if you have admin access (dangerous if yes!)
```

**Best Practice**: Always test RBAC policies with `kubectl auth can-i` before deploying applications. Use least-privilege principles and regularly audit permissions. This is like testing keycards before giving them to employees - you want to make sure they work for what they need and don't work for what they shouldn't access.

## Example: Creating a Read-Only User

Let's walk through creating a comprehensive read-only user step by step. This is a common pattern for monitoring systems, auditors, or junior team members who need to observe but not modify the system.

```yaml
# readonly-rbac.yaml
# This file demonstrates the declarative approach to RBAC
# Instead of running multiple kubectl commands, we define everything in YAML

apiVersion: v1
kind: ServiceAccount
metadata:
  name: readonly-user
  namespace: default
  # This creates our digital identity
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: readonly-role
  # Notice this is a ClusterRole, not a Role
  # This means it can be used across all namespaces
rules:
# Each rule defines permissions for specific API groups and resources
- apiGroups: [""] # Empty string means the core API group
  resources: ["pods", "services", "configmaps", "persistentvolumeclaims"]
  verbs: ["get", "list", "watch"]
  # get: retrieve a specific resource by name
  # list: retrieve all resources of this type
  # watch: monitor for changes in real-time
- apiGroups: ["apps"] # The apps API group contains deployments, replicasets, etc.
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods/log"] # This is a subresource - logs belonging to pods
  verbs: ["get", "list"]
  # This allows reading pod logs, which is essential for troubleshooting
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: readonly-binding
subjects:
# Subjects are who gets the permissions
- kind: ServiceAccount
  name: readonly-user
  namespace: default
roleRef:
# roleRef defines which role to grant
  kind: ClusterRole
  name: readonly-role
  apiGroup: rbac.authorization.k8s.io
```

Now let's apply and test this configuration:

```bash
# Apply the RBAC configuration
kubectl apply -f readonly-rbac.yaml

# Test the readonly user permissions systematically
echo "Testing read permissions (should be 'yes'):"
kubectl auth can-i get pods --as=system:serviceaccount:default:readonly-user
kubectl auth can-i list services --as=system:serviceaccount:default:readonly-user
kubectl auth can-i get pods/log --as=system:serviceaccount:default:readonly-user

echo "Testing write permissions (should be 'no'):"
kubectl auth can-i create pods --as=system:serviceaccount:default:readonly-user
kubectl auth can-i delete pods --as=system:serviceaccount:default:readonly-user
kubectl auth can-i update deployments --as=system:serviceaccount:default:readonly-user

# Test across different namespaces (ClusterRole should work everywhere)
kubectl auth can-i get pods --as=system:serviceaccount:default:readonly-user --namespace=kube-system
```

## Demo: Progressive RBAC Implementation

This demo shows how to build up permissions incrementally, which helps you understand how each component contributes to the overall security model.

```bash
#!/bin/bash
# save as rbac-demo.sh
# This script demonstrates building RBAC permissions step by step

NAMESPACE="rbac-demo"
SA_NAME="demo-user"

echo "🔐 RBAC Progressive Demo - Building Security Layer by Layer"

# Clean up any previous runs
kubectl delete namespace $NAMESPACE --ignore-not-found=true
sleep 5

# Create namespace and service account
echo "🏗️  Setting up foundation: namespace and identity"
kubectl create namespace $NAMESPACE
kubectl create serviceaccount $SA_NAME --namespace=$NAMESPACE

echo "🔍 Initial permissions check (should all be 'no' - this is good!):"
kubectl auth can-i get pods --as=system:serviceaccount:$NAMESPACE:$SA_NAME --namespace=$NAMESPACE
kubectl auth can-i create pods --as=system:serviceaccount:$NAMESPACE:$SA_NAME --namespace=$NAMESPACE
kubectl auth can-i get deployments --as=system:serviceaccount:$NAMESPACE:$SA_NAME --namespace=$NAMESPACE

# Step 1: Basic pod read permissions
echo ""
echo "📖 Step 1: Adding pod read permissions..."
kubectl create role pod-reader \
  --verb=get,list,watch \
  --resource=pods \
  --namespace=$NAMESPACE

kubectl create rolebinding pod-reader-binding \
  --role=pod-reader \
  --serviceaccount=$NAMESPACE:$SA_NAME \
  --namespace=$NAMESPACE

echo "   Testing pod permissions after Step 1:"
kubectl auth can-i get pods --as=system:serviceaccount:$NAMESPACE:$SA_NAME --namespace=$NAMESPACE
kubectl auth can-i create pods --as=system:serviceaccount:$NAMESPACE:$SA_NAME --namespace=$NAMESPACE

# Step 2: Add deployment permissions
echo ""
echo "🚀 Step 2: Adding deployment management permissions..."
kubectl create role deployment-manager \
  --verb=get,list,watch,create,update,patch \
  --resource=deployments \
  --namespace=$NAMESPACE

kubectl create rolebinding deployment-manager-binding \
  --role=deployment-manager \
  --serviceaccount=$NAMESPACE:$SA_NAME \
  --namespace=$NAMESPACE

echo "   Testing deployment permissions after Step 2:"
kubectl auth can-i create deployments --as=system:serviceaccount:$NAMESPACE:$SA_NAME --namespace=$NAMESPACE
kubectl auth can-i delete deployments --as=system:serviceaccount:$NAMESPACE:$SA_NAME --namespace=$NAMESPACE

# Step 3: Add log access
echo ""
echo "📋 Step 3: Adding log access permissions..."
kubectl create role log-reader \
  --verb=get,list \
  --resource=pods/log \
  --namespace=$NAMESPACE

kubectl create rolebinding log-reader-binding \
  --role=log-reader \
  --serviceaccount=$NAMESPACE:$SA_NAME \
  --namespace=$NAMESPACE

echo "   Testing log permissions after Step 3:"
kubectl auth can-i get pods/log --as=system:serviceaccount:$NAMESPACE:$SA_NAME --namespace=$NAMESPACE

# Step 4: Demonstrate that permissions are namespace-scoped
echo ""
echo "🚧 Step 4: Testing namespace isolation (should be 'no'):"
kubectl auth can-i get pods --as=system:serviceaccount:$NAMESPACE:$SA_NAME --namespace=default
kubectl auth can-i get pods --as=system:serviceaccount:$NAMESPACE:$SA_NAME --namespace=kube-system

echo ""
echo "✅ RBAC demo complete! Notice how permissions built up incrementally."
echo "🔒 Key insight: Each permission was explicitly granted - security by default!"
echo "🧹 Cleanup: kubectl delete namespace $NAMESPACE"
```

## Advanced Pattern: Team-Based RBAC System

Now let's create a comprehensive RBAC system that reflects real-world organizational structures. This example shows how to manage permissions for multiple teams across different environments.

```bash
#!/bin/bash
# save as team-rbac-system.sh
# This creates a production-ready RBAC system for multiple teams

echo "👥 Team-Based RBAC System Setup"
echo "This demonstrates enterprise-grade permission management"

# Define teams and their intended roles
# In a real organization, these would map to your actual teams
declare -A TEAMS
TEAMS[developers]="dev-role"
TEAMS[qa-engineers]="qa-role"
TEAMS[devops]="devops-role"
TEAMS[security]="security-role"
TEAMS[readonly-users]="readonly-role"

# Create namespaces for different environments
# This separation is crucial for security - production should be protected!
NAMESPACES=("development" "staging" "production")

echo "🏗️  Creating environment namespaces..."
for ns in "${NAMESPACES[@]}"; do
  kubectl create namespace $ns --dry-run=client -o yaml | kubectl apply -f -
  echo "   ✓ Created namespace: $ns"
done

echo ""
echo "👤 Creating team service accounts..."
# Create service accounts for each team
for team in "${!TEAMS[@]}"; do
  for ns in "${NAMESPACES[@]}"; do
    kubectl create serviceaccount $team --namespace=$ns --dry-run=client -o yaml | kubectl apply -f -
  done
  echo "   ✓ Created service accounts for: $team"
done

echo ""
echo "🎭 Creating role definitions..."

# Developer Role: Can manage most resources in dev/staging, read-only in production
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: development
  name: dev-role
rules:
- apiGroups: ["", "apps", "extensions"]
  resources: ["*"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["pods/exec", "pods/log"]
  verbs: ["create", "get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: staging
  name: dev-role
rules:
- apiGroups: ["", "apps", "extensions"]
  resources: ["*"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["pods/exec", "pods/log"]
  verbs: ["create", "get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: dev-role
rules:
- apiGroups: ["", "apps"]
  resources: ["pods", "services", "deployments", "replicasets"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get", "list"]
EOF

# QA Role: Full access to staging, read-only elsewhere
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: development
  name: qa-role
rules:
- apiGroups: ["", "apps"]
  resources: ["pods", "services", "deployments", "replicasets"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods/log", "pods/exec"]
  verbs: ["create", "get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: staging
  name: qa-role
rules:
- apiGroups: ["", "apps", "extensions"]
  resources: ["*"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["pods/exec", "pods/log"]
  verbs: ["create", "get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: qa-role
rules:
- apiGroups: ["", "apps"]
  resources: ["pods", "services", "deployments"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get", "list"]
EOF

# DevOps Role: Full cluster access (use with caution!)
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: devops-role
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
EOF

# Security Role: Read-only across everything + some security-specific permissions
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: security-role
rules:
- apiGroups: [""]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps", "extensions", "networking.k8s.io"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["policy"]
  resources: ["podsecuritypolicies"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
EOF

# Read-only Role: Basic read access
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: readonly-role
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get", "list"]
EOF

echo "   ✓ All roles created successfully"

echo ""
echo "🔗 Creating role bindings..."

# Create role bindings for developers
for ns in development staging production; do
  kubectl create rolebinding dev-binding \
    --role=dev-role \
    --serviceaccount=$ns:developers \
    --namespace=$ns
done

# Create role bindings for QA
for ns in development staging production; do
  kubectl create rolebinding qa-binding \
    --role=qa-role \
    --serviceaccount=$ns:qa-engineers \
    --namespace=$ns
done

# Create cluster role bindings for DevOps (they need cluster-wide access)
for ns in development staging production; do
  kubectl create clusterrolebinding devops-binding-$ns \
    --clusterrole=devops-role \
    --serviceaccount=$ns:devops
done

# Create cluster role bindings for Security team
for ns in development staging production; do
  kubectl create clusterrolebinding security-binding-$ns \
    --clusterrole=security-role \
    --serviceaccount=$ns:security
done

# Create cluster role bindings for read-only users
for ns in development staging production; do
  kubectl create clusterrolebinding readonly-binding-$ns \
    --clusterrole=readonly-role \
    --serviceaccount=$ns:readonly-users
done

echo "   ✓ All role bindings created"

echo ""
echo "🧪 Testing the permission matrix..."
echo ""

# Test developer permissions
echo "👨‍💻 Developer permissions:"
echo "   Development (should be full access):"
kubectl auth can-i create deployments --as=system:serviceaccount:development:developers --namespace=development
kubectl auth can-i delete pods --as=system:serviceaccount:development:developers --namespace=development

echo "   Production (should be read-only):"
kubectl auth can-i create deployments --as=system:serviceaccount:production:developers --namespace=production
kubectl auth can-i get pods --as=system:serviceaccount:production:developers --namespace=production

echo ""
echo "🧪 QA Engineer permissions:"
echo "   Staging (should be full access):"
kubectl auth can-i create deployments --as=system:serviceaccount:staging:qa-engineers --namespace=staging
kubectl auth can-i delete pods --as=system:serviceaccount:staging:qa-engineers --namespace=staging

echo "   Production (should be read-only):"
kubectl auth can-i create deployments --as=system:serviceaccount:production:qa-engineers --namespace=production
kubectl auth can-i get pods --as=system:serviceaccount:production:qa-engineers --namespace=production

echo ""
echo "🛠️  DevOps permissions:"
echo "   Should have cluster admin access:"
kubectl auth can-i "*" "*" --as=system:serviceaccount:production:devops

echo ""
echo "🔒 Security team permissions:"
echo "   Should have read access everywhere:"
kubectl auth can-i get secrets --as=system:serviceaccount:production:security --namespace=production
kubectl auth can-i create secrets --as=system:serviceaccount:production:security --namespace=production

echo ""
echo "👀 Read-only user permissions:"
echo "   Should only be able to read:"
kubectl auth can-i get pods --as=system:serviceaccount:development:readonly-users --namespace=development
kubectl auth can-i create pods --as=system:serviceaccount:development:readonly-users --namespace=development

echo ""
echo "✅ Team-based RBAC system is fully configured!"
echo ""
echo "📋 Summary of what was created:"
echo "   • 3 namespaces (development, staging, production)"
echo "   • 5 teams with service accounts in each namespace"
echo "   • Graduated permissions: full dev access → limited staging → read-only production"
echo "   • Special roles for DevOps (admin) and Security (audit)"
echo ""
echo "🔧 Next steps:"
echo "   1. Create actual user certificates and bind them to these service accounts"
echo "   2. Set up monitoring for RBAC denials"
echo "   3. Regular permission audits"
echo "   4. Document emergency access procedures"
echo ""
echo "🧹 Cleanup all resources: kubectl delete namespaces development staging production"
```

## Understanding RBAC in Real-World Context

RBAC isn't just about technical permissions - it's about implementing your organization's security policies in code. Here are some key principles to remember:

**Principle of Least Privilege**: Every service account should have the minimum permissions needed to function. It's better to start restrictive and add permissions as needed than to start permissive and try to remove permissions later.

**Defense in Depth**: RBAC is one layer of security. Combine it with network policies, pod security policies, admission controllers, and proper secret management for comprehensive protection.

**Regular Auditing**: Permissions tend to accumulate over time. Regularly review and clean up unused service accounts and overly broad permissions.

**Testing is Critical**: Always test your RBAC configurations before deploying to production. A single misconfigured permission can either block legitimate access or create security vulnerabilities.

This comprehensive RBAC system provides a foundation for secure, scalable Kubernetes operations while maintaining the flexibility teams need to be productive.