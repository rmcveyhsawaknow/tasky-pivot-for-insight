---
post_title: "AWS to Azure PaaS Migration - Tasky Application"
author1: "Platform Engineering"
post_slug: "aws-to-azure-paas-migration"
microsoft_alias: "N/A"
featured_image: "N/A"
categories: "Cloud Migration"
tags: "azure, aws, terraform, migration, paas, iac, github-actions"
ai_note: "AI-assisted migration planning"
summary: "Project migration plan for porting the Tasky application infrastructure from AWS PaaS services to Azure PaaS services with updated GitHub Actions CI/CD workflows."
post_date: "2026-03-06"
---

## Project Overview

This document defines the scope, objectives, and phased approach for migrating the
Tasky application infrastructure from AWS cloud services to Azure PaaS services. The
migration focuses exclusively on infrastructure and CI/CD changes — the application
code (Go/Gin web app) remains unchanged.

### Objective

Port the Tasky three-tier application infrastructure from AWS to Azure PaaS equivalents
while maintaining application functionality, implementing enterprise-grade tagging for
billing and IS asset tracking, and updating GitHub Actions workflows for Azure deployment.

### Scope

**In Scope:**

- Infrastructure-as-Code migration from AWS Terraform modules to Azure Terraform modules
- GitHub Actions CD workflow updates for Azure deployment (terraform-plan, terraform-apply)
- Kubernetes manifest updates for AKS compatibility (ingress, annotations)
- Environment tier configuration for dev and prod
- Standard tagging for billing codes and Information System identifiers
- Cost analysis workflow updates for Azure pricing

**Out of Scope:**

- Application code changes (Go/Gin backend, HTML/JS frontend)
- Application CI workflow changes (Docker build-and-publish to GHCR is cloud-agnostic)
- Data migration from existing MongoDB to Cosmos DB (separate operational task)
- DNS and custom domain configuration
- SSL/TLS certificate provisioning

## Current Architecture (AWS)

The Tasky application runs on a three-tier AWS architecture:

```
┌─────────────────────────────────────────────────────────────────┐
│                    AWS Three-Tier Architecture                   │
├─────────────────────────────────────────────────────────────────┤
│  Web Tier:     Amazon EKS (v1.28) + AWS ALB (K8s managed)      │
│  Data Tier:    MongoDB 4.0.x on EC2 (Amazon Linux 2)           │
│  Storage Tier: S3 Bucket (versioned, public read for backups)  │
│  Network:      VPC (10.0.0.0/16), 3 AZs, public/private       │
│  IAM:          OIDC, IRSA, instance profiles                   │
│  Monitoring:   CloudWatch log groups                           │
│  State:        S3 + DynamoDB (Terraform backend)               │
└─────────────────────────────────────────────────────────────────┘
```

### AWS Services Inventory

| Component | AWS Service | Configuration |
|-----------|-------------|---------------|
| Container Orchestration | Amazon EKS v1.28 | Managed node group, t3.medium, 1-3 nodes |
| Database | MongoDB 4.0.x on EC2 | Amazon Linux 2, t3.medium, private subnet |
| Object Storage | Amazon S3 | Versioning, lifecycle (30d), public read |
| Load Balancer | AWS ALB | K8s-managed via AWS LB Controller |
| Networking | AWS VPC | 10.0.0.0/16, 3 AZs, NAT Gateway |
| Identity | AWS IAM | OIDC, IRSA, instance profiles |
| Monitoring | CloudWatch | Log groups for MongoDB backup |
| IaC State | S3 + DynamoDB | Terraform remote backend |
| CI/CD | GitHub Actions | OIDC auth to AWS |

### Terraform Modules (Current)

| Module | Purpose | Key Resources |
|--------|---------|---------------|
| `vpc` | Network foundation | VPC, subnets, IGW, NAT GW, route tables, VPC endpoints |
| `eks` | Container orchestration | EKS cluster, node group, addons, IRSA |
| `mongodb-ec2` | Database tier | EC2 instance, security group, IAM role, CloudWatch |
| `s3-backup` | Backup storage | S3 bucket, versioning, lifecycle, public access |
| `alb` | Load balancing (commented) | ALB, target group, listeners, Route53 |

## Target Architecture (Azure)

