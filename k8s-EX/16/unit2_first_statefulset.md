# Unit 2: Your First StatefulSet - Basic Creation and Management

## Learning Objectives
By the end of this unit, you will:
- Create your first StatefulSet using both imperative and declarative approaches
- Observe stable pod naming and ordered creation in action
- Perform basic StatefulSet operations: scaling, updating, and deletion
- Understand the relationship between StatefulSets and headless services
- Experience the persistence guarantees that StatefulSets provide

## Prerequisites Check
Before diving in, ensure you have:
- A working Kubernetes cluster (local or cloud)
- `kubectl` configured and tested
- Understanding of basic pod and service concepts
- Completion of Unit 1 concepts

Quick verification:
```bash
kubectl cluster-info
kubectl get nodes
```

## Guided Discovery: Creating Your First StatefulSet

Instead of jumping straight into complex YAML, let's build understanding through exploration and experimentation.

### Step 1: The Imperative Approach - Quick Start

Let's start with the simplest possible StatefulSet to see the core behaviors:

```bash
# Create a basic StatefulSet imperatively
kubectl create statefulset web --image=nginx:alpine --replicas=3 \
  --dry-run=client -o yaml > basic-statefulset.yaml

# Examine what was generated
cat basic-statefulset.yaml
```

**Guided Questions:**
- What do you notice about the structure compared to a Deployment YAML?
- What's missing that we identified as important in Unit 1?
- Why might the `--dry-run=client` flag be useful here?

### Step 2: Understanding the Missing Pieces

The generated YAML is incomplete for a functional StatefulSet. Let's identify what's missing:

```bash
# Try to apply the basic StatefulSet
kubectl apply -f basic-statefulset.yaml

# Check what happens
kubectl get statefulset web
kubectl get pods -l app=web -w
```

**Observation Exercise:**
- Do the pods start successfully?
- What pattern do you see in the pod names?
- How long do you wait between pod creations?

### Step 3: Adding the Missing Service

StatefulSets need a headless service for stable networking. Let's create one:

```bash
# Create a headless service
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: web
  labels:
    app: web
spec:
  ports:
  - port: 80
    name: web
  clusterIP: None  # This makes it headless
  selector:
    app: web
EOF

# Now check the StatefulSet behavior
kubectl get pods -l app=web
```

**Critical Thinking Questions:**
- What changed after adding the service?
- Why is `clusterIP: None` important?
- How can you verify the stable DNS names are working?

### Step 4: Testing Stable Network Identity

Let's verify that pods get stable DNS names:

```bash
# Create a test pod to check DNS resolution
kubectl run dns-test --image=busybox:1.35 --restart=Never -it -- sh

# Inside the test pod, try these commands:
nslookup web-0.web
nslookup web-1.web
nslookup web-2.web
nslookup web

# Exit and clean up the test pod
exit
kubectl delete pod dns-test
```

**Reflection Questions:**
- What DNS names did each pod receive?
- How does the headless service (`web`) resolve differently from individual pods?
- Why might this stable naming be crucial for database clustering?

## Hands-On Lab: Building a Complete StatefulSet

Now let's create a more realistic StatefulSet with persistent storage. We'll build a simple web server that maintains local state.

### Lab Setup: StatefulSet with Persistent Storage

```bash
# First, let's clean up our basic example
kubectl delete statefulset web
kubectl delete service web

# Create a complete StatefulSet configuration
cat << EOF | kubectl apply -f -
# Headless service for stable network identity
apiVersion: v1
kind: Service
metadata:
  name: webapp
  labels:
    app: webapp
spec:
  ports:
  - port: 80
    name: web
  clusterIP: None
  selector:
    app: webapp
---
# StatefulSet with persistent storage
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: webapp
spec:
  serviceName: "webapp"  # Links to our headless service
  replicas: 3
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - name: web
        image: nginx:alpine
        ports:
        - containerPort: 80
          name: web
        # Mount persistent storage
        volumeMounts:
        - name: webapp-storage
          mountPath: /usr/share/nginx/html
        # Add a simple initialization script
        command: ["/bin/sh"]
        args: ["-c", "echo 'Hello from \$(hostname)' > /usr/share/nginx/html/index.html && nginx -g 'daemon off;'"]
  # This is the key difference - persistent volume templates
  volumeClaimTemplates:
  - metadata:
      name: webapp-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 1Gi
EOF
```

