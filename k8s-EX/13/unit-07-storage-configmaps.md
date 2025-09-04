# Unit 7: Storage and ConfigMaps

## Learning Objectives
By the end of this unit, you will:
- Understand how storage resources interact with namespace boundaries
- Implement secure configuration management using ConfigMaps and Secrets
- Design data isolation strategies for multi-tenant environments
- Configure persistent storage with appropriate namespace policies
- Manage configuration lifecycle and versioning across namespaces

## Pre-Unit Data Thinking
Consider these data management scenarios:
1. How do you organize sensitive files in a shared computer system?
2. What happens when multiple applications need access to the same configuration data?
3. How would you ensure that one team's database doesn't interfere with another team's data?

## Part 1: Understanding Storage in Namespaces

### Discovery Exercise: Storage Scope Investigation

Let's explore how different storage resources behave with namespace boundaries:

**Step 1: Examine Storage Resource Scopes**
```bash
# Check which storage resources are namespace-scoped
kubectl api-resources --namespaced=true | grep -E "(configmap|secret|pvc)"
kubectl api-resources --namespaced=false | grep -E "(pv|storageclass|csi)"

# Explore existing storage resources
kubectl get pv  # Cluster-scoped
kubectl get pvc --all-namespaces  # Namespace-scoped
kubectl get configmaps --all-namespaces | head -10
kubectl get secrets --all-namespaces | head -10
```

**Investigation Questions:**
1. Why are PersistentVolumes cluster-scoped while PersistentVolumeClaims are namespace-scoped?
2. What implications does this have for data isolation?
3. How might this affect storage security and access control?

### Discovery Exercise: Default Storage Behavior

**Step 2: Create Test Namespaces with Storage**
```yaml
# storage-test-setup.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: storage-team-a
---
apiVersion: v1
kind: Namespace
metadata:
  name: storage-team-b
---
# ConfigMap in team-a
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: storage-team-a
data:
  database_url: "postgres://team-a-db:5432/appdb"
  log_level: "info"
---
# ConfigMap with same name in team-b
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config  # Same name, different namespace
  namespace: storage-team-b
data:
  database_url: "postgres://team-b-db:5432/appdb"
  log_level: "debug"
```

**Step 3: Test Cross-Namespace Access**
```bash
kubectl apply -f storage-test-setup.yaml

# Try to access ConfigMap from different namespaces
kubectl get configmap app-config -n storage-team-a
kubectl get configmap app-config -n storage-team-b

# Deploy pod that tries to mount ConfigMap from another namespace
kubectl run test-pod --image=busybox --rm -it -n storage-team-a -- ls /etc/config
# Mount ConfigMap from team-b namespace - what happens?
```

**Analysis Questions:**
1. Can pods access ConfigMaps from other namespaces?
2. What are the security implications of this behavior?
3. How does this support or hinder multi-tenancy?

## Part 2: ConfigMap and Secret Management

### Mini-Project 1: Secure Configuration Architecture

**Scenario:** You're managing configuration for a microservices application with these requirements:
- **Shared Configuration:** Common settings used by multiple services
- **Environment-Specific Config:** Different values for dev/staging/prod
- **Secret Configuration:** API keys, passwords, certificates
- **Team-Specific Config:** Settings unique to each team's services

**Design Challenge:**
Before implementing, consider:
1. How will you organize configuration to avoid duplication?
2. How will you handle configuration that needs to be shared across namespaces?
3. What security boundaries should exist for different types of configuration?

**Step 1: Hierarchical Configuration Design**
```yaml
# shared-config-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: shared-config
  labels:
    config-type: shared
    access-level: readonly
---
# Common configuration available to all applications
apiVersion: v1
kind: ConfigMap
metadata:
  name: common-config
  namespace: shared-config
data:
  timezone: "UTC"
  log_format: "json"
  monitoring_endpoint: "http://monitoring.shared-services:9090"
  tracing_enabled: "true"
---
# Environment-specific shared configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: environment-config
  namespace: shared-config
  labels:
    environment: development
data:
  debug_mode: "true"
  resource_limits: "low"
  external_api_endpoint: "https://dev-api.example.com"
```

**Step 2: Application-Specific Configuration**
```yaml
# app-specific-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-app-config
  namespace: storage-team-a
data:
  port: "8080"
  worker_processes: "2"
  cache_ttl: "300"
  feature_flags: |
    new_ui: true
    advanced_search: false
    beta_features: true
---
# Database configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: database-config
  namespace: storage-team-a
data:
  max_connections: "100"
  connection_timeout: "30"
  pool_size: "10"
```

