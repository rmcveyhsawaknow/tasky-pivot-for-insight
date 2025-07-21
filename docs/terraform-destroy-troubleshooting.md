# Terraform Destroy Issues and Solutions

## Overview

This document explains the common issues encountered when running `terraform destroy` on the Tasky infrastructure and provides comprehensive solutions to resolve them.

## Common Destroy Issues

### 1. S3 Bucket Not Empty Error

**Error Message:**
```
Error: deleting S3 Bucket (tasky-dev-v9-mongodb-backup-9lyiss0a): operation error S3: DeleteBucket, 
https response error StatusCode: 409, RequestID: W8VFJ3D227ND8KH6, HostID: dtgQHawDefATPWatIUSJj7PVE1d13I6Pkpdxz2gmS4rV0f/V/kJtxByweZ+lcHqlAriaFH7TG3Y=, 
api error BucketNotEmpty: The bucket you tried to delete is not empty. You must delete all versions in the bucket.
```

**Root Cause:**
- S3 bucket has versioning enabled
- Contains backup files uploaded by the MongoDB backup script
- Terraform cannot delete non-empty buckets by default
- Object versions and delete markers must be removed manually

**Solution:**
The S3 bucket configuration has been updated with `force_destroy = true` to prevent this issue in future deployments. For existing infrastructure, use the cleanup scripts provided.

### 2. Subnet Dependencies Error

**Error Message:**
```
Error: deleting EC2 Subnet (subnet-0594fa3ff772523f3): operation error EC2: DeleteSubnet, 
https response error StatusCode: 400, RequestID: c8331e7a-50c5-4ac3-a028-d971cc6c0417, 
api error DependencyViolation: The subnet 'subnet-0594fa3ff772523f3' has dependencies and cannot be deleted.
```

**Root Causes:**
1. **Elastic Network Interfaces (ENIs)** created by EKS that remain after cluster deletion
2. **ALB Target Group attachments** that weren't properly cleaned up
3. **VPC Endpoints** that may still be attached to subnets
4. **NAT Gateways** that haven't been fully deleted
5. **Lambda Functions** with VPC configuration (if any)
6. **RDS Subnet Groups** (if any)

**Why This Happens:**
- AWS services create ENIs automatically for network connectivity
- These ENIs are not directly managed by Terraform
- When services are deleted, ENIs may remain in "available" state
- Terraform cannot delete subnets while ENIs exist

## Solution Scripts

### 1. Automated Cleanup Script (`cleanup-before-destroy.sh`)

**Purpose:** Automatically cleans up resources that prevent successful terraform destroy.

**Features:**
- Empties S3 buckets including all versions and delete markers
- Removes orphaned ENIs that block subnet deletion
- Cleans up EKS-related LoadBalancer services
- Deregisters ALB target group targets
- Waits for resources to be fully cleaned up

**Usage:**
```bash
cd terraform/
./cleanup-before-destroy.sh
terraform destroy -auto-approve
```

### 2. Manual Cleanup Script (`manual-cleanup.sh`)

**Purpose:** Interactive script for manual resource cleanup when automated script fails.

**Features:**
- Interactive menu-driven interface
- Resource inventory and dependency analysis
- Selective resource cleanup
- ENI and subnet dependency resolution
- Force S3 bucket emptying
- Manual EKS cluster cleanup

**Usage:**
```bash
cd terraform/
./manual-cleanup.sh
```

### 3. Safe Destroy Script (`safe-destroy.sh`)

**Purpose:** Comprehensive destroy process with automatic cleanup and retries.

**Features:**
- Pre-destroy cleanup execution
- Terraform destroy with retries
- Targeted destroy for problematic resources
- Fallback to manual cleanup
- State verification and cleanup options

**Usage:**
```bash
cd terraform/
./safe-destroy.sh
```

## Step-by-Step Destroy Process

### Recommended Approach

1. **Run Safe Destroy Script:**
   ```bash
   cd terraform/
   ./safe-destroy.sh
   ```

