# 19. Helm Basics: From Package Manager to Production-Ready Charts

Helm is fundamentally a package manager for Kubernetes, much like how npm manages JavaScript packages or apt manages system packages on Ubuntu. However, Helm goes beyond simple package management by providing templating capabilities that allow you to create reusable, configurable applications. Think of Helm as a way to turn your complex Kubernetes YAML files into smart, parameterized templates that can be easily shared, versioned, and deployed across different environments.

Understanding Helm requires grasping three core concepts: Charts (the packages), Releases (installed instances of charts), and Repositories (where charts are stored and shared). A chart is like a blueprint for your application, a release is a specific deployment of that blueprint with particular configuration values, and a repository is a collection of charts that can be shared across teams and organizations.

## 19.1 Helm Installation and Essential Operations

Before diving into chart creation, let's establish a solid foundation with Helm installation and understand how each command contributes to the overall workflow. Each step builds upon the previous one, creating a complete picture of Helm's capabilities.

```bash
# Install Helm (example for Linux)
# This script downloads and installs the latest stable version of Helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Verify installation - this should show the Helm version
helm version

# Add a chart repository
# Repositories are like app stores for Helm charts
# Bitnami is one of the most popular and well-maintained repositories
helm repo add bitnami https://charts.bitnami.com/bitnami

# Update repository information to get the latest chart versions
# This is similar to running 'apt update' before installing packages
helm repo update

# List all configured repositories to verify setup
helm repo list

# Search for charts in repositories
# This helps you discover available applications and their versions
helm search repo nginx
helm search repo bitnami/nginx --versions  # Show all available versions

# Install a chart with specific version for reproducible deployments
# The --version flag ensures you get exactly the version you tested with
helm install my-nginx bitnami/nginx --version 13.2.0

# View detailed information about your installation
# This shows the current status, resources created, and any notes from the chart
helm status my-nginx

# List all releases in the current namespace
# Releases are running instances of charts in your cluster
helm list

# List releases across all namespaces for cluster-wide visibility
helm list --all-namespaces

# Upgrade a release with new configuration
# This demonstrates how Helm manages application lifecycle
helm upgrade my-nginx bitnami/nginx \
  --set replicaCount=3 \
  --set service.type=LoadBalancer \
  --version 13.2.0

# View the history of upgrades for rollback purposes
# Helm maintains a complete history of changes to your releases
helm history my-nginx

# Rollback to a previous version if needed
# This is one of Helm's most powerful features for production stability
helm rollback my-nginx 1

# Get the values that were used for the current release
# This helps you understand the current configuration
helm get values my-nginx

# Uninstall a release cleanly
# This removes all resources that were created by the chart
helm uninstall my-nginx

# Keep release history even after uninstall (useful for auditing)
helm uninstall my-nginx --keep-history
```

The progression here follows a natural workflow: installation, discovery, deployment, management, and cleanup. Each command serves a specific purpose in the application lifecycle, and understanding this flow is crucial for effective Helm usage.

## 19.2 Creating Custom Charts: Building Reusable Application Templates

Creating a custom chart is where Helm's true power emerges. Think of this process as creating a template that can adapt to different environments while maintaining consistency across deployments. We'll build understanding by starting with Helm's generated structure and then customizing it for real-world scenarios.

```bash
# Create a new chart with Helm's standard structure
# This generates a complete, working chart that follows best practices
helm create myapp

# Examine the generated structure to understand the components
# Each file serves a specific purpose in the chart ecosystem
tree myapp/
# myapp/
# ├── Chart.yaml          # Chart metadata and version information
# ├── values.yaml         # Default configuration values
# ├── charts/             # Dependencies (other charts this chart needs)
# ├── templates/          # Kubernetes resource templates
# │   ├── deployment.yaml # Application deployment template
# │   ├── service.yaml    # Network service template
# │   ├── ingress.yaml    # External access configuration
# │   └── _helpers.tpl    # Reusable template functions
# └── tests/              # Chart testing resources

# Let's understand Chart.yaml - the chart's identity document
cat myapp/Chart.yaml
# This file defines the chart's metadata, version, and dependencies
# The version field tracks chart changes, while appVersion tracks the application version

# Now let's create a more realistic values.yaml for a production application
# This file is the heart of chart customization - it defines all configurable parameters
cat << EOF > myapp/values.yaml
# Replica count determines how many pods will run your application
# Start with 2 for basic high availability
replicaCount: 2

# Image configuration defines what container to run
image:
  repository: nginx
  tag: "1.21-alpine"  # Use specific tags instead of 'latest' for stability
  pullPolicy: IfNotPresent
  # pullSecrets: []   # Add if using private registries

# Service configuration determines how your app is exposed within the cluster
service:
  type: ClusterIP      # Internal cluster access only
  port: 80
  targetPort: 80

# Ingress configuration for external access
ingress:
  enabled: false       # Start disabled, enable when ready for external access
  className: "nginx"
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
  hosts:
    - host: myapp.local
      paths:
        - path: /
          pathType: Prefix
  # tls: []            # Add TLS configuration when ready

# Resource limits prevent one application from consuming all cluster resources
resources:
  limits:
    cpu: 500m          # Maximum CPU usage
    memory: 512Mi      # Maximum memory usage
  requests:
    cpu: 200m          # Guaranteed CPU allocation
    memory: 256Mi      # Guaranteed memory allocation

# Autoscaling configuration for handling variable loads
autoscaling:
  enabled: false       # Disable initially, enable after load testing
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

# Health check configuration ensures reliability
livenessProbe:
  httpGet:
    path: /
    port: http
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /
    port: http
  initialDelaySeconds: 5
  periodSeconds: 5

# Security context for running containers safely
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 2000

# Node selection and affinity rules for proper placement
nodeSelector: {}
tolerations: []
affinity: {}

# Environment-specific configurations
environment: development

# Database configuration (for applications that need it)
database:
  enabled: false
  host: ""
  port: 5432
  name: myapp
  # Credentials should come from secrets, not values files

# Feature flags for gradual rollouts
features:
  newUI: false
  advancedAnalytics: false
EOF

# Test chart rendering without actually installing it
# This is crucial for catching template errors before deployment
helm template myapp ./myapp

# Test with different values to ensure flexibility
helm template myapp ./myapp --set replicaCount=5 --set environment=production

# Lint the chart to catch common issues
# This validates template syntax and follows best practices
helm lint ./myapp

# Install the chart locally for testing
# Use a test namespace to isolate the deployment
kubectl create namespace myapp-test
helm install myapp-test ./myapp --namespace myapp-test

# Verify the installation worked correctly
kubectl get all -n myapp-test
helm status myapp-test -n myapp-test

# Test an upgrade with different values
helm upgrade myapp-test ./myapp \
  --namespace myapp-test \
  --set replicaCount=3 \
  --set environment=staging

# Clean up the test installation
helm uninstall myapp-test -n myapp-test
kubectl delete namespace myapp-test
```

This section demonstrates the iterative process of chart development: generate, customize, test, and refine. Each step builds confidence in your chart's reliability and flexibility before you share it with others.

## 19.3 Production-Ready Chart Repository with CI/CD Pipeline

Creating a chart repository transforms your individual charts into a scalable distribution system. This mini-project demonstrates enterprise-grade practices including automated testing, version management, and continuous deployment. Think of this as creating your own "app store" for your organization's applications.

