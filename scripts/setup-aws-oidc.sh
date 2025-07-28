#!/bin/bash

# ==============================================================================
# AWS OIDC SETUP SCRIPT FOR GITHUB ACTIONS
# ==============================================================================
# This script sets up AWS OIDC integration for secure GitHub Actions access
# Run this once per AWS account to enable credential-less authentication
# ==============================================================================

set -e

# Disable AWS CLI pager to prevent script interruptions
export AWS_PAGER=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration variables
GITHUB_REPO="${GITHUB_REPO:-rmcveyhsawaknow/tasky-pivot-for-insight}"
ROLE_NAME="${ROLE_NAME:-GitHubActionsTerraformRole}"
AWS_ACCOUNT_ID=""

# Show usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --repo REPO      GitHub repository (default: rmcveyhsawaknow/tasky-pivot-for-insight)"
    echo "  --role ROLE      IAM role name (default: GitHubActionsTerraformRole)"
    echo "  --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Use defaults"
    echo "  $0 --repo myorg/myrepo               # Custom repository"
    echo "  $0 --role MyCustomRole               # Custom role name"
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --repo)
            GITHUB_REPO="$2"
            shift 2
            ;;
        --role)
            ROLE_NAME="$2"
            shift 2
            ;;
        --help)
            usage
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed or not in PATH"
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS CLI is not configured or lacks permissions"
        exit 1
    fi
    
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    print_success "AWS CLI configured for account: $AWS_ACCOUNT_ID"
}

# Create or update OIDC provider
setup_oidc_provider() {
    print_status "Setting up GitHub OIDC provider..."
    
    local provider_arn="arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
    
    if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$provider_arn" &> /dev/null; then
        print_success "GitHub OIDC provider already exists"
    else
        print_status "Creating GitHub OIDC provider..."
        aws iam create-open-id-connect-provider \
            --url https://token.actions.githubusercontent.com \
            --client-id-list sts.amazonaws.com \
            --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
            --tags Key=Purpose,Value=GitHubActions Key=Repository,Value="$GITHUB_REPO"
        print_success "GitHub OIDC provider created successfully"
    fi
}

# Create IAM role for GitHub Actions
create_github_role() {
    print_status "Creating IAM role for GitHub Actions..."
    
    # Create trust policy document
    cat > /tmp/github-trust-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
                },
                "StringLike": {
                    "token.actions.githubusercontent.com:sub": [
                        "repo:${GITHUB_REPO}:ref:refs/heads/deploy/*",
                        "repo:${GITHUB_REPO}:ref:refs/heads/main",
                        "repo:${GITHUB_REPO}:pull_request"
                    ]
                }
            }
        }
    ]
}
EOF

    # Create the role
    if aws iam get-role --role-name "$ROLE_NAME" &> /dev/null; then
        print_warning "Role $ROLE_NAME already exists, updating trust policy..."
        aws iam update-assume-role-policy \
            --role-name "$ROLE_NAME" \
            --policy-document file:///tmp/github-trust-policy.json
    else
        print_status "Creating new role: $ROLE_NAME"
        aws iam create-role \
            --role-name "$ROLE_NAME" \
            --assume-role-policy-document file:///tmp/github-trust-policy.json \
            --description "Role for GitHub Actions Terraform operations" \
            --tags Key=Purpose,Value=GitHubActions Key=Repository,Value="$GITHUB_REPO"
    fi
    
    print_success "IAM role created/updated successfully"
    rm -f /tmp/github-trust-policy.json
}

# Attach policies to the role
attach_policies() {
    print_status "Attaching policies to IAM role..."
    
    # For development/testing, using AdministratorAccess
    # In production, consider creating a more restrictive policy
    aws iam attach-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
    
    print_success "Policies attached successfully"
    print_warning "Note: AdministratorAccess is used for development. Consider creating a more restrictive policy for production."
}

