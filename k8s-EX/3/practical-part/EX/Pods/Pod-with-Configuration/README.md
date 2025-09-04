# Enhanced Pod: Quickstart & Operations Guide

This repository contains a single **Kubernetes Pod** that runs an NGINX web server and serves static content from a **ConfigMap**.

## 🎯 Objective

- Deploy a self-contained web Pod quickly.
- Learn how a Pod mounts a ConfigMap as a volume.
- Practice the day‑2 basics: run, verify, display, troubleshoot, and monitor.

## 📦 Project Contents

```
.
├─ enhanced-pod.yaml    # Pod + ConfigMap manifest
└─ README.md            # This guide
```
- **Pod name**: `enhanced-web-pod`
- **Container**: `nginx`
- **Image**: `nginx:1.21`
- **Exposed container port**: `80`
- **ConfigMap**: `web-content` (mounted as a volume inside the Pod)

> Tip: You can open `enhanced-pod.yaml` to see the volume mount path for `web-content` and where NGINX serves content from.

## ✅ Prerequisites

- A Kubernetes cluster (Minikube, Kind, k3d, Docker Desktop, or any K8s 1.24+ cluster).
- `kubectl` installed and pointing to the right context:
  ```bash
  kubectl version --client
  kubectl config current-context
  ```

## 🚀 Quick Start (5 commands)

```bash
# 1) Create namespace (optional but recommended)
kubectl create ns web-lab

# 2) Apply the manifest
kubectl -n web-lab apply -f enhanced-pod.yaml

# 3) Wait until the Pod is Ready
kubectl -n web-lab wait --for=condition=Ready pod/enhanced-web-pod --timeout=90s

# 4) Port‑forward to reach NGINX locally
kubectl -n web-lab port-forward pod/enhanced-web-pod 8080:80

# 5) In another terminal, open or curl the site
curl -i localhost:8080
# or open http://localhost:8080 in your browser
```

## 🔎 Display & Verify

- Check Pod status and IP:
  ```bash
  kubectl -n web-lab get pod -o wide
  kubectl -n web-lab describe pod enhanced-web-pod
  ```
- Confirm content came from the ConfigMap:
  ```bash
  # Exec into the container and list mounted content
  kubectl -n web-lab exec -it enhanced-web-pod -- /bin/sh -lc 'ls -la /usr/share/nginx/html && head -n 20 /usr/share/nginx/html/index.html || true'
  ```
  > If your mount path differs, adjust the path accordingly.

## 🧪 Useful One‑Liners

```bash
# Live logs
kubectl -n web-lab logs -f enhanced-web-pod

# Shell into the container
kubectl -n web-lab exec -it enhanced-web-pod -- sh

# Send a test HTTP request from INSIDE the Pod
kubectl -n web-lab exec -it enhanced-web-pod -- sh -lc 'apk add --no-cache curl || apt-get update && apt-get install -y curl || true; curl -i http://127.0.0.1:80'
```

## 🛠️ Troubleshooting

### Pod Pending
- Not enough cluster resources or a bad node selector/taint.
- Check events and scheduling:
  ```bash
  kubectl -n web-lab describe pod enhanced-web-pod | sed -n "/Events:/,$p"
  kubectl -n web-lab get events --sort-by=.lastTimestamp | tail -n 20
  ```

### ImagePullBackOff / ErrImagePull
- Image `nginx:1.21` couldn’t be pulled.
  ```bash
  kubectl -n web-lab describe pod enhanced-web-pod | sed -n "/Events:/,$p"
  ```
- If it’s a private registry, set an imagePullSecret and reference it in the Pod.

### CrashLoopBackOff
- Check the container command/args and logs:
  ```bash
  kubectl -n web-lab logs enhanced-web-pod --previous
  kubectl -n web-lab describe pod enhanced-web-pod
  ```

### NGINX serves default page instead of your content
- Ensure the ConfigMap `web-content` exists and is mounted at the path NGINX serves (commonly `/usr/share/nginx/html`):
  ```bash
  kubectl -n web-lab get cm web-content -o yaml
  kubectl -n web-lab exec -it enhanced-web-pod -- sh -lc 'ls -la /usr/share/nginx/html'
  ```
- If the paths don’t align, update the `volumeMounts` path in `enhanced-pod.yaml`.

### Port‑forward fails / nothing on localhost:8080
- Ensure the Pod is Ready:
  ```bash
  kubectl -n web-lab get pod enhanced-web-pod
  ```
- Try another local port (e.g., 8081):
  ```bash
  kubectl -n web-lab port-forward pod/enhanced-web-pod 8081:80
  ```

## 📈 Monitoring (Basics)

> These require the **metrics‑server** (or another metrics pipeline) to be installed on your cluster.

```bash
# CPU/Memory for Pods in the namespace
kubectl -n web-lab top pod

# Watch the Pod status change in real time
kubectl -n web-lab get pod -w

# Watch cluster/node resource pressure
kubectl top nodes
```

For richer dashboards, consider **k9s**, **Lens**, or a Prometheus + Grafana stack.

## 🧹 Cleanup

```bash
kubectl -n web-lab delete -f enhanced-pod.yaml
kubectl delete ns web-lab
```

## 📚 What to Explore Next

- Add **readiness/liveness probes** to the NGINX container.
- Convert this Pod to a **Deployment** for self‑healing and rolling updates.
- Add a **Service** + **Ingress** to expose it without port‑forwarding.
- Use a **ConfigMap** for custom NGINX config and mount it to `/etc/nginx/conf.d`.
