---
description: 'AWS Terraform Technical Exercise - Three-tier web application deployment guide'
applyTo: '**/*.md'
---

## Objective

Demonstrate proficiency in deploying and managing cloud-based solutions by setting up a three-tiered web application architecture on AWS. This repository implements the Insight Technical Exercise requirements using AWS-native services with full Infrastructure-as-Code deployment via Terraform.

**Technologies:** Terraform | AWS | EKS | MongoDB | S3 | CI/CD | Infrastructure-as-Code

## Technical Exercise Requirements Fulfilled

### Environment Components

- **Web Application Tier**: Containerized tasky app deployed on Amazon EKS cluster
- **Database Tier**: MongoDB server on EC2 VM configured for Kubernetes access
- **Storage Tier**: S3 bucket with public read permissions for MongoDB backups
- **Public Access**: Application publicly accessible via AWS Application Load Balancer
- **Infrastructure-as-Code**: Complete Terraform deployment automation

### Security & Configuration Requirements

- **MongoDB Authentication**: Connection string-based authentication implemented
- **Highly Privileged MongoDB VM**: EC2 instance with Admin AWS permissions via IAM role
- **Container Admin Configuration**: Cluster-admin RBAC permissions configured
- **exercise.txt File**: Container includes required exercise.txt content file
- **Outdated OS/MongoDB**: Amazon Linux 2 with MongoDB v4.0.x (legacy versions)

## Architecture Overview

### Three-Tier Architecture

- **Web Tier**: Tasky application containerized and deployed on Amazon EKS with public-facing Application Load Balancer
- **Data Tier**: MongoDB v4.0.x running on Amazon Linux 2 EC2 instance with authentication enabled
- **Storage Tier**: S3 bucket configured for MongoDB backups with public-read permissions

### Architecture Diagram

AWS Architecture Diagram: `diagrams/aws_architecture_diagram1.png`

### Network Architecture

- **VPC**: Custom VPC with public and private subnets across multiple AZs
- **Security Groups**: Configured to allow EKS to MongoDB communication on port 27017
- **IAM Roles**: EC2 instance with AdminAccess for backup operations
- **Load Balancer**: Internet-facing ALB for public application access

## Key Features

- **Compliance**: Meets all Insight Technical Exercise requirements
- **Security**: MongoDB authentication with connection string format
- **Automation**: Fully automated Terraform provisioning and GitHub Actions CI/CD
- **Monitoring**: CloudWatch integration for backup script monitoring
- **Scalability**: EKS auto-scaling for web tier workloads
- **Backup Strategy**: Automated MongoDB backups to S3 with public URL access
- **Demo-Ready**: Configured for 45-minute technical presentation panel

## Quick Start Guide

### Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform v1.0+ installed
- kubectl installed
- Docker installed (for local container builds)

### 1. Clone and Setup Repository

```bash
git clone https://github.com/your-username/tasky-pivot-for-insight.git
cd tasky-pivot-for-insight
```

### 2. Configure AWS Environment

```bash
# Set your AWS region
export AWS_REGION=us-east-2
export AWS_PROFILE=your-aws-profile

# Verify AWS credentials
aws sts get-caller-identity
```

### 3. Deploy Infrastructure with Terraform

```bash
cd terraform/
terraform init
terraform plan
terraform apply -auto-approve
```

### 4. Configure kubectl for EKS

```bash
aws eks update-kubeconfig --region $AWS_REGION --name tasky-eks-cluster
kubectl get nodes
```

### 5. Deploy Application

```bash
cd ../k8s/
kubectl apply -f .
kubectl get pods -n tasky
```

## Component Specifications

### MongoDB Configuration

- **OS**: Amazon Linux 2 (outdated as required)
- **MongoDB Version**: 4.0.28 (legacy version per requirements)
- **Authentication**: Enabled with username/password
- **Connection String**: `mongodb://username:password@mongodb-host:27017/tasky`
- **VM Permissions**: EC2 instance role with `AdministratorAccess` policy

### Kubernetes Configuration

- **Cluster**: Amazon EKS v1.24
- **Node Group**: t3.medium instances with auto-scaling (1-3 nodes)
- **RBAC**: Container deployed with `cluster-admin` permissions
- **Load Balancer**: AWS Application Load Balancer (internet-facing)
- **Namespace**: `tasky` namespace with appropriate service accounts

### S3 Backup Configuration

