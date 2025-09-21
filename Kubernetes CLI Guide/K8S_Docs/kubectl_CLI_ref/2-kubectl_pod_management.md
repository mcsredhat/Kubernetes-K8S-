# Pod Management and Lifecycle Operations

Pods are the fundamental execution unit in Kubernetes. These commands cover everything from basic pod creation to advanced debugging scenarios that you'll encounter in production environments.

## Pod Creation and Management
```bash
# Basic pod creation patterns
kubectl run <pod-name> --image=<image> --restart=Never    # Create single pod
kubectl run <pod-name> --image=<image> --port=<port>      # Pod with exposed port
kubectl run <pod-name> --image=<image> --env="KEY=VALUE" --restart=Never  # Pod with environment

# Advanced pod creation with comprehensive configuration
kubectl run $APP_NAME \
  --image=nginx:1.21 \
  --port=80 \
  --restart=Never \
  --namespace=production \
  --labels="app=$APP_NAME,tier=frontend,version=v1.0" \
  --annotations="description=$APP_NAME production pod" \
  --annotations="owner=platform-team" \
  --env="PORT=80" \
  --env="APP_ENV=production" \
  --requests="cpu=100m,memory=128Mi" \
  --limits="cpu=500m,memory=512Mi" \
  --dry-run=client \
  --output=yaml > $APP_NAME-production.yaml

# Pod lifecycle management
kubectl apply -f pod-config.yaml             # Apply pod configuration
kubectl delete pod <pod-name>                # Delete specific pod
kubectl delete pod <pod-name> --grace-period=0 --force  # Force delete stuck pod
kubectl delete pods --all                    # Delete all pods in current namespace
kubectl delete pods -l app=<label-value>     # Delete pods by label selector

# Pod replacement and patching
kubectl replace -f pod-config.yaml           # Replace existing pod
kubectl patch pod <pod-name> -p '{"spec":{"containers":[{"name":"container-name","image":"new-image:tag"}]}}'  # Patch pod configuration
```

## Pod Monitoring and Status
```bash
# Basic pod listing and status
kubectl get pods                              # List pods in current namespace
kubectl get pods -o wide                      # Extended information (node, IP, etc.)
kubectl get pods --all-namespaces            # Pods across all namespaces
kubectl get pods -w                          # Watch pod changes in real-time
kubectl get pods --watch-only --output-watch-events  # Watch with detailed event info

# Advanced pod status monitoring
kubectl get pods --sort-by=.metadata.creationTimestamp       # Sort by age
kubectl get pods --sort-by=.status.startTime                # Sort by start time
kubectl get pods --field-selector=status.phase=Running       # Filter running pods
kubectl get pods --field-selector=status.phase=Pending       # Find pending pods
kubectl get pods --field-selector=status.phase=Failed        # Find failed pods
kubectl get pods --field-selector=spec.nodeName=<node-name>  # Pods on specific node

# Pod filtering and advanced queries
kubectl get pods -l app=nginx                                # Filter by single label
kubectl get pods -l 'environment in (production,staging)'    # Multiple label values
kubectl get pods -l 'app,version'                           # Pods with both labels
kubectl get pods -l 'app!=legacy'                           # Exclude specific label value
kubectl get pods --field-selector=status.phase!=Running      # Non-running pods
kubectl get pods --field-selector=spec.restartPolicy=Always  # Pods with specific restart policy

# Resource usage and performance monitoring
kubectl top pods                                    # Current CPU and memory usage
kubectl top pods --sort-by=memory                   # Sort by memory consumption
kubectl top pods --sort-by=cpu                      # Sort by CPU usage
kubectl top pods -l app=nginx --containers          # Usage by container
kubectl top pods --all-namespaces | head -10       # Top resource consumers cluster-wide
```

## Enhanced Output Formats for Pod Analysis
```bash
# Custom columns for specific information
kubectl get pods -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName,IP:.status.podIP
kubectl get pods -o custom-columns=NAME:.metadata.name,READY:.status.containerStatuses[0].ready,RESTARTS:.status.containerStatuses[0].restartCount
kubectl get pods -o custom-columns=POD:.metadata.name,NAMESPACE:.metadata.namespace,CREATED:.metadata.creationTimestamp

# JSONPath queries for precise data extraction
kubectl get pods -o jsonpath='{.items[*].metadata.name}'                    # Pod names only
kubectl get pods -o jsonpath='{.items[*].status.podIP}'                     # Pod IPs only
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{" => "}{.status.phase}{"\n"}{end}'  # Name and status
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{" @ "}{.spec.nodeName}{"\n"}{end}'  # Pod to node mapping

# Go template output format for complex formatting
kubectl get pods -o go-template='{{range .items}}{{.metadata.name}}{{"\t"}}{{.status.phase}}{{"\t"}}{{.spec.nodeName}}{{"\n"}}{{end}}'
kubectl get pods -o go-template='{{range .items}}{{if eq .status.phase "Running"}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}'  # Only running pods
kubectl get pods -o go-template='{{range .items}}{{.metadata.name}}: {{range .spec.containers}}{{.image}} {{end}}{{"\n"}}{{end}}'  # Pod images

# Complex status analysis with table format
kubectl get pods -o custom-columns-file=pod-columns.txt  # Use predefined column file
# Create pod-columns.txt:
# NAME:.metadata.name
# STATUS:.status.phase
# READY:.status.containerStatuses[*].ready
# RESTARTS:.status.containerStatuses[*].restartCount
# AGE:.metadata.creationTimestamp
```

