# Troubleshooting Guide

Common issues and solutions for local Dify EE deployment.

---

## Quick Diagnostic

Run before troubleshooting:

```bash
scripts/verify-environment.sh
```

---

## Plugin System Issues

### UNAUTHORIZED When Building

**Error:**
```
UNAUTHORIZED: authentication required
checking push permission for "docker.io/xxx"
```

**Cause:** Trying to push to Docker Hub without credentials.

**Solution:**
1. Start local registry: `docker run -d -p 5050:5000 --name local-registry registry:2`
2. Update values.yaml:
```yaml
pluginBuilder:
  imageRepoPrefix: "host.docker.internal:5050"
  imageRepoType: docker
  insecureImageRepo: true
```
3. Apply: `helm upgrade dify <path> -n dify && kubectl rollout restart deployment dify-plugin-connector -n dify`

---

### ImagePullBackOff - HTTP/HTTPS Mismatch

**Error:**
```
http: server gave HTTP response to HTTPS client
Failed to pull image "host.docker.internal:5050/..."
```

**Cause:** Kind containerd not configured for insecure (HTTP) registry.

**Solution:**
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

**Verify:**
```bash
docker exec dify-ee-kind-worker cat /etc/containerd/certs.d/host.docker.internal:5050/hosts.toml
```

---

### ECR Repo Creation Fails

**Error:**
```
aws ecr describe-repositories ... Unable to locate credentials
```

**Cause:** `imageRepoType: ecr` in values.yaml but no AWS credentials.

**Solution:**
```yaml
pluginBuilder:
  imageRepoType: docker  # NOT ecr
```

---

### ConfigMap Shows Old Config

**Symptom:** Changed values.yaml but ConfigMap still shows old values (e.g., ECR).

**Solution:**
```bash
helm upgrade dify <path> -n dify
kubectl rollout restart deployment dify-plugin-connector -n dify

# Verify
kubectl get configmap dify-plugin-connector-config -n dify -o yaml | grep -E "repoType|imagePrefix"
```

---

## Storage (MinIO) Issues

### PrivkeyNotFoundError

**Error:**
```
PrivkeyNotFoundError: Private key not found, tenant_id: xxx
```

**Cause:** RSA private key couldn't be saved to MinIO (credential mismatch).

**Diagnosis:**
```bash
# Check actual MinIO credentials
docker exec dev-minio env | grep MINIO_ROOT

# Check what Dify is using
kubectl exec deploy/dify-api -n dify -- env | grep S3_ACCESS_KEY
```

**Solution (if mismatch):**
1. Update values.yaml with correct credentials
2. Apply:
```bash
helm upgrade dify <path> -n dify
kubectl rollout restart deployment dify-api dify-worker dify-plugin-daemon -n dify
```

**Solution (if keys already lost):**
```bash
# Generate new keys
openssl genpkey -algorithm RSA -out /tmp/private.pem -pkeyopt rsa_keygen_bits:2048
openssl rsa -pubout -in /tmp/private.pem -out /tmp/public.pem

# Get tenant ID from error, then update database
PUBLIC_KEY=$(cat /tmp/public.pem)
PGPASSWORD=devpassword psql -h localhost -p 55432 -U postgres -d dify -c \
  "UPDATE tenants SET encrypt_public_key = '$PUBLIC_KEY' WHERE id = '<tenant-id>';"

# Upload private key to MinIO (use mc, NOT docker cp)
docker cp /tmp/private.pem dev-minio:/tmp/priv.pem
docker exec dev-minio mc cp /tmp/priv.pem local/dify/privkeys/<tenant-id>/private.pem
```

---

### MinIO Access Denied

**Error:**
```
Access Denied when calling PutObject
```

**Cause:** Bucket permissions or corrupted directory.

**Solution:**
```bash
# Set public access
docker exec dev-minio mc anonymous set public local/dify

# If specific path corrupted, delete and recreate
docker exec dev-minio rm -rf /data/dify/<path>
# Then upload via mc (not docker cp)
```

**Important:** Never copy files directly to `/data/dify/`. MinIO is object storage - use `mc` or S3 API.

---

## Kubernetes Issues

### Pod CrashLoopBackOff

**Diagnosis:**
```bash
kubectl logs <pod-name> -n dify
kubectl describe pod <pod-name> -n dify
```

**Common causes:**
- Database connection failed → Check PostgreSQL is running
- Redis connection failed → Check Redis is running
- Plugin-daemon before plugin-connector → Wait for auto-recovery

---

### Nodes NotReady After containerd Restart

**Cause:** kubelet needs to reconnect to containerd.

**Solution:** Wait ~30 seconds, or:
```bash
docker exec dify-ee-kind-worker systemctl restart kubelet
docker exec dify-ee-kind-control-plane systemctl restart kubelet
kubectl wait --for=condition=Ready nodes --all --timeout=60s
```

---

### Connection Refused

**Symptom:** Pods can't connect to external services.

**Check:**
```bash
# Services running?
docker ps | grep -E "postgres|redis|minio|qdrant"

# Using correct host?
kubectl exec deploy/dify-api -n dify -- env | grep HOST
# Should show host.docker.internal, NOT localhost
```

---

## Helm Issues

### MinIO Post-Job Hangs

**Cause:** `minio.enabled: true` but using external MinIO.

**Solution:**
```yaml
minio:
  enabled: false
```

---

### Helm Upgrade Doesn't Apply

**Symptom:** Changed values but pods still use old config.

**Solution:**
```bash
# Force restart after upgrade
helm upgrade dify <path> -n dify
kubectl rollout restart deployment -n dify -l app.kubernetes.io/instance=dify
```

---

## Verification Commands

### Infrastructure
```bash
docker ps | grep -E "postgres|redis|minio|qdrant|registry"
kubectl get nodes
curl http://localhost:5050/v2/_catalog
```

### Dify Pods
```bash
kubectl get pods -n dify
kubectl get ingress -n dify
```

### Plugin System
```bash
kubectl get difyplugin -n dify
kubectl get jobs -n dify
curl http://localhost:5050/v2/_catalog  # Check for plugin images
```

### Logs
```bash
kubectl logs deploy/dify-api -n dify --tail=50
kubectl logs deploy/dify-plugin-connector -n dify --tail=50
kubectl logs deploy/dify-plugin-daemon -n dify --tail=50
```
