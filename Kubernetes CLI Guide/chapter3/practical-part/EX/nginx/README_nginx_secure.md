# Secure NGINX Web Pod: Quickstart & Operations Guide

This project provides a **secure NGINX web deployment** on Kubernetes with TLS/HTTPS enabled.

## 🎯 Objective

- Deploy an NGINX web server with TLS support.
- Learn how to use **Secrets** for TLS certificates.
- Understand how Pods, Services, and Ingress combine for secure web hosting.
- Practice deployment, troubleshooting, and monitoring.

## 📦 Project Contents

```
.
├─ nginx-web-secure.yaml   # Deployment + Service + Secret + Ingress manifest
└─ README_nginx_secure.md  # This guide
```

### Resources Defined

- **Deployment**: `nginx-secure-deploy`
- **Service**: `nginx-secure-svc`
- **Ingress**: `nginx-secure-ingress`
- **TLS Secret**: `nginx-tls-secret`
- **ConfigMap** (if any): `none`

### Containers



- **Exposed container ports**: 8080

## ✅ Prerequisites

- A Kubernetes cluster with **Ingress Controller** (e.g., NGINX Ingress).
- `kubectl` installed and configured.
- TLS certificate & key base64‑encoded into a Kubernetes Secret, or auto‑generated for testing.

```bash
kubectl version --client
kubectl config current-context
```

## 🚀 Step-by-Step: Run & Display

```bash
# 1. Apply the manifest
kubectl apply -f nginx-web-secure.yaml

# 2. Verify resources
kubectl get deploy,svc,ingress,secrets

# 3. Wait until the Pod is Ready
kubectl wait --for=condition=Ready pod -l app=nginx-secure --timeout=120s

# 4. Check Service and Ingress
kubectl get svc nginx-secure-svc
kubectl get ingress nginx-secure-ingress
```

## 🔎 Access the Web App

- If running locally with Minikube:
  ```bash
  minikube tunnel
  kubectl get ingress nginx-secure-ingress
  ```
  Open `https://<minikube-ip>` in your browser.

- If running on a cloud cluster with Ingress, use the external IP/DNS.

## 🛠️ Troubleshooting

### Pod Pending / Not Ready
- Check events and pod description:
  ```bash
  kubectl describe pod -l app=nginx-secure
  ```

### TLS Not Working
- Verify TLS secret exists:
  ```bash
  kubectl get secret nginx-tls-secret -o yaml
  ```
- Ensure Ingress references the correct secret.

### Ingress Not Accessible
- Check Ingress Controller logs.
- Ensure your DNS or `/etc/hosts` points to the cluster IP.

### 404 or Default Backend
- Check Ingress rules in `nginx-web-secure.yaml`.
- Verify Service selector matches Deployment labels.

## 📈 Monitoring

```bash
# Live watch Pod
kubectl get pod -l app=nginx-secure -w

# Logs
kubectl logs -l app=nginx-secure --tail=50

# Pod resource usage (requires metrics-server)
kubectl top pod -l app=nginx-secure

# Events
kubectl get events --sort-by=.lastTimestamp | tail -n 20
```

## 🧹 Cleanup

```bash
kubectl delete -f nginx-web-secure.yaml
```

## 📚 What to Explore Next

- Add **readiness/liveness probes** to the NGINX container.
- Automate TLS renewal using **cert-manager**.
- Add custom NGINX config via **ConfigMap**.
- Scale Deployment replicas and test load balancing.
