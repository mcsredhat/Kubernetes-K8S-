# Unit 5: Security Deep Dive and RBAC

## Learning Objectives
- Understand Kubernetes Secrets security limitations and real-world implications
- Master RBAC configuration for granular secret access control
- Implement security best practices for production environments
- Learn threat modeling for secret management
- Practice security incident response scenarios

## Pre-Unit Security Assessment

Before diving deep into security, let's assess your current security mindset with some realistic scenarios:

**Scenario 1**: A developer accidentally runs `kubectl get secret database-password -o yaml` in a Slack channel. The base64 encoded password is visible in the channel history. What's your immediate response plan?

**Scenario 2**: Your monitoring system detects that a pod is repeatedly failing to start with "secret not found" errors, but when you check, the secret exists. What security implications should you consider?

**Scenario 3**: A former employee had cluster admin access and may have had the ability to view all secrets before their access was revoked. How do you assess and respond to this potential exposure?

Take a moment to think through these scenarios. What questions come to mind? What would be your first steps in each case?

## Understanding the Security Model

### The Truth About Base64 "Security"

Let's start with a fundamental truth that many Kubernetes tutorials gloss over:

**Critical Understanding**: Base64 encoding is NOT encryption. It's simply a way to represent binary data in text format.

Let's demonstrate this clearly:

```bash
# Create a secret with a "secure" password
kubectl create secret generic security-demo \
  --from-literal=password="super_secret_password_123"

# View the "encoded" value
kubectl get secret security-demo -o yaml

# Anyone can decode this instantly
echo "c3VwZXJfc2VjcmV0X3Bhc3N3b3JkXzEyMw==" | base64 -d
```

**Reflection Question**: Given this limitation, why do you think Kubernetes Secrets are still valuable? What protection do they actually provide?

<details>
<summary>Security benefits despite base64 limitations</summary>

- Separation from application code and container images
- Protection against accidental disclosure in logs (when properly configured)
- Integration with RBAC for access control
- Structured approach to sensitive data management  
- Foundation for encryption at rest (when etcd encryption is enabled)
- Better than hardcoded credentials or plain ConfigMaps

</details>

### Encryption at Rest: The Missing Piece

In production clusters, you should enable etcd encryption to protect secrets at the storage layer:

```yaml
# etcd-encryption-config.yaml (cluster-level configuration)
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources:
  - secrets
  providers:
  - aescbc:
      keys:
      - name: key1
        secret: <base64-encoded-32-byte-key>
  - identity: {}  # Fallback for reading unencrypted data
```

**Important**: This configuration is applied at the cluster level during setup, not through regular kubectl commands.

**Discussion Questions**:
1. Why isn't encryption at rest enabled by default in Kubernetes?
2. What operational considerations come with enabling encryption at rest?
3. How does this change your threat model?

## RBAC Deep Dive: Building Secure Access Controls

Role-Based Access Control is your primary tool for controlling who can access secrets. Let's build a comprehensive RBAC strategy.

### Designing Role Hierarchies

Before implementing RBAC, let's think through role design. Consider these personas in a typical organization:

- **Platform Administrators**: Full cluster access (should be minimal)
- **DevOps Engineers**: Deployment and infrastructure management
- **Developers**: Application development and testing
- **Applications**: Runtime access to their own secrets
- **CI/CD Systems**: Automated deployment capabilities
- **Security Auditors**: Read-only access for compliance

**Design Challenge**: How would you structure roles for these personas? What principles would guide your decisions?

### Implementing Layered Security

```yaml
# comprehensive-rbac.yaml
# Base role for secret reading (building block)
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: secret-reader-base
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]
---
# Developer role - limited to non-production
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: development
  name: developer-secret-manager
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
  # No resourceNames restriction - developers need flexibility in dev
---
# Application-specific role - production ready
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: webapp-secret-access
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["webapp-database", "webapp-api-keys", "webapp-tls"]
  verbs: ["get"]
  # Notice: only GET, only specific secrets
---
# DevOps role - production operations
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: devops-secret-ops
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "create", "update", "patch"]
  # Notice: no DELETE - prevents accidental removal
- apiGroups: [""]
  resources: ["events"]
  verbs: ["get", "list"]
  # Allow viewing events related to secret operations
---
# Audit role - compliance and security
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: security-auditor
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["events"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]
  verbs: ["get", "list"]
```

