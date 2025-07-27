#!/bin/bash

# Tasky Application - Codespace Setup Script
# This script installs required tools and validates the environment for AWS deployment

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check version and compare with minimum required
check_version() {
    local tool="$1"
    local min_version="$2"
    local current_version="$3"
    
    log_info "Checking $tool version: $current_version"
    
    # Simple version comparison (works for most semantic versions)
    if [ "$current_version" = "$min_version" ] || [ "$(printf '%s\n' "$min_version" "$current_version" | sort -V | head -n1)" = "$min_version" ]; then
        log_success "$tool version $current_version meets minimum requirement ($min_version)"
        return 0
    else
        log_warning "$tool version $current_version is below minimum requirement ($min_version)"
        return 1
    fi
}

# Main setup function
main() {
    log_header "Tasky Codespace Setup - Starting Environment Validation"
    
    # Create temp directory for downloads
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT
    
    # Create utils directory for tools (needed for kubeval in deployment guide)
    mkdir -p scripts/utils
    
    log_header "Phase 1: Checking Pre-installed Tools"
    
    # Check tools that should already be in codespace
    tools_status=()
    
    # Git (should be pre-installed)
    if command_exists git; then
        git_version=$(git --version | awk '{print $3}')
        log_info "Git version: $git_version"
        tools_status+=("git:installed:$git_version")
    else
        log_error "Git is not installed!"
        tools_status+=("git:missing:N/A")
    fi
    
    # Docker (should be pre-installed)
    if command_exists docker; then
        docker_version=$(docker -v | awk '{print $3}' | sed 's/,//')
        log_info "Docker version: $docker_version"
        tools_status+=("docker:installed:$docker_version")
    else
        log_error "Docker is not installed!"
        tools_status+=("docker:missing:N/A")
    fi
    
    # kubectl (should be pre-installed)
    if command_exists kubectl; then
        kubectl_version=$(kubectl version --client --output=yaml 2>/dev/null | grep gitVersion | awk '{print $2}' | sed 's/v//')
        log_info "kubectl version: $kubectl_version"
        tools_status+=("kubectl:installed:$kubectl_version")
    else
        log_error "kubectl is not installed!"
        tools_status+=("kubectl:missing:N/A")
    fi
    
    log_header "Phase 2: Installing Required Tools"
    
    # Install AWS CLI v2
    log_info "Installing AWS CLI v2..."
    if command_exists aws; then
        current_aws_version=$(aws --version 2>&1 | awk '{print $1}' | cut -d/ -f2)
        log_info "AWS CLI already installed: $current_aws_version"
        
        # Check if it's v2 and recent enough
        if [[ $current_aws_version == 2.* ]]; then
            log_success "AWS CLI v2 is already installed"
            tools_status+=("aws:existing:$current_aws_version")
        else
            log_warning "AWS CLI v1 detected, upgrading to v2..."
            install_aws_cli=true
        fi
    else
        log_info "AWS CLI not found, installing v2..."
        install_aws_cli=true
    fi
    
    if [ "${install_aws_cli:-false}" = true ]; then
        cd "$TEMP_DIR"
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
        unzip -q awscliv2.zip
        sudo ./aws/install --update
        
        # Verify installation
        if command_exists aws; then
            aws_version=$(aws --version 2>&1 | awk '{print $1}' | cut -d/ -f2)
            log_success "AWS CLI v2 installed successfully: $aws_version"
            tools_status+=("aws:installed:$aws_version")
        else
            log_error "AWS CLI installation failed!"
            tools_status+=("aws:failed:N/A")
        fi
    fi
    
    # Install Terraform v1.0+
    log_info "Installing Terraform v1.0+..."
    if command_exists terraform; then
        current_terraform_version=$(terraform version -json | jq -r '.terraform_version' 2>/dev/null || terraform version | head -n1 | awk '{print $2}' | sed 's/v//')
        log_info "Terraform already installed: $current_terraform_version"
        
        # Check if version meets requirements (1.0+)
        if check_version "Terraform" "1.0.0" "$current_terraform_version"; then
            log_success "Terraform version meets requirements"
            tools_status+=("terraform:existing:$current_terraform_version")
        else
            log_warning "Terraform version below 1.0, upgrading..."
            install_terraform=true
        fi
    else
        log_info "Terraform not found, installing latest..."
        install_terraform=true
    fi
    
    if [ "${install_terraform:-false}" = true ]; then
        # Add HashiCorp repository
        wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
        
        # Update package list and install
        sudo apt update
        sudo apt install -y terraform
        
        # Verify installation
        if command_exists terraform; then
            terraform_version=$(terraform version -json | jq -r '.terraform_version' 2>/dev/null || terraform version | head -n1 | awk '{print $2}' | sed 's/v//')
            log_success "Terraform installed successfully: $terraform_version"
            tools_status+=("terraform:installed:$terraform_version")
        else
            log_error "Terraform installation failed!"
            tools_status+=("terraform:failed:N/A")
        fi
    fi
    
    # Install AWS Session Manager Plugin
    log_info "Installing AWS Session Manager Plugin..."
    if command_exists session-manager-plugin; then
        log_info "AWS Session Manager Plugin already installed"
        # Try to get version (note: session-manager-plugin doesn't have a standard --version flag)
        log_success "AWS Session Manager Plugin is already available"
        tools_status+=("session-manager:existing:installed")
    else
        log_info "AWS Session Manager Plugin not found, installing..."
        
        cd "$TEMP_DIR"
        log_info "Downloading AWS Session Manager Plugin..."
        curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"
        
        log_info "Installing AWS Session Manager Plugin..."
        sudo dpkg -i session-manager-plugin.deb
        
        # Verify installation
        if command_exists session-manager-plugin; then
            log_success "AWS Session Manager Plugin installed successfully"
            tools_status+=("session-manager:installed:latest")
        else
            log_error "AWS Session Manager Plugin installation failed!"
            tools_status+=("session-manager:failed:N/A")
        fi
    fi
    
    # Install bc (basic calculator) - required for cost analysis scripts
    log_info "Installing bc (basic calculator)..."
    if command_exists bc; then
        bc_version=$(bc --version | head -n1 | awk '{print $2}' 2>/dev/null || echo "installed")
        log_info "bc already installed: $bc_version"
        tools_status+=("bc:existing:$bc_version")
    else
        log_info "bc not found, installing..."
        sudo apt-get update
        sudo apt-get install -y bc
        
        # Verify installation
        if command_exists bc; then
            bc_version=$(bc --version | head -n1 | awk '{print $2}' 2>/dev/null || echo "installed")
            log_success "bc installed successfully: $bc_version"
            tools_status+=("bc:installed:$bc_version")
        else
            log_error "bc installation failed!"
            tools_status+=("bc:failed:N/A")
        fi
    fi
    
    log_header "Phase 3: Final Version Check"
    
    # Display all tool versions
    echo -e "\n${BLUE}Tool Version Summary:${NC}"
    echo "===================="
    
    for status in "${tools_status[@]}"; do
        IFS=':' read -r tool state version <<< "$status"
        case $state in
            "installed"|"existing")
                echo -e "${GREEN}✓${NC} $tool: $version"
                ;;
            "missing"|"failed")
                echo -e "${RED}✗${NC} $tool: Not available"
                ;;
        esac
    done
    
    # Final verification commands
    log_header "Phase 4: Environment Verification"
    
    echo -e "\n${BLUE}Running verification commands:${NC}"
    
    # AWS CLI
    if command_exists aws; then
        echo -e "\n${YELLOW}AWS CLI:${NC}"
        aws --version
    fi
    
    # Terraform
    if command_exists terraform; then
        echo -e "\n${YELLOW}Terraform:${NC}"
        terraform version
    fi
    
    # kubectl
    if command_exists kubectl; then
        echo -e "\n${YELLOW}kubectl:${NC}"
        kubectl version --client
    fi
    
    # Docker
    if command_exists docker; then
        echo -e "\n${YELLOW}Docker:${NC}"
        docker --version
    fi
    
    # Git
    if command_exists git; then
        echo -e "\n${YELLOW}Git:${NC}"
        git version
    fi
    
    # AWS Session Manager Plugin
    if command_exists session-manager-plugin; then
        echo -e "\n${YELLOW}AWS Session Manager Plugin:${NC}"
        echo "AWS Session Manager Plugin is installed and available"
        # Note: session-manager-plugin doesn't have a standard --version flag
    fi
    
    # bc (basic calculator)
    if command_exists bc; then
        echo -e "\n${YELLOW}bc (Basic Calculator):${NC}"
        bc --version | head -n1 || echo "bc is installed and available"
    fi
    
    log_header "Setup Complete"
    
    # Check if all critical tools are available
    critical_tools=("aws" "terraform" "kubectl" "docker" "git" "session-manager-plugin" "bc")
    missing_tools=()
    
    for tool in "${critical_tools[@]}"; do
        if ! command_exists "$tool"; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -eq 0 ]; then
        log_success "All required tools are installed and ready!"
        echo -e "\n${GREEN}Next Steps:${NC}"
        echo "1. Configure AWS credentials: aws configure"
        echo "2. Verify AWS access: aws sts get-caller-identity"
        echo "3. Navigate to terraform directory: cd terraform/"
        echo "4. Initialize Terraform: terraform init"
        echo "5. Review deployment guide: docs/deployment-guide.md"
    else
        log_error "Missing critical tools: ${missing_tools[*]}"
        echo -e "\n${RED}Please resolve the missing tools before proceeding.${NC}"
        exit 1
    fi
}

# Script entry point
main "$@"
