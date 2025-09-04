# Unit 2: Secret Types and Creation Methods

## Learning Objectives
- Master all three Secret creation methods (literal, file, YAML)
- Understand different Secret types and their specific use cases
- Create Docker registry credentials for private image access
- Build TLS Secrets for HTTPS applications
- Practice with a multi-secret application scenario

## Pre-Unit Challenge

Before we dive in, let's check your understanding from Unit 1:

**Quick Test**: Create a Secret called `quiz-secret` with a key `answer` containing the value `kubernetes-rocks`. Then, without looking at your notes, decode the value to verify it's correct.

How did that go? What commands did you use?

## Secret Types: Choosing the Right Tool

Kubernetes offers several Secret types, each optimized for specific use cases. Think of them as specialized containers for different kinds of sensitive data.

### 1. Generic Secrets (type: Opaque)
The "Swiss Army knife" of Secrets - handles any key-value data.

### 2. Docker Registry Secrets (type: kubernetes.io/dockerconfigjson)
Specialized for container registry authentication.

### 3. TLS Secrets (type: kubernetes.io/tls)
Designed specifically for SSL/TLS certificates.

**Prediction Question**: Why do you think Kubernetes provides these specialized types instead of just using generic Secrets for everything?

## Creation Method Deep Dive

### Method 1: From Literal Values (Command Line)

You already tried this! But let's explore its strengths and weaknesses:

```bash
# Quick and direct - great for testing
kubectl create secret generic app-config \
  --from-literal=database-host=postgres.example.com \
  --from-literal=database-port=5432 \
  --from-literal=api-timeout=30

# Multiple secrets in one command
kubectl create secret generic social-auth \
  --from-literal=google-client-id=123456789 \
  --from-literal=google-client-secret=abc-xyz-secret \
  --from-literal=github-oauth-token=ghp_token_here
```

**Think About It**: When would this method be inappropriate or risky?

### Method 2: From Files (More Secure)

Files keep sensitive data out of command history and process lists:

```bash
# Create files with sensitive data
echo -n "my-production-db-password" > db-password.txt
echo -n "sk-live-stripe-key-xyz" > stripe-api-key.txt

# Create Secret from files
kubectl create secret generic production-secrets \
  --from-file=database-password=db-password.txt \
  --from-file=stripe-key=stripe-api-key.txt

# IMPORTANT: Clean up immediately
rm db-password.txt stripe-api-key.txt
```

**Security Note**: The `-n` flag prevents newline characters that can break authentication.

### Method 3: YAML Manifests (Declarative)

For production and GitOps workflows:

```yaml
# app-secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: declarative-secrets
  namespace: production
type: Opaque
data:
  # Values must be base64 encoded
  username: bXlhcHBfdXNlcg==  # myapp_user
  password: c3VwZXJfc2VjdXJl  # super_secure
stringData:
  # Plain text - Kubernetes encodes automatically
  api-endpoint: "https://api.production.example.com"
```

```bash
kubectl apply -f app-secrets.yaml
```

**Critical Question**: What's the security risk with YAML Secret manifests? How would you handle this in a real GitOps workflow?

## Mini-Project 2: Docker Registry Secret

Let's create credentials for a private Docker registry:

```bash
# Create registry credentials
kubectl create secret docker-registry private-repo-creds \
  --docker-server=registry.mycompany.com \
  --docker-username=deploy-user \
  --docker-password=registry-password-456 \
  --docker-email=devops@mycompany.com

# Examine the structure
kubectl get secret private-repo-creds -o yaml
```

**Exploration Questions**:
1. What's different about the structure compared to generic Secrets?
2. What key name contains the credential data?
3. How would you decode and examine the Docker config JSON?

## Mini-Project 3: TLS Certificate Secret

Generate and store TLS certificates:

```bash
# Generate a self-signed certificate (for testing only!)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout myapp.key -out myapp.crt \
  -subj "/CN=myapp.example.com"

# Create TLS Secret
kubectl create secret tls myapp-tls \
  --cert=myapp.crt \
  --key=myapp.key

# Examine the result
kubectl describe secret myapp-tls

# Clean up certificate files
rm myapp.key myapp.crt
```

**Analysis Questions**:
1. What are the standardized key names in TLS Secrets?
2. Why might Ingress controllers expect this specific format?
3. How would this differ in production with a real CA-signed certificate?

## Comprehensive Exercise: Multi-Application Scenario

You're deploying a complete e-commerce stack that needs:

1. **Database credentials** (generic Secret)
   - Username: `ecommerce_user`
   - Password: `db_production_pass_789`
   - Host: `postgres.cluster.local`

2. **API integration** (generic Secret)
   - Stripe key: `sk_live_stripe_production_key`
   - SendGrid key: `SG.production.email.key`
   - OAuth secret: `oauth_client_secret_xyz`

3. **Private registry access** (docker-registry Secret)
   - Server: `ecr.us-west-2.amazonaws.com`
   - Username: `AWS`
   - Password: `temporary-ecr-token`
   - Email: `unused`

4. **TLS certificate** (tls Secret)
   - Generate for domain: `shop.example.com`

**Your Challenge**: Create all four Secrets using different methods:
- Use literals for the database Secret
- Use files for the API Secret
- Use the specialized docker-registry command
- Use openssl + tls command for certificates

**Verification Steps**:
1. List all your Secrets
2. Describe each one to verify the structure
3. Decode one value from each Secret to confirm correctness

**Reflection Questions**:
1. Which creation method felt most natural for each Secret type?
2. What security considerations did you have to think about?
3. How would you automate this process for multiple environments?

## Looking Ahead

In Unit 3, we'll learn how applications actually consume these Secrets through environment variables and volume mounts. We'll build a real application that uses all the Secrets you just created!

**Preparation Question**: How do you think a pod specification would reference these Secrets? What are some ways applications typically read sensitive configuration data?