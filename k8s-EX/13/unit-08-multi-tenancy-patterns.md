# Unit 8: Multi-Tenancy Patterns

## Learning Objectives
By the end of this unit, you will:
- Understand different multi-tenancy models and their trade-offs
- Design tenant isolation strategies using namespaces effectively
- Implement resource sharing patterns that balance efficiency with security
- Create governance frameworks for multi-tenant environments
- Architect scalable solutions that support hundreds of tenants

## Pre-Unit Multi-Tenancy Thinking
Consider these real-world multi-tenancy scenarios:
1. How does a cloud provider like AWS isolate thousands of customers while sharing infrastructure?
2. What's the difference between a hotel (shared building, private rooms) and separate houses?
3. How would you balance cost efficiency with privacy and security in a shared system?

## Part 1: Understanding Multi-Tenancy Models

### Discovery Exercise: Tenancy Model Analysis

Let's explore different approaches to multi-tenancy and their implications:

**Step 1: Single-Tenant Per Namespace Model**
```bash
# Create individual tenant namespaces
kubectl create namespace tenant-acme-corp
kubectl create namespace tenant-globodyne  
kubectl create namespace tenant-stark-industries

# Label them for tenant management
kubectl label namespace tenant-acme-corp tenant=acme-corp tier=premium
kubectl label namespace tenant-globodyne tenant=globodyne tier=standard
kubectl label namespace tenant-stark-industries tenant=stark-industries tier=enterprise
```

**Step 2: Shared Namespace Multi-Tenancy Model**
```bash
# Single namespace with tenant identification through labels
kubectl create namespace multi-tenant-shared

# Applications would use tenant-aware labeling
kubectl create deployment acme-web --image=nginx -n multi-tenant-shared
kubectl label deployment acme-web tenant=acme-corp -n multi-tenant-shared
```

**Step 3: Hybrid Model**
```bash
# Namespace per tenant type, multiple tenants per namespace
kubectl create namespace premium-tenants
kubectl create namespace standard-tenants
kubectl create namespace enterprise-tenants
```

**Analysis Questions:**
1. What are the security implications of each model?
2. How would resource management differ between these approaches?
3. Which model would be easier to manage at 10 tenants vs 1000 tenants?
4. What are the cost implications of each approach?

### Discovery Exercise: Tenant Isolation Requirements

**Investigation Challenge:**
Different tenants may have different isolation requirements. Let's explore:

**Tenant Profile A: Startup (Cost-Sensitive)**
- Willing to share infrastructure for cost savings
- Basic security requirements
- Flexible on performance guarantees

**Tenant Profile B: Financial Services (Compliance-Heavy)**
- Strict data isolation requirements
- Regulatory compliance needs (PCI DSS, SOX)
- Performance SLAs required

**Tenant Profile C: Healthcare (HIPAA Compliant)**
- Complete data isolation mandated
- Audit trail requirements
- Encryption at rest and in transit

**Design Challenge:**
How would you architect a platform that serves all three tenant types? Consider:
1. Can they share the same cluster?
2. What namespace strategies would work?
3. How would you handle different security requirements?

## Part 2: Namespace-Based Tenant Isolation

### Mini-Project 1: Comprehensive Tenant Onboarding

**Scenario:** You're building a SaaS platform that needs to onboard new tenants quickly while ensuring proper isolation.

**Requirements:**
- Automated tenant namespace creation
- Consistent security policies per tenant tier
- Resource quotas based on subscription level
- Monitoring and billing integration
- Self-service capabilities for tenant admins

**Step 1: Tenant Onboarding Automation**
```yaml
# tenant-onboarding-template.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: "tenant-{TENANT_ID}"
  labels:
    tenant-id: "{TENANT_ID}"
    tenant-name: "{TENANT_NAME}"
    subscription-tier: "{TIER}"  # free, standard, premium, enterprise
    billing-account: "{BILLING_ID}"
    compliance-level: "{COMPLIANCE}"  # basic, standard, strict
    created-date: "{CREATION_DATE}"
  annotations:
    tenant.saas.com/contact-email: "{CONTACT_EMAIL}"
    tenant.saas.com/organization: "{ORG_NAME}"
    tenant.saas.com/onboarding-version: "v2.1"
---
# Tenant-specific resource quota
apiVersion: v1
kind: ResourceQuota
metadata:
  name: tenant-quota
  namespace: "tenant-{TENANT_ID}"
spec:
  hard:
    # Computed based on subscription tier
    requests.cpu: "{CPU_REQUEST_LIMIT}"
    requests.memory: "{MEMORY_REQUEST_LIMIT}"
    limits.cpu: "{CPU_LIMIT}"
    limits.memory: "{MEMORY_LIMIT}"
    pods: "{POD_LIMIT}"
    services: "{SERVICE_LIMIT}"
    secrets: "{SECRET_LIMIT}"
    configmaps: "{CONFIGMAP_LIMIT}"
    persistentvolumeclaims: "{PVC_LIMIT}"
    requests.storage: "{STORAGE_LIMIT}"
```

