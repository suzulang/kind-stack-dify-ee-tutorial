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

## Quick Cleanup (All-in-One)

For complete cleanup, execute these steps in order:

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

After cleanup, verify:

```bash
# No Kind cluster
kind get clusters | grep dify-ee-kind || echo "Kind cluster removed"

# No Docker containers
docker ps | grep -E "(dev-postgres|dev-redis|dev-minio|dev-qdrant)" || echo "Containers removed"
```
