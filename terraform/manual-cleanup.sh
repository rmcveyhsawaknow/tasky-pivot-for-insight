#!/bin/bash

# ==============================================================================
# MANUAL TERRAFORM CLEANUP SCRIPT
# ==============================================================================
# This script provides manual cleanup procedures when terraform destroy fails
# and the automated cleanup script doesn't resolve all issues.
#
# Use this script when:
# 1. terraform destroy still fails after running cleanup-before-destroy.sh
# 2. You need to manually identify and remove specific AWS resources
# 3. You want to do a complete infrastructure teardown
# ==============================================================================

set -e
set -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

# Get user input for resource identifiers
get_resource_identifiers() {
    log "Please provide the following information from your failed terraform destroy output:"
    
    echo
    read -p "VPC ID (or press Enter to skip): " VPC_ID
    read -p "S3 Bucket Name (or press Enter to skip): " BUCKET_NAME
    read -p "EKS Cluster Name (or press Enter to skip): " EKS_CLUSTER_NAME
    
    echo
    log "Subnet IDs that failed to delete:"
    read -p "Subnet ID 1 (or press Enter if none): " SUBNET_ID_1
    read -p "Subnet ID 2 (or press Enter if none): " SUBNET_ID_2
    read -p "Subnet ID 3 (or press Enter if none): " SUBNET_ID_3
    
    # Store subnet IDs in array
    SUBNET_IDS=()
    [[ -n "$SUBNET_ID_1" ]] && SUBNET_IDS+=("$SUBNET_ID_1")
    [[ -n "$SUBNET_ID_2" ]] && SUBNET_IDS+=("$SUBNET_ID_2")
    [[ -n "$SUBNET_ID_3" ]] && SUBNET_IDS+=("$SUBNET_ID_3")
}

