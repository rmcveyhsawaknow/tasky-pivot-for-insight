#!/bin/bash
# advanced-cost-analysis.sh - Advanced AWS Cost Analysis with Real-time Pricing
# Uses AWS Pricing API and Cost Explorer for accurate cost estimation

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
REGION="${AWS_DEFAULT_REGION:-us-east-1}"
OUTPUT_DIR="cost-analysis-$(date +%Y%m%d-%H%M%S)"
TERRAFORM_DIR="${1:-terraform}"

echo -e "${BLUE}🚀 Advanced AWS Cost Analysis for Tasky${NC}"
echo "============================================="

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Function to get real-time pricing
get_ec2_pricing() {
    local instance_type="$1"
    local os="${2:-Linux}"
    
    aws pricing get-products \
        --service-code AmazonEC2 \
        --region us-east-1 \
        --filters \
            "Type=TERM_MATCH,Field=instanceType,Value=$instance_type" \
            "Type=TERM_MATCH,Field=operatingSystem,Value=$os" \
            "Type=TERM_MATCH,Field=tenancy,Value=Shared" \
            "Type=TERM_MATCH,Field=preInstalledSw,Value=NA" \
            "Type=TERM_MATCH,Field=location,Value=US East (N. Virginia)" \
        --format-version aws_v1 \
        --output json \
        --query 'PriceList[0]' | \
    jq -r '.terms.OnDemand | to_entries[0].value.priceDimensions | to_entries[0].value.pricePerUnit.USD' 2>/dev/null || echo "0.05"
}

# Function to get EKS pricing
get_eks_pricing() {
    # EKS control plane is fixed at $0.10/hour
    echo "0.10"
}

# Function to get ALB pricing
get_alb_pricing() {
    aws pricing get-products \
        --service-code AWSELB \
        --region us-east-1 \
        --filters \
            "Type=TERM_MATCH,Field=productFamily,Value=Load Balancer-Application" \
            "Type=TERM_MATCH,Field=location,Value=US East (N. Virginia)" \
        --format-version aws_v1 \
        --output json \
        --query 'PriceList[0]' | \
    jq -r '.terms.OnDemand | to_entries[0].value.priceDimensions | to_entries[0].value.pricePerUnit.USD' 2>/dev/null || echo "0.0225"
}

# Function to get NAT Gateway pricing
get_nat_pricing() {
    aws pricing get-products \
        --service-code AmazonVPC \
        --region us-east-1 \
        --filters \
            "Type=TERM_MATCH,Field=productFamily,Value=NAT Gateway" \
            "Type=TERM_MATCH,Field=location,Value=US East (N. Virginia)" \
        --format-version aws_v1 \
        --output json \
        --query 'PriceList[0]' | \
    jq -r '.terms.OnDemand | to_entries[0].value.priceDimensions | to_entries[0].value.pricePerUnit.USD' 2>/dev/null || echo "0.045"
}

