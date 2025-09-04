# Unit 2: Namespace Operations

## Learning Objectives
By the end of this unit, you will:
- Master declarative and imperative namespace creation methods
- Design effective metadata strategies using labels and annotations
- Implement naming conventions for scalable resource organization
- Automate namespace lifecycle management
- Handle namespace deletion and cleanup safely

## Pre-Unit Reflection
Based on your Unit 1 experience:
1. What challenges did you encounter when managing your first namespace?
2. How might inconsistent naming affect a team of 10 developers?
3. What information would you want to capture about each namespace for future maintenance?

## Part 1: Advanced Namespace Creation Strategies

### Discovery Exercise: Method Comparison

You learned basic creation in Unit 1. Now let's explore when different approaches are most effective.

**Investigation Challenge:**
Try creating the same namespace using three different methods and observe the results:

```bash
# Method 1: Imperative with kubectl
kubectl create namespace test-imperative

# Method 2: Declarative YAML
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: test-declarative
EOF

# Method 3: Using generators
kubectl create namespace test-generator --dry-run=client -o yaml > test-generator.yaml
kubectl apply -f test-generator.yaml
```

**Analysis Questions:**
1. Which method gives you the most control over metadata?
2. When might you prefer each approach in a production environment?
3. How do the resulting namespaces differ when you inspect them with `kubectl describe`?

### Mini-Project 1: Template-Based Namespace Creation

**Scenario:** Your organization needs a standardized way to create namespaces for new projects.

**Design Challenge:** 
Before implementing, consider:
1. What metadata should be required vs optional?
2. How would you ensure consistency across teams?
3. What validation might prevent common mistakes?

**Implementation:**

```yaml
# namespace-template.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: PROJECT-ENVIRONMENT  # Template placeholders
  labels:
    project: "PROJECT"
    environment: "ENVIRONMENT" 
    team: "TEAM"
    cost-center: "COST-CENTER"
    managed-by: "platform-team"
  annotations:
    description: "DESCRIPTION"
    created-date: "CREATED-DATE"
    owner: "OWNER-EMAIL"
    lifecycle-policy: "LIFECYCLE-POLICY"
    backup-required: "BACKUP-REQUIRED"
```

**Automation Script Challenge:**
Create a script that uses this template. What parameters should be required vs have defaults?

```bash
#!/bin/bash
# create-namespace.sh - Your implementation here

# Usage: ./create-namespace.sh --project bookstore --env dev --team backend
# Should validate inputs and substitute template values
```

**Reflection Questions:**
1. How does this template approach solve problems you identified in your analysis?
2. What additional validation would make this more robust?

## Part 2: Metadata Mastery

### Discovery Exercise: Labels vs Annotations Deep Dive

**Investigation Task:**
Create two identical namespaces but with different metadata approaches:

```yaml
# Approach A: Label-heavy
apiVersion: v1
kind: Namespace
metadata:
  name: metadata-test-a
  labels:
    project: ecommerce
    environment: development
    team: frontend
    version: v1.2.0
    compliance-required: "true"
    backup-schedule: daily
    monitoring-level: standard
```

```yaml
# Approach B: Annotation-heavy
apiVersion: v1
kind: Namespace
metadata:
  name: metadata-test-b
  labels:
    project: ecommerce
    environment: development
    team: frontend
  annotations:
    version: "v1.2.0"
    compliance-required: "true"
    backup-schedule: "daily"
    monitoring-level: "standard"
    description: "Frontend development environment"
    contact: "frontend-team@company.com"
    created-by: "platform-automation"
    last-updated: "2024-01-15"
```

**Experimentation:**
Now try these commands on both namespaces:
```bash
kubectl get namespaces --selector="team=frontend"
kubectl get namespaces --selector="compliance-required=true"
kubectl get namespaces -o jsonpath='{range .items[*]}{.metadata.name}: {.metadata.annotations.description}{"\n"}{end}'
```

**Analysis Questions:**
1. Which selector queries worked? Why?
2. When would you choose labels over annotations for each piece of metadata?
3. How might this decision impact automation tools that consume this data?

### Mini-Project 2: Metadata Strategy Design

**Real-World Scenario:** 
You're designing metadata standards for a company with:
- 5 teams (frontend, backend, data, ml, devops)
- 4 environments (dev, test, staging, prod)
- 3 compliance levels (none, standard, high)
- Multiple cost centers and projects

