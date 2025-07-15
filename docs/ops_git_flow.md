# GitOps Flow Strategy & Operations Guide

## Overview

This document outlines the GitOps workflow strategy for the Tasky Pivot for Insight project, incorporating GitHub Actions automation, environment-specific deployments, and secure credential management.

## Git Branch Strategy

### Branch Structure
```
main                    # Production-ready code, container builds
├── develop             # Integration branch for feature development
├── feature/*           # Individual feature branches
├── hotfix/*           # Critical production fixes
└── deploy/*           # Environment-specific deployment branches
    ├── deploy/dev-v1   # Development environment deployment
    ├── deploy/stg-v2   # Staging environment deployment
    └── deploy/prod-v3  # Production environment deployment
```

### GitHub Actions Trigger Strategy

| Workflow | Trigger Branches | Purpose |
|----------|------------------|---------|
| `build-and-publish.yml` | `main`, `develop` | Build and publish container images |
| `terraform-plan.yml` | `deploy/*` (PRs only) | Terraform plan validation and review |
| `terraform-apply.yml` | `deploy/*` (push/manual) | Infrastructure deployment |

## Phase 2: Infrastructure Deployment Strategy

### Current Status ✅
- [x] Phase 1: Pre-flight validation completed
- [x] Container registry setup at: `ghcr.io/rmcveyhsawaknow/tasky-pivot-for-insight`
- [x] GitHub Actions workflows configured with proper branch filtering
- [x] Development branch (`develop`) integration tested

### Next Steps: AWS Infrastructure Deployment

#### Step 1: Create Development Deployment Branch

```bash
# Location: Repo Root Directory
git checkout develop
git pull origin develop
git checkout -b deploy/dev-v1

# Copy and customize Terraform variables for development
cp terraform/terraform.tfvars.example terraform/terraform-dev.tfvars
```

#### Step 2: Configure Development Environment Variables

Edit `terraform/terraform-dev.tfvars` with development-specific settings:

```hcl
# Development Environment Configuration
aws_region    = "us-east-2"
environment   = "dev"
project_name  = "tasky"
stack_version = "v1"

# Development EKS Configuration (cost-optimized)
eks_node_instance_types = ["t3.small"]  # Smaller instances for dev
eks_node_desired_size   = 1             # Single node for dev
eks_node_max_size       = 2
eks_node_min_size       = 1

# Development MongoDB Configuration
mongodb_instance_type = "t3.small"      # Smaller instance for dev
mongodb_username     = "taskyadmin"
mongodb_password     = "DevTaskySecure123!" # Dev-specific password

# Development-specific tags
additional_tags = {
  CostCenter  = "development"
  AutoShutdown = "true"
  Owner       = "rmcveyhsawaknow"
}
```

#### Step 3: GitHub Secrets Configuration

Configure the following secrets in GitHub repository settings (`Settings > Secrets and variables > Actions`):

**Environment Secrets (for deploy/dev-v1):**
```
AWS_ACCESS_KEY_ID       # IAM user access key for development
AWS_SECRET_ACCESS_KEY   # IAM user secret key for development
AWS_REGION              # us-east-2
MONGODB_PASSWORD        # DevTaskySecure123!
JWT_SECRET              # Development JWT secret
```

**Repository Secrets (for OIDC - Recommended):**
```
AWS_ROLE_ARN           # arn:aws:iam::ACCOUNT:role/GitHubActionsTerraformRole
AWS_REGION             # us-east-2
```

## Phase 3: Terraform Deployment Execution

### Step 1: Push Development Deployment Branch

```bash
# Add terraform variables file
git add terraform/terraform-dev.tfvars

# Commit deployment configuration
git commit -m "deploy: configure development environment v1

- Add development-specific Terraform variables
- Configure cost-optimized EKS and MongoDB instances
- Set up development environment secrets
- Enable automated deployment via GitHub Actions"

# Push to trigger terraform-apply.yml workflow
git push origin deploy/dev-v1
```