**Step 2: Tenant Security Policies**
```yaml
# tenant-security-template.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: tenant-isolation
  namespace: "tenant-{TENANT_ID}"
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: "tenant-{TENANT_ID}"
    # Allow ingress from tenant's own namespace
  - from:
    - namespaceSelector:
        matchLabels:
          type: shared-services
    # Allow access from shared services (monitoring, logging)
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          type: shared-services
  - to: []
    ports:
    - protocol: UDP
      port: 53  # DNS
---
# Tenant RBAC
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: tenant-admin
  namespace: "tenant-{TENANT_ID}"
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets"]
  verbs: ["*"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["*"]
- apiGroups: [""]
  resources: ["pods/log", "pods/exec"]
  verbs: ["get", "create"]
# No access to modify namespace, quotas, or network policies
```

**Step 3: Onboarding Script**
```bash
#!/bin/bash
# tenant-onboard.sh

TENANT_ID=$1
TENANT_NAME=$2
TIER=${3:-standard}
CONTACT_EMAIL=$4

if [ -z "$TENANT_ID" ] || [ -z "$TENANT_NAME" ] || [ -z "$CONTACT_EMAIL" ]; then
    echo "Usage: $0 <tenant-id> <tenant-name> <tier> <contact-email>"
    exit 1
fi

# Define tier-based resource allocations
case $TIER in
    "free")
        CPU_REQUEST="500m"
        MEMORY_REQUEST="1Gi"
        CPU_LIMIT="1000m"
        MEMORY_LIMIT="2Gi"
        POD_LIMIT="5"
        STORAGE_LIMIT="5Gi"
        ;;
    "standard")
        CPU_REQUEST="2000m"
        MEMORY_REQUEST="4Gi"
        CPU_LIMIT="4000m"
        MEMORY_LIMIT="8Gi"
        POD_LIMIT="20"
        STORAGE_LIMIT="50Gi"
        ;;
    "premium")
        CPU_REQUEST="8000m"
        MEMORY_REQUEST="16Gi"
        CPU_LIMIT="16000m"
        MEMORY_LIMIT="32Gi"
        POD_LIMIT="100"
        STORAGE_LIMIT="500Gi"
        ;;
esac

# Generate namespace configuration from template
sed -e "s/{TENANT_ID}/$TENANT_ID/g" \
    -e "s/{TENANT_NAME}/$TENANT_NAME/g" \
    -e "s/{TIER}/$TIER/g" \
    -e "s/{CONTACT_EMAIL}/$CONTACT_EMAIL/g" \
    -e "s/{CPU_REQUEST_LIMIT}/$CPU_REQUEST/g" \
    -e "s/{MEMORY_REQUEST_LIMIT}/$MEMORY_REQUEST/g" \
    -e "s/{CPU_LIMIT}/$CPU_LIMIT/g" \
    -e "s/{MEMORY_LIMIT}/$MEMORY_LIMIT/g" \
    -e "s/{POD_LIMIT}/$POD_LIMIT/g" \
    -e "s/{STORAGE_LIMIT}/$STORAGE_LIMIT/g" \
    tenant-onboarding-template.yaml | kubectl apply -f -

# Create tenant admin service account
kubectl create serviceaccount tenant-admin -n tenant-$TENANT_ID
kubectl create rolebinding tenant-admin-binding \
    --role=tenant-admin \
    --serviceaccount=tenant-$TENANT_ID:tenant-admin \
    -n tenant-$TENANT_ID

echo "Tenant $TENANT_NAME (ID: $TENANT_ID) onboarded successfully!"
echo "Namespace: tenant-$TENANT_ID"
echo "Tier: $TIER"
echo "Resource Limits: CPU=$CPU_LIMIT, Memory=$MEMORY_LIMIT"
```

**Testing Exercise:**
1. Onboard several test tenants with different tiers
2. Verify resource quotas are correctly applied
3. Test network isolation between tenants
4. Confirm tenant admins have appropriate access

### Discovery Exercise: Shared Services Architecture

**Challenge:** Design shared services that multiple tenants can use safely.

**Common Shared Services:**
- Monitoring and observability (Prometheus, Grafana)
- Logging aggregation (Elasticsearch, Kibana)
- Certificate management (cert-manager)
- Image scanning and security
- CI/CD pipeline services
- API gateways and ingress controllers

**Step 1: Shared Services Namespace Design**
```yaml
# shared-services.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: shared-monitoring
  labels:
    type: shared-services
    service-category: monitoring
    access-level: tenant-accessible
---
apiVersion: v1
kind: Namespace
metadata:
  name: shared-logging
  labels:
    type: shared-services
    service-category: logging
    access-level: tenant-accessible
---
apiVersion: v1
kind: Namespace
metadata:
  name: shared-security
  labels:
    type: shared-services
    service-category: security
    access-level: platform-only  # Only platform team access
```

**Step 2: Tenant Access to Shared Services**
```yaml
# monitoring-access-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-tenant-monitoring
  namespace: shared-monitoring
spec:
  podSelector:
    matchLabels:
      app: prometheus
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          tenant-id: {}  # Any tenant namespace
    ports:
    - protocol: TCP
      port: 9090
---
# Tenant monitoring collection
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-monitoring-collection
  namespace: "tenant-{TENANT_ID}"
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          service-category: monitoring
    ports:
    - protocol: TCP
      port: 8080  # Application metrics port
```

**Analysis Questions:**
1. How do you prevent tenants from accessing other tenants' metrics?
2. What shared services require special security considerations?
3. How would you handle shared services that need tenant-specific configuration?

## Part 3: Resource Sharing and Optimization