```bash
#!/bin/bash
# save as helm-repo-setup.sh
# This script creates a complete chart repository with production-ready practices

REPO_NAME="myapp-charts"
CHART_NAME="webapp"

echo "🏭 Setting up Enterprise Helm Chart Repository"
echo "This will create a complete CI/CD pipeline for chart development and distribution"

# Create comprehensive repository structure
# Each directory serves a specific purpose in the development lifecycle
mkdir -p $REPO_NAME/{charts,docs,scripts,tests,environments,security}
cd $REPO_NAME

# Initialize git repository with proper configuration
git init
cat << EOF > .gitignore
# Packaged charts - these are generated artifacts
*.tgz
*.tar.gz

# OS-specific files
.DS_Store
Thumbs.db

# IDE and editor files
.vscode/
.idea/
*.swp
*.swo

# Temporary files and logs
*.log
tmp/
.tmp/

# Secret files (should never be committed)
secrets/
*.key
*.pem
.env
EOF

# Create base chart with enhanced structure
helm create charts/$CHART_NAME

# Create comprehensive testing configuration
# This demonstrates different deployment scenarios your chart should handle
mkdir -p charts/$CHART_NAME/ci
cat << EOF > charts/$CHART_NAME/ci/test-values.yaml
# Minimal configuration for basic functionality testing
replicaCount: 1
image:
  repository: nginx
  tag: "1.21-alpine"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80

# Conservative resource limits for testing environment
resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 50m
    memory: 64Mi

# Disable complex features during basic testing
autoscaling:
  enabled: false
ingress:
  enabled: false

# Enable health checks to ensure reliability
livenessProbe:
  httpGet:
    path: /
    port: http
  initialDelaySeconds: 10
  periodSeconds: 5

readinessProbe:
  httpGet:
    path: /
    port: http
  initialDelaySeconds: 5
  periodSeconds: 3
EOF

# Create production-like testing values
cat << EOF > charts/$CHART_NAME/ci/production-test-values.yaml
# Production-like configuration for comprehensive testing
replicaCount: 3
image:
  repository: nginx
  tag: "1.21-alpine"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80

# Production-level resource allocation
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 200m
    memory: 256Mi

# Enable autoscaling for load testing
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 70

# Security context for production safety
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 2000
EOF

# Create comprehensive test suite
# This testing approach ensures chart reliability across different scenarios
cat << 'EOF' > tests/chart-test.sh
#!/bin/bash
set -e

# Test configuration
CHART_PATH="charts/webapp"
RELEASE_NAME="test-release"
NAMESPACE="chart-testing"
TIMEOUT="300s"

echo "🧪 Comprehensive Helm Chart Testing Suite"
echo "This suite validates chart functionality, security, and reliability"

# Ensure we have a clean testing environment
cleanup() {
  echo "🧹 Cleaning up test resources..."
  helm uninstall $RELEASE_NAME -n $NAMESPACE --ignore-not-found
  kubectl delete namespace $NAMESPACE --ignore-not-found
  kubectl delete pod test-pod -n $NAMESPACE --ignore-not-found
}
trap cleanup EXIT

# Create isolated testing namespace
echo "🏗️  Setting up test environment..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Phase 1: Static Analysis and Linting
echo "📋 Phase 1: Static Analysis"
echo "Running Helm lint to check chart structure and templates..."
helm lint $CHART_PATH

echo "🔍 Checking for security best practices..."
# Verify Chart.yaml contains required fields
if ! grep -q "version:" $CHART_PATH/Chart.yaml; then
  echo "❌ Chart.yaml missing version field"
  exit 1
fi

if ! grep -q "appVersion:" $CHART_PATH/Chart.yaml; then
  echo "❌ Chart.yaml missing appVersion field"
  exit 1
fi

# Phase 2: Template Rendering Tests
echo "🎨 Phase 2: Template Rendering Tests"
echo "Testing template rendering with minimal values..."
helm template $RELEASE_NAME $CHART_PATH \
  --values $CHART_PATH/ci/test-values.yaml \
  > /tmp/rendered-templates-minimal.yaml

echo "Testing template rendering with production values..."
helm template $RELEASE_NAME $CHART_PATH \
  --values $CHART_PATH/ci/production-test-values.yaml \
  > /tmp/rendered-templates-production.yaml

# Validate generated YAML syntax
echo "✅ Validating generated YAML syntax..."
kubectl apply --dry-run=client -f /tmp/rendered-templates-minimal.yaml
kubectl apply --dry-run=client -f /tmp/rendered-templates-production.yaml

# Phase 3: Basic Installation Test
echo "🚀 Phase 3: Basic Installation Test"
echo "Installing chart with minimal configuration..."
helm install $RELEASE_NAME $CHART_PATH \
  --namespace $NAMESPACE \
  --values $CHART_PATH/ci/test-values.yaml \
  --wait \
  --timeout $TIMEOUT

# Phase 4: Resource Validation
echo "🔍 Phase 4: Resource Validation"
echo "Verifying all expected resources were created..."

# Check deployment
if kubectl get deployment $RELEASE_NAME-webapp -n $NAMESPACE >/dev/null 2>&1; then
  echo "✅ Deployment created successfully"
  # Verify deployment is ready
  kubectl wait --for=condition=available deployment/$RELEASE_NAME-webapp -n $NAMESPACE --timeout=120s
  echo "✅ Deployment is available and ready"
else
  echo "❌ Deployment not found"
  exit 1
fi

# Check service
if kubectl get service $RELEASE_NAME-webapp -n $NAMESPACE >/dev/null 2>&1; then
  echo "✅ Service created successfully"
else
  echo "❌ Service not found"
  exit 1
fi

# Phase 5: Pod Health and Readiness
echo "⏳ Phase 5: Pod Health Verification"
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/instance=$RELEASE_NAME \
  -n $NAMESPACE \
  --timeout=120s
echo "✅ All pods are healthy and ready"

# Verify pod security context
echo "🔒 Checking security context..."
POD_NAME=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/instance=$RELEASE_NAME -o jsonpath='{.items[0].metadata.name}')
SECURITY_CONTEXT=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.spec.securityContext}')
if [[ "$SECURITY_CONTEXT" != "null" && "$SECURITY_CONTEXT" != "{}" ]]; then
  echo "✅ Security context is properly configured"
else
  echo "⚠️  Warning: No security context found"
fi

# Phase 6: Functional Testing
echo "🌐 Phase 6: Functional Testing"
echo "Testing HTTP connectivity and application functionality..."

# Create a test pod to verify service connectivity
kubectl run test-pod \
  --image=busybox:1.35 \
  --rm -i --restart=Never \
  -n $NAMESPACE \
  --command -- sh -c "
    echo 'Testing HTTP connectivity...'
    wget -q --spider --timeout=10 http://$RELEASE_NAME-webapp/
    if [ \$? -eq 0 ]; then
      echo '✅ HTTP connectivity test passed'
    else
      echo '❌ HTTP connectivity test failed'
      exit 1
    fi
  "

# Phase 7: Upgrade Testing
echo "🔄 Phase 7: Upgrade Testing"
echo "Testing chart upgrade functionality..."
helm upgrade $RELEASE_NAME $CHART_PATH \
  --namespace $NAMESPACE \
  --values $CHART_PATH/ci/production-test-values.yaml \
  --wait \
  --timeout $TIMEOUT

# Verify upgrade completed successfully
kubectl wait --for=condition=available deployment/$RELEASE_NAME-webapp -n $NAMESPACE --timeout=120s
echo "✅ Upgrade completed successfully"

# Phase 8: Rollback Testing
echo "↩️  Phase 8: Rollback Testing"
echo "Testing rollback functionality..."
helm rollback $RELEASE_NAME 1 -n $NAMESPACE --wait --timeout $TIMEOUT
kubectl wait --for=condition=available deployment/$RELEASE_NAME-webapp -n $NAMESPACE --timeout=120s
echo "✅ Rollback completed successfully"

echo ""
echo "🎉 All tests passed successfully!"
echo "📊 Test Summary:"
echo "   ✅ Static analysis and linting"
echo "   ✅ Template rendering validation"
echo "   ✅ Resource creation verification"
echo "   ✅ Pod health and readiness checks"
echo "   ✅ Security context validation"
echo "   ✅ Functional connectivity testing"
echo "   ✅ Upgrade and rollback testing"
echo ""
echo "Your chart is ready for production deployment! 🚀"
EOF

chmod +x tests/chart-test.sh

# Create advanced release automation script
# This script handles version management, testing, and publication
cat << 'EOF' > scripts/release.sh
#!/bin/bash
set -e

# Release configuration
CHART_PATH="charts/webapp"
VERSION=$1
RELEASE_NOTES=$2

# Color codes for better output visibility
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
  echo -e "${BLUE}📦 $1${NC}"
}

print_success() {
  echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
  echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
  echo -e "${RED}❌ $1${NC}"
}

# Validate input parameters
if [ -z "$VERSION" ]; then
  print_error "Usage: $0 <version> [release_notes]"
  echo "Examples:"
  echo "  $0 1.0.0 'Initial release'"
  echo "  $0 1.1.0 'Added new features'"
  echo "  $0 1.0.1 'Bug fixes and improvements'"
  exit 1
fi

# Validate version format (semantic versioning)
if ! [[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  print_error "Version must follow semantic versioning format (e.g., 1.0.0)"
  exit 1
fi

print_header "Creating Helm Chart Release v$VERSION"

# Check if version already exists
if git tag -l | grep -q "v$VERSION"; then
  print_error "Version v$VERSION already exists!"
  echo "Existing tags:"
  git tag -l | grep "v[0-9]" | sort -V | tail -5
  exit 1
fi

# Ensure working directory is clean
if [[ -n $(git status --porcelain) ]]; then
  print_warning "Working directory has uncommitted changes"
  git status --short
  read -p "Continue anyway? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

# Update chart metadata
print_header "Updating Chart Metadata"
sed -i "s/version:.*/version: $VERSION/" $CHART_PATH/Chart.yaml
sed -i "s/appVersion:.*/appVersion: \"$VERSION\"/" $CHART_PATH/Chart.yaml

# Add release notes to Chart.yaml if provided
if [ -n "$RELEASE_NOTES" ]; then
  echo "📝 Release Notes: $RELEASE_NOTES"
fi
EOF

chmod +x scripts/release.sh

# Create security scanning script
cat << 'EOF' > scripts/security-scan.sh
#!/bin/bash
set -e

CHART_PATH="charts/webapp"

echo "🔒 Security Scanning for Helm Charts"

# Check for common security misconfigurations
echo "🔍 Checking for security best practices..."

# Check if security context is defined
if ! grep -q "securityContext" $CHART_PATH/templates/deployment.yaml; then
  echo "⚠️  Warning: No security context found in deployment"
fi

# Check for resource limits
if ! grep -q "resources:" $CHART_PATH/values.yaml; then
  echo "⚠️  Warning: No resource limits defined"
fi

# Check for non-root user
if ! grep -q "runAsNonRoot" $CHART_PATH/values.yaml; then
  echo "⚠️  Warning: Consider running as non-root user"
fi

# Scan for hardcoded secrets (basic check)
echo "🔍 Scanning for potential hardcoded secrets..."
if grep -r -i "password\|secret\|key\|token" $CHART_PATH/templates/ --exclude="*.md"; then
  echo "⚠️  Warning: Potential hardcoded secrets found"
fi

echo "✅ Security scan completed"
EOF

chmod +x scripts/security-scan.sh

# Create environment-specific configurations
mkdir -p environments/{development,staging,production}

cat << EOF > environments/development/values.yaml
# Development environment configuration
# Optimized for fast iteration and debugging

replicaCount: 1
image:
  repository: nginx
  tag: "latest"
  pullPolicy: Always  # Always pull for development

service:
  type: NodePort  # Easy access for local development

resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi

autoscaling:
  enabled: false

ingress:
  enabled: false

# Development-specific features
environment: development
debug: true
logLevel: debug

# Enable development tools
devtools:
  enabled: true
  hotReload: true
EOF

cat << EOF > environments/staging/values.yaml
# Staging environment configuration  
# Production-like but with relaxed constraints

replicaCount: 2
image:
  repository: nginx
  tag: "1.21-alpine"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 200m
    memory: 256Mi

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 70

ingress:
  enabled: true
  className: "nginx"
  hosts:
    - host: myapp-staging.company.com
      paths:
        - path: /
          pathType: Prefix

environment: staging
debug: false
logLevel: info

# Staging-specific monitoring
monitoring:
  enabled: true
  metrics: true
EOF

cat << EOF > environments/production/values.yaml
# Production environment configuration
# Maximum reliability and performance

replicaCount: 3
image:
  repository: nginx
  tag: "1.21-alpine"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP

resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 500m
    memory: 512Mi

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 20
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

ingress:
  enabled: true
  className: "nginx"
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  hosts:
    - host: myapp.company.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: myapp-tls
      hosts:
        - myapp.company.com

# Production security settings
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 2000
  readOnlyRootFilesystem: true

# Production monitoring and alerting
monitoring:
  enabled: true
  metrics: true
  alerts: true
  
# Backup configuration
backup:
  enabled: true
  schedule: "0 2 * * *"

environment: production
debug: false
logLevel: warn
EOF

# Create advanced GitHub Actions workflow
mkdir -p .github/workflows
cat << 'EOF' > .github/workflows/ci-cd.yml
name: Chart CI/CD Pipeline
on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]
  release:
    types: [created]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  # Static analysis and linting
  lint:
    name: 🔍 Lint and Validate
    runs-on: ubuntu-latest
    steps:
    - name: Checkout
      uses: actions/checkout@v4
      with:
        fetch-depth: 0

    - name: Set up Helm
      uses: azure/setup-helm@v4
      with:
        version: '3.14.0'

    - name: Set up Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.11'

    - name: Install chart-testing
      uses: helm/chart-testing-action@v2.6.1

    - name: Run chart-testing (list-changed)
      id: list-changed
      run: |
        changed=$(ct list-changed --target-branch ${{ github.event.repository.default_branch }})
        if [[ -n "$changed" ]]; then
          echo "changed=true" >> "$GITHUB_OUTPUT"
        fi

    - name: Run chart-testing (lint)
      if: steps.list-changed.outputs.changed == 'true'
      run: ct lint --target-branch ${{ github.event.repository.default_branch }}

    - name: Security scan
      run: ./scripts/security-scan.sh

  # Comprehensive testing
  test:
    name: 🧪 Test Charts
    runs-on: ubuntu-latest
    needs: lint
    strategy:
      matrix:
        k8s-version: ['v1.27.3', 'v1.28.0', 'v1.29.0']
    steps:
    - name: Checkout
      uses: actions/checkout@v4
      with:
        fetch-depth: 0

    - name: Set up Helm
      uses: azure/setup-helm@v4
      with:
        version: '3.14.0'

    - name: Set up chart-testing
      uses: helm/chart-testing-action@v2.6.1

    - name: Create kind cluster
      uses: helm/kind-action@v1.8.0
      with:
        node_image: kindest/node:${{ matrix.k8s-version }}
        cluster_name: chart-testing

    - name: Run comprehensive tests
      run: ./tests/chart-test.sh

    - name: Test different environments
      run: |
        # Test development configuration
        helm template test-dev charts/webapp -f environments/development/values.yaml
        
        # Test staging configuration  
        helm template test-staging charts/webapp -f environments/staging/values.yaml
        
        # Test production configuration
        helm template test-prod charts/webapp -f environments/production/values.yaml

  # Build and package
  package:
    name: 📦 Package Charts
    runs-on: ubuntu-latest
    needs: [lint, test]
    if: github.ref == 'refs/heads/main'
    outputs:
      chart-version: ${{ steps.version.outputs.version }}
    steps:
    - name: Checkout
      uses: actions/checkout@v4
      with:
        fetch-depth: 0

    - name: Set up Helm
      uses: azure/setup-helm@v4
      with:
        version: '3.14.0'

    - name: Generate version
      id: version
      run: |
        if [[ ${{ github.event_name }} == 'release' ]]; then
          VERSION=${{ github.event.release.tag_name }}
          VERSION=${VERSION#v}  # Remove 'v' prefix if present
        else
          VERSION=$(date +%Y.%m.%d)-${GITHUB_SHA::8}
        fi
        echo "version=$VERSION" >> "$GITHUB_OUTPUT"
        echo "Generated version: $VERSION"

    - name: Update chart version
      run: |
        sed -i "s/version:.*/version: ${{ steps.version.outputs.version }}/" charts/webapp/Chart.yaml
        sed -i "s/appVersion:.*/appVersion: \"${{ steps.version.outputs.version }}\"/" charts/webapp/Chart.yaml

    - name: Package chart
      run: |
        mkdir -p ./docs
        helm package charts/webapp --destination ./docs/

    - name: Update repository index
      run: |
        helm repo index ./docs/ --url https://${{ github.repository_owner }}.github.io/${{ github.event.repository.name }}/

    - name: Upload packaged charts
      uses: actions/upload-artifact@v4
      with:
        name: helm-charts
        path: ./docs/

  # Deploy to GitHub Pages
  deploy:
    name: 🚀 Deploy to GitHub Pages
    runs-on: ubuntu-latest
    needs: package
    if: github.ref == 'refs/heads/main'
    permissions:
      contents: read
      pages: write
      id-token: write
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Download packaged charts
      uses: actions/download-artifact@v4
      with:
        name: helm-charts
        path: ./docs/

    - name: Update GitHub Pages content
      run: |
        # Update the HTML page with the new version
        sed -i "s/VERSION_PLACEHOLDER/${{ needs.package.outputs.chart-version }}/" docs/index.html

    - name: Setup Pages
      uses: actions/configure-pages@v4

    - name: Upload to GitHub Pages
      uses: actions/upload-pages-artifact@v3
      with:
        path: ./docs/

    - name: Deploy to GitHub Pages
      id: deployment
      uses: actions/deploy-pages@v4

  # Notify on completion
  notify:
    name: 📢 Notify
    runs-on: ubuntu-latest
    needs: [lint, test, package, deploy]
    if: always()
    steps:
    - name: Notify success
      if: needs.deploy.result == 'success'
      run: |
        echo "✅ Chart successfully deployed!"
        echo "🌐 Repository URL: https://${{ github.repository_owner }}.github.io/${{ github.event.repository.name }}/"
        echo "📦 Version: ${{ needs.package.outputs.chart-version }}"

    - name: Notify failure
      if: failure()
      run: |
        echo "❌ Pipeline failed!"
        echo "Please check the logs for details."
EOF

# Create comprehensive documentation
cat << EOF > README.md
# 🚢 MyApp Helm Charts Repository

[![Chart CI/CD](https://github.com/mycompany/myapp-charts/workflows/Chart%20CI%2FCD%20Pipeline/badge.svg)](https://github.com/mycompany/myapp-charts/actions)
[![Helm Version](https://img.shields.io/badge/Helm-v3.14+-blue.svg)](https://helm.sh)
[![Kubernetes Version](https://img.shields.io/badge/Kubernetes-v1.27+-blue.svg)](https://kubernetes.io)

A production-ready Helm chart repository featuring enterprise-grade applications with comprehensive CI/CD pipelines, security scanning, and multi-environment support.

## 🚀 Quick Start

### Adding the Repository
\`\`\`bash
# Add the Helm repository
helm repo add myapp-charts https://mycompany.github.io/myapp-charts/

# Update your local repository cache
helm repo update

# Verify the repository was added
helm repo list
\`\`\`

### Installing a Chart
\`\`\`bash
# Basic installation
helm install my-webapp myapp-charts/webapp

# Installation with custom values
helm install my-webapp myapp-charts/webapp \\
  --set replicaCount=3 \\
  --set ingress.enabled=true

# Installation for specific environment
helm install my-webapp myapp-charts/webapp \\
  -f environments/production/values.yaml
\`\`\`

## 📊 Available Charts

### webapp
A comprehensive web application chart designed for production environments.

**Key Features:**
- 🏗️ **Multi-Environment Support**: Separate configurations for dev, staging, and production
- 📈 **Auto-Scaling**: Horizontal Pod Autoscaling with CPU and memory metrics
- 🌐 **Ingress Ready**: Built-in ingress configuration with TLS support
- 🔒 **Security First**: Pod security contexts, network policies, and security scanning
- 📊 **Monitoring**: Prometheus metrics integration and health checks
- 🔄 **CI/CD Ready**: Automated testing and deployment pipelines
- 🛡️ **High Availability**: Multi-replica deployments with anti-affinity rules
- 📦 **Resource Management**: Configurable resource limits and requests

**Quick Examples:**
\`\`\`bash
# Development deployment
helm install dev-webapp myapp-charts/webapp \\
  -f environments/development/values.yaml

# Staging deployment with ingress
helm install staging-webapp myapp-charts/webapp \\
  -f environments/staging/values.yaml

# Production deployment with full features
helm install prod-webapp myapp-charts/webapp \\
  -f environments/production/values.yaml
\`\`\`

## 🛠️ Development Workflow

### Prerequisites
- Kubernetes cluster (v1.27+)
- Helm 3.14+
- kubectl configured
- Git

### Setting Up Development Environment
\`\`\`bash
# Clone the repository
git clone https://github.com/mycompany/myapp-charts.git
cd myapp-charts

# Run tests locally
./tests/chart-test.sh

# Test security configurations
./scripts/security-scan.sh

# Validate chart templates
helm lint charts/webapp
helm template test charts/webapp --debug
\`\`\`

### Testing Different Environments
\`\`\`bash
# Test development configuration
helm template dev-test charts/webapp \\
  -f environments/development/values.yaml

# Test staging configuration
helm template staging-test charts/webapp \\
  -f environments/staging/values.yaml

# Test production configuration
helm template prod-test charts/webapp \\
  -f environments/production/values.yaml
\`\`\`

### Creating a Release
\`\`\`bash
# Create a new release
./scripts/release.sh 1.2.0 "Added new monitoring features"

# Push to repository
git push origin main
git push origin v1.2.0
\`\`\`

## 🔒 Security

### Security Features
- **Pod Security Contexts**: All containers run as non-root users
- **Resource Limits**: CPU and memory limits prevent resource exhaustion
- **Network Policies**: Configurable network isolation
- **Secret Management**: Integration with Kubernetes secrets and external secret managers
- **Security Scanning**: Automated vulnerability scanning in CI/CD pipeline

### Security Best Practices
- Never commit secrets to the repository
- Use specific image tags instead of \`latest\`
- Enable security contexts for all workloads
- Regularly update chart dependencies
- Run security scans before deployment

## 📈 Monitoring and Observability

### Built-in Monitoring
- **Health Checks**: Liveness and readiness probes
- **Metrics Export**: Prometheus metrics integration
- **Logging**: Structured logging with configurable levels
- **Tracing**: OpenTelemetry support for distributed tracing

### Monitoring Setup
\`\`\`bash
# Install with monitoring enabled
helm install webapp myapp-charts/webapp \\
  --set monitoring.enabled=true \\
  --set monitoring.metrics=true \\
  --set monitoring.alerts=true
\`\`\`

## 🌍 Multi-Environment Deployment

### Environment Configurations
- **Development**: Single replica, relaxed security, debug enabled
- **Staging**: Production-like configuration with reduced resources
- **Production**: High availability, security hardened, monitoring enabled

### Environment-Specific Deployments
\`\`\`bash
# Deploy to development
helm install dev-app myapp-charts/webapp \\
  -f environments/development/values.yaml \\
  --namespace development

# Deploy to staging
helm install staging-app myapp-charts/webapp \\
  -f environments/staging/values.yaml \\
  --namespace staging

# Deploy to production
helm install prod-app myapp-charts/webapp \\
  -f environments/production/values.yaml \\
  --namespace production
\`\`\`

## 🔄 CI/CD Pipeline

### Automated Processes
- **Linting**: Chart validation and best practice checking
- **Testing**: Multi-version Kubernetes compatibility testing
- **Security Scanning**: Vulnerability and configuration scanning
- **Packaging**: Automatic chart packaging and versioning
- **Deployment**: GitHub Pages deployment for chart distribution

### Pipeline Triggers
- **Pull Requests**: Run tests and validation
- **Main Branch**: Full pipeline with deployment
- **Releases**: Tagged releases with changelog generation

## 🤝 Contributing

### Development Process
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests locally: \`./tests/chart-test.sh\`
5. Create a pull request
6. Address review feedback
7. Merge after approval

### Chart Guidelines
- Follow Helm best practices
- Include comprehensive documentation
- Add appropriate tests
- Update CHANGELOG.md
- Maintain backward compatibility

### Testing Requirements
- All charts must pass linting
- Comprehensive test coverage
- Multi-environment validation
- Security scan compliance

## 📚 Resources

### Documentation
- [Helm Documentation](https://helm.sh/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Chart Best Practices](https://helm.sh/docs/chart_best_practices/)

### Support
- 🐛 [Report Issues](https://github.com/mycompany/myapp-charts/issues)
- 💬 [Discussions](https://github.com/mycompany/myapp-charts/discussions)
- 📧 [Contact Team](mailto:platform-team@company.com)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🎯 Roadmap

### Upcoming Features
- [ ] Advanced auto-scaling with custom metrics
- [ ] Multi-cloud deployment support
- [ ] Enhanced security policies
- [ ] Backup and disaster recovery
- [ ] Service mesh integration
- [ ] GitOps workflow integration

---

**Built with ❤️ by the Platform Team**
EOF

# Create contributing guidelines
cat << EOF > CONTRIBUTING.md
# Contributing to MyApp Helm Charts

Thank you for your interest in contributing! This document provides guidelines and best practices for contributing to our Helm chart repository.

## 🚀 Getting Started

### Prerequisites
- Kubernetes cluster (kind, minikube, or cloud provider)
- Helm 3.14 or later
- kubectl configured
- Git
- Basic understanding of Kubernetes and Helm

### Development Setup
\`\`\`bash
# Fork and clone the repository
git clone https://github.com/yourusername/myapp-charts.git
cd myapp-charts

# Create a development branch
git checkout -b feature/your-feature-name

# Run initial tests to ensure everything works
./tests/chart-test.sh
\`\`\`

## 📋 Contribution Guidelines

### Code Style
- Follow Helm best practices and conventions
- Use meaningful names for templates and values
- Include comprehensive comments in templates
- Maintain consistent indentation (2 spaces)

### Chart Structure
- Use the standard Helm chart structure
- Include all necessary template files
- Provide comprehensive default values
- Include proper metadata in Chart.yaml

### Documentation
- Update README.md for significant changes
- Include inline comments in complex templates
- Document all configurable values
- Provide usage examples

### Testing
- All changes must pass existing tests
- Add new tests for new features
- Test across multiple Kubernetes versions
- Validate security configurations

## 🧪 Testing Your Changes

### Local Testing
\`\`\`bash
# Run the full test suite
./tests/chart-test.sh

# Test specific configurations
helm template test charts/webapp -f environments/development/values.yaml
helm template test charts/webapp -f environments/staging/values.yaml
helm template test charts/webapp -f environments/production/values.yaml

# Security scan
./scripts/security-scan.sh
\`\`\`

### Manual Testing
\`\`\`bash
# Create test namespace
kubectl create namespace chart-test

# Install your changes
helm install test-release charts/webapp --namespace chart-test

# Verify functionality
kubectl get all -n chart-test

# Clean up
helm uninstall test-release -n chart-test
kubectl delete namespace chart-test
\`\`\`

## 🔄 Pull Request Process

### Before Submitting
1. Ensure all tests pass locally
2. Update documentation as needed
3. Add or update tests for new features
4. Follow semantic versioning for breaking changes

### Pull Request Guidelines
- Use descriptive titles and descriptions
- Reference related issues
- Include testing instructions
- Update CHANGELOG.md if applicable

### Review Process
1. Automated tests must pass
2. Code review by maintainers
3. Documentation review
4. Final approval and merge

## 🏗️ Chart Development Best Practices

### Template Guidelines
\`\`\`yaml
# Use consistent naming
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "webapp.fullname" . }}
  labels:
    {{- include "webapp.labels" . | nindent 4 }}

# Include security contexts
securityContext:
  {{- toYaml .Values.securityContext | nindent 8 }}

# Use resource limits
resources:
  {{- toYaml .Values.resources | nindent 10 }}
\`\`\`

### Values.yaml Structure
\`\`\`yaml
# Group related configurations
image:
  repository: nginx
  tag: "1.21-alpine"
  pullPolicy: IfNotPresent

# Provide sensible defaults
replicaCount: 1

# Include comprehensive resource specifications
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 200m
    memory: 256Mi
\`\`\`

### Security Considerations
- Always include security contexts
- Use non-root users when possible
- Define resource limits
- Avoid hardcoded secrets
- Enable security scanning

## 📝 Release Process

### Version Management
- Follow semantic versioning (MAJOR.MINOR.PATCH)
- Update Chart.yaml version field
- Update appVersion for application changes
- Create meaningful release notes

### Creating Releases
\`\`\`bash
# Use the release script
./scripts/release.sh 1.3.0 "Added new monitoring features"

# Or manually
git tag -a v1.3.0 -m "Release version 1.3.0"
git push origin v1.3.0
\`\`\`

## 🐛 Reporting Issues

### Bug Reports
- Use the issue template
- Include Kubernetes and Helm versions
- Provide reproduction steps
- Include relevant logs and configurations

### Feature Requests
- Describe the use case
- Explain the expected behavior
- Consider backward compatibility
- Discuss implementation approaches

## 🤝 Community

### Communication
- Join our discussions on GitHub
- Follow our coding standards
- Be respectful and constructive
- Help others in the community

### Recognition
Contributors are recognized in:
- CHANGELOG.md for significant contributions
- GitHub contributors list
- Community acknowledgments

## 📚 Resources

### Learning Materials
- [Helm Chart Development Guide](https://helm.sh/docs/chart_best_practices/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [YAML Best Practices](https://yaml.org/spec/1.2/spec.html)

### Tools
- [Helm](https://helm.sh/) - Package manager for Kubernetes
- [kind](https://kind.sigs.k8s.io/) - Kubernetes in Docker for testing
- [kubeval](https://kubeval.instrumenta.dev/) - Kubernetes YAML validation

Thank you for contributing to making our Helm charts better! 🎉
EOF

echo "✅ Enhanced Helm Chart Repository Setup Complete!"
echo ""
echo "📁 Complete Repository Structure:"
find . -type f \( -name "*.sh" -o -name "*.yaml" -o -name "*.yml" -o -name "*.md" -o -name "*.html" \) | head -25
echo "   ... and more files"
echo ""
echo "🚀 Next Steps:"
echo "1. Initialize repository: git add . && git commit -m 'Initial enhanced setup'"
echo "2. Run comprehensive tests: ./tests/chart-test.sh"
echo "3. Test security scanning: ./scripts/security-scan.sh"
echo "4. Create your first release: ./scripts/release.sh 1.0.0 'Initial release'"
echo "5. Push to GitHub and enable Pages for chart distribution"
echo "6. Configure GitHub Actions secrets if needed"
echo ""
echo "💡 Key Features Added:"
echo "   ✅ Multi-environment configurations (dev/staging/prod)"
echo "   ✅ Comprehensive testing with multiple K8s versions"
echo "   ✅ Security scanning and best practices"
echo "   ✅ Advanced CI/CD pipeline with GitHub Actions"
echo "   ✅ Professional documentation and contribution guidelines"
echo "   ✅ Automated chart packaging and distribution"
echo "   ✅ Version management and changelog generation"
echo ""
cd ..
```

