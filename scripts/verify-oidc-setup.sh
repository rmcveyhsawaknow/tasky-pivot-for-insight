#!/bin/bash

# Simple verification script for OIDC setup
export AWS_PAGER=""

echo "🔍 Verifying AWS OIDC Setup..."
echo ""

# Get AWS Account ID
echo "Getting AWS Account ID..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo ""

# Check IAM Role
echo "Checking IAM Role..."
ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/GitHubActionsTerraformRole"
if aws iam get-role --role-name GitHubActionsTerraformRole --query 'Role.Arn' --output text >/dev/null 2>&1; then
    echo "✅ IAM Role exists: $ROLE_ARN"
else
    echo "❌ IAM Role does not exist"
fi
echo ""

# Check S3 Bucket
echo "Checking S3 Bucket..."
BUCKET_NAME="tasky-terraform-state-${AWS_ACCOUNT_ID}"
if aws s3 ls "s3://$BUCKET_NAME" >/dev/null 2>&1; then
    echo "✅ S3 Bucket exists: $BUCKET_NAME"
else
    echo "❌ S3 Bucket does not exist"
fi
echo ""

# Check DynamoDB Table
echo "Checking DynamoDB Table..."
if aws dynamodb describe-table --table-name terraform-state-lock --query 'Table.TableName' --output text >/dev/null 2>&1; then
    echo "✅ DynamoDB Table exists: terraform-state-lock"
else
    echo "❌ DynamoDB Table does not exist"
fi
echo ""

# Output GitHub Configuration
echo "📋 GitHub Repository Configuration Needed:"
echo ""
echo "=== REPOSITORY SECRETS ==="
echo "Navigate to: https://github.com/rmcveyhsawaknow/tasky-pivot-for-insight/settings/secrets/actions"
echo ""
echo "Add these secrets:"
echo "AWS_ROLE_ARN: $ROLE_ARN"
echo "MONGODB_PASSWORD: [generate-secure-password]"
echo "JWT_SECRET: [generate-jwt-secret]"
echo ""
echo "=== REPOSITORY VARIABLES ==="
echo "Navigate to: https://github.com/rmcveyhsawaknow/tasky-pivot-for-insight/settings/variables/actions"
echo ""
echo "Add these variables:"
echo "AWS_REGION: us-east-1"
echo "PROJECT_NAME: tasky"
echo "ENVIRONMENT: dev"
echo "STACK_VERSION: v12"
echo "MONGODB_INSTANCE_TYPE: t3.micro"
echo "VPC_CIDR: 10.0.0.0/16"
echo "MONGODB_DATABASE_NAME: go-mongodb"
echo "MONGODB_USERNAME: taskyadmin"
echo ""
echo "🎉 Setup verification complete!"