### Mini-Project 2: Efficient Resource Sharing

**Challenge:** Balance resource efficiency with tenant isolation.

**Scenario:**
- 50 tenants with varying workload patterns
- Peak usage times differ by geographic region
- Some tenants have predictable batch processing needs
- Others have unpredictable traffic spikes
- Cost optimization is critical for platform viability

**Step 1: Dynamic Resource Allocation**
```yaml
# resource-sharing-policy.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: tenant-base-quota
  namespace: "tenant-{TENANT_ID}"
  annotations:
    quota.saas.com/burst-allowed: "true"
    quota.saas.com/burst-multiplier: "2.0"
    quota.saas.com/peak-hours: "09:00-17:00"
spec:
  hard:
    # Base guaranteed resources
    requests.cpu: "1000m"
    requests.memory: "2Gi"
    # Burstable limits (higher than base)
    limits.cpu: "4000m"
    limits.memory: "8Gi"
---
# Priority classes for different workload types
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: tenant-production
value: 1000
globalDefault: false
description: "Production workloads for paying tenants"
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: tenant-development
value: 500
globalDefault: false
description: "Development workloads, can be preempted"
```

**Step 2: Workload Classification**
```yaml
# tenant-workload-classes.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tenant-web-app
  namespace: "tenant-{TENANT_ID}"
  labels:
    workload-type: "interactive"
    business-criticality: "high"
spec:
  template:
    spec:
      priorityClassName: tenant-production
      containers:
      - name: web
        image: nginx
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
---
apiVersion: batch/v1
kind: Job
metadata:
  name: tenant-batch-job
  namespace: "tenant-{TENANT_ID}"
  labels:
    workload-type: "batch"
    business-criticality: "medium"
spec:
  template:
    spec:
      priorityClassName: tenant-development
      containers:
      - name: processor
        image: batch-processor
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "4Gi"
            cpu: "2000m"
```

**Step 3: Monitoring Resource Utilization**
```bash
#!/bin/bash
# resource-utilization-monitor.sh

echo "=== Tenant Resource Utilization Report ==="
echo "Generated: $(date)"
echo

for tenant_ns in $(kubectl get namespaces -l tenant-id --no-headers -o custom-columns=":metadata.name"); do
    tenant_id=$(kubectl get namespace $tenant_ns -o jsonpath='{.metadata.labels.tenant-id}')
    tier=$(kubectl get namespace $tenant_ns -o jsonpath='{.metadata.labels.subscription-tier}')
    
    echo "--- Tenant: $tenant_id (Tier: $tier) ---"
    
    # Get quota usage
    echo "Quota Usage:"
    kubectl describe resourcequota -n $tenant_ns | grep -A 10 "Resource.*Used.*Hard"
    
    # Get actual resource consumption
    echo "Actual Usage:"
    kubectl top pods -n $tenant_ns --no-headers | awk '{cpu+=$2; mem+=$3} END {print "Total CPU:", cpu, "Total Memory:", mem}'
    
    echo
done
```

**Optimization Questions:**
1. How would you implement automatic quota adjustments based on usage patterns?
2. What mechanisms would handle resource contention fairly?
3. How would you charge tenants for resource usage accurately?

### Discovery Exercise: Cost Allocation and Chargeback

**Investigation Challenge:**
Implement cost tracking and chargeback for multi-tenant environments.

**Step 1: Resource Tagging for Cost Allocation**
```yaml
# cost-allocation-labels.yaml
metadata:
  labels:
    tenant-id: "acme-corp"
    cost-center: "engineering"
    environment: "production"
    project: "web-portal"
    billing-code: "PROJ-001"
  annotations:
    cost.saas.com/hourly-rate: "0.15"
    cost.saas.com/billing-account: "acme-corp-billing"
    cost.saas.com/cost-allocation-model: "resource-usage"
```

**Step 2: Usage Monitoring**
```bash
#!/bin/bash
# cost-calculation.sh

TENANT_ID=$1
MONTH=${2:-$(date +%Y-%m)}

echo "Cost Report for Tenant: $TENANT_ID"
echo "Month: $MONTH"
echo "========================="

# Calculate CPU hours
cpu_hours=$(kubectl get pods -n tenant-$TENANT_ID -o jsonpath='{range .items[*]}{.spec.containers[*].resources.requests.cpu}{"\n"}{end}' | awk -F'm' '{total += $1} END {print total/1000}')

# Calculate memory GB-hours  
memory_hours=$(kubectl get pods -n tenant-$TENANT_ID -o jsonpath='{range .items[*]}{.spec.containers[*].resources.requests.memory}{"\n"}{end}' | awk -F'Gi' '{total += $1} END {print total}')

# Storage usage
storage_gb=$(kubectl get pvc -n tenant-$TENANT_ID -o jsonpath='{range .items[*]}{.spec.resources.requests.storage}{"\n"}{end}' | awk -F'Gi' '{total += $1} END {print total}')

echo "Resource Usage:"
echo "  CPU Hours: $cpu_hours"
echo "  Memory GB-Hours: $memory_hours"
echo "  Storage GB: $storage_gb"

# Apply pricing model (example rates)
cpu_cost=$(echo "$cpu_hours * 0.10" | bc)
memory_cost=$(echo "$memory_hours * 0.05" | bc)
storage_cost=$(echo "$storage_gb * 0.10" | bc)

total_cost=$(echo "$cpu_cost + $memory_cost + $storage_cost" | bc)

echo "Cost Breakdown:"
echo "  CPU Cost: \$cpu_cost"
echo "  Memory Cost: \$memory_cost"  
echo "  Storage Cost: \$storage_cost"
echo "  Total: \$total_cost"
```

