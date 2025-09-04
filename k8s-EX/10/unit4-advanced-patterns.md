# Unit 4: Advanced Secret Management Patterns

## Learning Objectives
- Design multi-environment Secret strategies
- Implement Secret rotation workflows
- Understand RBAC for Secret security
- Integrate with external secret management systems
- Build production-ready Secret management practices

## Pre-Unit Knowledge Check

Let's start by reflecting on your journey so far. Think about these scenarios and how you'd approach them:

1. **Multi-Environment Challenge**: You need to deploy the same application to development, staging, and production environments, but each needs different database passwords, API keys, and certificates. How would you organize this?

2. **Security Concern**: A team member accidentally pushed a YAML file containing base64-encoded secrets to GitHub. What are the implications, and how would you prevent this?

3. **Operational Reality**: Your application's database password needs to be rotated every 30 days without application downtime. What challenges do you foresee?

Take a few moments to think through these scenarios. What questions come to mind? What approaches seem promising or problematic?

## Pattern 1: Multi-Environment Secret Management

Based on your reflection above, what do you think are the key challenges when managing secrets across different environments?

<details>
<summary>Common challenges students identify</summary>

- Same secret names but different values per environment
- Risk of accidentally using production secrets in development
- Managing deployment pipelines across environments
- Maintaining security while enabling developer productivity

</details>

Let's build a systematic approach. But first, a question: How would you organize your environments if you were designing this system from scratch?

### Environment-Specific Namespaces Strategy

Here's one approach - but I want you to think critically about it:

```bash
# Create environment-specific namespaces
kubectl create namespace development
kubectl create namespace staging  
kubectl create namespace production
```

**Critical Thinking Questions**:
- What are the advantages of namespace-based environment separation?
- What potential problems do you see with this approach?
- How would this affect your deployment pipelines?

### Building Environment-Aware Secret Creation

Let's create a script that handles environment-specific secrets. But before looking at the solution, how would you structure such a script?

**Your Design Challenge**: Sketch out (mentally or on paper) what parameters and logic this script would need. What decisions would it need to make based on the environment?

```bash
#!/bin/bash
# environment-secrets.sh

ENVIRONMENT=${1:-development}
NAMESPACE=${ENVIRONMENT}

# Function to validate environment
validate_environment() {
    case $1 in
        development|staging|production)
            echo "✅ Valid environment: $1"
            ;;
        *)
            echo "❌ Invalid environment: $1"
            echo "Valid options: development, staging, production"
            exit 1
            ;;
    esac
}

# Function to get environment-specific values
get_database_config() {
    local env=$1
    case $env in
        development)
            DB_HOST="dev-postgres.internal"
            DB_PASSWORD="dev_password_123"
            DB_NAME="myapp_dev"
            ;;
        staging)
            DB_HOST="staging-postgres.internal" 
            DB_PASSWORD="staging_secure_password"
            DB_NAME="myapp_staging"
            ;;
        production)
            # In real production, these would come from a secure vault
            DB_HOST="prod-postgres.cluster.local"
            DB_PASSWORD="production_ultra_secure_password"
            DB_NAME="myapp_production"
            ;;
    esac
}

# Main execution
validate_environment $ENVIRONMENT
get_database_config $ENVIRONMENT

echo "🚀 Creating secrets for $ENVIRONMENT environment..."

kubectl create secret generic database-config \
    --namespace=$NAMESPACE \
    --from-literal=host=$DB_HOST \
    --from-literal=password=$DB_PASSWORD \
    --from-literal=database=$DB_NAME \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Secrets created successfully!"
```

**Analysis Questions**:
1. What security concerns do you have about this script?
2. How would you modify it for production use?
3. What happens if someone runs this script with the wrong environment parameter?

Now try running this script (you can create it as a file or adapt the commands):

