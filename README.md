# 🍕 Tasky Pivot for Insight – AWS + Terraform

[![Terraform](https://img.shields.io/badge/IaC-Terraform-blueviolet)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/Cloud-AWS-orange)](https://aws.amazon.com/)
[![EKS](https://img.shields.io/badge/Kubernetes-EKS-326ce5)](https://aws.amazon.com/eks/)
[![CI/CD](https://img.shields.io/badge/CI/CD-GitHub%20Actions-blue)](https://github.com/features/actions)

---

## 📖 Overview
This repo delivers a **three-tier web application architecture** as part of the Insight Technical Architect evaluation. It takes the original Azure exercise and gives it a humorous AWS pivot, using Terraform for full Infrastructure-as-Code (IaC) deployment.

---

## 🌐 Architecture Summary
- **Web Tier:** tasky app containerized and deployed on Amazon EKS with public-facing ALB.
- **Data Tier:** MongoDB v4.0.x running on Amazon Linux 2 EC2 instance with authentication.
- **Storage Tier:** S3 bucket for MongoDB backups with public-read enabled.
- **CI/CD:** AWS CLI deploy from GitHub Gitflow repo, promoting changes via GitHub Actions workflows.

### 🗺️ Architecture Diagram
![AWS Architecture Diagram](diagrams/aws_architecture_diagram1.png)

---

## 🚀 Features
- ☁️ Azure-native → AWS-native service mapping
- ⚙️ Fully automated Terraform provisioning
- 🔁 GitHub Actions CI/CD pipeline integration
- 📝 MongoDB backup scripts with S3 public URLs
- ⏱️ Demo-ready for 45-minute panel presentation

---

## 🏃‍♂️ Quick Start

### Prerequisites
- AWS CLI configured with appropriate credentials
- Terraform v1.0+ installed
- kubectl installed
- Docker installed (for local container builds)

### 1. Fork tasky and Pull Full Git History
```bash
git clone --mirror https://github.com/jeffthorne/tasky.git
cd tasky.git
git remote set-url --push origin https://github.com/<your-username>/tasky-pivot-for-insight.git
git push --mirror
```
This preserves full commit history and makes your repo track upstream for future updates.

### 2. Pull Updates from Upstream
```bash
git remote add upstream https://github.com/jeffthorne/tasky.git
git fetch upstream
git merge upstream/main
```

### 3. Configure AWS Environment
```bash
# Set your AWS region
export AWS_REGION=us-west-2
export AWS_PROFILE=your-aws-profile

# Verify AWS credentials
aws sts get-caller-identity
```

### 4. Deploy Infrastructure with Terraform
```bash
cd terraform/
terraform init
terraform plan
terraform apply -auto-approve
```

### 5. Configure kubectl for EKS
```bash
aws eks update-kubeconfig --region $AWS_REGION --name tasky-eks-cluster
kubectl get nodes
```

### 6. Deploy Application
```bash
cd ../k8s/
kubectl apply -f .
kubectl get pods -n tasky
```

### 7. Destroy Resources
```bash
terraform destroy -auto-approve
```

---

## 📂 Repository Structure
```
tasky-pivot-for-insight/
├── terraform/                 # Infrastructure-as-Code
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── modules/
├── k8s/                      # Kubernetes manifests
│   ├── deployment.yaml
│   ├── service.yaml
│   └── rbac.yaml
├── scripts/                  # MongoDB backup scripts
│   └── mongodb-backup.sh
├── diagrams/                 # Architecture documentation
│   └── aws_architecture_diagram1.png
├── docs/                     # Additional documentation
│   ├── technical-specs.md
│   ├── deployment-guide.md
│   └── ops_git_flow.md      # GitOps workflow & deployment strategy
├── .github/workflows/        # CI/CD pipelines
│   ├── terraform-plan.yml
│   ├── terraform-apply.yml
│   └── build-and-publish.yml
├── main.go                   # Application entry point
├── go.mod                    # Go dependencies
├── go.sum                    # Go checksums
├── Dockerfile               # Container image definition
├── docker-compose.yml       # Local development
├── .env.example             # Environment variables template
└── README.md
```

---

## 🐳 Docker & Local Development

### Environment Variables
The following environment variables are needed:

|Variable|Purpose|Example|
|---|---|---|
|`MONGODB_URI`|Address to mongo server|`mongodb://servername:27017` or `mongodb://username:password@hostname:port` or `mongodb+srv://` schema|
|`SECRET_KEY`|Secret key for JWT tokens|`secret123`|

### Running with Docker
```bash
# Build the image
docker build -t tasky:latest .

# Run with environment variables
docker run -p 8080:8080 \
  -e MONGODB_URI="mongodb://username:password@hostname:27017/tasky" \
  -e SECRET_KEY="your-secret-key" \
  tasky:latest
```

### Running with Go
```bash
# Download dependencies
go mod tidy

# Create .env file with required variables
cp .env.example .env
# Edit .env with your MongoDB URI and Secret Key

# Run the application
go run main.go
```

The application will be available at `http://localhost:8080`

---

## 🎯 Technical Exercise Requirements Compliance

### Environment Components ✅
- **Web Application Tier**: Containerized tasky app deployed on Amazon EKS cluster
- **Database Tier**: MongoDB server on EC2 VM configured for Kubernetes access  
- **Storage Tier**: S3 bucket with public read permissions for MongoDB backups
- **Public Access**: Application publicly accessible via AWS Application Load Balancer
- **Infrastructure-as-Code**: Complete Terraform deployment automation

### Security & Configuration Requirements ✅
- **MongoDB Authentication**: Connection string-based authentication implemented
- **Highly Privileged MongoDB VM**: EC2 instance with Admin AWS permissions via IAM role
- **Container Admin Configuration**: Cluster-admin RBAC permissions configured
- **exercise.txt File**: Container includes required exercise.txt content file
- **Outdated OS/MongoDB**: Amazon Linux 2 with MongoDB v4.0.x (legacy versions)

---

## 🔄 GitOps Deployment Strategy

This project implements a sophisticated GitOps workflow using GitHub Actions and branch-specific deployments:

- **Development Flow**: `develop` branch → container builds and testing
- **Infrastructure Flow**: `deploy/*` branches → Terraform plan/apply workflows
- **Production Flow**: `main` branch → production-ready container images

For detailed deployment procedures, environment promotion strategies, and troubleshooting guides, see: **[docs/ops_git_flow.md](docs/ops_git_flow.md)**

---

## 🔧 Four Anticipated Challenges & Solutions

### 1. **Challenge: MongoDB Legacy Version Compatibility with Modern EKS**
**Solution**: Custom user data scripts and version pinning
- Use Amazon Linux 2 AMI with MongoDB 4.0.x installation scripts
- Pin specific MongoDB version in EC2 user data
- Configure security groups for EKS-to-EC2 communication on port 27017

### 2. **Challenge: Public S3 Access Security Considerations**
**Solution**: Least-privilege IAM with specific bucket policies
- Create dedicated S3 bucket with public-read-only bucket policy
- Use IAM roles for EC2 instances rather than access keys
- Implement backup rotation and lifecycle policies

### 3. **Challenge: EKS to EC2 Network Connectivity**
**Solution**: Security group rules and VPC routing configuration
- Configure VPC with public/private subnet architecture
- Set up security groups allowing EKS pods to reach MongoDB on port 27017
- Use VPC endpoints for secure AWS service communication

### 4. **Challenge: Container Cluster-Admin RBAC Requirements**
**Solution**: Kubernetes service accounts and role bindings
- Create service account with cluster-admin permissions
- Configure pod security context for required access
- Implement namespace isolation with appropriate RBAC

---

## 🧪 Validation & Testing

### Pre-Presentation Checklist
- [ ] Web application accessible via public URL
- [ ] MongoDB authentication working with connection string
- [ ] S3 backup accessible via public URL  
- [ ] Container includes `exercise.txt` file
- [ ] EKS cluster has cluster-admin RBAC configured
- [ ] MongoDB VM has AWS Admin permissions

### Testing Commands
```bash
# Test web application access
curl -I https://your-alb-dns-name.us-west-2.elb.amazonaws.com

# Verify MongoDB connection from EKS pod
kubectl exec -it tasky-pod -- mongosh mongodb://username:password@mongodb-ip:27017

# Check S3 backup public access
curl -I https://your-backup-bucket.s3.amazonaws.com/backups/latest.tar.gz

# Verify exercise.txt in container
kubectl exec -it tasky-pod -- cat /app/exercise.txt
```

---

## 📜 License
© 2025 Insight – Technical Exercise Submission

Original project: https://github.com/dogukanozdemir/golang-todo-mongodb