### Step 2: Monitor GitHub Actions Deployment

1. **Navigate to**: `https://github.com/rmcveyhsawaknow/tasky-pivot-for-insight/actions`
2. **Monitor**: `Terraform Apply` workflow execution
3. **Expected Duration**: 15-20 minutes for complete infrastructure deployment
4. **Verify**: All steps complete successfully:
   - AWS credentials configuration
   - Terraform initialization
   - Infrastructure planning
   - Resource deployment (VPC, EKS, EC2, S3)

### Step 3: Post-Deployment Configuration

After successful Terraform deployment:

```bash
# Configure kubectl access (run locally)
aws eks update-kubeconfig --region us-east-2 --name tasky-dev-v1-eks-cluster

# Verify EKS connectivity
kubectl get nodes
kubectl cluster-info

# Deploy application to EKS
cd k8s/
kubectl apply -f .

# Monitor deployment
kubectl get pods -n tasky --watch

# Get application URL
kubectl get svc tasky-service -n tasky -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## Phase 4: Validation & Testing Checklist

### Infrastructure Validation ✅

```bash
# 1. Verify Terraform outputs
cd terraform/
terraform output

# 2. Check EKS cluster status
aws eks describe-cluster --name tasky-dev-v1-eks-cluster

# 3. Validate MongoDB EC2 instance
MONGODB_IP=$(terraform output -raw mongodb_private_ip)
INSTANCE_ID=$(terraform output -raw mongodb_instance_id)
aws ec2 describe-instances --instance-ids $INSTANCE_ID

# 4. Test S3 backup bucket
S3_BUCKET=$(terraform output -raw s3_backup_bucket_name)
aws s3 ls s3://$S3_BUCKET/
curl -I https://$S3_BUCKET.s3.us-east-2.amazonaws.com/backups/
```

### Application Validation ✅

```bash
# 1. Check pod status
kubectl get pods -n tasky

# 2. Verify LoadBalancer service
kubectl get svc tasky-service -n tasky

