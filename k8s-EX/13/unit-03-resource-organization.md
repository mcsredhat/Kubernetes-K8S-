# Unit 3: Resource Organization

## Learning Objectives
By the end of this unit, you will:
- Design effective resource organization patterns within namespaces
- Implement cross-namespace communication strategies
- Master resource discovery techniques across namespace boundaries
- Apply naming conventions that scale across multiple resource types
- Troubleshoot common resource organization challenges

## Pre-Unit Discovery
Think about your experience with organizing complex systems:
1. How do you currently organize files, code, or other resources in your work?
2. When you have multiple related applications, what problems arise if they're not well organized?
3. What happens when one system needs to talk to another but can't find it?

## Part 1: Resource Organization Within Namespaces

### Discovery Exercise: The Organization Challenge

**Scenario Setup:**
You're managing a microservices application with these components:
- Web frontend (3 services)
- API gateway (1 service)  
- User service (2 services + database)
- Order service (2 services + database)
- Notification service (1 service + message queue)
- Monitoring stack (4 services)

**Investigation Questions:**
Before we explore solutions, consider:
1. If all these components shared the same namespace, what organizational challenges would emerge?
2. How would a new team member understand the system architecture?
3. What happens when you need to troubleshoot a performance issue?

### Mini-Project 1: Multi-Application Namespace Design

**Design Challenge:**
Let's implement different organization approaches and compare their effectiveness.

**Approach A: Flat Organization**
```yaml
# All resources with basic names
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: ecommerce-dev
---
apiVersion: apps/v1  
kind: Deployment
metadata:
  name: api
  namespace: ecommerce-dev
---
apiVersion: apps/v1
kind: Deployment  
metadata:
  name: user-service
  namespace: ecommerce-dev
# ... more services
```

**Approach B: Prefixed Organization**
```yaml
# Resources grouped by component
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-web
  namespace: ecommerce-dev
  labels:
    component: frontend
    app: web
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service-api  
  namespace: ecommerce-dev
  labels:
    component: user-service
    app: api
```

**Approach C: Label-Based Organization**
```yaml
# Resources organized primarily through labels
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: ecommerce-dev
  labels:
    app.kubernetes.io/name: web
    app.kubernetes.io/component: frontend
    app.kubernetes.io/part-of: ecommerce
    app.kubernetes.io/version: "1.2.0"
```

**Experimentation Task:**
Implement all three approaches in test namespaces, then try these operations:
```bash
# Find all frontend components
kubectl get all -l component=frontend -n <namespace>

# List all services for user-service
kubectl get svc -l app.kubernetes.io/component=user-service -n <namespace>

# Show all resources for the ecommerce application
kubectl get all -l app.kubernetes.io/part-of=ecommerce -n <namespace>
```

**Analysis Questions:**
1. Which approach made it easiest to find related resources?
2. How would each approach scale as you add more services?
3. Which would be most helpful during an incident response?

### Discovery Exercise: Label Strategy Deep Dive

**Investigation Challenge:**
Research how major projects organize their labels:

```bash
# If you have access to these, examine their labeling:
kubectl get all -n kube-system --show-labels
kubectl get all -n istio-system --show-labels  # if using Istio
kubectl get all -n monitoring --show-labels     # if using Prometheus
```

**Pattern Analysis:**
1. What common label patterns do you notice?
2. How do these projects distinguish between different types of metadata?
3. Which patterns would work for your applications?

## Part 2: Cross-Namespace Communication

### Discovery Exercise: The Communication Problem

**Setup Challenge:**
Create this scenario to explore cross-namespace communication:

```bash
# Namespace 1: Frontend application
kubectl create namespace frontend-prod
kubectl create deployment web --image=nginx --namespace=frontend-prod
kubectl expose deployment web --port=80 --namespace=frontend-prod

# Namespace 2: Backend services  
kubectl create namespace backend-prod
kubectl create deployment api --image=httpd --namespace=backend-prod
kubectl expose deployment api --port=80 --namespace=backend-prod
```

**Investigation Questions:**
Now try to make these services communicate:
1. From a pod in frontend-prod, can you reach the api service using just `api`?
2. What happens when you try `api.backend-prod`?
3. What's the full DNS name needed for cross-namespace communication?

**Experimentation:**
```bash
# Test connectivity
kubectl exec -n frontend-prod deployment/web -- nslookup api
kubectl exec -n frontend-prod deployment/web -- nslookup api.backend-prod
kubectl exec -n frontend-prod deployment/web -- nslookup api.backend-prod.svc.cluster.local
```

### Mini-Project 2: Service Discovery Patterns

**Real-World Scenario:**
You're building a microservices platform where:
- Frontend apps in `frontend-*` namespaces need to call APIs
- APIs in `backend-*` namespaces need to access databases  
- Monitoring in `monitoring` namespace needs to scrape all services

