# Unit 2: Advanced Role Patterns and Cross-Namespace Permissions

## Learning Objectives
By the end of this unit, you will:
- Design complex permission models using advanced role patterns
- Understand when and how to use ClusterRoles vs Roles
- Implement cross-namespace access patterns safely
- Create reusable permission templates

## Reflection: Building on Unit 1

Before diving into advanced patterns, let's reflect on what we learned:

1. **What was the most challenging part of creating your first RBAC setup in Unit 1?**
2. **Think about your monitoring service account project - what additional permissions might a real monitoring system need?**
3. **Can you predict what might happen if we tried to use a Role from one namespace in a different namespace?**

## Advanced Role Design Patterns

### Pattern 1: The Graduated Permissions Model

In real organizations, different environments need different security levels. Let's explore how to implement this:

```yaml
# dev-permissions.yaml - Permissive for development
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: development
  name: developer-role
rules:
- apiGroups: ["", "apps", "extensions"]
  resources: ["*"]  # All resources
  verbs: ["*"]      # All actions
- apiGroups: [""]
  resources: ["pods/exec", "pods/log"]
  verbs: ["create", "get", "list"]
---
# staging-permissions.yaml - More restrictive
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: staging
  name: developer-role
rules:
- apiGroups: ["", "apps"]
  resources: ["pods", "services", "deployments", "configmaps"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get", "list"]
# Note: No delete permissions and no exec access
---
# production-permissions.yaml - Read-only
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: developer-role
rules:
- apiGroups: ["", "apps"]
  resources: ["pods", "services", "deployments", "configmaps"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get", "list"]
```

**Discussion Question**: Why might we want different permission levels across environments? What are the trade-offs between security and developer productivity?

### Pattern 2: Resource-Specific Permissions

Sometimes you need granular control over specific resources:

```bash
# Create a role that can only manage a specific deployment
kubectl create role app-deployer \
  --verb=get,list,watch,update,patch \
  --resource=deployments \
  --resource-name=my-critical-app

# Create a role that can access specific secrets
kubectl create role secret-reader \
  --verb=get \
  --resource=secrets \
  --resource-name=database-credentials,api-keys
```

## Hands-On Lab 2: ClusterRoles vs Roles Deep Dive

### Experiment 1: Understanding the Scope Difference

```bash
# Setup
kubectl create namespace scope-test-1
kubectl create namespace scope-test-2
kubectl create serviceaccount tester --namespace scope-test-1

# Create a namespace-scoped Role
kubectl create role namespace-reader \
  --verb=get,list \
  --resource=pods \
  --namespace=scope-test-1

# Create a cluster-scoped Role
kubectl create clusterrole cluster-reader \
  --verb=get,list \
  --resource=pods
```

**Your Task**: Before running the commands below, predict what the outcomes will be:

```bash
# Test 1: Role with RoleBinding (same namespace)
kubectl create rolebinding test1 \
  --role=namespace-reader \
  --serviceaccount=scope-test-1:tester \
  --namespace=scope-test-1

kubectl auth can-i get pods \
  --as=system:serviceaccount:scope-test-1:tester \
  --namespace=scope-test-1

# Your prediction: ____________

# Test 2: Role with RoleBinding (different namespace)
kubectl auth can-i get pods \
  --as=system:serviceaccount:scope-test-1:tester \
  --namespace=scope-test-2

# Your prediction: ____________
```

### Experiment 2: ClusterRole Flexibility

```bash
# Test 3: ClusterRole with ClusterRoleBinding
kubectl create clusterrolebinding test3 \
  --clusterrole=cluster-reader \
  --serviceaccount=scope-test-1:tester

kubectl auth can-i get pods \
  --as=system:serviceaccount:scope-test-1:tester \
  --namespace=scope-test-1

kubectl auth can-i get pods \
  --as=system:serviceaccount:scope-test-1:tester \
  --namespace=scope-test-2

# Your predictions: ____________, ____________

# Clean up the cluster binding for next test
kubectl delete clusterrolebinding test3

# Test 4: ClusterRole with RoleBinding (namespace-scoped usage)
kubectl create rolebinding test4 \
  --clusterrole=cluster-reader \
  --serviceaccount=scope-test-1:tester \
  --namespace=scope-test-1

kubectl auth can-i get pods \
  --as=system:serviceaccount:scope-test-1:tester \
  --namespace=scope-test-1

kubectl auth can-i get pods \
  --as=system:serviceaccount:scope-test-1:tester \
  --namespace=scope-test-2

# Your predictions: ____________, ____________
```

