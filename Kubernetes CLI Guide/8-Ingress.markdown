# Complete Kubernetes Ingress Guide

## Understanding Ingress: The Gateway to Your Applications

Think of Kubernetes Ingress as the sophisticated front door to your cluster's services. While Services handle internal communication between pods, Ingress manages how external traffic enters your cluster and gets routed to the right destinations. It's like having a smart receptionist who not only knows where everyone sits but can also handle security, speak multiple languages (protocols), and even redirect visitors to the right building wing based on what they're looking for.

The beauty of Ingress lies in its ability to consolidate multiple routing rules into a single entry point, eliminating the need for multiple LoadBalancer services (which can be expensive in cloud environments) or NodePort services (which expose random high-numbered ports).

## The Ingress Ecosystem: Controllers, Resources, and Classes

Before diving into creating Ingress resources, it's crucial to understand the three-part ecosystem that makes HTTP routing work in Kubernetes.

### Ingress Controllers: The Traffic Directors

An Ingress Controller is the actual software component that processes Ingress rules and handles the HTTP traffic. Think of it as the engine that makes your routing rules come to life. Popular choices include NGINX Ingress Controller, Traefik, HAProxy, and cloud-provider specific controllers like AWS ALB or Google Cloud Load Balancer.

The controller continuously watches for Ingress resources in your cluster and automatically configures itself to route traffic according to your specifications. When you create or modify an Ingress resource, the controller detects this change and updates its routing configuration in real-time.

### Ingress Resources: The Routing Blueprints

Ingress resources are Kubernetes API objects that define your routing rules. They're declarative specifications that tell the Ingress Controller how to route incoming requests. These resources contain the mapping between external URLs and internal services, along with additional configuration like TLS settings and custom annotations.

### Ingress Classes: The Configuration Profiles

Ingress Classes allow you to have multiple Ingress Controllers in the same cluster, each handling different types of traffic or serving different purposes. This is particularly useful in complex environments where you might want different controllers for internal versus external traffic, or for different teams within your organization.

## Setting Up Your First Ingress Controller

Let's start by installing an NGINX Ingress Controller, which is one of the most popular and feature-rich options available.

```bash
# For minikube users - this enables the built-in NGINX addon
minikube addons enable ingress

# For production clusters, install the official NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

# Wait for the controller pods to be ready - this ensures everything is properly initialized
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

# Verify the controller is running and check its configuration
kubectl get pods -n ingress-nginx
kubectl get services -n ingress-nginx
```

The installation creates a new namespace called `ingress-nginx` and deploys the controller along with associated services. The controller will watch for Ingress resources across all namespaces by default.

## Your First Ingress: Basic HTTP Routing

Let's create a simple web application and expose it through Ingress to understand the fundamental concepts.

```yaml
# basic-web-app.yaml
# First, we create a simple web application deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-world
  labels:
    app: hello-world
spec:
  replicas: 3  # Multiple replicas for high availability
  selector:
    matchLabels:
      app: hello-world
  template:
    metadata:
      labels:
        app: hello-world
    spec:
      containers:
      - name: hello-world
        image: nginx:alpine
        ports:
        - containerPort: 80  # The port our application listens on
        # Let's customize the nginx welcome page to make testing easier
        volumeMounts:
        - name: custom-content
          mountPath: /usr/share/nginx/html
      volumes:
      - name: custom-content
        configMap:
          name: hello-world-content
---
# Create custom content to make our application identifiable
apiVersion: v1
kind: ConfigMap
metadata:
  name: hello-world-content
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>Hello World Application</title></head>
    <body>
        <h1>Welcome to our Hello World App!</h1>
        <p>This request was served by pod: <strong>$HOSTNAME</strong></p>
        <p>Time: <span id="time"></span></p>
        <script>
            document.getElementById('time').textContent = new Date().toLocaleString();
        </script>
    </body>
    </html>
---
# The Service acts as a stable network endpoint for our pods
apiVersion: v1
kind: Service
metadata:
  name: hello-world-service
spec:
  selector:
    app: hello-world  # This selector matches our deployment's pod labels
  ports:
  - port: 80          # The port the service exposes
    targetPort: 80    # The port on the pod to forward traffic to
  type: ClusterIP     # Internal service type - only accessible within cluster
---
# Now the Ingress resource that makes our service accessible from outside
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-world-ingress
  annotations:
    # These annotations configure the NGINX controller's behavior
    nginx.ingress.kubernetes.io/rewrite-target: /
    # Add custom headers to help with debugging
    nginx.ingress.kubernetes.io/configuration-snippet: |
      add_header X-Served-By $hostname;
spec:
  # Specify which Ingress Controller should handle this resource
  ingressClassName: nginx
  rules:
  - host: hello-world.local  # The domain name for our application
    http:
      paths:
      - path: /              # Match all paths starting with /
        pathType: Prefix     # How to interpret the path (Prefix, Exact, or ImplementationSpecific)
        backend:
          service:
            name: hello-world-service  # Must match the service name above
            port:
              number: 80               # Must match the service port
```

```bash
# Deploy our complete application stack
kubectl apply -f basic-web-app.yaml

# Check that everything was created successfully
kubectl get deployments,services,ingress,configmaps

# Monitor the deployment rollout
kubectl rollout status deployment/hello-world

# Get the external IP address assigned to our Ingress
kubectl get ingress hello-world-ingress
```

To test this setup, you'll need to add an entry to your `/etc/hosts` file (or Windows equivalent) that maps `hello-world.local` to your Ingress Controller's external IP address. This simulates DNS resolution for our custom domain.

## Understanding Path Types and Routing Behavior

The `pathType` field in Ingress resources controls how the path matching works, and understanding these options is crucial for designing effective routing rules.

### Prefix Path Type
When you specify `pathType: Prefix`, the Ingress Controller matches any request where the URL path starts with the specified prefix. For example, a path of `/api` would match `/api`, `/api/users`, `/api/v1/health`, and so on. This is the most commonly used path type for microservices architectures where you want to route entire API sections to specific services.

### Exact Path Type
The `pathType: Exact` option requires the URL path to match exactly. A path of `/health` would only match requests to `/health` and not `/health/status` or `/health/`. This is useful for specific endpoints like health checks or webhooks where you need precise control.

### ImplementationSpecific Path Type
This option delegates the path matching behavior to the specific Ingress Controller implementation. Different controllers may interpret this differently, so it's generally better to use Prefix or Exact for portability.

## Advanced Routing: Multiple Applications and Path-Based Delegation

Real-world applications often consist of multiple microservices that need to be accessible through different URL paths. Let's create a more complex example that demonstrates advanced routing patterns.

```yaml
# microservices-ingress.yaml
# Frontend application deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
      tier: web
  template:
    metadata:
      labels:
        app: frontend
        tier: web
    spec:
      containers:
      - name: frontend
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: frontend-content
          mountPath: /usr/share/nginx/html
      volumes:
      - name: frontend-content
        configMap:
          name: frontend-content
---
# API backend deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-backend
spec:
  replicas: 3  # More replicas for the API layer
  selector:
    matchLabels:
      app: api
      tier: backend
  template:
    metadata:
      labels:
        app: api
        tier: backend
    spec:
      containers:
      - name: api
        image: httpd:alpine  # Using Apache as a different web server for distinction
        ports:
        - containerPort: 80
        volumeMounts:
        - name: api-content
          mountPath: /usr/local/apache2/htdocs
      volumes:
      - name: api-content
        configMap:
          name: api-content
---
# Admin interface deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: admin-interface
spec:
  replicas: 1  # Single replica for admin interface
  selector:
    matchLabels:
      app: admin
      tier: management
  template:
    metadata:
      labels:
        app: admin
        tier: management
    spec:
      containers:
      - name: admin
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: admin-content
          mountPath: /usr/share/nginx/html
      volumes:
      - name: admin-content
        configMap:
          name: admin-content
---
# ConfigMaps with different content for each service
apiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-content
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>Frontend Application</title></head>
    <body style="font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px;">
        <h1>🌐 Frontend Application</h1>
        <p>This is the main user interface served from <strong>$HOSTNAME</strong></p>
        <nav>
            <a href="/api/" style="margin-right: 10px;">API Documentation</a>
            <a href="/admin/" style="margin-right: 10px;">Admin Panel</a>
        </nav>
        <div style="margin-top: 20px; padding: 10px; background: #f0f0f0;">
            <p>Current time: <span id="time"></span></p>
        </div>
        <script>
            document.getElementById('time').textContent = new Date().toLocaleString();
        </script>
    </body>
    </html>
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: api-content
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>API Backend</title></head>
    <body style="font-family: monospace; max-width: 800px; margin: 0 auto; padding: 20px;">
        <h1>🔧 API Backend Service</h1>
        <p>RESTful API endpoint served from <strong>$HOSTNAME</strong></p>
        <div style="background: #e8f4f8; padding: 10px; margin: 10px 0;">
            <h3>Available Endpoints:</h3>
            <ul>
                <li>GET /api/users - List all users</li>
                <li>GET /api/health - Health check</li>
                <li>POST /api/data - Submit data</li>
            </ul>
        </div>
        <p><a href="/">← Back to Frontend</a></p>
    </body>
    </html>
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: admin-content
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>Admin Interface</title></head>
    <body style="font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; background: #fff8e1;">
        <h1>⚙️ Admin Interface</h1>
        <p>Administrative dashboard served from <strong>$HOSTNAME</strong></p>
        <div style="background: #ffecb3; padding: 10px; margin: 10px 0; border-left: 4px solid #ffa000;">
            <h3>⚠️ Restricted Access</h3>
            <p>This area is for authorized administrators only.</p>
        </div>
        <div style="margin-top: 20px;">
            <h3>System Status</h3>
            <p>All services operational ✅</p>
        </div>
        <p><a href="/">← Back to Frontend</a></p>
    </body>
    </html>
---
# Services for each application
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
spec:
  selector:
    app: frontend
    tier: web
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: api-service
spec:
  selector:
    app: api
    tier: backend
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: admin-service
spec:
  selector:
    app: admin
    tier: management
  ports:
  - port: 80
    targetPort: 80
---
# Advanced Ingress with multiple path-based routing rules
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: microservices-ingress
  annotations:
    # Global configurations that apply to all paths
    nginx.ingress.kubernetes.io/use-regex: "true"
    # Add security headers
    nginx.ingress.kubernetes.io/server-snippet: |
      add_header X-Frame-Options "SAMEORIGIN" always;
      add_header X-Content-Type-Options "nosniff" always;
      add_header X-XSS-Protection "1; mode=block" always;
    # Custom error pages
    nginx.ingress.kubernetes.io/custom-http-errors: "404,503"
spec:
  ingressClassName: nginx
  rules:
  - host: myapp.company.com  # Production-like domain name
    http:
      paths:
      # Frontend gets the root path and any unmatched paths
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-service
            port:
              number: 80
      # API paths go to the backend service
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 80
      # Admin interface requires exact path matching for security
      - path: /admin
        pathType: Prefix
        backend:
          service:
            name: admin-service
            port:
              number: 80
```