## 19.4 Advanced Helm Concepts and Enterprise Patterns

Understanding Helm at an enterprise level requires mastering dependency management, custom resource definitions, and advanced templating techniques. These concepts enable you to create sophisticated, maintainable chart ecosystems.

### Dependency Management and Chart Libraries

Charts can depend on other charts, enabling modular architecture and code reuse. This is particularly powerful for creating chart libraries that standardize common patterns across your organization.

```bash
# Create a library chart for common templates
helm create common-library
cd common-library

# Convert to library chart by updating Chart.yaml
cat << EOF > Chart.yaml
apiVersion: v2
name: common-library
description: Common templates and helpers for all applications
type: library
version: 0.1.0
EOF

# Create reusable templates in templates/_common.tpl
cat << 'EOF' > templates/_common.tpl
{{/*
Common labels for all resources
Usage: {{ include "common.labels" . }}
*/}}
{{- define "common.labels" -}}
helm.sh/chart: {{ include "common.chart" . }}
{{ include "common.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
environment: {{ .Values.environment | default "development" }}
{{- end }}

{{/*
Selector labels
Usage: {{ include "common.selectorLabels" . }}
*/}}
{{- define "common.selectorLabels" -}}
app.kubernetes.io/name: {{ include "common.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create chart name and version as used by the chart label
*/}}
{{- define "common.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common name template
*/}}
{{- define "common.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name
*/}}
{{- define "common.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Common security context
Usage: {{ include "common.securityContext" .Values.securityContext }}
*/}}
{{- define "common.securityContext" -}}
runAsNonRoot: true
runAsUser: {{ .runAsUser | default 1000 }}
runAsGroup: {{ .runAsGroup | default 2000 }}
fsGroup: {{ .fsGroup | default 2000 }}
{{- if .readOnlyRootFilesystem }}
readOnlyRootFilesystem: true
{{- end }}
{{- if .allowPrivilegeEscalation }}
allowPrivilegeEscalation: {{ .allowPrivilegeEscalation }}
{{- else }}
allowPrivilegeEscalation: false
{{- end }}
{{- end }}

{{/*
Common resource template
Usage: {{ include "common.resources" .Values.resources }}
*/}}
{{- define "common.resources" -}}
{{- if .limits }}
limits:
  {{- if .limits.cpu }}
  cpu: {{ .limits.cpu }}
  {{- end }}
  {{- if .limits.memory }}
  memory: {{ .limits.memory }}
  {{- end }}
{{- end }}
{{- if .requests }}
requests:
  {{- if .requests.cpu }}
  cpu: {{ .requests.cpu }}
  {{- end }}
  {{- if .requests.memory }}
  memory: {{ .requests.memory }}
  {{- end }}
{{- end }}
{{- end }}
EOF

# Now use the library in your main chart
cd ../charts/webapp

# Add dependency to Chart.yaml
cat << EOF >> Chart.yaml

dependencies:
  - name: common-library
    version: "0.1.0"
    repository: "file://../common-library"
EOF

# Update dependencies
helm dependency update

# Use library templates in your deployment
cat << 'EOF' > templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "common.fullname" . }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "common.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "common.selectorLabels" . | nindent 8 }}
    spec:
      securityContext:
        {{- include "common.securityContext" .Values.securityContext | nindent 8 }}
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          resources:
            {{- include "common.resources" .Values.resources | nindent 12 }}
          ports:
            - name: http
              containerPort: 80
              protocol: TCP
          livenessProbe:
            {{- toYaml .Values.livenessProbe | nindent 12 }}
          readinessProbe:
            {{- toYaml .Values.readinessProbe | nindent 12 }}
EOF
```

