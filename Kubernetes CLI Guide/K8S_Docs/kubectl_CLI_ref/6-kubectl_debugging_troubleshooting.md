# Debugging and Troubleshooting

When applications fail or behave unexpectedly, these debugging techniques help you identify root causes quickly. Master these commands to become effective at production troubleshooting.

## Log Analysis and Advanced Monitoring
```bash
# Basic log operations with enhanced filtering
kubectl logs <pod-name>                                    # Current container logs
kubectl logs <pod-name> -f                                 # Follow logs in real-time
kubectl logs <pod-name> --previous                         # Previous container instance logs
kubectl logs <pod-name> -c <container-name>               # Specific container logs
kubectl logs <pod-name> --all-containers=true             # All containers in pod

# Time-based log filtering and analysis
kubectl logs <pod-name> --since=2h                         # Logs from last 2 hours
kubectl logs <pod-name> --since=2024-01-01T10:00:00Z      # Logs since specific timestamp
kubectl logs <pod-name> --tail=100                        # Last 100 lines
kubectl logs <pod-name> --since=1h --tail=50              # Combined time and line limits
kubectl logs <pod-name> --timestamps                       # Include timestamps in output

# Multi-pod log aggregation and analysis
kubectl logs -l app=nginx --prefix=true                   # Logs from multiple pods with pod names
kubectl logs -l app=nginx --previous --prefix=true        # Previous logs from multiple pods
kubectl logs deployment/<name>                            # All pods in deployment
kubectl logs -f -l app=nginx --max-log-requests=10       # Follow logs from up to 10 pods
kubectl logs job/<job-name>                               # All pods in job

# Advanced log processing and filtering
kubectl logs <pod-name> | grep -E "(ERROR|WARN|FATAL)"    # Filter by log levels
kubectl logs <pod-name> | grep -v "DEBUG"                 # Exclude debug logs
kubectl logs <pod-name> --since=1h | wc -l                # Count log lines in last hour
kubectl logs <pod-name> -f | grep --line-buffered "error" # Real-time error filtering

# Structured log analysis with jq
kubectl logs <pod-name> --output json | jq '.[] | select(.level=="ERROR")'  # Filter error logs
kubectl logs <pod-name> --output json | jq -r '.timestamp + " " + .message'  # Formatted output
kubectl logs <pod-name> --output json | jq 'group_by(.level) | map({level: .[0].level, count: length})'  # Log level summary
```

## Enhanced Network Debugging
```bash
# DNS resolution and service discovery testing
kubectl run dns-debug --image=busybox --rm -it --restart=Never -- nslookup kubernetes.default.svc.cluster.local
kubectl run dns-debug --image=busybox --rm -it --restart=Never -- nslookup <service-name>.<namespace>.svc.cluster.local
kubectl exec -it <pod-name> -- cat /etc/resolv.conf             # DNS configuration in pod
kubectl exec -it <pod-name> -- dig <service-name> +search       # DNS with search domains

# Advanced connectivity testing
kubectl run curl-debug --image=curlimages/curl --rm -it --restart=Never -- curl -v http://<service-name>
kubectl run wget-debug --image=busybox --rm -it --restart=Never -- wget -qO- http://<service-name>
kubectl run network-debug --image=nicolaka/netshoot --rm -it --restart=Never -- /bin/bash          # Full network toolkit

# Network debugging with netshoot container
# Inside netshoot, use these advanced commands:
kubectl run netshoot --image=nicolaka/netshoot --rm -it --restart=Never -- bash
# Available tools:
# - nmap -p 80 <service-name>          # Port scanning
# - dig <service-name>.default.svc.cluster.local  # Advanced DNS queries
# - tcpdump -i any host <service-ip>   # Packet capture
# - ss -tuln                           # Socket statistics
# - curl -v telnet://<service-name>:80 # Telnet-style connection test
# - traceroute <service-name>          # Network path tracing
# - iftop                              # Network traffic monitoring

# Service mesh debugging (Istio example)
kubectl exec <pod-name> -c istio-proxy -- curl -s localhost:15000/clusters  # Envoy clusters
kubectl exec <pod-name> -c istio-proxy -- curl -s localhost:15000/stats    # Envoy statistics
kubectl logs <pod-name> -c istio-proxy                                      # Sidecar logs

# Network policy testing
kubectl run policy-test-allowed --image=busybox --rm -it --restart=Never --labels="app=allowed" -- wget -qO- http://<service-name>
kubectl run policy-test-denied --image=busybox --rm -it --restart=Never --labels="app=denied" -- timeout 5 wget -qO- http://<service-name> || echo "Blocked by policy"
```

