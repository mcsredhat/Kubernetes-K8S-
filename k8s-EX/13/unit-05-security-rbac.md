# Unit 5: Security and RBAC

## Learning Objectives
By the end of this unit, you will:
- Understand Kubernetes authentication and authorization fundamentals
- Implement Role-Based Access Control (RBAC) for namespace security
- Design service account strategies for application security
- Configure Pod Security Standards and security contexts
- Troubleshoot common security and permission issues

## Pre-Unit Security Mindset
Before diving into technical implementation, consider these security scenarios:
1. If you managed access to a corporate building, how would you balance security with usability?
2. What's the difference between "who you are" (authentication) and "what you can do" (authorization)?
3. How would you ensure that a contractor only accesses the specific offices they need?

## Part 1: Understanding Kubernetes Security Model

### Discovery Exercise: Current Security Posture Assessment

Let's start by understanding your current cluster's security configuration:

**Step 1: Examine Your Current Access**
```bash
# What can YOU currently do?
kubectl auth can-i --list

# What can you do in specific namespaces?
kubectl auth can-i --list --namespace=kube-system
kubectl auth can-i --list --namespace=default

# Who are you, according to Kubernetes?
kubectl config view --minify
```

**Investigation Questions:**
1. What permissions do you currently have?
2. Are there namespaces where your permissions differ?
3. What authentication method is your cluster using?

**Step 2: Explore Existing RBAC**
```bash
# See what roles exist
kubectl get roles --all-namespaces
kubectl get clusterroles | head -20

# Examine some built-in roles
kubectl describe clusterrole view
kubectl describe clusterrole edit
kubectl describe clusterrole admin
```

**Analysis Questions:**
1. What's the difference between `view`, `edit`, and `admin` roles?
2. Which roles are namespace-scoped vs cluster-scoped?
3. What patterns do you notice in the permission structure?

### Discovery Exercise: The Permission Problem

**Scenario Setup:**
Imagine you're setting up access for these personas:
- **Developer:** Needs to deploy and debug applications in their team's namespace
- **DevOps Engineer:** Needs to manage resources across multiple namespaces  
- **Security Auditor:** Needs read-only access to review configurations
- **Application Service Account:** Needs minimal permissions to function

**Design Challenge:**
Before looking at implementation, consider:
1. What specific permissions would each persona need?
2. How would you group similar permissions together?
3. What's the principle of least privilege in this context?

## Part 2: Implementing RBAC for Users

### Mini-Project 1: Developer Access Control

**Step 1: Create a Development Namespace with Security**
```yaml
# secure-dev-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: secure-development
  labels:
    security-level: development
    team: backend
---
# Role for developers in this namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: secure-development
  name: developer
rules:
- apiGroups: [""] # "" indicates the core API group
  resources: ["pods", "services", "configmaps", "secrets"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["pods/log", "pods/exec"]
  verbs: ["get", "create"]
```

**Step 2: Create a Test User (Simulated)**
```bash
# In real environments, users come from external systems (OIDC, certificates, etc.)
# For testing, we'll create a service account to represent a user
kubectl create serviceaccount developer-alice -n secure-development

# Bind the role to our test user
kubectl create rolebinding alice-developer \
  --role=developer \
  --serviceaccount=secure-development:developer-alice \
  --namespace=secure-development
```

**Step 3: Test the Permissions**
```bash
# Test what alice can do
kubectl auth can-i --list --as=system:serviceaccount:secure-development:developer-alice -n secure-development

# Test specific actions
kubectl auth can-i create pods --as=system:serviceaccount:secure-development:developer-alice -n secure-development
kubectl auth can-i delete nodes --as=system:serviceaccount:secure-development:developer-alice
```

**Analysis Exercise:**
1. What can Alice do within her namespace?
2. What can't Alice do? Why these restrictions?
3. How would you modify the role if Alice needed to view (but not modify) other namespaces?

### Mini-Project 2: Multi-Namespace Access

**Challenge:** Create access for a DevOps engineer who manages multiple team namespaces.

