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
