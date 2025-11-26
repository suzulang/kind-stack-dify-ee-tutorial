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
echo "⏳ 等待集群就绪..."

# 简单的 API Server 检查
for i in {1..30}; do
    if kubectl cluster-info --request-timeout=5s >/dev/null 2>&1; then
        echo "✓ API 服务器已就绪"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ 错误: 无法连接到 Kubernetes API 服务器"
        exit 1
    fi
    sleep 2
done

# 节点就绪检查（超时缩短为 60s）
kubectl wait --for=condition=Ready nodes --all --timeout=60s >/dev/null 2>&1 || echo "⚠️  等待节点就绪超时，但继续执行..."

echo ""
echo "📌 NGINX Ingress Controller 安装（可选）"
read -p "是否安装 NGINX Ingress Controller? [Y/n]: " -n 1 -r
echo ""

INSTALL_INGRESS=true
if [[ $REPLY =~ ^[Nn]$ ]]; then
    INSTALL_INGRESS=false
    echo "✓ 跳过 NGINX Ingress Controller 安装"
else
    echo "✓ 将安装 NGINX Ingress Controller"
fi

if [ "$INSTALL_INGRESS" = true ]; then
    echo ""
echo "➤ Installing NGINX Ingress Controller..."
    # 添加重试逻辑
    INGRESS_URL="https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml"
    INGRESS_YAML="/tmp/ingress-nginx-deploy.yaml"

    # 临时调整宿主机代理设置
    # 注意：之前的代理设置 (host.docker.internal) 是给 Docker 容器内使用的
    # 在宿主机执行 curl/kubectl 时，需要使用 localhost
    if [ "$USE_PROXY" = true ]; then
        HOST_PROXY_URL=$(echo "$PROXY_URL" | sed 's/host.docker.internal/127.0.0.1/')
        echo "🔄 调整宿主机代理为: $HOST_PROXY_URL"
        export HTTP_PROXY="$HOST_PROXY_URL"
        export HTTPS_PROXY="$HOST_PROXY_URL"
        export http_proxy="$HOST_PROXY_URL"
        export https_proxy="$HOST_PROXY_URL"
    fi

    echo "  📥 正在下载 Ingress Controller 清单..."
    if curl -L --retry 3 --retry-delay 5 --connect-timeout 10 -o "${INGRESS_YAML}" "${INGRESS_URL}"; then
        echo "✓ 下载成功"
    else
        echo "❌ 下载失败，请检查网络连接"
        exit 1
    fi

    # 确保上下文正确
    kubectl cluster-info --context kind-dify-ee-kind >/dev/null 2>&1

    CONTROL_PLANE_NODE="dify-ee-kind-control-plane"
    kubectl label node "${CONTROL_PLANE_NODE}" ingress-ready=true --overwrite >/dev/null 2>&1 || true

    TMP_INGRESS_DIR=$(mktemp -d)
    cp "${INGRESS_YAML}" "${TMP_INGRESS_DIR}/base.yaml"
    cat > "${TMP_INGRESS_DIR}/ingress-node-patch.yaml" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ingress-nginx-controller
  namespace: ingress-nginx
spec:
  template:
    spec:
      nodeSelector:
        kubernetes.io/hostname: "${CONTROL_PLANE_NODE}"
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule
EOF

    cat > "${TMP_INGRESS_DIR}/kustomization.yaml" <<EOF
resources:
  - base.yaml
patchesStrategicMerge:
  - ingress-node-patch.yaml
EOF

    for i in {1..5}; do
        echo "  尝试应用 Ingress Controller 清单... ($i/5)"
        if kubectl apply --context kind-dify-ee-kind -k "${TMP_INGRESS_DIR}" --request-timeout=30s; then
            echo "✓ Ingress Controller 清单应用成功"
            rm -f "${INGRESS_YAML}"
            rm -rf "${TMP_INGRESS_DIR}"
            break
        else
            APPLY_EXIT_CODE=$?
            if [ $i -eq 5 ]; then
                echo "❌ 错误: 应用 Ingress Controller 清单失败 (退出码: ${APPLY_EXIT_CODE})"
                echo "⚠️  如果脚本失败但手动执行成功，可能是脚本环境问题。"
                read -p "请尝试在另一个终端手动执行 'kubectl apply -k ${TMP_INGRESS_DIR}'，完成后按回车继续..."
                if kubectl get ns ingress-nginx >/dev/null 2>&1; then
                     echo "✓ 检测到手动安装成功，继续..."
                     rm -f "${INGRESS_YAML}"
                     rm -rf "${TMP_INGRESS_DIR}"
                     break
                else
                     echo "❌ 仍未检测到 ingress-nginx 命名空间，退出。"
                     rm -f "${INGRESS_YAML}"
                     rm -rf "${TMP_INGRESS_DIR}"
                     exit 1
                fi
            fi
            echo "  连接失败，等待后重试..."
            sleep 5
        fi
    done

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
fi

echo ""
echo "🎉 Done."
