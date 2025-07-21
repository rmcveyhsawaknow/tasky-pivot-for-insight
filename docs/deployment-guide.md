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

# Initialize and create a plan file for validation (won't apply)
terraform init
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

# Test application (optional, there is expected output, error parsing uri: scheme must be "mongodb" or "mongodb+srv", this is showing app trying to start, but no db)
./tasky --help || echo "Build successful"
```

### Step 1.3: Docker Image Build
```bash
# Build Docker image
docker build -t tasky:latest .

# Verify image was created
docker images | grep tasky

# Verify exercise.txt is included in container (override entrypoint to avoid MongoDB connection error)
docker run --rm --entrypoint="" tasky:latest cat /app/exercise.txt

# Alternative verification with file details
docker run --rm --entrypoint="sh" tasky:latest -c "ls -la /app/exercise.txt && echo '--- Content ---' && cat /app/exercise.txt"

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

> **💡 Best Practice**: Using Terraform plan files (`-out=terraform.tfplan`) ensures that the exact same plan that was reviewed is applied, preventing any unexpected changes between plan and apply operations.

```bash
# Initialize Terraform
terraform init

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

The deployment process uses AWS Application Load Balancer (ALB) for cost-effective, cloud-native load balancing with custom domain support.

**Recommended: ALB-First Deployment (Cost-Optimized & Production-Ready)**

This is the preferred deployment method for production workloads:

```bash
# Install AWS Load Balancer Controller and deploy application
cd ..
./scripts/setup-alb-controller.sh

# The setup script automatically:
# ✅ Installs AWS Load Balancer Controller via Helm
# ✅ Deploys the application with ALB Ingress configuration
# ✅ Configures health checks and security groups
# ✅ Sets up custom domain support for ideatasky.ryanmcvey.me
# ✅ Provides cost-optimized Layer 7 load balancing
```

**Alternative: Automated Deployment (Legacy Fallback)**

Use this method for development or if ALB setup encounters issues:

```bash
# Use the enhanced deployment script (falls back to LoadBalancer if no ALB)
cd ../scripts
./deploy.sh
```

The script will automatically:
- 🔍 Check for AWS Load Balancer Controller
- ✅ Deploy ALB Ingress if controller is available  
- 🔄 Fall back to LoadBalancer service if no ALB controller
- 🌐 Provide appropriate URLs and configuration instructions

**Manual Deployment (Advanced Users Only)**

```bash
# Apply Kubernetes manifests manually
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

# Deploy ingress (requires ALB controller)
kubectl apply -f ingress.yaml
```

### Step 3: Verify Deployment

```bash
# Check pod status
kubectl get pods -n tasky

# Check service status
kubectl get svc -n tasky

# For ALB deployments - Check ingress status
kubectl get ingress -n tasky

# Get application URL (ALB)
kubectl get ingress tasky-ingress -n tasky -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Get application URL (LoadBalancer - legacy)
kubectl get svc tasky-service -n tasky -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Check for container connection issues to mongo db
kubectl logs -f deployment/tasky-app -n tasky --tail=50

