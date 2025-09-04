# Unit 3: Service Account Tokens and Authentication Deep Dive

## Learning Objectives
By the end of this unit, you will:
- Understand how service account tokens work under the hood
- Implement custom authentication patterns
- Work with service account token secrets and mounting
- Design secure token rotation strategies
- Troubleshoot authentication issues in production

## Exploring Your Current Understanding

Before we dive into the technical details, let's explore what you already know:

1. **In Unit 1, when you created a service account, how do you think the Kubernetes API actually verified that requests came from that service account?**

2. **Consider this scenario**: You're running a pod with a service account, and the pod needs to make API calls to create other resources. What do you think needs to happen "behind the scenes" for this to work?

3. **Security question**: If service accounts are like digital ID cards, what prevents someone from "copying" or "stealing" these credentials?

## The Authentication Journey: From Request to Response

Let's trace what happens when your application makes a Kubernetes API call:

### Discovery Exercise: Examining Service Account Secrets

```bash
# Create a service account and examine what gets created
kubectl create namespace auth-exploration
kubectl create serviceaccount explorer --namespace auth-exploration

# Now, let's investigate what was actually created
kubectl describe sa explorer -n auth-exploration

# Look at the service account in YAML format
kubectl get sa explorer -n auth-exploration -o yaml

# What do you notice in the output? What fields seem related to authentication?
```

**Reflection Questions**:
- What did you observe in the `describe` output?
- Are there any references to secrets or tokens?
- How do you think these pieces work together?

### Understanding Token Lifecycle (Kubernetes 1.24+)

Modern Kubernetes has evolved its token system. Let's explore:

```bash
# Create a pod that will use our service account
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: token-explorer
  namespace: auth-exploration
spec:
  serviceAccountName: explorer
  containers:
  - name: explorer
    image: nicolaka/netshoot
    command: ["sleep", "3600"]
EOF

# Now let's examine how tokens are provided to the pod
kubectl exec -it token-explorer -n auth-exploration -- /bin/bash

# Inside the pod, explore the mounted service account
ls -la /var/run/secrets/kubernetes.io/serviceaccount/
cat /var/run/secrets/kubernetes.io/serviceaccount/token
cat /var/run/secrets/kubernetes.io/serviceaccount/namespace
cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt

# Exit the pod
exit
```

