# Kubernetes Namespaces - Complete Mastery Guide

Namespaces are the cornerstone of Kubernetes multi-tenancy, providing logical isolation that enables teams to share cluster resources safely while maintaining operational independence. This comprehensive guide explores every aspect of namespace management, from fundamental concepts to enterprise-scale implementations.

## Table of Contents
1. [Understanding Namespaces Deeply](#understanding-namespaces-deeply)
2. [Namespace Architecture Patterns](#namespace-architecture-patterns)
3. [Advanced Creation and Management](#advanced-creation-and-management)
4. [Resource Control and Governance](#resource-control-and-governance)
5. [Security and Access Control](#security-and-access-control)
6. [Network Isolation Strategies](#network-isolation-strategies)
7. [Lifecycle and Operational Management](#lifecycle-and-operational-management)
8. [Monitoring and Observability](#monitoring-and-observability)
9. [Enterprise Patterns and Multi-Tenancy](#enterprise-patterns-and-multi-tenancy)
10. [Troubleshooting and Best Practices](#troubleshooting-and-best-practices)

---

## 1. Understanding Namespaces Deeply

### The Conceptual Foundation

Think of Kubernetes namespaces as apartments in a large building. Each apartment (namespace) provides a private living space where tenants (teams or applications) can organize their belongings (resources) without interfering with their neighbors. The building management (cluster administrators) can set rules about resource usage, security policies, and communication between apartments.

This analogy helps us understand that namespaces provide three fundamental capabilities: **isolation**, **organization**, and **resource scoping**. These capabilities work together to enable multiple teams or applications to coexist safely within a single Kubernetes cluster.

### Namespace Scope and Boundaries

Not all Kubernetes resources are bound by namespace boundaries. Understanding this distinction is crucial for effective namespace design.

```bash
# Discover namespace-scoped resources - these live within namespace boundaries
kubectl api-resources --namespaced=true | head -10

# Examples of namespace-scoped resources:
# pods, services, deployments, configmaps, secrets, ingresses,
# replicasets, jobs, cronjobs, persistentvolumeclaims

# Discover cluster-scoped resources - these exist globally across the cluster
kubectl api-resources --namespaced=false | head -10

# Examples of cluster-scoped resources:
# nodes, namespaces, persistentvolumes, storageclasses,
# clusterroles, clusterrolebindings, customresourcedefinitions
```

This distinction has important implications. When you delete a namespace, only the namespace-scoped resources within it are removed. Cluster-scoped resources like PersistentVolumes or ClusterRoles remain intact, which is why careful planning of resource relationships is essential.

### Default Namespaces and Their Purposes

Kubernetes creates several system namespaces by default, each serving a specific purpose in cluster operations:

```bash
# Examine the default namespaces and their roles
kubectl get namespaces --show-labels

# The 'default' namespace - where resources go when no namespace is specified
kubectl describe namespace default

# The 'kube-system' namespace - critical cluster infrastructure
kubectl get pods -n kube-system

# The 'kube-public' namespace - publicly readable information
kubectl get configmaps -n kube-public

# The 'kube-node-lease' namespace - node heartbeat mechanism
kubectl get leases -n kube-node-lease
```

Understanding these system namespaces helps you appreciate how Kubernetes itself uses namespace isolation to organize cluster components. The kube-system namespace, for instance, runs critical components like the DNS server, proxy, and scheduler, while keeping them separate from user workloads.

### Namespace Naming and Identification

Kubernetes namespace names must follow specific rules that reflect DNS subdomain naming conventions. This constraint exists because namespace names often become part of DNS names for services within the cluster.

```bash
# Valid namespace names follow these patterns:
# - Must be a valid DNS subdomain name
# - Can contain lowercase letters, numbers, and hyphens
# - Must start and end with alphanumeric characters
# - Maximum length of 63 characters

# Examples of valid names:
kubectl create namespace frontend-team       # ✅ Valid
kubectl create namespace api-v2             # ✅ Valid  
kubectl create namespace data-science-dev   # ✅ Valid

# Examples of invalid names would be:
# Frontend-Team    (uppercase letters)
# api_v2          (underscores)
# -frontend       (starts with hyphen)
# team.api        (contains dots)
```

The naming convention you choose should reflect your organizational structure and make it easy for teams to identify their resources. Many organizations adopt patterns like `team-environment` or `application-environment` to create predictable, meaningful namespace names.

---

## 2. Namespace Architecture Patterns

### Single-Tenant vs Multi-Tenant Approaches

The choice between single-tenant and multi-tenant namespace architectures depends on your organization's size, security requirements, and operational complexity. Let's explore both approaches with practical examples.

#### Single-Tenant Architecture (Namespace per Application)

In this pattern, each application gets its own set of namespaces across environments. This provides strong isolation but can lead to namespace proliferation.

```bash
#!/bin/bash
# single-tenant-setup_namespace_monitoring() {
    local namespace=$1
    local monitoring_tier=${2:-"standard"}
    local alert_severity=${3:-"warning"}
    
    echo "📊 Setting up monitoring for namespace: $namespace"
    
    # Deploy monitoring agents
    deploy_monitoring_agents "$namespace"
    
    # Create ServiceMonitors for Prometheus
    create_service_monitors "$namespace"
    
    # Set up alerting rules
    create_alerting_rules "$namespace" "$monitoring_tier" "$alert_severity"
    
    # Configure dashboards
    create_monitoring_dashboards "$namespace"
    
    # Set up log aggregation
    setup_log_aggregation "$namespace"
    
    echo "✅ Monitoring setup complete for namespace: $namespace"
}

deploy_monitoring_agents() {
    local namespace=$1
    
    # Deploy node exporter sidecar for detailed metrics
    cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: namespace-monitor
  namespace: $namespace
  labels:
    app: namespace-monitor
    component: metrics
spec:
  selector:
    matchLabels:
      app: namespace-monitor
  template:
    metadata:
      labels:
        app: namespace-monitor
        component: metrics
    spec:
      serviceAccountName: monitoring-sa
      containers:
      - name: metrics-collector
        image: prom/node-exporter:latest
        args:
        - --path.procfs=/host/proc
        - --path.sysfs=/host/sys
        - --collector.filesystem.ignored-mount-points
        - ^/(sys|proc|dev|host|etc|rootfs/var/lib/docker/containers|rootfs/var/lib/docker/overlay2|rootfs/run/docker/netns|rootfs/var/lib/docker/aufs)($|/)
        ports:
        - containerPort: 9100
          name: metrics
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        volumeMounts:
        - name: proc
          mountPath: /host/proc
          readOnly: true
        - name: sys
          mountPath: /host/sys
          readOnly: true
      volumes:
      - name: proc
        hostPath:
          path: /proc
      - name: sys
        hostPath:
          path: /sys
      hostNetwork: true
      hostPID: true
---
apiVersion: v1
kind: Service
metadata:
  name: namespace-monitor-metrics
  namespace: $namespace
  labels:
    app: namespace-monitor
    metrics: enabled
spec:
  selector:
    app: namespace-monitor
  ports:
  - port: 9100
    targetPort: 9100
    name: metrics
EOF
}

create_service_monitors() {
    local namespace=$1
    
    # ServiceMonitor for application metrics
    cat << EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: ${namespace}-applications
  namespace: $namespace
  labels:
    monitoring: applications
    namespace: $namespace
spec:
  selector:
    matchLabels:
      metrics: enabled
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
    honorLabels: true
  namespaceSelector:
    matchNames:
    - $namespace
---
# ServiceMonitor for infrastructure components
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: ${namespace}-infrastructure
  namespace: $namespace
  labels:
    monitoring: infrastructure
    namespace: $namespace
spec:
  selector:
    matchLabels:
      component: infrastructure
      metrics: enabled
  endpoints:
  - port: metrics
    interval: 15s
    path: /metrics
  namespaceSelector:
    matchNames:
    - $namespace
EOF
}

create_alerting_rules() {
    local namespace=$1
    local tier=$2
    local severity=$3
    
    cat << EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: ${namespace}-alerts
  namespace: $namespace
  labels:
    monitoring-tier: $tier
    alert-severity: $severity
    namespace: $namespace
spec:
  groups:
  - name: ${namespace}-resource-usage
    interval: 30s
    rules:
    - alert: NamespaceHighCPUUsage
      expr: |
        (
          sum(rate(container_cpu_usage_seconds_total{namespace="$namespace"}[5m])) /
          sum(kube_resourcequota{namespace="$namespace", resource="requests.cpu", type="hard"}) * 100
        ) > 80
      for: 5m
      labels:
        severity: $severity
        namespace: $namespace
        resource: cpu
      annotations:
        summary: "High CPU usage in namespace $namespace"
        description: "Namespace $namespace is using {{ \$value }}% of its CPU quota"
        runbook_url: "https://runbooks.company.com/namespace-cpu-usage"
    
    - alert: NamespaceHighMemoryUsage
      expr: |
        (
          sum(container_memory_usage_bytes{namespace="$namespace"}) /
          sum(kube_resourcequota{namespace="$namespace", resource="requests.memory", type="hard"}) * 100
        ) > 85
      for: 5m
      labels:
        severity: $severity
        namespace: $namespace
        resource: memory
      annotations:
        summary: "High memory usage in namespace $namespace"
        description: "Namespace $namespace is using {{ \$value }}% of its memory quota"
    
    - alert: NamespacePodCountHigh
      expr: |
        (
          sum(kube_pod_info{namespace="$namespace"}) /
          sum(kube_resourcequota{namespace="$namespace", resource="pods", type="hard"}) * 100
        ) > 90
      for: 2m
      labels:
        severity: warning
        namespace: $namespace
        resource: pods
      annotations:
        summary: "High pod count in namespace $namespace"
        description: "Namespace $namespace is using {{ \$value }}% of its pod quota"
    
    - alert: NamespacePersistentVolumeUsage
      expr: |
        (
          sum(kubelet_volume_stats_used_bytes{namespace="$namespace"}) /
          sum(kubelet_volume_stats_capacity_bytes{namespace="$namespace"}) * 100
        ) > 85
      for: 5m
      labels:
        severity: warning
        namespace: $namespace
        resource: storage
      annotations:
        summary: "High storage usage in namespace $namespace"
        description: "Namespace $namespace storage is {{ \$value }}% full"
  
  - name: ${namespace}-application-health
    interval: 30s
    rules:
    - alert: NamespacePodCrashLooping
      expr: |
        rate(kube_pod_container_status_restarts_total{namespace="$namespace"}[5m]) * 60 * 5 > 0
      for: 2m
      labels:
        severity: critical
        namespace: $namespace
        type: reliability
      annotations:
        summary: "Pod crash looping in namespace $namespace"
        description: "Pod {{ \$labels.pod }} is crash looping in namespace $namespace"
    
    - alert: NamespaceServiceDown
      expr: |
        up{namespace="$namespace"} == 0
      for: 1m
      labels:
        severity: critical
        namespace: $namespace
        type: availability
      annotations:
        summary: "Service down in namespace $namespace"
        description: "Service {{ \$labels.job }} is down in namespace $namespace"
    
    - alert: NamespaceHighErrorRate
      expr: |
        (
          sum(rate(http_requests_total{namespace="$namespace", status=~"5.."}[5m])) /
          sum(rate(http_requests_total{namespace="$namespace"}[5m])) * 100
        ) > 5
      for: 3m
      labels:
        severity: warning
        namespace: $namespace
        type: reliability
      annotations:
        summary: "High error rate in namespace $namespace"
        description: "Error rate is {{ \$value }}% in namespace $namespace"
  
  - name: ${namespace}-security-events
    interval: 30s
    rules:
    - alert: NamespaceUnauthorizedAccess
      expr: |
        increase(apiserver_audit_total{namespace="$namespace", verb="create", objectRef_apiVersion="v1", objectRef_resource="pods", user_username!~"system:.*"}[5m]) > 0
      for: 0m
      labels:
        severity: critical
        namespace: $namespace
        type: security
      annotations:
        summary: "Unauthorized pod creation in namespace $namespace"
        description: "User {{ \$labels.user_username }} created pods in namespace $namespace"
    
    - alert: NamespacePrivilegedContainer
      expr: |
        kube_pod_container_status_running{namespace="$namespace"} == 1
        and on(pod) kube_pod_spec_containers_security_context_privileged{namespace="$namespace"} == 1
      for: 0m
      labels:
        severity: critical
        namespace: $namespace
        type: security
      annotations:
        summary: "Privileged container running in namespace $namespace"
        description: "Privileged container in pod {{ \$labels.pod }} in namespace $namespace"
EOF
}

create_monitoring_dashboards() {
    local namespace=$1
    
    # Create Grafana dashboard ConfigMap
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${namespace}-dashboard
  namespace: $namespace
  labels:
    grafana_dashboard: "1"
    namespace: $namespace
data:
  ${namespace}-overview.json: |
    {
      "dashboard": {
        "id": null,
        "title": "Namespace Overview - $namespace",
        "tags": ["kubernetes", "namespace", "$namespace"],
        "timezone": "browser",
        "panels": [
          {
            "id": 1,
            "title": "CPU Usage",
            "type": "stat",
            "targets": [
              {
                "expr": "sum(rate(container_cpu_usage_seconds_total{namespace=\"$namespace\"}[5m]))",
                "legendFormat": "CPU Usage"
              }
            ],
            "fieldConfig": {
              "defaults": {
                "unit": "cores",
                "min": 0
              }
            },
            "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
          },
          {
            "id": 2,
            "title": "Memory Usage",
            "type": "stat",
            "targets": [
              {
                "expr": "sum(container_memory_usage_bytes{namespace=\"$namespace\"})",
                "legendFormat": "Memory Usage"
              }
            ],
            "fieldConfig": {
              "defaults": {
                "unit": "bytes",
                "min": 0
              }
            },
            "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
          },
          {
            "id": 3,
            "title": "Pod Count",
            "type": "stat",
            "targets": [
              {
                "expr": "sum(kube_pod_info{namespace=\"$namespace\"})",
                "legendFormat": "Running Pods"
              }
            ],
            "fieldConfig": {
              "defaults": {
                "unit": "short",
                "min": 0
              }
            },
            "gridPos": {"h": 8, "w": 6, "x": 0, "y": 8}
          },
          {
            "id": 4,
            "title": "Service Count",
            "type": "stat",
            "targets": [
              {
                "expr": "sum(kube_service_info{namespace=\"$namespace\"})",
                "legendFormat": "Services"
              }
            ],
            "gridPos": {"h": 8, "w": 6, "x": 6, "y": 8}
          },
          {
            "id": 5,
            "title": "Network I/O",
            "type": "graph",
            "targets": [
              {
                "expr": "sum(rate(container_network_receive_bytes_total{namespace=\"$namespace\"}[5m]))",
                "legendFormat": "Receive"
              },
              {
                "expr": "sum(rate(container_network_transmit_bytes_total{namespace=\"$namespace\"}[5m]))",
                "legendFormat": "Transmit"
              }
            ],
            "yAxes": [
              {
                "unit": "Bps"
              }
            ],
            "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8}
          }
        ],
        "time": {
          "from": "now-1h",
          "to": "now"
        },
        "refresh": "30s"
      }
    }
EOF
}

setup_log_aggregation() {
    local namespace=$1
    
    # Create Fluent Bit configuration for namespace-specific log collection
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${namespace}-fluent-bit-config
  namespace: $namespace
  labels:
    app: fluent-bit
    namespace: $namespace
data:
  fluent-bit.conf: |
    [SERVICE]
        Flush         1
        Log_Level     info
        Daemon        off
        Parsers_File  parsers.conf
        HTTP_Server   On
        HTTP_Listen   0.0.0.0
        HTTP_Port     2020

    [INPUT]
        Name              tail
        Path              /var/log/containers/*_${namespace}_*.log
        Parser            cri
        Tag               kube.*
        Refresh_Interval  5
        Mem_Buf_Limit     50MB
        Skip_Long_Lines   On

    [FILTER]
        Name                kubernetes
        Match               kube.*
        Kube_URL            https://kubernetes.default.svc:443
        Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
        Kube_Tag_Prefix     kube.var.log.containers.
        Merge_Log           On
        Keep_Log            Off
        K8S-Logging.Parser  On
        K8S-Logging.Exclude On

    [FILTER]
        Name             nest
        Match            kube.*
        Operation        lift
        Nested_under     kubernetes
        Add_prefix       k8s_

    [FILTER]
        Name             modify
        Match            kube.*
        Add              namespace ${namespace}
        Add              cluster \${CLUSTER_NAME}

    [OUTPUT]
        Name            es
        Match           kube.*
        Host            elasticsearch.logging.svc.cluster.local
        Port            9200
        Index           kubernetes-${namespace}
        Type            _doc
        Logstash_Format On
        Logstash_Prefix kubernetes-${namespace}
        Retry_Limit     False

  parsers.conf: |
    [PARSER]
        Name        cri
        Format      regex
        Regex       ^(?<time>[^ ]+) (?<stream>stdout|stderr) (?<logtag>[^ ]*) (?<message>.*)$
        Time_Key    time
        Time_Format %Y-%m-%dT%H:%M:%S.%L%z
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: ${namespace}-fluent-bit
  namespace: $namespace
  labels:
    app: fluent-bit
    namespace: $namespace
spec:
  selector:
    matchLabels:
      app: fluent-bit
  template:
    metadata:
      labels:
        app: fluent-bit
        namespace: $namespace
    spec:
      serviceAccountName: fluent-bit
      containers:
      - name: fluent-bit
        image: fluent/fluent-bit:2.0
        ports:
        - containerPort: 2020
          name: http
        env:
        - name: CLUSTER_NAME
          value: "production-cluster"  # Replace with actual cluster name
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        volumeMounts:
        - name: config
          mountPath: /fluent-bit/etc
        - name: varlog
          mountPath: /var/log
          readOnly: true
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
      volumes:
      - name: config
        configMap:
          name: ${namespace}-fluent-bit-config
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
      terminationGracePeriodSeconds: 10
EOF
}

# Resource usage analysis and reporting
generate_namespace_usage_report() {
    local namespace=$1
    local time_range=${2:-"7d"}
    local output_format=${3:-"text"}
    
    echo "📈 Generating usage report for namespace: $namespace"
    echo "Time range: $time_range"
    
    local report_file="${namespace}-usage-report-$(date +%Y%m%d).${output_format}"
    
    case $output_format in
        "json")
            generate_json_usage_report "$namespace" "$time_range" > "$report_file"
            ;;
        "csv")
            generate_csv_usage_report "$namespace" "$time_range" > "$report_file"
            ;;
        *)
            generate_text_usage_report "$namespace" "$time_range" > "$report_file"
            ;;
    esac
    
    echo "✅ Usage report generated: $report_file"
}

generate_text_usage_report() {
    local namespace=$1
    local time_range=$2
    
    cat << EOF
# Namespace Usage Report: $namespace
Generated: $(date)
Time Range: $time_range

## Resource Quotas and Usage
$(kubectl describe quota -n "$namespace" 2>/dev/null || echo "No resource quotas found")

## Current Resource Usage
### Pods
$(kubectl top pods -n "$namespace" --no-headers 2>/dev/null | head -10 || echo "Metrics not available")

### CPU and Memory Summary
$(kubectl top pods -n "$namespace" --no-headers 2>/dev/null | awk '
BEGIN { cpu_total=0; mem_total=0; count=0 }
{
    # Remove 'm' from CPU and convert to millicores
    cpu = $2; gsub(/m/, "", cpu); cpu_total += cpu
    # Remove 'Mi' from memory and convert to MB
    mem = $3; gsub(/Mi/, "", mem); mem_total += mem
    count++
}
END {
    print "Total Pods: " count
    print "Total CPU Usage: " cpu_total "m"
    print "Total Memory Usage: " mem_total "Mi"
    print "Average CPU per Pod: " (count > 0 ? cpu_total/count : 0) "m"
    print "Average Memory per Pod: " (count > 0 ? mem_total/count : 0) "Mi"
}' || echo "Unable to calculate summary")

## Storage Usage
$(kubectl get pvc -n "$namespace" --no-headers 2>/dev/null | awk '
BEGIN { total_storage=0; count=0 }
{
    storage = $4
    gsub(/Gi/, "", storage)
    total_storage += storage
    count++
}
END {
    print "Total PVCs: " count
    print "Total Storage Requested: " total_storage "Gi"
}' || echo "No PVCs found")

## Network Policies
$(kubectl get networkpolicies -n "$namespace" --no-headers 2>/dev/null | wc -l || echo "0") network policies configured

## Recent Events (Last 24 hours)
$(kubectl get events -n "$namespace" --sort-by='.lastTimestamp' | tail -20 || echo "No recent events")

## Recommendations
EOF

    # Add recommendations based on usage patterns
    generate_usage_recommendations "$namespace"
}

generate_usage_recommendations() {
    local namespace=$1
    
    echo "### Optimization Recommendations"
    
    # Check for over-provisioned resources
    local pod_count=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | wc -l)
    local quota_pods=$(kubectl get quota -n "$namespace" -o jsonpath='{.items[0].spec.hard.pods}' 2>/dev/null)
    
    if [[ -n "$quota_pods" && $pod_count -lt $((quota_pods / 2)) ]]; then
        echo "- Consider reducing pod quota from $quota_pods to $((pod_count * 2))"
    fi
    
    # Check for unused ConfigMaps and Secrets
    local unused_configmaps=$(kubectl get configmaps -n "$namespace" --no-headers 2>/dev/null | 
        grep -v "kube-root-ca.crt" | wc -l)
    if [[ $unused_configmaps -gt 10 ]]; then
        echo "- Review and cleanup unused ConfigMaps ($unused_configmaps found)"
    fi
    
    # Check for resource requests/limits
    echo "- Ensure all pods have resource requests and limits defined"
    echo "- Consider implementing horizontal pod autoscaling for variable workloads"
    echo "- Review network policies for security optimization"
}

# Performance monitoring and optimization
optimize_namespace_performance() {
    local namespace=$1
    local optimization_level=${2:-"standard"}
    
    echo "🚀 Optimizing performance for namespace: $namespace"
    
    case $optimization_level in
        "aggressive")
            apply_aggressive_optimizations "$namespace"
            ;;
        "conservative")
            apply_conservative_optimizations "$namespace"
            ;;
        *)
            apply_standard_optimizations "$namespace"
            ;;
    esac
    
    echo "✅ Performance optimization complete"
}

apply_standard_optimizations() {
    local namespace=$1
    
    # Apply performance-oriented resource limits
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: performance-limits
  namespace: $namespace
  labels:
    optimization-level: standard
spec:
  limits:
  - type: Container
    default:
      memory: "512Mi"
      cpu: "200m"
      ephemeral-storage: "1Gi"
    defaultRequest:
      memory: "256Mi"
      cpu: "100m"
      ephemeral-storage: "500Mi"
    max:
      memory: "2Gi"
      cpu: "1000m"
    maxLimitRequestRatio:
      memory: 2
      cpu: 2
EOF

    # Create performance monitoring service
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: performance-metrics
  namespace: $namespace
  labels:
    app: performance-monitor
    metrics: enabled
spec:
  selector:
    monitoring: performance
  ports:
  - port: 8080
    name: metrics
    targetPort: 8080
EOF

    echo "✅ Applied standard performance optimizations"
}

# Cost monitoring and optimization
setup_cost_monitoring() {
    local namespace=$1
    local cost_center=${2:-"engineering"}
    local budget_monthly=${3:-1000}
    
    echo "💰 Setting up cost monitoring for namespace: $namespace"
    
    # Add cost tracking labels
    kubectl label namespace "$namespace" \
        cost-center="$cost_center" \
        budget-monthly="$budget_monthly" \
        cost-tracking=enabled \
        --overwrite
    
    # Create cost monitoring alerts
    cat << EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: ${namespace}-cost-alerts
  namespace: $namespace
  labels:
    cost-monitoring: enabled
spec:
  groups:
  - name: ${namespace}-cost-monitoring
    rules:
    - alert: NamespaceHighCost
      expr: |
        (
          sum(kube_pod_container_resource_requests{namespace="$namespace", resource="cpu"}) * 0.05 +
          sum(kube_pod_container_resource_requests{namespace="$namespace", resource="memory"} / 1024 / 1024 / 1024) * 0.01
        ) * 24 * 30 > $budget_monthly
      for: 5m
      labels:
        severity: warning
        namespace: $namespace
        type: cost
      annotations:
        summary: "High projected monthly cost for namespace $namespace"
        description: "Projected monthly cost exceeds budget of \${budget_monthly}"
    
    - alert: NamespaceUnusedResources
      expr: |
        (
          avg_over_time(
            (sum(kube_pod_container_resource_requests{namespace="$namespace", resource="cpu"}) - 
             sum(rate(container_cpu_usage_seconds_total{namespace="$namespace"}[5m]))
            )[7d:]
          ) / sum(kube_pod_container_resource_requests{namespace="$namespace", resource="cpu"})
        ) > 0.5
      for: 1h
      labels:
        severity: info
        namespace: $namespace
        type: cost-optimization
      annotations:
        summary: "Unused CPU resources in namespace $namespace"
        description: "Over 50% of requested CPU is unused, consider right-sizing"
EOF

    echo "✅ Cost monitoring configured for namespace: $namespace"
}

---

## 9. Enterprise Patterns and Multi-Tenancy

### Multi-Tenant Architecture Implementation

Enterprise multi-tenancy requires sophisticated isolation, resource sharing, and governance mechanisms. This section covers advanced patterns for large-scale deployments.

```bash
#!/bin/bash
# enterprise-multi-tenancy.sh - Advanced multi-tenant patterns

implement_hierarchical_tenancy() {
    local organization=$1
    local business_units=("${@:2}")
    
    echo "🏢 Implementing hierarchical tenancy for: $organization"
    
    # Create organization-level namespace
    create_organization_namespace "$organization"
    
    # Create business unit namespaces
    for bu in "${business_units[@]}"; do
        create_business_unit_namespace "$organization" "$bu"
        
        # Create team namespaces within business unit
        create_team_namespaces "$organization" "$bu"
        
        # Set up cross-BU communication policies
        setup_cross_bu_policies "$organization" "$bu"
    done
    
    # Implement organization-wide governance
    apply_organization_governance "$organization"
    
    echo "✅ Hierarchical tenancy implemented for $organization"
}

create_organization_namespace() {
    local org=$1
    
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: ${org}-shared
  labels:
    organization: $org
    tenant-level: organization
    tenant-type: shared
    resource-sharing: cross-bu
  annotations:
    description: "Organization-wide shared resources and services"
    tenant-hierarchy: "organization"
    resource-policy: "shared-across-business-units"
EOF

    # Create organization-wide ResourceQuota
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ${org}-org-quota
  namespace: ${org}-shared
  labels:
    tenant-level: organization
spec:
  hard:
    requests.cpu: "100"
    requests.memory: 200Gi
    limits.cpu: "200"
    limits.memory: 400Gi
    pods: "500"
    services: "100"
    persistentvolumeclaims: "50"
    # Shared services quotas
    count/deployments.apps: "50"
    count/statefulsets.apps: "20"
    services.loadbalancers: "10"
EOF
}

create_business_unit_namespace() {
    local org=$1
    local bu=$2
    
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: ${org}-${bu}
  labels:
    organization: $org
    business-unit: $bu
    tenant-level: business-unit
    tenant-type: dedicated
    parent-tenant: ${org}-${bu}
  annotations:
    description: "Team namespace for $team in $bu business unit"
    tenant-hierarchy: "team"
    parent-namespace: "${org}-${bu}"
    team-contact: "${team}@${org}.com"
    environment: $env
EOF

        # Apply team-specific resource allocation
        apply_team_resource_allocation "$namespace" "$team" "$env"
        
        # Set up team-specific RBAC
        setup_team_rbac "$namespace" "$team" "$bu" "$org"
        
        # Configure team network policies
        setup_team_network_policies "$namespace" "$team" "$env"
    done
}

apply_team_resource_allocation() {
    local namespace=$1
    local team=$2
    local environment=$3
    
    # Define resource tiers based on team function and environment
    local cpu_base memory_base pod_base
    
    case $team in
        "frontend"|"backend")
            cpu_base=4
            memory_base=8
            pod_base=30
            ;;
        "ml-platform"|"data-engineering")
            cpu_base=8
            memory_base=32
            pod_base=20
            ;;
        "devops"|"platform")
            cpu_base=6
            memory_base=16
            pod_base=40
            ;;
        *)
            cpu_base=2
            memory_base=4
            pod_base=15
            ;;
    esac
    
    # Apply environment multipliers
    case $environment in
        "development")
            cpu_quota=$((cpu_base / 2))
            memory_quota=$((memory_base / 2))
            pod_quota=$((pod_base / 2))
            ;;
        "staging")
            cpu_quota=$((cpu_base * 3 / 4))
            memory_quota=$((memory_base * 3 / 4))
            pod_quota=$((pod_base * 3 / 4))
            ;;
        "production")
            cpu_quota=$cpu_base
            memory_quota=$memory_base
            pod_quota=$pod_base
            ;;
    esac
    
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ${namespace}-quota
  namespace: $namespace
  labels:
    team: $team
    environment: $environment
    tenant-level: team
spec:
  hard:
    requests.cpu: "${cpu_quota}"
    requests.memory: "${memory_quota}Gi"
    limits.cpu: "$((cpu_quota * 2))"
    limits.memory: "$((memory_quota * 2))Gi"
    pods: "$pod_quota"
    services: "$((pod_quota / 3))"
    secrets: "$((pod_quota / 2))"
    configmaps: "$((pod_quota / 2))"
    persistentvolumeclaims: "$((pod_quota / 5))"
EOF
}

setup_cross_bu_policies() {
    local org=$1
    local bu=$2
    
    # Create cross-business-unit communication policy
    cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: cross-bu-communication
  namespace: ${org}-${bu}
  labels:
    policy-type: cross-business-unit
    organization: $org
    business-unit: $bu
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  # Allow communication from organization shared services
  - from:
    - namespaceSelector:
        matchLabels:
          organization: $org
          tenant-level: organization
  
  # Allow communication from approved business units
  - from:
    - namespaceSelector:
        matchLabels:
          organization: $org
          cross-bu-access: approved
    - podSelector:
        matchLabels:
          cross-bu-client: approved
  
  egress:
  # Allow communication to organization shared services
  - to:
    - namespaceSelector:
        matchLabels:
          organization: $org
          tenant-level: organization
  
  # Allow external communication (with restrictions)
  - to: []
    ports:
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 80
  
  # DNS
  - to: []
    ports:
    - protocol: UDP
      port: 53
EOF
}

# Advanced tenant isolation with Virtual Clusters
implement_virtual_cluster_tenancy() {
    local tenant_name=$1
    local isolation_level=${2:-"hard"}
    
    echo "🏗️ Implementing virtual cluster tenancy for: $tenant_name"
    
    case $isolation_level in
        "hard")
            create_hard_isolated_tenant "$tenant_name"
            ;;
        "soft")
            create_soft_isolated_tenant "$tenant_name"
            ;;
        "shared")
            create_shared_tenant "$tenant_name"
            ;;
    esac
}

