# Unit 2: Chart Configuration and Values Management

## Learning Objectives
By the end of this unit, you will:
- Master the art of customizing charts through values
- Create and manage values files for different environments
- Understand value precedence and override mechanisms
- Build a multi-environment deployment strategy

## Understanding Chart Values

Values are the key to making charts flexible and reusable. Think of them as the "settings" or "configuration options" for your application. Every chart comes with default values, but the real power comes from customizing these values for your specific needs.

### Value Sources and Precedence

Helm merges values from multiple sources, with this order of precedence (highest to lowest):
1. Command-line `--set` parameters
2. Values files specified with `-f` or `--values`
3. Chart's default `values.yaml` file

```bash
# Understanding the precedence with a practical example
helm install my-app bitnami/nginx \
  --set replicaCount=5 \                    # Highest precedence
  -f production-values.yaml \               # Medium precedence
  # Chart's values.yaml provides defaults    # Lowest precedence
```

## Working with Values Files

### Creating Your First Values File

```bash
# Get the default values from a chart
helm show values bitnami/nginx > nginx-defaults.yaml

# Create a custom values file
cat << EOF > my-nginx-values.yaml
# Replica configuration
replicaCount: 3

# Image configuration  
image:
  repository: nginx
  tag: "1.25-alpine"
  pullPolicy: IfNotPresent

# Service configuration
service:
  type: LoadBalancer
  port: 80

# Resource limits
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 200m
    memory: 256Mi

# Enable ingress for external access
ingress:
  enabled: true
  ingressClassName: nginx
  hosts:
    - host: my-nginx.local
      paths:
        - path: /
          pathType: Prefix
EOF
```

### Deploying with Custom Values

```bash
# Create namespace for our demo
kubectl create namespace values-demo

# Deploy using your custom values
helm install custom-nginx bitnami/nginx \
  -f my-nginx-values.yaml \
  -n values-demo

# Verify the custom configuration was applied
kubectl get deployment custom-nginx-nginx -n values-demo -o yaml | grep replicas
kubectl get service custom-nginx-nginx -n values-demo -o yaml | grep type
```

## Mini-Project 2: Multi-Environment WordPress Deployment

Let's create a realistic scenario where you need to deploy WordPress in three different environments: development, staging, and production.

### Step 1: Create Environment-Specific Values Files

```bash
# Create directory structure
mkdir wordpress-multienv
cd wordpress-multienv

# Development values - optimized for quick iteration
cat << EOF > values-development.yaml
# Development environment configuration
wordpressBlogName: "Development Blog"
wordpressUsername: admin
# Note: In real scenarios, never put passwords in values files
# wordpressPassword: devpass123  # Use secrets instead

# Resource configuration - minimal for development
resources:
  requests:
    memory: 256Mi
    cpu: 250m
  limits:
    memory: 512Mi
    cpu: 500m

# Storage - minimal persistence
persistence:
  enabled: true
  size: 5Gi

# Database resources
mariadb:
  primary:
    resources:
      requests:
        memory: 256Mi
        cpu: 250m
      limits:
        memory: 512Mi
        cpu: 500m
    persistence:
      size: 5Gi

# Service configuration
service:
  type: NodePort
  
# Disable metrics in development
metrics:
  enabled: false
EOF

# Staging values - production-like but smaller
cat << EOF > values-staging.yaml
# Staging environment configuration
wordpressBlogName: "Staging Blog"
wordpressUsername: admin

# Higher resources for load testing
resources:
  requests:
    memory: 512Mi
    cpu: 500m
  limits:
    memory: 1Gi
    cpu: 1000m

# Larger storage for content testing
persistence:
  enabled: true
  size: 10Gi

# Database resources
mariadb:
  primary:
    resources:
      requests:
        memory: 512Mi
        cpu: 500m
      limits:
        memory: 1Gi
        cpu: 1000m
    persistence:
      size: 10Gi

# LoadBalancer for external testing
service:
  type: LoadBalancer
  
# Enable metrics for monitoring testing
metrics:
  enabled: true
  
# Ingress for external access
ingress:
  enabled: true
  hostname: wordpress-staging.local
EOF

# Production values - optimized for performance and reliability
cat << EOF > values-production.yaml
# Production environment configuration
wordpressBlogName: "Production Blog"
wordpressUsername: admin

# Production-level resources
resources:
  requests:
    memory: 1Gi
    cpu: 1000m
  limits:
    memory: 2Gi
    cpu: 2000m

# High-availability storage
persistence:
  enabled: true
  size: 50Gi
  storageClass: fast-ssd  # Use high-performance storage

# Database high availability
mariadb:
  architecture: replication
  primary:
    resources:
      requests:
        memory: 1Gi
        cpu: 1000m
      limits:
        memory: 2Gi
        cpu: 2000m
    persistence:
      size: 100Gi
      storageClass: fast-ssd
  secondary:
    replicaCount: 1
    resources:
      requests:
        memory: 1Gi
        cpu: 1000m
      limits:
        memory: 2Gi
        cpu: 2000m

# Production service configuration
service:
  type: LoadBalancer

# Full monitoring
metrics:
  enabled: true

# Production ingress with TLS
ingress:
  enabled: true
  hostname: wordpress-prod.example.com
  tls: true
  
# Security settings
securityContext:
  enabled: true
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000
EOF
```

