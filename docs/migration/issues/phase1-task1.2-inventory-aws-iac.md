# [Migration] 1.2 - Inventory Current AWS Infrastructure as Code

## AWS to Azure PaaS Migration Task

> **Phase:** 1 - Assessment
> **Backlog Task ID:** 1.2
> **Category:** Assessment
> **AWS Source Service:** AWS (Terraform IaC)
> **Priority:** High
> **Estimated Effort:** 2 days
> **Dependencies:** None

## Task Description

Catalog all Terraform modules (vpc, eks, mongodb-ec2, s3-backup, alb) and their resource definitions. Document provider versions, backend state configuration (S3 + DynamoDB), variable inputs, outputs, and inter-module dependencies.

### Research Findings

#### Terraform Configuration Overview

| Configuration | Value |
|--------------|-------|
| Required Terraform Version | >= 1.7.5 |
| AWS Provider | hashicorp/aws ~> 5.0 |
| Kubernetes Provider | hashicorp/kubernetes ~> 2.20 |
| Helm Provider | hashicorp/helm ~> 2.10 |
| State Backend (prod) | S3 bucket `tasky-terraform-state-152451250193` |
| State Locking | DynamoDB table `terraform-state-lock` |
| State Key | `tasky/terraform.tfstate` |
| State Encryption | Enabled |
| AWS Region | us-east-1 (default) |

#### Root Module Structure

```
terraform/
├── main.tf              → Module composition (vpc, s3_backup, mongodb_ec2, eks)
├── variables.tf         → 18 input variables with validations
├── outputs.tf           → 20+ outputs (cluster, db, backup, instructions)
├── providers.tf         → aws, kubernetes, helm providers
├── versions.tf          → Required provider versions
├── backend.tf           → Local backend (dev), backend-prod.hcl (prod)
├── backend-prod.hcl     → S3 backend config for CI/CD
└── modules/
    ├── vpc/             → VPC, subnets, IGW, NAT, routes, endpoints
    ├── eks/             → EKS cluster, node group, addons, IRSA
    ├── mongodb-ec2/     → EC2, security group, IAM, CloudWatch
    ├── s3-backup/       → S3 bucket, versioning, lifecycle, public access
    └── alb/             → ALB, target group, listeners, Route53 (commented out)
```

#### Module Inventory

##### VPC Module (`modules/vpc/`)
| File | Resources |
|------|-----------|
| main.tf | `aws_vpc`, `aws_internet_gateway`, `aws_subnet` (public x3, private x3), `aws_nat_gateway`, `aws_eip`, `aws_route_table` (public, private), `aws_route_table_association` (x6), `aws_vpc_endpoint` (S3, EC2), `aws_security_group` (vpc-endpoints) |
| variables.tf | `project_name`, `environment`, `stack_version`, `vpc_cidr`, `availability_zones`, `tags` |
| outputs.tf | `vpc_id`, `public_subnet_ids`, `private_subnet_ids`, `nat_gateway_id` |

##### EKS Module (`modules/eks/`)
| File | Resources |
|------|-----------|
| main.tf | `aws_eks_cluster`, `aws_eks_node_group`, `aws_iam_role` (cluster + node), `aws_iam_role_policy_attachment` (multiple), `aws_eks_addon` (vpc-cni, coredns, kube-proxy, ebs-csi), `aws_iam_openid_connect_provider`, `aws_iam_role` (ALB controller IRSA), `aws_security_group` + rules |
| variables.tf | `project_name`, `environment`, `stack_version`, `vpc_id`, `private_subnet_ids`, `public_subnet_ids`, `node_instance_types`, `node_desired_size`, `node_max_size`, `node_min_size`, `mongodb_security_group_id`, `tags` |
| outputs.tf | `cluster_name`, `cluster_endpoint`, `cluster_security_group_id`, `node_group_security_group_id`, `cluster_certificate_authority_data`, `aws_load_balancer_controller_role_arn` |

##### MongoDB EC2 Module (`modules/mongodb-ec2/`)
| File | Resources |
|------|-----------|
| main.tf | `aws_instance` (Amazon Linux 2, t3.medium), `aws_security_group` (MongoDB 27017 + SSH), `aws_iam_role` + `aws_iam_instance_profile` (AdministratorAccess), `aws_cloudwatch_log_group` (30-day retention), user-data bootstrap script |
| variables.tf | `project_name`, `environment`, `stack_version`, `vpc_id`, `private_subnet_ids`, `instance_type`, `mongodb_username`, `mongodb_password`, `mongodb_database_name`, `backup_bucket_name`, `tags` |
| outputs.tf | `private_ip`, `instance_id`, `security_group_id`, `mongodb_connection_uri`, `cloudwatch_log_group_name`, `troubleshooting_commands` |

