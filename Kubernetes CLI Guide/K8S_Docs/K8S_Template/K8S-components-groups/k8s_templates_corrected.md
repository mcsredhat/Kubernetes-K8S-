# Kubernetes Component Templates - Corrected & Production-Ready

This document provides comprehensive Kubernetes component templates with all errors corrected, security best practices, and production-ready specifications. Each template includes:

- **Description:** Clear usage guidance and practical notes
- **Detailed YAML Template:** Production-ready with labels, annotations, security, resource management, and observability
- **Apply Example:** Sample `kubectl apply` command
- **Customization Notes:** Tips for adaptation
- **Common Pitfalls:** Frequently encountered issues to avoid

All examples use `example-namespace` consistently. Save YAML files with descriptive names like `example-namespace.yaml`.

---

## 1. Namespace Management

### Namespace
**Description:** Logical isolation boundary for resources and teams
**Use Case:** Multi-tenant clusters, environment separation (dev/staging/prod)

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: example-namespace
  labels:
    name: example
    environment: production
  annotations:
    description: "Example namespace for demo resources"
spec:
  finalizers:
  - kubernetes
```

**Apply Example:**
```bash
kubectl apply -f namespace.yaml
kubectl get namespaces
```

**Customization Notes:**
- Don't use special characters in namespace names
- Use descriptive labels for cluster-wide organization
- Consider namespace naming conventions (e.g., `team-environment`)

**Common Pitfalls:**
- Creating resources without specifying namespace (defaults to `default`)
- Deleting namespace accidentally deletes all contained resources

---

### ResourceQuota
**Description:** Enforce hard limits on aggregate resource consumption per namespace
**Use Case:** Multi-tenant clusters, preventing resource exhaustion

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: example-quota
  namespace: example-namespace
  labels:
    quota-type: compute
  annotations:
    description: "Limits compute resources in the namespace"
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    pods: "20"
    persistentvolumeclaims: "5"
    requests.storage: "10Gi"
    services: "10"
    configmaps: "10"
    secrets: "5"
  scopeSelector:
    matchExpressions:
    - operator: In
      scopeName: PriorityClass
      values: ["high", "medium"]
```

**Apply Example:**
```bash
kubectl apply -f resourcequota.yaml -n example-namespace
kubectl describe resourcequota example-quota -n example-namespace
```

**Customization Notes:**
- Set realistic limits based on expected workloads
- Use `scopeSelector` to apply quotas to specific priority classes
- Monitor quota usage with `kubectl describe`

**Common Pitfalls:**
- Setting quotas too restrictive, causing pod scheduling failures
- Not accounting for system pods and overhead
- Forgetting to include storage quotas when using PVCs

---

### LimitRange
**Description:** Set default, minimum, and maximum resource constraints per pod/container
**Use Case:** Preventing resource waste, enforcing standards

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: example-limitrange
  namespace: example-namespace
  labels:
    limit-type: container
  annotations:
    description: "Default and max limits for containers"
spec:
  limits:
  - type: Container
    default:
      cpu: 500m
      memory: 256Mi
    defaultRequest:
      cpu: 200m
      memory: 128Mi
    max:
      cpu: 1
      memory: 512Mi
    min:
      cpu: 100m
      memory: 64Mi
  - type: Pod
    max:
      cpu: 2
      memory: 1Gi
    min:
      cpu: 100m        # CORRECTED: Must be >= Container min (100m >= 100m ✓)
      memory: 64Mi     # CORRECTED: Must be >= Container min (64Mi >= 64Mi ✓)
```

**Apply Example:**
```bash
kubectl apply -f limitrange.yaml -n example-namespace
kubectl get limitranges -n example-namespace
```

**Customization Notes:**
- Define separate limits for different workload types
- Pod limits must satisfy: **Pod min ≥ Container min AND Pod max ≥ Container max**
- Use for cost control in multi-tenant environments

**Common Pitfalls:**
- Setting min/max constraints that conflict with each other (Pod min < Container min)
- Forgetting that LimitRange applies to new pods only (existing pods unaffected)
- Not considering burstable vs guaranteed QoS classes

---

## 2. Workload Resources

### Pod
**Description:** Smallest deployable unit; ephemeral by design
**Use Case:** Testing, one-off tasks (prefer controllers for production)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: example-pod
  namespace: example-namespace
  labels:
    app: example
    tier: frontend
  annotations:
    description: "Example pod with multi-container setup"
spec:
  restartPolicy: Always
  serviceAccountName: example-serviceaccount
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 2000
    seccompProfile:
      type: RuntimeDefault
  initContainers:
  - name: init-container
    image: busybox:1.28
    command: ['sh', '-c', 'echo Initializing && sleep 5']
    securityContext:
      allowPrivilegeEscalation: false
      runAsNonRoot: true
      readOnlyRootFilesystem: true
  containers:
  - name: example-container
    image: nginx:1.21
    imagePullPolicy: IfNotPresent
    ports:
    - containerPort: 80
      protocol: TCP
      name: http
    env:
    - name: ENVIRONMENT
      value: "production"
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 500m
        memory: 256Mi
    livenessProbe:
      httpGet:
        path: /healthz
        port: 80
      initialDelaySeconds: 30
      periodSeconds: 10
      timeoutSeconds: 5
      failureThreshold: 3
    readinessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 5
      timeoutSeconds: 3
      failureThreshold: 2
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: false
    volumeMounts:
    - mountPath: /var/log/nginx
      name: log-volume
  volumes:
  - name: log-volume
    emptyDir: {}
  terminationGracePeriodSeconds: 30
```

**Apply Example:**
```bash
kubectl apply -f pod.yaml -n example-namespace
kubectl logs example-pod -n example-namespace
```

