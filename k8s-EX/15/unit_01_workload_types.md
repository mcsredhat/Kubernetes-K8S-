# Unit 1: Understanding Workload Types - The Foundation

## Learning Objectives
By the end of this unit, you will:
- Distinguish between continuous and finite workloads
- Identify when to use Jobs vs Deployments
- Understand the fundamental problem Jobs solve
- Create your mental model for batch processing in Kubernetes

## Pre-Learning Reflection
Before we dive in, take a moment to think about these questions:
- What types of tasks do you run on computers that have a clear beginning and end?
- What's the difference between a web server that needs to run 24/7 and a script that processes some files and then stops?
- Have you ever had a script that you only wanted to run once, but something kept restarting it automatically?

## The Restaurant Analogy: Understanding Workload Types

Imagine you're managing two different types of businesses:

**Restaurant (Continuous Workload)**
- Must stay open during business hours
- Serves customers continuously
- If the kitchen stops working, you fix it immediately
- Success = staying available and responsive

**Construction Project (Finite Workload)**  
- Has a specific start and completion date
- Once the house is built, the project is done
- You don't want workers showing up after completion
- Success = completing the work and stopping

### Discussion Questions
1. Which type of workload is a web server? Why?
2. Which type is a data backup script? Why?
3. What would happen if you treated a construction project like a restaurant?
4. What would happen if you treated a restaurant like a construction project?

## Kubernetes Resources for Each Workload Type

**For Continuous Workloads (Like Restaurants):**
- Deployments - for stateless applications
- StatefulSets - for stateful applications  
- DaemonSets - for system services on every node

**For Finite Workloads (Like Construction Projects):**
- Jobs - for one-time tasks
- CronJobs - for scheduled recurring tasks

## Hands-On Exploration: The Problem Jobs Solve

Let's see what happens when we use the wrong tool for the job.

### Experiment 1: Using a Deployment for Finite Work

```bash
# Create a Deployment that calculates pi and exits
kubectl create deployment bad-pi-calc --image=perl:5.34 -- perl -Mbignum=bpi -wle 'print bpi(100)'

# Watch what happens
kubectl get pods -l app=bad-pi-calc -w
```

**Observation Questions:**
- What do you see happening to the pods?
- How many times does the calculation run?
- Is this what you wanted for a one-time calculation?

### Experiment 2: Using a Job for the Same Task

```bash
# Create a Job for the same calculation
kubectl create job good-pi-calc --image=perl:5.34 -- perl -Mbignum=bpi -wle 'print bpi(100)'

# Watch what happens
kubectl get pods -l job-name=good-pi-calc -w
kubectl get jobs
```

**Reflection Questions:**
- How does the Job behavior differ from the Deployment?
- What happens after the calculation completes?
- Which approach makes more sense for this task?

### Clean Up Your Experiments

```bash
kubectl delete deployment bad-pi-calc
kubectl delete job good-pi-calc
```

## Real-World Workload Classification Exercise

For each scenario below, decide if it's a continuous or finite workload, and which Kubernetes resource you'd use:

1. **E-commerce website frontend** - serves web pages to customers
2. **Nightly database backup** - runs once per night
3. **Image resizing service** - processes uploaded images
4. **Monthly sales report generation** - runs first day of each month
5. **User authentication API** - validates login requests
6. **Log file cleanup script** - removes old files weekly
7. **Monitoring dashboard** - displays system metrics
8. **Data migration script** - runs once during system upgrade

### Discussion Points
- What patterns do you notice in continuous vs finite workloads?
- How does the expected lifetime of the task influence your choice?
- What about resource usage patterns?

## Mini-Project: Workload Type Decision Tree

Create a decision framework for choosing the right Kubernetes resource:

1. **Start with the fundamental question:** Does this task have a natural completion point?

2. **If YES (Finite):** 
   - Does it need to run on a schedule? → CronJob
   - Is it a one-time or manually triggered task? → Job

3. **If NO (Continuous):**
   - Does it need to maintain state? → StatefulSet
   - Does it need to run on every node? → DaemonSet  
   - Is it a typical web/API service? → Deployment

### Practice Scenarios
Test your decision tree with these scenarios:
- Processing a batch of customer orders
- Running a web API that handles payment transactions
- Generating SSL certificates that expire annually
- Operating a Redis cache cluster
- Converting video files uploaded by users
- Running a metrics collection agent on all servers

## Key Insights and Next Steps

Before moving to Unit 2, make sure you can clearly explain:

1. **The Restaurant vs Construction analogy** - When would you use each approach?
2. **Why Deployments restart containers** - What problem does this solve for continuous workloads?
3. **Why Jobs don't restart completed containers** - What problem does this solve for finite workloads?
4. **Real-world examples** - Can you classify workloads you encounter in your own projects?

## Preparation for Unit 2

In the next unit, we'll create your first Job from scratch and learn how to monitor its execution. Think about:
- What batch processing tasks do you need to do in your current projects?
- What would you want to know about a job while it's running?
- How would you troubleshoot a job that isn't working as expected?

## Quick Self-Assessment

Rate your confidence (1-5) on these concepts:
- [ ] I can distinguish between continuous and finite workloads
- [ ] I understand when to use Jobs vs Deployments
- [ ] I can predict the behavior of each workload type
- [ ] I can classify real-world scenarios correctly

If you rated anything below 3, review that section before proceeding to Unit 2.