This configuration demonstrates several important concepts. The order of path rules matters - more specific paths should come before more general ones. The frontend service gets the root path `/` with a `Prefix` match, which means it will handle any request that doesn't match the more specific `/api` or `/admin` paths.

```bash
# Deploy the microservices architecture
kubectl apply -f microservices-ingress.yaml

# Wait for all deployments to be ready
kubectl wait --for=condition=available --timeout=300s deployment/frontend-app
kubectl wait --for=condition=available --timeout=300s deployment/api-backend
kubectl wait --for=condition=available --timeout=300s deployment/admin-interface

# Check the status of our Ingress
kubectl describe ingress microservices-ingress

# Test the different paths (after adding myapp.company.com to /etc/hosts)
curl http://myapp.company.com/
curl http://myapp.company.com/api/
curl http://myapp.company.com/admin/
```

## HTTPS and TLS: Securing Your Applications

In production environments, HTTPS is not optional. Let's explore how to implement TLS termination with Ingress, covering both self-signed certificates for development and proper certificate management for production.

### Understanding TLS Termination

TLS termination means that the Ingress Controller handles the SSL/TLS encryption and decryption process. External clients connect to the Ingress Controller using HTTPS, but the communication between the Ingress Controller and your backend services happens over HTTP within the cluster's secure network.

This approach offers several advantages: it centralizes certificate management, reduces the computational load on your application pods, and simplifies certificate rotation and renewal processes.

```bash
#!/bin/bash
# tls-setup-comprehensive.sh
# A complete script for setting up HTTPS with self-signed certificates

echo "🔐 Setting up comprehensive HTTPS Ingress example"

# Create a dedicated namespace for our secure application
kubectl create namespace secure-demo --dry-run=client -o yaml | kubectl apply -f -

# Generate a more comprehensive self-signed certificate with Subject Alternative Names
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout secure-app.key -out secure-app.crt \
  -config <(
    echo '[dn]'
    echo 'CN=secure-app.local'
    echo '[req]'
    echo 'distinguished_name = dn'
    echo '[EXT]'
    echo 'subjectAltName=DNS:secure-app.local,DNS:www.secure-app.local,DNS:api.secure-app.local'
    echo 'keyUsage=keyEncipherment,dataEncipherment'
    echo 'extendedKeyUsage=serverAuth'
  ) -extensions EXT

# Create the TLS secret in our namespace
kubectl create secret tls secure-app-tls \
  --key secure-app.key \
  --cert secure-app.crt \
  --namespace secure-demo

# Create a comprehensive secure application
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-web-app
  namespace: secure-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: secure-web
  template:
    metadata:
      labels:
        app: secure-web
    spec:
      containers:
      - name: web-server
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: secure-content
          mountPath: /usr/share/nginx/html
        # Add security context for better security posture
        securityContext:
          runAsNonRoot: true
          runAsUser: 101
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
        # Health checks for better reliability
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
      volumes:
      - name: secure-content
        configMap:
          name: secure-app-content
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: secure-app-content
  namespace: secure-demo
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>Secure Application</title>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
            body { font-family: 'Segoe UI', sans-serif; max-width: 900px; margin: 0 auto; padding: 20px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; min-height: 100vh; }
            .container { background: rgba(255,255,255,0.1); padding: 30px; border-radius: 10px; backdrop-filter: blur(10px); }
            .security-badge { background: #27ae60; padding: 5px 15px; border-radius: 20px; display: inline-block; margin: 10px 0; }
            .info-box { background: rgba(255,255,255,0.2); padding: 15px; margin: 15px 0; border-radius: 5px; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🔒 Secure Web Application</h1>
            <div class="security-badge">✅ HTTPS Enabled</div>
            
            <div class="info-box">
                <h3>Security Features:</h3>
                <ul>
                    <li>TLS 1.2+ encryption</li>
                    <li>HTTP to HTTPS redirection</li>
                    <li>Security headers enabled</li>
                    <li>Certificate-based authentication</li>
                </ul>
            </div>
            
            <div class="info-box">
                <h3>Connection Details:</h3>
                <p><strong>Served by pod:</strong> <span id="hostname">$HOSTNAME</span></p>
                <p><strong>Protocol:</strong> <span id="protocol">HTTPS</span></p>
                <p><strong>Time:</strong> <span id="time"></span></p>
            </div>
            
            <p>This application demonstrates proper HTTPS configuration with Kubernetes Ingress.</p>
        </div>
        
        <script>
            document.getElementById('time').textContent = new Date().toLocaleString();
            // Check if we're actually using HTTPS
            if (location.protocol === 'https:') {
                document.getElementById('protocol').innerHTML = '🔒 HTTPS (Secure)';
            } else {
                document.getElementById('protocol').innerHTML = '⚠️ HTTP (Insecure)';
            }
        </script>
    </body>
    </html>
  health: |
    <!DOCTYPE html>
    <html>
    <head><title>Health Check</title></head>
    <body>
        <h1>Health Status: OK</h1>
        <p>Application is running normally</p>
        <p>Timestamp: <script>document.write(new Date().toISOString());</script></p>
    </body>
    </html>
---
apiVersion: v1
kind: Service
metadata:
  name: secure-web-service
  namespace: secure-demo
spec:
  selector:
    app: secure-web
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: secure-https-ingress
  namespace: secure-demo
  annotations:
    # Force HTTPS redirection
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    # Use modern TLS configuration
    nginx.ingress.kubernetes.io/ssl-protocols: "TLSv1.2 TLSv1.3"
    # Enable HSTS (HTTP Strict Transport Security)
    nginx.ingress.kubernetes.io/server-snippet: |
      add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
      add_header X-Frame-Options "DENY" always;
      add_header X-Content-Type-Options "nosniff" always;
      add_header X-XSS-Protection "1; mode=block" always;
      add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    # Custom error handling
    nginx.ingress.kubernetes.io/custom-http-errors: "404,503"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - secure-app.local
    - www.secure-app.local
    secretName: secure-app-tls  # This must match the secret we created
  rules:
  - host: secure-app.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: secure-web-service
            port:
              number: 80
  - host: www.secure-app.local  # Handle www subdomain as well
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: secure-web-service
            port:
              number: 80
EOF

echo "✅ Secure HTTPS application deployed successfully!"
echo ""
echo "📝 Next steps:"
echo "1. Add these entries to your /etc/hosts file:"
echo "   $(kubectl get ingress secure-https-ingress -n secure-demo -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo '<INGRESS_IP>') secure-app.local"
echo "   $(kubectl get ingress secure-https-ingress -n secure-demo -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo '<INGRESS_IP>') www.secure-app.local"
echo ""
echo "2. Test the application:"
echo "   curl -k https://secure-app.local"
echo "   curl -k https://www.secure-app.local"
echo ""
echo "3. Test HTTP to HTTPS redirect:"
echo "   curl -L http://secure-app.local"
echo ""
echo "4. View certificate details:"
echo "   openssl s_client -connect secure-app.local:443 -servername secure-app.local"
echo ""
echo "🧹 Cleanup commands:"
echo "kubectl delete namespace secure-demo"
echo "rm secure-app.key secure-app.crt"
EOF
```

Make this script executable and run it to see a complete HTTPS setup in action:

```bash
chmod +x tls-setup-comprehensive.sh
./tls-setup-comprehensive.sh
```

## Production-Ready Certificate Management with cert-manager

While self-signed certificates work for development and testing, production applications need proper certificates from trusted Certificate Authorities. The cert-manager project automates certificate provisioning and renewal using Let's Encrypt and other ACME providers.

```yaml
# cert-manager-production.yaml
# This example shows how to configure automatic certificate management
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: production-app-ingress
  annotations:
    # Tell cert-manager to automatically provision a certificate
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    # Additional NGINX configurations for production
    nginx.ingress.kubernetes.io/ssl-protocols: "TLSv1.2 TLSv1.3"
    nginx.ingress.kubernetes.io/ssl-ciphers: "ECDHE-RSA-AES128-GCM-SHA256,ECDHE-RSA-AES256-GCM-SHA384"
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"  # Allow larger uploads
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "60"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "60"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "60"
    # Security headers for production
    nginx.ingress.kubernetes.io/server-snippet: |
      add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
      add_header X-Frame-Options "SAMEORIGIN" always;
      add_header X-Content-Type-Options "nosniff" always;
      add_header X-XSS-Protection "1; mode=block" always;
      add_header Referrer-Policy "strict-origin-when-cross-origin" always;
      add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline';" always;
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - myapp.example.com
    secretName: myapp-tls-cert  # cert-manager will create this secret automatically
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: production-app-service
            port:
              number: 80
```

The beauty of this approach is that cert-manager handles the entire certificate lifecycle - from initial provisioning through automatic renewal before expiration.

