#!/bin/bash

# ==============================================================================
# SAFE TERRAFORM DESTROY SCRIPT
# ==============================================================================
# This script safely destroys Terraform infrastructure by:
# 1. Running pre-destroy cleanup
# 2. Attempting terraform destroy with retries
# 3. Providing fallback options if destroy fails
# ==============================================================================

set -e
set -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Function to ask for user confirmation
confirm() {
    read -p "$(echo -e "${YELLOW}$1 (y/N):${NC} ")" -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

# Check if we're in the right directory
check_directory() {
    if [[ ! -f "main.tf" ]]; then
        error "main.tf not found. Please run this script from the terraform directory."
        exit 1
    fi
    
    if [[ ! -f "terraform.tfstate" ]]; then
        warning "terraform.tfstate not found. Terraform may not have been initialized or applied."
        if ! confirm "Continue anyway"; then
            exit 1
        fi
    fi
}

# Run pre-destroy cleanup
run_cleanup() {
    log "Running pre-destroy cleanup..."
    
    if [[ -f "cleanup-before-destroy.sh" ]]; then
        if confirm "Run automated pre-destroy cleanup"; then
            ./cleanup-before-destroy.sh || {
                warning "Pre-destroy cleanup failed or had issues"
                if confirm "Continue with destroy anyway"; then
                    log "Continuing with terraform destroy..."
                else
                    error "Aborting destroy process"
                    exit 1
                fi
            }
        fi
    else
        warning "cleanup-before-destroy.sh not found in current directory"
    fi
}

# Run terraform destroy with retries
run_terraform_destroy() {
    local max_retries=3
    local retry=0
    
    while [[ $retry -lt $max_retries ]]; do
        log "Running terraform destroy (attempt $((retry + 1))/$max_retries)..."
        
        if terraform destroy -auto-approve; then
            success "Terraform destroy completed successfully!"
            return 0
        else
            ((retry++))
            if [[ $retry -lt $max_retries ]]; then
                warning "Terraform destroy failed. Retrying in 30 seconds..."
                sleep 30
            fi
        fi
    done
    
    error "Terraform destroy failed after $max_retries attempts"
    return 1
}

# Targeted destroy for specific resources
targeted_destroy() {
    log "Attempting targeted destroy for common problematic resources..."
    
    # List of resources that commonly cause issues, in order they should be destroyed
    local resources=(
        "module.alb"
        "module.eks.aws_eks_node_group.main"
        "module.eks.aws_eks_cluster.main"
        "module.mongodb_ec2"
        "module.vpc.aws_nat_gateway.main"
        "module.vpc.aws_route_table.private"
        "module.vpc.aws_route_table.public"
        "module.vpc.aws_subnet.private"
        "module.vpc.aws_subnet.public"
        "module.vpc.aws_internet_gateway.main"
        "module.vpc.aws_vpc.main"
        "module.s3_backup"
    )
    
    for resource in "${resources[@]}"; do
        log "Attempting to destroy: $resource"
        terraform destroy -target="$resource" -auto-approve || {
            warning "Failed to destroy $resource, continuing..."
        }
        sleep 5  # Brief pause between destroys
    done
    
    # Final destroy attempt
    log "Running final terraform destroy..."
    terraform destroy -auto-approve
}

# Show remaining resources
show_remaining_resources() {
    log "Checking for remaining resources..."
    
    if terraform state list 2>/dev/null | grep -q "."; then
        warning "The following resources remain:"
        terraform state list
        return 1
    else
        success "No resources remain in Terraform state"
        return 0
    fi
}

# Offer manual cleanup
offer_manual_cleanup() {
    warning "Terraform destroy was not completely successful"
    
    if show_remaining_resources; then
        return 0
    fi
    
    echo
    log "Options to resolve remaining resources:"
    echo "1. Run manual cleanup script (./manual-cleanup.sh)"
    echo "2. Use targeted destroy for specific resources"
    echo "3. Manually delete resources from AWS console"
    echo "4. Force remove resources from Terraform state (DANGEROUS)"
    
    echo
    if confirm "Do you want to run the manual cleanup script"; then
        if [[ -f "manual-cleanup.sh" ]]; then
            ./manual-cleanup.sh
        else
            error "manual-cleanup.sh not found"
        fi
    fi
    
    echo
    if confirm "Do you want to try targeted destroy"; then
        targeted_destroy
        show_remaining_resources
    fi
}

# Force state cleanup (last resort)
force_state_cleanup() {
    warning "This is a LAST RESORT option that will remove resources from Terraform state"
    warning "Resources may still exist in AWS and need manual cleanup"
    
    if confirm "Are you sure you want to force remove all resources from state"; then
        terraform state list | while read -r resource; do
            log "Removing $resource from state..."
            terraform state rm "$resource" || true
        done
        
        success "All resources removed from Terraform state"
        warning "You must manually verify and clean up any remaining AWS resources"
    fi
}

# Main execution
main() {
    log "Starting safe Terraform destroy process"
    
    check_directory
    
    # Show current state
    log "Current Terraform state:"
    terraform state list || warning "Could not list Terraform state"
    
    echo
    if ! confirm "Do you want to proceed with destroying all infrastructure"; then
        log "Destroy process cancelled by user"
        exit 0
    fi
    
    # Step 1: Pre-destroy cleanup
    run_cleanup
    
    # Step 2: Terraform destroy
    if run_terraform_destroy; then
        success "Infrastructure destroyed successfully!"
        
        # Verify no resources remain
        if show_remaining_resources; then
            success "All resources have been successfully destroyed"
        fi
    else
        # Step 3: Handle failures
        offer_manual_cleanup
        
        # Final check
        if ! show_remaining_resources; then
            success "All resources have been successfully destroyed"
        else
            warning "Some resources may still remain"
            
            echo
            if confirm "Do you want to force remove remaining resources from Terraform state"; then
                force_state_cleanup
            fi
        fi
    fi
    
    log "Destroy process completed"
}

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
