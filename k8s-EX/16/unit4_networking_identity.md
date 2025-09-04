# Unit 4: Networking and Identity - Stable Network Identity Deep Dive

## Learning Objectives
By the end of this unit, you will:
- Master headless services and understand their critical role in StatefulSets
- Configure and troubleshoot stable DNS naming for stateful applications
- Implement service discovery patterns for clustered applications
- Design networking strategies for multi-tier stateful architectures
- Understand load balancing considerations for stateful vs stateless workloads

## Pre-Unit Networking Foundation Check

Let's establish your current networking knowledge before diving into StatefulSet-specific concepts:

**Quick Knowledge Check:**
```bash
# Test your understanding of basic Kubernetes networking
kubectl run network-test --image=busybox:1.35 --restart=Never -it -- sh

# Inside the pod, try these commands:
nslookup kubernetes.default.svc.cluster.local
nslookup google.com
exit

kubectl delete pod network-test
```

**Reflection Questions:**
- What did the DNS lookups tell you about how pods resolve names?
- How do you think a database replica might find its primary server?
- What challenges would arise if database server names changed frequently?

## Discovery Lab: The Problem with Regular Services

Let's start by experiencing why regular services don't work for stateful applications that need to address individual pods.

### Experiment 1: Regular Service Behavior

```bash
# Create a Deployment with a regular service
kubectl create deployment web-demo --image=nginx:alpine --replicas=3

# Create a regular (ClusterIP) service
kubectl expose deployment web-demo --port=80 --target-port=80 --name=web-service

# Test the service behavior
kubectl get pods -l app=web-demo -o wide
kubectl get service web-service
```

Now let's see how the service behaves:

```bash
# Create a test pod to explore DNS behavior
kubectl run dns-explorer --image=busybox:1.35 --restart=Never -it -- sh

# Inside the test pod:
nslookup web-service.default.svc.cluster.local
# This returns the service's cluster IP

# Try to resolve individual pod names
nslookup web-demo-xxxxx-xxxxx.default.svc.cluster.local
# Replace xxxxx with actual pod name - this will fail!

exit
```

**Critical Discovery:**
- What IP did the service DNS lookup return?
- Could you resolve individual pod names?
- How would this impact a database cluster where replicas need to connect to a specific primary?

### Experiment 2: The Headless Service Solution

```bash
# Clean up the regular service
kubectl delete service web-service

# Create a headless service
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: web-headless
  labels:
    app: web-demo
spec:
  clusterIP: None  # This makes it headless!
  selector:
    app: web-demo
  ports:
  - port: 80
    name: web
EOF

# Test the headless service behavior
kubectl run dns-explorer --image=busybox:1.35 --restart=Never -it -- sh

# Inside the test pod:
nslookup web-headless.default.svc.cluster.local
# Notice the difference - you get multiple IPs!

exit
```

**Analysis Questions:**
- How did the DNS response change with the headless service?
- What advantage does getting multiple IP addresses provide?
- Why is this still not sufficient for StatefulSet needs?

## StatefulSet Networking Deep Dive

Now let's see how StatefulSets build on headless services to provide stable, individual pod identity.

### Lab: Complete StatefulSet Networking

```bash
# Clean up previous experiments
kubectl delete deployment web-demo
kubectl delete service web-headless
kubectl delete pod dns-explorer --ignore-not-found=true

# Create a complete StatefulSet with headless service
cat << EOF | kubectl apply -f -
# Headless service - enables individual pod DNS names
apiVersion: v1
kind: Service
metadata:
  name: web
  labels:
    app: web-stateful
spec:
  clusterIP: None
  selector:
    app: web-stateful
  ports:
  - port: 80
    name: web
---
# StatefulSet that uses the headless service
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: "web"  # Critical: links to headless service
  replicas: 3
  selector:
    matchLabels:
      app: web-stateful
  template:
    metadata:
      labels:
        app: web-stateful
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
          name: web
        # Create unique content for each pod
        command: ["/bin/sh"]
        args: ["-c", "echo 'Hello from '$(hostname) > /usr/share/nginx/html/index.html && nginx -g 'daemon off;'"]
EOF

# Wait for pods to be ready
kubectl wait --for=condition=Ready pod -l app=web-stateful --timeout=120s
```

