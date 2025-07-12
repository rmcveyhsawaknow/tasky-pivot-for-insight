output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "mongodb_private_ip" {
  description = "MongoDB EC2 instance private IP"
  value       = module.mongodb_ec2.private_ip
}

output "mongodb_connection_string" {
  description = "MongoDB connection string"
  value       = "mongodb://${var.mongodb_username}:${var.mongodb_password}@${module.mongodb_ec2.private_ip}:27017/tasky"
  sensitive   = true
}

output "s3_backup_bucket_name" {
  description = "S3 backup bucket name"
  value       = module.s3_backup.bucket_name
}

output "s3_backup_public_url" {
  description = "S3 backup bucket public URL"
  value       = module.s3_backup.public_url
}

output "kubectl_config_command" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "application_url" {
  description = "Application URL (after deployment)"
  value       = "http://${module.eks.load_balancer_hostname}"
}

output "next_steps" {
  description = "Next steps for deployment"
  value = <<-EOT
    1. Configure kubectl: ${output.kubectl_config_command.value}
    2. Deploy the application: kubectl apply -f ../k8s/
    3. Wait for Load Balancer: kubectl get svc -n tasky
    4. Access application at: ${output.application_url.value}
  EOT
}
