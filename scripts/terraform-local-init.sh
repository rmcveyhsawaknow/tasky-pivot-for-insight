#!/bin/bash

# ==============================================================================
# LOCAL TERRAFORM INITIALIZATION SCRIPT
# ==============================================================================
# This script initializes Terraform for local development
# Uses local state storage (no S3 backend)
# ==============================================================================

set -e

echo "🚀 Initializing Terraform for Local Development..."
echo ""

cd "$(dirname "$0")/../terraform" || exit 1

# Check if we're in the terraform directory
if [ ! -f "main.tf" ]; then
    echo "❌ Error: main.tf not found. Make sure you're in the terraform directory."
    exit 1
fi

echo "📁 Current directory: $(pwd)"
echo ""

# Format Terraform files
echo "🎨 Formatting Terraform files..."
terraform fmt

# Initialize Terraform (local backend)
echo "⚙️ Initializing Terraform with local backend..."
terraform init

echo ""
echo "✅ Terraform initialized successfully for local development!"
echo ""
echo "📝 Next steps:"
echo "   1. terraform validate  # Validate configuration"
echo "   2. terraform plan      # See what will be created"
echo "   3. terraform apply     # Deploy infrastructure"
echo ""
echo "💡 Note: This uses local state storage. For CI/CD deployments,"
echo "   GitHub Actions will use the S3 remote backend automatically."
