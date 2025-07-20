#!/bin/bash

# MongoDB EC2 Instance Status Check Script
# Usage: ./scripts/check-mongodb-status.sh

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_header() {
    echo
    echo "================================================================="
    echo -e "${BLUE}$1${NC}"
    echo "================================================================="
}

# Check if we're in the terraform directory or need to change to it
if [[ ! -f "main.tf" ]]; then
    if [[ -f "terraform/main.tf" ]]; then
        cd terraform
        print_info "Changed to terraform directory"
    else
        print_error "Could not find terraform configuration files"
        exit 1
    fi
fi

print_header "MongoDB EC2 Instance Status Check"

# Get terraform outputs
print_info "Getting information from Terraform outputs..."

INSTANCE_ID=$(terraform output -raw mongodb_instance_id 2>/dev/null || echo "")
MONGODB_IP=$(terraform output -raw mongodb_private_ip 2>/dev/null || echo "")
LOG_GROUP=$(terraform output -raw mongodb_cloudwatch_logs 2>/dev/null || echo "")

if [[ -z "$INSTANCE_ID" ]]; then
    print_error "Could not get instance ID from terraform output"
    print_error "Make sure you have run 'terraform apply' successfully"
    exit 1
fi

print_success "Instance ID: $INSTANCE_ID"
print_success "Private IP: $MONGODB_IP"
print_success "Log Group: $LOG_GROUP"

print_header "EC2 Instance Status"

# Check EC2 instance state
print_info "Checking EC2 instance state..."
INSTANCE_STATE=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query "Reservations[0].Instances[0].State.Name" \
    --output text)

if [[ "$INSTANCE_STATE" == "running" ]]; then
    print_success "Instance is running"
else
    print_error "Instance is not running (State: $INSTANCE_STATE)"
    exit 1
fi

# Check instance status checks
print_info "Checking instance status checks..."
STATUS_CHECKS=$(aws ec2 describe-instance-status \
    --instance-ids "$INSTANCE_ID" \
    --query "InstanceStatuses[0].{SystemStatus:SystemStatus.Status,InstanceStatus:InstanceStatus.Status}" \
    --output json 2>/dev/null || echo '{}')

if [[ "$STATUS_CHECKS" != '{}' ]]; then
    SYSTEM_STATUS=$(echo "$STATUS_CHECKS" | jq -r '.SystemStatus // "unknown"')
    INSTANCE_STATUS=$(echo "$STATUS_CHECKS" | jq -r '.InstanceStatus // "unknown"')
    
    if [[ "$SYSTEM_STATUS" == "ok" ]]; then
        print_success "System status checks: OK"
    else
        print_warning "System status checks: $SYSTEM_STATUS"
    fi
    
    if [[ "$INSTANCE_STATUS" == "ok" ]]; then
        print_success "Instance status checks: OK"
    else
        print_warning "Instance status checks: $INSTANCE_STATUS"
    fi
else
    print_warning "Status checks not available yet (instance may be starting)"
fi

print_header "CloudWatch Logs Status"

# Check if CloudWatch log group exists
print_info "Checking CloudWatch log group..."
if aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" --query "logGroups[?logGroupName=='$LOG_GROUP'].logGroupName" --output text | grep -q "$LOG_GROUP"; then
    print_success "CloudWatch log group exists: $LOG_GROUP"
    
    # Check for log streams
    print_info "Checking available log streams..."
    LOG_STREAMS=$(aws logs describe-log-streams \
        --log-group-name "$LOG_GROUP" \
        --query "logStreams[].logStreamName" \
        --output text)
    
    if [[ -n "$LOG_STREAMS" ]]; then
        print_success "Found log streams:"
        echo "$LOG_STREAMS" | tr '\t' '\n' | sed 's/^/    /'
        
        # Check for completion marker in user-data log
        print_info "Checking if user-data script completed..."
        USER_DATA_STREAM="$INSTANCE_ID/user-data.log"
        if echo "$LOG_STREAMS" | grep -q "$USER_DATA_STREAM"; then
            COMPLETION_CHECK=$(aws logs filter-log-events \
                --log-group-name "$LOG_GROUP" \
                --log-stream-names "$USER_DATA_STREAM" \
                --filter-pattern "User-data script execution completed successfully" \
                --query "events[].message" \
                --output text 2>/dev/null || echo "")
            
            if [[ -n "$COMPLETION_CHECK" ]]; then
                print_success "User-data script completed successfully"
            else
                print_warning "User-data script may still be running or failed"
                print_info "Check logs with: ./scripts/view-mongodb-logs.sh user-data --follow"
            fi
        else
            print_warning "User-data log stream not found yet"
        fi
    else
        print_warning "No log streams found - CloudWatch agent may not be running"
    fi
else
    print_error "CloudWatch log group not found: $LOG_GROUP"
    print_error "This indicates CloudWatch agent failed to start or create the log group"
fi

print_header "MongoDB Connectivity Test"

# Test MongoDB connectivity from current location (this will likely fail due to security groups)
print_info "Testing MongoDB connectivity (this may timeout due to security groups)..."

# Use timeout to avoid hanging
if timeout 5 nc -z "$MONGODB_IP" 27017 2>/dev/null; then
    print_success "MongoDB port 27017 is reachable"
else
    print_warning "Cannot reach MongoDB port 27017 from this location"
    print_info "This is expected if testing from outside the VPC"
    print_info "MongoDB should only be accessible from within the EKS cluster"
fi

print_header "Quick Troubleshooting Commands"

cat <<EOF

To troubleshoot issues, use these commands:

1. View real-time user-data execution:
   ./scripts/view-mongodb-logs.sh user-data --follow

2. Check MongoDB setup logs:
   ./scripts/view-mongodb-logs.sh mongodb-setup

3. View MongoDB server logs:
   ./scripts/view-mongodb-logs.sh mongod

4. Connect to the instance via SSM:
   aws ssm start-session --target $INSTANCE_ID

5. Run status check on the instance:
   # (after connecting via SSM)
   sudo /opt/mongodb-backup/status-check.sh

6. Check all available log streams:
   ./scripts/view-mongodb-logs.sh --list

7. View Terraform troubleshooting info:
   terraform output mongodb_troubleshooting

EOF

print_header "Summary"

if [[ "$INSTANCE_STATE" == "running" ]]; then
    if echo "$LOG_STREAMS" | grep -q "$INSTANCE_ID/user-data.log"; then
        if [[ -n "$COMPLETION_CHECK" ]]; then
            print_success "MongoDB instance appears to be fully configured"
            print_info "Next step: Test connectivity from within EKS cluster"
        else
            print_warning "MongoDB instance is running but setup may not be complete"
            print_info "Monitor user-data logs for completion status"
        fi
    else
        print_warning "MongoDB instance is running but CloudWatch logging not yet active"
        print_info "Wait a few minutes and run this script again"
    fi
else
    print_error "MongoDB instance is not in running state"
    print_info "Check AWS console or run 'terraform apply' to fix"
fi

echo
