# Unit 3: Persistent Storage Deep Dive - Mastering Data Persistence

## Learning Objectives
By the end of this unit, you will:
- Master volume claim templates and their lifecycle
- Configure different storage classes for various performance needs
- Understand storage persistence guarantees and limitations
- Design storage strategies for different application types
- Troubleshoot common storage-related issues in StatefulSets

## Pre-Unit Reflection: Your Storage Journey

Before we dive deep, let's establish where you're starting from:

**Think About Your Experience:**
1. In Unit 2, what did you observe about how persistent volumes behaved when pods were deleted?
2. What questions arose when you saw PVCs persist even after scaling down StatefulSets?
3. Have you encountered any storage challenges in your Kubernetes work or experiments?

**Current Understanding Check:**
- What do you think happens to data when a StatefulSet pod moves to a different node?
- If you have a database that needs fast storage, how might you configure that in Kubernetes?
- What concerns would you have about storage in a production database deployment?

Take a moment to reflect on these questions—they'll guide our exploration.

## Discovery Lab: Storage Behavior Exploration

Let's start by exploring storage behavior through experimentation rather than theory.

### Experiment 1: Understanding PVC Lifecycle

```bash
# Create a simple StatefulSet to observe storage behavior
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: storage-test
spec:
  clusterIP: None
  selector:
    app: storage-test
  ports:
  - port: 80
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: storage-test
spec:
  serviceName: storage-test
  replicas: 2
  selector:
    matchLabels:
      app: storage-test
  template:
    metadata:
      labels:
        app: storage-test
    spec:
      containers:
      - name: app
        image: busybox:1.35
        command: ["sleep", "3600"]
        volumeMounts:
        - name: data
          mountPath: /data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 1Gi
EOF

# Wait for pods to be ready
kubectl wait --for=condition=Ready pod -l app=storage-test --timeout=120s
```

**Guided Exploration Questions:**
- How many PVCs were created? What are their names?
- Can you predict the naming pattern for additional replicas?

Now let's test persistence:

```bash
# Create some data in each pod
kubectl exec storage-test-0 -- sh -c "echo 'Data from pod-0 at \$(date)' > /data/test.txt"
kubectl exec storage-test-1 -- sh -c "echo 'Data from pod-1 at \$(date)' > /data/test.txt"

# Verify the data
kubectl exec storage-test-0 -- cat /data/test.txt
kubectl exec storage-test-1 -- cat /data/test.txt

# Now delete the pods and observe
kubectl delete pod storage-test-0 storage-test-1
kubectl get pods -l app=storage-test -w
```

**Critical Thinking Moment:**
Wait for the pods to be recreated, then check your data:

```bash
kubectl exec storage-test-0 -- cat /data/test.txt
kubectl exec storage-test-1 -- cat /data/test.txt
```

- Did your data survive the pod deletion?
- What does this tell you about the relationship between pods and their storage?
- How is this different from what happens with regular pod volumes?

### Experiment 2: Scale Down and Data Persistence

```bash
# Scale down to 1 replica
kubectl scale statefulset storage-test --replicas=1

# Check what happened to pods and PVCs
kubectl get pods -l app=storage-test
kubectl get pvc -l app=storage-test

# Important question: What happened to the PVC for storage-test-1?
kubectl describe pvc data-storage-test-1
```

**Analysis Questions:**
- Why do you think the PVC for storage-test-1 still exists?
- What are the implications of this behavior for data safety?
- When might you want to manually delete these PVCs?

### Experiment 3: Scale Back Up - Data Recovery

```bash
# Scale back up to 2 replicas
kubectl scale statefulset storage-test --replicas=2

# Wait for the new pod
kubectl wait --for=condition=Ready pod storage-test-1 --timeout=120s

# Check if the data from earlier is still there
kubectl exec storage-test-1 -- cat /data/test.txt
```

**Discovery Moment:**
- Did storage-test-1 reconnect to its original data?
- What does this tell you about StatefulSet storage guarantees?
- How might this behavior be useful for database applications?

