#!/bin/bash
# cost-terraform.sh - AWS Cost Analysis for Terraform Infrastructure
# Generates Bill of Materials (BOM) and cost estimates for Tasky infrastructure

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TERRAFORM_DIR="${1:-terraform}"
OUTPUT_FILE="cost-analysis-$(date +%Y%m%d-%H%M%S).json"
BOM_FILE="bill-of-materials-$(date +%Y%m%d-%H%M%S).txt"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"

echo -e "${BLUE}🧮 AWS Cost Analysis for Tasky Infrastructure${NC}"
echo "=================================================="
echo "Region: $REGION"
echo "Terraform Directory: $TERRAFORM_DIR"
echo "Output Files: $OUTPUT_FILE, $BOM_FILE"
echo ""

# Check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}📋 Checking prerequisites...${NC}"
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}❌ AWS CLI not found. Please install AWS CLI.${NC}"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        echo -e "${RED}❌ AWS credentials not configured. Run 'aws configure' first.${NC}"
        exit 1
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        echo -e "${RED}❌ Terraform not found. Please install Terraform.${NC}"
        exit 1
    fi
    
    # Check jq
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}❌ jq not found. Installing jq...${NC}"
        sudo apt-get update && sudo apt-get install -y jq
    fi
    
    echo -e "${GREEN}✅ Prerequisites check passed${NC}"
    echo ""
}

# Extract resources from Terraform plan
extract_terraform_resources() {
    echo -e "${YELLOW}🔍 Analyzing Terraform resources...${NC}"
    
    cd "$TERRAFORM_DIR" || exit 1
    
    # Initialize Terraform if needed
    if [ ! -d ".terraform" ]; then
        echo "Initializing Terraform..."
        terraform init -backend=false
    fi
    
    # Generate plan
    echo "Generating Terraform plan..."
    terraform plan -out=cost-analysis.tfplan &> /dev/null
    terraform show -json cost-analysis.tfplan > "$OUTPUT_FILE"
    
    echo -e "${GREEN}✅ Terraform analysis complete${NC}"
    echo ""
}

# Parse resources and generate BOM
generate_bom() {
    echo -e "${YELLOW}📊 Generating Bill of Materials...${NC}"
    
    cat > "$BOM_FILE" << EOF
=======================================================
TASKY INFRASTRUCTURE - BILL OF MATERIALS
=======================================================
Generated: $(date)
Region: $REGION
Terraform Directory: $TERRAFORM_DIR

=======================================================
AWS RESOURCES BREAKDOWN
=======================================================

EOF

    # Extract key resources from Terraform plan
    RESOURCES=$(jq -r '.planned_values.root_module.resources[]? | select(.type != null) | "\(.type)|\(.name)|\(.values.instance_type // .values.node_instance_types[0] // "N/A")|\(.values.capacity // .values.desired_capacity // "1")"' "$TERRAFORM_DIR/$OUTPUT_FILE" 2>/dev/null || echo "")
    
    if [ -z "$RESOURCES" ]; then
        # Fallback: try to get from state if plan fails
        echo "Falling back to Terraform state analysis..."
        terraform -chdir="$TERRAFORM_DIR" show -json > "$OUTPUT_FILE" 2>/dev/null || true
        RESOURCES=$(jq -r '.values?.root_module?.resources[]? | select(.type != null) | "\(.type)|\(.name)|\(.values.instance_type // .values.node_instance_types[0] // "N/A")|\(.values.capacity // .values.desired_capacity // "1")"' "$TERRAFORM_DIR/$OUTPUT_FILE" 2>/dev/null || echo "")
    fi
    
    # Process each resource type
    echo "COMPUTE RESOURCES:" >> "$BOM_FILE"
    echo "==================" >> "$BOM_FILE"
    echo "$RESOURCES" | grep "aws_instance\|aws_eks\|aws_autoscaling" | while IFS='|' read -r type name instance_type capacity; do
        echo "- $type ($name): $instance_type x$capacity" >> "$BOM_FILE"
    done
    echo "" >> "$BOM_FILE"
    
    echo "LOAD BALANCING:" >> "$BOM_FILE"
    echo "===============" >> "$BOM_FILE"
    echo "$RESOURCES" | grep "aws_lb\|aws_alb" | while IFS='|' read -r type name instance_type capacity; do
        echo "- $type ($name)" >> "$BOM_FILE"
    done
    echo "" >> "$BOM_FILE"
    
    echo "NETWORKING:" >> "$BOM_FILE"
    echo "===========" >> "$BOM_FILE"
    echo "$RESOURCES" | grep "aws_vpc\|aws_subnet\|aws_nat_gateway\|aws_internet_gateway" | while IFS='|' read -r type name instance_type capacity; do
        echo "- $type ($name)" >> "$BOM_FILE"
    done
    echo "" >> "$BOM_FILE"
    
    echo "STORAGE:" >> "$BOM_FILE"
    echo "========" >> "$BOM_FILE"
    echo "$RESOURCES" | grep "aws_s3\|aws_ebs" | while IFS='|' read -r type name instance_type capacity; do
        echo "- $type ($name)" >> "$BOM_FILE"
    done
    echo "" >> "$BOM_FILE"
    
    echo "DATABASE:" >> "$BOM_FILE"
    echo "=========" >> "$BOM_FILE"
    echo "$RESOURCES" | grep "aws_db\|aws_rds\|aws_elasticache" | while IFS='|' read -r type name instance_type capacity; do
        echo "- $type ($name): $instance_type" >> "$BOM_FILE"
    done
    echo "" >> "$BOM_FILE"
}

