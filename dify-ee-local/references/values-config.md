# Dify EE values.yaml Configuration Guide

Complete configuration reference for local Kind deployment.

## Configuration Summary

| Section | Key | Value |
|---------|-----|-------|
| global.appSecretKey | Generated | `openssl rand -base64 42` |
| ingress.enabled | `true` | Enable Ingress |
| ingress.className | `nginx` | Use NGINX Ingress |
| externalPostgres.enabled | `true` | Use external PostgreSQL |
| externalRedis.enabled | `true` | Use external Redis |
| vectorDB.useExternal | `true` | Use external Qdrant |
| persistence.type | `s3` | Use MinIO for storage |
| minio.enabled | `false` | Disable built-in MinIO |

---

## Full Configuration

### Global Secrets

```yaml
global:
  appSecretKey: "<run: openssl rand -base64 42>"
  # innerApiKey is usually pre-filled, keep as-is
```

### Enterprise Secrets

```yaml
enterprise:
  appSecretKey: "<run: openssl rand -base64 42>"
  adminAPIsSecretKeySalt: "<run: openssl rand -base64 42>"
```

### Domains

```yaml
global:
  consoleApiDomain: "console.dify.local"
  consoleWebDomain: "console.dify.local"
  serviceApiDomain: "api.dify.local"
  appApiDomain: "app.dify.local"
  appWebDomain: "app.dify.local"
  filesDomain: "files.dify.local"
  enterpriseDomain: "enterprise.dify.local"
  triggerDomain: "trigger.dify.local"
```

### Ingress

```yaml
ingress:
  enabled: true
  className: "nginx"
```

### External PostgreSQL

```yaml
externalPostgres:
  enabled: true
  address: host.docker.internal
  port: 55432
  credentials:
    dify:
      database: "dify"
      username: "postgres"
      password: "devpassword"
      sslmode: "disable"
      extras: ""
      charset: ""
      uriScheme: "postgresql"
    plugin_daemon:
      database: "plugin_daemon"
      username: "postgres"
      password: "devpassword"
      sslmode: "disable"
      extras: ""
      charset: ""
      uriScheme: "postgresql"
    enterprise:
      database: "enterprise"
      username: "postgres"
      password: "devpassword"
      sslmode: "disable"
      extras: ""
      charset: ""
      uriScheme: "postgresql"
    audit:
      database: "audit"
      username: "postgres"
      password: "devpassword"
      sslmode: "disable"
      extras: ""
      charset: ""
      uriScheme: "postgresql"
```

### External Redis

```yaml
externalRedis:
  enabled: true
  useSSL: false
  host: "host.docker.internal"
  port: 6379
  username: ""
  password: "devpassword"
  db: 0
```

### External Qdrant

```yaml
vectorDB:
  useExternal: true
  externalType: "qdrant"
  externalQdrant:
    endpoint: "http://host.docker.internal:6333"
    apiKey: "devpassword"
```

### External MinIO (S3)

```yaml
persistence:
  type: "s3"
  s3:
    endpoint: "http://host.docker.internal:9000"
    accessKey: "minioadmin"
    secretKey: "minioadmin123"
    region: "us-east-1"
    bucketName: "dify"
    addressType: ""
    useAwsManagedIam: false
    useAwsS3: false
```

### Disable Built-in MinIO

```yaml
minio:
  enabled: false
```

---

## Infrastructure Connection Info

From inside Kind cluster, services connect via `host.docker.internal`:

| Service | Address | Credentials |
|---------|---------|-------------|
| PostgreSQL | host.docker.internal:55432 | postgres / devpassword |
| Redis | host.docker.internal:6379 | devpassword |
| Qdrant | http://host.docker.internal:6333 | devpassword |
| MinIO | http://host.docker.internal:9000 | minioadmin / minioadmin123 |

---

## Common Mistakes

1. **Forgot to disable built-in MinIO** → Helm install hangs on minio-post-job
2. **Using localhost instead of host.docker.internal** → Connection refused from pods
3. **sslmode: require instead of disable** → PostgreSQL connection fails
4. **plugin_daemon database name wrong** → Should be `plugin_daemon` not `dify_plugin_daemon`