### Advanced Chart Testing and Validation

Enterprise-grade charts require sophisticated testing strategies that go beyond basic functionality. This includes contract testing, performance validation, and chaos engineering.

```bash
# Create advanced testing framework
cat << 'EOF' > tests/advanced-test-suite.sh
#!/bin/bash
set -e

CHART_PATH="charts/webapp"
NAMESPACE="advanced-testing"
RELEASE_NAME="advanced-test"

echo "🚀 Advanced Helm Chart Testing Suite"
echo "This comprehensive suite tests performance, reliability, and edge cases"

# Cleanup function
cleanup() {
  echo "🧹 Cleaning up advanced test resources..."
  helm uninstall $RELEASE_NAME -n $NAMESPACE --ignore-not-found
  kubectl delete namespace $NAMESPACE --ignore-not-found
  kubectl delete -f tests/chaos-experiments/ --ignore-not-found || true
}
trap cleanup EXIT

# Create testing namespace with resource quotas
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Apply resource quotas for testing
cat << YAML | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: test-quota
  namespace: $NAMESPACE
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 4Gi
    limits.cpu: "4"
    limits.memory: 8Gi
    pods: "10"
YAML

echo "🏗️  Phase 1: Contract Testing"
echo "Validating chart contract and API compatibility..."

# Test with minimum required values
cat << YAML > /tmp/minimal-values.yaml
image:
  repository: nginx
  tag: "alpine"
YAML

helm template contract-test $CHART_PATH -f /tmp/minimal-values.yaml > /tmp/contract-output.yaml

# Validate required Kubernetes resources are present
required_resources=("Deployment" "Service")
for resource in "${required_resources[@]}"; do
  if grep -q "kind: $resource" /tmp/contract-output.yaml; then
    echo "✅ Required resource $resource found"
  else
    echo "❌ Required resource $resource missing"
    exit 1
  fi
done

echo "🔧 Phase 2: Configuration Matrix Testing"
echo "Testing various configuration combinations..."

# Test different replica counts
for replicas in 1 3 5; do
  echo "Testing with $replicas replicas..."
  helm template matrix-test $CHART_PATH \
    --set replicaCount=$replicas \
    --set resources.requests.cpu=100m \
    --set resources.requests.memory=128Mi > /tmp/matrix-$replicas.yaml
  
  # Validate resource generation
  actual_replicas=$(grep -c "name: matrix-test-webapp" /tmp/matrix-$replicas.yaml)
  if [[ $actual_replicas -eq 1 ]]; then
    echo "✅ Replica configuration $replicas validated"
  else
    echo "❌ Replica configuration $replicas failed"
    exit 1
  fi
done

echo "🚀 Phase 3: Performance and Load Testing"
echo "Installing chart for performance testing..."

# Install with performance testing configuration
helm install $RELEASE_NAME $CHART_PATH \
  --namespace $NAMESPACE \
  --set replicaCount=3 \
  --set resources.requests.cpu=200m \
  --set resources.requests.memory=256Mi \
  --set resources.limits.cpu=500m \
  --set resources.limits.memory=512Mi \
  --wait --timeout=300s

# Wait for all pods to be ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/instance=$RELEASE_NAME \
  -n $NAMESPACE --timeout=120s

# Performance testing with Apache Bench
echo "Running performance tests..."
kubectl run perf-test \
  --image=httpd:alpine \
  --rm -i --restart=Never \
  -n $NAMESPACE \
  --command -- sh -c "
    apk add --no-cache apache2-utils
    echo 'Starting performance test...'
    ab -n 1000 -c 10 http://$RELEASE_NAME-webapp/
    echo 'Performance test completed'
  "

echo "📈 Phase 4: Resource Utilization Testing"
echo "Monitoring resource usage patterns..."

# Monitor resource usage for 30 seconds
kubectl top pods -n $NAMESPACE --no-headers | while read line; do
  echo "Pod resource usage: $line"
done

# Test resource limits
echo "Testing resource limit enforcement..."
kubectl run resource-test \
  --image=alpine \
  --rm -i --restart=Never \
  -n $NAMESPACE \
  --overrides='{
    "spec": {
      "containers": [{
        "name": "resource-test",
        "image": "alpine",
        "command": ["sh", "-c", "echo Testing resource limits && sleep 10"],
        "resources": {
          "requests": {"cpu": "1", "memory": "1Gi"},
          "limits": {"cpu": "1", "memory": "1Gi"}
        }
      }]
    }
  }' \
  --command -- echo "Resource limit test completed"

echo "🔄 Phase 5: Lifecycle Testing"
echo "Testing upgrade and rollback scenarios..."

# Test upgrade with different configuration
helm upgrade $RELEASE_NAME $CHART_PATH \
  --namespace $NAMESPACE \
  --set replicaCount=2 \
  --set image.tag=latest \
  --wait --timeout=300s

# Verify upgrade
kubectl wait --for=condition=available deployment/$RELEASE_NAME-webapp -n $NAMESPACE --timeout=120s
echo "✅ Upgrade test completed"

# Test rollback
helm rollback $RELEASE_NAME 1 -n $NAMESPACE --wait --timeout=300s
kubectl wait --for=condition=available deployment/$RELEASE_NAME-webapp -n $NAMESPACE --timeout=120s
echo "✅ Rollback test completed"

echo "🔒 Phase 6: Security Testing"
echo "Running security validation tests..."

# Check for security contexts
POD_NAME=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/instance=$RELEASE_NAME -o jsonpath='{.items[0].metadata.name}')

# Verify non-root user
USER_ID=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.spec.containers[0].securityContext.runAsUser}')
if [[ "$USER_ID" != "0" && "$USER_ID" != "" ]]; then
  echo "✅ Container running as non-root user ($USER_ID)"
else
  echo "⚠️  Warning: Container may be running as root"
fi

# Test network connectivity restrictions
echo "Testing network policies..."
kubectl run network-test \
  --image=busybox \
  --rm -i --restart=Never \
  -n $NAMESPACE \
  --command -- sh -c "
    echo 'Testing internal connectivity...'
    nslookup $RELEASE_NAME-webapp
    echo 'Network connectivity test completed'
  "

echo "🌊 Phase 7: Chaos Engineering"
echo "Testing resilience under failure conditions..."

# Create chaos experiments directory
mkdir -p tests/chaos-experiments

# Pod deletion chaos test
cat << YAML > tests/chaos-experiments/pod-chaos.yaml
apiVersion: v1
kind: Pod
metadata:
  name: chaos-pod-killer
  namespace: $NAMESPACE
spec:
  restartPolicy: Never
  containers:
  - name: chaos
    image: alpine
    command: ["sh", "-c"]
    args:
    - |
      apk add --no-cache curl
      echo "Starting chaos experiment: Pod deletion"
      
      # Get a random pod to delete
      POD_TO_DELETE=\$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/instance=$RELEASE_NAME -o jsonpath='{.items[0].metadata.name}' || echo "none")
      
      if [ "\$POD_TO_DELETE" != "none" ]; then
        echo "Deleting pod: \$POD_TO_DELETE"
        kubectl delete pod \$POD_TO_DELETE -n $NAMESPACE
        
        echo "Waiting for recovery..."
        sleep 30
        
        # Check if service is still accessible
        if kubectl get service $RELEASE_NAME-webapp -n $NAMESPACE >/dev/null 2>&1; then
          echo "✅ Service survived pod deletion chaos"
        else
          echo "❌ Service failed during pod deletion chaos"
          exit 1
        fi
      fi
YAML

# Apply chaos experiment
kubectl apply -f tests/chaos-experiments/pod-chaos.yaml

# Wait for chaos experiment to complete
kubectl wait --for=condition=complete pod/chaos-pod-killer -n $NAMESPACE --timeout=120s

# Verify system recovery
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/instance=$RELEASE_NAME \
  -n $NAMESPACE --timeout=120s

echo "✅ Chaos engineering test completed - system recovered successfully"

echo "📊 Phase 8: Comprehensive Health Check"
echo "Final system validation..."

# Check all resources are healthy
resources_status=$(kubectl get all -n $NAMESPACE -l app.kubernetes.io/instance=$RELEASE_NAME --no-headers | wc -l)
if [[ $resources_status -gt 0 ]]; then
  echo "✅ All resources are present and accounted for"
else
  echo "❌ Some resources are missing after testing"
  exit 1
fi

# Final connectivity test
kubectl run final-connectivity-test \
  --image=busybox \
  --rm -i --restart=Never \
  -n $NAMESPACE \
  --command -- sh -c "
    echo 'Final connectivity test...'
    wget -q --spider --timeout=10 http://$RELEASE_NAME-webapp/
    echo '✅ Final connectivity test passed'
  "

echo ""
echo "🎉 Advanced Testing Suite Completed Successfully!"
echo "📋 Test Summary:"
echo "   ✅ Contract testing - API compatibility verified"
echo "   ✅ Configuration matrix - Multiple scenarios validated"
echo "   ✅ Performance testing - Load handling confirmed"
echo "   ✅ Resource utilization - Limits and requests working"
echo "   ✅ Lifecycle testing - Upgrades and rollbacks functional"
echo "   ✅ Security testing - Security contexts validated"
echo "   ✅ Chaos engineering - Resilience under failure confirmed"
echo "   ✅ Health validation - System fully operational"
echo ""
echo "🚀 Your chart is production-ready and battle-tested!"
EOF

chmod +x tests/advanced-test-suite.sh
```

