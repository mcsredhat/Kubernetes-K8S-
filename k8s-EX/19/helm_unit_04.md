# Unit 4: Advanced Helm Features and Enterprise Patterns

## Learning Objectives
By the end of this unit, you will:
- Implement sophisticated chart dependencies and subcharts
- Master Helm hooks for complex deployment orchestration
- Create chart libraries for organizational standardization
- Integrate Helm with CI/CD pipelines for automated workflows
- Apply enterprise security and compliance patterns

## Chart Dependencies and Subcharts

In enterprise environments, applications rarely exist in isolation. They depend on databases, message queues, monitoring systems, and other services. Helm's dependency system allows you to compose complex applications from smaller, focused charts.

### Understanding Dependency Types

```bash
# Create a new project to explore dependencies
helm create enterprise-app
cd enterprise-app

# Three types of dependencies:
# 1. Required dependencies - always installed
# 2. Conditional dependencies - installed based on configuration  
# 3. Optional dependencies - user choice during installation
```

### Mini-Project 4A: E-commerce Platform with Dependencies

Let's build a comprehensive e-commerce platform that demonstrates all dependency patterns:

```bash
# Update Chart.yaml with complex dependencies
cat << 'EOF' > Chart.yaml
apiVersion: v2
name: enterprise-app
description: Complete e-commerce platform with microservices
type: application
version: 1.0.0
appVersion: "2.0.0"

dependencies:
  # Required: Core infrastructure components
  - name: postgresql
    version: "12.x.x"
    repository: "https://charts.bitnami.com/bitnami"
    tags:
      - database
      - core

  # Conditional: Caching layer
  - name: redis
    version: "17.x.x"
    repository: "https://charts.bitnami.com/bitnami"
    condition: redis.enabled
    tags:
      - cache
      - performance

  # Optional: Message queue for async processing
  - name: rabbitmq
    version: "11.x.x"
    repository: "https://charts.bitnami.com/bitnami"
    condition: messageQueue.enabled
    tags:
      - messaging
      - async

  # Optional: Search functionality
  - name: elasticsearch
    version: "19.x.x"
    repository: "https://charts.bitnami.com/bitnami"
    condition: search.enabled
    tags:
      - search
      - optional

  # Optional: Monitoring stack
  - name: prometheus
    version: "22.x.x"
    repository: "https://prometheus-community.github.io/helm-charts"
    alias: monitoring
    condition: monitoring.enabled
    tags:
      - observability
      - optional

maintainers:
  - name: Platform Team
    email: platform@company.com
EOF
```

### Configure Dependency Values

```bash
# Create comprehensive values.yaml with dependency configuration
cat << 'EOF' > values.yaml
# Main application configuration
app:
  name: enterprise-ecommerce
  version: "2.0.0"
  
# Microservices configuration
services:
  frontend:
    enabled: true
    replicaCount: 2
    image:
      repository: mycompany/ecommerce-frontend
      tag: "2.0.0"
    resources:
      requests:
        cpu: 200m
        memory: 256Mi
      limits:
        cpu: 500m
        memory: 512Mi

  api:
    enabled: true
    replicaCount: 3
    image:
      repository: mycompany/ecommerce-api
      tag: "2.0.0"
    resources:
      requests:
        cpu: 500m
        memory: 512Mi
      limits:
        cpu: 1000m
        memory: 1Gi

  orderProcessor:
    enabled: true
    replicaCount: 2
    image:
      repository: mycompany/order-processor
      tag: "2.0.0"

# Dependency configurations
# PostgreSQL - Always enabled (required)
postgresql:
  auth:
    database: ecommerce
    username: ecommerce_user
    existingSecret: ecommerce-db-secret
  primary:
    resources:
      requests:
        cpu: 500m
        memory: 1Gi
      limits:
        cpu: 2000m
        memory: 2Gi
    persistence:
      enabled: true
      size: 50Gi
      storageClass: fast-ssd

# Redis - Conditionally enabled
redis:
  enabled: true
  auth:
    enabled: true
    existingSecret: redis-secret
  master:
    resources:
      requests:
        cpu: 250m
        memory: 256Mi
      limits:
        cpu: 500m
        memory: 512Mi

# RabbitMQ - Optional message queue
messageQueue:
  enabled: false
rabbitmq:
  auth:
    username: ecommerce
    existingPasswordSecret: rabbitmq-secret
  resources:
    requests:
      cpu: 250m
      memory: 256Mi

# Elasticsearch - Optional search
search:
  enabled: false
elasticsearch:
  master:
    replicaCount: 1
  data:
    replicaCount: 2
  coordinating:
    replicaCount: 1

# Prometheus - Optional monitoring
monitoring:
  enabled: false
prometheus:
  server:
    persistentVolume:
      enabled: true
      size: 20Gi
EOF
```

