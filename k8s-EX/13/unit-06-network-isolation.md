# Unit 6: Network Isolation

## Learning Objectives
By the end of this unit, you will:
- Understand Kubernetes networking fundamentals and security implications
- Implement Network Policies for traffic control and isolation
- Design secure communication patterns between namespaces
- Configure ingress and egress controls for different security zones
- Troubleshoot network connectivity and policy issues

## Pre-Unit Network Thinking
Consider these real-world networking scenarios:
1. In a corporate office, how do you ensure the guest WiFi can't access internal servers?
2. How would you design network access for a building with public areas, employee areas, and executive areas?
3. What happens when you need to allow specific communication while blocking everything else?

## Part 1: Understanding Kubernetes Networking

### Discovery Exercise: Default Network Behavior

Let's start by understanding how Kubernetes networking works without any restrictions:

**Step 1: Create Test Environment**
```bash
# Create multiple namespaces to test connectivity
kubectl create namespace net-test-frontend
kubectl create namespace net-test-backend  
kubectl create namespace net-test-database
```

**Step 2: Deploy Test Applications**
```yaml
# test-apps.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-app
  namespace: net-test-frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: app
        image: busybox
        command: ["sleep", "3600"]
---
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
  namespace: net-test-frontend
spec:
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-app
  namespace: net-test-backend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: app
        image: nginx
---
apiVersion: v1
kind: Service
metadata:
  name: backend-service
  namespace: net-test-backend
spec:
  selector:
    app: backend
  ports:
  - port: 80
```

**Step 3: Test Default Connectivity**
```bash
# Apply the test applications
kubectl apply -f test-apps.yaml

# Test cross-namespace connectivity
kubectl exec -n net-test-frontend deployment/frontend-app -- nslookup backend-service.net-test-backend.svc.cluster.local

kubectl exec -n net-test-frontend deployment/frontend-app -- wget -qO- --timeout=5 http://backend-service.net-test-backend.svc.cluster.local

# Test external connectivity
kubectl exec -n net-test-frontend deployment/frontend-app -- wget -qO- --timeout=5 http://google.com
```

**Discovery Questions:**
1. Can pods in frontend namespace reach pods in backend namespace?
2. Can pods reach external internet addresses?
3. What does this default behavior mean for security?
4. How might this be problematic in a multi-tenant environment?

### Discovery Exercise: Network Policy Prerequisites

**Investigation Task:**
Network policies require a compatible CNI (Container Network Interface). Let's check your environment:

```bash
# Check what CNI is running in your cluster
kubectl get pods -n kube-system | grep -E "(calico|weave|flannel|cilium)"

# Check if NetworkPolicy support is available
kubectl explain networkpolicy
```

**Analysis Questions:**
1. What CNI is your cluster using?
2. Does your CNI support NetworkPolicy enforcement?
3. What happens if you create NetworkPolicies on a cluster that doesn't support them?

**Note:** If your cluster doesn't support NetworkPolicies (e.g., basic Flannel), some exercises will be conceptual rather than practical.

## Part 2: Implementing Basic Network Policies

### Discovery Exercise: The Default Deny Pattern

**Security Principle:** Start with "deny all" and explicitly allow what's needed.

**Step 1: Implement Default Deny**
```yaml
# default-deny-all.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: net-test-backend
spec:
  podSelector: {}  # Applies to all pods in namespace
  policyTypes:
  - Ingress
  - Egress
# No ingress or egress rules = deny all traffic
```

**Step 2: Test the Impact**
```bash
# Apply the policy
kubectl apply -f default-deny-all.yaml

# Test connectivity again
kubectl exec -n net-test-frontend deployment/frontend-app -- wget -qO- --timeout=5 http://backend-service.net-test-backend.svc.cluster.local

# Test from within the same namespace
kubectl run test-pod --image=busybox --rm -it -n net-test-backend -- wget -qO- --timeout=5 http://backend-service
```

**Analysis Questions:**
1. What happened to connectivity after applying the policy?
2. Can pods within the backend namespace still communicate with each other?
3. Can the backend pods reach external services (for updates, etc.)?

### Mini-Project 1: Selective Access Control

**Challenge:** Allow only specific traffic while maintaining security.

**Requirements:**
- Frontend namespace can access backend namespace on port 80
- Backend namespace can access database namespace on port 5432
- All namespaces can access DNS (for service discovery)
- Database namespace cannot initiate outbound connections

**Step 1: Frontend to Backend Access**
```yaml
# frontend-to-backend-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: net-test-backend
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: net-test-frontend
    ports:
    - protocol: TCP
      port: 80
```

