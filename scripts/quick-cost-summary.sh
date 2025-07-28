#!/bin/bash
# quick-cost-summary.sh - Quick cost summary for Tasky infrastructure

echo "🧮 Tasky Infrastructure - Quick Cost Summary"
echo "============================================="
echo ""

# AWS Pricing (us-east-1, on-demand, as of 2025)
EKS_MONTHLY=72.00           # $0.10/hour * 720 hours
T3_MEDIUM_MONTHLY=30.24     # $0.042/hour * 720 hours  
ALB_MONTHLY=16.20           # $0.0225/hour * 720 hours
NAT_MONTHLY=32.40           # $0.045/hour * 720 hours
EBS_MONTHLY=15.00           # ~80GB gp3 storage
S3_MONTHLY=5.00             # ~10GB standard storage

echo "📊 Monthly Cost Breakdown:"
echo "-------------------------"
printf "EKS Control Plane:     \$%6.2f\n" $EKS_MONTHLY
printf "MongoDB EC2 (t3.medium): \$%6.2f\n" $T3_MEDIUM_MONTHLY
printf "EKS Nodes (2x t3.medium): \$%6.2f\n" $(echo "$T3_MEDIUM_MONTHLY * 2" | bc)
printf "Application Load Balancer: \$%6.2f\n" $ALB_MONTHLY
printf "NAT Gateway:           \$%6.2f\n" $NAT_MONTHLY
printf "EBS Volumes:           \$%6.2f\n" $EBS_MONTHLY
printf "S3 Backup Storage:     \$%6.2f\n" $S3_MONTHLY
echo "-------------------------"

TOTAL=$(echo "$EKS_MONTHLY + $T3_MEDIUM_MONTHLY + ($T3_MEDIUM_MONTHLY * 2) + $ALB_MONTHLY + $NAT_MONTHLY + $EBS_MONTHLY + $S3_MONTHLY" | bc)
printf "TOTAL MONTHLY:         \$%6.2f\n" $TOTAL
printf "TOTAL ANNUAL:          \$%7.2f\n" $(echo "$TOTAL * 12" | bc)

echo ""
echo "💡 Cost Optimization Opportunities:"
echo "-----------------------------------"
echo "• Use Spot instances for EKS nodes: Save ~\$42/month (70% discount)"
echo "• Right-size MongoDB to t3.small: Save ~\$15/month"
echo "• Implement auto-scaling: Save 30-50% in dev environments"
echo "• Use Reserved Instances: Save 30-60% with 1-3 year commitments"
echo ""

echo "⚠️  Cost Correction from README:"
echo "-------------------------------"
echo "• Previous estimate: \$230/month ❌"
echo "• Corrected estimate: \$$(printf "%.0f" $TOTAL)/month ✅"
echo "• Main oversight: EKS control plane cost (\$72/month)"
echo ""

echo "🔗 For detailed analysis, run:"
echo "  ./scripts/cost-terraform.sh"
echo "  ./scripts/advanced-cost-analysis.sh"
