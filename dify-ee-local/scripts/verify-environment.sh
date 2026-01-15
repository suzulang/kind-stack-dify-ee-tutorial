#!/bin/bash
# Verify Dify EE local environment setup
# Run this before helm install to catch common issues

set -e

echo "🔍 Verifying Dify EE Local Environment..."
echo ""

ERRORS=0

# 1. Check Kind cluster
echo "1. Checking Kind cluster..."
if kubectl cluster-info --context kind-dify-ee-kind &>/dev/null; then
    echo "   ✅ Kind cluster is running"

    # Check nodes
    READY_NODES=$(kubectl get nodes --context kind-dify-ee-kind --no-headers 2>/dev/null | grep -c "Ready" || echo "0")
    if [ "$READY_NODES" -ge 2 ]; then
        echo "   ✅ All nodes Ready ($READY_NODES nodes)"
    else
        echo "   ❌ Not all nodes Ready ($READY_NODES nodes)"
        ERRORS=$((ERRORS+1))
    fi
else
    echo "   ❌ Kind cluster not found"
    ERRORS=$((ERRORS+1))
fi
echo ""

# 2. Check local registry
echo "2. Checking local registry..."
if docker ps | grep -q "local-registry"; then
    echo "   ✅ Local registry container running"

    # Check accessibility
    if curl -s http://localhost:5050/v2/_catalog &>/dev/null; then
        echo "   ✅ Registry accessible at localhost:5050"
    else
        echo "   ❌ Registry not accessible"
        ERRORS=$((ERRORS+1))
    fi
else
    echo "   ❌ Local registry not running"
    echo "   💡 Fix: docker run -d -p 5050:5000 --restart=always --name local-registry registry:2"
    ERRORS=$((ERRORS+1))
fi
echo ""

# 3. Check Kind insecure registry config
echo "3. Checking Kind insecure registry config..."
for node in dify-ee-kind-control-plane dify-ee-kind-worker; do
    if docker exec $node cat /etc/containerd/certs.d/host.docker.internal:5050/hosts.toml &>/dev/null; then
        echo "   ✅ $node: insecure registry configured"
    else
        echo "   ❌ $node: insecure registry NOT configured"
        echo "   💡 Fix: See Phase 1.3 in SKILL.md"
        ERRORS=$((ERRORS+1))
    fi
done
echo ""

# 4. Check infrastructure services
echo "4. Checking infrastructure services..."
SERVICES=("dev-postgres" "dev-redis" "dev-minio" "dev-qdrant")
for svc in "${SERVICES[@]}"; do
    if docker ps | grep -q "$svc"; then
        echo "   ✅ $svc running"
    else
        echo "   ❌ $svc not running"
        ERRORS=$((ERRORS+1))
    fi
done
echo ""

# 5. Check MinIO credentials
echo "5. Checking MinIO credentials..."
if docker ps | grep -q "dev-minio"; then
    MINIO_USER=$(docker exec dev-minio env | grep MINIO_ROOT_USER | cut -d= -f2)
    MINIO_PASS=$(docker exec dev-minio env | grep MINIO_ROOT_PASSWORD | cut -d= -f2)
    echo "   📋 MinIO credentials:"
    echo "      MINIO_ROOT_USER=$MINIO_USER"
    echo "      MINIO_ROOT_PASSWORD=$MINIO_PASS"
    echo ""
    echo "   ⚠️  Make sure values.yaml has:"
    echo "      persistence.s3.accessKey: \"$MINIO_USER\""
    echo "      persistence.s3.secretKey: \"$MINIO_PASS\""
fi
echo ""

# 6. Check MinIO bucket
echo "6. Checking MinIO bucket..."
if docker exec dev-minio mc ls local/dify &>/dev/null; then
    echo "   ✅ MinIO bucket 'dify' exists"
else
    echo "   ❌ MinIO bucket 'dify' not found"
    echo "   💡 Fix: See Phase 1.7 in SKILL.md"
    ERRORS=$((ERRORS+1))
fi
echo ""

# Summary
echo "=========================================="
if [ $ERRORS -eq 0 ]; then
    echo "✅ All checks passed! Ready to deploy."
else
    echo "❌ Found $ERRORS issue(s). Please fix before deploying."
fi
echo "=========================================="

exit $ERRORS
