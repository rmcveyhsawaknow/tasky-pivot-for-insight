# Tasky Infrastructure Terraform

This directory contains the Infrastructure-as-Code (IaC) implementation for the Tasky three-tier web application using Terraform and AWS services.

## ⚠️ IMPORTANT: Terraform Destroy Issues and Solutions

### Common Problem
Running `terraform destroy` may fail with:
- S3 bucket not empty errors (versioned objects)
- Subnet dependency violations (orphaned ENIs from EKS/ALB)
- Resource cleanup timing issues

### ✅ Solution: Use Provided Scripts

We've created comprehensive scripts to handle these destroy issues:

#### 1. Safe Destroy (Recommended)
```bash
./safe-destroy.sh
```
**Complete automated destroy with cleanup, retries, and fallback options.**

#### 2. Pre-Destroy Cleanup
```bash
./cleanup-before-destroy.sh
terraform destroy -auto-approve
```
**Automated cleanup before manual destroy.**

#### 3. Manual Cleanup
```bash
./manual-cleanup.sh
```
**Interactive menu-driven cleanup for complex scenarios.**

### Scripts Overview

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `safe-destroy.sh` | Complete automated destroy | **Always use this first** |
| `cleanup-before-destroy.sh` | Automated pre-cleanup | When safe-destroy fails |
| `manual-cleanup.sh` | Interactive cleanup | When automation fails |

**📖 For detailed troubleshooting, see: [docs/terraform-destroy-troubleshooting.md](../docs/terraform-destroy-troubleshooting.md)**

---

## Architecture Overview

### Three-Tier Architecture Components

- **Web Tier**: Amazon EKS cluster hosting containerized Tasky application
- **Data Tier**: MongoDB 4.0.x on Amazon Linux 2 EC2 instance with authentication
- **Storage Tier**: S3 bucket for automated MongoDB backups with public read access

### AWS Services Used

- **VPC**: Custom network with public/private subnets across multiple AZs
- **EKS**: Kubernetes cluster for container orchestration and auto-scaling
- **EC2**: MongoDB database server with AdminAccess IAM permissions
- **S3**: Backup storage with public-read bucket policy
- **IAM**: Service roles and policies for secure resource access
- **Security Groups**: Network-level security controls

## Prerequisites

### Required Tools

- **Terraform**: >= 1.7.5, < 1.9.5
- **AWS CLI**: Configured with appropriate credentials
- **kubectl**: For EKS cluster management
- **Git**: For version control

### AWS Permissions

Your AWS credentials must have permissions to create:
- VPC and networking resources
- EKS clusters and node groups
- EC2 instances and security groups
- S3 buckets and bucket policies
- IAM roles and policies

## Quick Start

### 1. Clone Repository

```bash
git clone <repository-url>
cd tasky-pivot-for-insight/terraform
```

### 2. Configure Variables

Copy and customize the example variables:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your specific values:

```hcl
aws_region    = "us-east-1"
environment   = "dev"        # Options: dev, stg, prd
project_name  = "tasky"
stack_version = "v1"         # Version identifier for unique naming

# EKS Configuration
eks_node_instance_types = ["t3.medium"]
eks_node_desired_size   = 2
eks_node_max_size       = 3
eks_node_min_size       = 1

# MongoDB Configuration
mongodb_instance_type = "t3.medium"
mongodb_username     = "taskyadmin"
mongodb_password     = "your-secure-password"
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Plan Deployment

```bash
terraform plan
```

### 5. Deploy Infrastructure

```bash
terraform apply
```

### 6. Configure kubectl

```bash
aws eks update-kubeconfig --region us-east-1 --name tasky-dev-v1-eks-cluster
```

## Module Structure

```
terraform/
├── main.tf              # Main infrastructure configuration
├── variables.tf         # Input variables with validation
├── outputs.tf          # Output values for external use
├── versions.tf         # Terraform and provider version constraints
├── backend.tf          # Remote state configuration (commented)
├── terraform.tfvars.example  # Example variable values
└── modules/
    ├── vpc/            # VPC and networking resources
    ├── eks/            # EKS cluster and node groups
    ├── mongodb-ec2/    # MongoDB EC2 instance
    └── s3-backup/      # S3 backup bucket