**Guided Exploration Questions**:
1. What files did you find in the service account directory?
2. What do you think each file is used for?
3. Try to decode the token (hint: it's a JWT). What information does it contain?

### Hands-On Lab 3: Token Authentication Workshop

Let's build our understanding by creating different token scenarios:

#### Scenario 1: Default Token Behavior

```bash
# Create a simple pod and test its API access
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: api-tester-default
  namespace: auth-exploration
spec:
  # Using default service account (no serviceAccountName specified)
  containers:
  - name: tester
    image: bitnami/kubectl:latest
    command: ["sleep", "3600"]
EOF

# Test what the default service account can do
kubectl exec -it api-tester-default -n auth-exploration -- kubectl get pods

# What happened? Why do you think you got this result?
```

#### Scenario 2: Custom Service Account with Permissions

```bash
# Create a role and binding for our explorer service account
kubectl create role pod-manager \
  --verb=get,list,create,delete \
  --resource=pods \
  --namespace=auth-exploration

kubectl create rolebinding explorer-binding \
  --role=pod-manager \
  --serviceaccount=auth-exploration:explorer \
  --namespace=auth-exploration

# Create a pod using our custom service account
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: api-tester-custom
  namespace: auth-exploration
spec:
  serviceAccountName: explorer
  containers:
  - name: tester
    image: bitnami/kubectl:latest
    command: ["sleep", "3600"]
EOF

# Test the custom service account's capabilities
kubectl exec -it api-tester-custom -n auth-exploration -- kubectl get pods
kubectl exec -it api-tester-custom -n auth-exploration -- kubectl get services

# Analyze the results - what worked and what didn't? Why?
```

**Reflection Point**: Compare the results from the two scenarios. What does this tell you about how service account permissions work?

### Advanced Token Patterns

#### Pattern 1: Token Volume Projection

Sometimes you need more control over token properties:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: custom-token-pod
  namespace: auth-exploration
spec:
  serviceAccountName: explorer
  containers:
  - name: app
    image: nicolaka/netshoot
    command: ["sleep", "3600"]
    volumeMounts:
    - name: custom-token
      mountPath: /var/run/secrets/tokens
      readOnly: true
  volumes:
  - name: custom-token
    projected:
      sources:
      - serviceAccountToken:
          path: custom-token
          expirationSeconds: 3600  # 1 hour
          audience: custom-audience
EOF

# Examine the custom token
kubectl exec -it custom-token-pod -n auth-exploration -- cat /var/run/secrets/tokens/custom-token

# Compare it to the standard token
kubectl exec -it custom-token-pod -n auth-exploration -- cat /var/run/secrets/kubernetes.io/serviceaccount/token
```

**Investigation Question**: What differences do you notice between the custom token and the standard token? Why might you want to customize token properties?

#### Pattern 2: External Token Management

For advanced use cases, you might need to manage tokens externally:

```bash
# Create a token manually (requires appropriate permissions)
kubectl create token explorer --namespace auth-exploration --duration=1h

# Store this token for testing
TOKEN=$(kubectl create token explorer --namespace auth-exploration --duration=1h)

# Test using the token directly
kubectl --token="$TOKEN" get pods -n auth-exploration

# What are the implications of managing tokens this way?
```

## Mini-Project 3: Secure API Gateway Service Account

**Scenario**: You're building an API gateway that needs to:
- Route requests to services across multiple namespaces
- Check the health of backend services
- Read configuration from ConfigMaps
- Write metrics to a monitoring namespace
- Have short-lived tokens for security

**Challenge Questions (Think Before Implementing)**:
1. What type of role would be most appropriate - Role or ClusterRole? Why?
2. How would you handle the cross-namespace requirements securely?
3. What token configuration would be most secure?

### Implementation Phase:

```bash
# Set up the environment
kubectl create namespace api-gateway
kubectl create namespace backend-services  
kubectl create namespace monitoring-system

# Your task: Design and implement the service account and RBAC
# Consider these requirements:
# 1. Can read services in any namespace
# 2. Can read configmaps in api-gateway namespace
# 3. Can create/update metrics in monitoring-system namespace
# 4. Uses short-lived tokens (30 minutes)
# 5. Cannot access secrets or modify core infrastructure
```

**Guided Questions for Your Implementation**:
- How will you test each requirement systematically?
- What's the minimum set of permissions needed?
- How would you monitor and rotate these tokens in production?

### Sample Solution Framework:

```bash
# Step 1: Create the service account
kubectl create serviceaccount api-gateway --namespace api-gateway

# Step 2: Design your ClusterRole (fill in the blanks)
kubectl create clusterrole api-gateway-role \
  --verb=______ \
  --resource=______

# Step 3: Create your bindings
# Consider: Do you need ClusterRoleBinding, RoleBinding, or both?

# Step 4: Create a pod with custom token settings
# Include: token expiration, custom audience if needed

# Step 5: Comprehensive testing
# Test each requirement individually
```

## Authentication Troubleshooting Guide

When authentication fails, systematic diagnosis is crucial:

### Common Authentication Issues and Solutions

#### Issue 1: "Forbidden" vs "Unauthorized"

```bash
# Create scenarios to understand the difference
kubectl create serviceaccount test-unauth --namespace auth-exploration
kubectl create serviceaccount test-forbidden --namespace auth-exploration

# Give test-forbidden limited permissions
kubectl create role limited-role --verb=get --resource=services --namespace auth-exploration
kubectl create rolebinding test-forbidden-binding \
  --role=limited-role \
  --serviceaccount=auth-exploration:test-forbidden \
  --namespace=auth-exploration

# Test the different error types
echo "Testing unauthorized (no permissions at all):"
kubectl auth can-i get pods --as=system:serviceaccount:auth-exploration:test-unauth --namespace=auth-exploration

echo "Testing forbidden (has some permissions, but not for this action):"
kubectl auth can-i get pods --as=system:serviceaccount:auth-exploration:test-forbidden --namespace=auth-exploration
kubectl auth can-i get services --as=system:serviceaccount:auth-exploration:test-forbidden --namespace=auth-exploration
```

**Key Insight**: 
- **Unauthorized (401)**: Authentication failed - who are you?
- **Forbidden (403)**: Authentication succeeded, authorization failed - you can't do that

#### Issue 2: Token Expiration and Rotation

```bash
# Create a token with very short expiration for testing
SHORT_TOKEN=$(kubectl create token explorer --namespace auth-exploration --duration=60s)

echo "Testing with fresh token:"
kubectl --token="$SHORT_TOKEN" get pods -n auth-exploration

echo "Wait 70 seconds, then test again..."
sleep 70

echo "Testing with expired token:"
kubectl --token="$SHORT_TOKEN" get pods -n auth-exploration
```

**Production Strategy Question**: How would you handle token rotation in a production application? What are the trade-offs between token lifetime and security?

#### Issue 3: Service Account Mounting Problems

```bash
# Create a pod that explicitly disables token mounting
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: no-token-pod
  namespace: auth-exploration
spec:
  serviceAccountName: explorer
  automountServiceAccountToken: false  # This disables token mounting
  containers:
  - name: app
    image: bitnami/kubectl:latest
    command: ["sleep", "3600"]
EOF

# Try to use kubectl from within this pod
kubectl exec -it no-token-pod -n auth-exploration -- kubectl get pods

# What error do you get? How would you fix this if the application needed API access?
```

## Advanced Security Patterns

### Pattern 1: Impersonation for Enhanced Security

Sometimes you need applications to act on behalf of users:

```bash
# Create a service account that can impersonate users
kubectl create clusterrole user-impersonator \
  --verb=impersonate \
  --resource=users,groups

kubectl create serviceaccount impersonator --namespace auth-exploration
kubectl create clusterrolebinding impersonator-binding \
  --clusterrole=user-impersonator \
  --serviceaccount=auth-exploration:impersonator

# Test impersonation (if you have appropriate permissions)
kubectl auth can-i get pods --as=alice@company.com
```

**Discussion Questions**:
- When would impersonation be useful in real applications?
- What are the security implications of granting impersonation permissions?
- How does this relate to concepts like "service mesh" and "zero trust" architecture?

### Pattern 2: Bound Service Account Tokens

For ultra-secure environments, you can bind tokens to specific resources:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: bound-token-pod
  namespace: auth-exploration
spec:
  serviceAccountName: explorer
  containers:
  - name: app
    image: nicolaka/netshoot
    command: ["sleep", "3600"]
    volumeMounts:
    - name: bound-token
      mountPath: /var/run/secrets/tokens
      readOnly: true
  volumes:
  - name: bound-token
    projected:
      sources:
      - serviceAccountToken:
          path: bound-token
          expirationSeconds: 1800
          audience: https://kubernetes.default.svc
          # This token is bound to this specific pod
EOF

# Examine the bound token properties
kubectl exec -it bound-token-pod -n auth-exploration -- \
  cat /var/run/secrets/tokens/bound-token | base64 -d

# Try to use this token from outside the pod (should fail in secure setups)
```

## Real-World Authentication Scenarios

Let's explore some complex real-world scenarios:

### Scenario 1: Microservices Communication

**Challenge**: You have 5 microservices that need to communicate with each other. Each service needs:
- To call specific endpoints on other services
- To read its own configuration
- To write logs to a centralized system
- Different services have different security requirements

**Your Design Challenge**:
1. How many service accounts will you create? One per service or shared?
2. What's your strategy for service-to-service authentication?
3. How will you handle secrets (database passwords, API keys)?
4. What happens when a service is compromised?

**Implementation Starter**:
```bash
# Create the microservices namespace
kubectl create namespace microservices

# Services: user-service, order-service, payment-service, notification-service, audit-service
# Your task: Design the authentication architecture

# Consider:
# - Which services need to call which other services?
# - What's the principle of least privilege for each?
# - How will you test the entire authentication flow?
```

### Scenario 2: Multi-Cloud and Hybrid Environments

**Challenge**: Your application runs in multiple Kubernetes clusters (dev, staging, prod) and needs to:
- Access shared resources in a central cluster
- Authenticate with external cloud services (AWS, GCP, Azure)
- Maintain consistent security policies across clusters

**Discussion Questions**:
- How do service account tokens work across cluster boundaries?
- What are the security implications of cross-cluster authentication?
- How would you implement this without storing long-lived credentials?

## Advanced Token Management Scripts

Create this comprehensive token management utility:

```bash
#!/bin/bash
# save as sa-token-manager.sh
# Advanced service account token management utility

set -euo pipefail

NAMESPACE=${1:-default}
SA_NAME=${2:-}
ACTION=${3:-info}

usage() {
    echo "Usage: $0 <namespace> <service-account> <action>"
    echo "Actions: info, create-token, test-permissions, rotate, audit"
    exit 1
}

if [[ -z "$SA_NAME" ]]; then
    usage
fi

sa_exists() {
    kubectl get sa "$SA_NAME" -n "$NAMESPACE" >/dev/null 2>&1
}

show_info() {
    echo "🔍 Service Account Information"
    echo "================================"
    
    if ! sa_exists; then
        echo "❌ Service account $SA_NAME does not exist in namespace $NAMESPACE"
        return 1
    fi
    
    echo "📋 Service Account Details:"
    kubectl get sa "$SA_NAME" -n "$NAMESPACE" -o wide
    
    echo ""
    echo "🔗 Associated RoleBindings:"
    kubectl get rolebindings -n "$NAMESPACE" -o json | \
        jq -r ".items[] | select(.subjects[]? | select(.kind==\"ServiceAccount\" and .name==\"$SA_NAME\")) | .metadata.name" | \
        while read binding; do
            echo "   - $binding (namespace: $NAMESPACE)"
        done
    
    echo ""
    echo "🌐 Associated ClusterRoleBindings:"
    kubectl get clusterrolebindings -o json | \
        jq -r ".items[] | select(.subjects[]? | select(.kind==\"ServiceAccount\" and .name==\"$SA_NAME\" and .namespace==\"$NAMESPACE\")) | .metadata.name" | \
        while read binding; do
            echo "   - $binding (cluster-wide)"
        done
    
    echo ""
    echo "🎫 Current Token Status:"
    if kubectl get secret -n "$NAMESPACE" -o json | jq -r ".items[] | select(.metadata.annotations[\"kubernetes.io/service-account.name\"] == \"$SA_NAME\") | .metadata.name" | grep -q .; then
        echo "   📄 Legacy token secrets found"
    else
        echo "   🆕 Using projected tokens (modern approach)"
    fi
}

create_token() {
    local duration=${4:-3600}  # Default 1 hour
    echo "🎫 Creating token for $SA_NAME (duration: ${duration}s)"
    
    if ! sa_exists; then
        echo "❌ Service account does not exist"
        return 1
    fi
    
    local token
    token=$(kubectl create token "$SA_NAME" --namespace="$NAMESPACE" --duration="${duration}s")
    echo "✅ Token created successfully"
    echo "🔑 Token: $token"
    echo ""
    echo "💡 Usage example:"
    echo "kubectl --token='$token' get pods -n $NAMESPACE"
}

test_permissions() {
    echo "🧪 Testing permissions for $SA_NAME"
    echo "===================================="
    
    local tests=(
        "get pods"
        "list services"
        "create configmaps"
        "delete deployments"
        "get secrets"
        "create secrets"
    )
    
    for test in "${tests[@]}"; do
        local result
        result=$(kubectl auth can-i $test --as="system:serviceaccount:$NAMESPACE:$SA_NAME" --namespace="$NAMESPACE")
        if [[ "$result" == "yes" ]]; then
            echo "   ✅ Can $test"
        else
            echo "   ❌ Cannot $test"
        fi
    done
    
    echo ""
    echo "🌐 Cross-namespace test (default namespace):"
    local cross_result
    cross_result=$(kubectl auth can-i get pods --as="system:serviceaccount:$NAMESPACE:$SA_NAME" --namespace="default")
    if [[ "$cross_result" == "yes" ]]; then
        echo "   ✅ Has cross-namespace access"
    else
        echo "   ❌ No cross-namespace access"
    fi
}

audit_sa() {
    echo "🔍 Security Audit for $SA_NAME"
    echo "==============================="
    
    # Check for overly broad permissions
    echo "⚠️  Checking for risky permissions:"
    
    # Check for cluster-admin
    if kubectl get clusterrolebindings -o json | \
       jq -r ".items[] | select(.roleRef.name == \"cluster-admin\" and (.subjects[]? | select(.kind==\"ServiceAccount\" and .name==\"$SA_NAME\" and .namespace==\"$NAMESPACE\")))" | \
       grep -q .; then
        echo "   🚨 WARNING: Has cluster-admin permissions!"
    fi
    
    # Check for wildcard permissions
    local wildcard_roles
    wildcard_roles=$(kubectl get roles,clusterroles -A -o json | \
        jq -r '.items[] | select(.rules[]? | select(.verbs[] == "*" or .resources[] == "*")) | .metadata.name' | \
        head -5)
    
    if [[ -n "$wildcard_roles" ]]; then
        echo "   ⚠️  Found roles with wildcard permissions:"
        echo "$wildcard_roles" | sed 's/^/      - /'
    fi
    
    # Token age check
    echo ""
    echo "🕐 Token Analysis:"
    echo "   💡 Modern Kubernetes uses short-lived projected tokens"
    echo "   💡 Check your application's token refresh logic"
    
    # Namespace boundaries
    echo ""
    echo "🏠 Namespace Boundary Check:"
    local other_namespaces
    other_namespaces=$(kubectl get namespaces -o name | grep -v "namespace/$NAMESPACE" | head -3)
    for ns in $other_namespaces; do
        ns_name=$(echo "$ns" | cut -d'/' -f2)
        local can_access
        can_access=$(kubectl auth can-i get pods --as="system:serviceaccount:$NAMESPACE:$SA_NAME" --namespace="$ns_name")
        if [[ "$can_access" == "yes" ]]; then
            echo "   ⚠️  Can access namespace: $ns_name"
        fi
    done
}

case "$ACTION" in
    "info")
        show_info
        ;;
    "create-token")
        create_token "$@"
        ;;
    "test")
        test_permissions
        ;;
    "audit")
        audit_sa
        ;;
    *)
        echo "Unknown action: $ACTION"
        usage
        ;;
esac
```

## Production-Ready Token Patterns

### Pattern 3: Application Token Refresh

For production applications, implement automatic token refresh:

```yaml
# token-refresher-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: token-aware-app
  namespace: auth-exploration
spec:
  replicas: 1
  selector:
    matchLabels:
      app: token-aware-app
  template:
    metadata:
      labels:
        app: token-aware-app
    spec:
      serviceAccountName: explorer
      containers:
      - name: app
        image: nicolaka/netshoot
        command: ["sleep", "3600"]
        env:
        - name: TOKEN_REFRESH_INTERVAL
          value: "1800"  # 30 minutes
        volumeMounts:
        - name: service-account-token
          mountPath: /var/run/secrets/tokens
          readOnly: true
      volumes:
      - name: service-account-token
        projected:
          sources:
          - serviceAccountToken:
              path: token
              expirationSeconds: 3600  # 1 hour
              # Token refreshes automatically before expiration
```

## Comprehensive Challenge: Enterprise Authentication System

**Final Project**: Design a complete authentication system for a fictional e-commerce company with these requirements:

### Business Requirements:
- **Frontend Team**: Needs to deploy web applications, access CDN configurations
- **Backend Team**: Manages APIs, databases, and internal services  
- **DevOps Team**: Infrastructure management, monitoring, logging
- **Security Team**: Audit access, manage security policies, incident response
- **Data Team**: Analytics, reporting, read-only access to production data

### Technical Constraints:
- Multiple environments: dev, staging, production
- Cross-team collaboration requirements
- Compliance auditing needed
- Token rotation every 4 hours maximum
- No long-lived credentials allowed

### Your Implementation Tasks:

1. **Design Phase**:
   - Draw the authentication architecture
   - Define service accounts and roles for each team
   - Plan cross-namespace access patterns
   - Design token management strategy

2. **Implementation Phase**:
   ```bash
   # Create your implementation here
   # Start with namespace creation
   # Then service accounts
   # Then roles and bindings
   # Finally, test everything
   ```

3. **Testing Phase**:
   - Create comprehensive test scenarios
   - Verify principle of least privilege
   - Test token rotation
   - Perform security audit

4. **Documentation Phase**:
   - Document the authentication flow
   - Create troubleshooting guide
   - Write token rotation procedures
   - Plan for emergency access scenarios

## Key Takeaways from Unit 3

1. **Tokens are the authentication mechanism** - understanding how they work is crucial for troubleshooting
2. **Modern Kubernetes uses projected tokens** - they're more secure and flexible than legacy token secrets
3. **Token lifecycle management** is critical for production systems
4. **Authentication vs Authorization** - knowing the difference helps with troubleshooting
5. **Security in depth** - combine short-lived tokens with proper RBAC and monitoring

## Preparation for Unit 4

In our final unit, we'll explore:
- GitOps-based RBAC management
- Integration with external identity providers (OIDC, SAML)
- Automated compliance and auditing
- Advanced security patterns and real-world case studies

**Pre-Unit 4 Reflection Questions**:
1. How would you manage RBAC policies for 100+ microservices across multiple teams?
2. What challenges do you see in keeping RBAC policies synchronized with your application deployments?
3. Have you worked with identity providers like Active Directory or Auth0? How might these integrate with Kubernetes?

## Cleanup
```bash
kubectl delete namespace auth-exploration microservices
```