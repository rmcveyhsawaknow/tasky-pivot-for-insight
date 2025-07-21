# Application Load Balancer (ALB) Setup Guide

## Overview

This guide explains how to set up a cost-effective AWS Application Load Balancer (ALB) for the Tasky containerized web application running on EKS, including custom domain configuration for `ideatasky.ryanmcvey.me`.

## Architecture Changes

### Before (Network Load Balancer)
- Kubernetes Service: `LoadBalancer` type with NLB annotations
- Higher cost, less features for web applications
- Direct exposure through AWS NLB

### After (Application Load Balancer)
- Kubernetes Service: `ClusterIP` type
- Kubernetes Ingress: ALB Ingress Controller
- Lower cost, more web-specific features
- SSL termination, path-based routing, health checks

## Cost Benefits

### ALB vs NLB Cost Comparison
- **ALB**: ~$16.20/month base cost + $0.008/LCU-hour
- **NLB**: ~$16.20/month base cost + $0.006/NLCU-hour
- **ALB Advantages**: 
  - Better for HTTP/HTTPS workloads
  - Built-in SSL termination
  - Content-based routing
  - Integration with AWS WAF
  - Better health checks for web applications

## Prerequisites

1. **Terraform Applied**: Complete infrastructure must be deployed
2. **kubectl**: Configured for your EKS cluster
3. **Helm**: Version 3.x installed
4. **AWS CLI**: Configured with appropriate permissions

## Deployment Steps

### Step 1: Apply Terraform Configuration

```bash
cd terraform
terraform plan
terraform apply
```

### Step 2: Install AWS Load Balancer Controller

Run the automated setup script:

```bash
./scripts/setup-alb-controller.sh
```

Or manually install:

```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name $(terraform output -raw eks_cluster_name)

# Install Helm chart
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Create service account with IRSA
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/component: controller
    app.kubernetes.io/name: aws-load-balancer-controller
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: $(terraform output -raw eks_aws_load_balancer_controller_role_arn)
EOF

# Install controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$(terraform output -raw eks_cluster_name) \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=us-east-1
```

### Step 3: Deploy Application

```bash
kubectl apply -f k8s/
```

### Step 4: Get ALB DNS Name

```bash
kubectl get ingress tasky-ingress -n tasky
```

Example output:
```
NAME            CLASS    HOSTS                   ADDRESS                                    PORTS   AGE
tasky-ingress   <none>   ideatasky.ryanmcvey.me  k8s-tasky-taskyingr-abc123-1234567890.us-east-1.elb.amazonaws.com   80      2m
```

## Custom Domain Configuration

### Step 5: Configure Cloudflare DNS

1. **Log into Cloudflare Dashboard**
2. **Select your domain** `ryanmcvey.me`
3. **Add DNS Record**:
   - **Type**: CNAME
   - **Name**: `ideatasky`
   - **Target**: `<ALB-DNS-NAME>` (from Step 4)
   - **TTL**: Auto
   - **Proxy Status**: DNS Only (grey cloud)

Example:
```
Type: CNAME
Name: ideatasky
Target: k8s-tasky-taskyingr-abc123-1234567890.us-east-1.elb.amazonaws.com
TTL: Auto
```

### Step 6: SSL Certificate Setup (Optional)

For HTTPS support, you can:

1. **Use AWS Certificate Manager (ACM)**:
   ```bash
   # Request certificate in ACM
   aws acm request-certificate \
     --domain-name ideatasky.ryanmcvey.me \
     --validation-method DNS \
     --region us-east-1
   ```

2. **Update Ingress for HTTPS**:
   ```yaml
   # Update k8s/ingress.yaml annotations
   alb.ingress.kubernetes.io/ssl-redirect: '443'
   alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-1:ACCOUNT:certificate/CERT-ID
   alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
   ```

3. **Use Cloudflare SSL (Recommended)**:
   - Enable "Full" or "Full (Strict)" SSL mode in Cloudflare
   - Change proxy status to "Proxied" (orange cloud)
   - Cloudflare will handle SSL termination

## Verification

### Test Application Access

1. **Via ALB DNS**: `http://<ALB-DNS-NAME>`
2. **Via Custom Domain**: `http://ideatasky.ryanmcvey.me`

### Health Check Verification

```bash
# Check ALB health
kubectl describe ingress tasky-ingress -n tasky

# Check target group health in AWS Console
aws elbv2 describe-target-health --target-group-arn $(terraform output -raw alb_target_group_arn)
```

### Application Logs

```bash
# Check application pods
kubectl get pods -n tasky

# Check application logs
kubectl logs -l app.kubernetes.io/name=tasky -n tasky

# Check ALB controller logs
kubectl logs -l app.kubernetes.io/name=aws-load-balancer-controller -n kube-system
```

## Troubleshooting

### Common Issues

1. **Ingress not getting ALB DNS**:
   ```bash
   # Check controller logs
   kubectl logs -l app.kubernetes.io/name=aws-load-balancer-controller -n kube-system
   
   # Check service account
   kubectl describe sa aws-load-balancer-controller -n kube-system
   ```

2. **504 Gateway Timeout**:
   - Check application health endpoint
   - Verify security group rules
   - Check target group health

3. **502 Bad Gateway**:
   - Verify application is running on correct port (8080)
   - Check service selector matches pod labels

### Debug Commands

```bash
# Check all resources
kubectl get ingress,svc,pods -n tasky

# Describe ingress for events
kubectl describe ingress tasky-ingress -n tasky

# Check ALB in AWS Console
aws elbv2 describe-load-balancers --region us-east-1

# Check target groups
aws elbv2 describe-target-groups --region us-east-1
```

## Cost Optimization Tips

1. **Idle Timeout**: Set to 60 seconds (configured in ingress)
2. **Health Check Interval**: 30 seconds (balanced cost vs responsiveness)
3. **Access Logs**: Disabled by default to save S3 costs
4. **Multiple Applications**: Use path-based routing on same ALB

## Security Considerations

1. **Security Groups**: ALB security group allows HTTP/HTTPS from anywhere
2. **Target Groups**: Only ALB can reach application pods
3. **HTTPS**: Enable for production workloads
4. **WAF**: Consider AWS WAF integration for additional protection

## Next Steps

1. **Monitoring**: Set up CloudWatch dashboards for ALB metrics
2. **SSL Certificate**: Configure HTTPS with ACM or Cloudflare
3. **Auto Scaling**: Configure HPA based on ALB target group metrics
4. **Blue/Green Deployments**: Use ALB listener rules for deployment strategies

## Resources

- [AWS Load Balancer Controller Documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [ALB Ingress Annotations Reference](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/guide/ingress/annotations/)
- [EKS Best Practices for Load Balancing](https://aws.github.io/aws-eks-best-practices/reliability/docs/networkingbestpractices/)
