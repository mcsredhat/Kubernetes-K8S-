# Unit 2: Your First Job - Creation and Monitoring

## Learning Objectives
By the end of this unit, you will:
- Create Jobs using both imperative commands and declarative YAML
- Monitor Job execution and understand status indicators
- Access job output and logs effectively
- Troubleshoot basic Job failures
- Understand Job lifecycle management

## Pre-Unit Check-In
Before we start creating Jobs, let's ensure you're ready:
- Can you explain the difference between continuous and finite workloads?
- Do you have access to a Kubernetes cluster where you can run commands?
- What's one batch processing task from your work that you'd like to automate?

## Your First Job: The Calculator

Let's start with something simple that gives immediate, visible results.

### Guided Creation Exercise

Instead of just showing you the command, let's think through what we need:

**Planning Questions:**
1. What container image would be good for mathematical calculations?
2. How can we make the calculation take long enough that we can observe the job running?
3. What command would calculate something interesting that we can verify?

Now let's create our first job:

```bash
# Create a Job that calculates pi to 1000 digits
kubectl create job pi-calculator --image=perl:5.34 -- perl -Mbignum=bpi -wle 'print bpi(1000)'
```

**Immediate Observation:**
What happened when you ran this command? Did you see a pod start immediately, or was there a delay?

### Monitoring Your Job in Real-Time

Now let's learn to observe our job as it runs:

```bash
# Check the job status
kubectl get jobs
```

**Analysis Questions:**
- What do you see in the COMPLETIONS column?
- What does "0/1" vs "1/1" tell you?
- How long has your job been running?

```bash
# Watch the pods created by your job
kubectl get pods -l job-name=pi-calculator -w
```

**Observation Exercise:**
Watch the pod status change. What sequence of states do you see?
- Pending → Running → Completed?
- Did any other states appear?

### Accessing Your Job's Output

Once the job completes, how do we see what it calculated?

```bash
# View the calculation results
kubectl logs job/pi-calculator
```

**Verification Exercise:**
- Did you get exactly 1000 digits of pi?
- How can you verify this is correct? (Try comparing with an online pi calculator)
- What would happen if the calculation failed?

## Understanding Job Status and Events

Let's dig deeper into what Kubernetes tells us about our job:

```bash
# Get detailed information about your job
kubectl describe job pi-calculator
```

**Investigation Exercise:**
Look at the output and find:
1. The Events section - what story does it tell?
2. The Conditions section - what does "Complete" mean?
3. The Pod Template section - how does this compare to what you specified?

**Reflection Questions:**
- If this job had failed, where would you look first for clues?
- What information here would be most useful for debugging?

## Hands-On: Creating Jobs with YAML

Imperative commands are great for experimentation, but let's learn the declarative approach:

### Guided YAML Creation

Before I show you the YAML, think about what sections you'll need:
- What API version and kind?
- What metadata would be useful?
- What goes in the spec section?

```yaml
# Save as first-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: word-counter
  labels:
    purpose: learning
    type: batch-processing
spec:
  template:
    spec:
      containers:
      - name: counter
        image: busybox:1.35
        command: ["sh", "-c"]
        args:
        - |
          echo "Starting word count analysis..."
          echo "The quick brown fox jumps over the lazy dog" > /tmp/sample.txt
          echo "This sentence contains several words for counting" >> /tmp/sample.txt
          echo "Let's analyze this text file" >> /tmp/sample.txt
          
          echo "=== Analysis Results ==="
          echo "Total lines: $(wc -l < /tmp/sample.txt)"
          echo "Total words: $(wc -w < /tmp/sample.txt)"
          echo "Total characters: $(wc -c < /tmp/sample.txt)"
          echo "=== Complete ==="
      restartPolicy: Never
```

**Before applying, predict:**
- What will this job do when it runs?
- How long do you think it will take?
- What will appear in the logs?

```bash
# Apply your job
kubectl apply -f first-job.yaml

# Monitor its execution
kubectl get job word-counter -w
```

**Observation Questions:**
- How was creating with YAML different from the imperative command?
- What advantages does YAML give you?
- When might you prefer the imperative approach?

## Troubleshooting Exercise: When Jobs Go Wrong

Let's intentionally create a failing job to learn troubleshooting skills:

```bash
# Create a job that will fail
kubectl create job failing-job --image=busybox:1.35 -- sh -c 'echo "Starting..."; sleep 5; echo "About to fail..."; exit 1'
```

