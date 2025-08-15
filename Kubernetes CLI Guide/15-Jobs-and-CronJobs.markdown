# 15. Jobs and CronJobs - Complete Guide to Batch Processing in Kubernetes

## Understanding the Difference: Continuous vs. Finite Tasks

Before diving into the technical details, let's establish a fundamental concept that will guide everything we do with Jobs and CronJobs. In the world of applications, there are two completely different types of workloads, and understanding this distinction is crucial for choosing the right Kubernetes resource.

**Continuous workloads** are like a restaurant that stays open all day. A web server, database, or API service needs to run constantly, handling requests as they come in. If the process stops or crashes, Kubernetes should immediately restart it because customers are waiting. This is what Deployments, StatefulSets, and DaemonSets are designed for.

**Finite workloads** are like a construction project that has a clear beginning and end. You might need to process a batch of files, generate a report, backup a database, or perform maintenance tasks. These jobs should run to completion and then stop. If you tried to use a Deployment for this, Kubernetes would keep restarting your completed task forever, wasting resources and potentially causing problems.

Jobs and CronJobs are Kubernetes resources specifically designed for finite workloads. Jobs handle one-time tasks that need to run to completion, while CronJobs schedule recurring finite tasks using familiar cron syntax. Think of Jobs as hiring a contractor for a specific project, and CronJobs as scheduling regular maintenance visits.

## 15.1 Creating and Understanding Jobs

Jobs are perfect for tasks that need to complete successfully exactly once or a specific number of times. Let's explore how to create them and understand the options that control their behavior.

### Basic Job Creation - The Foundation

```bash
# Create a simple Job imperatively - runs a task to completion
kubectl create job pi-calc --image=perl:5.34 -- perl -Mbignum=bpi -wle 'print bpi(2000)'
# This creates a Job that calculates pi to 2000 digits and then terminates
# The key difference from a Deployment: once this calculation finishes, the pod should stop and stay stopped

# Check if the job completed successfully
kubectl get jobs
# You'll see a COMPLETIONS column showing something like "1/1" when successful

# View the actual calculation result
kubectl logs job/pi-calc
# This shows you the 2000 digits of pi that were calculated
```

When you create this Job, Kubernetes creates a pod to run the calculation. Once the perl command finishes successfully (exit code 0), the pod moves to a "Completed" state and stays there. Kubernetes doesn't restart it because the job is done. This is fundamentally different from how Deployments work.

### Parallel Processing - Scaling Your Batch Work

Sometimes you need to process large amounts of data or perform computationally intensive tasks that can benefit from parallel execution. Jobs support this through parallelism and completions settings.

```bash
# Create a parallel Job - runs multiple pods simultaneously
kubectl create job parallel-job --image=busybox -- sh -c 'echo Processing on $HOSTNAME at $(date); sleep $((RANDOM % 20 + 10))'

# To add parallelism, we need to edit the job or use a YAML definition
# Let's demonstrate with kubectl patch after creation
kubectl patch job parallel-job -p '{"spec":{"parallelism":3,"completions":5}}'
# This means: run up to 3 pods at once until 5 pods have completed successfully
```

The parallelism and completions concept is crucial to understand. Think of it like having a team of workers (parallelism) complete a certain number of tasks (completions). If you set parallelism to 3 and completions to 5, Kubernetes will start 3 workers immediately. As each worker finishes their task, Kubernetes starts a new worker until 5 tasks have been completed successfully.

This pattern is incredibly powerful for batch processing scenarios like image resizing, data analysis, or file processing where you can break the work into independent chunks.

```bash
# Monitor the parallel job in action
kubectl get pods -l job-name=parallel-job -w
# You'll see pods being created, running, completing, and new ones starting
# This gives you a real-time view of how Kubernetes manages the parallel execution
```

## 15.2 Creating and Understanding CronJobs

CronJobs are like having a reliable assistant who performs recurring tasks on a schedule. They create new Jobs at specified times using the familiar cron syntax, making them perfect for maintenance tasks, backups, reports, and cleanup operations.

### Basic CronJob Creation

```bash
# Create a CronJob imperatively - schedules recurring tasks
kubectl create cronjob backup-job --image=busybox --schedule="0 2 * * *" -- sh -c 'echo Backing up at $(date) | tee /tmp/backup-$(date +%Y%m%d).log'
# --schedule="0 2 * * *" means run daily at 2:00 AM
# Each time the schedule triggers, Kubernetes creates a new Job (which creates a new pod)

# Understanding cron syntax is essential:
# minute hour day-of-month month day-of-week
# 0 2 * * * = every day at 2:00 AM
# */15 * * * * = every 15 minutes
# 0 9 * * 1-5 = weekdays at 9:00 AM
# 0 0 1 * * = first day of every month at midnight
```

The beauty of CronJobs is that they handle all the scheduling complexity for you. You don't need to write cron scripts on individual servers or worry about server failures affecting your scheduled tasks. Kubernetes ensures that your CronJobs run according to schedule across your cluster.

### Managing CronJob Behavior

```bash
# List CronJobs - view scheduled tasks and their status
kubectl get cronjobs
kubectl get cj -o wide # 'cj' is shorthand, shows more details including last schedule time
# The output shows you when each CronJob last ran and when it's scheduled to run next

# Trigger a CronJob manually - essential for testing before waiting for the scheduled time
kubectl create job --from=cronjob/backup-job manual-backup-test
# This creates a one-off Job using the same specification as your CronJob
# Perfect for testing your CronJob logic without waiting for the schedule
```

This manual triggering capability is invaluable during development and debugging. You can test your CronJob logic immediately rather than waiting hours or days for the next scheduled execution.

## 15.3 Managing Jobs and CronJobs - Monitoring and Troubleshooting

Understanding how to monitor and troubleshoot Jobs is crucial because batch processing often involves complex operations that can fail in various ways.

### Monitoring Job Execution

```bash
# List Jobs - check status of current and past tasks
kubectl get jobs
kubectl get jobs -o wide
# The COMPLETIONS column shows successful/desired completions (e.g., "3/5" means 3 of 5 required completions finished)
# The DURATION column shows how long the job has been running or took to complete

# Describe Job - your primary debugging tool for failed or stuck jobs
kubectl describe job pi-calc
# This shows you:
# - Events that occurred during job execution
# - Pod creation and completion details
# - Any error conditions or retry attempts
# - The job's current status and conditions
```

The describe command is your best friend when jobs aren't behaving as expected. It shows you the complete story of what Kubernetes tried to do and what went wrong.

### Accessing Job Output and Logs

```bash
# View Job logs - inspect the actual output from your batch process
kubectl logs job/pi-calc
# For jobs with multiple pods, this shows logs from one pod

# If your job creates multiple pods (parallel processing), you might need to check logs from all of them
kubectl get pods -l job-name=pi-calc -o name | xargs -I {} kubectl logs {}
# This gets logs from all pods created by the job
# Essential for parallel jobs where different pods might have different outcomes
```

Understanding how to access logs from batch jobs is critical because unlike web services that you can test interactively, batch jobs often run and complete before you can examine them. The logs contain the actual output and any error messages from your processing.

### Job Lifecycle Management

```bash
# Jobs don't automatically clean themselves up - this is intentional
# Completed jobs remain so you can examine their logs and status
kubectl delete job pi-calc
# This deletes the job and all its associated pods
# The logs disappear too, so make sure you've captured any important output first

# For CronJobs, you can pause and resume scheduled execution
kubectl patch cronjob backup-job -p '{"spec":{"suspend":true}}'
# This prevents new Jobs from being created at scheduled times
# Existing running jobs continue to completion
kubectl patch cronjob backup-job -p '{"spec":{"suspend":false}}' # Resume scheduling

# View CronJob execution history - understand the pattern of past runs
kubectl get jobs -l cronjob-name=backup-job
# Shows all Jobs that were created by this CronJob
# Helps you see success/failure patterns over time
```

The suspend functionality is particularly useful during maintenance windows or when you need to temporarily stop automated processes without deleting the entire CronJob configuration.

## 15.4 Job YAML Deep Dive - Understanding Every Configuration Option

While imperative commands are great for quick tasks, declarative YAML configurations give you complete control over job behavior and ensure reproducibility.

```yaml
# pi-job.yaml - A comprehensive Job configuration
apiVersion: batch/v1
kind: Job
metadata:
  name: pi-calc
  labels:
    app: mathematical-computation
    type: batch-job
spec:
  # Core job behavior settings
  completions: 1        # How many pods must complete successfully
  parallelism: 1        # How many pods can run simultaneously
  backoffLimit: 4       # How many times to retry failed pods before giving up
  activeDeadlineSeconds: 300  # Maximum time job can run (5 minutes)
  
  # The template defines what each pod will do
  template:
    metadata:
      labels:
        app: mathematical-computation
        batch: pi-calculation
    spec:
      containers:
      - name: pi
        image: perl:5.34
        command: ["perl", "-Mbignum=bpi", "-wle", "print bpi(2000)"]
        resources:
          # Resource limits prevent runaway batch jobs from consuming too much
          limits:
            memory: "128Mi"
            cpu: "500m"
          requests:
            memory: "64Mi"
            cpu: "250m"
      restartPolicy: Never # Critical: Jobs must use Never or OnFailure
      # Never: don't restart failed containers, let the Job controller handle retries
      # OnFailure: restart failed containers up to backoffLimit times
```

Each of these settings controls important aspects of how your job behaves. The `completions` and `parallelism` settings work together to define your processing pattern. The `backoffLimit` prevents infinite retry loops when something is fundamentally wrong. The `activeDeadlineSeconds` acts as a safety valve to prevent jobs from running forever.

```bash
# Apply the job configuration
kubectl apply -f pi-job.yaml

# Monitor the job's progress in real-time
kubectl get job pi-calc -w
# Watch the COMPLETIONS column change from "0/1" to "1/1" when successful

# Examine the detailed execution
kubectl describe job pi-calc
# Look for events showing pod creation, execution, and completion
```

Understanding the difference between `Never` and `OnFailure` restart policies is crucial. With `Never`, if a container fails, the pod terminates and the Job controller decides whether to create a new pod based on the `backoffLimit`. With `OnFailure`, Kubernetes restarts the failed container within the same pod. Choose based on whether your application can handle being restarted mid-process.

## 15.5 CronJob YAML Deep Dive - Scheduling and History Management

CronJobs have additional complexity because they create Jobs over time, requiring careful management of scheduling conflicts and resource cleanup.

```yaml
# backup-cronjob.yaml - A production-ready CronJob configuration
apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup-job
  labels:
    purpose: data-backup
    frequency: daily
spec:
  # Scheduling configuration
  schedule: "0 2 * * *"              # Daily at 2:00 AM
  timeZone: "America/New_York"       # Explicit timezone (Kubernetes 1.25+)
  
  # History and cleanup management
  successfulJobsHistoryLimit: 3      # Keep last 3 successful job records
  failedJobsHistoryLimit: 1          # Keep last 1 failed job record
  
  # Concurrency control
  concurrencyPolicy: Forbid          # Don't start new job if previous is still running
  # Other options: Allow (default), Replace (kill old job and start new one)
  
  # Deadline management
  startingDelineSeconds: 300         # If job can't start within 5 minutes, consider it missed
  
  # The job template that gets created each time the schedule triggers
  jobTemplate:
    metadata:
      labels:
        purpose: data-backup
        created-by: cronjob
    spec:
      backoffLimit: 2                # Fewer retries for scheduled jobs
      activeDeradlineSeconds: 1800   # 30 minutes max execution time
      template:
        spec:
          containers:
          - name: backup
            image: busybox:1.35
            command: ["/bin/sh", "-c"]
            args:
            - |
              echo "Starting backup at $(date)"
              # Simulate backup operations
              echo "Backing up database..."
              sleep 10
              echo "Backing up files..."
              sleep 5
              echo "Backup completed successfully at $(date)"
              echo "Backup summary: $(date)" > /backup/backup-$(date +%Y%m%d).log
            volumeMounts:
            - name: backup-storage
              mountPath: /backup
            resources:
              limits:
                memory: "256Mi"
                cpu: "500m"
              requests:
                memory: "128Mi"
                cpu: "250m"
          volumes:
          - name: backup-storage
            persistentVolumeClaim:
              claimName: backup-storage-pvc
          restartPolicy: OnFailure    # For scheduled jobs, OnFailure often makes more sense
```

