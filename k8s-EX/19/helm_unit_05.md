# Unit 5: Production Helm - Troubleshooting, Performance, and Advanced Operations

## Learning Objectives
By the end of this unit, you will:
- Master advanced Helm troubleshooting techniques for production issues
- Implement performance optimization strategies for large-scale deployments
- Deploy and manage Helm across multiple clusters and environments
- Integrate Helm with service mesh and cloud-native ecosystem tools
- Build disaster recovery and business continuity strategies

## Advanced Helm Troubleshooting

Production Helm deployments can fail in complex ways. Understanding how to diagnose and resolve these issues quickly is crucial for maintaining system reliability.

### Debugging Helm Release Issues

```bash
# Create a troubleshooting toolkit
mkdir helm-troubleshooting
cd helm-troubleshooting

# Script for comprehensive release diagnosis
cat << 'EOF' > diagnose-release.sh
#!/bin/bash
set -e

RELEASE_NAME=${1:-""}
NAMESPACE=${2:-"default"}

if [ -z "$RELEASE_NAME" ]; then
    echo "Usage: $0 <release-name> [namespace]"
    exit 1
fi

echo "🔍 Diagnosing Helm Release: $RELEASE_NAME in namespace: $NAMESPACE"
echo "============================================================"

# Check if release exists
echo "📋 Release Information:"
if helm list -n $NAMESPACE | grep -q "$RELEASE_NAME"; then
    helm status $RELEASE_NAME -n $NAMESPACE
    echo ""
    
    echo "📊 Release History:"
    helm history $RELEASE_NAME -n $NAMESPACE
    echo ""
    
    echo "⚙️  Current Values:"
    helm get values $RELEASE_NAME -n $NAMESPACE
    echo ""
else
    echo "❌ Release '$RELEASE_NAME' not found in namespace '$NAMESPACE'"
    echo "Available releases in namespace:"
    helm list -n $NAMESPACE
    exit 1
fi

# Analyze Kubernetes resources
echo "🔧 Kubernetes Resource Analysis:"
echo "Deployments:"
kubectl get deployments -l app.kubernetes.io/instance=$RELEASE_NAME -n $NAMESPACE -o wide

echo "Pods:"
kubectl get pods -l app.kubernetes.io/instance=$RELEASE_NAME -n $NAMESPACE -o wide

echo "Services:"
kubectl get services -l app.kubernetes.io/instance=$RELEASE_NAME -n $NAMESPACE -o wide

echo ""
echo "🚨 Problem Detection:"

# Check for failed pods
FAILED_PODS=$(kubectl get pods -l app.kubernetes.io/instance=$RELEASE_NAME -n $NAMESPACE -o json | jq -r '.items[] | select(.status.phase != "Running" and .status.phase != "Succeeded") | .metadata.name' 2>/dev/null || true)

if [ -n "$FAILED_PODS" ]; then
    echo "⚠️  Failed pods detected:"
    for pod in $FAILED_PODS; do
        echo "  Pod: $pod"
        echo "  Status: $(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.status.phase}')"
        echo "  Reason: $(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}' 2>/dev/null || echo 'Unknown')"
        
        echo "  Recent events:"
        kubectl get events --field-selector involvedObject.name=$pod -n $NAMESPACE --sort-by='.lastTimestamp' | tail -5
        
        echo "  Container logs (last 20 lines):"
        kubectl logs $pod -n $NAMESPACE --tail=20 || echo "  Unable to retrieve logs"
        echo ""
    done
else
    echo "✅ All pods are healthy"
fi

# Check for pending pods
PENDING_PODS=$(kubectl get pods -l app.kubernetes.io/instance=$RELEASE_NAME -n $NAMESPACE -o json | jq -r '.items[] | select(.status.phase == "Pending") | .metadata.name' 2>/dev/null || true)

if [ -n "$PENDING_PODS" ]; then
    echo "⏳ Pending pods detected:"
    for pod in $PENDING_PODS; do
        echo "  Pod: $pod"
        kubectl describe pod $pod -n $NAMESPACE | grep -A 10 "Conditions:\|Events:"
    done
fi

# Check resource usage
echo "📊 Resource Usage Analysis:"
kubectl top pods -l app.kubernetes.io/instance=$RELEASE_NAME -n $NAMESPACE 2>/dev/null || echo "Metrics server not available"

# Check for common issues
echo "🔍 Common Issues Check:"

# PVC issues
PVC_ISSUES=$(kubectl get pvc -l app.kubernetes.io/instance=$RELEASE_NAME -n $NAMESPACE -o json | jq -r '.items[] | select(.status.phase != "Bound") | .metadata.name' 2>/dev/null || true)
if [ -n "$PVC_ISSUES" ]; then
    echo "⚠️  PVC issues detected:"
    kubectl get pvc -l app.kubernetes.io/instance=$RELEASE_NAME -n $NAMESPACE
fi

# Service endpoint issues
SERVICES=$(kubectl get services -l app.kubernetes.io/instance=$RELEASE_NAME -n $NAMESPACE -o json | jq -r '.items[].metadata.name' 2>/dev/null || true)
for service in $SERVICES; do
    ENDPOINTS=$(kubectl get endpoints $service -n $NAMESPACE -o json | jq -r '.subsets[]?.addresses[]?.ip' 2>/dev/null || true)
    if [ -z "$ENDPOINTS" ]; then
        echo "⚠️  Service $service has no endpoints"
    fi
done

echo ""
echo "🔧 Suggested Troubleshooting Steps:"
echo "1. Check pod logs: kubectl logs -l app.kubernetes.io/instance=$RELEASE_NAME -n $NAMESPACE"
echo "2. Describe problematic pods: kubectl describe pod <pod-name> -n $NAMESPACE"
echo "3. Check events: kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp'"
echo "4. Verify chart values: helm get values $RELEASE_NAME -n $NAMESPACE"
echo "5. Test with dry-run: helm template $RELEASE_NAME <chart-path> --debug"
echo "6. Check resource quotas: kubectl describe quota -n $NAMESPACE"
EOF

chmod +x diagnose-release.sh
```

