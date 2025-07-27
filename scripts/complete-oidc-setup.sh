#!/bin/bash

# Complete OIDC Setup Script - No Pager Version
export AWS_PAGER=""
export AWS_CLI_AUTO_PROMPT=off

set -e

echo "🚀 Completing AWS OIDC Setup for GitHub Actions"
echo ""

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: $AWS_ACCOUNT_ID"

GITHUB_REPO="rmcveyhsawaknow/tasky-pivot-for-insight"
ROLE_NAME="GitHubActionsTerraformRole"

echo "Repository: $GITHUB_REPO"
echo "Role Name: $ROLE_NAME"
echo ""

# Check and wait for DynamoDB table if it's still being created
echo "Checking DynamoDB table status..."
while true; do
    STATUS=$(aws dynamodb describe-table --table-name terraform-state-lock --query 'Table.TableStatus' --output text 2>/dev/null || echo "NOT_FOUND")
    if [ "$STATUS" = "ACTIVE" ]; then
        echo "✅ DynamoDB table is ACTIVE"
        break
    elif [ "$STATUS" = "CREATING" ]; then
        echo "⏳ DynamoDB table still creating, waiting 10 seconds..."
        sleep 10
    elif [ "$STATUS" = "NOT_FOUND" ]; then
        echo "❌ DynamoDB table not found, creating it..."
        aws dynamodb create-table \
            --table-name terraform-state-lock \
            --attribute-definitions AttributeName=LockID,AttributeType=S \
            --key-schema AttributeName=LockID,KeyType=HASH \
            --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1 \
            --tags Key=Purpose,Value=TerraformStateLock Key=Repository,Value="$GITHUB_REPO" >/dev/null
        echo "DynamoDB table creation initiated..."
        sleep 10
    else
        echo "❌ DynamoDB table in unexpected status: $STATUS"
        break
    fi
done

echo ""
echo "🎉 AWS OIDC setup complete!"
echo ""
echo "=== GITHUB REPOSITORY CONFIGURATION ==="
echo ""
echo "Step 1: Go to GitHub Repository Secrets"
echo "URL: https://github.com/rmcveyhsawaknow/tasky-pivot-for-insight/settings/secrets/actions"
echo ""
echo "Add these Repository Secrets (click 'New repository secret'):"
echo "AWS_ROLE_ARN: arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}"
echo "MONGODB_PASSWORD: [generate a secure password]"
echo "JWT_SECRET: [generate a secure JWT secret]"
echo ""
echo "Step 2: Go to GitHub Repository Variables"  
echo "URL: https://github.com/rmcveyhsawaknow/tasky-pivot-for-insight/settings/variables/actions"
echo ""
echo "Add these Repository Variables (click 'New repository variable'):"
echo "AWS_REGION: us-east-1"
echo "PROJECT_NAME: tasky"
echo "ENVIRONMENT: dev"
echo "STACK_VERSION: v12"
echo "MONGODB_INSTANCE_TYPE: t3.micro"
echo "VPC_CIDR: 10.0.0.0/16"
echo "MONGODB_DATABASE_NAME: go-mongodb"
echo "MONGODB_USERNAME: taskyadmin"
echo ""
echo "=== TERRAFORM BACKEND CONFIGURATION ==="
echo ""
echo "Update terraform/backend.tf with:"
echo ""
cat << EOF
terraform {
  backend "s3" {
    bucket         = "tasky-terraform-state-${AWS_ACCOUNT_ID}"
    key            = "tasky/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
EOF
echo ""
echo "✅ Setup complete! You can now use GitHub Actions for deployments."
