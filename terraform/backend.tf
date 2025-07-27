# ==============================================================================
# TERRAFORM BACKEND CONFIGURATION
# ==============================================================================
# This file supports both local and remote backend configurations:
# - LOCAL DEVELOPMENT: Uses local state (default when no backend config provided)
# - CI/CD DEPLOYMENT: Uses S3 remote backend (configured via backend-config)
# ==============================================================================

terraform {
  # Backend configuration is intentionally left empty for flexibility
  # This allows the same code to work with both local and remote backends

  # Local development: Uses local terraform.tfstate (default behavior)
  # CI/CD deployment: Uses S3 backend via -backend-config flag

  # The backend configuration is provided at runtime via:
  # terraform init -backend-config=backend-prod.hcl (for CI/CD)
  # terraform init (for local development)
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
