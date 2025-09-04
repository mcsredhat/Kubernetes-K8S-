# Complete Kubernetes Services Guide: From Foundation to Mastery

Think of a bustling city where buildings are constantly being demolished and rebuilt, streets are being rerouted, and the entire layout changes daily. Yet somehow, the postal service still delivers mail reliably to every address. This is the magic of Kubernetes Services - they provide persistent addresses in a world of constant change, ensuring your applications can always find each other no matter how the underlying infrastructure shifts.

In this comprehensive guide, you'll progress from understanding the fundamental networking challenges to building sophisticated service architectures. Each section includes hands-on labs, progressive demos, and real-world mini-projects that build on previous concepts. By the end, you'll have the practical skills to design and troubleshoot complex service meshes in production environments.

## 🎯 Learning Journey Overview

**Foundation Level** (Sections 1-3): Understanding the core problems Services solve and basic connectivity patterns
**Intermediate Level** (Sections 4-6): Exploring different Service types, advanced configurations, and debugging techniques  
**Advanced Level** (Sections 7-9): Building production-ready architectures with security, monitoring, and performance optimization

---

## FOUNDATION LEVEL (Sections 1-3)

## Section 1: The Networking Challenge - Why Services Matter

Before diving into Services, let's experience the fundamental problem they solve. This hands-on exploration will help you viscerally understand why Services are essential, not just conceptually know it.

### Lab 1.1: Experiencing Pod Network Volatility

Let's start by witnessing the chaotic nature of pod networking firsthand. This lab will show you exactly why direct pod connections are unreliable.

```bash
# Create a simple deployment to observe pod behavior
kubectl create deployment network-demo --image=nginx --replicas=2

# Watch the pods and their IP addresses
kubectl get pods -l app=network-demo -o wide --watch &
WATCH_PID=$!

# In another terminal, let's save the current pod IPs
kubectl get pods -l app=network-demo -o jsonpath='{.items[*].status.podIP}' > initial-ips.txt
echo "Initial pod IPs saved:"
cat initial-ips.txt

# Now let's simulate the chaos of pod lifecycle management
echo "🔥 Simulating pod restarts (watch the IPs change)..."
kubectl rollout restart deployment network-demo

# Wait for rollout to complete
kubectl rollout status deployment network-demo

# Compare the new IPs with the original ones
kubectl get pods -l app=network-demo -o jsonpath='{.items[*].status.podIP}' > new-ips.txt
echo "New pod IPs after restart:"
cat new-ips.txt

echo "IP changes:"
diff initial-ips.txt new-ips.txt || echo "IPs have changed!"

# Stop the watch process
kill $WATCH_PID 2>/dev/null || true
```

### Lab 1.2: The Fragility of Direct Pod Communication

Now let's experience what it's like to build applications that rely on direct pod IPs. This lab will demonstrate why this approach fails in real-world scenarios.

```bash
# Create a client pod that tries to connect to specific pod IPs
kubectl run fragile-client --image=busybox --restart=Never -- sleep 3600

# Get the current nginx pod IPs
NGINX_IPS=($(kubectl get pods -l app=network-demo -o jsonpath='{.items[*].status.podIP}'))
echo "Current nginx pod IPs: ${NGINX_IPS[@]}"

# Test connectivity to each pod directly
for ip in "${NGINX_IPS[@]}"; do
    echo "Testing connectivity to $ip:"
    kubectl exec fragile-client -- timeout 5 wget -qO- $ip 2>/dev/null | head -1 || echo "Failed to connect"
done

# Now let's scale up the deployment and see what happens
kubectl scale deployment network-demo --replicas=4
kubectl wait --for=condition=ready pod -l app=network-demo --timeout=60s

# Get the updated list of pod IPs
NEW_NGINX_IPS=($(kubectl get pods -l app=network-demo -o jsonpath='{.items[*].status.podIP}'))
echo "After scaling, nginx pod IPs: ${NEW_NGINX_IPS[@]}"

# Our original hardcoded IPs still work, but we're missing the new pods
echo "Testing original hardcoded IPs (missing new pods):"
for ip in "${NGINX_IPS[@]}"; do
    kubectl exec fragile-client -- timeout 5 wget -qO- $ip 2>/dev/null >/dev/null && echo "$ip: OK" || echo "$ip: Failed"
done

echo "New pod IPs that our client doesn't know about:"
for ip in "${NEW_NGINX_IPS[@]}"; do
    if [[ ! " ${NGINX_IPS[@]} " =~ " ${ip} " ]]; then
        echo "  $ip (unknown to client)"
    fi
done

# Clean up the fragile client for now
kubectl delete pod fragile-client
```

### Reflection Exercise: Understanding the Core Problem

Take a moment to think about what you just observed:
1. Pod IPs changed when pods restarted
2. New pods appeared with entirely new IPs when scaling
3. Applications connecting directly to pod IPs would break constantly
4. Manual IP management becomes impossible at scale

This experience forms the foundation for understanding why Services are not just helpful, but essential for reliable applications.

---

## Section 2: Your First Service - The Foundation

Now that you understand the problem, let's experience the solution. This section progressively builds your understanding of how Services create stability from chaos.

### Lab 2.1: Creating Your First Service - Observing the Transformation

Let's create a Service and witness how it transforms the networking landscape you just explored.

```bash
# Using the same deployment from before, let's expose it through a Service
kubectl expose deployment network-demo --port=80 --name=stable-service

# Examine what was created - notice the stable IP address
echo "🎯 Service created with stable endpoint:"
kubectl get service stable-service -o wide
SERVICE_IP=$(kubectl get service stable-service -o jsonpath='{.spec.clusterIP}')
echo "Service IP: $SERVICE_IP (this will never change)"

# Compare this with the volatile pod IPs
echo "📱 Current pod IPs (these change constantly):"
kubectl get pods -l app=network-demo -o jsonpath='{.items[*].status.podIP}' | tr ' ' '\n'

# Create a client to test the stable service
kubectl run stable-client --image=busybox --restart=Never -- sleep 3600

# Test connectivity through the Service
echo "🔗 Testing connectivity through stable Service:"
kubectl exec stable-client -- wget -qO- $SERVICE_IP 2>/dev/null | head -1

# Now let's see the magic - restart pods while keeping service connectivity
echo "🔄 Restarting pods while Service remains accessible:"
kubectl rollout restart deployment network-demo &

# Test Service connectivity during the restart
for i in {1..10}; do
    echo "Test $i during restart:"
    kubectl exec stable-client -- timeout 3 wget -qO- $SERVICE_IP 2>/dev/null | head -1 || echo "Temporary disruption"
    sleep 2
done

# Wait for rollout to complete
kubectl rollout status deployment network-demo

# Verify Service still works with completely new pods
echo "✅ Final connectivity test with new pods:"
kubectl exec stable-client -- wget -qO- $SERVICE_IP 2>/dev/null | head -1
```

### Lab 2.2: Understanding Service Discovery Through DNS

Services become even more powerful when you don't need to remember IP addresses. Let's explore DNS-based service discovery.

```bash
# Test DNS resolution for our Service
echo "🌐 DNS Magic - Services as Names, Not Numbers:"
kubectl exec stable-client -- nslookup stable-service
echo

# Test connectivity using the service name instead of IP
echo "🔗 Connecting by name instead of IP address:"
kubectl exec stable-client -- wget -qO- stable-service 2>/dev/null | head -1

# Explore the full DNS structure
echo "🌐 Complete DNS namespace exploration:"
kubectl exec stable-client -- nslookup stable-service.default.svc.cluster.local

# Create services in different namespaces to understand DNS scope
kubectl create namespace dns-demo
kubectl create deployment cross-ns-app --image=httpd --namespace=dns-demo
kubectl expose deployment cross-ns-app --port=80 --name=cross-ns-service --namespace=dns-demo

echo "🌉 Cross-namespace DNS resolution:"
kubectl exec stable-client -- nslookup cross-ns-service.dns-demo.svc.cluster.local
kubectl exec stable-client -- timeout 5 wget -qO- cross-ns-service.dns-demo.svc.cluster.local 2>/dev/null | head -1 || echo "Cross-namespace connection works!"
```

### Mini-Project 2.1: Building a Simple Microservice Architecture

Let's apply what you've learned by building a complete microservice application with proper service discovery.

```yaml
# Create microservice-foundation.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: microservice-demo
---
# Frontend service that will call the backend
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: microservice-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
      tier: web
  template:
    metadata:
      labels:
        app: frontend
        tier: web
    spec:
      containers:
      - name: frontend
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: config
          mountPath: /etc/nginx/conf.d/default.conf
          subPath: nginx.conf
      volumes:
      - name: config
        configMap:
          name: frontend-config
---
# Backend API service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-api
  namespace: microservice-demo
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend-api
      tier: api
  template:
    metadata:
      labels:
        app: backend-api
        tier: api
    spec:
      containers:
      - name: api
        image: httpd:alpine
        ports:
        - containerPort: 80
        env:
        - name: POSTGRES_DB
          value: appdb
        - name: POSTGRES_USER
          value: apiuser  
        - name: POSTGRES_PASSWORD
          value: secretpass
---
# Database service
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: database
  namespace: microservice-demo
spec:
  serviceName: database-service
  replicas: 1
  selector:
    matchLabels:
      app: database
      tier: data
  template:
    metadata:
      labels:
        app: database
        tier: data
    spec:
      containers:
      - name: postgres
        image: postgres:13-alpine
        env:
        - name: POSTGRES_DB
          value: microservicedb
        - name: POSTGRES_USER
          value: apiuser
        - name: POSTGRES_PASSWORD
          value: devpassword
        ports:
        - containerPort: 5432
        readinessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - apiuser
            - -d
            - microservicedb
          initialDelaySeconds: 10
          periodSeconds: 5
---
# Services for each tier
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
  namespace: microservice-demo
spec:
  type: LoadBalancer
  selector:
    tier: web
  ports:
  - port: 80
    targetPort: 80
    name: web
---
apiVersion: v1
kind: Service
metadata:
  name: backend-api-service
  namespace: microservice-demo
spec:
  selector:
    tier: api
  ports:
  - port: 80
    targetPort: 80
    name: api
---
apiVersion: v1
kind: Service
metadata:
  name: database-service
  namespace: microservice-demo
spec:
  selector:
    tier: data
  ports:
  - port: 5432
    targetPort: 5432
    name: postgres
---
# Configuration for frontend to demonstrate service-to-service communication
apiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-config
  namespace: microservice-demo
data:
  nginx.conf: |
    server {
        listen 80;
        location / {
            return 200 '🌐 Frontend Service (connects to backend-api-service)\n';
            add_header Content-Type text/plain;
        }
        location /api {
            return 200 '🔗 API call would go to: backend-api-service:80\n';
            add_header Content-Type text/plain;
        }
        location /health {
            return 200 '✅ Frontend healthy - can reach backend-api-service and database-service\n';
            add_header Content-Type text/plain;
        }
    }
```

```bash
# Deploy the complete microservice architecture
kubectl apply -f microservice-foundation.yaml

# Wait for all components to be ready
echo "🚀 Deploying microservice architecture..."
kubectl wait --for=condition=available deployment --all -n microservice-demo --timeout=300s
kubectl wait --for=condition=ready pod -l app=database -n microservice-demo --timeout=300s

# Test the complete service discovery mesh
echo "🔍 Testing microservice communication patterns:"
kubectl run service-tester --image=busybox --rm -it --restart=Never --namespace=microservice-demo -- sh -c "
echo '🧪 Microservice Service Discovery Tests'
echo '====================================='

echo '1. DNS Resolution Tests:'
echo '   Frontend service:' && nslookup frontend-service
echo '   Backend API service:' && nslookup backend-api-service  
echo '   Database service:' && nslookup database-service

echo
echo '2. Service Connectivity Tests:'
echo '   Frontend HTTP:' && wget -qO- --timeout=5 frontend-service || echo 'Connection failed'
echo '   Backend API HTTP:' && wget -qO- --timeout=5 backend-api-service || echo 'Connection failed'
echo '   Database TCP:' && timeout 5 nc -zv database-service 5432

echo
echo '3. Service Discovery Summary:'
echo '   ✅ All services discoverable by simple names'
echo '   ✅ No hardcoded IP addresses needed'
echo '   ✅ Services automatically load balance across pods'
"
```

