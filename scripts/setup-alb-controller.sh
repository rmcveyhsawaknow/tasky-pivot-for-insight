#!/bin/bash

# ==============================================================================
# AWS LOAD BALANCER CONTROLLER INSTALLATION SCRIPT
# ==============================================================================
# This script installs the AWS Load Balancer Controller for EKS
# Run this after Terraform has been applied successfully
# ==============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Cleanup function for failed installations
cleanup_failed_installation() {
    print_warning "Cleaning up failed AWS Load Balancer Controller installation..."
    
    # Remove helm release if it exists in a failed state
    if helm list -n kube-system | grep -q "aws-load-balancer-controller"; then
        print_status "Removing existing Helm release..."
        helm uninstall aws-load-balancer-controller -n kube-system || true
        sleep 10  # Wait for cleanup to complete
    fi
    
    # Remove service account if it exists
    kubectl delete serviceaccount aws-load-balancer-controller -n kube-system --ignore-not-found=true
    
    print_success "Cleanup completed"
}

# Show usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --cleanup    Clean up failed installation before retrying"
    echo "  --help       Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                # Normal installation"
    echo "  $0 --cleanup      # Clean up and install"
    exit 0
}

# Check if required tools are installed
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    
    if ! command -v helm &> /dev/null; then
        print_error "Helm is not installed. Please install Helm first."
        exit 1
    fi
    
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install AWS CLI first."
        exit 1
    fi
    
    print_success "All prerequisites are installed"
}

# Get cluster information from environment variables or Terraform outputs
get_cluster_info() {
    print_status "Getting cluster information..."
    
    # First try to get from environment variables (GitHub Actions workflow)
    if [ -n "$CLUSTER_NAME" ] && [ -n "$AWS_REGION" ]; then
        print_status "Using cluster information from environment variables"
        # SERVICE_ACCOUNT_ROLE_ARN will be constructed from cluster name
        SERVICE_ACCOUNT_ROLE_ARN="arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/${CLUSTER_NAME}-aws-load-balancer-controller"
    else
        # Fallback to Terraform outputs (local development)
        print_status "Getting cluster information from Terraform outputs..."
        
        cd terraform
        
        # Get cluster name and region
        CLUSTER_NAME=$(terraform output -raw eks_cluster_name 2>/dev/null || echo "")
        AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-east-1")
        SERVICE_ACCOUNT_ROLE_ARN=$(terraform output -raw eks_aws_load_balancer_controller_role_arn 2>/dev/null || echo "")
        
        cd ..
    fi
    
    if [ -z "$CLUSTER_NAME" ]; then
        print_error "Could not get cluster name from environment variables or Terraform outputs"
        exit 1
    fi
    
    # If SERVICE_ACCOUNT_ROLE_ARN is still empty, try to construct it
    if [ -z "$SERVICE_ACCOUNT_ROLE_ARN" ]; then
        print_warning "Service account role ARN not found, attempting to construct from cluster name..."
        ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
        if [ -n "$ACCOUNT_ID" ]; then
            SERVICE_ACCOUNT_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${CLUSTER_NAME}-aws-load-balancer-controller"
            print_status "Constructed role ARN: $SERVICE_ACCOUNT_ROLE_ARN"
        else
            print_error "Could not get AWS account ID to construct service account role ARN"
            exit 1
        fi
    fi
    
    print_success "Cluster info retrieved: $CLUSTER_NAME in $AWS_REGION"
}

# Update kubeconfig
update_kubeconfig() {
    print_status "Updating kubeconfig for EKS cluster..."
    aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME
    print_success "Kubeconfig updated"
}

