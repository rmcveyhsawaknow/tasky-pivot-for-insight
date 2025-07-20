# Scripts Documentation

This directory contains automation scripts for the Tasky application deployment and maintenance.

## Setup Scripts

### `setup-codespace.sh`
Automated setup script for GitHub Codespaces or fresh Linux environments.

**Purpose:**
- Installs AWS CLI v2 (if missing or upgrading from v1)
- Installs Terraform v1.0+ (if missing or below minimum version)
- Checks versions of pre-installed tools (Git, Docker, kubectl)
- Provides comprehensive verification and next steps

**Usage:**
```bash
./scripts/setup-codespace.sh
```

**Features:**
- ✅ Colorized output with clear status indicators
- 🔧 Intelligent tool detection and version comparison
- 📦 Automated installation with error handling
- 📋 Final verification and next steps guidance
- 🛡️ Safe to run multiple times (idempotent)

### `check-versions.sh`
Quick version checker that verifies tool installations without installing anything.

## MongoDB Troubleshooting Scripts

### `check-mongodb-status.sh`
Comprehensive status checker for the MongoDB EC2 instance.

**Purpose:**
- Checks EC2 instance state and health
- Verifies CloudWatch logging setup
- Tests MongoDB connectivity
- Provides troubleshooting guidance

**Usage:**
```bash
./scripts/check-mongodb-status.sh
```

**Features:**
- 🔍 Complete infrastructure health check
- 📊 CloudWatch log stream verification
- 🚀 Quick troubleshooting commands
- 📋 Status summary and next steps

### `view-mongodb-logs.sh`
Interactive log viewer for MongoDB CloudWatch logs.

**Purpose:**
- View different log types from CloudWatch
- Follow logs in real-time
- List available log streams

**Usage:**
```bash
# Show available log types
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
- `user-data` - Initial setup script execution
- `mongodb-setup` - Detailed MongoDB installation logs
- `mongod` - MongoDB server logs
- `backup` - Backup operation logs
- `cloud-init` - Cloud-init execution logs
- `cloud-init-output` - Cloud-init output logs

**Purpose:**
- Checks if all required tools are installed
- Verifies minimum version requirements
- Provides quick status overview

**Usage:**
```bash
./scripts/check-versions.sh
```

**Output:**
- ✅ Green checkmarks for properly installed tools
- ⚠️ Yellow warnings for tools below minimum versions
- ❌ Red X marks for missing tools

## Deployment Scripts

### `deploy.sh`
Application deployment script for Kubernetes environments.

**Purpose:**
- Deploys the Tasky application to EKS cluster
- Configures necessary Kubernetes resources
- Validates deployment health

### `mongodb-backup.sh`
MongoDB backup automation script.

**Purpose:**
- Creates automated MongoDB backups
- Uploads backups to S3 bucket with public access
- Implements backup rotation and cleanup

## Requirements

### Minimum Tool Versions
- **AWS CLI**: v2.0.0+
- **Terraform**: v1.0.0+
- **kubectl**: Any recent version
- **Docker**: Any recent version
- **Git**: Any recent version

### Supported Platforms
- ✅ GitHub Codespaces (Ubuntu 24.04)
- ✅ Ubuntu 20.04+ (WSL2, native)
- ✅ Debian-based Linux distributions
- ⚠️ Other Linux distributions (may require modifications)

## Troubleshooting

### Common Issues

**Script permission denied:**
```bash
chmod +x scripts/*.sh
```

**Package installation fails:**
```bash
sudo apt update
sudo apt upgrade -y
```

**AWS CLI installation conflicts:**
```bash
# Remove old AWS CLI v1 if needed
sudo apt remove awscli
# Then run setup script
./scripts/setup-codespace.sh
```

### Manual Installation Commands

If the automated script fails, you can run these commands manually:

**AWS CLI v2:**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

**Terraform:**
```bash
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

## Contributing

When modifying scripts:
1. Test in a fresh Codespace environment
2. Ensure idempotent behavior (safe to run multiple times)
3. Add appropriate error handling and user feedback
4. Update this documentation for any new features
5. Follow the established coding style and conventions