### Mini-Project 5A: Troubleshooting Lab

```bash
# Create various problematic scenarios for troubleshooting practice
cat << 'EOF' > create-problem-scenarios.sh
#!/bin/bash

echo "Creating troubleshooting scenarios..."

# Scenario 1: Resource limit issues
cat << 'YAML' > scenario-1-resource-limits.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-starved-app
  labels:
    scenario: resource-limits
spec:
  replicas: 3
  selector:
    matchLabels:
      app: resource-starved
  template:
    metadata:
      labels:
        app: resource-starved
    spec:
      containers:
      - name: memory-hungry
        image: nginx:alpine
        resources:
          requests:
            memory: "2Gi"  # Requesting too much memory
            cpu: "2000m"   # Requesting too much CPU
          limits:
            memory: "4Gi"
            cpu: "4000m"
        command: ["sh", "-c", "while true; do dd if=/dev/zero of=/tmp/memory bs=1M count=1000; sleep 1; done"]
YAML

# Scenario 2: ConfigMap dependency issue
cat << 'YAML' > scenario-2-missing-configmap.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: configmap-dependent-app
spec:
  selector:
    matchLabels:
      app: configmap-dependent
  template:
    metadata:
      labels:
        app: configmap-dependent
    spec:
      containers:
      - name: app
        image: nginx:alpine
        volumeMounts:
        - name: config
          mountPath: /etc/config
        env:
        - name: CONFIG_VALUE
          valueFrom:
            configMapKeyRef:
              name: nonexistent-config  # This ConfigMap doesn't exist
              key: value
      volumes:
      - name: config
        configMap:
          name: nonexistent-config
YAML

# Scenario 3: Image pull issues
cat << 'YAML' > scenario-3-image-pull.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: image-pull-failed-app
spec:
  selector:
    matchLabels:
      app: image-pull-failed
  template:
    metadata:
      labels:
        app: image-pull-failed
    spec:
      containers:
      - name: app
        image: nonexistent-registry.com/fake/image:latest  # Non-existent image
        imagePullPolicy: Always
YAML

# Scenario 4: Service selector mismatch
cat << 'YAML' > scenario-4-service-mismatch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: service-mismatch-app
spec:
  selector:
    matchLabels:
      app: correct-label
  template:
    metadata:
      labels:
        app: correct-label
    spec:
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: service-mismatch-svc
spec:
  selector:
    app: wrong-label  # This doesn't match the deployment labels
  ports:
  - port: 80
    targetPort: 80
YAML

echo "Problem scenarios created. Use these files to practice troubleshooting:"
echo "1. Resource limits: kubectl apply -f scenario-1-resource-limits.yaml"
echo "2. ConfigMap issues: kubectl apply -f scenario-2-missing-configmap.yaml"  
echo "3. Image pull problems: kubectl apply -f scenario-3-image-pull.yaml"
echo "4. Service misconfigurations: kubectl apply -f scenario-4-service-mismatch.yaml"
EOF

chmod +x create-problem-scenarios.sh
```

## Performance Optimization Strategies

Large-scale Helm deployments require optimization techniques to maintain performance and reliability.

### Helm Performance Analysis Tools