**Step 3: Secret Management Strategy**
```yaml
# app-secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: web-app-secrets
  namespace: storage-team-a
type: Opaque
data:
  # Base64 encoded values
  database_password: cGFzc3dvcmQxMjM=  # password123
  api_key: YWJjZGVmZ2hpams=  # abcdefghijk
  jwt_secret: bXlzZWNyZXR0b2tlbg==  # mysecrettoken
---
# SSL/TLS certificates
apiVersion: v1
kind: Secret
metadata:
  name: tls-certificates
  namespace: storage-team-a
type: kubernetes.io/tls
data:
  tls.crt: LS0tLS1CRUdJTi... # Certificate data
  tls.key: LS0tLS1CRUdJTi... # Private key data
```

**Implementation Exercise:**
1. How would applications access shared configuration from other namespaces?
2. What mechanisms would you use to sync configuration across environments?
3. How would you implement configuration versioning and rollback?

### Discovery Exercise: Configuration Access Patterns

**Investigation Challenge:**
Explore different ways applications can consume configuration:

**Pattern A: Environment Variables**
```yaml
# env-var-pattern.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-with-env-vars
  namespace: storage-team-a
spec:
  template:
    spec:
      containers:
      - name: app
        image: nginx
        env:
        - name: DATABASE_URL
          valueFrom:
            configMapKeyRef:
              name: database-config
              key: connection_string
        - name: API_KEY
          valueFrom:
            secretKeyRef:
              name: web-app-secrets
              key: api_key
```

**Pattern B: Volume Mounts**
```yaml
# volume-mount-pattern.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-with-volumes
  namespace: storage-team-a
spec:
  template:
    spec:
      containers:
      - name: app
        image: nginx
        volumeMounts:
        - name: config-volume
          mountPath: /etc/config
        - name: secrets-volume
          mountPath: /etc/secrets
          readOnly: true
      volumes:
      - name: config-volume
        configMap:
          name: web-app-config
      - name: secrets-volume
        secret:
          secretName: web-app-secrets
```

**Analysis Questions:**
1. What are the trade-offs between environment variables and volume mounts?
2. How do these patterns affect configuration updates and pod restarts?
3. Which pattern provides better security for sensitive data?

### Mini-Project 2: Configuration Lifecycle Management

**Challenge:** Implement configuration management that supports:
- Version control for configuration changes
- Safe rollout of configuration updates  
- Environment promotion workflows
- Configuration drift detection

**Step 1: Versioned Configuration Strategy**
```yaml
# versioned-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config-v1-2-0
  namespace: storage-team-a
  labels:
    app: web-app
    version: "1.2.0"
    config-type: application
  annotations:
    config.example.com/created-by: "config-management-system"
    config.example.com/git-commit: "abc123def"
    config.example.com/last-updated: "2024-01-15T10:30:00Z"
data:
  application.yaml: |
    server:
      port: 8080
      threads: 10
    database:
      pool_size: 20
      timeout: 30
    features:
      new_feature: true
      beta_feature: false
```

**Step 2: Configuration Update Process**
```bash
#!/bin/bash
# config-update.sh
# Script for safe configuration updates

APP_NAME="web-app"
NAMESPACE="storage-team-a"
NEW_VERSION="1.3.0"
OLD_VERSION="1.2.0"

# Create new versioned ConfigMap
kubectl apply -f app-config-v${NEW_VERSION}.yaml

# Update application to use new config (blue-green pattern)
kubectl patch deployment ${APP_NAME} -n ${NAMESPACE} \
  -p '{"spec":{"template":{"spec":{"volumes":[{"name":"config-volume","configMap":{"name":"app-config-v'${NEW_VERSION}'"}}]}}}}'

# Monitor rollout
kubectl rollout status deployment/${APP_NAME} -n ${NAMESPACE}

# Cleanup old version after successful rollout
# kubectl delete configmap app-config-v${OLD_VERSION} -n ${NAMESPACE}
```

**Step 3: Configuration Validation**
```yaml
# config-validation.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: config-validator
  namespace: storage-team-a
data:
  validate.sh: |
    #!/bin/bash
    # Validate configuration before deployment
    
    # Check required keys exist
    required_keys=("server.port" "database.pool_size")
    for key in "${required_keys[@]}"; do
      if ! yq eval ".${key}" /etc/config/application.yaml > /dev/null; then
        echo "Missing required configuration: ${key}"
        exit 1
      fi
    done
    
    # Validate value ranges
    port=$(yq eval '.server.port' /etc/config/application.yaml)
    if [[ $port -lt 1024 || $port -gt 65535 ]]; then
      echo "Invalid port number: ${port}"
      exit 1
    fi
    
    echo "Configuration validation passed"
```

