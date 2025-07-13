# Backend Configuration Example
# Uncomment and configure the following to use remote state storage
# 
# terraform {
#   backend "s3" {
#     bucket         = "your-terraform-state-bucket"
#     key            = "tasky/terraform.tfstate"
#     region         = "us-west-2"
#     dynamodb_table = "terraform-state-lock"
#     encrypt        = true
#   }
# }
#
# To enable remote state:
# 1. Create an S3 bucket for state storage
# 2. Create a DynamoDB table for state locking
# 3. Uncomment the backend configuration above
# 4. Run: terraform init -reconfigure