##### S3 Backup Module (`modules/s3-backup/`)
| File | Resources |
|------|-----------|
| main.tf | `aws_s3_bucket` (force_destroy), `aws_s3_bucket_versioning`, `aws_s3_bucket_public_access_block` (public read), `aws_s3_bucket_policy` (public read + ALB logs), `aws_s3_bucket_lifecycle_configuration` (30-day retention) |
| variables.tf | `project_name`, `environment`, `stack_version`, `tags` |
| outputs.tf | `bucket_name`, `bucket_arn`, `public_url` |

##### ALB Module (`modules/alb/`) — Currently Commented Out
| File | Resources |
|------|-----------|
| main.tf | `aws_lb` (internet-facing), `aws_lb_target_group` (port 8080, IP-based), `aws_lb_listener` (HTTP/HTTPS), `aws_security_group` (80/443), `aws_route53_record` (optional alias), `aws_security_group_rule` (ALB→EKS egress) |
| variables.tf | Full ALB configuration variables |
| outputs.tf | `alb_dns_name`, `alb_hosted_zone_id`, `target_group_arn`, `application_url`, `custom_domain_url` |

**Note:** ALB module is commented out in root `main.tf` — ALB is now managed by Kubernetes AWS Load Balancer Controller via `k8s/ingress.yaml`. The module files remain in the codebase as a reference implementation. For the Azure migration, this module will not be ported; the equivalent functionality will be provided by an Azure Application Gateway Ingress Controller (AGIC) or nginx-ingress on AKS.

#### Inter-Module Dependencies

```
vpc ──────────────────────────────────┐
  ├── vpc_id ──────────────→ eks      │
  ├── vpc_id ──────────────→ mongodb  │
  ├── private_subnet_ids ──→ eks      │
  ├── private_subnet_ids ──→ mongodb  │
  └── public_subnet_ids ──→ eks      │
                                      │
s3_backup ────────────────────────────│
  └── bucket_name ────────→ mongodb   │
                                      │
mongodb_ec2 ──────────────────────────│
  └── security_group_id ──→ eks      │
```

#### Root Variables Summary

| Variable | Type | Default | Sensitive |
|----------|------|---------|-----------|
| `aws_region` | string | `us-east-1` | No |
| `environment` | string | `dev` | No |
| `project_name` | string | `tasky` | No |
| `stack_version` | string | `v1` | No |
| `vpc_cidr` | string | `10.0.0.0/16` | No |
| `mongodb_instance_type` | string | `t3.medium` | No |
| `mongodb_username` | string | `taskyadmin` | No |
| `mongodb_password` | string | `TaskySecure123!` | Yes |
| `mongodb_database_name` | string | `go-mongodb` | No |
| `jwt_secret` | string | (default set) | Yes |
| `eks_node_instance_types` | list(string) | `["t3.medium"]` | No |
| `eks_node_desired_size` | number | `2` | No |
| `eks_node_max_size` | number | `3` | No |
| `eks_node_min_size` | number | `1` | No |
| `alb_health_check_path` | string | `/` | No |
| `alb_ssl_certificate_arn` | string | `null` | No |
| `alb_enable_access_logs` | bool | `false` | No |
| `alb_domain_name` | string | `null` | No |

#### Common Tags (Applied to All Resources)

```hcl
common_tags = {
  Project      = "tasky"
  Environment  = var.environment
  StackVersion = var.stack_version
  ManagedBy    = "terraform"
  Owner        = "insight-technical-exercise"
  CreatedDate  = formatdate("YYYY-MM-DD", timestamp())
}
```

#### Naming Convention

All resources follow: `${project_name}-${environment}-${stack_version}-<resource_suffix>`

Example: `tasky-dev-v15-eks-cluster`

## Acceptance Criteria

- [x] All 5 Terraform modules cataloged with resource definitions (vpc, eks, mongodb-ec2, s3-backup, alb)
- [x] Provider versions documented (aws ~>5.0, kubernetes ~>2.20, helm ~>2.10)
- [x] Backend state configuration documented (S3 bucket + DynamoDB table + encryption)
- [x] All 18 root variables documented with types, defaults, and sensitivity flags
- [x] All 20+ outputs documented across root and modules
- [x] Inter-module dependency graph documented
- [x] Naming convention documented
- [x] Common tagging strategy documented

## References

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform S3 Backend](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
- Source: `terraform/main.tf`, `terraform/variables.tf`, `terraform/outputs.tf`, `terraform/versions.tf`, `terraform/providers.tf`, `terraform/backend-prod.hcl`, `terraform/modules/*/`
