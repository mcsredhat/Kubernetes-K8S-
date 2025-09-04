# kubectl run with .env file Template

This template separates configuration variables into `.env` files and provides clean kubectl run scripts that source them.

## .env Configuration Files

### nginx.env
```bash
# Pod Configuration
POD_NAME="nginx-web"
IMAGE="nginx"
TAG="1.20"
CONTAINER_PORT="8080"
NAMESPACE="web"
LABELS="app=nginx,tier=frontend,version=1.20"
ANNOTATIONS="description=Nginx web server with security context,owner=web-team"
ENV_VAR_1="NGINX_PORT=8080"
ENV_VAR_2="NGINX_HOST=localhost"
CONTAINER_NAME="nginx-web"
PORT_NAME="http"
OUTPUT_FILE="nginx-web-secure.yaml"

# Security Configuration
USER_ID="101"
GROUP_ID="101"
FS_GROUP_ID="101"

# Resource Configuration
MEMORY_REQUEST="64Mi"
CPU_REQUEST="100m"
MEMORY_LIMIT="128Mi"
CPU_LIMIT="200m"

# Application Configuration
APP_NAME="nginx"
CONFIG_MOUNT_PATH="/etc/nginx/nginx.conf"
CONFIG_FILE_NAME="nginx.conf"
CACHE_MOUNT_PATH="/var/cache/nginx"
RUN_MOUNT_PATH="/var/run"
LOGS_MOUNT_PATH="/var/log/nginx"
HEALTH_PATH="/health"

# Probe Configuration
LIVENESS_INITIAL_DELAY="30"
LIVENESS_PERIOD="10"
LIVENESS_TIMEOUT="5"
LIVENESS_FAILURE_THRESHOLD="3"
READINESS_INITIAL_DELAY="5"
READINESS_PERIOD="5"
READINESS_TIMEOUT="3"
READINESS_FAILURE_THRESHOLD="3"
STARTUP_INITIAL_DELAY="10"
STARTUP_PERIOD="3"
STARTUP_TIMEOUT="1"
STARTUP_FAILURE_THRESHOLD="30"
```

### apache.env
```bash
# Pod Configuration
POD_NAME="apache-web"
IMAGE="httpd"
TAG="2.4"
CONTAINER_PORT="8080"
NAMESPACE="web"
LABELS="app=apache,tier=frontend,version=2.4"
ANNOTATIONS="description=Apache HTTP server with security context,owner=web-team"
ENV_VAR_1="APACHE_PORT=8080"
ENV_VAR_2="APACHE_SERVER_NAME=localhost"
CONTAINER_NAME="apache-web"
PORT_NAME="http"
OUTPUT_FILE="apache-web-secure.yaml"

# Security Configuration
USER_ID="33"
GROUP_ID="33"
FS_GROUP_ID="33"

# Resource Configuration
MEMORY_REQUEST="128Mi"
CPU_REQUEST="150m"
MEMORY_LIMIT="256Mi"
CPU_LIMIT="300m"

# Application Configuration
APP_NAME="apache"
CONFIG_MOUNT_PATH="/usr/local/apache2/conf/httpd.conf"
CONFIG_FILE_NAME="httpd.conf"
CACHE_MOUNT_PATH="/usr/local/apache2/logs"
RUN_MOUNT_PATH="/var/run"
LOGS_MOUNT_PATH="/usr/local/apache2/logs"
HEALTH_PATH="/server-status"

# Probe Configuration
LIVENESS_INITIAL_DELAY="30"
LIVENESS_PERIOD="10"
LIVENESS_TIMEOUT="5"
LIVENESS_FAILURE_THRESHOLD="3"
READINESS_INITIAL_DELAY="5"
READINESS_PERIOD="5"
READINESS_TIMEOUT="3"
READINESS_FAILURE_THRESHOLD="3"
STARTUP_INITIAL_DELAY="10"
STARTUP_PERIOD="3"
STARTUP_TIMEOUT="1"
STARTUP_FAILURE_THRESHOLD="30"
```