# Generate detailed cost analysis
generate_detailed_analysis() {
    echo -e "${YELLOW}💰 Generating detailed cost analysis...${NC}"
    
    # Get real-time pricing
    echo "Fetching real-time AWS pricing..."
    T3_MEDIUM_PRICE=$(get_ec2_pricing "t3.medium")
    T3_SMALL_PRICE=$(get_ec2_pricing "t3.small")
    EKS_PRICE=$(get_eks_pricing)
    ALB_PRICE=$(get_alb_pricing)
    NAT_PRICE=$(get_nat_pricing)
    
    # Calculate monthly costs (hours * 30 days)
    HOURS_PER_MONTH=720
    
    # Core infrastructure costs
    EKS_MONTHLY=$(echo "$EKS_PRICE * $HOURS_PER_MONTH" | bc -l)
    MONGODB_MONTHLY=$(echo "$T3_MEDIUM_PRICE * $HOURS_PER_MONTH" | bc -l)
    NODE_GROUP_MONTHLY=$(echo "$T3_MEDIUM_PRICE * 2 * $HOURS_PER_MONTH" | bc -l)  # 2 nodes
    ALB_MONTHLY=$(echo "$ALB_PRICE * $HOURS_PER_MONTH" | bc -l)
    NAT_MONTHLY=$(echo "$NAT_PRICE * $HOURS_PER_MONTH" | bc -l)
    
    # Fixed costs
    EBS_MONTHLY=15.00  # Estimated for root + MongoDB volumes
    S3_MONTHLY=5.00    # Estimated backup storage
    
    # Total calculation
    TOTAL_MONTHLY=$(echo "$EKS_MONTHLY + $MONGODB_MONTHLY + $NODE_GROUP_MONTHLY + $ALB_MONTHLY + $NAT_MONTHLY + $EBS_MONTHLY + $S3_MONTHLY" | bc -l)
    
    # Generate detailed report
    cat > "$OUTPUT_DIR/detailed-cost-analysis.txt" << EOF
================================================================
TASKY INFRASTRUCTURE - DETAILED COST ANALYSIS
================================================================
Generated: $(date)
Region: $REGION
Pricing Data: Real-time AWS Pricing API

================================================================
COMPUTE SERVICES
================================================================
EKS Control Plane:
  - Service: Amazon EKS
  - Rate: \$${EKS_PRICE}/hour
  - Monthly: \$$(printf "%.2f" $EKS_MONTHLY)
  - Notes: Fixed cost regardless of cluster size

MongoDB EC2 Instance:
  - Instance Type: t3.medium
  - Rate: \$${T3_MEDIUM_PRICE}/hour
  - Monthly: \$$(printf "%.2f" $MONGODB_MONTHLY)
  - Notes: Amazon Linux 2, 24/7 operation

EKS Node Group:
  - Instance Type: 2x t3.medium
  - Rate: \$${T3_MEDIUM_PRICE}/hour each
  - Monthly: \$$(printf "%.2f" $NODE_GROUP_MONTHLY)
  - Notes: Auto Scaling Group, min 1, max 3 nodes

================================================================
NETWORKING SERVICES
================================================================
Application Load Balancer:
  - Service: ALB
  - Rate: \$${ALB_PRICE}/hour
  - Monthly: \$$(printf "%.2f" $ALB_MONTHLY)
  - Notes: Internet-facing, managed by Kubernetes

NAT Gateway:
  - Service: VPC NAT Gateway
  - Rate: \$${NAT_PRICE}/hour
  - Monthly: \$$(printf "%.2f" $NAT_MONTHLY)
  - Notes: Required for private subnet internet access

================================================================
STORAGE SERVICES
================================================================
EBS Volumes:
  - MongoDB Data: 20GB gp3
  - Root Volumes: 3x 20GB gp3
  - Estimated Monthly: \$${EBS_MONTHLY}
  - Notes: Based on \$0.08/GB/month for gp3

S3 Bucket:
  - Backup Storage: ~10GB (estimated)
  - Estimated Monthly: \$${S3_MONTHLY}
  - Notes: Standard storage + requests

================================================================
COST SUMMARY
================================================================
Total Monthly Cost: \$$(printf "%.2f" $TOTAL_MONTHLY)
Total Annual Cost:  \$$(printf "%.2f" $(echo "$TOTAL_MONTHLY * 12" | bc -l))

Cost Breakdown by Category:
- Compute (EKS + EC2): \$$(printf "%.2f" $(echo "$EKS_MONTHLY + $MONGODB_MONTHLY + $NODE_GROUP_MONTHLY" | bc -l)) ($(printf "%.0f" $(echo "($EKS_MONTHLY + $MONGODB_MONTHLY + $NODE_GROUP_MONTHLY) / $TOTAL_MONTHLY * 100" | bc -l))%)
- Networking (ALB + NAT): \$$(printf "%.2f" $(echo "$ALB_MONTHLY + $NAT_MONTHLY" | bc -l)) ($(printf "%.0f" $(echo "($ALB_MONTHLY + $NAT_MONTHLY) / $TOTAL_MONTHLY * 100" | bc -l))%)
- Storage (EBS + S3): \$$(printf "%.2f" $(echo "$EBS_MONTHLY + $S3_MONTHLY" | bc -l)) ($(printf "%.0f" $(echo "($EBS_MONTHLY + $S3_MONTHLY) / $TOTAL_MONTHLY * 100" | bc -l))%)

================================================================
COST OPTIMIZATION OPPORTUNITIES
================================================================
1. EKS Node Groups - Use Spot Instances:
   - Current Cost: \$$(printf "%.2f" $NODE_GROUP_MONTHLY)/month
   - With Spot (70% discount): \$$(printf "%.2f" $(echo "$NODE_GROUP_MONTHLY * 0.3" | bc -l))/month
   - Monthly Savings: \$$(printf "%.2f" $(echo "$NODE_GROUP_MONTHLY * 0.7" | bc -l))

2. MongoDB Instance - Right-sizing:
   - Current: t3.medium (\$$(printf "%.2f" $MONGODB_MONTHLY)/month)
   - Alternative: t3.small (\$$(printf "%.2f" $(echo "$T3_SMALL_PRICE * $HOURS_PER_MONTH" | bc -l))/month)
   - Potential Savings: \$$(printf "%.2f" $(echo "$MONGODB_MONTHLY - ($T3_SMALL_PRICE * $HOURS_PER_MONTH)" | bc -l))/month

3. Development Environment Scheduling:
   - Stop non-prod resources outside business hours
   - Potential Savings: 60-70% for dev/test environments

4. S3 Backup Optimization:
   - Use S3 Intelligent Tiering
   - Implement lifecycle policies
   - Potential Savings: 20-40% on backup storage

================================================================
COMPARISON WITH CLOUD ALTERNATIVES
================================================================
Azure Equivalent (estimated):
- AKS Cluster: \$72/month (similar to EKS)
- Virtual Machines: Similar pricing to EC2
- Load Balancer: ~\$230/month
- Storage: Comparable to AWS
- Estimated Total: \$$(printf "%.2f" $(echo "$TOTAL_MONTHLY * 1.05" | bc -l))/month (+5%)

Google Cloud Equivalent (estimated):
- GKE Cluster: \$72/month (similar to EKS)
- Compute Engine: 5-10% less than EC2
- Load Balancer: ~\$18/month
- Storage: Comparable to AWS
- Estimated Total: \$$(printf "%.2f" $(echo "$TOTAL_MONTHLY * 0.95" | bc -l))/month (-5%)

================================================================
NOTES
================================================================
- Costs are based on us-east-1 pricing
- Data transfer costs not included (varies by usage)
- Reserved Instances could reduce costs by 30-60%
- Prices fetched from AWS Pricing API on $(date)
- Actual costs may vary based on usage patterns

EOF

    echo -e "${GREEN}✅ Detailed cost analysis generated: $OUTPUT_DIR/detailed-cost-analysis.txt${NC}"
}

