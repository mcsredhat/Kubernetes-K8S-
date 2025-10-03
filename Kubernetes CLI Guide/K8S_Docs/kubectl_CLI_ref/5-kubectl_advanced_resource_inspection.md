# Advanced Resource Inspection

Master these advanced querying techniques to extract precise information efficiently. These skills are essential for automation, monitoring, and troubleshooting in production environments.

## Custom Output Formats and Column Definitions
```bash
# Pod-focused custom columns
kubectl get pods -n dev -o custom-columns=\
NAME:.metadata.name,\
STATUS:.status.phase,\
NODE:.spec.nodeName,\
IP:.status.podIP,\
PORTS:.spec.containers[*].ports[*].containerPort

# Deployment analysis with detailed information
 kubectl get deployments -n dev -o custom-columns=NAME:.metadata.name,REPLICAS-lastUpdateTime:.status.conditions[*].lastUpdateTime,REPLICAS-NUM:.spec.replicas,STRATEGY:.spec.strategy.type,IMAGE:.spec.template.spec.containe
rs[0].image,CREATED:.metadata.creationTimestamp

# Node comprehensive information
kubectl get nodes -o custom-columns=\
NAME:.metadata.name,\
STATUS:.status.conditions[?(@.type==\"Ready\")].status,\
VERSION:.status.nodeInfo.kubeletVersion,\
OS:.status.nodeInfo.osImage,\
ARCH:.status.nodeInfo.architecture,\
KERNEL:.status.nodeInfo.kernelVersion

# Service details with endpoint information
kubectl get services -o custom-columns=NAME:.metadata.name,TYPE:.spec.type,CLUSTER-IP:.spec.clusterIP,EXTERNAL-IP:.status.loadBalancer.ingress[0].ip,PORTS:.spec.ports[*].port,TARGETPORT:.spec.ports[*].targetPort

# Custom column files for reusable templates
# Create pod-columns.txt:
echo "NAME:.metadata.name
READY:.status.containerStatuses[*].ready
RESTARTS:.status.containerStatuses[*].restartCount
NODE:.spec.nodeName
AGE:.metadata.creationTimestamp" > pod-columns.txt

kubectl get pods -o custom-columns-file=pod-columns.txt
```

## JSONPath Advanced Queries and Data Extraction
```bash
# Basic resource extraction
kubectl get pods -n dev -o jsonpath='{.items[*].metadata.name}'                  # All pod names
kubectl get pods -n dev -o jsonpath='{.items[*].status.podIP}'                  # All pod IPs
kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}'  # Node internal IPs
kubectl get deployments -o jsonpath='{.items[*].spec.replicas}'              # Desired replicas

# Complex data relationships with ranges
kubectl get pods -n dev -o jsonpath='{range .items[*]}{.metadata.name}{" => "}{.spec.nodeName}{"\n"}{end}'  # Pod to node mapping
kubectl get pods -n dev -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.spec.containers[*].image}{"\n"}{end}'  # Pod images
kubectl get services -o jsonpath='{range .items[*]}{.metadata.name}{" => "}{.spec.ports[*].port}{"\n"}{end}'  # Service ports

# Advanced JSONPath with conditional expressions
kubectl get pods -n dev -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}'  # Only running pods
kubectl get nodes -o jsonpath='{.items[?(@.status.conditions[0].status=="True")].metadata.name}'  # Ready nodes
kubectl get services -o jsonpath='{.items[?(@.spec.type=="LoadBalancer")].metadata.name}'  # LoadBalancer services

# Resource status and metrics analysis
kubectl get pods -n dev -o jsonpath='{range .items[*]}{.metadata.name}{" => Ready: "}{.status.containerStatuses[*].ready}{", Restarts: "}{.status.containerStatuses[*].restartCount}{"\n"}{end}'
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{": CPU="}{.status.capacity.cpu}{", Memory="}{.status.capacity.memory}{"\n"}{end}'

# Complex nested data extraction
kubectl get pods -n dev -o jsonpath='{range .items[*]}{.metadata.name}{": "}{range .spec.containers[*]}{.name}={.image}{" "}{end}{"\n"}{end}'  # Container details
kubectl get deployments -o jsonpath='{range .items[*]}{.metadata.name}{": replicas="}{.spec.replicas}{", ready="}{.status.readyReplicas}{", strategy="}{.spec.strategy.type}{"\n"}{end}'
```