## Advanced Ingress Patterns and Best Practices

### Traffic Splitting and Canary Deployments

Ingress can be used to implement sophisticated deployment strategies. Here's an example of how to split traffic between different versions of an application:

```yaml
# canary-deployment-ingress.yaml
# Main production deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-v1
spec:
  replicas: 5
  selector:
    matchLabels:
      app: myapp
      version: v1
  template:
    metadata:
      labels:
        app: myapp
        version: v1
    spec:
      containers:
      - name: app
        image: myapp:1.0.0
        ports:
        - containerPort: 80
---
# Canary deployment with new version
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-v2-canary
spec:
  replicas: 1  # Much smaller for initial testing
  selector:
    matchLabels:
      app: myapp
      version: v2-canary
  template:
    metadata:
      labels:
        app: myapp
        version: v2-canary
    spec:
      containers:
      - name: app
        image: myapp:2.0.0-beta
        ports:
        - containerPort: 80
---
# Service for production traffic
apiVersion: v1
kind: Service
metadata:
  name: app-v1-service
spec:
  selector:
    app: myapp
    version: v1
  ports:
  - port: 80
---
# Service for canary traffic
apiVersion: v1
kind: Service
metadata:
  name: app-v2-canary-service
spec:
  selector:
    app: myapp
    version: v2-canary
  ports:
  - port: 80
---
# Main ingress for production traffic
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-production-ingress
  annotations:
    nginx.ingress.kubernetes.io/canary: "false"
spec:
  ingressClassName: nginx
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-v1-service
            port:
              number: 80
---
# Canary ingress that receives a small percentage of traffic
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-canary-ingress
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-weight: "10"  # 10% of traffic goes to canary
    # Alternative canary strategies:
    # nginx.ingress.kubernetes.io/canary-by-header: "X-Canary"
    # nginx.ingress.kubernetes.io/canary-by-cookie: "canary-user"
spec:
  ingressClassName: nginx
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-v2-canary-service
            port:
              number: 80
```

This canary deployment setup allows you to gradually test new versions with real traffic while maintaining the ability to quickly rollback if issues arise.

### Multi-Domain and Wildcard Routing

Enterprise applications often need to handle multiple domains or dynamic subdomains. Here's how to configure Ingress for these scenarios:

```yaml
# multi-domain-ingress.yaml
# Application that serves multiple brands/domains
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multi-tenant-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: multi-tenant
  template:
    metadata:
      labels:
        app: multi-tenant
    spec:
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: app-content
          mountPath: /usr/share/nginx/html
        env:
        - name: SERVER_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
      volumes:
      - name: app-content
        configMap:
          name: multi-tenant-content
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: multi-tenant-content
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>Multi-Tenant Application</title>
        <style>
            body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
            .domain-info { background: #e3f2fd; padding: 15px; border-radius: 5px; margin: 15px 0; }
            .tenant-badge { background: #2196f3; color: white; padding: 5px 10px; border-radius: 3px; }
        </style>
    </head>
    <body>
        <h1>🏢 Multi-Tenant SaaS Platform</h1>
        
        <div class="domain-info">
            <h3>Current Tenant Information</h3>
            <p><strong>Domain:</strong> <span id="domain">...</span></p>
            <p><strong>Pod:</strong> <span class="tenant-badge">$HOSTNAME</span></p>
            <p><strong>Timestamp:</strong> <span id="timestamp">...</span></p>
        </div>
        
        <div class="domain-info">
            <h3>Supported Domains</h3>
            <ul>
                <li>company-a.saas.com - Tenant A</li>
                <li>company-b.saas.com - Tenant B</li>
                <li>enterprise.saas.com - Enterprise Tenant</li>
                <li>*.dev.saas.com - Development Environments</li>
            </ul>
        </div>
        
        <p>This application demonstrates how a single backend can serve multiple tenants 
           based on the domain name in the request.</p>
           
        <script>
            document.getElementById('domain').textContent = window.location.hostname;
            document.getElementById('timestamp').textContent = new Date().toLocaleString();
        </script>
    </body>
    </html>
---
apiVersion: v1
kind: Service
metadata:
  name: multi-tenant-service
spec:
  selector:
    app: multi-tenant
  ports:
  - port: 80
    targetPort: 80
---
# Ingress with multiple domains and wildcard support
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-domain-ingress
  annotations:
    nginx.ingress.kubernetes.io/server-snippet: |
      # Add custom headers to identify the tenant
      set $tenant "unknown";
      if ($host ~ "^company-a\.") {
        set $tenant "tenant-a";
      }
      if ($host ~ "^company-b\.") {
        set $tenant "tenant-b";
      }
      if ($host ~ "^enterprise\.") {
        set $tenant "enterprise";
      }
      if ($host ~ "^(.+)\.dev\.") {
        set $tenant "dev-$1";
      }
      add_header X-Tenant-ID $tenant always;
    # Rate limiting per domain
    nginx.ingress.kubernetes.io/rate-limit-requests-per-second: "10"
    nginx.ingress.kubernetes.io/rate-limit-window: "1m"
spec:
  ingressClassName: nginx
  rules:
  # Specific tenant domains
  - host: company-a.saas.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: multi-tenant-service
            port:
              number: 80
  - host: company-b.saas.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: multi-tenant-service
            port:
              number: 80
  - host: enterprise.saas.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: multi-tenant-service
            port:
              number: 80
  # Wildcard for development environments
  # Note: Wildcard certificates would be needed for HTTPS
  - host: "*.dev.saas.com"
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: multi-tenant-service
            port:
              number: 80
```

### Geographic and Load Balancer Integration

For global applications, you often need to integrate Ingress with cloud load balancers and implement geographic routing:

```yaml
# global-ingress-setup.yaml
# Configuration for global load balancing with cloud integration
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: global-app-ingress
  annotations:
    # Cloud-specific annotations (example for Google Cloud)
    kubernetes.io/ingress.class: "gce"
    kubernetes.io/ingress.global-static-ip-name: "myapp-global-ip"
    ingress.gcp.kubernetes.io/managed-certificates: "myapp-ssl-cert"
    
    # Alternative for AWS ALB
    # kubernetes.io/ingress.class: "alb"
    # alb.ingress.kubernetes.io/scheme: internet-facing
    # alb.ingress.kubernetes.io/target-type: ip
    # alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:region:account:certificate/cert-id
    
    # Performance and security settings
    nginx.ingress.kubernetes.io/proxy-buffering: "on"
    nginx.ingress.kubernetes.io/proxy-buffer-size: "128k"
    nginx.ingress.kubernetes.io/proxy-buffers-number: "4"
    nginx.ingress.kubernetes.io/client-max-body-size: "100m"
    
    # Geographic routing headers
    nginx.ingress.kubernetes.io/server-snippet: |
      # Add geographic information to responses
      add_header X-Region "us-central1" always;
      add_header X-Zone "$server_name" always;
      
      # Implement basic geographic routing logic
      set $backend_pool "default";
      if ($http_cloudfront_viewer_country ~ "^(US|CA|MX)$") {
        set $backend_pool "americas";
      }
      if ($http_cloudfront_viewer_country ~ "^(GB|DE|FR|IT|ES)$") {
        set $backend_pool "europe";
      }
      if ($http_cloudfront_viewer_country ~ "^(JP|KR|SG|AU)$") {
        set $backend_pool "asia";
      }
      add_header X-Backend-Pool $backend_pool always;

spec:
  rules:
  - host: app.globalcompany.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: global-app-service
            port:
              number: 80
  # Health check endpoint for load balancer
  - host: app.globalcompany.com
    http:
      paths:
      - path: /health
        pathType: Exact
        backend:
          service:
            name: health-check-service
            port:
              number: 80
```

## Monitoring and Observability for Ingress

Proper monitoring is crucial for understanding your Ingress performance and troubleshooting issues. Here's a comprehensive monitoring setup:

```yaml
# ingress-monitoring.yaml
# ServiceMonitor for Prometheus to scrape NGINX Ingress metrics
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: nginx-ingress-controller-metrics
  namespace: ingress-nginx
spec:
  endpoints:
  - port: prometheus
    interval: 30s
    path: /metrics
  selector:
    matchLabels:
      app.kubernetes.io/name: ingress-nginx
      app.kubernetes.io/component: controller
---
# Example application with custom metrics endpoint
apiVersion: apps/v1
kind: Deployment
metadata:
  name: monitored-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: monitored-app
  template:
    metadata:
      labels:
        app: monitored-app
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
          name: http
        - containerPort: 8080
          name: metrics
        volumeMounts:
        - name: app-content
          mountPath: /usr/share/nginx/html
        - name: nginx-config
          mountPath: /etc/nginx/conf.d
        # Resource limits for better monitoring
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        # Comprehensive health checks
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 30
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /ready
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
          timeoutSeconds: 3
          failureThreshold: 2
      volumes:
      - name: app-content
        configMap:
          name: monitored-app-content
      - name: nginx-config
        configMap:
          name: nginx-metrics-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: monitored-app-content
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>Monitored Application</title>
        <style>
            body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
            .metrics-box { background: #f5f5f5; padding: 15px; border-radius: 5px; margin: 15px 0; }
            .status-good { color: #27ae60; font-weight: bold; }
            .metric { display: inline-block; margin: 10px; padding: 10px; background: white; border-radius: 3px; }
        </style>
    </head>
    <body>
        <h1>📊 Monitored Application</h1>
        
        <div class="metrics-box">
            <h3>Application Status</h3>
            <p class="status-good">✅ All systems operational</p>
            <p><strong>Pod:</strong> $HOSTNAME</p>
            <p><strong>Uptime:</strong> <span id="uptime">Loading...</span></p>
        </div>
        
        <div class="metrics-box">
            <h3>Available Endpoints</h3>
            <ul>
                <li><a href="/health">Health Check</a> - Application health status</li>
                <li><a href="/ready">Readiness Check</a> - Ready to serve traffic</li>
                <li><a href="/metrics">Prometheus Metrics</a> - Application metrics</li>
                <li><a href="/stats">Statistics</a> - Request statistics</li>
            </ul>
        </div>
        
        <div class="metrics-box">
            <h3>Real-time Metrics</h3>
            <div class="metric">
                <strong>Requests:</strong> <span id="request-count">0</span>
            </div>
            <div class="metric">
                <strong>Response Time:</strong> <span id="response-time">0ms</span>
            </div>
            <div class="metric">
                <strong>Memory Usage:</strong> <span id="memory-usage">Unknown</span>
            </div>
        </div>
        
        <script>
            let requestCount = 0;
            let startTime = Date.now();
            
            function updateMetrics() {
                document.getElementById('uptime').textContent = 
                    Math.floor((Date.now() - startTime) / 1000) + ' seconds';
                document.getElementById('request-count').textContent = ++requestCount;
                document.getElementById('response-time').textContent = 
                    Math.floor(Math.random() * 100) + 'ms';
                document.getElementById('memory-usage').textContent = 
                    Math.floor(Math.random() * 100) + 'MB';
            }
            
            setInterval(updateMetrics, 2000);
            updateMetrics();
        </script>
    </body>
    </html>
  health: |
    <!DOCTYPE html>
    <html>
    <head><title>Health Check</title></head>
    <body>
        <h1>Health Status: OK</h1>
        <p>Application is healthy and ready to serve requests</p>
        <p>Timestamp: <script>document.write(new Date().toISOString());</script></p>
        <p>Pod: $HOSTNAME</p>
    </body>
    </html>
  ready: |
    <!DOCTYPE html>
    <html>
    <head><title>Readiness Check</title></head>
    <body>
        <h1>Readiness Status: Ready</h1>
        <p>Application is ready to receive traffic</p>
        <p>Database: Connected ✅</p>
        <p>Cache: Connected ✅</p>
        <p>External APIs: Connected ✅</p>
    </body>
    </html>
  metrics: |
    # HELP http_requests_total Total number of HTTP requests
    # TYPE http_requests_total counter
    http_requests_total{method="GET",path="/",status="200"} 1234
    http_requests_total{method="GET",path="/health",status="200"} 567
    http_requests_total{method="POST",path="/api/data",status="201"} 89
    
    # HELP http_request_duration_seconds HTTP request latency
    # TYPE http_request_duration_seconds histogram
    http_request_duration_seconds_bucket{le="0.1"} 1000
    http_request_duration_seconds_bucket{le="0.5"} 1200
    http_request_duration_seconds_bucket{le="1"} 1250
    http_request_duration_seconds_bucket{le="+Inf"} 1300
    http_request_duration_seconds_sum 245.7
    http_request_duration_seconds_count 1300
    
    # HELP memory_usage_bytes Current memory usage in bytes
    # TYPE memory_usage_bytes gauge
    memory_usage_bytes 67108864
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-metrics-config
data:
  metrics.conf: |
    server {
        listen 8080;
        location /metrics {
            access_log off;
            return 200 '# HELP nginx_connections_active Active connections
    # TYPE nginx_connections_active gauge
    nginx_connections_active 5
    
    # HELP nginx_http_requests_total Total HTTP requests
    # TYPE nginx_http_requests_total counter
    nginx_http_requests_total 12345
    ';
            add_header Content-Type text/plain;
        }
    }
---
apiVersion: v1
kind: Service
metadata:
  name: monitored-app-service
  labels:
    app: monitored-app
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/metrics"
spec:
  selector:
    app: monitored-app
  ports:
  - name: http
    port: 80
    targetPort: 80
  - name: metrics
    port: 8080
    targetPort: 8080
---
# Ingress with detailed monitoring annotations
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: monitored-app-ingress
  annotations:
    # Enable detailed request logging
    nginx.ingress.kubernetes.io/enable-access-log: "true"
    # Custom log format for better observability
    nginx.ingress.kubernetes.io/log-format-upstream: |
      $remote_addr - $remote_user [$time_local] "$request" $status $body_bytes_sent 
      "$http_referer" "$http_user_agent" $request_length $request_time 
      [$proxy_upstream_name] [$proxy_alternative_upstream_name] $upstream_addr 
      $upstream_response_length $upstream_response_time $upstream_status $req_id
    # Enable rate limiting with monitoring
    nginx.ingress.kubernetes.io/rate-limit-requests-per-second: "100"
    nginx.ingress.kubernetes.io/rate-limit-window: "1m"
    # Add custom headers for tracing
    nginx.ingress.kubernetes.io/server-snippet: |
      add_header X-Request-ID $req_id always;
      add_header X-Response-Time $request_time always;
      add_header X-Upstream-Server $upstream_addr always;
spec:
  ingressClassName: nginx
  rules:
  - host: monitored-app.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: monitored-app-service
            port:
              number: 80
```

## Troubleshooting Common Ingress Issues

Understanding how to diagnose and resolve Ingress problems is crucial for maintaining reliable applications. Here's a systematic approach to troubleshooting:

### Debugging Connectivity Issues

```bash
#!/bin/bash
# ingress-troubleshooting.sh
# Comprehensive Ingress troubleshooting script

echo "🔍 Kubernetes Ingress Troubleshooting Guide"
echo "============================================"

# Function to check a specific component
check_component() {
    local component=$1
    local command=$2
    echo -n "Checking $component... "
    if eval $command >/dev/null 2>&1; then
        echo "✅ OK"
        return 0
    else
        echo "❌ FAILED"
        return 1
    fi
}

echo ""
echo "1. INGRESS CONTROLLER STATUS"
echo "----------------------------"
check_component "Ingress Controller Pods" \
    "kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller | grep -q Running"

check_component "Ingress Controller Service" \
    "kubectl get service -n ingress-nginx | grep -q ingress-nginx-controller"

# Get detailed controller information
echo ""
echo "Ingress Controller Details:"
kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller -o wide

echo ""
echo "2. INGRESS RESOURCES"
echo "-------------------"
echo "All Ingress resources across namespaces:"
kubectl get ingress --all-namespaces -o wide

echo ""
echo "3. DNS AND CONNECTIVITY TESTS"
echo "-----------------------------"

# Function to test DNS resolution and HTTP connectivity
test_ingress() {
    local hostname=$1
    local expected_status=${2:-200}
    
    echo "Testing $hostname:"
    
    # Get the Ingress Controller's external IP
    local ingress_ip=$(kubectl get service -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    if [ -z "$ingress_ip" ]; then
        ingress_ip=$(kubectl get service -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.clusterIP}')
        echo "  Using ClusterIP: $ingress_ip (consider port-forwarding for external access)"
    else
        echo "  External IP: $ingress_ip"
    fi
    
    # Test HTTP connectivity
    if command -v curl >/dev/null 2>&1; then
        echo -n "  HTTP Test: "
        local http_status=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: $hostname" http://$ingress_ip/ 2>/dev/null)
        if [ "$http_status" = "$expected_status" ]; then
            echo "✅ $http_status"
        else
            echo "❌ $http_status (expected $expected_status)"
        fi
    else
        echo "  curl not available for HTTP testing"
    fi
    
    # Check /etc/hosts entry
    echo -n "  /etc/hosts entry: "
    if grep -q "$hostname" /etc/hosts 2>/dev/null; then
        echo "✅ Found"
        grep "$hostname" /etc/hosts | head -n1
    else
        echo "❌ Missing"
        echo "    Add this line to /etc/hosts: $ingress_ip $hostname"
    fi
}

# Test common hostnames (you can modify this list)
for hostname in hello-world.local myapp.company.com secure-app.local; do
    if kubectl get ingress --all-namespaces -o json | jq -r '.items[].spec.rules[].host' | grep -q "^$hostname$" 2>/dev/null; then
        test_ingress "$hostname"
        echo ""
    fi
done

echo ""
echo "4. SERVICE CONNECTIVITY"
echo "----------------------"
echo "Services that might be referenced by Ingress:"
kubectl get services --all-namespaces -o wide | grep -E "(frontend|api|web|app)"

echo ""
echo "5. POD STATUS"
echo "------------"
echo "Application pods status:"
kubectl get pods --all-namespaces -o wide | grep -E "(frontend|api|web|app)" | head -10

echo ""
echo "6. INGRESS CONTROLLER LOGS"
echo "--------------------------"
echo "Recent Ingress Controller logs (last 20 lines):"
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=20

echo ""
echo "7. COMMON FIXES"
echo "--------------"
echo "If you're experiencing issues, try these solutions:"
echo ""
echo "🔧 DNS Issues:"
echo "   - Ensure /etc/hosts entries point to the correct IP"
echo "   - For minikube: minikube ip"
echo "   - For cloud: kubectl get service -n ingress-nginx"
echo ""
echo "🔧 Certificate Issues:"
echo "   - Check TLS secret exists: kubectl get secret <secret-name>"
echo "   - Verify certificate validity: openssl x509 -in cert.crt -text -noout"
echo ""
echo "🔧 Backend Issues:"
echo "   - Verify service endpoints: kubectl get endpoints <service-name>"
echo "   - Check pod readiness: kubectl get pods -o wide"
echo "   - Test service directly: kubectl port-forward service/<service-name> 8080:80"
echo ""
echo "🔧 Path Matching Issues:"
echo "   - Use 'Prefix' for most cases, 'Exact' for specific endpoints"
echo "   - Check annotation: nginx.ingress.kubernetes.io/rewrite-target"
echo ""
echo "🔧 Controller Issues:"
echo "   - Restart controller: kubectl rollout restart deployment/ingress-nginx-controller -n ingress-nginx"
echo "   - Check controller events: kubectl describe pods -n ingress-nginx"
echo ""
echo "For detailed debugging, use:"
echo "kubectl describe ingress <ingress-name> -n <namespace>"
echo "kubectl logs -f -n ingress-nginx -l app.kubernetes.io/component=controller"
EOF
```

### Advanced Configuration Examples

Here are some advanced configuration patterns that solve common production challenges:

```yaml
# advanced-patterns.yaml
# Rate limiting with different tiers
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-rate-limited-ingress
  annotations:
    # Different rate limits for different paths
    nginx.ingress.kubernetes.io/server-snippet: |
      location /api/public {
        limit_req zone=public burst=20 nodelay;
      }
      location /api/premium {
        limit_req zone=premium burst=100 nodelay;
      }
      location /api/internal {
        # No rate limiting for internal APIs
        allow 10.0.0.0/8;
        allow 172.16.0.0/12;
        allow 192.168.0.0/16;
        deny all;
      }
    # Custom error pages
    nginx.ingress.kubernetes.io/custom-http-errors: "403,429,500,502,503"
    nginx.ingress.kubernetes.io/default-backend: error-page-service
spec:
  ingressClassName: nginx
  rules:
  - host: api.company.com
    http:
      paths:
      - path: /api/public
        pathType: Prefix
        backend:
          service:
            name: public-api-service
            port:
              number: 80
      - path: /api/premium
        pathType: Prefix
        backend:
          service:
            name: premium-api-service
            port:
              number: 80
      - path: /api/internal
        pathType: Prefix
        backend:
          service:
            name: internal-api-service
            port:
              number: 80
---
# WebSocket support with sticky sessions
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: websocket-ingress
  annotations:
    # Enable WebSocket support
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
    # Enable session affinity for WebSocket connections
    nginx.ingress.kubernetes.io/affinity: "cookie"
    nginx.ingress.kubernetes.io/affinity-mode: "persistent"
    nginx.ingress.kubernetes.io/session-cookie-name: "websocket-server"
    nginx.ingress.kubernetes.io/session-cookie-expires: "86400"
    nginx.ingress.kubernetes.io/session-cookie-max-age: "86400"
    nginx.ingress.kubernetes.io/session-cookie-path: "/"
    # WebSocket specific headers
    nginx.ingress.kubernetes.io/proxy-set-headers: |
      map $http_upgrade $connection_upgrade {
          default upgrade;
          '' close;
      }
    nginx.ingress.kubernetes.io/configuration-snippet: |
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection $connection_upgrade;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;
spec:
  ingressClassName: nginx
  rules:
  - host: chat.company.com
    http:
      paths:
      - path: /ws
        pathType: Prefix
        backend:
          service:
            name: websocket-service
            port:
              number: 8080
      - path: /
        pathType: Prefix
        backend:
          service:
            name: chat-frontend-service
            port:
              number: 80
```

## Performance Optimization and Best Practices

### Resource Management and Scaling

```yaml
# performance-optimized-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: high-performance-ingress
  annotations:
    # Connection and timeout optimizations
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "5"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "60"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "60"
    nginx.ingress.kubernetes.io/proxy-next-upstream-timeout: "0"
    nginx.ingress.kubernetes.io/proxy-request-buffering: "off"
    
    # Buffer configurations for high throughput
    nginx.ingress.kubernetes.io/proxy-buffer-size: "128k"
    nginx.ingress.kubernetes.io/proxy-buffers-number: "4"
    nginx.ingress.kubernetes.io/proxy-busy-buffers-size: "256k"
    
    # Enable compression
    nginx.ingress.kubernetes.io/enable-brotli: "true"
    nginx.ingress.kubernetes.io/brotli-level: "6"
    nginx.ingress.kubernetes.io/brotli-types: "text/xml image/svg+xml application/x-font-ttf image/vnd.microsoft.icon application/x-font-opentype application/json font/eot application/vnd.ms-fontobject application/javascript font/otf application/xml application/xhtml+xml text/javascript application/x-javascript text/plain application/x-font-truetype application/xml+rss image/x-icon font/opentype text/css image/x-win-bitmap"
    
    # Caching headers for static content
    nginx.ingress.kubernetes.io/server-snippet: |
      # Cache static assets
      location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header X-Cache-Status "HIT-STATIC";
      }
      
      # Cache API responses briefly
      location ~* ^/api/ {
        add_header Cache-Control "public, max-age=300";
        add_header X-Cache-Status "HIT-API";
      }
      
      # Security and performance headers
      add_header X-Frame-Options "SAMEORIGIN" always;
      add_header X-Content-Type-Options "nosniff" always;
      add_header X-XSS-Protection "1; mode=block" always;
      add_header Referrer-Policy "strict-origin-when-cross-origin" always;
      
      # Enable HTTP/2 server push for critical resources
      location = / {
        http2_push /css/main.css;
        http2_push /js/app.js;
      }
    
    # Load balancing method
    nginx.ingress.kubernetes.io/upstream-hash-by: "$request_uri"
    # Alternative: nginx.ingress.kubernetes.io/load-balance: "round_robin"
    
    # Connection pooling for better performance
    nginx.ingress.kubernetes.io/upstream-keepalive-connections: "32"
    nginx.ingress.kubernetes.io/upstream-keepalive-requests: "100"
    nginx.ingress.kubernetes.io/upstream-keepalive-timeout: "60"
    
spec:
  ingressClassName: nginx
  rules:
  - host: highperf.company.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: high-performance-service
            port:
              number: 80
```

### Production Deployment Checklist and Security Hardening

```yaml
# production-security-ingress.yaml
# Production-ready Ingress with comprehensive security
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: production-secure-ingress
  annotations:
    # Force HTTPS and modern TLS
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/ssl-protocols: "TLSv1.2 TLSv1.3"
    nginx.ingress.kubernetes.io/ssl-ciphers: "ECDHE-ECDSA-AES128-GCM-SHA256,ECDHE-RSA-AES128-GCM-SHA256,ECDHE-ECDSA-AES256-GCM-SHA384,ECDHE-RSA-AES256-GCM-SHA384"
    nginx.ingress.kubernetes.io/ssl-prefer-server-ciphers: "true"
    
    # Security headers - comprehensive set for production
    nginx.ingress.kubernetes.io/server-snippet: |
      # HSTS with preload
      add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
      
      # Content Security Policy - adjust based on your app's needs
      add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data: https:; connect-src 'self' https://api.company.com; frame-ancestors 'none';" always;
      
      # Additional security headers
      add_header X-Frame-Options "DENY" always;
      add_header X-Content-Type-Options "nosniff" always;
      add_header X-XSS-Protection "1; mode=block" always;
      add_header Referrer-Policy "strict-origin-when-cross-origin" always;
      add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
      
      # Hide server information
      more_clear_headers 'Server';
      more_clear_headers 'X-Powered-By';
      add_header X-Served-By "Production-Cluster" always;
      
      # Rate limiting by IP
      limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
      limit_req_zone $binary_remote_addr zone=login:10m rate=1r/s;
      
      # Geographic restrictions (example)
      # Uncomment and modify based on your needs
      # map $geoip_country_code $allowed_country {
      #     default 0;
      #     US 1;
      #     CA 1;
      #     GB 1;
      # }
      
      # Block known bad user agents
      map $http_user_agent $blocked_agent {
          default 0;
          ~*malicious 1;
          ~*bot 1;
          ~*crawler 1;
      }
      
      if ($blocked_agent) {
          return 403;
      }
      
      # API rate limiting
      location /api/ {
          limit_req zone=api burst=20 nodelay;
          limit_req_status 429;
      }
      
      # Stricter rate limiting for login endpoints
      location /auth/login {
          limit_req zone=login burst=5 nodelay;
          limit_req_status 429;
      }
      
      # Block access to sensitive files
      location ~* \.(env|git|svn|htaccess|htpasswd)$ {
          deny all;
          return 404;
      }
      
      # Monitor and log suspicious activity
      location /admin {
          access_log /var/log/nginx/admin_access.log;
          error_log /var/log/nginx/admin_error.log;
      }
    
    # Request size limits
    nginx.ingress.kubernetes.io/proxy-body-size: "10m"
    nginx.ingress.kubernetes.io/client-max-body-size: "10m"
    
    # Timeout configurations
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "10"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "30"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "30"
    
    # Enable request ID for tracing
    nginx.ingress.kubernetes.io/enable-access-log: "true"
    nginx.ingress.kubernetes.io/log-format-upstream: |
      [$time_local] $remote_addr - $remote_user "$request" $status $body_bytes_sent 
      "$http_referer" "$http_user_agent" $request_length $request_time 
      [$proxy_upstream_name] $upstream_addr $upstream_response_length 
      $upstream_response_time $upstream_status $req_id $http_x_forwarded_for
    
    # Custom error pages
    nginx.ingress.kubernetes.io/custom-http-errors: "400,401,403,404,405,408,410,411,412,413,414,415,416,417,418,421,422,423,424,426,428,429,431,451,500,501,502,503,504,505,506,507,508,510,511"
    nginx.ingress.kubernetes.io/default-backend: custom-error-pages
    
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - app.company.com
    - www.app.company.com
    secretName: company-app-tls
  rules:
  - host: app.company.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: production-app-service
            port:
              number: 80
  - host: www.app.company.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: production-app-service
            port:
              number: 80
---
# Custom error pages service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: custom-error-pages
spec:
  replicas: 2
  selector:
    matchLabels:
      app: error-pages
  template:
    metadata:
      labels:
        app: error-pages
    spec:
      containers:
      - name: error-pages
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: error-pages-content
          mountPath: /usr/share/nginx/html
        resources:
          requests:
            memory: "32Mi"
            cpu: "10m"
          limits:
            memory: "64Mi"
            cpu: "50m"
      volumes:
      - name: error-pages-content
        configMap:
          name: error-pages-content
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: error-pages-content
data:
  404.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>Page Not Found</title>
        <style>
            body { font-family: Arial, sans-serif; text-align: center; padding: 50px; background: #f5f5f5; }
            .error-container { max-width: 600px; margin: 0 auto; background: white; padding: 40px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
            .error-code { font-size: 72px; color: #e74c3c; margin: 0; }
            .error-message { font-size: 24px; color: #333; margin: 20px 0; }
            .error-description { color: #666; margin: 20px 0; }
            .home-link { display: inline-block; background: #3498db; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; margin-top: 20px; }
        </style>
    </head>
    <body>
        <div class="error-container">
            <h1 class="error-code">404</h1>
            <h2 class="error-message">Page Not Found</h2>
            <p class="error-description">The page you are looking for might have been removed, had its name changed, or is temporarily unavailable.</p>
            <a href="/" class="home-link">Go Home</a>
        </div>
    </body>
    </html>
  403.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>Access Forbidden</title>
        <style>
            body { font-family: Arial, sans-serif; text-align: center; padding: 50px; background: #f5f5f5; }
            .error-container { max-width: 600px; margin: 0 auto; background: white; padding: 40px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
            .error-code { font-size: 72px; color: #e74c3c; margin: 0; }
            .error-message { font-size: 24px; color: #333; margin: 20px 0; }
            .error-description { color: #666; margin: 20px 0; }
        </style>
    </head>
    <body>
        <div class="error-container">
            <h1 class="error-code">403</h1>
            <h2 class="error-message">Access Forbidden</h2>
            <p class="error-description">You don't have permission to access this resource.</p>
        </div>
    </body>
    </html>
  500.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>Internal Server Error</title>
        <style>
            body { font-family: Arial, sans-serif; text-align: center; padding: 50px; background: #f5f5f5; }
            .error-container { max-width: 600px; margin: 0 auto; background: white; padding: 40px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
            .error-code { font-size: 72px; color: #e74c3c; margin: 0; }
            .error-message { font-size: 24px; color: #333; margin: 20px 0; }
            .error-description { color: #666; margin: 20px 0; }
        </style>
    </head>
    <body>
        <div class="error-container">
            <h1 class="error-code">500</h1>
            <h2 class="error-message">Internal Server Error</h2>
            <p class="error-description">Something went wrong on our end. Please try again later.</p>
        </div>
    </body>
    </html>
---
apiVersion: v1
kind: Service
metadata:
  name: custom-error-pages
spec:
  selector:
    app: error-pages
  ports:
  - port: 80
    targetPort: 80
```