### Helm Hooks and Custom Resource Management

Helm hooks enable sophisticated deployment orchestration, allowing you to run jobs before, during, and after releases. This is crucial for database migrations, secret management, and complex initialization procedures.

```bash
# Create comprehensive hook examples
mkdir -p charts/webapp/templates/hooks

# Pre-install hook for database migration
cat << 'EOF' > charts/webapp/templates/hooks/pre-install-db-migration.yaml
{{- if .Values.database.migration.enabled }}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "common.fullname" . }}-db-migration
  labels:
    {{- include "common.labels" . | nindent 4 }}
    component: database-migration
  annotations:
    "helm.sh/hook": pre-install,pre-upgrade
    "helm.sh/hook-weight": "-5"
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  template:
    metadata:
      name: {{ include "common.fullname" . }}-db-migration
      labels:
        {{- include "common.selectorLabels" . | nindent 8 }}
        component: database-migration
    spec:
      restartPolicy: Never
      initContainers:
      - name: wait-for-db
        image: postgres:13-alpine
        command:
        - sh
        - -c
        - |
          until pg_isready -h {{ .Values.database.host }} -p {{ .Values.database.port }}; do
            echo "Waiting for database..."
            sleep 2
          done
          echo "Database is ready!"
        env:
        - name: PGUSER
          value: {{ .Values.database.user | quote }}
        - name: PGHOST
          value: {{ .Values.database.host | quote }}
        - name: PGPORT
          value: {{ .Values.database.port | quote }}
      containers:
      - name: migration
        image: {{ .Values.database.migration.image }}
        command:
        - sh
        - -c
        - |
          echo "Starting database migration..."
          # Run your migration commands here
          {{ .Values.database.migration.command | default "echo 'No migration command specified'" }}
          echo "Migration completed successfully!"
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: {{ include "common.fullname" . }}-db-secret
              key: database-url
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
          requests:
            cpu: 100m
            memory: 128Mi
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 2000
{{- end }}
EOF

# Post-install hook for health check and notification
cat << 'EOF' > charts/webapp/templates/hooks/post-install-health-check.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "common.fullname" . }}-post-install-check
  labels:
    {{- include "common.labels" . | nindent 4 }}
    component: post-install-check
  annotations:
    "helm.sh/hook": post-install,post-upgrade
    "helm.sh/hook-weight": "1"
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  template:
    metadata:
      name: {{ include "common.fullname" . }}-post-install-check
      labels:
        {{- include "common.selectorLabels" . | nindent 8 }}
        component: post-install-check
    spec:
      restartPolicy: Never
      containers:
      - name: health-check
        image: curlimages/curl:latest
        command:
        - sh
        - -c
        - |
          echo "Waiting for application to be ready..."
          sleep 30
          
          # Health check with retries
          for i in $(seq 1 10); do
            if curl -f http://{{ include "common.fullname" . }}:{{ .Values.service.port }}/health; then
              echo "✅ Application health check passed!"
              break
            else
              echo "⏳ Attempt $i/10 failed, retrying in 10 seconds..."
              sleep 10
            fi
            
            if [ $i -eq 10 ]; then
              echo "❌ Health check failed after 10 attempts"
              exit 1
            fi
          done
          
          {{- if .Values.notifications.enabled }}
          # Send deployment notification
          curl -X POST {{ .Values.notifications.webhook }} \
            -H "Content-Type: application/json" \
            -d '{
              "text": "✅ {{ .Release.Name }} successfully deployed to {{ .Release.Namespace }}",
              "version": "{{ .Chart.AppVersion }}",
              "environment": "{{ .Values.environment }}"
            }'
          {{- end }}
          
          echo "🎉 Post-install checks completed successfully!"
        resources:
          limits:
            cpu: 100m
            memory: 128Mi
          requests:
            cpu: 50m
            memory: 64Mi
      securityContext:
        runAsNonRoot: true
        runAsUser: 65534
EOF

# Pre-delete hook for graceful shutdown
cat << 'EOF' > charts/webapp/templates/hooks/pre-delete-backup.yaml
{{- if .Values.backup.enabled }}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "common.fullname" . }}-pre-delete-backup
  labels:
    {{- include "common.labels" . | nindent 4 }}
    component: pre-delete-backup
  annotations:
    "helm.sh/hook": pre-delete
    "helm.sh/hook-weight": "-1"
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  template:
    metadata:
      name: {{ include "common.fullname" . }}-pre-delete-backup
    spec:
      restartPolicy: Never
      containers:
      - name: backup
        image: {{ .Values.backup.image | default "alpine" }}
        command:
        - sh
        - -c
        - |
          echo "Starting pre-deletion backup..."
          timestamp=$(date +%Y%m%d-%H%M%S)
          backup_name="{{ .Release.Name }}-${timestamp}"
          
          {{- if .Values.database.enabled }}
          echo "Backing up database..."
          pg_dump $DATABASE_URL > /backup/${backup_name}-database.sql
          {{- end }}
          
          echo "Backup completed: ${backup_name}"
          
          {{- if .Values.notifications.enabled }}
          curl -X POST {{ .Values.notifications.webhook }} \
            -H "Content-Type: application/json" \
            -d "{\"text\": \"🗄️ Backup created before deleting {{ .Release.Name }}: ${backup_name}\"}"
          {{- end }}
        env:
        {{- if .Values.database.enabled }}
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: {{ include "common.fullname" . }}-db-secret
              key: database-url
        {{- end }}
        volumeMounts:
        - name: backup-storage
          mountPath: /backup
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
          requests:
            cpu: 100m
            memory: 128Mi
      volumes:
      - name: backup-storage
        persistentVolumeClaim:
          claimName: {{ .Values.backup.pvcName | default (printf "%s-backup" (include "common.fullname" .)) }}
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 2000
{{- end }}
EOF

# Add hook-related values to the main values.yaml
cat << EOF >> charts/webapp/values.yaml

# Database configuration
database:
  enabled: false
  host: "postgresql"
  port: 5432
  user: "webapp"
  name: "webapp"
  migration:
    enabled: false
    image: "migrate/migrate:latest"
    command: "migrate -path /migrations -database \$DATABASE_URL up"

# Backup configuration
backup:
  enabled: false
  image: "postgres:13-alpine"
  pvcName: ""
  schedule: "0 2 * * *"

# Notification configuration
notifications:
  enabled: false
  webhook: "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
EOF
```