**Testing Exercise:**
1. How would you test configuration changes before applying them to production?
2. What rollback strategy would you implement if a configuration update causes issues?
3. How would you detect and alert on configuration drift?

## Part 3: Persistent Storage and Namespaces

### Discovery Exercise: Storage Class and PV Behavior

**Investigation Task:**
Understand how persistent storage works across namespace boundaries:

```bash
# Examine available storage classes (cluster-scoped)
kubectl get storageclasses

# Look at existing persistent volumes (cluster-scoped)
kubectl get pv

# Check persistent volume claims by namespace
kubectl get pvc --all-namespaces
```

**Step 1: Create Storage Resources**
```yaml
# namespace-storage.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: team-a-storage
  namespace: storage-team-a
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: standard  # Use available storage class
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: team-b-storage
  namespace: storage-team-b
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: standard
```

**Step 2: Test Storage Access**
```yaml
# storage-test-pods.yaml
apiVersion: v1
kind: Pod
metadata:
  name: storage-writer
  namespace: storage-team-a
spec:
  containers:
  - name: writer
    image: busybox
    command: ["sh", "-c", "echo 'Team A data' > /data/team-a-file.txt && sleep 3600"]
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: team-a-storage
---
apiVersion: v1
kind: Pod
metadata:
  name: storage-reader
  namespace: storage-team-b
spec:
  containers:
  - name: reader
    image: busybox
    command: ["sleep", "3600"]
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: team-a-storage  # Try to access team-a's PVC
```

**Analysis Questions:**
1. Can a pod in one namespace mount a PVC from another namespace?
2. What happens to the underlying PV when a PVC is deleted?
3. How does this behavior support or hinder data isolation?

### Mini-Project 3: Multi-Tenant Storage Architecture

**Challenge:** Design storage architecture for a multi-tenant SaaS application:

**Requirements:**
- Each tenant's data must be completely isolated
- Shared read-only reference data accessible to all tenants
- Different storage performance tiers for different tenant plans
- Backup and disaster recovery per tenant
- Compliance requirements for data sovereignty

**Step 1: Tenant Namespace Strategy**
```yaml
# tenant-storage-template.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: tenant-{TENANT_ID}
  labels:
    tenant-id: "{TENANT_ID}"
    tenant-plan: "{PLAN_LEVEL}"  # basic, premium, enterprise
    data-classification: "tenant-data"
    backup-required: "true"
---
# Tenant-specific storage class for performance tiers
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: tenant-{TENANT_ID}-storage
provisioner: kubernetes.io/aws-ebs  # or appropriate provisioner
parameters:
  type: gp3  # or ssd for premium tenants
  iops: "3000"  # based on tenant plan
  throughput: "125"
reclaimPolicy: Retain  # Prevent accidental data loss
allowVolumeExpansion: true
```

**Step 2: Shared Data Architecture**
```yaml
# shared-reference-data.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: shared-reference-data
  labels:
    data-type: reference
    access-level: readonly
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: reference-data-pvc
  namespace: shared-reference-data
spec:
  accessModes:
    - ReadOnlyMany  # Multiple readers
  resources:
    requests:
      storage: 10Gi
  storageClassName: shared-reference-storage
```

**Step 3: Data Access Patterns**
```yaml
# tenant-application.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tenant-app
  namespace: tenant-123
spec:
  template:
    spec:
      containers:
      - name: app
        image: tenant-application:latest
        volumeMounts:
        - name: tenant-data
          mountPath: /var/lib/tenant-data
        - name: reference-data
          mountPath: /var/lib/reference-data
          readOnly: true
      volumes:
      - name: tenant-data
        persistentVolumeClaim:
          claimName: tenant-data-pvc
      - name: reference-data
        # How would you mount shared data from another namespace?
        # This is a design challenge - what patterns work?
```

**Design Questions:**
1. How would you share reference data across tenant namespaces securely?
2. What storage policies would enforce tenant data isolation?
3. How would you handle tenant data migration and backup?

### Discovery Exercise: Storage Security Considerations

**Investigation Challenge:**
Explore security aspects of storage in multi-tenant environments:

```bash
# Examine storage-related security settings
kubectl get pv -o yaml | grep -A5 -B5 "nodeAffinity\|accessModes\|claimPolicy"

# Check storage class security parameters
kubectl describe storageclass standard

# Look for storage-related RBAC permissions
kubectl describe clusterrole system:persistent-volume-provisioner
```

**Security Analysis Questions:**
1. What prevents one tenant from accessing another's persistent volumes?
2. How do storage classes affect security and isolation?
3. What happens to data when a namespace is deleted?

