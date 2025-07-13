#!/bin/bash
set -e

echo "🚀 Deploying Tasky to AWS EKS..."

# Configuration
CLUSTER_NAME="${CLUSTER_NAME:-tasky-dev-v1-eks-cluster}"
AWS_REGION="${AWS_REGION:-us-east-2}"
NAMESPACE="tasky"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check prerequisites
print_status "Checking prerequisites..."

if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed"
    exit 1
fi

# Configure kubectl
print_status "Configuring kubectl for EKS cluster..."
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

if [ $? -ne 0 ]; then
    print_error "Failed to configure kubectl. Please check your AWS credentials and cluster name."
    exit 1
fi

# Verify cluster connectivity
print_status "Verifying cluster connectivity..."
kubectl cluster-info

# Get MongoDB IP from Terraform output (if available)
if [ -f "../terraform/terraform.tfstate" ]; then
    print_status "Retrieving MongoDB IP from Terraform state..."
    MONGODB_IP=$(cd ../terraform && terraform output -raw mongodb_private_ip 2>/dev/null || echo "")
    if [ -n "$MONGODB_IP" ]; then
        print_success "MongoDB IP found: $MONGODB_IP"
        
        # Update the secret with the correct MongoDB URI
        MONGODB_URI="mongodb://taskyadmin:asimplepass@$MONGODB_IP:27017/tasky"
        MONGODB_URI_B64=$(echo -n "$MONGODB_URI" | base64)
        
        print_status "Updating MongoDB URI in secret..."
        # Use awk to safely replace the mongodb-uri line
        awk -v new_uri="$MONGODB_URI_B64" '
        /^[[:space:]]*mongodb-uri:/ { 
            print "  mongodb-uri: " new_uri
            next 
        }
        { print }
        ' ../k8s/secret.yaml > ../k8s/secret.yaml.tmp
        mv ../k8s/secret.yaml.tmp ../k8s/secret.yaml
        print_success "MongoDB URI updated successfully"
        
    else
        print_warning "Could not retrieve MongoDB IP from Terraform. Using placeholder value."
    fi
else
    print_warning "Terraform state not found. Using placeholder MongoDB URI."
fi

# Apply Kubernetes manifests
print_status "Applying Kubernetes manifests..."

# Create namespace first
kubectl apply -f ../k8s/namespace.yaml

# Apply RBAC
kubectl apply -f ../k8s/rbac.yaml

# Apply ConfigMap and Secret
kubectl apply -f ../k8s/configmap.yaml
kubectl apply -f ../k8s/secret.yaml

# Apply Deployment
kubectl apply -f ../k8s/deployment.yaml

# Apply Service
kubectl apply -f ../k8s/service.yaml

# Wait for deployment to be ready
print_status "Waiting for deployment to be ready..."
kubectl wait --for=condition=available deployment/tasky-app -n "$NAMESPACE" --timeout=300s

if [ $? -ne 0 ]; then
    print_error "Deployment failed to become ready within 5 minutes"
    kubectl get pods -n "$NAMESPACE"
    kubectl describe deployment/tasky-app -n "$NAMESPACE"
    exit 1
fi

print_success "Deployment is ready!"

# Get service information
print_status "Getting service information..."
kubectl get svc -n "$NAMESPACE"

# Wait for Load Balancer to be ready
print_status "Waiting for Load Balancer to be ready (this may take a few minutes)..."
LB_HOSTNAME=""
for i in {1..30}; do
    LB_HOSTNAME=$(kubectl get svc tasky-service -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    if [ -n "$LB_HOSTNAME" ] && [ "$LB_HOSTNAME" != "null" ]; then
        break
    fi
    echo "Waiting for Load Balancer... ($i/30)"
    sleep 10
done

if [ -n "$LB_HOSTNAME" ] && [ "$LB_HOSTNAME" != "null" ]; then
    print_success "Load Balancer is ready!"
    echo ""
    echo "🎉 Deployment completed successfully!"
    echo ""
    echo "Application URL: http://$LB_HOSTNAME"
    echo ""
    echo "You can test the application with:"
    echo "curl -I http://$LB_HOSTNAME"
    echo ""
    echo "To check the status:"
    echo "kubectl get pods -n $NAMESPACE"
    echo "kubectl get svc -n $NAMESPACE"
else
    print_warning "Load Balancer is still provisioning. Check status with:"
    echo "kubectl get svc -n $NAMESPACE"
fi

print_status "Deployment completed!"

# Show pod status
echo ""
print_status "Pod status:"
kubectl get pods -n "$NAMESPACE" -o wide

# Show logs from one pod
print_status "Recent logs from application:"
POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=tasky -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$POD_NAME" ]; then
    kubectl logs "$POD_NAME" -n "$NAMESPACE" --tail=20
fi
