variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-2"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "AWS region must be in the format xx-xxxx-x (e.g., us-east-2)."
  }
}

variable "environment" {
  description = "Environment name (dev, stg, prd)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "stg", "prd"], var.environment)
    error_message = "Environment must be one of: dev, stg, prd."
  }
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "tasky"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}[a-z0-9]$", var.project_name))
    error_message = "Project name must be 3-32 characters, start with a letter, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "stack_version" {
  description = "Stack version identifier to avoid duplicate service names in the same AWS account"
  type        = string
  default     = "v1"

  validation {
    condition     = can(regex("^v[0-9]+$", var.stack_version)) && length(var.stack_version) <= 4
    error_message = "Stack version must be in format v1, v2, v3, etc. (max 4 characters)."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-2a", "us-east-2b", "us-east-2c"]
}

variable "mongodb_instance_type" {
  description = "EC2 instance type for MongoDB"
  type        = string
  default     = "t3.medium"
}

variable "mongodb_username" {
  description = "MongoDB username"
  type        = string
  default     = "taskyadmin"
}

variable "mongodb_password" {
  description = "MongoDB password"
  type        = string
  sensitive   = true
  default     = "TaskySecure123!"
}

variable "mongodb_database_name" {
  description = "Name of the MongoDB database to create"
  type        = string
  default     = "go-mongodb"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_-]*$", var.mongodb_database_name))
    error_message = "Database name must start with a letter and contain only letters, numbers, underscores, and hyphens."
  }
}

variable "jwt_secret" {
  description = "JWT secret key"
  type        = string
  sensitive   = true
  default     = "tasky-jwt-secret-key-for-insight-exercise"
}

variable "eks_node_instance_types" {
  description = "List of EC2 instance types for EKS worker nodes"
  type        = list(string)
  default     = ["t3.medium"]

  validation {
    condition     = length(var.eks_node_instance_types) > 0 && length(var.eks_node_instance_types) <= 5
    error_message = "Must specify 1-5 instance types for EKS nodes."
  }
}

variable "eks_node_desired_size" {
  description = "Desired number of EKS worker nodes"
  type        = number
  default     = 2

  validation {
    condition     = var.eks_node_desired_size >= 1 && var.eks_node_desired_size <= 10
    error_message = "Desired size must be between 1 and 10 nodes."
  }
}

variable "eks_node_max_size" {
  description = "Maximum number of EKS worker nodes"
  type        = number
  default     = 3

  validation {
    condition     = var.eks_node_max_size >= 1 && var.eks_node_max_size <= 20
    error_message = "Maximum size must be between 1 and 20 nodes."
  }
}

variable "eks_node_min_size" {
  description = "Minimum number of EKS worker nodes"
  type        = number
  default     = 1

  validation {
    condition     = var.eks_node_min_size >= 0 && var.eks_node_min_size <= 10
    error_message = "Minimum size must be between 0 and 10 nodes."
  }
}
