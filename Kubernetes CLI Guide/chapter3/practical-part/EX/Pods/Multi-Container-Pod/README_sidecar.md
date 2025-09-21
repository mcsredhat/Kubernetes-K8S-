# Sidecar Pod: Quickstart & Operations Guide

This project demonstrates a **Kubernetes Pod with a sidecar container pattern**.  
A sidecar container runs alongside the main container to provide additional functionality such as logging, proxying, or monitoring.

## 🎯 Objective

- Deploy a Pod with **multiple containers** (main app + sidecar).
- Show how containers can share volumes and cooperate.
- Practice running, inspecting, troubleshooting, and monitoring multi‑container Pods.

## 📦 Project Contents

```
.
├─ sidecar-pod.yaml       # Pod manifest with sidecar container
└─ README_sidecar.md      # This guide
```

### Pod & Containers

- **Pod name**: `web-with-sidecar`
- **Containers**:
- **web-server** (nginx:1.21)
- **shared-logs** (busybox:1.35)
- **shared-logs** (busybox:1.35)
- **Exposed ports**: 80

## ✅ Prerequisites

- A Kubernetes cluster (Minikube, Kind, k3d, or Docker Desktop).
- `kubectl` installed and configured.

```bash
kubectl version --client
kubectl config current-context
```

## 🚀 Step-by-Step: Run & Display

```bash
# 1. Apply the manifest
kubectl apply -f sidecar-pod.yaml

# 2. Wait for Pod readiness
kubectl wait --for=condition=Ready pod/web-with-sidecar --timeout=90s

# 3. Display Pod status and IP
kubectl get pod web-with-sidecar -o wide

# 4. Describe the Pod (events, volume mounts, conditions)
kubectl describe pod web-with-sidecar

# 5. List the containers inside the Pod
kubectl get pod web-with-sidecar -o jsonpath='{.spec.containers[*].name}'
```

## 🔎 Inspect & Interact

```bash
# Logs of main container
kubectl logs web-with-sidecar -c web-server --tail=20

# Logs of sidecar container
kubectl logs web-with-sidecar -c shared-logs --tail=20

# Exec into main container
kubectl exec -it web-with-sidecar -c web-server -- sh

# Exec into sidecar container
kubectl exec -it web-with-sidecar -c shared-logs -- sh
```

## 🛠️ Troubleshooting

### Pod Pending
- Likely scheduling/resource issues.
- Check events:
  ```bash
  kubectl describe pod web-with-sidecar | sed -n "/Events:/,$p"
  ```

### CrashLoopBackOff in Sidecar
- Inspect logs of the sidecar container:
  ```bash
  kubectl logs web-with-sidecar -c shared-logs
  ```

### Shared Volume Not Working
- Verify volumeMount paths in `sidecar-pod.yaml`.
- Exec into both containers and check if files are visible in the shared path.

### Service Access Issues
- Ensure the right port is exposed: 80.
- Try port-forwarding:
  ```bash
  kubectl port-forward pod/web-with-sidecar 8080:80
  ```

## 📈 Monitoring

```bash
# Watch Pod in real time
kubectl get pod web-with-sidecar -w

# Resource usage (requires metrics-server)
kubectl top pod web-with-sidecar
kubectl top pod web-with-sidecar --containers

# Events stream
kubectl get events --sort-by=.lastTimestamp | tail -n 20
```

## 🧹 Cleanup

```bash
kubectl delete -f sidecar-pod.yaml
```

## 📚 What to Explore Next

- Add **liveness/readiness probes** to both containers.
- Extend the sidecar for logging, monitoring, or proxying traffic.
- Convert the Pod to a **Deployment** for replicas and rolling updates.
- Expose it via a **Service** + **Ingress** for external access.