**Analysis Questions:**
1. How would you handle shared resource costs (load balancers, monitoring)?
2. What granularity of cost tracking is practical and useful?
3. How would you implement fair billing for burst resource usage?

## Part 4: Governance and Compliance

### Mini-Project 3: Multi-Tenant Governance Framework

**Challenge:** Implement governance that scales across hundreds of tenants while maintaining security and compliance.

**Governance Requirements:**
- Consistent security policies across all tenants
- Compliance reporting per tenant and aggregate
- Self-service capabilities with proper guardrails
- Audit trails for all tenant activities
- Automated policy enforcement and remediation

**Step 1: Policy as Code Implementation**
```yaml
# governance-policies.yaml
apiVersion: kyverno.io/v1
kind: Policy
metadata:
  name: tenant-namespace-policies
spec:
  validationFailureAction: enforce
  background: true
  rules:
  - name: require-tenant-labels
    match:
      resources:
        kinds:
        - Namespace
        names:
        - "tenant-*"
    validate:
      message: "Tenant namespaces must have required labels"
      pattern:
        metadata:
          labels:
            tenant-id: "?*"
            subscription-tier: "free|standard|premium|enterprise"
            billing-account: "?*"
  - name: enforce-resource-quotas
    match:
      resources:
        kinds:
        - Namespace
        names:
        - "tenant-*"
    generate:
      kind: ResourceQuota
      name: tenant-quota
      namespace: "{{request.object.metadata.name}}"
      data:
        spec:
          hard:
            pods: "{{request.object.metadata.labels.subscription-tier | tier_to_pods}}"
---
apiVersion: kyverno.io/v1
kind: Policy
metadata:
  name: tenant-security-policies
spec:
  validationFailureAction: enforce
  rules:
  - name: disallow-privileged-containers
    match:
      resources:
        kinds:
        - Pod
        namespaces:
        - "tenant-*"
    validate:
      message: "Privileged containers are not allowed for tenants"
      pattern:
        spec:
          =(securityContext):
            =(privileged): false
  - name: require-resource-limits
    match:
      resources:
        kinds:
        - Pod
        namespaces:
        - "tenant-*"
    validate:
      message: "All containers must have resource limits"
      pattern:
        spec:
          containers:
          - name: "*"
            resources:
              limits:
                memory: "?*"
                cpu: "?*"
```

**Step 2: Compliance Monitoring**
```bash
#!/bin/bash
# compliance-audit.sh

echo "=== Multi-Tenant Compliance Report ==="
echo "Generated: $(date)"
echo

# Check policy violations
echo "Policy Violations:"
kubectl get events --all-namespaces --field-selector reason=PolicyViolation

# Check security compliance
echo "Security Compliance Check:"
total_tenants=0
compliant_tenants=0

for tenant_ns in $(kubectl get namespaces -l tenant-id --no-headers -o custom-columns=":metadata.name"); do
    total_tenants=$((total_tenants + 1))
    
    # Check if all required policies are in place
    has_quota=$(kubectl get resourcequota -n $tenant_ns --no-headers | wc -l)
    has_netpol=$(kubectl get networkpolicy -n $tenant_ns --no-headers | wc -l)
    has_rbac=$(kubectl get rolebinding -n $tenant_ns --no-headers | wc -l)
    
    if [[ $has_quota -gt 0 && $has_netpol -gt 0 && $has_rbac -gt 0 ]]; then
        compliant_tenants=$((compliant_tenants + 1))
    else
        echo "Non-compliant tenant: $tenant_ns (Quota: $has_quota, NetPol: $has_netpol, RBAC: $has_rbac)"
    fi
done

compliance_rate=$((compliant_tenants * 100 / total_tenants))
echo "Compliance Rate: $compliance_rate% ($compliant_tenants/$total_tenants)"
```

**Step 3: Self-Service Portal Integration**
```yaml
# tenant-self-service-rbac.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: tenant-self-service
rules:
# Allow tenant users to view their own namespace
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["get"]
  resourceNames: [] # Will be restricted by RoleBinding
# Allow management of their applications
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
# Allow viewing of quotas and limits (but not modification)
- apiGroups: [""]
  resources: ["resourcequotas", "limitranges"]
  verbs: ["get", "list"]
# No access to modify security policies, network policies, or RBAC
---
# Tenant-specific binding (created per tenant)
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: tenant-self-service-binding
  namespace: "tenant-{TENANT_ID}"
subjects:
- kind: User
  name: "{TENANT_ADMIN_USER}"
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: tenant-self-service
  apiGroup: rbac.authorization.k8s.io
```

**Governance Questions:**
1. How would you balance self-service capabilities with security controls?
2. What approval workflows would you implement for policy exceptions?
3. How would you handle governance across multiple clusters?

### Discovery Exercise: Compliance Automation

**Investigation Challenge:**
Explore automated compliance monitoring and remediation.