# Create Terraform backend resources
setup_terraform_backend() {
    print_status "Setting up Terraform backend resources..."
    
    local bucket_name="tasky-terraform-state-${AWS_ACCOUNT_ID}"
    local table_name="terraform-state-lock"
    
    # Create S3 bucket for Terraform state
    if aws s3 ls "s3://$bucket_name" &> /dev/null; then
        print_success "S3 bucket $bucket_name already exists"
    else
        print_status "Creating S3 bucket for Terraform state..."
        aws s3 mb "s3://$bucket_name" --region us-east-1
        
        # Enable versioning
        aws s3api put-bucket-versioning \
            --bucket "$bucket_name" \
            --versioning-configuration Status=Enabled
        
        # Enable server-side encryption
        aws s3api put-bucket-encryption \
            --bucket "$bucket_name" \
            --server-side-encryption-configuration '{
                "Rules": [
                    {
                        "ApplyServerSideEncryptionByDefault": {
                            "SSEAlgorithm": "AES256"
                        }
                    }
                ]
            }'
        
        print_success "S3 bucket created with versioning and encryption enabled"
    fi
    
    # Create DynamoDB table for state locking
    if aws dynamodb describe-table --table-name "$table_name" &> /dev/null; then
        print_success "DynamoDB table $table_name already exists"
    else
        print_status "Creating DynamoDB table for state locking..."
        aws dynamodb create-table \
            --table-name "$table_name" \
            --attribute-definitions AttributeName=LockID,AttributeType=S \
            --key-schema AttributeName=LockID,KeyType=HASH \
            --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1 \
            --tags Key=Purpose,Value=TerraformStateLock Key=Repository,Value="$GITHUB_REPO"
        
        print_status "Waiting for DynamoDB table to be active..."
        aws dynamodb wait table-exists --table-name "$table_name"
        print_success "DynamoDB table created successfully"
    fi
    
    echo ""
    print_success "Terraform backend resources ready:"
    echo "  - S3 Bucket: $bucket_name"
    echo "  - DynamoDB Table: $table_name"
}

# Output configuration for GitHub
output_github_configuration() {
    local role_arn="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}"
    local bucket_name="tasky-terraform-state-${AWS_ACCOUNT_ID}"
    
    echo ""
    print_success "🎉 AWS OIDC setup complete!"
    echo ""
    print_status "=== GITHUB REPOSITORY CONFIGURATION ==="
    echo ""
    echo "Add these secrets to your GitHub repository:"
    echo "Settings > Secrets and variables > Actions > Repository secrets"
    echo ""
    echo "AWS_ROLE_ARN: $role_arn"
    echo ""
    echo "Add these variables to your GitHub repository:"
    echo "Settings > Secrets and variables > Actions > Variables"
    echo ""
    echo "AWS_REGION: us-east-1"
    echo "PROJECT_NAME: tasky"
    echo "ENVIRONMENT: dev"
    echo "STACK_VERSION: v12"
    echo "MONGODB_INSTANCE_TYPE: t3.micro"
    echo "VPC_CIDR: 10.0.0.0/16"
    echo "MONGODB_DATABASE_NAME: go-mongodb"
    echo ""
    echo "Add these additional secrets (generate secure values):"
    echo "MONGODB_USERNAME: taskyadmin"
    echo "MONGODB_PASSWORD: <generate-secure-password>"
    echo "JWT_SECRET: <generate-jwt-secret>"
    echo ""
    print_status "=== TERRAFORM BACKEND CONFIGURATION ==="
    echo ""
    echo "Update terraform/backend.tf with:"
    echo ""
    cat << EOF
terraform {
  backend "s3" {
    bucket         = "$bucket_name"
    key            = "tasky/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
EOF
    echo ""
    print_success "Setup complete! You can now use GitHub Actions for deployments."
}

# Main execution
main() {
    echo "🚀 AWS OIDC Setup for GitHub Actions"
    echo "Repository: $GITHUB_REPO"
    echo "Role Name: $ROLE_NAME"
    echo ""
    
    check_prerequisites
    setup_oidc_provider
    create_github_role
    attach_policies
    setup_terraform_backend
    output_github_configuration
}

# Run main function
main "$@"
