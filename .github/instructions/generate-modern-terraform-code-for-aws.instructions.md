---
description: 'Guidelines for generating modern Terraform code for AWS'
applyTo: '**/*.tf'
---

## 1. Use Latest Terraform and Providers
Always target the latest stable Terraform version and AWS providers. In code, specify the required Terraform and provider versions to enforce this. Keep provider versions updated to get new features and fixes.

```hcl
terraform {
  required_version = ">= 1.7.5, < 1.9.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

## 2. Organize Code Cleanly
Structure Terraform configurations with logical file separation:

- Use `main.tf` for resources
- Use `variables.tf` for inputs
- Use `outputs.tf` for outputs
- Follow consistent naming conventions and formatting (`terraform fmt`)

This makes the code easy to navigate and maintain.

## 3. Encapsulate in Modules

Use Terraform modules to group reusable infrastructure components. For any resource set that will be used in multiple contexts:

- Create a module with its own variables/outputs
- Reference it rather than duplicating code
- This promotes reuse and consistency

## 4. Leverage Variables and Outputs

- **Parameterize** all configurable values using variables with types and descriptions
- **Provide default values** where appropriate for optional variables
- **Use outputs** to expose key resource attributes for other modules or user reference
- **Mark sensitive values** accordingly to protect secrets

## 5. Provider Selection and AWS Services

- **Use `aws` provider** for all AWS resources – it offers comprehensive coverage of AWS services including:
  - **Compute**: EC2 instances, EKS clusters, Auto Scaling Groups
  - **Storage**: S3 buckets, EBS volumes, EFS file systems
  - **Networking**: VPC, subnets, security groups, ALB/NLB, Route 53
  - **IAM**: Roles, policies, instance profiles for secure access
  - **Database**: RDS, DynamoDB, DocumentDB (though EC2-hosted MongoDB is used in this project)
- **Leverage AWS-specific features**:
  - Application Load Balancers for public web access
  - Security Groups for network-level security
  - IAM roles for EC2 instances (like AdminAccess for MongoDB VM)
  - S3 bucket policies for public read access to backups
- **Follow AWS naming conventions** and use appropriate resource types for the three-tier architecture

## 6. Minimal Dependencies

- **Do not introduce** additional providers or modules beyond the project's scope without confirmation
- If a special provider (e.g., `random`, `tls`) or external module is needed:
  - Add a comment to explain
  - Ensure the user approves it
- Keep the infrastructure stack lean and avoid unnecessary complexity

## 7. Ensure Idempotency

- Write configurations that can be applied repeatedly with the same outcome
- **Avoid non-idempotent actions**:
  - Scripts that run on every apply
  - Resources that might conflict if created twice
- **Test by doing multiple `terraform apply` runs** and ensure the second run results in zero changes
- Use resource lifecycle settings or conditional expressions to handle drift or external changes gracefully

## 8. State Management

- **Use a remote backend** (like AWS S3 with DynamoDB state locking) to store Terraform state securely
- Enable team collaboration and prevent concurrent modifications
- **Never commit state files** to source control
- **Example backend configuration**:
```hcl
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "tasky/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```
- This prevents conflicts and keeps the infrastructure state consistent

## 9. Document and Diagram

- **Maintain up-to-date documentation**
- **Update README.md** with any new variables, outputs, or usage instructions whenever the code changes
- Consider using tools like `terraform-docs` for automation
- **Update architecture diagrams** to reflect infrastructure changes after each significant update
- Well-documented code and diagrams ensure the whole team understands the infrastructure

## 10. Validate and Test Changes

- **Run `terraform validate`** and review the `terraform plan` output before applying changes
- Catch errors or unintended modifications early
- **Consider implementing automated checks**:
  - CI pipeline
  - Pre-commit hooks
  - Enforce formatting, linting, and basic validation

## 12. Resource Management and Destruction Best Practices

### Ensuring Proper Terraform Apply/Destroy Cycles
- **Principle:** All resources created by Terraform must be properly tagged, tracked, and destroyable without orphaning resources.

- **Comprehensive Resource Tagging:** Every single resource (VPC, subnets, gateways, logs, security groups, etc.) must include standardized tags
```hcl
# Define common tags at the root level
locals {
  common_tags = {
    Project     = "tasky-pivot-for-insight"
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = "insight-technical-exercise"
    CreatedBy   = "terraform"
    Repository  = "tasky-pivot-for-insight"
  }
}

# Apply to ALL resources without exception
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-igw"
    Type = "internet-gateway"
  })
}
```

- **Explicit Resource Dependencies:** Use `depends_on` to control destruction order and prevent orphaned resources
```hcl
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  # Ensure internet gateway exists before creating routes
  depends_on = [aws_internet_gateway.main]
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-rt"
  })
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  
  # Ensure proper destruction order
  depends_on = [aws_internet_gateway.main, aws_route_table.public]
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
    Type = "public"
    AZ   = data.aws_availability_zones.available.names[count.index]
  })
}
```