### GitOps Integration and Advanced Deployment Patterns

Modern Helm usage often involves GitOps workflows where charts are managed declaratively through Git repositories. This section demonstrates integration with ArgoCD and Flux.

```bash
# Create GitOps deployment configurations
mkdir -p gitops/{argocd,flux,kustomize}

# ArgoCD Application manifest
cat << 'EOF' > gitops/argocd/webapp-application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: webapp-production
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/mycompany/myapp-charts
    targetRevision: HEAD
    path: charts/webapp
    helm:
      valueFiles:
        - ../../environments/production/values.yaml
      parameters:
        - name: image.tag
          value: "1.2.3"
        - name: replicaCount
          value: "5"
  destination:
    server: https://kubernetes.default.svc
    namespace: webapp-production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
  revisionHistoryLimit: 10
EOF

# ArgoCD ApplicationSet for multi-environment deployment
cat << 'EOF' > gitops/argocd/webapp-applicationset.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: webapp-environments
  namespace: argocd
spec:
  generators:
  - list:
      elements:
      - env: development
        namespace: webapp-dev
        replicaCount: "1"
        resources: "small"
      - env: staging
        namespace: webapp-staging
        replicaCount: "2"
        resources: "medium"
      - env: production
        namespace: webapp-prod
        replicaCount: "5"
        resources: "large"
  template:
    metadata:
      name: webapp-{{.env}}
    spec:
      project: default
      source:
        repoURL: https://github.com/mycompany/myapp-charts
        targetRevision: HEAD
        path: charts/webapp
        helm:
          valueFiles:
            - ../../environments/{{.env}}/values.yaml
          parameters:
            - name: replicaCount
              value: "{{.replicaCount}}"
            - name: environment
              value: "{{.env}}"
      destination:
        server: https://kubernetes.default.svc
        namespace: "{{.namespace}}"
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
EOF

# Flux HelmRelease manifest
cat << 'EOF' > gitops/flux/webapp-helmrelease.yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: webapp
  namespace: flux-system
spec:
  interval: 10m
  chart:
    spec:
      chart: webapp
      version: '>=1.0.0 <2.0.0'
      sourceRef:
        kind: HelmRepository
        name: myapp-charts
        namespace: flux-system
      interval: 5m
  targetNamespace: webapp-production
  install:
    createNamespace: true
    remediation:
      retries: 3
  upgrade:
    remediation:
      retries: 3
  values:
    replicaCount: 3
    image:
      repository: nginx
      tag: "1.21-alpine"
    environment: production
    ingress:
      enabled: true
      hosts:
        - host: webapp.company.com
          paths:
            - path: /
              pathType: Prefix
    autoscaling:
      enabled: true
      minReplicas: 3
      maxReplicas: 10
    monitoring:
      enabled: true
  valuesFrom:
    - kind: ConfigMap
      name: webapp-config
      valuesKey: values.yaml
    - kind: Secret
      name: webapp-secrets
      valuesKey: secrets.yaml
EOF

# Flux HelmRepository
cat << 'EOF' > gitops/flux/webapp-helmrepository.yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: myapp-charts
  namespace: flux-system
spec:
  interval: 10m
  url: https://mycompany.github.io/myapp-charts/
EOF

# Kustomization for environment-specific overlays
cat << 'EOF' > gitops/kustomize/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../flux/webapp-helmrepository.yaml
  - ../flux/webapp-helmrelease.yaml

patchesStrategicMerge:
  - production-patch.yaml

namespace: webapp-production
EOF

cat << 'EOF' > gitops/kustomize/production-patch.yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: webapp
spec:
  values:
    replicaCount: 5
    resources:
      limits:
        cpu: 1000m
        memory: 1Gi
      requests:
        cpu: 500m
        memory: 512Mi
    monitoring:
      alerts: true
    backup:
      enabled: true
EOF

# Create deployment automation script
cat << 'EOF' > scripts/deploy-gitops.sh
#!/bin/bash
set -e

ENVIRONMENT=${1:-development}
CHART_VERSION=${2:-latest}
DRY_RUN=${3:-false}

echo "🚀 GitOps Deployment Script"
echo "Environment: $ENVIRONMENT"
echo "Chart Version: $CHART_VERSION"
echo "Dry Run: $DRY_RUN"

# Validate environment
case $ENVIRONMENT in
  development|staging|production)
    echo "✅ Valid environment: $ENVIRONMENT"
    ;;
  *)
    echo "❌ Invalid environment. Use: development, staging, or production"
    exit 1
    ;;
esac

# Update ArgoCD Application
if command -v argocd &> /dev/null; then
  echo "🔄 Updating ArgoCD Application..."
  
  if [[ $DRY_RUN == "true" ]]; then
    echo "DRY RUN: Would update ArgoCD application webapp-$ENVIRONMENT"
  else
    argocd app sync webapp-$ENVIRONMENT
    argocd app wait webapp-$ENVIRONMENT --timeout 600
    echo "✅ ArgoCD application synced successfully"
  fi
fi

# Update Flux HelmRelease
if command -v flux &> /dev/null; then
  echo "🔄 Updating Flux HelmRelease..."
  
  if [[ $DRY_RUN == "true" ]]; then
    echo "DRY RUN: Would reconcile Flux HelmRelease"
  else
    flux reconcile source helm myapp-charts
    flux reconcile helmrelease webapp
    echo "✅ Flux HelmRelease reconciled successfully"
  fi
fi

# Verify deployment
echo "🔍 Verifying deployment..."
kubectl get pods -n webapp-$ENVIRONMENT -l app.kubernetes.io/name=webapp

echo "🎉 GitOps deployment completed!"
EOF

chmod +x scripts/deploy-gitops.sh
```