**Step 2: DNS Access Policy**
```yaml
# allow-dns-access.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: net-test-backend
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
  - to: []  # Allow access to cluster DNS
    ports:
    - protocol: UDP
      port: 53
```

**Step 3: Testing Your Policies**
```bash
# First, label your namespaces for the selectors to work
kubectl label namespace net-test-frontend name=net-test-frontend
kubectl label namespace net-test-backend name=net-test-backend

# Apply the policies
kubectl apply -f frontend-to-backend-policy.yaml
kubectl apply -f allow-dns-access.yaml

# Test the access
kubectl exec -n net-test-frontend deployment/frontend-app -- wget -qO- --timeout=5 http://backend-service.net-test-backend.svc.cluster.local
```

**Design Exercise:**
Complete the policy set for the database tier. What additional considerations are needed?

### Discovery Exercise: Policy Combination Effects

**Investigation Challenge:**
Multiple NetworkPolicies can apply to the same pods. How do they interact?

```yaml
# policy-1.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-port-80
  namespace: net-test-backend
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - ports:
    - protocol: TCP
      port: 80
---
# policy-2.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-frontend
  namespace: net-test-backend
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: net-test-frontend
```

**Experimentation:**
1. Apply both policies to the same pods
2. Test different combinations of source and port
3. What's the relationship between multiple policies?

**Analysis Questions:**
1. Are NetworkPolicies additive or restrictive when combined?
2. How would you debug connectivity issues with multiple policies?
3. What's the best practice for organizing multiple related policies?

## Part 3: Advanced Network Policy Patterns

### Mini-Project 2: Multi-Tier Application Security

**Real-World Scenario:**
Design network policies for a realistic e-commerce application:

**Architecture:**
- **Web Tier:** Nginx reverse proxy (receives external traffic)
- **App Tier:** Application servers (processes business logic)
- **Cache Tier:** Redis cache (temporary data storage)
- **Data Tier:** PostgreSQL database (persistent data)

**Security Requirements:**
- External traffic only reaches web tier
- Web tier can only access app tier
- App tier can access both cache and data tiers
- Cache and data tiers cannot access external internet
- Each tier can access DNS and necessary system services

**Implementation Challenge:**

**Step 1: Environment Setup**
```bash
# Create namespaces for each tier
kubectl create namespace ecommerce-web
kubectl create namespace ecommerce-app
kubectl create namespace ecommerce-cache
kubectl create namespace ecommerce-data

# Label namespaces for policy selectors
kubectl label namespace ecommerce-web tier=web
kubectl label namespace ecommerce-app tier=app
kubectl label namespace ecommerce-cache tier=cache
kubectl label namespace ecommerce-data tier=data
```

**Step 2: Deploy Sample Applications**
```yaml
# ecommerce-apps.yaml
# Deploy representative applications in each tier
# (Implementation details for practice)
```

**Step 3: Design Network Policies**
```yaml
# web-tier-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: web-tier-policy
  namespace: ecommerce-web
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - {}  # Allow all ingress (external traffic)
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          tier: app
    ports:
    - protocol: TCP
      port: 8080
  # Add DNS egress rules
```

**Design Questions:**
1. How would you handle health checks and monitoring traffic?
2. What additional ports might each tier need?
3. How would you accommodate SSL/TLS termination?

### Discovery Exercise: Network Policy Debugging

**Common Problem Scenario:**
```yaml
# problematic-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: broken-policy
  namespace: net-test-backend
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          environment: frontend  # Wrong label!
    ports:
    - protocol: TCP
      port: 80
```

**Debugging Process:**
```bash
# Apply the problematic policy
kubectl apply -f problematic-policy.yaml

# Test connectivity
kubectl exec -n net-test-frontend deployment/frontend-app -- wget -qO- --timeout=5 http://backend-service.net-test-backend.svc.cluster.local

# Debugging steps:
# 1. Check policy syntax
kubectl describe networkpolicy broken-policy -n net-test-backend

# 2. Verify label selectors
kubectl get namespaces --show-labels

# 3. Check policy coverage
kubectl get networkpolicy -A

# 4. Test with temporary permissive policy
```

**Analysis Questions:**
1. What are common causes of NetworkPolicy failures?
2. How do you distinguish between policy issues and application issues?
3. What tools help debug network connectivity problems?

## Part 4: Cross-Namespace Communication Patterns

### Mini-Project 3: Shared Services Architecture

**Challenge:** Design network policies for shared services that multiple namespaces need to access.

**Scenario:**
- Multiple application namespaces need to access shared services:
  - Monitoring (Prometheus, Grafana)
  - Logging (Elasticsearch, Kibana)
  - Service mesh components (Istio, Linkerd)
- Shared services should only accept connections from authorized namespaces
- Applications should only be able to access necessary shared services

