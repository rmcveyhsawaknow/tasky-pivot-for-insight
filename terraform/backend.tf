# ==============================================================================
# TERRAFORM BACKEND CONFIGURATION
# ==============================================================================
# This file configures remote state storage for Terraform
# Update the bucket name after running setup-aws-oidc.sh
# ==============================================================================

terraform {
  # Remote backend for state storage and locking
  backend "s3" {
    # Replace ACCOUNT_ID with your AWS account ID after running setup-aws-oidc.sh
    bucket         = "tasky-terraform-state-ACCOUNT_ID"
    key            = "tasky/terraform.tfstate"
    region         = "us-east-1"
    
    # State locking and consistency
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
    
    # Versioning for state history
    versioning = true
  }
}

# Note: To use this backend:
# 1. Run scripts/setup-aws-oidc.sh to create the S3 bucket and DynamoDB table
# 2. Replace ACCOUNT_ID in the bucket name with your actual AWS account ID
# 3. Run terraform init to migrate your state to the remote backend
