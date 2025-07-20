# 🍕 Tasky Pivot for Insight – AWS + Terraform

[![Terraform](https://img.shields.io/badge/IaC-Terraform-blueviolet)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/Cloud-AWS-orange)](https://aws.amazon.com/)
[![EKS](https://img.shields.io/badge/Kubernetes-EKS-326ce5)](https://aws.amazon.com/eks/)
[![CI/CD](https://img.shields.io/badge/CI/CD-GitHub%20Actions-blue)](https://github.com/features/actions)

## 📖 Overview

**Tasky** is a modern task management web application built with Go, featuring user authentication, task creation/management, and persistent data storage. This repository demonstrates enterprise-grade infrastructure automation by implementing a complete AWS three-tier architecture deployment using Infrastructure-as-Code (IaC) principles.

### About Tasky Application
- **Technology Stack**: Go backend, HTML/CSS/JavaScript frontend, MongoDB database
- **Features**: User registration/authentication, task CRUD operations, responsive web interface
- **Architecture**: RESTful API design with JWT-based authentication and MongoDB data persistence
- **Containerization**: Docker-ready with multi-stage builds and security best practices

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
![AWS Architecture Diagram](diagrams/enhanced-graph.svg)

## 🚀 Infrastructure Automation Methods

This project implements **DevOps automation principles** through two primary deployment approaches, emphasizing the CALMS framework (Culture, Automation, Lean, Measurement, Sharing) and Infrastructure-as-Code best practices.

### Method A: Local Development & IDE Deployment

**Purpose**: Developer-centric workflow for rapid iteration, testing, and manual infrastructure provisioning.

**Workflow**:
1. **Local Development**: Full Docker Compose stack for application development
2. **Infrastructure Provisioning**: Manual Terraform execution from IDE/terminal
3. **Application Deployment**: Direct kubectl commands for container orchestration
4. **Validation**: Manual testing and verification procedures

**Best Use Cases**:
- Feature development and testing
- Infrastructure experimentation and tuning
- Troubleshooting and debugging
- Learning and skill development

### Method B: CI/CD via GitHub Actions

**Purpose**: Production-ready automated pipeline following GitOps principles for reliable, repeatable deployments.

**Workflow**:
1. **Continuous Integration**: Automated testing, building, and security scanning
2. **Infrastructure Deployment**: Terraform automation with state management
3. **Application Deployment**: Automated Kubernetes deployments with rollback capabilities
4. **Monitoring**: Automated health checks and deployment validation

**Best Use Cases**:
- Production deployments
- Team collaboration and consistent environments
- Compliance and audit requirements
- Scaling across multiple environments

📖 **For complete deployment instructions using either method, see: [docs/deployment-guide.md](docs/deployment-guide.md)**

## 📂 Repository Structure
```
tasky-pivot-for-insight/
├── terraform/                 # Infrastructure-as-Code
│   ├── main.tf                # Main Terraform configuration
│   ├── variables.tf           # Input variables
│   ├── outputs.tf             # Output values
│   ├── providers.tf           # Provider configurations
│   ├── backend.tf             # Remote state configuration
│   ├── versions.tf            # Version constraints
│   ├── terraform.tfvars.example # Example configuration
│   └── modules/               # Terraform modules
│       ├── eks/               # EKS cluster module
│       ├── mongodb-ec2/       # MongoDB EC2 module
│       ├── s3-backup/         # S3 backup bucket module
│       └── vpc/               # VPC networking module
├── k8s/                       # Kubernetes manifests
│   ├── namespace.yaml         # Namespace definition
│   ├── rbac.yaml              # Service account & permissions
│   ├── configmap.yaml         # Application configuration
│   ├── secret.yaml            # MongoDB connection secrets
│   ├── deployment.yaml        # Tasky application deployment
│   └── service.yaml           # LoadBalancer service
├── scripts/                   # Automation scripts
│   ├── setup-codespace.sh     # Automated tool installation & setup
│   ├── check-versions.sh      # Tool version verification
│   ├── deploy.sh              # Application deployment script
│   ├── mongodb-backup.sh      # MongoDB backup script
│   ├── README.md              # Scripts documentation
│   └── utils/                 # Utility tools
├── docs/                      # Documentation
│   ├── deployment-guide.md    # Detailed deployment procedures
│   ├── technical-specs.md     # Architecture specifications
│   └── ops_git_flow.md        # GitOps workflow guide
├── .github/                   # GitHub configuration
│   ├── workflows/             # CI/CD pipelines
│   └── instructions/          # Coding guidelines & standards
├── assets/                    # Frontend static assets
│   ├── css/                   # Stylesheets
│   ├── js/                    # JavaScript files
│   ├── img/                   # Images and icons
│   ├── login.html             # Login page template
│   └── todo.html              # Todo page template
├── auth/                      # Authentication module
│   └── auth.go                # JWT authentication logic
├── controllers/               # Application controllers
│   ├── todoController.go      # Todo CRUD operations
│   └── userController.go      # User management
├── database/                  # Database connectivity
│   └── database.go            # MongoDB connection setup
├── models/                    # Data models
│   └── models.go              # User and Todo structures
├── diagrams/                  # Architecture diagrams
├── main.go                    # Go application entry point
├── Dockerfile                 # Container image definition
├── docker-compose.yml         # Local development environment
├── go.mod                     # Go module definition
├── go.sum                     # Go module checksums
├── .env.example               # Environment variables template
└── exercise.txt               # Technical exercise requirements
```

## 🐳 Local Application-Only Development

For developing and testing the Tasky application without AWS infrastructure, use the local development stack:

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

### Running with Go (Development Mode)
```bash
# Install dependencies
go mod tidy

# Configure environment
cp .env.example .env
# Edit .env with your MongoDB URI and Secret Key

# Run application
go run main.go
```

### Local Development Features
- **Hot Reload**: Direct Go execution for rapid development cycles
- **Isolated Environment**: MongoDB container with persistent volumes
- **Port Forwarding**: Application accessible at `http://localhost:8080`
- **Debug Support**: Full debugging capabilities with IDE integration

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
curl -I https://$S3_BUCKET.s3.us-east-2.amazonaws.com/backups/
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