# Get AWS pricing for key resources
get_aws_pricing() {
    echo -e "${YELLOW}💰 Fetching AWS pricing data...${NC}"
    
    cat >> "$BOM_FILE" << EOF
=======================================================
ESTIMATED MONTHLY COSTS (USD)
=======================================================

MAJOR COST COMPONENTS:
EOF

    # EKS Cluster pricing
    EKS_PRICE="72.00"  # $0.10/hour * 24 * 30
    echo "- EKS Cluster Control Plane: \$${EKS_PRICE}/month" >> "$BOM_FILE"
    
    # EC2 pricing for MongoDB (assuming t3.medium)
    MONGODB_PRICE=$(aws pricing get-products \
        --service-code AmazonEC2 \
        --region "$REGION" \
        --filters "Type=TERM_MATCH,Field=instanceType,Value=t3.medium" \
        "Type=TERM_MATCH,Field=operatingSystem,Value=Linux" \
        "Type=TERM_MATCH,Field=tenancy,Value=Shared" \
        "Type=TERM_MATCH,Field=preInstalledSw,Value=NA" \
        --format-version aws_v1 \
        --query 'PriceList[0]' \
        --output text 2>/dev/null | jq -r '.terms.OnDemand | to_entries[0].value.priceDimensions | to_entries[0].value.pricePerUnit.USD' 2>/dev/null || echo "0.0416")
    
    MONGODB_MONTHLY=$(echo "$MONGODB_PRICE * 24 * 30" | bc -l 2>/dev/null || echo "30.00")
    echo "- MongoDB EC2 Instance (t3.medium): \$${MONGODB_MONTHLY}/month" >> "$BOM_FILE"
    
    # EKS Node Group pricing (assuming t3.medium)
    NODE_GROUP_PRICE=$(echo "$MONGODB_PRICE * 2 * 24 * 30" | bc -l 2>/dev/null || echo "60.00")  # 2 nodes
    echo "- EKS Node Group (2x t3.medium): \$${NODE_GROUP_PRICE}/month" >> "$BOM_FILE"
    
    # ALB pricing
    ALB_PRICE="22.50"  # $0.0225/hour * 24 * 30
    echo "- Application Load Balancer: \$${ALB_PRICE}/month" >> "$BOM_FILE"
    
    # NAT Gateway pricing
    NAT_PRICE="32.40"  # $0.045/hour * 24 * 30
    echo "- NAT Gateway: \$${NAT_PRICE}/month" >> "$BOM_FILE"
    
    # S3 pricing (estimated)
    S3_PRICE="5.00"
    echo "- S3 Bucket (backups): \$${S3_PRICE}/month" >> "$BOM_FILE"
    
    # EBS pricing (estimated)
    EBS_PRICE="10.00"
    echo "- EBS Volumes: \$${EBS_PRICE}/month" >> "$BOM_FILE"
    
    # Calculate total
    TOTAL=$(echo "$EKS_PRICE + $MONGODB_MONTHLY + $NODE_GROUP_PRICE + $ALB_PRICE + $NAT_PRICE + $S3_PRICE + $EBS_PRICE" | bc -l 2>/dev/null || echo "200.00")
    
    cat >> "$BOM_FILE" << EOF

ESTIMATED TOTAL: \$${TOTAL}/month

=======================================================
NOTES:
=======================================================
- Costs are estimates based on us-east-1 pricing
- Actual costs may vary based on usage patterns
- Data transfer costs not included
- Backup storage costs may vary based on retention
- EKS cluster cost is fixed at \$72/month regardless of usage
- EC2 and ALB costs are based on 24/7 operation

=======================================================
COST OPTIMIZATION RECOMMENDATIONS:
=======================================================
- Use Spot instances for EKS nodes (50-70% savings)
- Implement auto-scaling for EKS nodes
- Use S3 Intelligent Tiering for backups
- Consider using EKS Fargate for specific workloads
- Monitor and right-size instances based on actual usage

EOF
}

# Generate cost comparison report
generate_cost_comparison() {
    echo -e "${YELLOW}📈 Generating cost comparison...${NC}"
    
    cat >> "$BOM_FILE" << EOF
=======================================================
COST COMPARISON: Traditional vs Cloud-Native ALB
=======================================================

BEFORE (Dual ALB Setup):
- Terraform-managed ALB: \$22.50/month
- Kubernetes-managed ALB: \$22.50/month
- Total ALB costs: \$45.00/month

AFTER (Cloud-Native Setup):
- Kubernetes-managed ALB only: \$22.50/month
- Monthly savings: \$22.50
- Annual savings: \$270.00

ARCHITECTURE BENEFITS:
- 50% reduction in ALB costs
- Simplified infrastructure management
- Better integration with Kubernetes services
- Automatic target group management

EOF
}

# Main execution
main() {
    check_prerequisites
    extract_terraform_resources
    generate_bom
    get_aws_pricing
    generate_cost_comparison
    
    echo -e "${GREEN}✅ Cost analysis complete!${NC}"
    echo ""
    echo -e "${BLUE}📄 Files generated:${NC}"
    echo "- Terraform analysis: $TERRAFORM_DIR/$OUTPUT_FILE"
    echo "- Bill of Materials: $BOM_FILE"
    echo ""
    echo -e "${BLUE}📊 Cost Summary:${NC}"
    grep "ESTIMATED TOTAL" "$BOM_FILE"
    echo ""
    echo -e "${YELLOW}💡 View detailed cost breakdown:${NC}"
    echo "cat $BOM_FILE"
    echo ""
    echo -e "${YELLOW}🔗 For detailed AWS pricing:${NC}"
    echo "https://calculator.aws/"
}

# Run main function
main "$@"
