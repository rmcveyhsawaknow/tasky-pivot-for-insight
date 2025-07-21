#!/bin/bash
set -e

echo "🚀 Deploying Tasky to AWS EKS..."

# Configuration - Auto-detect from Terraform if not provided
if [ -z "$CLUSTER_NAME" ] || [ -z "$AWS_REGION" ]; then
    print_status() {
        echo -e "\033[0;34m[INFO]\033[0m $1"
    }
    
    print_status "Auto-detecting cluster configuration from Terraform..."
    
    if [ -f "../terraform/terraform.tfstate" ]; then
        if [ -z "$CLUSTER_NAME" ]; then
            CLUSTER_NAME=$(cd ../terraform && terraform output -raw eks_cluster_name 2>/dev/null || echo "")
        fi
        
        if [ -z "$AWS_REGION" ]; then
            # Try different ways to get the region
            AWS_REGION=$(cd ../terraform && terraform output -raw aws_region 2>/dev/null || echo "")
            
            # If aws_region output doesn't exist, extract from kubectl_config_command
            if [ -z "$AWS_REGION" ]; then
                AWS_REGION=$(cd ../terraform && terraform output -raw kubectl_config_command 2>/dev/null | grep -o 'region [a-z0-9-]*' | cut -d' ' -f2 || echo "")
            fi
        fi
        
        if [ -n "$CLUSTER_NAME" ] && [ -n "$AWS_REGION" ]; then
            echo "✅ Auto-detected from Terraform:"
            echo "   Cluster Name: $CLUSTER_NAME"
            echo "   AWS Region: $AWS_REGION"
        fi
    fi
fi

# Fallback to defaults if still not set
CLUSTER_NAME="${CLUSTER_NAME:-tasky-dev-v1-eks-cluster}"
AWS_REGION="${AWS_REGION:-us-west-2}"  # Changed to match terraform default
NAMESPACE="tasky"
USE_ALB=false  # Default to false, will be set to true if ALB controller is available