### Lab Exercise 1: Observe Ordered Creation

```bash
# Watch the pods being created
kubectl get pods -l app=webapp -w
```

**Guided Observation:**
- In what order are the pods created?
- Does each pod wait for the previous one to be Ready?
- How long does the entire process take?

**Pause the watch (Ctrl+C) and check storage:**

```bash
# Check the persistent volume claims
kubectl get pvc -l app=webapp

# Describe one to see the details
kubectl describe pvc webapp-storage-webapp-0
```

**Analysis Questions:**
- How many PVCs were created?
- What naming pattern do they follow?
- What happens to the PVC if you delete a pod?

### Lab Exercise 2: Test Persistence

Let's verify that data actually persists across pod restarts:

```bash
# Connect to webapp-0 and create some custom content
kubectl exec -it webapp-0 -- sh

# Inside the pod:
echo "Custom content from webapp-0 at $(date)" > /usr/share/nginx/html/custom.html
ls -la /usr/share/nginx/html/
exit

# Test the content is accessible
kubectl exec webapp-0 -- cat /usr/share/nginx/html/custom.html

# Now delete the pod and watch it recreate
kubectl delete pod webapp-0
kubectl get pods -l app=webapp -w
```

**Wait for webapp-0 to be Running again, then test:**

```bash
# Check if our custom content survived
kubectl exec webapp-0 -- cat /usr/share/nginx/html/custom.html
```

**Critical Analysis:**
- Did your custom content survive the pod deletion?
- What does this tell you about how StatefulSets handle storage?
- How is this different from what would happen with a Deployment?

## StatefulSet Management Operations

Now let's explore the key management operations you'll need in production.

### Scaling StatefulSets

```bash
# Scale up to 5 replicas
kubectl scale statefulset webapp --replicas=5

# Watch the scaling process
kubectl get pods -l app=webapp -w
```

**Guided Questions:**
- Which pods are created first when scaling up?
- Do new pods wait for existing ones to be ready?
- How does this compare to Deployment scaling?

```bash
# Scale back down to 2 replicas
kubectl scale statefulset webapp --replicas=2

# Observe the scale-down process
kubectl get pods -l app=webapp
kubectl get pvc -l app=webapp
```

**Important Discovery:**
- Which pods were deleted when scaling down?
- What happened to their PVCs?
- Why might this behavior be important for stateful applications?

### Updating StatefulSets

```bash
# Update the container image
kubectl set image statefulset webapp web=nginx:1.21-alpine

# Monitor the rolling update
kubectl rollout status statefulset webapp
kubectl get pods -l app=webapp -w
```

**Observation Exercise:**
- In what order are pods updated?
- Why might updates happen in reverse order?
- How does this minimize disruption for clustered applications?

### Inspection and Troubleshooting

```bash
# Get detailed StatefulSet information
kubectl describe statefulset webapp

# Check the update history
kubectl rollout history statefulset webapp

# View events for troubleshooting
kubectl get events --sort-by=.metadata.creationTimestamp
```

**Skill Development Questions:**
- What information in `describe` output helps you understand StatefulSet health?
- How can events help you troubleshoot startup issues?
- What would you look for if pods were stuck in Pending state?

## Comparison Exercise: StatefulSet vs Deployment Behavior

Let's create a side-by-side comparison to solidify your understanding:

```bash
# Create a Deployment for comparison
kubectl create deployment webapp-deploy --image=nginx:alpine --replicas=3

# Compare the pod names
echo "=== StatefulSet Pods ==="
kubectl get pods -l app=webapp

echo "=== Deployment Pods ==="
kubectl get pods -l app=webapp-deploy

# Delete one pod from each and observe
kubectl delete pod webapp-1
kubectl delete pod $(kubectl get pods -l app=webapp-deploy -o jsonpath='{.items[0].metadata.name}')

# Watch the replacements
kubectl get pods -l app=webapp -o wide
kubectl get pods -l app=webapp-deploy -o wide
```

