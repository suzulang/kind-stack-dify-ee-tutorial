---
name: dify-ee-local
description: |
  Deploy Dify Enterprise Edition to a local Kind (Kubernetes in Docker) cluster.
  Use when: (1) Setting up local Dify EE development environment, (2) "deploy dify enterprise locally",
  (3) "setup dify ee on kind", (4) "local kubernetes dify". Requires: Docker, kubectl, Helm, Kind.
---

# Dify EE Local Deployment

Deploy Dify Enterprise Edition to a local Kind cluster.

## Required Paths

Ask user for:
1. **kind-stack path**: Directory containing `kind-cluster/` and `infrastructure/`
2. **Helm Chart path**: Directory containing Dify EE `Chart.yaml` and `values.yaml`

## Quick Start

```
Phase 1: Infrastructure  →  Phase 2: Configure  →  Phase 3: Deploy  →  Phase 4: Verify
```

---

## Phase 1: Infrastructure Setup

See [references/infrastructure.md](references/infrastructure.md) for detailed setup.

### 1.1 Create Kind Cluster

```bash
cd <kind-stack-path>/kind-cluster && ./init.sh
kubectl get nodes  # Verify: 2 nodes Ready
```

### 1.2 Start Local Registry

```bash
docker run -d -p 5050:5000 --restart=always --name local-registry registry:2
```

### 1.3 Configure Kind for Insecure Registry

```bash
for node in dify-ee-kind-control-plane dify-ee-kind-worker; do
  docker exec $node mkdir -p /etc/containerd/certs.d/host.docker.internal:5050
  docker exec $node sh -c 'cat > /etc/containerd/certs.d/host.docker.internal:5050/hosts.toml << EOF
server = "http://host.docker.internal:5050"
[host."http://host.docker.internal:5050"]
  capabilities = ["pull", "resolve", "push"]
  skip_verify = true
EOF'
  docker exec $node systemctl restart containerd
done
kubectl wait --for=condition=Ready nodes --all --timeout=60s
```

### 1.4 Start External Services

```bash
cd <kind-stack-path>/infrastructure
docker compose up -d
./init-databases.sh
```

### 1.5 Get MinIO Credentials

```bash
docker exec dev-minio env | grep MINIO_ROOT
# Note: Use these exact values in values.yaml
```

### 1.6 Create MinIO Bucket

```bash
MINIO_USER=$(docker exec dev-minio env | grep MINIO_ROOT_USER | cut -d= -f2)
MINIO_PASS=$(docker exec dev-minio env | grep MINIO_ROOT_PASSWORD | cut -d= -f2)
docker exec dev-minio mc alias set local http://localhost:9000 "$MINIO_USER" "$MINIO_PASS"
docker exec dev-minio mc mb local/dify --ignore-existing
docker exec dev-minio mc anonymous set public local/dify
```

---

## Phase 2: Configure values.yaml

See [references/helm-config.md](references/helm-config.md) for complete configuration.

### Critical Settings

```yaml
# Storage - USE ACTUAL MINIO CREDENTIALS FROM STEP 1.5
persistence:
  type: "s3"
  s3:
    endpoint: "http://host.docker.internal:9000"
    accessKey: "<MINIO_ROOT_USER>"
    secretKey: "<MINIO_ROOT_PASSWORD>"
    bucketName: "dify"
    useAwsS3: false

minio:
  enabled: false

# Plugin Builder - USE LOCAL REGISTRY
pluginBuilder:
  insecureImageRepo: true
  imageRepoPrefix: "host.docker.internal:5050"
  imageRepoType: docker
```

---

## Phase 3: Deploy

```bash
helm install dify <helm-chart-path> -n dify --create-namespace --timeout 10m
kubectl get pods -n dify  # Wait for all Running
```

### Verify Plugin Builder Config

```bash
kubectl get configmap dify-plugin-connector-config -n dify -o yaml | grep -E "repoType|imagePrefix"
# Expected: repoType: "docker", imagePrefix: "host.docker.internal:5050"
```

If incorrect: `helm upgrade dify <helm-chart-path> -n dify && kubectl rollout restart deployment dify-plugin-connector -n dify`

---

## Phase 4: Configure Access

Add to `/etc/hosts`:
```
127.0.0.1 console.dify.local app.dify.local api.dify.local enterprise.dify.local files.dify.local trigger.dify.local
```

Access: http://console.dify.local

---

## Phase 5: Verify Plugin System

See [references/plugin-system.md](references/plugin-system.md) for complete plugin installation flow.

```bash
# Install any plugin from Marketplace, then monitor:
kubectl get difyplugin,jobs -n dify -w
# Expected: DifyPlugin status → Building → Running
```

---

## Troubleshooting

See [references/troubleshooting.md](references/troubleshooting.md) for common issues.

**Quick checks:**
```bash
scripts/verify-environment.sh  # Run before deploy
```

| Symptom | Likely Cause | Reference |
|---------|--------------|-----------|
| Plugin UNAUTHORIZED | Missing local registry | infrastructure.md |
| Plugin ImagePullBackOff | Kind insecure registry not configured | infrastructure.md |
| PrivkeyNotFoundError | MinIO credentials mismatch | troubleshooting.md |
| ConfigMap has ECR | Helm config not applied | troubleshooting.md |