## Resource and Performance Deep Analysis
```bash
# Enhanced resource usage monitoring
kubectl top nodes --sort-by=memory                                         # Node memory usage
kubectl top pods --all-namespaces --sort-by=memory --containers           # Memory usage with containers
kubectl top pods --sort-by=cpu -l app=<name>            # CPU usage for specific app
kubectl top pods --use-protocol-buffers                 # More efficient resource queries

# Node resource analysis and capacity planning
kubectl describe nodes | grep -A 5 "Allocated resources" # Resource allocation per node
kubectl describe node <node-name> | grep -A 10 "Non-terminated Pods"  # Pods consuming node resources
kubectl get pods --all-namespaces -o wide --field-selector spec.nodeName=<node-name>  # All pods on specific node

# Advanced resource metrics collection
kubectl get --raw /api/v1/nodes/<node-name>/proxy/metrics/cadvisor | grep container_cpu_usage_seconds_total  # Raw CPU metrics
kubectl get --raw /api/v1/nodes/<node-name>/proxy/stats/summary  # Node summary statistics
kubectl get --raw /metrics | grep apiserver                      # API server metrics

# Resource constraint analysis
kubectl describe limitrange                               # Resource limit ranges
kubectl describe resourcequota                           # Resource quotas and usage
kubectl get pods -o custom-columns=NAME:.metadata.name,CPU-REQ:.spec.containers[*].resources.requests.cpu,MEM-REQ:.spec.containers[*].resources.requests.memory,CPU-LIM:.spec.containers[*].resources.limits.cpu,MEM-LIM:.spec.containers[*].resources.limits.memory

# Quality of Service (QoS) debugging
kubectl get pods -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass     # Pod QoS classes
kubectl get pods --field-selector=status.qosClass=BestEffort                   # Best effort pods (no resource requests)
kubectl get pods --field-selector=status.qosClass=Guaranteed                   # Guaranteed pods (requests = limits)
kubectl get pods --field-selector=status.qosClass=Burstable                    # Burstable pods (requests < limits)
```

## Event Analysis and System Monitoring
```bash
# Enhanced event analysis and correlation
kubectl get events --sort-by=.lastTimestamp                        # All recent events chronologically
kubectl get events --sort-by=.lastTimestamp --field-selector type=Warning  # Warning events only
kubectl get events --field-selector reason=FailedScheduling         # Scheduling failures
kubectl get events --field-selector reason=Killing                  # Pod termination events
kubectl get events --field-selector involvedObject.kind=Pod         # Pod-specific events

# Advanced event filtering and monitoring
kubectl get events --all-namespaces --field-selector type=Warning --sort-by=.lastTimestamp -o custom-columns=TIME:.lastTimestamp,NAMESPACE:.namespace,REASON:.reason,OBJECT:.involvedObject.name,MESSAGE:.message
kubectl get events --watch --field-selector reason=Failed          # Watch failure events
kubectl get events --since=1h --field-selector type!=Normal        # Non-normal events in last hour

# Event correlation with specific resources
kubectl get events --field-selector involvedObject.name=<pod-name>,reason=Failed  # Specific pod failures
kubectl get events --output json | jq '.items[] | select(.type=="Warning") | {time: .lastTimestamp, reason: .reason, message: .message, object: .involvedObject.name}'  # JSON event processing

# Custom event monitoring scripts
kubectl get events -w --output-watch-events | while read line; do
  echo "$(date): $line"
  # Add custom processing here
done

# System component health monitoring
kubectl get componentstatuses                             # Control plane component health
kubectl get pods -n kube-system                          # System component pods
kubectl get events -n kube-system --sort-by=.lastTimestamp  # System events
```