**Troubleshooting Challenge:**
1. How can you tell this job failed?
2. What commands would you use to investigate?
3. Where do you find the error message?

**Discovery Exercise:**
```bash
# Try these commands and see what each tells you
kubectl get jobs
kubectl get pods -l job-name=failing-job
kubectl describe job failing-job
kubectl logs job/failing-job
```

**Analysis Questions:**
- Which command gave you the most useful information about the failure?
- What's the difference between the job status and the pod status?
- How does a failed job behave differently from a successful one?

## Resource Cleanup Exercise

Understanding cleanup is crucial for managing cluster resources:

```bash
# List all jobs in your current namespace
kubectl get jobs

# Delete completed jobs
kubectl delete job pi-calculator word-counter failing-job
```

**Important Questions:**
- What happens to the pod when you delete a job?
- What happens to the logs?
- Should you delete jobs immediately after they complete?

## Mini-Project: Personal Batch Processor

Create a job that processes some "data" relevant to your interests. Here are some ideas:

**Option 1: System Information Collector**
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: system-info-collector
spec:
  template:
    spec:
      containers:
      - name: collector
        image: busybox:1.35
        command: ["sh", "-c"]
        args:
        - |
          echo "=== System Information Collection ==="
          echo "Date: $(date)"
          echo "Hostname: $(hostname)"
          echo "Uptime: $(uptime)"
          echo "Disk space: $(df -h /)"
          echo "Memory info: $(free -h)"
          echo "=== Collection Complete ==="
      restartPolicy: Never
```

**Option 2: Text Analyzer**
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: text-analyzer
spec:
  template:
    spec:
      containers:
      - name: analyzer
        image: busybox:1.35
        command: ["sh", "-c"]
        args:
        - |
          TEXT="Your custom text here - maybe a favorite quote or poem"
          echo "Analyzing: $TEXT"
          echo "Character count: $(echo "$TEXT" | wc -c)"
          echo "Word count: $(echo "$TEXT" | wc -w)"
          echo "Vowel count: $(echo "$TEXT" | tr -cd 'aeiouAEIOU' | wc -c)"
          echo "Analysis complete!"
      restartPolicy: Never
```

**Challenge:** Modify one of these templates to process something meaningful to you.

**Reflection Questions:**
- How did you decide what to process?
- What modifications did you make to the template?
- How could you verify your job worked correctly?

## Self-Assessment and Troubleshooting Practice

Test your understanding with these scenarios:

**Scenario 1:** You create a job, but `kubectl get jobs` shows "0/1" completions for a long time.
- What commands would you run to investigate?
- What are the most likely causes?

**Scenario 2:** Your job completes, but when you check the logs, they're empty.
- What might have gone wrong?
- How could you modify the job to be more verbose?

**Scenario 3:** You want to run the same job multiple times with different inputs.
- Should you create multiple jobs or reuse the same one?
- How would you organize this?

## Key Insights and Patterns

Before moving to Unit 3, ensure you understand:

1. **Job Creation Patterns**
   - When to use imperative vs declarative approaches
   - Essential YAML structure for Jobs
   - Importance of `restartPolicy: Never`

2. **Monitoring and Debugging Flow**
   - `kubectl get jobs` for high-level status
   - `kubectl describe job` for detailed events
   - `kubectl logs job/<name>` for output
   - `kubectl get pods` for underlying pod status

3. **Lifecycle Management**
   - Jobs don't automatically clean up
   - Completed jobs remain for log access
   - Manual deletion removes both job and pods

## Preparation for Unit 3

In the next unit, we'll explore parallel processing - running multiple workers simultaneously. Think about:
- What tasks could benefit from parallel processing?
- How would you divide work among multiple workers?
- What challenges might arise when multiple pods work on the same task?

## Confidence Check

Rate your understanding (1-5):
- [ ] I can create Jobs using both kubectl commands and YAML
- [ ] I can monitor job execution and understand the status indicators
- [ ] I can access job logs and troubleshoot basic failures
- [ ] I understand when and why to delete completed jobs
- [ ] I can explain the job lifecycle from creation to completion

**If any rating is below 3:** Review that section and practice with additional examples before proceeding.

**All 4s or 5s?** Excellent! You're ready to explore parallel processing in Unit 3.
