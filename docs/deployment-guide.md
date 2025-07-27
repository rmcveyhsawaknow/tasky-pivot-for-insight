# Deployment Guide

This guide provides step-by-step instructions for deploying the Tasky application on AWS using Terraform and Kubernetes.

## Prerequisites

### Automated Setup (Recommended for Codespaces)

For GitHub Codespaces or fresh Linux environments, use the automated setup script:

```bash
# Run the automated setup script
./scripts/setup-codespace.sh
```

This script will:
- ✅ Check versions of pre-installed tools (Git, Docker, kubectl)
- 🔧 Install AWS CLI v2 if missing or upgrade from v1
- 🔧 Install Terraform v1.0+ if missing or below minimum version
- ✅ Verify all installations and display version summary
- 📋 Provide next steps for AWS configuration

> **📝 Note:** For detailed script documentation, see [`scripts/README.md`](../scripts/README.md)
- 📋 Provide next steps for AWS configuration

### Manual Installation (Alternative)

If you prefer manual installation or the script doesn't work for your environment:

#### Required Tools
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

# Initialize with local backend for validation (won't apply)
# Option 1: Use the provided script (recommended)
cd ..
./scripts/terraform-local-init.sh
cd terraform

# Option 2: Manual initialization 
# terraform init

# Create a plan file for validation (won't apply)
terraform plan -out=validation.tfplan

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

# Test application build and startup validation
./test-build.sh

# Alternative manual validation (if test-build.sh is not available):
# Test that the app can start and attempt MongoDB connection (will timeout with fake credentials)
# go build -o tasky main.go && MONGODB_URI="mongodb://testuser:testpass@nonexistent:27017/testdb" SECRET_KEY="test123" timeout 2s ./tasky >/dev/null 2>&1; if [ $? -eq 124 ]; then echo "✅ Build successful - app started and attempted connection"; else echo "❌ Build failed - app startup error"; fi
```

### Step 1.3: Docker Image Build
```bash
# Build Docker image
docker build -t tasky:latest .

# Verify image was created
docker images | grep tasky

# Verify exercise.txt is included in container (override entrypoint to avoid MongoDB connection error)
docker run --rm --entrypoint="" tasky:latest cat /app/exercise.txt

```

### Step 1.4: Local Development Stack
```bash
# Start local development environment
docker-compose up -d

# Wait for services to start
sleep 10

# Codespace test, check ports tab in terminal context, browse to UI and Signup, create a task

# Clean up local stack
docker-compose down
```

### Step 1.5: Kubernetes Manifest Validation
```bash
# Download kubeval for offline validation
curl -L https://github.com/instrumenta/kubeval/releases/latest/download/kubeval-linux-amd64.tar.gz | tar xz -C scripts/utils/

# Enhanced validation with error handling
echo "=== Kubernetes Manifest Validation ==="
VALIDATION_ERRORS=0