## Interactive Debugging and Troubleshooting Sessions
```bash
# Enhanced shell access and command execution
kubectl exec -it <pod-name> -- /bin/bash                  # Interactive bash shell
kubectl exec -it <pod-name> -- sh                         # Interactive sh shell (Alpine/minimal images)
kubectl exec -it <pod-name> -- ash                        # Alpine shell specifically
kubectl exec <pod-name> -- ps aux                         # Process list
kubectl exec <pod-name> -- df -h                          # Disk usage
kubectl exec <pod-name> -- netstat -tuln                  # Network connections
kubectl exec <pod-name> -- lsof                           # Open files and network connections

# Multi-container pod debugging
kubectl exec -it <pod-name> -c <container-name> -- /bin/bash      # Specific container shell
kubectl logs <pod-name> -c <container-name> -f                   # Specific container logs
kubectl describe pod <pod-name> | grep -A 5 "Container ID"       # Container runtime details
kubectl exec <pod-name> -c <container-name> -- env               # Container environment variables

# Debug container creation and attachment
kubectl run debug-pod --image=busybox --rm -it --restart=Never -- sh  # Temporary debug pod
kubectl run ubuntu-debug --image=ubuntu --rm -it --restart=Never -- bash  # Full Ubuntu environment
kubectl run network-debug --image=nicolaka/netshoot --rm -it --restart=Never -- bash  # Network debugging toolkit

# Advanced debugging with specific tools
kubectl run curl-debug --image=curlimages/curl --rm -it --restart=Never -- sh  # HTTP testing
kubectl run dns-utils --image=tutum/dnsutils --rm -it --restart=Never -- bash  # DNS debugging tools
kubectl run mysql-client --image=mysql:8.0 --rm -it --restart=Never -- mysql -h <mysql-service> -u root -p  # Database debugging

# File system operations and investigation
kubectl cp <pod-name>:/app/config.yaml ./local-config.yaml       # Copy file from pod
kubectl cp ./debug-script.sh <pod-name>:/tmp/debug.sh           # Copy file to pod
kubectl exec <pod-name> -- find /app -name "*.log" -exec ls -la {} \;  # Find and list log files
kubectl exec <pod-name> -- du -sh /var/log/*                    # Directory sizes
kubectl exec <pod-name> -- tail -f /var/log/application.log     # Follow log files

# Process and performance debugging
kubectl exec <pod-name> -- top -bn1                             # Process snapshot
kubectl exec <pod-name> -- iostat                               # I/O statistics
kubectl exec <pod-name> -- vmstat                               # Virtual memory stats
kubectl exec <pod-name> -- free -h                              # Memory usage
kubectl exec <pod-name> -- lscpu                                # CPU information
```

## Application-Specific Debugging Techniques
```bash
# Java application debugging
kubectl exec <pod-name> -- jstack <java-pid>                    # Java thread dump
kubectl exec <pod-name> -- jmap -dump:format=b,file=/tmp/heap.hprof <java-pid>  # Heap dump
kubectl exec <pod-name> -- jstat -gc <java-pid> 1s              # Garbage collection stats
kubectl cp <pod-name>:/tmp/heap.hprof ./heap.hprof              # Copy heap dump locally

# Node.js application debugging
kubectl exec <pod-name> -- node --inspect-brk=0.0.0.0:9229 app.js  # Enable debugging
kubectl port-forward <pod-name> 9229:9229                       # Forward debug port
kubectl exec <pod-name> -- npm run debug                        # Run debug script

# Python application debugging
kubectl exec <pod-name> -- python -m pdb app.py                 # Python debugger
kubectl exec <pod-name> -- python -c "import pdb; pdb.set_trace()"  # Set breakpoint
kubectl logs <pod-name> | grep -E "(Traceback|Error|Exception)" # Python error patterns

# Database debugging
kubectl exec -it <mysql-pod> -- mysql -u root -p -e "SHOW PROCESSLIST;"  # MySQL processes
kubectl exec -it <postgres-pod> -- psql -U postgres -c "SELECT * FROM pg_stat_activity;"  # PostgreSQL activity
kubectl exec <redis-pod> -- redis-cli monitor                   # Redis command monitoring

# Web server debugging
kubectl exec <nginx-pod> -- nginx -t                            # Nginx configuration test
kubectl exec <apache-pod> -- httpd -t                           # Apache configuration test
kubectl exec <nginx-pod> -- cat /var/log/nginx/error.log        # Nginx error logs
kubectl logs <pod-name> | grep -E "(404|500|502|503)"          # HTTP error codes
```

