# ==============================================================================
# ALB MODULE VARIABLES
# ==============================================================================

variable "project_name" {
  description = "Name of the project"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.project_name))
    error_message = "Project name must only contain alphanumeric characters and hyphens."
  }
}

variable "environment" {
  description = "Environment (e.g., dev, staging, production)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be one of: dev, staging, production."
  }
}

variable "stack_version" {
  description = "Stack version for resource naming"
  type        = string
  default     = "v1"
}

variable "vpc_id" {
  description = "VPC ID where ALB will be deployed"
  type        = string
  validation {
    condition     = can(regex("^vpc-", var.vpc_id))
    error_message = "VPC ID must be a valid AWS VPC identifier."
  }
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for ALB placement"
  type        = list(string)
  validation {
    condition     = length(var.public_subnet_ids) >= 2
    error_message = "At least 2 public subnets are required for ALB high availability."
  }
}

variable "eks_security_group_ids" {
  description = "List of EKS security group IDs to allow ALB access"
  type        = list(string)
  default     = []
}

variable "health_check_path" {
  description = "Health check path for target group"
  type        = string
  default     = "/"
  validation {
    condition     = can(regex("^/", var.health_check_path))
    error_message = "Health check path must start with '/'."
  }
}

variable "ssl_certificate_arn" {
  description = "SSL certificate ARN for HTTPS listener (optional)"
  type        = string
  default     = null
}

variable "enable_access_logs" {
  description = "Enable ALB access logs"
  type        = bool
  default     = false
}

variable "access_logs_bucket" {
  description = "S3 bucket for ALB access logs (required if enable_access_logs is true)"
  type        = string
  default     = null
}

variable "create_dns_record" {
  description = "Whether to create Route53 DNS record"
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "Domain name for Route53 record (e.g., ideatasky.ryanmcvey.me)"
  type        = string
  default     = null
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID for DNS record creation"
  type        = string
  default     = null
}

variable "tags" {
  description = "A map of tags to assign to the resource"
  type        = map(string)
  default     = {}
}