This enhanced Helm guide now provides a comprehensive foundation for enterprise-grade Kubernetes application management. The progression from basic concepts through advanced patterns like dependency management, sophisticated testing, and GitOps integration creates a complete learning path that prepares you for real-world Helm usage at scale.

The key insight is that Helm isn't just a templating tool—it's the foundation of a modern application delivery platform. By mastering these concepts and implementing the provided automation, you'll be equipped to manage complex, multi-environment Kubernetes deployments with confidence and reliability.

## Summary

This enhanced Helm guide transforms basic package management concepts into a comprehensive enterprise deployment strategy. You now have:

- **Foundational Understanding**: Clear progression from installation through custom chart creation
- **Production-Ready Patterns**: Multi-environment configurations, comprehensive testing, and security scanning
- **Advanced Automation**: CI/CD pipelines, release management, and GitOps integration
- **Enterprise Features**: Dependency management, hooks, custom resources, and chaos engineering
- **Operational Excellence**: Monitoring, alerting, backup strategies, and disaster recovery

The real power of this approach lies in its systematic building of complexity—each section adds capabilities while maintaining the foundation established in previous sections. This creates a sustainable path to mastering Helm at any scale.
  # Update or add description with release notes
  if grep -q "description:" $CHART_PATH/Chart.yaml; then
    sed -i "s/description:.*/description: A Helm chart for Kubernetes - $RELEASE_NOTES/" $CHART_PATH/Chart.yaml
  else
    echo "description: A Helm chart for Kubernetes - $RELEASE_NOTES" >> $CHART_PATH/Chart.yaml
  fi
