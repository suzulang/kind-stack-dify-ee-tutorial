---
name: dify-ee-local
description: |
  Deploy Dify Enterprise Edition to a local Kind (Kubernetes in Docker) cluster.
  Use when: (1) Setting up local Dify EE development environment, (2) "deploy dify enterprise locally",
  (3) "setup dify ee on kind", (4) "local kubernetes dify". Requires: Docker, kubectl, Helm, Kind.
  Uses kind-stack-dify-ee-tutorial for infrastructure and user-provided Helm Chart.
---

# Dify EE Local Deployment

Deploy Dify Enterprise Edition to a local Kind cluster in 4 phases.

## Prerequisites

Run `scripts/check-prerequisites.sh` to verify:
- Docker (20.10+)
- kubectl (1.24+)
- Helm (3.x)
- Kind (0.20+)

## Required Paths

Ask user for:
1. **kind-stack path**: Directory containing `kind-cluster/` and `infrastructure/`
2. **Helm Chart path**: Directory containing Dify EE `Chart.yaml` and `values.yaml`

---

## Phase 1: Infrastructure Setup

### 1.1 Create Kind Cluster

```bash
cd <kind-stack-path>/kind-cluster
./init.sh
```

Verify:
```bash
kubectl cluster-info --context kind-dify-ee-kind
kubectl get nodes
```

### 1.2 Start Infrastructure Services

```bash
cd <kind-stack-path>/infrastructure
docker compose -f docker-compose.yaml up -d
```

Verify:
```bash
docker ps | grep -E "(dev-postgres|dev-redis|dev-minio|dev-qdrant)"
```

### 1.3 Initialize Databases

```bash
./init-databases.sh
```

Use defaults: host=localhost, port=55432, user=postgres, password=devpassword

Creates databases: `dify`, `plugin_daemon`, `enterprise`, `audit`

---

## Phase 2: Configure values.yaml

See [references/values-config.md](references/values-config.md) for complete configuration.

### 2.1 Generate Secrets

Run `scripts/generate-secrets.sh` to generate required keys.

### 2.2 Key Configuration Changes

Edit `<helm-chart-path>/values.yaml`:

**Global secrets:**
```yaml
global:
  appSecretKey: "<generated-key>"
```

**Domains (fixed):**
```yaml
global:
  consoleApiDomain: "console.dify.local"
  consoleWebDomain: "console.dify.local"
  serviceApiDomain: "api.dify.local"
  appApiDomain: "app.dify.local"
  appWebDomain: "app.dify.local"
  filesDomain: "files.dify.local"
  enterpriseDomain: "enterprise.dify.local"
  triggerDomain: "trigger.dify.local"
```

**Enable Ingress:**
```yaml
ingress:
  enabled: true
  className: "nginx"
```

**External PostgreSQL:**
```yaml
externalPostgres:
  enabled: true
  address: host.docker.internal
  port: 55432
  credentials:
    dify:
      password: "devpassword"
      sslmode: "disable"
    # Same for plugin_daemon, enterprise, audit
```

**External Redis:**
```yaml
externalRedis:
  enabled: true
  host: "host.docker.internal"
  port: 6379
  password: "devpassword"
```

**External Qdrant:**
```yaml
vectorDB:
  useExternal: true
  externalType: "qdrant"
  externalQdrant:
    endpoint: "http://host.docker.internal:6333"
    apiKey: "devpassword"
```

**External MinIO (S3):**
```yaml
persistence:
  type: "s3"
  s3:
    endpoint: "http://host.docker.internal:9000"
    accessKey: "minioadmin"
    secretKey: "minioadmin123"
    bucketName: "dify"
    useAwsS3: false

minio:
  enabled: false
```

### 2.3 Create MinIO Bucket

```bash
docker exec dev-minio mc alias set local http://localhost:9000 minioadmin minioadmin123
docker exec dev-minio mc mb local/dify --ignore-existing
```

---

## Phase 3: Deploy

### 3.1 Install Helm Chart

```bash
helm install dify <helm-chart-path> --namespace dify --create-namespace --timeout 10m
```

### 3.2 Verify Deployment

```bash
kubectl get pods -n dify
kubectl get ingress -n dify
```

Wait for all pods to be Running (16 pods expected).

---

## Phase 4: Configure Hosts

### 4.1 Add DNS Mappings

Run `scripts/show-hosts-config.sh` to display the hosts configuration.

Add to `/etc/hosts`:
```
127.0.0.1 console.dify.local
127.0.0.1 app.dify.local
127.0.0.1 api.dify.local
127.0.0.1 enterprise.dify.local
127.0.0.1 files.dify.local
127.0.0.1 trigger.dify.local
```

### 4.2 Verify Access

```bash
curl -s -o /dev/null -w "%{http_code}" http://console.dify.local
curl -s -o /dev/null -w "%{http_code}" http://enterprise.dify.local
```

Expected: 307 (redirect) or 200

---

## Access URLs

- Console: http://console.dify.local
- Enterprise Admin: http://enterprise.dify.local
- WebApp: http://app.dify.local

---

## Troubleshooting

### Pod CrashLoopBackOff

Check logs: `kubectl logs <pod-name> -n dify`

Common cause: plugin-daemon starts before plugin-connector. Wait for auto-recovery.

### MinIO Job Timeout

Ensure `minio.enabled: false` in values.yaml when using external MinIO.

### Connection Refused

Verify infrastructure containers: `docker ps`
Verify Kind cluster: `kubectl get nodes`