## Complete Production Setup Script

Here's a comprehensive script that demonstrates best practices for setting up Ingress in a production environment:

```bash
#!/bin/bash
# production-ingress-setup.sh
# Complete production-ready Ingress setup with monitoring and security

set -euo pipefail

# Configuration variables
NAMESPACE="${NAMESPACE:-production}"
APP_NAME="${APP_NAME:-company-app}"
DOMAIN="${DOMAIN:-app.company.com}"
EMAIL="${EMAIL:-admin@company.com}"

echo "🚀 Setting up Production Kubernetes Ingress"
echo "============================================"
echo "Namespace: $NAMESPACE"
echo "Application: $APP_NAME"
echo "Domain: $DOMAIN"
echo "Email: $EMAIL"
echo ""

# Function to wait for resource to be ready
wait_for_resource() {
    local resource_type=$1
    local resource_name=$2
    local namespace=${3:-default}
    local timeout=${4:-300}
    
    echo "⏳ Waiting for $resource_type/$resource_name to be ready..."
    kubectl wait --for=condition=available --timeout=${timeout}s \
        $resource_type/$resource_name -n $namespace 2>/dev/null || \
    kubectl wait --for=condition=ready --timeout=${timeout}s \
        $resource_type/$resource_name -n $namespace 2>/dev/null || \
    true
}

# Create namespace
echo "📦 Creating namespace..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Install cert-manager if not present
if ! kubectl get namespace cert-manager >/dev/null 2>&1; then
    echo "🔐 Installing cert-manager..."
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
    wait_for_resource deployment cert-manager cert-manager
    wait_for_resource deployment cert-manager-cainjector cert-manager
    wait_for_resource deployment cert-manager-webhook cert-manager
    echo "✅ cert-manager installed successfully"
else
    echo "✅ cert-manager already installed"
fi

# Create Let's Encrypt ClusterIssuer
echo "🔒 Setting up Let's Encrypt certificate issuer..."
cat << EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: $EMAIL
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

# Deploy the production application
echo "🏭 Deploying production application..."
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $APP_NAME
  namespace: $NAMESPACE
  labels:
    app: $APP_NAME
    version: production
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 25%
      maxSurge: 25%
  selector:
    matchLabels:
      app: $APP_NAME
  template:
    metadata:
      labels:
        app: $APP_NAME
        version: production
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 101
        fsGroup: 101
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
          name: http
        - containerPort: 8080
          name: metrics
        volumeMounts:
        - name: app-content
          mountPath: /usr/share/nginx/html
        - name: nginx-config
          mountPath: /etc/nginx/conf.d
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 30
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /ready
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 3
          successThreshold: 1
          failureThreshold: 3
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
      volumes:
      - name: app-content
        configMap:
          name: $APP_NAME-content
      - name: nginx-config
        configMap:
          name: $APP_NAME-nginx-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: $APP_NAME-content
  namespace: $NAMESPACE
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>Production Application</title>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
            body { 
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; 
                max-width: 1200px; margin: 0 auto; padding: 20px; 
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                color: white; min-height: 100vh;
            }
            .container { 
                background: rgba(255,255,255,0.1); padding: 40px; 
                border-radius: 15px; backdrop-filter: blur(10px); 
                box-shadow: 0 8px 32px rgba(0,0,0,0.1);
            }
            .header { text-align: center; margin-bottom: 40px; }
            .status-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; }
            .status-card { 
                background: rgba(255,255,255,0.2); padding: 20px; 
                border-radius: 10px; border: 1px solid rgba(255,255,255,0.3);
            }
            .metric { font-size: 24px; font-weight: bold; color: #4CAF50; }
            .label { font-size: 14px; opacity: 0.8; }
            .security-badge { 
                background: #27ae60; padding: 8px 16px; 
                border-radius: 20px; display: inline-block; margin: 10px 5px;
                font-size: 12px; font-weight: bold;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>🚀 Production Application</h1>
                <div class="security-badge">✅ HTTPS Enabled</div>
                <div class="security-badge">🔒 Security Headers</div>
                <div class="security-badge">📊 Monitoring Active</div>
                <div class="security-badge">🛡️ Rate Limited</div>
            </div>
            
            <div class="status-grid">
                <div class="status-card">
                    <div class="metric" id="uptime">0s</div>
                    <div class="label">Uptime</div>
                </div>
                <div class="status-card">
                    <div class="metric" id="requests">0</div>
                    <div class="label">Total Requests</div>
                </div>
                <div class="status-card">
                    <div class="metric" id="response-time">0ms</div>
                    <div class="label">Avg Response Time</div>
                </div>
                <div class="status-card">
                    <div class="metric">$HOSTNAME</div>
                    <div class="label">Pod Instance</div>
                </div>
            </div>
            
            <div style="margin-top: 40px; text-align: center;">
                <h3>🌐 Production Features</h3>
                <ul style="text-align: left; max-width: 600px; margin: 0 auto;">
                    <li>Automatic HTTPS with Let's Encrypt certificates</li>
                    <li>Advanced security headers and CSP</li>
                    <li>Rate limiting and DDoS protection</li>
                    <li>Health checks and readiness probes</li>
                    <li>Horizontal pod autoscaling</li>
                    <li>Comprehensive monitoring and logging</li>
                    <li>Zero-downtime deployments</li>
                    <li>Custom error pages</li>
                </ul>
            </div>
        </div>
        
        <script>
            let startTime = Date.now();
            let requestCount = 0;
            
            function updateMetrics() {
                const uptime = Math.floor((Date.now() - startTime) / 1000);
                document.getElementById('uptime').textContent = uptime + 's';
                document.getElementById('requests').textContent = ++requestCount;
                document.getElementById('response-time').textContent = 
                    (50 + Math.floor(Math.random() * 100)) + 'ms';
            }
            
            setInterval(updateMetrics, 3000);
            updateMetrics();
        </script>
    </body>
    </html>
  health: |
    <!DOCTYPE html>
    <html>
    <head><title>Health Check</title></head>
    <body>
        <h1>Health Status: OK</h1>
        <p>Application: $APP_NAME</p>
        <p>Status: Healthy ✅</p>
        <p>Pod: $HOSTNAME</p>
        <p>Timestamp: <script>document.write(new Date().toISOString());</script></p>
    </body>
    </html>
  ready: |
    <!DOCTYPE html>
    <html>
    <head><title>Readiness Check</title></head>
    <body>
        <h1>Readiness Status: Ready</h1>
        <p>Application: Ready to serve traffic ✅</p>
        <p>Database: Connected ✅</p>
        <p>Cache: Connected ✅</p>
        <p>External APIs: Connected ✅</p>
    </body>
    </html>
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: $APP_NAME-nginx-config
  namespace: $NAMESPACE
data:
  default.conf: |
    server {
        listen 80;
        server_name localhost;
        root /usr/share/nginx/html;
        index index.html;
        
        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
        
        location / {
            try_files \$uri \$uri/ =404;
        }
        
        location /health {
            access_log off;
            try_files /health =404;
        }
        
        location /ready {
            access_log off;
            try_files /ready =404;
        }
    }
    
    server {
        listen 8080;
        location /metrics {
            access_log off;
            return 200 'nginx_http_requests_total{method="GET",status="200"} 12345\nnginx_connections_active 5\n';
            add_header Content-Type text/plain;
        }
    }
---
apiVersion: v1
kind: Service
metadata:
  name: $APP_NAME-service
  namespace: $NAMESPACE
  labels:
    app: $APP_NAME
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/metrics"
spec:
  selector:
    app: $APP_NAME
  ports:
  - name: http
    port: 80
    targetPort: 80
  - name: metrics
    port: 8080
    targetPort: 8080
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: $APP_NAME-ingress
  namespace: $NAMESPACE
  annotations:
    # Automatic certificate management
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    
    # Security configurations
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/ssl-protocols: "TLSv1.2 TLSv1.3"
    
    # Performance optimizations
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "10"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "60"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "60"
    
    # Comprehensive security headers
    nginx.ingress.kubernetes.io/server-snippet: |
      add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
      add_header X-Frame-Options "SAMEORIGIN" always;
      add_header X-Content-Type-Options "nosniff" always;
      add_header X-XSS-Protection "1; mode=block" always;
      add_header Referrer-Policy "strict-origin-when-cross-origin" always;
      add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline';" always;
      
      # Rate limiting
      limit_req_zone \$binary_remote_addr zone=global:10m rate=10r/s;
      limit_req zone=global burst=20 nodelay;
      limit_req_status 429;
      
      # Custom error handling
      error_page 404 /404.html;
      error_page 500 502 503 504 /50x.html;
    
    # Enable access logging
    nginx.ingress.kubernetes.io/enable-access-log: "true"
    
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - $DOMAIN
    secretName: $APP_NAME-tls
  rules:
  - host: $DOMAIN
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: $APP_NAME-service
            port:
              number: 80
EOF

echo "⏳ Waiting for deployment to be ready..."
wait_for_resource deployment $APP_NAME $NAMESPACE

echo "🔍 Checking certificate status..."
sleep 30  # Give cert-manager time to process the certificate request

# Check certificate status
echo "📋 Certificate Status:"
kubectl describe certificate $APP_NAME-tls -n $NAMESPACE | grep -A 5 "Status:" || true

echo ""
echo "✅ Production Ingress setup completed successfully!"
echo ""
echo "📊 Status Summary:"
echo "===================="
kubectl get ingress -n $NAMESPACE
echo ""
kubectl get certificates -n $NAMESPACE 2>/dev/null || echo "Certificates: Not available (cert-manager may not be fully configured)"
echo ""
kubectl get pods -n $NAMESPACE

echo ""
echo "🌐 Access Information:"
echo "======================"
echo "Application URL: https://$DOMAIN"
echo "Health Check: https://$DOMAIN/health"
echo "Readiness Check: https://$DOMAIN/ready"
echo ""

echo "📝 Next Steps:"
echo "=============="
echo "1. Ensure DNS points $DOMAIN to your Ingress Controller's external IP"
echo "2. Wait for Let's Encrypt certificate to be issued (may take a few minutes)"
echo "3. Test the application: curl -I https://$DOMAIN"
echo "4. Monitor logs: kubectl logs -f -n $NAMESPACE deployment/$APP_NAME"
echo "5. Check Ingress Controller logs: kubectl logs -f -n ingress-nginx -l app.kubernetes.io/component=controller"
echo ""

echo "🧹 Cleanup Commands:"
echo "===================="
echo "kubectl delete namespace $NAMESPACE"
echo "kubectl delete clusterissuer letsencrypt-prod"
echo ""

echo "🔧 Troubleshooting:"
echo "==================="
echo "kubectl describe ingress $APP_NAME-ingress -n $NAMESPACE"
echo "kubectl describe certificate $APP_NAME-tls -n $NAMESPACE"
echo "kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp'"
EOF
```

## Summary and Key Takeaways

This comprehensive guide has covered Kubernetes Ingress from basic concepts to production-ready implementations. Here are the key points to remember:

### Core Concepts
- **Ingress Controllers** are the actual software that processes traffic and routing rules
- **Ingress Resources** define the routing configuration declaratively
- **Ingress Classes** allow multiple controllers in the same cluster
- **Path Types** (Prefix, Exact, ImplementationSpecific) control how URLs are matched

### Production Best Practices
1. **Security First**: Always use HTTPS, implement security headers, and configure rate limiting
2. **Monitor Everything**: Set up comprehensive logging and metrics collection
3. **Plan for Scale**: Use proper resource limits, health checks, and autoscaling
4. **Automate Certificate Management**: Use cert-manager for automatic certificate provisioning and renewal
5. **Test Thoroughly**: Implement proper health checks and test failure scenarios

### Common Patterns
- **Path-based routing** for microservices architectures
- **Host-based routing** for multi-tenant applications
- **Canary deployments** for safe application updates
- **Geographic routing** for global applications
- **WebSocket support** for real-time applications

### Troubleshooting Approach
1. Check Ingress Controller status and logs
2. Verify DNS resolution and /etc/hosts entries
3. Validate service endpoints and pod readiness
4. Test path matching and annotation syntax
5. Examine certificate status and TLS configuration
6. Monitor resource usage and performance metrics

### Advanced Features Covered
- **Traffic Splitting**: Canary deployments with percentage-based routing
- **Security Hardening**: Comprehensive security headers and access controls
- **Performance Optimization**: Caching, compression, and connection pooling
- **Multi-domain Support**: Wildcard domains and tenant isolation
- **Custom Error Pages**: Branded error handling for better user experience
- **Monitoring Integration**: Prometheus metrics and structured logging

### Architecture Considerations

When designing your Ingress strategy, consider these architectural patterns:

#### Edge Proxy Pattern
Use Ingress as the single entry point for all external traffic, handling concerns like:
- SSL termination and certificate management
- Authentication and authorization
- Rate limiting and DDoS protection
- Request routing and load balancing
- Observability and logging

#### Service Mesh Integration
In complex microservices environments, Ingress often works alongside service mesh solutions:
- **Ingress handles North-South traffic** (external to internal)
- **Service mesh handles East-West traffic** (internal service-to-service)
- Both provide complementary security, observability, and traffic management features

#### Multi-Cluster Scenarios
For organizations running multiple Kubernetes clusters:
- Use external load balancers to distribute traffic across clusters
- Implement consistent Ingress configurations across environments
- Consider GitOps approaches for managing Ingress resources
- Plan for disaster recovery and failover scenarios

## Real-World Implementation Examples

### E-commerce Platform
```yaml
# ecommerce-ingress-example.yaml
# Real-world e-commerce platform with multiple services
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ecommerce-platform-ingress
  annotations:
    # Performance optimizations for high-traffic e-commerce
    nginx.ingress.kubernetes.io/proxy-buffering: "on"
    nginx.ingress.kubernetes.io/proxy-buffer-size: "128k"
    nginx.ingress.kubernetes.io/client-max-body-size: "100m"  # Large file uploads
    
    # Caching strategy for different content types
    nginx.ingress.kubernetes.io/server-snippet: |
      # Static assets - long cache
      location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header Vary "Accept-Encoding";
      }
      
      # Product images - medium cache
      location ~* ^/images/ {
        expires 7d;
        add_header Cache-Control "public";
      }
      
      # API responses - short cache with revalidation
      location ~* ^/api/(products|categories) {
        add_header Cache-Control "public, max-age=300, must-revalidate";
      }
      
      # No cache for user-specific content
      location ~* ^/(cart|checkout|account) {
        add_header Cache-Control "private, no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
        add_header Expires "0";
      }
      
      # Rate limiting for different endpoints
      limit_req_zone $binary_remote_addr zone=api:10m rate=100r/s;
      limit_req_zone $binary_remote_addr zone=search:10m rate=50r/s;
      limit_req_zone $binary_remote_addr zone=checkout:10m rate=10r/s;
      
      # API endpoints - higher rate limit
      location /api/ {
        limit_req zone=api burst=200 nodelay;
      }
      
      # Search functionality - moderate rate limiting
      location /search {
        limit_req zone=search burst=100 nodelay;
      }
      
      # Checkout process - strict rate limiting
      location /checkout {
        limit_req zone=checkout burst=20 nodelay;
      }
      
      # Security headers optimized for e-commerce
      add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
      add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' https://js.stripe.com https://checkout.stripe.com; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; img-src 'self' data: https: blob:; connect-src 'self' https://api.stripe.com; frame-src https://js.stripe.com https://hooks.stripe.com;" always;
      add_header X-Frame-Options "SAMEORIGIN" always;
      add_header X-Content-Type-Options "nosniff" always;
      
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - shop.company.com
    - api.shop.company.com
    - admin.shop.company.com
    secretName: ecommerce-tls
  rules:
  # Main storefront
  - host: shop.company.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: storefront-service
            port:
              number: 80
      - path: /api/
        pathType: Prefix
        backend:
          service:
            name: api-gateway-service
            port:
              number: 80
      - path: /images/
        pathType: Prefix
        backend:
          service:
            name: image-service
            port:
              number: 80
  # API subdomain for mobile apps and third-party integrations
  - host: api.shop.company.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-gateway-service
            port:
              number: 80
  # Admin interface
  - host: admin.shop.company.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: admin-panel-service
            port:
              number: 80
```

### SaaS Platform with Multi-tenancy
```yaml
# saas-platform-ingress.yaml
# Multi-tenant SaaS platform with custom domain support
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: saas-platform-ingress
  annotations:
    # Advanced tenant routing based on subdomain
    nginx.ingress.kubernetes.io/server-snippet: |
      # Extract tenant information from subdomain
      map $host $tenant_id {
        ~^(?<tenant>.+)\.saas\.company\.com$ $tenant;
        default "unknown";
      }
      
      # Add tenant context to all requests
      proxy_set_header X-Tenant-ID $tenant_id;
      add_header X-Served-Tenant $tenant_id always;
      
      # Tenant-specific rate limiting
      limit_req_zone $tenant_id zone=tenant_api:10m rate=1000r/s;
      limit_req_zone $tenant_id zone=tenant_upload:10m rate=10r/s;
      
      # Different limits for different plan tiers (would need external data source)
      # This is a simplified example
      set $rate_limit "tenant_api";
      if ($tenant_id ~ "^(premium|enterprise)") {
        set $rate_limit "premium_api";
      }
      
      location /api/ {
        limit_req zone=$rate_limit burst=100 nodelay;
        
        # Add tenant-specific headers
        proxy_set_header X-Tenant-Plan $rate_limit;
        proxy_set_header X-Original-Host $host;
      }
      
      location /upload/ {
        limit_req zone=tenant_upload burst=5 nodelay;
        client_max_body_size 1G;  # Large file uploads for premium tenants
      }
      
      # Tenant isolation headers
      add_header X-Frame-Options "SAMEORIGIN" always;
      add_header Content-Security-Policy "default-src 'self' https://*.saas.company.com; frame-ancestors 'self' https://*.saas.company.com;" always;
      
    # Custom error pages with tenant branding
    nginx.ingress.kubernetes.io/custom-http-errors: "404,403,500,502,503"
    nginx.ingress.kubernetes.io/default-backend: tenant-error-pages
    
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - "*.saas.company.com"
    - saas.company.com
    secretName: saas-wildcard-tls
  rules:
  # Main marketing site
  - host: saas.company.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: marketing-site-service
            port:
              number: 80
  # Wildcard for tenant subdomains
  - host: "*.saas.company.com"
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: tenant-app-service
            port:
              number: 80
      - path: /api/
        pathType: Prefix
        backend:
          service:
            name: tenant-api-service
            port:
              number: 80
```