### Networking Exploration: Individual Pod Identity

```bash
# Check the pod names - notice the predictable pattern
kubectl get pods -l app=web-stateful

# Test individual pod DNS resolution
kubectl run dns-explorer --image=busybox:1.35 --restart=Never -it -- sh

# Inside the test pod, test each type of DNS resolution:

# 1. Individual pod DNS names
nslookup web-0.web.default.svc.cluster.local
nslookup web-1.web.default.svc.cluster.local  
nslookup web-2.web.default.svc.cluster.local

# 2. Headless service (returns all pod IPs)
nslookup web.default.svc.cluster.local

# 3. Test connectivity to individual pods
wget -qO- web-0.web.default.svc.cluster.local
wget -qO- web-1.web.default.svc.cluster.local
wget -qO- web-2.web.default.svc.cluster.local

exit
```

**Key Insights:**
- What pattern do the individual pod DNS names follow?
- How do the responses differ between individual pods and the headless service?
- Why is this stable naming crucial for stateful applications?

### Persistence of Network Identity

Let's verify that network identity persists across pod lifecycle events:

```bash
# Record current pod information
echo "Before pod deletion:"
kubectl get pods -l app=web-stateful -o wide

# Delete web-1 to simulate a failure
kubectl delete pod web-1

# Watch the replacement process
kubectl get pods -l app=web-stateful -w
# Press Ctrl+C after web-1 is running again

# Test DNS resolution again
kubectl run dns-test --image=busybox:1.35 --restart=Never -it -- sh

# Inside the pod:
nslookup web-1.web.default.svc.cluster.local
wget -qO- web-1.web.default.svc.cluster.local

exit
```

**Critical Analysis:**
- Did web-1 get the same name after recreation?
- Does the DNS name still resolve correctly?
- How does this behavior differ from Deployment pod replacement?

## Real-World Application: Database Cluster Networking

Let's implement a realistic database cluster scenario that demonstrates why stable networking is essential.

### Lab: MySQL Cluster with Service Discovery

```bash
# Clean up previous test
kubectl delete pod dns-explorer dns-test --ignore-not-found=true

# Create a MySQL cluster that demonstrates inter-pod communication
cat << EOF | kubectl apply -f -
# Headless service for MySQL cluster
apiVersion: v1
kind: Service
metadata:
  name: mysql-cluster
  labels:
    app: mysql-cluster
spec:
  clusterIP: None
  selector:
    app: mysql-cluster
  ports:
  - port: 3306
    name: mysql
---
# ConfigMap with cluster discovery script
apiVersion: v1
kind: ConfigMap
metadata:
  name: mysql-cluster-config
data:
  discover-cluster.sh: |
    #!/bin/bash
    echo "=== MySQL Cluster Discovery ==="
    echo "My hostname: $(hostname)"
    echo "My FQDN: $(hostname -f)"
    echo ""
    echo "Discovering cluster members:"
    
    # Try to resolve each potential cluster member
    for i in {0..2}; do
      host="mysql-cluster-$i.mysql-cluster.default.svc.cluster.local"
      if nslookup "$host" > /dev/null 2>&1; then
        echo "  ✓ Found cluster member: $host"
        # In a real MySQL cluster, this is where you'd add replication setup
      else
        echo "  ✗ Cluster member not found: $host"
      fi
    done
    
    echo ""
    echo "=== Service Discovery Test ==="
    nslookup mysql-cluster.default.svc.cluster.local
    echo ""
    echo "Ready to start MySQL with cluster awareness!"
---
# MySQL StatefulSet with cluster discovery
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql-cluster
spec:
  serviceName: mysql-cluster
  replicas: 3
  selector:
    matchLabels:
      app: mysql-cluster
  template:
    metadata:
      labels:
        app: mysql-cluster
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: "cluster-password"
        - name: MYSQL_DATABASE
          value: "clusterdb"
        ports:
        - containerPort: 3306
          name: mysql
        # Run discovery script on startup
        lifecycle:
          postStart:
            exec:
              command: ["/bin/bash", "/scripts/discover-cluster.sh"]
        volumeMounts:
        - name: cluster-scripts
          mountPath: /scripts
      volumes:
      - name: cluster-scripts
        configMap:
          name: mysql-cluster-config
          defaultMode: 0755
EOF

# Wait for the cluster to start
kubectl wait --for=condition=Ready pod -l app=mysql-cluster --timeout=180s
```