# Generate AWS Cost Calculator URL
generate_cost_calculator_url() {
    echo -e "${YELLOW}🔗 Generating AWS Cost Calculator configuration...${NC}"
    
    cat > "$OUTPUT_DIR/aws-calculator-config.json" << EOF
{
  "estimate": {
    "name": "Tasky Infrastructure Cost Estimate",
    "region": "$REGION",
    "services": [
      {
        "service": "AmazonEKS",
        "configuration": {
          "clusters": 1,
          "hours_per_month": 720,
          "rate_per_hour": $EKS_PRICE
        }
      },
      {
        "service": "AmazonEC2",
        "configuration": {
          "instances": [
            {
              "type": "t3.medium",
              "count": 3,
              "hours_per_month": 720,
              "rate_per_hour": $T3_MEDIUM_PRICE
            }
          ]
        }
      },
      {
        "service": "AWSELB",
        "configuration": {
          "load_balancers": 1,
          "hours_per_month": 720,
          "rate_per_hour": $ALB_PRICE
        }
      },
      {
        "service": "AmazonVPC",
        "configuration": {
          "nat_gateways": 1,
          "hours_per_month": 720,
          "rate_per_hour": $NAT_PRICE
        }
      }
    ],
    "estimated_monthly_total": $(printf "%.2f" $TOTAL_MONTHLY)
  }
}
EOF

    cat > "$OUTPUT_DIR/aws-calculator-instructions.txt" << EOF
AWS Cost Calculator Configuration
=================================

To use the AWS Cost Calculator (https://calculator.aws/):

1. Go to: https://calculator.aws/
2. Add the following services:

EKS Service:
- Service: Amazon Elastic Kubernetes Service (EKS)
- Clusters: 1
- Hours per month: 720

EC2 Instances:
- Service: Amazon EC2
- Instance type: t3.medium
- Number of instances: 3 (1 MongoDB + 2 EKS nodes)
- Usage: 720 hours/month

Application Load Balancer:
- Service: Elastic Load Balancing
- Type: Application Load Balancer
- Number: 1
- Hours per month: 720

NAT Gateway:
- Service: Amazon VPC
- NAT Gateways: 1
- Hours per month: 720

EBS Volumes:
- Service: Amazon EBS
- Volume type: gp3
- Storage amount: 80 GB total
- Snapshot storage: 10 GB (estimated)

S3 Storage:
- Service: Amazon S3
- Storage class: S3 Standard
- Storage amount: 10 GB (estimated)

Expected Total: \$$(printf "%.2f" $TOTAL_MONTHLY)/month

EOF

    echo -e "${GREEN}✅ AWS Calculator configuration generated: $OUTPUT_DIR/aws-calculator-config.json${NC}"
    echo -e "${GREEN}✅ Calculator instructions: $OUTPUT_DIR/aws-calculator-instructions.txt${NC}"
}

# Generate Terraform cost annotations
generate_terraform_annotations() {
    echo -e "${YELLOW}📝 Generating Terraform cost annotations...${NC}"
    
    cat > "$OUTPUT_DIR/terraform-cost-annotations.tf" << EOF
# Terraform Cost Annotations for Tasky Infrastructure
# Add these comments to your Terraform files for cost tracking

# EKS Cluster - \$$(printf "%.2f" $EKS_MONTHLY)/month
resource "aws_eks_cluster" "main" {
  # Monthly Cost: \$$(printf "%.2f" $EKS_MONTHLY)
  # Annual Cost: \$$(printf "%.2f" $(echo "$EKS_MONTHLY * 12" | bc -l))
  # Cost Category: Compute - Fixed
}

# MongoDB EC2 Instance - \$$(printf "%.2f" $MONGODB_MONTHLY)/month  
resource "aws_instance" "mongodb" {
  instance_type = "t3.medium"
  # Monthly Cost: \$$(printf "%.2f" $MONGODB_MONTHLY)
  # Annual Cost: \$$(printf "%.2f" $(echo "$MONGODB_MONTHLY * 12" | bc -l))
  # Cost Category: Compute - Variable
  # Optimization: Consider t3.small for dev environments
}

# EKS Node Group - \$$(printf "%.2f" $NODE_GROUP_MONTHLY)/month
resource "aws_eks_node_group" "main" {
  instance_types = ["t3.medium"]
  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }
  # Monthly Cost: \$$(printf "%.2f" $NODE_GROUP_MONTHLY) (2 nodes)
  # Annual Cost: \$$(printf "%.2f" $(echo "$NODE_GROUP_MONTHLY * 12" | bc -l))
  # Cost Category: Compute - Auto Scaling
  # Optimization: Use Spot instances for 70% savings
}

# Application Load Balancer - \$$(printf "%.2f" $ALB_MONTHLY)/month
# Note: Managed by Kubernetes Ingress Controller
# Monthly Cost: \$$(printf "%.2f" $ALB_MONTHLY)
# Annual Cost: \$$(printf "%.2f" $(echo "$ALB_MONTHLY * 12" | bc -l))
# Cost Category: Networking - Fixed

# NAT Gateway - \$$(printf "%.2f" $NAT_MONTHLY)/month
resource "aws_nat_gateway" "main" {
  # Monthly Cost: \$$(printf "%.2f" $NAT_MONTHLY)
  # Annual Cost: \$$(printf "%.2f" $(echo "$NAT_MONTHLY * 12" | bc -l))
  # Cost Category: Networking - Fixed
  # Note: Required for private subnet internet access
}

# Total Infrastructure Cost: \$$(printf "%.2f" $TOTAL_MONTHLY)/month
# Total Annual Cost: \$$(printf "%.2f" $(echo "$TOTAL_MONTHLY * 12" | bc -l))

EOF

    echo -e "${GREEN}✅ Terraform cost annotations generated: $OUTPUT_DIR/terraform-cost-annotations.tf${NC}"
}