```bash
# Create performance analysis toolkit
cat << 'EOF' > helm-performance-analyzer.sh
#!/bin/bash

CHART_PATH=${1:-"."}
RELEASE_NAME=${2:-"perf-test"}
NAMESPACE=${3:-"default"}

echo "🚀 Helm Performance Analysis"
echo "Chart: $CHART_PATH"
echo "Release: $RELEASE_NAME"
echo "Namespace: $NAMESPACE"
echo "=================================="

# Template rendering performance
echo "📊 Template Rendering Performance:"
time_output=$(time (helm template $RELEASE_NAME $CHART_PATH >/dev/null) 2>&1)
echo "Template rendering time: $time_output"

# Chart size analysis
echo "📏 Chart Size Analysis:"
if [ -f "$CHART_PATH/Chart.yaml" ]; then
    chart_size=$(du -sh $CHART_PATH | cut -f1)
    echo "Chart directory size: $chart_size"
    
    template_count=$(find $CHART_PATH/templates -name "*.yaml" -o -name "*.yml" | wc -l)
    echo "Template files: $template_count"
    
    values_size=$(wc -c < $CHART_PATH/values.yaml 2>/dev/null || echo "0")
    echo "values.yaml size: ${values_size} bytes"
fi

# Resource analysis
echo "🔍 Generated Resource Analysis:"
rendered_output=$(helm template $RELEASE_NAME $CHART_PATH 2>/dev/null)
if [ $? -eq 0 ]; then
    resource_count=$(echo "$rendered_output" | grep -c "^kind:" || true)
    echo "Total Kubernetes resources: $resource_count"
    
    echo "Resource breakdown:"
    echo "$rendered_output" | grep "^kind:" | sort | uniq -c | sort -nr
    
    # Check for large ConfigMaps/Secrets
    large_configs=$(echo "$rendered_output" | awk '/^kind: (ConfigMap|Secret)/{kind=$2} /^data:/{in_data=1} in_data && /^[^ ]/{if(in_data && kind) print kind; in_data=0; kind=""}' | wc -l)
    echo "ConfigMaps/Secrets with data: $large_configs"
fi

# Memory usage estimation
echo "💾 Memory Usage Estimation:"
if [ -n "$rendered_output" ]; then
    output_size=$(echo "$rendered_output" | wc -c)
    echo "Rendered output size: $output_size bytes"
    estimated_memory=$((output_size / 1024))
    echo "Estimated memory usage: ~${estimated_memory}KB"
fi

# Dependency analysis
echo "🔗 Dependency Analysis:"
if [ -f "$CHART_PATH/Chart.yaml" ]; then
    dep_count=$(grep -c "^  - name:" $CHART_PATH/Chart.yaml 2>/dev/null || echo "0")
    echo "Chart dependencies: $dep_count"
    
    if [ -d "$CHART_PATH/charts" ]; then
        subchart_size=$(du -sh $CHART_PATH/charts 2>/dev/null | cut -f1 || echo "0")
        echo "Subcharts total size: $subchart_size"
    fi
fi

# Recommendations
echo ""
echo "🎯 Performance Recommendations:"
if [ $template_count -gt 20 ]; then
    echo "⚠️  Consider splitting large charts into multiple smaller charts"
fi

if [ $resource_count -gt 50 ]; then
    echo "⚠️  Large number of resources - consider using subchart organization"
fi

if [ $values_size -gt 10000 ]; then
    echo "⚠️  Large values.yaml file - consider environment-specific value files"
fi

if [ $dep_count -gt 5 ]; then
    echo "⚠️  Many dependencies - verify all are necessary and up-to-date"
fi
EOF

chmod +x helm-performance-analyzer.sh
```

### Optimizing Chart Templates