## Part 4: Advanced Configuration Patterns

### Mini-Project 4: GitOps Configuration Management

**Challenge:** Implement GitOps-style configuration management with namespace-aware deployment:

**Architecture:**
- Git repository contains configuration for all environments
- Automated system applies configurations to appropriate namespaces
- Configuration changes tracked through Git history
- Environment-specific overrides and templating

**Step 1: Repository Structure**
```
config-repo/
├── base/
│   ├── configmaps/
│   │   ├── common.yaml
│   │   └── database.yaml
│   └── secrets/
│       └── sealed-secrets.yaml
├── environments/
│   ├── development/
│   │   ├── kustomization.yaml
│   │   └── patches/
│   ├── staging/
│   │   ├── kustomization.yaml
│   │   └── patches/
│   └── production/
│       ├── kustomization.yaml
│       └── patches/
└── namespaces/
    ├── team-a/
    └── team-b/
```

**Step 2: Configuration Templates**
```yaml
# base/configmaps/common.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: common-config
data:
  log_level: info
  timezone: UTC
  monitoring_enabled: "true"
  # Values to be overridden by environment
  api_endpoint: PLACEHOLDER
  resource_limits: PLACEHOLDER
---
# environments/development/patches/common-config.yaml  
apiVersion: v1
kind: ConfigMap
metadata:
  name: common-config
data:
  log_level: debug
  api_endpoint: "https://dev-api.example.com"
  resource_limits: "low"
```

**Step 3: Automated Deployment**
```bash
#!/bin/bash
# config-deployment.sh
# GitOps configuration deployment script

ENVIRONMENT=$1
NAMESPACE=$2

if [ -z "$ENVIRONMENT" ] || [ -z "$NAMESPACE" ]; then
    echo "Usage: $0 <environment> <namespace>"
    exit 1
fi

# Build configuration for environment
kustomize build environments/$ENVIRONMENT > /tmp/config-${ENVIRONMENT}.yaml

# Apply to specific namespace
kubectl apply -f /tmp/config-${ENVIRONMENT}.yaml -n $NAMESPACE

# Verify deployment
kubectl get configmaps,secrets -n $NAMESPACE
```

**Advanced Features:**
1. How would you implement configuration validation in the GitOps pipeline?
2. What rollback mechanisms would you build into this system?
3. How would you handle secrets in a GitOps workflow?

### Discovery Exercise: Configuration Security and Compliance

**Investigation Challenge:**
Explore security considerations for configuration management:

**Security Scenarios:**
1. **Secret Sprawl:** Secrets duplicated across multiple namespaces
2. **Configuration Drift:** Namespace configurations diverging from standards
3. **Access Control:** Who can modify configuration in different namespaces
4. **Audit Requirements:** Tracking configuration changes for compliance

**Mitigation Strategies:**
```yaml
# external-secrets-integration.yaml
# Use external secret management systems
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-secret-store
  namespace: storage-team-a
spec:
  provider:
    vault:
      server: "https://vault.example.com"
      path: "secret"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "storage-team-a-role"
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-secrets
  namespace: storage-team-a
spec:
  refreshInterval: 15s
  secretStoreRef:
    name: vault-secret-store
    kind: SecretStore
  target:
    name: web-app-secrets
  data:
  - secretKey: database_password
    remoteRef:
      key: app-secrets
      property: database_password
```

**Analysis Questions:**
1. How would you implement least-privilege access to configuration data?
2. What auditing capabilities would you need for compliance?
3. How would you detect and prevent configuration drift?

## Part 5: Real-World Application

### Comprehensive Scenario: Enterprise Configuration Management

**Your Challenge:**
Design complete configuration and storage management for an enterprise environment:

**Organizational Context:**
- **Multiple Business Units:** Each with different compliance requirements
- **Various Application Types:** Web apps, batch jobs, databases, ML workloads
- **Environment Promotion:** Dev → QA → Staging → Production pipeline
- **Disaster Recovery:** Cross-region backup and recovery requirements
- **Compliance:** SOX, PCI DSS, GDPR requirements for different applications

**Technical Requirements:**
- Configuration should be version-controlled and auditable
- Secrets must be encrypted at rest and in transit
- Storage must be isolated between business units
- Shared configuration should be reusable across teams
- Emergency access procedures for configuration changes

**Design Phase Questions:**
1. How will you structure namespaces to support both isolation and sharing?
2. What configuration hierarchy will minimize duplication while ensuring flexibility?
3. How will you implement storage policies that meet different compliance requirements?
4. What automation will ensure consistent application of policies?