**Step 1: Shared Services Namespace Design**
```yaml
# shared-services-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: shared-services
  labels:
    type: shared
    security-level: restricted
```

**Step 2: Application Namespace Access Control**
```yaml
# app-namespace-template.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: app-team-alpha
  labels:
    team: alpha
    access-shared-services: "true"
    monitoring-enabled: "true"
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-shared-services
  namespace: app-team-alpha
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          type: shared
    ports:
    - protocol: TCP
      port: 9090  # Prometheus
    - protocol: TCP
      port: 3000  # Grafana
```

**Step 3: Shared Services Access Control**
```yaml
# shared-services-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: monitoring-access
  namespace: shared-services
spec:
  podSelector:
    matchLabels:
      component: monitoring
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          monitoring-enabled: "true"
    ports:
    - protocol: TCP
      port: 9090
```

**Design Exercise:**
1. How would you handle different access levels (read-only vs admin)?
2. What happens when you need to add a new shared service?
3. How would you implement time-based access restrictions?

### Discovery Exercise: Service Mesh Integration

**Investigation Challenge:**
How do NetworkPolicies interact with service mesh technologies?

**Research Topics:**
1. **Istio + NetworkPolicy:** How do they complement each other?
2. **mTLS vs NetworkPolicy:** Which provides what type of security?
3. **Policy Precedence:** What happens when both are configured?

**Experimental Setup** (if service mesh is available):
```yaml
# Compare behavior with and without service mesh
```

**Analysis Questions:**
1. What security concerns does NetworkPolicy address that service mesh doesn't?
2. What security features does service mesh provide beyond NetworkPolicy?
3. How would you design a defense-in-depth strategy using both?

## Part 5: Advanced Network Isolation Patterns

### Mini-Project 4: Zero Trust Network Architecture

**Challenge:** Implement a zero trust network model where no communication is allowed by default.

**Zero Trust Principles:**
- Never trust, always verify
- Assume breach has occurred
- Verify explicitly for every connection
- Use least privilege access

**Implementation Strategy:**

**Step 1: Global Default Deny**
```bash
#!/bin/bash
# apply-zero-trust.sh
# Script to apply default deny policies to all namespaces

for namespace in $(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}'); do
  if [[ "$namespace" != "kube-system" && "$namespace" != "kube-public" ]]; then
    cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: $namespace
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF
  fi
done
```

**Step 2: Explicit Allow Policies**
```yaml
# zero-trust-communication.yaml
# Define explicit communication patterns
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: explicit-frontend-backend
  namespace: backend-namespace
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          tier: frontend
    - podSelector:
        matchLabels:
          component: load-balancer
    ports:
    - protocol: TCP
      port: 8080
```

**Step 3: System Services Access**
```yaml
# system-services-access.yaml
# Carefully allow access to necessary system services
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-system-services
  namespace: application-namespace
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to: []
    ports:
    - protocol: UDP
      port: 53  # DNS
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: TCP
      port: 443  # API server access if needed
```

**Testing Strategy:**
1. Systematically test each allowed communication path
2. Verify that unplanned communication is blocked
3. Monitor for policy violations and adjust accordingly

### Discovery Exercise: Performance and Scale Considerations

**Investigation Challenge:**
How do NetworkPolicies affect cluster performance and scalability?

**Performance Testing:**
```bash
# Baseline performance test
kubectl run perf-test --image=busybox --rm -it -- wget -qO- http://target-service

# Performance with extensive policies
# Apply many NetworkPolicies and repeat the test
```

**Scale Considerations:**
1. How many NetworkPolicies can a cluster handle effectively?
2. What's the impact of complex label selectors on performance?
3. How do you optimize policies for large-scale deployments?

**Best Practices Research:**
- Policy organization strategies
- Label selector optimization  
- Monitoring NetworkPolicy performance

## Part 6: Real-World Application

### Comprehensive Scenario: Enterprise Network Security

**Your Challenge:**
Design complete network isolation for an enterprise environment:

**Organizational Structure:**
- **5 Business Units:** Each with their own applications and data
- **Shared Infrastructure:** Monitoring, logging, CI/CD, databases
- **Security Zones:** Public-facing, internal, restricted, management
- **Compliance Requirements:** PCI DSS, GDPR, SOX (different apps)

**Network Security Requirements:**
- Complete isolation between business units
- Shared services accessible only by authorized applications
- Different security zones with appropriate controls
- External access only through approved channels
- Complete audit trail of network access patterns

**Architecture Design:**

**Step 1: Zone-Based Network Architecture**
```yaml
# Define network zones with appropriate labeling
# Public Zone: External-facing applications
# Internal Zone: Business applications  
# Restricted Zone: Sensitive data processing
# Management Zone: Administrative tools
```