echo "Using configuration:"
echo "  Cluster Name: $CLUSTER_NAME"
echo "  AWS Region: $AWS_REGION"
echo "  Namespace: $NAMESPACE"

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
    # Source shared secret management utilities
    if [ -f "utils/manage-secrets.sh" ]; then
        source utils/manage-secrets.sh
        
        print_status "Updating secret.yaml with Terraform values using shared utility..."
        if update_secret_yaml "../terraform" "../k8s/secret.yaml"; then
            print_success "Secret.yaml updated successfully with consistent values"
        else
            print_warning "Could not update secret.yaml automatically. Using manual approach..."
            
            # Fallback to original approach
            print_status "Retrieving MongoDB IP from Terraform state..."
            MONGODB_IP=$(cd ../terraform && terraform output -raw mongodb_private_ip 2>/dev/null || echo "")
            if [ -n "$MONGODB_IP" ]; then
                print_success "MongoDB IP found: $MONGODB_IP"
                
                # Get MongoDB credentials from terraform outputs or use defaults
                MONGODB_USERNAME=$(cd ../terraform && terraform output -raw mongodb_username 2>/dev/null || echo "admin")
                
                # Try to get password from terraform output, if not available, try to read from tfvars
                MONGODB_PASSWORD=$(cd ../terraform && terraform output -raw mongodb_password 2>/dev/null || echo "")
                if [ -z "$MONGODB_PASSWORD" ]; then
                    # Try to extract from terraform.tfvars as fallback
                    MONGODB_PASSWORD=$(cd ../terraform && grep '^mongodb_password' terraform.tfvars 2>/dev/null | sed 's/.*=.*"\([^"]*\)".*/\1/' || echo "asimplepass")
                fi
                
                # Get MongoDB database name from terraform
                MONGODB_DATABASE=$(cd ../terraform && terraform output -raw mongodb_database_name 2>/dev/null || echo "go-mongodb")
                
                # Update the secret with the correct MongoDB URI
                MONGODB_URI="mongodb://${MONGODB_USERNAME}:${MONGODB_PASSWORD}@${MONGODB_IP}:27017/${MONGODB_DATABASE}"
                MONGODB_URI_B64=$(echo -n "$MONGODB_URI" | base64 | tr -d '\n')
                
                # Get JWT secret from terraform or use default
                JWT_SECRET=$(cd ../terraform && terraform output -raw jwt_secret 2>/dev/null || echo "tasky-jwt-secret-key-for-insight-exercise")
                JWT_SECRET_B64=$(echo -n "$JWT_SECRET" | base64 | tr -d '\n')
                
                print_status "Updating MongoDB URI and JWT secret in secret..."
                
                # Use awk to safely replace both the mongodb-uri and jwt-secret lines
                awk -v new_uri="$MONGODB_URI_B64" -v new_jwt="$JWT_SECRET_B64" '
                /^[[:space:]]*mongodb-uri:/ { 
                    print "  mongodb-uri: " new_uri
                    next 
                }
                /^[[:space:]]*jwt-secret:/ { 
                    print "  jwt-secret: " new_jwt
                    next 
                }
                { print }
                ' ../k8s/secret.yaml > ../k8s/secret.yaml.tmp
                mv ../k8s/secret.yaml.tmp ../k8s/secret.yaml
                print_success "MongoDB URI and JWT secret updated successfully"
            else
                print_warning "Could not retrieve MongoDB IP from Terraform. Using placeholder value."
                print_warning "You may need to manually update the MongoDB connection string later."
            fi
        fi
    else
        print_warning "Shared secret utilities not found. Using original approach..."
        
        # Original approach as fallback
        print_status "Retrieving MongoDB IP from Terraform state..."
        MONGODB_IP=$(cd ../terraform && terraform output -raw mongodb_private_ip 2>/dev/null || echo "")
        if [ -n "$MONGODB_IP" ]; then
            print_success "MongoDB IP found: $MONGODB_IP"
            
            # Get MongoDB credentials from terraform outputs or use defaults
            MONGODB_USERNAME=$(cd ../terraform && terraform output -raw mongodb_username 2>/dev/null || echo "admin")
            
            # Try to get password from terraform output, if not available, try to read from tfvars
            MONGODB_PASSWORD=$(cd ../terraform && terraform output -raw mongodb_password 2>/dev/null || echo "")
            if [ -z "$MONGODB_PASSWORD" ]; then
                # Try to extract from terraform.tfvars as fallback
                MONGODB_PASSWORD=$(cd ../terraform && grep '^mongodb_password' terraform.tfvars 2>/dev/null | sed 's/.*=.*"\([^"]*\)".*/\1/' || echo "asimplepass")
            fi
            
            # Get MongoDB database name from terraform
            MONGODB_DATABASE=$(cd ../terraform && terraform output -raw mongodb_database_name 2>/dev/null || echo "go-mongodb")
            
            # Update the secret with the correct MongoDB URI
            MONGODB_URI="mongodb://${MONGODB_USERNAME}:${MONGODB_PASSWORD}@${MONGODB_IP}:27017/${MONGODB_DATABASE}"
            MONGODB_URI_B64=$(echo -n "$MONGODB_URI" | base64 | tr -d '\n')
            
            # Get JWT secret from terraform or use default
            JWT_SECRET=$(cd ../terraform && terraform output -raw jwt_secret 2>/dev/null || echo "tasky-jwt-secret-key-for-insight-exercise")
            JWT_SECRET_B64=$(echo -n "$JWT_SECRET" | base64 | tr -d '\n')
            
            print_status "Updating MongoDB URI and JWT secret in secret..."
            
            # Use awk to safely replace both the mongodb-uri and jwt-secret lines
            awk -v new_uri="$MONGODB_URI_B64" -v new_jwt="$JWT_SECRET_B64" '
            /^[[:space:]]*mongodb-uri:/ { 
                print "  mongodb-uri: " new_uri
                next 
            }
            /^[[:space:]]*jwt-secret:/ { 
                print "  jwt-secret: " new_jwt
                next 
            }
            { print }
            ' ../k8s/secret.yaml > ../k8s/secret.yaml.tmp
            mv ../k8s/secret.yaml.tmp ../k8s/secret.yaml
            print_success "MongoDB URI and JWT secret updated successfully"
            
        else
            print_warning "Could not retrieve MongoDB IP from Terraform. Using placeholder value."
            print_warning "You may need to manually update the MongoDB connection string later."
        fi
    fi
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