## Understanding Volume Claim Templates

Based on your experiments, let's dive deeper into how volume claim templates work.

### Anatomy of a Volume Claim Template

```yaml
volumeClaimTemplates:
- metadata:
    name: data                    # Template name - becomes part of PVC name
    labels:                       # Labels applied to all created PVCs
      app: my-app
      tier: storage
  spec:
    accessModes: ["ReadWriteOnce"]  # How the volume can be mounted
    resources:
      requests:
        storage: 10Gi             # Amount of storage requested
    storageClassName: ssd         # Type of storage to provision
```

**Guided Analysis Questions:**
- If your StatefulSet is named `mysql` and has 3 replicas, what will the PVC names be?
- Why might you want to add labels to your volume claim templates?
- What happens if you change the storage request after PVCs are created?

### Access Modes Deep Dive

Let's understand the different access modes through practical scenarios:

```bash
# Check what access modes are available in your cluster
kubectl get storageclass

# Look at the access modes supported by each storage class
kubectl describe storageclass
```

**Real-World Scenario Analysis:**
Consider these applications and determine appropriate access modes:

1. **Database Server**: Needs exclusive read/write access to prevent corruption
2. **Shared File System**: Multiple pods need to read/write shared files  
3. **Log Aggregation**: Multiple pods write logs, one pod reads all logs

**Which access mode would you choose for each?**
- `ReadWriteOnce` (RWO): Volume can be mounted read-write by a single node
- `ReadOnlyMany` (ROX): Volume can be mounted read-only by many nodes
- `ReadWriteMany` (RWX): Volume can be mounted read-write by many nodes

## Storage Classes: Choosing the Right Storage Type

Different applications have different storage performance and reliability requirements. Let's explore how to match storage types to application needs.

### Hands-On: Creating Custom Storage Classes

```bash
# First, see what storage classes are available in your cluster
kubectl get storageclass -o wide

# Create different storage classes for different use cases
cat << EOF | kubectl apply -f -
# Fast SSD storage for databases
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: kubernetes.io/no-provisioner  # Use your cluster's provisioner
parameters:
  type: ssd
  replication-type: synchronous
  iops: "3000"
reclaimPolicy: Retain  # Keep data even after PVC deletion
allowVolumeExpansion: true
---
# Standard storage for general applications  
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard-hdd
provisioner: kubernetes.io/no-provisioner
parameters:
  type: hdd
  replication-type: asynchronous
reclaimPolicy: Delete  # Clean up automatically
allowVolumeExpansion: true
---
# Backup storage for long-term retention
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: backup-storage
provisioner: kubernetes.io/no-provisioner
parameters:
  type: cold-storage
  replication-type: geo-distributed
reclaimPolicy: Retain
allowVolumeExpansion: false
EOF
```

**Design Thinking Exercise:**
For each storage class above:
- What type of applications would benefit from it?
- Why might you choose `Retain` vs `Delete` for the reclaim policy?
- When would `allowVolumeExpansion` be important?

### Practical Application: Database Storage Strategy

Let's design a comprehensive storage strategy for different database scenarios:

```bash
# Scenario 1: High-Performance OLTP Database
cat << EOF > database-storage-strategy.yaml
# Primary database StatefulSet with optimized storage
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql-primary
spec:
  serviceName: mysql-primary
  replicas: 1
  selector:
    matchLabels:
      app: mysql-primary
  template:
    metadata:
      labels:
        app: mysql-primary
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: "secure-password"
        volumeMounts:
        - name: mysql-data
          mountPath: /var/lib/mysql
        - name: mysql-logs
          mountPath: /var/log/mysql
  volumeClaimTemplates:
  - metadata:
      name: mysql-data
      labels:
        storage-type: primary-data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: fast-ssd      # Fast storage for data
      resources:
        requests:
          storage: 100Gi
  - metadata:
      name: mysql-logs
      labels:
        storage-type: logs
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: standard-hdd   # Standard storage for logs
      resources:
        requests:
          storage: 20Gi
EOF
```