**Design Challenge:**
How will you handle service discovery? Consider these approaches:

**Approach A: Hardcoded FQDNs**
```yaml
# Frontend configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: frontend-prod
data:
  api_url: "http://user-api.backend-prod.svc.cluster.local"
  order_url: "http://order-api.backend-prod.svc.cluster.local"
```

**Approach B: Service Mesh / Ingress**
```yaml
# Using a service mesh for cross-namespace calls
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: api-routing
  namespace: frontend-prod
spec:
  hosts:
  - user-api
  http:
  - route:
    - destination:
        host: user-api.backend-prod.svc.cluster.local
```

**Approach C: Shared Services Namespace**
```bash
# Common services that multiple namespaces need
kubectl create namespace shared-services
# Deploy commonly used services here
```

**Analysis Exercise:**
1. What are the security implications of each approach?
2. How would each approach handle service upgrades?
3. Which approach provides the best debugging experience?

### Discovery Exercise: DNS and Service Resolution

**Investigation Task:**
Understand how Kubernetes DNS resolution works across namespaces:

```bash
# From any pod, examine the DNS configuration
kubectl exec -it <any-pod> -- cat /etc/resolv.conf

# Test different resolution patterns
kubectl exec -it <pod-in-ns-A> -- nslookup <service>
kubectl exec -it <pod-in-ns-A> -- nslookup <service>.<namespace-B>
kubectl exec -it <pod-in-ns-A> -- nslookup <service>.<namespace-B>.svc
kubectl exec -it <pod-in-ns-A> -- nslookup <service>.<namespace-B>.svc.cluster.local
```

**Understanding Questions:**
1. What's the shortest name that works for cross-namespace calls?
2. When might you want to use the full FQDN?
3. How does the search domain in resolv.conf affect name resolution?

## Part 3: Advanced Resource Discovery

### Discovery Exercise: Resource Relationships

**Challenge Setup:**
Deploy a complex application to explore resource relationships:

```yaml
# Complete application stack
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: discovery-test
  labels:
    tier: frontend
    app: web-app
    version: v1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
        tier: frontend
    spec:
      containers:
      - name: web
        image: nginx
---
apiVersion: v1
kind: Service
metadata:
  name: web-service
  namespace: discovery-test
  labels:
    tier: frontend
    app: web-app
spec:
  selector:
    app: web-app
  ports:
  - port: 80
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-config
  namespace: discovery-test
  labels:
    tier: frontend
    app: web-app
data:
  nginx.conf: |
    # nginx configuration
```

**Discovery Questions:**
Now explore the relationships:
1. How can you find all resources related to the `web-app`?
2. Which resources depend on others, and how can you identify these dependencies?
3. What happens to related resources when you delete the deployment?

**Investigation Commands:**
```bash
# Try different discovery approaches
kubectl get all -l app=web-app -n discovery-test
kubectl get all,configmaps,secrets -l app=web-app -n discovery-test
kubectl describe deployment web-app -n discovery-test
# Look for resource references in the output
```

### Mini-Project 3: Resource Mapping Tool

**Challenge:**
Build a tool that maps resource relationships within a namespace.

**Requirements:**
- Identify which services select which pods
- Find which ConfigMaps/Secrets are mounted by which deployments
- Show which resources share common labels

**Implementation Approach:**
```bash
#!/bin/bash
# resource-mapper.sh

NAMESPACE=$1

echo "=== Resource Relationship Map for $NAMESPACE ==="

# Your implementation:
# 1. Get all resources with labels
# 2. Group by common labels  
# 3. Show relationships (Service -> Pods, Deployment -> ConfigMaps, etc.)
# 4. Identify orphaned resources
```

**Testing Your Tool:**
Create test scenarios:
- Well-organized application with clear relationships
- Mixed application with some orphaned resources
- Complex application with multiple tiers

**Reflection Questions:**
1. What patterns make resource relationships clearer?
2. How would this tool help during incident response?
3. What additional relationship types should it detect?

## Part 4: Naming Convention Systems

### Discovery Exercise: Naming at Scale

**Investigation Challenge:**
Research naming conventions from major Kubernetes projects:

```bash
# Examine different naming patterns
kubectl get all -A --show-labels | grep -E "(prometheus|grafana|jaeger|istio)"

# Look for patterns in resource names and labels
```

**Pattern Analysis:**
1. How do these projects handle resource naming within namespaces?
2. What conventions help distinguish between different types of resources?
3. How do they handle versioning and environment differences in names?

### Mini-Project 4: Comprehensive Naming Strategy

**Design Challenge:**
Create a naming convention system that works across:
- Multiple teams and projects
- Different environments  
- Various resource types
- Cross-namespace references