### Cluster Discovery Analysis

```bash
# Check the logs to see cluster discovery in action
echo "=== mysql-cluster-0 discovery logs ==="
kubectl logs mysql-cluster-0 --tail=20

echo "=== mysql-cluster-1 discovery logs ==="  
kubectl logs mysql-cluster-1 --tail=20

echo "=== mysql-cluster-2 discovery logs ==="
kubectl logs mysql-cluster-2 --tail=20
```

**Analysis Questions:**
- How does each pod discover the other members of the cluster?
- What would happen if pod names weren't stable?
- How might this discovery process work in a real MySQL replication setup?

### Testing Network Stability Under Stress

```bash
# Simulate various failure scenarios to test network stability
echo "Testing network identity persistence..."

# Test 1: Delete multiple pods simultaneously
kubectl delete pod mysql-cluster-0 mysql-cluster-1

# Watch them restart with same identities
kubectl get pods -l app=mysql-cluster -w
# Press Ctrl+C after both pods are running

# Test 2: Scale down and up to test identity persistence
kubectl scale statefulset mysql-cluster --replicas=1
kubectl get pods -l app=mysql-cluster

kubectl scale statefulset mysql-cluster --replicas=3
kubectl wait --for=condition=Ready pod -l app=mysql-cluster --timeout=180s

# Verify network identity is maintained
kubectl exec mysql-cluster-0 -- nslookup mysql-cluster-0.mysql-cluster.default.svc.cluster.local
kubectl exec mysql-cluster-2 -- nslookup mysql-cluster-2.mysql-cluster.default.svc.cluster.local
```

**Resilience Analysis:**
- Did pods maintain their network identities through failures?
- How quickly do DNS records update when pods restart?
- What implications does this have for application connection handling?

## Advanced Networking Patterns

Now let's explore sophisticated networking patterns used in production stateful applications.

### Pattern 1: Primary/Replica Discovery and Routing

```bash
# Create services that distinguish between primary and replica roles
cat << EOF | kubectl apply -f -
# Service for primary (read/write operations)
apiVersion: v1
kind: Service
metadata:
  name: mysql-primary
  labels:
    app: mysql-cluster
    role: primary
spec:
  selector:
    app: mysql-cluster
    statefulset.kubernetes.io/pod-name: mysql-cluster-0  # Always route to pod-0
  ports:
  - port: 3306
    name: mysql
---
# Service for replicas (read-only operations)  
apiVersion: v1
kind: Service
metadata:
  name: mysql-replicas
  labels:
    app: mysql-cluster
    role: replica
spec:
  selector:
    app: mysql-cluster
  ports:
  - port: 3306
    name: mysql
---
# Headless service for cluster internal communication
apiVersion: v1
kind: Service
metadata:
  name: mysql-internal
  labels:
    app: mysql-cluster
    role: internal
spec:
  clusterIP: None
  selector:
    app: mysql-cluster
  ports:
  - port: 3306
    name: mysql
EOF
```

### Testing Multi-Service Architecture

```bash
# Test different service endpoints
kubectl run mysql-client --image=mysql:8.0 --restart=Never -it -- bash

# Inside the client pod:
# Test primary connection (should go to mysql-cluster-0)
mysql -h mysql-primary.default.svc.cluster.local -u root -pcluster-password -e "SELECT @@hostname;"

# Test replica connection (load balances across all pods)
mysql -h mysql-replicas.default.svc.cluster.local -u root -pcluster-password -e "SELECT @@hostname;"

# Test internal cluster communication
nslookup mysql-internal.default.svc.cluster.local

exit
```