**Compliance Scenarios:**
1. **Data Residency:** Ensure certain tenants' data stays in specific regions
2. **Encryption Standards:** Verify all sensitive data is encrypted at rest
3. **Access Auditing:** Track and report all access to tenant resources
4. **Retention Policies:** Automatically clean up resources based on tenant policies

**Implementation Research:**
```yaml
# Example: Automated remediation for policy violations
apiVersion: kyverno.io/v1
kind: Policy
metadata:
  name: auto-remediate-violations
spec:
  validationFailureAction: enforce
  background: true
  rules:
  - name: add-missing-labels
    match:
      resources:
        kinds:
        - Pod
        namespaces:
        - "tenant-*"
    mutate:
      patchStrategicMerge:
        metadata:
          labels:
            +(compliance.audited): "true"
            +(last-scanned): "{{time.now()}}"
```

**Analysis Questions:**
1. What compliance requirements can be automated vs require manual review?
2. How would you handle exceptions and special cases?
3. What evidence would auditors need to verify compliance?

## Part 5: Advanced Multi-Tenancy Patterns

### Mini-Project 4: Hierarchical Tenancy

**Challenge:** Implement a hierarchical tenancy model for enterprise customers with subsidiaries.

**Scenario:**
- Enterprise customers have multiple subsidiaries
- Each subsidiary may have multiple departments/projects
- Billing rolls up through the hierarchy
- Some resources are shared at different levels
- Access control follows organizational structure

**Step 1: Hierarchical Namespace Structure**
```yaml
# hierarchical-tenancy.yaml
# Root enterprise tenant
apiVersion: v1
kind: Namespace
metadata:
  name: enterprise-megacorp
  labels:
    tenant-type: "enterprise-root"
    tenant-id: "megacorp"
    billing-root: "true"
---
# Subsidiary namespaces
apiVersion: v1
kind: Namespace
metadata:
  name: subsidiary-megacorp-aerospace
  labels:
    tenant-type: "subsidiary"
    parent-tenant: "megacorp"
    tenant-id: "megacorp-aerospace"
    billing-parent: "enterprise-megacorp"
---
apiVersion: v1
kind: Namespace
metadata:
  name: subsidiary-megacorp-automotive
  labels:
    tenant-type: "subsidiary"
    parent-tenant: "megacorp"
    tenant-id: "megacorp-automotive"
    billing-parent: "enterprise-megacorp"
---
# Project/department namespaces
apiVersion: v1
kind: Namespace
metadata:
  name: project-rocket-development
  labels:
    tenant-type: "project"
    parent-tenant: "megacorp-aerospace"
    root-tenant: "megacorp"
    tenant-id: "rocket-dev"
    billing-parent: "subsidiary-megacorp-aerospace"
```

**Step 2: Hierarchical RBAC**
```yaml
# hierarchical-rbac.yaml
# Enterprise admin role (highest level)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: enterprise-admin
rules:
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["get", "list"]
  resourceNames: [] # Restricted by binding
- apiGroups: [""]
  resources: ["resourcequotas"]
  verbs: ["get", "list", "update", "patch"] # Can modify quotas
---
# Subsidiary admin role (mid-level)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: subsidiary-admin
rules:
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["get", "list"]
- apiGroups: ["apps"]
  resources: ["deployments", "services"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
---
# Project role (lowest level)
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: project-developer
  namespace: project-rocket-development
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "create", "update", "patch"]
```

**Step 3: Resource Inheritance**
```bash
#!/bin/bash
# hierarchical-resource-allocation.sh

# Calculate resource allocation down the hierarchy
ENTERPRISE_CPU="100000m"  # 100 cores for entire enterprise
ENTERPRISE_MEMORY="400Gi"

# Allocate to subsidiaries (example: 60/40 split)
AEROSPACE_CPU="60000m"
AEROSPACE_MEMORY="240Gi"
AUTOMOTIVE_CPU="40000m"  
AUTOMOTIVE_MEMORY="160Gi"

# Further allocate to projects within aerospace
ROCKET_DEV_CPU="30000m"
ROCKET_DEV_MEMORY="120Gi"
SATELLITE_DEV_CPU="30000m"
SATELLITE_DEV_MEMORY="120Gi"

# Apply quotas hierarchically
apply_quota() {
    local namespace=$1
    local cpu=$2
    local memory=$3
    
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: hierarchical-quota
  namespace: $namespace
spec:
  hard:
    requests.cpu: "$cpu"
    requests.memory: "$memory"
    limits.cpu: "$(echo "$cpu" | sed 's/m/*2m/g' | bc)"
    limits.memory: "$(echo "$memory" | sed 's/Gi/*2Gi/g' | bc)"
EOF
}

apply_quota "project-rocket-development" "$ROCKET_DEV_CPU" "$ROCKET_DEV_MEMORY"
```

**Hierarchical Design Questions:**
1. How would you handle resource reallocation between subsidiaries?
2. What happens when a subsidiary is acquired or divested?
3. How would you implement cascading policy updates?

### Discovery Exercise: Advanced Isolation Techniques

**Investigation Challenge:**
Explore cutting-edge isolation techniques for multi-tenancy:

**Technique 1: Virtual Clusters**
Research virtual cluster solutions (vCluster, Kamaji) that provide cluster-level isolation within a single physical cluster.

**Technique 2: Sandboxing Technologies**
Investigate container sandboxing (Kata Containers, gVisor) for stronger isolation.

