# Unit 3: Consuming Secrets in Applications

## Learning Objectives
- Master the two primary methods of consuming Secrets: environment variables and volume mounts
- Build working applications that use Secret data
- Understand the security and practical implications of each consumption method
- Create a complete application deployment using multiple Secrets

## Pre-Unit Reflection

Before diving into consumption patterns, let's think about what you already know:

**Reflection Questions**:
1. From your experience with applications (Kubernetes or otherwise), how do applications typically receive configuration data?
2. What are the pros and cons of environment variables vs configuration files for sensitive data?
3. If you were designing an application, which approach would feel more natural to you and why?

Take a moment to consider these questions - your intuitions here will help guide how you think about Secret consumption patterns.

## The Two Consumption Patterns

When applications need to access Secret data, Kubernetes provides two main approaches. Before I explain them, what do you think these two approaches might be?

<details>
<summary>Click after you've thought about it</summary>

The two primary patterns are:
1. **Environment Variables**: Inject Secret values directly into container environment
2. **Volume Mounts**: Mount Secret data as files in the container filesystem

</details>

## Pattern 1: Environment Variables

Many applications expect sensitive configuration through environment variables. Let's build this step by step.

### Building Your First Secret-Consuming Pod

First, let's start with something simple. Can you predict what this pod specification will do?

```yaml
# simple-secret-consumer.yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-consumer
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'echo "Username: $DB_USERNAME"; echo "Password: $DB_PASSWORD"; sleep 3600']
    env:
    - name: DB_USERNAME
      valueFrom:
        secretKeyRef:
          name: my-database-secret  # From Unit 1
          key: username
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: my-database-secret
          key: password
```

**Before you run this**, walk through the YAML:
- What environment variables will be available in the container?
- Where is the data coming from?
- What do you expect to see when you check the pod logs?

Now let's test your prediction:

```bash
kubectl apply -f simple-secret-consumer.yaml
kubectl logs secret-consumer
```

**Analysis Questions**:
1. Did the output match your prediction?
2. What happens if you reference a Secret that doesn't exist?
3. What happens if you reference a key that doesn't exist in the Secret?

### Bulk Environment Variable Loading

Sometimes you want to load all Secret keys as environment variables. Let's explore this:

```yaml
# bulk-secret-consumer.yaml
apiVersion: v1
kind: Pod
metadata:
  name: bulk-secret-consumer
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'env | grep -E "(DB_|API_)"; sleep 3600']
    envFrom:
    - secretRef:
        name: ecommerce-secrets  # From Unit 2
        prefix: API_
    - secretRef:
        name: my-database-secret
        prefix: DB_
```

**Prediction Challenge**: 
- How many environment variables do you expect this container to have from Secrets?
- What will their names be?
- Why might the prefix be useful?

## Pattern 2: Volume Mounts (File-Based Access)

Some applications prefer reading sensitive data from files. Let's explore why and how.

**Discussion**: Can you think of scenarios where files might be preferable to environment variables for sensitive data?

<details>
<summary>Some considerations</summary>

Files might be better when:
- Dealing with large certificates or complex configuration
- Applications that support file-based configuration reloading
- More restrictive file permissions are needed
- Avoiding exposure in process environment listings

</details>

### Building a File-Based Secret Consumer

```yaml
# file-secret-consumer.yaml
apiVersion: v1
kind: Pod
metadata:
  name: file-secret-consumer
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'ls -la /etc/secrets/; cat /etc/secrets/*; sleep 3600']
    volumeMounts:
    - name: secret-volume
      mountPath: /etc/secrets
      readOnly: true
  volumes:
  - name: secret-volume
    secret:
      secretName: my-database-secret
      defaultMode: 0400  # Read-only for owner
```

**Before running this**, analyze:
1. Where will the Secret data appear in the container?
2. What filenames do you expect to see?
3. What do you think `defaultMode: 0400` does?

Test your understanding:
```bash
kubectl apply -f file-secret-consumer.yaml
kubectl logs file-secret-consumer
```

**Follow-up Exploration**:
```bash
# Interactively explore the mounted files
kubectl exec -it file-secret-consumer -- sh
# Inside the container:
# ls -la /etc/secrets/
# cat /etc/secrets/username
# cat /etc/secrets/password
```

## Mini-Project 4: Real Application with Multiple Secrets

Now let's build something more realistic. We'll create a web application that uses multiple Secrets through different consumption methods.

First, let's think through the requirements:

**Scenario**: You're deploying a web API that needs:
- Database credentials (environment variables - common pattern)
- TLS certificates (files - required for HTTPS)
- API keys for external services (your choice of method)

**Planning Questions**:
1. Which consumption method makes most sense for each type of secret?
2. How would you organize the volume mounts if using files?
3. What security considerations should influence your choices?

Here's a realistic deployment:

