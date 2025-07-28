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

# Create backup of backend.tf for S3 configuration
if [ -f "backend.tf" ]; then
    # Check if this is already a local backend configuration
    if grep -q "No backend configuration = local state storage" backend.tf; then
        echo "💡 backend.tf already configured for local development"
        # Check if backup exists, if not, restore from original S3 config
        if [ ! -f "backend.tf.s3backup" ]; then
            echo "⚠️  No S3 backup found. Creating backup from original S3 configuration..."
            # Create the original S3 backend configuration
            cat > backend.tf.s3backup << 'EOF'
# ==============================================================================
# TERRAFORM BACKEND CONFIGURATION
# ==============================================================================
# This file supports both local and remote backend configurations:
# - LOCAL DEVELOPMENT: Uses local state (default when no backend config provided)
# - CI/CD DEPLOYMENT: Uses S3 remote backend (configured via backend-config)
# ==============================================================================

terraform {
  # Backend configuration for S3 remote state
  # Configuration details provided via backend-config file
  backend "s3" {
    # Configuration is provided at runtime via:
    # terraform init -backend-config=backend-prod.hcl (for CI/CD)
    # This enables the use of -backend-config parameter
  }
}

# ==========================================
# BACKEND CONFIGURATION FILES EXPLANATION
# ==========================================
# 
# For LOCAL development (this repository):
#   - No additional configuration needed
#   - Simply run: terraform init
#   - Uses local terraform.tfstate file
#   - Perfect for testing and development
#
# For CI/CD deployment (GitHub Actions):
#   - Uses backend-prod.hcl configuration file
#   - Run: terraform init -backend-config=backend-prod.hcl
#   - Enables team collaboration and state locking
#   - Required for production deployments
#
# This approach provides:
#   ✅ Simple local development
#   ✅ Robust CI/CD pipeline support  
#   ✅ No conditional logic needed
#   ✅ Clear separation of concerns
EOF
            echo "✅ S3 backup configuration created"
        fi
    else
        echo "💾 Backing up backend.tf to backend.tf.s3backup..."
        cp backend.tf backend.tf.s3backup
    fi
fi

# Create local backend configuration for development
echo "🏠 Creating local backend configuration..."
cat > backend.tf.local << 'EOF'
# ==============================================================================
# LOCAL DEVELOPMENT BACKEND CONFIGURATION
# ==============================================================================
# This configuration uses local state storage for development
# Original S3 backend config backed up as backend.tf.s3backup
# ==============================================================================

terraform {
  # No backend configuration = local state storage
  # terraform.tfstate file will be created in this directory
}
EOF

# Replace backend.tf temporarily with local configuration
mv backend.tf.local backend.tf

# Format Terraform files
echo "🎨 Formatting Terraform files..."
terraform fmt

# Initialize Terraform (local backend)
echo "⚙️ Initializing Terraform with local backend..."
terraform init

echo ""
echo "✅ Terraform initialized successfully for local development!"
echo "📁 State file will be stored locally as: terraform.tfstate"
echo ""
echo "📝 Next steps:"
echo "   1. terraform validate  # Validate configuration"
echo "   2. terraform plan      # See what will be created"
echo "   3. terraform apply     # Deploy infrastructure"
echo ""
echo "🔄 To restore S3 backend configuration:"
echo "   ./scripts/terraform-restore-s3-backend.sh"
echo ""
echo "💡 Note: This uses local state storage. For CI/CD deployments,"
echo "   GitHub Actions will use the S3 remote backend automatically."