**Technique 3: Service Mesh Tenancy**
Explore how service meshes (Istio, Linkerd) can provide additional tenant isolation.

**Analysis Questions:**
1. When would you choose virtual clusters over namespace-based tenancy?
2. What are the performance implications of different isolation techniques?
3. How do these techniques affect operational complexity?

## Part 6: Real-World Application

### Comprehensive Scenario: SaaS Platform Architecture

**Your Ultimate Challenge:**
Design and implement a complete multi-tenant SaaS platform:

**Platform Requirements:**
- **Scale:** Support 1000+ tenants across multiple tiers
- **Compliance:** Meet SOC 2, GDPR, and industry-specific requirements
- **Performance:** 99.9% uptime SLA with performance guarantees
- **Economics:** Optimize costs while maintaining margins
- **Operations:** Minimize operational overhead through automation
- **Global:** Support multiple regions with data residency requirements

**Business Model:**
- **Free Tier:** Limited resources, shared infrastructure
- **Standard Tier:** Dedicated resources, basic SLAs
- **Premium Tier:** Enhanced resources, stronger SLAs
- **Enterprise Tier:** Custom resources, dedicated support, compliance features

**Architecture Design Phase:**

**Step 1: Multi-Cluster Strategy**
```yaml
# cluster-strategy.yaml
# Production Clusters by Region
regions:
  us-east:
    clusters:
      - prod-us-east-1    # Primary production
      - prod-us-east-2    # DR/overflow
  eu-west:
    clusters:
      - prod-eu-west-1    # GDPR compliance
  ap-southeast:
    clusters:
      - prod-ap-se-1      # APAC region

# Tenant placement strategy
tenant_placement:
  free_tier:
    cluster_type: "shared-multi-tenant"
    isolation_level: "namespace"
    max_tenants_per_cluster: 500
  standard_tier:
    cluster_type: "dedicated-multi-tenant"  
    isolation_level: "namespace"
    max_tenants_per_cluster: 100
  premium_tier:
    cluster_type: "dedicated-multi-tenant"
    isolation_level: "enhanced-namespace"
    max_tenants_per_cluster: 50
  enterprise_tier:
    cluster_type: "dedicated-single-tenant"
    isolation_level: "virtual-cluster"
    max_tenants_per_cluster: 1
```

**Step 2: Tenant Lifecycle Management**
```bash
#!/bin/bash
# enterprise-tenant-lifecycle.sh

# Complete tenant lifecycle management system

tenant_create() {
    local tenant_id=$1
    local tier=$2
    local region=$3
    local compliance_level=$4
    
    echo "Creating tenant: $tenant_id in $region with $tier tier"
    
    # Select appropriate cluster
    cluster=$(select_cluster $tier $region)
    
    # Generate tenant configuration
    generate_tenant_config $tenant_id $tier $compliance_level > tenant-$tenant_id.yaml
    
    # Apply to selected cluster
    kubectl apply -f tenant-$tenant_id.yaml --context=$cluster
    
    # Setup monitoring and alerting
    setup_tenant_monitoring $tenant_id $cluster
    
    # Configure backup policies
    setup_tenant_backup $tenant_id $tier
    
    # Register in billing system
    register_billing $tenant_id $tier
    
    echo "Tenant $tenant_id created successfully"
}

tenant_upgrade() {
    local tenant_id=$1
    local new_tier=$2
    
    echo "Upgrading tenant $tenant_id to $new_tier"
    
    # May require migration to different cluster
    current_cluster=$(get_tenant_cluster $tenant_id)
    target_cluster=$(select_cluster $new_tier $(get_tenant_region $tenant_id))
    
    if [ "$current_cluster" != "$target_cluster" ]; then
        migrate_tenant $tenant_id $current_cluster $target_cluster
    else
        update_tenant_resources $tenant_id $new_tier
    fi
    
    # Update billing
    update_billing $tenant_id $new_tier
}

tenant_migrate() {
    local tenant_id=$1
    local source_cluster=$2
    local target_cluster=$3
    
    echo "Migrating tenant $tenant_id from $source_cluster to $target_cluster"
    
    # Create maintenance window
    enable_maintenance_mode $tenant_id
    
    # Backup current state
    backup_tenant $tenant_id $source_cluster
    
    # Create resources in target cluster
    kubectl apply -f tenant-$tenant_id.yaml --context=$target_cluster
    
    # Migrate data
    migrate_tenant_data $tenant_id $source_cluster $target_cluster
    
    # Update DNS/routing
    update_tenant_routing $tenant_id $target_cluster
    
    # Validate migration
    validate_tenant_migration $tenant_id $target_cluster
    
    # Cleanup source
    cleanup_source_tenant $tenant_id $source_cluster
    
    # Exit maintenance mode
    disable_maintenance_mode $tenant_id
}
```