## Integration with Cloud Providers

### AWS Application Load Balancer (ALB)
```yaml
# aws-alb-ingress.yaml
# AWS-specific Ingress configuration using ALB Ingress Controller
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: aws-alb-ingress
  annotations:
    # AWS Load Balancer Controller annotations
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/backend-protocol: HTTP
    
    # SSL/TLS configuration
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-west-2:123456789:certificate/12345678-1234-1234-1234-12345678
    alb.ingress.kubernetes.io/ssl-policy: ELBSecurityPolicy-TLS-1-2-2017-01
    alb.ingress.kubernetes.io/ssl-redirect: '443'
    
    # Health check configuration
    alb.ingress.kubernetes.io/healthcheck-protocol: HTTP
    alb.ingress.kubernetes.io/healthcheck-port: traffic-port
    alb.ingress.kubernetes.io/healthcheck-path: /health
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: '15'
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: '5'
    alb.ingress.kubernetes.io/success-codes: '200'
    alb.ingress.kubernetes.io/healthy-threshold-count: '2'
    alb.ingress.kubernetes.io/unhealthy-threshold-count: '2'
    
    # AWS-specific features
    alb.ingress.kubernetes.io/load-balancer-name: production-app-alb
    alb.ingress.kubernetes.io/tags: Environment=production,Team=platform,Cost-Center=engineering
    alb.ingress.kubernetes.io/security-groups: sg-12345678,sg-87654321
    alb.ingress.kubernetes.io/subnets: subnet-12345678,subnet-87654321
    
    # WAF integration
    alb.ingress.kubernetes.io/wafv2-acl-arn: arn:aws:wafv2:us-west-2:123456789:regional/webacl/production-waf/12345678
    
spec:
  rules:
  - host: app.company.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: production-app-service
            port:
              number: 80
```

### Google Cloud Load Balancer
```yaml
# gcp-ingress.yaml
# Google Cloud-specific Ingress configuration
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: gcp-global-ingress
  annotations:
    # GCP-specific annotations
    kubernetes.io/ingress.class: "gce"
    kubernetes.io/ingress.global-static-ip-name: "production-global-ip"
    
    # Managed SSL certificates
    networking.gke.io/managed-certificates: "production-ssl-cert"
    
    # Cloud Armor security policy
    cloud.google.com/armor-config: '{"production-armor-policy": "production-security-policy"}'
    
    # Backend configuration
    cloud.google.com/backend-config: '{"default": "production-backend-config"}'
    
    # CDN configuration
    kubernetes.io/ingress.global-static-ip-name: "production-global-ip"
    
spec:
  rules:
  - host: app.company.com
    http:
      paths:
      - path: /*
        pathType: ImplementationSpecific
        backend:
          service:
            name: production-app-service
            port:
              number: 80
---
# Backend configuration for GCP
apiVersion: cloud.google.com/v1
kind: BackendConfig
metadata:
  name: production-backend-config
spec:
  # Health check configuration
  healthCheck:
    checkIntervalSec: 15
    timeoutSec: 5
    healthyThreshold: 2
    unhealthyThreshold: 3
    type: HTTP
    requestPath: /health
    port: 80
  
  # Connection draining
  connectionDraining:
    drainingTimeoutSec: 60
  
  # Session affinity
  sessionAffinity:
    affinityType: "CLIENT_IP"
    affinityCookieTtlSec: 3600
  
  # Cloud CDN
  cdn:
    enabled: true
    cachePolicy:
      includeHost: true
      includeProtocol: true
      includeQueryString: false
    negativeCaching: true
    negativeCachingPolicy:
    - code: 404
      ttl: 120
    - code: 500
      ttl: 60
---
# Managed SSL certificate
apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata:
  name: production-ssl-cert
spec:
  domains:
    - app.company.com
    - www.app.company.com
```

## GitOps and Infrastructure as Code

### Helm Chart for Ingress Resources
```yaml
# helm-chart/templates/ingress.yaml
# Parameterized Ingress template for different environments
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "myapp.fullname" . }}-ingress
  namespace: {{ .Values.namespace }}
  labels:
    {{- include "myapp.labels" . | nindent 4 }}
  annotations:
    {{- if .Values.ingress.certManager.enabled }}
    cert-manager.io/cluster-issuer: {{ .Values.ingress.certManager.clusterIssuer }}
    {{- end }}
    {{- if .Values.ingress.nginx.enabled }}
    nginx.ingress.kubernetes.io/ssl-redirect: "{{ .Values.ingress.ssl.redirect }}"
    nginx.ingress.kubernetes.io/proxy-body-size: {{ .Values.ingress.nginx.proxyBodySize }}
    {{- if .Values.ingress.rateLimit.enabled }}
    nginx.ingress.kubernetes.io/rate-limit-requests-per-second: "{{ .Values.ingress.rateLimit.rps }}"
    nginx.ingress.kubernetes.io/rate-limit-window: "{{ .Values.ingress.rateLimit.window }}"
    {{- end }}
    {{- range $key, $value := .Values.ingress.annotations }}
    {{ $key }}: {{ $value | quote }}
    {{- end }}
    {{- end }}
spec:
  ingressClassName: {{ .Values.ingress.className }}
  {{- if .Values.ingress.tls.enabled }}
  tls:
  {{- range .Values.ingress.hosts }}
  - hosts:
    {{- range .hosts }}
    - {{ . }}
    {{- end }}
    secretName: {{ .tlsSecretName | default (printf "%s-tls" .name) }}
  {{- end }}
  {{- end }}
  rules:
  {{- range .Values.ingress.hosts }}
  - host: {{ .host }}
    http:
      paths:
      {{- range .paths }}
      - path: {{ .path }}
        pathType: {{ .pathType | default "Prefix" }}
        backend:
          service:
            name: {{ .serviceName }}
            port:
              number: {{ .servicePort }}
      {{- end }}
  {{- end }}
```

```yaml
# helm-chart/values-production.yaml
# Production values for the Helm chart
namespace: production

ingress:
  enabled: true
  className: nginx
  
  # Certificate management
  certManager:
    enabled: true
    clusterIssuer: letsencrypt-prod
  
  # TLS configuration
  tls:
    enabled: true
  
  # SSL settings
  ssl:
    redirect: true
  
  # NGINX-specific settings
  nginx:
    enabled: true
    proxyBodySize: "100m"
  
  # Rate limiting
  rateLimit:
    enabled: true
    rps: 100
    window: "1m"
  
  # Custom annotations
  annotations:
    nginx.ingress.kubernetes.io/server-snippet: |
      add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
      add_header X-Frame-Options "SAMEORIGIN" always;
      add_header X-Content-Type-Options "nosniff" always;
      add_header X-XSS-Protection "1; mode=block" always;
  
  # Host configuration
  hosts:
  - name: main
    host: app.company.com
    paths:
    - path: /
      pathType: Prefix
      serviceName: myapp-service
      servicePort: 80
    - path: /api/
      pathType: Prefix
      serviceName: myapp-api-service
      servicePort: 80
    hosts:
    - app.company.com
    - www.app.company.com
    tlsSecretName: myapp-main-tls
```

## Conclusion

Kubernetes Ingress is a powerful and flexible system for managing HTTP and HTTPS traffic into your cluster. This comprehensive guide has covered everything from basic concepts to advanced production patterns, providing you with the knowledge and tools needed to implement robust, secure, and scalable ingress solutions.

### Key Success Factors

1. **Start Simple**: Begin with basic HTTP routing and gradually add complexity
2. **Security by Design**: Implement HTTPS, security headers, and rate limiting from the beginning
3. **Monitor Everything**: Set up comprehensive observability from day one
4. **Automate Certificate Management**: Use cert-manager for production deployments
5. **Plan for Scale**: Design your ingress architecture with growth in mind
6. **Test Thoroughly**: Implement proper health checks and test failure scenarios
7. **Document Your Setup**: Maintain clear documentation of your ingress configuration and troubleshooting procedures

### Future Considerations

As Kubernetes and the ingress ecosystem continue to evolve, keep an eye on emerging technologies and patterns:

- **Gateway API**: The next-generation replacement for Ingress with more advanced routing capabilities
- **Service Mesh Integration**: Combining ingress with service mesh for comprehensive traffic management
- **Edge Computing**: Extending ingress capabilities to edge locations for improved performance
- **Advanced Security**: Integration with Web Application Firewalls (WAF) and advanced threat detection
- **Multi-Cloud Strategies**: Managing ingress across multiple cloud providers and hybrid environments

Remember that ingress is often the first point of contact between your users and your applications. Investing time in properly configuring and monitoring your ingress infrastructure will pay dividends in application reliability, security, and user experience.

The examples and patterns provided in this guide should serve as a solid foundation for your ingress implementations. Adapt them to your specific requirements, and don't hesitate to experiment with different configurations to find what works best for your use case.