```

## Configuration Variables

### Core Variables

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `aws_region` | AWS region for resources | string | "us-east-1" | No |
| `environment` | Environment name (dev/stg/prd) | string | "dev" | No |
| `project_name` | Project name for resource naming | string | "tasky" | No |
| `stack_version` | Stack version identifier | string | "v1" | No |

### EKS Variables

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `eks_node_instance_types` | EC2 instance types for worker nodes | list(string) | ["t3.medium"] | No |
| `eks_node_desired_size` | Desired number of worker nodes | number | 2 | No |
| `eks_node_max_size` | Maximum number of worker nodes | number | 3 | No |
| `eks_node_min_size` | Minimum number of worker nodes | number | 1 | No |

### MongoDB Variables

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `mongodb_instance_type` | EC2 instance type for MongoDB | string | "t3.medium" | No |
| `mongodb_username` | MongoDB admin username | string | "taskyadmin" | No |
| `mongodb_password` | MongoDB admin password | string | - | Yes |

## Output Values

After successful deployment, Terraform provides:

- **EKS cluster name and endpoint**
- **MongoDB private IP and connection string**
- **S3 backup bucket name and public URL**
- **kubectl configuration command**
- **Step-by-step deployment instructions**

## Security Considerations

### IAM Permissions

- **EKS Cluster**: Service-linked role with minimal required permissions
- **MongoDB EC2**: AdminAccess role (as per exercise requirements)
- **Node Groups**: Worker node permissions for EKS integration

### Network Security

- **VPC**: Isolated network with public/private subnet architecture
- **Security Groups**: Restrictive rules allowing only required traffic
- **MongoDB Access**: Port 27017 accessible only from EKS security group

### Data Protection

- **MongoDB**: Authentication enabled with username/password
- **S3 Backups**: Public read access (as per exercise requirements)
- **Secrets**: Sensitive values marked appropriately in Terraform

## State Management

### Local State (Default)

For development and testing, Terraform state is stored locally in `terraform.tfstate`.

### Backend Configuration

This Terraform configuration supports both local and remote backend storage:

#### Local Development (Default)
For local development and testing, the configuration uses local state storage:

```bash
# Recommended: Use the provided initialization script
./scripts/terraform-local-init.sh

# Alternative: Manual initialization
cd terraform
terraform init
```

**What the script does:**
- ✅ Formats Terraform files (`terraform fmt`)
- ✅ Initializes with local backend (`terraform init`)
- ✅ Provides helpful next steps and validation commands
- ✅ Clear indication of local vs CI/CD backend usage

This creates a local `terraform.tfstate` file in your terraform directory.

#### CI/CD Deployment (Remote Backend)
For CI/CD deployments, the configuration uses S3 remote backend with state locking:

```bash
# Used by GitHub Actions automatically
terraform init -backend-config=backend-prod.hcl
```

The remote backend configuration includes:
- **S3 Bucket**: `tasky-terraform-state-{ACCOUNT_ID}`
- **DynamoDB Table**: `terraform-state-lock` 
- **Encryption**: Enabled
- **State Locking**: Enabled

#### Backend Configuration Benefits

**Local Development:**
- ✅ Simple setup - no AWS configuration needed
- ✅ Fast initialization 
- ✅ Perfect for testing and experimentation
- ✅ No dependencies on remote resources

**CI/CD Deployment:**
- ✅ Team collaboration with shared state
- ✅ State locking prevents concurrent modifications
- ✅ Encryption at rest and in transit
- ✅ State versioning and history

## Deployment Validation

### Infrastructure Verification

```bash
# Verify all resources created successfully
terraform output

# Check EKS cluster status
aws eks describe-cluster --name tasky-dev-eks-cluster

# Verify MongoDB EC2 instance
aws ec2 describe-instances --filters "Name=tag:Project,Values=tasky"

# Check S3 bucket configuration
aws s3api get-bucket-policy --bucket tasky-dev-backup-bucket
```

### Application Deployment

```bash
# Configure kubectl
terraform output kubectl_config_command

# Deploy application
kubectl apply -f ../k8s/

# Monitor deployment
kubectl get pods -n tasky --watch

# Get application URL
kubectl get svc -n tasky
```

## Troubleshooting

### Common Issues

1. **EKS Node Group Failed**
   - Check subnet CIDR blocks have sufficient IP addresses
   - Verify IAM roles have required permissions

2. **MongoDB Connection Failed**
   - Ensure security group allows traffic on port 27017
   - Verify MongoDB service is running on EC2 instance

3. **S3 Access Denied**
   - Check bucket policy allows public read access
   - Verify backup scripts have proper IAM permissions

### Debugging Commands

```bash
# Check Terraform plan for errors
terraform plan -detailed-exitcode

# Validate configuration
terraform validate

# View state information
terraform show

# Debug specific resources
terraform state show module.eks.aws_eks_cluster.main
```

## Cost Optimization

### Resource Sizing

- **EKS Nodes**: Start with t3.medium, scale based on application needs
- **MongoDB**: t3.medium suitable for development, consider larger for production
- **Multi-AZ**: Reduces costs compared to cross-region deployment

### Cost Monitoring

- Enable AWS Cost Explorer for spending analysis
- Set up billing alerts for unexpected charges
- Use Spot instances for non-production EKS nodes

## Maintenance

### Regular Updates

- **Terraform**: Keep providers updated to latest stable versions
- **EKS**: Follow AWS EKS version lifecycle and upgrade path
- **MongoDB**: Plan upgrades from legacy 4.0.x to supported versions

### Backup Strategy

- **Terraform State**: Regular backups to secure location
- **MongoDB Data**: Automated daily backups to S3
- **Configuration**: Version control all infrastructure code

## Support

### Documentation

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [MongoDB Documentation](https://docs.mongodb.com/)

### Getting Help

1. Check Terraform plan output for specific error messages
2. Review AWS CloudTrail logs for API call failures
3. Consult module-specific README files in `modules/` directories
4. Use `terraform show` to inspect current infrastructure state

---

**Note**: This infrastructure is designed for the Insight Technical Exercise requirements, including legacy MongoDB version and specific security configurations. For production use, consider updating to supported MongoDB versions and implementing additional security hardening.