**Step 3: Advanced Resource Management**
```yaml
# advanced-resource-management.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: tenant-resource-policies
  namespace: platform-system
data:
  resource-allocation.yaml: |
    # Resource allocation matrix
    tiers:
      free:
        base_cpu: "100m"
        base_memory: "256Mi"
        burst_multiplier: 2
        storage: "1Gi"
        priority_class: "tenant-free"
      standard:
        base_cpu: "500m"
        base_memory: "1Gi"
        burst_multiplier: 3
        storage: "10Gi"
        priority_class: "tenant-standard"
      premium:
        base_cpu: "2000m"
        base_memory: "4Gi"
        burst_multiplier: 4
        storage: "100Gi"
        priority_class: "tenant-premium"
        dedicated_nodes: true
      enterprise:
        base_cpu: "8000m"
        base_memory: "16Gi"
        burst_multiplier: 5
        storage: "1Ti"
        priority_class: "tenant-enterprise"
        dedicated_cluster: true
        
    # Auto-scaling policies
    auto_scaling:
      free:
        enabled: false
      standard:
        enabled: true
        min_replicas: 1
        max_replicas: 5
      premium:
        enabled: true
        min_replicas: 2
        max_replicas: 20
      enterprise:
        enabled: true
        min_replicas: 3
        max_replicas: 100
        custom_metrics: true
---
# Dynamic resource allocation operator
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-allocation-operator
  namespace: platform-system
spec:
  template:
    spec:
      containers:
      - name: operator
        image: platform/resource-operator:v1.0
        env:
        - name: ALLOCATION_POLICY_CONFIG
          value: "/etc/config/resource-allocation.yaml"
        volumeMounts:
        - name: config
          mountPath: /etc/config
      volumes:
      - name: config
        configMap:
          name: tenant-resource-policies
```

**Step 4: Comprehensive Monitoring and Observability**
```yaml
# tenant-monitoring-stack.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: tenant-monitoring
  labels:
    type: shared-services
    service-category: monitoring
---
# Multi-tenant Prometheus configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: tenant-monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
    
    # Tenant-aware scraping
    scrape_configs:
    - job_name: 'tenant-applications'
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      # Only scrape pods in tenant namespaces
      - source_labels: [__meta_kubernetes_namespace]
        regex: 'tenant-.*'
        action: keep
      # Add tenant ID label
      - source_labels: [__meta_kubernetes_namespace]
        regex: 'tenant-(.*)'
        target_label: tenant_id
      # Tenant isolation for metrics
      - source_labels: [tenant_id]
        target_label: __tmp_tenant
      - source_labels: [__tmp_tenant]
        regex: '(.*)'
        replacement: 'tenant-${1}'
        target_label: __metrics_path__
        
    # Separate recording rules per tenant tier
    rule_files:
    - "/etc/prometheus/rules/tenant-*.yml"
---
# Grafana dashboard provisioning
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboards
  namespace: tenant-monitoring
data:
  tenant-overview.json: |
    {
      "dashboard": {
        "title": "Tenant Overview",
        "templating": {
          "list": [
            {
              "name": "tenant",
              "type": "query",
              "query": "label_values(tenant_id)",
              "multi": false
            }
          ]
        },
        "panels": [
          {
            "title": "Resource Usage",
            "targets": [
              {
                "expr": "sum by (resource) (kube_pod_container_resource_requests{namespace=\"tenant-$tenant\"})"
              }
            ]
          }
        ]
      }
    }
```

**Implementation Validation:**

**Step 5: End-to-End Testing Framework**
```bash
#!/bin/bash
# e2e-testing-framework.sh

# Comprehensive testing of multi-tenant platform

test_tenant_isolation() {
    echo "Testing tenant isolation..."
    
    # Create test tenants
    create_test_tenant "test-tenant-a" "standard"
    create_test_tenant "test-tenant-b" "standard"
    
    # Deploy applications
    deploy_test_app "test-tenant-a" "app-a"
    deploy_test_app "test-tenant-b" "app-b"
    
    # Test network isolation
    test_network_isolation "test-tenant-a" "test-tenant-b"
    
    # Test resource isolation
    test_resource_isolation "test-tenant-a" "test-tenant-b"
    
    # Test data isolation
    test_data_isolation "test-tenant-a" "test-tenant-b"
    
    # Cleanup
    cleanup_test_tenant "test-tenant-a"
    cleanup_test_tenant "test-tenant-b"
}

test_scale_behavior() {
    echo "Testing scale behavior..."
    
    # Create multiple tenants rapidly
    for i in $(seq 1 50); do
        create_test_tenant "scale-test-$i" "free" &
    done
    wait
    
    # Verify all tenants are healthy
    verify_tenant_health "scale-test-*"
    
    # Test resource contention
    generate_load "scale-test-*"
    
    # Verify SLA compliance
    check_sla_compliance "scale-test-*"
    
    # Cleanup
    cleanup_test_tenants "scale-test-*"
}

test_tier_upgrades() {
    echo "Testing tier upgrades..."
    
    create_test_tenant "upgrade-test" "free"
    
    # Test upgrade path: free -> standard -> premium -> enterprise
    for tier in "standard" "premium" "enterprise"; do
        upgrade_tenant "upgrade-test" "$tier"
        verify_tier_capabilities "upgrade-test" "$tier"
    done
    
    # Test downgrade path
    for tier in "premium" "standard" "free"; do
        downgrade_tenant "upgrade-test" "$tier"
        verify_tier_capabilities "upgrade-test" "$tier"
    done
    
    cleanup_test_tenant "upgrade-test"
}

test_compliance_controls() {
    echo "Testing compliance controls..."
    
    # Create tenants with different compliance requirements
    create_test_tenant "hipaa-test" "premium" "us-east" "hipaa"
    create_test_tenant "gdpr-test" "standard" "eu-west" "gdpr"
    create_test_tenant "pci-test" "enterprise" "us-east" "pci"
    
    # Test compliance policy enforcement
    test_hipaa_compliance "hipaa-test"
    test_gdpr_compliance "gdpr-test"  
    test_pci_compliance "pci-test"
    
    # Test data residency
    verify_data_residency "gdpr-test" "eu-west"
    verify_data_residency "hipaa-test" "us-east"
    
    cleanup_test_tenant "hipaa-test"
    cleanup_test_tenant "gdpr-test"
    cleanup_test_tenant "pci-test"
}

# Run all tests
run_all_tests() {
    echo "=== Multi-Tenant Platform E2E Testing ==="
    
    test_tenant_isolation
    test_scale_behavior
    test_tier_upgrades  
    test_compliance_controls
    
    echo "=== All Tests Completed ==="
}

run_all_tests
```

