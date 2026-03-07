# [Migration] 1.5 - Identify Application Configuration Dependencies

## AWS to Azure PaaS Migration Task

> **Phase:** 1 - Assessment
> **Backlog Task ID:** 1.5
> **Category:** Assessment
> **AWS Source Service:** AWS EKS / K8s
> **Azure Target Service:** Azure AKS / K8s
> **Priority:** High
> **Estimated Effort:** 1 day
> **Dependencies:** 1.1

## Task Description

Map all application runtime configuration: MONGODB_URI, SECRET_KEY, PORT, GIN_MODE, and any other env vars. Document Kubernetes manifests (deployment, service, ingress, configmap, secret, rbac, namespace) and their cloud-provider-specific dependencies.

### Research Findings

#### Application Environment Variables

| Variable | Source | Default | Sensitivity | Description |
|----------|--------|---------|-------------|-------------|
| `MONGODB_URI` | K8s Secret `tasky-secrets.mongodb-uri` | `mongodb://mongo:27017/tasky` (docker-compose) | **Sensitive** | MongoDB connection string with auth credentials |
| `SECRET_KEY` | K8s Secret `tasky-secrets.jwt-secret` | `local-development-secret` (docker-compose) | **Sensitive** | JWT signing key for authentication |
| `PORT` | K8s ConfigMap `tasky-config.PORT` | `8080` | Non-sensitive | HTTP server listen port |
| `GIN_MODE` | K8s ConfigMap `tasky-config.GIN_MODE` | `release` | Non-sensitive | Gin framework mode (debug/release) |
| `AWS_REGION` | .env.example only | `us-east-1` | Non-sensitive | AWS region (not used by app directly) |
| `AWS_PROFILE` | .env.example only | `default` | Non-sensitive | AWS profile (not used by app directly) |

#### Configuration Loading Mechanism

1. **godotenv** — `main.go:15` calls `godotenv.Overload()` to load `.env` file
2. **database/database.go:23** — reads `MONGODB_URI` via `os.Getenv("MONGODB_URI")`
3. **auth/auth.go:17** — reads `SECRET_KEY` via `os.Getenv("SECRET_KEY")` at package init
4. **main.go:34** — `router.Run(":8080")` — port is hardcoded, but configurable via `PORT` env var in Gin

#### MongoDB Connection String Format

Current format: `mongodb://<username>:<password>@<host>:27017/<database>`

Example: `mongodb://taskyadmin:TaskySecure123!@10.0.x.x:27017/tasky`

**Important:** The database name in the connection string is `tasky`, but `database/database.go:56` uses `go-mongodb` as the database name:
```go
func OpenCollection(client *mongo.Client, collectionName string) *mongo.Collection {
    return client.Database("go-mongodb").Collection(collectionName)
}
```

This is a **known discrepancy** — the connection string's database parameter is not used by the driver when `Database()` is called directly. The app always operates against the `go-mongodb` database regardless of the URI path. During Azure migration to Cosmos DB, the Cosmos DB database should be named `go-mongodb` to match the application code, and the connection string's database path should also be aligned.

#### Kubernetes Manifests Inventory

| Manifest | Resource | Cloud-Specific? | Migration Impact |
|----------|----------|----------------|------------------|
| `namespace.yaml` | Namespace `tasky` | ❌ No | None — standard K8s |
| `deployment.yaml` | Deployment `tasky-app` (2 replicas) | ❌ No | None — standard K8s |
| `service.yaml` | Service `tasky-service` (ClusterIP 80→8080) | ❌ No | None — standard K8s |
| `configmap.yaml` | ConfigMap `tasky-config` (PORT, GIN_MODE) | ❌ No | None — standard K8s |
| `secret.yaml` | Secret `tasky-secrets` (mongodb-uri, jwt-secret) | ❌ No | **Values change** (new connection string for Cosmos DB) |
| `rbac.yaml` | ServiceAccount + ClusterRoleBinding (cluster-admin) | ❌ No | None — standard K8s |
| `ingress.yaml` | Ingress `tasky-ingress` | **✅ YES** | **HIGH IMPACT** — AWS-specific annotations |

#### Cloud-Provider-Specific Dependencies in K8s Manifests

##### `ingress.yaml` — AWS Load Balancer Controller Annotations (Lines 12-29)

