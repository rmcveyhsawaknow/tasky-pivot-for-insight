#!/bin/bash

# ==============================================================================
# RESTORE S3 BACKEND CONFIGURATION SCRIPT
# ==============================================================================
# This script restores the S3 backend configuration for CI/CD deployments
# 
# Usage:
#   Interactive: ./terraform-restore-s3-backend.sh
#   Non-interactive: echo "y" | ./terraform-restore-s3-backend.sh
# ==============================================================================

set -e

echo "🔄 Restoring S3 Backend Configuration..."
echo ""

cd "$(dirname "$0")/../terraform" || exit 1

# Check if backup exists
if [ ! -f "backend.tf.s3backup" ]; then
    echo "❌ Error: backend.tf.s3backup not found. Cannot restore S3 backend."
    echo "💡 This means the S3 backend was never backed up during local init."
    echo "📁 Current directory: $(pwd)"
    echo "📄 Available files:"
    ls -la backend.tf* 2>/dev/null || echo "   No backend.tf files found"
    exit 1
fi

# Restore the S3 backend configuration
echo "📁 Current directory: $(pwd)"
echo "🔄 Restoring backend.tf from backup..."
cp backend.tf.s3backup backend.tf

# Clean up any existing local state (user confirmation required)
if [ -f "terraform.tfstate" ]; then
    echo ""
    echo "⚠️  Local terraform.tfstate file detected!"
    echo "📄 File: $(pwd)/terraform.tfstate"
    echo ""
    read -p "❓ Do you want to remove the local state file? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🗑️  Removing local state file..."
        rm terraform.tfstate
        if [ -f "terraform.tfstate.backup" ]; then
            rm terraform.tfstate.backup
        fi
        echo "✅ Local state files removed."
    else
        echo "⚠️  Local state file preserved. You may need to migrate state manually."
    fi
fi

# Remove .terraform directory to force re-initialization
if [ -d ".terraform" ]; then
    echo "🧹 Cleaning up local Terraform initialization..."
    rm -rf .terraform
fi

echo ""
echo "✅ S3 backend configuration restored!"
echo "💾 Backup file preserved at: backend.tf.s3backup"
echo ""
echo "📝 Next steps for CI/CD deployment:"
echo "   1. terraform init -backend-config=backend-prod.hcl"
echo "   2. terraform plan"
echo "   3. terraform apply"
echo ""
echo "🔄 To switch back to local development:"
echo "   ./scripts/terraform-local-init.sh"
echo ""
echo "💡 Note: You'll need valid AWS credentials and the S3 bucket must exist."
