# 🍕 Tasky Pivot for Insight – AWS + Terraform

[![Terraform](https://img.shields.io/badge/IaC-Terraform-blueviolet)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/Cloud-AWS-orange)](https://aws.amazon.com/)
[![EKS](https://img.shields.io/badge/Kubernetes-EKS-326ce5)](https://aws.amazon.com/eks/)
[![CI/CD](https://img.shields.io/badge/CI/CD-GitHub%20Actions-blue)](https://github.com/features/actions)

## 📖 Overview

This repository delivers a **three-tier web application architecture** as part of the Insight Technical Architect evaluation. It implements an AWS-native deployment of the Tasky application using complete Infrastructure-as-Code (IaC) with Terraform.

## 🌐 Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     AWS Three-Tier Architecture                 │
├─────────────────────────────────────────────────────────────────┤
│ Web Tier:     EKS + ALB + Tasky Container                      │
│               ↓                                                │
│ Data Tier:    MongoDB 4.0.x on Amazon Linux 2 EC2             │
│               ↓                                                │
│ Storage Tier: S3 Bucket (Public) + Automated Backups          │
└─────────────────────────────────────────────────────────────────┘
```

### Components
- **Web Tier**: Containerized Tasky app on Amazon EKS with public Application Load Balancer
- **Data Tier**: MongoDB v4.0.x on Amazon Linux 2 EC2 instance with authentication  
- **Storage Tier**: S3 bucket with public read access for MongoDB backups
- **Infrastructure**: Complete Terraform automation with ~50+ AWS resources

### 🗺️ Architecture Diagram
![AWS Architecture Diagram](diagrams/aws_architecture_diagram1.png)

## 🚀 Quick Start

### Prerequisites
- **AWS Account** with billing enabled and appropriate permissions
- **AWS CLI v2** installed and configured (`aws configure`)
- **Terraform v1.0+** installed  
- **kubectl** installed
- **Docker** installed

### 1. Configure AWS Credentials
```bash
# Configure AWS credentials (required)
aws configure

# Verify configuration  
aws sts get-caller-identity
```

**Required AWS IAM Permissions**:
- EC2 full access
- EKS full access  
- S3 full access
- IAM full access
- VPC full access
- CloudWatch logs access

### 2. Deploy Infrastructure
```bash
# Clone repository
git clone https://github.com/rmcveyhsawaknow/tasky-pivot-for-insight.git
cd tasky-pivot-for-insight

# Configure Terraform variables
cd terraform/
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Edit with your AWS settings

# Deploy infrastructure (~15-20 minutes)
terraform init
terraform plan
terraform apply
```

### 3. Configure kubectl and Deploy Application
```bash
# Configure kubectl for EKS
CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
AWS_REGION=$(terraform output -raw aws_region)
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

# Deploy application
cd ../k8s/
kubectl apply -f .

# Get application URL
kubectl get svc tasky-service -n tasky
```

### 4. Verify Deployment
```bash
# Check application status
kubectl get pods -n tasky

# Test application access
LB_URL=$(kubectl get svc tasky-service -n tasky -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl -I http://$LB_URL

# Verify exercise requirements
kubectl exec -it deployment/tasky-app -n tasky -- cat /app/exercise.txt
```

**📖 For detailed step-by-step instructions, troubleshooting, and validation procedures, see: [docs/deployment-guide.md](docs/deployment-guide.md)**

## 📂 Repository Structure
```
tasky-pivot-for-insight/
├── terraform/                 # Infrastructure-as-Code
│   ├── main.tf                # Main Terraform configuration
│   ├── variables.tf           # Input variables
│   ├── outputs.tf             # Output values
│   └── modules/               # Terraform modules
│       ├── eks/               # EKS cluster module
│       ├── mongodb-ec2/       # MongoDB EC2 module
│       ├── s3-backup/         # S3 backup bucket module
│       └── vpc/               # VPC networking module
├── k8s/                       # Kubernetes manifests
│   ├── deployment.yaml        # Tasky application deployment
│   ├── service.yaml           # LoadBalancer service
│   ├── rbac.yaml              # Service account & permissions
│   ├── configmap.yaml         # Application configuration
│   ├── secret.yaml            # MongoDB connection secrets
│   └── namespace.yaml         # Namespace definition
├── scripts/                   # Automation scripts
│   ├── deploy.sh              # Application deployment script
│   └── mongodb-backup.sh      # MongoDB backup script
├── docs/                      # Documentation
│   ├── deployment-guide.md    # Detailed deployment procedures
│   ├── technical-specs.md     # Architecture specifications
│   └── ops_git_flow.md        # GitOps workflow guide
├── .github/workflows/         # CI/CD pipelines
├── main.go                    # Go application entry point
├── Dockerfile                 # Container image definition
├── docker-compose.yml         # Local development environment
└── exercise.txt               # Technical exercise requirements
```

## 🐳 Local Development

### Environment Variables
|Variable|Purpose|Example|
|---|---|---|
|`MONGODB_URI`|MongoDB connection string|`mongodb://username:password@hostname:27017/tasky`|
|`SECRET_KEY`|JWT token secret|`your-secret-key`|

### Running Locally with Docker Compose
```bash
# Start local development environment
docker-compose up --build -d

# Test application
curl http://localhost:8080

# View logs
docker-compose logs tasky

# Clean up
docker-compose down
```

### Running with Go
```bash
# Install dependencies
go mod tidy

# Configure environment
cp .env.example .env
# Edit .env with your MongoDB URI and Secret Key

# Run application
go run main.go
```

## 🎯 Technical Exercise Compliance

### ✅ Architecture Requirements
- **Three-tier architecture**: Web (EKS) + Data (MongoDB EC2) + Storage (S3)
- **Public access**: Web application via Application Load Balancer
- **Database**: MongoDB with authentication enabled
- **Storage**: S3 bucket with public read access for backups

### ✅ Security & Configuration
- **MongoDB Authentication**: Connection string-based auth implemented
- **Highly Privileged MongoDB VM**: EC2 with AdministratorAccess IAM role
- **Container Admin Configuration**: cluster-admin RBAC permissions
- **exercise.txt File**: Present in container at `/app/exercise.txt`
- **Legacy Requirements**: Amazon Linux 2 + MongoDB v4.0.x

### ✅ Infrastructure-as-Code
- **Complete Terraform automation**: ~50+ AWS resources
- **Modular design**: Reusable Terraform modules
- **State management**: Remote state with S3 backend support
- **Variable configuration**: Customizable deployment parameters

## 🔄 CI/CD & GitOps

This project implements GitOps workflows using GitHub Actions:

- **Infrastructure**: Terraform plan/apply on `deploy/*` branches
- **Application**: Container builds and testing on `develop` branch  
- **Production**: Automated deployments from `main` branch

For detailed GitOps procedures and branch strategies, see: [docs/ops_git_flow.md](docs/ops_git_flow.md)

## 🧪 Validation & Testing

### Quick Validation Commands
```bash
# Verify infrastructure
terraform show | grep -E "(vpc|eks|ec2|s3)"

# Check application health
kubectl get all -n tasky
kubectl logs -f deployment/tasky-app -n tasky

# Test MongoDB connectivity
MONGODB_IP=$(terraform output -raw mongodb_private_ip)
kubectl exec -it deployment/tasky-app -n tasky -- nc -zv $MONGODB_IP 27017

# Verify S3 backup access
S3_BUCKET=$(terraform output -raw s3_backup_bucket_name)
curl -I https://$S3_BUCKET.s3.us-west-2.amazonaws.com/backups/
```

### Pre-Presentation Checklist
- [ ] Web application accessible via public URL
- [ ] MongoDB authentication working with connection string
- [ ] S3 backup accessible via public URL  
- [ ] Container includes `exercise.txt` file
- [ ] EKS cluster has cluster-admin RBAC configured
- [ ] MongoDB VM has AWS Administrator permissions

## 🔧 Troubleshooting

### Common Issues
1. **AWS Credentials**: Verify with `aws sts get-caller-identity`
2. **Terraform Errors**: Check AWS permissions and region settings
3. **EKS Access**: Ensure kubectl is configured correctly
4. **Pod Failures**: Check logs with `kubectl logs -f deployment/tasky-app -n tasky`

### Debug Commands
```bash
# Check AWS resources
aws eks describe-cluster --name $(terraform output -raw eks_cluster_name)
aws ec2 describe-instances --filters "Name=tag:Project,Values=tasky"

# Kubernetes debugging
kubectl describe pod -l app.kubernetes.io/name=tasky -n tasky
kubectl get events -n tasky --sort-by='.lastTimestamp'
```

## 🧹 Cleanup

```bash
# Delete Kubernetes resources
kubectl delete namespace tasky

# Destroy Terraform infrastructure
cd terraform/
terraform destroy

# Verify cleanup
aws eks list-clusters
aws ec2 describe-instances --filters "Name=tag:Project,Values=tasky"
```

## 🎤 Demo Preparation

This deployment is ready for a **45-minute technical presentation** with:

1. **Live Infrastructure Review** (AWS Console walkthrough)
2. **Application Functionality** (Task management, user authentication)
3. **Database Operations** (MongoDB queries, data persistence)
4. **Security Demonstration** (RBAC, IAM roles, authentication)
5. **Backup Strategy** (S3 public URLs, automated backups)
6. **Architecture Discussion** (Design decisions, scalability)

### Key Technical Talking Points
- **Azure to AWS Migration**: Platform expertise demonstration
- **Legacy System Integration**: Working within constraints (MongoDB 4.0.x, Amazon Linux 2)
- **Security Compliance**: Enterprise-grade permissions and authentication
- **Infrastructure Automation**: Terraform best practices and modular design
- **Operational Excellence**: Monitoring, logging, and backup strategies

## 📜 License & Attribution

**Technical Exercise Submission for Insight Technical Architect Role**

Original project: [dogukanozdemir/golang-todo-mongodb](https://github.com/dogukanozdemir/golang-todo-mongodb)  
Forked and adapted by: [jeffthorne/tasky](https://github.com/jeffthorne/tasky)  
AWS Architecture Implementation: © 2025