**Step 1: Design the Access Pattern**
```yaml
# devops-access.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: devops-engineer
rules:
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list"]
# What other cluster-level permissions would a DevOps engineer need?
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: namespace-admin
  # This will be bound in multiple namespaces
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
```

**Step 2: Apply Access Across Multiple Namespaces**
```bash
# Create test namespaces
kubectl create namespace team-frontend
kubectl create namespace team-backend
kubectl create namespace team-data

# Create the DevOps service account
kubectl create serviceaccount devops-bob -n default

# Bind cluster role
kubectl create clusterrolebinding bob-devops-cluster \
  --clusterrole=devops-engineer \
  --serviceaccount=default:devops-bob

# Bind namespace admin role in each team namespace
for ns in team-frontend team-backend team-data; do
  kubectl create rolebinding bob-admin-${ns} \
    --role=namespace-admin \
    --serviceaccount=default:devops-bob \
    --namespace=${ns}
done
```

**Testing Exercise:**
```bash
# Test Bob's permissions
kubectl auth can-i get namespaces --as=system:serviceaccount:default:devops-bob
kubectl auth can-i create deployments --as=system:serviceaccount:default:devops-bob -n team-frontend
kubectl auth can-i delete namespaces --as=system:serviceaccount:default:devops-bob
```

**Design Questions:**
1. Why use both ClusterRole and Role for the DevOps engineer?
2. How would you handle a DevOps engineer who should only manage certain types of namespaces?
3. What's the security risk of giving someone admin access to multiple namespaces?

### Discovery Exercise: Permission Granularity

**Investigation Challenge:**
Let's explore how granular RBAC can be:

```yaml
# granular-role.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader-only
  namespace: secure-development
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get"]
# Can read pods and logs, but cannot exec into pods
```

```yaml
# specific-resource-role.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: specific-deployment-manager
  namespace: secure-development
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "update", "patch"]
  resourceNames: ["web-app", "api-server"]  # Only these specific deployments
```

**Experimentation:**
1. Create these roles and test their boundaries
2. What happens when you try to access resources not explicitly permitted?
3. How specific can you make permissions while remaining practical?

## Part 3: Service Account Security

### Discovery Exercise: Service Account Fundamentals

**Investigation Task:**
Every namespace gets a default service account. Let's explore what this means:

```bash
# Examine default service accounts
kubectl get serviceaccounts --all-namespaces | grep default

# Look at the default service account in detail
kubectl describe serviceaccount default -n secure-development

# What permissions does it have?
kubectl auth can-i --list --as=system:serviceaccount:secure-development:default -n secure-development
```

**Analysis Questions:**
1. What permissions does the default service account have?
2. Why might this be a security concern?
3. When should applications use custom service accounts?

### Mini-Project 3: Application Service Account Design

**Scenario:** You're deploying a web application that needs to:
- Read configuration from ConfigMaps
- Update its own status (for health checks)
- Access a specific secret for API keys
- But NOT access other applications' resources

**Step 1: Design Minimal Permissions**
```yaml
# app-service-account.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: web-app-sa
  namespace: secure-development
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: web-app-role
  namespace: secure-development
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list"]
  resourceNames: ["web-app-config"]  # Only specific ConfigMap
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get"]
  resourceNames: ["web-app-secrets"]
# What other minimal permissions might be needed?
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: web-app-binding
  namespace: secure-development
subjects:
- kind: ServiceAccount
  name: web-app-sa
  namespace: secure-development
roleRef:
  kind: Role
  name: web-app-role
  apiGroup: rbac.authorization.k8s.io
```

**Step 2: Deploy Application with Service Account**
```yaml
# web-app-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-web-app
  namespace: secure-development
spec:
  replicas: 2
  selector:
    matchLabels:
      app: secure-web-app
  template:
    metadata:
      labels:
        app: secure-web-app
    spec:
      serviceAccountName: web-app-sa  # Use custom service account
      containers:
      - name: app
        image: nginx
        # Application would use mounted service account token
```

