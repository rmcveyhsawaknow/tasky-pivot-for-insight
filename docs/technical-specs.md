# Technical Specifications

## Architecture Overview

This document provides detailed technical specifications for the Tasky application deployment on AWS, implementing a three-tier web application architecture as part of the Insight Technical Exercise.

## Infrastructure Components

### Web Tier - Amazon EKS
- **Service**: Amazon Elastic Kubernetes Service (EKS)
- **Version**: 1.28
- **Node Configuration**:
  - Instance Type: t3.medium
  - Node Count: 2-3 (auto-scaling)
  - Capacity Type: On-Demand
- **Container Runtime**: containerd
- **CNI**: AWS VPC CNI
- **Add-ons**: EBS CSI Driver, CoreDNS, kube-proxy

### Data Tier - MongoDB on EC2
- **Operating System**: Amazon Linux 2 (legacy requirement)
- **MongoDB Version**: 4.0.28 (legacy requirement)
- **Instance Type**: t3.medium
- **Storage**: 20GB GP3 EBS volume, encrypted
- **Authentication**: Enabled with username/password
- **Network**: Private subnet, port 27017
- **IAM Role**: AdministratorAccess (as required)

### Storage Tier - Amazon S3
- **Bucket Configuration**: Public read access enabled
- **Versioning**: Enabled
- **Lifecycle Policy**: 30-day retention, 7-day non-current version expiration
- **Access Pattern**: Public URLs for backup files
- **Backup Schedule**: Daily at 2 AM UTC via cron job

## Network Architecture

### VPC Configuration
- **CIDR Block**: 10.0.0.0/16
- **Availability Zones**: 3 (us-east-2a, us-east-2b, us-east-2c)
- **Public Subnets**: 3 (10.0.0.0/24, 10.0.1.0/24, 10.0.2.0/24)
- **Private Subnets**: 3 (10.0.3.0/24, 10.0.4.0/24, 10.0.5.0/24)
- **NAT Gateways**: 3 (one per AZ for high availability)
- **Internet Gateway**: 1

### Security Groups
1. **EKS Security Group**:
   - Inbound: Managed by EKS
   - Outbound: MongoDB on port 27017, internet access
2. **MongoDB Security Group**:
   - Inbound: Port 27017 from EKS, SSH from VPC
   - Outbound: Internet access for updates and S3

## Application Specifications

### Container Configuration
- **Base Image**: golang:1.19 (multi-stage build with alpine:3.17.0)
- **Port**: 8080
- **Resource Limits**: 500m CPU, 512Mi memory
- **Resource Requests**: 100m CPU, 128Mi memory
- **Health Checks**: Liveness and readiness probes
- **Security Context**: Non-root user (65534)

### Environment Variables
- `MONGODB_URI`: Connection string with authentication
- `SECRET_KEY`: JWT secret for authentication
- `PORT`: Application port (8080)
- `GIN_MODE`: Production mode setting

### Kubernetes Configuration
- **Namespace**: tasky
- **Service Account**: tasky-admin (cluster-admin permissions)
- **Deployment**: 2 replicas with rolling update strategy
- **Service**: LoadBalancer type with NLB annotation
- **Secrets**: MongoDB URI and JWT secret (base64 encoded)
- **ConfigMap**: Application configuration

## Security Configuration

### IAM Roles and Policies
1. **MongoDB EC2 Instance**:
   - Role: AdministratorAccess (as required)
   - Purpose: S3 backup operations, CloudWatch logging
2. **EKS Cluster Role**:
   - Policies: AmazonEKSClusterPolicy
3. **EKS Node Group Role**:
   - Policies: AmazonEKSWorkerNodePolicy, AmazonEKS_CNI_Policy, AmazonEC2ContainerRegistryReadOnly

### RBAC Configuration
- **Service Account**: tasky-admin
- **Cluster Role Binding**: cluster-admin (as required)
- **Scope**: All cluster resources and operations

### Network Security
- **Encryption in Transit**: TLS for all communication
- **Encryption at Rest**: EBS volumes encrypted
- **MongoDB Authentication**: Username/password with authenticationDatabase
- **Firewall Rules**: Restrictive security groups

## Backup Strategy

