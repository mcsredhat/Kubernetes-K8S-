# Kubernetes Template Deployment Guide

## Prerequisites

Before deploying the templates, ensure you have:

1. **Kubernetes cluster** (v1.25+) with appropriate permissions
2. **kubectl** configured and connected to your cluster
3. **Storage CSI drivers** installed (for AWS EBS, GCP PD, or local storage)
4. **Ingress controller** (nginx-ingress recommended)
5. **cert-manager** (for SSL certificates)
6. **metrics-server** (for horizontal pod autoscaling)

## Step 1: Prepare Your Environment Variables

Create a configuration file with your specific values:

```bash
# Create environment configuration
cat > config.env << EOF
APP_NAME=myapp
NAMESPACE=myapp-prod
ENVIRONMENT=production
TEAM=platform-team
DOMAIN=myapp.example.com
REPLICAS=3
STORAGE_SIZE=10Gi
STORAGE_CLASS=myapp
IMAGE=nginx:1.25-alpine
BACKEND_IMAGE=myapp/backend:latest
PROJECT_ID=my-gcp-project-id
REGION=us-central1
KEYRING=myapp-keyring
KEY=myapp-key
EOF

# Load the configuration
source config.env
```

## Step 2: Update Template Variables

Replace template variables in all files using sed:

```bash
# Create a directory for your customized files
mkdir -p k8s-deploy
cd k8s-deploy

# Copy all template files here first, then run replacements:
for file in ../01-*.yaml ../02-*.yaml ../03-*.yaml ../04-*.yaml ../05-*.yaml ../06-*.yaml ../07-*.yaml ../08-*.yaml ../09-*.yaml ../10-*.yaml; do
  filename=$(basename "$file")
  sed -e "s/{{APP_NAME}}/$APP_NAME/g" \
      -e "s/{{NAMESPACE}}/$NAMESPACE/g" \
      -e "s/{{ENVIRONMENT}}/$ENVIRONMENT/g" \
      -e "s/{{TEAM}}/$TEAM/g" \
      -e "s/{{DOMAIN}}/$DOMAIN/g" \
      -e "s/{{REPLICAS}}/$REPLICAS/g" \
      -e "s/{{STORAGE_SIZE}}/$STORAGE_SIZE/g" \
      -e "s/{{STORAGE_CLASS}}/$STORAGE_CLASS/g" \
      -e "s/{{IMAGE}}/$IMAGE/g" \
      -e "s/{{BACKEND_IMAGE}}/$BACKEND_IMAGE/g" \
      -e "s/{{PROJECT_ID}}/$PROJECT_ID/g" \
      -e "s/{{REGION}}/$REGION/g" \
      -e "s/{{KEYRING}}/$KEYRING/g" \
      -e "s/{{KEY}}/$KEY/g" \
      "$file" > "$filename"
done
```

## Step 3: Update Security Values

**CRITICAL SECURITY STEP:** Update all default passwords and keys in `03-secrets-config.yaml`:

```bash
# Generate secure passwords and keys
DB_PASSWORD=$(openssl rand -base64 32)
API_KEY=$(openssl rand -hex 32)
JWT_SECRET=$(openssl rand -base64 32)
ENCRYPTION_KEY=$(openssl rand -base64 32)
GRAFANA_PASSWORD=$(openssl rand -base64 16)

# Update the secrets file
sed -i "s/CHANGE-THIS-SECURE-PASSWORD-123!/$DB_PASSWORD/g" 03-secrets-config.yaml
sed -i "s/CHANGE-THIS-API-KEY-abc123def456/$API_KEY/g" 03-secrets-config.yaml
sed -i "s/CHANGE-THIS-32-CHAR-JWT-SECRET-KEY!/$JWT_SECRET/g" 03-secrets-config.yaml
sed -i "s/CHANGE-THIS-32-CHARACTER-ENCRYPTION-KEY!/$ENCRYPTION_KEY/g" 03-secrets-config.yaml
sed -i "s/CHANGE-THIS-GRAFANA-ADMIN-PASSWORD!/$GRAFANA_PASSWORD/g" 03-secrets-config.yaml

echo "Generated passwords saved to secrets.txt (keep secure!)"
cat > secrets.txt << EOF
Database Password: $DB_PASSWORD
API Key: $API_KEY
JWT Secret: $JWT_SECRET
Encryption Key: $ENCRYPTION_KEY
Grafana Password: $GRAFANA_PASSWORD
EOF
```