```
┌─────────────────────────────────────────────────────────────────┐
│                   Azure Three-Tier Architecture                  │
├─────────────────────────────────────────────────────────────────┤
│  Web Tier:     Azure AKS + Ingress Controller                  │
│  Data Tier:    Azure Cosmos DB for MongoDB API (4.0)           │
│  Storage Tier: Azure Blob Storage (lifecycle, public access)   │
│  Network:      Azure VNet, subnets, NSGs, NAT Gateway         │
│  Identity:     Azure RBAC, Managed Identity, Workload Identity │
│  Monitoring:   Azure Monitor + Log Analytics                   │
│  State:        Azure Storage Account (Terraform backend)       │
└─────────────────────────────────────────────────────────────────┘
```

### Service Mapping

| Component | AWS Service | Azure PaaS Equivalent | Notes |
|-----------|-------------|----------------------|-------|
| Container Orchestration | EKS | Azure Kubernetes Service (AKS) | Managed K8s, Azure CNI networking |
| Database | MongoDB on EC2 | Cosmos DB for MongoDB API | PaaS, MongoDB 4.0 wire protocol compatible |
| Object Storage | S3 | Azure Blob Storage | Storage Account with blob container |
| Load Balancer | ALB (K8s) | App Gateway Ingress or nginx-ingress | AGIC or community ingress controller |
| Virtual Network | VPC | Azure Virtual Network (VNet) | Subnets, NSGs, NAT Gateway |
| Identity/Auth | IAM + OIDC | Azure RBAC + Managed Identity | Workload identity for AKS pods |
| Monitoring | CloudWatch | Azure Monitor + Log Analytics | Container Insights for AKS |
| IaC State | S3 + DynamoDB | Azure Storage Account | Blob backend with state locking |
| CI/CD Auth | AWS OIDC Role | Azure OIDC Federated Credentials | App registration + federated identity |

## Tagging Strategy

All Azure resources will include standard tags for billing and IS asset tracking:

### Required Tags

| Tag Key | Description | Example Values |
|---------|-------------|----------------|
| `billing_code` | Billing/charge code for cost allocation | `PROJ-TASKY-2026` |
| `cost_center` | Cost center identifier | `CC-ENGINEERING-001` |
| `information_system_id` | FISMA/IS system identifier | `IS-TASKY-001` |
| `system_owner` | System owner contact | `platform-engineering` |
| `data_classification` | Data sensitivity classification | `Unclassified`, `CUI` |
| `environment` | Deployment environment | `dev`, `prod` |
| `project` | Project name | `tasky` |
| `managed_by` | IaC tool identifier | `terraform` |

### Environment Tiers

| Parameter | Dev Tier | Prod Tier |
|-----------|----------|-----------|
| AKS Node Count | 1 | 2-3 |
| AKS Node Size | Standard_B2s | Standard_D2s_v3 |
| Cosmos DB RU/s | 400 | 1000 |
| Blob Storage Tier | Cool | Hot |
| Log Retention (days) | 7 | 30 |
| VNet CIDR | 10.1.0.0/16 | 10.2.0.0/16 |

## Migration Phases

### Phase 1: Assessment

Inventory and document the current application stack, infrastructure components,
CI/CD workflows, tagging strategy, and configuration dependencies. This phase
produces the technical baseline for all subsequent migration work.

**Deliverables:**

- Application architecture documentation
- AWS IaC inventory
- CI/CD workflow documentation
- Tagging strategy mapping
- Configuration dependency map

### Phase 2: Service Mapping

Research and document the parallel Azure PaaS service for each AWS component.
Evaluate compatibility, configuration differences, and migration considerations
for networking, compute, database, storage, identity, and monitoring.

**Deliverables:**

- AWS-to-Azure service mapping matrix
- Compatibility assessment per service
- Network architecture design for Azure
- Identity and access model for Azure

### Phase 3: IaC Development

Develop Terraform modules for all Azure infrastructure components with support
for dev and prod environment tiers. Implement standard tagging inputs for billing
codes and IS asset tracking identifiers across all modules.

**Deliverables:**

- Azure Terraform provider configuration
- Resource group module
- Virtual network module
- AKS cluster module
- Cosmos DB for MongoDB module
- Blob storage module
- Application Gateway / ingress module
- Monitor and Log Analytics module
- Root module with standard tag inputs
- Environment-specific tfvars (dev, prod)