### Install and Manage Dependencies

```bash
# Download dependency charts
helm dependency update

# Examine what was downloaded
ls charts/
# You'll see: postgresql-12.x.x.tgz, redis-17.x.x.tgz, etc.

# Install with specific dependency configurations
helm install ecommerce-dev . \
  --set redis.enabled=true \
  --set messageQueue.enabled=false \
  --set search.enabled=false \
  --set monitoring.enabled=true \
  --create-namespace \
  --namespace ecommerce-dev

# Install production with all features
helm install ecommerce-prod . \
  --set redis.enabled=true \
  --set messageQueue.enabled=true \
  --set search.enabled=true \
  --set monitoring.enabled=true \
  --create-namespace \
  --namespace ecommerce-prod

# Manage dependency versions
helm dependency list
helm dependency build
```

## Helm Hooks: Advanced Deployment Orchestration

Hooks allow you to intervene at specific points in the release lifecycle. Think of them as "before" and "after" scripts that can handle complex setup, migration, testing, and cleanup tasks.

### Understanding Hook Types

Helm provides several hook types for different lifecycle phases:
- `pre-install`, `post-install`: Run before/after chart installation  
- `pre-upgrade`, `post-upgrade`: Run before/after chart upgrades
- `pre-rollback`, `post-rollback`: Run before/after rollbacks
- `pre-delete`, `post-delete`: Run before/after chart deletion
- `test`: Run when `helm test` is executed

### Mini-Project 4B: Database Migration Pipeline

```bash
# Create comprehensive migration hooks
mkdir -p templates/hooks

# Pre-install hook: Database schema setup
cat << 'EOF' > templates/hooks/pre-install-db-setup.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "enterprise-app.fullname" . }}-db-setup
  labels:
    {{- include "enterprise-app.labels" . | nindent 4 }}
    component: database-setup
  annotations:
    "helm.sh/hook": pre-install
    "helm.sh/hook-weight": "-10"
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  template:
    metadata:
      name: {{ include "enterprise-app.fullname" . }}-db-setup
    spec:
      restartPolicy: Never
      initContainers:
      # Wait for PostgreSQL to be ready
      - name: wait-for-db
        image: postgres:15-alpine
        command:
        - sh
        - -c
        - |
          echo "Waiting for PostgreSQL to be ready..."
          until pg_isready -h {{ include "enterprise-app.fullname" . }}-postgresql -p 5432 -U {{ .Values.postgresql.auth.username }}; do
            echo "PostgreSQL is not ready yet. Waiting 5 seconds..."
            sleep 5
          done
          echo "PostgreSQL is ready!"
        env:
        - name: PGUSER
          value: {{ .Values.postgresql.auth.username }}
      containers:
      - name: db-setup
        image: migrate/migrate:latest
        command:
        - sh
        - -c
        - |
          echo "Creating database schema..."
          migrate -path /migrations -database "${DATABASE_URL}" up
          echo "Database schema created successfully!"
        env:
        - name: DATABASE_URL
          value: "postgres://{{ .Values.postgresql.auth.username }}:$(POSTGRES_PASSWORD)@{{ include "enterprise-app.fullname" . }}-postgresql:5432/{{ .Values.postgresql.auth.database }}?sslmode=disable"
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: {{ .Values.postgresql.auth.existingSecret }}
              key: password
        volumeMounts:
        - name: migrations
          mountPath: /migrations
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
          requests:
            cpu: 100m
            memory: 128Mi
      volumes:
      - name: migrations
        configMap:
          name: {{ include "enterprise-app.fullname" . }}-migrations
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 2000
EOF

# Pre-upgrade hook: Database migration with backup
cat << 'EOF' > templates/hooks/pre-upgrade-migration.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "enterprise-app.fullname" . }}-migration-{{ .Release.Revision }}
  labels:
    {{- include "enterprise-app.labels" . | nindent 4 }}
    component: database-migration
  annotations:
    "helm.sh/hook": pre-upgrade
    "helm.sh/hook-weight": "-5"
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: migration
        image: migrate/migrate:latest
        command:
        - sh
        - -c
        - |
          echo "Starting database migration for release {{ .Release.Revision }}..."
          
          # Create backup before migration
          echo "Creating backup..."
          pg_dump "${DATABASE_URL}" > "/backup/backup-$(date +%Y%m%d-%H%M%S).sql"
          
          # Run migrations
          echo "Running migrations..."
          migrate -path /migrations -database "${DATABASE_URL}" up
          
          echo "Migration completed successfully!"
        env:
        - name: DATABASE_URL
          value: "postgres://{{ .Values.postgresql.auth.username }}:$(POSTGRES_PASSWORD)@{{ include "enterprise-app.fullname" . }}-postgresql:5432/{{ .Values.postgresql.auth.database }}?sslmode=disable"
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: {{ .Values.postgresql.auth.existingSecret }}
              key: password
        volumeMounts:
        - name: migrations
          mountPath: /migrations
        - name: backup-storage
          mountPath: /backup
        resources:
          limits:
            cpu: 1000m
            memory: 1Gi
          requests:
            cpu: 200m
            memory: 256Mi
      volumes:
      - name: migrations
        configMap:
          name: {{ include "enterprise-app.fullname" . }}-migrations
      - name: backup-storage
        persistentVolumeClaim:
          claimName: {{ include "enterprise-app.fullname" . }}-backup-pvc
EOF

# Post-install hook: Data seeding and verification
cat << 'EOF' > templates/hooks/post-install-seed.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "enterprise-app.fullname" . }}-data-seed
  labels:
    {{- include "enterprise-app.labels" . | nindent 4 }}
    component: data-seeding
  annotations:
    "helm.sh/hook": post-install
    "helm.sh/hook-weight": "5"
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: data-seed
        image: {{ .Values.services.api.image.repository }}:{{ .Values.services.api.image.tag }}
        command:
        - sh
        - -c
        - |
          echo "Seeding initial data..."
          
          # Wait for API to be ready
          echo "Waiting for API service to be ready..."
          until curl -f http://{{ include "enterprise-app.fullname" . }}-api:3000/health; do
            echo "API not ready, waiting 10 seconds..."
            sleep 10
          done
          
          # Seed data
          node scripts/seed-data.js
          
          # Verify seeding
          echo "Verifying data seeding..."
          node scripts/verify-seed.js
          
          echo "Data seeding completed successfully!"
        env:
        - name: DATABASE_URL
          value: "postgres://{{ .Values.postgresql.auth.username }}:$(POSTGRES_PASSWORD)@{{ include "enterprise-app.fullname" . }}-postgresql:5432/{{ .Values.postgresql.auth.database }}"
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: {{ .Values.postgresql.auth.existingSecret }}
              key: password
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
          requests:
            cpu: 100m
            memory: 128Mi
EOF

# Test hook: Comprehensive application testing
cat << 'EOF' > templates/hooks/test-comprehensive.yaml
apiVersion: v1
kind: Pod
metadata:
  name: {{ include "enterprise-app.fullname" . }}-test
  labels:
    {{- include "enterprise-app.labels" . | nindent 4 }}
    component: testing
  annotations:
    "helm.sh/hook": test
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  restartPolicy: Never
  containers:
  - name: comprehensive-test
    image: curlimages/curl:latest
    command:
    - sh
    - -c
    - |
      echo "Running comprehensive application tests..."
      
      # Test 1: API Health Check
      echo "Test 1: API Health Check"
      if curl -f http://{{ include "enterprise-app.fullname" . }}-api:3000/health; then
        echo "✅ API health check passed"
      else
        echo "❌ API health check failed"
        exit 1
      fi
      
      # Test 2: Database connectivity
      echo "Test 2: Database Connectivity"
      if curl -f http://{{ include "enterprise-app.fullname" . }}-api:3000/db-status; then
        echo "✅ Database connectivity test passed"
      else
        echo "❌ Database connectivity test failed"
        exit 1
      fi
      
      {{- if .Values.redis.enabled }}
      # Test 3: Redis connectivity (if enabled)
      echo "Test 3: Redis Connectivity"
      if curl -f http://{{ include "enterprise-app.fullname" . }}-api:3000/cache-status; then
        echo "✅ Redis connectivity test passed"
      else
        echo "❌ Redis connectivity test failed"
        exit 1
      fi
      {{- end }}
      
      # Test 4: Frontend availability
      echo "Test 4: Frontend Availability"
      if curl -f http://{{ include "enterprise-app.fullname" . }}-frontend:3000/; then
        echo "✅ Frontend availability test passed"
      else
        echo "❌ Frontend availability test failed"
        exit 1
      fi
      
      echo "🎉 All tests passed successfully!"
  resources:
    limits:
      cpu: 100m
      memory: 128Mi
    requests:
      cpu: 50m
      memory: 64Mi
EOF

# Pre-delete hook: Data backup and cleanup preparation
cat << 'EOF' > templates/hooks/pre-delete-backup.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "enterprise-app.fullname" . }}-pre-delete-backup
  labels:
    {{- include "enterprise-app.labels" . | nindent 4 }}
    component: pre-delete-backup
  annotations:
    "helm.sh/hook": pre-delete
    "helm.sh/hook-weight": "-5"
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: backup
        image: postgres:15-alpine
        command:
        - sh
        - -c
        - |
          echo "Creating final backup before deletion..."
          timestamp=$(date +%Y%m%d-%H%M%S)
          backup_file="/backup/final-backup-${timestamp}.sql"
          
          pg_dump "${DATABASE_URL}" > "${backup_file}"
          echo "Backup created: ${backup_file}"
          
          # Notify about the backup location
          echo "Backup available at: ${backup_file}"
          echo "Please ensure this backup is moved to permanent storage!"
        env:
        - name: DATABASE_URL
          value: "postgres://{{ .Values.postgresql.auth.username }}:$(POSTGRES_PASSWORD)@{{ include "enterprise-app.fullname" . }}-postgresql:5432/{{ .Values.postgresql.auth.database }}"
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: {{ .Values.postgresql.auth.existingSecret }}
              key: password
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
          claimName: {{ include "enterprise-app.fullname" . }}-backup-pvc
EOF
```