**Design Challenge:**
1. Create a metadata schema that supports:
   - Easy filtering and selection
   - Cost tracking and reporting
   - Compliance monitoring
   - Contact information for issues
   - Lifecycle management automation

2. Implement your schema for these scenarios:
   - A production ML model serving namespace
   - A development frontend testing namespace
   - A high-compliance financial data processing namespace

**Validation Exercise:**
Write kubectl commands that would:
- Find all high-compliance namespaces
- List all production namespaces for cost center "engineering"
- Show contact information for all ML team namespaces

## Part 3: Resource Organization Patterns

### Discovery Exercise: Organization Anti-Patterns

**Investigation Challenge:**
Examine these organization approaches and identify problems:

```bash
# Scenario A: Everything in project namespaces
kubectl create namespace project-alpha
kubectl create namespace project-beta
# All environments for each project mixed together

# Scenario B: Everything in environment namespaces  
kubectl create namespace development
kubectl create namespace production
# All projects for each environment mixed together

# Scenario C: Very specific namespaces
kubectl create namespace frontend-dev-feature-123
kubectl create namespace backend-prod-hotfix-456
# Highly specific, many namespaces
```

**Analysis Questions:**
1. What operational challenges would each scenario create?
2. How would debugging be affected in each approach?
3. Which scenario would be most difficult to secure properly?

### Mini-Project 3: Naming Convention Design

**Challenge:** Design a naming convention that balances clarity with manageability.

**Requirements Analysis:**
Before implementing, consider:
1. What information is essential in the namespace name itself?
2. How will this scale to 100+ namespaces?
3. What kubernetes naming constraints must you respect?

**Implementation Exercise:**
```bash
# Test your naming convention with these scenarios:
# 1. BookStore app, frontend component, development environment
# 2. Analytics platform, data processing, production environment  
# 3. Internal tools, monitoring dashboard, staging environment

# Your naming convention: _______________

# Create examples:
kubectl create namespace [your-name-for-scenario-1] --dry-run=client -o yaml
```

**Validation Questions:**
1. Can someone understand the purpose from the name alone?
2. How would you sort these namespaces in a list?
3. What regex pattern would match all development namespaces?

## Part 4: Lifecycle Management

### Discovery Exercise: Namespace States and Transitions

**Investigation Task:**
Observe namespace behavior during creation, use, and deletion:

```bash
# Create a namespace and watch its status
kubectl create namespace lifecycle-test
kubectl get namespace lifecycle-test -o yaml | grep -A5 -B5 status

# Add some resources
kubectl create deployment test-app --image=nginx --namespace=lifecycle-test
kubectl create service clusterip test-svc --tcp=80:80 --namespace=lifecycle-test

# Initiate deletion and observe
kubectl delete namespace lifecycle-test &
# In another terminal, quickly run:
kubectl get namespace lifecycle-test -o yaml | grep -A10 status
kubectl get all -n lifecycle-test
```

**Analysis Questions:**
1. What phases did you observe during the namespace lifecycle?
2. Why doesn't the namespace delete immediately?
3. What could cause a namespace to get stuck in "Terminating" status?

### Mini-Project 4: Safe Namespace Cleanup

**Scenario:** You need to clean up development namespaces older than 30 days, but some may contain important data.

**Safety-First Challenge:**
Design a cleanup process that:
1. Identifies candidates for cleanup
2. Provides safety checks and confirmations
3. Handles stuck namespaces gracefully
4. Logs all actions for audit purposes

**Implementation:**
```bash
#!/bin/bash
# safe-cleanup.sh

# Step 1: Identify cleanup candidates
# Your approach here - how will you determine age?

# Step 2: Safety checks
# What should you verify before deletion?

# Step 3: Graceful cleanup
# How will you handle finalizers and stuck resources?
```

**Testing Your Solution:**
Create test scenarios:
1. A namespace with just deployments (should clean easily)
2. A namespace with persistent volumes (needs careful handling)
3. A namespace with custom finalizers (might get stuck)

**Reflection Questions:**
1. What additional safety measures would you want in production?
2. How would you handle namespaces that refuse to delete?

## Part 5: Real-World Application