**Analysis Exercise**: 
1. Review each role definition. What security principles do you see implemented?
2. Which roles follow the principle of least privilege? Which might be too permissive?
3. How would you test these roles to ensure they work as intended?

### Testing RBAC Configurations

Security configurations should be tested thoroughly. Here's how to validate your RBAC setup:

```bash
#!/bin/bash
# rbac-test.sh

# Create test service accounts
kubectl create serviceaccount developer-sa -n development
kubectl create serviceaccount webapp-sa -n production
kubectl create serviceaccount devops-sa -n production

# Bind to appropriate roles
kubectl create rolebinding developer-secrets \
  --role=developer-secret-manager \
  --serviceaccount=development:developer-sa \
  -n development

kubectl create rolebinding webapp-secrets \
  --role=webapp-secret-access \
  --serviceaccount=production:webapp-sa \
  -n production

# Test permissions
echo "🧪 Testing developer permissions in development..."
kubectl auth can-i create secrets --as=system:serviceaccount:development:developer-sa -n development
kubectl auth can-i delete secrets --as=system:serviceaccount:development:developer-sa -n development
kubectl auth can-i get secrets --as=system:serviceaccount:development:developer-sa -n production

echo "🧪 Testing webapp permissions in production..."
kubectl auth can-i get secret webapp-database --as=system:serviceaccount:production:webapp-sa -n production
kubectl auth can-i delete secret webapp-database --as=system:serviceaccount:production:webapp-sa -n production
kubectl auth can-i get secret other-app-secrets --as=system:serviceaccount:production:webapp-sa -n production

echo "🧪 Testing cross-namespace access..."
kubectl auth can-i get secrets --as=system:serviceaccount:production:webapp-sa -n development
```

**Hands-On Challenge**: Run these tests and analyze the results. What do the results tell you about your RBAC configuration? Are there any surprises?

## Security Best Practices Implementation

### Practice 1: Secret Hygiene

Let's implement a comprehensive secret hygiene checklist:

```bash
#!/bin/bash
# secret-security-audit.sh

echo "🔍 Performing Secret Security Audit"

# Check for secrets with overly broad RBAC
echo "Checking RBAC permissions..."
kubectl get rolebindings,clusterrolebindings -o wide | grep -E "(secrets|*)"

# Find secrets that might be too permissive
echo "Checking secret access patterns..."
kubectl get secrets --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{" "}{.type}{"\n"}{end}' | \
  while read namespace name type; do
    if [[ "$type" == "Opaque" ]]; then
      echo "Auditing: $namespace/$name"
      # Check if secret is actually being used
      kubectl get pods -n "$namespace" -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.volumes[*].secret.secretName}{" "}{.spec.containers[*].envFrom[*].secretRef.name}{"\n"}{end}' | \
        grep -q "$name" || echo "⚠️  Unused secret: $namespace/$name"
    fi
  done

# Check for secrets without appropriate labels
echo "Checking secret metadata..."
kubectl get secrets --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{" "}{.metadata.labels}{"\n"}{end}' | \
  grep -v "owner\|app\|environment" | head -5
```

**Implementation Exercise**: Run this audit script on your cluster. What issues does it identify? How would you address them?

### Practice 2: Monitoring Secret Access

Security requires visibility. Let's implement secret access monitoring:

```yaml
# secret-monitoring.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: secret-audit-policy
  namespace: kube-system
data:
  audit-policy.yaml: |
    apiVersion: audit.k8s.io/v1
    kind: Policy
    rules:
    - level: Metadata
      namespaces: ["production", "staging"]
      resources:
      - group: ""
        resources: ["secrets"]
      verbs: ["get", "list", "create", "update", "patch", "delete"]
    - level: Request
      namespaces: ["production"]
      resources:
      - group: ""
        resources: ["secrets"]
      verbs: ["create", "update", "patch", "delete"]
```

