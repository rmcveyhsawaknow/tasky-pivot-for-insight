#!/bin/bash

# ==============================================================================
# TERRAFORM PRE-DESTROY CLEANUP SCRIPT
# ==============================================================================
# This script handles cleanup of resources that can prevent terraform destroy
# from completing successfully. It should be run BEFORE terraform destroy.
#
# Issues addressed:
# 1. Empty S3 bucket (including versioned objects)
# 2. Clean up orphaned ENIs that block subnet deletion
# 3. Clean up ALB target group attachments
# 4. Force cleanup of EKS resources
# ==============================================================================

set -e
set -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if required tools are installed
check_dependencies() {
    log "Checking dependencies..."
    
    if ! command -v aws &> /dev/null; then
        error "AWS CLI is required but not installed"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        error "jq is required but not installed"
        exit 1
    fi
    
    if ! command -v terraform &> /dev/null; then
        error "Terraform is required but not installed"
        exit 1
    fi
    
    success "All dependencies are available"
}

# Get terraform outputs
get_terraform_outputs() {
    log "Getting Terraform outputs..."
    
    if [[ ! -f "terraform.tfstate" ]]; then
        error "terraform.tfstate file not found. Make sure you're in the terraform directory."
        exit 1
    fi
    
    # Extract important resource information from terraform state
    BUCKET_NAME=$(terraform output -raw s3_backup_bucket_name 2>/dev/null || echo "")
    VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || echo "")
    EKS_CLUSTER_NAME=$(terraform output -raw eks_cluster_name 2>/dev/null || echo "")
    
    if [[ -z "$BUCKET_NAME" ]]; then
        warning "Could not get S3 bucket name from terraform output, trying state file..."
        BUCKET_NAME=$(terraform state show 'module.s3_backup.aws_s3_bucket.backup' 2>/dev/null | grep "bucket " | awk '{print $3}' | tr -d '"' || echo "")
    fi
    
    if [[ -z "$VPC_ID" ]]; then
        warning "Could not get VPC ID from terraform output, trying state file..."
        VPC_ID=$(terraform state show 'module.vpc.aws_vpc.main' 2>/dev/null | grep "id " | head -1 | awk '{print $3}' | tr -d '"' || echo "")
    fi
    
    if [[ -z "$EKS_CLUSTER_NAME" ]]; then
        warning "Could not get EKS cluster name from terraform output, trying state file..."
        EKS_CLUSTER_NAME=$(terraform state show 'module.eks.aws_eks_cluster.main' 2>/dev/null | grep "name " | head -1 | awk '{print $3}' | tr -d '"' || echo "")
    fi
    
    log "Found resources:"
    log "  S3 Bucket: ${BUCKET_NAME:-'Not found'}"
    log "  VPC ID: ${VPC_ID:-'Not found'}"
    log "  EKS Cluster: ${EKS_CLUSTER_NAME:-'Not found'}"
}

# Empty S3 bucket including all versions
empty_s3_bucket() {
    if [[ -z "$BUCKET_NAME" ]]; then
        warning "No S3 bucket name found, skipping S3 cleanup"
        return 0
    fi
    
    log "Emptying S3 bucket: $BUCKET_NAME"
    
    # Check if bucket exists
    if ! aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
        warning "S3 bucket $BUCKET_NAME does not exist or is not accessible"
        return 0
    fi
    
    # Delete all object versions
    log "Deleting all object versions..."
    aws s3api list-object-versions --bucket "$BUCKET_NAME" --output json | \
        jq -r '.Versions[]? | "\(.Key) \(.VersionId)"' | \
        while read -r key version_id; do
            if [[ -n "$key" && -n "$version_id" ]]; then
                log "  Deleting version: $key ($version_id)"
                aws s3api delete-object --bucket "$BUCKET_NAME" --key "$key" --version-id "$version_id" || true
            fi
        done
    
    # Delete all delete markers
    log "Deleting all delete markers..."
    aws s3api list-object-versions --bucket "$BUCKET_NAME" --output json | \
        jq -r '.DeleteMarkers[]? | "\(.Key) \(.VersionId)"' | \
        while read -r key version_id; do
            if [[ -n "$key" && -n "$version_id" ]]; then
                log "  Deleting delete marker: $key ($version_id)"
                aws s3api delete-object --bucket "$BUCKET_NAME" --key "$key" --version-id "$version_id" || true
            fi
        done
    
    # Final cleanup - delete any remaining objects
    log "Final cleanup of remaining objects..."
    aws s3 rm "s3://$BUCKET_NAME" --recursive || true
    
    success "S3 bucket $BUCKET_NAME has been emptied"
}

# Clean up orphaned ENIs that might be blocking subnet deletion
cleanup_orphaned_enis() {
    if [[ -z "$VPC_ID" ]]; then
        warning "No VPC ID found, skipping ENI cleanup"
        return 0
    fi
    
    log "Cleaning up orphaned ENIs in VPC: $VPC_ID"
    
    # Find ENIs in the VPC that are available (not attached)
    ORPHANED_ENIS=$(aws ec2 describe-network-interfaces \
        --filters "Name=vpc-id,Values=$VPC_ID" "Name=status,Values=available" \
        --query 'NetworkInterfaces[].NetworkInterfaceId' \
        --output text)
    
    if [[ -n "$ORPHANED_ENIS" && "$ORPHANED_ENIS" != "None" ]]; then
        log "Found orphaned ENIs: $ORPHANED_ENIS"
        for eni in $ORPHANED_ENIS; do
            log "  Deleting ENI: $eni"
            aws ec2 delete-network-interface --network-interface-id "$eni" || true
        done
        success "Orphaned ENIs cleaned up"
    else
        log "No orphaned ENIs found"
    fi
}