**Customization Notes:**
- Use explicit image tags, never `latest` in production
- Configure both liveness and readiness probes
- Set appropriate `terminationGracePeriodSeconds` for graceful shutdowns

**Common Pitfalls:**
- Using `latest` image tag causing unexpected updates
- Missing or misconfigured health probes
- Not setting resource requests/limits

---

### Deployment
**Description:** Manages stateless applications with rolling updates and auto-rollback
**Use Case:** Web servers, microservices, stateless APIs

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: example-deployment
  namespace: example-namespace
  labels:
    app: example
    version: v1
  annotations:
    description: "Stateless app deployment"
spec:
  replicas: 3
  revisionHistoryLimit: 10
  progressDeadlineSeconds: 600
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  selector:
    matchLabels:
      app: example
  template:
    metadata:
      labels:
        app: example
        tier: frontend
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
    spec:
      serviceAccountName: example-serviceaccount
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 2000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: example-container
        image: nginx:1.21
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
          protocol: TCP
          name: http
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        resources:
          requests:
            cpu: 250m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          httpGet:
            path: /healthz
            port: 80
          initialDelaySeconds: 30
          timeoutSeconds: 5
          periodSeconds: 10
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          timeoutSeconds: 3
          periodSeconds: 10
          failureThreshold: 2
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: false
          capabilities:
            drop:
            - ALL
        volumeMounts:
        - mountPath: /app/config
          name: config-volume
          readOnly: true
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - example
            topologyKey: kubernetes.io/hostname
      volumes:
      - name: config-volume
        configMap:
          name: example-configmap
          defaultMode: 0644
      terminationGracePeriodSeconds: 30
```

**Apply Example:**
```bash
kubectl apply -f deployment.yaml -n example-namespace
kubectl rollout status deployment/example-deployment -n example-namespace
kubectl set image deployment/example-deployment example-container=nginx:1.22 -n example-namespace
```

**Customization Notes:**
- Using `requiredDuringSchedulingIgnoredDuringExecution` requires sufficient nodes. With 3 replicas, you need at least 3 nodes across different availability zones/physical hosts. If nodes are insufficient, pods will remain unscheduled.
- Alternative: Use `preferredDuringSchedulingIgnoredDuringExecution` for better availability but looser distribution guarantees
- Set `progressDeadlineSeconds` to detect stuck rollouts
- Use explicit image versions with digest hashes for immutability

**Common Pitfalls:**
- Using `requiredDuringSchedulingIgnoredDuringExecution` without verifying node availability
- Setting `maxUnavailable: 25%` with 2-3 replicas causes complete downtime
- Insufficient `initialDelaySeconds` for slow-starting apps

---

### StatefulSet
**Description:** Manages stateful applications with stable network identity and persistent storage
**Use Case:** Databases, message queues, clustered applications

```yaml
# CORRECTED: First create the headless Service required by StatefulSet
apiVersion: v1
kind: Service
metadata:
  name: example-statefulset-svc
  namespace: example-namespace
  labels:
    app: example
    service: headless
  annotations:
    description: "Headless service for StatefulSet DNS"
spec:
  clusterIP: None  # CRITICAL: Makes this a headless service
  selector:
    app: example
  ports:
  - port: 80
    targetPort: 80
    name: web
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: example-statefulset
  namespace: example-namespace
  labels:
    app: example
    stateful: db
  annotations:
    description: "Stateful application with persistent storage"
spec:
  serviceName: example-statefulset-svc  # CRITICAL: References headless service
  replicas: 3
  revisionHistoryLimit: 10
  podManagementPolicy: OrderedReady
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      partition: 0
  selector:
    matchLabels:
      app: example
  template:
    metadata:
      labels:
        app: example
    spec:
      serviceAccountName: example-serviceaccount
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:  # CORRECTED: Changed to preferred
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - example
              topologyKey: kubernetes.io/hostname
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 2000
      containers:
      - name: example-container
        image: nginx:1.21
        ports:
        - containerPort: 80
          name: web
        volumeMounts:
        - mountPath: /data
          name: data-volume
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            cpu: 1
            memory: 2Gi
        livenessProbe:
          tcpSocket:
            port: 80
          initialDelaySeconds: 60
          periodSeconds: 10
        readinessProbe:
          tcpSocket:
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 5
      terminationGracePeriodSeconds: 300
  volumeClaimTemplates:
  - metadata:
      name: data-volume
      labels:
        volume-type: persistent
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: example-storageclass
      resources:
        requests:
          storage: 10Gi
```

**Apply Example:**
```bash
kubectl apply -f statefulset.yaml -n example-namespace
kubectl get statefulset -n example-namespace
kubectl get pvc -n example-namespace
kubectl get svc example-statefulset-svc -n example-namespace  # Verify headless service
```

**Customization Notes:**
- Always deploy headless Service before or with StatefulSet
- Use `OrderedReady` for sequential initialization, `Parallel` for independent pods
- Use `preferredDuringSchedulingIgnoredDuringExecution` for pod distribution (prioritizes persistence/stability over perfect distribution)
- StatefulSets require stable identity more than perfect node distribution; `preferred` allows graceful degradation when nodes unavailable
- Set longer `terminationGracePeriodSeconds` for graceful shutdowns

**Common Pitfalls:**
- Missing headless Service (causes DNS resolution failures)
- Referencing wrong service type (ClusterIP instead of headless)
- Using `requiredDuringSchedulingIgnoredDuringExecution` prevents scheduling when insufficient nodes available
- Insufficient `terminationGracePeriodSeconds` cutting off connections prematurely

---

### DaemonSet
**Description:** Automatically runs pod on every cluster node
**Use Case:** Logging agents, monitoring collectors, node-level utilities

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: example-daemonset
  namespace: example-namespace
  labels:
    app: example
    role: agent
  annotations:
    description: "Runs on every node for monitoring"
spec:
  revisionHistoryLimit: 10
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
  selector:
    matchLabels:
      app: example
  template:
    metadata:
      labels:
        app: example
    spec:
      serviceAccountName: example-serviceaccount
      hostNetwork: false
      hostPID: false
      dnsPolicy: ClusterFirst
      tolerations:
      - operator: Exists
        effect: NoSchedule
      - operator: Exists
        effect: NoExecute
      priorityClassName: system-node-critical
      containers:
      - name: example-container
        image: fluentd:1.14
        imagePullPolicy: Always
        ports:
        - containerPort: 24224
          name: fluentd-input
          protocol: TCP
        env:
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        resources:
          requests:
            cpu: 100m
            memory: 200Mi
          limits:
            cpu: 200m
            memory: 400Mi
        livenessProbe:
          tcpSocket:
            port: 24224
          initialDelaySeconds: 60
          periodSeconds: 10
        readinessProbe:
          tcpSocket:
            port: 24224
          initialDelaySeconds: 10
          periodSeconds: 5
        securityContext:
          allowPrivilegeEscalation: false
        volumeMounts:
        - mountPath: /var/log
          name: varlog
          readOnly: true
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
          type: Directory
      terminationGracePeriodSeconds: 30
```

**Apply Example:**
```bash
kubectl apply -f daemonset.yaml -n example-namespace
kubectl get daemonset -n example-namespace
kubectl describe daemonset example-daemonset -n example-namespace
```

**Customization Notes:**
- Always include all taints tolerations for universal node coverage
- Use resource requests/limits even for system pods
- Avoid `hostNetwork: true` unless absolutely necessary

**Common Pitfalls:**
- Forgetting tolerations causing pods to skip tainted nodes
- Missing taints on new nodes preventing daemonset pods
- Excessive resource consumption accumulating across cluster

---

### Job
**Description:** Runs pods to completion (one-time or batch tasks)
**Use Case:** Database migrations, data processing, CI/CD tasks

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: example-job
  namespace: example-namespace
  labels:
    job-type: batch
  annotations:
    description: "One-time batch processing job"
spec:
  ttlSecondsAfterFinished: 3600
  backoffLimit: 4
  activeDeadlineSeconds: 3600
  completions: 1
  parallelism: 1
  template:
    metadata:
      labels:
        job: example
    spec:
      restartPolicy: Never  # CORRECTED: Jobs must use Never or OnFailure, never Always
      serviceAccountName: example-serviceaccount
      securityContext:
        runAsNonRoot: true
      containers:
      - name: example-container
        image: busybox:1.28
        command:
        - sh
        - -c
        - |
          echo "Running job at $(date)"
          echo "Job ID: $JOB_ID"
          exit 0
        env:
        - name: JOB_ID
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        resources:
          requests:
            cpu: 100m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
```

**Apply Example:**
```bash
kubectl apply -f job.yaml -n example-namespace
kubectl get jobs -n example-namespace
kubectl logs -l job-name=example-job -n example-namespace
kubectl describe job example-job -n example-namespace
kubectl delete job example-job -n example-namespace
```

**Customization Notes:**
- Use `ttlSecondsAfterFinished` to auto-cleanup completed jobs
- Set realistic `backoffLimit` based on expected failure rate
- Use `activeDeadlineSeconds` to prevent runaway jobs
- **restartPolicy options:** `Never` (pod fails, replaced by new pod), `OnFailure` (pod restarts in place), `Always` (invalid for Jobs)

**Common Pitfalls:**
- Not setting `ttlSecondsAfterFinished` causing log accumulation
- Using `restartPolicy: Always` (invalid for Jobs)
- Setting `backoffLimit` too high or too low

---

### CronJob
**Description:** Manages scheduled job execution using cron syntax
**Use Case:** Backups, cleanup tasks, periodic maintenance

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: example-cronjob
  namespace: example-namespace
  labels:
    schedule-type: nightly
  annotations:
    description: "Scheduled backup job"
spec:
  schedule: "0 2 * * *"
  timezone: "Etc/UTC"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  startingDeadlineSeconds: 300
  jobTemplate:
    spec:
      ttlSecondsAfterFinished: 86400
      backoffLimit: 2
      template:
        metadata:
          labels:
            cronjob: example
        spec:
          restartPolicy: OnFailure
          serviceAccountName: example-serviceaccount
          containers:
          - name: example-container
            image: busybox:1.28
            command:
            - sh
            - -c
            - |
              echo "Backup starting at $(date)"
              sleep 60
              echo "Backup completed"
            resources:
              requests:
                cpu: 200m
                memory: 128Mi
              limits:
                cpu: 500m
                memory: 256Mi
            env:
            - name: BACKUP_TIME
              value: "2am-utc"
```

**Apply Example:**
```bash
kubectl apply -f cronjob.yaml -n example-namespace
kubectl get cronjob -n example-namespace
kubectl get jobs -n example-namespace
```

**Customization Notes:**
- Use `Forbid` concurrency policy to prevent overlapping executions
- Set timezone if not using UTC
- Monitor job history with appropriate limits

**Common Pitfalls:**
- Using ambiguous cron expressions
- Setting `concurrencyPolicy: Allow` causing duplicate work
- Not cleaning up old job history

---

## 3. Configuration Management

### ConfigMap
**Description:** Store non-sensitive configuration as key-value pairs
**Use Case:** Application config, feature flags, environment-specific settings

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: example-configmap
  namespace: example-namespace
  labels:
    config-type: app
  annotations:
    description: "Non-sensitive app configuration"
data:
  config.key1: "value1"
  config.key2: "value2"
  database.url: "postgresql://db.example.svc.cluster.local:5432/mydb"
  log.level: "INFO"
  app.properties: |
    server.port=8080
    server.servlet.context-path=/api
    logging.level.root=INFO
