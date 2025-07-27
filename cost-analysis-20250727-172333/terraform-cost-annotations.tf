# Terraform Cost Annotations for Tasky Infrastructure
# Add these comments to your Terraform files for cost tracking

# EKS Cluster - $72.00/month
resource "aws_eks_cluster" "main" {
  # Monthly Cost: $72.00
  # Annual Cost: $864.00
  # Cost Category: Compute - Fixed
}

# MongoDB EC2 Instance - $36.00/month  
resource "aws_instance" "mongodb" {
  instance_type = "t3.medium"
  # Monthly Cost: $36.00
  # Annual Cost: $432.00
  # Cost Category: Compute - Variable
  # Optimization: Consider t3.small for dev environments
}

# EKS Node Group - $72.00/month
resource "aws_eks_node_group" "main" {
  instance_types = ["t3.medium"]
  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }
  # Monthly Cost: $72.00 (2 nodes)
  # Annual Cost: $864.00
  # Cost Category: Compute - Auto Scaling
  # Optimization: Use Spot instances for 70% savings
}

# Application Load Balancer - $16.20/month
# Note: Managed by Kubernetes Ingress Controller
# Monthly Cost: $16.20
# Annual Cost: $194.40
# Cost Category: Networking - Fixed

# NAT Gateway - $32.40/month
resource "aws_nat_gateway" "main" {
  # Monthly Cost: $32.40
  # Annual Cost: $388.80
  # Cost Category: Networking - Fixed
  # Note: Required for private subnet internet access
}

# Total Infrastructure Cost: $248.60/month
# Total Annual Cost: $2983.20

