# ==============================================================================
# INFRASTRUCTURE OUTPUTS
# ==============================================================================
# Key information needed for application deployment and management

# Network Infrastructure
output "vpc_id" {
  description = "ID of the VPC hosting the three-tier architecture"
  value       = module.vpc.vpc_id
}

output "aws_region" {
  description = "AWS region where resources are deployed"
  value       = var.aws_region
}

# EKS Cluster Information
output "eks_cluster_name" {
  description = "Name of the EKS cluster for containerized applications"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "API server endpoint for the EKS cluster"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "eks_node_group_security_group_id" {
  description = "Security group ID for EKS node group"
  value       = module.eks.node_group_security_group_id
}

output "eks_aws_load_balancer_controller_role_arn" {
  description = "ARN of the AWS Load Balancer Controller IAM role"
  value       = module.eks.aws_load_balancer_controller_role_arn
}

# MongoDB Database Information
output "mongodb_private_ip" {
  description = "Private IP address of the MongoDB EC2 instance"
  value       = module.mongodb_ec2.private_ip
}

output "mongodb_instance_id" {
  description = "EC2 instance ID for the MongoDB server"
  value       = module.mongodb_ec2.instance_id
}

output "mongodb_connection_string" {
  description = "MongoDB connection string for application configuration"
  value       = module.mongodb_ec2.mongodb_connection_uri
  sensitive   = true
}

output "mongodb_security_group_id" {
  description = "Security group ID for the MongoDB instance"
  value       = module.mongodb_ec2.security_group_id
}

output "mongodb_cloudwatch_logs" {
  description = "CloudWatch log group for MongoDB monitoring"
  value       = module.mongodb_ec2.cloudwatch_log_group_name
}

output "mongodb_troubleshooting" {
  description = "Commands for troubleshooting MongoDB instance"
  value       = module.mongodb_ec2.troubleshooting_commands
}

output "mongodb_username" {
  description = "MongoDB username for application connections"
  value       = var.mongodb_username
  sensitive   = true
}

output "mongodb_password" {
  description = "MongoDB password for application connections"
  value       = var.mongodb_password
  sensitive   = true
}

output "mongodb_database_name" {
  description = "MongoDB database name used by the application"
  value       = var.mongodb_database_name
}

output "jwt_secret" {
  description = "JWT secret key for application authentication"
  value       = var.jwt_secret
  sensitive   = true
}

# S3 Backup Storage
output "s3_backup_bucket_name" {
  description = "Name of the S3 bucket for MongoDB backups"
  value       = module.s3_backup.bucket_name
}

output "s3_backup_public_url" {
  description = "Public URL for accessing MongoDB backups"
  value       = module.s3_backup.public_url
}

# ==============================================================================
# APPLICATION LOAD BALANCER OUTPUTS
# ==============================================================================

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "alb_hosted_zone_id" {
  description = "Hosted zone ID of the Application Load Balancer"
  value       = module.alb.alb_hosted_zone_id
}

output "alb_target_group_arn" {
  description = "ARN of the ALB target group"
  value       = module.alb.target_group_arn
}

output "application_url" {
  description = "Application URL via Application Load Balancer"
  value       = module.alb.application_url
}

output "custom_domain_url" {
  description = "Custom domain URL if configured"
  value       = module.alb.custom_domain_url
}

# Deployment Commands and Information
output "kubectl_config_command" {
  description = "Command to configure kubectl for EKS cluster access"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

# # Deployment Instructions
# output "deployment_instructions" {
#   description = "Step-by-step deployment instructions"
#   value       = <<-EOT
#     Tasky Application Deployment Instructions:
#     ==========================================

#     1. Configure kubectl access:
#        ${output.kubectl_config_command.value}

#     2. Verify cluster connectivity:
#        kubectl get nodes

#     3. Deploy the application:
#        kubectl apply -f ../k8s/

#     4. Monitor deployment:
#        kubectl get pods -n tasky --watch

#     5. Get load balancer URL:
#        kubectl get svc -n tasky

#     6. Access application:
#        ${output.application_url.value}

#     7. Verify MongoDB backup:
#        ${output.s3_backup_public_url.value}
#   EOT
# }
