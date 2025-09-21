# Service Discovery and Networking

Services provide stable networking endpoints for pods and enable service discovery. Understanding these concepts is crucial for building resilient distributed applications.

## Service Management and Creation
```bash
# Service creation methods
kubectl expose deployment <name> --port=80 --target-port=8080    # Expose deployment
kubectl expose pod <pod-name> --port=80 --type=NodePort         # Expose pod with NodePort
kubectl create service clusterip <name> --tcp=80:8080           # Create ClusterIP service
kubectl create service nodeport <name> --tcp=80:8080            # Create NodePort service
kubectl create service loadbalancer <name> --tcp=80:8080        # Create LoadBalancer service
kubectl create service externalname <name> --external-name=external.example.com  # ExternalName service

# Advanced service creation with selectors
kubectl create service clusterip my-service --tcp=80:8080 --dry-run=client -o yaml > service.yaml
# Then edit service.yaml to add selector: app: my-app

# Service inspection and management
kubectl get services                                   # List all services
kubectl get services -o wide                          # Extended service information
kubectl get svc                                       # Shorthand for services
kubectl describe service <name>                       # Detailed service information
kubectl get endpoints                                 # List service endpoints
kubectl get endpoints <service-name>                  # Specific service endpoints

# Service modification and patching
kubectl patch service <name> -p '{"spec":{"type":"NodePort"}}'  # Change service type
kubectl patch service <name> -p '{"spec":{"ports":[{"port":8080,"targetPort":80}]}}'  # Update ports
kubectl annotate service <name> service.beta.kubernetes.io/aws-load-balancer-type=nlb  # Cloud provider annotations
```

## Service Types and Configuration Analysis
```bash
# Service type analysis
kubectl get services -o custom-columns=NAME:.metadata.name,TYPE:.spec.type,CLUSTER-IP:.spec.clusterIP,EXTERNAL-IP:.status.loadBalancer.ingress[0].ip,PORT:.spec.ports[0].port
kubectl get services --field-selector spec.type=LoadBalancer      # Only LoadBalancer services
kubectl get services --field-selector spec.type=NodePort         # Only NodePort services

# Port configuration analysis
kubectl get services -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.spec.ports[*].port}{":"}{.spec.ports[*].targetPort}{" => "}{.spec.ports[*].nodePort}{"\n"}{end}'
kubectl describe service <name> | grep -A 5 "Port"               # Port details

# Selector and endpoint analysis  
kubectl get service <name> -o jsonpath='{.spec.selector}'        # Service selector
kubectl get endpoints <service-name> -o jsonpath='{.subsets[*].addresses[*].ip}'  # Endpoint IPs
kubectl get endpoints <service-name> -o custom-columns=ENDPOINTS:.subsets[*].addresses[*].ip,PORTS:.subsets[*].ports[*].port
```

## Network Debugging and Connectivity Testing
```bash
# DNS resolution testing
kubectl run dns-debug --image=busybox --rm -it --restart=Never -- nslookup kubernetes.default      # DNS resolution test
kubectl run dns-debug --image=busybox --rm -it --restart=Never -- nslookup <service-name>.<namespace>.svc.cluster.local
kubectl exec -it <pod-name> -- cat /etc/resolv.conf             # DNS configuration in pod
kubectl exec -it <pod-name> -- nslookup <service-name>          # DNS from within pod

# Network connectivity testing
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- curl -v http://<service-name>
kubectl run wget-test --image=busybox --rm -it --restart=Never -- wget -qO- http://<service-name>
kubectl run network-debug --image=nicolaka/netshoot --rm -it --restart=Never -- /bin/bash          # Full network toolkit

# Advanced network debugging with netshoot
# Inside netshoot container, you can use:
# - nmap -p 80 <service-name>          # Port scanning
# - dig <service-name>.default.svc.cluster.local  # Advanced DNS queries
# - tcpdump -i any host <service-ip>   # Packet capture
# - ss -tuln                           # Socket statistics
# - curl -v telnet://<service-name>:80 # Telnet-style connection test

# Service connectivity verification from pods
kubectl run test-pod --image=busybox --rm -it --restart=Never -- wget -qO- http://<service-name>   # Test service connectivity
kubectl exec -it <pod-name> -- nslookup <service-name>.<namespace>.svc.cluster.local  # DNS resolution from pod
kubectl port-forward service/<service-name> 8080:80                                # Port forward for local testing

# Cross-namespace service testing
kubectl run test-pod --image=busybox --rm -it --restart=Never -- nslookup <service-name>.<target-namespace>.svc.cluster.local
kubectl run test-pod --image=busybox --rm -it --restart=Never -- wget -qO- http://<service-name>.<target-namespace>.svc.cluster.local

# Network policy testing and verification
kubectl get networkpolicies                           # List network policies
kubectl describe networkpolicy <policy-name>          # Network policy details
kubectl get pods --show-labels | grep <policy-selector>  # Pods affected by network policy

# Test network policy effectiveness
kubectl run policy-test --image=busybox --rm -it --restart=Never --labels="app=test" -- wget -qO- http://<service-name>  # Test with specific labels
kubectl exec -it <pod-name> -- timeout 5 wget -qO- http://<blocked-service> || echo "Connection blocked by policy"  # Policy validation
```

