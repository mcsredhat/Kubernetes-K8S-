# Mastering Kubernetes StatefulSets: A Complete Guide

StatefulSets represent one of Kubernetes' most powerful workload controllers, specifically designed to manage applications that require stable, persistent identities and ordered operations. Unlike Deployments that treat all pods as interchangeable, StatefulSets ensure each pod maintains a unique, stable identity throughout its lifecycle.

## Understanding StatefulSets: The Foundation

Before diving into practical examples, it's essential to understand why StatefulSets exist and what problems they solve. Traditional web applications are typically stateless, meaning any instance can handle any request, and if an instance fails, it can be replaced by an identical copy without consequence. However, many applications require persistent state, stable network identities, or ordered startup and shutdown procedures.

StatefulSets provide three fundamental guarantees that distinguish them from other Kubernetes controllers:

**Stable Network Identity**: Each pod in a StatefulSet receives a predictable hostname that persists across restarts. This hostname follows the pattern `<statefulset-name>-<ordinal>`, where the ordinal is a zero-based index. This predictability is crucial for applications that need to discover and communicate with specific instances.

**Persistent Storage**: StatefulSets integrate seamlessly with persistent volumes, ensuring that each pod's data survives pod restarts, rescheduling, and even scaling operations. When a pod is recreated, it reconnects to the same persistent volume it was using before.

**Ordered Operations**: StatefulSets deploy, scale, and terminate pods in a predictable order. This ordering is essential for applications like databases where the primary node must be ready before replicas can start, or for applications that require careful coordination during startup or shutdown.

## StatefulSet Components Deep Dive

A StatefulSet consists of several interconnected components that work together to provide these guarantees. Understanding each component helps you design robust stateful applications.

### Headless Services: The Discovery Mechanism

Every StatefulSet requires a headless service, which is a service with `clusterIP: None`. Unlike regular services that provide load balancing and a single virtual IP, headless services create DNS records for each pod, enabling direct pod-to-pod communication. When you query the headless service, DNS returns the IP addresses of all pods rather than a single load-balanced endpoint.

This direct addressing capability is crucial for stateful applications. For example, in a database cluster, you might need to connect directly to the primary node for writes while distributing reads across replicas. The headless service makes this possible by providing stable DNS names for each pod.

### Volume Claim Templates: Persistent Storage Management

Volume claim templates define how persistent storage is provisioned for each pod in the StatefulSet. Unlike regular volumes that are shared across pods, volume claim templates create a unique persistent volume claim for each pod. These claims follow the naming pattern `<template-name>-<pod-name>`, ensuring each pod gets its own storage.

The beauty of volume claim templates lies in their lifecycle management. When you scale up a StatefulSet, new pods automatically get new persistent volume claims. When you scale down, the claims are retained, so if you scale back up, the pods reconnect to their original data. This behavior prevents accidental data loss during scaling operations.

## Practical Implementation: MySQL StatefulSet

Let's implement a comprehensive MySQL StatefulSet that demonstrates all the key concepts while building understanding progressively.