**Step 3: Validation**
```bash
# Verify the application is using the correct service account
kubectl describe pod -l app=secure-web-app -n secure-development | grep "Service Account"

# Test the service account permissions
kubectl auth can-i get configmaps --as=system:serviceaccount:secure-development:web-app-sa -n secure-development
kubectl auth can-i get secrets --as=system:serviceaccount:secure-development:web-app-sa -n secure-development
kubectl auth can-i delete pods --as=system:serviceaccount:secure-development:web-app-sa -n secure-development
```

**Security Analysis:**
1. What attack scenarios does this service account design prevent?
2. How would you handle an application that needs permissions in multiple namespaces?
3. What's the trade-off between security and operational simplicity?

## Part 4: Pod Security Standards

### Discovery Exercise: Container Security Context

**Investigation Challenge:**
Let's explore how containers run by default and what security implications this has:

```yaml
# security-test-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: security-investigation
  namespace: secure-development
spec:
  containers:
  - name: investigator
    image: busybox
    command: ["sleep", "3600"]
```

```bash
# Deploy and investigate
kubectl apply -f security-test-pod.yaml

# Check what user the container runs as
kubectl exec security-investigation -n secure-development -- id

# Check what capabilities it has
kubectl exec security-investigation -n secure-development -- cat /proc/1/status | grep Cap

# Check filesystem permissions
kubectl exec security-investigation -n secure-development -- ls -la /
```

**Security Questions:**
1. What user ID is the container running as?
2. What capabilities does it have by default?
3. What security risks does this default configuration present?

### Mini-Project 4: Implementing Pod Security

**Step 1: Create Security Context**
```yaml
# secure-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
  namespace: secure-development
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
  containers:
  - name: secure-app
    image: nginx
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
        add:
        - NET_BIND_SERVICE  # Only if needed for port < 1024
    volumeMounts:
    - name: tmp-volume
      mountPath: /tmp
    - name: cache-volume
      mountPath: /var/cache/nginx
  volumes:
  - name: tmp-volume
    emptyDir: {}
  - name: cache-volume
    emptyDir: {}
```

**Step 2: Test Security Restrictions**
```bash
# Try to deploy the secure pod
kubectl apply -f secure-pod.yaml

# If it fails, what needs to be fixed?
kubectl describe pod secure-pod -n secure-development

# Compare with the unrestricted pod
kubectl exec security-investigation -n secure-development -- id
kubectl exec secure-pod -n secure-development -- id  # If it's running
```

**Step 3: Pod Security Standards**
```yaml
# pod-security-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: security-enforced
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

**Testing Exercise:**
1. Try deploying various pod configurations to the security-enforced namespace
2. What configurations are rejected?
3. How do the warn, audit, and enforce modes differ?

### Discovery Exercise: Security Context Strategies

**Challenge:** Design security contexts for different application types:

**Application Type A: Static Web Server**
```yaml
# What security context would be appropriate for a static file server?
```

**Application Type B: Database**
```yaml
# What security context considerations are important for a database?
```

**Application Type C: Batch Processing Job**
```yaml
# What security context would work for a data processing job?
```

**Design Considerations:**
1. Which applications can run with read-only root filesystems?
2. When might you need specific Linux capabilities?
3. How do security requirements differ between dev and prod environments?

## Part 5: Advanced Security Patterns

### Discovery Exercise: Network-Level Security

**Investigation Challenge:**
Security isn't just about RBAC - network policies provide another layer of protection:

```yaml
# basic-network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: secure-development
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
# This blocks all traffic by default
```

```yaml
# selective-access-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: web-app-access
  namespace: secure-development
spec:
  podSelector:
    matchLabels:
      app: secure-web-app
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: frontend-namespace
    ports:
    - protocol: TCP
      port: 80
```

**Testing Network Security:**
```bash
# Deploy the policies and test connectivity
kubectl apply -f basic-network-policy.yaml