---

## Section 3: Service Types Deep Dive - Choosing the Right Tool

Different networking scenarios require different Service types. This section provides hands-on experience with each type, helping you understand when and why to use each one.

### Lab 3.1: ClusterIP - The Foundation of Internal Communication

ClusterIP is the default Service type and the foundation of most Kubernetes networking. Let's explore its characteristics through progressive examples.

```bash
# Create a comprehensive ClusterIP demonstration
kubectl create namespace clusterip-demo

# Deploy a multi-tier application using only ClusterIP services
cat << 'EOF' > clusterip-architecture.yaml
# Web tier
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-tier
  namespace: clusterip-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-tier
  template:
    metadata:
      labels:
        app: web-tier
    spec:
      containers:
      - name: web
        image: nginx:alpine
        ports:
        - containerPort: 80
---
# API tier
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-tier
  namespace: clusterip-demo
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api-tier
  template:
    metadata:
      labels:
        app: api-tier
    spec:
      containers:
      - name: api
        image: httpd:alpine
        ports:
        - containerPort: 80
        env:
        - name: TIER_NAME
          value: "API Processing Layer"
---
# Cache tier
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cache-tier
  namespace: clusterip-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: cache-tier
  template:
    metadata:
      labels:
        app: cache-tier
    spec:
      containers:
      - name: redis
        image: redis:alpine
        ports:
        - containerPort: 6379
---
# ClusterIP services for internal communication
apiVersion: v1
kind: Service
metadata:
  name: web-service
  namespace: clusterip-demo
spec:
  type: ClusterIP
  selector:
    app: web-tier
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: api-service
  namespace: clusterip-demo
spec:
  type: ClusterIP
  selector:
    app: api-tier
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: cache-service
  namespace: clusterip-demo
spec:
  type: ClusterIP
  selector:
    app: cache-tier
  ports:
  - port: 6379
    targetPort: 6379
EOF

kubectl apply -f clusterip-architecture.yaml

# Wait for deployment completion
kubectl wait --for=condition=available deployment --all -n clusterip-demo --timeout=120s

# Test internal connectivity patterns
echo "🔍 ClusterIP Internal Communication Tests"
echo "========================================"

kubectl run internal-client --image=busybox --rm -it --restart=Never --namespace=clusterip-demo -- sh -c "
echo '1. Testing service-to-service communication:'
echo '   Web → API:' && timeout 5 wget -qO- api-service || echo 'Failed'
echo '   Cache accessible:' && timeout 5 nc -zv cache-service 6379

echo
echo '2. Testing load balancing across replicas:'
for i in {1..5}; do
    echo \"   Call $i:\" && timeout 3 wget -qO- api-service 2>/dev/null | head -1 || echo 'Failed'
done

echo
echo '3. ClusterIP characteristics:'
echo '   - Only accessible from within the cluster'
echo '   - Provides stable IP and DNS name'  
echo '   - Automatically load balances across healthy pods'
echo '   - Forms the foundation for microservice architectures'
"
```

### Lab 3.2: NodePort - Development and Testing Gateway

NodePort services extend ClusterIP functionality by opening ports on every cluster node.

```bash
# Create a NodePort service demonstration
kubectl create namespace nodeport-demo

# Deploy an application we want to access externally
kubectl create deployment dev-app --image=nginx --replicas=3 --namespace=nodeport-demo

# Create different types of NodePort services to compare
echo "🌐 Creating NodePort services with different configurations:"

# Standard NodePort (random port)
kubectl expose deployment dev-app --type=NodePort --port=80 --name=nodeport-random --namespace=nodeport-demo

# NodePort with specific port (if available)
kubectl expose deployment dev-app --type=NodePort --port=80 --name=nodeport-specific --namespace=nodeport-demo
kubectl patch service nodeport-specific --namespace=nodeport-demo -p '{"spec":{"ports":[{"port":80,"targetPort":80,"nodePort":30080,"protocol":"TCP"}]}}'

# Wait for services to be ready
kubectl wait --for=condition=available deployment dev-app -n nodeport-demo --timeout=120s

# Analyze NodePort characteristics
echo "🔍 NodePort Service Analysis:"
kubectl get services -n nodeport-demo -o wide

# Test different access methods
kubectl run nodeport-tester --image=curlimages/curl --rm -it --restart=Never --namespace=nodeport-demo -- sh -c "
echo '🧪 NodePort Access Methods Testing'
echo '=================================='

echo '1. ClusterIP access (internal):'
curl -s nodeport-random | head -2

echo
echo '2. NodePort characteristics:'
echo 'ClusterIP: $(kubectl get service nodeport-random -n nodeport-demo -o jsonpath=\"{.spec.clusterIP}\")'
echo 'NodePort: $(kubectl get service nodeport-random -n nodeport-demo -o jsonpath=\"{.spec.ports[0].nodePort}\")'
echo '   - Accessible internally via ClusterIP'
echo '   - Accessible externally via NodeIP:NodePort'
echo '   - Use for: Development, testing, simple external access'
echo '   - Avoid for: Production (use LoadBalancer instead)'
"
```

### Lab 3.3: LoadBalancer - Production External Access

LoadBalancer services represent the production approach to external access.

```bash
# Create a LoadBalancer service demonstration
kubectl create namespace loadbalancer-demo

# Deploy a production-like application
cat << 'EOF' > loadbalancer-application.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: production-app
  namespace: loadbalancer-demo
spec:
  replicas: 4
  selector:
    matchLabels:
      app: production-app
      version: v1
  template:
    metadata:
      labels:
        app: production-app
        version: v1
    spec:
      containers:
      - name: web
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
EOF

kubectl apply -f loadbalancer-application.yaml

# Create a LoadBalancer service
kubectl expose deployment production-app --type=LoadBalancer --port=80 --name=production-lb --namespace=loadbalancer-demo

echo "☁️ LoadBalancer Service Creation Process:"
echo "======================================="

# Test LoadBalancer service characteristics
kubectl run lb-tester --image=curlimages/curl --rm -it --restart=Never --namespace=loadbalancer-demo -- sh -c "
echo 'LoadBalancer Service Access Methods:'
echo '=================================='

echo '1. Internal ClusterIP access:'
curl -s production-lb | head -3

echo
echo '2. LoadBalancer maintains all service types:'
echo '   ClusterIP: $(kubectl get service production-lb -n loadbalancer-demo -o jsonpath=\"{.spec.clusterIP}\")'
echo '   NodePort: $(kubectl get service production-lb -n loadbalancer-demo -o jsonpath=\"{.spec.ports[0].nodePort}\")'
echo '   LoadBalancer: External IP (cloud provider dependent)'
"
```

---

## INTERMEDIATE LEVEL (Sections 4-6)

## Section 4: Advanced Service Patterns - Beyond Basic Connectivity

With the fundamentals mastered, let's explore sophisticated Service patterns that solve complex architectural challenges.

### Lab 4.1: Multi-Port Services - Complex Application Architecture

Modern applications often need multiple ports for different functions. Let's build a realistic multi-port application.

```bash
# Create a comprehensive multi-port service demonstration
kubectl create namespace multiport-demo

# Deploy a complex application with multiple service ports
cat << 'EOF' > multiport-application.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multi-service-app
  namespace: multiport-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: multi-service-app
  template:
    metadata:
      labels:
        app: multi-service-app
    spec:
      containers:
      - name: web-app
        image: nginx:alpine
        ports:
        - containerPort: 80
          name: web
        - containerPort: 8080
          name: admin
        volumeMounts:
        - name: web-config
          mountPath: /etc/nginx/conf.d/default.conf
          subPath: nginx.conf
      - name: metrics
        image: prom/node-exporter:latest
        ports:
        - containerPort: 9100
          name: metrics
        args:
        - --path.procfs=/host/proc
        - --path.sysfs=/host/sys
        - --collector.filesystem.ignored-mount-points
        - ^/(sys|proc|dev|host|etc)($|/)
        volumeMounts:
        - name: proc
          mountPath: /host/proc
          readOnly: true
        - name: sys
          mountPath: /host/sys
          readOnly: true
      volumes:
      - name: web-config
        configMap:
          name: multiport-config
      - name: proc
        hostPath:
          path: /proc
      - name: sys
        hostPath:
          path: /sys
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: multiport-config
  namespace: multiport-demo
data:
  nginx.conf: |
    server {
        listen 80;
        server_name _;
        location / {
            return 200 '🌐 Main Web Application\nPort: 80\nService: multi-service-app\nTime: $time_iso8601\n';
            add_header Content-Type text/plain;
        }
    }
    
    server {
        listen 8080;
        server_name _;
        location / {
            return 200 '🔧 Admin Interface\nPort: 8080\nService: multi-service-app\nTime: $time_iso8601\n';
            add_header Content-Type text/plain;
        }
    }
---
# Multi-port service definition
apiVersion: v1
kind: Service
metadata:
  name: multi-service
  namespace: multiport-demo
spec:
  selector:
    app: multi-service-app
  ports:
  - name: web-port
    port: 80
    targetPort: web
    protocol: TCP
  - name: admin-port
    port: 8080
    targetPort: admin
    protocol: TCP
  - name: metrics-port
    port: 9100
    targetPort: metrics
    protocol: TCP
EOF

kubectl apply -f multiport-application.yaml
kubectl wait --for=condition=available deployment multi-service-app -n multiport-demo --timeout=120s

# Test multi-port service functionality
echo "🔌 Multi-Port Service Testing"
echo "============================"

kubectl run multiport-tester --image=curlimages/curl --rm -it --restart=Never --namespace=multiport-demo -- sh -c "
echo '1. Testing Web Application (Port 80):'
curl -s multi-service:80

echo
echo '2. Testing Admin Interface (Port 8080):'
curl -s multi-service:8080

echo
echo '3. Testing Metrics Port (Port 9100):'
timeout 5 nc -zv multi-service 9100 && echo 'Metrics port accessible'

echo
echo '4. Port Summary:'
echo '   Port 80   -> Web Application'
echo '   Port 8080 -> Admin Interface'  
echo '   Port 9100 -> Metrics Collection'
"
```

### Lab 4.2: Headless Services - Direct Pod Access

Sometimes you need to access individual pods rather than load balancing across them. Headless Services provide this capability.

```bash
# Create a headless service demonstration with StatefulSet
kubectl create namespace headless-demo

# Deploy a StatefulSet that benefits from headless services
cat << 'EOF' > headless-application.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: database-cluster
  namespace: headless-demo
spec:
  serviceName: database-headless
  replicas: 3
  selector:
    matchLabels:
      app: database-cluster
  template:
    metadata:
      labels:
        app: database-cluster
    spec:
      containers:
      - name: postgres
        image: postgres:13-alpine
        env:
        - name: POSTGRES_DB
          value: clusterdb
        - name: POSTGRES_USER
          value: clusteruser
        - name: POSTGRES_PASSWORD
          value: clusterpass
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        ports:
        - containerPort: 5432
        readinessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - clusteruser
          initialDelaySeconds: 10
          periodSeconds: 5
  volumeClaimTemplates:
  - metadata:
      name: postgres-data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 1Gi
---
# Headless service (clusterIP: None)
apiVersion: v1
kind: Service
metadata:
  name: database-headless
  namespace: headless-demo
spec:
  clusterIP: None  # This makes the service "headless"
  selector:
    app: database-cluster
  ports:
  - port: 5432
    targetPort: 5432
    name: postgres
---
# Regular service for comparison
apiVersion: v1
kind: Service
metadata:
  name: database-regular
  namespace: headless-demo
spec:
  selector:
    app: database-cluster
  ports:
  - port: 5432
    targetPort: 5432
    name: postgres
EOF

kubectl apply -f headless-application.yaml
kubectl wait --for=condition=ready pod -l app=database-cluster -n headless-demo --timeout=300s

# Demonstrate headless service DNS behavior
echo "🌐 Headless Service DNS Discovery"
echo "================================"

kubectl run dns-explorer --image=busybox --rm -it --restart=Never --namespace=headless-demo -- sh -c "
echo '1. Regular Service DNS (single IP):'
nslookup database-regular

echo
echo '2. Headless Service DNS (multiple IPs):'
nslookup database-headless

echo
echo '3. Individual Pod DNS Records:'
nslookup database-cluster-0.database-headless
nslookup database-cluster-1.database-headless  
nslookup database-cluster-2.database-headless
"
```

### Lab 4.3: External Services - Integrating External Dependencies

Not every service your application needs runs inside Kubernetes. External Services provide elegant integration.

```bash
# Create external service integration demonstration
kubectl create namespace external-services-demo

cat << 'EOF' > external-services.yaml
# ExternalName service pointing to external database
apiVersion: v1
kind: Service
metadata:
  name: external-database
  namespace: external-services-demo
spec:
  type: ExternalName
  externalName: postgresql.example.com
  ports:
  - port: 5432
    targetPort: 5432
---
# External API service using manual endpoints  
apiVersion: v1
kind: Service
metadata:
  name: external-api
  namespace: external-services-demo
spec:
  ports:
  - port: 443
    targetPort: 443
    name: https
---
apiVersion: v1
kind: Endpoints
metadata:
  name: external-api
  namespace: external-services-demo
subsets:
- addresses:
  - ip: 8.8.8.8  # Google DNS for testing
  - ip: 8.8.4.4  # Google DNS alternate
  ports:
  - port: 443
    name: https
---
# Application that uses external services
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-with-external-deps
  namespace: external-services-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: external-app
  template:
    metadata:
      labels:
        app: external-app
    spec:
      containers:
      - name: app
        image: curlimages/curl
        command: ['sleep', '3600']
        env:
        - name: DATABASE_HOST
          value: "external-database"
        - name: API_HOST
          value: "external-api"
EOF

kubectl apply -f external-services.yaml
kubectl wait --for=condition=available deployment app-with-external-deps -n external-services-demo --timeout=120s

# Test external service integration
echo "🌐 External Service Integration Testing"
echo "======================================"

kubectl run external-tester --image=curlimages/curl --rm -it --restart=Never --namespace=external-services-demo -- sh -c "
echo '1. ExternalName Service DNS Resolution:'
nslookup external-database
echo 'Note: This resolves to postgresql.example.com'

echo
echo '2. Manual Endpoints Service DNS Resolution:'  
nslookup external-api
echo 'Note: This resolves to the manually configured IP addresses'

echo
echo '3. Testing External API Connectivity:'
timeout 5 nc -zv external-api 443 && echo 'HTTPS port accessible' || echo 'HTTPS connection failed'

echo
echo '💼 External Service Use Cases:'
echo '   🗄️ External Databases (RDS, Cloud SQL)'
echo '   🌐 External APIs and webhooks'
echo '   ⚙️ Infrastructure Services (DNS, NTP)'
echo '   🔄 Migration Patterns (external to internal)'
"
```

---

## Section 5: Service Debugging and Troubleshooting - When Things Go Wrong

Even with perfect Service configurations, issues arise. This section provides systematic approaches to diagnosing and fixing Service connectivity problems.

### Lab 5.1: Debugging Service Selection Issues

Service selector problems are the most common cause of Service failures. Let's create and fix various selector issues.

```bash
# Create a troubleshooting environment with intentional problems
kubectl create namespace debug-demo

# Deploy applications with various label configurations
cat << 'EOF' > debugging-applications.yaml
# Working application
apiVersion: apps/v1
kind: Deployment
metadata:
  name: working-app
  namespace: debug-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: working-app
      version: v1
  template:
    metadata:
      labels:
        app: working-app
        version: v1
        environment: production
    spec:
      containers:
      - name: web
        image: nginx:alpine
        ports:
        - containerPort: 80
---
# Application with extra labels
apiVersion: apps/v1
kind: Deployment
metadata:
  name: extra-labels-app
  namespace: debug-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: extra-labels-app
  template:
    metadata:
      labels:
        app: extra-labels-app
        version: v2
        team: backend
        environment: staging
        region: us-west
    spec:
      containers:
      - name: web
        image: nginx:alpine
        ports:
        - containerPort: 80
---
# Application with minimal labels
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minimal-app
  namespace: debug-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      service: minimal
  template:
    metadata:
      labels:
        service: minimal
        role: api
    spec:
      containers:
      - name: web
        image: nginx:alpine
        ports:
        - containerPort: 80
EOF

kubectl apply -f debugging-applications.yaml
kubectl wait --for=condition=available deployment --all -n debug-demo --timeout=120s

# Create services with various selector problems
echo "🛠 Creating Services with Common Selector Issues"
echo "==============================================="

# Problem 1: Service selector doesn't match any pods
kubectl create service clusterip broken-selector --tcp=80:80 --namespace=debug-demo
kubectl patch service broken-selector -n debug-demo -p '{"spec":{"selector":{"app":"non-existent-app"}}}'

# Problem 2: Service selector is too restrictive
kubectl create service clusterip too-restrictive --tcp=80:80 --namespace=debug-demo
kubectl patch service too-restrictive -n debug-demo -p '{"spec":{"selector":{"app":"extra-labels-app","version":"v1","team":"frontend"}}}'

# Problem 3: Service selector uses wrong label keys
kubectl create service clusterip wrong-keys --tcp=80:80 --namespace=debug-demo
kubectl patch service wrong-keys -n debug-demo -p '{"spec":{"selector":{"application":"minimal-app","tier":"web"}}}'

# Problem 4: Working service for comparison
kubectl expose deployment working-app --port=80 --name=working-service --namespace=debug-demo

# Systematic debugging process
echo "🔍 Systematic Service Debugging Process"
echo "======================================"

cat << 'EOF' > debug-services.sh
#!/bin/bash
echo "🧰 Service Debugging Toolkit"
echo "============================"

debug_service() {
    local service_name=$1
    echo "🔍 Debugging Service: $service_name"
    echo "-----------------------------------"
    
    echo "1. Service Configuration:"
    kubectl describe service $service_name -n debug-demo | grep -E "(Selector|Port|Endpoints)"
    
    echo
    echo "2. Endpoints Check:"
    kubectl get endpoints $service_name -n debug-demo
    
    echo
    echo "3. Available Pods and Their Labels:"
    kubectl get pods -n debug-demo --show-labels | head -5
    
    echo
    echo "4. Connectivity Test:"
    kubectl run test-$service_name-$(date +%s) --image=busybox --rm --restart=Never --namespace=debug-demo -- timeout 5 wget -qO- $service_name 2>/dev/null | head -1 || echo "   ❌ Connection failed"
    
    echo "========================================="
    echo
}

# Debug each problematic service
for service in broken-selector too-restrictive wrong-keys working-service; do
    debug_service $service
    sleep 2
done

echo "🛠️ Common Fixes:"
echo "=================="
echo "1. Fix broken-selector: kubectl patch service broken-selector -n debug-demo -p '{\"spec\":{\"selector\":{\"app\":\"working-app\"}}}'"
echo "2. Fix too-restrictive: kubectl patch service too-restrictive -n debug-demo -p '{\"spec\":{\"selector\":{\"app\":\"extra-labels-app\"}}}'"
echo "3. Fix wrong-keys: kubectl patch service wrong-keys -n debug-demo -p '{\"spec\":{\"selector\":{\"service\":\"minimal\"}}}'"
EOF

chmod +x debug-services.sh
./debug-services.sh
```

### Lab 5.2: Pod Health and Readiness Issues

Services only route traffic to healthy pods. Let's explore how pod health affects Service functionality.

```bash
# Create applications with various health check scenarios
kubectl create namespace health-debug

cat << 'EOF' > health-scenarios.yaml
# Healthy application
apiVersion: apps/v1
kind: Deployment
metadata:
  name: healthy-app
  namespace: health-debug
spec:
  replicas: 3
  selector:
    matchLabels:
      app: healthy-app
  template:
    metadata:
      labels:
        app: healthy-app
    spec:
      containers:
      - name: web
        image: nginx:alpine
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 10
---
# Application with failing readiness probe
apiVersion: apps/v1
kind: Deployment
metadata:
  name: unready-app
  namespace: health-debug
spec:
  replicas: 3
  selector:
    matchLabels:
      app: unready-app
  template:
    metadata:
      labels:
        app: unready-app
    spec:
      containers:
      - name: web
        image: nginx:alpine
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /nonexistent-health-check
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 60
          periodSeconds: 10
EOF

kubectl apply -f health-scenarios.yaml

# Create services for each application
kubectl expose deployment healthy-app --port=80 --name=healthy-service --namespace=health-debug
kubectl expose deployment unready-app --port=80 --name=unready-service --namespace=health-debug

# Monitor the health scenarios
echo "🏥 Pod Health Monitoring Dashboard"
echo "=================================="

cat << 'EOF' > health-monitor.sh
#!/bin/bash

monitor_health() {
    echo "📊 Health Status Monitoring"
    echo "============================"
    
    echo "Healthy App Pods:"
    kubectl get pods -l app=healthy-app -n health-debug
    
    echo
    echo "Unready App Pods:"
    kubectl get pods -l app=unready-app -n health-debug
    
    echo
    echo "Service Endpoints:"
    echo "Healthy service endpoints:"
    kubectl get endpoints healthy-service -n health-debug
    echo "Unready service endpoints:"
    kubectl get endpoints unready-service -n health-debug
    
    echo
    echo "Connectivity Tests:"
    kubectl run health-test --image=busybox --rm --restart=Never --namespace=health-debug -- sh -c "
    echo 'Healthy service:' && timeout 3 wget -qO- healthy-service | head -1 || echo 'Failed'
    echo 'Unready service:' && timeout 3 wget -qO- unready-service | head -1 || echo 'Failed (expected due to health checks)'
    "
}

monitor_health
EOF

chmod +x health-monitor.sh
./health-monitor.sh
```

---

## Section 6: Performance Optimization - Making Services Lightning Fast

Understanding Service performance characteristics helps you build efficient, scalable applications. This section explores optimization techniques through hands-on performance testing.

### Lab 6.1: Service Performance Characteristics and Optimization

Let's explore how different Service configurations impact performance and learn optimization techniques.

```bash
# Create a performance testing environment
kubectl create namespace performance-demo

# Deploy applications with different performance characteristics
cat << 'EOF' > performance-applications.yaml
# High-performance application with optimized configuration
apiVersion: apps/v1
kind: Deployment
metadata:
  name: optimized-app
  namespace: performance-demo
spec:
  replicas: 4
  selector:
    matchLabels:
      app: optimized-app
      performance: high
  template:
    metadata:
      labels:
        app: optimized-app
        performance: high
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 1
          periodSeconds: 1
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
---
# Standard application
apiVersion: apps/v1
kind: Deployment
metadata:
  name: standard-app
  namespace: performance-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: standard-app
      performance: medium
  template:
    metadata:
      labels:
        app: standard-app
        performance: medium
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 10
---
# Resource-constrained application
apiVersion: apps/v1
kind: Deployment
metadata:
  name: constrained-app
  namespace: performance-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: constrained-app
      performance: low
  template:
    metadata:
      labels:
        app: constrained-app
        performance: low
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 50m
            memory: 64Mi
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 30
EOF

kubectl apply -f performance-applications.yaml
kubectl wait --for=condition=available deployment --all -n performance-demo --timeout=180s

# Create different service configurations for performance comparison
echo "⚡ Creating Services with Different Performance Characteristics"
echo "============================================================="

# Standard ClusterIP service
kubectl expose deployment optimized-app --port=80 --name=optimized-service --namespace=performance-demo

# Service with session affinity
kubectl expose deployment standard-app --port=80 --name=standard-service --namespace=performance-demo
kubectl expose deployment standard-app --port=80 --name=sticky-service --namespace=performance-demo
kubectl patch service sticky-service -n performance-demo -p '{"spec":{"sessionAffinity":"ClientIP","sessionAffinityConfig":{"clientIP":{"timeoutSeconds":300}}}}'

# Constrained service
kubectl expose deployment constrained-app --port=80 --name=constrained-service --namespace=performance-demo

# Performance testing toolkit
echo "🧪 Performance Testing Toolkit Setup"
echo "===================================="

cat << 'EOF' > performance-test-suite.sh
#!/bin/bash

test_service_response_time() {
    local service_name=$1
    local test_name=$2
    local iterations=${3:-10}
    
    echo "📊 Testing $test_name ($service_name)"
    echo "--------------------------------------------"
    
    # Array to store response times
    times=()
    
    for i in $(seq 1 $iterations); do
        start_time=$(date +%s%N)
        kubectl run perf-test-$i --image=busybox --rm --restart=Never \
            --namespace=performance-demo -- timeout 5 wget -qO- $service_name >/dev/null 2>&1
        end_time=$(date +%s%N)
        
        if [ $? -eq 0 ]; then
            duration=$(( (end_time - start_time) / 1000000 ))  # Convert to milliseconds
            times+=($duration)
            echo "  Test $i: ${duration}ms"
        else
            echo "  Test $i: FAILED"
        fi
        
        sleep 1
    done
    
    # Calculate statistics
    if [ ${#times[@]} -gt 0 ]; then
        total=0
        for time in "${times[@]}"; do
            total=$((total + time))
        done
        average=$((total / ${#times[@]}))
        
        # Find min and max
        min=${times[0]}
        max=${times[0]}
        for time in "${times[@]}"; do
            if [ $time -lt $min ]; then min=$time; fi
            if [ $time -gt $max ]; then max=$time; fi
        done
        
        echo "  📈 Results:"
        echo "     Average: ${average}ms"
        echo "     Min: ${min}ms"
        echo "     Max: ${max}ms"
        echo "     Success Rate: ${#times[@]}/$iterations ($(( ${#times[@]} * 100 / iterations ))%)"
    else
        echo "  ❌ All tests failed"
    fi
    echo ""
}

test_concurrent_connections() {
    local service_name=$1
    local concurrent_requests=${2:-5}
    
    echo "🔄 Concurrent Connection Test: $service_name"
    echo "-------------------------------------------"
    echo "   Running $concurrent_requests concurrent requests..."
    
    start_time=$(date +%s)
    
    # Launch concurrent requests
    pids=()
    for i in $(seq 1 $concurrent_requests); do
        kubectl run concurrent-test-$i --image=busybox --restart=Never \
            --namespace=performance-demo -- timeout 10 wget -qO- $service_name >/dev/null 2>&1 &
        pids+=($!)
    done
    
    # Wait for all to complete
    success_count=0
    for pid in "${pids[@]}"; do
        if wait $pid; then
            success_count=$((success_count + 1))
        fi
    done
    
    end_time=$(date +%s)
    total_time=$((end_time - start_time))
    
    echo "   ✅ Completed: $success_count/$concurrent_requests requests succeeded"
    echo "   ⏱️ Total time: ${total_time}s"
    echo "   📊 Requests/second: $(( concurrent_requests / total_time ))"
    
    # Cleanup test pods
    kubectl delete pods -l run -n performance-demo --ignore-not-found=true >/dev/null 2>&1
    
    echo ""
}

# Main performance testing suite
main() {
    echo "🚀 KUBERNETES SERVICE PERFORMANCE TESTING SUITE"
    echo "==============================================="
    echo ""
    
    # Test 1: Response Time Comparison
    echo "TEST 1: Response Time Comparison"
    echo "================================"
    test_service_response_time "optimized-service" "Optimized Service (4 replicas, fast probes)" 10
    test_service_response_time "standard-service" "Standard Service (2 replicas, normal probes)" 10  
    test_service_response_time "constrained-service" "Constrained Service (1 replica, slow probes)" 5
    
    # Test 2: Session Affinity Impact
    echo "TEST 2: Session Affinity Performance Impact"
    echo "==========================================="
    test_service_response_time "standard-service" "Standard Service (no affinity)" 8
    test_service_response_time "sticky-service" "Sticky Session Service (ClientIP affinity)" 8
    
    # Test 3: Concurrent Connection Handling
    echo "TEST 3: Concurrent Connection Handling"
    echo "======================================"
    test_concurrent_connections "optimized-service" 8
    test_concurrent_connections "standard-service" 6
    test_concurrent_connections "constrained-service" 3
    
    echo "🎯 PERFORMANCE TESTING COMPLETE"
    echo "==============================="
    echo "Key findings:"
    echo "✅ More replicas = better concurrent handling"
    echo "✅ Faster health checks = quicker failover" 
    echo "✅ Resource limits prevent resource contention"
    echo "✅ Session affinity may reduce load distribution efficiency"
    echo "✅ Kubernetes handles load balancing automatically"
}

main
EOF

chmod +x performance-test-suite.sh
./performance-test-suite.sh
```

---

## ADVANCED LEVEL (Sections 7-9)

## Section 7: Security and Network Policies - Protecting Your Services

Security is paramount in production environments. This section covers service security, network policies, and access control patterns.

### Lab 7.1: Network Policies for Service Security

Network policies control traffic flow between pods and services. Let's implement comprehensive security policies.

```bash
# Create a security demonstration environment
kubectl create namespace security-demo

# Deploy a multi-tier application with security requirements
cat << 'EOF' > secure-application.yaml
# Frontend tier (public-facing)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: security-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
      tier: web
      security-zone: dmz
  template:
    metadata:
      labels:
        app: frontend
        tier: web
        security-zone: dmz
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        env:
        - name: TIER
          value: "frontend"
---
# API tier (internal services)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-service
  namespace: security-demo
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api-service
      tier: api
      security-zone: internal
  template:
    metadata:
      labels:
        app: api-service
        tier: api
        security-zone: internal
    spec:
      containers:
      - name: api
        image: httpd:alpine
        ports:
        - containerPort: 80
        env:
        - name: TIER
          value: "api"
---
# Database tier (highly secured)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database
  namespace: security-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: database
      tier: data
      security-zone: restricted
  template:
    metadata:
      labels:
        app: database
        tier: data
        security-zone: restricted
    spec:
      containers:
      - name: postgres
        image: postgres:13-alpine
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_DB
          value: securedb
        - name: POSTGRES_USER
          value: secureuser
        - name: POSTGRES_PASSWORD
          value: securepass
---
# Admin tools (management access)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: admin-tools
  namespace: security-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: admin-tools
      tier: management
      security-zone: admin
  template:
    metadata:
      labels:
        app: admin-tools
        tier: management
        security-zone: admin
    spec:
      containers:
      - name: tools
        image: busybox
        command: ['sleep', '3600']
        env:
        - name: TIER
          value: "admin"
---
# Services
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
  namespace: security-demo
spec:
  type: LoadBalancer
  selector:
    tier: web
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: api-service
  namespace: security-demo
spec:
  selector:
    tier: api
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: database-service
  namespace: security-demo
spec:
  selector:
    tier: data
  ports:
  - port: 5432
    targetPort: 5432
EOF

kubectl apply -f secure-application.yaml
kubectl wait --for=condition=available deployment --all -n security-demo --timeout=120s

# Test baseline connectivity (before network policies)
echo "🔓 Baseline Security Test (No Network Policies)"
echo "=============================================="

kubectl run security-test --image=busybox --rm -it --restart=Never --namespace=security-demo --labels="tier=test" -- sh -c "
echo 'Testing connectivity between all services (should all work initially):'

echo '1. Frontend to API:'
timeout 5 nc -zv api-service 80 && echo '✅ Connection successful' || echo '❌ Connection failed'

echo '2. Frontend to Database (should be blocked later):'  
timeout 5 nc -zv database-service 5432 && echo '✅ Connection successful' || echo '❌ Connection failed'

echo '3. API to Database:'
timeout 5 nc -zv database-service 5432 && echo '✅ Connection successful' || echo '❌ Connection failed'
"

# Implement comprehensive network policies
echo "🛡️ Implementing Layered Security Policies"
echo "========================================"

cat << 'EOF' > security-policies.yaml
# Policy 1: Database Access Control (most restrictive)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-security-policy
  namespace: security-demo
spec:
  podSelector:
    matchLabels:
      tier: data
      security-zone: restricted
  policyTypes:
  - Ingress
  - Egress
  ingress:
  # Only API tier can access database
  - from:
    - podSelector:
        matchLabels:
          tier: api
          security-zone: internal
    ports:
    - protocol: TCP
      port: 5432
  # Admin tools can access for maintenance
  - from:
    - podSelector:
        matchLabels:
          tier: management
          security-zone: admin
    ports:
    - protocol: TCP
      port: 5432
  egress:
  # Allow DNS resolution
  - to: []
    ports:
    - protocol: UDP
      port: 53
---
# Policy 2: API Tier Security
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-security-policy
  namespace: security-demo
spec:
  podSelector:
    matchLabels:
      tier: api
      security-zone: internal
  policyTypes:
  - Ingress
  - Egress
  ingress:
  # Only frontend can access API
  - from:
    - podSelector:
        matchLabels:
          tier: web
          security-zone: dmz
    ports:
    - protocol: TCP
      port: 80
  # Admin tools can access API
  - from:
    - podSelector:
        matchLabels:
          tier: management
          security-zone: admin
    ports:
    - protocol: TCP
      port: 80
  egress:
  # API can access database
  - to:
    - podSelector:
        matchLabels:
          tier: data
          security-zone: restricted
    ports:
    - protocol: TCP
      port: 5432
  # Allow DNS resolution
  - to: []
    ports:
    - protocol: UDP
      port: 53
---
# Policy 3: Frontend Security
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-security-policy
  namespace: security-demo
spec:
  podSelector:
    matchLabels:
      tier: web
      security-zone: dmz
  policyTypes:
  - Ingress
  - Egress
  ingress:
  # Accept traffic from anywhere (public-facing)
  - {}
  egress:
  # Frontend can only access API tier
  - to:
    - podSelector:
        matchLabels:
          tier: api
          security-zone: internal
    ports:
    - protocol: TCP
      port: 80
  # Allow DNS resolution
  - to: []
    ports:
    - protocol: UDP
      port: 53
---
# Policy 4: Admin Tools (privileged access)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: admin-security-policy
  namespace: security-demo
spec:
  podSelector:
    matchLabels:
      tier: management
      security-zone: admin
  policyTypes:
  - Egress
  egress:
  # Admin tools can access everything
  - to:
    - podSelector: {}
  # Allow external access for tools/updates
  - to: []
    ports:
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 443
    - protocol: UDP
      port: 53
---
# Policy 5: Default Deny (security baseline)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: security-demo
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF

kubectl apply -f security-policies.yaml

# Wait for policies to be applied
sleep 10

# Test security enforcement
echo "🔒 Security Policy Enforcement Testing"
echo "====================================="

cat << 'EOF' > security-test-suite.sh
#!/bin/bash

test_security_policy() {
    local from_label=$1
    local to_service=$2
    local port=$3
    local should_succeed=$4
    local description=$5
    
    echo "Testing: $description"
    echo "From: $from_label → To: $to_service:$port"
    
    kubectl run security-test-$(date +%s) --image=busybox --rm --restart=Never \
        --namespace=security-demo --labels="$from_label" -- \
        timeout 5 nc -zv $to_service $port 2>&1 >/dev/null
    
    if [ $? -eq 0 ]; then
        if [ "$should_succeed" = "true" ]; then
            echo "   ✅ PASS: Connection allowed (as expected)"
        else
            echo "   ❌ FAIL: Connection should be blocked!"
        fi
    else
        if [ "$should_succeed" = "false" ]; then
            echo "   ✅ PASS: Connection blocked (as expected)"
        else
            echo "   ❌ FAIL: Connection should be allowed!"
        fi
    fi
    echo "---"
}

echo "🛡️ COMPREHENSIVE SECURITY POLICY TESTING"
echo "========================================"
echo ""

echo "TEST 1: Allowed Connections (should succeed)"
echo "============================================"
test_security_policy "tier=web,security-zone=dmz" "api-service" "80" "true" "Frontend → API"
test_security_policy "tier=api,security-zone=internal" "database-service" "5432" "true" "API → Database"
test_security_policy "tier=management,security-zone=admin" "database-service" "5432" "true" "Admin → Database"
test_security_policy "tier=management,security-zone=admin" "api-service" "80" "true" "Admin → API"

echo
echo "TEST 2: Blocked Connections (should fail)"
echo "========================================="
test_security_policy "tier=web,security-zone=dmz" "database-service" "5432" "false" "Frontend → Database (direct)"
test_security_policy "tier=test" "api-service" "80" "false" "Unauthorized → API"
test_security_policy "tier=test" "database-service" "5432" "false" "Unauthorized → Database"

echo
echo "TEST 3: Service Accessibility Summary"
echo "====================================="
echo "✅ Frontend Service: Public (LoadBalancer)"
echo "🔒 API Service: Internal only (from Frontend + Admin)"
echo "🔐 Database Service: Restricted (from API + Admin only)"
echo "🔧 Admin Tools: Full access (management purposes)"

EOF

chmod +x security-test-suite.sh
./security-test-suite.sh
```

### Lab 7.2: Service Mesh Security with mTLS

For advanced security, let's implement mutual TLS (mTLS) between services using Istio service mesh patterns.

```bash
# Create a service mesh security demonstration
kubectl create namespace servicemesh-security

# Deploy applications that will use mTLS
cat << 'EOF' > mtls-applications.yaml
# Order service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
  namespace: servicemesh-security
spec:
  replicas: 2
  selector:
    matchLabels:
      app: order-service
      version: v1
  template:
    metadata:
      labels:
        app: order-service
        version: v1
      annotations:
        sidecar.istio.io/inject: "true"
    spec:
      containers:
      - name: order
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: config
          mountPath: /etc/nginx/conf.d/default.conf
          subPath: nginx.conf
      volumes:
      - name: config
        configMap:
          name: order-config
---
# Payment service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-service
  namespace: servicemesh-security
spec:
  replicas: 2
  selector:
    matchLabels:
      app: payment-service
      version: v1
  template:
    metadata:
      labels:
        app: payment-service
        version: v1
      annotations:
        sidecar.istio.io/inject: "true"
    spec:
      containers:
      - name: payment
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: config
          mountPath: /etc/nginx/conf.d/default.conf
          subPath: nginx.conf
      volumes:
      - name: config
        configMap:
          name: payment-config
---
# Inventory service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inventory-service
  namespace: servicemesh-security
spec:
  replicas: 2
  selector:
    matchLabels:
      app: inventory-service
      version: v1
  template:
    metadata:
      labels:
        app: inventory-service
        version: v1
      annotations:
        sidecar.istio.io/inject: "true"
    spec:
      containers:
      - name: inventory
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: config
          mountPath: /etc/nginx/conf.d/default.conf
          subPath: nginx.conf
      volumes:
      - name: config
        configMap:
          name: inventory-config
---
# Configuration for services
apiVersion: v1
kind: ConfigMap
metadata:
  name: order-config
  namespace: servicemesh-security
data:
  nginx.conf: |
    server {
        listen 80;
        location / {
            return 200 '🛒 Order Service\nSecure: mTLS enabled\nService: order-service\n';
            add_header Content-Type text/plain;
        }
        location /health {
            return 200 'healthy';
            add_header Content-Type text/plain;
        }
    }
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: payment-config
  namespace: servicemesh-security
data:
  nginx.conf: |
    server {
        listen 80;
        location / {
            return 200 '💳 Payment Service\nSecure: mTLS enabled\nService: payment-service\n';
            add_header Content-Type text/plain;
        }
        location /health {
            return 200 'healthy';
            add_header Content-Type text/plain;
        }
    }
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: inventory-config
  namespace: servicemesh-security
data:
  nginx.conf: |
    server {
        listen 80;
        location / {
            return 200 '📦 Inventory Service\nSecure: mTLS enabled\nService: inventory-service\n';
            add_header Content-Type text/plain;
        }
        location /health {
            return 200 'healthy';
            add_header Content-Type text/plain;
        }
    }
---
# Services
apiVersion: v1
kind: Service
metadata:
  name: order-service
  namespace: servicemesh-security
spec:
  selector:
    app: order-service
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: payment-service
  namespace: servicemesh-security
spec:
  selector:
    app: payment-service
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: inventory-service
  namespace: servicemesh-security
spec:
  selector:
    app: inventory-service
  ports:
  - port: 80
    targetPort: 80
EOF

kubectl apply -f mtls-applications.yaml

# Create Service Mesh Security Policies (Istio-style)
echo "🔐 Implementing Service Mesh Security Policies"
echo "============================================="

cat << 'EOF' > service-mesh-policies.yaml
# PeerAuthentication: Enable strict mTLS
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: servicemesh-security
spec:
  mtls:
    mode: STRICT
---
# AuthorizationPolicy: Order service can access Payment and Inventory
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: payment-access-policy
  namespace: servicemesh-security
spec:
  selector:
    matchLabels:
      app: payment-service
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/servicemesh-security/sa/default"]
        # In real scenario, use specific service accounts
    when:
    - key: source.labels[app]
      values: ["order-service"]
---
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: inventory-access-policy
  namespace: servicemesh-security
spec:
  selector:
    matchLabels:
      app: inventory-service
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/servicemesh-security/sa/default"]
    when:
    - key: source.labels[app]
      values: ["order-service"]
---
# DestinationRule: Configure TLS for services
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: mtls-destination-rules
  namespace: servicemesh-security
spec:
  host: "*.servicemesh-security.svc.cluster.local"
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
EOF

# Note: These policies require Istio to be installed
# For demonstration, we'll show the security concepts
echo "📋 Service Mesh Security Configuration (requires Istio)"
cat service-mesh-policies.yaml

echo ""
echo "🔒 Service Mesh Security Benefits:"
echo "================================="
echo "✅ Automatic mTLS between all services"
echo "✅ Certificate management handled by service mesh"
echo "✅ Fine-grained authorization policies"
echo "✅ Traffic encryption in transit"
echo "✅ Identity-based service authentication"
echo "✅ Audit logging of all service communications"

# Test service connectivity (without Istio, standard connectivity)
kubectl run mesh-security-test --image=curlimages/curl --rm -it --restart=Never --namespace=servicemesh-security -- sh -c "
echo '🧪 Service Mesh Connectivity Test'
echo '================================'

echo '1. Order Service:'
curl -s order-service | head -3

echo
echo '2. Payment Service:'
curl -s payment-service | head -3

echo
echo '3. Inventory Service:'
curl -s inventory-service | head-3

echo
echo 'Note: In a real service mesh with mTLS:'
echo '- All traffic would be encrypted'
echo '- Certificates would be auto-rotated'
echo '- Fine-grained policies would be enforced'
"
```

---

## Section 8: Service Observability and Monitoring - Seeing What's Happening

Production services need comprehensive monitoring and observability. This section covers metrics, logging, tracing, and alerting for Kubernetes Services.

### Lab 8.1: Service Metrics and Monitoring

Let's implement comprehensive monitoring for our services using Prometheus-style metrics.