**Architecture Questions:**
- How does this service architecture support read/write splitting?
- What are the benefits of having separate services for different roles?
- How might client applications use these different endpoints?

### Pattern 2: Cross-Namespace Service Discovery

```bash
# Create a separate namespace for application clients
kubectl create namespace app-clients

# Create a client that needs to connect to the database cluster
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: app-clients
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: app
        image: busybox:1.35
        command: ["sleep", "3600"]
EOF

# Test cross-namespace service discovery
kubectl exec -n app-clients deployment/web-app -- nslookup mysql-primary.default.svc.cluster.local
kubectl exec -n app-clients deployment/web-app -- nslookup mysql-cluster-0.mysql-cluster.default.svc.cluster.local
```

**Cross-Namespace Analysis:**
- How do clients in different namespaces discover stateful services?
- What security implications exist for cross-namespace service access?
- How might you structure service discovery in a multi-tenant environment?

## Load Balancing Strategies for Stateful Applications

Unlike stateless applications, stateful applications often need specialized load balancing approaches.

### Lab: Understanding Load Balancing Differences

```bash
# Create a load balancing comparison test
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: load-balance-test
data:
  test-connections.sh: |
    #!/bin/bash
    echo "=== Testing Load Balancing Behavior ==="
    
    echo "1. Headless service (mysql-internal) - returns all pod IPs:"
    nslookup mysql-internal.default.svc.cluster.local
    
    echo ""
    echo "2. Regular service (mysql-replicas) - returns single VIP:"
    nslookup mysql-replicas.default.svc.cluster.local
    
    echo ""
    echo "3. Testing actual connections to see load balancing:"
    for i in {1..6}; do
      echo -n "Connection $i: "
      mysql -h mysql-replicas.default.svc.cluster.local -u root -pcluster-password -e "SELECT @@hostname;" 2>/dev/null | tail -n1
      sleep 1
    done
    
    echo ""
    echo "4. Direct pod connections (always consistent):"
    for i in {0..2}; do
      echo -n "mysql-cluster-$i: "
      mysql -h mysql-cluster-$i.mysql-internal.default.svc.cluster.local -u root -pcluster-password -e "SELECT @@hostname;" 2>/dev/null | tail -n1
    done
---
apiVersion: batch/v1
kind: Job
metadata:
  name: load-balance-test
spec:
  template:
    spec:
      containers:
      - name: test
        image: mysql:8.0
        command: ["/bin/bash", "/scripts/test-connections.sh"]
        volumeMounts:
        - name: test-script
          mountPath: /scripts
      volumes:
      - name: test-script
        configMap:
          name: load-balance-test
          defaultMode: 0755
      restartPolicy: Never
EOF

# Wait for the job to complete and check results
kubectl wait --for=condition=complete job/load-balance-test --timeout=60s
kubectl logs job/load-balance-test
```

**Load Balancing Analysis:**
- How does load balancing differ between the headless and regular services?
- When would you want load balancing vs direct pod addressing?
- What are the implications for database connections and session affinity?

## Production Networking Patterns

Let's implement a comprehensive networking strategy for a real-world stateful application.

### Complete Example: Distributed Cache Cluster