# Try to access services before and after applying policies
kubectl run test-pod --image=busybox --rm -it -- wget -qO- http://secure-web-app-service
```

**Integration Questions:**
1. How do network policies complement RBAC?
2. When would you use one vs the other?
3. How do they work together for defense in depth?

### Mini-Project 5: Comprehensive Security Implementation

**Real-World Scenario:**
Design complete security for a three-tier application:
- **Frontend:** Web servers that serve static content
- **Backend:** API servers that process business logic  
- **Database:** Data storage with sensitive information

**Security Requirements:**
- Frontend can only be accessed from internet
- Backend can only be accessed from frontend
- Database can only be accessed from backend
- Each tier runs with minimal required permissions
- No component can access Kubernetes API unless necessary

**Implementation Challenge:**

**Step 1: Namespace and RBAC Design**
```yaml
# three-tier-security.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: three-tier-app
  labels:
    pod-security.kubernetes.io/enforce: restricted
---
# Frontend service account
apiVersion: v1
kind: ServiceAccount
metadata:
  name: frontend-sa
  namespace: three-tier-app
---
# Backend service account
apiVersion: v1
kind: ServiceAccount  
metadata:
  name: backend-sa
  namespace: three-tier-app
---
# Database service account
apiVersion: v1
kind: ServiceAccount
metadata:
  name: database-sa
  namespace: three-tier-app
---
# What roles and bindings would each service account need?
```

**Step 2: Security Contexts**
```yaml
# frontend-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: three-tier-app
spec:
  template:
    spec:
      serviceAccountName: frontend-sa
      securityContext:
        # Design appropriate security context for frontend
      containers:
      - name: frontend
        securityContext:
          # Container-level security context
```

**Step 3: Network Policies**
```yaml
# network-policies.yaml
# Design network policies that enforce the communication rules
```

**Validation Framework:**
Create tests that verify:
1. Each component can only access what it should
2. Security policies prevent unauthorized access
3. The application functions correctly within security constraints

## Part 6: Troubleshooting Security Issues

### Discovery Exercise: Common Security Problems

**Scenario A: Permission Denied Errors**
```bash
# Simulate a common problem
kubectl create deployment debug-app --image=nginx -n secure-development
kubectl patch deployment debug-app -n secure-development -p '{"spec":{"template":{"spec":{"serviceAccountName":"restricted-sa"}}}}'
```

**Troubleshooting Process:**
1. What error symptoms would you see?
2. What commands help diagnose RBAC issues?
3. How do you differentiate between RBAC and other permission problems?

**Diagnostic Commands:**
```bash
# Check what the service account can do
kubectl auth can-i --list --as=system:serviceaccount:secure-development:restricted-sa

# Check role bindings
kubectl get rolebindings -n secure-development -o wide

# Examine events for clues
kubectl get events -n secure-development --sort-by='.lastTimestamp'
```

**Scenario B: Pod Security Policy Violations**
```bash
# Deploy a pod that violates security policies
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: privileged-pod
  namespace: security-enforced
spec:
  containers:
  - name: app
    image: nginx
    securityContext:
      privileged: true
EOF
```

**Analysis Questions:**
1. What error message indicates a security policy violation?
2. How do you determine which security requirement is being violated?
3. What's the difference between a warning and an enforcement failure?

### Mini-Project 6: Security Monitoring and Auditing

**Challenge:** Create monitoring for security-related events and violations.

**Implementation:**
```bash
#!/bin/bash
# security-monitor.sh

echo "=== RBAC Violations ==="
kubectl get events --all-namespaces --field-selector reason=Forbidden

echo "=== Pod Security Violations ==="
kubectl get events --all-namespaces --field-selector reason=FailedCreate | grep -i security

echo "=== Service Account Usage ==="
kubectl get pods --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,SERVICE_ACCOUNT:.spec.serviceAccountName"