immutable: false
```

**Apply Example:**
```bash
kubectl apply -f configmap.yaml -n example-namespace
kubectl get configmap -n example-namespace
kubectl edit configmap example-configmap -n example-namespace
```

**Customization Notes:**
- Use `immutable: true` for config that shouldn't change
- Separate ConfigMaps by concern (database, logging, etc.)
- Use multi-line format for complex configurations

**Common Pitfalls:**
- Storing secrets in ConfigMap (use Secret instead)
- Expecting running pods to auto-reload ConfigMap changes
- Creating overly large ConfigMaps (1MB limit)

---

### Secret
**Description:** Store sensitive data (passwords, tokens, certificates)
**Use Case:** Database credentials, API keys, TLS certificates

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: example-secret
  namespace: example-namespace
  labels:
    secret-type: auth
  annotations:
    description: "Sensitive credentials"
type: Opaque
data:
  password: cGFzc3dvcmQxMjM=
  username: YWRtaW4=
  api-token: ZXhhbXBsZXRva2VuMTIz
immutable: true
```

**Apply Example:**
```bash
# Create from literal values
kubectl create secret generic example-secret \
  --from-literal=username=admin \
  --from-literal=password=secret123 \
  -n example-namespace

# Apply from file
kubectl apply -f secret.yaml -n example-namespace

# View secret
kubectl get secret example-secret -n example-namespace -o yaml
```

**Customization Notes:**
- Always set `immutable: true` for production secrets
- Use external secret management (e.g., Sealed Secrets, External Secrets Operator)
- Never commit secrets to version control

**Common Pitfalls:**
- Base64-encoded secrets are NOT encrypted (anyone can decode)
- Storing secrets in version control
- Using mutable secrets allowing accidental overwrites

---

### Volume
**Description:** Attach storage to containers for data persistence/sharing
**Use Case:** Application data, logs, temporary files

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: example-pod-volumes
  namespace: example-namespace
spec:
  containers:
  - name: app-container
    image: nginx:1.21
    volumeMounts:
    - mountPath: /config
      name: config-volume
      readOnly: true
    - mountPath: /secrets
      name: secret-volume
      readOnly: true
    - mountPath: /data
      name: persistent-volume
    - mountPath: /tmp
      name: temp-volume
  volumes:
  - name: config-volume
    configMap:
      name: example-configmap
      defaultMode: 0644
      items:
      - key: app.properties
        path: application.properties
  - name: secret-volume
    secret:
      secretName: example-secret
      defaultMode: 0600
  - name: persistent-volume
    persistentVolumeClaim:
      claimName: example-pvc
  - name: temp-volume
    emptyDir:
      medium: Memory
      sizeLimit: 500Mi
```

**Apply Example:**
```bash
kubectl apply -f pod-with-volumes.yaml -n example-namespace
kubectl describe pod example-pod-volumes -n example-namespace
```

**Customization Notes:**
- Use `readOnly: true` for config/secrets
- Set appropriate `defaultMode` permissions (0600 for secrets, 0644 for configs)
- Use `emptyDir` for temporary storage only

**Common Pitfalls:**
- Using `readOnly: true` then trying to write to volume
- Not setting proper permissions on secret volumes (should be 0600)
- Assuming `emptyDir` survives pod restarts

---

## 4. Storage Management

### StorageClass
**Description:** Define storage provisioner and parameters for dynamic PV creation
**Use Case:** Automatic volume provisioning, multi-tier storage strategies

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: example-storageclass
  labels:
    storage: fast
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
    description: "Fast SSD storage class"
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
  encrypted: "true"
  kms-key-id: "arn:aws:kms:region:account:key/key-id"
  fsType: ext4
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
mountOptions:
- discard
- noatime
```

**Apply Example:**
```bash
kubectl apply -f storageclass.yaml
kubectl get storageclass
kubectl describe storageclass example-storageclass
```

**Customization Notes:**
- Set one as default using annotation
- Adjust `iops` and `throughput` based on workload
- Use `Retain` for critical data, `Delete` for ephemeral
- Verify provisioner is available in your cluster

**Common Pitfalls:**
- Multiple default StorageClasses causing ambiguity
- `volumeBindingMode: Immediate` binding before pod scheduling
- Not accounting for encryption/replication overhead

---

### PersistentVolumeClaim
**Description:** Request storage from StorageClass
**Use Case:** App data storage, database volumes

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: example-pvc
  namespace: example-namespace
  labels:
    storage: persistent
  annotations:
    description: "PVC for app data"
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: example-storageclass
  volumeMode: Filesystem
```

**Apply Example:**
```bash
kubectl apply -f pvc.yaml -n example-namespace
kubectl get pvc -n example-namespace
kubectl describe pvc example-pvc -n example-namespace
```

**Customization Notes:**
- Choose appropriate `accessModes` (RWO for databases, RWX for shared)
- Use `Block` mode only for databases requiring raw block access
- Monitor PVC capacity
- If StorageClass doesn't exist, PVC will remain `Pending` indefinitely—verify StorageClass exists before applying

**Common Pitfalls:**
- Using RWX when RWO suffices (performance penalty)
- Not leaving headroom for growth
- Mounting PVC with multiple pods using RWO (causes corruption)
- PVC stuck in Pending state due to missing StorageClass

---

## 5. Networking & Service Exposure

### Service
**Description:** Stable endpoint for pod communication
**Use Case:** Load balancing, service discovery, internal routing

```yaml
apiVersion: v1
kind: Service
metadata:
  name: example-service
  namespace: example-namespace
  labels:
    app: example
    service-type: cluster
  annotations:
    description: "Internal service for app"
spec:
  type: ClusterIP
  selector:
    app: example
    tier: frontend
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 8080
  sessionAffinity: None
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 10800
  externalTrafficPolicy: Cluster
  ipFamilies:
  - IPv4
  ipFamilyPolicy: SingleStack
