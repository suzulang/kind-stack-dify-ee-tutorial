# AI Instructions

> This section is for AI assistants. Human users can skip to [Kind Stack - Dify Enterprise Edition](#kind-stack---dify-enterprise-edition).

## Available Skills

This repository provides two skills for Dify EE local deployment:

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

## Infrastructure Details

| Service    | Host (from Kind)         | Port  | Credentials               |
|------------|--------------------------|-------|---------------------------|
| PostgreSQL | host.docker.internal     | 55432 | postgres / devpassword    |
| Redis      | host.docker.internal     | 6379  | devpassword               |
| Qdrant     | host.docker.internal     | 6333  | devpassword               |
| MinIO      | host.docker.internal     | 9000  | minioadmin / minioadmin123|

**Databases**: dify, plugin_daemon, enterprise, audit

## File Structure

```
kind-cluster/init.sh          # Creates Kind cluster + Ingress
infrastructure/docker-compose.yaml  # PostgreSQL, Redis, Qdrant, MinIO
infrastructure/init-databases.sh    # Creates required databases
dify-ee-local/SKILL.md        # Full deployment instructions
dify-ee-cleanup/SKILL.md      # Full cleanup instructions
```

---

# Kind Stack - Dify Enterprise Edition

Provides prerequisites and infrastructure configuration for deploying Dify Enterprise Edition on a local Kind (Kubernetes in Docker) cluster.

## Important Notice

**This project is for educational demonstration purposes only. Not recommended for testing or production environments.**

This project only provides prerequisites for Dify Enterprise Edition deployment:
- Kind cluster creation and configuration
- Data persistence infrastructure deployment
- Database initialization

For actual Dify Enterprise Edition deployment, please refer to official documentation.

## Project Overview

This project provides prerequisites for installing Dify Enterprise Edition:

- **Kind Cluster Management**: Automated creation and configuration with proxy support
- **Ingress Controller**: Automatic NGINX Ingress Controller installation
- **Data Persistence Infrastructure**: PostgreSQL, Redis, Qdrant, MinIO via Docker Compose
- **Database Initialization**: Automatic check and creation of required PostgreSQL databases

## Project Structure

```
kind-stack/
├── kind-cluster/                    # Kind cluster configuration
│   ├── init.sh                      # Kind cluster initialization script
│   └── config.yaml                  # Kind cluster config file
├── infrastructure/                  # Data persistence infrastructure
│   ├── docker-compose.yaml          # Docker Compose configuration
│   ├── init-databases.sh            # Database initialization script
│   └── data/                        # Data directory
├── dify-ee-local/                   # Deployment skill
└── dify-ee-cleanup/                 # Cleanup skill
```

## Quick Start

### Prerequisites

- **Docker Desktop** or **Docker Engine** (20.10+)
- **kubectl** (1.24+)
- **Helm** 3.x
- **Kind** (0.20+)

### Install Dependencies

```bash
# macOS
brew install kind helm postgresql

# Linux (Ubuntu/Debian)
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

## Usage Guide

### Step 1: Create Kind Cluster

```bash
cd kind-cluster
./init.sh
```

### Step 2: Start Infrastructure

```bash
cd infrastructure
docker compose -f docker-compose.yaml up -d
```

### Step 3: Initialize Databases

```bash
./init-databases.sh
```

## Configuration

### Infrastructure Configuration (Access from Kind Cluster)

- **PostgreSQL**: `host.docker.internal:55432`
- **Redis**: `host.docker.internal:6379`
- **Qdrant**: `http://host.docker.internal:6333`
- **MinIO**: `http://host.docker.internal:9000`

## Stop and Cleanup

```bash
# Stop infrastructure services
cd infrastructure && docker compose down

# Delete Kind cluster
kind delete cluster --name dify-ee-kind

# Clean data
rm -rf infrastructure/data/*
```

## Related Documentation

- [Dify Documentation](https://docs.dify.ai/)
- [Dify Enterprise Edition Documentation](https://enterprise-docs.dify.ai/)
- [Kind Documentation](https://kind.sigs.k8s.io/)

## Disclaimer

**This project is for educational demonstration purposes only. Not recommended for testing or production environments.**

For production deployment, please use the official Helm Chart and deployment guide.