```bash
# Clean up test resources
kubectl delete job load-balance-test
kubectl delete configmap load-balance-test
kubectl delete pod mysql-client --ignore-not-found=true

# Create a Redis cluster with comprehensive networking
cat << EOF | kubectl apply -f -
# Internal headless service for cluster formation
apiVersion: v1
kind: Service
metadata:
  name: redis-cluster-internal
  labels:
    app: redis-cluster
    tier: cache
spec:
  clusterIP: None
  selector:
    app: redis-cluster
  ports:
  - port: 6379
    name: redis
  - port: 16379
    name: cluster-bus
---
# External service for client connections
apiVersion: v1
kind: Service
metadata:
  name: redis-cluster
  labels:
    app: redis-cluster
    tier: cache
spec:
  type: ClusterIP
  selector:
    app: redis-cluster
  ports:
  - port: 6379
    name: redis
---
# Redis cluster StatefulSet
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis-cluster
  labels:
    app: redis-cluster
    tier: cache
spec:
  serviceName: redis-cluster-internal
  replicas: 6  # Typical Redis cluster: 3 masters + 3 replicas
  selector:
    matchLabels:
      app: redis-cluster
  template:
    metadata:
      labels:
        app: redis-cluster
        tier: cache
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
          name: redis
        - containerPort: 16379
          name: cluster-bus
        command:
        - redis-server
        - /etc/redis/redis.conf
        - --cluster-enabled
        - yes
        - --cluster-node-timeout
        - "5000"
        - --cluster-announce-hostname
        - $(hostname).redis-cluster-internal.default.svc.cluster.local
        env:
        - name: POD_IP
          valueFrom:
            fieldRef:
              fieldPath: status.podIP
        volumeMounts:
        - name: redis-config
          mountPath: /etc/redis
        - name: redis-data
          mountPath: /data
      volumes:
      - name: redis-config
        configMap:
          name: redis-cluster-config
  volumeClaimTemplates:
  - metadata:
      name: redis-data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 1Gi
---
# Redis configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-cluster-config
data:
  redis.conf: |
    bind 0.0.0.0
    port 6379
    cluster-enabled yes
    cluster-config-file nodes.conf
    cluster-node-timeout 5000
    appendonly yes
    appendfsync everysec
    save 900 1
    save 300 10
    save 60 10000
EOF

# Wait for Redis pods to start
kubectl wait --for=condition=Ready pod -l app=redis-cluster --timeout=180s
```

### Redis Cluster Network Analysis

```bash
# Test the networking setup
echo "=== Redis Cluster Network Analysis ==="

# Check pod DNS resolution
echo "1. Individual pod DNS names:"
for i in {0..2}; do
  echo "  redis-cluster-$i.redis-cluster-internal.default.svc.cluster.local"
  kubectl exec redis-cluster-0 -- nslookup redis-cluster-$i.redis-cluster-internal.default.svc.cluster.local
done

# Test cluster bus communication
echo "2. Testing Redis cluster discovery:"
kubectl exec redis-cluster-0 -- redis-cli cluster nodes

# Test client connectivity
echo "3. Testing client connections:"
kubectl run redis-client --image=redis:7-alpine --restart=Never -it -- bash

# Inside the client:
redis-cli -h redis-cluster.default.svc.cluster.local ping
redis-cli -h redis-cluster-0.redis-cluster-internal.default.svc.cluster.local ping
exit
```

**Network Architecture Analysis:**
- How does the dual-service approach (internal + external) benefit the Redis cluster?
- Why are stable hostnames important for Redis cluster formation?
- How does this pattern apply to other distributed systems?

## Unit Challenge: Design a Complete Multi-Tier Network Architecture

Design and implement a comprehensive networking solution for a realistic three-tier application:

**Architecture Requirements:**
1. **Web Tier**: Stateless frontend (Deployment + Service)
2. **API Tier**: Stateless backend (Deployment + Service)  
3. **Data Tier**: Stateful database cluster (StatefulSet + multiple services)

**Networking Requirements:**
- Web tier needs load balancing across all instances
- API tier needs service discovery and load balancing
- Database tier needs:
  - Individual pod addressing for cluster coordination
  - Primary/replica routing for read/write splitting
  - Internal cluster communication for replication
- Cross-tier communication must be secure and efficient

**Challenge Template:**
```bash
cat << EOF > multi-tier-networking-challenge.yaml
# Design a complete networking solution
# Include:
# 1. Appropriate service types for each tier
# 2. Service discovery mechanisms
# 3. Network policies for security (optional advanced feature)
# 4. DNS naming strategies
# 5. Load balancing considerations

# Your complete solution here...
EOF
```

**Validation Criteria:**
1. Deploy the entire stack and verify connectivity between tiers
2. Demonstrate primary/replica routing in the database tier
3. Test service discovery from web tier to database tier
4. Simulate failures and verify network stability
5. Document your design decisions and trade-offs

## Troubleshooting Network Issues

### Common Networking Problems and Solutions

