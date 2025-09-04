# Unit 1: Resource Management Fundamentals
**Duration**: 2-3 hours  
**Core Question**: "How does Kubernetes decide where to place my pods and what resources they can use?"

## 🎯 Learning Objectives
By the end of this unit, you will:
- Understand the difference between resource requests and limits
- Recognize the three Quality of Service (QoS) classes
- Create pods with appropriate resource specifications
- Predict how Kubernetes will schedule pods based on resource constraints

## 🔍 Pre-Assessment: Where Are You Starting?

Before we dive in, let's establish your baseline. Try to answer these questions based on what you currently know:

1. **When you create a pod without specifying any resource requirements, what happens?**
   - Can it be scheduled on any node?
   - How much CPU and memory can it use?
   - What happens if it tries to use too much memory?

2. **If you have a 4-CPU, 8GB RAM node, and you want to run 10 identical pods on it, what should you consider?**

Don't worry if you're unsure - these questions will guide our exploration!

---

## 📚 Foundation Concepts

### The Restaurant Analogy
Think of Kubernetes resource management like a restaurant:
- **Resource Requests** = Making a reservation ("I need a table for 4")
- **Resource Limits** = The fire code maximum ("This room holds max 100 people")
- **Node Capacity** = The restaurant's total seating
- **Scheduler** = The host who decides where to seat you

### Step 1: Understanding Resource Requests

Let's start with a simple experiment:

```bash
# Create your lab namespace
kubectl create namespace resource-lab
kubectl config set-context --current --namespace=resource-lab

# Create a pod WITHOUT resource specifications
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: no-resources
  labels:
    experiment: step-1
spec:
  containers:
  - name: app
    image: nginx:alpine
    ports:
    - containerPort: 80
EOF

# Check if it was scheduled
kubectl get pod no-resources -o wide
```

**🤔 Reflection Question**: What node was your pod placed on? How do you think Kubernetes made that decision?

Now let's add resource requests:

```bash
# Create a pod WITH resource requests
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: with-requests
  labels:
    experiment: step-1
spec:
  containers:
  - name: app
    image: nginx:alpine
    ports:
    - containerPort: 80
    resources:
      requests:
        cpu: 100m      # 0.1 CPU core
        memory: 128Mi  # 128 MB RAM
EOF

# Compare the scheduling behavior
kubectl describe pod with-requests | grep -A 5 "QoS Class"
kubectl describe pod no-resources | grep -A 5 "QoS Class"
```

**🔍 Investigation Questions**:
- What's different about the "QoS Class" between these two pods?
- Which pod would be prioritized if the node runs out of resources?

### Step 2: Understanding Resource Limits

Now let's explore what happens when we set limits:

```bash
# Create a pod with both requests and limits
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: with-limits
  labels:
    experiment: step-2
spec:
  containers:
  - name: app
    image: nginx:alpine
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 200m      # Maximum 0.2 CPU cores
        memory: 256Mi  # Maximum 256 MB RAM
EOF

# Check the QoS class
kubectl describe pod with-limits | grep "QoS Class"
```

**💡 Key Insight**: You now have all three QoS classes represented. Can you identify them?

### Step 3: Testing Resource Limits in Action

Let's see what happens when a pod tries to exceed its limits:

```bash
# Create a memory stress test pod
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: memory-stress
  labels:
    experiment: step-3
spec:
  containers:
  - name: stress
    image: polinux/stress
    command: ["stress"]
    args: ["--vm", "1", "--vm-bytes", "300M", "--vm-hang", "1"]
    resources:
      requests:
        memory: 100Mi
      limits:
        memory: 200Mi  # This is LESS than what the app tries to use (300M)
EOF

# Watch what happens
kubectl get pod memory-stress -w
```

**🎯 Challenge Question**: What do you predict will happen and why?

After observing the behavior, check the events:
```bash
kubectl describe pod memory-stress | grep -A 10 Events
```

### Step 4: CPU vs Memory Behavior

Create a CPU stress test to see the difference:

```bash
# Create a CPU stress test pod
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: cpu-stress
  labels:
    experiment: step-4
spec:
  containers:
  - name: stress
    image: polinux/stress
    command: ["stress"]
    args: ["--cpu", "2", "--timeout", "300s"]
    resources:
      requests:
        cpu: 100m
      limits:
        cpu: 150m  # Less than what it's trying to use
EOF

# Monitor the CPU usage
kubectl top pod cpu-stress --containers
```

**🤔 Compare and Contrast**: How does CPU limiting differ from memory limiting?

---

## 🧪 Guided Lab: Build a Multi-Tier Application

Now let's apply what you've learned by building a realistic application with different resource profiles.

### Lab Setup: E-commerce Application
You'll create a simple e-commerce app with three components:
1. **Frontend**: Web server (moderate CPU, low memory)
2. **API**: Application server (high CPU during processing, moderate memory)
3. **Database**: Data storage (low CPU, high memory for caching)

### Lab Step 1: Design Resource Profiles

Before creating the YAML, let's think through the requirements:

**🤔 Planning Questions**:
1. Which component would need the most memory for its requests?
2. Which component might have the most variable CPU usage?
3. How would you set limits to allow bursting while preventing resource starvation?

### Lab Step 2: Create the Frontend