### Create Supporting Resources for Hooks

```bash
# Create migrations ConfigMap
cat << 'EOF' > templates/migrations-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "enterprise-app.fullname" . }}-migrations
  labels:
    {{- include "enterprise-app.labels" . | nindent 4 }}
data:
  001_initial_schema.up.sql: |
    -- Initial database schema for e-commerce platform
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    
    -- Users table
    CREATE TABLE IF NOT EXISTS users (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      email VARCHAR(255) UNIQUE NOT NULL,
      password_hash VARCHAR(255) NOT NULL,
      first_name VARCHAR(100),
      last_name VARCHAR(100),
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    
    -- Products table
    CREATE TABLE IF NOT EXISTS products (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      name VARCHAR(255) NOT NULL,
      description TEXT,
      price DECIMAL(10,2) NOT NULL,
      stock_quantity INTEGER DEFAULT 0,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    
    -- Orders table
    CREATE TABLE IF NOT EXISTS orders (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      user_id UUID REFERENCES users(id),
      status VARCHAR(50) DEFAULT 'pending',
      total_amount DECIMAL(10,2) NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    
    -- Order items table
    CREATE TABLE IF NOT EXISTS order_items (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      order_id UUID REFERENCES orders(id),
      product_id UUID REFERENCES products(id),
      quantity INTEGER NOT NULL,
      price DECIMAL(10,2) NOT NULL
    );
    
  002_add_indexes.up.sql: |
    -- Performance indexes
    CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
    CREATE INDEX IF NOT EXISTS idx_products_name ON products(name);
    CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id);
    CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
    CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
    CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON order_items(product_id);
    
  003_add_audit_columns.up.sql: |
    -- Add audit columns for tracking changes
    ALTER TABLE users ADD COLUMN IF NOT EXISTS created_by UUID;
    ALTER TABLE users ADD COLUMN IF NOT EXISTS updated_by UUID;
    
    ALTER TABLE products ADD COLUMN IF NOT EXISTS created_by UUID;
    ALTER TABLE products ADD COLUMN IF NOT EXISTS updated_by UUID;
    
    ALTER TABLE orders ADD COLUMN IF NOT EXISTS created_by UUID;
    ALTER TABLE orders ADD COLUMN IF NOT EXISTS updated_by UUID;
EOF

# Create backup PVC
cat << 'EOF' > templates/backup-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ include "enterprise-app.fullname" . }}-backup-pvc
  labels:
    {{- include "enterprise-app.labels" . | nindent 4 }}
    component: backup-storage
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  {{- if .Values.backup.storageClass }}
  storageClassName: {{ .Values.backup.storageClass }}
  {{- end }}
EOF

# Add backup configuration to values.yaml
cat << 'EOF' >> values.yaml

# Backup configuration
backup:
  storageClass: ""
  retentionDays: 30
EOF
```

