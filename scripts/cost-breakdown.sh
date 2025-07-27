#!/bin/bash
# cost-breakdown.sh - Generate AWS resource inventory and cost breakdown for BOM

set -e

echo "💰 AWS Resource Inventory & Cost Breakdown"
echo "=========================================="
echo ""

# Configuration
REGION="${AWS_DEFAULT_REGION:-us-east-1}"
PROJECT_NAME="tasky"

echo "🔍 Analyzing deployed AWS resources for project: $PROJECT_NAME"
echo "Region: $REGION"
echo ""

# Function to check if AWS CLI is configured
check_aws_config() {
    if ! aws sts get-caller-identity &> /dev/null; then
        echo "❌ AWS CLI not configured. Please run 'aws configure' first."
        exit 1
    fi
    echo "✅ AWS credentials validated"
}

# Function to get actual deployed resources
get_deployed_resources() {
    echo ""
    echo "📊 Current Deployed AWS Resources:"
    echo "================================"
    
    # EKS Clusters
    echo "🚀 EKS Clusters:"
    aws eks list-clusters --region "$REGION" --query 'clusters[]' --output table 2>/dev/null || echo "  No EKS clusters found"
    
    # EC2 Instances
    echo ""
    echo "🖥️  EC2 Instances:"
    aws ec2 describe-instances \
        --region "$REGION" \
        --filters "Name=instance-state-name,Values=running,stopped" \
        --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name,Tags[?Key==`Name`].Value|[0]]' \
        --output table 2>/dev/null || echo "  No EC2 instances found"
    
    # Load Balancers
    echo ""
    echo "⚖️  Load Balancers:"
    aws elbv2 describe-load-balancers \
        --region "$REGION" \
        --query 'LoadBalancers[].[LoadBalancerName,Type,State.Code,Scheme]' \
        --output table 2>/dev/null || echo "  No load balancers found"
    
    # S3 Buckets
    echo ""
    echo "🪣 S3 Buckets:"
    aws s3api list-buckets \
        --query 'Buckets[].[Name,CreationDate]' \
        --output table 2>/dev/null | grep -i "$PROJECT_NAME" || echo "  No project-related S3 buckets found"
    
    # VPC and Networking
    echo ""
    echo "🌐 VPC Resources:"
    aws ec2 describe-vpcs \
        --region "$REGION" \
        --filters "Name=tag:Project,Values=$PROJECT_NAME" \
        --query 'Vpcs[].[VpcId,CidrBlock,State,Tags[?Key==`Name`].Value|[0]]' \
        --output table 2>/dev/null || echo "  No project VPCs found"
    
    # NAT Gateways
    echo ""
    echo "🌉 NAT Gateways:"
    aws ec2 describe-nat-gateways \
        --region "$REGION" \
        --filter "Name=tag:Project,Values=$PROJECT_NAME" \
        --query 'NatGateways[].[NatGatewayId,State,SubnetId,Tags[?Key==`Name`].Value|[0]]' \
        --output table 2>/dev/null || echo "  No NAT gateways found"
}