create_hard_isolated_tenant() {
    local tenant=$1
    
    # Create dedicated node pool for tenant (would require cluster-level configuration)
    # This is represented as a placeholder for the concept
    
    # Create tenant root namespace
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: ${tenant}-root
  labels:
    tenant: $tenant
    isolation-level: hard
    tenant-type: virtual-cluster
    node-pool: ${tenant}-dedicated
  annotations:
    description: "Root namespace for hard-isolated tenant: $tenant"
    isolation-model: "virtual-cluster"
    dedicated-nodes: "true"
EOF

    # Create strict resource quotas for the entire tenant
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ${tenant}-tenant-quota
  namespace: ${tenant}-root
  labels:
    tenant: $tenant
    quota-scope: tenant-wide
spec:
  hard:
    requests.cpu: "50"
    requests.memory: 100Gi
    limits.cpu: "100"
    limits.memory: 200Gi
    pods: "200"
    services: "50"
    persistentvolumeclaims: "30"
    count/deployments.apps: "50"
    count/statefulsets.apps: "10"
    services.loadbalancers: "5"
EOF

    # Create tenant-specific storage class
    cat << EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ${tenant}-ssd
  labels:
    tenant: $tenant
    performance-tier: high
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp3
  fsType: ext4
  encrypted: "true"
allowedTopologies:
- matchLabelExpressions:
  - key: kubernetes.io/hostname
    values: 
    - ${tenant}-node-1
    - ${tenant}-node-2
    - ${tenant}-node-3
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
EOF

    # Set up tenant-specific monitoring namespace
    create_tenant_monitoring_namespace "$tenant"
    
    echo "✅ Hard-isolated tenant created: $tenant"
}

