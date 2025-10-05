**\*\*comparison table\*\* of \*\*Pod-level vs Container-level fields\*\* you can use as a quick reference when writing YAMLs:**



**## 🟢 POD LEVEL (applies to the whole Pod)**



**These fields describe the \*\*Pod as a unit\*\* (shared across all containers):**



**\* \*\*metadata\*\***



  **\* `name`**

  **\* `namespace`**

  **\* `labels`**

  **\* `annotations`**

**\* \*\*spec (pod-wide parts)\*\***



  **\* `serviceAccountName`**

  **\* `automountServiceAccountToken`**

  **\* `restartPolicy` (Always, OnFailure, Never – applies to all containers)**

  **\* `priorityClassName` (Pod scheduling priority)**

  **\* `nodeSelector`**

  **\* `affinity` (nodeAffinity, podAffinity, podAntiAffinity)**

  **\* `tolerations`**

  **\* `volumes` (shared storage definitions)**

  **\* `dnsPolicy`, `dnsConfig`**

  **\* `hostNetwork`, `hostPID`, `hostIPC`**

  **\* `terminationGracePeriodSeconds`**

  **\* `imagePullSecrets`**

  **\* `securityContext` (Pod-wide default security settings)**

  **\* `schedulerName`**



**---**



**## 🔵 CONTAINER LEVEL (applies to each container individually inside the Pod)**



**Each container has its own \*\*runtime config\*\*:**



**\* \*\*container spec\*\***



  **\* `name`**

  **\* `image`**

  **\* `command` / `args`**

  **\* `workingDir`**

  **\* `ports` (containerPort, protocol)**

  **\* `env` (single env vars)**

  **\* `envFrom` (inject from ConfigMap or Secret)**

  **\* `volumeMounts` (how this container uses Pod volumes)**

  **\* `resources` (requests \& limits for CPU/memory/storage)**

  **\* `livenessProbe` (restart check)**

  **\* `readinessProbe` (traffic check)**

  **\* `startupProbe` (first-time startup check)**

  **\* `lifecycle` (postStart, preStop hooks)**

  **\* `securityContext` (container-specific security settings)**

  **\* `stdin`, `tty` (for interactive containers)**

  **\* `imagePullPolicy`**







**---**



**# 📊 Pod vs Container Fields in Kubernetes**



**| \*\*Scope\*\*        | \*\*Field\*\*                                | \*\*Description\*\*                               |**

**| ---------------- | ---------------------------------------- | --------------------------------------------- |**

**|    \*\*Pod-level\*\* | `metadata.name`                          | Pod name                                      |**

**|                  | `metadata.namespace`                     | Namespace where Pod lives                     |**

**|                  | `metadata.labels`                        | Key/value tags for selectors, grouping        |**

**|                  | `metadata.annotations`                   | Extra metadata (non-identifying)              |**

**|                  | `spec.volumes`                           | Defines storage volumes shared by containers  |**

**|                  | `spec.serviceAccountName`                | Which ServiceAccount Pod uses                 |**

**|                  | `spec.automountServiceAccountToken`      | Auto-mount service account token              |**

**|                  | `spec.restartPolicy`                     | Restart strategy (Always, OnFailure, Never)   |**

**|                  | `spec.priorityClassName`                 | Scheduling priority                           |**

**|                  | `spec.nodeSelector`                      | Constraints to schedule Pod to specific nodes |**

**|                  | `spec.affinity`                          | Node/Pod affinity \& anti-affinity rules       |**

**|                  | `spec.tolerations`                       | Allow scheduling on tainted nodes             |**

**|                  | `spec.dnsPolicy`, `dnsConfig`            | Pod DNS settings                              |**

**|                  | `spec.hostNetwork`, `hostPID`, `hostIPC` | Share node’s network/PID/IPC namespaces       |**

**|                  | `spec.terminationGracePeriodSeconds`     | Time before force-killing containers          |**

**|                  | `spec.imagePullSecrets`                  | Secrets for pulling private images            |**

**|                  | `spec.securityContext`                   | Pod-wide default security settings            |**

**|                  | `spec.schedulerName`                     | Custom scheduler name (if not default)        |**



**---**



**| \*\*Scope\*\*              | \*\*Field\*\*         | \*\*Description\*\*                                             |**

**| ---------------------- | ----------------- | ----------------------------------------------------------- |**

**|    \*\*Container-level\*\* | `name`            | Unique name for the container in the Pod                    |**

**|                        | `image`           | Container image (e.g., nginx:1.25)                          |**

**|                        | `command`, `args` | Override image’s entrypoint \& arguments                     |**

**|                        | `workingDir`      | Default working directory inside container                  |**

**|                        | `ports`           | Ports exposed by the container                              |**

**|                        | `env`             | Individual environment variables                            |**

**|                        | `envFrom`         | Bulk import env vars from ConfigMap/Secret                  |**

**|                        | `volumeMounts`    | Mount Pod volumes inside container                          |**

**|                        | `resources`       | CPU/memory/storage requests \& limits                        |**

**|                        | `livenessProbe`   | Restart container if health fails                           |**

**|                        | `readinessProbe`  | Remove from Service endpoints if fails                      |**

**|                        | `startupProbe`    | Special check for slow-starting apps                        |**

**|                        | `lifecycle`       | Hooks: `postStart`, `preStop`                               |**

**|                        | `securityContext` | Container-specific security (runAsUser, capabilities, etc.) |**

**|                        | `stdin`, `tty`    | Interactive containers (like shells)                        |**

**|                        | `imagePullPolicy` | Always, IfNotPresent, Never                                 |**



**---**

**+------------------------------------------------------+**

**| 🔴 Deployment (apps/v1)                              |**

**|------------------------------------------------------|**

**| metadata: name, labels, annotations                  |**

**| spec:                                                |**

**|   replicas        -> desired number of Pods         |**

**|   selector        -> which Pods/ReplicaSets to manage|**

**|   strategy        -> RollingUpdate / Recreate       |**

**|   template        -> Pod template (spec + metadata) |**

**+------------------------------------------------------+**

                         **|**

                         **v**

**+--------------------------------------------------------------+**

**|                     🔴 ReplicaSet (apps/v1)                  |**

**|--------------------------------------------------------------|**

**| metadata: name, labels, annotations                          |**

**| spec:                                                        |**

**|   replicas        -> How many Pods to run                    |**

**|   selector        -> Which Pods this ReplicaSet manages      |**

**|   template        -> Pod template (spec + metadata)          |**

**+--------------------------------------------------------------+**

                         **|**

                         **v**

**+--------------------------------------------------------------+**

**|                        🟢 Pod (v1)                           |**

**|--------------------------------------------------------------|**

**| metadata: name, namespace, labels, annotations               |**

**| spec:                                                        |**

**|    volumes, nodeSelector, affinity, tolerations              |**

**|   securityContext, priorityClassName, restartPolicy          |**

**|   serviceAccountName, terminationGracePeriodSeconds          |**

**+--------------------------------------------------------------+**

                         **|**

                         **v**

**+--------------------------------------------------------------+**

**|                  🔵 Container (inside Pod)                   |**

**|--------------------------------------------------------------|**

**| name, image                                                  |**

**| ports, command, args                                         |**

**| env, envFrom                                                 |**

**| volumeMounts                                                 |**

**| resources (CPU, memory, storage requests/limits)             |**

**| probes (liveness, readiness, startup)                        |**

**| lifecycle (postStart, preStop)                               |**

**| securityContext (user, fsGroup, capabilities)                |**

**+--------------------------------------------------------------+**