```bash
# Create an optimized chart example
helm create optimized-app
cd optimized-app

# Create performance-optimized helpers
cat << 'EOF' > templates/_performance-helpers.tpl
{{/*
Cached selector labels to avoid recalculation
*/}}
{{- define "optimized-app.selectorLabels" -}}
{{- if not (hasKey . "_selectorLabels") -}}
{{- $labels := dict "app.kubernetes.io/name" (include "optimized-app.name" .) "app.kubernetes.io/instance" .Release.Name -}}
{{- $_ := set . "_selectorLabels" $labels -}}
{{- end -}}
{{- toYaml ._selectorLabels -}}
{{- end }}

{{/*
Optimized resource definition with defaults
*/}}
{{- define "optimized-app.resources" -}}
{{- $resources := .Values.resources | default dict -}}
{{- $limits := $resources.limits | default dict -}}
{{- $requests := $resources.requests | default dict -}}
limits:
  cpu: {{ $limits.cpu | default "500m" }}
  memory: {{ $limits.memory | default "512Mi" }}
requests:
  cpu: {{ $requests.cpu | default "100m" }}
  memory: {{ $requests.memory | default "128Mi" }}
{{- end }}

{{/*
Conditional template inclusion helper
*/}}
{{- define "optimized-app.includeTemplate" -}}
{{- $templateName := index . 0 -}}
{{- $context := index . 1 -}}
{{- $condition := index . 2 -}}
{{- if $condition -}}
{{- include $templateName $context -}}
{{- end -}}
{{- end }}

{{/*
Environment-specific configuration merger
*/}}
{{- define "optimized-app.envConfig" -}}
{{- $global := .Values.global | default dict -}}
{{- $env := index .Values.environments .Values.environment | default dict -}}
{{- $merged := merge $env $global -}}
{{- toYaml $merged -}}
{{- end }}
EOF

# Create conditional resource templates
mkdir templates/optional

cat << 'EOF' > templates/optional/ingress.yaml
{{- if .Values.ingress.enabled -}}
{{- $fullName := include "optimized-app.fullname" . -}}
{{- $svcPort := .Values.service.port -}}
{{- if and .Values.ingress.className (not (hasKey .Values.ingress.annotations "kubernetes.io/ingress.class")) }}
  {{- $_ := set .Values.ingress.annotations "kubernetes.io/ingress.class" .Values.ingress.className}}
{{- end }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ $fullName }}
  labels:
    {{- include "optimized-app.labels" . | nindent 4 }}
  {{- with .Values.ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- if and .Values.ingress.className (semverCompare ">=1.18-0" .Capabilities.KubeVersion.GitVersion) }}
  ingressClassName: {{ .Values.ingress.className }}
  {{- end }}
  {{- if .Values.ingress.tls }}
  tls:
    {{- range .Values.ingress.tls }}
    - hosts:
        {{- range .hosts }}
        - {{ . | quote }}
        {{- end }}
      secretName: {{ .secretName }}
    {{- end }}
  {{- end }}
  rules:
    {{- range .Values.ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path }}
            pathType: {{ .pathType }}
            backend:
              service:
                name: {{ $fullName }}
                port:
                  number: {{ $svcPort }}
          {{- end }}
    {{- end }}
{{- end }}
EOF

  {{ $filename }}: |
    {{- $content | nindent 4 }}
  {{- end }}
  {{- end }}
{{- end }}
EOF

# Create optimized values.yaml structure
cat << 'EOF' > values.yaml
# Performance-optimized configuration structure
global:
  imageRegistry: ""
  imagePullSecrets: []

# Environment selection
environment: development

# Environment-specific configurations
environments:
  development:
    replicaCount: 1
    resources:
      requests:
        cpu: 50m
        memory: 64Mi
      limits:
        cpu: 200m
        memory: 256Mi
  staging:
    replicaCount: 2
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 500m
        memory: 512Mi
  production:
    replicaCount: 3
    resources:
      requests:
        cpu: 200m
        memory: 256Mi
      limits:
        cpu: 1000m
        memory: 1Gi

# Application configuration
app:
  name: optimized-app
  version: "1.0.0"

image:
  repository: nginx
  tag: "1.21-alpine"
  pullPolicy: IfNotPresent

# Conditional features
features:
  ingress: false
  monitoring: false
  autoscaling: false
  networkPolicy: false

# Service configuration
service:
  type: ClusterIP
  port: 80
  targetPort: 8080

# Configuration management
config:
  enabled: false
  data: {}
  files: {}

# Resource defaults (applied via helper templates)
resources: {}
EOF
```

## Multi-Cluster Helm Management

### Mini-Project 5B: Multi-Cluster Deployment Strategy