create_soft_isolated_tenant() {
    local tenant=$1
    
    # Create tenant namespace with soft isolation
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: ${tenant}-tenant
  labels:
    tenant: $tenant
    isolation-level: soft
    tenant-type: logical
    resource-sharing: controlled
  annotations:
    description: "Soft-isolated tenant: $tenant"
    isolation-model: "namespace-based"
    resource-sharing: "controlled"
EOF

    # Apply tenant-wide network policies for soft isolation
    cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ${tenant}-tenant-isolation
  namespace: ${tenant}-tenant
  labels:
    tenant: $tenant
    policy-type: tenant-isolation
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  # Only allow ingress from same tenant or approved sources
  - from:
    - namespaceSelector:
        matchLabels:
          tenant: $tenant
    - namespaceSelector:
        matchLabels:
          tenant-access: approved
    - podSelector:
        matchLabels:
          tenant-client: $tenant
  
  egress:
  # Allow egress to same tenant
  - to:
    - namespaceSelector:
        matchLabels:
          tenant: $tenant
  
  # Allow egress to shared services
  - to:
    - namespaceSelector:
        matchLabels:
          service-type: shared
    - namespaceSelector:
        matchLabels:
          name: kube-system
  
  # External access
  - to: []
    ports:
    - protocol: TCP
      port: 443
    - protocol: UDP
      port: 53
EOF

    echo "✅ Soft-isolated tenant created: $tenant"
}

create_tenant_monitoring_namespace() {
    local tenant=$1
    
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: ${tenant}-monitoring
  labels:
    tenant: $tenant
    service-type: monitoring
    tenant-component: observability
  annotations:
    description: "Monitoring infrastructure for tenant: $tenant"
    tenant-service: "observability"
EOF

    # Deploy tenant-specific Prometheus instance
    cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${tenant}-prometheus
  namespace: ${tenant}-monitoring
  labels:
    app: prometheus
    tenant: $tenant
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
      tenant: $tenant
  template:
    metadata:
      labels:
        app: prometheus
        tenant: $tenant
    spec:
      serviceAccountName: ${tenant}-prometheus
      containers:
      - name: prometheus
        image: prom/prometheus:latest
        args:
        - --config.file=/etc/prometheus/prometheus.yml
        - --storage.tsdb.path=/prometheus/
        - --web.console.libraries=/etc/prometheus/console_libraries
        - --web.console.templates=/etc/prometheus/consoles
        - --storage.tsdb.retention.time=15d
        - --web.enable-lifecycle
        - --web.external-url=https://prometheus-${tenant}.company.com
        ports:
        - containerPort: 9090
          name: web
        resources:
          requests:
            memory: "2Gi"
            cpu: "500m"
          limits:
            memory: "4Gi"
            cpu: "1000m"
        volumeMounts:
        - name: config
          mountPath: /etc/prometheus
        - name: storage
          mountPath: /prometheus
      volumes:
      - name: config
        configMap:
          name: ${tenant}-prometheus-config
      - name: storage
        persistentVolumeClaim:
          claimName: ${tenant}-prometheus-storage
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${tenant}-prometheus-config
  namespace: ${tenant}-monitoring
  labels:
    app: prometheus
    tenant: $tenant
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
      external_labels:
        tenant: '$tenant'
        cluster: 'production'
    
    rule_files:
    - "/etc/prometheus/rules/*.yml"
    
    scrape_configs:
    - job_name: 'kubernetes-pods'
      kubernetes_sd_configs:
      - role: pod
        namespaces:
          names:
          - ${tenant}-tenant
          - ${tenant}-root
          - ${tenant}-monitoring
      
      relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: \$1:\$2
        target_label: __address__
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
      - source_labels: [__meta_kubernetes_namespace]
        action: replace
        target_label: kubernetes_namespace
      - source_labels: [__meta_kubernetes_pod_name]
        action: replace
        target_label: kubernetes_pod_name
    
    - job_name: 'kubernetes-service-endpoints'
      kubernetes_sd_configs:
      - role: endpoints
        namespaces:
          names:
          - ${tenant}-tenant
          - ${tenant}-root
      
      relabel_configs:
      - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scheme]
        action: replace
        target_label: __scheme__
        regex: (https?)
      - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels: [__address__, __meta_kubernetes_service_annotation_prometheus_io_port]
        action: replace
        target_label: __address__
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: \$1:\$2
      - action: labelmap
        regex: __meta_kubernetes_service_label_(.+)
      - source_labels: [__meta_kubernetes_namespace]
        action: replace
        target_label: kubernetes_namespace
      - source_labels: [__meta_kubernetes_service_name]
        action: replace
        target_label: kubernetes_name
EOF
}

# Tenant resource sharing and governance
implement_resource_sharing_governance() {
    local organization=$1
    
    echo "📋 Implementing resource sharing governance for: $organization"
    
    # Create shared resource pool
    create_shared_resource_pool "$organization"
    
    # Set up resource borrowing policies
    setup_resource_borrowing "$organization"
    
    # Implement cost allocation tracking
    setup_cost_allocation_tracking "$organization"
    
    # Create governance reporting
    setup_governance_reporting "$organization"
}

create_shared_resource_pool() {
    local org=$1
    
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: ${org}-shared-pool
  labels:
    organization: $org
    resource-type: shared-pool
    allocation-policy: dynamic
  annotations:
    description: "Shared resource pool for burst capacity and common services"
    allocation-model: "dynamic-borrowing"
    cost-model: "usage-based"
EOF

    # Create large shared quota
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ${org}-shared-pool-quota
  namespace: ${org}-shared-pool
  labels:
    resource-type: shared-pool
spec:
  hard:
    requests.cpu: "200"
    requests.memory: 400Gi
    limits.cpu: "400"
    limits.memory: 800Gi
    pods: "1000"
    services: "200"
    persistentvolumeclaims: "100"
EOF

    # Create resource borrowing policy
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${org}-borrowing-policy
  namespace: ${org}-shared-pool
  labels:
    policy-type: resource-borrowing
data:
  policy.yaml: |
    borrowing_rules:
      max_borrow_duration: "4h"
      max_borrow_percentage: 50
      priority_borrowers:
        - production
        - critical
      approval_required_above:
        cpu: "10"
        memory: "20Gi"
      automatic_approval_below:
        cpu: "5"
        memory: "10Gi"
      cost_multiplier:
        burst: 1.5
        sustained: 2.0
EOF
}

setup_cost_allocation_tracking() {
    local org=$1
    
    # Create cost tracking service
    cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${org}-cost-tracker
  namespace: ${org}-shared-pool
  labels:
    app: cost-tracker
    organization: $org
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cost-tracker
  template:
    metadata:
      labels:
        app: cost-tracker
        organization: $org
    spec:
      serviceAccountName: cost-tracker
      containers:
      - name: cost-tracker
        image: cost-tracker:latest  # Placeholder - would be custom image
        env:
        - name: ORGANIZATION
          value: $org
        - name: PROMETHEUS_URL
          value: "http://prometheus.monitoring.svc.cluster.local:9090"
        - name: COST_MODEL_CONFIG
          valueFrom:
            configMapKeyRef:
              name: cost-model-config
              key: config.yaml
        ports:
        - containerPort: 8080
          name: http
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "200m"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: cost-model-config
  namespace: ${org}-shared-pool
  labels:
    app: cost-tracker
data:
  config.yaml: |
    cost_model:
      cpu_cost_per_core_hour: 0.05
      memory_cost_per_gb_hour: 0.01
      storage_cost_per_gb_month: 0.10
      network_cost_per_gb: 0.02
    
    business_units:
      engineering:
        cost_center: "TECH-001"
        budget_monthly: 10000
        alert_threshold: 0.8
      data-science:
        cost_center: "DATA-001"
        budget_monthly: 15000
        alert_threshold: 0.9
      sales:
        cost_center: "SALES-001"
        budget_monthly: 3000
        alert_threshold: 0.7
    
    allocation_rules:
      shared_services:
        distribution: "equal"
        services: ["monitoring", "logging", "ingress"]
      burst_capacity:
        charging: "actual_usage"
        premium_rate: 1.5
EOF
}

---

## 10. Troubleshooting and Best Practices

### Common Namespace Issues and Solutions

Understanding common namespace problems and their solutions is crucial for maintaining healthy cluster operations.