**Note**: Audit logging requires cluster-level configuration and is typically configured during cluster setup.

For application-level monitoring, you can implement custom logging:

```yaml
# secret-access-logger.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secret-access-logger
spec:
  replicas: 1
  selector:
    matchLabels:
      app: secret-access-logger
  template:
    metadata:
      labels:
        app: secret-access-logger
    spec:
      serviceAccountName: security-auditor
      containers:
      - name: logger
        image: alpine:latest
        command:
        - /bin/sh
        - -c
        - |
          while true; do
            echo "$(date): Auditing secret access..."
            kubectl get events --all-namespaces --field-selector involvedObject.kind=Secret
            sleep 300  # Check every 5 minutes
          done
```

## Threat Modeling for Secret Management

Let's systematically think through potential threats to your secret management system.

### Threat Categories

**Internal Threats**:
- Malicious insiders with cluster access
- Compromised developer accounts
- Accidental exposure through logging or debugging

**External Threats**:
- Compromised container images
- Supply chain attacks
- Cluster compromise through vulnerable components

**Operational Threats**:
- Misconfigured RBAC
- Secrets in version control
- Unencrypted backups

**Assessment Exercise**: For each threat category, design detection and mitigation strategies. What controls would you implement?

### Incident Response Scenarios

Let's practice responding to security incidents involving secrets:

#### Scenario 1: Suspected Secret Exposure

```bash
#!/bin/bash
# incident-response-secret-exposure.sh

echo "🚨 INCIDENT RESPONSE: Suspected Secret Exposure"
echo "Incident ID: INC-$(date +%Y%m%d-%H%M%S)"

AFFECTED_SECRET=${1:-"database-password"}
NAMESPACE=${2:-"production"}

echo "📋 Step 1: Immediate containment"
echo "Affected Secret: $AFFECTED_SECRET in namespace $NAMESPACE"

# Document current state
kubectl get secret "$AFFECTED_SECRET" -n "$NAMESPACE" -o yaml > "incident-evidence-$(date +%s).yaml"

# Check who has access to this secret
echo "📋 Step 2: Access assessment"
kubectl get rolebindings,clusterrolebindings --all-namespaces -o yaml | \
  grep -A 10 -B 10 "$AFFECTED_SECRET" || echo "No explicit secret name bindings found"

# Find pods using this secret
echo "📋 Step 3: Impact assessment"
kubectl get pods -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{" uses secrets: "}{.spec.containers[*].envFrom[*].secretRef.name}{" "}{.spec.volumes[*].secret.secretName}{"\n"}{end}' | \
  grep "$AFFECTED_SECRET" && echo "☝️ These pods are using the affected secret"

echo "📋 Step 4: Rotation preparation"
echo "Manual steps required:"
echo "1. Generate new secret values"
echo "2. Update external systems (databases, APIs) with new credentials"
echo "3. Execute rotation script"
echo "4. Verify all applications are functioning"
echo "5. Document lessons learned"
```

**Practice Exercise**: Run this incident response script with different parameters. What additional information would you want to collect? What steps are missing?

#### Scenario 2: RBAC Breach

```bash
#!/bin/bash
# rbac-breach-response.sh

echo "🚨 RBAC BREACH DETECTED"

SUSPICIOUS_ACCOUNT=${1:-"suspicious-service-account"}
NAMESPACE=${2:-"default"}

echo "📊 Analyzing permissions for: $SUSPICIOUS_ACCOUNT"

# Check current permissions
kubectl auth can-i --list --as="system:serviceaccount:$NAMESPACE:$SUSPICIOUS_ACCOUNT"

# Find all bindings for this account
kubectl get rolebindings,clusterrolebindings --all-namespaces -o yaml | \
  grep -A 20 -B 5 "$SUSPICIOUS_ACCOUNT"

echo "🔒 Immediate lockdown options:"
echo "1. Delete service account: kubectl delete serviceaccount $SUSPICIOUS_ACCOUNT -n $NAMESPACE"
echo "2. Remove role bindings: kubectl delete rolebinding <binding-name> -n $NAMESPACE"
echo "3. Create deny policy (if admission controller supports it)"

echo "🔍 Investigation actions:"
echo "1. Check audit logs for recent activities by this account"
echo "2. Review how this account was created and by whom"
echo "3. Assess blast radius - what secrets could have been accessed"
```

