# ==============================================================================
# INFRASTRUCTURE OUTPUTS
# ==============================================================================
# Key information needed for application deployment and management

# Network Infrastructure
output "vpc_id" {
  description = "ID of the VPC hosting the three-tier architecture"
  value       = module.vpc.vpc_id
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

# MongoDB Database Information
output "mongodb_private_ip" {
  description = "Private IP address of the MongoDB EC2 instance"
  value       = module.mongodb_ec2.private_ip
}

output "mongodb_connection_string" {
  description = "MongoDB connection string for application configuration"
  value       = "mongodb://${var.mongodb_username}:${var.mongodb_password}@${module.mongodb_ec2.private_ip}:27017/tasky"
  sensitive   = true
}

output "mongodb_security_group_id" {
  description = "Security group ID for the MongoDB instance"
  value       = module.mongodb_ec2.security_group_id
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

# Deployment Commands and Information
output "kubectl_config_command" {
  description = "Command to configure kubectl for EKS cluster access"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "application_url" {
  description = "Application URL after load balancer deployment"
  value       = "http://${module.eks.load_balancer_hostname}"
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