# Install AWS Load Balancer Controller
install_alb_controller() {
    print_status "Installing AWS Load Balancer Controller..."
    
    # Check if AWS Load Balancer Controller is already installed
    if helm list -n kube-system | grep -q "aws-load-balancer-controller"; then
        print_warning "AWS Load Balancer Controller is already installed"
        print_status "Checking if upgrade is needed..."
        
        # Try to upgrade existing installation
        helm repo add eks https://aws.github.io/eks-charts
        helm repo update
        
        print_status "Upgrading existing AWS Load Balancer Controller..."
        helm upgrade aws-load-balancer-controller eks/aws-load-balancer-controller \
            -n kube-system \
            --set clusterName=$CLUSTER_NAME \
            --set serviceAccount.create=false \
            --set serviceAccount.name=aws-load-balancer-controller \
            --set region=$AWS_REGION \
            --set vpcId=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query 'cluster.resourcesVpcConfig.vpcId' --output text) \
            --reuse-values
        
        print_success "AWS Load Balancer Controller upgraded"
        return
    fi
    
    # Add the EKS repository to Helm
    helm repo add eks https://aws.github.io/eks-charts
    helm repo update
    
    # Create service account with IRSA annotations
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/component: controller
    app.kubernetes.io/name: aws-load-balancer-controller
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: $SERVICE_ACCOUNT_ROLE_ARN
EOF
    
    # Install AWS Load Balancer Controller (fresh installation)
    print_status "Installing fresh AWS Load Balancer Controller..."
    helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
        -n kube-system \
        --set clusterName=$CLUSTER_NAME \
        --set serviceAccount.create=false \
        --set serviceAccount.name=aws-load-balancer-controller \
        --set region=$AWS_REGION \
        --set vpcId=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query 'cluster.resourcesVpcConfig.vpcId' --output text)
    
    print_success "AWS Load Balancer Controller installed"
}

# Wait for controller to be ready
wait_for_controller() {
    print_status "Waiting for AWS Load Balancer Controller to be ready..."
    
    # Check if controller pods exist first
    if ! kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --no-headers 2>/dev/null | grep -q .; then
        print_error "No AWS Load Balancer Controller pods found"
        print_status "Please check the installation logs above"
        exit 1
    fi
    
    # Wait for pods to be ready
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=aws-load-balancer-controller -n kube-system --timeout=300s
    print_success "AWS Load Balancer Controller is ready"
    
    # Verify controller is working by checking logs
    print_status "Verifying controller status..."
    POD_NAME=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller -o jsonpath='{.items[0].metadata.name}')
    if [ -n "$POD_NAME" ]; then
        print_status "Controller pod: $POD_NAME"
        # Check for any immediate errors in logs
        RECENT_LOGS=$(kubectl logs "$POD_NAME" -n kube-system --tail=3 2>/dev/null | grep -i error || echo "")
        if [ -n "$RECENT_LOGS" ]; then
            print_warning "Recent errors in controller logs:"
            echo "$RECENT_LOGS"
        else
            print_success "No immediate errors in controller logs"
        fi
    fi
}