## Mini-Project 6: Security Hardening Implementation

Let's implement a comprehensive security hardening project that demonstrates mastery of Kubernetes secret security.

**Project Requirements**:
1. **Multi-layered RBAC**: Implement proper role separation
2. **Security Monitoring**: Set up secret access monitoring
3. **Automated Security Checks**: Create scripts for ongoing security validation
4. **Incident Response**: Prepare runbooks for common security scenarios
5. **Compliance Reporting**: Generate reports for security audits

### Implementation Framework

```yaml
# security-hardened-environment.yaml
# Namespace with security labels
apiVersion: v1
kind: Namespace
metadata:
  name: secure-production
  labels:
    security-level: "high"
    compliance: "required"
    audit: "enabled"
---
# Network policy to restrict secret access (if CNI supports)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: secret-access-restriction
  namespace: secure-production
spec:
  podSelector:
    matchLabels:
      access-secrets: "true"
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: secure-production
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: secure-production
---
# Pod Security Policy for secret-accessing pods
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: restricted-secret-access
spec:
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
    - ALL
  volumes:
    - 'secret'
    - 'configMap'
    - 'emptyDir'
    - 'projected'
  runAsUser:
    rule: 'MustRunAsNonRoot'
  seLinux:
    rule: 'RunAsAny'
  fsGroup:
    rule: 'RunAsAny'
---
# Service account with minimal permissions
apiVersion: v1
kind: ServiceAccount
metadata:
  name: secure-app
  namespace: secure-production
  annotations:
    security.alpha.kubernetes.io/sysctls: ""
    security.alpha.kubernetes.io/unsafe-sysctls: ""
---
# Minimal role for application
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: secure-production
  name: secure-app-role
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["app-database-creds", "app-api-keys"]
  verbs: ["get"]
---
# Role binding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: secure-app-binding
  namespace: secure-production
subjects:
- kind: ServiceAccount
  name: secure-app
  namespace: secure-production
roleRef:
  kind: Role
  name: secure-app-role
  apiGroup: rbac.authorization.k8s.io
```

### Security Validation Scripts

```bash
#!/bin/bash
# security-validation-suite.sh

echo "🛡️  Kubernetes Secrets Security Validation Suite"
echo "=================================================="

# Test 1: RBAC Validation
echo "📋 Test 1: RBAC Configuration Validation"
validate_rbac() {
    local namespace=$1
    local service_account=$2
    
    echo "Validating RBAC for $service_account in $namespace..."
    
    # Test overprivileged access
    if kubectl auth can-i "*" "*" --as="system:serviceaccount:$namespace:$service_account" 2>/dev/null; then
        echo "❌ FAIL: Service account has wildcard permissions"
        return 1
    fi
    
    # Test cross-namespace access
    if kubectl auth can-i get secrets --as="system:serviceaccount:$namespace:$service_account" -n kube-system 2>/dev/null; then
        echo "❌ FAIL: Service account can access system namespace"
        return 1
    fi
    
    # Test secret creation (should usually be denied)
    if kubectl auth can-i create secrets --as="system:serviceaccount:$namespace:$service_account" -n "$namespace" 2>/dev/null; then
        echo "⚠️  WARNING: Service account can create secrets"
    fi
    
    echo "✅ PASS: RBAC validation completed"
}

# Test 2: Secret Content Security
echo "📋 Test 2: Secret Content Analysis"
validate_secret_content() {
    echo "Scanning for insecure secret patterns..."
    
    # Check for secrets with obvious weak passwords
    kubectl get secrets --all-namespaces -o yaml | \
    while IFS= read -r line; do
        if [[ $line =~ cGFzc3dvcmQ= ]] || [[ $line =~ MTIzNDU2 ]]; then  # base64 for "password" and "123456"
            echo "❌ FAIL: Weak password pattern detected"
            return 1
        fi
    done
    
    # Check for secrets without proper labels
    kubectl get secrets --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{" "}{.metadata.labels.app}{"\n"}{end}' | \
    while read namespace name app; do
        if [[ -z "$app" && "$name" != "default-token"* ]]; then
            echo "⚠️  WARNING: Secret $namespace/$name lacks app label"
        fi
    done
    
    echo "✅ PASS: Secret content analysis completed"
}

# Test 3: Network Security
echo "📋 Test 3: Network Security Validation"
validate_network_security() {
    echo "Checking network policies affecting secret access..."
    
    # Look for network policies in production namespaces
    local production_namespaces=$(kubectl get namespaces -l environment=production -o name 2>/dev/null | cut -d/ -f2)
    
    for ns in $production_namespaces; do
        local policies=$(kubectl get networkpolicies -n "$ns" -o name 2>/dev/null | wc -l)
        if [[ $policies -eq 0 ]]; then
            echo "⚠️  WARNING: No network policies in production namespace $ns"
        else
            echo "✅ Network policies found in $ns"
        fi
    done
}

# Test 4: Audit Configuration
echo "📋 Test 4: Audit and Monitoring Validation"
validate_audit_config() {
    echo "Checking audit configuration for secret operations..."
    
    # Check if audit logging is enabled (cluster-dependent)
    if kubectl get events --all-namespaces --field-selector involvedObject.kind=Secret | grep -q "Secret"; then
        echo "✅ Secret-related events are being recorded"
    else
        echo "⚠️  WARNING: No recent secret-related events found (may indicate audit gaps)"
    fi
    
    # Check for monitoring pods that could track secret access
    if kubectl get pods --all-namespaces -l app=secret-monitor -o name 2>/dev/null | grep -q "pod/"; then
        echo "✅ Secret monitoring components detected"
    else
        echo "⚠️  WARNING: No dedicated secret monitoring detected"
    fi
}

# Run all tests
validate_rbac "secure-production" "secure-app"
validate_secret_content
validate_network_security  
validate_audit_config

echo "🏁 Security validation suite completed"
```

**Hands-On Challenge**: Implement and run this security validation suite. What issues does it identify in your cluster? How would you address each finding?

## Advanced Security Patterns

### Pattern 1: Secret Attestation

Implement a system that validates secrets before they're used:

```yaml
# secret-attestation-webhook.yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionWebhook
metadata:
  name: secret-attestation
webhooks:
- name: secret-attestation.security.company.com
  clientConfig:
    service:
      name: secret-attestation-service
      namespace: security-system
      path: "/validate-secret"
  rules:
  - operations: ["CREATE", "UPDATE"]
    apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["secrets"]
  admissionReviewVersions: ["v1", "v1beta1"]
```

**Implementation Note**: This requires developing a webhook service that validates secret content against your security policies.

### Pattern 2: Zero-Trust Secret Access

Implement continuous verification of secret access:

```yaml
# zero-trust-secret-access.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: secret-access-policy
data:
  policy.rego: |
    package kubernetes.secrets
    
    # Deny access to secrets outside business hours
    deny[msg] {
        input.request.kind.kind == "Secret"
        input.request.operation == "GET"
        time.hour(time.now_ns()) < 8
        time.hour(time.now_ns()) > 18
        msg := "Secret access denied outside business hours"
    }
    
    # Require MFA for production secret access
    deny[msg] {
        input.request.namespace == "production"
        input.request.kind.kind == "Secret"
        not input.request.userInfo.extra.mfa_verified[_] == "true"
        msg := "MFA required for production secret access"
    }
```

**Discussion**: How would you implement the MFA verification in this policy? What operational challenges would this create?