## Chart Libraries and Standardization

Chart libraries enable organizations to create reusable templates and enforce standards across all applications.

### Mini-Project 4C: Organizational Chart Library

```bash
# Create a library chart for common patterns
helm create company-common-lib
cd company-common-lib

# Convert to library chart
cat << 'EOF' > Chart.yaml
apiVersion: v2
name: company-common-lib
description: Common templates and standards for company applications
type: library
version: 1.0.0
maintainers:
  - name: Platform Team
    email: platform@company.com
keywords:
  - library
  - standards
  - templates
EOF

# Create comprehensive library templates
cat << 'EOF' > templates/_common.tpl
{{/*
Company standard labels
Usage: {{ include "company.labels" . }}
*/}}
{{- define "company.labels" -}}
helm.sh/chart: {{ include "company.chart" . }}
{{ include "company.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
company.com/team: {{ .Values.team | default "unknown" }}
company.com/environment: {{ .Values.environment | default "development" }}
company.com/cost-center: {{ .Values.costCenter | default "engineering" }}
{{- end }}

{{/*
Company security context
Usage: {{ include "company.securityContext" . }}
*/}}
{{- define "company.securityContext" -}}
runAsNonRoot: true
runAsUser: 1000
runAsGroup: 1000
fsGroup: 1000
seccompProfile:
  type: RuntimeDefault
capabilities:
  drop:
    - ALL
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
{{- end }}

{{/*
Company resource defaults
Usage: {{ include "company.resources" .Values.resources }}
*/}}
{{- define "company.resources" -}}
{{- $resources := . -}}
{{- if not $resources }}
{{- $resources = dict "requests" (dict "cpu" "100m" "memory" "128Mi") "limits" (dict "cpu" "500m" "memory" "512Mi") -}}
{{- end }}
limits:
  cpu: {{ $resources.limits.cpu | default "500m" }}
  memory: {{ $resources.limits.memory | default "512Mi" }}
requests:
  cpu: {{ $resources.requests.cpu | default "100m" }}
  memory: {{ $resources.requests.memory | default "128Mi" }}
{{- end }}

{{/*
Company network policy
Usage: {{ include "company.networkPolicy" . }}
*/}}
{{- define "company.networkPolicy" -}}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ include "common.fullname" . }}
  labels:
    {{- include "company.labels" . | nindent 4 }}
spec:
  podSelector:
    matchLabels:
      {{- include "common.selectorLabels" . | nindent 6 }}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: {{ .Release.Namespace }}
    - podSelector: {}
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
  - to: []
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 443
{{- end }}

{{/*
Company monitoring annotations
Usage: {{ include "company.monitoringAnnotations" . }}
*/}}
{{- define "company.monitoringAnnotations" -}}
prometheus.io/scrape: "true"
prometheus.io/port: {{ .Values.monitoring.port | default "9090" | quote }}
prometheus.io/path: {{ .Values.monitoring.path | default "/metrics" }}
{{- end }}
EOF

# Create deployment template
cat << 'EOF' > templates/_deployment.tpl
{{/*
Company standard deployment
Usage: {{ include "company.deployment" . }}
*/}}
{{- define "company.deployment" -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "common.fullname" . }}
  labels:
    {{- include "company.labels" . | nindent 4 }}
  annotations:
    company.com/deployment-strategy: {{ .Values.deploymentStrategy | default "RollingUpdate" }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount | default 1 }}
  {{- end }}
  strategy:
    type: {{ .Values.deploymentStrategy | default "RollingUpdate" }}
    {{- if eq (.Values.deploymentStrategy | default "RollingUpdate") "RollingUpdate" }}
    rollingUpdate:
      maxUnavailable: {{ .Values.rollingUpdate.maxUnavailable | default "25%" }}
      maxSurge: {{ .Values.rollingUpdate.maxSurge | default "25%" }}
    {{- end }}
  selector:
    matchLabels:
      {{- include "common.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "common.selectorLabels" . | nindent 8 }}
        {{- include "company.labels" . | nindent 8 }}
      annotations:
        {{- include "company.monitoringAnnotations" . | nindent 8 }}
        company.com/config-hash: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
    spec:
      securityContext:
        {{- include "company.securityContext" . | nindent 8 }}
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy | default "IfNotPresent" }}
          securityContext:
            {{- include "company.securityContext" . | nindent 12 }}
          resources:
            {{- include "company.resources" .Values.resources | nindent 12 }}
          {{- if .Values.healthChecks }}
          livenessProbe:
            {{- toYaml .Values.healthChecks.liveness | nindent 12 }}
          readinessProbe:
            {{- toYaml .Values.healthChecks.readiness | nindent 12 }}
          {{- end }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end }}
EOF
```

