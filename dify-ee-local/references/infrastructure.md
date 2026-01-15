# Infrastructure Layer

Local Dify EE requires these infrastructure components:

| Component | Container | Port | Purpose |
|-----------|-----------|------|---------|
| Kind Cluster | dify-ee-kind-* | - | Kubernetes runtime |
| Local Registry | local-registry | 5050 | Plugin image storage |
| PostgreSQL | dev-postgres | 55432 | Database |
| Redis | dev-redis | 6379 | Cache & Queue |
| MinIO | dev-minio | 9000/9001 | S3-compatible storage |
| Qdrant | dev-qdrant | 6333/6334 | Vector database |

---

## Kind Cluster

### Create Cluster

```bash
cd <kind-stack-path>/kind-cluster
./init.sh
```

### Verify

```bash
kubectl cluster-info --context kind-dify-ee-kind
kubectl get nodes
# Expected: 2 nodes (control-plane + worker), both Ready
```

### Delete Cluster (cleanup)

```bash
kind delete cluster --name dify-ee-kind
```

---

## Local Image Registry

**Why needed**: Plugin system builds Docker images via Kaniko and needs a registry to push/pull. Docker Hub requires authentication; local registry doesn't.

### Setup

```bash
# Port 5050 to avoid macOS AirPlay conflict on 5000
docker run -d -p 5050:5000 --restart=always --name local-registry registry:2
```

### Verify

```bash
curl http://localhost:5050/v2/_catalog
# Expected: {"repositories":[]}
```

### Configure Kind for HTTP Registry

Kind uses containerd which defaults to HTTPS. Must configure for HTTP:

```bash
for node in dify-ee-kind-control-plane dify-ee-kind-worker; do
  docker exec $node mkdir -p /etc/containerd/certs.d/host.docker.internal:5050
  docker exec $node sh -c 'cat > /etc/containerd/certs.d/host.docker.internal:5050/hosts.toml << EOF
server = "http://host.docker.internal:5050"

[host."http://host.docker.internal:5050"]
  capabilities = ["pull", "resolve", "push"]
  skip_verify = true
EOF'
done

# Restart containerd (nodes will briefly go NotReady)
docker exec dify-ee-kind-control-plane systemctl restart containerd
docker exec dify-ee-kind-worker systemctl restart containerd

# Wait for recovery
sleep 10
kubectl wait --for=condition=Ready nodes --all --timeout=60s
```

### Verify Configuration

```bash
docker exec dify-ee-kind-worker cat /etc/containerd/certs.d/host.docker.internal:5050/hosts.toml
```

### List Images After Plugin Install

```bash
curl -s http://localhost:5050/v2/_catalog
# Shows: {"repositories":["openai-xxx","deepseek-xxx",...]}
```

---

## PostgreSQL

### Connection Info

| Property | Value |
|----------|-------|
| Host (from Kind) | host.docker.internal |
| Port | 55432 |
| Username | postgres |
| Password | devpassword |

### Required Databases

- `dify` - Main application
- `plugin_daemon` - Plugin daemon
- `enterprise` - Enterprise features
- `audit` - Audit logs

### Initialize

```bash
cd <kind-stack-path>/infrastructure
./init-databases.sh
```

### Manual Creation (if needed)

```bash
PGPASSWORD=devpassword psql -h localhost -p 55432 -U postgres << EOF
CREATE DATABASE dify;
CREATE DATABASE plugin_daemon;
CREATE DATABASE enterprise;
CREATE DATABASE audit;
EOF
```

---

## Redis

### Connection Info

| Property | Value |
|----------|-------|
| Host (from Kind) | host.docker.internal |
| Port | 6379 |
| Password | devpassword |

### Test Connection

```bash
docker exec dev-redis redis-cli -a devpassword PING
# Expected: PONG
```

---

## MinIO (S3-Compatible Storage)

### Connection Info

| Property | Value |
|----------|-------|
| Endpoint (from Kind) | http://host.docker.internal:9000 |
| Console | http://localhost:9001 |
| Bucket | dify |

### Get Credentials

```bash
docker exec dev-minio env | grep MINIO_ROOT
```

**CRITICAL**: Use the exact values shown in `values.yaml`. Credential mismatch causes RSA key save failures.

### Setup Bucket

```bash
MINIO_USER=$(docker exec dev-minio env | grep MINIO_ROOT_USER | cut -d= -f2)
MINIO_PASS=$(docker exec dev-minio env | grep MINIO_ROOT_PASSWORD | cut -d= -f2)

docker exec dev-minio mc alias set local http://localhost:9000 "$MINIO_USER" "$MINIO_PASS"
docker exec dev-minio mc mb local/dify --ignore-existing
docker exec dev-minio mc anonymous set public local/dify
```

### What's Stored in MinIO

| Path | Content |
|------|---------|
| `plugin_packages/` | Downloaded .difypkg files |
| `connector_build_caches/` | Build context tar files for Kaniko |
| `privkeys/` | RSA private keys (per tenant) |
| `assets/` | Plugin assets (icons, etc.) |

### Troubleshooting MinIO

**View bucket contents:**
```bash
docker exec dev-minio mc ls local/dify/ --recursive
```

**Upload via mc (correct way):**
```bash
docker exec dev-minio mc cp /path/to/file local/dify/path/to/destination
```

**DO NOT** copy files directly to `/data/dify/` - MinIO is object storage, not a filesystem.

---

## Qdrant (Vector Database)

### Connection Info

| Property | Value |
|----------|-------|
| Endpoint (from Kind) | http://host.docker.internal:6333 |
| API Key | devpassword |

### Test Connection

```bash
curl http://localhost:6333/collections
```

---

## Network Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Host Machine (macOS)                      │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              Docker Containers                        │   │
│  │                                                       │   │
│  │  dev-postgres:55432  dev-redis:6379  dev-minio:9000  │   │
│  │  dev-qdrant:6333     local-registry:5050             │   │
│  └──────────────────────────────────────────────────────┘   │
│                           │                                  │
│                           │ host.docker.internal             │
│                           ▼                                  │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              Kind Cluster (Docker-in-Docker)          │   │
│  │                                                       │   │
│  │  ┌─────────────────┐  ┌─────────────────────────┐    │   │
│  │  │ control-plane   │  │ worker                  │    │   │
│  │  │                 │  │                         │    │   │
│  │  │ (k8s system)    │  │ dify-api, dify-web,    │    │   │
│  │  │                 │  │ plugin-*, etc.          │    │   │
│  │  └─────────────────┘  └─────────────────────────┘    │   │
│  └──────────────────────────────────────────────────────┘   │
│                           │                                  │
│                           │ localhost:80 (via Ingress)       │
│                           ▼                                  │
│                    Browser Access                            │
│               http://console.dify.local                      │
└─────────────────────────────────────────────────────────────┘
```

**Key Point**: Pods in Kind access external services via `host.docker.internal`, not `localhost`.