# 3. Test application access
LB_URL=$(kubectl get svc tasky-service -n tasky -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl -I http://$LB_URL

# 4. Verify exercise.txt in container
kubectl exec -it deployment/tasky-app -n tasky -- cat /app/exercise.txt

# 5. Test MongoDB connectivity from pod
kubectl exec -it deployment/tasky-app -n tasky -- nc -zv $MONGODB_IP 27017
```

### Security Validation ✅

```bash
# 1. Verify cluster-admin permissions
kubectl auth can-i '*' '*' --as=system:serviceaccount:tasky:tasky-admin

# 2. Check EC2 instance IAM permissions
aws ssm send-command \
  --instance-ids $INSTANCE_ID \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["aws sts get-caller-identity"]'

# 3. Test S3 public access
curl -I https://$S3_BUCKET.s3.us-east-2.amazonaws.com/backups/latest.tar.gz

# 4. Verify legacy system requirements
aws ssm send-command \
  --instance-ids $INSTANCE_ID \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["cat /etc/os-release", "mongod --version"]'
```

## Environment Promotion Strategy

### Development → Staging Promotion

```bash
# 1. Create staging deployment branch
git checkout develop
git checkout -b deploy/stg-v2

# 2. Copy and modify staging variables
cp terraform/terraform-dev.tfvars terraform/terraform-stg.tfvars
# Edit for staging-specific configuration (larger instances, multi-AZ)

# 3. Update environment in variables
sed -i 's/environment   = "dev"/environment   = "stg"/' terraform/terraform-stg.tfvars
sed -i 's/stack_version = "v1"/stack_version = "v2"/' terraform/terraform-stg.tfvars

# 4. Commit and push
git add terraform/terraform-stg.tfvars
git commit -m "deploy: configure staging environment v2"
git push origin deploy/stg-v2
```

### Staging → Production Promotion

```bash
# 1. Create production deployment branch
git checkout main
git checkout -b deploy/prod-v3

# 2. Copy staging configuration and enhance for production
cp terraform/terraform-stg.tfvars terraform/terraform-prod.tfvars
# Edit for production requirements (larger instances, backup retention, monitoring)

# 3. Production-specific security and compliance
# - Enable detailed CloudWatch logging
# - Configure backup retention policies
# - Add additional security groups
# - Enable GuardDuty and CloudTrail integration

# 4. Require manual approval for production deployment
# Configure GitHub Environment protection rules
```

## Troubleshooting Guide

### Common Issues & Solutions

#### 1. GitHub Actions Terraform Apply Fails

```bash
# Check AWS credentials in GitHub secrets
# Verify IAM permissions for Terraform operations
# Review Terraform plan logs in GitHub Actions

# Debug locally:
cd terraform/
terraform init
terraform plan -var-file=terraform-dev.tfvars
```

#### 2. EKS Pods in CrashLoopBackOff

```bash
# Check pod logs
kubectl logs -f deployment/tasky-app -n tasky

# Verify secrets and configmaps
kubectl describe secret tasky-secrets -n tasky
kubectl describe configmap tasky-config -n tasky

# Check MongoDB connectivity
kubectl exec -it deployment/tasky-app -n tasky -- telnet $MONGODB_IP 27017
```

#### 3. LoadBalancer Service Pending

```bash
# Check AWS Load Balancer Controller
kubectl get pods -n kube-system | grep aws-load-balancer

# Verify subnet tags for load balancer provisioning
aws ec2 describe-subnets --filters "Name=tag:kubernetes.io/role/elb,Values=1"

# Check service events
kubectl describe svc tasky-service -n tasky
```

## Security Best Practices

### Secrets Management

1. **GitHub Secrets**: Use repository or environment-specific secrets
2. **OIDC Integration**: Prefer IAM roles over long-lived access keys
3. **Environment Isolation**: Separate AWS accounts/regions for environments
4. **Principle of Least Privilege**: Minimal IAM permissions for each environment

### Branch Protection Rules

Configure the following protection rules:

- `main`: Require PR reviews, status checks, up-to-date branches
- `develop`: Require status checks, allow force pushes for integration
- `deploy/*`: Require manual approval for production environments

## Cost Management

### Development Environment
- **Auto-shutdown**: Configure Lambda function for off-hours shutdown
- **Spot Instances**: Use spot instances for non-critical workloads
- **Resource Limits**: Minimal instance sizes for cost optimization

### Monitoring & Alerts
- Set up billing alerts for unexpected charges
- Monitor resource utilization with CloudWatch
- Implement resource tagging for cost allocation

## Next Steps: Phase 5 Implementation

1. **Execute Development Deployment** (Current Priority)
   - Create `deploy/dev-v1` branch with configuration
   - Configure GitHub secrets for AWS access
   - Execute terraform deployment via GitHub Actions
   - Validate infrastructure and application deployment

2. **Application Integration Testing**
   - Deploy application to EKS cluster
   - Test MongoDB connectivity and authentication
   - Verify public access and LoadBalancer functionality
   - Validate all exercise requirements

3. **Documentation & Presentation Prep**
   - Update deployment status in documentation
   - Capture screenshots and demo flows
   - Prepare 45-minute technical presentation
   - Create runbooks for common operations

## Status Dashboard

### Current State: Phase 2 - Infrastructure Deployment Ready

- ✅ **Phase 1**: Pre-flight validation completed
- ✅ **GitHub Actions**: Container build pipeline operational
- ✅ **Branch Strategy**: Deploy branch filtering configured
- 🔄 **Phase 2**: AWS infrastructure deployment in progress
- ⏳ **Phase 3**: Application deployment pending
- ⏳ **Phase 4**: Security validation pending
- ⏳ **Phase 5**: Production readiness pending

**Next Action**: Execute development environment deployment via `deploy/dev-v1` branch

---

*This GitOps flow ensures secure, automated, and environment-specific deployments while maintaining separation of concerns between code development and infrastructure operations.*