```bash
# Test with different environments
./environment-secrets.sh development
./environment-secrets.sh staging
./environment-secrets.sh production

# Verify the results
kubectl get secrets -n development
kubectl get secrets -n staging
kubectl get secrets -n production
```

**Reflection**: How does seeing the actual secrets across environments change your perspective on the challenges?

## Pattern 2: Secret Rotation Without Downtime

This is where theory meets operational reality. Before we dive into implementation, let's think through the problem:

**Scenario**: You need to rotate a database password that's currently being used by 10 application pods. The rotation must happen without any service interruption.

**Your Strategy Session**: How would you approach this? What steps would you take? What could go wrong?

<details>
<summary>Think through this before expanding</summary>

Key considerations often include:
- How to update secrets without restarting pods
- Ensuring database accepts both old and new passwords during transition
- Rollback strategy if something goes wrong
- Monitoring and verification of the rotation

</details>

### Building a Safe Rotation Workflow

Let's implement a rotation strategy step by step. I'll provide the framework, but I want you to think through each step:

```bash
#!/bin/bash
# secret-rotation.sh

SECRET_NAME="database-config"
NAMESPACE="production"
DEPLOYMENT_NAME="web-app"

echo "🔄 Starting secret rotation for $SECRET_NAME"

# Step 1: Create new secret with updated values
echo "Step 1: Creating new secret..."
# What should happen here?

# Step 2: Update deployment to use new secret
echo "Step 2: Updating deployment..."
# How would you update the deployment reference?

# Step 3: Wait for rollout completion
echo "Step 3: Waiting for rollout..."
# How would you verify the rollout succeeded?

# Step 4: Verify application health
echo "Step 4: Verifying application health..."
# What health checks would you perform?

# Step 5: Clean up old secret
echo "Step 5: Cleaning up old secret..."
# When is it safe to remove the old secret?
```

**Implementation Challenge**: Fill in the missing commands for each step. What kubectl commands would you use?

<details>
<summary>Suggested implementation after you've tried</summary>

```bash
# Step 1
kubectl create secret generic database-config-new \
    --namespace=$NAMESPACE \
    --from-literal=host=prod-postgres.cluster.local \
    --from-literal=password=rotated_password_abc123 \
    --from-literal=database=myapp_production

# Step 2  
kubectl patch deployment $DEPLOYMENT_NAME -n $NAMESPACE -p \
    '{"spec":{"template":{"spec":{"containers":[{"name":"web-app","envFrom":[{"secretRef":{"name":"database-config-new"}}]}]}}}}'

# Step 3
kubectl rollout status deployment/$DEPLOYMENT_NAME -n $NAMESPACE

# Step 4
kubectl get pods -l app=$DEPLOYMENT_NAME -n $NAMESPACE
# Additional health checks specific to your application

# Step 5
kubectl delete secret database-config -n $NAMESPACE
kubectl get secret database-config-new -n $NAMESPACE -o yaml | \
    sed 's/database-config-new/database-config/' | \
    kubectl apply -f -
kubectl delete secret database-config-new -n $NAMESPACE
```

</details>

**Critical Analysis**: What assumptions does this rotation strategy make? Under what conditions might it fail?

## Pattern 3: RBAC Security for Secrets

Security isn't just about the secrets themselves - it's about controlling who can access them. Let's explore this systematically.

**Security Design Question**: If you were architecting access controls for secrets, what different types of access would you need to consider?

Think about:
- Different roles in your organization
- Different types of operations on secrets
- The principle of least privilege

### Implementing Granular Secret Access

Let's build a realistic RBAC scenario. You have:
- **Developers**: Need to create and modify secrets in development
- **DevOps Engineers**: Need full secret access in staging, read-only in production
- **Applications**: Need read-only access to specific secrets
- **Auditors**: Need read-only access for compliance

**Design Challenge**: Before looking at the implementation, how would you structure these roles and permissions?