## Container Image and Registry Debugging
```bash
# Image inspection and analysis
kubectl describe pod <pod-name> | grep -A 5 "Image"             # Current image information
kubectl get pod <pod-name> -o jsonpath='{.spec.containers[*].image}'  # All container images
kubectl get pod <pod-name> -o jsonpath='{.status.containerStatuses[*].imageID}'  # Image IDs

# Pull policy and image issues
kubectl describe pod <pod-name> | grep -A 10 "Events" | grep -i "pull"  # Image pull events
kubectl get events --field-selector reason=Failed,involvedObject.kind=Pod  # Failed pod events
kubectl get events --field-selector reason=ErrImagePull         # Image pull failures

# Registry and authentication debugging
kubectl get secrets -o custom-columns=NAME:.metadata.name,TYPE:.type | grep docker  # Docker registry secrets
kubectl describe secret <registry-secret>                       # Registry authentication details
kubectl create secret docker-registry test-secret --docker-server=registry.example.com --docker-username=user --docker-password=pass --dry-run=client -o yaml  # Test registry secret

# Image security and scanning
kubectl get pod <pod-name> -o custom-columns=NAME:.metadata.name,SECURITY-CONTEXT:.spec.securityContext,USER:.spec.containers[0].securityContext.runAsUser
kubectl describe pod <pod-name> | grep -A 15 "Security Context"  # Security settings
```

## Persistent Volume and Storage Debugging
```bash
# Storage and volume analysis
kubectl get pv,pvc                                              # Persistent volumes and claims
kubectl describe pvc <pvc-name>                                 # PVC details and events
kubectl get pods -o custom-columns=NAME:.metadata.name,VOLUMES:.spec.volumes[*].name,MOUNTS:.spec.containers[*].volumeMounts[*].mountPath
kubectl describe pod <pod-name> | grep -A 10 "Volumes"         # Volume configuration

# Storage capacity and usage
kubectl exec <pod-name> -- df -h                               # Disk usage inside container
kubectl exec <pod-name> -- du -sh /data/*                      # Directory sizes
kubectl get pv -o custom-columns=NAME:.metadata.name,CAPACITY:.spec.capacity.storage,STATUS:.status.phase,CLAIM:.spec.claimRef.name

# Storage class and provisioning issues
kubectl get storageclass                                        # Available storage classes
kubectl describe storageclass <sc-name>                         # Storage class details
kubectl get events --field-selector reason=ProvisioningFailed   # Storage provisioning failures
```

## Emergency Response and Recovery Procedures
```bash
# Immediate cluster health assessment
kubectl get nodes --no-headers | grep -v Ready | wc -l         # Count non-ready nodes
kubectl get pods --all-namespaces --field-selector=status.phase=Failed | wc -l  # Count failed pods
kubectl get events --field-selector type=Warning --since=10m | wc -l  # Recent warnings

# Quick resource pressure check
kubectl top nodes --sort-by=memory | head -5                   # Top memory consumers
kubectl top pods --all-namespaces --sort-by=memory | head -10  # Memory-hungry pods
kubectl describe nodes | grep -A 5 "Resource Pressure"         # Node pressure conditions

# Emergency pod restart and recovery
kubectl rollout restart deployment/<deployment-name>            # Restart deployment pods
kubectl delete pod <pod-name> --grace-period=0 --force         # Force delete stuck pod
kubectl scale deployment <deployment-name> --replicas=0         # Scale down
kubectl scale deployment <deployment-name> --replicas=3         # Scale back up

# System component health check
kubectl get componentstatuses                                   # Control plane health
kubectl get pods -n kube-system --field-selector=status.phase!=Running  # Unhealthy system pods
kubectl get events -n kube-system --field-selector type=Warning --since=30m  # System warnings

# Cluster connectivity and API health
kubectl cluster-info                                           # Basic cluster info
kubectl get --raw /healthz                                     # API server health
kubectl get --raw /readyz                                      # API server readiness
kubectl auth can-i '*' '*' --all-namespaces                   # Verify admin access
```