```yaml
# realistic-web-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-web-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: secure-web-app
  template:
    metadata:
      labels:
        app: secure-web-app
    spec:
      containers:
      - name: web-app
        image: nginx:alpine
        ports:
        - containerPort: 443
          name: https
        - containerPort: 80
          name: http
        # Database credentials via environment variables
        env:
        - name: DB_HOST
          valueFrom:
            secretKeyRef:
              name: ecommerce-secrets
              key: database-host
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: ecommerce-secrets
              key: database-password
        # Bulk load API keys with prefix
        envFrom:
        - secretRef:
            name: ecommerce-secrets
            prefix: API_
        # Mount TLS certificates as files
        volumeMounts:
        - name: tls-certs
          mountPath: /etc/ssl/certs/app
          readOnly: true
        - name: nginx-config
          mountPath: /etc/nginx/conf.d
      volumes:
      - name: tls-certs
        secret:
          secretName: myapp-tls
          defaultMode: 0400
      - name: nginx-config
        configMap:
          name: nginx-ssl-config
---
# ConfigMap for nginx SSL configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-ssl-config
data:
  default.conf: |
    server {
        listen 443 ssl;
        ssl_certificate /etc/ssl/certs/app/tls.crt;
        ssl_certificate_key /etc/ssl/certs/app/tls.key;
        
        location / {
            return 200 'Hello from Secure App!\nDB Host: $DB_HOST\nAPI Keys Available: $API_STRIPE_KEY';
            add_header Content-Type text/plain;
        }
        
        location /env {
            return 200 'Environment Variables:\n$DB_HOST\n$DB_PASSWORD\n$API_STRIPE_KEY';
            add_header Content-Type text/plain;
        }
    }
```

**Implementation Challenge**:
1. Deploy this application using your Secrets from previous units
2. Verify it can access the Secret data correctly
3. Identify any missing Secrets and create them

**Testing Your Deployment**:
```bash
# Check if pods are running
kubectl get pods -l app=secure-web-app

# Examine the environment variables
kubectl exec deployment/secure-web-app -- env | grep -E "(DB_|API_)"

# Check mounted certificate files
kubectl exec deployment/secure-web-app -- ls -la /etc/ssl/certs/app/

# Test the application
kubectl port-forward deployment/secure-web-app 8443:443
# Then access https://localhost:8443 (accept the self-signed certificate warning)
```

## Troubleshooting Exercise

Let's practice debugging common Secret consumption issues. I'll give you some broken examples, and you identify what's wrong:

**Broken Example 1**:
```yaml
env:
- name: DATABASE_URL
  valueFrom:
    secretKeyRef:
      name: db-secret
      key: database-url  # This key doesn't exist in the Secret
```

**Broken Example 2**:
```yaml
volumeMounts:
- name: api-keys
  mountPath: /etc/api-keys
volumes:
- name: api-keys
  secret:
    secretName: api-secrets
    defaultMode: 0777  # Overly permissive!
```

**Your Debugging Task**: 
1. What issues can you identify in each example?
2. How would you fix them?
3. What symptoms would you see if you deployed these configurations?

## Advanced Pattern: Selective File Mounting

Sometimes you only want specific keys from a Secret as files:

```yaml
volumes:
- name: selective-secrets
  secret:
    secretName: multi-key-secret
    items:
    - key: database-password
      path: db_pass
      mode: 0400
    - key: api-key
      path: api_key
      mode: 0400
    # Other keys in the secret won't be mounted
```

**Exploration Questions**:
1. When might you want to mount only specific keys?
2. How does this differ from mounting the entire Secret?
3. What security benefits does this provide?

## Unit 3 Comprehensive Challenge

Deploy a complete application stack that demonstrates mastery of Secret consumption:

**Requirements**:
1. Create a multi-tier application (frontend + backend + database simulation)
2. Use at least 3 different Secrets
3. Demonstrate both environment variable and file-based consumption
4. Include proper security practices (read-only mounts, appropriate permissions)
5. Implement proper error handling for missing Secrets

**Architecture Suggestion**:
- **Frontend**: Nginx with TLS certificates (files) + API endpoint configs (env vars)
- **Backend**: Application with database credentials (env vars) + external service API keys (files)
- **Monitoring**: Sidecar container that reads config from mounted Secret files

**Success Criteria**:
- All pods start successfully
- Applications can access their required Secret data
- Demonstrate both consumption methods
- Show proper security configurations

## Reflection and Next Steps

Before moving to Unit 4, reflect on:

1. **Pattern Preferences**: Which consumption method felt more natural to you? When would you choose one over the other?

2. **Security Implications**: What security considerations did you encounter? How did file permissions and mount options affect security?

3. **Operational Complexity**: How did managing multiple consumption methods affect the complexity of your deployments?

4. **Real-World Application**: How would these patterns apply to applications you've worked with or might work with in the future?

In Unit 4, we'll explore advanced Secret management patterns including multi-environment configurations, Secret rotation strategies, and integration with external secret management systems.

**Preparation Thinking**: How do you think Secret management might differ between development, staging, and production environments? What challenges might arise as your application scales?