- **Bucket Policy**: Public read access enabled
- **Backup Frequency**: Automated daily backups via cron job
- **Backup Script**: Located in `/opt/mongodb-backup/backup.sh` on EC2
- **Public URL Format**: `https://your-bucket.s3.amazonaws.com/backups/mongodb-backup-YYYY-MM-DD.tar.gz`

### Container Specifications

- **Base Image**: Node.js 16-alpine
- **Required File**: `exercise.txt` included in container with exercise content
- **Health Checks**: Kubernetes readiness and liveness probes configured
- **Resource Limits**: CPU: 500m, Memory: 512Mi

## Validation & Testing

### Pre-Presentation Checklist

- [ ] Web application accessible via public URL
- [ ] MongoDB authentication working with connection string
- [ ] S3 backup accessible via public URL
- [ ] Container includes `exercise.txt` file
- [ ] EKS cluster has cluster-admin RBAC configured
- [ ] MongoDB VM has AWS Admin permissions
- [ ] All infrastructure deployed via Terraform

### Testing Commands

```bash
# Test web application access
curl -I https://your-alb-dns-name.us-east-2.elb.amazonaws.com

# Verify MongoDB connection from EKS pod
kubectl exec -it tasky-pod -- mongosh mongodb://username:password@mongodb-ip:27017

# Check S3 backup public access
curl -I https://your-backup-bucket.s3.amazonaws.com/backups/latest.tar.gz

# Verify exercise.txt in container
kubectl exec -it tasky-pod -- cat /app/exercise.txt
```

## Presentation Ready Features

### Live Demo Components

1. **Public Web Access**: Demonstrate tasky application functionality
2. **Database Interaction**: Show MongoDB data persistence
3. **Backup Validation**: Access MongoDB backup via public S3 URL
4. **Infrastructure Review**: Terraform state and AWS resources
5. **Security Configuration**: RBAC and IAM permissions demonstration

### Technical Discussion Points

- **Challenge**: MongoDB legacy version compatibility with modern EKS
- **Solution**: Custom user data scripts and version pinning
- **Challenge**: Public S3 access security considerations
- **Solution**: Least-privilege IAM with specific bucket policies
- **Challenge**: EKS to EC2 network connectivity
- **Solution**: Security group rules and VPC routing configuration

## Architecture Diagrams & Documentation

### Files Structure

```
├── terraform/                 # Infrastructure-as-Code
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── k8s/                      # Kubernetes manifests
│   ├── deployment.yaml
│   ├── service.yaml
│   └── rbac.yaml
├── scripts/                  # MongoDB backup scripts
│   └── mongodb-backup.sh
├── diagrams/                 # Architecture documentation
│   └── aws_architecture_diagram1.png
└── docs/                     # Additional documentation
    └── technical-specs.md
```

### Resource Outputs

After successful deployment, Terraform outputs:

- **Application URL**: Public ALB DNS name
- **MongoDB Connection**: Private IP and connection string
- **S3 Backup Bucket**: Public bucket URL
- **EKS Cluster**: Cluster endpoint and config command

## Troubleshooting

### Common Issues

1. **EKS Pod CrashLoopBackOff**: Check MongoDB connection string in secrets
2. **S3 Access Denied**: Verify bucket policy allows public read
3. **MongoDB Connection Failed**: Check security group rules (port 27017)
4. **Terraform Apply Fails**: Ensure AWS credentials and region are set

### Support Resources

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [MongoDB Authentication Guide](https://docs.mongodb.com/manual/tutorial/enable-authentication/)
- [Kubernetes RBAC Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)

## Technical Exercise Compliance Matrix

| Requirement | Implementation | Status |
|-------------|----------------|---------|
| Containerized web app on K8s | Tasky app on EKS | 
| MongoDB on VM | EC2 with Amazon Linux 2 + MongoDB 4.0.x | 
| Object storage with public read | S3 bucket with public policy |
| MongoDB authentication | Connection string with user/pass |
| Highly privileged MongoDB VM | EC2 with AdministratorAccess IAM role |
| Automated MongoDB backups | Cron script to S3 |
| Outdated Linux + MongoDB | Amazon Linux 2 + MongoDB 4.0.28 |
| exercise.txt in container | File included in Docker image |
| Public web access | ALB with internet gateway |
| Cluster-admin RBAC | ServiceAccount with cluster-admin binding |
| Infrastructure-as-Code | Complete Terraform deployment |

---

*Built for Insight Technical Architect evaluation - Ready for 45-minute technical presentation panel*
