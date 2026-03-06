# [Migration] 1.1 - Document Current Application Architecture

## AWS to Azure PaaS Migration Task

> **Phase:** 1 - Assessment
> **Backlog Task ID:** 1.1
> **Category:** Assessment
> **Priority:** High
> **Estimated Effort:** 2 days
> **Dependencies:** None

## Task Description

Inventory the Tasky Go web application stack including runtime (Go/Gin), database (MongoDB 4.0.x), storage (S3 backups), containerization (Docker multi-stage), and Kubernetes orchestration (EKS). Capture all service endpoints, ports, environment variables, and configuration dependencies.

### Research Findings

#### Application Runtime Stack

| Component | Technology | Version | Details |
|-----------|-----------|---------|---------|
| Language | Go | 1.18 (module) / 1.19 (Docker) | Compiled static binary |
| Web Framework | Gin | v1.8.1 | HTTP router with middleware |
| Database Driver | mongo-driver | v1.9.1 | Official MongoDB Go driver |
| Authentication | JWT (dgrijalva/jwt-go) | v3.2.0 | HS256 signing, 2-hour expiry |
| Config Loader | godotenv | v1.4.0 | .env file loading |
| Password Hashing | golang.org/x/crypto | v0.0.0-20210711 | bcrypt for password storage |

#### Application Architecture

```
main.go (Entry Point)
├── controllers/
│   ├── todoController.go   → CRUD operations for tasks
│   └── userController.go   → Signup, Login, session management
├── database/
│   └── database.go         → MongoDB client initialization, connection pooling
├── auth/
│   └── auth.go             → JWT generation, validation, session management
├── models/
│   └── models.go           → Todo and User data models (BSON/JSON)
└── assets/
    ├── login.html           → Login/signup page
    ├── todo.html            → Task management page
    ├── css/                 → Stylesheets
    ├── js/                  → Client-side JavaScript
    └── img/                 → Static images
```

#### API Endpoints

| Method | Route | Handler | Auth Required |
|--------|-------|---------|---------------|
| GET | `/` | `index` | No |
| POST | `/signup` | `controller.SignUp` | No |
| POST | `/login` | `controller.Login` | No |
| GET | `/todo` | `controller.Todo` | Yes (cookie) |
| GET | `/todos/:userid` | `controller.GetTodos` | Yes (cookie) |
| GET | `/todo/:id` | `controller.GetTodo` | Yes (cookie) |
| POST | `/todo/:userid` | `controller.AddTodo` | Yes (cookie) |
| PUT | `/todo` | `controller.UpdateTodo` | Yes (cookie) |
| DELETE | `/todo/:userid/:id` | `controller.DeleteTodo` | Yes (cookie) |
| DELETE | `/todos/:userid` | `controller.ClearAll` | Yes (cookie) |

#### Service Endpoints and Ports

| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| Tasky Web App | 8080 | HTTP | Gin web server |
| MongoDB | 27017 | TCP | MongoDB wire protocol |

#### Docker Build (Multi-stage)

| Stage | Base Image | Purpose |
|-------|-----------|---------|
| deps | golang:1.19-alpine | Download and verify Go modules |
| build | golang:1.19-alpine | Compile static binary (CGO_ENABLED=0) |
| production | alpine:3.17.0 | Runtime with ca-certs, non-root user (UID 1001) |

- **Container Health Check:** `wget --spider http://localhost:8080/health`
- **Non-root User:** appuser:appgroup (UID/GID 1001)
- **Exposed Port:** 8080
- **Entrypoint:** `/app/tasky`
- **Static Assets:** `/app/assets/`, `/app/exercise.txt`

#### MongoDB Configuration

- **Database Name:** `go-mongodb` (hardcoded in `database/database.go:56`)
- **Connection Pooling:** MaxPool=10, MinPool=2, MaxIdleTime=30s
- **Timeouts:** ServerSelection=5s, Connect=10s, Socket=10s
- **Collections:** `users`, `todos` (inferred from controllers)
- **Authentication:** Connection string-based (`MONGODB_URI` env var)

#### Kubernetes Orchestration (EKS)

| K8s Resource | Name | Namespace | Key Config |
|-------------|------|-----------|------------|
| Namespace | tasky | - | Standard labels |
| Deployment | tasky-app | tasky | 2 replicas, rolling update |
| Service | tasky-service | tasky | ClusterIP, port 80→8080 |
| Ingress | tasky-ingress | tasky | ALB ingress class, internet-facing |
| ConfigMap | tasky-config | tasky | PORT=8080, GIN_MODE=release |
| Secret | tasky-secrets | tasky | mongodb-uri, jwt-secret |
| RBAC | tasky-admin | tasky | ServiceAccount + cluster-admin binding |

#### Container Image

- **Registry:** ghcr.io/rmcveyhsawaknow/tasky-pivot-for-insight:main
- **Pull Policy:** Always

## Acceptance Criteria

- [x] Application runtime stack documented (Go 1.18/1.19, Gin v1.8.1, MongoDB driver v1.9.1)
- [x] All API endpoints inventoried with routes, methods, and auth requirements
- [x] Docker multi-stage build documented (3 stages: deps, build, production)
- [x] Service ports and protocols documented (8080 HTTP, 27017 TCP)
- [x] MongoDB connection configuration documented (pooling, timeouts, database name)
- [x] Kubernetes manifests inventoried (deployment, service, ingress, configmap, secret, rbac, namespace)
- [x] Container image registry and tag documented (GHCR)
- [x] All component dependencies and interactions captured

## References

- [Go Gin Framework](https://gin-gonic.com/docs/)
- [MongoDB Go Driver](https://www.mongodb.com/docs/drivers/go/current/)
- [Kubernetes Deployment API](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- Source: `main.go`, `database/database.go`, `auth/auth.go`, `models/models.go`, `Dockerfile`, `k8s/*.yaml`