### redis.env
```bash
# Pod Configuration
POD_NAME="redis-cache"
IMAGE="redis"
TAG="7-alpine"
CONTAINER_PORT="6379"
NAMESPACE="database"
LABELS="app=redis,tier=cache,version=7"
ANNOTATIONS="description=Redis cache server with security context,owner=database-team"
ENV_VAR_1="REDIS_PORT=6379"
ENV_VAR_2="REDIS_DATABASES=16"
CONTAINER_NAME="redis-cache"
PORT_NAME="redis"
OUTPUT_FILE="redis-cache-secure.yaml"

# Security Configuration
USER_ID="999"
GROUP_ID="999"
FS_GROUP_ID="999"

# Resource Configuration
MEMORY_REQUEST="256Mi"
CPU_REQUEST="200m"
MEMORY_LIMIT="512Mi"
CPU_LIMIT="500m"

# Application Configuration
APP_NAME="redis"
CONFIG_MOUNT_PATH="/usr/local/etc/redis/redis.conf"
CONFIG_FILE_NAME="redis.conf"
CACHE_MOUNT_PATH="/data"
RUN_MOUNT_PATH="/var/run"
LOGS_MOUNT_PATH="/var/log/redis"
HEALTH_PATH="/ping"

# Probe Configuration
LIVENESS_INITIAL_DELAY="30"
LIVENESS_PERIOD="10"
LIVENESS_TIMEOUT="5"
LIVENESS_FAILURE_THRESHOLD="3"
READINESS_INITIAL_DELAY="5"
READINESS_PERIOD="5"
READINESS_TIMEOUT="3"
READINESS_FAILURE_THRESHOLD="3"
STARTUP_INITIAL_DELAY="10"
STARTUP_PERIOD="3"
STARTUP_TIMEOUT="1"
STARTUP_FAILURE_THRESHOLD="30"
```

## kubectl run Scripts

### create-pod.sh (Generic Script)
```bash
#!/bin/bash

# Check if config file is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <env-file>"
    echo "Example: $0 nginx.env"
    echo "Available env files:"
    ls -1 *.env 2>/dev/null || echo "No .env files found"
    exit 1
fi

ENV_FILE=$1

# Check if env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "Environment file $ENV_FILE not found!"
    exit 1
fi

# Source the environment variables
echo "Loading configuration from $ENV_FILE..."
source "$ENV_FILE"

# Validate required variables
REQUIRED_VARS=(
    "POD_NAME" "IMAGE" "TAG" "CONTAINER_PORT" "NAMESPACE" 
    "CONTAINER_NAME" "USER_ID" "GROUP_ID" "FS_GROUP_ID"
)

for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        echo "Error: Required variable $var is not set in $ENV_FILE"
        exit 1
    fi
done

echo "Creating pod: $POD_NAME in namespace: $NAMESPACE"

# Execute kubectl run command
kubectl run ${POD_NAME} \
  --image=${IMAGE}:${TAG} \
  --port=${CONTAINER_PORT} \
  --restart=Never \
  --namespace=${NAMESPACE} \
  --labels="${LABELS}" \
  --annotations="${ANNOTATIONS}" \
  --env="${ENV_VAR_1}" \
  --env="${ENV_VAR_2}" \
  --overrides='{
    "spec": {
      "securityContext": {
        "runAsNonRoot": true,
        "runAsUser": '${USER_ID}',
        "runAsGroup": '${GROUP_ID}',
        "fsGroup": '${FS_GROUP_ID}',
        "seccompProfile": {
          "type": "RuntimeDefault"
        }
      },
      "containers": [{
        "name": "'${CONTAINER_NAME}'",
        "image": "'${IMAGE}':'${TAG}'",
        "ports": [{"containerPort": '${CONTAINER_PORT}', "name": "'${PORT_NAME}'"}],
        "securityContext": {
          "allowPrivilegeEscalation": false,
          "readOnlyRootFilesystem": true,
          "runAsNonRoot": true,
          "runAsUser": '${USER_ID}',
          "runAsGroup": '${GROUP_ID}',
          "capabilities": {
            "drop": ["ALL"]
          }
        },
        "resources": {
          "requests": {"memory": "'${MEMORY_REQUEST}'", "cpu": "'${CPU_REQUEST}'"},
          "limits": {"memory": "'${MEMORY_LIMIT}'", "cpu": "'${CPU_LIMIT}'"}
        },
        "volumeMounts": [
          {
            "name": "'${APP_NAME}'-config",
            "mountPath": "'${CONFIG_MOUNT_PATH}'",
            "subPath": "'${CONFIG_FILE_NAME}'",
            "readOnly": true
          },
          {
            "name": "'${APP_NAME}'-cache",
            "mountPath": "'${CACHE_MOUNT_PATH}'"
          },
          {
            "name": "'${APP_NAME}'-run",
            "mountPath": "'${RUN_MOUNT_PATH}'"
          },
          {
            "name": "'${APP_NAME}'-logs",
            "mountPath": "'${LOGS_MOUNT_PATH}'"
          }
        ],
        "livenessProbe": {
          "httpGet": {
            "path": "'${HEALTH_PATH}'",
            "port": '${CONTAINER_PORT}',
            "scheme": "HTTP"
          },
          "initialDelaySeconds": '${LIVENESS_INITIAL_DELAY}',
          "periodSeconds": '${LIVENESS_PERIOD}',
          "timeoutSeconds": '${LIVENESS_TIMEOUT}',
          "failureThreshold": '${LIVENESS_FAILURE_THRESHOLD}'
        },
        "readinessProbe": {
          "httpGet": {
            "path": "'${HEALTH_PATH}'",
            "port": '${CONTAINER_PORT}',
            "scheme": "HTTP"
          },
          "initialDelaySeconds": '${READINESS_INITIAL_DELAY}',
          "periodSeconds": '${READINESS_PERIOD}',
          "timeoutSeconds": '${READINESS_TIMEOUT}',
          "failureThreshold": '${READINESS_FAILURE_THRESHOLD}'
        },
        "startupProbe": {
          "httpGet": {
            "path": "'${HEALTH_PATH}'",
            "port": '${CONTAINER_PORT}',
            "scheme": "HTTP"
          },
          "initialDelaySeconds": '${STARTUP_INITIAL_DELAY}',
          "periodSeconds": '${STARTUP_PERIOD}',
          "timeoutSeconds": '${STARTUP_TIMEOUT}',
          "failureThreshold": '${STARTUP_FAILURE_THRESHOLD}'
        }
      }],
      "volumes": [
        {
          "name": "'${APP_NAME}'-config",
          "configMap": {
            "name": "'${APP_NAME}'-config",
            "items": [
              {
                "key": "'${CONFIG_FILE_NAME}'",
                "path": "'${CONFIG_FILE_NAME}'"
              }
            ]
          }
        },
        {
          "name": "'${APP_NAME}'-cache",
          "emptyDir": {}
        },
        {
          "name": "'${APP_NAME}'-run",
          "emptyDir": {}
        },
        {
          "name": "'${APP_NAME}'-logs",
          "emptyDir": {}
        }
      ]
    }
  }' \
  --dry-run=client \
  --output=yaml > ${OUTPUT_FILE}

echo "Pod manifest created: ${OUTPUT_FILE}"
echo "To apply: kubectl apply -f ${OUTPUT_FILE}"
```

