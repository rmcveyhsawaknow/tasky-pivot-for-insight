# AWS Architecture Diagram

This directory contains architectural diagrams for the Tasky application deployment on AWS.

## Diagrams

### aws_architecture_diagram1.png
Three-tier architecture diagram showing:
- **Web Tier**: EKS cluster with containerized Tasky application
- **Data Tier**: MongoDB 4.0.x on Amazon Linux 2 EC2 instance
- **Storage Tier**: S3 bucket for backup storage with public read access

The diagram illustrates the complete infrastructure including:
- VPC with public/private subnets
- Security groups and networking
- Load balancer for public access
- IAM roles and permissions
- Backup strategy to S3

## Creating Diagrams

To create or update the architecture diagrams, you can use tools like:
- [Lucidchart](https://www.lucidchart.com/)
- [Draw.io](https://app.diagrams.net/)
- [AWS Architecture Icons](https://aws.amazon.com/architecture/icons/)

Save diagrams in PNG format with descriptive names.