```yaml
# secret-rbac.yaml
# Developer role - development environment only
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: development
  name: secret-developer
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
---
# DevOps role - staging environment (full access)
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: staging
  name: secret-devops-staging
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
---
# DevOps role - production environment (read-only)
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: secret-devops-production
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]
---
# Application service account - specific secrets only
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: app-secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["database-config", "api-secrets"]  # Only specific secrets
  verbs: ["get"]
---
# Service account for applications
apiVersion: v1
kind: ServiceAccount
metadata:
  name: web-app-service-account
  namespace: production
---
# Bind application service account to limited role
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-secret-access
  namespace: production
subjects:
- kind: ServiceAccount
  name: web-app-service-account
  namespace: production
roleRef:
  kind: Role
  name: app-secret-reader
  apiGroup: rbac.authorization.k8s.io
```

**Analysis Exercise**: 
1. Test this RBAC configuration with different service accounts
2. Try to access secrets that aren't explicitly allowed
3. What happens when you try to perform operations beyond the granted verbs?

```bash
# Test RBAC permissions
kubectl auth can-i get secrets --as=system:serviceaccount:production:web-app-service-account -n production
kubectl auth can-i delete secrets --as=system:serviceaccount:production:web-app-service-account -n production
kubectl auth can-i get secret database-config --as=system:serviceaccount:production:web-app-service-account -n production
```

**Security Reflection**: How does this RBAC setup align with the principle of least privilege? What improvements would you make?

## Pattern 4: Integration with External Secret Management

Here's where we acknowledge Kubernetes Secrets' limitations. Base64 encoding isn't encryption, and for production systems, you often need more sophisticated secret management.

**Discussion Question**: What limitations of Kubernetes Secrets have you encountered or can you anticipate in production environments?

<details>
<summary>Common limitations teams encounter</summary>

- Base64 encoding is easily reversible
- No built-in secret rotation
- Secrets stored in etcd (potential single point of failure)
- Limited audit capabilities
- No secret versioning
- Challenges with secret sharing across clusters

</details>

### Simulating External Secret Integration

Let's build a pattern that simulates integration with an external system like HashiCorp Vault or AWS Secrets Manager:

```bash
#!/bin/bash
# external-secret-sync.sh
# Simulates pulling secrets from external system

EXTERNAL_SYSTEM=${1:-vault}
ENVIRONMENT=${2:-development}

# Simulate external secret retrieval
retrieve_from_external_system() {
    local system=$1
    local env=$2
    
    echo "🔌 Connecting to $system for $env environment..."
    
    # This would be actual API calls in production
    case $system in
        vault)
            echo "📡 Retrieving secrets from HashiCorp Vault..."
            # vault kv get -field=password secret/myapp/$env/database
            # Simulated values:
            EXTERNAL_DB_PASSWORD="vault_retrieved_password_${env}_$(date +%s)"
            EXTERNAL_API_KEY="vault_api_key_${env}_$(date +%s)"
            ;;
        aws)
            echo "☁️ Retrieving secrets from AWS Secrets Manager..."
            # aws secretsmanager get-secret-value --secret-id myapp/$env/database
            # Simulated values:
            EXTERNAL_DB_PASSWORD="aws_sm_password_${env}_$(date +%s)"
            EXTERNAL_API_KEY="aws_sm_api_key_${env}_$(date +%s)"
            ;;
        *)
            echo "❌ Unknown external system: $system"
            exit 1
            ;;
    esac
}

# Sync to Kubernetes
sync_to_kubernetes() {
    local env=$1
    
    echo "🚀 Syncing secrets to Kubernetes..."
    
    kubectl create secret generic external-synced-secrets \
        --namespace=$env \
        --from-literal=database-password="$EXTERNAL_DB_PASSWORD" \
        --from-literal=api-key="$EXTERNAL_API_KEY" \
        --from-literal=last-sync="$(date)" \
        --dry-run=client -o yaml | kubectl apply -f -
        
    echo "✅ Sync completed successfully"
}

# Main workflow
retrieve_from_external_system $EXTERNAL_SYSTEM $ENVIRONMENT
sync_to_kubernetes $ENVIRONMENT
```