# Function to generate cost breakdown based on actual resources
generate_actual_cost_breakdown() {
    echo ""
    echo "💸 Live Cost Analysis (Based on Deployed Resources):"
    echo "=================================================="
    
    # Get EKS cluster count
    EKS_COUNT=$(aws eks list-clusters --region "$REGION" --query 'length(clusters)' --output text 2>/dev/null || echo "0")
    
    # Get EC2 instance details
    EC2_INSTANCES=$(aws ec2 describe-instances \
        --region "$REGION" \
        --filters "Name=instance-state-name,Values=running" \
        --query 'Reservations[].Instances[].[InstanceType]' \
        --output text 2>/dev/null || echo "")
    
    # Get ALB count
    ALB_COUNT=$(aws elbv2 describe-load-balancers \
        --region "$REGION" \
        --query 'length(LoadBalancers[?Type==`application`])' \
        --output text 2>/dev/null || echo "0")
    
    # Get NAT Gateway count
    NAT_COUNT=$(aws ec2 describe-nat-gateways \
        --region "$REGION" \
        --filter "Name=state,Values=available" \
        --query 'length(NatGateways)' \
        --output text 2>/dev/null || echo "0")
    
    echo "Resource Summary:"
    echo "- EKS Clusters: $EKS_COUNT"
    echo "- Running EC2 Instances: $(echo "$EC2_INSTANCES" | wc -w)"
    echo "- Application Load Balancers: $ALB_COUNT"
    echo "- NAT Gateways: $NAT_COUNT"
    echo ""
    
    # Calculate costs
    TOTAL_MONTHLY=0
    
    if [ "$EKS_COUNT" -gt 0 ]; then
        EKS_COST=$(echo "$EKS_COUNT * 72" | bc)
        echo "EKS Control Planes ($EKS_COUNT): \$$EKS_COST/month"
        TOTAL_MONTHLY=$(echo "$TOTAL_MONTHLY + $EKS_COST" | bc)
    fi
    
    if [ -n "$EC2_INSTANCES" ] && [ "$EC2_INSTANCES" != "" ]; then
        EC2_COST=0
        for instance_type in $EC2_INSTANCES; do
            case $instance_type in
                t3.medium)
                    EC2_COST=$(echo "$EC2_COST + 30.24" | bc)
                    ;;
                t3.small)
                    EC2_COST=$(echo "$EC2_COST + 15.12" | bc)
                    ;;
                t3.large)
                    EC2_COST=$(echo "$EC2_COST + 60.48" | bc)
                    ;;
                *)
                    EC2_COST=$(echo "$EC2_COST + 30" | bc)  # Default estimate
                    ;;
            esac
        done
        echo "EC2 Instances: \$$EC2_COST/month"
        TOTAL_MONTHLY=$(echo "$TOTAL_MONTHLY + $EC2_COST" | bc)
    fi
    
    if [ "$ALB_COUNT" -gt 0 ]; then
        ALB_COST=$(echo "$ALB_COUNT * 16.20" | bc)
        echo "Application Load Balancers ($ALB_COUNT): \$$ALB_COST/month"
        TOTAL_MONTHLY=$(echo "$TOTAL_MONTHLY + $ALB_COST" | bc)
    fi
    
    if [ "$NAT_COUNT" -gt 0 ]; then
        NAT_COST=$(echo "$NAT_COUNT * 32.40" | bc)
        echo "NAT Gateways ($NAT_COUNT): \$$NAT_COST/month"
        TOTAL_MONTHLY=$(echo "$TOTAL_MONTHLY + $NAT_COST" | bc)
    fi
    
    # Add estimated costs for EBS and S3
    if [ "$TOTAL_MONTHLY" != "0" ]; then
        STORAGE_COST=20
        echo "Storage (EBS + S3, estimated): \$$STORAGE_COST/month"
        TOTAL_MONTHLY=$(echo "$TOTAL_MONTHLY + $STORAGE_COST" | bc)
    fi
    
    echo ""
    echo "🎯 ESTIMATED TOTAL: \$$TOTAL_MONTHLY/month"
    echo "🎯 ESTIMATED ANNUAL: \$$(echo "$TOTAL_MONTHLY * 12" | bc)/year"
}

# Function to compare with planned costs
compare_with_planned() {
    echo ""
    echo "📈 Planned vs Actual Cost Comparison:"
    echo "===================================="
    echo "Planned (from Terraform): ~\$231/month"
    echo "Actual (from AWS resources): \$$TOTAL_MONTHLY/month"
    
    if [ "$TOTAL_MONTHLY" != "0" ]; then
        DIFFERENCE=$(echo "$TOTAL_MONTHLY - 231" | bc)
        if [ "$(echo "$DIFFERENCE > 0" | bc)" -eq 1 ]; then
            echo "⚠️  Over budget by: \$$DIFFERENCE/month"
        else
            DIFFERENCE=$(echo "$DIFFERENCE * -1" | bc)
            echo "✅ Under budget by: \$$DIFFERENCE/month"
        fi
    fi
}

# Function to generate bill of materials
generate_bill_of_materials() {
    echo ""
    echo "📋 Bill of Materials (BOM):"
    echo "=========================="
    
    BOM_FILE="aws-bom-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$BOM_FILE" << EOF
AWS INFRASTRUCTURE BILL OF MATERIALS
====================================
Project: $PROJECT_NAME
Region: $REGION
Generated: $(date)

DEPLOYED RESOURCES:
- EKS Clusters: $EKS_COUNT
- EC2 Instances: $(echo "$EC2_INSTANCES" | wc -w)
- Application Load Balancers: $ALB_COUNT
- NAT Gateways: $NAT_COUNT

MONTHLY COST ESTIMATE: \$$TOTAL_MONTHLY
ANNUAL COST ESTIMATE: \$$(echo "$TOTAL_MONTHLY * 12" | bc)

RESOURCE DETAILS:
$(aws ec2 describe-instances --region "$REGION" --filters "Name=instance-state-name,Values=running" --query 'Reservations[].Instances[].[InstanceId,InstanceType,Tags[?Key==`Name`].Value|[0]]' --output table 2>/dev/null || echo "No running instances")

OPTIMIZATION RECOMMENDATIONS:
- Use Spot instances for non-production workloads
- Implement auto-scaling for variable workloads
- Use Reserved Instances for predictable workloads
- Monitor usage patterns for right-sizing opportunities

EOF
    
    echo "✅ BOM saved to: $BOM_FILE"
}

# Main execution
main() {
    check_aws_config
    get_deployed_resources
    generate_actual_cost_breakdown
    compare_with_planned
    generate_bill_of_materials
    
    echo ""
    echo "🔗 Next Steps:"
    echo "- Review detailed cost breakdown in: $BOM_FILE"
    echo "- Use AWS Cost Explorer for historical spend analysis"
    echo "- Set up AWS Budgets for cost monitoring and alerts"
    echo "- Consider AWS Cost Optimization Hub for recommendations"
}

# Check if bc is installed
if ! command -v bc &> /dev/null; then
    echo "Installing bc calculator..."
    sudo apt-get update && sudo apt-get install -y bc
fi

# Run main function
main "$@"
