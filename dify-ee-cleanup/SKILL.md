---
name: dify-ee-cleanup
description: |
  Completely uninstall and clean up Dify Enterprise Edition local development environment.
  Use when: (1) "cleanup dify", (2) "uninstall dify ee", (3) "remove dify local environment",
  (4) "clean up kind cluster dify", (5) "delete dify deployment".
  Removes: Kind cluster, Docker containers, and persistent data.
---

# Dify EE Cleanup

Completely remove Dify Enterprise Edition local development environment.

## Required Path

Ask user for **kind-stack path**: Directory containing `kind-cluster/` and `infrastructure/`

---

## Infrastructure Components

| Component | Container | Port | Cleanup |
|-----------|-----------|------|---------|
| Kind Cluster | dify-ee-kind-* | - | Core |
| PostgreSQL | dev-postgres | 55432 | Core |
| Redis | dev-redis | 6379 | Core |
| MinIO | dev-minio | 9000/9001 | Core |
| Qdrant | dev-qdrant | 6333/6334 | Core |
| Local Registry | local-registry | 5050 | Optional |

---

## Quick Cleanup (Core)

Execute these steps in order:

### Step 1: Uninstall Helm Release

```bash
helm uninstall dify -n dify 2>/dev/null || true
kubectl delete namespace dify --ignore-not-found
```

### Step 2: Delete Kind Cluster

```bash
kind delete cluster --name dify-ee-kind
```

### Step 3: Stop and Remove Infrastructure Containers

```bash
cd <kind-stack-path>/infrastructure
docker compose -f docker-compose.yaml down -v --rmi all
```

### Step 4: Clean Persistent Data

```bash
rm -rf <kind-stack-path>/infrastructure/data/*
```

---

## Optional Cleanup

### Optional: Remove Local Registry

⚠️ **Warning**: Only remove if not used by other projects.

The local registry (`local-registry:5050`) may be shared by multiple projects.

```bash
# Check if registry has other images
curl -s http://localhost:5050/v2/_catalog

# Remove if only Dify images or empty
docker rm -f local-registry
```

### Optional: Remove /etc/hosts Entries

```bash
sudo sed -i '' '/dify.local/d' /etc/hosts
```

Or manually remove these lines from `/etc/hosts`:
- 127.0.0.1 console.dify.local
- 127.0.0.1 app.dify.local
- 127.0.0.1 api.dify.local
- 127.0.0.1 enterprise.dify.local
- 127.0.0.1 files.dify.local
- 127.0.0.1 trigger.dify.local

---

## Partial Cleanup Options

### Only K8s Resources (Keep Infrastructure)

```bash
helm uninstall dify -n dify
kubectl delete namespace dify
```

### Only Infrastructure (Keep K8s)

```bash
cd <kind-stack-path>/infrastructure
docker compose -f docker-compose.yaml down -v --rmi all
rm -rf <kind-stack-path>/infrastructure/data/*
```

### Only Kind Cluster (Keep Docker Containers)

```bash
kind delete cluster --name dify-ee-kind
```

---

## Verification

### Core Verification

```bash
# No Kind cluster
kind get clusters | grep dify-ee-kind || echo "Kind cluster removed"

# No infrastructure containers
docker ps | grep -E "(dev-postgres|dev-redis|dev-minio|dev-qdrant)" || echo "Infrastructure removed"
```

### Optional Verification

```bash
# Local registry removed
docker ps | grep local-registry || echo "Local registry removed"

# Hosts entries removed
grep dify.local /etc/hosts || echo "Hosts entries removed"
```
