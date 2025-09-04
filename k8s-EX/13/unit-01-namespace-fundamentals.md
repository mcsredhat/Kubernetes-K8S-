# Unit 1: Namespace Fundamentals

## Learning Objectives
By the end of this unit, you will:
- Understand what Kubernetes namespaces are and why they exist
- Distinguish between namespace-scoped and cluster-scoped resources
- Explore default namespaces in a Kubernetes cluster
- Create your first custom namespace
- Apply basic resource organization principles

## Pre-Unit Reflection Questions
Before we start, take a moment to consider:
1. When working with files on your computer, how do you organize them? What happens when you have too many files in one location?
2. If you've worked with Kubernetes before, what challenges have you faced when managing multiple applications or environments?
3. What does "isolation" mean to you in a technical context?

## Part 1: Understanding the "Why" Behind Namespaces

### Discovery Exercise: The Apartment Building Analogy

Imagine Kubernetes as a large apartment building. Without organization, what problems might arise?

**Think about this scenario:** You manage a building where:
- 50 different families live (applications)
- Everyone shares the same mailbox system (resources)
- There are no apartment numbers (no names/organization)
- All utilities are shared without limits (no resource controls)

**Reflection Questions:**
1. What practical problems would residents face daily?
2. How would you organize this building to solve these issues?
3. What systems would you implement to manage resources fairly?

### The Kubernetes Reality

In a Kubernetes cluster without proper organization:
```bash
# Everything lives together - can you spot the problems?
kubectl get pods
# Output shows a mix of:
# - Production web servers
# - Development databases  
# - Monitoring tools
# - Test applications
# - System components
```

**Mini-Investigation:** 
Before reading further, what specific problems can you anticipate with this approach? List at least 3 concerns.

## Part 2: Exploring Your Current Cluster

### Demo 1: Default Namespace Discovery

Let's start by exploring what already exists in your cluster:

```bash
# Step 1: See all namespaces
kubectl get namespaces

# Step 2: Look more closely at the default namespace
kubectl describe namespace default

# Step 3: See what's currently in the default namespace
kubectl get all -n default
```

**Analysis Questions:**
1. How many namespaces exist by default in your cluster?
2. What kinds of resources do you see in each namespace?
3. Can you guess the purpose of each default namespace based on its name and contents?

### Demo 2: Understanding Namespace vs Cluster Scope

```bash
# Namespace-scoped resources (these belong TO a namespace)
kubectl api-resources --namespaced=true | head -10

# Cluster-scoped resources (these exist ACROSS the cluster)
kubectl api-resources --namespaced=false | head -10
```

**Discovery Exercise:**
1. Look at the two lists above. Why do you think some resources are namespace-scoped while others are cluster-scoped?
2. Pick 3 resources from each list. Can you explain why each belongs in its category?

### Demo 3: The Current Context Challenge

```bash
# Where am I working right now?
kubectl config get-contexts

# What namespace am I using by default?
kubectl config view --minify --output 'jsonpath={.contexts[0].context.namespace}'
```

**Problem to Solve:** If the output is empty, what namespace are your kubectl commands using by default?

## Part 3: Hands-On Namespace Creation

### Mini-Project 1: Your First Namespace

**Scenario:** You're setting up a development environment for a web application called "BookStore."

**Step 1: Plan Before You Build**
Before creating anything, answer these questions:
1. What should you name this namespace?
2. How will you document its purpose?
3. What labels might be useful for organization?

**Step 2: Create and Explore**

```yaml
# bookstore-dev-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: bookstore-dev
  labels:
    environment: development
    project: bookstore
    team: backend
  annotations:
    description: "Development environment for BookStore application"
    created-by: "your-name"
    contact: "your-email@company.com"
```

```bash
# Apply the namespace
kubectl apply -f bookstore-dev-namespace.yaml

# Verify creation
kubectl get namespace bookstore-dev -o yaml
```

**Analysis Questions:**
1. What additional metadata was automatically added to your namespace?
2. Why might the annotations be more useful than just the labels?

### Mini-Project 2: Working Within Your Namespace

**Challenge:** Deploy a simple application to your new namespace and explore the isolation.