2. **If Safe Destroy Fails, Run Manual Steps:**
   ```bash
   # Step 1: Clean up resources
   ./cleanup-before-destroy.sh
   
   # Step 2: Attempt destroy
   terraform destroy -auto-approve
   
   # Step 3: If still failing, run manual cleanup
   ./manual-cleanup.sh
   ```

### Manual Emergency Cleanup

If all scripts fail, follow these manual steps:

1. **Empty S3 Bucket:**
   ```bash
   # Replace bucket-name with your actual bucket name
   aws s3api delete-objects --bucket bucket-name --delete "$(aws s3api list-object-versions --bucket bucket-name --query '{Objects: Versions[].{Key: Key, VersionId: VersionId}}')"
   aws s3api delete-objects --bucket bucket-name --delete "$(aws s3api list-object-versions --bucket bucket-name --query '{Objects: DeleteMarkers[].{Key: Key, VersionId: VersionId}}')"
   aws s3 rm s3://bucket-name --recursive
   ```

2. **Delete Orphaned ENIs:**
   ```bash
   # Replace vpc-id with your VPC ID
   aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=vpc-id" "Name=status,Values=available" --query 'NetworkInterfaces[].NetworkInterfaceId' --output text | xargs -n1 aws ec2 delete-network-interface --network-interface-id
   ```

3. **Delete EKS Services:**
   ```bash
   # Update kubeconfig and delete LoadBalancer services
   aws eks update-kubeconfig --name your-cluster-name
   kubectl get svc --all-namespaces -o wide | grep LoadBalancer
   kubectl delete svc service-name -n namespace
   ```

4. **Targeted Terraform Destroy:**
   ```bash
   terraform destroy -target=module.alb
   terraform destroy -target=module.eks
   terraform destroy -target=module.vpc
   terraform destroy -target=module.s3_backup
   terraform destroy -auto-approve
   ```

## Prevention Measures

### Infrastructure Code Improvements

1. **S3 Bucket Force Destroy:**
   ```hcl
   resource "aws_s3_bucket" "backup" {
     bucket        = local.bucket_name
     force_destroy = true  # Allows destruction even with contents
   }
   ```

2. **Proper Resource Dependencies:**
   - Added explicit `depends_on` relationships
   - Proper resource ordering for destruction
   - Lifecycle rules to prevent premature deletion

3. **ENI Cleanup Automation:**
   - Consider using Lambda functions for automated ENI cleanup
   - Implement proper tagging for resource identification

### Best Practices

1. **Always Run Cleanup First:**
   - Run cleanup scripts before terraform destroy
   - Verify resource cleanup completion

2. **Monitor Resource Creation:**
   - Use AWS CloudTrail to track resource creation
   - Implement proper tagging strategies

3. **Test Destroy Process:**
   - Test destroy process in development environments
   - Document any manual steps required

4. **Use Terraform Workspaces:**
   - Separate environments to isolate destroy operations
   - Easier to test and validate destroy processes

## Troubleshooting Guide

### Issue: Script Permission Denied
```bash
chmod +x *.sh
```

### Issue: AWS CLI Not Configured
```bash
aws configure
# or
export AWS_PROFILE=your-profile
```

### Issue: kubectl Not Working
```bash
aws eks update-kubeconfig --region us-east-1 --name your-cluster-name
```

### Issue: Resources Still Exist After Destroy
1. Check AWS Console for orphaned resources
2. Use AWS CLI to manually delete resources
3. Remove resources from Terraform state as last resort:
   ```bash
   terraform state rm resource_name
   ```

### Issue: State File Corruption
```bash
terraform state list
terraform state show resource_name
terraform import resource_type.name resource_id
```

## Emergency Contacts and Resources

- **AWS Support:** For resource deletion issues that cannot be resolved
- **Terraform Documentation:** https://www.terraform.io/docs/
- **AWS CLI Reference:** https://docs.aws.amazon.com/cli/

## Conclusion

The destroy issues are primarily caused by:
1. AWS services creating resources not directly managed by Terraform
2. S3 bucket versioning preventing automatic cleanup
3. Complex resource dependencies in EKS and networking

The provided scripts automate the resolution of these issues, making the destroy process reliable and predictable. Always use the safe-destroy.sh script as the first approach, falling back to manual cleanup only when necessary.