```bash
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  labels:
    tier: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ecommerce-frontend
  template:
    metadata:
      labels:
        app: ecommerce-frontend
        tier: frontend
    spec:
      containers:
      - name: web
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 100m     # Why this value?
            memory: 64Mi  # Why this value?
          limits:
            cpu: 300m     # Why allow this much bursting?
            memory: 128Mi # Why this limit?
EOF
```

**🔍 Analysis Questions**:
- Why might the frontend need CPU bursting capability?
- What would happen if many users hit the site simultaneously?

### Lab Step 3: Create the API Layer

```bash
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  labels:
    tier: api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ecommerce-api
  template:
    metadata:
      labels:
        app: ecommerce-api
        tier: api
    spec:
      containers:
      - name: api
        image: httpd:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 800m     # High burst capacity
            memory: 512Mi
EOF
```

### Lab Step 4: Create the Database

```bash
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database
  labels:
    tier: database
spec:
  replicas: 1  # Single instance for this lab
  selector:
    matchLabels:
      app: ecommerce-db
  template:
    metadata:
      labels:
        app: ecommerce-db
        tier: database
    spec:
      containers:
      - name: db
        image: postgres:13-alpine
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_DB
          value: ecommerce
        - name: POSTGRES_USER
          value: app
        - name: POSTGRES_PASSWORD
          value: secret123
        resources:
          requests:
            cpu: 100m      # Steady, predictable CPU
            memory: 512Mi  # High memory for caching
          limits:
            cpu: 400m
            memory: 1Gi    # Allow for large query processing
EOF
```

### Lab Step 5: Analyze Your Deployment

```bash
# Check all pods are running
kubectl get pods -o wide

# Examine resource allocations
kubectl describe deployments

# Check QoS classes across your application
kubectl get pods -o custom-columns="NAME:.metadata.name,QOS:.status.qosClass,NODE:.spec.nodeName"

# View resource requests vs limits
kubectl get pods -o json | jq -r '.items[] | "\(.metadata.name): CPU req=\(.spec.containers[0].resources.requests.cpu // "none") limit=\(.spec.containers[0].resources.limits.cpu // "none")"'
```

**🎯 Analysis Challenge**:
1. Which pods have the highest priority during resource contention?
2. If your node runs out of memory, which pods would be evicted first?
3. How would you adjust the resource specifications if you observed the API pods were frequently hitting their CPU limits?

---

## 🧠 Knowledge Check

Before moving to Unit 2, let's verify your understanding:

### Scenario-Based Questions

**Scenario 1**: You have a node with 2 CPU cores and 4GB RAM. You want to deploy 4 pods, each requesting 600m CPU and 1GB memory.
- Will all pods be scheduled? Why or why not?
- What would you change to make this work?

**Scenario 2**: A pod is defined with:
```yaml
resources:
  requests:
    memory: 256Mi
  limits:
    memory: 256Mi
    cpu: 500m
```
- What QoS class will this pod have?
- What happens if you don't specify a CPU request?

**Scenario 3**: During peak traffic, your application pods keep getting killed with "OOMKilled" status.
- What does this indicate?
- How would you investigate and fix this?

---

## 🚀 Mini-Project: Resource Right-Sizing Challenge

Your challenge is to optimize a poorly configured application:

```bash
# Deploy this intentionally poorly configured app
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wasteful-app
spec:
  replicas: 5
  selector:
    matchLabels:
      app: wasteful
  template:
    metadata:
      labels:
        app: wasteful
    spec:
      containers:
      - name: app
        image: nginx:alpine
        resources:
          requests:
            cpu: 1000m    # Way too much!
            memory: 2Gi   # Way too much!
          limits:
            cpu: 2000m
            memory: 4Gi
EOF
```

**Your Mission**:
1. Monitor the actual resource usage using `kubectl top`
2. Right-size the resource requests based on actual usage
3. Ensure the app can still handle traffic spikes
4. Calculate how much cluster capacity you freed up

**🎯 Success Criteria**:
- All 5 replicas should still run
- Resource requests should be within 20% of actual usage
- Limits should allow for reasonable bursting
- Document your reasoning for each change

---

## 📝 Unit 1 Wrap-Up

### Key Takeaways
Write down your answers to solidify your learning:

1. **In your own words, explain the difference between requests and limits.**

2. **When would you choose each QoS class and why?**
   - Guaranteed:
   - Burstable:
   - BestEffort:

3. **What's one insight about resource management that surprised you?**

### Preparation for Unit 2
In the next unit, we'll explore monitoring and analysis. Think about:
- How would you identify if your resource specifications are optimal?
- What metrics would tell you if an application is resource-starved or wasteful?
- How might you automate the right-sizing process you just did manually?

---

## 🧹 Lab Cleanup

```bash
# Clean up all resources from this unit
kubectl delete namespace resource-lab

# Or if you want to keep the namespace and just clean up pods/deployments
kubectl delete deployment --all -n resource-lab
kubectl delete pod --all -n resource-lab
```

**🎊 Congratulations!** You've mastered the fundamentals of Kubernetes resource management. You now understand how requests and limits work, can predict scheduling behavior, and can design resource specifications for multi-tier applications.

Ready for Unit 2? We'll dive into monitoring and analyzing resource usage patterns!