# Unit 5: Production Patterns & Troubleshooting
**Duration**: 4-5 hours  
**Core Question**: "How do I maintain optimal resource utilization in a production environment at scale?"

## 🎯 Learning Objectives
By the end of this unit, you will:
- Implement production-ready resource management patterns
- Troubleshoot complex resource-related issues in live environments
- Design resilient resource architectures that handle failures gracefully
- Create comprehensive monitoring and alerting for resource management
- Build runbooks for common resource management scenarios
- Operate resource optimization systems at enterprise scale

## 🏗️ Building on Your Complete Foundation

You've mastered the fundamentals (Unit 1), monitoring (Unit 2), governance (Unit 3), and intelligent optimization (Unit 4). Now it's time for the reality of production operations.

**🤔 Production Reality Check**:
- What happens when VPA recommendations conflict with application performance?
- How do you handle resource management during a major incident?
- What's your strategy when intelligent optimization goes wrong?
- How do you maintain resource efficiency as your cluster grows from 100 to 10,000 pods?

Today we'll explore the battle-tested patterns and troubleshooting techniques that keep production Kubernetes clusters running optimally under real-world conditions.

---

## 🚨 Foundation: Production Resource Management Challenges

### Step 1: Understanding Production Complexity

```bash
# Set up a realistic production-simulation environment
kubectl create namespace prod-simulation
kubectl config set-context --current --namespace=prod-simulation

# Create a realistic production-like setup with common issues
cat << EOF | kubectl apply -f -
# Simulate a production environment with various resource patterns
apiVersion: v1
kind: ConfigMap
metadata:
  name: production-scenarios
data:
  # Traffic spike simulation
  traffic-spike.sh: |
    #!/bin/sh
    echo "Simulating traffic spike pattern..."
    for hour in \$(seq 1 24); do
      if [ \$hour -ge 9 ] && [ \$hour -le 17 ]; then
        # Business hours - high load
        stress_level=\$(((hour - 8) * 10))
        echo "Hour \$hour: Business hours - stress level \$stress_level"
        yes > /dev/null &
        PID=\$!
        sleep 300  # 5 minutes
        kill \$PID
      elif [ \$hour -ge 18 ] && [ \$hour -le 22 ]; then
        # Evening - medium load  
        echo "Hour \$hour: Evening traffic"
        sleep 150
        yes > /dev/null &
        PID=\$!
        sleep 150
        kill \$PID
      else
        # Night/early morning - low load
        echo "Hour \$hour: Low traffic period"
        sleep 300
      fi
    done
  
  # Memory leak simulation
  memory-leak.sh: |
    #!/bin/sh
    echo "Simulating gradual memory leak..."
    counter=0
    while true; do
      counter=\$((counter + 1))
      # Allocate memory that doesn't get freed
      dd if=/dev/zero of=/tmp/leak\$counter bs=1M count=10 2>/dev/null
      echo "Memory allocation cycle \$counter completed"
      sleep 60
      
      # Simulate occasional cleanup (imperfect leak)
      if [ \$((counter % 10)) -eq 0 ]; then
        rm -f /tmp/leak\$((counter - 5))
        echo "Partial cleanup performed"
      fi
    done
  
  # Database connection pool simulation
  db-connection-spike.sh: |
    #!/bin/sh
    echo "Simulating database connection pool behavior..."
    while true; do
      # Simulate connection pool growth
      for i in \$(seq 1 50); do
        echo "DB connection \$i established" 
        sleep 0.1
      done
      
      # Hold connections and consume CPU
      yes > /dev/null &
      CPU_PID=\$!
      sleep 30
      kill \$CPU_PID
      
      # Release connections  
      echo "Releasing database connections"
      sleep 10
    done
EOF
```

### Step 2: Deploy Production-Realistic Workloads

```bash
# Create workloads that represent common production patterns
cat << EOF | kubectl apply -f -
# Web frontend with variable traffic patterns
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-frontend
  labels:
    tier: frontend
    criticality: high
spec:
  replicas: 5
  selector:
    matchLabels:
      app: web-frontend
  template:
    metadata:
      labels:
        app: web-frontend
        tier: frontend
    spec:
      containers:
      - name: web
        image: nginx:alpine
        command: ["/bin/sh"]
        args: ["/scripts/traffic-spike.sh"]
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 1
            memory: 1Gi
        volumeMounts:
        - name: scripts
          mountPath: /scripts
      volumes:
      - name: scripts
        configMap:
          name: production-scenarios
          defaultMode: 0755
---
# API backend with potential memory leaks
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-backend
  labels:
    tier: backend
    criticality: high
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api-backend
  template:
    metadata:
      labels:
        app: api-backend
        tier: backend
    spec:
      containers:
      - name: api
        image: alpine:latest
        command: ["/bin/sh"]
        args: ["/scripts/memory-leak.sh"]
        resources:
          requests:
            cpu: 300m
            memory: 512Mi
          limits:
            cpu: 1
            memory: 2Gi
        volumeMounts:
        - name: scripts
          mountPath: /scripts
      volumes:
      - name: scripts
        configMap:
          name: production-scenarios
          defaultMode: 0755
---
# Database with connection pooling
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database-service
  labels:
    tier: data
    criticality: critical
spec:
  replicas: 2
  selector:
    matchLabels:
      app: database-service
  template:
    metadata:
      labels:
        app: database-service
        tier: data
    spec:
      containers:
      - name: database
        image: postgres:13-alpine
        env:
        - name: POSTGRES_DB
          value: proddb
        - name: POSTGRES_USER
          value: dbuser
        - name: POSTGRES_PASSWORD
          value: dbpass123
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            cpu: 2
            memory: 4Gi
      - name: connection-monitor
        image: alpine:latest
        command: ["/bin/sh"]
        args: ["/scripts/db-connection-spike.sh"]
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        volumeMounts:
        - name: scripts
          mountPath: /scripts
      volumes: