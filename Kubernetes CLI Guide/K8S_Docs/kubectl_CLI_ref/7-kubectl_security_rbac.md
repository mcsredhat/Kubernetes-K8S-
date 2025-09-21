# Security and RBAC

Security is paramount in production Kubernetes environments. These commands help you understand and manage authentication, authorization, and security contexts effectively.

## Permission and Access Verification
```bash
# Check current user permissions
kubectl auth can-i create deployments                             # Test deployment creation
kubectl auth can-i delete pods --all-namespaces                   # Test cluster-wide pod deletion
kubectl auth can-i get secrets --namespace kube-system            # Test system secrets access
kubectl auth can-i create clusterroles                           # Test cluster role creation
kubectl auth can-i '*' '*'                                       # Test admin access
kubectl auth can-i list pods --as=system:serviceaccount:default:default  # Test as service account

# Advanced permission testing with specific resources
kubectl auth can-i create pods --as=system:serviceaccount:webapp:webapp-sa  # Specific service account test
kubectl auth can-i get pods --subresource=log                    # Test subresource access
kubectl auth can-i create pods --resource=pods --verb=create     # Explicit verb testing
kubectl auth can-i impersonate users --as=admin                  # Test impersonation rights

# Permission discovery and enumeration
kubectl auth can-i --list                                        # List all allowed actions
kubectl auth can-i --list --namespace=<namespace>                # Namespace-specific permissions
kubectl auth can-i --list --as=system:serviceaccount:<namespace>:<sa-name>  # Service account permissions
kubectl auth can-i --list --as=system:serviceaccount:kube-system:default    # System service account

# User and authentication information
kubectl config current-context                                   # Current context
kubectl config view --minify --raw -o jsonpath='{.users[0].name}' # Current user name
kubectl config view --minify -o jsonpath='{.contexts[0].context.user}'  # Context user
kubectl auth whoami                                              # Current user identity (if supported)

# Certificate and token inspection
kubectl config view --raw -o jsonpath='{.users[0].user.client-certificate-data}' | base64 -d | openssl x509 -text  # Decode client certificate
kubectl get secret $(kubectl get serviceaccount default -o jsonpath='{.secrets[0].name}') -o jsonpath='{.data.token}' | base64 -d  # Service account token
```

## Service Account Management and Security
```bash
# Service account operations
kubectl get serviceaccounts                           # List service accounts in current namespace
kubectl get serviceaccounts --all-namespaces          # All service accounts cluster-wide
kubectl get sa                                        # Shorthand for serviceaccounts
kubectl describe serviceaccount <sa-name>             # Service account details
kubectl create serviceaccount <sa-name>               # Create service account
kubectl delete serviceaccount <sa-name>               # Delete service account

# Service account token and secret management
kubectl create token <sa-name>                        # Create token for service account
kubectl create token <sa-name> --duration=1h          # Token with custom duration
kubectl create token <sa-name> --audience=api         # Token with specific audience
kubectl create token <sa-name> --bound-object-kind=Pod --bound-object-name=<pod-name>  # Bound token

# Legacy token secrets (pre-1.24)
kubectl get secret <sa-token-secret> -o yaml          # View service account token secret
kubectl get secret <sa-token-secret> -o jsonpath='{.data.token}' | base64 -d  # Decode token

# Service account annotations and labels
kubectl annotate serviceaccount <sa-name> eks.amazonaws.com/role-arn=arn:aws:iam::ACCOUNT:role/ROLE  # AWS IAM role annotation
kubectl label serviceaccount <sa-name> app=webapp version=v1.0  # Add labels

# Binding service accounts to roles
kubectl create rolebinding <binding-name> --clusterrole=<role> --serviceaccount=<namespace>:<sa-name>
kubectl create clusterrolebinding <binding-name> --clusterrole=<role> --serviceaccount=<namespace>:<sa-name>
kubectl create rolebinding <binding-name> --role=<role> --serviceaccount=<namespace>:<sa-name> --namespace=<target-namespace>
```

