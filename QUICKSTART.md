# 🚀 Quick Start Guide - Deploy Tasky from Scratch

This guide will help you deploy the complete Tasky application infrastructure and application using GitHub Actions in under 30 minutes.

## Prerequisites ✅

- [x] AWS Account with administrative access
- [x] GitHub account with repository access
- [x] AWS CLI installed and configured locally (optional, for OIDC setup)
- [x] GitHub CLI installed (optional, for automated setup)

## Option A: Automated Setup (Recommended) 🤖

### Step 1: Clone and Setup Repository
```bash
git clone https://github.com/rmcveyhsawaknow/tasky-pivot-for-insight.git
cd tasky-pivot-for-insight
```

### Step 2: Run Setup Scripts
```bash
# Setup AWS OIDC and Terraform backend (one-time)
./scripts/setup-aws-oidc.sh

# Configure GitHub repository secrets and variables
./scripts/setup-github-repo.sh
```

### Step 3: Deploy via GitHub Actions
```bash
# Create deployment branch and push
git checkout -b deploy/v12-quickstart
git add .
git commit -m "feat: initial deployment via GitHub Actions"
git push origin deploy/v12-quickstart
```

**⏱️ Deployment time: 15-20 minutes**

### Step 4: Access Your Application
After deployment completes, check the workflow output for:
- ✅ Application URL (via ALB)
- ✅ MongoDB backup URLs
- ✅ Cluster access commands

## Option B: Manual Setup 🔧

### Step 1: Configure AWS OIDC
```bash
# Run OIDC setup
./scripts/setup-aws-oidc.sh

# Note the IAM role ARN output
```

### Step 2: Configure GitHub Secrets
Go to: `https://github.com/rmcveyhsawaknow/tasky-pivot-for-insight/settings/secrets/actions`

Add these **Repository Secrets**:
- `AWS_ROLE_ARN`: `arn:aws:iam::YOUR-ACCOUNT-ID:role/GitHubActionsTerraformRole`
- `MONGODB_USERNAME`: `taskyadmin`
- `MONGODB_PASSWORD`: `<generate-secure-password>`
- `JWT_SECRET`: `<generate-secure-secret>`

### Step 3: Configure GitHub Variables
Go to: `https://github.com/rmcveyhsawaknow/tasky-pivot-for-insight/settings/variables/actions`

Add these **Repository Variables**:
- `AWS_REGION`: `us-east-1`
- `PROJECT_NAME`: `tasky`
- `ENVIRONMENT`: `dev`
- `STACK_VERSION`: `v12`
- `MONGODB_INSTANCE_TYPE`: `t3.micro`
- `VPC_CIDR`: `10.0.0.0/16`
- `MONGODB_DATABASE_NAME`: `go-mongodb`

### Step 4: Deploy
```bash
git checkout -b deploy/manual-setup
git add .
git commit -m "feat: manual GitHub Actions deployment"
git push origin deploy/manual-setup
```

## What Gets Deployed 🏗️

### Infrastructure (via Terraform)
- **VPC**: Custom VPC with public/private subnets
- **EKS Cluster**: Managed Kubernetes cluster
- **MongoDB**: EC2 instance with authentication
- **S3 Bucket**: Backup storage with public read access
- **Load Balancer**: AWS Application Load Balancer via Kubernetes Ingress

### Application (via Kubernetes)
- **Tasky App**: Go application with 3 replicas
- **Configuration**: ConfigMaps and Secrets
- **Ingress**: Public access via ALB
- **Monitoring**: Health checks and logging

## Monitoring Deployment 📊

### GitHub Actions Dashboard
```bash
# View workflow runs
gh run list --repo rmcveyhsawaknow/tasky-pivot-for-insight

# Watch active deployment
gh run watch --repo rmcveyhsawaknow/tasky-pivot-for-insight

# View detailed logs
gh run view --repo rmcveyhsawaknow/tasky-pivot-for-insight --log
```

### AWS Console
- **EKS**: `aws eks list-clusters`
- **EC2**: Check MongoDB instance in `us-east-1`
- **S3**: Verify backup bucket creation
- **CloudFormation**: Monitor resource creation

## Accessing Your Application 🌐

### Application URLs
After deployment, find these in workflow output:
```bash
# Application URL (from workflow)
https://your-alb-dns-name.us-east-1.elb.amazonaws.com

# Health check
curl https://your-alb-dns-name.us-east-1.elb.amazonaws.com/health

# Application features
# - User registration: /register
# - User login: /login  
# - Todo management: /todos
```

### MongoDB Access
```bash
# Get MongoDB IP from Terraform output
kubectl get configmap app-config -n tasky -o yaml

# Connect via EC2 (if needed)
ssh -i your-key.pem ec2-user@mongodb-ip
```

### Backup Access
```bash
# Public backup URLs (from workflow output)
https://tasky-backup-bucket.s3.us-east-1.amazonaws.com/backups/latest.tar.gz
```

## Troubleshooting 🔍

### Common Issues

**1. OIDC Setup Fails**
```bash
# Check AWS credentials
aws sts get-caller-identity

# Verify IAM permissions
aws iam list-roles | grep GitHubActions
```

**2. Workflow Fails**
```bash
# Check secrets configuration
gh secret list --repo rmcveyhsawaknow/tasky-pivot-for-insight

# Review workflow logs
gh run view --repo rmcveyhsawaknow/tasky-pivot-for-insight --log
```

**3. Application Not Accessible**
```bash
# Check ALB status
kubectl get ingress -n tasky

# Verify pods are running  
kubectl get pods -n tasky

# Check service endpoints
kubectl get svc -n tasky
```

**4. MongoDB Connection Issues**
```bash
# Check MongoDB logs
./scripts/view-mongodb-logs.sh

# Verify security groups
aws ec2 describe-security-groups --group-names tasky-mongodb-sg
```

### Cleanup (if needed)
```bash
# Destroy infrastructure
cd terraform/
terraform destroy -auto-approve

# Or use the safe destroy script
./safe-destroy.sh
```

## Next Steps 🎯

### Development Workflow
1. **Make Changes**: Edit application code or infrastructure
2. **Create PR**: Pull request triggers validation workflow
3. **Review**: Check Terraform plan and cost estimation  
4. **Deploy**: Merge to `main` or push to `deploy/*` branch

### Production Readiness
1. **Environment Protection**: Add approval requirements
2. **Custom Domain**: Configure Route 53 DNS
3. **SSL/TLS**: Add SSL certificate to ALB
4. **Monitoring**: Integrate CloudWatch/Prometheus
5. **Scaling**: Configure HPA for application pods

### Security Enhancements
1. **Network Policies**: Restrict pod-to-pod communication
2. **Pod Security**: Implement Pod Security Standards
3. **Secrets Management**: Integrate AWS Secrets Manager
4. **Image Scanning**: Add vulnerability scanning

## Support 💬

- **Documentation**: Check `/docs` folder for detailed guides
- **Issues**: Open GitHub issue for bugs or feature requests
- **Architecture**: See `/diagrams` for infrastructure visualization
- **Scripts**: Use `/scripts` for operational tasks

---

**🎉 Congratulations! You now have a fully automated, production-ready Tasky deployment!**

**Total deployment time: ~20 minutes | Infrastructure cost: ~$25/month**
