# Kind Stack - Dify Enterprise Edition

[中文](README.zh.md) | [English](README.en.md) | [日本語](README.ja.md)

---

## AI Instructions / AI 指令 / AI 向け説明

This repository provides skills for Dify EE local deployment. See language-specific README for details.

| Skill | Triggers |
|-------|----------|
| `dify-ee-local` | "deploy dify enterprise locally", "部署 dify 企业版", "dify をローカルにデプロイ" |
| `dify-ee-cleanup` | "cleanup dify", "清理 dify", "dify を削除" |

### Infrastructure

| Service    | Host                     | Port  | Credentials               |
|------------|--------------------------|-------|---------------------------|
| PostgreSQL | host.docker.internal     | 55432 | postgres / devpassword    |
| Redis      | host.docker.internal     | 6379  | devpassword               |
| Qdrant     | host.docker.internal     | 6333  | devpassword               |
| MinIO      | host.docker.internal     | 9000  | minioadmin / minioadmin123|

### Key Files

```
kind-cluster/init.sh                # Kind cluster + Ingress
infrastructure/docker-compose.yaml  # PostgreSQL, Redis, Qdrant, MinIO
infrastructure/init-databases.sh    # Database initialization
dify-ee-local/SKILL.md              # Deployment instructions
dify-ee-cleanup/SKILL.md            # Cleanup instructions
```