```yaml
# simple-web-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: simple-web
  namespace: bookstore-dev
spec:
  replicas: 2
  selector:
    matchLabels:
      app: simple-web
  template:
    metadata:
      labels:
        app: simple-web
    spec:
      containers:
      - name: web
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: web-service
  namespace: bookstore-dev
spec:
  selector:
    app: simple-web
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
```

```bash
# Deploy the application
kubectl apply -f simple-web-app.yaml

# Explore the deployment
kubectl get all -n bookstore-dev
kubectl get all  # Notice the difference!
```

**Investigation Tasks:**
1. Can you see your application when you run `kubectl get pods` without specifying the namespace?
2. Try accessing the service from another namespace - what happens?
3. What commands would you use to work exclusively within your namespace?

## Part 4: Real-World Application

### Scenario: Multi-Environment Setup

**Your Task:** A company needs separate environments for development, staging, and production of their e-commerce platform.

**Design Challenge:**
1. What naming convention would you use for the namespaces?
2. What labels and annotations would help with organization?
3. How would you document the purpose and ownership of each namespace?

**Implementation Exercise:**

Create a script that sets up all three environments:

```bash
#!/bin/bash
# setup-environments.sh

environments=("dev" "staging" "prod")
project="ecommerce"

for env in "${environments[@]}"; do
  kubectl create namespace "${project}-${env}" --dry-run=client -o yaml > "${project}-${env}-namespace.yaml"
  # Add your labels and annotations
  # Apply the namespace
done
```

**Reflection Questions:**
1. How does this approach solve the "apartment building" problems we discussed?
2. What new challenges might this create?
3. How would you explain the value of namespaces to a teammate who's new to Kubernetes?

## Part 5: Common Pitfalls and Solutions

### Discovery Exercise: Troubleshooting Namespace Issues

**Scenario:** A new developer joins your team and reports these problems:

1. "I can't see any of the applications that should be running"
2. "My kubectl commands seem to work, but nothing appears"
3. "I created a service, but other apps can't connect to it"

**Problem-Solving Questions:**
1. What questions would you ask to diagnose each issue?
2. What kubectl commands would help you investigate?
3. How would you prevent these problems in the future?

### Best Practices Checklist

Based on your experience in this unit, evaluate these practices:

- [ ] Always specify namespaces explicitly in YAML files
- [ ] Use descriptive names that indicate purpose and environment
- [ ] Include comprehensive labels for filtering and selection
- [ ] Document namespace ownership and purpose in annotations
- [ ] Set up your kubectl context to avoid default namespace confusion

**Personal Reflection:**
Which of these practices would have prevented issues you've encountered?

## Unit Assessment

### Knowledge Check
1. **Explain in your own words:** What problem do namespaces solve in Kubernetes?
2. **Apply your understanding:** Design a namespace structure for a company with 3 teams working on 5 different applications across dev/staging/prod environments.
3. **Troubleshoot:** A developer says "kubectl get pods shows nothing, but I know there are pods running." What are the likely causes and solutions?

### Hands-On Verification

Complete this practical assessment:

1. Create a namespace called `assessment-namespace`
2. Deploy any simple application to it
3. Demonstrate that the application is isolated from the default namespace
4. Show how to work exclusively within your namespace
5. Clean up all resources when finished

### Preparation for Unit 2

**Preview Questions to Consider:**
1. How would you organize multiple applications within a single namespace?
2. What metadata strategies might help with resource management?
3. How could you automate namespace creation for consistency?

**Coming Next:** In Unit 2, we'll dive deeper into namespace operations, including advanced labeling strategies, metadata management, and automated namespace lifecycle management.

## Additional Resources

### Commands Quick Reference
```bash
# Namespace basics
kubectl get namespaces
kubectl describe namespace <name>
kubectl create namespace <name>
kubectl delete namespace <name>

# Working with namespaces
kubectl get pods -n <namespace>
kubectl config set-context --current --namespace=<namespace>
kubectl config view --minify --output 'jsonpath={.contexts[0].context.namespace}'

# Resource scope investigation
kubectl api-resources --namespaced=true
kubectl api-resources --namespaced=false
```

### Further Exploration
1. Read the official Kubernetes documentation on namespaces
2. Explore how different tools (Helm, Kustomize) handle namespaces
3. Research namespace naming conventions used by major cloud providers