## RBAC Analysis and Management
```bash
# Role and binding discovery
kubectl get roles,rolebindings --all-namespaces               # All roles and bindings
kubectl get clusterroles,clusterrolebindings                  # Cluster-wide roles and bindings
kubectl get roles -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,RESOURCES:.rules[*].resources,VERBS:.rules[*].verbs
kubectl describe clusterrole cluster-admin                    # Cluster admin permissions
kubectl describe clusterrole view                             # View role permissions
kubectl describe clusterrole edit                             # Edit role permissions

# Advanced role analysis
kubectl get clusterroles -o custom-columns=NAME:.metadata.name,RESOURCES:.rules[*].resources | grep pods  # Roles with pod access
kubectl get clusterrole system:node -o yaml                   # Node permissions
kubectl get clusterrole system:kube-scheduler -o yaml         # Scheduler permissions

# Role binding analysis and inspection
kubectl describe rolebinding <binding-name>                   # Role binding details
kubectl describe clusterrolebinding <binding-name>            # Cluster role binding details
kubectl get rolebindings -o wide                             # Role bindings with subjects
kubectl get clusterrolebindings -o wide                      # Cluster role bindings with subjects
kubectl get rolebindings -o custom-columns=NAME:.metadata.name,ROLE:.roleRef.name,SUBJECTS:.subjects[*].name

# Advanced binding queries
kubectl get rolebindings,clusterrolebindings --all-namespaces -o json | \
  jq '.items[] | select(.subjects[]?.name=="<user-or-sa-name>") | {kind: .kind, name: .metadata.name, namespace: .metadata.namespace, role: .roleRef.name}'

# Find all bindings for a specific subject
kubectl get rolebindings,clusterrolebindings --all-namespaces -o custom-columns=KIND:.kind,NAMESPACE:.metadata.namespace,NAME:.metadata.name,SUBJECTS:.subjects[*].name,ROLE:.roleRef.name | grep <subject-name>

# RBAC matrix analysis
kubectl auth reconcile --filename rbac.yaml --dry-run=client  # Test RBAC configuration
kubectl create role test-role --verb=get,list --resource=pods --dry-run=client -o yaml  # Generate role YAML
kubectl create rolebinding test-binding --role=test-role --user=testuser --dry-run=client -o yaml  # Generate binding YAML
```

## Pod Security Standards (PSS) and Security Contexts
```bash
# Pod Security Standards implementation
kubectl label namespace <namespace> pod-security.kubernetes.io/enforce=restricted  # Apply security standard
kubectl label namespace <namespace> pod-security.kubernetes.io/audit=restricted    # Audit mode
kubectl label namespace <namespace> pod-security.kubernetes.io/warn=restricted     # Warning mode
kubectl label namespace <namespace> pod-security.kubernetes.io/enforce-version=latest  # Specific version

# Security context analysis
kubectl get pods -o custom-columns=NAME:.metadata.name,USER:.spec.securityContext.runAsUser,GROUP:.spec.securityContext.runAsGroup,FS-GROUP:.spec.securityContext.fsGroup
kubectl get pods -o custom-columns=NAME:.metadata.name,PRIVILEGED:.spec.containers[0].securityContext.privileged,ROOT:.spec.containers[0].securityContext.runAsUser
kubectl describe pod <pod-name> | grep -A 15 "Security Context"  # Detailed security settings

# Container security capabilities
kubectl get pod <pod-name> -o jsonpath='{.spec.containers[*].securityContext.capabilities}'
kubectl describe pod <pod-name> | grep -A 5 -B 5 "Capabilities"  # Capability settings
kubectl get pods -o custom-columns=NAME:.metadata.name,CAPS-ADD:.spec.containers[0].securityContext.capabilities.add,CAPS-DROP:.spec.containers[0].securityContext.capabilities.drop

# Security context constraints and policies
kubectl get pods -o custom-columns=NAME:.metadata.name,READ-ONLY-FS:.spec.containers[0].securityContext.readOnlyRootFilesystem,ALLOW-PRIV-ESC:.spec.containers[0].securityContext.allowPrivilegeEscalation
kubectl get pods --field-selector=spec.securityContext.runAsUser=0  # Pods running as root

# Security violations and warnings
kubectl get events --field-selector reason=FailedCreate | grep -i "security\|policy"  # Security-related creation failures
kubectl get events --field-selector type=Warning | grep -i "security\|privileged"    # Security warnings
```

## Network Security and Policies
```bash
# Network policy management
kubectl get networkpolicies --all-namespaces              # All network policies
kubectl get netpol                                        # Shorthand for networkpolicies
kubectl describe networkpolicy <policy-name>              # Network policy details
kubectl get networkpolicies -o custom-columns=NAME:.metadata.name,NAMESPACE:.metadata.namespace,POD-SELECTOR:.spec.podSelector.matchLabels

# Network policy testing and validation
kubectl get pods --show-labels | grep <policy-selector>   # Pods affected by network policy
kubectl run policy-test --image=busybox --rm -it --restart=Never --labels="app=test" -- wget -qO- http://<service-name>  # Test with specific labels
kubectl exec -it <pod-name> -- timeout 5 wget -qO- http://<blocked-service> || echo "Connection blocked by policy"  # Policy validation

# Advanced network policy analysis
kubectl get networkpolicy <policy-name> -o yaml | grep -A 10 "ingress\|egress"  # Policy rules
kubectl get pods -l <network-policy-selector> -o wide     # Pods matched by policy
kubectl describe endpoints <service-name> | grep -A 5 "Addresses"  # Endpoint addresses for policy testing

# Network policy creation examples
kubectl create -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF

# Test network connectivity with policy
kubectl run netpol-test --image=busybox --rm -it --restart=Never -- sh -c "timeout 5 wget -qO- http://kubernetes.default.svc.cluster.local || echo 'Connection denied'"
```