# Check if ingress.yaml exists and AWS Load Balancer Controller is available
if [ -f "../k8s/ingress.yaml" ]; then
    print_status "Checking for AWS Load Balancer Controller..."
    ALB_CONTROLLER_READY=$(kubectl get deployment aws-load-balancer-controller -n kube-system --no-headers 2>/dev/null | awk '{print $2}' | grep -E '^[0-9]+/[0-9]+$' || echo "")
    
    if [ -n "$ALB_CONTROLLER_READY" ]; then
        print_status "AWS Load Balancer Controller found. Applying ingress for ALB..."
        kubectl apply -f ../k8s/ingress.yaml
        USE_ALB=true
    else
        print_warning "AWS Load Balancer Controller not found. Skipping ingress deployment."
        print_warning "Run './setup-alb-controller.sh' first to install the controller, or use LoadBalancer service."
        USE_ALB=false
    fi
else
    print_status "No ingress.yaml found. Using LoadBalancer service approach."
    USE_ALB=false
fi

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

# Wait for Load Balancer or Ingress to be ready based on deployment type
if [ "$USE_ALB" = "true" ]; then
    print_status "Waiting for ALB Ingress to be ready (this may take a few minutes)..."
    ALB_HOSTNAME=""
    for i in {1..30}; do
        ALB_HOSTNAME=$(kubectl get ingress tasky-ingress -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        if [ -n "$ALB_HOSTNAME" ] && [ "$ALB_HOSTNAME" != "null" ]; then
            break
        fi
        echo "Waiting for ALB Ingress... ($i/30)"
        sleep 10
    done

    if [ -n "$ALB_HOSTNAME" ] && [ "$ALB_HOSTNAME" != "null" ]; then
        print_success "ALB Ingress is ready!"
        echo ""
        echo "🎉 Deployment completed successfully!"
        echo ""
        echo "Application URL: http://$ALB_HOSTNAME"
        echo "Custom Domain: http://ideatasky.ryanmcvey.me (configure DNS CNAME)"
        echo ""
        echo "You can test the application with:"
        echo "curl -I http://$ALB_HOSTNAME"
        echo ""
        echo "To configure custom domain in Cloudflare:"
        echo "  Type: CNAME"
        echo "  Name: ideatasky"
        echo "  Target: $ALB_HOSTNAME"
        echo ""
        echo "To check the status:"
        echo "kubectl get pods -n $NAMESPACE"
        echo "kubectl get ingress -n $NAMESPACE"
    else
        print_warning "ALB Ingress is still provisioning. Check status with:"
        echo "kubectl get ingress tasky-ingress -n $NAMESPACE"
    fi
else
    # Legacy LoadBalancer service approach
    print_status "Waiting for LoadBalancer to be ready (this may take a few minutes)..."
    LB_HOSTNAME=""
    for i in {1..30}; do
        LB_HOSTNAME=$(kubectl get svc tasky-service -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        if [ -n "$LB_HOSTNAME" ] && [ "$LB_HOSTNAME" != "null" ]; then
            break
        fi
        echo "Waiting for LoadBalancer... ($i/30)"
        sleep 10
    done

    if [ -n "$LB_HOSTNAME" ] && [ "$LB_HOSTNAME" != "null" ]; then
        print_success "LoadBalancer is ready!"
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
        print_warning "LoadBalancer is still provisioning. Check status with:"
        echo "kubectl get svc -n $NAMESPACE"
    fi
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
