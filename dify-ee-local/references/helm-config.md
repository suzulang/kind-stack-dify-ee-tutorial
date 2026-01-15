# Helm Configuration Reference

Complete `values.yaml` configuration for local Kind deployment.

---

## Configuration Summary

| Section | Key Setting | Local Value |
|---------|-------------|-------------|
| ingress.enabled | Enable Ingress | `true` |
| ingress.className | Ingress class | `nginx` |
| externalPostgres.enabled | Use external PG | `true` |
| externalRedis.enabled | Use external Redis | `true` |
| vectorDB.useExternal | Use external Qdrant | `true` |
| persistence.type | Storage type | `s3` |
| minio.enabled | Built-in MinIO | `false` |
| pluginBuilder.imageRepoType | Registry type | `docker` |

---

## Secrets

Generate with `openssl rand -base64 42`:

```yaml
global:
  appSecretKey: "<generated>"

enterprise:
  appSecretKey: "<generated>"
  adminAPIsSecretKeySalt: "<generated>"
```

---

## Domains

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

---

## Ingress

```yaml
ingress:
  enabled: true
  className: "nginx"
```

---

## External PostgreSQL

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

---

## External Redis

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

---

## External Qdrant

```yaml
vectorDB:
  useExternal: true
  externalType: "qdrant"
  externalQdrant:
    endpoint: "http://host.docker.internal:6333"
    apiKey: "devpassword"
```

---

## Storage (MinIO/S3)

**CRITICAL**: Get actual credentials first:
```bash
docker exec dev-minio env | grep MINIO_ROOT
```

```yaml
persistence:
  type: "s3"
  s3:
    endpoint: "http://host.docker.internal:9000"
    accessKey: "<MINIO_ROOT_USER>"      # From command above
    secretKey: "<MINIO_ROOT_PASSWORD>"  # From command above
    region: "us-east-1"
    bucketName: "dify"
    addressType: ""
    useAwsManagedIam: false
    useAwsS3: false

minio:
  enabled: false  # MUST be false when using external MinIO
```

---

## Plugin Builder

**CRITICAL for local development:**

```yaml
pluginBuilder:
  # Local registry settings
  insecureImageRepo: true
  imageRepoPrefix: "host.docker.internal:5050"
  imageRepoType: docker

  # Ignored when imageRepoType is docker, but keep defaults
  ecrRegion: "us-east-1"
  imageRepoSecret: "image-repo-secret"

  # Builder images
  shaderImage: "gcr.io/kaniko-project/executor:latest"
  gatewayImage: "nginx:1.27.3"
  busyBoxImage: "busybox:latest"
  awsCliImage: "amazon/aws-cli:latest"
```

### DO NOT Use

| Setting | Why |
|---------|-----|
| `imageRepoType: ecr` | Requires AWS credentials |
| `imageRepoPrefix: docker.io/xxx` | Requires Docker Hub auth |
| `insecureImageRepo: false` | Local registry is HTTP |

---

## Verify After Deploy

```bash
# Check plugin builder config
kubectl get configmap dify-plugin-connector-config -n dify -o yaml | grep -E "repoType|imagePrefix|insecureRepo"
```

Expected:
```
repoType: "docker"
imagePrefix: "host.docker.internal:5050"
insecureRepo: true
```

If wrong, run:
```bash
helm upgrade dify <helm-chart-path> -n dify
kubectl rollout restart deployment dify-plugin-connector -n dify
```

---

## Common Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| `minio.enabled: true` | Helm hangs on minio-post-job | Set to `false` |
| `localhost` instead of `host.docker.internal` | Connection refused | Use `host.docker.internal` |
| `sslmode: require` | PostgreSQL connection fails | Use `disable` |
| Wrong MinIO credentials | PrivkeyNotFoundError | Match actual credentials |
| `imageRepoType: ecr` | ECR repo creation fails | Use `docker` |
| `insecureImageRepo: false` | HTTPS error on pull | Set to `true` |