# Force cleanup of EKS resources
cleanup_eks_resources() {
    if [[ -z "$EKS_CLUSTER_NAME" ]]; then
        warning "No EKS cluster name found, skipping EKS cleanup"
        return 0
    fi
    
    log "Cleaning up EKS resources for cluster: $EKS_CLUSTER_NAME"
    
    # Check if cluster exists
    if ! aws eks describe-cluster --name "$EKS_CLUSTER_NAME" &>/dev/null; then
        log "EKS cluster $EKS_CLUSTER_NAME does not exist, skipping EKS cleanup"
        return 0
    fi
    
    # Update kubeconfig
    log "Updating kubeconfig..."
    aws eks update-kubeconfig --region $(aws configure get region) --name "$EKS_CLUSTER_NAME" || true
    
    # Delete any remaining services of type LoadBalancer
    log "Cleaning up LoadBalancer services..."
    if command -v kubectl &> /dev/null; then
        kubectl get svc --all-namespaces -o json | \
            jq -r '.items[] | select(.spec.type=="LoadBalancer") | "\(.metadata.namespace) \(.metadata.name)"' | \
            while read -r namespace name; do
                if [[ -n "$namespace" && -n "$name" ]]; then
                    log "  Deleting LoadBalancer service: $namespace/$name"
                    kubectl delete svc "$name" -n "$namespace" --timeout=60s || true
                fi
            done
    else
        warning "kubectl not available, skipping service cleanup"
    fi
    
    # Wait a bit for AWS to clean up associated resources
    log "Waiting for AWS to clean up associated resources..."
    sleep 30
    
    success "EKS resources cleanup completed"
}

# Clean up ALB target groups and load balancers
cleanup_alb_resources() {
    if [[ -z "$VPC_ID" ]]; then
        warning "No VPC ID found, skipping ALB cleanup"
        return 0
    fi
    
    log "Cleaning up ALB resources in VPC: $VPC_ID"
    
    # Find and delete target groups
    TARGET_GROUPS=$(aws elbv2 describe-target-groups \
        --query "TargetGroups[?VpcId=='$VPC_ID'].TargetGroupArn" \
        --output text)
    
    if [[ -n "$TARGET_GROUPS" && "$TARGET_GROUPS" != "None" ]]; then
        for tg in $TARGET_GROUPS; do
            log "  Deregistering targets from: $tg"
            # Deregister all targets
            TARGETS=$(aws elbv2 describe-target-health --target-group-arn "$tg" \
                --query 'TargetHealthDescriptions[].Target' --output json)
            
            if [[ "$TARGETS" != "[]" ]]; then
                aws elbv2 deregister-targets --target-group-arn "$tg" --targets "$TARGETS" || true
            fi
        done
        
        # Wait for deregistration
        log "Waiting for target deregistration..."
        sleep 30
    fi
    
    success "ALB resources cleanup completed"
}

# Wait for resources to be fully deleted
wait_for_resource_cleanup() {
    log "Waiting for resources to be fully cleaned up..."
    
    # Wait for ENIs to be deleted
    if [[ -n "$VPC_ID" ]]; then
        local retries=0
        local max_retries=12  # 2 minutes max
        
        while [[ $retries -lt $max_retries ]]; do
            REMAINING_ENIS=$(aws ec2 describe-network-interfaces \
                --filters "Name=vpc-id,Values=$VPC_ID" "Name=status,Values=available" \
                --query 'length(NetworkInterfaces[])' \
                --output text)
            
            if [[ "$REMAINING_ENIS" == "0" ]]; then
                success "All orphaned ENIs have been cleaned up"
                break
            fi
            
            log "Still waiting for $REMAINING_ENIS ENIs to be deleted... (attempt $((retries + 1))/$max_retries)"
            sleep 10
            ((retries++))
        done
        
        if [[ $retries -eq $max_retries ]]; then
            warning "Timeout waiting for ENI cleanup, proceeding anyway"
        fi
    fi
}

# Main execution
main() {
    log "Starting Terraform pre-destroy cleanup"
    
    # Check if we're in the right directory
    if [[ ! -f "main.tf" ]]; then
        error "main.tf not found. Please run this script from the terraform directory."
        exit 1
    fi
    
    check_dependencies
    get_terraform_outputs
    
    # Perform cleanup operations
    cleanup_eks_resources
    cleanup_alb_resources
    cleanup_orphaned_enis
    empty_s3_bucket
    wait_for_resource_cleanup
    
    success "Pre-destroy cleanup completed successfully!"
    log "You can now run 'terraform destroy' safely."
    
    # Optional: Show next steps
    log ""
    log "Next steps:"
    log "1. Run: terraform destroy"
    log "2. If there are still issues, run this script again"
    log "3. For manual cleanup, check AWS console for remaining resources"
}

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
