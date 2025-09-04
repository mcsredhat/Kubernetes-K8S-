# Unit 1: Kubernetes Secrets Fundamentals

## Learning Objectives
By the end of this unit, you will:
- Understand what Kubernetes Secrets are and why they exist
- Distinguish between Secrets and ConfigMaps
- Identify the security benefits and limitations of Secrets
- Create your first Secret using imperative commands

## The Problem: Where Do Passwords Go?

Imagine you're deploying a web application that needs to connect to a database. Your app needs:
- Database username and password
- API keys for external services
- SSL certificates for HTTPS

**Question for you**: Where would you store these sensitive values in a traditional deployment? What are the risks of each approach?

Think about these common (but problematic) approaches:
- Hardcoding in application source code
- Environment variables in Docker images
- Configuration files in version control
- Plain text files on the server

## Enter Kubernetes Secrets

Secrets provide a dedicated, more secure way to handle sensitive data in Kubernetes. They're designed specifically for confidential information, unlike ConfigMaps which are for general configuration.

### Key Differences: Secrets vs ConfigMaps

| Aspect | ConfigMaps | Secrets |
|--------|------------|---------|
| Purpose | Non-sensitive configuration | Sensitive data |
| Storage | Plain text | Base64 encoded |
| Encryption | None | Can be encrypted at rest |
| RBAC | Standard permissions | More restrictive by default |
| Visibility | Visible in kubectl describe | Values hidden by default |

## Mini-Project 1: Your First Secret

Let's create a simple Secret for a database connection:

```bash
# Create a Secret with database credentials
kubectl create secret generic my-database-secret \
  --from-literal=username=myapp_user \
  --from-literal=password=super_secure_password_123

# Examine what was created
kubectl get secrets
kubectl describe secret my-database-secret
```

**Try this now**, then answer:
1. What do you notice about how the password is displayed (or not displayed)?
2. How many data entries does your Secret contain?

### Looking Deeper

```bash
# See the actual encoded values (be careful in production!)
kubectl get secret my-database-secret -o yaml

# Decode a value to verify it worked
kubectl get secret my-database-secret -o jsonpath='{.data.password}' | base64 -d
```

**Important Security Note**: Base64 is encoding, NOT encryption. Anyone who can view the Secret can easily decode it.

## Hands-On Exercise

Create a Secret for an imaginary e-commerce application that needs:
- Database password: `ecommerce_db_pass_456`
- Stripe API key: `sk_test_1234567890`
- JWT signing secret: `my_jwt_secret_xyz`

Name your Secret `ecommerce-secrets`.

**Challenge Questions**:
1. How would you verify all three values are stored correctly?
2. What command would show you just the Secret names without values?
3. How would you delete this Secret when you're done testing?

## Reflection Questions

Before moving to the next unit, consider:
- What makes Secrets more secure than plain environment variables?
- In what scenarios might base64 encoding alone be insufficient?
- How do you think applications will actually use these Secret values?

## Next Steps

In Unit 2, we'll explore the different types of Secrets and learn how to create them from files and YAML manifests. We'll also build our first application that actually consumes Secret data.

---

**Prerequisites for Unit 2**: Make sure you can successfully create and examine Secrets using the commands above.