## Ingress and External Access Management
```bash
# Ingress resource management
kubectl get ingress                                   # List ingress resources
kubectl get ingress -o wide                          # Extended ingress information
kubectl get ing                                      # Shorthand for ingress
kubectl describe ingress <name>                      # Detailed ingress information
kubectl create ingress <name> --rule="host/path=service:port"  # Create simple ingress

# Advanced ingress creation
kubectl create ingress web-ingress \
  --rule="example.com/api/*=api-service:80" \
  --rule="example.com/*=web-service:80" \
  --annotation="nginx.ingress.kubernetes.io/rewrite-target=/"

# Ingress debugging and analysis
kubectl get ingress <name> -o yaml                   # Full ingress specification
kubectl get events --field-selector involvedObject.name=<ingress-name>  # Ingress-related events
kubectl get ingress -o custom-columns=NAME:.metadata.name,HOSTS:.spec.rules[*].host,PATHS:.spec.rules[*].http.paths[*].path,SERVICES:.spec.rules[*].http.paths[*].backend.service.name

# TLS and certificate analysis
kubectl get ingress <name> -o jsonpath='{.spec.tls[*].secretName}'  # TLS secret names
kubectl get secret <tls-secret-name> -o yaml | grep -A 10 "tls.crt"  # Certificate data
kubectl describe secret <tls-secret-name>                            # Certificate details

# Ingress controller debugging
kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx  # Nginx ingress controller pods
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx -f   # Ingress controller logs
kubectl get events -n ingress-nginx --sort-by=.lastTimestamp               # Ingress controller events
```

## Load Balancer and External Service Management
```bash
# LoadBalancer service analysis
kubectl get services --field-selector spec.type=LoadBalancer -o wide       # All LoadBalancer services
kubectl describe service <lb-service-name> | grep -A 5 "LoadBalancer"     # LoadBalancer details
kubectl get service <lb-service-name> -o jsonpath='{.status.loadBalancer.ingress[*].ip}'  # External IPs

# Cloud provider integration
kubectl annotate service <name> service.beta.kubernetes.io/aws-load-balancer-type=nlb             # AWS Network Load Balancer
kubectl annotate service <name> service.beta.kubernetes.io/aws-load-balancer-internal=true        # Internal load balancer
kubectl annotate service <name> cloud.google.com/load-balancer-type=Internal                      # GCP internal LB
kubectl annotate service <name> service.beta.kubernetes.io/azure-load-balancer-internal=true      # Azure internal LB

# External service monitoring
kubectl get service <external-service> -o custom-columns=NAME:.metadata.name,EXTERNAL-NAME:.spec.externalName,TYPE:.spec.type
kubectl run external-test --image=busybox --rm -it --restart=Never -- nslookup <external-service-name>  # Test external service resolution
```

## Advanced Networking and Service Mesh Integration
```bash
# Service mesh sidecar inspection (Istio example)
kubectl get pods -o custom-columns=NAME:.metadata.name,CONTAINERS:.spec.containers[*].name | grep istio-proxy  # Istio sidecar containers
kubectl logs <pod-name> -c istio-proxy                                     # Istio sidecar logs
kubectl describe pod <pod-name> | grep -A 5 -B 5 "istio-proxy"           # Sidecar configuration

# Traffic policy and routing analysis
kubectl get virtualservices                          # Istio virtual services (if using Istio)
kubectl get destinationrules                         # Istio destination rules
kubectl describe virtualservice <vs-name>            # Virtual service routing rules

# Multi-cluster and federation
kubectl get services --all-namespaces -o custom-columns=NAME:.metadata.name,NAMESPACE:.metadata.namespace,TYPE:.spec.type,CLUSTER-IP:.spec.clusterIP
kubectl config get-contexts                          # Available clusters for multi-cluster services
```

## Port Forwarding and Local Development
```bash
# Basic port forwarding
kubectl port-forward pod/<pod-name> 8080:80               # Forward pod port to local
kubectl port-forward deployment/<name> 8080:80            # Forward deployment port
kubectl port-forward service/<service-name> 8080:80       # Forward service port

# Advanced port forwarding scenarios
kubectl port-forward <pod-name> 8080:80 --address 0.0.0.0       # Bind to all interfaces
kubectl port-forward service/<name> 8080:80 9090:9090           # Multiple port forwards
kubectl port-forward pod/<pod-name> :80                         # Random local port
kubectl port-forward service/<name> 8080:80 --namespace=<ns>    # Cross-namespace forwarding

# Background port forwarding
kubectl port-forward service/<name> 8080:80 > /dev/null 2>&1 &  # Background process
echo $! > port-forward.pid                                      # Save PID for cleanup
kill $(cat port-forward.pid)                                    # Cleanup port forward

# Port forwarding for debugging
kubectl port-forward deployment/webapp 8080:80 & KUBECTL_PID=$!  # Start with PID tracking
curl http://localhost:8080/health                               # Test local access
kill $KUBECTL_PID                                              # Clean up
```
