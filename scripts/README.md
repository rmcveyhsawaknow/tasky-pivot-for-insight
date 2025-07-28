# Scripts Documentation

This directory contains automation scripts for the Tasky application deployment, maintenance, and cost analysis.

## 📋 Table of Contents

- [💰 Cost Analysis & Planning Tools](#cost-analysis--planning-tools)
- [⚙️ Setup & Configuration Scripts](#setup--configuration-scripts)
- [🔄 Deployment & Application Management](#deployment--application-management)
- [🗄️ MongoDB & Database Management](#mongodb--database-management)
- [🔧 Troubleshooting & Monitoring](#troubleshooting--monitoring)
- [📋 Requirements](#requirements)
- [🔧 Common Issues & Solutions](#common-issues--solutions)
- [🤝 Contributing Guidelines](#contributing-guidelines)

## 💰 Cost Analysis & Planning Tools

Comprehensive AWS cost estimation and monitoring tools to help manage and optimize infrastructure expenses. These tools provide various levels of analysis from quick summaries to detailed Bills of Materials.

### [`quick-cost-summary.sh`](quick-cost-summary.sh)
**Simple cost breakdown for immediate reference**

**Purpose:**
- Provides instant cost breakdown based on planned infrastructure
- Shows realistic monthly estimates (~$231/month)
- Quick reference for budgeting and planning decisions

**Usage:**
```bash
./scripts/quick-cost-summary.sh
```

**Sample Output:**
```
💰 Tasky Infrastructure Cost Breakdown
=====================================
EKS Control Plane:     $72.00/month
MongoDB EC2:           $30.24/month  
EKS Worker Nodes (2x): $60.48/month
Application Load Balancer: $16.20/month
NAT Gateway:           $32.40/month
Storage (EBS + S3):    $20.00/month
=====================================
TOTAL MONTHLY COST:    $231.32/month
TOTAL ANNUAL COST:     $2,775.84/year
```

**Features:**
- ✅ Instant execution (< 1 second)
- 📊 Component-by-component breakdown
- 💡 Realistic AWS pricing estimates
- 📈 Monthly and annual projections

### [`cost-terraform.sh`](cost-terraform.sh)
**Comprehensive Terraform cost analysis and BOM generation**

**Purpose:**
- Analyzes Terraform configuration files for resource inventory
- Generates detailed Bills of Materials (BOMs)
- Provides cost optimization recommendations
- Extracts complete resource inventory from Infrastructure-as-Code

**Usage:**
```bash
./scripts/cost-terraform.sh
```

**Features:**
- 📊 Complete Terraform resource analysis
- 💰 Detailed cost breakdown by AWS service
- 📋 Automated Bill of Materials generation
- 🎯 Cost optimization recommendations
- 📈 Annual and monthly cost projections
- 📝 Exportable reports in multiple formats

**Dependencies:**
- AWS CLI configured
- Terraform installed
- jq for JSON parsing
- bc calculator for mathematical operations

### [`advanced-cost-analysis.sh`](advanced-cost-analysis.sh)
**Real-time AWS pricing analysis with optimization recommendations**

**Purpose:**
- Uses AWS Pricing API for live, up-to-date pricing data
- Provides advanced cost projections and modeling
- Generates optimization strategies based on usage patterns
- Annotates Terraform configurations with cost information

**Usage:**
```bash
./scripts/advanced-cost-analysis.sh
```

**Features:**
- 🌐 AWS Pricing API integration for real-time data
- 📊 Advanced cost modeling and projections
- 🎯 Intelligent optimization recommendations
- 📝 Terraform configuration cost annotations
- 💡 Right-sizing suggestions based on actual usage
- 🔄 Comparison with current industry pricing trends

**Dependencies:**
- AWS CLI with pricing:GetProducts permissions
- Internet connectivity for API calls
- bc calculator for complex calculations
- jq for JSON processing

### [`cost-breakdown.sh`](cost-breakdown.sh)
**Live analysis of deployed AWS resources with actual costs**

**Purpose:**
- Analyzes currently deployed AWS resources in real-time
- Compares actual costs vs planned estimates
- Generates real-time cost breakdown from live infrastructure
- Creates detailed BOMs from actively running resources

**Usage:**
```bash
./scripts/cost-breakdown.sh
```

**Features:**
- 🔍 Live AWS resource discovery and inventory
- 💸 Real-time cost analysis from deployed infrastructure
- 📈 Planned vs actual cost comparison with variance analysis
- 📋 Automated BOM generation from live resources
- ⚠️ Budget variance alerts and notifications
- 📊 Resource utilization assessment

**Dependencies:**
- AWS CLI configured with appropriate permissions
- Active AWS resources deployed
- bc calculator for mathematical operations

## ⚙️ Setup & Configuration Scripts

Initial environment setup and one-time configuration scripts for development environments, AWS integration, and GitHub Actions. These scripts embody DevOps automation principles, eliminating manual toil and ensuring consistent, repeatable deployments across teams.

### [`setup-codespace.sh`](setup-codespace.sh)
**Automated development environment setup**

**Purpose:**
- Installs and configures all required development tools
- Sets up AWS CLI v2 with latest features
- Installs Terraform v1.0+ with version verification
- Configures development environment for optimal workflow

**Usage:**
```bash
./scripts/setup-codespace.sh
```

**Features:**
- ✅ Automated tool installation and configuration
- 🔧 Environment validation and health checks
- 📦 Dependency management for consistent environments
- 🚀 Zero-configuration developer onboarding

### [`setup-aws-oidc.sh`](setup-aws-oidc.sh) ✨ **Updated**
**Secure AWS OIDC provider setup for GitHub Actions**

**Purpose:**
- Creates AWS OIDC identity provider for credential-less authentication
- Sets up IAM roles with appropriate trust policies
- Configures Terraform backend S3 bucket and DynamoDB table
- Enables secure, automated deployments without long-lived credentials

**Usage:**
```bash
./scripts/setup-aws-oidc.sh
```

**Recent Improvements:**
- 🔧 **Fixed**: Added `AWS_PAGER=""` to prevent script interruptions
- 🚀 **Enhanced**: Improved error handling and progress feedback
- 🔍 **Reliable**: Eliminates pager-related hang issues in automated environments

**Features:**
- 🔐 Zero-credential GitHub Actions authentication
- 🏗️ Automated Terraform backend provisioning
- 📊 Comprehensive setup validation and verification
- 🎯 Production-ready security configurations

### [`generate-github-config.sh`](generate-github-config.sh) ✨ **New**
**GitHub repository configuration value generator**

**Purpose:**
- Generates secure passwords and JWT secrets
- Provides exact configuration values for manual GitHub setup
- Works reliably in all environments including Codespaces
- Alternative to automated GitHub CLI configuration

**Usage:**
```bash
./scripts/generate-github-config.sh
```

**Features:**
- 🔐 Cryptographically secure secret generation
- 📋 Copy-paste ready configuration values
- 🔗 Direct links to GitHub repository settings
- 💻 Works in restricted environments (Codespaces, CI/CD)

**Why This Approach:**
- **Culture**: Promotes transparency with clear manual steps
- **Automation**: Automates value generation while allowing manual verification
- **Lean**: Eliminates waste from failed automated attempts
- **Measurement**: Provides immediate feedback on configuration status
- **Sharing**: Clear instructions enable team collaboration

### [`setup-github-repo.sh`](setup-github-repo.sh) ⚠️ **Known Issues**
**Automated GitHub repository configuration (Limited Functionality)**

**Purpose:**
- Attempts automated GitHub secrets and variables configuration
- Falls back to manual instructions when API permissions are insufficient

**Usage:**
```bash
./scripts/setup-github-repo.sh
```

**Known Limitations:**
- ❌ Fails in GitHub Codespaces due to API token permissions
- ❌ Requires elevated GitHub token permissions not available by default
- ⚠️ **Recommendation**: Use `generate-github-config.sh` instead

**Troubleshooting:**
If this script fails with "Resource not accessible by integration" errors, this is expected behavior in Codespaces. The GitHub token provided automatically lacks the necessary permissions to manage repository secrets programmatically.

### [`verify-oidc-setup.sh`](verify-oidc-setup.sh) ✨ **New**
**AWS OIDC setup validation and verification**

**Purpose:**
- Validates all AWS resources created by OIDC setup
- Provides GitHub configuration instructions
- Troubleshoots common setup issues

**Usage:**
```bash
./scripts/verify-oidc-setup.sh
```

**Features:**
- ✅ IAM role validation
- ✅ S3 bucket verification
- ✅ DynamoDB table status check
- 📋 GitHub configuration guidance

### [`complete-oidc-setup.sh`](complete-oidc-setup.sh) ✨ **New**
**Fallback OIDC setup completion script**

**Purpose:**
- Completes any remaining OIDC setup steps
- Handles edge cases and incomplete setups
- Provides comprehensive configuration output

**Usage:**
```bash
./scripts/complete-oidc-setup.sh
```

**Features:**
- 🔄 Completes interrupted setups
- 📊 Comprehensive status reporting
- 🎯 Production-ready configuration validation
- ✅ Colorized output with clear status indicators
- 🔧 Intelligent tool detection and version comparison
- 📦 Automated installation with comprehensive error handling
- 📋 Final verification and next steps guidance
- 🛡️ Safe to run multiple times (idempotent behavior)
- 🔄 Automatic cleanup of previous installations

**Supported Platforms:**
- ✅ GitHub Codespaces (Ubuntu 24.04)
- ✅ Ubuntu 20.04+ (WSL2, native installations)
- ✅ Debian-based Linux distributions
- ⚠️ Other Linux distributions (may require modifications)

### [`setup-aws-oidc.sh`](setup-aws-oidc.sh)
**One-time AWS OIDC provider and IAM role configuration**

**Purpose:**
- Configures AWS OIDC identity provider for GitHub Actions
- Creates IAM roles with appropriate trust policies
- Enables credential-less authentication for CI/CD pipelines
- Sets up secure, temporary token-based AWS access

**Usage:**
```bash
./scripts/setup-aws-oidc.sh
```

**Security Benefits:**
- 🔐 Eliminates need for long-lived AWS access keys
- 🎫 Uses temporary, scoped tokens for enhanced security
- 🛡️ Implements least-privilege access principles
- 📝 Creates audit trail for all AWS operations

**Prerequisites:**
- AWS CLI configured with administrative permissions
- GitHub repository with Actions enabled

### [`setup-github-repo.sh`](setup-github-repo.sh)
**GitHub repository secrets and variables automation**

**Purpose:**
- Automates GitHub repository configuration for CI/CD
- Sets up required secrets and environment variables
- Configures repository settings for optimal workflow
- Integrates with AWS OIDC for secure deployments

**Usage:**
```bash
./scripts/setup-github-repo.sh
```

**Features:**
- 🔧 Automated secrets management
- 📋 Repository variables configuration
- 🔒 Security settings optimization
- 📊 Environment setup for multiple deployment stages

**Prerequisites:**
- GitHub CLI (gh) authenticated
- Repository admin permissions

### [`check-versions.sh`](check-versions.sh)
**Quick verification of tool installations and minimum version requirements**

**Purpose:**
- Validates that all required tools are properly installed
- Verifies minimum version requirements are met
- Provides quick status overview of development environment
- Identifies tools that need updates or installation

**Usage:**
```bash
./scripts/check-versions.sh
```

**Output Format:**
- ✅ Green checkmarks for properly installed tools
- ⚠️ Yellow warnings for tools below minimum versions
- ❌ Red X marks for missing tools
- 📋 Summary of environment readiness

## 🔄 Deployment & Application Management

Scripts for deploying applications, managing Kubernetes resources, and orchestrating infrastructure components.

### [`deploy.sh`](deploy.sh)
**Tasky application deployment to Kubernetes**

**Purpose:**
- Deploys the Tasky application to EKS cluster
- Configures necessary Kubernetes resources
- Validates deployment health and connectivity
- Manages application lifecycle and updates

**Usage:**
```bash
./scripts/deploy.sh
```

**Features:**
- 🚀 Complete application deployment automation
- 🔧 Kubernetes resource configuration management
- 💾 Secret and ConfigMap management
- 🏥 Health check validation and monitoring
- 📋 Deployment status reporting

**Prerequisites:**
- kubectl configured for target EKS cluster
- Terraform infrastructure deployed
- Kubernetes cluster accessible

### [`setup-alb-controller.sh`](setup-alb-controller.sh)
**AWS Load Balancer Controller installation and ALB Ingress deployment**

**Purpose:**
- Installs AWS Load Balancer Controller using Helm
- Configures IRSA (IAM Role for Service Accounts) integration
- Deploys Tasky application with ALB Ingress
- Provides ALB DNS name for domain configuration

**Usage:**
```bash
./scripts/setup-alb-controller.sh
```

**Features:**
- ✅ Automatic prerequisite checking and validation
- 🔧 Reads cluster configuration from Terraform outputs
- 📦 Installs and configures AWS Load Balancer Controller
- 🌐 Provides step-by-step domain configuration instructions
- 🛡️ Comprehensive error handling and status reporting
- 💰 Cost-optimized Layer 7 load balancing setup

**Benefits:**
- Cost-effective Application Load Balancer management
- Kubernetes-native ingress configuration
- Custom domain support (ideatasky.ryanmcvey.me)
- Production-ready health checks and SSL configuration

### [`manage-secrets.sh`](manage-secrets.sh)
**Kubernetes secrets management with Terraform integration**

**Purpose:**
- Manages Kubernetes secrets with consistent parameters
- Integrates with Terraform outputs for dynamic configuration
- Validates secret creation and updates
- Provides comparison between file-based and cluster secrets

**Usage:**
```bash
./scripts/manage-secrets.sh
```

**Features:**
- 🔐 Consistent secret management across environments
- 🔄 Terraform integration for dynamic values
- ✅ Secret validation and verification
- 📊 Comparison tools for troubleshooting

## 🗄️ MongoDB & Database Management

MongoDB management, backup, monitoring, and troubleshooting tools for database operations.

### [`mongodb-backup.sh`](mongodb-backup.sh)
**Automated MongoDB backups to S3 with public access**

**Purpose:**
- Creates automated MongoDB backups with 5-minute schedule
- Uploads backups to S3 bucket with public read access
- Implements backup rotation and cleanup policies
- Generates demo-ready JSON exports for easy viewing

**Usage:**
```bash
# Automatically scheduled via cron
# Manual execution:
./scripts/mongodb-backup.sh
```

**Features:**
- ⏰ Automated 5-minute backup schedule for demos
- 📁 Creates both latest.tar.gz (overwriting) and historical backups
- 📄 JSON exports (todos.json, users.json) for text viewing
- 🌐 Public S3 URLs for easy access during presentations
- 🧹 Intelligent cleanup and rotation policies

**Output Examples:**
- Public URLs: `https://bucket-name.s3.amazonaws.com/backups/latest.tar.gz`
- Historical: `https://bucket-name.s3.amazonaws.com/backups/cron_JULIAN_DATE.tar.gz`

### [`check-mongodb-status.sh`](check-mongodb-status.sh)
**Comprehensive MongoDB EC2 instance health monitoring**

**Purpose:**
- Checks EC2 instance state and overall health
- Verifies CloudWatch logging setup and configuration
- Tests MongoDB connectivity from various sources
- Provides detailed troubleshooting guidance

**Usage:**
```bash
./scripts/check-mongodb-status.sh
```

**Features:**
- 🔍 Complete infrastructure health assessment
- 📊 CloudWatch log stream verification
- 🔗 MongoDB connectivity testing from EKS pods
- 🚀 Quick troubleshooting command suggestions
- 📋 Comprehensive status summary and next steps

**Checks Performed:**
- EC2 instance state and health checks
- MongoDB process status and connectivity
- CloudWatch agent configuration
- Network connectivity from EKS cluster
- Backup system functionality

### [`view-mongodb-logs.sh`](view-mongodb-logs.sh)
**Interactive CloudWatch log viewer for MongoDB operations**

**Purpose:**
- Provides easy access to different MongoDB log types
- Enables real-time log following for troubleshooting
- Lists available log streams with filtering options
- Simplifies CloudWatch log navigation and analysis

**Usage:**
```bash
# Show available log types and options
./scripts/view-mongodb-logs.sh --help

# View user-data execution logs
./scripts/view-mongodb-logs.sh user-data

# Follow MongoDB server logs in real-time
./scripts/view-mongodb-logs.sh mongod --follow

# Show last 50 lines of setup logs
./scripts/view-mongodb-logs.sh mongodb-setup --lines 50

# List all available log streams
./scripts/view-mongodb-logs.sh --list
```

**Available Log Types:**
- `user-data` - Initial EC2 setup script execution
- `mongodb-setup` - Detailed MongoDB installation and configuration
- `mongod` - MongoDB server operation logs
- `backup` - Backup operation logs and status
- `cloud-init` - Cloud-init execution and system setup
- `cloud-init-output` - Cloud-init output and error messages

## 🔧 Troubleshooting & Monitoring

Diagnostic and monitoring tools for infrastructure and application debugging.

### [`test-backup-from-codespace.sh`](test-backup-from-codespace.sh)
**Backup functionality testing from development environments**

**Purpose:**
- Tests backup functionality from GitHub Codespaces
- Validates S3 connectivity and permissions
- Verifies backup process end-to-end
- Provides development environment testing capabilities

**Usage:**
```bash
./scripts/test-backup-from-codespace.sh
```

**Features:**
- 🔍 S3 connectivity validation
- 📋 Backup process verification
- 🌐 Public URL accessibility testing
- 🛠️ Development environment compatibility

## 📋 Requirements

### Minimum Tool Versions
- **AWS CLI**: v2.0.0+ (for latest features and security)
- **Terraform**: v1.0.0+ (for module compatibility)
- **kubectl**: Any recent version (v1.20+)
- **Docker**: Any recent version (v20.0+)
- **Git**: Any recent version (v2.25+)
- **Helm**: v3.0+ (for AWS Load Balancer Controller)
- **jq**: v1.6+ (for JSON processing)
- **bc**: Any version (for mathematical calculations)

### Supported Platforms
- ✅ GitHub Codespaces (Ubuntu 24.04) - Fully tested and supported
- ✅ Ubuntu 20.04+ (WSL2, native) - Primary development platform
- ✅ Debian-based Linux distributions - Compatible with modifications
- ⚠️ Other Linux distributions - May require script modifications
- ❌ macOS/Windows - Not currently supported (contributions welcome)

### AWS Permissions Required
- **IAM**: Create roles, policies, OIDC providers
- **EKS**: Cluster management and node group operations
- **EC2**: Instance management, VPC operations, security groups
- **S3**: Bucket operations, object management
- **CloudWatch**: Log access and metric collection
- **Application Load Balancer**: ALB creation and management

## 🔧 Common Issues & Solutions

### Installation Issues

**Script permission denied:**
```bash
chmod +x scripts/*.sh
```

**Package installation fails:**
```bash
sudo apt update && sudo apt upgrade -y
```

**AWS CLI installation conflicts:**
```bash
# Remove old AWS CLI v1 if needed
sudo apt remove awscli
sudo pip uninstall awscli
# Then run setup script
./scripts/setup-codespace.sh
```

**bc calculator missing:**
```bash
sudo apt update && sudo apt install -y bc
```

### AWS Configuration Issues

**AWS credentials not configured:**
```bash
aws configure
# OR for OIDC
aws sts get-caller-identity
```

**Terraform backend issues:**
```bash
terraform init -reconfigure
```

**kubectl not configured:**
```bash
aws eks update-kubeconfig --region us-east-1 --name your-cluster-name
```

### Script-Specific Troubleshooting

**Cost analysis scripts fail:**
- Ensure bc calculator is installed: `sudo apt install -y bc`
- Verify AWS CLI permissions for pricing API
- Check internet connectivity for real-time pricing

**MongoDB scripts timeout:**
- Verify EC2 instance is running
- Check security group rules for port 27017
- Ensure MongoDB service is started

**Backup scripts fail:**
- Verify S3 bucket permissions
- Check CloudWatch agent configuration
- Ensure cron service is running

## 🤝 Contributing Guidelines

When modifying or adding scripts:

1. **Testing Requirements:**
   - Test in a fresh GitHub Codespace environment
   - Verify idempotent behavior (safe to run multiple times)
   - Test error scenarios and edge cases

2. **Code Standards:**
   - Add comprehensive error handling and user feedback
   - Include detailed help text and usage examples
   - Follow established coding style and conventions
   - Use consistent output formatting with colors and symbols

3. **Documentation:**
   - Update this README.md for any new features or changes
   - Include inline comments for complex logic
   - Provide usage examples and expected output
   - Document all dependencies and prerequisites

4. **Security Considerations:**
   - Never hardcode secrets or sensitive information
   - Use appropriate AWS IAM permissions (least privilege)
   - Validate inputs and sanitize user data
   - Follow secure coding practices

5. **Backwards Compatibility:**
   - Maintain compatibility with existing workflows
   - Use feature flags for breaking changes
   - Provide migration paths for deprecated features

For detailed script usage examples, troubleshooting guides, and contribution guidelines, see the complete documentation above.

**📖 Quick Reference:**
- 💰 **Cost Analysis**: Use `quick-cost-summary.sh` for immediate estimates
- ⚙️ **Setup**: Run `setup-codespace.sh` for development environment
- 🔄 **Deploy**: Use `setup-alb-controller.sh` for production deployment  
- 🗄️ **MongoDB**: Use `check-mongodb-status.sh` for database monitoring
- 🔧 **Debug**: Use `view-mongodb-logs.sh` for troubleshooting