## Step 4: Verify Cluster Prerequisites

Check your cluster is ready:

```bash
# Verify kubectl connection
kubectl cluster-info

# Check for required components
echo "Checking prerequisites..."

# Check for storage classes
kubectl get storageclass

# Check for ingress controller
kubectl get pods -n ingress-nginx

# Check for cert-manager
kubectl get pods -n cert-manager

# Check for metrics-server
kubectl get deployment metrics-server -n kube-system

# Verify cluster has required permissions
kubectl auth can-i create namespace
kubectl auth can-i create persistentvolumeclaim
```

## Step 5: Deploy in Correct Order

Deploy the resources in the proper sequence to handle dependencies:

### Phase 1: Foundation (Namespace and Storage)
```bash
echo "Phase 1: Creating namespace and storage..."

# Apply namespace first
kubectl apply -f 01-namespace.yaml

# Wait for namespace to be ready
kubectl wait --for=condition=Active namespace/$NAMESPACE --timeout=60s

# Apply storage classes and PVC
kubectl apply -f 02-storage.yaml

# Wait for PVC to be bound
kubectl wait --for=condition=Bound pvc/${APP_NAME}-data-pvc -n $NAMESPACE --timeout=300s
```

### Phase 2: Configuration and Security
```bash
echo "Phase 2: Creating configuration and RBAC..."

# Apply secrets and config
kubectl apply -f 03-secrets-config.yaml

# Apply RBAC
kubectl apply -f 04-rbac.yaml

# Verify secrets are created
kubectl get secrets -n $NAMESPACE
kubectl get configmaps -n $NAMESPACE
kubectl get serviceaccount -n $NAMESPACE
```

### Phase 3: Core Application
```bash
echo "Phase 3: Deploying application..."

# Apply deployment
kubectl apply -f 05-deployment.yaml

# Wait for deployment to be ready
kubectl rollout status deployment/${APP_NAME}-deployment -n $NAMESPACE --timeout=600s

# Check pod status
kubectl get pods -n $NAMESPACE -l app=$APP_NAME
```

### Phase 4: Networking
```bash
echo "Phase 4: Configuring networking..."

# Apply services and ingress
kubectl apply -f 06-services-ingress.yaml

# Apply network security policies
kubectl apply -f 08-security-network.yaml

# Wait for services to be ready
kubectl get svc -n $NAMESPACE
kubectl get ingress -n $NAMESPACE
```

### Phase 5: Scaling and Monitoring
```bash
echo "Phase 5: Setting up autoscaling and monitoring..."

# Apply autoscaling
kubectl apply -f 07-autoscaling-availability.yaml

# Apply monitoring stack
kubectl apply -f 09-monitoring.yaml

# Wait for monitoring pods
kubectl rollout status deployment/prometheus -n monitoring --timeout=300s
kubectl rollout status deployment/grafana -n monitoring --timeout=300s

# Check HPA status
kubectl get hpa -n $NAMESPACE
```

### Phase 6: Backup and Maintenance (Optional)
```bash
echo "Phase 6: Setting up backup and maintenance..."

# Apply backup configuration
kubectl apply -f 10-backup-maintenance.yaml

# Verify backup CronJob is scheduled
kubectl get cronjob -n $NAMESPACE
```

## Step 6: Verification and Testing

Verify the deployment is working correctly:

```bash
echo "Running deployment verification..."

# Check all pods are running
kubectl get pods -n $NAMESPACE -o wide

# Check services are accessible
kubectl get svc -n $NAMESPACE

# Test internal connectivity
kubectl run test-pod --image=busybox --rm -it --restart=Never -- /bin/sh

# Inside the test pod:
# nslookup ${APP_NAME}-service.${NAMESPACE}.svc.cluster.local
# wget -qO- http://${APP_NAME}-service.${NAMESPACE}.svc.cluster.local/health

# Check ingress and external access
kubectl get ingress -n $NAMESPACE

# Test external endpoint (replace with your domain)
curl -I https://$DOMAIN/health

# Check logs
kubectl logs -l app=$APP_NAME -n $NAMESPACE --tail=50

# Verify monitoring
kubectl port-forward -n monitoring svc/grafana 3000:3000 &
echo "Grafana available at http://localhost:3000"
echo "Username: admin, Password: (check secrets.txt)"

# Check Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090 &
echo "Prometheus available at http://localhost:9090"
```