### Comprehensive Scenario: Platform Team Automation

**Your Role:** You're building namespace automation for a platform team supporting 20+ development teams.

**Requirements:**
- Consistent namespace creation across teams
- Automatic labeling for cost tracking
- Integration with monitoring systems
- Cleanup of unused development environments
- Compliance tagging for audit requirements

**Architecture Challenge:**
Design a system that addresses these questions:
1. How will teams request new namespaces?
2. What approval process (if any) should exist?
3. How will you prevent naming conflicts?
4. What defaults should be applied automatically?

**Implementation Phase:**
Build components for:

1. **Request Validation:**
```yaml
# namespace-request.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: namespace-request
data:
  project: "my-app"
  environment: "development"
  team: "backend"
  # Additional required fields...
```

2. **Automated Processing:**
```bash
# process-namespace-request.sh
# Your automation logic
```

3. **Compliance Integration:**
```yaml
# compliance-labels.yaml
# Required labels for different compliance levels
```

**Testing Strategy:**
How will you test this automation? Consider:
- Valid requests
- Invalid inputs
- Conflict scenarios  
- Cleanup processes

## Part 6: Advanced Operations

### Discovery Exercise: Batch Operations

**Challenge:** You need to apply changes to multiple namespaces efficiently.

**Scenarios to Solve:**
1. Add a new label to all development namespaces
2. Update annotations on all namespaces owned by a specific team
3. Apply a ConfigMap to namespaces matching certain criteria

**Investigation:**
```bash
# Try different approaches:

# Approach 1: Loop through namespaces
for ns in $(kubectl get namespaces -l environment=dev -o name); do
  # Your operation here
done

# Approach 2: Use kubectl patch
kubectl patch namespace -l environment=dev -p '{"metadata":{"labels":{"batch-updated":"true"}}}'

# Approach 3: Generate and apply YAML
kubectl get namespaces -l environment=dev -o yaml > dev-namespaces.yaml
# Edit and reapply
```

**Analysis Questions:**
1. Which approach is most reliable for large numbers of namespaces?
2. How would you handle failures in batch operations?
3. What rollback strategy would you implement?

## Unit Assessment

### Practical Skills Verification

**Assessment Challenge:** 
Create a complete namespace management system that demonstrates your mastery:

1. **Design Phase:**
   - Define a metadata schema for a multi-team environment
   - Create naming conventions that scale
   - Plan lifecycle management procedures

2. **Implementation Phase:**
   - Build template-based creation tools
   - Implement batch operation scripts  
   - Create cleanup and validation processes

3. **Testing Phase:**
   - Demonstrate creation, update, and deletion
   - Show filtering and selection capabilities
   - Prove safety mechanisms work

### Knowledge Integration

**Scenario-Based Questions:**
1. A namespace is stuck in "Terminating" status. Walk through your diagnostic and resolution process.
2. Design metadata strategy for compliance tracking across 100+ namespaces.
3. Create an automation system that scales from 5 to 500 namespaces.

### Preparation for Unit 3

**Preview Considerations:**
1. How will resources within namespaces find and communicate with each other?
2. What patterns help organize multiple applications within a single namespace?
3. How do naming conventions extend beyond namespaces to the resources within them?

**Coming Next:** In Unit 3, we'll explore resource organization within namespaces, cross-namespace communication patterns, and advanced resource discovery techniques.

## Quick Reference

### Essential Commands
```bash
# Creation methods
kubectl create namespace <name>
kubectl apply -f namespace.yaml
kubectl create namespace <name> --dry-run=client -o yaml

# Metadata operations  
kubectl label namespace <name> key=value
kubectl annotate namespace <name> key=value
kubectl patch namespace <name> -p '{"metadata":{"labels":{"key":"value"}}}'

# Batch operations
kubectl get namespaces -l key=value
kubectl patch namespace -l key=value -p '{"metadata":{"labels":{"new-key":"value"}}}'

# Lifecycle management
kubectl delete namespace <name>
kubectl get namespace <name> -o yaml | grep finalizers
```

### Troubleshooting Patterns
- Stuck namespace: Check finalizers and dependent resources
- Metadata conflicts: Use `kubectl patch` vs direct YAML edits
- Batch failures: Implement proper error handling and rollback
- Naming conflicts: Validate against existing namespaces before creation