### Specific Application Scripts

### create-nginx.sh
```bash
#!/bin/bash
source nginx.env

kubectl run ${POD_NAME} \
  --image=${IMAGE}:${TAG} \
  --port=${CONTAINER_PORT} \
  --restart=Never \
  --namespace=${NAMESPACE} \
  --labels="${LABELS}" \
  --annotations="${ANNOTATIONS}" \
  --env="${ENV_VAR_1}" \
  --env="${ENV_VAR_2}" \
  --overrides='{
    "spec": {
      "securityContext": {
        "runAsNonRoot": true,
        "runAsUser": '${USER_ID}',
        "runAsGroup": '${GROUP_ID}',
        "fsGroup": '${FS_GROUP_ID}',
        "seccompProfile": {
          "type": "RuntimeDefault"
        }
      },
      "containers": [{
        "name": "'${CONTAINER_NAME}'",
        "image": "'${IMAGE}':'${TAG}'",
        "ports": [{"containerPort": '${CONTAINER_PORT}', "name": "'${PORT_NAME}'"}],
        "securityContext": {
          "allowPrivilegeEscalation": false,
          "readOnlyRootFilesystem": true,
          "runAsNonRoot": true,
          "runAsUser": '${USER_ID}',
          "runAsGroup": '${GROUP_ID}',
          "capabilities": {
            "drop": ["ALL"]
          }
        },
        "resources": {
          "requests": {"memory": "'${MEMORY_REQUEST}'", "cpu": "'${CPU_REQUEST}'"},
          "limits": {"memory": "'${MEMORY_LIMIT}'", "cpu": "'${CPU_LIMIT}'"}
        },
        "volumeMounts": [
          {
            "name": "'${APP_NAME}'-config",
            "mountPath": "'${CONFIG_MOUNT_PATH}'",
            "subPath": "'${CONFIG_FILE_NAME}'",
            "readOnly": true
          },
          {
            "name": "'${APP_NAME}'-cache",
            "mountPath": "'${CACHE_MOUNT_PATH}'"
          },
          {
            "name": "'${APP_NAME}'-run",
            "mountPath": "'${RUN_MOUNT_PATH}'"
          },
          {
            "name": "'${APP_NAME}'-logs",
            "mountPath": "'${LOGS_MOUNT_PATH}'"
          }
        ],
        "livenessProbe": {
          "httpGet": {
            "path": "'${HEALTH_PATH}'",
            "port": '${CONTAINER_PORT}',
            "scheme": "HTTP"
          },
          "initialDelaySeconds": '${LIVENESS_INITIAL_DELAY}',
          "periodSeconds": '${LIVENESS_PERIOD}',
          "timeoutSeconds": '${LIVENESS_TIMEOUT}',
          "failureThreshold": '${LIVENESS_FAILURE_THRESHOLD}'
        },
        "readinessProbe": {
          "httpGet": {
            "path": "'${HEALTH_PATH}'",
            "port": '${CONTAINER_PORT}',
            "scheme": "HTTP"
          },
          "initialDelaySeconds": '${READINESS_INITIAL_DELAY}',
          "periodSeconds": '${READINESS_PERIOD}',
          "timeoutSeconds": '${READINESS_TIMEOUT}',
          "failureThreshold": '${READINESS_FAILURE_THRESHOLD}'
        },
        "startupProbe": {
          "httpGet": {
            "path": "'${HEALTH_PATH}'",
            "port": '${CONTAINER_PORT}',
            "scheme": "HTTP"
          },
          "initialDelaySeconds": '${STARTUP_INITIAL_DELAY}',
          "periodSeconds": '${STARTUP_PERIOD}',
          "timeoutSeconds": '${STARTUP_TIMEOUT}',
          "failureThreshold": '${STARTUP_FAILURE_THRESHOLD}'
        }
      }],
      "volumes": [
        {
          "name": "'${APP_NAME}'-config",
          "configMap": {
            "name": "'${APP_NAME}'-config",
            "items": [
              {
                "key": "'${CONFIG_FILE_NAME}'",
                "path": "'${CONFIG_FILE_NAME}'"
              }
            ]
          }
        },
        {
          "name": "'${APP_NAME}'-cache",
          "emptyDir": {}
        },
        {
          "name": "'${APP_NAME}'-run",
          "emptyDir": {}
        },
        {
          "name": "'${APP_NAME}'-logs",
          "emptyDir": {}
        }
      ]
    }
  }' \
  --dry-run=client \
  --output=yaml > ${OUTPUT_FILE}

echo "Nginx pod manifest created: ${OUTPUT_FILE}"
```