# Your additional security monitoring logic
```

**Advanced Monitoring Ideas:**
1. Track which service accounts are actually being used
2. Identify pods running as root
3. Monitor for privilege escalation attempts
4. Audit changes to RBAC resources

## Part 7: Real-World Application

### Comprehensive Scenario: Enterprise Security Implementation

**Your Challenge:**
Design and implement security for an enterprise Kubernetes environment:

**Organizational Context:**
- **5 Development Teams:** Each with dev/staging/prod namespaces
- **Platform Team:** Manages cluster infrastructure and shared services
- **Security Team:** Needs audit access and policy enforcement
- **External Contractors:** Need limited access to specific projects

**Compliance Requirements:**
- Principle of least privilege must be enforced
- All actions must be auditable
- Sensitive workloads must be isolated
- Development environments should not impact production

**Design Phase:**
1. How will you structure namespaces for proper isolation?
2. What RBAC hierarchy will support both security and usability?
3. How will you handle shared resources and cross-team dependencies?
4. What automation will ensure consistent security policy application?

**Implementation Challenge:**

**Step 1: Namespace Security Template**
```yaml
# Create a template for secure namespace creation
```

**Step 2: Role Hierarchy Design**
```yaml
# Design roles that can be composed for different access levels
```

**Step 3: Automated Security Policy Application**
```bash
#!/bin/bash
# apply-security-policies.sh
# Script to consistently apply security policies to new namespaces
```

**Step 4: Audit and Monitoring System**
```yaml
# Tools and processes for ongoing security monitoring
```

### Advanced Challenge: Multi-Cluster Security

**Scenario Extension:**
Your organization expands to multiple clusters:
- Production cluster (high security)
- Staging cluster (moderate security)  
- Development cluster (flexible for experimentation)

**Additional Considerations:**
1. How do security policies differ across cluster types?
2. How do you manage consistent identity across clusters?
3. What additional network security is needed between clusters?

## Unit Assessment

### Practical Security Implementation

**Assessment Challenge:**
Design and implement a complete security solution:

1. **Planning Phase:**
   - Design RBAC strategy for a multi-team environment
   - Plan service account architecture for applications
   - Design pod security policies for different workload types

2. **Implementation Phase:**
   - Create roles, bindings, and service accounts
   - Deploy applications with appropriate security contexts
   - Implement network policies for traffic control

3. **Validation Phase:**
   - Prove that access controls work as designed
   - Demonstrate that security policies prevent violations
   - Show monitoring and auditing capabilities

### Security Incident Response

**Scenario-Based Assessment:**
1. **Compromise Response:** A service account token has been compromised. Walk through your response process.

2. **Privilege Escalation:** Someone has gained unauthorized admin access to a production namespace. How do you investigate and remediate?

3. **Policy Violation:** Multiple pods are being deployed that violate security policies. How do you identify the source and prevent recurrence?

### Knowledge Integration Questions

1. **Balance Question:** How do you balance security requirements with developer productivity?

2. **Scale Question:** How does your security model change as you scale from 10 to 1000 namespaces?

3. **Evolution Question:** How do you safely migrate from a permissive to a restrictive security model?

### Preparation for Unit 6

**Preview Questions:**
1. How does network security complement the RBAC and pod security you've implemented?
2. What happens when applications in different namespaces need to communicate securely?
3. How would you control network traffic both within and between namespaces?

**Coming Next:** In Unit 6, we'll explore Network Isolation, learning to implement network policies, design secure communication patterns, and create network-level security boundaries between namespaces.

## Quick Reference

### RBAC Commands
```bash
# Permission checking
kubectl auth can-i <verb> <resource> --as=<user> -n <namespace>
kubectl auth can-i --list --as=<user> -n <namespace>

# Role management
kubectl create role <name> --verb=<verbs> --resource=<resources> -n <namespace>
kubectl create rolebinding <name> --role=<role> --user=<user> -n <namespace>
kubectl create clusterrole <name> --verb=<verbs> --resource=<resources>
kubectl create clusterrolebinding <name> --clusterrole=<role> --user=<user>

# Service accounts
kubectl create serviceaccount <name> -n <namespace>
kubectl get serviceaccounts -A
```

### Security Context Examples
```yaml
# Pod-level security context
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000

# Container-level security context
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop: ["ALL"]
```

### Pod Security Standards
```yaml
# Namespace labels for Pod Security Standards
metadata:
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted  
    pod-security.kubernetes.io/warn: restricted
```

### Troubleshooting
```bash
# RBAC troubleshooting
kubectl describe rolebinding -n <namespace>
kubectl describe clusterrolebinding | grep <user>
kubectl get events --field-selector reason=Forbidden

# Security context troubleshooting
kubectl describe pod <pod> | grep -A10 "Security Context"
kubectl get events --field-selector reason=FailedCreate
```