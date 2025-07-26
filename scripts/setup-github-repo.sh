#!/bin/bash

# ==============================================================================
# GITHUB REPOSITORY SETUP SCRIPT
# ==============================================================================
# This script helps configure GitHub repository secrets and variables
# for automated deployments with GitHub Actions
# ==============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration variables
GITHUB_REPO="${GITHUB_REPO:-rmcveyhsawaknow/tasky-pivot-for-insight}"
AWS_ACCOUNT_ID=""

# Show usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --repo REPO          GitHub repository (default: rmcveyhsawaknow/tasky-pivot-for-insight)"
    echo "  --account-id ID      AWS Account ID (will be detected if not provided)"
    echo "  --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Use defaults and detect account ID"
    echo "  $0 --repo myorg/myrepo               # Custom repository"
    echo "  $0 --account-id 123456789012         # Specify account ID"
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --repo)
            GITHUB_REPO="$2"
            shift 2
            ;;
        --account-id)
            AWS_ACCOUNT_ID="$2"
            shift 2
            ;;
        --help)
            usage
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v gh &> /dev/null; then
        print_warning "GitHub CLI (gh) is not installed. Manual configuration required."
        echo "Install with: brew install gh  # macOS"
        echo "             or sudo apt install gh  # Ubuntu"
        return 1
    fi
    
    if ! gh auth status &> /dev/null; then
        print_warning "GitHub CLI is not authenticated. Please run: gh auth login"
        return 1
    fi
    
    if [ -z "$AWS_ACCOUNT_ID" ]; then
        if command -v aws &> /dev/null && aws sts get-caller-identity &> /dev/null; then
            AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
            print_success "Detected AWS Account ID: $AWS_ACCOUNT_ID"
        else
            print_error "AWS Account ID not provided and cannot be detected"
            echo "Please provide --account-id or configure AWS CLI"
            exit 1
        fi
    fi
    
    return 0
}

# Generate secure secrets
generate_secrets() {
    print_status "Generating secure secrets..."
    
    # Generate MongoDB password
    MONGODB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    print_success "Generated MongoDB password"
    
    # Generate JWT secret
    JWT_SECRET=$(openssl rand -base64 64 | tr -d "=+/" | cut -c1-50)
    print_success "Generated JWT secret"
}

# Configure GitHub secrets using gh CLI
configure_secrets_with_cli() {
    print_status "Configuring GitHub secrets with CLI..."
    
    local role_arn="arn:aws:iam::${AWS_ACCOUNT_ID}:role/GitHubActionsTerraformRole"
    
    # Set repository secrets
    echo "$role_arn" | gh secret set AWS_ROLE_ARN --repo "$GITHUB_REPO"
    echo "taskyadmin" | gh secret set MONGODB_USERNAME --repo "$GITHUB_REPO"
    echo "$MONGODB_PASSWORD" | gh secret set MONGODB_PASSWORD --repo "$GITHUB_REPO"
    echo "$JWT_SECRET" | gh secret set JWT_SECRET --repo "$GITHUB_REPO"
    
    print_success "GitHub secrets configured successfully"
}

# Configure GitHub variables using gh CLI
configure_variables_with_cli() {
    print_status "Configuring GitHub variables with CLI..."
    
    # Set repository variables
    gh variable set AWS_REGION --body "us-east-1" --repo "$GITHUB_REPO"
    gh variable set PROJECT_NAME --body "tasky" --repo "$GITHUB_REPO"
    gh variable set ENVIRONMENT --body "dev" --repo "$GITHUB_REPO"
    gh variable set STACK_VERSION --body "v12" --repo "$GITHUB_REPO"
    gh variable set MONGODB_INSTANCE_TYPE --body "t3.micro" --repo "$GITHUB_REPO"
    gh variable set VPC_CIDR --body "10.0.0.0/16" --repo "$GITHUB_REPO"
    gh variable set MONGODB_DATABASE_NAME --body "go-mongodb" --repo "$GITHUB_REPO"
    
    print_success "GitHub variables configured successfully"
}

# Output manual configuration instructions
output_manual_configuration() {
    local role_arn="arn:aws:iam::${AWS_ACCOUNT_ID}:role/GitHubActionsTerraformRole"
    
    echo ""
    print_warning "Manual GitHub configuration required"
    echo ""
    print_status "Navigate to: https://github.com/$GITHUB_REPO/settings/secrets/actions"
    echo ""
    print_status "=== REPOSITORY SECRETS ==="
    echo "Add these secrets (Settings > Secrets and variables > Actions > Repository secrets):"
    echo ""
    echo "AWS_ROLE_ARN:"
    echo "$role_arn"
    echo ""
    echo "MONGODB_USERNAME:"
    echo "taskyadmin"
    echo ""
    echo "MONGODB_PASSWORD:"
    echo "$MONGODB_PASSWORD"
    echo ""
    echo "JWT_SECRET:"
    echo "$JWT_SECRET"
    echo ""
    print_status "=== REPOSITORY VARIABLES ==="
    echo "Add these variables (Settings > Secrets and variables > Actions > Variables):"
    echo ""
    echo "AWS_REGION: us-east-1"
    echo "PROJECT_NAME: tasky"
    echo "ENVIRONMENT: dev"
    echo "STACK_VERSION: v12"
    echo "MONGODB_INSTANCE_TYPE: t3.micro"
    echo "VPC_CIDR: 10.0.0.0/16"
    echo "MONGODB_DATABASE_NAME: go-mongodb"
}

# Update Terraform backend configuration
update_terraform_backend() {
    print_status "Updating Terraform backend configuration..."
    
    local bucket_name="tasky-terraform-state-${AWS_ACCOUNT_ID}"
    local backend_file="terraform/backend.tf"
    
    if [ -f "$backend_file" ]; then
        # Replace ACCOUNT_ID placeholder with actual account ID
        sed -i "s/ACCOUNT_ID/$AWS_ACCOUNT_ID/g" "$backend_file"
        print_success "Updated $backend_file with account ID: $AWS_ACCOUNT_ID"
    else
        print_warning "Backend configuration file not found: $backend_file"
    fi
}

# Create deployment branch
create_deployment_branch() {
    print_status "Creating deployment branch..."
    
    local branch_name="deploy/v12-automation"
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_warning "Not in a git repository. Skipping branch creation."
        return
    fi
    
    # Create and switch to deployment branch
    if git checkout -b "$branch_name" 2>/dev/null; then
        print_success "Created new branch: $branch_name"
    else
        print_warning "Branch $branch_name already exists or cannot be created"
        git checkout "$branch_name" 2>/dev/null || true
    fi
    
    echo ""
    print_status "Next steps:"
    echo "1. Commit your changes: git add . && git commit -m 'feat: setup GitHub Actions CI/CD'"
    echo "2. Push the branch: git push origin $branch_name"
    echo "3. This will trigger the terraform-apply workflow"
}

# Validate configuration
validate_configuration() {
    print_status "Validating configuration..."
    
    # Check if secrets were set (requires gh CLI)
    if command -v gh &> /dev/null && gh auth status &> /dev/null; then
        local secrets_count=$(gh secret list --repo "$GITHUB_REPO" 2>/dev/null | wc -l || echo "0")
        if [ "$secrets_count" -gt 0 ]; then
            print_success "GitHub secrets are configured"
        else
            print_warning "No GitHub secrets found. Manual configuration may be required."
        fi
    fi
    
    # Check Terraform backend file
    if grep -q "$AWS_ACCOUNT_ID" terraform/backend.tf 2>/dev/null; then
        print_success "Terraform backend configuration updated"
    else
        print_warning "Terraform backend may need manual update"
    fi
}

# Main execution
main() {
    echo "🔧 GitHub Repository Setup for Tasky CI/CD"
    echo "Repository: $GITHUB_REPO"
    echo "AWS Account ID: ${AWS_ACCOUNT_ID:-'<to be detected>'}"
    echo ""
    
    # Check if CLI tools are available
    if check_prerequisites; then
        generate_secrets
        configure_secrets_with_cli
        configure_variables_with_cli
        print_success "✅ Automated configuration completed!"
    else
        generate_secrets
        output_manual_configuration
        print_warning "⚠️ Manual configuration required due to missing CLI tools"
    fi
    
    update_terraform_backend
    create_deployment_branch
    validate_configuration
    
    echo ""
    print_success "🎉 Repository setup complete!"
    echo ""
    print_status "=== NEXT STEPS ==="
    echo "1. Verify GitHub secrets and variables are configured"
    echo "2. Commit and push your changes to trigger deployment"
    echo "3. Monitor the GitHub Actions workflow for successful deployment"
    echo "4. Access your application via the ALB URL provided in the workflow output"
    echo ""
    print_status "=== USEFUL COMMANDS ==="
    echo "# View workflow runs:"
    echo "gh run list --repo $GITHUB_REPO"
    echo ""
    echo "# Watch a specific workflow run:"
    echo "gh run watch --repo $GITHUB_REPO"
    echo ""
    echo "# View workflow logs:"
    echo "gh run view --repo $GITHUB_REPO --log"
}

# Run main function
main "$@"
