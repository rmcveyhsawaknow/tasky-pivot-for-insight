#!/bin/bash
# ==============================================================================
# SHARED SECRET MANAGEMENT UTILITIES
# ==============================================================================
# This script provides shared functions for managing Kubernetes secrets
# consistently across deploy.sh and setup-alb-controller.sh
# ==============================================================================

# Function to update secret.yaml file with terraform values
update_secret_yaml() {
    local terraform_dir="${1:-terraform}"
    local secret_file="${2:-k8s/secret.yaml}"
    
    echo "📝 Updating secret.yaml with Terraform values..."
    
    # Check if terraform directory exists
    if [ ! -d "$terraform_dir" ]; then
        echo "❌ Terraform directory not found: $terraform_dir"
        return 1
    fi
    
    # Get all required values from terraform with comprehensive fallbacks
    local mongodb_ip mongodb_username mongodb_password mongodb_database jwt_secret
    
    mongodb_ip=$(cd "$terraform_dir" && terraform output -raw mongodb_private_ip 2>/dev/null || echo "")
    mongodb_username=$(cd "$terraform_dir" && terraform output -raw mongodb_username 2>/dev/null || echo "taskyadmin")
    
    # Try multiple sources for password
    mongodb_password=$(cd "$terraform_dir" && terraform output -raw mongodb_password 2>/dev/null || echo "")
    if [ -z "$mongodb_password" ]; then
        # Fallback to tfvars if available
        mongodb_password=$(cd "$terraform_dir" && grep '^mongodb_password' terraform.tfvars 2>/dev/null | sed 's/.*=.*"\([^"]*\)".*/\1/' || echo "justapassv10")
    fi
    
    mongodb_database=$(cd "$terraform_dir" && terraform output -raw mongodb_database_name 2>/dev/null || echo "go-mongodb")
    jwt_secret=$(cd "$terraform_dir" && terraform output -raw jwt_secret 2>/dev/null || echo "12345rtyhujk-0987ytfc-3erftghnm-asdfgh")
    
    if [ -z "$mongodb_ip" ]; then
        echo "⚠️ Warning: Could not retrieve MongoDB IP from Terraform"
        echo "   Using placeholder values. You'll need to update manually later."
        return 1
    fi
    
    echo "✅ Retrieved Terraform values:"
    echo "   MongoDB IP: $mongodb_ip"
    echo "   MongoDB Username: $mongodb_username"
    echo "   MongoDB Database: $mongodb_database"
    echo "   Password length: ${#mongodb_password} characters"
    
    # Construct MongoDB URI
    local mongodb_uri="mongodb://${mongodb_username}:${mongodb_password}@${mongodb_ip}:27017/${mongodb_database}"
    
    # Base64 encode values
    local mongodb_uri_b64=$(echo -n "$mongodb_uri" | base64 | tr -d '\n')
    local jwt_secret_b64=$(echo -n "$jwt_secret" | base64 | tr -d '\n')
    
    # Update the secret.yaml file using awk
    awk -v new_uri="$mongodb_uri_b64" -v new_jwt="$jwt_secret_b64" '
    /^[[:space:]]*mongodb-uri:/ { 
        print "  mongodb-uri: " new_uri
        next 
    }
    /^[[:space:]]*jwt-secret:/ { 
        print "  jwt-secret: " new_jwt
        next 
    }
    { print }
    ' "$secret_file" > "$secret_file.tmp"
    
    if [ $? -eq 0 ]; then
        mv "$secret_file.tmp" "$secret_file"
        echo "✅ Successfully updated $secret_file"
        return 0
    else
        echo "❌ Failed to update $secret_file"
        rm -f "$secret_file.tmp"
        return 1
    fi
}