## Step 7: Post-Deployment Configuration

### SSL Certificate Setup
```bash
# If using cert-manager with Let's Encrypt, verify certificate
kubectl get certificate -n $NAMESPACE
kubectl describe certificate ${APP_NAME}-tls -n $NAMESPACE

# Check certificate is ready
kubectl wait --for=condition=Ready certificate/${APP_NAME}-tls -n $NAMESPACE --timeout=600s
```

### DNS Configuration
```bash
# Get ingress external IP
EXTERNAL_IP=$(kubectl get ingress ${APP_NAME}-ingress -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Configure DNS: $DOMAIN -> $EXTERNAL_IP"
```

### Monitoring Access
```bash
# Create port forwards for monitoring access
kubectl port-forward -n monitoring svc/grafana 3000:3000 &
kubectl port-forward -n monitoring svc/prometheus 9090:9090 &

echo "Monitoring URLs:"
echo "Grafana: http://localhost:3000 (admin / $(grep 'Grafana Password' secrets.txt | cut -d' ' -f3))"
echo "Prometheus: http://localhost:9090"
```

## Step 8: Backup Testing

Test the backup system:

```bash
# Trigger a manual backup
kubectl create job --from=cronjob/${APP_NAME}-backup ${APP_NAME}-manual-backup -n $NAMESPACE

# Check backup job status
kubectl get job ${APP_NAME}-manual-backup -n $NAMESPACE
kubectl logs job/${APP_NAME}-manual-backup -n $NAMESPACE

# Create a volume snapshot
kubectl apply -f - <<EOF
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: ${APP_NAME}-test-snapshot
  namespace: $NAMESPACE
spec:
  volumeSnapshotClassName: ${APP_NAME}-snapshot-class
  source:
    persistentVolumeClaimName: ${APP_NAME}-data-pvc
EOF

# Verify snapshot creation
kubectl get volumesnapshot -n $NAMESPACE
```

## Troubleshooting Commands

Common troubleshooting commands:

```bash
# Check all resources
kubectl get all -n $NAMESPACE

# Check events for issues
kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp'

# Check pod logs
kubectl logs -l app=$APP_NAME -n $NAMESPACE --previous

# Describe problematic resources
kubectl describe pod -l app=$APP_NAME -n $NAMESPACE
kubectl describe pvc ${APP_NAME}-data-pvc -n $NAMESPACE
kubectl describe ingress ${APP_NAME}-ingress -n $NAMESPACE

# Check resource usage
kubectl top pods -n $NAMESPACE
kubectl top nodes

# Debug networking
kubectl exec -it deployment/${APP_NAME}-deployment -n $NAMESPACE -- /bin/sh

# Check HPA metrics
kubectl describe hpa ${APP_NAME}-hpa -n $NAMESPACE

# Restart deployment if needed
kubectl rollout restart deployment/${APP_NAME}-deployment -n $NAMESPACE
```

## Cleanup (if needed)

To remove the entire deployment:

```bash
# Delete in reverse order
kubectl delete -f 10-backup-maintenance.yaml
kubectl delete -f 09-monitoring.yaml
kubectl delete -f 08-security-network.yaml
kubectl delete -f 07-autoscaling-availability.yaml
kubectl delete -f 06-services-ingress.yaml
kubectl delete -f 05-deployment.yaml
kubectl delete -f 04-rbac.yaml
kubectl delete -f 03-secrets-config.yaml
kubectl delete -f 02-storage.yaml
kubectl delete -f 01-namespace.yaml

# Or delete everything at once
kubectl delete namespace $NAMESPACE monitoring --wait=true
```

## Production Checklist

Before going to production:

- [ ] All template variables replaced with actual values
- [ ] All default passwords and keys updated
- [ ] SSL certificates configured and working
- [ ] DNS records pointing to correct IP
- [ ] Resource limits appropriate for workload
- [ ] Backup system tested and verified
- [ ] Monitoring dashboards configured
- [ ] Network policies tested
- [ ] Security scan completed
- [ ] Disaster recovery plan documented
- [ ] Team access and permissions configured

Remember to keep your `secrets.txt` file secure and never commit it to version control!