**Strategic Questions:**
- Why use different storage classes for data vs logs?
- What are the trade-offs between cost and performance here?
- How might this configuration change for a read replica vs primary database?

## Advanced Storage Patterns

Now that you understand the fundamentals, let's explore advanced patterns used in production environments.

### Pattern 1: Multi-Tier Storage Strategy

```bash
# Clean up previous experiment first
kubectl delete statefulset storage-test
kubectl delete service storage-test

# Create a StatefulSet that demonstrates multi-tier storage
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: multi-tier-app
spec:
  clusterIP: None
  selector:
    app: multi-tier-app
  ports:
  - port: 8080
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: multi-tier-app
spec:
  serviceName: multi-tier-app
  replicas: 3
  selector:
    matchLabels:
      app: multi-tier-app
  template:
    metadata:
      labels:
        app: multi-tier-app
    spec:
      containers:
      - name: app
        image: busybox:1.35
        command: ["sleep", "3600"]
        volumeMounts:
        - name: hot-data      # Frequently accessed data
          mountPath: /hot-data
        - name: warm-data     # Occasionally accessed data  
          mountPath: /warm-data
        - name: cold-data     # Backup/archive data
          mountPath: /cold-data
  volumeClaimTemplates:
  # Hot data: Fast, expensive storage
  - metadata:
      name: hot-data
      labels:
        tier: hot
        performance: high
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: fast-ssd
      resources:
        requests:
          storage: 10Gi
  # Warm data: Balanced storage
  - metadata:
      name: warm-data
      labels:
        tier: warm
        performance: medium
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: standard-hdd
      resources:
        requests:
          storage: 50Gi
  # Cold data: Cheap, slower storage
  - metadata:
      name: cold-data
      labels:
        tier: cold
        performance: low
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: backup-storage
      resources:
        requests:
          storage: 200Gi
EOF
```

**Architecture Analysis:**
- How might an application use this three-tier storage approach?
- What types of data would you put in each tier?
- How does this strategy balance cost and performance?

### Pattern 2: Storage with Backup Strategy

Let's implement a pattern that includes automated backup considerations:

```bash
# Test the multi-tier setup
kubectl wait --for=condition=Ready pod -l app=multi-tier-app --timeout=120s

# Simulate different types of data
kubectl exec multi-tier-app-0 -- sh -c "echo 'Active user sessions' > /hot-data/sessions.json"
kubectl exec multi-tier-app-0 -- sh -c "echo 'Historical analytics' > /warm-data/analytics.db"  
kubectl exec multi-tier-app-0 -- sh -c "echo 'Archived logs from 2020' > /cold-data/archive.log"

# Check the storage allocation
kubectl get pvc -l app=multi-tier-app
kubectl describe pvc -l tier=hot
```

**Design Challenge:**
Based on what you see, design a backup strategy:
- Which storage tier would you backup most frequently?
- How might backup frequency differ between tiers?
- What tools or processes would you use for each tier?

## Troubleshooting Storage Issues

Let's explore common storage problems and how to diagnose them.

### Lab: Simulating and Solving Storage Problems

```bash
# Problem 1: PVC Stuck in Pending
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: problematic-pvc
spec:
  accessModes: ["ReadWriteOnce"]
  storageClassName: non-existent-class  # This will cause problems
  resources:
    requests:
      storage: 5Gi
EOF

# Observe the problem
kubectl get pvc problematic-pvc
kubectl describe pvc problematic-pvc
```

**Diagnostic Questions:**
- What status is the PVC in?
- What information in the `describe` output helps you understand the problem?
- How would you fix this issue?

```bash
# Problem 2: Pod Can't Mount Volume
kubectl run test-pod --image=busybox:1.35 --restart=Never -- sleep 3600
kubectl patch pod test-pod -p '{"spec":{"volumes":[{"name":"test-vol","persistentVolumeClaim":{"claimName":"problematic-pvc"}}],"containers":[{"name":"test-pod","volumeMounts":[{"name":"test-vol","mountPath":"/data"}]}]}}'

kubectl get pod test-pod
kubectl describe pod test-pod
```