**Step 2: Cross-Zone Communication Rules**
```yaml
# Define which zones can communicate with which others
# Implement DMZ patterns for external access
# Create secure channels for management access
```

**Step 3: Business Unit Isolation**
```yaml
# Ensure complete isolation between business units
# Allow controlled access to shared services
# Implement break-glass procedures for emergency access
```

**Step 4: Compliance Controls**
```yaml
# Special network controls for compliance-required applications
# Additional monitoring and logging for audit purposes
# Network segmentation for sensitive data flows
```

### Advanced Challenge: Dynamic Network Policy Management

**Scenario Extension:**
Your network policies need to adapt to changing business requirements:
- Temporary project access between normally isolated units
- Scaling policies as new applications are deployed
- Emergency access procedures that bypass normal restrictions
- Integration with external identity and access management systems

**Implementation Considerations:**
1. How would you automate policy application for new namespaces?
2. What approval workflows would you implement for policy changes?
3. How would you handle policy conflicts and exceptions?
4. What rollback procedures would you implement for policy changes?

## Unit Assessment

### Practical Network Security Implementation

**Assessment Challenge:**
Design and implement a complete network security solution:

1. **Design Phase:**
   - Create network architecture for a multi-tier application
   - Plan network policies that enforce security boundaries
   - Design communication flows that minimize attack surface

2. **Implementation Phase:**
   - Deploy applications across multiple namespaces
   - Implement comprehensive NetworkPolicy coverage
   - Configure appropriate ingress and egress controls

3. **Validation Phase:**
   - Prove that security boundaries are enforced
   - Demonstrate that legitimate traffic flows work
   - Show monitoring and troubleshooting capabilities

### Network Security Scenarios

**Scenario-Based Assessment:**
1. **Security Breach Response:** A pod has been compromised. How do your network policies limit the blast radius?

2. **Compliance Audit:** Auditors need to verify that sensitive data flows are properly isolated. Demonstrate your network controls.

3. **Application Integration:** A new service needs to integrate with existing applications. How do you safely modify network policies?

### Troubleshooting Challenges

**Debugging Exercises:**
1. **Connectivity Issues:** Services can't communicate despite apparently correct policies. Systematic diagnosis required.

2. **Performance Problems:** Network policies are causing unexpected performance degradation. Identify and optimize.

3. **Policy Conflicts:** Multiple teams' NetworkPolicies are interfering with each other. Resolve conflicts while maintaining security.

### Knowledge Integration Questions

1. **Architecture Question:** How do you balance network security with operational simplicity?

2. **Scale Question:** How does your network policy strategy change from 10 to 1000 microservices?

3. **Evolution Question:** How do you migrate from a permissive to a zero-trust network model without breaking existing applications?

### Preparation for Unit 7

**Preview Questions:**
1. How do storage and configuration management interact with namespace boundaries?
2. What security considerations apply to data stored in different namespaces?
3. How would you design storage policies that support both isolation and sharing?

**Coming Next:** In Unit 7, we'll explore Storage and ConfigMaps, learning to manage persistent storage within namespace boundaries, implement secure configuration management, and design data isolation strategies.

## Quick Reference

### Basic NetworkPolicy Examples
```yaml
# Default deny all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress

# Allow from specific namespace
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: allowed-namespace
```

### Common Policy Patterns
```yaml
# Allow DNS
egress:
- to: []
  ports:
  - protocol: UDP
    port: 53

# Allow to external services
egress:
- to: []
  ports:
  - protocol: TCP
    port: 443

# Allow between specific pods
ingress:
- from:
  - podSelector:
      matchLabels:
        app: allowed-app
  ports:
  - protocol: TCP
    port: 8080
```

### Debugging Commands
```bash
# Check policies
kubectl get networkpolicy -A
kubectl describe networkpolicy <policy-name> -n <namespace>

# Test connectivity
kubectl exec <pod> -- nc -zv <host> <port>
kubectl exec <pod> -- nslookup <service>

# Check labels
kubectl get namespaces --show-labels
kubectl get pods --show-labels -n <namespace>

# Monitor events
kubectl get events --field-selector reason=NetworkPolicyViolation
```

### Policy Testing Patterns
```bash
# Test from pod
kubectl run test-pod --image=busybox --rm -it -n <namespace> -- <command>

# Test specific connectivity
kubectl exec -n <source-ns> <pod> -- wget -qO- --timeout=5 http://<service>.<target-ns>

# Verify DNS resolution
kubectl exec -n <ns> <pod> -- nslookup <service>.<namespace>.svc.cluster.local
```