## CI/CD Integration Patterns

### Mini-Project 4D: Automated Helm Pipeline

```bash
# Create comprehensive CI/CD pipeline
mkdir -p .github/workflows

cat << 'EOF' > .github/workflows/helm-ci-cd.yaml
name: Helm Chart CI/CD Pipeline

on:
  push:
    branches: [ main, develop ]
    paths: [ 'charts/**' ]
  pull_request:
    branches: [ main ]
    paths: [ 'charts/**' ]
  release:
    types: [ published ]

env:
  HELM_VERSION: "3.14.0"
  KUBERNETES_VERSION: "1.28.0"

jobs:
  lint-and-validate:
    name: Lint and Validate Charts
    runs-on: ubuntu-latest
    steps:
    - name: Checkout
      uses: actions/checkout@v4
      with:
        fetch-depth: 0

    - name: Set up Helm
      uses: azure/setup-helm@v4
      with:
        version: v${{ env.HELM_VERSION }}

    - name: Set up Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.11'

    - name: Set up chart-testing
      uses: helm/chart-testing-action@v2.6.1

    - name: Run chart-testing (list-changed)
      id: list-changed
      run: |
        changed=$(ct list-changed --target-branch ${{ github.event.repository.default_branch }})
        if [[ -n "$changed" ]]; then
          echo "changed=true" >> $GITHUB_OUTPUT
        fi

    - name: Run chart-testing (lint)
      if: steps.list-changed.outputs.changed == 'true'
      run: ct lint --target-branch ${{ github.event.repository.default_branch }}

    - name: Validate Helm templates
      if: steps.list-changed.outputs.changed == 'true'
      run: |
        for chart in charts/*/; do
          if [[ -d "$chart" ]]; then
            echo "Validating $chart"
            helm template test "$chart" --debug --validate
            helm template test "$chart" --set replicaCount=3 --validate
          fi
        done

  security-scan:
    name: Security Scanning
    runs-on: ubuntu-latest
    needs: lint-and-validate
    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Run Checkov security scan
      uses: bridgecrewio/checkov-action@master
      with:
        directory: .
        framework: kubernetes
        output_format: sarif
        output_file_path: reports/results.sarif

    - name: Upload Checkov results to GitHub
      uses: github/codeql-action/upload-sarif@v2
      if: always()
      with:
        sarif_file: reports/results.sarif

  integration-test:
    name: Integration Testing
    runs-on: ubuntu-latest
    needs: lint-and-validate
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
        version: v${{ env.HELM_VERSION }}

    - name: Set up chart-testing
      uses: helm/chart-testing-action@v2.6.1

    - name: Create kind cluster
      uses: helm/kind-action@v1.8.0
      with:
        node_image: kindest/node:${{ matrix.k8s-version }}
        cluster_name: kind-cluster-${{ matrix.k8s-version }}

    - name: Install chart dependencies
      run: |
        for chart in charts/*/; do
          if [[ -f "$chart/Chart.yaml" ]]; then
            helm dependency update "$chart"
          fi
        done

    - name: Run chart-testing (install)
      run: ct install --target-branch ${{ github.event.repository.default_branch }}

    - name: Run custom integration tests
      run: |
        # Custom test script
        ./scripts/integration-tests.sh

  package-and-release:
    name: Package and Release
    runs-on: ubuntu-latest
    needs: [lint-and-validate, security-scan, integration-test]
    if: github.event_name == 'release' || (github.event_name == 'push' && github.ref == 'refs/heads/main')
    steps:
    - name: Checkout
      uses: actions/checkout@v4
      with:
        fetch-depth: 0
        token: ${{ secrets.GITHUB_TOKEN }}

    - name: Configure Git
      run: |
        git config user.name "$GITHUB_ACTOR"
        git config user.email "$GITHUB_ACTOR@users.noreply.github.com"

    - name: Set up Helm
      uses: azure/setup-helm@v4
      with:
        version: v${{ env.HELM_VERSION }}

    - name: Package Helm charts
      run: |
        mkdir -p .helm-releases
        for chart in charts/*/; do
          if [[ -d "$chart" ]]; then
            helm package "$chart" --destination .helm-releases/
          fi
        done

    - name: Update Helm repository index
      run: |
        helm repo index .helm-releases/ \
          --url https://${{ github.repository_owner }}.github.io/${{ github.event.repository.name }}/

    - name: Deploy to GitHub Pages
      uses: peaceiris/actions-gh-pages@v3
      with:
        github_token: ${{ secrets.GITHUB_TOKEN }}
        publish_dir: .helm-releases
        enable_jekyll: false

    - name: Create GitHub Release
      if: github.event_name == 'release'
      uses: softprops/action-gh-release@v1
      with:
        files: .helm-releases/*.tgz
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  notify:
    name: Notification
    runs-on: ubuntu-latest
    needs: [package-and-release]
    if: always()
    steps:
    - name: Notify Slack
      uses: 8398a7/action-slack@v3
      with:
        status: ${{ job.status }}
        channel: '#platform-engineering'
        webhook_url: ${{ secrets.SLACK_WEBHOOK }}
        fields: repo,message,commit,author,action,eventName,ref,workflow
EOF

# Create integration test script
cat << 'EOF' > scripts/integration-tests.sh
#!/bin/bash
set -e

echo "Running comprehensive integration tests..."

# Test 1: Chart installation with different configurations
echo "Test 1: Multi-configuration deployment testing"

NAMESPACE="integration-test"
kubectl create namespace $NAMESPACE || true

# Test minimal configuration
helm install test-minimal charts/enterprise-app \
  --namespace $NAMESPACE \
  --set redis.enabled=false \
  --set messageQueue.enabled=false \
  --set search.enabled=false \
  --wait --timeout=600s

# Verify deployment
kubectl wait --for=condition=available deployment/test-minimal-enterprise-app \
  -n $NAMESPACE --timeout=300s

echo "✅ Minimal configuration test passed"

# Test full configuration
helm install test-full charts/enterprise-app \
  --namespace $NAMESPACE \
  --set redis.enabled=true