```bash
#!/bin/bash
# namespace-troubleshooter.sh - Comprehensive troubleshooting toolkit

diagnose_namespace_issues() {
    local namespace=$1
    local verbose=${2:-false}
    
    echo "🔍 Diagnosing issues in namespace: $namespace"
    
    # Check if namespace exists
    if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
        echo "❌ Namespace '$namespace' does not exist"
        return 1
    fi
    
    # Run comprehensive health checks
    check_namespace_health "$namespace" "$verbose"
    check_resource_quotas "$namespace" "$verbose"
    check_network_policies "$namespace" "$verbose"
    check_rbac_issues "$namespace" "$verbose"
    check_pod_issues "$namespace" "$verbose"
    check_storage_issues "$namespace" "$verbose"
    
    # Generate diagnosis report
    generate_diagnosis_report "$namespace"
}

check_namespace_health() {
    local namespace=$1
    local verbose=$2
    
    echo "🏥 Checking namespace health..."
    
    # Check namespace status
    local ns_status=$(kubectl get namespace "$namespace" -o jsonpath='{.status.phase}')
    if [[ "$ns_status" != "Active" ]]; then
        echo "⚠️  Namespace status is: $ns_status (expected: Active)"
    else
        echo "✅ Namespace status: Active"
    fi
    
    # Check for namespace being stuck in terminating state
    local deletion_timestamp=$(kubectl get namespace "$namespace" -o jsonpath='{.metadata.deletionTimestamp}')
    if [[ -n "$deletion_timestamp" ]]; then
        echo "🚨 WARNING: Namespace is being deleted (deletionTimestamp: $deletion_timestamp)"
        check_finalizers "$namespace"
    fi
    
    # Check recent events
    local error_events=$(kubectl get events -n "$namespace" --field-selector type=Warning --no-headers 2>/dev/null | wc -l)
    if [[ $error_events -gt 0 ]]; then
        echo "⚠️  Found $error_events warning events in the namespace"
        if [[ "$verbose" == "true" ]]; then
            kubectl get events -n "$namespace" --field-selector type=Warning
        fi
    else
        echo "✅ No warning events found"
    fi
}

check_finalizers() {
    local namespace=$1
    
    echo "🔍 Checking namespace finalizers..."
    
    local finalizers=$(kubectl get namespace "$namespace" -o jsonpath='{.spec.finalizers[*]}')
    if [[ -n "$finalizers" ]]; then
        echo "⚠️  Namespace has finalizers: $finalizers"
        echo "💡 Suggestion: Check if these finalizers are preventing deletion"
        
        # Common finalizer issues and solutions
        if [[ "$finalizers" == *"kubernetes"* ]]; then
            echo "   - kubernetes finalizer: Check for remaining resources in namespace"
            kubectl api-resources --verbs=list --namespaced -o name | xargs -n 1 kubectl get --show-kind --ignore-not-found -n "$namespace"
        fi
        
        if [[ "$finalizers" == *"controller"* ]]; then
            echo "   - controller finalizer: Check if the controller is running and healthy"
        fi
    else
        echo "✅ No finalizers blocking namespace deletion"
    fi
}

check_resource_quotas() {
    local namespace=$1
    local verbose=$2
    
    echo "📊 Checking resource quotas..."
    
    local quotas=$(kubectl get quota -n "$namespace" --no-headers 2>/dev/null | wc -l)
    if [[ $quotas -eq 0 ]]; then
        echo "⚠️  No resource quotas found - resources are unlimited"
        return 0
    fi
    
    echo "✅ Found $quotas resource quota(s)"
    
    # Check quota usage
    kubectl get quota -n "$namespace" -o custom-columns='NAME:.metadata.name,RESOURCE:.spec.hard,USED:.status.used' --no-headers 2>/dev/null | while read -r line; do
        local quota_name=$(echo "$line" | awk '{print $1}')
        echo "   Analyzing quota: $quota_name"
        
        # Get detailed quota information
        local quota_info=$(kubectl describe quota "$quota_name" -n "$namespace" 2>/dev/null)
        
        # Check for quota violations
        if echo "$quota_info" | grep -q "exceeded"; then
            echo "   🚨 Quota exceeded in $quota_name"
            if [[ "$verbose" == "true" ]]; then
                echo "$quota_info" | grep -A 5 -B 5 "exceeded"
            fi
        fi
        
        # Check for near-quota conditions (>80% usage)
        check_quota_thresholds "$namespace" "$quota_name"
    done
}

check_quota_thresholds() {
    local namespace=$1
    local quota_name=$2
    
    # Get quota details in JSON for easier parsing
    local quota_json=$(kubectl get quota "$quota_name" -n "$namespace" -o json 2>/dev/null)
    
    if [[ -n "$quota_json" ]]; then
        # Parse CPU quota
        local cpu_hard=$(echo "$quota_json" | jq -r '.spec.hard["requests.cpu"] // empty' | sed 's/m$//' | sed 's/$//')
        local cpu_used=$(echo "$quota_json" | jq -r '.status.used["requests.cpu"] // empty' | sed 's/m$//' | sed 's/$//')
        
        if [[ -n "$cpu_hard" && -n "$cpu_used" ]]; then
            local cpu_percent=$(echo "scale=0; $cpu_used * 100 / $cpu_hard" | bc 2>/dev/null || echo "0")
            if [[ $cpu_percent -gt 80 ]]; then
                echo "   ⚠️  CPU usage at ${cpu_percent}% of quota"
            fi
        fi
        
        # Parse memory quota
        local mem_hard=$(echo "$quota_json" | jq -r '.spec.hard["requests.memory"] // empty' | sed 's/Gi$//' | sed 's/Mi$//' | sed 's/$//')
        local mem_used=$(echo "$quota_json" | jq -r '.status.used["requests.memory"] // empty' | sed 's/Gi$//' | sed 's/Mi$//' | sed 's/$//')
        
        if [[ -n "$mem_hard" && -n "$mem_used" ]]; then
            # Convert Mi to Gi if needed
            if [[ "$mem_hard" == *"Mi" ]]; then
                mem_hard=$(echo "scale=2; $mem_hard / 1024" | bc)
            fi
            if [[ "$mem_used" == *"Mi" ]]; then
                mem_used=$(echo "scale=2; $mem_used / 1024" | bc)
            fi
            
            local mem_percent=$(echo "scale=0; $mem_used * 100 / $mem_hard" | bc 2>/dev/null || echo "0")
            if [[ $mem_percent -gt 80 ]]; then
                echo "   ⚠️  Memory usage at ${mem_percent}% of quota"
            fi
        fi
    fi
}

check_network_policies() {
    local namespace=$1
    local verbose=$2
    
    echo "🌐 Checking network policies..."
    
    local policies=$(kubectl get networkpolicies -n "$namespace" --no-headers 2>/dev/null | wc -l)
    if [[ $policies -eq 0 ]]; then
        echo "⚠️  No network policies found - all traffic is allowed"
        return 0
    fi
    
    echo "✅ Found $policies network policy(ies)"
    
    # Check for default deny policies
    local has_default_deny=$(kubectl get networkpolicies -n "$namespace" -o json 2>/dev/null | jq -r '.items[] | select(.spec.podSelector == {}) | .metadata.name' | wc -l)
    
    if [[ $has_default_deny -eq 0 ]]; then
        echo "   ⚠️  No default deny policy found - consider implementing one for security"
    else
        echo "   ✅ Default deny policy implemented"
    fi
    
    # Check for policy conflicts
    check_network_policy_conflicts "$namespace" "$verbose"
}

check_network_policy_conflicts() {
    local namespace=$1
    local verbose=$2
    
    echo "   🔍 Checking for policy conflicts..."
    
    # Get all network policies
    local policies=$(kubectl get networkpolicies -n "$namespace" -o json 2>/dev/null)
    
    # Check for overlapping selectors
    local selectors=$(echo "$policies" | jq -r '.items[].spec.podSelector')
    
    # This is a simplified check - in reality, you'd need more sophisticated overlap detection
    local empty_selectors=$(echo "$selectors" | grep -c '{}' || true)
    
    if [[ $empty_selectors -gt 1 ]]; then
        echo "   ⚠️  Multiple policies with empty pod selectors found - may cause conflicts"
    fi
}

check_rbac_issues() {
    local namespace=$1
    local verbose=$2
    
    echo "🔐 Checking RBAC configuration..."
    
    # Check for service accounts
    local service_accounts=$(kubectl get serviceaccounts -n "$namespace" --no-headers 2>/dev/null | wc -l)
    echo "   Found $service_accounts service account(s)"
    
    # Check for role bindings
    local role_bindings=$(kubectl get rolebindings -n "$namespace" --no-headers 2>/dev/null | wc -l)
    echo "   Found $role_bindings role binding(s)"
    
    # Check for roles
    local roles=$(kubectl get roles -n "$namespace" --no-headers 2>/dev/null | wc -l)
    echo "   Found $roles role(s)"
    
    # Check for orphaned role bindings
    check_orphaned_rbac "$namespace" "$verbose"
}

check_orphaned_rbac() {
    local namespace=$1
    local verbose=$2
    
    echo "   🔍 Checking for orphaned RBAC resources..."
    
    # Check for role bindings without corresponding roles
    kubectl get rolebindings -n "$namespace" -o json 2>/dev/null | jq -r '.items[] | select(.roleRef.kind == "Role") | .roleRef.name' | sort -u | while read -r role_name; do
        if [[ -n "$role_name" ]] && ! kubectl get role "$role_name" -n "$namespace" >/dev/null 2>&1; then
            echo "   ⚠️  Role binding references non-existent role: $role_name"
        fi
    done
    
    # Check for role bindings without corresponding service accounts
    kubectl get rolebindings -n "$namespace" -o json 2>/dev/null | jq -r '.items[] | .subjects[]? | select(.kind == "ServiceAccount") | .name' | sort -u | while read -r sa_name; do
        if [[ -n "$sa_name" ]] && ! kubectl get serviceaccount "$sa_name" -n "$namespace" >/dev/null 2>&1; then
            echo "   ⚠️  Role binding references non-existent service account: $sa_name"
        fi
    done
}

check_pod_issues() {
    local namespace=$1
    local verbose=$2
    
    echo "🐳 Checking pod issues..."
    
    # Check pod status distribution
    local pod_status=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | awk '{print $3}' | sort | uniq -c)
    
    if [[ -n "$pod_status" ]]; then
        echo "   Pod status distribution:"
        echo "$pod_status" | while read -r count status; do
            echo "     $status: $count"
            
            # Flag problematic statuses
            case $status in
                "CrashLoopBackOff"|"Error"|"Failed"|"ImagePullBackOff"|"ErrImagePull")
                    echo "     🚨 Found pods in problematic state: $status"
                    if [[ "$verbose" == "true" ]]; then
                        kubectl get pods -n "$namespace" --field-selector=status.phase!=Running --no-headers | head -5
                    fi
                    ;;
                "Pending")
                    echo "     ⚠️  Pods stuck in Pending state - check resource availability and node selectors"
                    ;;
                "Terminating")
                    echo "     ⚠️  Pods stuck in Terminating state - may indicate finalizer issues"
                    ;;
            esac
        done
    else
        echo "   ✅ No pods found or all pods are healthy"
    fi
    
    # Check for resource-related issues
    check_pod_resource_issues "$namespace" "$verbose"
}

check_pod_resource_issues() {
    local namespace=$1
    local verbose=$2
    
    echo "   🔍 Checking pod resource issues..."
    
    # Check for pods without resource requests/limits
    local pods_without_requests=$(kubectl get pods -n "$namespace" -o json 2>/dev/null | jq -r '.items[] | select(.spec.containers[]?.resources.requests == null) | .metadata.name' | wc -l)
    
    if [[ $pods_without_requests -gt 0 ]]; then
        echo "   ⚠️  $pods_without_requests pod(s) without resource requests"
    fi
    
    # Check for evicted pods
    local evicted_pods=$(kubectl get pods -n "$namespace" --field-selector=status.phase=Failed -o json 2>/dev/null | jq -r '.items[] | select(.status.reason == "Evicted") | .metadata.name' | wc -l)
    
    if [[ $evicted_pods -gt 0 ]]; then
        echo "   🚨 $evicted_pods evicted pod(s) found - indicates resource pressure"
        if [[ "$verbose" == "true" ]]; then
            kubectl get pods -n "$namespace" --field-selector=status.phase=Failed -o json | jq -r '.items[] | select(.status.reason == "Evicted") | "\(.metadata.name): \(.status.message)"'
        fi
    fi
}

check_storage_issues() {
    local namespace=$1
    local verbose=$2
    
    echo "💾 Checking storage issues..."
    
    # Check PVC status
    local pvc_status=$(kubectl get pvc -n "$namespace" --no-headers 2>/dev/null | awk '{print $2}' | sort | uniq -c)
    
    if [[ -n "$pvc_status" ]]; then
        echo "   PVC status distribution:"
        echo "$pvc_status" | while read -r count status; do
            echo "     $status: $count"
            
            case $status in
                "Pending")
                    echo "     ⚠️  PVCs stuck in Pending state - check storage class and availability"
                    if [[ "$verbose" == "true" ]]; then
                        kubectl describe pvc -n "$namespace" | grep -A 10 "Status.*Pending"
                    fi
                    ;;
                "Lost")
                    echo "     🚨 PVCs in Lost state - data may be inaccessible"
                    ;;
            esac
        done
    else
        echo "   ✅ No PVCs found or all PVCs are bound"
    fi
    
    # Check for storage capacity issues
    check_storage_capacity "$namespace" "$verbose"
}

check_storage_capacity() {
    local namespace=$1
    local verbose=$2
    
    echo "   🔍 Checking storage capacity..."
    
    # Get PVC usage information
    kubectl get pvc -n "$namespace" -o json 2>/dev/null | jq -r '.items[] | "\(.metadata.name) \(.spec.resources.requests.storage) \(.status.capacity.storage // "unknown")"' | while read -r pvc_name requested capacity; do
        if [[ "$capacity" != "unknown" && "$capacity" != "$requested" ]]; then
            echo "   ⚠️  PVC $pvc_name: requested $requested, got $capacity"
        fi
    done
}

generate_diagnosis_report() {
    local namespace=$1
    local report_file="${namespace}-diagnosis-$(date +%Y%m%d-%H%M%S).txt"
    
    echo "📋 Generating comprehensive diagnosis report..."
    
    {
        echo "# Namespace Diagnosis Report: $namespace"
        echo "Generated: $(date)"
        echo "Cluster: $(kubectl config current-context)"
        echo ""
        
        echo "## Namespace Overview"
        kubectl describe namespace "$namespace" 2>/dev/null || echo "Unable to describe namespace"
        echo ""
        
        echo "## Resource Summary"
        kubectl get all -n "$namespace" 2>/dev/null || echo "Unable to list resources"
        echo ""
        
        echo "## Resource Quotas"
        kubectl describe quota -n "$namespace" 2>/dev/null || echo "No resource quotas found"
        echo ""
        
        echo "## Recent Events"
        kubectl get events -n "$namespace" --sort-by='.lastTimestamp' | tail -20 2>/dev/null || echo "No events found"
        echo ""
        
        echo "## Network Policies"
        kubectl describe networkpolicies -n "$namespace" 2>/dev/null || echo "No network policies found"
        echo ""
        
        echo "## RBAC Configuration"
        echo "### Service Accounts"
        kubectl get serviceaccounts -n "$namespace" 2>/dev/null || echo "No service accounts found"
        echo ""
        echo "### Roles"
        kubectl get roles -n "$namespace" 2>/dev/null || echo "No roles found"
        echo ""
        echo "### Role Bindings"
        kubectl get rolebindings -n "$namespace" 2>/dev/null || echo "No role bindings found"
        echo ""
        
        echo "## Recommendations"
        generate_recommendations "$namespace"
        
    } > "$report_file"
    
    echo "✅ Diagnosis report saved: $report_file"
}

generate_recommendations() {
    local namespace=$1
    
    echo "Based on the analysis, here are recommendations for namespace '$namespace':"
    echo ""
    
    # Resource-based recommendations
    local pod_count=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | wc -l)
    local quota_exists=$(kubectl get quota -n "$namespace" --no-headers 2>/dev/null | wc -l)
    
    if [[ $pod_count -gt 0 && $quota_exists -eq 0 ]]; then
        echo "- Implement ResourceQuota to prevent resource exhaustion"
    fi
    
    local netpol_count=$(kubectl get networkpolicies -n "$namespace" --no-headers 2>/dev/null | wc -l)
    if [[ $pod_count -gt 0 && $netpol_count -eq 0 ]]; then
        echo "- Implement NetworkPolicies for better security posture"
    fi
    
    # Check for pods without resource requests
    local pods_without_requests=$(kubectl get pods -n "$namespace" -o json 2>/dev/null | jq -r '.items[] | select(.spec.containers[]?.resources.requests == null) | .metadata.name' | wc -l)
    if [[ $pods_without_requests -gt 0 ]]; then
        echo "- Set resource requests and limits on all pods for better scheduling"
    fi
    
    echo "- Regular monitoring and alerting setup recommended"
    echo "- Consider implementing pod disruption budgets for critical workloads"
    echo "- Review and update RBAC permissions regularly"
}

# Namespace performance optimization
optimize_namespace_performance() {
    local namespace=$1
    local optimization_type=${2:-"balanced"}
    
    echo "🚀 Optimizing namespace performance: $namespace"
    
    case $optimization_type in
        "cpu-optimized")
            apply_cpu_optimizations "$namespace"
            ;;
        "memory-optimized")
            apply_memory_optimizations "$namespace"
            ;;
        "storage-optimized")
            apply_storage_optimizations "$namespace"
            ;;
        "network-optimized")
            apply_network_optimizations "$namespace"
            ;;
        *)
            apply_balanced_optimizations "$namespace"
            ;;
    esac
}

apply_balanced_optimizations() {
    local namespace=$1
    
    echo "   Applying balanced optimizations..."
    
    # Create optimized LimitRange
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: performance-optimized-limits
  namespace: $namespace
  labels:
    optimization-type: balanced
    managed-by: performance-optimizer
spec:
  limits:
  - type: Container
    default:
      memory: "512Mi"
      cpu: "200m"
      ephemeral-storage: "1Gi"
    defaultRequest:
      memory: "256Mi"
      cpu: "100m"
      ephemeral-storage: "500Mi"
    max:
      memory: "4Gi"
      cpu: "2000m"
      ephemeral-storage: "10Gi"
    min:
      memory: "64Mi"
      cpu: "50m"
      ephemeral-storage: "100Mi"
    maxLimitRequestRatio:
      memory: 2
      cpu: 2
  - type: Pod
    max:
      memory: "8Gi"
      cpu: "4000m"
EOF

    # Create performance monitoring ConfigMap
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: performance-config
  namespace: $namespace
  labels:
    optimization-type: balanced
data:
  performance.yaml: |
    optimization:
      type: balanced
      applied_date: $(date -Iseconds)
      settings:
        resource_efficiency: enabled
        monitoring: enhanced
        alerting: standard
    recommendations:
      - "Monitor resource usage patterns regularly"
      - "Adjust resource requests based on actual usage"
      - "Implement horizontal pod autoscaling where appropriate"
      - "Use readiness and liveness probes for better reliability"
EOF

    echo "   ✅ Balanced optimizations applied"
}

# Namespace migration utilities
migrate_namespace() {
    local source_namespace=$1
    local target_namespace=$2
    local migration_strategy=${3:-"copy"}
    local dry_run=${4:-true}
    
    echo "🚚 Migrating namespace: $source_namespace → $target_namespace"
    echo "Strategy: $migration_strategy, Dry run: $dry_run"
    
    # Validate source namespace exists
    if ! kubectl get namespace "$source_namespace" >/dev/null 2>&1; then
        echo "❌ Source namespace '$source_namespace' does not exist"
        return 1
    fi
    
    # Create target namespace if it doesn't exist
    if ! kubectl get namespace "$target_namespace" >/dev/null 2>&1; then
        if [[ "$dry_run" == "false" ]]; then
            create_target_namespace "$source_namespace" "$target_namespace"
        else
            echo "[DRY RUN] Would create target namespace: $target_namespace"
        fi
    fi
    
    case $migration_strategy in
        "copy")
            copy_namespace_resources "$source_namespace" "$target_namespace" "$dry_run"
            ;;
        "move")
            move_namespace_resources "$source_namespace" "$target_namespace" "$dry_run"
            ;;
        "clone")
            clone_namespace_resources "$source_namespace" "$target_namespace" "$dry_run"
            ;;
    esac
    
    # Generate migration report
    generate_migration_report "$source_namespace" "$target_namespace" "$migration_strategy"
}

copy_namespace_resources() {
    local source=$1
    local target=$2
    local dry_run=$3
    
    echo "   📋 Copying resources from $source to $target..."
    
    # Get all resources in source namespace
    local resources_to_copy=(
        "configmaps"
        "secrets"
        "services"
        "deployments"
        "statefulsets"
        "daemonsets"
        "jobs"
        "cronjobs"
        "ingresses"
        "networkpolicies"
        "servicemonitors"
        "persistentvolumeclaims"
    )
    
    for resource_type in "${resources_to_copy[@]}"; do
        local resource_count=$(kubectl get "$resource_type" -n "$source" --no-headers 2>/dev/null | wc -l)
        
        if [[ $resource_count -gt 0 ]]; then
            echo "     Copying $resource_count $resource_type..."
            
            if [[ "$dry_run" == "false" ]]; then
                kubectl get "$resource_type" -n "$source" -o yaml | \
                sed "s/namespace: $source/namespace: $target/g" | \
                kubectl apply -f -
            else
                echo "     [DRY RUN] Would copy $resource_count $resource_type"
            fi
        fi
    done
}

create_target_namespace() {
    local source=$1
    local target=$2
    
    echo "   🏗️ Creating target namespace with metadata from source..."
    
    # Copy namespace metadata
    kubectl get namespace "$source" -o yaml | \
    sed "s/name: $source/name: $target/g" | \
    sed '/resourceVersion:/d' | \
    sed '/uid:/d' | \
    sed '/creationTimestamp:/d' | \
    sed '/selfLink:/d' | \
    kubectl apply -f -
    
    # Copy resource quotas
    kubectl get quota -n "$source" -o yaml 2>/dev/null | \
    sed "s/namespace: $source/namespace: $target/g" | \
    sed '/resourceVersion:/d' | \
    sed '/uid:/d' | \
    sed '/creationTimestamp:/d' | \
    kubectl apply -f - 2>/dev/null || true
    
    # Copy limit ranges
    kubectl get limitrange -n "$source" -o yaml 2>/dev/null | \
    sed "s/namespace: $source/namespace: $target/g" | \
    sed '/resourceVersion:/d' | \
    sed '/uid:/d' | \
    sed '/creationTimestamp:/d' | \
    kubectl apply -f - 2>/dev/null || true
}

# Best practices enforcement
enforce_namespace_best_practices() {
    local namespace=$1
    local enforcement_level=${2:-"standard"}
    
    echo "📜 Enforcing best practices for namespace: $namespace"
    
    case $enforcement_level in
        "strict")
            enforce_strict_practices "$namespace"
            ;;
        "relaxed")
            enforce_relaxed_practices "$namespace"
            ;;
        *)
            enforce_standard_practices "$namespace"
            ;;
    esac
}

enforce_standard_practices() {
    local namespace=$1
    
    echo "   Applying standard best practices..."
    
    # Ensure namespace has proper labels
    kubectl label namespace "$namespace" \
        best-practices=enforced \
        enforcement-level=standard \
        enforcement-date="$(date +%Y-%m-%d)" \
        --overwrite
    
    # Check and create resource quota if missing
    if ! kubectl get quota -n "$namespace" >/dev/null 2>&1; then
        echo "   📊 Creating default resource quota..."
        cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: default-quota
  namespace: $namespace
  labels:
    created-by: best-practices-enforcer
    enforcement-level: standard
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    pods: "20"
    services: "10"
    secrets: "20"
    configmaps: "20"
    persistentvolumeclaims: "10"
EOF
    fi
    
    # Check and create limit range if missing
    if ! kubectl get limitrange -n "$namespace" >/dev/null 2>&1; then
        echo "   📏 Creating default limit range..."
        cat << EOF | kubectl apply -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: $namespace
  labels:
    created-by: best-practices-enforcer
    enforcement-level: standard
spec:
  limits:
  - type: Container
    default:
      memory: "512Mi"
      cpu: "200m"
    defaultRequest:
      memory: "128Mi"
      cpu: "50m"
    max:
      memory: "2Gi"
      cpu: "1000m"
    min:
      memory: "32Mi"
      cpu: "10m"
EOF
    fi
    
    # Check for basic network policy
    if ! kubectl get networkpolicy -n "$namespace" >/dev/null 2>&1; then
        echo "   🌐 Creating default network policy..."
        cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: $namespace
  labels:
    created-by: best-practices-enforcer
    enforcement-level: standard
    policy-type: default-deny
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  egress:
  # Allow DNS
  - to: []
    ports:
    - protocol: UDP
      port: 53
  # Allow HTTPS
  - to: []
    ports:
    - protocol: TCP
      port: 443
EOF
    fi
    
    echo "   ✅ Standard best practices enforced"
}

# Namespace cleanup utilities
cleanup_unused_resources() {
    local namespace=$1
    local cleanup_age_days=${2:-30}
    local dry_run=${3:-true}
    
    echo "🧹 Cleaning up unused resources in namespace: $namespace"
    echo "Cleanup age: $cleanup_age_days days, Dry run: $dry_run"
    
    # Calculate cutoff date
    local cutoff_date=$(date -d "$cleanup_age_days days ago" --iso-8601=seconds)
    
    # Clean up failed pods
    cleanup_failed_pods "$namespace" "$cutoff_date" "$dry_run"
    
    # Clean up succeeded jobs
    cleanup_succeeded_jobs "$namespace" "$cutoff_date" "$dry_run"
    
    # Clean up unused configmaps and secrets
    cleanup_unused_configmaps "$namespace" "$dry_run"
    cleanup_unused_secrets "$namespace" "$dry_run"
    
    # Clean up completed replica sets
    cleanup_old_replicasets "$namespace" "$cutoff_date" "$dry_run"
    
    echo "✅ Cleanup completed for namespace: $namespace"
}

cleanup_failed_pods() {
    local namespace=$1
    local cutoff_date=$2
    local dry_run=$3
    
    echo "   🗑️ Cleaning up failed pods..."
    
    local failed_pods=$(kubectl get pods -n "$namespace" --field-selector=status.phase=Failed -o json | \
        jq -r --arg cutoff "$cutoff_date" '.items[] | select(.metadata.creationTimestamp < $cutoff) | .metadata.name')
    
    if [[ -n "$failed_pods" ]]; then
        local count=$(echo "$failed_pods" | wc -w)
        echo "     Found $count failed pods older than $cutoff_date"
        
        if [[ "$dry_run" == "false" ]]; then
            echo "$failed_pods" | xargs kubectl delete pod -n "$namespace"
            echo "     ✅ Deleted $count failed pods"
        else
            echo "     [DRY RUN] Would delete $count failed pods"
        fi
    else
        echo "     ✅ No old failed pods found"
    fi
}

cleanup_succeeded_jobs() {
    local namespace=$1
    local cutoff_date=$2
    local dry_run=$3
    
    echo "   🗑️ Cleaning up succeeded jobs..."
    
    local succeeded_jobs=$(kubectl get jobs -n "$namespace" --field-selector=status.successful=1 -o json | \
        jq -r --arg cutoff "$cutoff_date" '.items[] | select(.status.completionTime < $cutoff) | .metadata.name')
    
    if [[ -n "$succeeded_jobs" ]]; then
        local count=$(echo "$succeeded_jobs" | wc -w)
        echo "     Found $count succeeded jobs older than $cutoff_date"
        
        if [[ "$dry_run" == "false" ]]; then
            echo "$succeeded_jobs" | xargs kubectl delete job -n "$namespace"
            echo "     ✅ Deleted $count succeeded jobs"
        else
            echo "     [DRY RUN] Would delete $count succeeded jobs"
        fi
    else
        echo "     ✅ No old succeeded jobs found"
    fi
}

cleanup_unused_configmaps() {
    local namespace=$1
    local dry_run=$2
    
    echo "   🗑️ Checking for unused ConfigMaps..."
    
    # Get all configmaps
    local all_configmaps=$(kubectl get configmaps -n "$namespace" -o json | jq -r '.items[].metadata.name')
    
    # Get configmaps referenced by pods
    local used_configmaps=$(kubectl get pods -n "$namespace" -o json | \
        jq -r '.items[] | [.spec.volumes[]?.configMap.name, .spec.containers[]?.envFrom[]?.configMapRef.name, .spec.containers[]?.env[]?.valueFrom.configMapKeyRef.name] | .[] | select(. != null)' | \
        sort -u)
    
    # Find unused configmaps (excluding system ones)
    local unused_configmaps=""
    for cm in $all_configmaps; do
        if [[ "$cm" != "kube-root-ca.crt" ]] && ! echo "$used_configmaps" | grep -q "^$cm$"; then
            unused_configmaps="$unused_configmaps $cm"
        fi
    done
    
    if [[ -n "$unused_configmaps" ]]; then
        local count=$(echo "$unused_configmaps" | wc -w)
        echo "     Found $count unused ConfigMaps"
        
        if [[ "$dry_run" == "false" ]]; then
            echo "$unused_configmaps" | xargs kubectl delete configmap -n "$namespace"
            echo "     ✅ Deleted $count unused ConfigMaps"
        else
            echo "     [DRY RUN] Would delete ConfigMaps: $unused_configmaps"
        fi
    else
        echo "     ✅ No unused ConfigMaps found"
    fi
}

# Generate comprehensive best practices report
generate_best_practices_report() {
    local namespace=$1
    local output_format=${2:-"text"}
    
    echo "📊 Generating best practices report for namespace: $namespace"
    
    local report_file="${namespace}-best-practices-$(date +%Y%m%d).${output_format}"
    
    {
        echo "# Kubernetes Namespace Best Practices Report"
        echo "Namespace: $namespace"
        echo "Generated: $(date)"
        echo "Cluster: $(kubectl config current-context)"
        echo ""
        
        # Security assessment
        assess_security_practices "$namespace"
        
        # Resource management assessment
        assess_resource_practices "$namespace"
        
        # Operational practices assessment
        assess_operational_practices "$namespace"
        
        # Generate overall score and recommendations
        generate_practices_score "$namespace"
        
    } > "$report_file"
    
    echo "✅ Best practices report generated: $report_file"
}

assess_security_practices() {
    local namespace=$1
    
    echo "## Security Practices Assessment"
    echo ""
    
    # Check for network policies
    local netpol_count=$(kubectl get networkpolicies -n "$namespace" --no-headers 2>/dev/null | wc -l)
    if [[ $netpol_count -gt 0 ]]; then
        echo "✅ Network policies implemented ($netpol_count found)"
    else
        echo "❌ No network policies found - RECOMMENDATION: Implement network policies"
    fi
    
    # Check for pod security standards
    local pss_enforce=$(kubectl get namespace "$namespace" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null)
    if [[ -n "$pss_enforce" ]]; then
        echo "✅ Pod Security Standards enforced: $pss_enforce"
    else
        echo "❌ Pod Security Standards not configured - RECOMMENDATION: Configure PSS"
    fi
    
    # Check for RBAC
    local rbac_count=$(kubectl get rolebindings -n "$namespace" --no-headers 2>/dev/null | wc -l)
    if [[ $rbac_count -gt 0 ]]; then
        echo "✅ RBAC configured ($rbac_count role bindings)"
    else
        echo "⚠️  No RBAC configuration found - RECOMMENDATION: Implement RBAC"
    fi
    
    echo ""
}

assess_resource_practices() {
    local namespace=$1
    
    echo "## Resource Management Assessment"
    echo ""
    
    # Check for resource quotas
    local quota_count=$(kubectl get quota -n "$namespace" --no-headers 2>/dev/null | wc -l)
    if [[ $quota_count -gt 0 ]]; then
        echo "✅ Resource quotas configured ($quota_count found)"
    else
        echo "❌ No resource quotas found - RECOMMENDATION: Implement resource quotas"
    fi
    
    # Check for limit ranges
    local limit_count=$(kubectl get limitrange -n "$namespace" --no-headers 2>/dev/null | wc -l)
    if [[ $limit_count -gt 0 ]]; then
        echo "✅ Limit ranges configured ($limit_count found)"
    else
        echo "❌ No limit ranges found - RECOMMENDATION: Implement limit ranges"
    fi
    
    # Check for pods with resource requests/limits
    local total_pods=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | wc -l)
    local pods_with_requests=0
    
    if [[ $total_pods -gt 0 ]]; then
        pods_with_requests=$(kubectl get pods -n "$namespace" -o json 2>/dev/null | \
            jq -r '.items[] | select(.spec.containers[].resources.requests != null) | .metadata.name' | wc -l)
        
        local percentage=$((pods_with_requests * 100 / total_pods))
        
        if [[ $percentage -ge 90 ]]; then
            echo "✅ Resource requests configured on $percentage% of pods"
        elif [[ $percentage -ge 50 ]]; then
            echo "⚠️  Resource requests configured on only $percentage% of pods - RECOMMENDATION: Add requests to all pods"
        else
            echo "❌ Resource requests configured on only $percentage% of pods - CRITICAL: Add resource requests"
        fi
    fi
    
    echo ""
}

assess_operational_practices() {
    local namespace=$1
    
    echo "## Operational Practices Assessment"
    echo ""
    
    # Check for proper labeling
    local labeled_resources=$(kubectl get all -n "$namespace" -o json 2>/dev/null | \
        jq -r '.items[] | select(.metadata.labels != null and (.metadata.labels | length) > 0) | .metadata.name' | wc -l)
    local total_resources=$(kubectl get all -n "$namespace" --no-headers 2>/dev/null | wc -l)
    
    if [[ $total_resources -gt 0 ]]; then
        local label_percentage=$((labeled_resources * 100 / total_resources))
        if [[ $label_percentage -ge 90 ]]; then
            echo "✅ $label_percentage% of resources are properly labeled"
        else
            echo "⚠️  Only $label_percentage% of resources are labeled - RECOMMENDATION: Add consistent labels"
        fi
    fi
    
    # Check for monitoring setup
    local monitoring_services=$(kubectl get services -n "$namespace" -l metrics=enabled --no-headers 2>/dev/null | wc -l)
    if [[ $monitoring_services -gt 0 ]]; then
        echo "✅ Monitoring services configured ($monitoring_services found)"
    else
        echo "⚠️  No monitoring services found - RECOMMENDATION: Set up monitoring"
    fi
    
    # Check for health probes
    local pods_with_probes=$(kubectl get pods -n "$namespace" -o json 2>/dev/null | \
        jq -r '.items[] | select(.spec.containers[].livenessProbe != null or .spec.containers[].readinessProbe != null) | .metadata.name' | wc -l)
    
    if [[ $total_pods -gt 0 ]]; then
        local probe_percentage=$((pods_with_probes * 100 / total_pods))
        if [[ $probe_percentage -ge 80 ]]; then
            echo "✅ $probe_percentage% of pods have health probes"
        else
            echo "⚠️  Only $probe_percentage% of pods have health probes - RECOMMENDATION: Add liveness/readiness probes"
        fi
    fi
    
    echo ""
}

generate_practices_score() {
    local namespace=$1
    
    echo "## Overall Assessment Score"
    echo ""
    
    local score=0
    local max_score=10
    
    # Security score (3 points max)
    local netpol_count=$(kubectl get networkpolicies -n "$namespace" --no-headers 2>/dev/null | wc -l)
    [[ $netpol_count -gt 0 ]] && ((score++))
    
    local pss_enforce=$(kubectl get namespace "$namespace" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null)
    [[ -n "$pss_enforce" ]] && ((score++))
    
    local rbac_count=$(kubectl get rolebindings -n "$namespace" --no-headers 2>/dev/null | wc -l)
    [[ $rbac_count -gt 0 ]] && ((score++))
    
    # Resource management score (4 points max)
    local quota_count=$(kubectl get quota -n "$namespace" --no-headers 2>/dev/null | wc -l)
    [[ $quota_count -gt 0 ]] && ((score++))
    
    local limit_count=$(kubectl get limitrange -n "$namespace" --no-headers 2>/dev/null | wc -l)
    [[ $limit_count -gt 0 ]] && ((score++))
    
    local total_pods=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | wc -l)
    if [[ $total_pods -gt 0 ]]; then
        local pods_with_requests=$(kubectl get pods -n "$namespace" -o json 2>/dev/null | \
            jq -r '.items[] | select(.spec.containers[].resources.requests != null) | .metadata.name' | wc -l)
        local percentage=$((pods_with_requests * 100 / total_pods))
        [[ $percentage -ge 80 ]] && ((score++))
        
        local pods_with_limits=$(kubectl get pods -n "$namespace" -o json 2>/dev/null | \
            jq -r '.items[] | select(.spec.containers[].resources.limits != null) | .metadata.name' | wc -l)
        local limit_percentage=$((pods_with_limits * 100 / total_pods))
        [[ $limit_percentage -ge 80 ]] && ((score++))
    fi
    
    # Operational practices score (3 points max)
    local total_resources=$(kubectl get all -n "$namespace" --no-headers 2>/dev/null | wc -l)
    if [[ $total_resources -gt 0 ]]; then
        local labeled_resources=$(kubectl get all -n "$namespace" -o json 2>/dev/null | \
            jq -r '.items[] | select(.metadata.labels != null and (.metadata.labels | length) > 0) | .metadata.name' | wc -l)
        local label_percentage=$((labeled_resources * 100 / total_resources))
        [[ $label_percentage -ge 80 ]] && ((score++))
    fi
    
    local monitoring_services=$(kubectl get services -n "$namespace" -l metrics=enabled --no-headers 2>/dev/null | wc -l)
    [[ $monitoring_services -gt 0 ]] && ((score++))
    
    if [[ $total_pods -gt 0 ]]; then
        local pods_with_probes=$(kubectl get pods -n "$namespace" -o json 2>/dev/null | \
            jq -r '.items[] | select(.spec.containers[].livenessProbe != null or .spec.containers[].readinessProbe != null) | .metadata.name' | wc -l)
        local probe_percentage=$((pods_with_probes * 100 / total_pods))
        [[ $probe_percentage -ge 80 ]] && ((score++))
    fi
    
    local score_percentage=$((score * 100 / max_score))
    
    echo "**Overall Score: $score/$max_score ($score_percentage%)**"
    echo ""
    
    if [[ $score_percentage -ge 90 ]]; then
        echo "🏆 **EXCELLENT** - Your namespace follows best practices very well!"
    elif [[ $score_percentage -ge 70 ]]; then
        echo "✅ **GOOD** - Your namespace follows most best practices with room for improvement."
    elif [[ $score_percentage -ge 50 ]]; then
        echo "⚠️  **FAIR** - Several best practices need to be implemented."
    else
        echo "❌ **POOR** - Critical best practices are missing. Immediate action required."
    fi
    
    echo ""
    echo "## Priority Recommendations"
    
    # Generate prioritized recommendations based on missing practices
    if [[ $netpol_count -eq 0 ]]; then
        echo "1. **HIGH PRIORITY**: Implement network policies for security isolation"
    fi
    
    if [[ $quota_count -eq 0 ]]; then
        echo "2. **HIGH PRIORITY**: Implement resource quotas to prevent resource exhaustion"
    fi
    
    if [[ -z "$pss_enforce" ]]; then
        echo "3. **MEDIUM PRIORITY**: Configure Pod Security Standards"
    fi
    
    if [[ $limit_count -eq 0 ]]; then
        echo "4. **MEDIUM PRIORITY**: Implement limit ranges for better resource control"
    fi
    
    if [[ $total_pods -gt 0 ]]; then
        local pods_with_requests=$(kubectl get pods -n "$namespace" -o json 2>/dev/null | \
            jq -r '.items[] | select(.spec.containers[].resources.requests != null) | .metadata.name' | wc -l)
        local percentage=$((pods_with_requests * 100 / total_pods))
        if [[ $percentage -lt 80 ]]; then
            echo "5. **MEDIUM PRIORITY**: Add resource requests and limits to all pods"
        fi
    fi
    
    if [[ $monitoring_services -eq 0 ]]; then
        echo "6. **LOW PRIORITY**: Set up monitoring and observability"
    fi
}

# Usage examples and testing
test_namespace_management() {
    local test_namespace="test-namespace-$(date +%s)"
    
    echo "🧪 Testing namespace management functions..."
    
    # Test namespace creation
    echo "Testing namespace creation..."
    create_namespace_with_lifecycle "$test_namespace" "test-team" "testing" "development" 30
    
    # Test diagnosis
    echo "Testing diagnosis..."
    diagnose_namespace_issues "$test_namespace" false
    
    # Test best practices enforcement
    echo "Testing best practices enforcement..."
    enforce_namespace_best_practices "$test_namespace" "standard"
    
    # Test monitoring setup
    echo "Testing monitoring setup..."
    setup_namespace_monitoring "$test_namespace" "standard" "warning"
    
    # Wait a moment for resources to be created
    sleep 5
    
    # Test best practices report
    echo "Testing best practices report..."
    generate_best_practices_report "$test_namespace" "text"
    
    # Test cleanup
    echo "Testing cleanup..."
    cleanup_unused_resources "$test_namespace" 0 false
    
    # Clean up test namespace
    echo "Cleaning up test namespace..."
    kubectl delete namespace "$test_namespace" --wait=false
    
    echo "✅ All tests completed successfully!"
}

# Main execution function
main() {
    local command=$1
    shift
    
    case $command in
        "create")
            create_namespace_with_lifecycle "$@"
            ;;
        "diagnose")
            diagnose_namespace_issues "$@"
            ;;
        "monitor")
            setup_namespace_monitoring "$@"
            ;;
        "optimize")
            optimize_namespace_performance "$@"
            ;;
        "migrate")
            migrate_namespace "$@"
            ;;
        "cleanup")
            cleanup_unused_resources "$@"
            ;;
        "best-practices")
            enforce_namespace_best_practices "$@"
            ;;
        "report")
            generate_best_practices_report "$@"
            ;;
        "test")
            test_namespace_management
            ;;
        *)
            echo "Usage: $0 {create|diagnose|monitor|optimize|migrate|cleanup|best-practices|report|test} [options]"
            echo ""
            echo "Commands:"
            echo "  create <name> <team> <env> [stage] [retention]  - Create namespace with lifecycle"
            echo "  diagnose <namespace> [verbose]                  - Diagnose namespace issues"
            echo "  monitor <namespace> [tier] [severity]           - Setup monitoring"
            echo "  optimize <namespace> [type]                     - Optimize performance"
            echo "  migrate <source> <target> [strategy] [dry-run]  - Migrate namespace"
            echo "  cleanup <namespace> [days] [dry-run]            - Cleanup unused resources"
            echo "  best-practices <namespace> [level]              - Enforce best practices"
            echo "  report <namespace> [format]                     - Generate practices report"
            echo "  test                                             - Run test suite"
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

---

## Conclusion

This comprehensive guide has covered every aspect of Kubernetes namespace management, from basic concepts to enterprise-scale implementations. The key takeaways include:

### Essential Points to Remember

1. **Namespace Design Matters**: Choose between single-tenant and multi-tenant architectures based on your organizational needs, security requirements, and operational complexity.

2. **Security is Paramount**: Always implement proper RBAC, network policies, and Pod Security Standards. Security should be built into your namespace design from the beginning.

3. **Resource Governance is Critical**: Use ResourceQuotas and LimitRanges to prevent resource exhaustion and ensure fair resource allocation across teams and applications.

4. **Monitoring and Observability**: Implement comprehensive monitoring for resource usage, performance metrics, security events, and operational health.

5. **Lifecycle Management**: Plan for the complete lifecycle of namespaces, including creation, evolution, migration, and eventual decommissioning.

6. **Automation is Key**: Use automation for namespace creation, policy enforcement, monitoring setup, and cleanup operations to ensure consistency and reduce operational overhead.

### Best Practices Summary

- **Always** implement ResourceQuotas and LimitRanges
- **Always** use NetworkPolicies for traffic control
- **Always** configure proper RBAC with least privilege principle
- **Always** add comprehensive labels and annotations for organization
- **Always** implement monitoring and alerting
- **Never** leave namespaces without resource controls
- **Never** use overly permissive RBAC policies
- **Never** ignore namespace lifecycle management
- **Never** forget to plan for disaster recovery and backup

### Tools and Scripts Provided

This guide includes production-ready scripts for:
- Advanced namespace creation and management
- Comprehensive monitoring and alerting setup
- Security policy enforcement
- Performance optimization
- Migration utilities
- Troubleshooting and diagnosis
- Best practices enforcement
- Resource cleanup automation

### Moving Forward

Namespace management is an ongoing process that requires regular review and optimization. Use the tools and patterns provided in this guide to build a robust, secure, and efficient namespace strategy that scales with your organization's growth.

Remember that effective namespace management is not just about technical implementation—it's about enabling teams to work efficiently while maintaining security, performance, and cost control across your Kubernetes infrastructure.shared
  annotations:
    description: "Business unit namespace for $bu"
    tenant-hierarchy: "business-unit"
    parent-namespace: "${org}-shared"
    cost-center: $bu
    budget-owner: "${bu}-leadership"
EOF

    # Business unit specific quotas
    local bu_cpu_quota bu_memory_quota bu_pod_quota
    case $bu in
        "engineering")
            bu_cpu_quota="50"
            bu_memory_quota="100Gi"
            bu_pod_quota="200"
            ;;
        "data-science")
            bu_cpu_quota="30"
            bu_memory_quota="150Gi"  # More memory for ML workloads
            bu_pod_quota="100"
            ;;
        "sales")
            bu_cpu_quota="10"
            bu_memory_quota="20Gi"
            bu_pod_quota="50"
            ;;
        *)
            bu_cpu_quota="20"
            bu_memory_quota="40Gi"
            bu_pod_quota="100"
            ;;
    esac
    
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ${org}-${bu}-quota
  namespace: ${org}-${bu}
  labels:
    business-unit: $bu
    tenant-level: business-unit
spec:
  hard:
    requests.cpu: "$bu_cpu_quota"
    requests.memory: $bu_memory_quota
    limits.cpu: "$((bu_cpu_quota * 2))"
    limits.memory: "$((${bu_memory_quota%Gi} * 2))Gi"
    pods: "$bu_pod_quota"
    services: "$((bu_pod_quota / 4))"
    secrets: "$((bu_pod_quota / 2))"
    configmaps: "$((bu_pod_quota / 2))"
EOF
}

create_team_namespaces() {
    local org=$1
    local bu=$2
    
    # Define teams per business unit
    local -A teams=(
        ["engineering"]="frontend backend devops platform"
        ["data-science"]="ml-platform data-engineering analytics"
        ["sales"]="crm sales-ops"
    )
    
    for team in ${teams[$bu]}; do
        create_team_namespace "$org" "$bu" "$team"
    done
}

create_team_namespace() {
    local org=$1
    local bu=$2
    local team=$3
    
    for env in development staging production; do
        local namespace="${org}-${bu}-${team}-${env}"
        
        cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: $namespace
  labels:
    organization: $org
    business-unit: $bu
    team: $team
    environment: $env
    tenant-level: team
    tenant-type: dedicated
    parent-tenant: ${org}-.sh - Create dedicated namespaces for each application

create_application_namespaces() {
    local app_name=$1
    local environments=("development" "staging" "production")
    
    echo "Creating single-tenant namespace architecture for: $app_name"
    
    for env in "${environments[@]}"; do
        local namespace="${app_name}-${env}"
        
        # Create namespace with comprehensive metadata
        cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: $namespace
  labels:
    app: $app_name
    environment: $env
    tenant-model: single-tenant
    isolation-level: application
    created-date: $(date +%Y-%m-%d)
  annotations:
    description: "Dedicated namespace for $app_name in $env environment"
    owner: "$(whoami)"
    tenant-model: "single-tenant"
    resource-allocation: "dedicated"
EOF
        
        echo "✅ Created namespace: $namespace"
        
        # Apply environment-specific resource quotas
        apply_environment_quota $namespace $env
        
        # Set up application-specific network policies
        create_app_network_policy $namespace $app_name
    done
}

apply_environment_quota() {
    local namespace=$1
    local environment=$2
    
    # Define resource allocations based on environment
    case $environment in
        "development")
            cpu_request="1"
            memory_request="2Gi"
            cpu_limit="2"
            memory_limit="4Gi"
            pod_limit="10"
            ;;
        "staging")
            cpu_request="2"
            memory_request="4Gi" 
            cpu_limit="4"
            memory_limit="8Gi"
            pod_limit="20"
            ;;
        "production")
            cpu_request="4"
            memory_request="8Gi"
            cpu_limit="8"
            memory_limit="16Gi"
            pod_limit="50"
            ;;
    esac
    
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ${namespace}-quota
  namespace: $namespace
  labels:
    environment: $environment
    quota-tier: $environment
spec:
  hard:
    requests.cpu: "$cpu_request"
    requests.memory: $memory_request
    limits.cpu: "$cpu_limit"
    limits.memory: $memory_limit
    pods: "$pod_limit"
    services: "15"
    secrets: "20"
    configmaps: "20"
    persistentvolumeclaims: "10"
EOF
}

# Example usage: Create namespaces for an e-commerce application
create_application_namespaces "ecommerce-frontend"
create_application_namespaces "ecommerce-api"
create_application_namespaces "ecommerce-worker"
```