### Advanced Challenge: Global Multi-Tenant Architecture

**Scenario Extension:**
Your SaaS platform expands globally with these additional complexities:
- **Data Sovereignty:** Some tenants' data cannot leave specific geographic regions
- **Cross-Region Replication:** Enterprise tenants need disaster recovery across regions
- **Edge Computing:** Some workloads need to run close to end users
- **Regulatory Variations:** Different regions have different compliance requirements
- **Cost Optimization:** Resource costs vary significantly between regions

**Global Architecture Considerations:**
1. How would you design tenant placement across regions?
2. What strategies would handle cross-region data replication while respecting sovereignty?
3. How would you optimize costs across regions with different pricing models?
4. What operational procedures would manage global incidents and maintenance?

## Unit Assessment

### Practical Multi-Tenancy Implementation

**Comprehensive Assessment Challenge:**
Design and implement a complete multi-tenant platform:

1. **Architecture Phase:**
   - Design tenant isolation strategy for 100+ tenants
   - Plan resource sharing and optimization approach
   - Create governance and compliance framework

2. **Implementation Phase:**
   - Build automated tenant onboarding system
   - Implement comprehensive monitoring and billing
   - Create self-service portal with appropriate guardrails

3. **Validation Phase:**
   - Demonstrate tenant isolation working correctly
   - Show resource optimization and fair sharing
   - Prove compliance controls and audit capabilities

### Multi-Tenancy Scenarios

**Advanced Scenario Assessment:**
1. **Growth Challenge:** Scale from 10 to 1000 tenants. What breaks? How do you fix it?

2. **Compliance Emergency:** A major compliance violation is discovered affecting multiple tenants. How do you respond?

3. **Resource Crunch:** Your cluster is at capacity but you have urgent tenant onboarding needs. How do you handle this?

4. **Acquisition Integration:** Your company acquires another SaaS provider with different multi-tenancy patterns. How do you integrate?

### Knowledge Integration Questions

1. **Economics Question:** How do you balance platform costs with tenant value to maintain profitable unit economics?

2. **Technology Evolution:** How would you migrate your multi-tenancy model to adopt new Kubernetes features or different isolation technologies?

3. **Organizational Scaling:** How does your multi-tenancy approach change as your engineering team grows from 5 to 50 people?

### Preparation for Unit 9

**Preview Questions:**
1. How do you manage the lifecycle of hundreds of tenant namespaces?
2. What automation is needed to keep multi-tenant environments healthy?
3. How would you implement zero-downtime updates across all tenants?

**Coming Next:** In Unit 9, we'll explore Lifecycle Management, learning to automate namespace lifecycle operations, implement environment progression patterns, and create robust backup and disaster recovery strategies.

## Quick Reference

### Multi-Tenancy Patterns
```bash
# Tenant namespace creation
kubectl create namespace tenant-${TENANT_ID}
kubectl label namespace tenant-${TENANT_ID} tenant-id=${TENANT_ID} tier=${TIER}

# Resource quota per tenant  
kubectl create quota tenant-quota --hard=cpu=2,memory=4Gi -n tenant-${TENANT_ID}

# Network isolation
kubectl apply -f tenant-network-policy.yaml -n tenant-${TENANT_ID}
```

### Tenant Management Commands
```bash
# List all tenants
kubectl get namespaces -l tenant-id

# Get tenant resource usage
kubectl top pods -n tenant-${TENANT_ID}
kubectl describe quota -n tenant-${TENANT_ID}

# Tenant-specific operations
kubectl get all -n tenant-${TENANT_ID}
kubectl logs -f deployment/app -n tenant-${TENANT_ID}
```

### Governance and Compliance
```yaml
# Policy enforcement example
apiVersion: kyverno.io/v1
kind: Policy
metadata:
  name: tenant-policies
spec:
  validationFailureAction: enforce
  rules:
  - name: require-tenant-labels
    match:
      resources:
        kinds: [Namespace]
        names: ["tenant-*"]
    validate:
      pattern:
        metadata:
          labels:
            tenant-id: "?*"
```

### Monitoring Queries
```promql
# Resource usage by tenant
sum by (tenant_id) (kube_pod_container_resource_requests{namespace=~"tenant-.*"})

# Tenant SLA compliance
up{namespace=~"tenant-.*"} * 100

# Cost allocation by tenant
sum by (tenant_id) (rate(container_cpu_usage_seconds_total{namespace=~"tenant-.*"}[5m]))
```