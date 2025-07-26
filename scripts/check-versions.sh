#!/bin/bash

# Tasky Application - Version Checker Script
# This script checks the versions of required tools without installing anything

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check version and compare with minimum required
check_version() {
    local tool="$1"
    local min_version="$2"
    local current_version="$3"
    
    # Simple version comparison (works for most semantic versions)
    if [ "$current_version" = "$min_version" ] || [ "$(printf '%s\n' "$min_version" "$current_version" | sort -V | head -n1)" = "$min_version" ]; then
        echo -e "${GREEN}✓${NC} $tool: $current_version (>= $min_version)"
        return 0
    else
        echo -e "${YELLOW}⚠${NC} $tool: $current_version (< $min_version required)"
        return 1
    fi
}

echo -e "${BLUE}=== Tasky Application - Tool Version Check ===${NC}\n"

# Define minimum required versions
MIN_TERRAFORM_VERSION="1.0.0"
MIN_AWS_CLI_VERSION="2.0.0"

all_good=true

# Check Git
if command_exists git; then
    git_version=$(git --version | awk '{print $3}')
    echo -e "${GREEN}✓${NC} Git: $git_version"
else
    echo -e "${RED}✗${NC} Git: Not installed"
    all_good=false
fi

# Check Docker
if command_exists docker; then
    docker_version=$(docker -v | awk '{print $3}' | sed 's/,//')
    echo -e "${GREEN}✓${NC} Docker: $docker_version"
else
    echo -e "${RED}✗${NC} Docker: Not installed"
    all_good=false
fi

# Check kubectl
if command_exists kubectl; then
    kubectl_version=$(kubectl version --client --output=yaml 2>/dev/null | grep gitVersion | awk '{print $2}' | sed 's/v//')
    echo -e "${GREEN}✓${NC} kubectl: $kubectl_version"
else
    echo -e "${RED}✗${NC} kubectl: Not installed"
    all_good=false
fi

# Check AWS CLI
if command_exists aws; then
    aws_version=$(aws --version 2>&1 | awk '{print $1}' | cut -d/ -f2)
    if ! check_version "AWS CLI" "$MIN_AWS_CLI_VERSION" "$aws_version"; then
        all_good=false
    fi
else
    echo -e "${RED}✗${NC} AWS CLI: Not installed"
    all_good=false
fi

# Check Terraform
if command_exists terraform; then
    terraform_version=$(terraform version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null || terraform version | head -n1 | awk '{print $2}' | sed 's/v//')
    if ! check_version "Terraform" "$MIN_TERRAFORM_VERSION" "$terraform_version"; then
        all_good=false
    fi
else
    echo -e "${RED}✗${NC} Terraform: Not installed"
    all_good=false
fi

echo -e "\n${BLUE}=== Summary ===${NC}"

if [ "$all_good" = true ]; then
    echo -e "${GREEN}✓ All tools are installed and meet minimum requirements!${NC}"
    echo -e "\nYou're ready to deploy the Tasky application."
    echo -e "Next step: ${YELLOW}aws configure${NC} (if not already done)"
else
    echo -e "${YELLOW}⚠ Some tools need attention.${NC}"
    echo -e "\nTo install missing or upgrade outdated tools, run:"
    echo -e "${YELLOW}./scripts/setup-codespace.sh${NC}"
fi