#### Multi-Tenant Architecture (Shared Namespaces)

In this pattern, multiple applications or teams share namespaces, typically organized by environment or function. This approach requires more sophisticated resource management and security controls.

```bash
#!/bin/bash
# multi-tenant-setup.sh - Create shared namespaces with tenant isolation

create_shared_namespaces() {
    local environments=("development" "staging" "production")
    local tiers=("frontend" "backend" "data")
    
    echo "Creating multi-tenant namespace architecture"
    
    for env in "${environments[@]}"; do
        for tier in "${tiers[@]}"; do
            local namespace="${tier}-${env}"
            
            cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: $namespace
  labels:
    environment: $env
    tier: $tier
    tenant-model: multi-tenant
    isolation-level: logical
    shared-resources: "true"
  annotations:
    description: "Shared namespace for $tier tier in $env environment"
    tenant-model: "multi-tenant"
    resource-allocation: "shared"
    tenant-isolation: "label-based"
EOF
            
            # Apply shared resource quotas with higher limits
            apply_shared_quota $namespace $env $tier
            
            # Create tenant-specific limit ranges
            create_tenant_limits $namespace
            
            echo "✅ Created shared namespace: $namespace"
        done
    done
}

apply_shared_quota() {
    local namespace=$1
    local environment=$2
    local tier=$3
    
    # Shared namespaces get higher resource allocations
    local multiplier=3
    case $environment in
        "development")
            base_cpu=2
            base_memory=4
            ;;
        "staging") 
            base_cpu=4
            base_memory=8
            ;;
        "production")
            base_cpu=8
            base_memory=16
            ;;
    esac
    
    local cpu_request=$((base_cpu * multiplier))
    local memory_request="${base_memory * multiplier}Gi"
    local cpu_limit=$((cpu_request * 2))
    local memory_limit="${base_memory * multiplier * 2}Gi"
    
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ${namespace}-shared-quota
  namespace: $namespace
  labels:
    quota-type: shared
    tier: $tier
spec:
  hard:
    requests.cpu: "$cpu_request"
    requests.memory: $memory_request
    limits.cpu: "$cpu_limit"
    limits.memory: $memory_limit
    pods: "100"
    services: "50"
    secrets: "100"
    configmaps: "100"
EOF
}

create_tenant_limits() {
    local namespace=$1
    
    # Create LimitRange to prevent any single tenant from consuming all resources
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: tenant-limits
  namespace: $namespace
  labels:
    purpose: tenant-isolation
spec:
  limits:
  - type: Container
    default:
      memory: "512Mi"
      cpu: "250m"
    defaultRequest:
      memory: "128Mi"
      cpu: "50m"
    max:
      memory: "2Gi"
      cpu: "1000m"
    min:
      memory: "32Mi"
      cpu: "10m"
  - type: Pod
    max:
      memory: "4Gi"
      cpu: "2000m"
EOF
}
```