**Troubleshooting Practice:**
- What prevents the pod from starting?
- What's the relationship between the PVC problem and the pod problem?
- What's your step-by-step approach to fixing this?

### Storage Troubleshooting Checklist

Based on your experiments, let's build a systematic troubleshooting approach:

**When a StatefulSet pod won't start:**

1. **Check PVC Status**
   ```bash
   kubectl get pvc -l app=your-app
   kubectl describe pvc problematic-pvc-name
   ```

2. **Check Storage Class**
   ```bash
   kubectl get storageclass
   kubectl describe storageclass your-storage-class
   ```

3. **Check Node Resources**
   ```bash
   kubectl describe node
   # Look for storage pressure or resource constraints
   ```

4. **Check Events**
   ```bash
   kubectl get events --sort-by=.metadata.creationTimestamp
   # Look for volume binding failures
   ```

**Practice Exercise:**
Create a problematic StatefulSet configuration and work through the troubleshooting checklist. What issues can you create and solve?

## Real-World Storage Design Workshop

Let's apply everything you've learned to design storage solutions for realistic scenarios.

### Scenario 1: E-commerce Platform Storage Design

**Requirements:**
- MySQL database (1 primary, 2 replicas)
- Redis cache cluster (3 nodes)
- Elasticsearch for search (3 nodes)
- File uploads storage (shared across web servers)

**Your Design Challenge:**
```bash
# Create storage classes and StatefulSet configurations for each component
# Consider: Performance needs, data persistence requirements, backup strategies

cat << EOF > ecommerce-storage-design.yaml
# Your storage design goes here
# Think about:
# - Which components need StatefulSets vs Deployments
# - Appropriate storage classes for each use case
# - Volume sizes based on expected data growth
# - Access modes for different sharing requirements
EOF
```

**Guided Design Questions:**
- Which storage class would you use for each component and why?
- How would backup and disaster recovery differ for each service?
- What happens if you need to migrate data between clusters?

### Scenario 2: Analytics Platform Storage Design

**Requirements:**
- Time-series database (InfluxDB cluster)
- Data processing pipeline (temporary storage needs)
- Long-term data archive (cold storage)
- Real-time dashboard cache

**Design Considerations:**
- Time-series data grows predictably but continuously
- Processing pipelines need fast temporary storage
- Archives need cost-effective, reliable storage
- Caches can be rebuilt but benefit from persistence

**Your Challenge:**
Design a comprehensive storage strategy that balances performance, cost, and reliability.

## Unit Challenge: Complete Storage Solution

Design and implement a complete storage solution for a monitoring stack:

**Components:**
1. **Prometheus** (time-series metrics storage)
2. **Grafana** (dashboard configurations and user data)  
3. **Alertmanager** (alert state and configuration)

**Requirements:**
- Prometheus needs fast storage for recent data, slower storage for historical data
- Grafana needs persistent storage for dashboards and user settings
- Alertmanager needs reliable storage for alert state
- All components should survive pod restarts and node failures
- Storage should be appropriately sized for a medium-scale environment

**Starter Template:**
```bash
cat << EOF > monitoring-storage-solution.yaml
# Design a complete storage solution for monitoring stack
# Include:
# 1. Appropriate storage classes
# 2. StatefulSet configurations with proper volume claim templates
# 3. Headless services
# 4. Consider backup and recovery strategies

# Your solution here...
EOF
```

**Validation Criteria:**
1. Deploy your solution and verify all pods start successfully
2. Create some test data in each component
3. Delete pods and verify data persistence
4. Scale components up/down and observe storage behavior
5. Document your design decisions and trade-offs

## Self-Assessment and Knowledge Consolidation

### Practical Skills Check

Test your understanding with these hands-on challenges:

```bash
# Challenge 1: Storage Class Detective Work
kubectl get storageclass -o yaml
# Analyze each storage class and determine:
# - What type of storage it provides
# - What applications would benefit from it
# - What the reclaim policy means for data safety

# Challenge 2: PVC Lifecycle Management
kubectl get pvc --all-namespaces
# For each PVC, determine:
# - Which pod(s) are using it
# - What happens if you delete the pod vs the PVC
# - How to safely clean up unused PVCs

# Challenge 3: Storage Troubleshooting
# Create a broken StatefulSet with storage issues
# Practice diagnosing and fixing the problems
```

### Conceptual Understanding Questions

1. **Storage Design:**
   - When would you use multiple volume claim templates in a single StatefulSet?
   - How do you decide between ReadWriteOnce vs ReadWriteMany?
   - What factors influence your choice of storage class?

2. **Operational Considerations:**
   - What's the difference between deleting a pod vs deleting a PVC?
   - How do you safely migrate data between storage classes?
   - What backup strategies work best for different types of stateful applications?

3. **Real-World Scenarios:**
   - How would you design storage for a database that needs both fast transaction logs and bulk data storage?
   - What storage considerations are important for multi-region deployments?
   - How do you handle storage when scaling StatefulSets across multiple availability zones?

### Advanced Topics for Further Exploration

**Volume Snapshots and Cloning:**
```bash
# Research these concepts for your specific cloud provider
kubectl get volumeSnapshot
kubectl get volumeSnapshotClass
# How might snapshots integrate with your backup strategies?
```

**Storage Monitoring and Alerting:**
```bash
# Consider what storage metrics you should monitor
kubectl top pods --containers
# What alerts would you set up for storage-related issues?
```

## Cleanup and Preparation for Unit 4

```bash
# Clean up all resources created in this unit
kubectl delete statefulset multi-tier-app --ignore-not-found=true
kubectl delete service multi-tier-app --ignore-not-found=true
kubectl delete pvc problematic-pvc --ignore-not-found=true
kubectl delete pod test-pod --ignore-not-found=true

# Note: Some PVCs may remain - review and delete as needed
kubectl get pvc
# Manually delete any PVCs you want to clean up

# Clean up custom storage classes if created
kubectl delete storageclass fast-ssd standard-hdd backup-storage --ignore-not-found=true
```

## Unit Summary

### Key Concepts Mastered:
- **Volume Claim Templates**: How StatefulSets automatically create and manage persistent storage
- **Storage Classes**: Matching storage types to application performance and reliability needs
- **Access Modes**: Understanding when to use ReadWriteOnce, ReadOnlyMany, and ReadWriteMany
- **Storage Lifecycle**: How PVCs persist independently of pods and StatefulSets
- **Multi-Tier Storage**: Designing cost-effective storage strategies for different data types

### Skills Developed:
- Configuring persistent storage for stateful applications
- Designing storage classes for different performance requirements
- Troubleshooting common storage-related issues
- Creating comprehensive storage strategies for complex applications
- Understanding the relationship between storage and application architecture

### Production-Ready Patterns:
- Multi-tier storage strategies (hot/warm/cold data)
- Storage class design for different workload types
- Backup and disaster recovery considerations
- Storage monitoring and alerting strategies
- Cost optimization through appropriate storage selection

### Looking Ahead to Unit 4:
In Unit 4, we'll explore the networking side of StatefulSets in depth. You'll learn how headless services provide stable network identity, how StatefulSet DNS works, and advanced networking patterns for clustered applications. We'll also cover service discovery and inter-pod communication patterns essential for distributed systems.

**Preparation Questions for Unit 4:**
- How do you think pods in a database cluster find and communicate with each other?
- What networking challenges exist when pods can be rescheduled to different nodes?
- How might load balancing work differently for stateful vs stateless applications?

**Key Takeaways for Your Kubernetes Journey:**
Storage is often the most critical aspect of stateful applications. The patterns and troubleshooting skills you've developed in this unit will serve as the foundation for deploying production-ready databases, distributed systems, and other persistent workloads. Remember that storage decisions made early in a project can be difficult to change later, so invest time in thoughtful design upfront.