```bash
# Create multi-cluster management toolkit
mkdir multi-cluster-helm
cd multi-cluster-helm

# Cluster configuration management
cat << 'EOF' > cluster-config.yaml
clusters:
  development:
    context: dev-cluster
    namespace: app-dev
    values: environments/dev-values.yaml
    registry: dev-registry.company.com
    
  staging:
    context: staging-cluster  
    namespace: app-staging
    values: environments/staging-values.yaml
    registry: staging-registry.company.com
    
  production-us:
    context: prod-us-cluster
    namespace: app-prod
    values: environments/prod-us-values.yaml
    registry: prod-registry.company.com
    
  production-eu:
    context: prod-eu-cluster
    namespace: app-prod
    values: environments/prod-eu-values.yaml
    registry: prod-registry.company.com

# Global settings
global:
  chart: ../optimized-app
  timeout: 600s
  wait: true
  atomic: true
EOF

# Multi-cluster deployment script
cat << 'EOF' > deploy-multi-cluster.sh
#!/bin/bash
set -e

CLUSTER_CONFIG="cluster-config.yaml"
CHART_PATH=""
OPERATION=${1:-"install"}
TARGET_CLUSTERS=${2:-"all"}

# Parse YAML config (requires yq)
if ! command -v yq &> /dev/null; then
    echo "Error: yq is required for parsing YAML configuration"
    echo "Install with: pip install yq"
    exit 1
fi

# Get global chart path
CHART_PATH=$(yq eval '.global.chart' $CLUSTER_CONFIG)
TIMEOUT=$(yq eval '.global.timeout' $CLUSTER_CONFIG)

echo "Multi-Cluster Helm Deployment"
echo "Operation: $OPERATION"
echo "Chart: $CHART_PATH"
echo "Target: $TARGET_CLUSTERS"
echo "=================================="

# Function to deploy to a specific cluster
deploy_to_cluster() {
    local cluster_name=$1
    local context=$(yq eval ".clusters.${cluster_name}.context" $CLUSTER_CONFIG)
    local namespace=$(yq eval ".clusters.${cluster_name}.namespace" $CLUSTER_CONFIG)
    local values_file=$(yq eval ".clusters.${cluster_name}.values" $CLUSTER_CONFIG)
    local registry=$(yq eval ".clusters.${cluster_name}.registry" $CLUSTER_CONFIG)
    
    echo "Deploying to cluster: $cluster_name"
    echo "  Context: $context"
    echo "  Namespace: $namespace"
    echo "  Values: $values_file"
    
    # Switch kubectl context
    kubectl config use-context $context
    
    # Create namespace if it doesn't exist
    kubectl create namespace $namespace --dry-run=client -o yaml | kubectl apply -f -
    
    case $OPERATION in
        "install")
            helm install $cluster_name $CHART_PATH \
                --namespace $namespace \
                --values $values_file \
                --set global.registry=$registry \
                --timeout $TIMEOUT \
                --wait
            ;;
        "upgrade")
            helm upgrade $cluster_name $CHART_PATH \
                --namespace $namespace \
                --values $values_file \
                --set global.registry=$registry \
                --timeout $TIMEOUT \
                --wait
            ;;
        "uninstall")
            helm uninstall $cluster_name --namespace $namespace
            ;;
        "status")
            helm status $cluster_name --namespace $namespace
            ;;
        *)
            echo "Unknown operation: $OPERATION"
            exit 1
            ;;
    esac
    
    echo "Completed deployment to $cluster_name"
    echo ""
}

# Get list of clusters to deploy to
if [ "$TARGET_CLUSTERS" = "all" ]; then
    clusters=$(yq eval '.clusters | keys | .[]' $CLUSTER_CONFIG)
else
    clusters=$(echo $TARGET_CLUSTERS | tr ',' '\n')
fi

# Deploy to each cluster
for cluster in $clusters; do
    # Check if cluster exists in config
    if yq eval ".clusters | has(\"$cluster\")" $CLUSTER_CONFIG | grep -q "true"; then
        deploy_to_cluster $cluster
    else
        echo "Warning: Cluster '$cluster' not found in configuration"
    fi
done

echo "Multi-cluster deployment completed"
EOF

chmod +x deploy-multi-cluster.sh

# Create environment-specific values
mkdir environments

cat << 'EOF' > environments/dev-values.yaml
environment: development
replicaCount: 1

image:
  tag: "dev-latest"
  pullPolicy: Always

resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 200m
    memory: 256Mi

config:
  enabled: true
  data:
    LOG_LEVEL: debug
    ENVIRONMENT: development

features:
  monitoring: false
  autoscaling: false
EOF

cat << 'EOF' > environments/prod-us-values.yaml
environment: production-us
replicaCount: 5

image:
  tag: "1.2.3"
  pullPolicy: IfNotPresent

resources:
  requests:
    cpu: 500m
    memory: 512Mi
  limits:
    cpu: 2000m
    memory: 2Gi

config:
  enabled: true
  data:
    LOG_LEVEL: warn
    ENVIRONMENT: production
    REGION: us-east-1
    
features:
  monitoring: true
  autoscaling: true
  networkPolicy: true

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 20
  targetCPUUtilizationPercentage: 70

ingress:
  enabled: true
  hosts:
    - host: app-us.company.com
      paths:
        - path: /
          pathType: Prefix
EOF

cat << 'EOF' > environments/prod-eu-values.yaml
environment: production-eu
replicaCount: 3

image:
  tag: "1.2.3"
  pullPolicy: IfNotPresent

resources:
  requests:
    cpu: 500m
    memory: 512Mi
  limits:
    cpu: 2000m
    memory: 2Gi

config:
  enabled: true
  data:
    LOG_LEVEL: warn
    ENVIRONMENT: production
    REGION: eu-west-1
    
features:
  monitoring: true
  autoscaling: true
  networkPolicy: true

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 15
  targetCPUUtilizationPercentage: 70

ingress:
  enabled: true
  hosts:
    - host: app-eu.company.com
      paths:
        - path: /
          pathType: Prefix
EOF
```

## Service Mesh Integration

### Integrating Helm with Istio Service Mesh