```bash
#!/bin/bash
# Enhanced MySQL StatefulSet Demo
# This script demonstrates StatefulSet concepts through practical MySQL deployment

echo "🎓 StatefulSet Learning Demo: MySQL Cluster"
echo "This demo will teach StatefulSet concepts through hands-on MySQL deployment"

# Step 1: Create the headless service
# The headless service enables pod-to-pod communication with stable DNS names
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: mysql-headless
  labels:
    app: mysql
    demo: statefulset-learning
spec:
  ports:
  - port: 3306
    name: mysql
    protocol: TCP
  # clusterIP: None makes this a headless service
  # This means DNS queries return pod IPs directly instead of a load-balanced VIP
  clusterIP: None
  selector:
    app: mysql
---
# Optional: Regular service for external access to any MySQL instance
apiVersion: v1
kind: Service
metadata:
  name: mysql-read
  labels:
    app: mysql
    demo: statefulset-learning
spec:
  ports:
  - port: 3306
    name: mysql
    protocol: TCP
  selector:
    app: mysql
EOF

echo "📚 Concept Check: Headless service created"
echo "   • Headless services provide stable DNS names for each pod"
echo "   • Each pod gets: <pod-name>.<service-name>.<namespace>.svc.cluster.local"
echo "   • Example: mysql-0.mysql-headless.default.svc.cluster.local"

# Step 2: Create a comprehensive StatefulSet with educational annotations
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
  labels:
    app: mysql
    demo: statefulset-learning
spec:
  # serviceName MUST match the headless service name
  # This creates the DNS subdomain for pod discovery
  serviceName: mysql-headless
  
  # Start with 1 replica to demonstrate ordered scaling
  replicas: 1
  
  # Selector must match the template labels
  selector:
    matchLabels:
      app: mysql
  
  # updateStrategy controls how updates are rolled out
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      # OnDelete means pods are updated only when manually deleted
      # RollingUpdate updates pods automatically in reverse order
      partition: 0  # Start updating from pod 0 onwards
  
  # The pod template defines what each pod looks like
  template:
    metadata:
      labels:
        app: mysql
    spec:
      # Termination grace period for clean shutdowns
      terminationGracePeriodSeconds: 30
      
      containers:
      - name: mysql
        image: mysql:8.0
        
        # Environment variables for MySQL configuration
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: "statefulset-demo-password"
        - name: MYSQL_DATABASE
          value: "testdb"
        - name: MYSQL_USER
          value: "testuser"
        - name: MYSQL_PASSWORD
          value: "testpass"
        # Use the pod name in the database for demonstration
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        
        ports:
        - containerPort: 3306
          name: mysql
          protocol: TCP
        
        # Volume mounts connect the persistent storage to the container
        volumeMounts:
        - name: mysql-data
          mountPath: /var/lib/mysql
          # subPath prevents the mount from hiding existing directory contents
          subPath: mysql
        
        # Custom initialization script to demonstrate pod identity
        - name: init-script
          mountPath: /docker-entrypoint-initdb.d
        
        # Readiness probe ensures pod is ready to receive traffic
        readinessProbe:
          exec:
            command: ["mysql", "-h", "127.0.0.1", "-u", "root", "-pstatefulset-demo-password", "-e", "SELECT 1"]
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 3
        
        # Liveness probe detects if the container needs to be restarted
        livenessProbe:
          exec:
            command: ["mysqladmin", "ping", "-h", "127.0.0.1", "-u", "root", "-pstatefulset-demo-password"]
          initialDelaySeconds: 60
          periodSeconds: 30
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 3
        
        # Resource requests and limits for proper scheduling
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      
      # Volumes section defines non-persistent volumes
      volumes:
      - name: init-script
        configMap:
          name: mysql-init-script
          defaultMode: 0755

  # Volume claim templates create persistent storage for each pod
  volumeClaimTemplates:
  - metadata:
      name: mysql-data
      labels:
        app: mysql
    spec:
      # AccessModes define how the volume can be mounted
      # ReadWriteOnce: volume can be mounted read-write by a single node
      accessModes: ["ReadWriteOnce"]
      
      # Storage class defines the type of storage (optional)
      # If omitted, uses the default storage class
      # storageClassName: "fast-ssd"
      
      resources:
        requests:
          storage: 2Gi
EOF

# Create initialization script to demonstrate pod identity
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: security-config
  namespace: secure-statefulset-demo
data:
  security-context.yaml: |
    # Pod Security Context Configuration
    securityContext:
      runAsNonRoot: true
      runAsUser: 999
      runAsGroup: 999
      fsGroup: 999
      seccompProfile:
        type: RuntimeDefault
    
    # Container Security Context
    containerSecurityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      runAsNonRoot: true
      runAsUser: 999
      capabilities:
        drop:
        - ALL
        add:
        - NET_BIND_SERVICE
EOF

# Create the secure StatefulSet
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: secure-db-headless
  namespace: secure-statefulset-demo
spec:
  ports:
  - port: 5432
    name: postgres
  clusterIP: None
  selector:
    app: secure-db
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: secure-postgres
  namespace: secure-statefulset-demo
spec:
  serviceName: secure-db-headless
  replicas: 3
  selector:
    matchLabels:
      app: secure-db
  template:
    metadata:
      labels:
        app: secure-db
      annotations:
        # Security scanning annotations
        container.apparmor.security.beta.kubernetes.io/postgres: runtime/default
    spec:
      serviceAccountName: secure-db-sa
      
      # Pod-level security context
      securityContext:
        runAsNonRoot: true
        runAsUser: 999  # postgres user
        runAsGroup: 999 # postgres group
        fsGroup: 999
        seccompProfile:
          type: RuntimeDefault
        supplementalGroups: [999]
      
      # Node selection for security compliance
      nodeSelector:
        security-level: "high"
      
      # Pod anti-affinity for security isolation
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values: ["secure-db"]
            topologyKey: kubernetes.io/hostname
      
      containers:
      - name: postgres
        image: postgres:14-alpine  # Use minimal base image
        
        # Container-level security context
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 999
          capabilities:
            drop:
            - ALL
            add:
            - CHOWN
            - SETGID
            - SETUID
        
        # Environment variables from secrets
        env:
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: username
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: password
        - name: POSTGRES_DB
          value: "securedb"
        - name: PGDATA
          value: "/var/lib/postgresql/data/pgdata"
        
        ports:
        - containerPort: 5432
          name: postgres
        
        volumeMounts:
        - name: postgres-data
          mountPath: /var/lib/postgresql/data
        - name: postgres-config
          mountPath: /etc/postgresql
          readOnly: true
        - name: tls-certs
          mountPath: /etc/ssl/certs/postgres
          readOnly: true
        # Writable temporary directories
        - name: tmp
          mountPath: /tmp
        - name: var-run
          mountPath: /var/run/postgresql
        
        # Resource limits for security
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        
        # Enhanced health checks
        readinessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - pg_isready -U $POSTGRES_USER -h 127.0.0.1
          initialDelaySeconds: 15
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        
        livenessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - pg_isready -U $POSTGRES_USER -h 127.0.0.1
          initialDelaySeconds: 30
          periodSeconds: 30
          timeoutSeconds: 5
          failureThreshold: 3
      
      # Security monitoring sidecar
      - name: security-monitor
        image: alpine:latest
        command: ["/bin/sh"]
        args:
          - -c
          - |
            while true; do
              echo "$(date): Security monitoring active for $HOSTNAME"
              # In real scenarios, this would integrate with security monitoring tools
              sleep 60
            done
        
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 65534  # nobody user
          capabilities:
            drop:
            - ALL
        
        resources:
          requests:
            memory: "32Mi"
            cpu: "10m"
          limits:
            memory: "64Mi"
            cpu: "50m"
        
        volumeMounts:
        - name: tmp
          mountPath: /tmp
      
      volumes:
      - name: postgres-config
        configMap:
          name: postgres-secure-config
      - name: tls-certs
        secret:
          secretName: tls-certificates
      - name: tmp
        emptyDir: {}
      - name: var-run
        emptyDir: {}
  
  volumeClaimTemplates:
  - metadata:
      name: postgres-data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 2Gi
      # Use encrypted storage class if available
      storageClassName: "encrypted-ssd"
EOF

# Create secure PostgreSQL configuration
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-secure-config
  namespace: secure-statefulset-demo
data:
  postgresql.conf: |
    # Security-hardened PostgreSQL configuration
    
    # Connection and Authentication
    listen_addresses = '*'
    port = 5432
    max_connections = 100
    
    # SSL Configuration
    ssl = on
    ssl_cert_file = '/etc/ssl/certs/postgres/tls.crt'
    ssl_key_file = '/etc/ssl/certs/postgres/tls.key'
    ssl_prefer_server_ciphers = on
    ssl_ciphers = 'ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256'
    
    # Security Settings
    password_encryption = scram-sha-256
    
    # Logging for Security Auditing
    logging_collector = on
    log_destination = 'stderr'
    log_connections = on
    log_disconnections = on
    log_statement = 'all'
    log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
    
    # Performance with Security
    shared_buffers = 128MB
    effective_cache_size = 256MB
    
  pg_hba.conf: |
    # Security-hardened host-based authentication
    
    # Local connections (Unix socket)
    local   all             postgres                                peer
    local   all             all                                     scram-sha-256
    
    # IPv4 connections with strict authentication
    hostssl all             all             0.0.0.0/0               scram-sha-256
    
    # Reject non-SSL connections
    host    all             all             0.0.0.0/0               reject
EOF

echo "⏳ Deploying secure StatefulSet..."

# Note: This deployment might fail if the security requirements can't be met
# (e.g., no nodes with security-level=high label, no encrypted-ssd storage class)
echo "📝 Note: This demo requires:"
echo "   • Nodes labeled with security-level=high"
echo "   • Storage class named 'encrypted-ssd'"
echo "   • Network policy support"

# Try to deploy but don't wait if it fails due to missing requirements
kubectl get statefulset secure-postgres -n secure-statefulset-demo --timeout=60s || {
  echo "⚠️  StatefulSet deployment pending - security requirements may not be met"
  echo "Checking deployment status..."
  kubectl describe statefulset secure-postgres -n secure-statefulset-demo | tail -20
}

echo ""
echo "🔍 Security Validation and Testing:"

# Create security test suite
cat << 'EOF' > /tmp/security-tests.sh
#!/bin/bash
# Security validation tests for StatefulSet

NAMESPACE="secure-statefulset-demo"

echo "🔒 StatefulSet Security Validation Suite"
echo "========================================="

# Test 1: Verify non-root execution
echo ""
echo "Test 1: Non-root execution validation"
for pod in $(kubectl get pods -n $NAMESPACE -l app=secure-db -o name 2>/dev/null); do
  echo "  Checking $pod:"
  kubectl exec -n $NAMESPACE $pod -c postgres -- id 2>/dev/null || echo "    Pod not ready"
done

# Test 2: Verify read-only root filesystem
echo ""
echo "Test 2: Read-only root filesystem validation"
for pod in $(kubectl get pods -n $NAMESPACE -l app=secure-db -o name 2>/dev/null); do
  echo "  Checking $pod:"
  kubectl exec -n $NAMESPACE $pod -c postgres -- touch /test-file 2>&1 | grep -q "Read-only" && echo "    ✅ Root filesystem is read-only" || echo "    ❌ Root filesystem is writable"
done

# Test 3: Verify capabilities
echo ""
echo "Test 3: Security capabilities validation"
kubectl get pods -n $NAMESPACE -l app=secure-db -o yaml 2>/dev/null | grep -A 10 "securityContext:" | head -15

# Test 4: Network policy validation
echo ""
echo "Test 4: Network policy validation"
kubectl get networkpolicy -n $NAMESPACE -o wide

# Test 5: Secret mounting validation
echo ""
echo "Test 5: Secret mounting validation"
for pod in $(kubectl get pods -n $NAMESPACE -l app=secure-db -o name 2>/dev/null); do
  echo "  Checking secret mounts in $pod:"
  kubectl exec -n $NAMESPACE $pod -c postgres -- ls -la /etc/ssl/certs/postgres/ 2>/dev/null || echo "    TLS certificates not mounted"
done

# Test 6: Resource limits validation
echo ""
echo "Test 6: Resource limits validation"
kubectl describe pods -n $NAMESPACE -l app=secure-db 2>/dev/null | grep -A 4 "Limits:" | head -10

echo ""
echo "🔍 Security recommendations based on results:"
echo "   • Ensure all pods run as non-root users"
echo "   • Verify read-only root filesystems are enforced"
echo "   • Check that unnecessary capabilities are dropped"
echo "   • Validate network policies are active and restrictive"
echo "   • Confirm secrets are properly mounted and protected"
echo "   • Monitor resource usage against defined limits"
EOF

chmod +x /tmp/security-tests.sh
echo "Created security test suite: /tmp/security-tests.sh"

# Run security tests
echo ""
echo "🧪 Running security validation tests:"
bash /tmp/security-tests.sh

echo ""
echo "📋 Security Checklist for Production StatefulSets:"
echo ""
echo "🔐 Authentication and Authorization:"
echo "   ✅ Use dedicated service accounts with minimal privileges"
echo "   ✅ Implement RBAC with principle of least privilege"
echo "   ✅ Rotate credentials regularly using secret rotation"
echo "   ✅ Use external secret management systems (Vault, etc.)"
echo ""
echo "🛡️ Container Security:"
echo "   ✅ Run containers as non-root users"
echo "   ✅ Use read-only root filesystems"
echo "   ✅ Drop all capabilities and add only required ones"
echo "   ✅ Enable seccomp and AppArmor profiles"
echo "   ✅ Use minimal base images (distroless, alpine)"
echo ""
echo "🌐 Network Security:"
echo "   ✅ Implement network policies for traffic isolation"
echo "   ✅ Use TLS for all inter-pod communication"
echo "   ✅ Restrict ingress and egress traffic"
echo "   ✅ Use service mesh for advanced traffic control"
echo ""
echo "💾 Data Security:"
echo "   ✅ Use encrypted storage classes"
echo "   ✅ Implement data-at-rest encryption"
echo "   ✅ Secure backup and restore procedures"
echo "   ✅ Regular security scanning of persistent volumes"
echo ""
echo "📊 Security Monitoring:"
echo "   ✅ Enable comprehensive audit logging"
echo "   ✅ Monitor for security policy violations"
echo "   ✅ Implement runtime security scanning"
echo "   ✅ Set up alerting for suspicious activities"
echo ""
echo "🔄 Update and Patch Management:"
echo "   ✅ Regular security updates for base images"
echo "   ✅ Automated vulnerability scanning"
echo "   ✅ Staged deployment of security patches"
echo "   ✅ Rollback procedures for failed updates"

echo ""
echo "🧹 Security demo cleanup:"
echo "kubectl delete namespace secure-statefulset-demo"
echo "# This will remove all resources in the security demo namespace"
```

