# Unit 1: RBAC Foundations and Core Concepts

## Learning Objectives
By the end of this unit, you will:
- Understand the four core components of Kubernetes RBAC
- Create and manage Service Accounts
- Test permissions using `kubectl auth can-i`
- Implement basic security principles

## Pre-Lab Questions
Before we dive in, let's establish your current understanding:

1. **What do you think "least privilege" means in security contexts?**
2. **Can you think of a real-world analogy for role-based access control?**
3. **What might happen if every application had full admin access to a Kubernetes cluster?**

## Core Concepts Overview

### The RBAC Security Model
Think of RBAC like a university access card system:
- **Service Accounts** = Student/Faculty ID cards
- **Roles** = Permission templates (Student, Professor, Janitor)
- **RoleBindings** = Assigning permissions to specific people
- **Resources** = What's being protected (classrooms, labs, offices)

### The Four Pillars Explained

#### 1. Service Accounts: Digital Identity Cards
```bash
# Every process needs an identity - who is making the request?
kubectl create serviceaccount my-app
kubectl create sa monitoring-service  # 'sa' is shorthand

# List existing service accounts
kubectl get serviceaccounts
kubectl get sa

# Every namespace gets a 'default' service account automatically
kubectl get sa default -o yaml
```

**Key Insight**: If you don't specify a service account, pods use the `default` service account in their namespace.

#### 2. Roles: Permission Templates
Roles define WHAT actions can be performed on WHICH resources.

```bash
# Create a role that can only READ pods
kubectl create role pod-reader \
  --verb=get,list,watch \
  --resource=pods

# Create a role that can manage deployments
kubectl create role deployment-manager \
  --verb=get,list,watch,create,update,patch,delete \
  --resource=deployments
```

**Verbs Explained**:
- `get` = Retrieve a specific resource by name
- `list` = See all resources of this type
- `watch` = Monitor for changes in real-time
- `create` = Make new resources
- `update/patch` = Modify existing resources
- `delete` = Remove resources

#### 3. RoleBindings: The Connection
RoleBindings connect WHO (service account) to WHAT (role).

```bash
# Give a service account specific permissions
kubectl create rolebinding my-app-binding \
  --role=pod-reader \
  --serviceaccount=default:my-app

# You can also bind to users and groups
kubectl create rolebinding user-binding \
  --role=pod-reader \
  --user=alice@company.com
```

#### 4. Resources: What's Being Protected
Resources are the Kubernetes objects being secured:
- Core resources: `pods`, `services`, `configmaps`, `secrets`
- App resources: `deployments`, `replicasets`, `daemonsets`
- Subresources: `pods/log`, `pods/exec`, `pods/status`

## Hands-On Lab 1: Your First RBAC Setup

### Step 1: Create the Foundation
```bash
# Create a dedicated namespace for our experiments
kubectl create namespace rbac-lab

# Create a service account for our application
kubectl create serviceaccount web-app --namespace rbac-lab

# Verify creation
kubectl get sa -n rbac-lab
```

### Step 2: Test Initial Permissions (Should Fail)
```bash
# Test what our service account can do (should be nothing)
kubectl auth can-i get pods \
  --as=system:serviceaccount:rbac-lab:web-app \
  --namespace=rbac-lab

# Expected output: no
```

**Reflection Question**: Why did this return "no"? What does this tell us about Kubernetes security defaults?

### Step 3: Create Basic Permissions
```bash
# Create a role that allows reading pods and services
kubectl create role web-app-reader \
  --verb=get,list,watch \
  --resource=pods,services \
  --namespace=rbac-lab

# Verify the role was created
kubectl describe role web-app-reader -n rbac-lab
```

### Step 4: Connect Identity to Permissions
```bash
# Create the binding
kubectl create rolebinding web-app-binding \
  --role=web-app-reader \
  --serviceaccount=rbac-lab:web-app \
  --namespace=rbac-lab

# Verify the binding
kubectl describe rolebinding web-app-binding -n rbac-lab
```

### Step 5: Test the New Permissions
```bash
# Now these should work
kubectl auth can-i get pods \
  --as=system:serviceaccount:rbac-lab:web-app \
  --namespace=rbac-lab

kubectl auth can-i list services \
  --as=system:serviceaccount:rbac-lab:web-app \
  --namespace=rbac-lab

# But this should still fail
kubectl auth can-i create pods \
  --as=system:serviceaccount:rbac-lab:web-app \
  --namespace=rbac-lab

kubectl auth can-i get pods \
  --as=system:serviceaccount:rbac-lab:web-app \
  --namespace=default
```

## Mini-Project 1: Build a Monitoring Service Account

**Scenario**: You need to create a service account for a monitoring system that can:
- Read pod information across all namespaces
- View service details
- Access pod logs for debugging
- NOT be able to modify anything

### Your Task:
1. Create a service account called `monitoring-sa`
2. Design appropriate permissions (hint: you'll need a ClusterRole)
3. Test your implementation thoroughly
4. Document what permissions you granted and why

### Solution Template:
```bash
# Step 1: Create the service account
kubectl create serviceaccount ____________ --namespace ____________

# Step 2: Create permissions (fill in the blanks)
kubectl create clusterrole ____________ \
  --verb=____________ \
  --resource=____________

# Step 3: Create the binding
kubectl create clusterrolebinding ____________ \
  --clusterrole=____________ \
  --serviceaccount=____________

# Step 4: Test permissions
# Add your test commands here
```

## Understanding Through Questions

1. **Why do you think Kubernetes has both Roles and ClusterRoles?**
   - When would you use each one?
   - What are the security implications?

2. **What happens if you create a RoleBinding that references a ClusterRole?**
   - Try it and observe the behavior
   - Why might this be useful?

3. **Security Principle Check**: 
   - Is it better to start with broad permissions and remove them, or start narrow and add them?
   - Why do you think this is?

## Common Mistakes and Debugging

### Mistake 1: Forgetting Namespace Context
```bash
# This won't work if your role is in a different namespace
kubectl create rolebinding wrong-binding \
  --role=pod-reader \
  --serviceaccount=default:my-app \
  --namespace=wrong-namespace
```

### Mistake 2: Incorrect Service Account Format
```bash
# Wrong - missing namespace
--serviceaccount=my-app

# Right - includes namespace
--serviceaccount=my-namespace:my-app
```

### Mistake 3: Not Testing Permissions
Always use `kubectl auth can-i` to verify your RBAC configuration works as expected.

## Key Takeaways

1. **Default Deny**: Kubernetes RBAC follows a "default deny" model - nothing is allowed unless explicitly granted
2. **Namespace Boundaries**: Roles work within namespaces, ClusterRoles work cluster-wide
3. **Testing is Essential**: Always test your RBAC policies before deploying applications
4. **Least Privilege**: Start with minimal permissions and add only what's needed

## Next Steps

In Unit 2, we'll explore:
- Advanced role patterns
- Cross-namespace permissions
- Service account tokens and authentication
- Debugging permission issues

## Cleanup
```bash
kubectl delete namespace rbac-lab
```

## Self-Assessment Questions

1. Can you explain the difference between a Role and a ClusterRole to a colleague?
2. What would happen if you deleted a RoleBinding but left the Role and ServiceAccount?
3. How would you grant a service account the ability to read secrets in just the "production" namespace?