```bash
# Create service mesh integration examples
mkdir service-mesh-integration
cd service-mesh-integration

# Istio-enabled Helm chart
cat << 'EOF' > templates/virtualservice.yaml
{{- if and .Values.istio.enabled .Values.istio.virtualService.enabled }}
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: {{ include "optimized-app.fullname" . }}
  labels:
    {{- include "optimized-app.labels" . | nindent 4 }}
spec:
  hosts:
    {{- range .Values.istio.virtualService.hosts }}
    - {{ . | quote }}
    {{- end }}
  {{- if .Values.istio.virtualService.gateways }}
  gateways:
    {{- toYaml .Values.istio.virtualService.gateways | nindent 4 }}
  {{- end }}
  http:
    {{- range .Values.istio.virtualService.routes }}
    - match:
        {{- toYaml .match | nindent 8 }}
      route:
        {{- toYaml .route | nindent 8 }}
      {{- if .fault }}
      fault:
        {{- toYaml .fault | nindent 8 }}
      {{- end }}
      {{- if .timeout }}
      timeout: {{ .timeout }}
      {{- end }}
      {{- if .retries }}
      retries:
        {{- toYaml .retries | nindent 8 }}
      {{- end }}
    {{- end }}
{{- end }}
EOF

cat << 'EOF' > templates/destinationrule.yaml
{{- if and .Values.istio.enabled .Values.istio.destinationRule.enabled }}
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: {{ include "optimized-app.fullname" . }}
  labels:
    {{- include "optimized-app.labels" . | nindent 4 }}
spec:
  host: {{ include "optimized-app.fullname" . }}
  {{- if .Values.istio.destinationRule.trafficPolicy }}
  trafficPolicy:
    {{- toYaml .Values.istio.destinationRule.trafficPolicy | nindent 4 }}
  {{- end }}
  {{- if .Values.istio.destinationRule.subsets }}
  subsets:
    {{- range .Values.istio.destinationRule.subsets }}
    - name: {{ .name }}
      labels:
        {{- toYaml .labels | nindent 8 }}
      {{- if .trafficPolicy }}
      trafficPolicy:
        {{- toYaml .trafficPolicy | nindent 8 }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}
EOF

cat << 'EOF' > templates/peerauthentication.yaml
{{- if and .Values.istio.enabled .Values.istio.security.peerAuthentication.enabled }}
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: {{ include "optimized-app.fullname" . }}
  labels:
    {{- include "optimized-app.labels" . | nindent 4 }}
spec:
  selector:
    matchLabels:
      {{- include "optimized-app.selectorLabels" . | nindent 6 }}
  mtls:
    mode: {{ .Values.istio.security.peerAuthentication.mtlsMode }}
{{- end }}
EOF

# Service mesh values
cat << 'EOF' > istio-values.yaml
# Istio service mesh configuration
istio:
  enabled: true
  
  # Sidecar injection
  sidecar:
    inject: true
    
  # Virtual Service configuration
  virtualService:
    enabled: true
    hosts:
      - app.company.com
    gateways:
      - istio-system/company-gateway
    routes:
      - match:
          - uri:
              prefix: /
        route:
          - destination:
              host: optimized-app
              port:
                number: 80
        timeout: 30s
        retries:
          attempts: 3
          perTryTimeout: 10s
        fault:
          delay:
            percentage:
              value: 0.1
            fixedDelay: 5s
  
  # Destination Rule for traffic management
  destinationRule:
    enabled: true
    trafficPolicy:
      connectionPool:
        tcp:
          maxConnections: 100
        http:
          http1MaxPendingRequests: 50
          maxRequestsPerConnection: 2
      loadBalancer:
        simple: LEAST_CONN
    subsets:
      - name: v1
        labels:
          version: v1
        trafficPolicy:
          connectionPool:
            tcp:
              maxConnections: 50
      - name: v2
        labels:
          version: v2
        trafficPolicy:
          connectionPool:
            tcp:
              maxConnections: 100
  
  # Security policies
  security:
    peerAuthentication:
      enabled: true
      mtlsMode: STRICT
EOF
```

## Disaster Recovery and Business Continuity

### Mini-Project 5C: Comprehensive Backup and Recovery System