## Pod Debugging and Inspection
```bash
# Detailed pod inspection
kubectl describe pod <pod-name>               # Comprehensive pod details and events
kubectl describe pod <pod-name> | grep -A 5 Events  # Focus on recent events
kubectl get pod <pod-name> -o yaml           # Full pod specification
kubectl get pod <pod-name> -o yaml | grep -A 10 status  # Focus on status section

# Configuration comparison and diff
kubectl diff -f pod-config.yaml              # Compare current state with file
kubectl get pod <pod-name> -o yaml | kubectl diff -f -  # Compare with stdin

# Log analysis and monitoring
kubectl logs <pod-name>                           # Current container logs
kubectl logs <pod-name> -f                        # Follow logs in real-time
kubectl logs <pod-name> --previous               # Previous container logs (after restart)
kubectl logs <pod-name> --since=1h               # Logs from last hour
kubectl logs <pod-name> --since-time=2024-01-01T00:00:00Z  # Logs since specific time
kubectl logs <pod-name> --tail=100               # Last 100 log lines
kubectl logs -l app=nginx --prefix=true          # Logs from multiple pods with prefix
kubectl logs <pod-name> -c <container-name>      # Logs from specific container

# Advanced log queries with jq processing
kubectl logs <pod-name> --output json | jq '.[] | select(.level=="ERROR")'  # Filter error logs
kubectl logs <pod-name> -f --output json | jq -r '.timestamp + " " + .message'  # Formatted live logs
```

## Interactive Debugging and Execution
```bash
# Interactive debugging and execution
kubectl exec <pod-name> -- <command>                    # Execute command in pod
kubectl exec -it <pod-name> -- /bin/bash               # Interactive shell
kubectl exec <pod-name> -c <container-name> -- <command>  # Execute in specific container
kubectl exec -it <pod-name> -- sh -c "ps aux | grep nginx"  # Complex commands

# Debug pod creation for troubleshooting
kubectl run debug-pod --image=busybox --rm -it --restart=Never -- sh  # Temporary debug pod
kubectl run network-debug --image=nicolaka/netshoot --rm -it --restart=Never -- bash  # Network debugging
kubectl run ubuntu-debug --image=ubuntu --rm -it --restart=Never -- bash  # Full Ubuntu environment

# File operations between local system and pods
kubectl cp <local-file> <pod-name>:<remote-path>       # Copy file to pod
kubectl cp <pod-name>:<remote-path> <local-file>       # Copy file from pod
kubectl cp <local-directory> <pod-name>:<remote-directory> --container <container-name>  # Directory copy

# Advanced exec scenarios
kubectl exec <pod-name> -- env                         # Environment variables
kubectl exec <pod-name> -- cat /etc/resolv.conf        # DNS configuration
kubectl exec <pod-name> -- netstat -tuln               # Network connections
kubectl exec <pod-name> -- df -h                       # Disk usage
kubectl exec <pod-name> -- top -bn1                    # Process information
```

## Pod Security Context and Capabilities
```bash
# Security context analysis
kubectl get pods -o custom-columns=NAME:.metadata.name,USER:.spec.securityContext.runAsUser,GROUP:.spec.securityContext.runAsGroup
kubectl get pods -o custom-columns=NAME:.metadata.name,PRIVILEGED:.spec.containers[0].securityContext.privileged
kubectl describe pod <pod-name> | grep -A 15 "Security Context"  # Detailed security settings

# Container capabilities inspection
kubectl get pod <pod-name> -o jsonpath='{.spec.containers[*].securityContext.capabilities}'
kubectl describe pod <pod-name> | grep -A 5 -B 5 "Capabilities"  # Capability settings
```

## Pod Lifecycle Hooks and Probes
```bash
# Probe configuration analysis
kubectl get pods -o custom-columns=NAME:.metadata.name,LIVENESS:.spec.containers[0].livenessProbe,READINESS:.spec.containers[0].readinessProbe
kubectl describe pod <pod-name> | grep -A 10 "Liveness\|Readiness\|Startup"  # Probe details

# Lifecycle hook inspection
kubectl get pod <pod-name> -o jsonpath='{.spec.containers[*].lifecycle}'
kubectl describe pod <pod-name> | grep -A 5 -B 5 "Post Start\|Pre Stop"  # Lifecycle hooks
```