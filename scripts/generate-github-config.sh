#!/bin/bash

# Generate GitHub Configuration Values
echo "🔧 GitHub Repository Configuration Values"
echo "=========================================="
echo ""

# AWS Account ID (from the previous setup)
AWS_ACCOUNT_ID="152451250193"
ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/GitHubActionsTerraformRole"

# Generate secure secrets
MONGODB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
JWT_SECRET=$(openssl rand -base64 64 | tr -d "=+/" | cut -c1-50)

echo "📋 Copy these values to your GitHub repository:"
echo ""
echo "🔗 Repository Secrets URL:"
echo "https://github.com/rmcveyhsawaknow/tasky-pivot-for-insight/settings/secrets/actions"
echo ""
echo "📝 Repository Secrets (click 'New repository secret' for each):"
echo ""
echo "Name: AWS_ROLE_ARN"
echo "Value: $ROLE_ARN"
echo ""
echo "Name: MONGODB_USERNAME" 
echo "Value: taskyadmin"
echo ""
echo "Name: MONGODB_PASSWORD"
echo "Value: $MONGODB_PASSWORD"
echo ""
echo "Name: JWT_SECRET"
echo "Value: $JWT_SECRET"
echo ""
echo "🔗 Repository Variables URL:"
echo "https://github.com/rmcveyhsawaknow/tasky-pivot-for-insight/settings/variables/actions"
echo ""
echo "📝 Repository Variables (click 'New repository variable' for each):"
echo ""
echo "Name: AWS_REGION, Value: us-east-1"
echo "Name: PROJECT_NAME, Value: tasky"
echo "Name: ENVIRONMENT, Value: dev"
echo "Name: STACK_VERSION, Value: v12"
echo "Name: MONGODB_INSTANCE_TYPE, Value: t3.micro"
echo "Name: VPC_CIDR, Value: 10.0.0.0/16"
echo "Name: MONGODB_DATABASE_NAME, Value: go-mongodb"
echo ""
echo "✅ After configuration, you can deploy by:"
echo "1. git checkout -b deploy/v12-quickstart"
echo "2. git add . && git commit -m 'feat: deploy via GitHub Actions'"
echo "3. git push origin deploy/v12-quickstart"
echo ""
echo "🎉 This will trigger the automated deployment!"