```yaml
annotations:
  # AWS-SPECIFIC — Must be replaced for Azure
  alb.ingress.kubernetes.io/scheme: internet-facing
  alb.ingress.kubernetes.io/target-type: ip
  alb.ingress.kubernetes.io/backend-protocol: HTTP
  alb.ingress.kubernetes.io/healthcheck-path: /
  alb.ingress.kubernetes.io/healthcheck-protocol: HTTP
  alb.ingress.kubernetes.io/healthcheck-port: traffic-port
  alb.ingress.kubernetes.io/healthcheck-interval-seconds: '30'
  alb.ingress.kubernetes.io/healthcheck-timeout-seconds: '5'
  alb.ingress.kubernetes.io/healthy-threshold-count: '2'
  alb.ingress.kubernetes.io/unhealthy-threshold-count: '2'
  alb.ingress.kubernetes.io/load-balancer-attributes: idle_timeout.timeout_seconds=60
  alb.ingress.kubernetes.io/tags: Environment=dev,Project=tasky,ManagedBy=kubernetes,Component=alb
```

```yaml
spec:
  ingressClassName: alb  # AWS-SPECIFIC — Must change to nginx or AGIC for Azure
```

**AWS-Specific Items to Replace:**
1. All `alb.ingress.kubernetes.io/*` annotations → Azure AGIC or nginx-ingress annotations
2. `ingressClassName: alb` → `ingressClassName: nginx` or `azure-application-gateway`
3. Custom domain: `ideatasky.ryanmcvey.me` (DNS configuration separate)

##### `deployment.yaml` — Container Image Reference

```yaml
image: ghcr.io/rmcveyhsawaknow/tasky-pivot-for-insight:main
```

This uses GHCR (GitHub Container Registry) which is cloud-agnostic — **no migration impact**.

##### `rbac.yaml` — cluster-admin Binding

The ServiceAccount `tasky-admin` has `cluster-admin` ClusterRoleBinding — this is standard K8s RBAC, not cloud-specific. However, for Azure AKS, consider whether Azure RBAC integration should be used instead.

#### Terraform-to-K8s Configuration Flow (Deploy Workflow)

The `terraform-apply.yml` workflow passes configuration from Terraform outputs to K8s:

```
Terraform Outputs:
  mongodb_private_ip ──→ constructs MONGODB_URI ──→ K8s Secret
  mongodb_username   ──→ constructs MONGODB_URI ──→ K8s Secret
  mongodb_password   ──→ constructs MONGODB_URI ──→ K8s Secret
  jwt_secret         ──→ directly ──→ K8s Secret
```

For Azure migration, the Cosmos DB connection string will be a Terraform output that replaces the MongoDB URI construction.

#### Configuration Changes Required for Azure

| Configuration | Current (AWS) | Required (Azure) | Impact |
|--------------|---------------|-------------------|--------|
| MongoDB URI | `mongodb://user:pass@<ec2-ip>:27017/tasky` | Cosmos DB connection string (`mongodb://...documents.azure.com:10255/...?ssl=true`) | Secret value change |
| Ingress Class | `alb` | `nginx` or `azure-application-gateway` | Manifest change |
| Ingress Annotations | `alb.ingress.kubernetes.io/*` | nginx or AGIC annotations | Manifest change |
| kubectl Config | `aws eks update-kubeconfig` | `az aks get-credentials` | Workflow change |
| ALB Controller | AWS Load Balancer Controller (Helm) | nginx-ingress or AGIC | Helm/deployment change |

#### Items with NO Cloud-Provider Dependency

- Application code (main.go, controllers, auth, models, database)
- Dockerfile and docker-compose.yml
- K8s namespace, deployment, service, configmap, rbac manifests
- Container image in GHCR
- Application port (8080)
- JWT authentication mechanism
- MongoDB driver and connection pooling

## Acceptance Criteria

- [x] All application environment variables mapped (MONGODB_URI, SECRET_KEY, PORT, GIN_MODE)
- [x] Configuration loading mechanism documented (godotenv, os.Getenv)
- [x] MongoDB connection string format documented with database name discrepancy noted
- [x] All 7 Kubernetes manifests reviewed for cloud-provider-specific dependencies
- [x] AWS-specific ingress annotations identified and documented (13 ALB annotations)
- [x] Cloud-agnostic K8s resources identified (namespace, deployment, service, configmap, rbac)
- [x] Terraform-to-K8s configuration flow documented
- [x] Required Azure configuration changes mapped

## References

- [Azure Cosmos DB for MongoDB Connection String](https://learn.microsoft.com/en-us/azure/cosmos-db/mongodb/connect-account)
- [AKS Ingress Controllers](https://learn.microsoft.com/en-us/azure/aks/concepts-network-ingress)
- [AGIC - Application Gateway Ingress Controller](https://learn.microsoft.com/en-us/azure/application-gateway/ingress-controller-overview)
- Source: `main.go`, `database/database.go`, `auth/auth.go`, `.env.example`, `k8s/*.yaml`, `docker-compose.yml`
