# GitHub Actions Environment Configuration
# This file documents the required GitHub repository settings for CI/CD

## Repository Secrets (Required)
The following secrets must be configured in your GitHub repository:
Settings > Secrets and variables > Actions > Repository secrets

| Secret Name | Description | Example |
|-------------|-------------|---------|
| AWS_ROLE_ARN | IAM role ARN for OIDC authentication | arn:aws:iam::123456789012:role/GitHubActionsTerraformRole |
| MONGODB_USERNAME | MongoDB admin username | taskyadmin |
| MONGODB_PASSWORD | MongoDB admin password | SecureRandomPassword123 |
| JWT_SECRET | JWT signing secret for authentication | RandomJWTSecret456 |

## Repository Variables (Required)
The following variables must be configured in your GitHub repository:
Settings > Secrets and variables > Actions > Variables

| Variable Name | Description | Default Value |
|---------------|-------------|---------------|
| AWS_REGION | AWS deployment region | us-east-1 |
| PROJECT_NAME | Project identifier | tasky |
| ENVIRONMENT | Environment name | dev |
| STACK_VERSION | Stack version identifier | v12 |
| MONGODB_INSTANCE_TYPE | EC2 instance type for MongoDB | t3.micro |
| VPC_CIDR | VPC CIDR block | 10.0.0.0/16 |
| MONGODB_DATABASE_NAME | MongoDB database name | go-mongodb |

## Setup Scripts

### Automated Setup
Run the setup script to configure everything automatically:
```bash
./scripts/setup-github-repo.sh
```

### Manual Setup
1. Configure AWS OIDC (one-time):
   ```bash
   ./scripts/setup-aws-oidc.sh
   ```

2. Manually add secrets and variables via GitHub web interface

## Workflow Triggers

### terraform-apply.yml
- **Trigger**: Push to `main`, `develop`, or `deploy/*` branches
- **Purpose**: Deploy infrastructure and application
- **Duration**: ~15-20 minutes
- **Outputs**: Application URL, backup URLs, cluster info

### terraform-plan.yml  
- **Trigger**: Pull requests to `main`
- **Purpose**: Validate changes and estimate costs
- **Duration**: ~5-10 minutes
- **Outputs**: Plan summary, cost estimation, security validation

## Environment Protection (Optional)
For production deployments, consider adding environment protection rules:

1. Go to Settings > Environments
2. Create "production" environment
3. Add protection rules:
   - Required reviewers
   - Wait timer
   - Deployment branches

## Branch Strategy
- `main`: Production deployments
- `develop`: Staging deployments  
- `deploy/*`: Feature/hotfix deployments
- Pull requests trigger validation only

## Monitoring & Debugging
- View workflow runs: `gh run list`
- Watch active run: `gh run watch` 
- View logs: `gh run view --log`
- Access artifacts from completed runs

## Security Notes
- All secrets are encrypted and only accessible to authorized workflows
- OIDC provides temporary credentials, no long-lived AWS keys
- Terraform state is stored securely in S3 with encryption and locking
- Container images are scanned for vulnerabilities