```bash
# Problem 1: Pod can't resolve headless service DNS
# Diagnosis commands:
kubectl exec <pod-name> -- nslookup <service-name>
kubectl describe service <service-name>
kubectl get endpoints <service-name>

# Problem 2: Intermittent connection failures
# Check service endpoint consistency:
kubectl get endpoints <service-name> -w

# Problem 3: DNS resolution delays
# Test DNS performance:
kubectl exec <pod-name> -- time nslookup <service-name>
```

### Network Troubleshooting Lab

```bash
# Create a problematic configuration to practice troubleshooting
cat << EOF | kubectl apply -f -
# Intentionally problematic StatefulSet
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: broken-network
spec:
  serviceName: nonexistent-service  # This will cause problems
  replicas: 2
  selector:
    matchLabels:
      app: broken-network
  template:
    metadata:
      labels:
        app: broken-network
    spec:
      containers:
      - name: app
        image: busybox:1.35
        command: ["sleep", "3600"]
EOF

# Practice troubleshooting:
kubectl get statefulset broken-network
kubectl describe statefulset broken-network
kubectl get pods -l app=broken-network
# What problems do you identify?
# How would you fix them?
```

## Cleanup and Unit Summary

```bash
# Clean up all resources created in this unit
kubectl delete statefulset web mysql-cluster redis-cluster broken-network --ignore-not-found=true
kubectl delete service web mysql-cluster mysql-primary mysql-replicas mysql-internal redis-cluster redis-cluster-internal --ignore-not-found=true
kubectl delete configmap mysql-cluster-config redis-cluster-config --ignore-not-found=true
kubectl delete namespace app-clients --ignore-not-found=true
kubectl delete pod redis-client --ignore-not-found=true

# Clean up any remaining PVCs if desired
kubectl get pvc
# kubectl delete pvc <pvc-names> # if you want to clean up storage
```

## Unit Summary

### Key Concepts Mastered:
- **Headless Services**: How `clusterIP: None` enables individual pod DNS resolution
- **Stable Network Identity**: DNS naming patterns for StatefulSet pods
- **Service Discovery**: Methods for pods to find and communicate with cluster members
- **Multi-Service Patterns**: Using different services for different access patterns
- **Load Balancing Strategy**: When to use load balancing vs direct pod addressing

### Production-Ready Patterns:
- Primary/replica service splitting for read/write workload distribution
- Internal vs external service separation for security and performance
- Cross-namespace service discovery for multi-tier architectures
- Network troubleshooting and diagnostic techniques
- Distributed system networking patterns (cluster formation, leader election)

### Skills Developed:
- Configuring headless services for StatefulSet networking
- Designing multi-service architectures for complex stateful applications
- Implementing service discovery patterns for clustered applications
- Troubleshooting DNS and connectivity issues in Kubernetes
- Understanding load balancing implications for stateful vs stateless workloads

### Real-World Applications:
- Database cluster networking (MySQL, PostgreSQL, MongoDB)
- Distributed cache systems (Redis, Memcached)
- Message queue clusters (Kafka, RabbitMQ)
- Distributed coordination systems (etcd, Zookeeper)
- Any clustered application requiring stable network identity

### Looking Ahead to Unit 5:
In Unit 5, we'll focus on production operations for StatefulSets. You'll learn advanced scaling strategies, rolling update patterns, backup and recovery procedures, monitoring and alerting, and troubleshooting complex operational scenarios. We'll also cover disaster recovery and high availability patterns for mission-critical stateful applications.

**Preparation Questions for Unit 5:**
- How would you safely update a database cluster without downtime?
- What monitoring metrics would be most important for stateful applications?
- How might backup and recovery differ between stateful and stateless applications?
- What challenges exist when scaling stateful applications compared to stateless ones?

**Key Networking Takeaways:**
Stable network identity is fundamental to stateful applications. The patterns you've learned—headless services, stable DNS naming, and service discovery—form the foundation for building reliable distributed systems. Remember that networking failures in stateful applications often have more severe consequences than in stateless applications, so robust design and thorough testing are essential.