## Secrets Management and Security
```bash
# Secret inspection and management
kubectl get secrets                                        # List secrets in current namespace
kubectl get secrets --all-namespaces                      # All secrets cluster-wide
kubectl describe secret <secret-name>                     # Secret details (without values)
kubectl get secret <secret-name> -o yaml                  # Full secret (includes base64 values)

# Secret type analysis
kubectl get secrets -o custom-columns=NAME:.metadata.name,TYPE:.type,DATA:.data
kubectl get secrets --field-selector type=kubernetes.io/tls  # TLS secrets
kubectl get secrets --field-selector type=Opaque           # Opaque secrets
kubectl get secrets -l app=<app-name>                      # Application-specific secrets

# Secret value extraction and decoding
kubectl get secret <secret-name> -o jsonpath='{.data}' | jq -r 'to_entries[] | "\(.key): \(.value | @base64d)"'  # Decode all keys
kubectl get secret <secret-name> -o jsonpath='{.data.<key-name>}' | base64 -d  # Decode specific key
kubectl view-secret <secret-name> <key-name>               # If kubectl-view-secret plugin is installed

# Secret security analysis
kubectl get secrets -o json | jq '.items[] | select(.metadata.name | test("token|password|key")) | .metadata.name'  # Potentially sensitive secrets
kubectl get pods -o custom-columns=NAME:.metadata.name,SECRET-VOLS:.spec.volumes[?(@.secret)].secret.secretName,SECRET-ENVS:.spec.containers[*].env[?(@.valueFrom.secretKeyRef)].valueFrom.secretKeyRef.name

# Certificate and TLS secret analysis
kubectl get secrets --field-selector type=kubernetes.io/tls -o custom-columns=NAME:.metadata.name,NAMESPACE:.metadata.namespace
kubectl get secret <tls-secret> -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout  # Certificate details
kubectl get secret <tls-secret> -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -enddate -noout  # Certificate expiration
```

## Admission Controllers and Security Policies
```bash
# Admission controller information
kubectl get mutatingwebhookconfigurations                  # Mutating admission webhooks
kubectl get validatingwebhookconfigurations               # Validating admission webhooks
kubectl describe mutatingwebhookconfiguration <name>      # Webhook details
kubectl describe validatingwebhookconfiguration <name>    # Validation webhook details

# OPA Gatekeeper policies (if installed)
kubectl get constraints                                    # Gatekeeper constraints
kubectl get constrainttemplates                          # Constraint templates
kubectl describe constraint <constraint-name>             # Constraint details

# Pod Security Policy analysis (deprecated but may exist)
kubectl get podsecuritypolicy                            # PSP resources
kubectl describe podsecuritypolicy <psp-name>            # PSP details
kubectl auth can-i use podsecuritypolicy/<psp-name> --as=system:serviceaccount:<namespace>:<sa-name>  # PSP access check

# Security scanning and compliance
kubectl get events --field-selector reason=FailedMount | grep -i "security\|permission"  # Security-related mount failures
kubectl get pods --field-selector=status.phase=Failed -o custom-columns=NAME:.metadata.name,REASON:.status.containerStatuses[0].state.waiting.reason
```

## Advanced Security Analysis and Monitoring
```bash
# Security-focused resource analysis
kubectl get pods --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,PRIVILEGED:.spec.containers[0].securityContext.privileged,USER:.spec.containers[0].securityContext.runAsUser | grep -v "<none>"

# Identity and access monitoring
kubectl get rolebindings,clusterrolebindings --all-namespaces -o json | \
  jq -r '.items[] | select(.subjects[]?.kind=="User") | "\(.metadata.namespace // "cluster"):\(.metadata.name) -> \(.subjects[].name)"'

# Service account usage analysis
kubectl get pods --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,SA:.spec.serviceAccountName | grep -v default
kubectl get serviceaccounts --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,SECRETS:.secrets[*].name,AUTOMOUNT:.automountServiceAccountToken

# Security context violations
kubectl get pods --all-namespaces -o json | \
  jq -r '.items[] | select(.spec.securityContext.runAsUser == 0 or .spec.containers[].securityContext.runAsUser == 0) | "\(.metadata.namespace)/\(.metadata.name) runs as root"'

# Image security analysis
kubectl get pods --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,IMAGE:.spec.containers[0].image | grep -E "(latest|:v?[0-9]+$)" # Images with potentially insecure tags
kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.containers[].image | test(":latest$")) | "\(.metadata.namespace)/\(.metadata.name) uses :latest tag"'
```