# Function to create kubernetes secret directly
create_k8s_secret() {
    local namespace="${1:-tasky}"
    local secret_name="${2:-tasky-secrets}"
    local terraform_dir="${3:-terraform}"
    
    echo "🔐 Creating Kubernetes secret: $secret_name in namespace: $namespace"
    
    # Get all required values from terraform
    local mongodb_ip mongodb_username mongodb_password mongodb_database jwt_secret
    
    mongodb_ip=$(cd "$terraform_dir" && terraform output -raw mongodb_private_ip 2>/dev/null || echo "")
    mongodb_username=$(cd "$terraform_dir" && terraform output -raw mongodb_username 2>/dev/null || echo "taskyadmin")
    
    # Try multiple sources for password  
    mongodb_password=$(cd "$terraform_dir" && terraform output -raw mongodb_password 2>/dev/null || echo "")
    if [ -z "$mongodb_password" ]; then
        mongodb_password=$(cd "$terraform_dir" && grep '^mongodb_password' terraform.tfvars 2>/dev/null | sed 's/.*=.*"\([^"]*\)".*/\1/' || echo "justapassv10")
    fi
    
    mongodb_database=$(cd "$terraform_dir" && terraform output -raw mongodb_database_name 2>/dev/null || echo "go-mongodb")
    jwt_secret=$(cd "$terraform_dir" && terraform output -raw jwt_secret 2>/dev/null || echo "12345rtyhujk-0987ytfc-3erftghnm-asdfgh")
    
    if [ -z "$mongodb_ip" ]; then
        echo "❌ Error: Could not get MongoDB IP from Terraform outputs"
        echo "   Creating placeholder secret that will need manual update"
        
        # Create secret with placeholder values
        kubectl create secret generic "$secret_name" -n "$namespace" \
            --from-literal=mongodb-uri="mongodb://${mongodb_username}:${mongodb_password}@mongodb-placeholder:27017/${mongodb_database}" \
            --from-literal=jwt-secret="$jwt_secret" \
            --dry-run=client -o yaml | kubectl apply -f -
        
        return 1
    fi
    
    echo "✅ Using Terraform values:"
    echo "   MongoDB IP: $mongodb_ip"
    echo "   MongoDB Username: $mongodb_username" 
    echo "   MongoDB Database: $mongodb_database"
    
    # Construct MongoDB URI
    local mongodb_uri="mongodb://${mongodb_username}:${mongodb_password}@${mongodb_ip}:27017/${mongodb_database}"
    
    # Create or update the secret
    kubectl create secret generic "$secret_name" -n "$namespace" \
        --from-literal=mongodb-uri="$mongodb_uri" \
        --from-literal=jwt-secret="$jwt_secret" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    if [ $? -eq 0 ]; then
        echo "✅ Successfully created/updated secret: $secret_name"
        return 0
    else
        echo "❌ Failed to create secret: $secret_name"
        return 1
    fi
}

# Function to validate secret consistency
validate_secret() {
    local namespace="${1:-tasky}"
    local secret_name="${2:-tasky-secrets}"
    
    echo "🔍 Validating secret: $secret_name"
    
    # Check if secret exists
    if ! kubectl get secret "$secret_name" -n "$namespace" &>/dev/null; then
        echo "❌ Secret $secret_name not found in namespace $namespace"
        return 1
    fi
    
    # Get and decode the mongodb-uri
    local mongodb_uri_b64=$(kubectl get secret "$secret_name" -n "$namespace" -o jsonpath='{.data.mongodb-uri}' 2>/dev/null)
    if [ -n "$mongodb_uri_b64" ]; then
        local mongodb_uri=$(echo "$mongodb_uri_b64" | base64 -d)
        echo "✅ MongoDB URI: $mongodb_uri"
        
        # Basic validation
        if [[ "$mongodb_uri" =~ ^mongodb://.*@.*:[0-9]+/.* ]]; then
            echo "✅ MongoDB URI format appears valid"
        else
            echo "⚠️ Warning: MongoDB URI format may be invalid"
        fi
    else
        echo "❌ Could not retrieve mongodb-uri from secret"
        return 1
    fi
    
    # Check JWT secret
    local jwt_secret_b64=$(kubectl get secret "$secret_name" -n "$namespace" -o jsonpath='{.data.jwt-secret}' 2>/dev/null)
    if [ -n "$jwt_secret_b64" ]; then
        echo "✅ JWT secret is present (${#jwt_secret_b64} characters base64)"
    else
        echo "❌ JWT secret is missing"
        return 1
    fi
    
    echo "✅ Secret validation completed"
    return 0
}

# Function to compare secret.yaml with actual k8s secret
compare_secrets() {
    local namespace="${1:-tasky}"
    local secret_name="${2:-tasky-secrets}"
    local secret_file="${3:-k8s/secret.yaml}"
    
    echo "🔍 Comparing secret.yaml with Kubernetes secret..."
    
    # This is a placeholder for comparison logic
    # Could be expanded to decode and compare actual values
    echo "📋 Manual comparison recommended:"
    echo "   1. Check secret.yaml file: $secret_file"
    echo "   2. Check k8s secret: kubectl get secret $secret_name -n $namespace -o yaml"
}
