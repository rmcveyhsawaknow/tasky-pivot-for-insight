# ==============================================================================
# TASKY APPLICATION INFRASTRUCTURE
# ==============================================================================
# Three-tier architecture deployment for Insight Technical Exercise
# - Web Tier: Amazon EKS cluster with containerized application
# - Data Tier: MongoDB on EC2 instance with authentication
# - Storage Tier: S3 bucket for automated backups
# ==============================================================================

# Local values for consistent tagging and naming
locals {
  # Consistent naming pattern: project-environment-stackversion
  name_prefix = "${var.project_name}-${var.environment}-${var.stack_version}"

  common_tags = {
    Project      = "tasky"
    Environment  = var.environment
    StackVersion = var.stack_version
    ManagedBy    = "terraform"
    Owner        = "insight-technical-exercise"
    CreatedDate  = formatdate("YYYY-MM-DD", timestamp())
  }
}

# Data sources
data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

# VPC Module - Network Infrastructure
# Provides secure network foundation with public/private subnets
module "vpc" {
  source = "./modules/vpc"

  project_name       = var.project_name
  environment        = var.environment
  stack_version      = var.stack_version
  vpc_cidr           = var.vpc_cidr
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = local.common_tags
}

# S3 Backup Module - Storage Tier
# Provides automated backup storage with public read access
module "s3_backup" {
  source = "./modules/s3-backup"

  project_name  = var.project_name
  environment   = var.environment
  stack_version = var.stack_version

  tags = local.common_tags
}

# MongoDB EC2 Module - Data Tier
# Provides MongoDB database server with authentication
module "mongodb_ec2" {
  source = "./modules/mongodb-ec2"

  project_name          = var.project_name
  environment           = var.environment
  stack_version         = var.stack_version
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  instance_type         = var.mongodb_instance_type
  mongodb_username      = var.mongodb_username
  mongodb_password      = var.mongodb_password
  mongodb_database_name = var.mongodb_database_name
  backup_bucket_name    = module.s3_backup.bucket_name

  tags = local.common_tags
}

# EKS Module - Web Tier
# Provides containerized application hosting with auto-scaling
module "eks" {
  source = "./modules/eks"

  project_name              = var.project_name
  environment               = var.environment
  stack_version             = var.stack_version
  vpc_id                    = module.vpc.vpc_id
  private_subnet_ids        = module.vpc.private_subnet_ids
  public_subnet_ids         = module.vpc.public_subnet_ids
  node_instance_types       = var.eks_node_instance_types
  node_desired_size         = var.eks_node_desired_size
  node_max_size             = var.eks_node_max_size
  node_min_size             = var.eks_node_min_size
  mongodb_security_group_id = module.mongodb_ec2.security_group_id

  tags = local.common_tags
}

# ALB Module - Application Load Balancer
# Provides cost-effective cloud-native load balancer for web applications
module "alb" {
  source = "./modules/alb"

  project_name           = var.project_name
  environment            = var.environment
  stack_version          = var.stack_version
  vpc_id                 = module.vpc.vpc_id
  public_subnet_ids      = module.vpc.public_subnet_ids
  eks_security_group_ids = [module.eks.node_group_security_group_id, module.eks.cluster_security_group_id]
  health_check_path      = var.alb_health_check_path
  ssl_certificate_arn    = var.alb_ssl_certificate_arn
  enable_access_logs     = var.alb_enable_access_logs
  access_logs_bucket     = var.alb_enable_access_logs ? module.s3_backup.bucket_name : null
  create_dns_record      = var.alb_create_dns_record
  domain_name            = var.alb_domain_name
  hosted_zone_id         = var.alb_hosted_zone_id

  tags = local.common_tags
}