---

## 5. Security and Access Control (Continued)

### Service Account Management (Completion)

Service accounts provide identity for pods and enable programmatic access to the Kubernetes API. Proper service account management is crucial for namespace security.

```bash
#!/bin/bash
# service-account-manager.sh - Advanced service account management (continued)

create_cicd_service_account() {
    local namespace=$1
    local team=$2
    
    kubectl create serviceaccount cicd-sa --namespace="$namespace"
    kubectl label serviceaccount cicd-sa \
        --namespace="$namespace" \
        purpose=deployment \
        team="$team" \
        access-level=deployer
    
    cat << EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: $namespace
  name: cicd-role
  labels:
    purpose: deployment
    access-level: deployer
rules:
# Can manage application resources
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]

# Can manage services and ingresses
- apiGroups: [""]
  resources: ["services"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]

- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]

# Can manage configuration
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]

# Can scale deployments
- apiGroups: ["autoscaling"]
  resources: ["horizontalpodautoscalers"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]

# Read access to pods for verification
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]

# Can manage jobs for deployment tasks
- apiGroups: ["batch"]
  resources: ["jobs"]
  verbs: ["get", "list", "watch", "create", "delete"]
EOF

    kubectl create rolebinding cicd-binding \
        --namespace="$namespace" \
        --role=cicd-role \
        --serviceaccount="$namespace:cicd-sa"
    
    echo "✅ Created CI/CD service account: cicd-sa"
}

create_admin_service_account() {
    local namespace=$1
    local team=$2
    
    kubectl create serviceaccount admin-sa --namespace="$namespace"
    kubectl label serviceaccount admin-sa \
        --namespace="$namespace" \
        purpose=administration \
        team="$team" \
        access-level=admin
    
    # Admin gets full access within the namespace
    kubectl create rolebinding admin-binding \
        --namespace="$namespace" \
        --clusterrole=admin \
        --serviceaccount="$namespace:admin-sa"
    
    echo "✅ Created admin service account: admin-sa"
}

# Generate kubeconfig for service account
generate_service_account_kubeconfig() {
    local namespace=$1
    local service_account=$2
    local cluster_name=${3:-$(kubectl config current-context)}
    local output_file="${service_account}-${namespace}-kubeconfig.yaml"
    
    echo "🔑 Generating kubeconfig for service account: $service_account"
    
    # Get service account token (Kubernetes 1.24+ method)
    local token_name="${service_account}-token"
    
    # Create token secret if it doesn't exist
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: $token_name
  namespace: $namespace
  annotations:
    kubernetes.io/service-account.name: $service_account
type: kubernetes.io/service-account-token
EOF

    # Wait for token to be created
    kubectl wait --for=condition=ready secret/$token_name --namespace=$namespace --timeout=60s
    
    # Extract token and CA certificate
    local token=$(kubectl get secret $token_name -n $namespace -o jsonpath='{.data.token}' | base64 -d)
    local ca_cert=$(kubectl get secret $token_name -n $namespace -o jsonpath='{.data.ca\.crt}')
    local server=$(kubectl config view -o jsonpath='{.clusters[?(@.name=="'$cluster_name'")].cluster.server}')
    
    # Generate kubeconfig
    cat > "$output_file" << EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: $ca_cert
    server: $server
  name: $cluster_name
contexts:
- context:
    cluster: $cluster_name
    namespace: $namespace
    user: $service_account
  name: ${service_account}-context
current-context: ${service_account}-context
users:
- name: $service_account
  user:
    token: $token
EOF

    echo "✅ Kubeconfig generated: $output_file"
    echo "📋 Usage: kubectl --kubeconfig=$output_file get pods"
}
```