## Conclusion: StatefulSet Mastery

StatefulSets represent a sophisticated approach to managing stateful applications in Kubernetes, providing the stability and persistence required by databases, message queues, and other stateful systems. Through this comprehensive guide, we've explored the fundamental concepts, practical implementations, advanced patterns, and production considerations necessary to master StatefulSets.

The key to successful StatefulSet deployment lies in understanding the unique requirements of your stateful applications and leveraging StatefulSets' guarantees—stable network identity, persistent storage, and ordered operations—to build robust, scalable systems. Whether you're deploying a simple MySQL database or a complex distributed system with leader election and replication, the patterns and practices demonstrated in this guide provide a solid foundation for success.

Remember that StatefulSets are just one piece of the Kubernetes ecosystem. They work best when combined with proper monitoring, security practices, backup strategies, and operational procedures. As you continue to work with StatefulSets, focus on understanding your application's specific requirements and adapting these patterns to meet your unique needs.

The evolution of stateful applications in Kubernetes continues, with new operators, storage solutions, and management tools emerging regularly. Stay engaged with the community, experiment with new approaches, and always prioritize reliability and security in your stateful workload deployments.:
  name: mysql-init-script
  labels:
    app: mysql
    demo: statefulset-learning
data:
  01-pod-identity.sql: |
    -- This script demonstrates how each pod maintains its identity
    CREATE TABLE IF NOT EXISTS pod_identity (
      id INT AUTO_INCREMENT PRIMARY KEY,
      pod_name VARCHAR(100) NOT NULL,
      startup_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      data_directory VARCHAR(200)
    );
    
    -- Insert pod identity information
    -- Note: The POD_NAME environment variable is unique for each pod
    INSERT INTO pod_identity (pod_name, data_directory) 
    VALUES (
      IFNULL(@pod_name, 'unknown-pod'), 
      '/var/lib/mysql'
    );
    
    -- Create a sample table to demonstrate persistence
    CREATE TABLE IF NOT EXISTS demo_data (
      id INT AUTO_INCREMENT PRIMARY KEY,
      message VARCHAR(200),
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    
    INSERT INTO demo_data (message) VALUES ('Initial data from pod initialization');
EOF

echo "⏳ Waiting for MySQL StatefulSet to be ready..."
echo "📚 StatefulSet pods start in order: mysql-0, then mysql-1, then mysql-2, etc."

# Wait for the first pod to be ready
kubectl wait --for=condition=ready pod/mysql-0 --timeout=300s

echo "✅ mysql-0 is ready!"
echo "🔍 Let's examine what StatefulSet created:"

# Show the resources created
kubectl get statefulset mysql -o wide
kubectl get pods -l app=mysql -o wide
kubectl get pvc -l app=mysql
kubectl get svc -l app=mysql

echo ""
echo "📚 Concept Check: Notice the predictable naming"
echo "   • Pod name: mysql-0 (not random like Deployment pods)"
echo "   • PVC name: mysql-data-mysql-0 (template-name + pod-name)"
echo "   • DNS name: mysql-0.mysql-headless.default.svc.cluster.local"

# Test pod identity and persistence
echo ""
echo "🧪 Testing pod identity and data persistence..."

# Connect to mysql-0 and insert pod-specific data
kubectl exec mysql-0 -- mysql -u root -pstatefulset-demo-password -e "
  USE testdb;
  SELECT 'Current pod identity:' as info;
  SELECT * FROM pod_identity;
  
  INSERT INTO demo_data (message) VALUES ('Data added after startup from mysql-0');
  SELECT 'Demo data:' as info;
  SELECT * FROM demo_data ORDER BY created_at;
"

echo ""
echo "📈 Now let's demonstrate ordered scaling..."
echo "📚 StatefulSets scale in order: 0, 1, 2... when scaling up"
echo "📚 StatefulSets scale in reverse order: 2, 1, 0... when scaling down"

# Scale up to 3 replicas
kubectl scale statefulset mysql --replicas=3

echo "⏳ Watching ordered pod creation (mysql-1 will start only after mysql-0 is ready)..."

# Wait for all pods with a timeout
kubectl wait --for=condition=ready pod -l app=mysql --timeout=600s

echo ""
echo "✅ All MySQL pods are ready!"
kubectl get pods -l app=mysql -o wide

# Test each pod's identity
echo ""
echo "🧪 Testing individual pod identities..."
for i in {0..2}; do
  echo "--- Testing mysql-$i ---"
  kubectl exec mysql-$i -- mysql -u root -pstatefulset-demo-password -e "
    USE testdb;
    INSERT INTO demo_data (message) VALUES ('Data from mysql-$i');
    SELECT CONCAT('Pod mysql-$i data:') as info;
    SELECT * FROM demo_data WHERE message LIKE '%mysql-$i%';
  " 2>/dev/null || echo "Pod mysql-$i not ready yet"
done

# Demonstrate persistence by deleting and recreating a pod
echo ""
echo "🔄 Testing persistence: Deleting mysql-1 to show data survives..."
kubectl delete pod mysql-1

echo "⏳ Waiting for mysql-1 to be recreated..."
kubectl wait --for=condition=ready pod/mysql-1 --timeout=300s

echo "🧪 Verifying data survived pod recreation..."
kubectl exec mysql-1 -- mysql -u root -pstatefulset-demo-password -e "
  USE testdb;
  SELECT 'Data after pod recreation:' as info;
  SELECT * FROM demo_data WHERE message LIKE '%mysql-1%';
"

# Demonstrate DNS resolution
echo ""
echo "🌐 Testing DNS resolution from within the cluster..."
kubectl run mysql-client --image=mysql:8.0 --rm -it --restart=Never --command -- bash -c "
  # Test headless service DNS resolution
  echo 'Testing headless service DNS resolution:'
  nslookup mysql-headless.default.svc.cluster.local
  
  echo ''
  echo 'Testing individual pod DNS resolution:'
  nslookup mysql-0.mysql-headless.default.svc.cluster.local
  
  echo ''
  echo 'Connecting to specific pod via DNS:'
  mysql -h mysql-0.mysql-headless.default.svc.cluster.local -u testuser -ptestpass -e 'SELECT \"Connected to mysql-0 via DNS!\" as result;'
"

# Test ordered shutdown
echo ""
echo "📉 Testing ordered scaling down (pods terminate in reverse order)..."
kubectl scale statefulset mysql --replicas=1

echo "⏳ Watch pods terminate in order: mysql-2, then mysql-1..."
kubectl get pods -l app=mysql -w &
WATCH_PID=$!
sleep 30
kill $WATCH_PID 2>/dev/null

echo ""
echo "✅ Scaled down to 1 replica. mysql-0 remains with all its data intact."
kubectl get pods -l app=mysql
kubectl get pvc -l app=mysql

echo ""
echo "🧪 Final persistence test - data should still be there:"
kubectl exec mysql-0 -- mysql -u root -pstatefulset-demo-password -e "
  USE testdb;
  SELECT 'Final data check - all data persisted:' as info;
  SELECT COUNT(*) as total_records FROM demo_data;
  SELECT * FROM demo_data ORDER BY created_at;
"

echo ""
echo "🎓 StatefulSet Demo Complete! Key learnings:"
echo "   ✅ Pods have stable, predictable names (mysql-0, mysql-1, mysql-2)"
echo "   ✅ Each pod gets its own persistent storage that survives restarts"
echo "   ✅ Pods start and stop in order (0→1→2 up, 2→1→0 down)"
echo "   ✅ DNS provides stable network identity for each pod"
echo "   ✅ Data persists even when pods are deleted and recreated"
echo "   ✅ Volume claims are retained during scaling operations"

echo ""
echo "🧹 Cleanup commands:"
echo "kubectl delete statefulset mysql"
echo "kubectl delete service mysql-headless mysql-read"
echo "kubectl delete configmap mysql-init-script"
echo "kubectl delete pvc -l app=mysql  # Careful: This deletes all data!"
```

## Advanced StatefulSet Patterns: Distributed PostgreSQL Cluster

Building on the MySQL example, let's explore a more sophisticated use case that demonstrates StatefulSets' power in managing distributed systems. This PostgreSQL cluster implements leader election, replication, and automatic failover.

```bash
#!/bin/bash
# Advanced StatefulSet Pattern: PostgreSQL Cluster with Leader Election
# This demonstrates sophisticated StatefulSet usage for distributed systems

echo "🎓 Advanced StatefulSet Pattern: Distributed PostgreSQL Cluster"
echo "This demo showcases StatefulSets managing complex distributed systems"

# Step 1: Create comprehensive configuration
# ConfigMaps store configuration that pods can mount as files
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-cluster-config
  labels:
    app: postgres-cluster
data:
  # Primary node initialization script
  primary-init.sh: |
    #!/bin/bash
    set -e
    
    echo "🎯 Initializing PostgreSQL primary node"
    
    # Check if this is the first pod (postgres-0) which becomes primary
    if [[ "\$POD_NAME" == "postgres-0" ]]; then
      if [ ! -f /var/lib/postgresql/data/PG_VERSION ]; then
        echo "📝 Setting up primary database..."
        
        # Initialize the database cluster
        initdb -D /var/lib/postgresql/data --auth-host=md5 --auth-local=peer
        
        # Configure PostgreSQL for replication
        cat >> /var/lib/postgresql/data/postgresql.conf << SQL_CONFIG
# Replication Configuration
listen_addresses = '*'
wal_level = replica
max_wal_senders = 5
max_replication_slots = 5
hot_standby = on
hot_standby_feedback = on
SQL_CONFIG
        
        # Configure client authentication
        cat >> /var/lib/postgresql/data/pg_hba.conf << HBA_CONFIG
# Replication connections
host replication postgres 0.0.0.0/0 md5
host all all 0.0.0.0/0 md5
HBA_CONFIG
        
        echo "✅ Primary node configuration complete"
      fi
    fi
  
  # Replica node initialization script
  replica-init.sh: |
    #!/bin/bash
    set -e
    
    echo "🔄 Initializing PostgreSQL replica node"
    
    # Only initialize if this is not the primary (postgres-0)
    if [[ "\$POD_NAME" != "postgres-0" ]]; then
      if [ ! -f /var/lib/postgresql/data/PG_VERSION ]; then
        echo "📝 Setting up replica database from primary..."
        
        # Wait for primary to be ready
        echo "⏳ Waiting for primary node to be ready..."
        until pg_isready -h postgres-0.postgres-cluster.default.svc.cluster.local -p 5432 -U postgres; do
          echo "Primary not ready, waiting..."
          sleep 5
        done
        
        # Create base backup from primary
        PGPASSWORD=\$POSTGRES_PASSWORD pg_basebackup \\
          -h postgres-0.postgres-cluster.default.svc.cluster.local \\
          -D /var/lib/postgresql/data \\
          -U postgres \\
          -v -P -R
        
        # Configure this as a standby server
        cat >> /var/lib/postgresql/data/postgresql.conf << REPLICA_CONFIG
# Replica-specific configuration
primary_conninfo = 'host=postgres-0.postgres-cluster.default.svc.cluster.local port=5432 user=postgres password=\$POSTGRES_PASSWORD'
promote_trigger_file = '/tmp/promote_trigger'
REPLICA_CONFIG
        
        echo "✅ Replica node configuration complete"
      fi
    fi
  
  # Health check script for determining primary/replica status
  health-check.sh: |
    #!/bin/bash
    # This script helps determine the role of each PostgreSQL instance
    
    if pg_isready -q; then
      # Check if this is a primary or standby
      ROLE=\$(psql -U postgres -tAc "SELECT CASE WHEN pg_is_in_recovery() THEN 'replica' ELSE 'primary' END;")
      echo "Node \$POD_NAME is \$ROLE"
      
      # For monitoring and service discovery
      if [[ "\$ROLE" == "primary" ]]; then
        # Create/update primary indicator
        touch /tmp/primary_indicator
      else
        # Remove primary indicator if it exists
        rm -f /tmp/primary_indicator
      fi
      
      exit 0
    else
      echo "PostgreSQL is not ready"
      exit 1
    fi
EOF

# Step 2: Create services for different access patterns
cat << EOF | kubectl apply -f -
# Headless service for StatefulSet pod discovery
apiVersion: v1
kind: Service
metadata:
  name: postgres-cluster
  labels:
    app: postgres-cluster
spec:
  ports:
  - port: 5432
    name: postgres
  clusterIP: None  # Headless service
  selector:
    app: postgres-cluster
---
# Service specifically for primary node (write operations)
apiVersion: v1
kind: Service
metadata:
  name: postgres-primary
  labels:
    app: postgres-cluster
    role: primary
spec:
  ports:
  - port: 5432
    name: postgres
  selector:
    app: postgres-cluster
    role: primary
---
# Service for read replicas (read-only operations)
apiVersion: v1
kind: Service
metadata:
  name: postgres-replica
  labels:
    app: postgres-cluster
    role: replica
spec:
  ports:
  - port: 5432
    name: postgres
  selector:
    app: postgres-cluster
    role: replica
EOF

# Step 3: Create the StatefulSet with sophisticated pod management
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  labels:
    app: postgres-cluster
spec:
  serviceName: postgres-cluster
  replicas: 3
  
  # Update strategy for controlled rolling updates
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      partition: 0
  
  # Pod management policy affects startup ordering
  podManagementPolicy: OrderedReady  # Ensures ordered startup
  
  selector:
    matchLabels:
      app: postgres-cluster
  
  template:
    metadata:
      labels:
        app: postgres-cluster
    spec:
      # Security context for PostgreSQL
      securityContext:
        fsGroup: 999  # postgres group
      
      # Longer termination period for graceful shutdown
      terminationGracePeriodSeconds: 60
      
      # Init container to set up the node based on its role
      initContainers:
      - name: postgres-init
        image: postgres:14
        command: ["/bin/bash"]
        args:
          - -c
          - |
            echo "🚀 Starting initialization for \$POD_NAME"
            
            # Determine if this should be primary or replica
            if [[ "\$POD_NAME" == "postgres-0" ]]; then
              echo "📝 This is the primary node"
              /config/primary-init.sh
            else
              echo "🔄 This is a replica node"
              /config/replica-init.sh
            fi
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: POSTGRES_PASSWORD
          value: "secure-cluster-password"
        volumeMounts:
        - name: postgres-data
          mountPath: /var/lib/postgresql/data
        - name: config
          mountPath: /config
        securityContext:
          runAsUser: 999  # postgres user
      
      containers:
      - name: postgres
        image: postgres:14
        
        env:
        - name: POSTGRES_PASSWORD
          value: "secure-cluster-password"
        - name: POSTGRES_DB
          value: "clusterdb"
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: POD_IP
          valueFrom:
            fieldRef:
              fieldPath: status.podIP
        
        ports:
        - containerPort: 5432
          name: postgres
        
        volumeMounts:
        - name: postgres-data
          mountPath: /var/lib/postgresql/data
        - name: config
          mountPath: /config
        
        # Comprehensive health checks
        readinessProbe:
          exec:
            command: ["/config/health-check.sh"]
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        
        livenessProbe:
          exec:
            command: ["pg_isready", "-U", "postgres"]
          initialDelaySeconds: 60
          periodSeconds: 30
          timeoutSeconds: 10
          failureThreshold: 5
        
        # Lifecycle hooks for graceful shutdown
        lifecycle:
          preStop:
            exec:
              command:
                - /bin/bash
                - -c
                - |
                  echo "🛑 Graceful shutdown initiated for \$POD_NAME"
                  # Perform clean shutdown
                  pg_ctl stop -D /var/lib/postgresql/data/pgdata -m fast
        
        resources:
          requests:
            memory: "512Mi"
            cpu: "200m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        
        securityContext:
          runAsUser: 999
      
      # Sidecar container for cluster management
      - name: cluster-monitor
        image: postgres:14
        command: ["/bin/bash"]
        args:
          - -c
          - |
            while true; do
              # Update pod labels based on current role
              ROLE=\$(psql -h localhost -U postgres -tAc "SELECT CASE WHEN pg_is_in_recovery() THEN 'replica' ELSE 'primary' END;" 2>/dev/null || echo "unknown")
              
              echo "\$(date): \$POD_NAME role is \$ROLE"
              
              # This would typically use the Kubernetes API to update labels
              # For demo purposes, we just log the status
              
              sleep 30
            done
        env:
        - name: POSTGRES_PASSWORD
          value: "secure-cluster-password"
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: PGPASSWORD
          value: "secure-cluster-password"
        
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
      
      volumes:
      - name: config
        configMap:
          name: postgres-cluster-config
          defaultMode: 0755
  
  # Persistent volume claims for each pod
  volumeClaimTemplates:
  - metadata:
      name: postgres-data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 5Gi
      # Optional: Specify storage class for performance requirements
      # storageClassName: "fast-ssd"
EOF

echo "⏳ Deploying PostgreSQL cluster..."
echo "📚 This demonstrates advanced StatefulSet patterns:"
echo "   • Complex initialization based on pod ordinal"
echo "   • Primary/replica role assignment"
echo "   • Cluster-aware configuration"
echo "   • Sidecar containers for monitoring"

# Wait for the cluster to be ready
kubectl wait --for=condition=ready pod -l app=postgres-cluster --timeout=600s

echo ""
echo "✅ PostgreSQL cluster is ready!"
kubectl get statefulset postgres -o wide
kubectl get pods -l app=postgres-cluster -o wide

# Test the cluster functionality
echo ""
echo "🧪 Testing cluster functionality..."

# Test primary node
echo "--- Testing Primary Node (postgres-0) ---"
kubectl exec postgres-0 -c postgres -- psql -U postgres -c "
  CREATE TABLE IF NOT EXISTS cluster_test (
    id SERIAL PRIMARY KEY,
    node_name VARCHAR(50),
    test_data TEXT,
    created_at TIMESTAMP DEFAULT NOW()
  );
  
  INSERT INTO cluster_test (node_name, test_data) 
  VALUES ('postgres-0', 'Data written to primary');
  
  SELECT 'Primary node data:' as info;
  SELECT * FROM cluster_test;
"

# Test replica nodes
echo ""
echo "--- Testing Replica Nodes (read-only) ---"
for i in {1..2}; do
  echo "Testing postgres-$i as replica:"
  kubectl exec postgres-$i -c postgres -- psql -U postgres -c "
    SELECT 'Replica postgres-$i data:' as info;
    SELECT * FROM cluster_test;
    SELECT 'This node is: ' || CASE WHEN pg_is_in_recovery() THEN 'REPLICA' ELSE 'PRIMARY' END as role;
  " 2>/dev/null || echo "postgres-$i not ready yet"
done

# Test DNS resolution
echo ""
echo "🌐 Testing cluster DNS resolution..."
kubectl run postgres-client --image=postgres:14 --rm -it --restart=Never -- bash -c "
  echo 'Testing headless service DNS:'
  nslookup postgres-cluster.default.svc.cluster.local
  
  echo ''
  echo 'Testing individual pod DNS:'
  for i in 0 1 2; do
    echo \"postgres-\$i:\"
    nslookup postgres-\$i.postgres-cluster.default.svc.cluster.local
  done
  
  echo ''
  echo 'Testing connection to primary via DNS:'
  PGPASSWORD=secure-cluster-password psql -h postgres-0.postgres-cluster.default.svc.cluster.local -U postgres -c 'SELECT version();'
"

echo ""
echo "🎓 Advanced StatefulSet Demo Complete!"
echo ""
echo "Key Advanced Patterns Demonstrated:"
echo "   ✅ Role-based initialization (primary vs replica)"
echo "   ✅ Complex inter-pod dependencies and coordination"
echo "   ✅ Multiple containers per pod (main + sidecar)"
echo "   ✅ Sophisticated health checking and monitoring"
echo "   ✅ Graceful shutdown procedures"
echo "   ✅ Service separation by role (primary/replica)"
echo "   ✅ Configuration management with ConfigMaps"
echo "   ✅ Security contexts and proper user management"

echo ""
echo "🧹 Cleanup commands:"
echo "kubectl delete statefulset postgres"
echo "kubectl delete service postgres-cluster postgres-primary postgres-replica"
echo "kubectl delete configmap postgres-cluster-config"
echo "kubectl delete pvc -l app=postgres-cluster  # Warning: Deletes all data!"
```

## StatefulSet Best Practices and Production Considerations

When deploying StatefulSets in production environments, several critical considerations ensure reliability, performance, and maintainability.

**Resource Management**: Always specify resource requests and limits for your containers. StatefulSets often manage resource-intensive applications like databases, so proper resource allocation prevents node overcommitment and ensures predictable performance. Consider the storage requirements carefully, as persistent volume claims cannot be easily resized in many storage classes.

**Update Strategies**: Choose your update strategy based on your application's requirements. The `RollingUpdate` strategy updates pods in reverse order (highest ordinal first), which is often appropriate for replicated systems where you want to update followers before the leader. The `OnDelete` strategy gives you manual control over when each pod is updated, which might be necessary for complex distributed systems.

**Backup and Disaster Recovery**: StatefulSets require careful backup strategies since each pod maintains unique state. Implement regular backups of persistent volumes and test restore procedures. Consider using volume snapshots where available, and ensure your backup strategy accounts for the ordered nature of StatefulSet data dependencies.

## StatefulSet Troubleshooting Guide

Understanding common StatefulSet issues and their solutions is crucial for maintaining reliable stateful applications.

```bash
#!/bin/bash
# StatefulSet Troubleshooting and Debugging Guide
# This script demonstrates common issues and diagnostic techniques

echo "🔧 StatefulSet Troubleshooting Guide"
echo "This guide covers common issues and diagnostic approaches"

# Create a deliberately problematic StatefulSet for demonstration
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: debug-headless
spec:
  ports:
  - port: 80
  clusterIP: None
  selector:
    app: debug-app
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: debug-app
spec:
  serviceName: debug-headless
  replicas: 3
  selector:
    matchLabels:
      app: debug-app
  template:
    metadata:
      labels:
        app: debug-app
    spec:
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: data
          mountPath: /usr/share/nginx/html
        # Deliberately problematic readiness probe
        readinessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 100Mi
EOF

echo ""
echo "🔍 Common StatefulSet Troubleshooting Commands:"

echo ""
echo "1. Check StatefulSet Status and Events"
echo "   kubectl describe statefulset debug-app"
echo "   kubectl get events --sort-by=.metadata.creationTimestamp"

echo ""
echo "2. Examine Pod Status and Logs"
echo "   kubectl get pods -l app=debug-app -o wide"
echo "   kubectl describe pod debug-app-0"
echo "   kubectl logs debug-app-0 --previous"  # Previous container logs if crashed

echo ""
echo "3. Check Persistent Volume Claims"
echo "   kubectl get pvc -l app=debug-app"
echo "   kubectl describe pvc data-debug-app-0"

echo ""
echo "4. Verify Service and DNS Resolution"
echo "   kubectl get svc debug-headless"
echo "   kubectl run dns-test --image=busybox --rm -it --restart=Never -- nslookup debug-headless"

echo ""
echo "🚨 Common Issues and Solutions:"

echo ""
echo "Issue 1: Pods Stuck in Pending State"
echo "Causes:"
echo "  • Insufficient cluster resources"
echo "  • Storage class issues"
echo "  • Node affinity/anti-affinity constraints"
echo "  • PVC binding failures"
echo ""
echo "Diagnostic commands:"
kubectl get pods -l app=debug-app
kubectl describe pod debug-app-0 | grep -A 10 "Events:"

echo ""
echo "Issue 2: Pods Stuck in Init or CrashLoopBackOff"
echo "Causes:"
echo "  • Container image issues"
echo "  • Configuration errors"
echo "  • Resource constraints"
echo "  • Failed health checks"

# Let's wait and see what happens with our problematic StatefulSet
sleep 30
kubectl get pods -l app=debug-app

echo ""
echo "Issue 3: StatefulSet Not Scaling"
echo "Causes:"
echo "  • Previous pod not ready (OrderedReady policy)"
echo "  • Resource constraints"
echo "  • Storage provisioning failures"

echo ""
echo "🔧 Advanced Debugging Techniques:"

# Create a debug toolkit pod for troubleshooting
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: debug-toolkit
spec:
  containers:
  - name: toolkit
    image: nicolaka/netshoot
    command: ["sleep", "3600"]
    volumeMounts:
    - name: debug-tools
      mountPath: /tools
  volumes:
  - name: debug-tools
    emptyDir: {}
EOF

echo ""
echo "Debug toolkit pod created for network and system debugging"
echo "Usage: kubectl exec -it debug-toolkit -- bash"

# Function to demonstrate debugging workflow
debug_workflow() {
  echo ""
  echo "🔍 Debugging Workflow Demonstration:"
  
  # Step 1: Overall health check
  echo "Step 1: Overall StatefulSet Health"
  kubectl get statefulset debug-app -o yaml | grep -A 5 "status:"
  
  # Step 2: Pod-level analysis
  echo ""
  echo "Step 2: Pod-level Analysis"
  for pod in $(kubectl get pods -l app=debug-app -o name); do
    echo "Analyzing $pod:"
    kubectl get $pod -o jsonpath='{.status.phase}' && echo
    kubectl get $pod -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' && echo
  done
  
  # Step 3: Storage analysis
  echo ""
  echo "Step 3: Storage Analysis"
  kubectl get pvc -l app=debug-app -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,VOLUME:.spec.volumeName
  
  # Step 4: Network connectivity
  echo ""
  echo "Step 4: Network Connectivity Test"
  if kubectl get pod debug-app-0 &>/dev/null; then
    kubectl exec debug-app-0 -- wget -qO- --timeout=5 http://debug-headless/ || echo "Connection failed"
  fi
}

debug_workflow

echo ""
echo "🛠️ Fixing Common Issues:"

# Fix the readiness probe issue
echo "Fixing readiness probe issue..."
kubectl patch statefulset debug-app -p '{"spec":{"template":{"spec":{"containers":[{"name":"app","readinessProbe":{"httpGet":{"path":"/","port":80}}}]}}}}'

echo "Waiting for fix to take effect..."
sleep 60

echo ""
echo "✅ After fix - checking status:"
kubectl get pods -l app=debug-app

echo ""
echo "🎓 StatefulSet Troubleshooting Summary:"
echo "   • Always check events first: kubectl get events"
echo "   • Examine pod describe output for detailed error information"
echo "   • Verify storage provisioning and binding"
echo "   • Test network connectivity and DNS resolution"
echo "   • Check resource constraints and limits"
echo "   • Use debug pods for network and system troubleshooting"
echo "   • Remember StatefulSets have ordered dependencies"

# Cleanup
kubectl delete statefulset debug-app
kubectl delete service debug-headless
kubectl delete pod debug-toolkit
kubectl delete pvc -l app=debug-app
```

## StatefulSet Scaling and Migration Strategies

Scaling StatefulSets requires careful consideration of data consistency and application-specific requirements.

```bash
#!/bin/bash
# StatefulSet Scaling and Migration Strategies
# This script demonstrates safe scaling and migration techniques

echo "📈 StatefulSet Scaling and Migration Strategies"

# Create a sample application to demonstrate scaling
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: scaling-demo-headless
spec:
  ports:
  - port: 6379
  clusterIP: None
  selector:
    app: scaling-demo
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis-cluster
spec:
  serviceName: scaling-demo-headless
  replicas: 3
  selector:
    matchLabels:
      app: scaling-demo
  template:
    metadata:
      labels:
        app: scaling-demo
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        command: ["redis-server"]
        args: ["--appendonly", "yes", "--appendfsync", "everysec"]
        ports:
        - containerPort: 6379
        volumeMounts:
        - name: data
          mountPath: /data
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 1Gi
EOF

echo "⏳ Waiting for initial deployment..."
kubectl wait --for=condition=ready pod -l app=scaling-demo --timeout=300s

echo ""
echo "✅ Initial deployment complete"
kubectl get statefulset redis-cluster
kubectl get pods -l app=scaling-demo

# Add some test data
echo ""
echo "📝 Adding test data to demonstrate persistence during scaling..."
for i in {0..2}; do
  kubectl exec redis-cluster-$i -- redis-cli set "key-$i" "data-from-redis-$i"
  kubectl exec redis-cluster-$i -- redis-cli set "shared-key" "updated-by-redis-$i"
done

echo ""
echo "🔍 Current data state:"
for i in {0..2}; do
  echo "redis-cluster-$i data:"
  kubectl exec redis-cluster-$i -- redis-cli get "key-$i"
done

echo ""
echo "📈 Safe Scaling Up Procedure:"
echo "1. Pre-scaling health check"
echo "2. Scale up gradually"
echo "3. Verify new pods"
echo "4. Test functionality"

# Pre-scaling health check
echo ""
echo "Step 1: Pre-scaling health check"
kubectl get statefulset redis-cluster -o jsonpath='{.status.readyReplicas}' && echo " ready replicas"
kubectl get pvc -l app=scaling-demo --no-headers | wc -l && echo " persistent volume claims"

# Scale up
echo ""
echo "Step 2: Scaling up to 5 replicas"
kubectl scale statefulset redis-cluster --replicas=5

# Monitor scaling progress
echo ""
echo "Step 3: Monitoring scaling progress..."
echo "Pods will be created in order: redis-cluster-3, then redis-cluster-4"

# Watch the scaling (with timeout)
timeout 180s kubectl get pods -l app=scaling-demo -w &
WATCH_PID=$!
sleep 120
kill $WATCH_PID 2>/dev/null

echo ""
echo "Step 4: Verifying new pods and testing functionality"
kubectl get pods -l app=scaling-demo
kubectl get pvc -l app=scaling-demo

# Test new pods
echo ""
echo "Testing new pods:"
for i in {3..4}; do
  if kubectl get pod redis-cluster-$i &>/dev/null; then
    kubectl exec redis-cluster-$i -- redis-cli set "key-$i" "data-from-new-redis-$i"
    kubectl exec redis-cluster-$i -- redis-cli get "key-$i"
  fi
done

echo ""
echo "📉 Safe Scaling Down Procedure:"
echo "1. Backup critical data from pods to be removed"
echo "2. Drain connections from high-ordinal pods"
echo "3. Scale down gradually"
echo "4. Verify remaining pods"

# Demonstrate data backup before scaling down
echo ""
echo "Step 1: Backing up data from pods that will be removed"
echo "In production, you would backup data from redis-cluster-4 and redis-cluster-3"

# For demo, just show what data exists
for i in {3..4}; do
  if kubectl get pod redis-cluster-$i &>/dev/null; then
    echo "Data in redis-cluster-$i:"
    kubectl exec redis-cluster-$i -- redis-cli keys "*" | head -5
  fi
done

echo ""
echo "Step 2: Scaling down to 3 replicas"
kubectl scale statefulset redis-cluster --replicas=3

echo ""
echo "Step 3: Monitoring scale-down (pods terminate in reverse order)"
timeout 60s kubectl get pods -l app=scaling-demo -w &
WATCH_PID=$!
sleep 45
kill $WATCH_PID 2>/dev/null

echo ""
echo "Step 4: Verifying remaining pods"
kubectl get pods -l app=scaling-demo
kubectl get pvc -l app=scaling-demo

# Verify original data is still there
echo ""
echo "✅ Verifying original data persistence:"
for i in {0..2}; do
  echo "redis-cluster-$i still has:"
  kubectl exec redis-cluster-$i -- redis-cli get "key-$i"
done

echo ""
echo "🔄 StatefulSet Migration Strategies:"

# Demonstrate blue-green migration
echo ""
echo "Blue-Green Migration Example:"
echo "This approach creates a new StatefulSet alongside the old one"

cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: redis-green-headless
spec:
  ports:
  - port: 6379
  clusterIP: None
  selector:
    app: redis-green
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis-green
spec:
  serviceName: redis-green-headless
  replicas: 3
  selector:
    matchLabels:
      app: redis-green
  template:
    metadata:
      labels:
        app: redis-green
    spec:
      containers:
      - name: redis
        image: redis:7-alpine  # Newer version
        command: ["redis-server"]
        args: ["--appendonly", "yes", "--appendfsync", "everysec"]
        ports:
        - containerPort: 6379
        volumeMounts:
        - name: data
          mountPath: /data
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 1Gi
EOF

echo "⏳ Deploying green environment..."
kubectl wait --for=condition=ready pod -l app=redis-green --timeout=300s

echo ""
echo "✅ Green environment ready"
echo "Blue environment (original):"
kubectl get pods -l app=scaling-demo

echo ""
echo "Green environment (new):"
kubectl get pods -l app=redis-green

# Data migration simulation
echo ""
echo "📦 Data Migration Simulation:"
echo "In production, you would migrate data from blue to green environment"

# Copy some data to demonstrate migration
kubectl exec redis-green-0 -- redis-cli set "migrated-key" "migrated-data"
kubectl exec redis-green-0 -- redis-cli get "migrated-key"

echo ""
echo "🎓 StatefulSet Scaling and Migration Best Practices:"
echo ""
echo "Scaling Up:"
echo "   • Always verify cluster resources before scaling"
echo "   • Monitor pod startup order and readiness"
echo "   • Test new pods thoroughly before proceeding"
echo "   • Consider application-specific clustering requirements"
echo ""
echo "Scaling Down:"
echo "   • Backup data from pods that will be removed"
echo "   • Drain connections gracefully"
echo "   • Scale down gradually to avoid service disruption"
echo "   • Verify data consistency after scaling"
echo ""
echo "Migration Strategies:"
echo "   • Blue-Green: Parallel environments with traffic switching"
echo "   • Rolling Update: Gradual replacement of pods"
echo "   • Canary: Partial traffic to new version"
echo "   • Backup and Restore: Export/import data approach"

echo ""
echo "🧹 Cleanup commands:"
echo "kubectl delete statefulset redis-cluster redis-green"
echo "kubectl delete service scaling-demo-headless redis-green-headless"
echo "kubectl delete pvc -l app=scaling-demo"
echo "kubectl delete pvc -l app=redis-green"
```

## Performance Optimization and Monitoring

StatefulSets often run performance-critical applications, making optimization and monitoring essential.

```bash
#!/bin/bash
# StatefulSet Performance Optimization and Monitoring
# This script demonstrates performance tuning and monitoring techniques

echo "⚡ StatefulSet Performance Optimization Guide"

# Create a performance-optimized StatefulSet
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: perf-demo-headless
spec:
  ports:
  - port: 5432
  clusterIP: None
  selector:
    app: perf-demo
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres-perf
spec:
  serviceName: perf-demo-headless
  replicas: 3
  selector:
    matchLabels:
      app: perf-demo
  template:
    metadata:
      labels:
        app: perf-demo
      annotations:
        # Prometheus scraping annotations
        prometheus.io/scrape: "true"
        prometheus.io/port: "9187"
        prometheus.io/path: "/metrics"
    spec:
      # Performance optimization: Pod placement
      affinity:
        # Prefer to spread pods across different nodes
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values: ["perf-demo"]
              topologyKey: kubernetes.io/hostname
      
      # Performance optimization: Priority and scheduling
      priorityClassName: high-priority
      
      containers:
      - name: postgres
        image: postgres:14
        env:
        - name: POSTGRES_PASSWORD
          value: "perf-demo-password"
        - name: POSTGRES_DB
          value: "perfdb"
        
        # Performance optimization: Resource management
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        
        ports:
        - containerPort: 5432
          name: postgres
        
        volumeMounts:
        - name: postgres-data
          mountPath: /var/lib/postgresql/data
        - name: postgres-config
          mountPath: /etc/postgresql
        
        # Performance optimization: Health checks
        readinessProbe:
          exec:
            command: ["pg_isready", "-U", "postgres"]
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        
        livenessProbe:
          exec:
            command: ["pg_isready", "-U", "postgres"]
          initialDelaySeconds: 30
          periodSeconds: 30
          timeoutSeconds: 5
          failureThreshold: 5
      
      # Monitoring sidecar container
      - name: postgres-exporter
        image: prometheuscommunity/postgres-exporter:latest
        env:
        - name: DATA_SOURCE_NAME
          value: "postgresql://postgres:perf-demo-password@localhost:5432/perfdb?sslmode=disable"
        ports:
        - containerPort: 9187
          name: metrics
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
      
      volumes:
      - name: postgres-config
        configMap:
          name: postgres-perf-config
  
  volumeClaimTemplates:
  - metadata:
      name: postgres-data
    spec:
      accessModes: ["ReadWriteOnce"]
      # Performance optimization: Storage class selection
      storageClassName: "fast-ssd"  # Use high-performance storage
      resources:
        requests:
          storage: 10Gi
EOF

# Create performance-tuned PostgreSQL configuration
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-perf-config
data:
  postgresql.conf: |
    # Performance Tuning Configuration
    
    # Memory Settings
    shared_buffers = 256MB
    effective_cache_size = 1GB
    work_mem = 4MB
    maintenance_work_mem = 64MB
    
    # Checkpoint Settings
    checkpoint_completion_target = 0.9
    wal_buffers = 16MB
    
    # Query Planner Settings
    default_statistics_target = 100
    random_page_cost = 1.1
    
    # Connection Settings
    max_connections = 100
    
    # Logging for Performance Analysis
    log_statement = 'all'
    log_duration = on
    log_min_duration_statement = 1000
    
    # Monitoring
    track_activities = on
    track_counts = on
    track_io_timing = on
EOF

# Create priority class for high-priority workloads
cat << EOF | kubectl apply -f -
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 1000
globalDefault: false
description: "High priority class for critical StatefulSet workloads"
EOF

echo "⏳ Deploying performance-optimized StatefulSet..."
kubectl wait --for=condition=ready pod -l app=perf-demo --timeout=300s

echo ""
echo "✅ Performance-optimized StatefulSet deployed"
kubectl get statefulset postgres-perf -o wide
kubectl get pods -l app=perf-demo -o wide

echo ""
echo "📊 Performance Monitoring and Metrics Collection:"

# Create a simple monitoring script
cat << 'EOF' > /tmp/monitor-statefulset.sh
#!/bin/bash
# StatefulSet Performance Monitoring Script

echo "📊 StatefulSet Performance Monitoring Dashboard"
echo "==========================================="

# Resource utilization
echo ""
echo "🔧 Resource Utilization:"
kubectl top pods -l app=perf-demo --no-headers | while read line; do
  echo "  $line"
done

# Storage utilization
echo ""
echo "💾 Storage Utilization:"
kubectl get pvc -l app=perf-demo -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,CAPACITY:.status.capacity.storage

# Pod distribution across nodes
echo ""
echo "🌐 Pod Distribution:"
kubectl get pods -l app=perf-demo -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName --no-headers

# Database-specific metrics (if accessible)
echo ""
echo "🗄️ Database Metrics:"
for pod in $(kubectl get pods -l app=perf-demo -o name | cut -d/ -f2); do
  echo "  $pod connections:"
  kubectl exec $pod -c postgres -- psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;" 2>/dev/null || echo "    Unable to connect"
done

# Performance bottlenecks check
echo ""
echo "⚠️  Performance Bottleneck Detection:"
echo "  Checking for resource constraints..."
kubectl describe pods -l app=perf-demo | grep -E "(cpu|memory)" | grep -E "(Request|Limit)" | head -6

echo ""
echo "  Recent events (last 10 minutes):"
kubectl get events --field-selector involvedObject.kind=Pod --field-selector reason!=Scheduled --sort-by=.metadata.creationTimestamp | tail -5
EOF

chmod +x /tmp/monitor-statefulset.sh
echo "Created monitoring script: /tmp/monitor-statefulset.sh"

# Run initial monitoring
echo ""
echo "🔍 Initial Performance Assessment:"
bash /tmp/monitor-statefulset.sh

echo ""
echo "📈 Performance Testing and Benchmarking:"

# Create a benchmark job
cat << EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: postgres-benchmark
spec:
  template:
    spec:
      containers:
      - name: pgbench
        image: postgres:14
        command: ["/bin/bash"]
        args:
          - -c
          - |
            echo "🚀 Starting PostgreSQL benchmark..."
            
            # Wait for database to be ready
            until pg_isready -h postgres-perf-0.perf-demo-headless -U postgres; do
              echo "Waiting for database..."
              sleep 5
            done
            
            # Initialize benchmark database
            PGPASSWORD=perf-demo-password pgbench -h postgres-perf-0.perf-demo-headless -U postgres -i -s 10 perfdb
            
            # Run benchmark
            echo "Running benchmark test..."
            PGPASSWORD=perf-demo-password pgbench -h postgres-perf-0.perf-demo-headless -U postgres -c 10 -j 2 -t 1000 perfdb
            
            echo "✅ Benchmark complete"
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      restartPolicy: Never
  backoffLimit: 3
EOF

echo "⏳ Running performance benchmark..."
kubectl wait --for=condition=complete job/postgres-benchmark --timeout=600s

echo ""
echo "📊 Benchmark Results:"
kubectl logs job/postgres-benchmark | tail -20

echo ""
echo "🎯 Performance Optimization Checklist:"
echo ""
echo "✅ Resource Management:"
echo "   • Set appropriate CPU and memory requests/limits"
echo "   • Use resource quotas to prevent resource starvation"
echo "   • Monitor resource utilization with kubectl top"
echo ""
echo "✅ Storage Optimization:"
echo "   • Choose appropriate storage classes (SSD for databases)"
echo "   • Size persistent volumes based on growth projections"
echo "   • Monitor storage I/O patterns and latency"
echo ""
echo "✅ Pod Placement:"
echo "   • Use pod anti-affinity to spread across nodes"
echo "   • Leverage node affinity for performance requirements"
echo "   • Consider topology constraints for data locality"
echo ""
echo "✅ Networking:"
echo "   • Optimize service discovery and DNS resolution"
echo "   • Use headless services for direct pod communication"
echo "   • Monitor network latency between pods"
echo ""
echo "✅ Application-Specific Tuning:"
echo "   • Configure application parameters for performance"
echo "   • Implement proper health checks to avoid cascading failures"
echo "   • Use connection pooling where applicable"
echo ""
echo "✅ Monitoring and Observability:"
echo "   • Deploy monitoring sidecars (Prometheus exporters)"
echo "   • Set up alerting for performance degradation"
echo "   • Implement distributed tracing for complex applications"

echo ""
echo "🧹 Cleanup commands:"
echo "kubectl delete statefulset postgres-perf"
echo "kubectl delete service perf-demo-headless"
echo "kubectl delete configmap postgres-perf-config"
echo "kubectl delete priorityclass high-priority"
echo "kubectl delete job postgres-benchmark"
echo "kubectl delete pvc -l app=perf-demo"
```

## Advanced StatefulSet Security Patterns

Security considerations are paramount when managing stateful applications, as they often handle sensitive data and require persistent access.

```bash
#!/bin/bash
# Advanced StatefulSet Security Patterns
# This script demonstrates comprehensive security configurations

echo "🔒 StatefulSet Security Patterns and Best Practices"

# Create comprehensive RBAC setup
cat << EOF | kubectl apply -f -
# Namespace for security demo
apiVersion: v1
kind: Namespace
metadata:
  name: secure-statefulset-demo
---
# Service account with minimal privileges
apiVersion: v1
kind: ServiceAccount
metadata:
  name: secure-db-sa
  namespace: secure-statefulset-demo
automountServiceAccountToken: false
---
# Role with minimal required permissions
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: secure-statefulset-demo
  name: secure-db-role
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["services"]
  verbs: ["get"]
---
# Role binding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: secure-db-binding
  namespace: secure-statefulset-demo
subjects:
- kind: ServiceAccount
  name: secure-db-sa
  namespace: secure-statefulset-demo
roleRef:
  kind: Role
  name: secure-db-role
  apiGroup: rbac.authorization.k8s.io
EOF

# Create secrets for sensitive configuration
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
  namespace: secure-statefulset-demo
type: Opaque
data:
  # Base64 encoded: admin
  username: YWRtaW4=
  # Base64 encoded: supersecretpassword123
  password: c3VwZXJzZWNyZXRwYXNzd29yZDEyMw==
  # Base64 encoded database connection string
  connection-string: cG9zdGdyZXNxbDovL2FkbWluOnN1cGVyc2VjcmV0cGFzc3dvcmQxMjNAbG9jYWxob3N0OjU0MzIvbXlkYg==
---
apiVersion: v1
kind: Secret
metadata:
  name: tls-certificates
  namespace: secure-statefulset-demo
type: kubernetes.io/tls
data:
  # Base64 encoded certificate and key (demo purposes only)
  tls.crt: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t...
  tls.key: LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0t...
EOF

# Create network policies for traffic isolation
cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: secure-db-network-policy
  namespace: secure-statefulset-demo
spec:
  podSelector:
    matchLabels:
      app: secure-db
  policyTypes:
  - Ingress
  - Egress
  ingress:
  # Allow connections only from pods with specific labels
  - from:
    - podSelector:
        matchLabels:
          role: db-client
    ports:
    - protocol: TCP
      port: 5432
  # Allow monitoring connections
  - from:
    - podSelector:
        matchLabels:
          role: monitoring
    ports:
    - protocol: TCP
      port: 9187
  egress:
  # Allow DNS resolution
  - to: []
    ports:
    - protocol: UDP
      port: 53
  # Allow connections to other database replicas
  - to:
    - podSelector:
        matchLabels:
          app: secure-db
    ports:
    - protocol: TCP
      port: 5432
EOF

# Create Pod Security Policy (if supported) or Pod Security Standards
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata