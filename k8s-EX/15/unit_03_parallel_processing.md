# Unit 3: Parallel Processing - Scaling Your Batch Work

## Pre-Unit Reflection

Before we explore parallel processing, let's tap into what you already know:

**Think about your daily experience:**
- When you have a large pile of dishes to wash, would it be faster to wash them one by one, or to have multiple people washing simultaneously?
- If you needed to send 100 invitations, would you rather write them yourself, or have 5 friends each write 20?
- What challenges might arise when multiple people work on the same project at the same time?

**From your programming experience:**
- Have you ever written code that processed a large dataset?
- What made it slow? What could have made it faster?
- What happens when multiple processes try to write to the same file?

## Learning Objectives
By the end of this unit, you will:
- Understand when parallel processing provides benefits
- Configure Jobs with parallelism and completions
- Design work that can be safely distributed across multiple pods
- Monitor and troubleshoot parallel job execution
- Recognize common pitfalls in parallel batch processing

## Discovering the Need for Parallelism

Let's start by experiencing the problem that parallelism solves.

### Experiment: The Slow Sequential Job

Create a job that simulates slow, sequential processing:

```yaml
# Save as slow-sequential.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: slow-sequential
spec:
  template:
    spec:
      containers:
      - name: processor
        image: busybox:1.35
        command: ["sh", "-c"]
        args:
        - |
          echo "Starting sequential processing at $(date)"
          for i in $(seq 1 10); do
            echo "Processing item $i at $(date)"
            sleep 6  # Each item takes 6 seconds
            echo "Completed item $i"
          done
          echo "All processing complete at $(date)"
      restartPolicy: Never
```

**Before running this:**
- How long do you predict this will take?
- What's the total processing time for 10 items at 6 seconds each?

```bash
kubectl apply -f slow-sequential.yaml
kubectl get job slow-sequential -w
```

**Observation Questions:**
- How does it feel watching this run?
- In what real-world scenarios would this pattern be inefficient?
- What if you had 1000 items instead of 10?

### Your Challenge: Design a Better Solution

Before I show you the parallel approach, think through this:

**Design Questions:**
- If you had 10 items and could use 5 workers, how would you divide the work?
- What would happen if Worker 1 finished early while Worker 5 was still processing?
- How would you ensure all 10 items get processed exactly once?

**Sketch your approach:** Draw or write out how you'd distribute this work.

## Introducing Parallelism and Completions

Now let's see Kubernetes' solution to this challenge:

### The Parallel Processing Model

```yaml
# Save as parallel-processing.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: parallel-processing
spec:
  completions: 10      # Total number of successful pod completions needed
  parallelism: 3       # Maximum number of pods running simultaneously
  template:
    spec:
      containers:
      - name: worker
        image: busybox:1.35
        command: ["sh", "-c"]
        args:
        - |
          WORKER_ID=$(hostname | sed 's/.*-//')
          echo "Worker $WORKER_ID starting at $(date)"
          
          # Simulate processing one work item
          PROCESS_TIME=$((RANDOM % 10 + 5))  # Random 5-15 seconds
          echo "Worker $WORKER_ID processing for $PROCESS_TIME seconds"
          sleep $PROCESS_TIME
          
          echo "Worker $WORKER_ID completed at $(date)"
      restartPolicy: Never
```

**Before applying, predict the behavior:**
- How many pods will start immediately?
- What happens when the first pod completes?
- How long will this take compared to the sequential version?

```bash
kubectl apply -f parallel-processing.yaml

# Watch the parallel execution
kubectl get pods -l job-name=parallel-processing -w
```

**Real-Time Analysis:**
- How many pods are running simultaneously?
- What happens as pods complete?
- How does this compare to your prediction?

### Understanding the Worker Pattern

Let's examine what happened:

```bash
# Check the final job status
kubectl get job parallel-processing

# Look at all the worker pods
kubectl get pods -l job-name=parallel-processing

# Check logs from different workers
kubectl logs -l job-name=parallel-processing --prefix=true
```

**Investigation Questions:**
- How did Kubernetes decide when to start new workers?
- Did all workers take the same amount of time?
- How does this pattern handle variable processing times?

## Hands-On Challenge: Design Your Own Parallel Workflow

Now it's your turn to solve a realistic parallel processing problem.

### The Scenario: Image Processing Pipeline

Imagine you need to process 20 images, and each image takes 10-30 seconds to process. You want to use 4 workers maximum.

**Planning Questions:**
1. What values would you use for `completions` and `parallelism`?
2. How would you simulate different processing times?
3. What information should each worker log to help you track progress?
4. How could you make each worker's output unique and identifiable?

### Your Implementation Challenge

Create a YAML file that:
- Processes 20 total work items (completions)
- Uses maximum 4 workers (parallelism) 
- Simulates realistic variable processing times
- Provides clear logging from each worker
- Includes worker identification in the output

**Template to get you started:**
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: image-processor
  labels:
    type: parallel-batch
    purpose: learning
spec:
  completions: ?  # You decide
  parallelism: ?  # You decide
  template:
    spec:
      containers:
      - name: processor
        image: busybox:1.35
        command: ["sh", "-c"]
        args:
        - |
          # Your processing logic here
          # Think about:
          # - How to identify this worker
          # - How to simulate realistic work
          # - What to log for visibility
          # - How to make timing realistic
      restartPolicy: Never
```

**After you implement it:**
- Test your solution and observe the behavior
- Does it work as you expected?
- What would you change about the design?

## Advanced Parallel Processing Patterns

Once you've mastered basic parallelism, let's explore more sophisticated patterns.

### Pattern 1: Dynamic Work Distribution

What if the work items aren't identical? Let's simulate a scenario where some items take much longer than others:

```yaml
# Save as dynamic-workload.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: dynamic-workload
spec:
  completions: 8
  parallelism: 3
  template:
    spec:
      containers:
      - name: worker
        image: busybox:1.35
        command: ["sh", "-c"]
        args:
        - |
          WORKER=$(hostname | sed 's/.*-//')
          
          # Simulate different types of work with varying complexity
          WORK_TYPES=("quick" "medium" "slow" "very-slow")
          WORK_TYPE=${WORK_TYPES[$((RANDOM % 4))]}
          
          case $WORK_TYPE in
            "quick") DURATION=3 ;;
            "medium") DURATION=8 ;;
            "slow") DURATION=15 ;;
            "very-slow") DURATION=25 ;;
          esac
          
          echo "Worker $WORKER got $WORK_TYPE task (${DURATION}s) at $(date)"
          sleep $DURATION
          echo "Worker $WORKER completed $WORK_TYPE task at $(date)"
      restartPolicy: Never
```

**Observation Exercise:**
```bash
kubectl apply -f dynamic-workload.yaml
kubectl get pods -l job-name=dynamic-workload -w
```

**Analysis Questions:**
- How does Kubernetes handle workers that finish at very different times?
- What happens to overall efficiency when work items vary significantly?
- In real scenarios, how could you optimize for this variability?

### Pattern 2: Resource-Aware Parallel Processing

Let's add resource constraints and see how they affect parallel execution:

```yaml
# Save as resource-aware-parallel.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: resource-aware-parallel
spec:
  completions: 6
  parallelism: 4  # Want 4 workers, but will resources allow it?
  template:
    spec:
      containers:
      - name: worker
        image: busybox:1.35
        command: ["sh", "-c"]
        args:
        - |
          echo "Worker $(hostname) starting heavy computation at $(date)"
          
          # Simulate CPU-intensive work
          for i in $(seq 1 1000000); do
            echo $((i * i)) > /dev/null
          done
          
          echo "Worker $(hostname) completed computation at $(date)"
        resources:
          requests:
            memory: "256Mi"
            cpu: "500m"
          limits:
            memory: "512Mi"
            cpu: "1000m"
      restartPolicy: Never
```

**Resource Investigation:**
```bash
kubectl apply -f resource-aware-parallel.yaml
kubectl get pods -l job-name=resource-aware-parallel -w
kubectl describe job resource-aware-parallel
```

**Critical Thinking Questions:**
- Do all 4 workers start immediately?
- What happens if your cluster doesn't have enough resources for full parallelism?
- How would you detect resource constraints affecting your job?

## Troubleshooting Parallel Jobs

Parallel processing introduces new categories of problems. Let's explore them:

### Debugging Exercise: The Mysterious Failure

Create a job where some workers might fail:

```bash
# Create a job where workers randomly fail
kubectl create job unreliable-workers --image=busybox:1.35 -- sh -c '
if [ $((RANDOM % 3)) -eq 0 ]; then
  echo "Worker failed at $(date)"; 
  exit 1; 
else 
  echo "Worker succeeded at $(date)"; 
  sleep 5; 
fi'

# Make it parallel
kubectl patch job unreliable-workers -p '{"spec":{"parallelism":3,"completions":5}}'
```

**Troubleshooting Challenge:**
Monitor this job and answer:
- How does Kubernetes handle failed workers?
- What happens to the overall job progress when individual workers fail?
- How can you distinguish between failed pods and successful ones?

**Investigation Commands:**
```bash
kubectl get job unreliable-workers -w
kubectl get pods -l job-name=unreliable-workers
kubectl describe job unreliable-workers
```

### Common Parallel Processing Pitfalls

Based on what you've observed, what problems might arise in these scenarios:

1. **Shared Resource Conflicts:** What if all workers try to write to the same file?
2. **Work Duplication:** How do you ensure work items are processed exactly once?
3. **Resource Starvation:** What if you request more parallelism than your cluster can support?
4. **Cascading Failures:** What if one worker's failure affects others?

**Discussion Questions:**
- Which of these have you encountered in your own parallel processing experience?
- How would you design your work distribution to avoid these issues?
- What patterns have you seen in successful parallel systems?

## Mini-Project: Build a Complete Parallel Processing Pipeline

Design and implement a parallel job that solves a realistic problem. Choose one:

### Option 1: Log Analysis Pipeline
Process multiple log files in parallel, extracting error counts from each:

```yaml
# Your implementation here
# Requirements:
# - Process 12 "log files" (simulated)
# - Use 3 workers maximum
# - Each worker processes different severity levels
# - Report findings in a structured format
```

### Option 2: Data Validation Pipeline
Validate multiple data sets in parallel:

```yaml
# Your implementation here
# Requirements:
# - Validate 15 data sets
# - Use 5 workers maximum
# - Some data sets should "fail" validation
# - Track validation results clearly
```

**Project Success Criteria:**
- Job completes successfully with proper parallelism
- Clear logging shows which worker processed what
- Proper error handling for failed work items
- Resource limits prevent cluster overload
- Easy to monitor progress and debug issues

## Self-Assessment and Reflection

Test your understanding of parallel processing:

**Scenario Analysis:**
For each scenario, determine the optimal parallelism and completions settings:

1. **Image resizing:** 100 images, each takes 5-10 seconds, 8 CPU cores available
2. **Database queries:** 50 queries, some take 2 seconds, others take 20 seconds
3. **File compression:** 20 large files, each takes 1-3 minutes, limited disk I/O

**Design Challenges:**
- How would you handle work items that depend on each other?
- What if you needed to aggregate results from all workers?
- How would you implement a retry mechanism for failed work items?

## Key Insights and Patterns

Before moving to Unit 4, ensure you understand:

1. **The Parallelism Model**
   - `completions` = total work to be done
   - `parallelism` = maximum concurrent workers
   - Kubernetes manages worker lifecycle automatically

2. **When Parallelism Helps**
   - Independent work items
   - CPU or I/O bound tasks
   - Large volumes of similar work
   - Variable processing times

3. **Common Pitfalls**
   - Resource conflicts between workers
   - Work duplication or missed items
   - Resource starvation
   - Inefficient work distribution

## Preparation for Unit 4

In Unit 4, we'll explore CronJobs for scheduled recurring tasks. Consider:
- What batch processing tasks need to run on a schedule in your projects?
- How do scheduling requirements change the design of your jobs?
- What additional challenges arise when jobs run automatically without human oversight?

## Confidence Check

Rate your understanding (1-5):
- [ ] I understand the relationship between parallelism and completions
- [ ] I can design parallel jobs for realistic processing scenarios
- [ ] I can monitor and troubleshoot parallel job execution
- [ ] I understand when parallelism provides benefits and when it doesn't
- [ ] I can identify and avoid common parallel processing pitfalls

**If any rating is below 3:** Practice with additional parallel job examples before proceeding.

**Ready for scheduling?** Unit 4 will introduce CronJobs for automated recurring tasks!