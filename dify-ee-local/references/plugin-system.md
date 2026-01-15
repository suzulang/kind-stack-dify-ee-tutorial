# Plugin System Architecture

Complete guide to how plugins are installed and run in Dify Enterprise.

---

## Components Involved

| Component | Role |
|-----------|------|
| **API** | Receives install request from UI |
| **Plugin-Daemon** | Orchestrates installation, stores metadata |
| **Plugin-Connector** | Generates Dockerfile, creates K8s resources |
| **Plugin-Manager** | Manages plugin lifecycle |
| **CRD-Controller** | Watches DifyPlugin CRs, creates Jobs/Deployments |
| **MinIO** | Stores .difypkg files, build context, RSA keys |
| **Local Registry** | Stores built plugin images |
| **Kaniko** | Builds Docker images in K8s Job |

---

## Installation Flow (5 Phases)

### Phase 1: User Interface

1. User clicks **Plugins → Explore Marketplace**
2. Browser fetches plugin list from `marketplace.dify.ai`
3. User clicks **Install** on a plugin

### Phase 2: Download & Initialize

```
Browser → API → Plugin-Daemon → MinIO
```

1. `.difypkg` package downloaded to MinIO (`plugin_packages/`)
2. API calls Plugin-Daemon to start installation
3. Plugin-Daemon extracts metadata, stores in MinIO

### Phase 3: Build Preparation

```
Plugin-Daemon → Plugin-Connector → MinIO
```

1. Plugin-Daemon checks if plugin already installed
2. If not, sends request to Plugin-Connector
3. Plugin-Connector:
   - Extracts `.difypkg`
   - Generates `Dockerfile` and build files
   - Packs into `.tar`
   - Uploads to MinIO (`connector_build_caches/`)

### Phase 4: Kubernetes Resource Creation

```
Plugin-Connector → DifyPlugin CR → CRD-Controller → Job → Deployment → Service
```

1. Plugin-Connector creates `DifyPlugin` Custom Resource (CR)
2. Plugin-Connector watches CR status
3. CRD-Controller detects CR, creates:
   - **Job** (Kaniko) → Builds Docker image, pushes to registry
   - **Deployment** → Runs the plugin image
   - **Service** → Exposes the plugin pod

### Phase 5: Complete Installation

```
CR Status: Running → Plugin-Daemon → Database → API → UI
```

1. Plugin-Connector sees CR status = `Running`
2. Returns Service endpoint to Plugin-Daemon
3. Plugin-Daemon stores endpoint in database
4. API returns success to UI

---

## Visual Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│ Phase 1: UI                                                          │
│   User → Marketplace → Click Install                                 │
└─────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────┐
│ Phase 2: Download                                                    │
│   .difypkg → MinIO (plugin_packages/)                               │
│   API → Plugin-Daemon (extract metadata)                            │
└─────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────┐
│ Phase 3: Build Prep                                                  │
│   Plugin-Connector → Generate Dockerfile → tar → MinIO              │
│                                          (connector_build_caches/)   │
└─────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────┐
│ Phase 4: K8s Resources                                               │
│   DifyPlugin CR → CRD-Controller                                     │
│                        ↓                                             │
│   Job (Kaniko) → Build Image → Push to Registry                      │
│                        ↓                                             │
│   Deployment → Pod (plugin) → Service                                │
└─────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────┐
│ Phase 5: Complete                                                    │
│   CR Status: Running → Plugin-Daemon → DB → Success                  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Monitoring Installation

### Watch Resources

```bash
kubectl get difyplugin,jobs,pods -n dify -w
```

### Expected State Transitions

| Resource | Status Flow |
|----------|-------------|
| DifyPlugin | (none) → Building → Running |
| Job | (created) → Running → Complete |
| Job Pod | Pending → Running → Completed |
| Deployment Pod | (created) → ContainerCreating → Running |

### Check DifyPlugin Status

```bash
kubectl get difyplugin -n dify
```

Example output:
```
NAME                               STATUS    ENDPOINT                                    READY
ca95519cb2f0ee348d4019fb58a5c312   Running   http://svc-ca95519cb2f0ee348d4019fb58a5c312.dify:8080   true
```

### Check Job Logs (Kaniko build)

```bash
kubectl logs job/<plugin-id> -n dify
```

### Check Registry for Built Images

```bash
curl -s http://localhost:5050/v2/_catalog
```

---

## Naming Convention

| Resource | Name Pattern |
|----------|--------------|
| DifyPlugin CR | `<plugin-id>` or `<plugin-id>--<retry>` |
| Job | Same as CR name |
| Job Pod | `<cr-name>-<random>` |
| Deployment | `<cr-name>` |
| Deployment Pod | `<cr-name>-<hash>-<random>` |
| Service | `svc-<plugin-id>` |
| Image | `<registry>/<plugin-name>-<plugin-id>:<version>` |

The `--<retry>` suffix (e.g., `--2`, `--3`) indicates retry attempts after failures.

---

## Clean Up Failed Installations

### Delete Failed CRs

```bash
# List all
kubectl get difyplugin -n dify

# Delete specific
kubectl delete difyplugin <name> -n dify

# Delete all failed
kubectl get difyplugin -n dify -o json | jq -r '.items[] | select(.status.state=="BuildFailed") | .metadata.name' | xargs -r kubectl delete difyplugin -n dify
```

### Delete Jobs

```bash
kubectl delete jobs --all -n dify
```

### Delete Error Pods

```bash
kubectl delete pods -n dify --field-selector=status.phase=Failed
```

---

## Local Development Requirements

For plugin system to work locally:

1. **Local Registry** - Kaniko needs somewhere to push images
2. **Insecure Registry Config** - Kind must accept HTTP registry
3. **Correct MinIO Credentials** - Build context upload must succeed
4. **imageRepoType: docker** - Not ECR or Docker Hub

See [infrastructure.md](infrastructure.md) for setup details.
