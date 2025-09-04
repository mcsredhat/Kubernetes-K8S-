# Unit 3: Creating Custom Helm Charts

## Learning Objectives
By the end of this unit, you will:
- Generate and understand the structure of custom Helm charts
- Create flexible templates using Go template syntax
- Build reusable helper functions and conditionals
- Package and validate your own charts

## Why Create Custom Charts?

While public charts cover many common applications, real-world scenarios often require:
- Custom applications that don't have existing charts
- Specific organizational requirements (security policies, naming conventions)
- Complex multi-service applications
- Internal tooling and utilities

Think of creating a chart as building a blueprint that others (including future you) can use to deploy your application consistently.

## Chart Structure Deep Dive

Let's start by understanding what Helm generates and why each piece matters:

```bash
# Create your first custom chart
helm create my-webapp
cd my-webapp

# Examine the generated structure
tree .
```

The generated structure follows these conventions:

```
my-webapp/
├── Chart.yaml          # Chart metadata and dependencies
├── values.yaml         # Default configuration values
├── charts/             # Chart dependencies (sub-charts)
├── templates/          # Kubernetes resource templates
│   ├── deployment.yaml # Main application deployment
│   ├── service.yaml    # Network service configuration
│   ├── ingress.yaml    # External access rules
│   ├── hpa.yaml        # Horizontal Pod Autoscaler
│   ├── NOTES.txt       # Post-installation instructions
│   └── _helpers.tpl    # Template helper functions
└── tests/              # Chart testing configurations
    └── test-connection.yaml
```

**Quick Understanding Check**: Which files do you think contain the actual Kubernetes resource definitions? Which ones contain the configuration options?

## Mini-Project 3: Building a Custom Web Application Chart

Let's build a chart for a fictional Node.js web application. This project will take you through the complete process of chart creation.

### Step 1: Initialize and Plan

```bash
# Create a new chart for our web application
helm create node-web-app
cd node-web-app

# Before modifying anything, let's plan what our application needs:
# 1. A Deployment to run our Node.js application
# 2. A Service to expose it internally
# 3. An optional Ingress for external access
# 4. ConfigMaps for application configuration
# 5. Secrets for sensitive data
# 6. Health checks and resource limits
```

### Step 2: Design the Values Structure

First, let's design our values.yaml to reflect real-world needs:

```bash
cat << 'EOF' > values.yaml
# Node.js Web Application Configuration

# Application metadata
app:
  name: "node-web-app"
  version: "1.0.0"

# Container image configuration
image:
  repository: node
  tag: "18-alpine"
  pullPolicy: IfNotPresent
  pullSecrets: []

# Application-specific configuration
nodeApp:
  # Port the application listens on
  port: 3000
  # Node.js environment
  nodeEnv: production
  # Custom environment variables
  envVars:
    LOG_LEVEL: info
    DATABASE_URL: ""
  # Configuration files to mount
  configFiles: {}
    # config.json: |
    #   {
    #     "database": {
    #       "host": "localhost"
    #     }
    #   }

# Deployment configuration
deployment:
  replicaCount: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1

# Service configuration
service:
  type: ClusterIP
  port: 80
  targetPort: 3000
  annotations: {}

# Ingress configuration
ingress:
  enabled: false
  className: ""
  annotations: {}
  hosts:
    - host: my-app.local
      paths:
        - path: /
          pathType: Prefix
  tls: []

# Resource limits and requests
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi

# Health check configuration
healthChecks:
  livenessProbe:
    httpGet:
      path: /health
      port: 3000
    initialDelaySeconds: 30
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 3
  readinessProbe:
    httpGet:
      path: /ready
      port: 3000
    initialDelaySeconds: 5
    periodSeconds: 5
    timeoutSeconds: 3
    failureThreshold: 3

# Horizontal Pod Autoscaling
autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

# Security context
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000
  capabilities:
    drop:
      - ALL

# Node selection and affinity
nodeSelector: {}
tolerations: []
affinity: {}

# Pod disruption budget
podDisruptionBudget:
  enabled: false
  minAvailable: 1

# Service account
serviceAccount:
  create: true
  annotations: {}
  name: ""

# Additional labels to apply to all resources
labels: {}

# Additional annotations to apply to all resources
annotations: {}
EOF
```

### Step 3: Build Template Helpers

Now let's create comprehensive helper functions:

```bash
cat << 'EOF' > templates/_helpers.tpl
{{/*
Expand the name of the chart.
*/}}
{{- define "node-web-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "node-web-app.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "node-web-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "node-web-app.labels" -}}
helm.sh/chart: {{ include "node-web-app.chart" . }}
{{ include "node-web-app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: {{ .Values.app.name }}
{{- with .Values.labels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "node-web-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "node-web-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "node-web-app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "node-web-app.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Generate environment variables for the application
*/}}
{{- define "node-web-app.envVars" -}}
- name: NODE_ENV
  value: {{ .Values.nodeApp.nodeEnv | quote }}
- name: PORT
  value: {{ .Values.nodeApp.port | quote }}
{{- range $key, $value := .Values.nodeApp.envVars }}
- name: {{ $key }}
  value: {{ $value | quote }}
{{- end }}
{{- end }}

{{/*
Common annotations
*/}}
{{- define "node-web-app.annotations" -}}
{{- with .Values.annotations }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Generate container security context
*/}}
{{- define "node-web-app.containerSecurityContext" -}}
runAsNonRoot: {{ .Values.securityContext.runAsNonRoot }}
runAsUser: {{ .Values.securityContext.runAsUser }}
runAsGroup: {{ .Values.securityContext.runAsGroup }}
capabilities:
  drop: {{ .Values.securityContext.capabilities.drop | toYaml | nindent 4 }}
{{- end }}

{{/*
Generate pod security context
*/}}
{{- define "node-web-app.podSecurityContext" -}}
fsGroup: {{ .Values.securityContext.fsGroup }}
{{- end }}
EOF