## Go Template Output Format for Complex Formatting
```bash
# Basic Go template patterns
kubectl get pods -n dev -o go-template='{{range .items}}{{.metadata.name}}{{"\t"}}{{.status.phase}}{{"\t"}}{{.spec.nodeName}}{{"\n"}}{{end}}'
kubectl get pods -n dev -o go-template='{{range .items}}{{if eq .status.phase "Running"}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}'  # Only running pods

# Conditional formatting with Go templates
kubectl get pods -n dev -o go-template='{{range .items}}{{.metadata.name}}: {{if .status.containerStatuses}}{{range .status.containerStatuses}}{{if .ready}}READY{{else}}NOT READY{{end}} {{end}}{{end}}{{"\n"}}{{end}}'

# Advanced Go template with functions
kubectl get nodes -o go-template='{{range .items}}{{.metadata.name}}: {{range .status.conditions}}{{if eq .type "Ready"}}{{.status}}{{end}}{{end}}{{"\n"}}{{end}}'
kubectl get services -o go-template='{{range .items}}{{.metadata.name}}: {{if .spec.ports}}{{range .spec.ports}}{{.port}}:{{.targetPort}} {{end}}{{end}}{{"\n"}}{{end}}'

# Table formatting with Go templates
kubectl get pods -n dev -o go-template='{{printf "%-30s %-10s %-15s\n" "NAME" "STATUS" "NODE"}}{{range .items}}{{printf "%-30s %-10s %-15s\n" .metadata.name .status.phase .spec.nodeName}}{{end}}'

# Go template files for complex reusable formats
# Create deployment-status.gotemplate:
echo '{{range .items}}
Deployment: {{.metadata.name}}
  Replicas: {{.status.replicas}}/{{.spec.replicas}}
  Strategy: {{.spec.strategy.type}}
  Image: {{range .spec.template.spec.containers}}{{.image}} {{end}}
  Ready: {{if .status.conditions}}{{range .status.conditions}}{{if eq .type "Available"}}{{.status}}{{end}}{{end}}{{end}}
---
{{end}}' > deployment-status.gotemplate

kubectl get deployments -n dev -o go-template-file=deployment-status.gotemplate
```

## Advanced Filtering and Sorting Techniques
```bash
# Multiple field selector combinations
kubectl get pods -n dev --field-selector=status.phase=Running,spec.nodeName=worker-1     # Multiple field conditions
kubectl get events --field-selector=type=Warning,reason=FailedScheduling          # Warning events with specific reason
kubectl get pods -n dev --field-selector=metadata.namespace!=kube-system                 # Exclude system pods
kubectl get services -n dev --field-selector=spec.type!=ClusterIP                        # Non-ClusterIP services

# Complex label selector patterns
kubectl get pods -l 'environment in (production,staging),tier=frontend'           # Multiple conditions
kubectl get pods -l 'environment,tier notin (database,cache)'                     # Exclude specific values
kubectl get pods -l 'version=v1.0' --field-selector=status.phase=Running         # Combine label and field selectors
kubectl get pods -l 'app' --field-selector=status.phase!=Succeeded                # Has label, not succeeded

# Advanced sorting with multiple criteria
kubectl get pods --sort-by=.metadata.creationTimestamp                           # Sort by creation time
kubectl get pods --sort-by=.status.startTime                                     # Sort by start time  
kubectl get events --sort-by=.lastTimestamp                                      # Sort events chronologically
kubectl get nodes --sort-by=.metadata.name                                       # Alphabetical sorting
kubectl get pods --sort-by=.spec.nodeName                                        # Sort by node assignment

# Combination queries for complex analysis
kubectl get pods --all-namespaces --field-selector=status.phase=Running --sort-by=.spec.nodeName -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,NODE:.spec.nodeName
kubectl get events --all-namespaces --field-selector=type=Warning --sort-by=.lastTimestamp -o custom-columns=TIME:.lastTimestamp,NAMESPACE:.namespace,REASON:.reason,MESSAGE:.message
```