**Implementation Exercise**:
1. Run this script with different parameters
2. Examine the resulting secrets
3. How would you schedule this script to run periodically?
4. What error handling would you add for production use?

**Architecture Question**: How does this pattern change your approach to secret management? What new operational considerations does it introduce?

## Mini-Project 5: Production-Ready Secret Pipeline

Now let's put it all together. You're going to build a complete secret management pipeline that demonstrates production best practices.

**Requirements**:
1. Multi-environment support (dev, staging, prod)
2. RBAC integration
3. Secret rotation capability
4. External system simulation
5. Audit logging
6. Rollback capability

**Architecture Planning Session**: Before implementing, sketch out:
- What components will you need?
- How will they interact?
- What failure modes should you handle?
- How will you test and validate the system?

Here's a framework to build from:

```yaml
# production-secret-pipeline.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: secret-management
  labels:
    purpose: secret-ops
---
# Secret management service account
apiVersion: v1
kind: ServiceAccount
metadata:
  name: secret-manager
  namespace: secret-management
---
# ClusterRole for secret management operations
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: secret-manager
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["events"]
  verbs: ["create"]
---
# Bind the cluster role
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: secret-manager
subjects:
- kind: ServiceAccount
  name: secret-manager
  namespace: secret-management
roleRef:
  kind: ClusterRole
  name: secret-manager
  apiGroup: rbac.authorization.k8s.io
---
# CronJob for automated secret rotation
apiVersion: batch/v1
kind: CronJob
metadata:
  name: secret-rotator
  namespace: secret-management
spec:
  schedule: "0 2 * * 0"  # Weekly at 2 AM Sunday
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: secret-manager
          containers:
          - name: rotator
            image: alpine:latest
            command:
            - /bin/sh
            - -c
            - |
              echo "🔄 Starting automated secret rotation..."
              # Your rotation logic here
              echo "✅ Rotation completed"
          restartPolicy: OnFailure
```

**Implementation Challenge**: 
1. Deploy this pipeline framework
2. Add your rotation script as a ConfigMap and mount it in the CronJob
3. Test the automated rotation
4. Add monitoring and alerting for rotation failures

**Advanced Extension**: Create a web interface or CLI tool that allows operators to:
- View secret status across environments
- Trigger manual rotations
- View audit logs
- Rollback changes

## Pattern 5: GitOps and Secret Management

One of the biggest challenges in production Kubernetes is managing secrets in GitOps workflows. Let's explore this systematically.

**The GitOps Dilemma**: You want to store everything in Git for transparency and automation, but secrets can't be stored in plaintext in Git. How would you solve this?

<details>
<summary>Common approaches teams use</summary>

1. **Sealed Secrets**: Encrypt secrets that can only be decrypted in-cluster
2. **External Secrets Operator**: Reference external secret stores in Git
3. **Helm with separate secret management**: Use Helm charts with external secret injection
4. **SOPS (Secrets OPerationS)**: Encrypt files that can be decrypted in CI/CD pipelines

</details>

### Implementing a GitOps-Safe Secret Pattern

Let's implement a simplified version of the external secrets pattern:

```yaml
# external-secret-reference.yaml
# This goes in Git - no actual secrets!
apiVersion: v1
kind: ConfigMap
metadata:
  name: secret-references
  namespace: production
data:
  secret-config.yaml: |
    secrets:
      - name: database-config
        namespace: production
        source: vault
        path: secret/myapp/production/database
        keys:
          - username
          - password
          - host
      - name: api-secrets
        namespace: production  
        source: aws-sm
        path: myapp/production/api-keys
        keys:
          - stripe-key
          - sendgrid-key
---
# Deployment that references the future secrets
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gitops-app
  namespace: production
spec:
  replicas: 2
  selector:
    matchLabels:
      app: gitops-app
  template:
    metadata:
      labels:
        app: gitops-app
      annotations:
        secret-sync/required: "database-config,api-secrets"
    spec:
      containers:
      - name: app
        image: nginx:alpine
        env:
        - name: DB_USERNAME
          valueFrom:
            secretKeyRef:
              name: database-config
              key: username
        envFrom:
        - secretRef:
            name: api-secrets
```