### MongoDB Backup Process
1. **Tool**: mongodump with authentication
2. **Frequency**: Daily at 2 AM UTC
3. **Retention**: 30 days in S3
4. **Compression**: gzip tar archives
5. **Upload**: AWS CLI to S3 bucket
6. **Public Access**: Direct URLs for demonstration

### Backup File Structure
```
s3://bucket-name/backups/
├── mongodb-backup-2024-01-15-20240115_020000.tar.gz
├── mongodb-backup-2024-01-16-20240116_020000.tar.gz
├── daily-2024-01-15.tar.gz
├── daily-2024-01-16.tar.gz
└── latest.tar.gz
```

## Monitoring and Logging

### CloudWatch Integration
- **EC2 Logs**: MongoDB logs, backup logs
- **EKS Logs**: API server, audit, authenticator, controller manager, scheduler
- **Application Logs**: Container stdout/stderr
- **Metrics**: EC2 instance metrics, EKS cluster metrics

### Log Groups
- `/aws/ec2/mongodb`: MongoDB and backup logs
- `/aws/eks/cluster-name/cluster`: EKS control plane logs

## Compliance Matrix

| Requirement | Implementation | Status |
|-------------|----------------|--------|
| Three-tier architecture | EKS + EC2 + S3 | ✅ |
| MongoDB authentication | Connection string auth | ✅ |
| Public S3 access | Bucket policy for public read | ✅ |
| Legacy OS | Amazon Linux 2 | ✅ |
| Legacy MongoDB | Version 4.0.28 | ✅ |
| Highly privileged VM | AdministratorAccess IAM role | ✅ |
| Container admin permissions | cluster-admin RBAC | ✅ |
| exercise.txt file | Included in container | ✅ |
| Public application access | LoadBalancer service | ✅ |
| Infrastructure as Code | Complete Terraform deployment | ✅ |

## Performance Characteristics

### Scalability
- **Horizontal**: EKS node auto-scaling (1-3 nodes)
- **Vertical**: Resource limits can be adjusted
- **Database**: Single instance (can be clustered if needed)

### Availability
- **Multi-AZ**: EKS nodes across 3 availability zones
- **Load Balancing**: Network Load Balancer with health checks
- **Database**: Single instance (consider MongoDB replica set for production)

### Expected Load
- **Development/Demo**: Low traffic, suitable for technical presentation
- **Scaling**: Can handle moderate traffic with current configuration
- **Bottlenecks**: MongoDB single instance is potential bottleneck

## Cost Optimization

### Resource Sizing
- **EKS Nodes**: t3.medium suitable for demo workloads
- **MongoDB**: t3.medium adequate for development data
- **S3**: Lifecycle policies to manage backup costs
- **NAT Gateways**: Three for HA (consider single for cost reduction in dev)

### Cost Management
- **Auto-scaling**: Reduces costs during low usage
- **Spot Instances**: Not used for stability in demo environment
- **Reserved Instances**: Consider for long-term deployments

## Troubleshooting Guide

### Common Issues
1. **Pod CrashLoopBackOff**: Check MongoDB connection string in secrets
2. **LoadBalancer Pending**: Verify subnet tags and AWS Load Balancer Controller
3. **MongoDB Connection Failed**: Check security group rules and authentication
4. **S3 Access Denied**: Verify bucket policy and IAM permissions

### Diagnostic Commands
```bash
# Check pod status
kubectl get pods -n tasky

# View pod logs
kubectl logs -f deployment/tasky-app -n tasky

# Check service status
kubectl get svc -n tasky

# Describe failing resources
kubectl describe pod <pod-name> -n tasky

# Test MongoDB connectivity
kubectl exec -it <pod-name> -n tasky -- nc -zv <mongodb-ip> 27017
```

## Future Enhancements

### Production Readiness
- MongoDB replica set for high availability
- Application monitoring with Prometheus/Grafana
- Ingress controller with SSL/TLS termination
- Secrets management with AWS Secrets Manager
- CI/CD pipeline with GitOps

### Security Improvements
- Pod Security Standards enforcement
- Network policies for pod-to-pod communication
- IRSA (IAM Roles for Service Accounts) for fine-grained permissions
- Vulnerability scanning in CI/CD pipeline

### Operational Improvements
- Horizontal Pod Autoscaler (HPA)
- Vertical Pod Autoscaler (VPA)
- Cluster Autoscaler for node scaling
- Backup verification and restore testing
- Disaster recovery procedures