**Requirements Analysis:**
Before implementing, consider:
1. What information must be encoded in resource names?
2. What can be handled through labels instead?
3. How will this support automation and tooling?
4. What constraints does Kubernetes impose on naming?

**Implementation:**
Design naming templates for:
```yaml
# Deployment naming
metadata:
  name: ${APP}-${COMPONENT}-${VERSION}
  labels:
    app.kubernetes.io/name: ${APP}
    app.kubernetes.io/component: ${COMPONENT}
    app.kubernetes.io/version: ${VERSION}

# Service naming  
metadata:
  name: ${APP}-${COMPONENT}-svc
  
# ConfigMap naming
metadata:
  name: ${APP}-${COMPONENT}-config
```

**Validation Exercise:**
Test your naming strategy with these scenarios:
- E-commerce application with web, api, and database components
- Monitoring stack with multiple interdependent services
- Multi-version deployment (blue/green or canary)

**Analysis Questions:**
1. Can you predict the service name from the deployment name?
2. How do you handle name length limits?
3. What happens when you need to rename components?

## Part 5: Real-World Application

### Comprehensive Scenario: Microservices Platform

**Your Challenge:**
Design resource organization for a complete microservices platform:

**Platform Requirements:**
- 5 core business services
- 3 infrastructure services (logging, monitoring, security)
- Development, staging, and production environments
- Multiple teams with different access levels
- CI/CD pipeline integration

**Architecture Questions:**
Before implementing, address:
1. How will you balance namespace isolation with operational efficiency?
2. What resource organization patterns will support both development and operations teams?
3. How will you handle shared dependencies and common services?

**Implementation Phase:**

**1. Namespace Design:**
```yaml
# What namespace structure will you use?
# How will teams collaborate across namespace boundaries?
```

**2. Resource Organization:**
```yaml
# How will you organize resources within each namespace?
# What labeling strategy supports both filtering and relationships?
```

**3. Communication Patterns:**
```yaml
# How will services discover and communicate with each other?
# What patterns support both security and usability?
```

**Testing Strategy:**
Validate your design with these scenarios:
- New service deployment
- Cross-service debugging
- Security incident response
- Environment promotion
- Team onboarding

### Advanced Challenge: Migration Scenario

**Scenario:**
You inherit a Kubernetes cluster with poor resource organization:
- Everything in default namespace
- Inconsistent naming
- No clear service relationships
- Multiple teams stepping on each other

**Migration Planning:**
1. How would you assess the current state?
2. What migration strategy minimizes disruption?
3. How do you ensure teams adopt new patterns?
4. What safety measures prevent data loss?

**Implementation Exercise:**
Create a migration plan that includes:
- Assessment tools
- Gradual migration steps
- Validation checkpoints  
- Rollback procedures

## Unit Assessment

### Practical Demonstration

**Assessment Challenge:**
Design and implement resource organization for a realistic scenario:

1. **Planning Phase:**
   - Choose a multi-service application architecture
   - Design namespace and resource organization strategy
   - Plan cross-namespace communication patterns

2. **Implementation Phase:**
   - Deploy the complete application stack
   - Demonstrate resource discovery capabilities
   - Show cross-namespace communication working

3. **Validation Phase:**
   - Prove the organization supports common operational tasks
   - Demonstrate troubleshooting scenarios
   - Show how new services would integrate

### Knowledge Integration

**Scenario Questions:**
1. You need to reorganize 50+ services across multiple namespaces. Walk through your approach.
2. Services in namespace A can't reach services in namespace B. Debug systematically.
3. Design resource organization that supports both multi-tenancy and operational efficiency.

### Preparation for Unit 4

**Preview Questions:**
1. How might resource consumption vary between different namespaces?
2. What problems could arise if one namespace consumes all cluster resources?
3. How would you ensure fair resource sharing across teams and applications?

**Coming Next:** In Unit 4, we'll explore resource quotas and limits, learning to manage resource consumption, implement fair sharing policies, and prevent resource contention across namespaces.

## Quick Reference

### Resource Discovery Commands
```bash
# Find resources by labels
kubectl get all -l app=myapp -n namespace
kubectl get all,configmaps,secrets -l tier=frontend -n namespace

# Cross-namespace resource listing
kubectl get services --all-namespaces -l app=myapp
kubectl get pods -A --field-selector metadata.namespace!=kube-system

# Service discovery
kubectl exec pod -- nslookup service.namespace.svc.cluster.local
kubectl get endpoints -n namespace
```

### Organization Patterns
```bash
# Label-based organization
app.kubernetes.io/name: application-name
app.kubernetes.io/component: component-name  
app.kubernetes.io/part-of: application-group
app.kubernetes.io/version: version

# Resource relationship discovery
kubectl describe deployment name | grep -E "(ConfigMap|Secret|Service)"
kubectl get events --field-selector involvedObject.name=resource-name
```