**Reflection**: What did you discover about how ClusterRoles can be used? When might you want to use a ClusterRole with a RoleBinding instead of just creating a Role?

## Mini-Project 2: Multi-Tenant Application Platform

**Scenario**: You're building a platform where multiple development teams share a Kubernetes cluster. Each team should:
- Have full control over their own namespace
- Be able to view (but not modify) shared resources in a "common" namespace
- Have no access to other teams' namespaces
- Have read-only access to monitoring data cluster-wide

### Implementation Challenge

Create RBAC policies for this scenario. Here's your starting structure:

```bash
# Setup the multi-tenant environment
kubectl create namespace team-alpha
kubectl create namespace team-beta  
kubectl create namespace common-resources
kubectl create namespace monitoring

# Create team service accounts
kubectl create serviceaccount alpha-dev --namespace team-alpha
kubectl create serviceaccount beta-dev --namespace team-beta
```

**Your Design Task**: 

1. **What types of roles will you need?** (Roles vs ClusterRoles)
2. **How will you implement the "view shared resources" requirement?**
3. **What's the most secure way to provide cluster-wide monitoring access?**

Try implementing your solution, then test it thoroughly. Here are some test cases to verify:

```bash
# Team Alpha should be able to:
kubectl auth can-i create deployments --as=system:serviceaccount:team-alpha:alpha-dev --namespace=team-alpha
kubectl auth can-i get configmaps --as=system:serviceaccount:team-alpha:alpha-dev --namespace=common-resources

# Team Alpha should NOT be able to:
kubectl auth can-i get pods --as=system:serviceaccount:team-alpha:alpha-dev --namespace=team-beta
kubectl auth can-i create secrets --as=system:serviceaccount:team-alpha:alpha-dev --namespace=common-resources
```

## Advanced Permission Debugging

When RBAC doesn't work as expected, systematic debugging is crucial:

### Debug Strategy 1: Permission Tracing

```bash
# Start with the basics - does the service account exist?
kubectl get sa my-app --namespace my-namespace

# Check what roles are bound to this service account
kubectl get rolebindings,clusterrolebindings --all-namespaces -o wide | grep my-app

# Examine the specific role permissions
kubectl describe role my-role --namespace my-namespace
kubectl describe clusterrole my-cluster-role

# Test specific permissions systematically
kubectl auth can-i get pods --as=system:serviceaccount:my-namespace:my-app --namespace=my-namespace
kubectl auth can-i list services --as=system:serviceaccount:my-namespace:my-app --namespace=my-namespace
```

### Debug Strategy 2: The RBAC Audit Script

Create this helpful debugging script:

```bash
#!/bin/bash
# save as rbac-debug.sh
# Usage: ./rbac-debug.sh <serviceaccount> <namespace>

SA_NAME=$1
NAMESPACE=$2

if [[ -z "$SA_NAME" || -z "$NAMESPACE" ]]; then
    echo "Usage: $0 <serviceaccount> <namespace>"
    exit 1
fi

echo "🔍 RBAC Debug Report for $SA_NAME in $NAMESPACE"
echo "=================================================="

# Check if service account exists
echo "1. Service Account Status:"
if kubectl get sa $SA_NAME -n $NAMESPACE &>/dev/null; then
    echo "   ✅ Service account exists"
    kubectl get sa $SA_NAME -n $NAMESPACE
else
    echo "   ❌ Service account does not exist"
    exit 1
fi

echo ""
echo "2. Role Bindings (Namespace-scoped):"
ROLE_BINDINGS=$(kubectl get rolebindings -n $NAMESPACE -o json | jq -r ".items[] | select(.subjects[]? | select(.kind==\"ServiceAccount\" and .name==\"$SA_NAME\" and .namespace==\"$NAMESPACE\")) | .metadata.name")

if [[ -z "$ROLE_BINDINGS" ]]; then
    echo "   ⚠️  No namespace role bindings found"
else
    for binding in $ROLE_BINDINGS; do
        echo "   📋 RoleBinding: $binding"
        kubectl describe rolebinding $binding -n $NAMESPACE | grep -E "(Role|Subjects)" -A2
    done
fi

echo ""
echo "3. Cluster Role Bindings:"
CLUSTER_BINDINGS=$(kubectl get clusterrolebindings -o json | jq -r ".items[] | select(.subjects[]? | select(.kind==\"ServiceAccount\" and .name==\"$SA_NAME\" and .namespace==\"$NAMESPACE\")) | .metadata.name")

if [[ -z "$CLUSTER_BINDINGS" ]]; then
    echo "   ⚠️  No cluster role bindings found"
else
    for binding in $CLUSTER_BINDINGS; do
        echo "   🌐 ClusterRoleBinding: $binding"
        kubectl describe clusterrolebinding $binding | grep -E "(Role|Subjects)" -A2
    done
fi

echo ""
echo "4. Quick Permission Test:"
echo "   Can get pods: $(kubectl auth can-i get pods --as=system:serviceaccount:$NAMESPACE:$SA_NAME -n $NAMESPACE)"
echo "   Can create deployments: $(kubectl auth can-i create deployments --as=system:serviceaccount:$NAMESPACE:$SA_NAME -n $NAMESPACE)"
echo "   Can list services: $(kubectl auth can-i list services --as=system:serviceaccount:$NAMESPACE:$SA_NAME -n $NAMESPACE)"
echo "   Can access secrets: $(kubectl auth can-i get secrets --as=system:serviceaccount:$NAMESPACE:$SA_NAME -n $NAMESPACE)"
```

## Real-World Scenarios Discussion

Let's explore some challenging real-world scenarios:

### Scenario 1: The Shared Service Account
**Question**: A development team wants to share a single service account across multiple applications in the same namespace. What are the pros and cons of this approach?

**Your Analysis**:
- Security implications: ________________
- Operational complexity: ________________
- Recommendation: ________________

### Scenario 2: The Cross-Namespace API Call
**Question**: Your application in namespace "frontend" needs to call a service in namespace "backend". What RBAC considerations are involved?

**Your Approach**:
1. What resources does the frontend need access to? ________________
2. How would you implement the minimum necessary permissions? ________________
3. What alternatives to RBAC might you consider? ________________

## Challenging Practice Exercise

Design and implement RBAC for this complex scenario:

**The E-commerce Platform Challenge**
- **Frontend team**: Deploys web apps, needs to read backend service endpoints
- **Backend team**: Manages APIs and databases, needs to read infrastructure configs
- **DevOps team**: Manages infrastructure, needs cluster-wide access
- **Security team**: Needs to audit all permissions and access secrets for compliance
- **QA team**: Needs to test in staging, view logs across all namespaces

Requirements:
1. Each team works in their own primary namespace
2. Some teams need limited cross-namespace access
3. Different permission levels for dev/staging/production
4. Security team needs audit capabilities without breaking things

**Challenge Questions**:
1. How many different roles will you need?
2. Which should be Roles vs ClusterRoles?
3. How will you handle the cross-namespace requirements?
4. What's your strategy for maintaining these permissions over time?

## Key Insights from Unit 2

1. **ClusterRoles are flexible** - they can be used with both ClusterRoleBindings (cluster-wide) and RoleBindings (namespace-scoped)
2. **Cross-namespace access requires careful planning** - consider security implications
3. **Debugging RBAC requires systematic testing** - create tools and scripts to help
4. **Real-world scenarios are complex** - multiple teams, environments, and security requirements

## Preparation for Unit 3

In the next unit, we'll tackle:
- Service account tokens and authentication mechanisms
- Advanced security patterns like impersonation
- Integration with external identity providers
- Automated RBAC management and GitOps patterns

**Pre-Unit 3 Questions**:
1. How do you think applications actually use service accounts to authenticate with the Kubernetes API?
2. What challenges might arise when managing RBAC policies for hundreds of applications?
3. Have you worked with any external identity systems (LDAP, Active Directory, OAuth)? How might these integrate with Kubernetes?

## Cleanup
```bash
kubectl delete namespace scope-test-1 scope-test-2 team-alpha team-beta common-resources monitoring
```