- **Log Group Management:** CloudWatch log groups are commonly orphaned - ensure they're tracked
```hcl
resource "aws_cloudwatch_log_group" "mongodb_backup" {
  name              = "/aws/ec2/${var.project_name}/mongodb-backup"
  retention_in_days = 14
  
  tags = merge(local.common_tags, {
    Name        = "${var.project_name}-mongodb-backup-logs"
    Component   = "mongodb"
    LogType     = "backup"
  })
}

resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 7
  
  tags = merge(local.common_tags, {
    Name        = "${var.project_name}-eks-cluster-logs"
    Component   = "eks"
    LogType     = "cluster"
  })
}
```

- **Module Tag Consistency:** Ensure all modules propagate tags correctly
```hcl
# In module call
module "vpc" {
  source = "./modules/vpc"
  
  project_name = var.project_name
  environment  = var.environment
  
  # Always pass common tags to modules
  tags = local.common_tags
}

# In module variables.tf
variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# In module main.tf - apply to every resource
resource "aws_vpc" "main" {
  # ... configuration ...
  tags = merge(var.tags, {
    Name = "${var.project_name}-vpc"
  })
}
```

- **Destruction Testing and Validation:**
```bash
# Before destroying, verify all resources have proper tags
aws resourcegroupstaggingapi get-resources \
  --tag-filters "Key=Project,Values=tasky-pivot-for-insight" \
  --region us-east-1

# After destroy, check for orphaned resources
aws resourcegroupstaggingapi get-resources \
  --tag-filters "Key=ManagedBy,Values=terraform" \
  --region us-east-1

# Manual cleanup command for any orphaned resources
aws logs describe-log-groups --log-group-name-prefix "/aws/ec2/tasky"
```

### Troubleshooting Destruction Issues
- **Common Orphaned Resources:**
  - CloudWatch Log Groups (not automatically destroyed)
  - Security Group rules with circular dependencies
  - Route tables with active routes
  - Network interfaces still attached to instances
  
- **Prevention Strategies:**
  - Use `terraform plan -destroy` before actual destruction
  - Implement pre-destroy hooks for cleanup
  - Regular state validation with `terraform refresh`
  - Monitor AWS billing for unexpected resources

### AWS-Specific Best Practices

### Three-Tier Architecture Components
- **Web Tier**: Use EKS for containerized applications with Application Load Balancer for public access
- **Data Tier**: EC2 instances for MongoDB with proper security groups allowing port 27017
- **Storage Tier**: S3 buckets with appropriate bucket policies for backup storage

### Security and IAM
- **IAM Roles**: Use instance profiles for EC2 instances rather than access keys
- **Least Privilege**: Start with minimal permissions and add as needed
- **Security Groups**: Act as virtual firewalls - be specific about ports and sources
- **VPC Design**: Use public/private subnet architecture with proper routing

### AWS Service Integration
- **EKS Integration**: Configure proper RBAC with cluster-admin permissions where required
- **S3 Bucket Policies**: Enable public read access for backup files when specified
- **CloudWatch**: Integrate logging and monitoring for backup scripts and application health
- **Route 53**: Use for DNS management if custom domains are required

### Resource Tagging and Lifecycle Management
- **Consistent Tagging Strategy**: Apply comprehensive tags to ALL resources for proper tracking and destruction
```hcl
locals {
  common_tags = {
    Project     = "tasky"
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = "insight-technical-exercise"
    CreatedBy   = "terraform"
    Timestamp   = timestamp()
  }
}

# Apply to every resource
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-vpc"
  })
}
```

- **Explicit Dependencies**: Use `depends_on` to ensure correct resource destruction order
```hcl
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  
  depends_on = [aws_internet_gateway.main]
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
    Type = "public"
  })
}
```

- **Resource Lifecycle Controls**: Prevent accidental destruction and ensure proper cleanup
```hcl
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.log_retention_days
  
  lifecycle {
    prevent_destroy = false
    create_before_destroy = true
  }
  
  tags = local.common_tags
}
```

- **Module Tag Propagation**: Ensure all modules accept and apply tags consistently
```hcl
# In module variables.tf
variable "tags" {
  description = "A map of tags to assign to the resource"
  type        = map(string)
  default     = {}
}

# In module resources
resource "aws_instance" "mongodb" {
  # ... other configuration ...
  tags = merge(var.tags, {
    Name = "${var.project_name}-mongodb"
    Role = "database"
  })
}
```

### Legacy System Requirements
- **Amazon Linux 2**: Use specific AMI for MongoDB EC2 instances as required
- **MongoDB 4.0.x**: Install legacy version via user data scripts
- **Public S3 Access**: Configure bucket policies for publicly accessible backup URLs