### Pattern 3: Secret Lifecycle Management

Implement automated secret lifecycle management:

```bash
#!/bin/bash
# secret-lifecycle-manager.sh

echo "🔄 Secret Lifecycle Management System"

# Configuration
MAX_SECRET_AGE_DAYS=90
WARNING_DAYS=14

# Function to check secret age
check_secret_age() {
    local namespace=$1
    local secret_name=$2
    
    local creation_time=$(kubectl get secret "$secret_name" -n "$namespace" -o jsonpath='{.metadata.creationTimestamp}')
    local creation_epoch=$(date -d "$creation_time" +%s)
    local current_epoch=$(date +%s)
    local age_days=$(( (current_epoch - creation_epoch) / 86400 ))
    
    echo "Secret $namespace/$secret_name is $age_days days old"
    
    if [[ $age_days -gt $MAX_SECRET_AGE_DAYS ]]; then
        echo "🚨 CRITICAL: Secret $namespace/$secret_name is overdue for rotation"
        # Trigger rotation workflow
        trigger_secret_rotation "$namespace" "$secret_name"
    elif [[ $age_days -gt $((MAX_SECRET_AGE_DAYS - WARNING_DAYS)) ]]; then
        echo "⚠️  WARNING: Secret $namespace/$secret_name needs rotation soon"
        # Send notification
        notify_secret_expiration "$namespace" "$secret_name" "$age_days"
    fi
}

# Function to trigger rotation
trigger_secret_rotation() {
    local namespace=$1
    local secret_name=$2
    
    echo "🔄 Initiating automated rotation for $namespace/$secret_name"
    
    # Create rotation job
    kubectl create job "rotate-$secret_name-$(date +%s)" \
        --from=cronjob/secret-rotator \
        --dry-run=client -o yaml | \
        sed "s/SECRET_NAME_PLACEHOLDER/$secret_name/g" | \
        sed "s/NAMESPACE_PLACEHOLDER/$namespace/g" | \
        kubectl apply -f -
}

# Function to send notifications
notify_secret_expiration() {
    local namespace=$1
    local secret_name=$2
    local age_days=$3
    
    # In production, this would integrate with your alerting system
    echo "📧 Sending expiration notification for $namespace/$secret_name (age: $age_days days)"
    
    # Create Kubernetes event
    kubectl annotate secret "$secret_name" -n "$namespace" \
        "security.company.com/expiration-warning=$(date)" \
        "security.company.com/age-days=$age_days"
}

# Main execution
echo "Scanning all secrets for lifecycle management..."

kubectl get secrets --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}' | \
while read namespace name; do
    # Skip system secrets
    if [[ "$name" != "default-token"* ]] && [[ "$namespace" != "kube-"* ]]; then
        check_secret_age "$namespace" "$name"
    fi
done

echo "✅ Secret lifecycle scan completed"
```

## Comprehensive Security Assessment

Let's put together everything you've learned into a comprehensive security assessment framework.

### Security Maturity Model

Rate your organization's secret management maturity:

**Level 1 - Basic**:
- [ ] Secrets used instead of hardcoded passwords
- [ ] Basic RBAC configured
- [ ] Secrets not in version control

**Level 2 - Managed**:
- [ ] Environment-specific secret management
- [ ] Automated secret rotation
- [ ] Secret access monitoring
- [ ] Incident response procedures

**Level 3 - Advanced**:
- [ ] Zero-trust secret access
- [ ] External secret management integration
- [ ] Automated compliance reporting
- [ ] Continuous security validation

**Level 4 - Optimized**:
- [ ] AI-driven anomaly detection
- [ ] Predictive secret management
- [ ] Cross-cloud secret federation
- [ ] Advanced threat hunting

**Self-Assessment**: Where does your current setup fall on this maturity model? What would be your next steps to advance?

### Final Project: Complete Security Implementation

**Capstone Challenge**: Design and implement a production-ready secret security system that demonstrates mastery of all concepts covered in this unit.