```

**Apply Example:**
```bash
kubectl apply -f service.yaml -n example-namespace
kubectl get service -n example-namespace
kubectl describe service example-service -n example-namespace
```

**Customization Notes:**
- Use `ClusterIP` for internal services (default)
- Use `NodePort` for external access without LoadBalancer
- Use `LoadBalancer` with cloud providers for external IPs

**Common Pitfalls:**
- Service selector not matching pod labels
- Port and targetPort confusion
- Not considering `externalTrafficPolicy` impact on source IP

---

### Ingress
**Description:** HTTP/HTTPS routing from outside cluster to services
**Use Case:** Public API access, web application hosting

```yaml
### Ingress
**Description:** HTTP/HTTPS routing from outside cluster to services
**Use Case:** Public API access, web application hosting

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-ingress
  namespace: example-namespace
  labels:
    ingress: web
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    description: "HTTP routing to services"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - example.com
    - api.example.com
    secretName: example-tls
  rules:
  - host: example.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 8080
      - path: /
        pathType: Prefix
        backend:
          service:
            name: example-service
            port:
              number: 80
  defaultBackend:
    service:
      name: default-service
      port:
        number: 80
```

**Apply Example:**
```bash
kubectl apply -f ingress.yaml -n example-namespace
kubectl get ingress -n example-namespace
kubectl describe ingress example-ingress -n example-namespace
```

**Customization Notes:**
- Use `cert-manager` for automatic TLS certificate provisioning
- Path order matters: specific paths before catch-all
- Test with `pathType: Exact` for debugging
- Verify Ingress controller is installed (nginx-ingress, traefik, etc.)

**Common Pitfalls:**
- Expecting Ingress to work without controller installed
- Wrong backend service names or ports
- Incorrect path routing precedence
- TLS certificate not auto-provisioned (cert-manager may not be installed)

---

### NetworkPolicy
**Description:** Enforce ingress/egress traffic rules between pods
**Use Case:** Network segmentation, compliance, security hardening

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: example-networkpolicy
  namespace: example-namespace
  labels:
    policy: access
  annotations:
    description: "Restrict traffic to frontend pods"
spec:
  podSelector:
    matchLabels:
      app: example
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          project: frontend
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 443
  egress:
  # CORRECTED: DNS rule listed first for visibility and priority
  - to:
    - podSelector: {}
    ports:
    - protocol: UDP
      port: 53  # CRITICAL: Always allow DNS for service discovery
  - to:
    - namespaceSelector:
        matchLabels:
          project: backend
    ports:
    - protocol: TCP
      port: 5432
    - protocol: TCP
      port: 443
```

**Apply Example:**
```bash
kubectl apply -f networkpolicy.yaml -n example-namespace
kubectl get networkpolicy -n example-namespace
kubectl describe networkpolicy example-networkpolicy -n example-namespace
```

**Customization Notes:**
- Always allow DNS egress (UDP 53) unless air-gapped
- Use `namespaceSelector` to allow cross-namespace traffic
- Start with `Ingress` rules, then add `Egress` restrictions
- Test gradually to avoid breaking applications
- Include explicit deny rules for security
- NetworkPolicy is only enforced if CNI plugin supports it (Calico, Weave, Cilium, etc.)