**Implementation Exercise**: 
1. Deploy this configuration
2. Create a controller or script that reads the ConfigMap and creates the actual secrets
3. Test that the application works when secrets are properly created

**Discussion Questions**:
1. What are the advantages of this approach over storing encrypted secrets in Git?
2. What operational complexity does this introduce?
3. How would you handle secret updates in this model?

## Comprehensive Assessment Project

Time to demonstrate mastery of advanced secret management! Here's your capstone project:

**Scenario**: You're the platform engineer for a fast-growing startup. You need to design and implement a complete secret management system that supports:

1. **Multiple Applications**: Web frontend, API backend, worker processes, monitoring stack
2. **Multiple Environments**: Development, staging, production, and disaster recovery  
3. **Multiple Teams**: Frontend developers, backend developers, platform team, security team
4. **Compliance Requirements**: Audit logging, secret rotation, access controls
5. **Operational Requirements**: GitOps workflow, automated deployments, disaster recovery

**Your Deliverables**:

1. **Architecture Document**: Describe your approach to each requirement
2. **RBAC Configuration**: Define roles and permissions for each team
3. **Secret Management Scripts**: Automation for creation, rotation, and synchronization
4. **GitOps Integration**: Show how secrets fit into your deployment pipeline
5. **Monitoring and Alerting**: How you'll track secret operations and failures
6. **Disaster Recovery Plan**: How you'll handle secret-related failures

**Success Criteria**:
- Demonstrate the principle of least privilege
- Show automated secret rotation without downtime
- Integrate with external secret management
- Provide audit trails for all secret operations
- Support rollback for failed deployments
- Work within a GitOps model without storing secrets in Git

**Bonus Challenges**:
- Implement secret encryption at rest
- Add automatic secret expiration
- Create a self-service portal for developers
- Implement cross-cluster secret replication

## Reflection and Advanced Topics

Congratulations on working through advanced secret management patterns! Before we conclude, let's reflect on your journey:

**Technical Reflection**:
1. Which patterns felt most applicable to your current or future work?
2. What surprised you about the complexity of production secret management?
3. Where do you see the biggest gaps between simple tutorials and production reality?

**Strategic Thinking**:
1. How would you present the ROI of investing in sophisticated secret management to leadership?
2. What would your migration plan look like for moving from basic to advanced secret management?
3. How do these patterns fit into broader platform engineering and DevOps practices?

## What's Next?

You've now mastered advanced Kubernetes secret management. Here are some areas for continued learning:

**Immediate Next Steps**:
- Research specific external secret management tools (Vault, AWS Secrets Manager, etc.)
- Explore Kubernetes operators like External Secrets Operator or Sealed Secrets
- Practice implementing these patterns in your own clusters

**Advanced Topics to Explore**:
- Service mesh integration (Istio, Linkerd) with secret management
- Kubernetes admission controllers for secret policy enforcement
- Cross-cloud secret replication and disaster recovery
- Integration with CI/CD pipelines and infrastructure as code

**Community Engagement**:
- Share your secret management patterns with the community
- Contribute to open-source secret management tools
- Attend KubeCon sessions on security and secret management

You're now equipped with production-ready secret management skills that will serve you well in any Kubernetes environment. The patterns and principles you've learned here scale from small applications to enterprise platforms.

Remember: Good secret management is not just about the technology—it's about creating systems that are secure, operationally sustainable, and enable your teams to move fast while staying safe.