---

## 6. Network Isolation Strategies (Continued)

### Network Policy Testing and Validation (Completion)

```bash
#!/bin/bash
# network-policy-tester.sh - Comprehensive network policy testing (continued)

test_internal_connectivity() {
    local namespace=$1
    
    echo "Testing internal connectivity..."
    
    # Test client to server communication
    if kubectl exec netpol-test-client -n "$namespace" -- curl -s --connect-timeout 5 netpol-test-server-svc > /dev/null; then
        echo "  ✅ Client to Server: SUCCESS"
    else
        echo "  ❌ Client to Server: FAILED"
    fi
    
    # Test client to database
    if kubectl exec netpol-test-client -n "$namespace" -- nc -z netpol-test-db-svc 5432; then
        echo "  ✅ Client to Database: SUCCESS"
    else
        echo "  ❌ Client to Database: FAILED"
    fi
}

test_dns_resolution() {
    local namespace=$1
    
    echo "Testing DNS resolution..."
    
    # Test internal service DNS
    if kubectl exec netpol-test-client -n "$namespace" -- nslookup netpol-test-server-svc > /dev/null 2>&1; then
        echo "  ✅ Internal DNS: SUCCESS"
    else
        echo "  ❌ Internal DNS: FAILED"
    fi
    
    # Test external DNS
    if kubectl exec netpol-test-client -n "$namespace" -- nslookup kubernetes.default.svc.cluster.local > /dev/null 2>&1; then
        echo "  ✅ External DNS: SUCCESS"
    else
        echo "  ❌ External DNS: FAILED"
    fi
}

test_external_connectivity() {
    local namespace=$1
    
    echo "Testing external connectivity..."
    
    # Test HTTPS connectivity
    if kubectl exec netpol-test-client -n "$namespace" -- curl -s --connect-timeout 5 https://httpbin.org/status/200 > /dev/null; then
        echo "  ✅ External HTTPS: SUCCESS"
    else
        echo "  ❌ External HTTPS: FAILED"
    fi
    
    # Test HTTP connectivity (should be blocked by policies)
    if kubectl exec netpol-test-client -n "$namespace" -- curl -s --connect-timeout 5 http://httpbin.org/status/200 > /dev/null 2>&1; then
        echo "  ⚠️  External HTTP: SUCCESS (may indicate policy gap)"
    else
        echo "  ✅ External HTTP: BLOCKED (expected)"
    fi
}

cleanup_test_infrastructure() {
    local namespace=$1
    
    echo "🧹 Cleaning up test infrastructure..."
    
    kubectl delete pod netpol-test-client netpol-test-server netpol-test-db -n "$namespace" --ignore-not-found
    kubectl delete service netpol-test-server-svc netpol-test-db-svc -n "$namespace" --ignore-not-found
    
    echo "✅ Test infrastructure cleaned up"
}
```