**Requirements**:
1. **Multi-tier RBAC**: Different access levels for different personas
2. **Automated Monitoring**: Detection of unauthorized secret access
3. **Incident Response**: Automated and manual response procedures
4. **Compliance Reporting**: Generate audit reports for compliance
5. **Threat Detection**: Identify suspicious patterns in secret access
6. **Recovery Procedures**: Automated secret recovery and rotation

**Deliverables**:
- RBAC configuration files
- Monitoring and alerting setup
- Incident response runbooks
- Security validation scripts
- Compliance reporting tools
- Documentation and training materials

**Success Criteria**:
- Pass all security validation tests
- Demonstrate incident response procedures
- Generate compliance reports
- Show evidence of continuous monitoring
- Provide evidence of defense-in-depth implementation

## Real-World Integration Scenarios

### Scenario 1: Enterprise Migration

You're migrating a legacy enterprise application to Kubernetes. The application currently stores passwords in property files and connects to 15 different databases and 8 external APIs. How would you approach secret management for this migration?

**Challenge Elements**:
- Legacy systems that expect specific credential formats
- Compliance requirements (PCI DSS, SOX, etc.)
- Zero-downtime migration requirement
- Integration with existing identity providers
- Audit trail requirements

### Scenario 2: Multi-Cloud Deployment

Your application needs to deploy across AWS EKS, Google GKE, and Azure AKS, with secrets that include cloud-specific credentials and cross-cloud shared secrets. How would you design this?

**Challenge Elements**:
- Cloud-specific secret management integration
- Cross-cloud secret synchronization
- Different security models across clouds
- Disaster recovery across cloud providers
- Cost optimization for secret management

### Scenario 3: Startup to Scale

You're a platform engineer at a rapidly growing startup. You started with simple Kubernetes secrets, but now you need to support 50+ microservices, 5 environments, and 20+ developers. How do you evolve your secret management?

**Challenge Elements**:
- Scaling secret management processes
- Developer self-service requirements
- Cost management
- Security maturity evolution
- Integration with growing toolchain

## Reflection and Mastery Validation

Congratulations on completing the security deep dive! Let's validate your mastery:

**Technical Mastery Questions**:
1. Explain the security implications of different secret consumption patterns (env vars vs volume mounts)
2. Design an RBAC strategy for a multi-tenant Kubernetes cluster
3. Describe how you would detect and respond to a suspected secret compromise
4. Compare the security models of different external secret management solutions

**Strategic Thinking Questions**:
1. How would you justify the investment in advanced secret management to business stakeholders?
2. What metrics would you use to measure the success of your secret management strategy?
3. How do secret management practices fit into broader DevSecOps and platform engineering initiatives?

**Practical Application Questions**:
1. Walk through your incident response procedure for a confirmed secret exposure
2. Demonstrate how you would audit secret access across your entire cluster
3. Show how you would implement secret rotation for a critical production system

If you can confidently answer these questions and have completed the hands-on exercises, you've achieved mastery of Kubernetes secret security.

## Next Steps and Advanced Topics

You're now equipped with production-grade Kubernetes secret security knowledge. Here are areas for continued growth:

**Immediate Applications**:
- Implement these patterns in your current projects
- Conduct security assessments of existing Kubernetes deployments
- Contribute to your organization's security and compliance initiatives

**Advanced Learning Paths**:
- Kubernetes security certifications (CKS - Certified Kubernetes Security Specialist)
- Cloud security specializations (AWS, Azure, GCP security certifications)
- Security tool development (admission controllers, operators, etc.)

**Community Engagement**:
- Share your security implementations and lessons learned
- Contribute to open-source security tools
- Participate in Kubernetes security working groups

**Leadership Development**:
- Develop security training programs for your organization
- Lead security architecture discussions
- Build security culture and awareness

Remember: Security is not a destination but a continuous journey. The patterns and principles you've learned here will evolve, but the fundamental thinking processes and security mindset you've developed will serve you throughout your career.

The next unit will focus on troubleshooting and operational excellence, building on the secure foundation you've established here.