### Phase 4: CI/CD Updates

Update GitHub Actions workflows to deploy to Azure instead of AWS. Replace
AWS OIDC authentication with Azure OIDC, update Terraform backend configuration,
and modify deployment steps for AKS. Update Kubernetes manifests for AKS
compatibility.

**Deliverables:**

- Updated terraform-plan.yml for Azure
- Updated terraform-apply.yml for Azure
- Updated cost-analysis.yml for Azure
- Azure OIDC federation documentation
- Updated Kubernetes manifests for AKS
- Verified build-and-publish.yml (no changes expected)

### Phase 5: Validation

Validate all Terraform modules compile and plan successfully for both dev and
prod environments. Validate GitHub Actions workflow syntax and configuration.
Create migration validation checklist and document rollback strategy.

**Deliverables:**

- Terraform plan validation (dev)
- Terraform plan validation (prod)
- Workflow syntax validation
- Migration validation checklist
- Rollback strategy documentation

## GitHub Actions Workflow Changes Summary

### Workflows Requiring Updates

| Workflow | Change Type | Key Changes |
|----------|-------------|-------------|
| `terraform-plan.yml` | Significant | Azure OIDC login, Azure env vars, Azure backend |
| `terraform-apply.yml` | Significant | Azure OIDC login, AKS kubectl config, Azure deploy steps |
| `cost-analysis.yml` | Moderate | Azure pricing references, Azure cost components |
| `build-and-publish.yml` | None/Minimal | GHCR-based, cloud-agnostic |

### CI/CD Authentication Changes

| Aspect | AWS (Current) | Azure (Target) |
|--------|---------------|----------------|
| Auth Method | OIDC via `aws-actions/configure-aws-credentials` | OIDC via `azure/login` |
| Secret: Role/ID | `AWS_ROLE_ARN` | `AZURE_CLIENT_ID` |
| Secret: Region/Location | `AWS_REGION` | `AZURE_LOCATION` |
| Additional Secrets | N/A | `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` |
| kubectl Config | `aws eks update-kubeconfig` | `az aks get-credentials` |
| Terraform Backend | S3 + DynamoDB | Azure Storage Account |

## Backlog Reference

The detailed task backlog is maintained in
[`aws-to-azure-migration-backlog.csv`](./aws-to-azure-migration-backlog.csv).

Each task in the CSV maps to a GitHub issue created in the repository project
board for Kanban-style tracking. Issues are labeled by phase and task type for
filtering and sprint planning.

## Issue Labels

| Label | Description |
|-------|-------------|
| `phase:assessment` | Phase 1 assessment tasks |
| `phase:service-mapping` | Phase 2 service mapping tasks |
| `phase:iac-development` | Phase 3 IaC development tasks |
| `phase:cicd-updates` | Phase 4 CI/CD update tasks |
| `phase:validation` | Phase 5 validation tasks |
| `task:documentation` | Documentation deliverables |
| `task:research` | Research and analysis tasks |
| `task:development` | Code/IaC development tasks |
| `task:configuration` | Configuration tasks |
| `task:testing` | Testing and validation tasks |
| `task:validation` | Verification tasks |
| `migration:aws-to-azure` | All migration project tasks |

## Job Description Alignment

This migration project directly demonstrates competencies required for the
Lead Azure Architect role at Avilamb:

| Job Requirement | Project Demonstration |
|-----------------|----------------------|
| Enterprise-scale Azure infrastructure | AKS, Cosmos DB, VNet, App Gateway architecture |
| Post-migration optimization | PaaS service selection over lift-and-shift EC2 |
| Cloud cost optimization | Environment-tier sizing, Cosmos DB RU/s tuning |
| Enterprise landing zone architecture | VNet design, subnet strategy, NSG governance |
| RBAC and tagging governance | Standard billing/IS tags, managed identity RBAC |
| Infrastructure-as-Code (Terraform) | Full Terraform module library for Azure |
| Azure Monitor and observability | Log Analytics, Container Insights |
| Multi-cloud exposure (AWS) | Source AWS architecture documented |
| GitOps practices | GitHub Actions CI/CD with OIDC |
| Federal/regulated environment | IS identifier tagging, data classification |
