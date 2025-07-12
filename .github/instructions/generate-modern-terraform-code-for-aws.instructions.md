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
    region         = "us-west-2"
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

## 11. AWS-Specific Best Practices

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

### Resource Tagging
```hcl
locals {
  common_tags = {
    Project     = "tasky"
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = "insight-technical-exercise"
  }
}
```

### Legacy System Requirements
- **Amazon Linux 2**: Use specific AMI for MongoDB EC2 instances as required
- **MongoDB 4.0.x**: Install legacy version via user data scripts
- **Public S3 Access**: Configure bucket policies for publicly accessible backup URLs