```bash
# Create disaster recovery toolkit
mkdir disaster-recovery
cd disaster-recovery

# Comprehensive backup script
cat << 'EOF' > helm-backup-system.sh
#!/bin/bash
set -e

BACKUP_DIR=${1:-"/backup/helm"}
CLUSTER_NAME=${2:-$(kubectl config current-context)}
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_PATH="$BACKUP_DIR/$CLUSTER_NAME/$TIMESTAMP"

echo "Helm Disaster Recovery Backup"
echo "Cluster: $CLUSTER_NAME"
echo "Backup Path: $BACKUP_PATH"
echo "==============================="

# Create backup directory
mkdir -p "$BACKUP_PATH"

# Backup all Helm releases
echo "Backing up Helm releases..."
helm list --all-namespaces -o json > "$BACKUP_PATH/helm-releases.json"

# Get all namespaces with Helm releases
NAMESPACES=$(helm list --all-namespaces --output json | jq -r '.[].namespace' | sort -u)

# Backup each release individually
mkdir -p "$BACKUP_PATH/releases"
for namespace in $NAMESPACES; do
    echo "Processing namespace: $namespace"
    mkdir -p "$BACKUP_PATH/releases/$namespace"
    
    # Get releases in this namespace
    RELEASES=$(helm list --namespace $namespace --output json | jq -r '.[].name')
    
    for release in $RELEASES; do
        echo "  Backing up release: $release"
        release_dir="$BACKUP_PATH/releases/$namespace/$release"
        mkdir -p "$release_dir"
        
        # Backup release information
        helm status "$release" --namespace "$namespace" > "$release_dir/status.txt"
        helm get values "$release" --namespace "$namespace" > "$release_dir/values.yaml"
        helm get manifest "$release" --namespace "$namespace" > "$release_dir/manifest.yaml"
        helm history "$release" --namespace "$namespace" > "$release_dir/history.txt"
        
        # Backup chart if possible
        if helm get notes "$release" --namespace "$namespace" &>/dev/null; then
            helm get notes "$release" --namespace "$namespace" > "$release_dir/notes.txt"
        fi
    done
done

# Backup Kubernetes resources
echo "Backing up Kubernetes resources..."
mkdir -p "$BACKUP_PATH/k8s-resources"

# Backup critical cluster resources
kubectl get namespaces -o yaml > "$BACKUP_PATH/k8s-resources/namespaces.yaml"
kubectl get persistentvolumes -o yaml > "$BACKUP_PATH/k8s-resources/persistent-volumes.yaml"
kubectl get storageclasses -o yaml > "$BACKUP_PATH/k8s-resources/storage-classes.yaml"

# Backup secrets and configmaps from Helm namespaces
for namespace in $NAMESPACES; do
    echo "Backing up secrets and configmaps from namespace: $namespace"
    ns_dir="$BACKUP_PATH/k8s-resources/$namespace"
    mkdir -p "$ns_dir"
    
    kubectl get secrets -n "$namespace" -o yaml > "$ns_dir/secrets.yaml" 2>/dev/null || true
    kubectl get configmaps -n "$namespace" -o yaml > "$ns_dir/configmaps.yaml" 2>/dev/null || true
    kubectl get persistentvolumeclaims -n "$namespace" -o yaml > "$ns_dir/pvcs.yaml" 2>/dev/null || true
done

# Create backup metadata
cat << METADATA > "$BACKUP_PATH/backup-metadata.json"
{
  "timestamp": "$TIMESTAMP",
  "cluster": "$CLUSTER_NAME",
  "kubernetes_version": "$(kubectl version --short --client -o json | jq -r '.clientVersion.gitVersion')",
  "helm_version": "$(helm version --short)",
  "backup_type": "full",
  "namespaces": $(echo "$NAMESPACES" | jq -R -s 'split("\n")[:-1]')
}
METADATA

# Create restore script
cat << 'RESTORE_SCRIPT' > "$BACKUP_PATH/restore.sh"
#!/bin/bash
set -e

BACKUP_PATH="$(dirname "$0")"
DRY_RUN=${1:-"false"}

echo "Helm Disaster Recovery Restore"
echo "Backup Path: $BACKUP_PATH"
echo "Dry Run: $DRY_RUN"
echo "==============================="

# Read backup metadata
if [ ! -f "$BACKUP_PATH/backup-metadata.json" ]; then
    echo "Error: backup-metadata.json not found"
    exit 1
fi

BACKUP_CLUSTER=$(jq -r '.cluster' "$BACKUP_PATH/backup-metadata.json")
BACKUP_TIMESTAMP=$(jq -r '.timestamp' "$BACKUP_PATH/backup-metadata.json")

echo "Restoring backup from cluster: $BACKUP_CLUSTER"
echo "Backup timestamp: $BACKUP_TIMESTAMP"

# Restore namespaces first
echo "Restoring namespaces..."
if [ "$DRY_RUN" = "true" ]; then
    echo "DRY RUN: Would restore namespaces"
else
    kubectl apply -f "$BACKUP_PATH/k8s-resources/namespaces.yaml"
fi

# Restore secrets and configmaps
echo "Restoring secrets and configmaps..."
for ns_dir in "$BACKUP_PATH/k8s-resources/"*/; do
    if [ -d "$ns_dir" ]; then
        namespace=$(basename "$ns_dir")
        echo "  Restoring resources for namespace: $namespace"
        
        if [ "$DRY_RUN" = "true" ]; then
            echo "  DRY RUN: Would restore secrets and configmaps for $namespace"
        else
            kubectl apply -f "$ns_dir/secrets.yaml" --namespace "$namespace" 2>/dev/null || true
            kubectl apply -f "$ns_dir/configmaps.yaml" --namespace "$namespace" 2>/dev/null || true
            kubectl apply -f "$ns_dir/pvcs.yaml" --namespace "$namespace" 2>/dev/null || true
        fi
    fi
done

# Note about Helm releases
echo ""
echo "Manual Helm Release Restoration Required:"
echo "==========================================="
echo "Due to the complexity of Helm release state, manual restoration is recommended:"
echo ""

# Generate restore commands for each release
for release_dir in "$BACKUP_PATH/releases/"*/*; do
    if [ -d "$release_dir" ]; then
        namespace=$(basename "$(dirname "$release_dir")")
        release=$(basename "$release_dir")
        
        echo "# Restore $release in namespace $namespace:"
        echo "helm install $release <chart-path> \\"
        echo "  --namespace $namespace \\"
        echo "  --values $release_dir/values.yaml"
        echo ""
    fi
done

echo "Restore process completed (manual steps required for Helm releases)"
RESTORE_SCRIPT

chmod +x "$BACKUP_PATH/restore.sh"

# Compress backup
echo "Compressing backup..."
cd "$(dirname "$BACKUP_PATH")"
tar -czf "$CLUSTER_NAME-$TIMESTAMP.tar.gz" "$TIMESTAMP"
echo "Backup compressed: $CLUSTER_NAME-$TIMESTAMP.tar.gz"

# Cleanup retention (keep last 10 backups)
echo "Cleaning up old backups..."
ls -t *.tar.gz 2>/dev/null | tail -n +11 | xargs rm -f || true

echo "Backup completed successfully!"
echo "Backup location: $BACKUP_PATH"
echo "Compressed backup: $CLUSTER_NAME-$TIMESTAMP.tar.gz"
EOF

chmod +x helm-backup-system.sh

# Create automated disaster recovery testing
cat << 'EOF' > test-disaster-recovery.sh
#!/bin/bash
set -e

TEST_NAMESPACE="dr-test"
TEST_RELEASE="dr-test-app"
BACKUP_PATH="/tmp/helm-dr-test"

echo "Disaster Recovery Testing"
echo "========================="

# Step 1: Deploy a test application
echo "Step 1: Deploying test application..."
kubectl create namespace $TEST_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

helm install $TEST_RELEASE ../optimized-app \
    --namespace $TEST_NAMESPACE \
    --set replicaCount=2 \
    --wait

echo "Test application deployed successfully"

# Step 2: Create backup
echo "Step 2: Creating backup..."
./helm-backup-system.sh $BACKUP_PATH

# Step 3: Simulate disaster (delete release)
echo "Step 3: Simulating disaster..."
helm uninstall $TEST_RELEASE --namespace $TEST_NAMESPACE
kubectl delete namespace $TEST_NAMESPACE

echo "Disaster simulated - application deleted"
sleep 5

# Step 4: Restore from backup
echo "Step 4: Testing restore..."
LATEST_BACKUP=$(find $BACKUP_PATH -name "*.tar.gz" | sort | tail -1)
if [ -n "$LATEST_BACKUP" ]; then
    RESTORE_DIR="/tmp/restore-test"
    mkdir -p $RESTORE_DIR
    cd $RESTORE_DIR
    tar -xzf "$LATEST_BACKUP"
    
    # Find the restore script
    RESTORE_SCRIPT=$(find . -name "restore.sh" | head -1)
    if [ -n "$RESTORE_SCRIPT" ]; then
        echo "Found restore script: $RESTORE_SCRIPT"
        bash "$RESTORE_SCRIPT" true  # Dry run first
    fi
fi

# Step 5: Manual verification steps
echo ""
echo "Step 5: Manual Verification Required"
echo "===================================="
echo "1. Review the restore script output above"
echo "2. Execute the suggested Helm commands to restore releases"
echo "3. Verify application functionality"
echo "4. Clean up test resources:"
echo "   kubectl delete namespace $TEST_NAMESPACE"
echo "   rm -rf $BACKUP_PATH $RESTORE_DIR"

echo ""
echo "Disaster recovery test completed!"
EOF

chmod +x test-disaster-recovery.sh
```