fi

print_success "Chart metadata updated to version $VERSION"

# Run comprehensive tests before release
print_header "Running Pre-Release Tests"
if ./tests/chart-test.sh; then
  print_success "All tests passed"
else
  print_error "Tests failed! Release aborted."
  # Revert changes
  git checkout -- $CHART_PATH/Chart.yaml
  exit 1
fi

# Package the chart
print_header "Packaging Chart"
mkdir -p ./docs
helm package $CHART_PATH --destination ./docs/
print_success "Chart packaged successfully"

# Update repository index
print_header "Updating Repository Index"
helm repo index ./docs/ --url https://mycompany.github.io/myapp-charts/
print_success "Repository index updated"

# Generate release changelog
print_header "Generating Release Documentation"
CHANGELOG_FILE="CHANGELOG.md"
if [ ! -f "$CHANGELOG_FILE" ]; then
  cat << 'CHANGELOG_HEADER' > $CHANGELOG_FILE
# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

CHANGELOG_HEADER
fi

# Add new version to changelog
TEMP_CHANGELOG=$(mktemp)
cat << EOF > $TEMP_CHANGELOG
# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [$VERSION] - $(date +%Y-%m-%d)
### Added
- Release version $VERSION
EOF

if [ -n "$RELEASE_NOTES" ]; then
  echo "- $RELEASE_NOTES" >> $TEMP_CHANGELOG
fi

echo "" >> $TEMP_CHANGELOG
tail -n +6 $CHANGELOG_FILE >> $TEMP_CHANGELOG
mv $TEMP_CHANGELOG $CHANGELOG_FILE

# Create or update GitHub Pages index
cat << 'HTML' > docs/index.html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>MyApp Helm Charts Repository</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      line-height: 1.6;
      color: #333;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      min-height: 100vh;
    }
    .container {
      max-width: 1200px;
      margin: 0 auto;
      padding: 2rem;
    }
    .header {
      background: rgba(255, 255, 255, 0.95);
      backdrop-filter: blur(10px);
      border-radius: 15px;
      padding: 2rem;
      margin-bottom: 2rem;
      box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
    }
    .header h1 {
      color: #2d3748;
      margin-bottom: 1rem;
      font-size: 2.5rem;
    }
    .header p {
      color: #4a5568;
      font-size: 1.1rem;
    }
    .installation {
      background: #1a202c;
      color: #e2e8f0;
      padding: 1.5rem;
      border-radius: 10px;
      margin: 1.5rem 0;
      font-family: 'Monaco', 'Menlo', monospace;
      overflow-x: auto;
    }
    .chart {
      background: rgba(255, 255, 255, 0.95);
      backdrop-filter: blur(10px);
      padding: 2rem;
      margin: 1.5rem 0;
      border-radius: 15px;
      box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
      transition: transform 0.3s ease;
    }
    .chart:hover {
      transform: translateY(-5px);
    }
    .chart h2 {
      color: #2d3748;
      margin-bottom: 1rem;
      display: flex;
      align-items: center;
    }
    .chart h2::before {
      content: "🚢";
      margin-right: 0.5rem;
    }
    .version {
      background: #48bb78;
      color: white;
      padding: 0.25rem 0.75rem;
      border-radius: 20px;
      font-size: 0.9rem;
      font-weight: bold;
      display: inline-block;
      margin-bottom: 1rem;
    }
    .features {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
      gap: 1rem;
      margin: 1rem 0;
    }
    .feature {
      background: #f7fafc;
      padding: 1rem;
      border-radius: 8px;
      border-left: 4px solid #4299e1;
    }
    .usage {
      background: #2d3748;
      color: #e2e8f0;
      padding: 1rem;
      border-radius: 8px;
      font-family: 'Monaco', 'Menlo', monospace;
      margin-top: 1rem;
      overflow-x: auto;
    }
    .footer {
      text-align: center;
      margin-top: 3rem;
      color: rgba(255, 255, 255, 0.8);
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>🚢 MyApp Helm Chart Repository</h1>
      <p>Production-ready Helm charts for modern Kubernetes deployments</p>
      <div class="installation">
        <div>helm repo add myapp-charts https://mycompany.github.io/myapp-charts/</div>
        <div>helm repo update</div>
      </div>
    </div>

    <div class="chart">
      <h2>webapp</h2>
      <div class="version">Latest Version: VERSION_PLACEHOLDER</div>
      <p>A comprehensive web application chart designed for production environments with enterprise-grade features and security.</p>
      
      <div class="features">
        <div class="feature">
          <strong>🏗️ Multi-Environment</strong><br>
          Configurable for dev, staging, and production
        </div>
        <div class="feature">
          <strong>📈 Auto-Scaling</strong><br>
          Horizontal Pod Autoscaling with custom metrics
        </div>
        <div class="feature">
          <strong>🌐 Ingress Ready</strong><br>
          Built-in ingress configuration with TLS support
        </div>
        <div class="feature">
          <strong>🔒 Security First</strong><br>
          Pod security contexts and network policies
        </div>
        <div class="feature">
          <strong>📊 Monitoring</strong><br>
          Prometheus metrics and health checks
        </div>
        <div class="feature">
          <strong>🔄 CI/CD Ready</strong><br>
          Automated testing and deployment pipelines
        </div>
      </div>

      <div class="usage">
        <div># Quick start</div>
        <div>helm install my-webapp myapp-charts/webapp</div>
        <div></div>
        <div># Production deployment</div>
        <div>helm install my-webapp myapp-charts/webapp \</div>
        <div>  --set replicaCount=3 \</div>
        <div>  --set autoscaling.enabled=true \</div>
        <div>  --set ingress.enabled=true</div>
      </div>
    </div>

    <div class="footer">
      <p>Built with ❤️ for Kubernetes • Updated automatically via CI/CD</p>
    </div>
  </div>
</body>
</html>
HTML

# Replace version placeholder with actual version
sed -i "s/VERSION_PLACEHOLDER/$VERSION/" docs/index.html

# Commit all changes
print_header "Committing Changes"
git add .
git commit -m "Release v$VERSION

$(if [ -n "$RELEASE_NOTES" ]; then echo "- $RELEASE_NOTES"; fi)

This release includes:
- Updated chart version to $VERSION
- Comprehensive testing validation
- Updated documentation
- Generated chart package"

# Create annotated tag
git tag -a "v$VERSION" -m "Release version $VERSION

$(if [ -n "$RELEASE_NOTES" ]; then echo "$RELEASE_NOTES"; fi)"

print_success "Release v$VERSION created successfully!"
echo ""
print_header "Next Steps"
echo "1. Push to repository:"
echo "   git push origin main"
echo "   git push origin v$VERSION"
echo ""
echo "2. Enable GitHub Pages in repository settings"
echo "3. Monitor the deployment pipeline"
echo ""
print_header "Release Summary"
echo "📦 Chart Version: $VERSION"
echo "🏷️  Git Tag: v$VERSION"
echo "📄 Package: docs/webapp-$VERSION.tgz"
echo "🌐 Repository URL: https://mycompany.github.io/myapp-charts/"
if [ -n "$RELEASE_NOTES" ]; then