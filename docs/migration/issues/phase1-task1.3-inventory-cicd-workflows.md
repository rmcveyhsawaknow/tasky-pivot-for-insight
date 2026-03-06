# [Migration] 1.3 - Inventory GitHub Actions CI/CD Workflows

## AWS to Azure PaaS Migration Task

> **Phase:** 1 - Assessment
> **Backlog Task ID:** 1.3
> **Category:** Assessment
> **AWS Source Service:** GitHub Actions + AWS OIDC
> **Priority:** High
> **Estimated Effort:** 1 day
> **Dependencies:** None

## Task Description

Document current GitHub Actions workflows: build-and-publish.yml (Docker image CI), terraform-plan.yml (IaC validation), terraform-apply.yml (IaC deployment + app deploy), cost-analysis.yml (cost reporting). Capture all secrets, variables, OIDC configuration, and environment references.

### Research Findings

#### Workflow Inventory

| Workflow File | Name | Trigger Events | Purpose |
|--------------|------|----------------|---------|
| `build-and-publish.yml` | Build and Publish a Docker image | push to `main`, `develop` | Docker CI → GHCR |
| `terraform-plan.yml` | Terraform Plan | push/PR to `deploy/*`, workflow_dispatch | IaC validation |
| `terraform-apply.yml` | Terraform Apply and Deploy | workflow_dispatch, workflow_run (after plan) | IaC deploy + app deploy |
| `cost-analysis.yml` | Infrastructure Cost Analysis | PR (terraform/**), schedule (weekly Mon 9AM), workflow_dispatch | Cost reporting |

---

#### Workflow 1: `build-and-publish.yml` (Application CI)

**Triggers:** Push to `main` or `develop` branches

**Permissions:** `contents: read`, `packages: write`

**Jobs:** `build-and-push-image` (ubuntu-latest)

| Step | Action/Command | Purpose |
|------|---------------|---------|
| Checkout | `actions/checkout@v3` | Clone repository |
| Docker Login | `docker/login-action@f054a8...` | Authenticate to GHCR |
| Metadata | `docker/metadata-action@98669a...` | Generate image tags/labels |
| Build & Push | `docker/build-push-action@ad4402...` | Build Docker image, push to GHCR |

**Registry:** `ghcr.io`
**Image:** `ghcr.io/${{ github.repository }}`
**Tags:** Branch-based + `latest=true`

**Secrets Used:** `GITHUB_TOKEN` (built-in)

> **Migration Impact:** LOW — This workflow uses GHCR (cloud-agnostic), no AWS dependencies.

---

#### Workflow 2: `terraform-plan.yml` (IaC Validation)

**Triggers:**
- Push to `deploy/*` branches (paths: `terraform/**`, `k8s/**`, workflow files, scripts)
- PR to `deploy/*` branches
- Manual `workflow_dispatch`

**Permissions:** `contents: read`, `pull-requests: write`, `id-token: write`

**Environment Variables:**
| Variable | Source | Default |
|----------|--------|---------|
| `TF_VERSION` | hardcoded | `1.7.5` |
| `AWS_REGION` | `vars.AWS_REGION` | `us-east-1` |
| `PROJECT_NAME` | `vars.PROJECT_NAME` | `tasky` |
| `ENVIRONMENT` | `vars.ENVIRONMENT` | `dev` |
| `STACK_VERSION` | `vars.STACK_VERSION` | `v15` |

**Jobs:** `terraform-plan` (ubuntu-latest)

| Step | Action/Command | Purpose |
|------|---------------|---------|
| Checkout | `actions/checkout@v4` | Clone repository |
| AWS Credentials | `aws-actions/configure-aws-credentials@v4` | **OIDC authentication** |
| Setup Terraform | `hashicorp/setup-terraform@v3` | Install Terraform 1.7.5 |
| Create tfvars | shell script | Generate `terraform.tfvars` from secrets/vars |
| Format Check | `terraform fmt -check -recursive` | Code style validation |
| Init | `terraform init -backend-config=backend-prod.hcl` | Initialize with S3 backend |
| Validate | `terraform validate` | Configuration validation |
| Plan | `terraform plan -out=tfplan` | Generate execution plan |
| Cost Estimation | shell script | Inline cost estimate output |
| Security Check | shell script | Inline security report |
| Update PR | `actions/github-script@v7` | Post plan as PR comment |

**Secrets Used:**
- `AWS_ROLE_ARN` — OIDC role for AWS authentication
- `MONGODB_USERNAME` — MongoDB admin username
- `MONGODB_PASSWORD` — MongoDB admin password
- `JWT_SECRET` — Application JWT signing key
- `GITHUB_TOKEN` — PR comment posting

**Variables Used:**
- `AWS_REGION`, `PROJECT_NAME`, `ENVIRONMENT`, `STACK_VERSION`
- `MONGODB_INSTANCE_TYPE`, `VPC_CIDR`, `MONGODB_DATABASE_NAME`

> **Migration Impact:** HIGH — Requires Azure OIDC login, Azure env vars, Azure Storage backend.

---

#### Workflow 3: `terraform-apply.yml` (IaC Deploy + App Deploy)

**Triggers:**
- Manual `workflow_dispatch` (with `action` choice: apply/destroy, `deploy_application` boolean)
- `workflow_run` after Terraform Plan succeeds on `deploy/*` branches

**Permissions:** `contents: read`, `id-token: write`

**Environment Variables:** Same as terraform-plan.yml

**Jobs:**

##### Job 1: `check-plan-success`
- Validates plan succeeded or is manual trigger
- Outputs `plan_successful` flag

##### Job 2: `terraform-apply` (needs check-plan-success)
- AWS OIDC authentication via `aws-actions/configure-aws-credentials@v4`
- Terraform init, plan, apply (or destroy)
- Captures outputs: `eks_cluster_name`, `mongodb_private_ip`, `s3_backup_url`, etc.
- Uploads credentials as artifact (sensitive values)

##### Job 3: `deploy-application` (needs terraform-apply)
- AWS OIDC authentication
- Installs kubectl v1.28.0 (`azure/setup-kubectl@v3`)
- Installs Helm v3.12.0 (`azure/setup-helm@v3`)
- Configures kubectl: `aws eks update-kubeconfig --region $REGION --name $CLUSTER`
- Downloads credentials artifact
- Runs `scripts/setup-alb-controller.sh` (ALB Controller + app deployment)
- Waits for ALB URL provisioning (up to 10 min)

**Secrets Used:**
- `AWS_ROLE_ARN` — OIDC role for AWS authentication
- `MONGODB_USERNAME`, `MONGODB_PASSWORD`, `JWT_SECRET`

**Variables Used:** Same as terraform-plan.yml

> **Migration Impact:** HIGH — Requires Azure OIDC login, `az aks get-credentials`, Azure-specific deploy steps.

---

#### Workflow 4: `cost-analysis.yml` (Cost Reporting)

**Triggers:**
- PR with changes to `terraform/**`
- Schedule: Weekly Monday 9 AM UTC
- Manual `workflow_dispatch` (with optimization flag)

**Permissions:** `id-token: write`, `contents: read`, `pull-requests: write`

**Jobs:** `cost-analysis` (ubuntu-latest)

| Step | Action/Command | Purpose |
|------|---------------|---------|
| Checkout | `actions/checkout@v4` | Clone repository |
| AWS Credentials | `aws-actions/configure-aws-credentials@v4` | OIDC authentication |
| Setup Terraform | `hashicorp/setup-terraform@v3` | Install Terraform |
| Install Deps | `apt-get install bc jq` | Cost calculation tools |
| Init TF | `terraform init -backend=false` | Local init for analysis |
| Basic Cost | `scripts/cost-terraform.sh` | Generate cost estimate |
| Advanced Cost | `scripts/advanced-cost-analysis.sh` | Optimization recommendations |
| PR Comment | `actions/github-script@v7` | Post cost report on PRs |
| Upload Artifacts | `actions/upload-artifact@v3` | Store cost analysis results |
| Validate Costs | shell script | Range validation ($80-$200/month) |

**Secrets Used:** `AWS_ROLE_ARN`

> **Migration Impact:** MODERATE — Update AWS pricing references to Azure pricing.

---

#### OIDC Configuration Summary

| Aspect | Current (AWS) |
|--------|--------------|
| Authentication Action | `aws-actions/configure-aws-credentials@v4` |
| OIDC Role Secret | `AWS_ROLE_ARN` |
| Token Permission | `id-token: write` |
| Backend Auth | Implicit via AWS credentials |
| kubectl Auth | `aws eks update-kubeconfig` |

#### All Secrets Referenced

| Secret | Used In | Purpose |
|--------|---------|---------|
| `AWS_ROLE_ARN` | terraform-plan, terraform-apply, cost-analysis | AWS OIDC authentication |
| `MONGODB_USERNAME` | terraform-plan, terraform-apply | Database credentials |
| `MONGODB_PASSWORD` | terraform-plan, terraform-apply | Database credentials |
| `JWT_SECRET` | terraform-plan, terraform-apply | Application auth key |
| `GITHUB_TOKEN` | build-and-publish, terraform-plan | Built-in token for GHCR and PR comments |

#### All Repository Variables Referenced

| Variable | Default | Used In |
|----------|---------|---------|
| `AWS_REGION` | `us-east-1` | terraform-plan, terraform-apply |
| `PROJECT_NAME` | `tasky` | terraform-plan, terraform-apply |
| `ENVIRONMENT` | `dev` | terraform-plan, terraform-apply |
| `STACK_VERSION` | `v15` | terraform-plan, terraform-apply |
| `MONGODB_INSTANCE_TYPE` | `t3.micro` | terraform-plan, terraform-apply |
| `VPC_CIDR` | `10.0.0.0/16` | terraform-plan, terraform-apply |
| `MONGODB_DATABASE_NAME` | `go-mongodb` | terraform-plan, terraform-apply |

## Acceptance Criteria

- [x] All 4 GitHub Actions workflows documented with triggers, permissions, and steps
- [x] All secrets inventoried (AWS_ROLE_ARN, MONGODB_USERNAME, MONGODB_PASSWORD, JWT_SECRET, GITHUB_TOKEN)
- [x] All repository variables inventoried (7 variables with defaults)
- [x] OIDC configuration documented (aws-actions/configure-aws-credentials@v4, role-to-assume)
- [x] Environment references documented (none using GitHub Environments currently)
- [x] Deployment flow captured (plan → apply → deploy-application, with artifact passing)
- [x] Migration impact assessed per workflow (LOW, HIGH, HIGH, MODERATE)

## References

- [GitHub Actions OIDC with AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [Azure OIDC for GitHub Actions](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure)
- Source: `.github/workflows/build-and-publish.yml`, `.github/workflows/terraform-plan.yml`, `.github/workflows/terraform-apply.yml`, `.github/workflows/cost-analysis.yml`