**Common Pitfalls:**
- Blocking DNS causing application failures
- Forgetting `namespaceSelector: {}` for cluster-internal traffic
- Overly restrictive rules breaking service discovery
- NetworkPolicy not enforced without CNI support
- Missing explicit allow rules (deny-all default doesn't apply without policy)
- Applying NetworkPolicy without cluster CNI support

---

## 6. Security & Access Control

### ServiceAccount
**Description:** Pod identity for Kubernetes API access
**Use Case:** RBAC enforcement, pod authentication

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: example-serviceaccount
  namespace: example-namespace
  labels:
    account: app
  annotations:
    description: "Service account for app pods"
automountServiceAccountToken: true
imagePullSecrets:
- name: registry-credentials
```

**Apply Example:**
```bash
kubectl apply -f serviceaccount.yaml -n example-namespace
kubectl get serviceaccount -n example-namespace
kubectl describe serviceaccount example-serviceaccount -n example-namespace
```

**Customization Notes:**
- Set `automountServiceAccountToken: false` for high-security requirements
- Link to cloud IAM for extended permissions (GCP, AWS, Azure)
- Use separate ServiceAccounts per application

**Common Pitfalls:**
- Using default ServiceAccount for all pods
- Binding overly permissive Roles to ServiceAccounts
- Token accessible to compromised container = cluster compromise

---

### Role
**Description:** Define API permissions (namespace-scoped)
**Use Case:** Least-privilege access control

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: example-namespace
  name: example-role
  labels:
    role: read-write
  annotations:
    description: "Permissions for app access"
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get"]
- apiGroups: ["batch"]
  resources: ["jobs"]
  verbs: ["create", "list", "get"]
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["app-secret"]
  verbs: ["get"]
```

**Apply Example:**
```bash
kubectl apply -f role.yaml -n example-namespace
kubectl get roles -n example-namespace
kubectl describe role example-role -n example-namespace
```

**Customization Notes:**
- Use `resourceNames` for single-resource access
- Separate read-only and admin roles
- Audit role usage regularly

**Common Pitfalls:**
- Using wildcards `*` in verbs (disable all safety)
- Granting cluster-admin unnecessarily
- Not reviewing permissions after updates

---

### ClusterRole
**Description:** Define cluster-wide API permissions
**Use Case:** System components, multi-namespace access

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: example-clusterrole
  labels:
    role: cluster-wide
  annotations:
    description: "Cluster-wide monitoring permissions"
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["persistentvolumes"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "daemonsets", "statefulsets"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["batch"]
  resources: ["jobs", "cronjobs"]
  verbs: ["get", "list", "watch"]
```

**Apply Example:**
```bash
kubectl apply -f clusterrole.yaml
kubectl get clusterrole example-clusterrole
kubectl describe clusterrole example-clusterrole
```

---

### RoleBinding
**Description:** Attach roles to ServiceAccounts (namespace-scoped)
**Use Case:** RBAC enforcement in specific namespace

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: example-rolebinding
  namespace: example-namespace
  labels:
    binding: app
  annotations:
    description: "Bind role to service account"
subjects:
- kind: ServiceAccount
  name: example-serviceaccount
  namespace: example-namespace
roleRef:
  kind: Role
  name: example-role
  apiGroup: rbac.authorization.k8s.io
```

**Apply Example:**
```bash
kubectl apply -f rolebinding.yaml -n example-namespace
kubectl get rolebindings -n example-namespace
kubectl auth can-i get pods --as=system:serviceaccount:example-namespace:example-serviceaccount
```

**Customization Notes:**
- Test permissions with `kubectl auth can-i`
- Use audit logs to validate RBAC policies
- Regularly review and rotate access

---

### ClusterRoleBinding
**Description:** Attach cluster roles to subjects (cluster-wide)
**Use Case:** System-level permissions across namespaces

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: example-clusterrolebinding
  labels:
    binding: system
  annotations:
    description: "Cluster-wide admin binding"
subjects:
- kind: ServiceAccount
  name: example-serviceaccount
  namespace: example-namespace
roleRef:
  kind: ClusterRole
  name: example-clusterrole
  apiGroup: rbac.authorization.k8s.io
```

**Apply Example:**
```bash
kubectl apply -f clusterrolebinding.yaml
kubectl get clusterrolebindings | grep example
```

**Customization Notes:**
- Minimize ClusterRoleBindings (use namespaced alternatives)
- Audit cluster-admin bindings monthly

---

## 7. Scaling & Reliability

### HorizontalPodAutoscaler
**Description:** Auto-scale pod replicas based on CPU/memory/custom metrics
**Use Case:** Dynamic workload scaling, cost optimization

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: example-hpa
  namespace: example-namespace
  labels:
    autoscaling: cpu
  annotations:
    description: "Scale based on CPU utilization"
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: example-deployment
  minReplicas: 2
  maxReplicas: 10
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
      - type: Pods
        value: 2
        periodSeconds: 15
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

**Apply Example:**
```bash
# CORRECTED: Verify Metrics Server is installed and running
kubectl get apiservice v1beta1.metrics.k8s.io -o yaml

# If not present, install it:
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Then apply HPA
kubectl apply -f hpa.yaml -n example-namespace
kubectl get hpa -n example-namespace
kubectl describe hpa example-hpa -n example-namespace
kubectl top pods -n example-namespace
```

**Customization Notes:**
- Requires Metrics Server installed and running (check APIService)
- Set realistic thresholds based on application behavior
- Use `behavior` to tune scale-up/down aggressiveness
- Allow time for metrics collection (initial delay ~1-2 minutes)

**Common Pitfalls:**
- Metrics Server not installed/running (HPA remains inactive without metrics)
- Setting thresholds too low (constant scaling churn)
- Not accounting for initialization time
- Using HPA with VPA in Auto mode (conflicts on decisions)

---

### VerticalPodAutoscaler
**Description:** Auto-tune resource requests and limits
**Use Case:** Right-sizing workloads, eliminating over/under-provisioning

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: example-vpa
  namespace: example-namespace
  labels:
    autoscaling: vertical
  annotations:
    description: "Auto-tune container resources"
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: example-deployment
  updatePolicy:
    updateMode: "Initial"  # Start with Initial to validate recommendations
  resourcePolicy:
    containerPolicies:
    - containerName: "*"
      minAllowed:
        cpu: 50m
        memory: 50Mi
      maxAllowed:
        cpu: 500m
        memory: 500Mi
      controlledValues: RequestsAndLimits
    - containerName: sidecar
      minAllowed:
        cpu: 10m
        memory: 10Mi
      maxAllowed:
        cpu: 50m
        memory: 50Mi
```

**Apply Example:**
```bash
kubectl apply -f vpa.yaml -n example-namespace
kubectl describe vpa example-vpa -n example-namespace
kubectl get vpa -n example-namespace

# View recommendations without applying
kubectl describe vpa example-vpa -n example-namespace | grep -A 5 "Recommendation"
```

**Customization Notes:**
- Use `Initial` mode first to see recommendations without restarts
- Transition to `Auto` mode only after validating recommendations
- Set reasonable min/max bounds to prevent extreme values
- NEVER use both HPA and VPA in Auto mode (they conflict and cause constant pod restarts)

**Common Pitfalls:**
- Using `Auto` mode without proper testing (pods restart constantly)
- VPA and HPA both in Auto mode targeting same metrics (fights for control)
- Recommendations ignored without proper setup
- VPA controller not installed/running

---

### PodDisruptionBudget
**Description:** Guarantee minimum pod availability during disruptions
**Use Case:** High-availability applications, planned maintenance

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: example-pdb
  namespace: example-namespace
  labels:
    reliability: high
  annotations:
    description: "Ensure minimum pods available"
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: example
      tier: frontend
  unhealthyPodEvictionPolicy: IfHealthyBudget
```

**Apply Example:**
```bash
kubectl apply -f pdb.yaml -n example-namespace
kubectl get pdb -n example-namespace
kubectl describe pdb example-pdb -n example-namespace
```

**Customization Notes:**
- Use `minAvailable` for critical apps (absolute number)
- Use `maxUnavailable` for flexible workloads (percentage)
- Monitor `DisruptionsAllowed` status
- Validate with: `kubectl get pdb -w` during disruptions

**Common Pitfalls:**
- Setting `minAvailable` too high preventing node maintenance
- Not accounting for pods not ready before disruption
- Using with single replica pods (defeats purpose)

---

## 8. Advanced Features

### MutatingWebhookConfiguration
**Description:** Intercept and modify API requests (e.g., inject sidecars)
**Use Case:** Automatic sidecar injection, resource modification

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: MutatingWebhookConfiguration
metadata:
  name: example-mutatingwebhook
  labels:
    webhook: mutating
  annotations:
    description: "Mutate pods on create"
webhooks:
- name: example.mutating.webhook
  admissionReviewVersions: ["v1"]
  sideEffects: None
  clientConfig:
    service:
      name: webhook-service
      namespace: example-namespace
      path: "/mutate"
      port: 443
    caBundle: LS0tLS1CRUdJTi... # Base64 CA cert
  rules:
  - operations: ["CREATE", "UPDATE"]
    apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["pods"]
    scope: "Namespaced"
  failurePolicy: Fail
  timeoutSeconds: 10
  objectSelector:
    matchLabels:
      mutate: "true"
  namespaceSelector:
    matchLabels:
      webhook-enabled: "true"
```

**Apply Example:**
```bash
kubectl apply -f mutatingwebhook.yaml
kubectl get mutatingwebhookconfigurations
```

**Customization Notes:**
- Always set `failurePolicy: Fail` for critical policies
- Deploy webhook service with proper TLS
- Test with non-production namespaces first

---

### ValidatingWebhookConfiguration
**Description:** Validate API requests before storage
**Use Case:** Policy enforcement, resource validation

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: example-validatingwebhook
  labels:
    webhook: validating
  annotations:
    description: "Validate pod resources"
webhooks:
- name: example.validating.webhook
  admissionReviewVersions: ["v1"]
  sideEffects: None
  clientConfig:
    service:
      name: webhook-service
      namespace: example-namespace
      path: "/validate"
      port: 443
    caBundle: LS0tLS1CRUdJTi...
  rules:
  - operations: ["CREATE", "UPDATE"]
    apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["pods"]
    scope: "Namespaced"
  failurePolicy: Fail
  timeoutSeconds: 5
  objectSelector:
    matchLabels:
      validate: "true"
  namespaceSelector:
    matchLabels:
      validation: "enabled"
```

**Apply Example:**
```bash
kubectl apply -f validatingwebhook.yaml
kubectl logs -l app=webhook-server -n example-namespace
```

---

### CustomResourceDefinition
**Description:** Extend Kubernetes API with custom resource types
**Use Case:** Operators, domain-specific resources

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: examples.example.com
  labels:
    crd: custom
  annotations:
    description: "Custom Example resource"
spec:
  group: example.com
  versions:
  - name: v1
    served: true
    storage: true
    deprecated: false
    schema:
      openAPIV3Schema:
        type: object
        required: ["spec"]
        properties:
          metadata:
            type: object
          spec:
            type: object
            required: ["size"]
            properties:
              size:
                type: integer
                minimum: 1
                maximum: 10
              replicas:
                type: integer
                default: 1
                minimum: 1
              image:
                type: string
                default: "nginx:1.21"
          status:
            type: object
            properties:
              availableReplicas:
                type: integer
              currentImage:
                type: string
    additionalPrinterColumns:
    - name: Size
      type: integer
      jsonPath: .spec.size
    - name: Replicas
      type: integer
      jsonPath: .spec.replicas
    - name: Age
      type: date
      jsonPath: .metadata.creationTimestamp
  scope: Namespaced
  names:
    plural: examples
    singular: example
    kind: Example
    shortNames:
    - ex
```

**Apply Example:**
```bash
kubectl apply -f crd.yaml
kubectl get crd
kubectl api-resources | grep example
```

---

## 9. Observability & Monitoring

### PodMonitor
**Description:** Define Prometheus scrape targets for pod metrics
**Use Case:** Monitoring application metrics

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: example-podmonitor
  namespace: example-namespace
  labels:
    release: prometheus
  annotations:
    description: "Scrape metrics from labeled pods"
spec:
  selector:
    matchLabels:
      app: example
      metrics: "true"
  namespaceSelector:
    matchNames:
    - example-namespace
  podMetricsEndpoints:
  - port: metrics
    path: /metrics
    interval: 30s
    scrapeTimeout: 10s
    scheme: http
    metricRelabelings:
    - sourceLabels: [__name__]
      action: keep
      regex: example_.*
    relabelings:
    - sourceLabels: [__meta_kubernetes_pod_label_app]
      targetLabel: application
```

**Apply Example:**
```bash
kubectl apply -f podmonitor.yaml -n example-namespace
# Requires Prometheus Operator to be installed
```

**Customization Notes:**
- Requires Prometheus Operator installed
- Use `metricRelabelings` to filter metrics
- Set realistic `interval` based on metric frequency

---

### ServiceMonitor
**Description:** Prometheus scrape configuration for Kubernetes Services
**Use Case:** Monitoring service endpoints

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: example-servicemonitor
  namespace: example-namespace
  labels:
    release: prometheus
  annotations:
    description: "Scrape service endpoints"
spec:
  selector:
    matchLabels:
      app: example
      monitoring: "true"
  namespaceSelector:
    matchNames:
    - example-namespace
  endpoints:
  - port: metrics
    path: /metrics
    interval: 30s
    scrapeTimeout: 10s
    honorLabels: true
    metricRelabelings:
    - action: labeldrop
      regex: (temporary|debug)
```

**Apply Example:**
```bash
kubectl apply -f servicemonitor.yaml -n example-namespace
```

---

## 10. Quick Reference Table

| Component | Scope | Use Case | Key Feature |
|-----------|-------|----------|-------------|
| Namespace | Cluster | Isolation, multi-tenancy | Logical boundary |
| ResourceQuota | Namespace | Limit consumption | Hard limits |
| LimitRange | Namespace | Set defaults | Per-container bounds |
| Pod | Namespace | Basic unit | Ephemeral |
| Deployment | Namespace | Stateless apps | Rolling updates |
| StatefulSet | Namespace | Stateful apps | Stable identity + headless svc |
| DaemonSet | Cluster | Node agents | One per node |
| Job | Namespace | Batch tasks | Run to completion |
| CronJob | Namespace | Scheduled jobs | Cron syntax |
| ConfigMap | Namespace | Non-secrets | Key-value config |
| Secret | Namespace | Sensitive data | Base64 encoded |
| Service | Namespace | Load balancing | Stable endpoint |
| Ingress | Namespace | External routing | HTTP/HTTPS |
| NetworkPolicy | Namespace | Traffic control | Allow/deny rules |
| HPA | Namespace | Auto-scaling | Metric-driven (requires Metrics Server) |
| VPA | Namespace | Resource tuning | Recommendation-driven |
| PDB | Namespace | Availability | Min replicas |

---

## Best Practices Summary

### Security
- Always use `securityContext` with `runAsNonRoot: true`
- Never store secrets in ConfigMaps
- Use `NetworkPolicy` with explicit allow/deny rules (and always allow DNS)
- Implement RBAC with least-privilege principle
- Enable Pod Security Policies/Standards
- Set all init containers and containers with proper security context

### Reliability
- Set resource `requests` and `limits` for all containers
- Configure `livenessProbe` and `readinessProbe` appropriately
- Use pod anti-affinity for better distribution (prefer for StatefulSet, required for Deployment in production)
- Implement `PodDisruptionBudget` for critical apps
- Monitor and alert on key metrics
- Use headless Services with StatefulSets

### Operations
- Use explicit image tags, never `latest`
- Store YAML in version control
- Automate deployments with GitOps
- Implement proper labeling scheme
- Regular backup and disaster recovery drills
- Test NetworkPolicy changes before applying broadly
- Verify required components (Metrics Server, Ingress Controller, CNI) before using dependent features

### Observability
- Add Prometheus scrape annotations
- Use structured logging with JSON format
- Implement distributed tracing
- Monitor resource utilization continuously
- Audit API access for compliance
- Verify Metrics Server with `kubectl get apiservice v1beta1.metrics.k8s.io` before HPA deployment

### Scaling Strategy
- Use HPA for horizontal scaling (replicas) with Metrics Server
- Use VPA for vertical scaling (requests/limits)
- NEVER use HPA and VPA together in Auto mode (they conflict, causing constant restarts)
- Start VPA in "Initial" mode to validate recommendations before switching to "Auto"
- Test scaling policies in non-production environments

---

## Troubleshooting Commands

```bash
# General diagnostics
kubectl get all -n example-namespace
kubectl describe pod <pod-name> -n example-namespace
kubectl logs <pod-name> -n example-namespace
kubectl logs <pod-name> -p -n example-namespace

# Debugging
kubectl exec -it <pod-name> -- /bin/bash -n example-namespace
kubectl port-forward pod/<pod-name> 8080:8080 -n example-namespace
kubectl top nodes
kubectl top pods -n example-namespace

# Events and status
kubectl get events -n example-namespace --sort-by='.lastTimestamp'
kubectl describe node <node-name>
kubectl describe resourcequota -n example-namespace

# RBAC validation
kubectl auth can-i create deployments --as=system:serviceaccount:example-namespace:example-serviceaccount
kubectl auth can-i list secrets --as=system:serviceaccount:example-namespace:example-serviceaccount

# Metrics Server verification
kubectl get apiservice v1beta1.metrics.k8s.io -o yaml
kubectl get deployment metrics-server -n kube-system

# HPA status
kubectl get hpa -n example-namespace
kubectl describe hpa <hpa-name> -n example-namespace
kubectl get metrics pods -n example-namespace

# VPA recommendations
kubectl describe vpa <vpa-name> -n example-namespace

# Network debugging
kubectl get networkpolicy -n example-namespace
kubectl describe networkpolicy <policy-name> -n example-namespace
kubectl get pods -o wide -n example-namespace

# Service resolution
kubectl get svc -n example-namespace
kubectl describe svc <service-name> -n example-namespace
```

---

## Error Corrections & Improvements Applied

1. **LimitRange Pod Limits** - Clarified Pod min/max must match or exceed Container min/max
2. **Pod Init Container Security** - Added `runAsNonRoot: true` and `readOnlyRootFilesystem: true`
3. **Deployment Anti-Affinity** - Used `required` with operational implications explained
4. **StatefulSet Anti-Affinity** - Changed to `preferred` (better for persistence/stability trade-off)
5. **StatefulSet Service** - Added headless Service definition and corrected `serviceName` reference
6. **NetworkPolicy DNS** - Moved DNS rule to top of egress for clarity and priority
7. **Job Restart Policy** - Clarified `Never` vs `OnFailure` vs `Always` usage
8. **HPA Metrics Server** - Improved verification using APIService check
9. **VPA Update Mode** - Recommended `Initial` mode before `Auto` with explicit conflict warning
10. **VPA + HPA Conflict** - Added explicit note about constant restart loops in Common Pitfalls
11. **PVC StorageClass** - Added warning about PVC remaining Pending if StorageClass missing
12. **Ingress Controller** - Added requirement note about Ingress controller installation
13. **NetworkPolicy CNI** - Emphasized CNI requirement for policy enforcement

---

**Last Updated:** October 2025  
**Kubernetes Versions:** 1.24+  
**Status:** Production Ready - All Corrections Applied & Enhanced