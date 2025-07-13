# Deployment Guide

This guide provides step-by-step instructions for deploying the Tasky application on AWS using Terraform and Kubernetes.

## Prerequisites

### Required Tools
- **AWS CLI v2**: [Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- **Terraform v1.0+**: [Installation Guide](https://developer.hashicorp.com/terraform/install)
- **kubectl**: [Installation Guide](https://kubernetes.io/docs/tasks/tools/)
- **Docker**: [Installation Guide](https://docs.docker.com/get-docker/)
- **Git**: [Installation Guide](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)

### AWS Account Setup
1. **AWS Account**: Active AWS account with billing enabled
2. **IAM User**: User with programmatic access and sufficient permissions
3. **Required IAM Permissions**:
   - EC2 full access
   - EKS full access
   - S3 full access
   - IAM full access
   - VPC full access
   - CloudWatch logs access

### Configure AWS CLI
```bash
# Configure AWS credentials
aws configure

# Verify configuration
aws sts get-caller-identity
```

## Phase 1: Pre-Flight Validation

Before deploying to AWS, validate all tools and configurations locally:

### Step 1.1: Terraform Validation
```bash
# Navigate to terraform directory
cd terraform/

# Format Terraform files
terraform fmt

# Validate Terraform syntax
terraform validate

# Expected output: "Success! The configuration is valid."
```

### Step 1.2: Go Application Build
```bash
# Return to project root
cd ..

# Install Go dependencies
go mod tidy

# Build the application
go build -o tasky main.go

# Verify build success
ls -la tasky

# Test application (optional)
./tasky --help || echo "Build successful"
```

### Step 1.3: Docker Image Build
```bash
# Build Docker image
docker build -t tasky:latest .

# Verify image was created
docker images | grep tasky

# Verify exercise.txt is included in container
docker run --rm tasky:latest cat /app/exercise.txt

# Expected output: Technical exercise requirements content
```

### Step 1.4: Local Development Stack
```bash
# Start local development environment
docker-compose up -d

# Wait for services to start
sleep 10

# Test application connectivity
curl -I http://localhost:8080 || echo "Local stack validation complete"

# Clean up local stack
docker-compose down
```

### Step 1.5: Kubernetes Manifest Validation
```bash
# Download kubeval for offline validation
curl -L https://github.com/instrumenta/kubeval/releases/latest/download/kubeval-linux-amd64.tar.gz | tar xz -C scripts/utils/

# Validate all Kubernetes manifests
for file in k8s/*.yaml; do
  echo "Validating $file..."
  ./scripts/utils/kubeval "$file"
done

# Expected output: All manifests should pass validation
```

### Phase 1 Validation Checklist
- [ ] Terraform formatting and validation passed
- [ ] Go application builds successfully
- [ ] Docker image builds and contains exercise.txt
- [ ] Local development stack starts without errors
- [ ] Kubernetes manifests pass kubeval validation

✅ **Phase 1 Complete**: All pre-flight validations passed - ready for AWS deployment

---

## Phase 2: AWS Infrastructure Deployment

### Step 2.1: Clone and Setup Repository

```bash
# Clone the repository (if not done in Phase 1)
git clone https://github.com/your-username/tasky-pivot-for-insight.git
cd tasky-pivot-for-insight

# Make scripts executable
chmod +x scripts/*.sh
```

### Step 2.2: Configure Terraform Variables

```bash
# Copy example variables file
cd terraform
cp terraform.tfvars.example terraform.tfvars

# Edit variables (customize as needed)
nano terraform.tfvars
```

**Key variables to review:**
- `aws_region`: Your preferred AWS region
- `mongodb_password`: Strong password for MongoDB
- `jwt_secret`: Secret key for JWT tokens

### Step 2.3: Deploy Infrastructure with Terraform

```bash
# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Apply configuration
terraform apply
```

**Expected deployment time**: 10-15 minutes

**Resources created**:
- VPC with public/private subnets
- EKS cluster with node group
- EC2 instance with MongoDB 4.0.x
- S3 bucket for backups
- IAM roles and security groups

### Step 2.4: Configure kubectl

```bash
# Get cluster name from Terraform output
CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
AWS_REGION=$(terraform output -raw aws_region)

# Configure kubectl
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

# Verify connectivity
kubectl cluster-info
```

### Step 2.5: Deploy Application

```bash
# Use the deployment script
cd ../scripts
./deploy.sh
```

**Or deploy manually:**
```bash
# Apply Kubernetes manifests
cd ../k8s

# Create namespace and RBAC
kubectl apply -f namespace.yaml
kubectl apply -f rbac.yaml

# Apply configuration and secrets
kubectl apply -f configmap.yaml
kubectl apply -f secret.yaml

# Deploy application
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

### Step 6: Verify Deployment

```bash
# Check pod status
kubectl get pods -n tasky

# Check service status
kubectl get svc -n tasky

# Get application URL
kubectl get svc tasky-service -n tasky -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### Step 7: Test Application

```bash
# Get Load Balancer URL
LB_URL=$(kubectl get svc tasky-service -n tasky -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test application
curl -I http://$LB_URL

# Open in browser
open http://$LB_URL  # macOS
# or
start http://$LB_URL  # Windows
```

## Post-Deployment Configuration

### Update MongoDB Connection String

If the automatic MongoDB IP detection didn't work:

1. Get MongoDB private IP:
```bash
cd terraform
MONGODB_IP=$(terraform output -raw mongodb_private_ip)
echo "MongoDB IP: $MONGODB_IP"
```

2. Update the secret:
```bash
# Create new connection string
MONGODB_URI="mongodb://taskyadmin:TaskySecure123!@$MONGODB_IP:27017/tasky"
MONGODB_URI_B64=$(echo -n "$MONGODB_URI" | base64)

# Update secret
kubectl patch secret tasky-secrets -n tasky -p="{\"data\":{\"mongodb-uri\":\"$MONGODB_URI_B64\"}}"

# Restart deployment to pick up new secret
kubectl rollout restart deployment/tasky-app -n tasky
```

### Verify MongoDB Backup

```bash
# Get S3 bucket name
S3_BUCKET=$(cd terraform && terraform output -raw s3_backup_bucket_name)

# Check backup script on MongoDB instance
INSTANCE_ID=$(cd terraform && terraform output -raw mongodb_instance_id)

# Connect to instance (if needed)
aws ssm start-session --target $INSTANCE_ID

# Manually trigger backup (on EC2 instance)
sudo /opt/mongodb-backup/backup.sh

# Check S3 for backups
aws s3 ls s3://$S3_BUCKET/backups/
```

## Verification Checklist

### Infrastructure Verification
- [ ] VPC created with public/private subnets
- [ ] EKS cluster running with nodes
- [ ] MongoDB EC2 instance running
- [ ] S3 bucket created with public read policy
- [ ] Security groups configured correctly

### Application Verification
- [ ] Pods running in tasky namespace
- [ ] LoadBalancer service has external IP
- [ ] Application accessible via browser
- [ ] Login/signup functionality works
- [ ] Tasks can be created and managed

### Security Verification
- [ ] MongoDB authentication enabled
- [ ] Container runs with cluster-admin permissions
- [ ] exercise.txt file present in container
- [ ] EC2 instance has AdministratorAccess role
- [ ] S3 backup accessible via public URL

### Test Commands
```bash
# Verify exercise.txt in container
kubectl exec -it deployment/tasky-app -n tasky -- cat /app/exercise.txt

# Test MongoDB connection
kubectl exec -it deployment/tasky-app -n tasky -- nc -zv $MONGODB_IP 27017

# Check RBAC permissions
kubectl auth can-i '*' '*' --as=system:serviceaccount:tasky:tasky-admin

# Test S3 public access
curl -I https://$S3_BUCKET.s3.$AWS_REGION.amazonaws.com/backups/latest.tar.gz
```

## Troubleshooting

### Common Issues

#### 1. Terraform Apply Fails
```bash
# Check AWS credentials
aws sts get-caller-identity

# Check Terraform version
terraform version

# Check for resource conflicts
terraform plan
```

#### 2. Pods in CrashLoopBackOff
```bash
# Check pod logs
kubectl logs -f deployment/tasky-app -n tasky

# Check events
kubectl get events -n tasky --sort-by='.lastTimestamp'

# Verify secrets
kubectl describe secret tasky-secrets -n tasky
```

#### 3. LoadBalancer Service Pending
```bash
# Check AWS Load Balancer Controller
kubectl get pods -n kube-system | grep aws-load-balancer

# Check subnet tags
aws ec2 describe-subnets --filters "Name=tag:kubernetes.io/role/elb,Values=1"

# Check service events
kubectl describe svc tasky-service -n tasky
```

#### 4. MongoDB Connection Issues
```bash
# Test from pod
kubectl exec -it deployment/tasky-app -n tasky -- telnet $MONGODB_IP 27017

# Check security groups
aws ec2 describe-security-groups --group-ids $MONGODB_SG_ID

# Check MongoDB logs on EC2
aws ssm start-session --target $INSTANCE_ID
sudo tail -f /var/log/mongodb/mongod.log
```

#### 5. S3 Access Issues
```bash
# Check bucket policy
aws s3api get-bucket-policy --bucket $S3_BUCKET

# Test public access
curl -I https://$S3_BUCKET.s3.$AWS_REGION.amazonaws.com/backups/

# Check IAM permissions
aws iam simulate-principal-policy --policy-source-arn $EC2_ROLE_ARN --action-names s3:PutObject --resource-arns arn:aws:s3:::$S3_BUCKET/*
```

## Cleanup

### Destroy Resources
```bash
# Delete Kubernetes resources
kubectl delete namespace tasky

# Destroy Terraform infrastructure
cd terraform
terraform destroy

# Verify all resources deleted
aws eks list-clusters
aws ec2 describe-instances --filters "Name=tag:Project,Values=tasky"
aws s3 ls | grep tasky
```

### Manual Cleanup (if needed)
```bash
# Delete S3 bucket contents
aws s3 rm s3://$S3_BUCKET --recursive

# Delete CloudWatch log groups
aws logs describe-log-groups --log-group-name-prefix "/aws/ec2/mongodb"
aws logs delete-log-group --log-group-name "/aws/ec2/mongodb"
```

## Performance Testing

### Load Testing
```bash
# Install hey (HTTP load testing tool)
go install github.com/rakyll/hey@latest

# Basic load test
hey -n 1000 -c 10 http://$LB_URL

# Test with authentication
hey -n 100 -c 5 -m POST -H "Content-Type: application/json" -d '{"username":"test","password":"test"}' http://$LB_URL/signup
```

### MongoDB Performance
```bash
# Connect to MongoDB instance
aws ssm start-session --target $INSTANCE_ID

# Run MongoDB performance tests
mongo tasky -u taskyadmin -p TaskySecure123! --eval "
  db.todos.insertMany([
    {name: 'Test Task 1', status: 'pending', user_id: 'test'},
    {name: 'Test Task 2', status: 'completed', user_id: 'test'}
  ]);
  db.todos.find().count();
"
```

## Monitoring

### CloudWatch Dashboards
- EC2 instance metrics
- EKS cluster metrics
- Application logs

### Useful CloudWatch Queries
```sql
-- Application errors
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc

-- MongoDB backup logs
fields @timestamp, @message
| filter @logStream like /backup/
| sort @timestamp desc
```

This deployment guide provides comprehensive instructions for setting up the Tasky application on AWS. Follow the steps carefully and refer to the troubleshooting section if you encounter any issues.