### create-apache.sh
```bash
#!/bin/bash
source apache.env

# Same kubectl run command structure as nginx, but uses apache.env variables
```

### create-redis.sh  
```bash
#!/bin/bash
source redis.env

# Same kubectl run command structure as nginx, but uses redis.env variables
```

## Directory Structure

```
kubernetes-templates/
├── envs/
│   ├── nginx.env
│   ├── apache.env
│   └── redis.env
├── scripts/
│   ├── create-pod.sh          # Generic script
│   ├── create-nginx.sh        # Nginx specific
│   ├── create-apache.sh       # Apache specific
│   └── create-redis.sh        # Redis specific
└── manifests/                 # Generated YAML files
    ├── nginx-web-secure.yaml
    ├── apache-web-secure.yaml
    └── redis-cache-secure.yaml
```

## Usage Examples

### Method 1: Generic Script
```bash
# Make script executable
chmod +x create-pod.sh

# Create pod using specific env file
./create-pod.sh nginx.env
./create-pod.sh apache.env
./create-pod.sh redis.env
```

### Method 2: Specific Scripts
```bash
# Make scripts executable
chmod +x create-nginx.sh create-apache.sh create-redis.sh

# Create specific pods
./create-nginx.sh
./create-apache.sh
./create-redis.sh
```

### Method 3: Source and run manually
```bash
# Source the environment file
source nginx.env

# Run the kubectl command directly (variables are now available)
kubectl run ${POD_NAME} --image=${IMAGE}:${TAG} --port=${CONTAINER_PORT} ...
```

## Benefits

1. **Clean separation**: Configuration is separate from execution logic
2. **Easy maintenance**: Update variables in `.env` files without touching scripts
3. **Reusable**: One script works with multiple `.env` files
4. **Version control friendly**: Track changes to configurations easily
5. **Environment specific**: Different `.env` files for dev, staging, prod
6. **Validation**: Script can validate required variables before execution

## Tips

- **Environment-specific configs**: Create `nginx-dev.env`, `nginx-prod.env`
- **Shared configs**: Use common variables across multiple `.env` files
- **Backup**: Keep `.env` files in version control
- **Security**: Use `.env.example` files for templates, keep secrets separate