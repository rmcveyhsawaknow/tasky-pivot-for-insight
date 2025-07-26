variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "stack_version" {
  description = "Stack version identifier for unique resource naming"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs"
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "mongodb_username" {
  description = "MongoDB username"
  type        = string
}

variable "mongodb_password" {
  description = "MongoDB password"
  type        = string
  sensitive   = true
}

variable "mongodb_database_name" {
  description = "MongoDB database name"
  type        = string
  default     = "go-mongodb"
}

variable "backup_bucket_name" {
  description = "S3 backup bucket name"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