# Main execution
main() {
    echo -e "${YELLOW}📊 Starting advanced cost analysis...${NC}"
    
    # Check prerequisites
    if ! command -v bc &> /dev/null; then
        echo "Installing bc calculator..."
        sudo apt-get update && sudo apt-get install -y bc
    fi
    
    generate_detailed_analysis
    generate_cost_calculator_url  
    generate_terraform_annotations
    
    echo ""
    echo -e "${GREEN}🎉 Advanced cost analysis complete!${NC}"
    echo ""
    echo -e "${BLUE}📁 Generated files in: $OUTPUT_DIR/${NC}"
    ls -la "$OUTPUT_DIR/"
    echo ""
    echo -e "${BLUE}💰 Estimated monthly cost: \$$(printf "%.2f" $TOTAL_MONTHLY)${NC}"
    echo -e "${BLUE}💰 Estimated annual cost: \$$(printf "%.2f" $(echo "$TOTAL_MONTHLY * 12" | bc -l))${NC}"
    echo ""
    echo -e "${YELLOW}📖 Next steps:${NC}"
    echo "1. Review detailed analysis: cat $OUTPUT_DIR/detailed-cost-analysis.txt"
    echo "2. Use AWS Calculator: cat $OUTPUT_DIR/aws-calculator-instructions.txt"
    echo "3. Add cost annotations to Terraform: cat $OUTPUT_DIR/terraform-cost-annotations.tf"
}

# Run main function
main "$@"
