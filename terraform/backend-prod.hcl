# ==============================================================================
# PRODUCTION BACKEND CONFIGURATION
# ==============================================================================
# This file configures the S3 remote backend for CI/CD deployments
# Used with: terraform init -backend-config=backend-prod.hcl
# ==============================================================================

# S3 bucket for state storage
bucket = "tasky-terraform-state-152451250193"

# State file path within bucket
key = "tasky/terraform.tfstate"

# AWS region
region = "us-east-1"

# DynamoDB table for state locking
dynamodb_table = "terraform-state-lock"

# Encryption at rest
encrypt = true

# Note: S3 bucket versioning is enabled on the bucket itself, not here
# The versioning argument is not valid in Terraform backend configuration