```bash
# Create a monitoring demonstration environment
kubectl create namespace monitoring-demo

# Deploy applications with built-in metrics
cat << 'EOF' > monitored-applications.yaml
# Frontend with metrics endpoint
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-app
  namespace: monitoring-demo
spec:
  replicas: 3
  selector:
    matchLabels:
      app: frontend-app
      tier: web
  template:
    metadata:
      labels:
        app: frontend-app
        tier: web
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9090"
        prometheus.io/path: "/metrics"
    spec:
      containers:
      - name: web
        image: nginx:alpine
        ports:
        - containerPort: 80
          name: web
        - containerPort: 9090
          name: metrics
        volumeMounts:
        - name: config
          mountPath: /etc/nginx/conf.d/default.conf
          subPath: nginx.conf
      - name: metrics-exporter
        image: nginx/nginx-prometheus-exporter:latest
        ports:
        - containerPort: 9113
          name: metrics
        args:
        - -nginx.scrape-uri=http://localhost/nginx_status
      volumes:
      - name: config
        configMap:
          name: nginx-config
---
# API service with custom metrics
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-service
  namespace: monitoring-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api-service
      tier: api
  template:
    metadata:
      labels:
        app: api-service
        tier: api
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
    spec:
      containers:
      - name: api
        image: httpd:alpine
        ports:
        - containerPort: 80
        - containerPort: 8080
        env:
        - name: METRICS_ENABLED
          value: "true"
        volumeMounts:
        - name: config
          mountPath: /usr/local/apache2/conf/httpd.conf
          subPath: httpd.conf
      volumes:
      - name: config
        configMap:
          name: api-config
---
# Database with monitoring
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: database
  namespace: monitoring-demo
spec:
  serviceName: database-headless
  replicas: 1
  selector:
    matchLabels:
      app: database
      tier: data
  template:
    metadata:
      labels:
        app: database
        tier: data
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9187"
    spec:
      containers:
      - name: postgres
        image: postgres:13-alpine
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_DB
          value: monitordb
        - name: POSTGRES_USER
          value: monitoruser
        - name: POSTGRES_PASSWORD
          value: monitorpass
      - name: postgres-exporter
        image: prometheuscommunity/postgres-exporter:latest
        ports:
        - containerPort: 9187
        env:
        - name: DATA_SOURCE_NAME
          value: "postgresql://monitoruser:monitorpass@localhost:5432/monitordb?sslmode=disable"
---
# Configuration for nginx with status endpoint
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
  namespace: monitoring-demo
data:
  nginx.conf: |
    server {
        listen 80;
        location / {
            return 200 '🌐 Frontend Application\nRequests served: $connection_requests\nTime: $time_iso8601\n';
            add_header Content-Type text/plain;
        }
        location /nginx_status {
            stub_status on;
            access_log off;
            allow all;
        }
        location /health {
            return 200 'healthy';
            add_header Content-Type text/plain;
        }
    }
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: api-config
  namespace: monitoring-demo
data:
  httpd.conf: |
    ServerRoot "/usr/local/apache2"
    Listen 80
    Listen 8080
    LoadModule mpm_event_module modules/mod_mpm_event.so
    LoadModule authz_core_module modules/mod_authz_core.so
    LoadModule dir_module modules/mod_dir.so
    LoadModule mime_module modules/mod_mime.so
    LoadModule status_module modules/mod_status.so
    
    <Directory />
        AllowOverride none
        Require all denied
    </Directory>
    
    DocumentRoot "/usr/local/apache2/htdocs"
    <Directory "/usr/local/apache2/htdocs">
        Options Indexes FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>
    
    <VirtualHost *:80>
        DocumentRoot "/usr/local/apache2/htdocs"
    </VirtualHost>
    
    <VirtualHost *:8080>
        <Location "/metrics">
            SetHandler server-status
            Require all granted
        </Location>
    </VirtualHost>
---
# Services with monitoring labels
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
  namespace: monitoring-demo
  labels:
    app: frontend-app
    tier: web
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "9113"
spec:
  selector:
    tier: web
  ports:
  - port: 80
    targetPort: 80
    name: web
  - port: 9113
    targetPort: 9113
    name: metrics
---
apiVersion: v1
kind: Service
metadata:
  name: api-service
  namespace: monitoring-demo
  labels:
    app: api-service
    tier: api
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
spec:
  selector:
    tier: api
  ports:
  - port: 80
    targetPort: 80
    name: api
  - port: 8080
    targetPort: 8080
    name: metrics
---
apiVersion: v1
kind: Service
metadata:
  name: database-service
  namespace: monitoring-demo
  labels:
    app: database
    tier: data
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "9187"
spec:
  selector:
    tier: data
  ports:
  - port: 5432
    targetPort: 5432
    name: postgres
  - port: 9187
    targetPort: 9187
    name: metrics
---
apiVersion: v1
kind: Service
metadata:
  name: database-headless
  namespace: monitoring-demo
spec:
  clusterIP: None
  selector:
    tier: data
  ports:
  - port: 5432
    targetPort: 5432
EOF

kubectl apply -f monitored-applications.yaml
kubectl wait --for=condition=available deployment --all -n monitoring-demo --timeout=180s

# Create service monitoring dashboard
echo "📊 Service Monitoring Dashboard Setup"
echo "====================================="

cat << 'EOF' > monitoring-toolkit.sh
#!/bin/bash

echo "🔍 SERVICE MONITORING TOOLKIT"
echo "============================"
echo ""

monitor_service_health() {
    local service_name=$1
    local namespace=$2
    
    echo "📋 Service Health Report: $service_name"
    echo "----------------------------------------"
    
    # Service basic info
    echo "1. Service Configuration:"
    kubectl get service $service_name -n $namespace -o wide
    
    echo
    echo "2. Service Endpoints:"
    kubectl get endpoints $service_name -n $namespace
    
    echo
    echo "3. Pod Health Status:"
    kubectl get pods -l $(kubectl get service $service_name -n $namespace -o jsonpath='{.spec.selector}' | sed 's/map\[//;s/\]//;s/ /,/g;s/:/=/g') -n $namespace
    
    echo
    echo "4. Recent Events:"
    kubectl get events -n $namespace --field-selector involvedObject.name=$service_name --sort-by='.lastTimestamp' | tail -3
    
    echo
    echo "5. Connectivity Test:"
    kubectl run monitor-test-$(date +%s) --image=curlimages/curl --rm --restart=Never \
        --namespace=$namespace -- timeout 5 curl -s $service_name:80 | head -2 || echo "❌ Service unreachable"
    
    echo "==============================================" 
    echo
}

collect_service_metrics() {
    echo "📈 SERVICE METRICS COLLECTION"
    echo "============================"
    
    echo "Checking metrics endpoints..."
    
    kubectl run metrics-collector --image=curlimages/curl --rm -it --restart=Never \
        --namespace=monitoring-demo -- sh -c "
        
    echo '1. Frontend Metrics:'
    curl -s frontend-service:9113/metrics 2>/dev/null | head -10 || echo 'Metrics not available'
    
    echo
    echo '2. API Service Metrics:'
    curl -s api-service:8080/metrics 2>/dev/null | head -10 || echo 'Metrics not available'
    
    echo
    echo '3. Database Metrics:'
    curl -s database-service:9187/metrics 2>/dev/null | head -10 || echo 'Metrics not available'
    
    echo
    echo '📊 Metrics Collection Summary:'
    echo '- Frontend: nginx_connections_active, nginx_http_requests_total'
    echo '- API: apache_up, apache_workers_busy'  
    echo '- Database: postgres_up, postgres_connections_active'
    "
}

generate_monitoring_dashboard() {
    echo "📊 MONITORING DASHBOARD"
    echo "======================"
    
    echo "Service Overview:"
    echo "┌─────────────────┬─────────────┬────────────────┬─────────────────┐"
    echo "│ Service         │ Replicas    │ Endpoints      │ Status          │"
    echo "├─────────────────┼─────────────┼────────────────┼─────────────────┤"
    
    for service in frontend-service api-service database-service; do
        replicas=$(kubectl get deployment $(echo $service | sed 's/-service//') -n monitoring-demo -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "N/A")
        endpoints=$(kubectl get endpoints $service -n monitoring-demo -o jsonpath='{.subsets[*].addresses[*].ip}' | wc -w)
        
        if [ "$endpoints" -gt 0 ]; then
            status="✅ Healthy"
        else
            status="❌ Unhealthy"
        fi
        
        printf "│ %-15s │ %-11s │ %-14s │ %-15s │\n" "$service" "$replicas" "$endpoints" "$status"
    done
    
    echo "└─────────────────┴─────────────┴────────────────┴─────────────────┘"
    echo ""
    
    echo "Quick Health Checks:"
    for service in frontend-service api-service database-service; do
        port=$(kubectl get service $service -n monitoring-demo -o jsonpath='{.spec.ports[0].port}')
        kubectl run quick-health-$(date +%s) --image=busybox --rm --restart=Never \
            --namespace=monitoring-demo -- timeout 3 nc -zv $service $port >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "   ✅ $service:$port - Reachable"
        else
            echo "   ❌ $service:$port - Unreachable"
        fi
    done
}

# Main monitoring routine
main() {
    echo "🚀 STARTING SERVICE MONITORING SUITE"
    echo "===================================="
    echo ""
    
    # Monitor each service
    for service in frontend-service api-service database-service; do
        monitor_service_health $service monitoring-demo
        sleep 2
    done
    
    # Collect metrics
    collect_service_metrics
    echo ""
    
    # Generate dashboard
    generate_monitoring_dashboard
    echo ""
    
    echo "📋 MONITORING RECOMMENDATIONS:"
    echo "=============================="
    echo "✅ Set up Prometheus to scrape metrics endpoints"
    echo "✅ Configure Grafana dashboards for visualization"
    echo "✅ Implement alerting rules for service failures"
    echo "✅ Monitor service response times and error rates"
    echo "✅ Set up distributed tracing for request flows"
    echo "✅ Configure log aggregation for all services"
}

main
EOF

chmod +x monitoring-toolkit.sh
./monitoring-toolkit.sh
```

### Lab 8.2: Distributed Tracing and Service Dependencies

Understanding how requests flow through your services is crucial for troubleshooting and optimization.

```bash
# Create a distributed tracing demonstration
kubectl create namespace tracing-demo

# Deploy microservices with tracing headers
cat << 'EOF' > tracing-applications.yaml
# Gateway service (entry point)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gateway-service
  namespace: tracing-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: gateway-service
      version: v1
  template:
    metadata:
      labels:
        app: gateway-service
        version: v1
    spec:
      containers:
      - name: gateway
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: config
          mountPath: /etc/nginx/conf.d/default.conf
          subPath: nginx.conf
      volumes:
      - name: config
        configMap:
          name: gateway-config
---
# User service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
  namespace: tracing-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: user-service
      version: v1
  template:
    metadata:
      labels:
        app: user-service
        version: v1
    spec:
      containers:
      - name: user
        image: curlimages/curl
        command: ['sleep', '3600']
        env:
        - name: SERVICE_NAME
          value: "user-service"
---
# Product service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: product-service
  namespace: tracing-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: product-service
      version: v1
  template:
    metadata:
      labels:
        app: product-service
        version: v1
    spec:
      containers:
      - name: product
        image: curlimages/curl
        command: ['sleep', '3600']
        env:
        - name: SERVICE_NAME
          value: "product-service"
---
# Order service (orchestrates other services)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
  namespace: tracing-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: order-service
      version: v1
  template:
    metadata:
      labels:
        app: order-service
        version: v1
    spec:
      containers:
      - name: order
        image: curlimages/curl
        command: ['sleep', '3600']
        env:
        - name: SERVICE_NAME
          value: "order-service"
        - name: USER_SERVICE_URL
          value: "http://user-service:80"
        - name: PRODUCT_SERVICE_URL
          value: "http://product-service:80"
---
# Services
apiVersion: v1
kind: Service
metadata:
  name: gateway-service
  namespace: tracing-demo
spec:
  type: LoadBalancer
  selector:
    app: gateway-service
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: user-service
  namespace: tracing-demo
spec:
  selector:
    app: user-service
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: product-service
  namespace: tracing-demo
spec:
  selector:
    app: product-service
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: order-service
  namespace: tracing-demo
spec:
  selector:
    app: order-service
  ports:
  - port: 80
    targetPort: 80
---
# Gateway configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: gateway-config
  namespace: tracing-demo
data:
  nginx.conf: |
    upstream order_backend {
        server order-service:80;
    }
    
    server {
        listen 80;
        
        # Add tracing headers
        location / {
            # Generate trace ID if not present
            set $trace_id $http_x_trace_id;
            if ($trace_id = '') {
                set $trace_id $request_id;
            }
            
            # Add tracing headers to response
            add_header X-Trace-Id $trace_id;
            add_header X-Service-Name "gateway-service";
            
            return 200 '🌐 Gateway Service\nTrace-ID: $trace_id\nService: gateway-service\nDownstream: order-service\n';
            add_header Content-Type text/plain;
        }
        
        location /order {
            # Forward tracing headers
            proxy_set_header X-Trace-Id $trace_id;
            proxy_set_header X-Parent-Span "gateway-service";
            proxy_pass http://order_backend/;
        }
        
        location /health {
            return 200 'healthy';
            add_header Content-Type text/plain;
        }
    }
EOF

kubectl apply -f tracing-applications.yaml
kubectl wait --for=condition=available deployment --all -n tracing-demo --timeout=120s

# Create distributed tracing simulation
echo "🔍 Distributed Tracing Simulation"
echo "================================="

cat << 'EOF' > tracing-simulator.sh
#!/bin/bash

simulate_request_trace() {
    local trace_id=$(uuidgen | tr '[:upper:]' '[:lower:]' | cut -c1-16)
    echo "🔍 SIMULATING REQUEST TRACE"
    echo "=========================="
    echo "Trace ID: $trace_id"
    echo ""
    
    echo "1. Request enters Gateway Service"
    kubectl run trace-gateway --image=curlimages/curl --rm --restart=Never \
        --namespace=tracing-demo -- curl -s -H "X-Trace-Id: $trace_id" gateway-service | head -4
    
    echo ""
    echo "2. Gateway forwards to Order Service"
    kubectl exec deployment/order-service -n tracing-demo -- curl -s -H "X-Trace-Id: $trace_id" -H "X-Parent-Span: gateway-service" user-service | head -1 &
    kubectl exec deployment/order-service -n tracing-demo -- curl -s -H "X-Trace-Id: $trace_id" -H "X-Parent-Span: gateway-service" product-service | head -1 &
    
    echo "   Order Service calls:"
    echo "   ├── User Service (trace: $trace_id)"
    echo "   └── Product Service (trace: $trace_id)"
    
    wait
    
    echo ""
    echo "3. Service Dependencies Map:"
    echo "   ┌─────────────────┐"
    echo "   │  Gateway (80)   │"
    echo "   └─────────┬───────┘"
    echo "             │"
    echo "   ┌─────────▼───────┐"
    echo "   │   Order (80)    │"  
    echo "   └─────┬───────┬───┘"
    echo "         │       │"
    echo "   ┌─────▼───┐ ┌─▼─────┐"
    echo "   │User (80)│ │Prod(80)│"
    echo "   └─────────┘ └───────┘"
    
    echo ""
    echo "4. Trace Summary:"
    echo "   Trace ID: $trace_id"
    echo "   Services: gateway → order → [user, product]"
    echo "   Latency: <measured in real tracing system>"
    echo "   Status: Success"
}

analyze_service_dependencies() {
    echo ""
    echo "📊 SERVICE DEPENDENCY ANALYSIS"
    echo "============================="
    
    echo "Service Communication Matrix:"
    echo "┌──────────────┬─────────────┬──────────────┬────────────────┐"
    echo "│ From Service │ To Service  │ Port         │ Purpose        │"
    echo "├──────────────┼─────────────┼──────────────┼────────────────┤"
    echo "│ Gateway      │ Order       │ 80           │ Order Processing│"
    echo "│ Order        │ User        │ 80           │ User Validation │"
    echo "│ Order        │ Product     │ 80           │ Product Lookup  │"
    echo "└──────────────┴─────────────┴──────────────┴────────────────┘"
    
    echo ""
    echo "Service Discovery Test:"
    kubectl run dependency-test --image=busybox --rm -it --restart=Never \
        --namespace=tracing-demo -- sh -c "
        
    echo 'Testing service reachability:'
    
    echo '✓ Gateway Service:'
    nslookup gateway-service | grep -E 'Name:|Address:' | head -2
    
    echo '✓ Order Service:'  
    nslookup order-service | grep -E 'Name:|Address:' | head -2
    
    echo '✓ User Service:'
    nslookup user-service | grep -E 'Name:|Address:' | head -2
    
    echo '✓ Product Service:'
    nslookup product-service | grep -E 'Name:|Address:' | head -2
    "
}

monitor_service_health_realtime() {
    echo ""
    echo "🏥 REAL-TIME SERVICE HEALTH MONITORING"
    echo "====================================="
    
    echo "Continuous health monitoring for 30 seconds..."
    
    for i in {1..6}; do
        timestamp=$(date '+%H:%M:%S')
        echo "[$timestamp] Health Check Round $i"
        
        for service in gateway-service order-service user-service product-service; do
            kubectl run health-check-$i --image=busybox --rm --restart=Never \
                --namespace=tracing-demo -- timeout 2 nc -zv $service 80 >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo "  ✅ $service - Healthy"
            else
                echo "  ❌ $service - Unhealthy"
            fi
        done
        echo "  ---"
        
        sleep 5
    done
    
    echo "Health monitoring complete."
}

# Main tracing simulation
main() {
    simulate_request_trace
    analyze_service_dependencies
    monitor_service_health_realtime
    
    echo ""
    echo "🎯 DISTRIBUTED TRACING RECOMMENDATIONS:"
    echo "======================================"
    echo "✅ Implement OpenTelemetry for automatic tracing"
    echo "✅ Use Jaeger or Zipkin for trace visualization"
    echo "✅ Propagate trace context across service boundaries"
    echo "✅ Monitor service latencies and error rates"
    echo "✅ Set up alerts for service dependency failures"
    echo "✅ Implement circuit breakers for resilience"
}

main
EOF

chmod +x tracing-simulator.sh
./tracing-simulator.sh
```

---

## Section 9: Production Best Practices - Enterprise-Grade Service Architecture

This final section covers enterprise patterns, high availability, disaster recovery, and production deployment strategies.

### Lab 9.1: High Availability Service Architecture

Let's build a production-grade, highly available service architecture with proper resilience patterns.

```bash
# Create a production-ready HA environment
kubectl create namespace production-ha

# Deploy multi-region, multi-zone application
cat << 'EOF' > ha-architecture.yaml
# Frontend tier with anti-affinity and multiple replicas
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-ha
  namespace: production-ha
spec:
  replicas: 6  # Sufficient for multi-zone distribution
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2
      maxUnavailable: 1
  selector:
    matchLabels:
      app: frontend-ha
      tier: web
  template:
    metadata:
      labels:
        app: frontend-ha
        tier: web
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9090"
    spec:
      # Pod anti-affinity for high availability
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - frontend-ha
              topologyKey: kubernetes.io/hostname
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 50
            preference:
              matchExpressions:
              - key: topology.kubernetes.io/zone
                operator: In
                values:
                - us-west-1a
                - us-west-1b
                - us-west-1c
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        - containerPort: 9090
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
        readinessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
          successThreshold: 1
          failureThreshold: 2
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 15
          failureThreshold: 3
        volumeMounts:
        - name: config
          mountPath: /etc/nginx/conf.d/default.conf
          subPath: nginx.conf
      volumes:
      - name: config
        configMap:
          name: frontend-ha-config
---
# API tier with StatefulSet for sticky sessions if needed
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-ha
  namespace: production-ha
spec:
  replicas: 9  # 3 per zone for N+2 redundancy
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 3
      maxUnavailable: 1
  selector:
    matchLabels:
      app: api-ha
      tier: api
  template:
    metadata:
      labels:
        app: api-ha
        tier: api
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - api-ha
            topologyKey: kubernetes.io/hostname
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: topology.kubernetes.io/zone
                operator: In
                values:
                - us-west-1a
                - us-west-1b
                - us-west-1c
      containers:
      - name: api
        image: httpd:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 300m
            memory: 512Mi
          limits:
            cpu: 1000m
            memory: 1Gi
        readinessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 45
          periodSeconds: 20
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
---
# Database cluster with multiple replicas
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: database-ha
  namespace: production-ha
spec:
  serviceName: database-ha-headless
  replicas: 3  # Primary + 2 replicas
  podManagementPolicy: Parallel
  selector:
    matchLabels:
      app: database-ha
      tier: data
  template:
    metadata:
      labels:
        app: database-ha
        tier: data
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - database-ha
            topologyKey: kubernetes.io/hostname
      containers:
      - name: postgres
        image: postgres:13-alpine
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_DB
          value: proddb
        - name: POSTGRES_USER
          value: produser
        - name: POSTGRES_PASSWORD
          value: prodpass
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            cpu: 2000m
            memory: 4Gi
        readinessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - produser
          initialDelaySeconds: 15
          periodSeconds: 10
        livenessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - produser
          initialDelaySeconds: 60
          periodSeconds: 30
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: postgres-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 10Gi
---
# High Availability Services with multiple endpoints
apiVersion: v1
kind: Service
metadata:
  name: frontend-ha-service
  namespace: production-ha
  labels:
    tier: web
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: nlb
    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
spec:
  type: LoadBalancer
  selector:
    tier: web
  ports:
  - port: 80
    targetPort: 80
    name: web
  - port: 9090
    targetPort: 9090
    name: metrics
  sessionAffinity: None  # For better load distribution
---
apiVersion: v1
kind: Service
metadata:
  name: api-ha-service
  namespace: production-ha
  labels:
    tier: api
spec:
  selector:
    tier: api
  ports:
  - port: 80
    targetPort: 80
    name: api
---
# Headless service for database clustering
apiVersion: v1
kind: Service
metadata:
  name: database-ha-headless
  namespace: production-ha
spec:
  clusterIP: None
  selector:
    tier: data
  ports:
  - port: 5432
    targetPort: 5432
    name: postgres
---
# Regular database service for applications
apiVersion: v1
kind: Service
metadata:
  name: database-ha-service
  namespace: production-ha
spec:
  selector:
    tier: data
  ports:
  - port: 5432
    targetPort: 5432
    name: postgres
---
# Frontend configuration with health checks
apiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-ha-config
  namespace: production-ha
data:
  nginx.conf: |
    upstream api_backend {
        server api-ha-service:80;
        keepalive 32;
    }
    
    server {
        listen 80;
        
        # Health check endpoint
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
        
        # Main application
        location / {
            return 200 '🏭 Production HA Frontend\nPod: $hostname\nTime: $time_iso8601\nHA Level: Multi-Zone\nReplicas: 6\nAPI Backend: api-ha-service\n';
            add_header Content-Type text/plain;
            add_header X-Pod-Name $hostname;
        }
        
        # API proxy with health checking
        location /api/ {
            proxy_pass http://api_backend/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_connect_timeout 5s;
            proxy_send_timeout 10s;
            proxy_read_timeout 10s;
        }
        
        # Metrics endpoint
        location /metrics {
            stub_status on;
            access_log off;
        }
    }
    
    server {
        listen 9090;
        location /metrics {
            stub_status on;
            access_log off;
        }
    }
EOF

kubectl apply -f ha-architecture.yaml

# Wait for HA deployment
echo "🏭 Deploying High Availability Architecture..."
kubectl wait --for=condition=available deployment --all -n production-ha --timeout=300s
kubectl wait --for=condition=ready pod -l tier=data -n production-ha --timeout=300s

# Test HA characteristics
echo "🔍 High Availability Testing Suite"
echo "=================================="

cat << 'EOF' > ha-testing-suite.sh
#!/bin/bash

test_multi_zone_distribution() {
    echo "🌍 MULTI-ZONE DISTRIBUTION TEST"
    echo "==============================="
    
    echo "Pod distribution across nodes/zones:"
    kubectl get pods -n production-ha -o wide --sort-by='.spec.nodeName'
    
    echo ""
    echo "Service endpoint distribution:"
    for service in frontend-ha-service api-ha-service database-ha-service; do
        endpoints=$(kubectl get endpoints $service -n production-ha -o jsonpath='{.subsets[*].addresses[*].ip}' | wc -w)
        echo "  $service: $endpoints endpoints"
    done
}

test_service_resilience() {
    echo ""
    echo "💪 SERVICE RESILIENCE TEST"
    echo "========================="
    
    echo "Testing service availability during pod failures..."
    
    # Get initial pod count
    initial_frontend_pods=$(kubectl get pods -l tier=web -n production-ha --no-headers | wc -l)
    initial_api_pods=$(kubectl get pods -l tier=api -n production-ha --no-headers | wc -l)
    
    echo "Initial state:"
    echo "  Frontend pods: $initial_frontend_pods"
    echo "  API pods: $initial_api_pods"
    
    echo ""
    echo "Simulating pod failures..."
    
    # Kill some pods to test resilience
    frontend_pod=$(kubectl get pods -l tier=web -n production-ha -o name | head -1)
    api_pod=$(kubectl get pods -l tier=api -n production-ha -o name | head -1)
    
    echo "Deleting pods: $frontend_pod, $api_pod"
    kubectl delete $frontend_pod $api_pod -n production-ha &
    
    # Test service availability during pod recreation
    echo "Testing service availability during pod recreation..."
    
    for i in {1..10}; do
        echo "Availability test $i:"
        kubectl run resilience-test-$i --image=curlimages/curl --rm --restart=Never \
            --namespace=production-ha -- timeout 3 curl -s frontend-ha-service | head -1 || echo "   ❌ Service unavailable"
        sleep 2
    done
    
    # Wait for pods to be recreated
    kubectl wait --for=condition=ready pod -l tier=web -n production-ha --timeout=120s
    kubectl wait --for=condition=ready pod -l tier=api -n production-ha --timeout=120s
    
    final_frontend_pods=$(kubectl get pods -l tier=web -n production-ha --no-headers | wc -l)
    final_api_pods=$(kubectl get pods -l tier=api -n production-ha --no-headers | wc -l)
    
    echo ""
    echo "Recovery validation:"
    echo "  Frontend pods: $final_frontend_pods (should equal $initial_frontend_pods)"
    echo "  API pods: $final_api_pods (should equal $initial_api_pods)"
    
    if [ "$final_frontend_pods" -eq "$initial_frontend_pods" ] && [ "$final_api_pods" -eq "$initial_api_pods" ]; then
        echo "  ✅ All pods successfully recreated"
    else
        echo "  ❌ Pod count mismatch after recovery"
    fi
}

test_load_balancing_efficiency() {
    echo ""
    echo "⚖️ LOAD BALANCING EFFICIENCY TEST"
    echo "================================"
    
    echo "Testing load distribution across multiple replicas..."
    
    # Create multiple concurrent connections
    for i in {1..20}; do
        kubectl run load-test-$i --image=curlimages/curl --restart=Never \
            --namespace=production-ha -- curl -s frontend-ha-service | grep "Pod:" &
    done
    
    # Wait for all tests to complete
    wait
    
    # Clean up test pods
    kubectl delete pods -l run -n production-ha --ignore-not-found=true >/dev/null 2>&1
    
    echo "Load balancing test completed."
    echo "In production, monitor for even distribution across pods."
}

test_database_ha_setup() {
    echo ""
    echo "🗄️ DATABASE HIGH AVAILABILITY TEST"
    echo "=================================="
    
    echo "Database cluster status:"
    kubectl get pods -l tier=data -n production-ha
    
    echo ""
    echo "Database service endpoints:"
    kubectl get endpoints database-ha-service -n production-ha
    kubectl get endpoints database-ha-headless -n production-ha
    
    echo ""
    echo "Testing database connectivity:"
    kubectl run db-test --image=postgres:13-alpine --rm --restart=Never \
        --namespace=production-ha -- psql -h database-ha-service -U produser -d proddb -c "SELECT 'Database HA test successful' as status;" || echo "Database connection failed"
    
    echo ""
    echo "Individual database pod access (headless service):"
    for i in {0..2}; do
        echo "Testing database-ha-$i:"
        kubectl run db-direct-test-$i --image=postgres:13-alpine --rm --restart=Never \
            --namespace=production-ha -- timeout 5 pg_isready -h database-ha-$i.database-ha-headless -U produser && echo "  ✅ Pod $i healthy" || echo "  ❌ Pod $i unhealthy"
    done
}

generate_ha_dashboard() {
    echo ""
    echo "📊 HIGH AVAILABILITY DASHBOARD"
    echo "=============================="
    
    echo "System Overview:"
    echo "┌─────────────────┬─────────┬───────────┬─────────────┬────────────────┐"
    echo "│ Service Tier    │ Desired │ Available │ Endpoints   │ HA Status      │"
    echo "├─────────────────┼─────────┼───────────┼─────────────┼────────────────┤"
    
    # Frontend stats
    frontend_desired=$(kubectl get deployment frontend-ha -n production-ha -o jsonpath='{.spec.replicas}')
    frontend_available=$(kubectl get deployment frontend-ha -n production-ha -o jsonpath='{.status.availableReplicas}')
    frontend_endpoints=$(kubectl get endpoints frontend-ha-service -n production-ha -o jsonpath='{.subsets[*].addresses[*].ip}' | wc -w)
    
    if [ "$frontend_available" = "$frontend_desired" ]; then
        frontend_status="✅ Healthy"
    else
        frontend_status="❌ Degraded"
    fi
    
    printf "│ %-15s │ %-7s │ %-9s │ %-11s │ %-14s │\n" "Frontend" "$frontend_desired" "$frontend_available" "$frontend_endpoints" "$frontend_status"
    
    # API stats  
    api_desired=$(kubectl get deployment api-ha -n production-ha -o jsonpath='{.spec.replicas}')
    api_available=$(kubectl get deployment api-ha -n production-ha -o jsonpath='{.status.availableReplicas}')
    api_endpoints=$(kubectl get endpoints api-ha-service -n production-ha -o jsonpath='{.subsets[*].addresses[*].ip}' | wc -w)
    
    if [ "$api_available" = "$api_desired" ]; then
        api_status="✅ Healthy"
    else
        api_status="❌ Degraded"
    fi
    
    printf "│ %-15s │ %-7s │ %-9s │ %-11s │ %-14s │\n" "API" "$api_desired" "$api_available" "$api_endpoints" "$api_status"
    
    # Database stats
    db_desired=$(kubectl get statefulset database-ha -n production-ha -o jsonpath='{.spec.replicas}')
    db_ready=$(kubectl get statefulset database-ha -n production-ha -o jsonpath='{.status.readyReplicas}')
    db_endpoints=$(kubectl get endpoints database-ha-service -n production-ha -o jsonpath='{.subsets[*].addresses[*].ip}' | wc -w)
    
    if [ "$db_ready" = "$db_desired" ]; then
        db_status="✅ Healthy"
    else
        db_status="❌ Degraded"
    fi
    
    printf "│ %-15s │ %-7s │ %-9s │ %-11s │ %-14s │\n" "Database" "$db_desired" "$db_ready" "$db_endpoints" "$db_status"
    
    echo "└─────────────────┴─────────┴───────────┴─────────────┴────────────────┘"
    
    echo ""
    echo "High Availability Features:"
    echo "✅ Multi-zone pod distribution"
    echo "✅ Pod anti-affinity rules"  
    echo "✅ Rolling update strategy"
    echo "✅ Health checks and auto-healing"
    echo "✅ Multiple service replicas"
    echo "✅ Load balancer integration"
    echo "✅ Persistent storage for stateful services"
    
    echo ""
    echo "Recommended Monitoring:"
    echo "📊 Service response times and error rates"
    echo "📊 Pod restart frequency and reasons"
    echo "📊 Resource utilization across zones"
    echo "📊 Database replication lag"
    echo "📊 Load balancer health checks"
}

# Main HA testing suite
main() {
    echo "🎯 HIGH AVAILABILITY TESTING SUITE"
    echo "=================================="
    echo ""
    
    test_multi_zone_distribution
    test_service_resilience
    test_load_balancing_efficiency
    test_database_ha_setup
    generate_ha_dashboard
    
    echo ""
    echo "🏆 PRODUCTION HA RECOMMENDATIONS:"
    echo "================================="
    echo "✅ Deploy across multiple availability zones"
    echo "✅ Use pod anti-affinity for critical services"
    echo "✅ Implement comprehensive health checks"
    echo "✅ Configure appropriate resource limits"
    echo "✅ Set up automated monitoring and alerting"
    echo "✅ Test disaster recovery procedures regularly"
    echo "✅ Implement circuit breakers and rate limiting"
    echo "✅ Use blue/green or canary deployments"
    echo "✅ Maintain runbooks for incident response"
    echo "✅ Regular backup and restore testing"
}

main
EOF

chmod +x ha-testing-suite.sh
./ha-testing-suite.sh
```

