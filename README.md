# AI Instructions

> This section is for AI assistants. Humans can skip to [Kind Stack - Dify Enterprise Edition](#kind-stack---dify-enterprise-edition).

## Available Skills

This repository provides two skills for AI-assisted Dify EE local deployment:

### 1. `dify-ee-local` - Deploy Dify EE

**Triggers**: "deploy dify enterprise locally", "setup dify ee on kind", "local kubernetes dify"

**Workflow**:
1. Ask user for: (a) kind-stack path, (b) Helm Chart path
2. Run `scripts/check-prerequisites.sh` to verify Docker, kubectl, Helm, Kind
3. Phase 1: Infrastructure Setup
   - `cd <kind-stack-path>/kind-cluster && ./init.sh`
   - `cd <kind-stack-path>/infrastructure && docker compose up -d`
   - `./init-databases.sh` (use defaults)
4. Phase 2: Configure `values.yaml` using [dify-ee-local/references/values-config.md](dify-ee-local/references/values-config.md)
5. Phase 3: `helm install dify <helm-chart-path> --namespace dify --create-namespace`
6. Phase 4: Add hosts entries (run `scripts/show-hosts-config.sh`)

**Access URLs**: console.dify.local, enterprise.dify.local, app.dify.local

### 2. `dify-ee-cleanup` - Remove Dify EE

**Triggers**: "cleanup dify", "uninstall dify ee", "remove dify local environment", "delete dify deployment"

**Quick Cleanup**:
```bash
helm uninstall dify -n dify 2>/dev/null || true
kubectl delete namespace dify --ignore-not-found
kind delete cluster --name dify-ee-kind
cd <kind-stack-path>/infrastructure && docker compose down -v --rmi all
rm -rf <kind-stack-path>/infrastructure/data/*
```

## Key Infrastructure Details

| Service    | Host (from Kind)         | Port  | Credentials               |
|------------|--------------------------|-------|---------------------------|
| PostgreSQL | host.docker.internal     | 55432 | postgres / devpassword    |
| Redis      | host.docker.internal     | 6379  | devpassword               |
| Qdrant     | host.docker.internal     | 6333  | devpassword               |
| MinIO      | host.docker.internal     | 9000  | minioadmin / minioadmin123|

**Databases**: dify, plugin_daemon, enterprise, audit

## File Structure for AI

```
kind-cluster/init.sh          # Creates Kind cluster + Ingress
infrastructure/docker-compose.yaml  # PostgreSQL, Redis, Qdrant, MinIO
infrastructure/init-databases.sh    # Creates required databases
dify-ee-local/SKILL.md        # Full deployment instructions
dify-ee-cleanup/SKILL.md      # Full cleanup instructions
```

---

# Kind Stack - Dify Enterprise Edition

为在本地 Kind (Kubernetes in Docker) 集群上部署 Dify Enterprise Edition 提供前置准备和基础设施配置。

## ⚠️ 重要提示

**本项目仅用于教学演示目的，不推荐用于测试和生产环境。**

本项目仅提供 Dify Enterprise Edition 部署的前置准备工作，包括：
- Kind 集群的创建和配置
- 数据持久化基础设施的部署
- 数据库的初始化

实际的 Dify Enterprise Edition 部署请参考官方文档。

## 📋 项目概述

本项目为安装 Dify Enterprise Edition 提供前置准备，包括：

- **Kind 集群管理**：自动化创建和配置 Kind 集群，支持代理配置
- **Ingress Controller**：自动安装 NGINX Ingress Controller
- **数据持久化基础设施**：PostgreSQL、Redis、Qdrant、MinIO 的 Docker Compose 部署
- **数据库初始化**：自动检查和创建所需的 PostgreSQL 数据库

## 🏗️ 项目结构

```
kind-stack/
├── kind-cluster/                    # Kind 集群相关配置
│   ├── init.sh                      # Kind 集群初始化脚本
│   └── config.yaml                  # Kind 集群配置文件
├── infrastructure/                  # 数据持久化基础设施
│   ├── docker-compose.yaml          # Docker Compose 配置（PostgreSQL、Redis、Qdrant、MinIO）
│   ├── init-databases.sh            # 数据库初始化脚本（Shell 版本）
│   ├── init-databases.py            # 数据库初始化脚本（Python 版本）
│   └── data/                        # 数据目录（已添加到 .gitignore）
│       ├── postgres/                # PostgreSQL 数据
│       ├── redis/                   # Redis 数据
│       ├── qdrant/                  # Qdrant 数据
│       └── minio/                   # MinIO 数据
├── .gitignore                       # Git 忽略规则
└── README.md                        # 本文件
```

## 🚀 快速开始

### 前置要求

- **Docker Desktop** 或 **Docker Engine** (20.10+)
- **kubectl** (1.24+)
- **Helm** 3.x
- **Kind** (0.20+)
- **PostgreSQL 客户端** (用于数据库检查)
- **Python** 3.8+ (可选，用于 Python 版本的数据库初始化脚本)

### 安装依赖

```bash
# macOS
brew install kind helm postgresql

# Linux (Ubuntu/Debian)
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# 安装 Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 安装 PostgreSQL 客户端
sudo apt-get install postgresql-client
```

## 📝 使用指南

### 步骤 1: 创建 Kind 集群并安装 NGINX Ingress Controller

运行初始化脚本创建 Kind 集群：

```bash
cd kind-cluster
./init.sh
```

脚本会自动完成以下操作：

1. **交互式配置代理**（可选）
   - 询问是否需要配置代理（默认：是）
   - 如果选择配置，提示输入代理地址（默认：`http://host.docker.internal:7890`）
   - 设置代理环境变量（HTTP_PROXY、HTTPS_PROXY、NO_PROXY）

2. **创建 Kind 集群**
   - `init.sh` 会先检查 `dify-ee-kind` 是否存在，必要时提示是否删除旧集群后再创建，避免脏状态
   - 集群名称：`dify-ee-kind`
   - 包含一个 control-plane 节点（端口映射：80→80, 443→443）
   - 包含一个 worker 节点（端口映射：80→8080, 443→8443）

3. **安装 NGINX Ingress Controller**
   - 自动安装并等待就绪
   - 安装过程将控制器 Deployment 使用 `nodeSelector` 与 `tolerations` 固定到 `dify-ee-kind-control-plane`，因为只有该节点映射了宿主机的 `80/443` 端口，确保外部流量能正确进入集群

**验证集群和 Ingress Controller**：

```bash
# 验证集群状态
kubectl cluster-info --context kind-dify-ee-kind
kubectl get nodes

# 验证 Ingress Controller 状态
kubectl get pods -n ingress-nginx
kubectl get pods -n ingress-nginx -o wide
```

### 步骤 2: 启动数据持久化基础设施

在启动 Dify 之前，需要先启动数据持久化服务（PostgreSQL、Redis、Qdrant、MinIO）：

```bash
cd infrastructure
docker compose -f docker-compose.yaml up -d
```

**验证服务启动**：

```bash
docker ps | grep -E "(dev-postgres|dev-redis|dev-minio|dev-qdrant)"
```

**服务端口映射**：

- PostgreSQL: `localhost:55432` → `容器:5432`
- Redis: `localhost:6379` → `容器:6379`
- MinIO API: `localhost:9000` → `容器:9000`
- MinIO Console: `localhost:9001` → `容器:9001`
- Qdrant: `localhost:6333` → `容器:6333`
- Qdrant Dashboard: `localhost:6334` → `容器:6334`

### 步骤 3: 初始化数据库

在部署 Dify 之前，需要确保所需的数据库已创建。可以使用 Shell 或 Python 版本的脚本：

**使用 Shell 脚本（推荐）**：

```bash
cd infrastructure
./init-databases.sh
```

**使用 Python 脚本**：

```bash
cd infrastructure
python3 init-databases.py
```

脚本会交互式提示输入数据库连接信息（所有字段都有默认值，可直接回车使用）。

脚本会自动检查并创建以下数据库（如果不存在）：
- `dify` - 主数据库
- `plugin_daemon` - 插件守护进程数据库
- `enterprise` - 企业版数据库
- `audit` - 审计数据库

**非交互式模式**（Python 脚本）：

```bash
# 使用命令行参数
python3 init-databases.py --host localhost --port 55432 --user postgres --password devpassword

# 使用环境变量
export PGHOST=localhost PGPORT=55432 PGUSER=postgres PGPASSWORD=devpassword
python3 init-databases.py --non-interactive
```

## ⚙️ 配置说明

### 基础设施配置（从 Kind 集群内访问）

- **PostgreSQL**: `host.docker.internal:55432`，数据库: `dify`, `plugin_daemon`, `enterprise`, `audit`
- **Redis**: `host.docker.internal:6379`，密码: `devpassword`
- **Qdrant**: `http://host.docker.internal:6333`，API Key: `devpassword`
- **MinIO**: `http://host.docker.internal:9000`，Access Key: `minioadmin`，Secret Key: `minioadmin123`

### 默认凭据

⚠️ **警告**：本项目使用默认的开发环境凭据，**仅适用于本地开发环境**。在生产环境中，请务必修改所有默认密码和密钥。

## 🔧 常用操作

### 查看服务状态

```bash
# 查看 Docker 容器状态
docker ps

# 查看 Kubernetes Pod 状态
kubectl get pods

# 查看服务
kubectl get svc

# 查看 Ingress
kubectl get ingress
```

### 查看日志

```bash
# 查看 Docker 容器日志
docker logs dev-postgres
docker logs dev-redis
docker logs dev-minio
docker logs dev-qdrant

# 查看 Kubernetes Pod 日志
kubectl logs <pod-name>
```

### 停止和清理

```bash
# 停止基础设施服务
cd infrastructure
docker compose -f docker-compose.yaml down

# 删除 Kind 集群
kind delete cluster --name dify-ee-kind

# 清理数据（谨慎操作！）
rm -rf infrastructure/data/*
```

## 🐛 故障排除

### 检查 Docker 服务

```bash
docker ps
docker compose -f infrastructure/docker-compose.yaml ps
```

### 检查端口占用

```bash
lsof -i :80 :443 :55432 :6379 :9000 :6333
```

### 测试数据库连接

```bash
PGPASSWORD=devpassword psql -h localhost -p 55432 -U postgres -d postgres -c "SELECT 1;"
```

### 检查 Kind 集群

```bash
# 查看集群列表
kind get clusters

# 查看集群详细信息
kubectl cluster-info --context kind-dify-ee-kind

# 检查节点状态
kubectl get nodes

# 检查 Ingress Controller
kubectl get pods -n ingress-nginx
kubectl describe pod -n ingress-nginx -l app.kubernetes.io/component=controller
```

### 常见问题

1. **端口已被占用**
   - 检查是否有其他服务占用了相同端口
   - 修改 `infrastructure/docker-compose.yaml` 中的端口映射

2. **无法连接到 PostgreSQL**
   - 确认 PostgreSQL 容器正在运行：`docker ps | grep dev-postgres`
   - 检查端口是否正确：`lsof -i :55432`
   - 如果从 Kind 集群内访问，使用 `host.docker.internal` 作为主机

3. **Kind 集群创建失败**
   - 检查 Docker 是否正在运行
   - 确认有足够的系统资源
   - 查看 Kind 日志：`docker logs dify-ee-kind-control-plane`

## 🔄 完整部署流程

```bash
# 1. 创建 Kind 集群并安装 Ingress Controller
cd kind-cluster
./init.sh

# 2. 启动基础设施服务
cd ../infrastructure
docker compose -f docker-compose.yaml up -d

# 3. 初始化数据库
./init-databases.sh

# 4. 验证服务状态
docker ps
kubectl get pods -n ingress-nginx
```

## 📚 相关文档

- [Dify 官方文档](https://docs.dify.ai/)
- [Dify Enterprise Edition 文档](https://enterprise-docs.dify.ai/)
- [Dify Helm Chart 文档](https://langgenius.github.io/dify-helm/#/)
- [Kind 文档](https://kind.sigs.k8s.io/)
- [Helm 文档](https://helm.sh/docs/)
- [Docker Compose 文档](https://docs.docker.com/compose/)

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

在提交 PR 之前，请确保：
- 代码符合项目的代码风格
- 添加必要的注释和文档
- 测试你的更改

## 📝 许可证

本项目遵循相关组件的许可证要求。

## 🔗 相关链接

- [Dify 官网](https://dify.ai/)
- [Dify GitHub](https://github.com/langgenius/dify)
- [Dify Helm Chart 文档](https://langgenius.github.io/dify-helm/#/)

## ⚠️ 免责声明

**本项目仅用于教学演示目的，不推荐用于测试和生产环境。**

本项目提供的配置和脚本仅用于学习和演示 Dify Enterprise Edition 的部署流程。在实际使用中：

- **不要**在生产环境使用本项目提供的默认配置
- **不要**使用默认密码和密钥
- **必须**参考 [Dify Enterprise Edition 官方文档](https://enterprise-docs.dify.ai/) 进行生产部署
- **必须**配置适当的安全策略和访问控制
- **必须**进行充分的安全审计和测试
- **必须**遵循企业级最佳实践和合规要求

对于生产环境部署，请使用官方提供的 Helm Chart 和部署指南。