for file in k8s/*.yaml; do
  echo "Validating $file..."
  if ./scripts/utils/kubeval "$file" 2>&1 | grep -q "ERR"; then
    echo " Validation issues found in $file"
    # Check if it's an Ingress networking/v1 schema issue
    if [[ "$file" == *"ingress.yaml" ]] && ./scripts/utils/kubeval "$file" 2>&1 | grep -q "ingress-networking-v1.json.*404"; then
      echo "Known issue: Ingress networking.k8s.io/v1 schema not available in kubeval"
      echo "Using kubectl validation instead..."
      kubectl --dry-run=client apply -f "$file" >/dev/null 2>&1 && echo "$file: kubectl validation PASSED" || echo "$file: kubectl validation FAILED"
    else
      VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
    fi
  else
    echo "$file: kubeval validation PASSED"
  fi
done

if [ $VALIDATION_ERRORS -eq 0 ]; then
  echo "All Kubernetes manifests validated successfully"
else
  echo "Found $VALIDATION_ERRORS validation error(s)"
  echo "Review the errors above before proceeding"
fi

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
# Make scripts executable
chmod +x scripts/*.sh
```

### Step 2.2: Backend Configuration Strategy

This deployment uses a **flexible backend configuration** that works for both local development and CI/CD:

**🏠 Local Development (What you're doing now):**
- Uses local `terraform.tfstate` file 
- No AWS S3 or DynamoDB dependencies
- Simple initialization with `./scripts/terraform-local-init.sh`

**🚀 CI/CD Deployment (GitHub Actions):**
- Uses S3 remote backend with state locking
- Automatic configuration via `terraform init -backend-config=backend-prod.hcl`
- Team collaboration and state management

### Step 2.3: Configure Terraform Variables

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

### Step 2.4: Deploy Infrastructure with Terraform

> **💡 Best Practice**: Using Terraform plan files (`-out=terraform.tfplan`) ensures that the exact same plan that was reviewed is applied, preventing any unexpected changes between plan and apply operations.

```bash
# Initialize Terraform with local backend
# Option 1: Use the provided script (recommended for local development)
cd .. && ./scripts/terraform-local-init.sh && cd terraform

# Option 2: Manual initialization (if you prefer direct commands)
# terraform init

# Review planned changes and save to file
terraform plan -out=terraform.tfplan

# Review the plan file (optional - displays the saved plan)
terraform show terraform.tfplan

# Apply configuration using the saved plan
terraform apply terraform.tfplan
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
# Get cluster name and region from Terraform output and export as environment variables
export CLUSTER_NAME=$(terraform output -raw eks_cluster_name)

# For existing deployments: Extract region from EKS endpoint or use default
export AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-east-1")

# If the aws_region output is missing (older Terraform state), extract from kubectl command
if [ "$AWS_REGION" = "us-east-1" ] && terraform output kubectl_config_command >/dev/null 2>&1; then
    AWS_REGION=$(terraform output -raw kubectl_config_command | grep -o 'region [a-z0-9-]*' | cut -d' ' -f2)
    export AWS_REGION
fi

# Verify the variables are set
echo "Cluster Name: $CLUSTER_NAME"
echo "AWS Region: $AWS_REGION"

# Configure kubectl
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

# Verify connectivity
kubectl cluster-info
kubectl get nodes
```

### Step 2.5: Deploy Application

The deployment uses AWS Application Load Balancer (ALB) via Kubernetes Ingress Controller for modern, cloud-native load balancing. This approach provides cost-effective Layer 7 load balancing with automatic SSL termination and custom domain support.

**AWS Load Balancer Controller Deployment (Production-Ready)**

This automated script handles the complete deployment:

```bash
# Navigate to project root and run the setup script
cd ..
./scripts/setup-alb-controller.sh
```

**The setup script automatically performs these steps:**
- ✅ Installs AWS Load Balancer Controller via Helm
- ✅ Creates Kubernetes namespace, RBAC, secrets, and deployments
- ✅ Deploys ALB Ingress with health checks and security configurations
- ✅ Configures custom domain support for `ideatasky.ryanmcvey.me`
- ✅ Updates MongoDB connection strings from Terraform outputs
- ✅ Provides cost-optimized Layer 7 load balancing with automatic target registration

**Expected Output:**
```
✅ AWS Load Balancer Controller installed
✅ Application deployed
✅ Application is accessible at: http://k8s-tasky-xxxxx.us-east-1.elb.amazonaws.com
```

**If deployment encounters issues, run cleanup and retry:**
```bash
./scripts/setup-alb-controller.sh --cleanup
```

### Step 3: Verify Deployment

```bash
# Check pod status
kubectl get pods -n tasky

# Check ingress status
kubectl get ingress -n tasky

# Get application URL
ALB_URL=$(kubectl get ingress tasky-ingress -n tasky -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Application URL: http://$ALB_URL"

# Check application logs
kubectl logs -f deployment/tasky-app -n tasky --tail=20
```

**If pods show connection issues to MongoDB:**
```bash
# Restart deployment to reinitialize connections
kubectl rollout restart deployment/tasky-app -n tasky

# Verify pod status
kubectl get pods -n tasky
```
```

### Step 4: Test Application

```bash
# Get ALB URL and test application
ALB_URL=$(kubectl get ingress tasky-ingress -n tasky -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test HTTP response
curl -I http://$ALB_URL

# Open in browser (macOS/Linux)
open http://$ALB_URL

# Test custom domain (after DNS configuration)
curl -I http://ideatasky.ryanmcvey.me
```

**Expected Response:**
- HTTP 200 for working application
- HTTP 404 if application is not serving on root path (check logs)

## Application Access & Verification

### Get Current Application URL

```bash
# Quick URL access
echo "Application URL: http://$(kubectl get ingress tasky-ingress -n tasky -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"

# Test application health
ALB_URL=$(kubectl get ingress tasky-ingress -n tasky -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl -s -o /dev/null -w "Status: %{http_code}" http://$ALB_URL && echo ""
```

### Complete Deployment Status

```bash
# Comprehensive deployment verification
echo "=== Tasky Deployment Status ==="

echo "1. Pod Status:"
kubectl get pods -n tasky -o wide

echo "2. Ingress Status:"
kubectl get ingress -n tasky

echo "3. ALB Controller Status:"
kubectl get pods -n kube-system | grep aws-load-balancer-controller

echo "4. Application URL:"
ALB_URL=$(kubectl get ingress tasky-ingress -n tasky -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "http://$ALB_URL"

echo "5. Recent Application Logs:"
kubectl logs --tail=100 deployment/tasky-app -n tasky
```
### Custom Domain Setup

After ALB deployment, configure your custom domain:

1. **Get ALB DNS name:**
```bash
ALB_DNS=$(kubectl get ingress tasky-ingress -n tasky -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "ALB DNS: $ALB_DNS"
```

2. **Configure DNS CNAME:**
- Add CNAME record: `ideatasky.ryanmcvey.me` → `$ALB_DNS`
- Wait 2-5 minutes for DNS propagation

3. **Test custom domain:**
```bash
curl -I http://ideatasky.ryanmcvey.me
```
## Post-Deployment Configuration

### Update MongoDB Connection (if needed)

If automatic MongoDB IP detection didn't work:

```bash
# Get MongoDB private IP from Terraform
cd terraform
MONGODB_IP=$(terraform output -raw mongodb_private_ip)
MONGODB_USER=$(terraform output -raw mongodb_username)
MONGODB_PASS=$(terraform output -raw mongodb_password)
MONGODB_DB=$(terraform output -raw mongodb_database_name)

# Create new connection string and update secret
MONGODB_URI="mongodb://$MONGODB_USER:$MONGODB_PASS@$MONGODB_IP:27017/$MONGODB_DB"
kubectl patch secret tasky-secrets -n tasky -p="{\"data\":{\"mongodb-uri\":\"$(echo -n $MONGODB_URI | base64)\"}}"

# Restart deployment to pick up new secret
kubectl rollout restart deployment/tasky-app -n tasky
```

### MongoDB Health Check

```bash
# Quick MongoDB status check from Terraform
cd terraform
INSTANCE_ID=$(terraform output -raw mongodb_instance_id)
MONGODB_IP=$(terraform output -raw mongodb_private_ip)

echo "MongoDB Instance: $INSTANCE_ID"
echo "MongoDB IP: $MONGODB_IP"

# Connect to MongoDB instance via SSM
aws ssm start-session --target $INSTANCE_ID

# On the EC2 instance, check MongoDB status:
# sudo systemctl status mongod
# sudo netstat -tlnp | grep 27017
# mongo --host 127.0.0.1:27017 -u $MONGODB_USER -p $MONGODB_PASS
```

### S3 Backup Verification

```bash
# Check S3 backup bucket
cd terraform
S3_BUCKET=$(terraform output -raw s3_backup_bucket_name)
AWS_REGION=$(terraform output -raw aws_region)

# List backups
aws s3 ls s3://$S3_BUCKET/backups/

# Test public access to backups
curl -I https://$S3_BUCKET.s3.$AWS_REGION.amazonaws.com/backups/
```

## Troubleshooting

### Common Issues

1. **503 Service Unavailable**
   - Check pod logs: `kubectl logs -f deployment/tasky-app -n tasky`
   - Verify MongoDB connection in pod logs
   - Restart deployment: `kubectl rollout restart deployment/tasky-app -n tasky`

2. **ALB not provisioning**
   - Check ALB controller: `kubectl get pods -n kube-system | grep aws-load-balancer-controller`
   - Check ingress events: `kubectl describe ingress tasky-ingress -n tasky`

3. **MongoDB connection failed**
   - Verify MongoDB IP in secret: `kubectl get secret tasky-secrets -n tasky -o yaml`
   - Check security groups allow port 27017
   - Verify MongoDB is running: Use SSM to connect to EC2 instance

### Quick Fixes

```bash
# Restart everything
kubectl rollout restart deployment/tasky-app -n tasky

# Check all resources
kubectl get all,ingress,secrets -n tasky

# View recent logs
kubectl logs --tail=50 deployment/tasky-app -n tasky
```

---

## Summary

**What was deployed:**
- ✅ AWS EKS cluster with ALB Ingress Controller
- ✅ MongoDB 4.0.x on EC2 with authentication
- ✅ S3 bucket with public backup access
- ✅ Tasky application with cluster-admin RBAC
- ✅ Cloud-native ALB for public access

**Access Points:**
- **Application URL**: Use `kubectl get ingress tasky-ingress -n tasky` to get ALB URL
- **Custom Domain**: `http://ideatasky.ryanmcvey.me` (after DNS configuration)
- **MongoDB**: Private IP accessible from EKS pods only
- **Backups**: Public S3 bucket for MongoDB backups

**Key Commands:**
```bash
# Get application URL
kubectl get ingress tasky-ingress -n tasky

# Check status
kubectl get pods,svc,ingress -n tasky

# View logs
kubectl logs -f deployment/tasky-app -n tasky
```
MONGODB_IP=$(terraform output -raw mongodb_private_ip)

echo "=== MongoDB Health Check ==="
echo "Instance ID: $INSTANCE_ID"
echo "Private IP: $MONGODB_IP"
echo

# Test connectivity from EKS pod
echo "=== Testing connectivity from EKS pod ==="
kubectl exec deployment/tasky-app -n tasky -- nc -zv $MONGODB_IP 27017 2>&1 || echo "❌ Connection failed"

# Check application logs for MongoDB connection
echo -e "\n=== Recent application logs (MongoDB related) ==="
kubectl logs deployment/tasky-app -n tasky --tail=10 | grep -i "mongo\|database\|connection" || echo "No recent MongoDB logs found"

# Check if backup exists in S3
echo -e "\n=== S3 Backup Status ==="
S3_BUCKET=$(terraform output -raw s3_backup_bucket_name)
aws s3 ls s3://$S3_BUCKET/backups/ | tail -5 || echo "No backups found"

echo -e "\n=== MongoDB Instance Status ==="
aws ec2 describe-instances --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].State.Name' --output text

echo -e "\n=== Next Steps ==="
echo "1. Connect to MongoDB: aws ssm start-session --target $INSTANCE_ID"
echo "2. Check MongoDB status: sudo systemctl status mongod"
echo "3. Connect to database: mongo --host 127.0.0.1:27017 -u taskyadmin -p asimplepass --authenticationDatabase tasky"
EOF

# Make script executable
chmod +x check_mongodb_health.sh

# Run the health check
./check_mongodb_health.sh
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
# Verify exercise.txt in container (two methods)
# Method 1: Override entrypoint
docker run --rm --entrypoint="" tasky:latest cat /app/exercise.txt

# Method 2: Use kubectl if deployed to cluster
kubectl exec -it deployment/tasky-app -n tasky -- cat /app/exercise.txt

# Test MongoDB connection
kubectl exec -it deployment/tasky-app -n tasky -- nc -zv $MONGODB_IP 27017

# Check RBAC permissions
kubectl auth can-i '*' '*' --as=system:serviceaccount:tasky:tasky-admin

# Test S3 public access
curl -I https://$S3_BUCKET.s3.$AWS_REGION.amazonaws.com/backups/latest.tar.gz
```

### MongoDB Database Operations

#### Connect to MongoDB via SSM and Query Database

```bash
# Get MongoDB instance ID
cd terraform
INSTANCE_ID=$(terraform output -raw mongodb_instance_id)

# Connect to MongoDB instance
aws ssm start-session --target $INSTANCE_ID

# Connect to MongoDB with authentication
mongo --host 127.0.0.1:27017 -u taskyadmin -p asimplepass --authenticationDatabase tasky
```

**Common MongoDB Queries:**

```javascript
// Show all databases with sizes
db.adminCommand("listDatabases");

// Switch to tasky database
use tasky;

// Show current database
db.getName();

// Show collections in current database
show collections;
// or
db.getCollectionNames();

// Get database statistics (includes size information)
db.stats();

// Get collection-specific statistics
db.users.stats();
db.todos.stats();

// Count documents in collections
db.users.count();
db.todos.count();

// Sample documents from collections
db.users.findOne();
db.todos.findOne();

// Show indexes
db.users.getIndexes();
db.todos.getIndexes();

// Get storage size information
db.stats().dataSize;  // Data size in bytes
db.stats().storageSize;  // Storage size in bytes
db.stats().indexSize;  // Index size in bytes

// Show collection sizes in a readable format
db.runCommand({collStats: "users"});
db.runCommand({collStats: "todos"});

// List all users in the database
db.getUsers();

// Check current user permissions
db.runCommand({usersInfo: "taskyadmin", showPrivileges: true});

// Create a test document (for testing)
db.todos.insertOne({
  name: "Test Task",
  description: "Test Description",
  status: "pending",
  user_id: "test-user",
  created_at: new Date()
});

// Query test document
db.todos.find({name: "Test Task"});

// Remove test document
db.todos.deleteOne({name: "Test Task"});

// Exit MongoDB shell
exit;
```

#### Quick MongoDB Health Check Script

```bash
# Create a MongoDB health check (run from EC2 instance)
cat > /tmp/mongo_health.js << 'EOF'
// MongoDB Health Check Script
print("=== MongoDB Health Check ===");
print("Server Status:");
var serverStatus = db.serverStatus();
print("MongoDB Version: " + serverStatus.version);
print("Uptime: " + serverStatus.uptime + " seconds");
print("Connections: " + serverStatus.connections.current + "/" + serverStatus.connections.available);

print("\n=== Database Information ===");
var dbStats = db.stats();
print("Database: " + db.getName());
print("Collections: " + dbStats.collections);
print("Data Size: " + (dbStats.dataSize / 1024 / 1024).toFixed(2) + " MB");
print("Storage Size: " + (dbStats.storageSize / 1024 / 1024).toFixed(2) + " MB");
print("Index Size: " + (dbStats.indexSize / 1024 / 1024).toFixed(2) + " MB");

print("\n=== Collection Details ===");
var collections = db.getCollectionNames();
collections.forEach(function(collection) {
    var count = db[collection].count();
    print(collection + ": " + count + " documents");
});

print("\n=== Authentication Status ===");
try {
    var authStatus = db.runCommand({connectionStatus: 1});
    print("Authenticated as: " + JSON.stringify(authStatus.authInfo.authenticatedUsers));
} catch(e) {
    print("Authentication check failed: " + e);
}
EOF

# Run the health check script
mongo --host 127.0.0.1:27017 -u taskyadmin -p asimplepass --authenticationDatabase tasky /tmp/mongo_health.js

# Clean up
rm /tmp/mongo_health.js
```

## Troubleshooting

### Common Issues

#### 1. Terraform Apply Fails
```bash
# Check AWS credentials
aws sts get-caller-identity

# Check Terraform version
terraform version

# Generate and review plan file for debugging
terraform plan -out=debug.tfplan
terraform show debug.tfplan

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
# Get MongoDB details
cd terraform
MONGODB_IP=$(terraform output -raw mongodb_private_ip)
INSTANCE_ID=$(terraform output -raw mongodb_instance_id)

# Test connectivity from pod
kubectl exec -it deployment/tasky-app -n tasky -- nc -zv $MONGODB_IP 27017

# If connection fails, check MongoDB service on EC2
aws ssm start-session --target $INSTANCE_ID

# On EC2 instance:
# Check if MongoDB is running
sudo systemctl status mongod

# If not running, start MongoDB
sudo systemctl start mongod
sudo systemctl enable mongod

# Check if MongoDB is binding to correct interface
sudo cat /etc/mongod.conf | grep bindIp

# If bindIp is 127.0.0.1, change to 0.0.0.0
sudo sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' /etc/mongod.conf
sudo systemctl restart mongod

# Verify MongoDB is listening on all interfaces
sudo netstat -tlnp | grep 27017

# Check MongoDB logs for errors
sudo tail -20 /var/log/mongodb/mongod.log

# Check if user data script completed successfully
sudo cat /var/log/user-data.log | tail -20

# Exit EC2 instance
exit

# Check security groups
MONGODB_SG=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' --output text)
aws ec2 describe-security-groups --group-ids $MONGODB_SG \
  --query 'SecurityGroups[0].IpPermissions[?FromPort==`27017`]'

# If security group rules are missing, add them
EKS_CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
EKS_NODE_SG=$(aws eks describe-cluster --name $EKS_CLUSTER_NAME \
  --query 'cluster.resourcesVpcConfig.securityGroupIds[0]' --output text)

# Add security group rule for EKS access to MongoDB
aws ec2 authorize-security-group-ingress \
  --group-id $MONGODB_SG \
  --protocol tcp \
  --port 27017 \
  --source-group $EKS_NODE_SG
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

# Clean up plan files
rm -f *.tfplan

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