# Manually identify and clean up ENI dependencies
cleanup_eni_dependencies() {
    if [[ -z "$VPC_ID" ]]; then
        warning "No VPC ID provided, skipping ENI dependency cleanup"
        return 0
    fi
    
    log "Analyzing ENI dependencies in VPC: $VPC_ID"
    
    # Get all ENIs in the VPC
    ENI_INFO=$(aws ec2 describe-network-interfaces \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --output table || true)
    
    if [[ -n "$ENI_INFO" ]]; then
        echo "$ENI_INFO"
        echo
        
        if confirm "Do you want to see detailed ENI information"; then
            aws ec2 describe-network-interfaces \
                --filters "Name=vpc-id,Values=$VPC_ID" \
                --output json | jq -r '.NetworkInterfaces[] | 
                    "ENI: \(.NetworkInterfaceId) | Status: \(.Status) | Type: \(.InterfaceType // "N/A") | 
                     Description: \(.Description // "N/A") | Attachment: \(.Attachment.InstanceId // "Not attached")"'
        fi
        
        if confirm "Do you want to delete all available (unattached) ENIs"; then
            aws ec2 describe-network-interfaces \
                --filters "Name=vpc-id,Values=$VPC_ID" "Name=status,Values=available" \
                --query 'NetworkInterfaces[].NetworkInterfaceId' \
                --output text | tr '\t' '\n' | while read -r eni; do
                if [[ -n "$eni" && "$eni" != "None" ]]; then
                    log "Deleting ENI: $eni"
                    aws ec2 delete-network-interface --network-interface-id "$eni" || \
                        error "Failed to delete ENI $eni"
                fi
            done
        fi
    else
        log "No ENIs found in VPC $VPC_ID"
    fi
}

# Manually clean up subnet dependencies
cleanup_subnet_dependencies() {
    if [[ ${#SUBNET_IDS[@]} -eq 0 ]]; then
        warning "No subnet IDs provided, skipping subnet dependency cleanup"
        return 0
    fi
    
    for subnet_id in "${SUBNET_IDS[@]}"; do
        log "Analyzing dependencies for subnet: $subnet_id"
        
        # Check for ENIs in the subnet
        ENI_COUNT=$(aws ec2 describe-network-interfaces \
            --filters "Name=subnet-id,Values=$subnet_id" \
            --query 'length(NetworkInterfaces[])' \
            --output text)
        
        if [[ "$ENI_COUNT" -gt 0 ]]; then
            warning "Found $ENI_COUNT ENIs in subnet $subnet_id"
            aws ec2 describe-network-interfaces \
                --filters "Name=subnet-id,Values=$subnet_id" \
                --output table
            
            if confirm "Do you want to delete ENIs in this subnet"; then
                aws ec2 describe-network-interfaces \
                    --filters "Name=subnet-id,Values=$subnet_id" \
                    --query 'NetworkInterfaces[?Status==`available`].NetworkInterfaceId' \
                    --output text | tr '\t' '\n' | while read -r eni; do
                    if [[ -n "$eni" && "$eni" != "None" ]]; then
                        log "Deleting ENI: $eni"
                        aws ec2 delete-network-interface --network-interface-id "$eni" || \
                            error "Failed to delete ENI $eni"
                    fi
                done
            fi
        fi
        
        # Check for other dependencies
        log "Checking for other dependencies in subnet $subnet_id..."
        
        # Check for instances
        INSTANCE_COUNT=$(aws ec2 describe-instances \
            --filters "Name=subnet-id,Values=$subnet_id" "Name=instance-state-name,Values=running,pending,shutting-down,stopping,stopped" \
            --query 'length(Reservations[].Instances[])' \
            --output text)
        
        if [[ "$INSTANCE_COUNT" -gt 0 ]]; then
            warning "Found $INSTANCE_COUNT instances in subnet $subnet_id"
            aws ec2 describe-instances \
                --filters "Name=subnet-id,Values=$subnet_id" \
                --query 'Reservations[].Instances[].[InstanceId,State.Name,InstanceType]' \
                --output table
        fi
        
        # Check for load balancers
        LB_COUNT=$(aws elbv2 describe-load-balancers \
            --query "length(LoadBalancers[?VpcId=='$VPC_ID' && contains(AvailabilityZones[].SubnetId, '$subnet_id')])" \
            --output text 2>/dev/null || echo "0")
        
        if [[ "$LB_COUNT" -gt 0 ]]; then
            warning "Found $LB_COUNT load balancers using subnet $subnet_id"
        fi
        
        # Check for NAT gateways
        NAT_COUNT=$(aws ec2 describe-nat-gateways \
            --filters "Name=subnet-id,Values=$subnet_id" "Name=state,Values=available,pending,deleting" \
            --query 'length(NatGateways[])' \
            --output text)
        
        if [[ "$NAT_COUNT" -gt 0 ]]; then
            warning "Found $NAT_COUNT NAT gateways in subnet $subnet_id"
            aws ec2 describe-nat-gateways \
                --filters "Name=subnet-id,Values=$subnet_id" \
                --output table
            
            if confirm "Do you want to delete NAT gateways in this subnet"; then
                aws ec2 describe-nat-gateways \
                    --filters "Name=subnet-id,Values=$subnet_id" "Name=state,Values=available" \
                    --query 'NatGateways[].NatGatewayId' \
                    --output text | tr '\t' '\n' | while read -r nat_gw; do
                    if [[ -n "$nat_gw" && "$nat_gw" != "None" ]]; then
                        log "Deleting NAT Gateway: $nat_gw"
                        aws ec2 delete-nat-gateway --nat-gateway-id "$nat_gw" || \
                            error "Failed to delete NAT Gateway $nat_gw"
                    fi
                done
            fi
        fi
    done
}

# Force empty S3 bucket with advanced options
force_empty_s3_bucket() {
    if [[ -z "$BUCKET_NAME" ]]; then
        warning "No S3 bucket name provided, skipping S3 cleanup"
        return 0
    fi
    
    log "Force emptying S3 bucket: $BUCKET_NAME"
    
    # Check if bucket exists
    if ! aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
        warning "S3 bucket $BUCKET_NAME does not exist"
        return 0
    fi
    
    # Show bucket contents
    log "Current bucket contents:"
    aws s3 ls "s3://$BUCKET_NAME" --recursive || true
    
    if confirm "Do you want to force delete all objects in this bucket"; then
        # Delete all versions
        log "Deleting all object versions..."
        aws s3api list-object-versions --bucket "$BUCKET_NAME" --output json | \
            jq -r '.Versions[]? | "--key \"\(.Key)\" --version-id \(.VersionId)"' | \
            while read -r params; do
                if [[ -n "$params" ]]; then
                    eval "aws s3api delete-object --bucket '$BUCKET_NAME' $params" || true
                fi
            done
        
        # Delete all delete markers
        log "Deleting all delete markers..."
        aws s3api list-object-versions --bucket "$BUCKET_NAME" --output json | \
            jq -r '.DeleteMarkers[]? | "--key \"\(.Key)\" --version-id \(.VersionId)"' | \
            while read -r params; do
                if [[ -n "$params" ]]; then
                    eval "aws s3api delete-object --bucket '$BUCKET_NAME' $params" || true
                fi
            done
        
        # Force delete using CLI
        log "Force deleting remaining objects..."
        aws s3 rm "s3://$BUCKET_NAME" --recursive --quiet || true
        
        success "S3 bucket $BUCKET_NAME has been forcefully emptied"
    fi
}

# Clean up EKS resources manually
manual_eks_cleanup() {
    if [[ -z "$EKS_CLUSTER_NAME" ]]; then
        warning "No EKS cluster name provided, skipping EKS cleanup"
        return 0
    fi
    
    log "Manual EKS cleanup for cluster: $EKS_CLUSTER_NAME"
    
    # Check if cluster exists
    if ! aws eks describe-cluster --name "$EKS_CLUSTER_NAME" &>/dev/null; then
        warning "EKS cluster $EKS_CLUSTER_NAME does not exist"
        return 0
    fi
    
    # Show cluster status
    log "Cluster status:"
    aws eks describe-cluster --name "$EKS_CLUSTER_NAME" \
        --query 'cluster.{Status:status,Version:version,Endpoint:endpoint}' \
        --output table
    
    # Show node groups
    log "Node groups:"
    aws eks list-nodegroups --cluster-name "$EKS_CLUSTER_NAME" \
        --output table
    
    if confirm "Do you want to delete all node groups"; then
        aws eks list-nodegroups --cluster-name "$EKS_CLUSTER_NAME" \
            --query 'nodegroups[]' --output text | while read -r ng; do
            if [[ -n "$ng" ]]; then
                log "Deleting node group: $ng"
                aws eks delete-nodegroup --cluster-name "$EKS_CLUSTER_NAME" \
                    --nodegroup-name "$ng" || error "Failed to delete node group $ng"
            fi
        done
        
        log "Waiting for node groups to be deleted..."
        sleep 60
    fi
    
    if confirm "Do you want to delete the EKS cluster"; then
        log "Deleting EKS cluster: $EKS_CLUSTER_NAME"
        aws eks delete-cluster --name "$EKS_CLUSTER_NAME" || \
            error "Failed to delete cluster $EKS_CLUSTER_NAME"
    fi
}

# Show comprehensive resource inventory
show_resource_inventory() {
    if [[ -z "$VPC_ID" ]]; then
        warning "No VPC ID provided, cannot show resource inventory"
        return 0
    fi
    
    log "Comprehensive resource inventory for VPC: $VPC_ID"
    
    echo "========================================"
    echo "LOAD BALANCERS"
    echo "========================================"
    aws elbv2 describe-load-balancers \
        --query "LoadBalancers[?VpcId=='$VPC_ID'].[LoadBalancerName,Type,State.Code]" \
        --output table || true
    
    echo
    echo "========================================"
    echo "TARGET GROUPS"
    echo "========================================"
    aws elbv2 describe-target-groups \
        --query "TargetGroups[?VpcId=='$VPC_ID'].[TargetGroupName,Protocol,Port]" \
        --output table || true
    
    echo
    echo "========================================"
    echo "SECURITY GROUPS"
    echo "========================================"
    aws ec2 describe-security-groups \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query 'SecurityGroups[].{GroupId:GroupId,GroupName:GroupName,Description:Description}' \
        --output table || true
    
    echo
    echo "========================================"
    echo "ROUTE TABLES"
    echo "========================================"
    aws ec2 describe-route-tables \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query 'RouteTables[].{RouteTableId:RouteTableId,AssociationSubnet:Associations[0].SubnetId}' \
        --output table || true
    
    echo
    echo "========================================"
    echo "INTERNET GATEWAYS"
    echo "========================================"
    aws ec2 describe-internet-gateways \
        --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
        --output table || true
    
    echo
    echo "========================================"
    echo "VPC ENDPOINTS"
    echo "========================================"
    aws ec2 describe-vpc-endpoints \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --output table || true
}

# Main menu
show_menu() {
    echo
    echo "========================================"
    echo "MANUAL TERRAFORM CLEANUP MENU"
    echo "========================================"
    echo "1. Show resource inventory"
    echo "2. Clean up ENI dependencies"
    echo "3. Clean up subnet dependencies"
    echo "4. Force empty S3 bucket"
    echo "5. Manual EKS cleanup"
    echo "6. Run all cleanup operations"
    echo "7. Exit"
    echo "========================================"
}

# Main execution
main() {
    log "Starting manual Terraform cleanup"
    
    get_resource_identifiers
    
    while true; do
        show_menu
        read -p "Select an option (1-7): " choice
        
        case $choice in
            1) show_resource_inventory ;;
            2) cleanup_eni_dependencies ;;
            3) cleanup_subnet_dependencies ;;
            4) force_empty_s3_bucket ;;
            5) manual_eks_cleanup ;;
            6) 
                cleanup_eni_dependencies
                cleanup_subnet_dependencies
                force_empty_s3_bucket
                manual_eks_cleanup
                ;;
            7) 
                log "Exiting manual cleanup"
                exit 0
                ;;
            *) error "Invalid option. Please select 1-7." ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
    done
}

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
