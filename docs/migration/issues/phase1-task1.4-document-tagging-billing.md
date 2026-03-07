# [Migration] 1.4 - Document Current Tagging and Billing Strategy

## AWS to Azure PaaS Migration Task

> **Phase:** 1 - Assessment
> **Backlog Task ID:** 1.4
> **Category:** Assessment
> **AWS Source Service:** AWS Resource Tags
> **Azure Target Service:** Azure Resource Tags
> **Priority:** Medium
> **Estimated Effort:** 1 day
> **Dependencies:** 1.1

## Task Description

Review current AWS resource tagging strategy (Project, Environment, StackVersion, ManagedBy, Owner, CreatedDate) and document billing/cost tracking approach for migration to Azure tagging and cost management.

### Research Findings

#### Current AWS Tagging Strategy

Tags are applied via Terraform `local.common_tags` block in `terraform/main.tf` and propagated to all modules via the `tags` variable:

```hcl
common_tags = {
  Project      = "tasky"
  Environment  = var.environment        # dev, stg, prd
  StackVersion = var.stack_version       # v1, v2, v15, etc.
  ManagedBy    = "terraform"
  Owner        = "insight-technical-exercise"
  CreatedDate  = formatdate("YYYY-MM-DD", timestamp())
}
```

Additionally, the AWS provider applies `default_tags` in `providers.tf`:
```hcl
provider "aws" {
  region = var.aws_region
  default_tags {
    tags = local.common_tags
  }
}
```

#### Current Tag Taxonomy

| Tag Key | Purpose | Values | Applied To |
|---------|---------|--------|------------|
| `Project` | Project identifier | `tasky` (static) | All resources via default_tags |
| `Environment` | Deployment tier | `dev`, `stg`, `prd` | All resources via default_tags |
| `StackVersion` | Stack iteration | `v1`, `v15`, etc. | All resources via default_tags |
| `ManagedBy` | IaC tool identifier | `terraform` (static) | All resources via default_tags |
| `Owner` | Ownership/accountability | `insight-technical-exercise` | All resources via default_tags |
| `CreatedDate` | Resource creation date | `YYYY-MM-DD` format | All resources via default_tags |
| `Name` | Resource-specific name | `${name_prefix}-<suffix>` | Per-resource in modules |
| `Component` | K8s-specific labels | `alb`, `web`, etc. | K8s ingress annotations |

#### Kubernetes-Level Tags (Ingress Annotations)

The ALB ingress (`k8s/ingress.yaml`) applies additional tags via annotations:
```yaml
alb.ingress.kubernetes.io/tags: Environment=dev,Project=tasky,ManagedBy=kubernetes,Component=alb
```

#### Naming Convention

Resources follow the pattern: `${project_name}-${environment}-${stack_version}-<resource_suffix>`

Example: `tasky-dev-v15-eks-cluster`, `tasky-dev-v15-mongodb`

#### Current Cost Tracking Approach

1. **No dedicated billing tags** — No `billing_code`, `cost_center`, or financial tracking tags
2. **No IS/FISMA identifiers** — No `information_system_id`, `system_owner`, or `data_classification` tags
3. **Cost estimation via CI/CD** — `cost-analysis.yml` workflow uses scripts to estimate costs
4. **Cost scripts:** `scripts/cost-terraform.sh`, `scripts/advanced-cost-analysis.sh`
5. **Cost validation range:** $80-$200/month expected for full stack

#### Gaps Identified for Azure Migration

| Gap | Description | Azure Requirement |
|-----|-------------|-------------------|
| No billing code tag | Cannot allocate costs to specific budgets | `billing_code` tag for cost management |
| No cost center tag | Cannot attribute costs to organizational units | `cost_center` tag for chargeback |
| No IS identifier | Missing FISMA/compliance system identifier | `information_system_id` for IS tracking |
| No system owner | Ownership not linked to identity management | `system_owner` for accountability |
| No data classification | No sensitivity labeling on resources | `data_classification` for compliance |
| Timestamp tag | `CreatedDate` uses `timestamp()` — changes on every apply | Use static date or remove drift |

#### Proposed Azure Tag Mapping

| AWS Tag (Current) | Azure Tag (Proposed) | Notes |
|-------------------|---------------------|-------|
| `Project` = "tasky" | `project` = "tasky" | Lowercase convention for Azure |
| `Environment` | `environment` | Keep: `dev`, `prod` |
| `StackVersion` | *Remove* | Not needed with Azure resource groups per environment |
| `ManagedBy` = "terraform" | `managed_by` = "terraform" | Snake_case convention |
| `Owner` | `system_owner` | Align with IS requirement |
| `CreatedDate` | *Remove* | Causes Terraform drift — `timestamp()` changes on every apply, triggering unnecessary resource updates. Replace with a static variable or omit entirely. |
| *NEW* | `billing_code` | Required for cost allocation |
| *NEW* | `cost_center` | Required for organizational chargeback |
| *NEW* | `information_system_id` | Required for FISMA/IS tracking |
| *NEW* | `data_classification` | Required for compliance (Unclassified/CUI) |

#### Proposed Common Tags Block for Azure

```hcl
common_tags = {
  project               = var.project_name
  environment           = var.environment
  managed_by            = "terraform"
  billing_code          = var.billing_code
  cost_center           = var.cost_center
  information_system_id = var.information_system_id
  system_owner          = var.system_owner
  data_classification   = var.data_classification
}
```

## Acceptance Criteria

- [x] Current 6-tag AWS taxonomy documented (Project, Environment, StackVersion, ManagedBy, Owner, CreatedDate)
- [x] Tag application mechanism documented (local.common_tags + default_tags provider)
- [x] Naming convention documented (project-environment-stackversion-suffix)
- [x] Current cost tracking approach documented (CI/CD-based estimation, no billing tags)
- [x] Gaps identified for Azure migration (no billing_code, cost_center, IS identifiers)
- [x] Proposed Azure tag mapping created with new required tags
- [x] Kubernetes-level tags (ingress annotations) documented

## References

- [Azure Resource Tagging Best Practices](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-tagging)
- [Azure Cost Management](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/quick-acm-cost-analysis)
- [Azure Policy for Tag Governance](https://learn.microsoft.com/en-us/azure/governance/policy/concepts/effects#modify)
- Source: `terraform/main.tf` (lines 10-23), `terraform/providers.tf`, `k8s/ingress.yaml` (line 29)