# look for " 27017: connect: connection refused "
```

### Step 4: Test Application

```bash
# For ALB deployments
ALB_URL=$(kubectl get ingress tasky-ingress -n tasky -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
if [ -n "$ALB_URL" ]; then
    echo "Testing ALB deployment: http://$ALB_URL"
    curl -I http://$ALB_URL
else
    # For LoadBalancer deployments (legacy)
    LB_URL=$(kubectl get svc tasky-service -n tasky -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    if [ -n "$LB_URL" ]; then
        echo "Testing LoadBalancer deployment: http://$LB_URL"
        curl -I http://$LB_URL
    else
        echo "No load balancer URL available yet. Check deployment status."
    fi
fi

# Custom domain testing (ALB only)
# After configuring DNS: curl -I http://ideatasky.ryanmcvey.me

# Open in browser
open http://$ALB_URL  # macOS (ALB)
open http://$LB_URL   # macOS (LoadBalancer)
# or
start http://$ALB_URL  # Windows (ALB)
start http://$LB_URL   # Windows (LoadBalancer)
```

## Application Verification and URLs

### Get Current Application URL

```bash
# Comprehensive URL detection script
echo "=== Application URL Detection ==="

# Check for ALB deployment (preferred)
ALB_URL=$(kubectl get ingress tasky-ingress -n tasky -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
if [ -n "$ALB_URL" ]; then
    echo "✅ ALB Deployment Detected"
    echo "Primary URL: http://$ALB_URL"
    echo "Custom Domain (after DNS setup): http://ideatasky.ryanmcvey.me"
    
    # Test ALB health
    echo -n "ALB Health Check: "
    curl -s -o /dev/null -w "%{http_code}" http://$ALB_URL && echo " ✅ OK" || echo " ❌ FAILED"
else
    echo "⚠️  ALB not detected, checking for LoadBalancer..."
    
    # Check for LoadBalancer deployment (fallback)
    LB_URL=$(kubectl get svc tasky-service -n tasky -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    if [ -n "$LB_URL" ]; then
        echo "✅ LoadBalancer Deployment Detected"
        echo "Application URL: http://$LB_URL"
        
        # Test LoadBalancer health
        echo -n "LoadBalancer Health Check: "
        curl -s -o /dev/null -w "%{http_code}" http://$LB_URL && echo " ✅ OK" || echo " ❌ FAILED"
    else
        echo "❌ No load balancer URL available"
        echo "Check deployment status with: kubectl get pods,svc,ingress -n tasky"
    fi
fi
```

### Complete Deployment Status

```bash
# Full deployment verification
echo "=== Tasky Deployment Status ==="

echo "1. Namespace Status:"
kubectl get namespace tasky

echo "2. Pod Status:"
kubectl get pods -n tasky -o wide

echo "3. Service Status:"
kubectl get svc -n tasky

echo "4. Ingress Status (ALB):"
kubectl get ingress -n tasky 2>/dev/null || echo "No ingress found (LoadBalancer deployment)"

echo "5. Recent Pod Logs:"
kubectl logs --tail=10 deployment/tasky-deployment -n tasky

echo "6. Resource Usage:"
kubectl top pods -n tasky 2>/dev/null || echo "Metrics server not available"

echo "7. ALB Controller Status:"
kubectl get pods -n kube-system | grep aws-load-balancer-controller || echo "ALB Controller not installed"
```

### Custom Domain Setup (ALB Only)

After ALB deployment, configure your custom domain:

1. **Get ALB DNS name:**
```bash
ALB_DNS=$(kubectl get ingress tasky-ingress -n tasky -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "ALB DNS: $ALB_DNS"
```

2. **Configure Cloudflare CNAME:**
- Login to Cloudflare dashboard
- Select domain: `ryanmcvey.me`
- Add CNAME record:
  - **Name:** `ideatasky`
  - **Content:** `$ALB_DNS` (the value from above)
  - **Proxy status:** ✅ Proxied (for additional security/performance)

3. **Test custom domain:**
```bash
# Wait 2-5 minutes for DNS propagation, then test
curl -I http://ideatasky.ryanmcvey.me
nslookup ideatasky.ryanmcvey.me
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

### Verify MongoDB Status and Backup

#### Quick MongoDB Status Check

```bash
# Get MongoDB instance information
cd terraform
INSTANCE_ID=$(terraform output -raw mongodb_instance_id)
MONGODB_IP=$(terraform output -raw mongodb_private_ip)
S3_BUCKET=$(terraform output -raw s3_backup_bucket_name)

echo "MongoDB Instance ID: $INSTANCE_ID"
echo "MongoDB Private IP: $MONGODB_IP"
echo "S3 Backup Bucket: $S3_BUCKET"
```

#### Connect to MongoDB Instance and Check Database Status

```bash
# Connect to MongoDB EC2 instance
aws ssm start-session --target $INSTANCE_ID
```

**Once connected to the EC2 instance, run these commands:**

```bash
# Check MongoDB service status
sudo systemctl status mongod

# Check if MongoDB is listening on port 27017
sudo netstat -tlnp | grep 27017

# Check MongoDB configuration
sudo cat /etc/mongod.conf | grep -A 5 -B 5 "bindIp\|port"

# Check MongoDB logs for any errors
sudo tail -20 /var/log/mongodb/mongod.log

# Connect to MongoDB with authentication and run database queries
mongo --host 127.0.0.1:27017 -u taskyadmin -p asimplepass --authenticationDatabase tasky

# Once in MongoDB shell, run these queries:
```

**MongoDB Shell Commands (run after connecting with mongo command above):**

```javascript
// Show current database
db;

// Switch to tasky database
use tasky;

// Show all databases and their sizes
db.adminCommand("listDatabases");

// Show all collections (tables) in current database
show collections;

// Get collection statistics
db.stats();

// Check if users collection exists and count documents
db.users.count();

// Check if todos collection exists and count documents
db.todos.count();

// Show indexes on collections
db.users.getIndexes();
db.todos.getIndexes();

// Get detailed collection stats
db.users.stats();
db.todos.stats();

// Sample a few documents from each collection (if they exist)
db.users.findOne();
db.todos.findOne();

// Check authentication status
db.runCommand({connectionStatus: 1});

// Show current user privileges
db.runCommand({usersInfo: "taskyadmin", showPrivileges: true});

// Exit MongoDB shell
exit;
```

**Additional System Checks (run in EC2 instance shell):**

```bash
# Check disk space
df -h

# Check data directory size
sudo du -sh /data/db

# Check MongoDB process
ps aux | grep mongod

# Check MongoDB version
mongod --version

# Check if backup script exists and is executable
ls -la /opt/mongodb-backup/backup.sh

# Check backup cron job
sudo cat /etc/crontab | grep backup

# Exit from EC2 instance
exit
```

#### MongoDB Backup Verification

```bash
# Manually trigger backup (from EC2 instance)
aws ssm start-session --target $INSTANCE_ID

# On EC2 instance, manually run backup
sudo /opt/mongodb-backup/backup.sh

# Exit EC2 instance
exit

# Check S3 for backups (from local terminal)
aws s3 ls s3://$S3_BUCKET/backups/

# Test public access to latest backup
curl -I https://$S3_BUCKET.s3.$AWS_REGION.amazonaws.com/backups/latest.tar.gz

# Download and verify backup content (optional)
wget https://$S3_BUCKET.s3.$AWS_REGION.amazonaws.com/backups/latest.tar.gz
tar -tzf latest.tar.gz | head -10
```

#### MongoDB Health Check Script

Create a comprehensive health check script:

```bash
# Create MongoDB health check script (run from local terminal)
cat > check_mongodb_health.sh << 'EOF'
#!/bin/bash

# Get Terraform outputs
cd terraform
INSTANCE_ID=$(terraform output -raw mongodb_instance_id)
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