**Implementation Challenge:**

**Step 1: Namespace Architecture**
```yaml
# Design namespace structure that supports:
# - Business unit isolation
# - Environment separation  
# - Shared services access
# - Compliance boundaries
```

**Step 2: Configuration Management Strategy**
```yaml
# Implement configuration system that provides:
# - Version control and audit trails
# - Environment-specific overrides
# - Secret management integration
# - Automated validation and deployment
```

**Step 3: Storage Architecture**
```yaml
# Design storage strategy that ensures:
# - Data isolation between business units
# - Performance tiers for different workload types
# - Backup and disaster recovery
# - Compliance with data sovereignty requirements
```

**Step 4: Operational Procedures**
```bash
# Create procedures for:
# - Configuration change management
# - Emergency access and rollback
# - Compliance reporting and auditing
# - Storage lifecycle management
```

### Advanced Challenge: Multi-Cloud Configuration

**Scenario Extension:**
Your organization operates across multiple cloud providers and on-premises environments:
- Different storage classes and capabilities per environment
- Varying compliance requirements by region
- Network connectivity constraints between environments
- Disaster recovery across cloud boundaries

**Additional Considerations:**
1. How would you maintain configuration consistency across different Kubernetes distributions?
2. What abstraction layers would hide cloud-specific storage details?
3. How would you handle configuration and data replication across regions?

## Unit Assessment

### Practical Configuration and Storage Management

**Assessment Challenge:**
Implement a complete configuration and storage solution:

1. **Design Phase:**
   - Plan configuration hierarchy for multi-team environment
   - Design storage architecture with appropriate isolation
   - Create security and compliance controls

2. **Implementation Phase:**
   - Deploy ConfigMaps, Secrets, and PVCs across multiple namespaces
   - Implement configuration lifecycle management
   - Create storage policies and access controls

3. **Validation Phase:**
   - Demonstrate that configuration management works across environments
   - Prove that storage isolation prevents unauthorized access
   - Show monitoring and compliance reporting capabilities

### Troubleshooting Scenarios

**Configuration and Storage Challenges:**
1. **Configuration Drift:** Namespaces have diverged from standard configuration. Detect and remediate.

2. **Storage Issues:** Applications can't access their persistent storage after cluster maintenance. Diagnose and fix.

3. **Secret Management:** Secrets are being duplicated across namespaces, creating security risks. Implement centralized management.

### Knowledge Integration Questions

1. **Security Question:** How do you balance configuration sharing with security isolation?

2. **Scale Question:** How does your configuration strategy change from 10 to 100 applications across 50 namespaces?

3. **Lifecycle Question:** How do you safely migrate storage and configuration when applications are refactored?

### Preparation for Unit 8

**Preview Questions:**
1. How do configuration and storage strategies change when supporting multiple tenants?
2. What additional isolation requirements emerge in multi-tenant environments?
3. How would you design systems that scale from single-tenant to multi-tenant usage?

**Coming Next:** In Unit 8, we'll explore Multi-Tenancy Patterns, learning to design scalable multi-tenant architectures, implement tenant isolation strategies, and create governance frameworks that support multiple organizational models.

## Quick Reference

### ConfigMap and Secret Commands
```bash
# ConfigMap management
kubectl create configmap <name> --from-file=<file> -n <namespace>
kubectl create configmap <name> --from-literal=<key>=<value> -n <namespace>
kubectl get configmaps -A
kubectl describe configmap <name> -n <namespace>

# Secret management  
kubectl create secret generic <name> --from-literal=<key>=<value> -n <namespace>
kubectl create secret tls <name> --cert=<cert-file> --key=<key-file> -n <namespace>
kubectl get secrets -A
kubectl describe secret <name> -n <namespace>
```

### Storage Commands
```bash
# PVC management
kubectl get pvc -A
kubectl describe pvc <name> -n <namespace>
kubectl get pv

# Storage classes
kubectl get storageclasses
kubectl describe storageclass <name>
```

### Configuration Patterns
```yaml
# Environment variables from ConfigMap
env:
- name: CONFIG_VALUE
  valueFrom:
    configMapKeyRef:
      name: config-name
      key: config-key

# Volume mount from ConfigMap
volumes:
- name: config-volume
  configMap:
    name: config-name
volumeMounts:
- name: config-volume
  mountPath: /etc/config
```

### Storage Patterns
```yaml
# PVC template
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: standard

# Volume mount from PVC
volumes:
- name: data-volume
  persistentVolumeClaim:
    claimName: pvc-name
volumeMounts:
- name: data-volume
  mountPath: /data
```