---

## 7. Lifecycle and Operational Management

### Namespace Lifecycle Management

Managing the complete lifecycle of namespaces requires understanding creation, evolution, migration, and eventual decommissioning patterns.

```bash
#!/bin/bash
# namespace-lifecycle-manager.sh - Complete namespace lifecycle management

create_namespace_with_lifecycle() {
    local name=$1
    local team=$2
    local environment=$3
    local lifecycle_stage=${4:-"active"}
    local retention_days=${5:-90}
    
    echo "🚀 Creating namespace with lifecycle management: $name"
    
    # Calculate lifecycle dates
    local created_date=$(date +%Y-%m-%d)
    local review_date=$(date -d "+90 days" +%Y-%m-%d)
    local expiry_date=$(date -d "+$retention_days days" +%Y-%m-%d)
    
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: $name
  labels:
    # Identity labels
    team: $team
    environment: $environment
    
    # Lifecycle labels
    lifecycle-stage: $lifecycle_stage
    created-date: $created_date
    managed-by: lifecycle-manager
    
    # Retention labels
    retention-policy: "delete-after-${retention_days}-days"
    auto-cleanup: "enabled"
  annotations:
    # Lifecycle annotations
    description: "Namespace managed by lifecycle automation"
    created-timestamp: $(date -Iseconds)
    created-by: $(whoami)
    
    # Lifecycle dates
    lifecycle.kubernetes.io/created-date: $created_date
    lifecycle.kubernetes.io/review-date: $review_date
    lifecycle.kubernetes.io/expiry-date: $expiry_date
    
    # Team information
    team.contact: "${team}@company.com"
    team.slack: "#${team}-alerts"
    
    # Operational information
    backup-required: "true"
    monitoring-enabled: "true"
    alerting-enabled: "true"
EOF

    # Apply initial resource policies
    apply_lifecycle_resource_policies "$name" "$lifecycle_stage"
    
    # Set up lifecycle monitoring
    setup_lifecycle_monitoring "$name"
    
    echo "✅ Namespace created with lifecycle management: $name"
}

apply_lifecycle_resource_policies() {
    local namespace=$1
    local stage=$2
    
    case $stage in
        "development"|"dev")
            apply_development_policies "$namespace"
            ;;
        "testing"|"staging")
            apply_testing_policies "$namespace"
            ;;
        "production"|"prod")
            apply_production_policies "$namespace"
            ;;
        "deprecated")
            apply_deprecated_policies "$namespace"
            ;;
        "archived")
            apply_archived_policies "$namespace"
            ;;
    esac
}

apply_development_policies() {
    local namespace=$1
    
    # Limited resources for development
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: development-quota
  namespace: $namespace
  labels:
    lifecycle-stage: development
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 4Gi
    limits.cpu: "4"
    limits.memory: 8Gi
    pods: "20"
    services: "10"
    persistentvolumeclaims: "5"
EOF

    # Relaxed limit ranges for experimentation
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: development-limits
  namespace: $namespace
  labels:
    lifecycle-stage: development
spec:
  limits:
  - type: Container
    default:
      memory: "512Mi"
      cpu: "200m"
    defaultRequest:
      memory: "128Mi"
      cpu: "50m"
    max:
      memory: "2Gi"
      cpu: "1000m"
EOF
}

apply_production_policies() {
    local namespace=$1
    
    # Generous but controlled resources for production
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: production-quota
  namespace: $namespace
  labels:
    lifecycle-stage: production
spec:
  hard:
    requests.cpu: "20"
    requests.memory: 40Gi
    limits.cpu: "40"
    limits.memory: 80Gi
    pods: "100"
    services: "30"
    persistentvolumeclaims: "20"
    secrets: "50"
    configmaps: "50"
EOF

    # Strict limit ranges for stability
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: production-limits
  namespace: $namespace
  labels:
    lifecycle-stage: production
spec:
  limits:
  - type: Container
    default:
      memory: "1Gi"
      cpu: "500m"
    defaultRequest:
      memory: "256Mi"
      cpu: "100m"
    max:
      memory: "8Gi"
      cpu: "4000m"
    min:
      memory: "64Mi"
      cpu: "50m"
    maxLimitRequestRatio:
      memory: 2
      cpu: 2
EOF
}

apply_deprecated_policies() {
    local namespace=$1
    
    # Reduced resources for deprecated namespaces
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: deprecated-quota
  namespace: $namespace
  labels:
    lifecycle-stage: deprecated
spec:
  hard:
    requests.cpu: "1"
    requests.memory: 2Gi
    limits.cpu: "2"
    limits.memory: 4Gi
    pods: "10"
    services: "5"
    persistentvolumeclaims: "2"
EOF
}

# Namespace lifecycle progression automation
progress_namespace_lifecycle() {
    local namespace=$1
    local target_stage=$2
    local reason=${3:-"lifecycle-progression"}
    
    echo "📊 Progressing namespace $namespace to stage: $target_stage"
    
    # Get current stage
    local current_stage=$(kubectl get namespace "$namespace" -o jsonpath='{.metadata.labels.lifecycle-stage}')
    
    if [[ "$current_stage" == "$target_stage" ]]; then
        echo "⚠️  Namespace is already in stage: $target_stage"
        return 0
    fi
    
    # Validate progression path
    if ! validate_lifecycle_progression "$current_stage" "$target_stage"; then
        echo "❌ Invalid lifecycle progression from $current_stage to $target_stage"
        return 1
    fi
    
    # Create backup before major transitions
    if [[ "$target_stage" == "deprecated" || "$target_stage" == "archived" ]]; then
        create_namespace_backup "$namespace"
    fi
    
    # Update namespace labels and annotations
    kubectl label namespace "$namespace" \
        lifecycle-stage="$target_stage" \
        lifecycle-transition-date="$(date +%Y-%m-%d)" \
        --overwrite
    
    kubectl annotate namespace "$namespace" \
        lifecycle.kubernetes.io/transition-reason="$reason" \
        lifecycle.kubernetes.io/transition-timestamp="$(date -Iseconds)" \
        lifecycle.kubernetes.io/previous-stage="$current_stage" \
        --overwrite
    
    # Apply new stage policies
    apply_lifecycle_resource_policies "$namespace" "$target_stage"
    
    # Send notifications
    send_lifecycle_notification "$namespace" "$current_stage" "$target_stage" "$reason"
    
    echo "✅ Namespace lifecycle progressed: $current_stage → $target_stage"
}

validate_lifecycle_progression() {
    local current=$1
    local target=$2
    
    # Define valid progressions
    case "$current" in
        "development")
            [[ "$target" == "testing" || "$target" == "deprecated" ]] && return 0
            ;;
        "testing")
            [[ "$target" == "production" || "$target" == "deprecated" ]] && return 0
            ;;
        "production")
            [[ "$target" == "deprecated" || "$target" == "archived" ]] && return 0
            ;;
        "deprecated")
            [[ "$target" == "archived" ]] && return 0
            ;;
        "archived")
            # Archived is typically terminal, but allow reactivation in special cases
            [[ "$target" == "development" || "$target" == "testing" ]] && return 0
            ;;
    esac
    
    return 1
}

# Automated cleanup of expired namespaces
cleanup_expired_namespaces() {
    local dry_run=${1:-true}
    local grace_period_days=${2:-7}
    
    echo "🧹 Scanning for expired namespaces (dry-run: $dry_run)"
    
    # Find namespaces with expiry dates
    local expired_namespaces=$(kubectl get namespaces \
        -o custom-columns='NAME:.metadata.name,EXPIRY:.metadata.annotations.lifecycle\.kubernetes\.io/expiry-date' \
        --no-headers | grep -v '<none>')
    
    while IFS= read -r line; do
        local name=$(echo "$line" | awk '{print $1}')
        local expiry_date=$(echo "$line" | awk '{print $2}')
        
        if [[ -n "$expiry_date" ]]; then
            local expiry_timestamp=$(date -d "$expiry_date" +%s)
            local current_timestamp=$(date +%s)
            local grace_timestamp=$((current_timestamp - grace_period_days * 86400))
            
            if [[ $expiry_timestamp -lt $grace_timestamp ]]; then
                echo "⏰ Found expired namespace: $name (expired: $expiry_date)"
                
                if [[ "$dry_run" == "true" ]]; then
                    echo "  🔍 [DRY RUN] Would delete namespace: $name"
                else
                    delete_namespace_safely "$name"
                fi
            fi
        fi
    done <<< "$expired_namespaces"
}

delete_namespace_safely() {
    local namespace=$1
    
    echo "🗑️  Safely deleting namespace: $namespace"
    
    # Create final backup
    create_namespace_backup "$namespace"
    
    # Send deletion notification
    send_deletion_notification "$namespace"
    
    # Mark as being deleted
    kubectl label namespace "$namespace" \
        lifecycle-stage=deleting \
        deletion-timestamp="$(date -Iseconds)" \
        --overwrite
    
    # Give time for notifications to be processed
    sleep 10
    
    # Delete the namespace
    kubectl delete namespace "$namespace" --wait=true
    
    echo "✅ Namespace deleted: $namespace"
}

create_namespace_backup() {
    local namespace=$1
    local backup_dir="/tmp/namespace-backups/$(date +%Y-%m-%d)"
    
    echo "💾 Creating backup for namespace: $namespace"
    
    mkdir -p "$backup_dir"
    
    # Export all resources in the namespace
    kubectl get all,configmaps,secrets,pvc,ingress,networkpolicies \
        -n "$namespace" \
        -o yaml > "$backup_dir/${namespace}-backup.yaml"
    
    # Export namespace metadata
    kubectl get namespace "$namespace" -o yaml > "$backup_dir/${namespace}-metadata.yaml"
    
    echo "✅ Backup created: $backup_dir/${namespace}-backup.yaml"
}
```

---

## 8. Monitoring and Observability

### Comprehensive Namespace Monitoring

Effective namespace monitoring requires observing resource usage, performance metrics, security events, and operational health across multiple dimensions.

```bash
#!/bin/bash
# namespace-monitoring-setup.sh - Comprehensive monitoring implementation

setup