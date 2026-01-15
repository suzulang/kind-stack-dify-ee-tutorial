# AI 指令

> 本节面向 AI 助手。人类用户可跳至 [Kind Stack - Dify Enterprise Edition](#kind-stack---dify-enterprise-edition)。

## 可用技能

本仓库提供两个用于 Dify EE 本地部署的技能：

### 1. `dify-ee-local` - 部署 Dify EE

**触发词**: "部署 dify 企业版", "本地部署 dify", "kind 部署 dify", "deploy dify enterprise locally"

**工作流程**:
1. 向用户询问: (a) kind-stack 路径, (b) Helm Chart 路径
2. 运行 `scripts/check-prerequisites.sh` 验证 Docker, kubectl, Helm, Kind
3. 阶段1: 基础设施搭建
   - `cd <kind-stack-path>/kind-cluster && ./init.sh`
   - `cd <kind-stack-path>/infrastructure && docker compose up -d`
   - `./init-databases.sh` (使用默认值)
4. 阶段2: 配置 `values.yaml`，参考 [dify-ee-local/references/values-config.md](dify-ee-local/references/values-config.md)
5. 阶段3: `helm install dify <helm-chart-path> --namespace dify --create-namespace`
6. 阶段4: 添加 hosts 配置 (运行 `scripts/show-hosts-config.sh`)

**访问地址**: console.dify.local, enterprise.dify.local, app.dify.local

### 2. `dify-ee-cleanup` - 清理 Dify EE

**触发词**: "清理 dify", "卸载 dify", "删除 dify 环境", "cleanup dify", "uninstall dify ee"

**快速清理**:
```bash
helm uninstall dify -n dify 2>/dev/null || true
kubectl delete namespace dify --ignore-not-found
kind delete cluster --name dify-ee-kind
cd <kind-stack-path>/infrastructure && docker compose down -v --rmi all
rm -rf <kind-stack-path>/infrastructure/data/*
```

## 基础设施详情

| 服务       | 主机 (Kind 内访问)       | 端口  | 凭据                      |
|------------|--------------------------|-------|---------------------------|
| PostgreSQL | host.docker.internal     | 55432 | postgres / devpassword    |
| Redis      | host.docker.internal     | 6379  | devpassword               |
| Qdrant     | host.docker.internal     | 6333  | devpassword               |
| MinIO      | host.docker.internal     | 9000  | minioadmin / minioadmin123|

**数据库**: dify, plugin_daemon, enterprise, audit

## 文件结构

```
kind-cluster/init.sh          # 创建 Kind 集群 + Ingress
infrastructure/docker-compose.yaml  # PostgreSQL, Redis, Qdrant, MinIO
infrastructure/init-databases.sh    # 创建所需数据库
dify-ee-local/SKILL.md        # 完整部署指令
dify-ee-cleanup/SKILL.md      # 完整清理指令
```

---

# Kind Stack - Dify Enterprise Edition

为在本地 Kind (Kubernetes in Docker) 集群上部署 Dify Enterprise Edition 提供前置准备和基础设施配置。

## 重要提示

**本项目仅用于教学演示目的，不推荐用于测试和生产环境。**

本项目仅提供 Dify Enterprise Edition 部署的前置准备工作，包括：
- Kind 集群的创建和配置
- 数据持久化基础设施的部署
- 数据库的初始化

实际的 Dify Enterprise Edition 部署请参考官方文档。

## 项目概述

本项目为安装 Dify Enterprise Edition 提供前置准备，包括：

- **Kind 集群管理**：自动化创建和配置 Kind 集群，支持代理配置
- **Ingress Controller**：自动安装 NGINX Ingress Controller
- **数据持久化基础设施**：PostgreSQL、Redis、Qdrant、MinIO 的 Docker Compose 部署
- **数据库初始化**：自动检查和创建所需的 PostgreSQL 数据库

## 项目结构

```
kind-stack/
├── kind-cluster/                    # Kind 集群相关配置
│   ├── init.sh                      # Kind 集群初始化脚本
│   └── config.yaml                  # Kind 集群配置文件
├── infrastructure/                  # 数据持久化基础设施
│   ├── docker-compose.yaml          # Docker Compose 配置
│   ├── init-databases.sh            # 数据库初始化脚本
│   └── data/                        # 数据目录
├── dify-ee-local/                   # 部署技能
└── dify-ee-cleanup/                 # 清理技能
```

## 快速开始

### 前置要求

- **Docker Desktop** 或 **Docker Engine** (20.10+)
- **kubectl** (1.24+)
- **Helm** 3.x
- **Kind** (0.20+)

### 安装依赖

```bash
# macOS
brew install kind helm postgresql

# Linux (Ubuntu/Debian)
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

## 使用指南

### 步骤 1: 创建 Kind 集群

```bash
cd kind-cluster
./init.sh
```

### 步骤 2: 启动基础设施

```bash
cd infrastructure
docker compose -f docker-compose.yaml up -d
```

### 步骤 3: 初始化数据库

```bash
./init-databases.sh
```

## 配置说明

### 基础设施配置（从 Kind 集群内访问）

- **PostgreSQL**: `host.docker.internal:55432`
- **Redis**: `host.docker.internal:6379`
- **Qdrant**: `http://host.docker.internal:6333`
- **MinIO**: `http://host.docker.internal:9000`

## 停止和清理

```bash
# 停止基础设施服务
cd infrastructure && docker compose down

# 删除 Kind 集群
kind delete cluster --name dify-ee-kind

# 清理数据
rm -rf infrastructure/data/*
```

## 相关文档

- [Dify 官方文档](https://docs.dify.ai/)
- [Dify Enterprise Edition 文档](https://enterprise-docs.dify.ai/)
- [Kind 文档](https://kind.sigs.k8s.io/)

## 免责声明

**本项目仅用于教学演示目的，不推荐用于测试和生产环境。**

对于生产环境部署，请使用官方提供的 Helm Chart 和部署指南。
