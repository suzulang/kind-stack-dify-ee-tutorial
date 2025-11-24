#!/usr/bin/env bash
set -e

# 默认代理地址
DEFAULT_PROXY_URL="http://host.docker.internal:7890"
NO_PROXY_LIST="127.0.0.1,localhost,host.docker.internal,.svc,.cluster.local,10.0.0.0/8"

# 交互式配置代理
echo ""
echo "📌 代理配置（可选）"
read -p "是否需要配置代理? [Y/n]: " -n 1 -r
echo ""

USE_PROXY=true
PROXY_URL=""
if [[ $REPLY =~ ^[Nn]$ ]]; then
    USE_PROXY=false
    echo "✓ 跳过代理配置"
else
    echo ""
    read -p "请输入代理地址 [默认: ${DEFAULT_PROXY_URL}]: " PROXY_URL
    PROXY_URL=${PROXY_URL:-${DEFAULT_PROXY_URL}}
    
    echo ""
    echo "📌 设置代理环境变量..."
    export HTTP_PROXY="${PROXY_URL}"
    export HTTPS_PROXY="${PROXY_URL}"
    export http_proxy="${PROXY_URL}"
    export https_proxy="${PROXY_URL}"
    export NO_PROXY="${NO_PROXY_LIST}"
    export no_proxy="${NO_PROXY_LIST}"
    
    echo "✓ 代理环境变量已设置:"
    echo "  HTTP_PROXY=$HTTP_PROXY"
    echo "  HTTPS_PROXY=$HTTPS_PROXY"
    echo "  NO_PROXY=$NO_PROXY"
fi

# kind config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.yaml"

# 检查配置文件是否存在
if [ ! -f "${CONFIG_FILE}" ]; then
    echo "❌ 错误: 配置文件 ${CONFIG_FILE} 不存在"
    exit 1
fi

echo "✓ 使用配置文件: ${CONFIG_FILE}"

# 检查集群是否已存在
if kind get clusters 2>/dev/null | grep -q "^dify-ee-kind$"; then
    echo ""
    echo "⚠️  检测到已存在的集群: dify-ee-kind"
    read -p "是否删除现有集群并重新创建? [y/N]: " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ 操作已取消"
        exit 0
    fi
    echo "➤ 正在删除现有集群..."
    kind delete cluster --name dify-ee-kind
else
    echo "✓ 未检测到现有集群"
fi

if [ "$USE_PROXY" = true ]; then
    echo "➤ Creating new kind cluster with proxy settings..."
else
    echo "➤ Creating new kind cluster..."
fi
kind create cluster --name dify-ee-kind --config "${CONFIG_FILE}"

echo "✅ 集群创建完成，正在验证..."
if [ "$USE_PROXY" = true ]; then
    echo "✓ 验证代理配置..."
    docker exec dify-ee-kind-control-plane env | grep -i proxy || echo "⚠️  警告: 控制平面节点中未找到代理变量"
else
    echo "✓ 代理未配置，跳过验证"
fi

echo ""
echo "➤ Installing NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

echo "⏳ Waiting for NGINX Ingress Controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

echo ""
echo "✅ NGINX Ingress Controller installed successfully!"
echo ""
echo "📊 Ingress Controller status:"
kubectl get pods -n ingress-nginx -o wide

echo ""
echo "🎉 Done."