**Comparative Analysis:**
- What differences do you notice in pod naming?
- How do replacement pods behave differently?
- Which approach would be better for a database cluster? Why?

## Common Patterns and Troubleshooting

### Understanding StatefulSet States

```bash
# Check StatefulSet status
kubectl get statefulset webapp -o wide

# Common states you might see:
# - Ready: 3/3 (all pods running and ready)
# - Ready: 2/3 (one pod having issues)
# - Ready: 0/3 (startup problems)
```

### Troubleshooting Stuck Pods

If a StatefulSet pod gets stuck, it blocks the creation of subsequent pods. Here's how to investigate:

```bash
# Check pod status
kubectl get pods -l app=webapp

# For any stuck pod, investigate:
kubectl describe pod webapp-X  # Replace X with actual pod number
kubectl logs webapp-X

# Check PVC binding issues
kubectl get pvc
kubectl describe pvc webapp-storage-webapp-X
```

**Troubleshooting Checklist:**
1. Is the pod stuck in Pending? → Check PVC binding and node resources
2. Is the pod in CrashLoopBackOff? → Check logs and container configuration  
3. Is the pod Ready but not serving traffic? → Check readiness probes
4. Are subsequent pods not starting? → StatefulSets wait for each pod to be Ready

## Unit Challenge: Apply Your Knowledge

Create a StatefulSet for a simple counter application that:

1. Runs 3 replicas
2. Each pod maintains a counter file in persistent storage
3. Provides stable network identity
4. Updates in an ordered fashion

**Starter Template:**
```bash
cat << EOF > challenge-statefulset.yaml
# Your challenge: Complete this StatefulSet configuration
# Requirements:
# - Use image: busybox:1.35
# - Command that creates and increments a counter file
# - Persistent storage for the counter
# - Proper headless service

# Add your service and StatefulSet configuration here
EOF
```

**Verification Steps:**
1. Apply your configuration
2. Verify ordered pod creation
3. Check that each pod maintains its own counter
4. Test persistence by deleting and recreating pods
5. Demonstrate stable DNS names

## Self-Assessment and Cleanup

### Knowledge Check Questions:

1. **Conceptual Understanding:**
   - Why does a StatefulSet need a headless service?
   - How does ordered pod creation benefit stateful applications?

2. **Practical Skills:**
   - How would you troubleshoot a StatefulSet where pod-1 never starts?
   - What's the difference between scaling a StatefulSet vs a Deployment?

3. **Real-World Application:**
   - When would you choose StatefulSet over Deployment?
   - How do persistent volume templates work?

### Cleanup Commands:
```bash
# Remove all resources created in this unit
kubectl delete statefulset webapp
kubectl delete statefulset webapp-deploy --ignore-not-found=true
kubectl delete service webapp
kubectl delete deployment webapp-deploy --ignore-not-found=true

# Note: PVCs remain by design - delete manually if needed
kubectl get pvc
# kubectl delete pvc webapp-storage-webapp-0 webapp-storage-webapp-1 webapp-storage-webapp-2
```

## Unit Summary

### Key Concepts Mastered:
- **Imperative vs Declarative**: When to use each approach for StatefulSets
- **Essential Components**: Headless services and volume claim templates  
- **Ordered Operations**: Creation, scaling, and update behaviors
- **Persistent Storage**: How PVCs provide data persistence
- **Management Operations**: Scaling, updating, and troubleshooting

### Skills Developed:
- Creating and configuring StatefulSets
- Observing and understanding ordered pod lifecycle
- Managing persistent storage in Kubernetes
- Troubleshooting common StatefulSet issues
- Comparing StatefulSet vs Deployment behaviors

### Looking Ahead to Unit 3:
In Unit 3, we'll dive deep into persistent storage concepts, exploring volume claim templates, storage classes, and advanced data persistence patterns. You'll learn how to design robust storage solutions for stateful applications.

**Preparation Questions for Unit 3:**
- What questions do you have about persistent storage?
- Have you encountered any storage-related challenges in your Kubernetes experience?
- What types of data persistence requirements might different applications have?