### Step 2: Deploy to Each Environment

```bash
# Create namespaces
kubectl create namespace wordpress-dev
kubectl create namespace wordpress-staging
kubectl create namespace wordpress-prod

# Deploy to development
helm install wordpress-dev bitnami/wordpress \
  -f values-development.yaml \
  -n wordpress-dev

# Deploy to staging
helm install wordpress-staging bitnami/wordpress \
  -f values-staging.yaml \
  -n wordpress-staging

# Deploy to production
helm install wordpress-prod bitnami/wordpress \
  -f values-production.yaml \
  -n wordpress-prod
```

### Step 3: Verify Environment Differences

```bash
# Compare resource allocations
echo "=== Development Resources ==="
kubectl get deployment wordpress-dev -n wordpress-dev -o jsonpath='{.spec.template.spec.containers[0].resources}'
echo -e "\n"

echo "=== Staging Resources ==="
kubectl get deployment wordpress-staging -n wordpress-staging -o jsonpath='{.spec.template.spec.containers[0].resources}'
echo -e "\n"

echo "=== Production Resources ==="
kubectl get deployment wordpress-prod -n wordpress-prod -o jsonpath='{.spec.template.spec.containers[0].resources}'
echo -e "\n"

# Compare service types
kubectl get services -l app.kubernetes.io/name=wordpress --all-namespaces
```

## Advanced Values Techniques

### Using Command-Line Overrides

Sometimes you need to make quick adjustments without modifying values files:

```bash
# Override specific values on the command line
helm upgrade wordpress-dev bitnami/wordpress \
  -f values-development.yaml \
  --set replicaCount=2 \
  --set resources.limits.memory=1Gi \
  -n wordpress-dev

# Set nested values
helm upgrade wordpress-staging bitnami/wordpress \
  -f values-staging.yaml \
  --set mariadb.primary.persistence.size=20Gi \
  -n wordpress-staging

# Set multiple values from a file (useful for secrets)
echo "wordpressPassword=newSecretPassword" > temp-values.env
helm upgrade wordpress-dev bitnami/wordpress \
  -f values-development.yaml \
  --set-file wordpressPassword=temp-values.env \
  -n wordpress-dev
rm temp-values.env
```

### Working with Value Templates

Values files can include template expressions for dynamic configuration:

```bash
# Create a templated values file
cat << 'EOF' > values-templated.yaml
# Dynamic configuration using environment variables
wordpressBlogName: "${BLOG_NAME:-Default Blog}"
environment: "${ENVIRONMENT}"

# Conditional resource allocation based on environment
resources:
  requests:
    memory: "${MEMORY_REQUEST:-512Mi}"
    cpu: "${CPU_REQUEST:-500m}"
    
# Dynamic replica count
replicaCount: "${REPLICA_COUNT:-1}"
EOF

# Use environment variables with the deployment
export BLOG_NAME="Dynamic Blog"
export ENVIRONMENT="testing"
export MEMORY_REQUEST="1Gi"
export CPU_REQUEST="750m"
export REPLICA_COUNT="3"

# Deploy with environment variable substitution
envsubst < values-templated.yaml > values-resolved.yaml
helm install dynamic-wordpress bitnami/wordpress \
  -f values-resolved.yaml \
  -n wordpress-dev
```

## Practice Exercise 2: Database Configuration Challenge

Deploy a PostgreSQL database with different configurations for each environment:

**Your task**: Create values files for PostgreSQL that demonstrate:

1. **Development**: Single instance, minimal resources, no backups
2. **Staging**: Single instance, moderate resources, daily backups
3. **Production**: High availability with read replicas, maximum resources, hourly backups

```bash
# Hint: Start by examining the PostgreSQL chart
helm show values bitnami/postgresql > postgresql-defaults.yaml

# Look for these configuration areas:
# - Replica configuration
# - Resource limits
# - Backup settings
# - High availability options

# Create your three values files here:
# values-postgresql-dev.yaml
# values-postgresql-staging.yaml  
# values-postgresql-prod.yaml
```

**Solution Framework**:
```yaml
# values-postgresql-dev.yaml
global:
  postgresql:
    auth:
      database: "devdb"

primary:
  resources:
    requests:
      memory: "256Mi"
      cpu: "250m"

# Add your configuration here...
```

What considerations did you make for each environment? How do the resource allocations reflect the different use cases?

## Understanding Values Schema

Modern Helm charts often include schema validation to ensure values are correct:

```bash
# Some charts include values.schema.json
# This validates your values before deployment

# Check if a chart has schema validation
helm show schema bitnami/nginx

# Validate your values against the schema
helm template test-release bitnami/nginx -f my-values.yaml --validate
```

## Values Management Best Practices

### 1. Environment Separation
```bash
# Organize values files clearly
values/
├── base-values.yaml          # Common settings
├── development-values.yaml   # Dev-specific overrides
├── staging-values.yaml       # Staging-specific overrides
└── production-values.yaml    # Prod-specific overrides
```

### 2. Secret Management
```bash
# Never put secrets in values files committed to Git
# Instead, use Kubernetes secrets or external secret management

# Create secrets separately
kubectl create secret generic wordpress-secrets \
  --from-literal=wordpress-password=secretpassword \
  --from-literal=mariadb-password=dbpassword \
  -n wordpress-prod

# Reference secrets in your values
cat << EOF > values-with-secrets.yaml
auth:
  existingSecret: wordpress-secrets
  secretKey: wordpress-password

mariadb:
  auth:
    existingSecret: wordpress-secrets
    secretKey: mariadb-password
EOF
```

### 3. Values Documentation
```bash
# Document your values files
cat << EOF > values-documented.yaml
# WordPress Configuration
# This file contains production settings for WordPress deployment

# Application Settings
wordpressBlogName: "Production Site"    # The site title
wordpressUsername: admin                # Admin username

# Performance Settings
replicaCount: 3                         # Number of WordPress pods
resources:
  requests:
    memory: 1Gi                         # Guaranteed memory
    cpu: 1000m                          # Guaranteed CPU (1 core)
  limits:
    memory: 2Gi                         # Maximum memory
    cpu: 2000m                          # Maximum CPU (2 cores)
EOF
```

## Troubleshooting Values Issues

### Common Problems and Solutions

```bash
# Problem 1: Values not taking effect
# Check what values are actually being used
helm get values your-release-name

# Problem 2: YAML syntax errors
# Validate YAML syntax before deploying
helm template test-release chart-name -f your-values.yaml --dry-run

# Problem 3: Precedence confusion
# Test value precedence
helm template test-release chart-name \
  -f base-values.yaml \
  -f override-values.yaml \
  --set key=command-line-value \
  --debug

# Problem 4: Nested value problems
# Use --debug to see final values
helm install test-release chart-name -f values.yaml --debug --dry-run
```

## Unit 2 Assessment Project

Deploy a complete monitoring stack (Prometheus + Grafana) with three different configurations:

**Requirements:**
1. **Development**: Single replicas, basic dashboards, no persistence
2. **Staging**: Multiple replicas, extended dashboards, short-term persistence  
3. **Production**: High availability, full dashboard suite, long-term persistence, alerting enabled

**Your deliverables:**
- Three values files for each environment
- Deployment commands for each environment
- Verification that different configurations are applied
- Documentation explaining your configuration choices

**Starter commands:**
```bash
# Add the Prometheus community repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Examine the kube-prometheus-stack chart
helm show values prometheus-community/kube-prometheus-stack > prometheus-defaults.yaml
```

What aspects of monitoring would differ between development and production environments? How would you handle sensitive configuration like alerting webhook URLs?

## Cleanup

```bash
# Remove all WordPress deployments
helm uninstall wordpress-dev -n wordpress-dev
helm uninstall wordpress-staging -n wordpress-staging  
helm uninstall wordpress-prod -n wordpress-prod

# Remove namespaces
kubectl delete namespace wordpress-dev wordpress-staging wordpress-prod values-demo

# Clean up files
rm -rf wordpress-multienv
rm nginx-defaults.yaml my-nginx-values.yaml values-resolved.yaml
```

## Next Steps

In Unit 3, you'll learn to create your own Helm charts from scratch, including templates, helpers, and conditional logic. You'll discover how to package your applications for distribution and reuse.

Before proceeding, consider: What aspects of your current application deployments could benefit from the templating and configuration management you've learned? How would you structure values for a complex application with multiple services?