## Resource Relationships and Dependencies Analysis
```bash
# Ownership and hierarchical relationships
kubectl get pods -n dev -o custom-columns=\
NAME:.metadata.name,\
OWNER:.metadata.ownerReferences[0].name,\
OWNER-KIND:.metadata.ownerReferences[0].kind,\
CONTROLLED-BY:.metadata.ownerReferences[0].controller

# Resource hierarchy visualization
kubectl get all -l app=<n>        # All resources with label
kubectl get -n dev all -l app=webapp
kubectl get deployment,replicaset,pods -l app=<n>    # Deployment hierarchy
kubectl get deployment,replicaset,pods -n dev -l app=webapp
kubectl get pods,services,endpoints -l app=<n>                # Service relationships
kubectl get pods,services,endpoints -n dev -l app=webapp
#####

kubectl krew install tree
kubectl tree deployment <deployment-name>                        # Hierarchical view (requires kubectl-tree plugin)
kubectl tree deployment wb -n dev
# Dependency mapping and analysis
kubectl get pods -n dev -o jsonpath='{range .items[*]}{.metadata.name}{": owned by "}{.metadata.ownerReferences[0].kind}{"/"}{.metadata.ownerReferences[0].name}{"\n"}{end}'
kubectl get services -o custom-columns=NAME:.metadata.name,SELECTOR:.spec.selector,ENDPOINTS:.status.loadBalancer.ingress[*].ip

# Event correlation and debugging
kubectl get events --field-selector involvedObject.name=<resource-name>          # Events for specific resource
kubectl get events --field-selector involvedObject.kind=Pod -n dev                    # Pod-related events
kubectl get events --watch --field-selector involvedObject.name=<pod-name>       # Live events for resource
 kubectl get events --watch --field-selector involvedObject.name=webapp-6d65579cd7-zhmpr -n dev 

kubectl get events --all-namespaces --field-selector reason=FailedScheduling -o custom-columns=TIME:.lastTimestamp,NAMESPACE:.namespace,POD:.involvedObject.name,MESSAGE:.message

# Cross-resource analysis
kubectl get pods,svc -A -o json | jq -r '.items | sort_by(.metadata.namespace)[] | [.metadata.namespace, .kind, .metadata.name] | @tsv'  # Multiple resource types sorted
kubectl get configmaps,secrets -n dev -l app=webapp -o custom-columns=KIND:.kind,NAME:.metadata.
name,NAMESPACE:.metadata.namespace
```

## Advanced Output Processing with External Tools
```bash
# JSON processing with jq for complex queries
kubectl get pods -n dev -o json | jq '.items[] | select(.status.phase=="Running") | .metadata.name'
kubectl get nodes -o json | jq '.items[] | {name: .metadata.name, capacity: .status.capacity, allocatable: .status.allocatable}'
kubectl get services -o json | jq '.items[] | select(.spec.type=="LoadBalancer") | {name: .metadata.name, external_ip: .status.loadBalancer.ingress[].ip}'

# CSV generation for spreadsheet analysis
kubectl get pods -n dev -o json | jq -r '["NAME","NAMESPACE","STATUS","NODE","IP"], (.items[] | [.metadata.name, .metadata.namespace, .status.phase, .spec.nodeName, .status.podIP]) | @csv'

# YAML processing with yq (if available)
kubectl get deployments -n dev -o yaml | yq '.items[] | select(.spec.replicas > 3) | .metadata.name'
kubectl get configmaps -o yaml | yq '.items[] | .data | keys'

# Advanced text processing combinations
kubectl get events --sort-by=.lastTimestamp -o custom-columns=TIME:.lastTimestamp,TYPE:.type,REASON:.reason,MESSAGE:.message | grep -E "(Warning|Error)" | tail -20
kubectl get pods -n dev -o custom-columns=NAME:.metadata.name,CPU-REQ:.spec.containers[0].resources.requests.cpu,MEM-REQ:.spec.containers[0].resources.requests.memory | column -t
```

## Real-time Monitoring and Watch Operations
```bash
# Advanced watch operations
kubectl get pods -n dev -w -o custom-columns=TIME:..metadata.creationTimestamp,NAME:.metadata.name,STATUS:.status.phase   # Custom watch format
kubectl get events --watch --output-watch-events                          # Detailed watch events
kubectl get all --watch-only -l app=<app-name>                           # Watch specific application resources

# Watch with filtering and processing
kubectl get pods -n dev -w | grep -E "(Running|Error|CrashLoopBackOff)"         # Filter watch output
kubectl get events -w --field-selector type=Warning                       # Watch only warnings
kubectl get nodes -w -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[?(@.type==\"Ready\")].status  # Watch node status

# Monitoring scripts and automation
# Create a monitoring script:
echo '#!/bin/bash
while true; do
  echo "=== $(date) ==="
  kubectl get pods --field-selector=status.phase!=Running
  kubectl get events --field-selector type=Warning --since=1m
  sleep 30
done' > monitor-cluster.sh
chmod +x monitor-cluster.sh
```

## Performance Optimization for Large Clusters
```bash
# Efficient queries for large clusters
kubectl get pods --chunk-size=500                                        # Process in chunks
kubectl get events --limit=100 --sort-by=.lastTimestamp                 # Limit results
kubectl get pods --field-selector=status.phase=Running --no-headers | wc -l  # Count without formatting

# Selective namespace queries
kubectl get pods -A --field-selector=metadata.namespace=production       # Single namespace across all
kubectl get all -n production,staging --dry-run=client                   # Multiple specific namespaces

# Optimized output for scripts
kubectl get pods -n dev --no-headers -o custom-columns=NAME:.metadata.name      # Headers disabled for parsing
kubectl get nodes --no-headers -o jsonpath='{.items[*].metadata.name}'   # Space-separated output
kubectl get services --output=name | cut -d/ -f2                         # Extract names only
```