# Deploy application
deploy_application() {
    print_status "Deploying Tasky application..."
    
    # Step 1: Create namespace first and wait for it to be available
    print_status "Creating namespace..."
    kubectl apply -f k8s/namespace.yaml
    
    # Wait for namespace with better error handling
    print_status "Waiting for namespace to be active..."
    if ! kubectl wait --for=condition=Active --timeout=60s namespace/tasky 2>/dev/null; then
        print_warning "Timeout waiting for namespace condition, checking namespace status manually..."
        
        # Check if namespace exists and is usable
        if kubectl get namespace tasky &> /dev/null; then
            print_status "Namespace exists, checking if it's usable..."
            
            # Try to create a simple test resource to verify namespace is working
            kubectl apply -f - << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: namespace-test
  namespace: tasky
data:
  test: "namespace-working"
EOF
            
            if [ $? -eq 0 ]; then
                print_success "Namespace is working despite condition timeout"
                kubectl delete configmap namespace-test -n tasky &> /dev/null
            else
                print_error "Namespace exists but is not usable"
                exit 1
            fi
        else
            print_error "Namespace creation failed"
            exit 1
        fi
    else
        print_success "Namespace is active"
    fi
    
    # Step 2: Create RBAC resources
    print_status "Creating RBAC resources..."
    kubectl apply -f k8s/rbac.yaml
    
    # Step 3: Create ConfigMap
    print_status "Creating ConfigMap..."
    kubectl apply -f k8s/configmap.yaml
    
    # Step 4: Create Secret with proper MongoDB URI from Terraform
    print_status "Creating Secret with MongoDB connection using shared utilities..."
    
    # Source shared secret management utilities
    if [ -f "scripts/manage-secrets.sh" ]; then
        source scripts/manage-secrets.sh
        
        # First, try to update secret.yaml for consistency
        print_status "Updating secret.yaml file for consistency..."
        if update_secret_yaml "terraform" "k8s/secret.yaml"; then
            print_success "Secret.yaml updated with consistent Terraform values"
        else
            print_warning "Could not update secret.yaml - will create secret directly"
        fi
        
        # Create/update the Kubernetes secret using consistent approach
        print_status "Creating Kubernetes secret with consistent values..."
        if create_k8s_secret "tasky" "tasky-secrets" "terraform"; then
            print_success "Secret created/updated successfully with consistent values"
            
            # Validate the created secret
            validate_secret "tasky" "tasky-secrets"
        else
            print_error "Failed to create secret with shared utilities"
            exit 1
        fi
    else
        print_error "Shared secret utilities not found at scripts/manage-secrets.sh"
        print_status "Expected file: scripts/manage-secrets.sh"
        exit 1
    fi
    
    # Step 5: Create Service
    print_status "Creating Service..."
    kubectl apply -f k8s/service.yaml
    
    # Step 6: Create Deployment
    print_status "Creating Deployment..."
    kubectl apply -f k8s/deployment.yaml
    
    # Step 7: Create Ingress (ALB)
    print_status "Creating Ingress..."
    kubectl apply -f k8s/ingress.yaml
    
    print_success "Application deployed"
    
    # Enhanced ALB URL checking and output
    print_status "Checking ALB provisioning status..."
    
    # Give ALB a moment to be created
    sleep 15
    
    # Try to get ALB DNS name (but don't wait indefinitely)
    ALB_DNS=$(kubectl get ingress tasky-ingress -n tasky -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    
    if [ -z "$ALB_DNS" ]; then
        print_warning "ALB DNS name not yet available - this is normal for new deployments"
        print_status "ALB provisioning can take 2-3 minutes to complete"
        print_status ""
        print_status "🔍 To check ALB status:"
        print_status "   kubectl get ingress tasky-ingress -n tasky"
        print_status ""
        print_status "📋 To get the ALB URL when ready:"
        print_status "   kubectl get ingress tasky-ingress -n tasky -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
        print_status ""
        print_status "🌐 Application will be accessible at: http://<alb-dns-name>"
    else
        print_success "🎉 ALB is ready!"
        print_success "Application is accessible at: http://$ALB_DNS"
        print_status ""
        print_status "🔗 ALB DNS Name: $ALB_DNS"
        print_status "🌐 Application URL: http://$ALB_DNS"
        print_status "📝 Custom Domain: Point ideatasky.ryanmcvey.me CNAME to: $ALB_DNS"
        
        # Output for GitHub Actions (if running in CI)
        if [ -n "${GITHUB_ENV:-}" ]; then
            echo "ALB_DNS_NAME=$ALB_DNS" >> $GITHUB_ENV
            echo "APPLICATION_URL=http://$ALB_DNS" >> $GITHUB_ENV
            print_status "✅ ALB information exported to GitHub Actions environment"
        fi
    fi
    
    # Always show deployment status
    print_status ""
    print_status "📊 Deployment Status Summary:"
    print_status "├── Namespace: $(kubectl get namespace tasky -o jsonpath='{.status.phase}' 2>/dev/null || echo 'Not found')"
    print_status "├── Deployment: $(kubectl get deployment tasky-deployment -n tasky -o jsonpath='{.status.readyReplicas}/{.status.replicas}' 2>/dev/null || echo '0/0') pods ready"
    print_status "├── Service: $(kubectl get service tasky-service -n tasky -o jsonpath='{.spec.type}' 2>/dev/null || echo 'Not found')"
    print_status "└── Ingress: $(kubectl get ingress tasky-ingress -n tasky -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null | head -c 30 || echo 'Provisioning...')"
}

# Main execution
main() {
    # Handle command line arguments
    case "${1:-}" in
        --cleanup)
            print_status "Starting cleanup and setup..."
            cleanup_failed_installation
            ;;
        --help)
            usage
            ;;
        "")
            print_status "Starting AWS Load Balancer Controller setup..."
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            ;;
    esac
    
    check_prerequisites
    get_cluster_info
    update_kubeconfig
    install_alb_controller
    wait_for_controller
    deploy_application
    
    print_success "🎉 Setup complete!"
    print_status ""
    print_status "📋 Next Steps:"
    print_status "1. Check ALB status: kubectl get ingress tasky-ingress -n tasky"
    print_status "2. View application: kubectl get pods -n tasky" 
    print_status "3. Get logs: kubectl logs -l app.kubernetes.io/name=tasky -n tasky"
    print_status ""
    print_status "⏱️  ALB provisioning typically takes 2-3 minutes"
    print_status "🌐 Application will be accessible once ALB is ready"
}

# Run main function
main "$@"