The `concurrencyPolicy` setting is particularly important for long-running batch jobs. If your backup takes longer than expected and the next scheduled time arrives, do you want to run both backups simultaneously (Allow), skip the new one (Forbid), or kill the old one and start fresh (Replace)? The choice depends on your specific use case.

```bash
# Create the CronJob
kubectl apply -f backup-cronjob.yaml

# Monitor the CronJob status
kubectl get cronjob backup-job -o wide
# Shows last schedule time, next schedule time, and activity status

# Check the Jobs created by this CronJob
kubectl get jobs -l cronjob-name=backup-job
# Each execution creates a new Job with a timestamp suffix
```

## Advanced Example: Parallel Data Processing Pipeline

Let's build a more sophisticated example that demonstrates how Jobs can be used for real-world data processing scenarios.

```yaml
# data-processing-pipeline.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: processing-script
data:
  process.sh: |
    #!/bin/bash
    echo "Worker $HOSTNAME starting data processing at $(date)"
    
    # Simulate downloading data chunk
    CHUNK_ID=$((RANDOM % 1000))
    echo "Processing data chunk $CHUNK_ID"
    
    # Simulate processing time (random between 10-30 seconds)
    PROCESS_TIME=$((RANDOM % 20 + 10))
    echo "Processing will take $PROCESS_TIME seconds"
    
    for i in $(seq 1 $PROCESS_TIME); do
        echo "Processing step $i/$PROCESS_TIME for chunk $CHUNK_ID"
        sleep 1
    done
    
    # Write results
    RESULT_FILE="/shared/results/result-$HOSTNAME-$CHUNK_ID.txt"
    echo "Data chunk $CHUNK_ID processed by $HOSTNAME at $(date)" > $RESULT_FILE
    echo "Processing completed successfully"
---
apiVersion: batch/v1
kind: Job
metadata:
  name: parallel-data-processor
  labels:
    app: data-pipeline
    type: parallel-batch
spec:
  parallelism: 4          # Run 4 workers simultaneously
  completions: 10         # Process 10 data chunks total
  backoffLimit: 3         # Allow some failures
  activeDeadlineSeconds: 600  # Kill job if it takes more than 10 minutes
  template:
    metadata:
      labels:
        app: data-pipeline
        role: worker
    spec:
      containers:
      - name: data-processor
        image: busybox:1.35
        command: ["/bin/sh", "/scripts/process.sh"]
        volumeMounts:
        - name: processing-script
          mountPath: /scripts
        - name: shared-results
          mountPath: /shared/results
        resources:
          limits:
            memory: "256Mi"
            cpu: "500m"
          requests:
            memory: "128Mi"
            cpu: "250m"
      volumes:
      - name: processing-script
        configMap:
          name: processing-script
          defaultMode: 0755
      - name: shared-results
        emptyDir: {}
      restartPolicy: Never
```

This example demonstrates several important concepts. The ConfigMap contains our processing logic, making it easy to update without rebuilding container images. The Job runs 4 workers in parallel to process 10 total chunks of data. As workers complete their tasks, new workers start until all 10 chunks are processed.

```bash
# Deploy the parallel processing job
kubectl apply -f data-processing-pipeline.yaml

# Watch the parallel execution in real-time
kubectl get pods -l job-name=parallel-data-processor -w
# You'll see 4 pods start immediately, then as they complete, new ones start

# Monitor job progress
kubectl get job parallel-data-processor -w
# Watch the COMPLETIONS counter increase: 0/10, 1/10, 2/10, etc.

# Check the processing logs from all workers
kubectl logs -l job-name=parallel-data-processor --prefix=true
# The --prefix=true shows which pod generated each log line
```

## Real-World CronJob Example: Database Maintenance Pipeline

Let's create a comprehensive example that shows how CronJobs can handle regular maintenance tasks with proper error handling and logging.

```yaml
# database-maintenance-cronjob.yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
type: Opaque
stringData:
  username: maintenance_user
  password: secure_password_123
  host: postgres.database.svc.cluster.local
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: maintenance-scripts
data:
  maintenance.sh: |
    #!/bin/bash
    set -e  # Exit on any error
    
    echo "=== Database Maintenance Started at $(date) ==="
    
    # Database connection info from environment
    export PGPASSWORD="$DB_PASSWORD"
    
    # Function to run SQL and log results
    run_sql() {
        local description="$1"
        local sql="$2"
        echo "Running: $description"
        if psql -h "$DB_HOST" -U "$DB_USERNAME" -d postgres -c "$sql"; then
            echo "✓ Success: $description"
        else
            echo "✗ Failed: $description"
            return 1
        fi
    }
    
    # Vacuum old data
    run_sql "Vacuuming old data" "VACUUM ANALYZE;"
    
    # Update statistics
    run_sql "Updating table statistics" "ANALYZE;"
    
    # Clean up old log entries (older than 30 days)
    run_sql "Cleaning old logs" "DELETE FROM application_logs WHERE created_at < NOW() - INTERVAL '30 days';"
    
    # Reindex frequently updated tables
    run_sql "Reindexing user tables" "REINDEX TABLE users;"
    
    echo "=== Database Maintenance Completed at $(date) ==="
    echo "Maintenance summary saved to /logs/maintenance-$(date +%Y%m%d_%H%M%S).log"
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: database-maintenance
  labels:
    app: database
    purpose: maintenance
spec:
  schedule: "0 3 * * 0"  # Every Sunday at 3:00 AM
  timeZone: "UTC"
  concurrencyPolicy: Forbid  # Never run overlapping maintenance
  successfulJobsHistoryLimit: 4  # Keep a month of successful runs
  failedJobsHistoryLimit: 2      # Keep failed runs for debugging
  startingDeadlineSeconds: 600   # Must start within 10 minutes of scheduled time
  jobTemplate:
    spec:
      backoffLimit: 1  # Only retry once for maintenance jobs
      activeDeadlineSeconds: 3600  # Maximum 1 hour for maintenance
      template:
        spec:
          containers:
          - name: db-maintenance
            image: postgres:15-alpine
            command: ["/bin/sh", "/scripts/maintenance.sh"]
            env:
            - name: DB_HOST
              valueFrom:
                secretKeyRef:
                  name: db-credentials
                  key: host
            - name: DB_USERNAME
              valueFrom:
                secretKeyRef:
                  name: db-credentials
                  key: username
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: db-credentials
                  key: password
            volumeMounts:
            - name: maintenance-scripts
              mountPath: /scripts
            - name: log-storage
              mountPath: /logs
            resources:
              limits:
                memory: "512Mi"
                cpu: "1000m"
              requests:
                memory: "256Mi"
                cpu: "500m"
          volumes:
          - name: maintenance-scripts
            configMap:
              name: maintenance-scripts
              defaultMode: 0755
          - name: log-storage
            persistentVolumeClaim:
              claimName: maintenance-logs-pvc
          restartPolicy: OnFailure
```

This comprehensive example shows several production-ready patterns. The database credentials are stored securely in a Secret. The maintenance logic is in a ConfigMap for easy updates. The CronJob is configured to never run overlapping maintenance tasks, which could cause database locks or conflicts.

```bash
# Deploy the maintenance system
kubectl apply -f database-maintenance-cronjob.yaml

# Test the maintenance job manually before waiting for Sunday
kubectl create job --from=cronjob/database-maintenance manual-maintenance-test

# Monitor the test execution
kubectl logs -f job/manual-maintenance-test

# Check the CronJob status and next scheduled run
kubectl get cronjob database-maintenance -o wide
```

## Complete Mini-Project: Batch Processing System with Monitoring

Let's put everything together in a comprehensive batch processing system that demonstrates enterprise-grade practices.

```bash
#!/bin/bash
# save as enterprise-batch-system.sh
# This script creates a complete batch processing environment with monitoring and cleanup

NAMESPACE="batch-processing"
echo "🏗️  Setting up enterprise batch processing system in namespace: $NAMESPACE"

# Create namespace with proper labels
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | \
kubectl apply -f - --context
kubectl label namespace $NAMESPACE purpose=batch-processing environment=production

# Create storage for batch processing
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: batch-storage
  namespace: $NAMESPACE
  labels:
    app: batch-processing
    type: storage
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 5Gi
  storageClassName: standard
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: batch-logs
  namespace: $NAMESPACE
  labels:
    app: batch-processing
    type: logs
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
  storageClassName: standard
EOF

# Create processing scripts as ConfigMap
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: batch-scripts
  namespace: $NAMESPACE
data:
  data-processor.sh: |
    #!/bin/bash
    set -e
    echo "=== Batch Processor \$HOSTNAME Starting at \$(date) ==="
    
    # Create unique work directory
    WORK_DIR="/data/work/\${HOSTNAME}-\$(date +%s)"
    mkdir -p "\$WORK_DIR"
    
    # Simulate data processing
    echo "Processing batch data in \$WORK_DIR"
    for i in \$(seq 1 10); do
        echo "Processing item \$i/10 at \$(date)" >> "\$WORK_DIR/process.log"
        # Simulate varying processing times
        sleep \$((RANDOM % 5 + 1))
    done
    
    # Generate results
    RESULT_FILE="/data/results/result-\${HOSTNAME}-\$(date +%Y%m%d_%H%M%S).json"
    cat > "\$RESULT_FILE" << EOJ
    {
      "worker": "\$HOSTNAME",
      "started": "\$(date -Iseconds)",
      "completed": "\$(date -Iseconds)",
      "items_processed": 10,
      "work_directory": "\$WORK_DIR",
      "status": "success"
    }
    EOJ
    
    echo "=== Batch Processor \$HOSTNAME Completed Successfully ==="
  
  cleanup.sh: |
    #!/bin/bash
    echo "=== Cleanup Job Starting at \$(date) ==="
    
    # Clean work directories older than 1 hour
    find /data/work -type d -mmin +60 -exec rm -rf {} + 2>/dev/null || true
    
    # Clean old result files (keep last 50)
    cd /data/results
    ls -t *.json 2>/dev/null | tail -n +51 | xargs rm -f 2>/dev/null || true
    
    # Log cleanup summary
    WORK_DIRS=\$(find /data/work -type d | wc -l)
    RESULT_FILES=\$(ls /data/results/*.json 2>/dev/null | wc -l)
    
    echo "Cleanup completed: \$WORK_DIRS work directories, \$RESULT_FILES result files remaining"
    echo "Cleanup completed at \$(date)" >> /logs/cleanup.log
EOF

# Create the parallel batch processing job
cat << EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: data-processing-batch
  namespace: $NAMESPACE
  labels:
    app: batch-processing
    type: parallel-job
spec:
  parallelism: 5          # 5 workers running simultaneously
  completions: 20         # Process 20 batches total
  backoffLimit: 3         # Allow some failures
  activeDeadlineSeconds: 1800  # 30 minutes maximum
  template:
    metadata:
      labels:
        app: batch-processing
        role: worker
    spec:
      containers:
      - name: batch-processor
        image: busybox:1.35
        command: ["/bin/sh", "/scripts/data-processor.sh"]
        volumeMounts:
        - name: batch-scripts
          mountPath: /scripts
        - name: batch-storage
          mountPath: /data
        - name: batch-logs
          mountPath: /logs
        resources:
          limits:
            memory: "256Mi"
            cpu: "500m"
          requests:
            memory: "128Mi"
            cpu: "250m"
        env:
        - name: BATCH_ID
          value: "batch-\$(date +%Y%m%d_%H%M%S)"
      volumes:
      - name: batch-scripts
        configMap:
          name: batch-scripts
          defaultMode: 0755
      - name: batch-storage
        persistentVolumeClaim:
          claimName: batch-storage
      - name: batch-logs
        persistentVolumeClaim:
          claimName: batch-logs
      restartPolicy: Never
EOF

# Create cleanup CronJob
cat << EOF | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: batch-cleanup
  namespace: $NAMESPACE
  labels:
    app: batch-processing
    purpose: cleanup
spec:
  schedule: "0 */4 * * *"  # Every 4 hours
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: cleanup
            image: busybox:1.35
            command: ["/bin/sh", "/scripts/cleanup.sh"]
            volumeMounts:
            - name: batch-scripts
              mountPath: /scripts
            - name: batch-storage
              mountPath: /data
            - name: batch-logs
              mountPath: /logs
            resources:
              limits:
                memory: "128Mi"
                cpu: "250m"
              requests:
                memory: "64Mi"
                cpu: "100m"
          volumes:
          - name: batch-scripts
            configMap:
              name: batch-scripts
              defaultMode: 0755
          - name: batch-storage
            persistentVolumeClaim:
              claimName: batch-storage
          - name: batch-logs
            persistentVolumeClaim:
              claimName: batch-logs
          restartPolicy: OnFailure
EOF

echo "✅ Enterprise batch processing system deployed successfully!"
echo ""
echo "📊 Monitoring Commands:"
echo "   Watch job progress:     kubectl get jobs -n $NAMESPACE -w"
echo "   View worker pods:       kubectl get pods -n $NAMESPACE -l role=worker"
echo "   Check processing logs:  kubectl logs -n $NAMESPACE -l role=worker --prefix=true -f"
echo "   View cleanup schedule:  kubectl get cronjob -n $NAMESPACE"
echo ""
echo "🔍 Inspection Commands:"
echo "   Check results:          kubectl exec -n $NAMESPACE -it \$(kubectl get pod -n $NAMESPACE -l role=worker -o name | head -1 | cut -d'/' -f2) -- ls -la /data/results/"
echo "   View cleanup logs:      kubectl logs -n $NAMESPACE -l purpose=cleanup"
echo ""
echo "🧹 Cleanup:"
echo "   Remove everything:      kubectl delete namespace $NAMESPACE"
echo ""
echo "🎯 This system demonstrates:"
echo "   • Parallel batch processing with proper resource limits"
echo "   • Persistent storage for work data and results"
echo "   • Automated cleanup with CronJobs"
echo "   • Proper labeling and organization"
echo "   • Production-ready error handling and logging"
```

## Key Takeaways for Mastering Jobs and CronJobs

Understanding Jobs and CronJobs deeply means grasping not just the commands and YAML syntax, but the underlying patterns and use cases. Jobs are perfect for finite workloads that need to complete successfully, while CronJobs handle recurring batch tasks that need to run on a schedule.

The parallelism and completions model allows you to scale batch processing horizontally, making efficient use of cluster resources. Resource limits prevent runaway batch jobs from affecting other workloads. Proper monitoring and logging are essential because batch jobs often run unattended and you need to understand their behavior over time.

CronJobs add scheduling complexity but provide powerful automation capabilities. Understanding concurrency policies helps you handle long-running jobs gracefully. History limits keep your cluster clean while preserving enough information for debugging.

These tools become incredibly powerful when combined with persistent storage, ConfigMaps for processing logic, and Secrets for credentials. They enable you to build sophisticated data processing pipelines that can handle enterprise-scale batch workloads reliably and efficiently.