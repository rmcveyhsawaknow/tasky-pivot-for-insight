locals {
  common_tags = {
    Project     = "tasky"
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = "insight-technical-exercise"
  }
}

# Data sources
data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr          = var.vpc_cidr
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 3)
  
  tags = local.common_tags
}

# S3 Backup Module
module "s3_backup" {
  source = "./modules/s3-backup"

  project_name = var.project_name
  environment  = var.environment
  
  tags = local.common_tags
}

# MongoDB EC2 Module
module "mongodb_ec2" {
  source = "./modules/mongodb-ec2"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id            = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  instance_type     = var.mongodb_instance_type
  mongodb_username  = var.mongodb_username
  mongodb_password  = var.mongodb_password
  backup_bucket_name = module.s3_backup.bucket_name
  
  tags = local.common_tags
}

# EKS Module
module "eks" {
  source = "./modules/eks"

  project_name            = var.project_name
  environment             = var.environment
  vpc_id                 = module.vpc.vpc_id
  private_subnet_ids     = module.vpc.private_subnet_ids
  public_subnet_ids      = module.vpc.public_subnet_ids
  node_instance_types    = var.eks_node_instance_types
  node_desired_size      = var.eks_node_desired_size
  node_max_size          = var.eks_node_max_size
  node_min_size          = var.eks_node_min_size
  mongodb_security_group_id = module.mongodb_ec2.security_group_id
  
  tags = local.common_tags
}
