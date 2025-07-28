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