## Unit 5 Final Assessment: Production-Ready Helm Operations

Design and implement a complete production operations framework for Helm that demonstrates mastery of all advanced concepts:

**Comprehensive Operations Platform Requirements:**

1. **Multi-Cluster Management:**
   - Deploy applications across development, staging, and multiple production clusters
   - Implement cluster-specific configuration management
   - Create automated failover procedures

2. **Performance Optimization:**
   - Optimize chart templates for large-scale deployments
   - Implement caching strategies for template rendering
   - Create performance monitoring and alerting

3. **Advanced Troubleshooting:**
   - Automated issue detection and diagnosis
   - Integration with logging and monitoring systems
   - Escalation procedures for critical failures

4. **Service Mesh Integration:**
   - Complete Istio service mesh integration
   - Traffic management and canary deployments
   - Security policy enforcement

5. **Disaster Recovery:**
   - Automated backup systems with retention policies
   - Cross-cluster replication strategies
   - Recovery time objective (RTO) and recovery point objective (RPO) compliance

**Deliverable Framework:**
```bash
production-helm-ops/
├── clusters/                     # Multi-cluster configurations
├── charts/                       # Production-ready charts
├── monitoring/                   # Performance and health monitoring
├── troubleshooting/              # Diagnostic and repair tools
├── disaster-recovery/            # Backup and recovery systems
├── security/                     # Security policies and compliance
├── automation/                   # CI/CD and operational automation
├── service-mesh/                 # Service mesh integration
└── documentation/                # Operational runbooks
```

This assessment should demonstrate your ability to operate Helm in production environments with enterprise-grade reliability, performance, and operational excellence.

## Summary

This comprehensive Helm learning path has taken you from basic package management through enterprise-grade production operations. You've mastered:

- **Fundamentals**: Installation, repositories, and basic operations
- **Configuration Management**: Values, templates, and environment strategies
- **Chart Development**: Custom charts, templates, and packaging
- **Enterprise Patterns**: Dependencies, hooks, libraries, and CI/CD integration
- **Production Operations**: Troubleshooting, performance optimization, multi-cluster management, and disaster recovery

The progression from simple chart installations to sophisticated multi-cluster production operations provides a complete foundation for managing Kubernetes applications at any scale. Each unit builds upon previous knowledge while introducing increasingly complex real-world scenarios.

Remember that mastering Helm is an ongoing process. The Kubernetes ecosystem continues to evolve, and staying current with best practices, security updates, and new features will ensure your Helm implementations remain robust and efficient in production environments.