### Lab 9.2: Disaster Recovery and Business Continuity

The final lab covers disaster recovery patterns and business continuity planning for Kubernetes Services.

```bash
# Create disaster recovery demonstration
kubectl create namespace disaster-recovery

# Deploy applications with backup and recovery capabilities
cat << 'EOF' > dr-architecture.yaml
# Primary application deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: primary-app
  namespace: disaster-recovery
  labels:
    disaster-recovery.io/tier: primary
    disaster-recovery.io/backup-policy: critical
spec:
  replicas: 3
  selector:
    matchLabels:
      app: primary-app
      tier: primary
  template:
    metadata:
      labels:
        app: primary-app
        tier: primary
      annotations:
        backup.disaster-recovery.io/frequency: "15min"
        backup.disaster-recovery.io/retention: "7d"
    spec:
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: app-data
          mountPath: /usr/share/nginx/html
        - name: config
          mountPath: /etc/nginx/conf.d/default.conf
          subPath: nginx.conf
      volumes:
      - name: app-data
        persistentVolumeClaim:
          claimName: primary-app-data
      - name: config
        configMap:
          name: primary-app-config
---
# Database with backup strategy
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: primary-database
  namespace: disaster-recovery
  labels:
    disaster-recovery.io/tier: data
    disaster-recovery.io/backup-policy: critical
spec:
  serviceName: primary-database-headless
  replicas: 1
  selector:
    matchLabels:
      app: primary-database
      tier: data
  template:
    metadata:
      labels:
        app: primary-database
        tier: data
      annotations:
        backup.disaster-recovery.io/frequency: "1h"
        backup.disaster-recovery.io/retention: "30d"
    spec:
      containers:
      - name: postgres
        image: postgres:13-alpine
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_DB
          value: primarydb
        - name: POSTGRES_USER
          value: primaryuser
        - name: POSTGRES_PASSWORD
          value: primarypass
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        - name: backup-scripts
          mountPath: /backup-scripts
      - name: backup-sidecar
        image: postgres:13-alpine
        command: ['/bin/bash', '-c']
        args:
        - |
          while true; do
            echo "$(date): Starting backup..."
            pg_dump -h localhost -U primaryuser -d primarydb > /backups/backup-$(date +%Y%m%d-%H%M%S).sql
            echo "$(date): Backup completed"
            # Cleanup old backups (keep last 168 hours = 7 days)
            find /backups -name "backup-*.sql" -mtime +7 -delete
            sleep 3600  # Backup every hour
          done
        env:
        - name: PGPASSWORD
          value: primarypass
        volumeMounts:
        - name: backup-storage
          mountPath: /backups
      volumes:
      - name: backup-scripts
        configMap:
          name: backup-scripts
          defaultMode: 0755
  volumeClaimTemplates:
  - metadata:
      name: postgres-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 5Gi
  - metadata:
      name: backup-storage
    spec:
      accessModes: ["ReadWriteOnce"]  
      resources:
        requests:
          storage: 10Gi
---
# Standby/DR site simulation
apiVersion: apps/v1
kind: Deployment
metadata:
  name: standby-app
  namespace: disaster-recovery
  labels:
    disaster-recovery.io/tier: standby
    disaster-recovery.io/role: disaster-recovery
spec:
  replicas: 1  # Minimal resources in standby
  selector:
    matchLabels:
      app: standby-app
      tier: standby
  template:
    metadata:
      labels:
        app: standby-app
        tier: standby
    spec:
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: config
          mountPath: /etc/nginx/conf.d/default.conf
          subPath: nginx.conf
      volumes:
      - name: config
        configMap:
          name: standby-app-config
---
# Services for primary and standby
apiVersion: v1
kind: Service
metadata:
  name: primary-service
  namespace: disaster-recovery
  labels:
    disaster-recovery.io/active: "true"
spec:
  type: LoadBalancer
  selector:
    tier: primary
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: primary-database-service
  namespace: disaster-recovery
spec:
  selector:
    tier: data
  ports:
  - port: 5432
    targetPort: 5432
---
apiVersion: v1
kind: Service
metadata:
  name: primary-database-headless
  namespace: disaster-recovery
spec:
  clusterIP: None
  selector:
    tier: data
  ports:
  - port: 5432
    targetPort: 5432
---
apiVersion: v1
kind: Service
metadata:
  name: standby-service
  namespace: disaster-recovery
  labels:
    disaster-recovery.io/active: "false"
spec:
  selector:
    tier: standby
  ports:
  - port: 80
    targetPort: 80
---
# Storage for primary app
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: primary-app-data
  namespace: disaster-recovery
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
# Configuration files
apiVersion: v1
kind: ConfigMap
metadata:
  name: primary-app-config
  namespace: disaster-recovery
data:
  nginx.conf: |
    server {
        listen 80;
        location / {
            return 200 '🏭 PRIMARY SITE\nStatus: Active\nDR Tier: Primary\nTime: $time_iso8601\nBackup: Enabled\nReplication: Active\n';
            add_header Content-Type text/plain;
            add_header X-DR-Site "primary";
            add_header X-DR-Status "active";
        }
        location /health {
            return 200 'primary-healthy';
            add_header Content-Type text/plain;
        }
        location /dr-status {
            return 200 'PRIMARY-ACTIVE';
            add_header Content-Type text/plain;
        }
    }
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: standby-app-config
  namespace: disaster-recovery
data:
  nginx.conf: |
    server {
        listen 80;
        location / {
            return 200 '🏥 STANDBY SITE\nStatus: Standby\nDR Tier: Secondary\nTime: $time_iso8601\nReady for: Failover\nLast Sync: $time_iso8601\n';
            add_header Content-Type text/plain;
            add_header X-DR-Site "standby";
            add_header X-DR-Status "standby";
        }