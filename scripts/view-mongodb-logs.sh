#!/bin/bash

# MongoDB EC2 Instance Quick Log Viewer
# Usage: ./scripts/view-mongodb-logs.sh [log-type]
# Log types: user-data, mongodb-setup, mongod, backup, cloud-init, cloud-init-output

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}INFO:${NC} $1"
}

print_success() {
    echo -e "${GREEN}SUCCESS:${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}WARNING:${NC} $1"
}

print_error() {
    echo -e "${RED}ERROR:${NC} $1"
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

# Get instance ID from terraform output
print_info "Getting MongoDB instance ID from Terraform..."
INSTANCE_ID=$(terraform output -raw mongodb_instance_id 2>/dev/null)
if [[ -z "$INSTANCE_ID" ]]; then
    print_error "Could not get instance ID from terraform output"
    print_error "Make sure you have run 'terraform apply' successfully"
    exit 1
fi

print_success "Found MongoDB instance: $INSTANCE_ID"

# Log group name
LOG_GROUP="/aws/ec2/mongodb"

# Available log types
declare -A LOG_STREAMS=(
    ["user-data"]="$INSTANCE_ID/user-data.log"
    ["mongodb-setup"]="$INSTANCE_ID/mongodb-setup.log"
    ["mongod"]="$INSTANCE_ID/mongod.log"
    ["backup"]="$INSTANCE_ID/backup.log"
    ["cloud-init"]="$INSTANCE_ID/cloud-init.log"
    ["cloud-init-output"]="$INSTANCE_ID/cloud-init-output.log"
)

# Function to show usage
show_usage() {
    echo "MongoDB Log Viewer"
    echo "=================="
    echo
    echo "Usage: $0 [log-type] [options]"
    echo
    echo "Available log types:"
    for log_type in "${!LOG_STREAMS[@]}"; do
        echo "  - $log_type"
    done
    echo
    echo "Options:"
    echo "  --follow, -f    Follow log output (tail -f equivalent)"
    echo "  --lines N, -n N Show last N lines (default: 100)"
    echo "  --list          List available log streams"
    echo "  --help, -h      Show this help message"
    echo
    echo "Examples:"
    echo "  $0 user-data                    # Show last 100 lines of user-data log"
    echo "  $0 mongod --follow              # Follow MongoDB server log in real-time"
    echo "  $0 mongodb-setup --lines 50     # Show last 50 lines of setup log"
    echo "  $0 --list                       # List all available log streams"
    echo
}

# Function to list available log streams
list_streams() {
    print_info "Checking available log streams in CloudWatch..."
    
    # Check if log group exists
    if ! aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" --query "logGroups[?logGroupName=='$LOG_GROUP'].logGroupName" --output text | grep -q "$LOG_GROUP"; then
        print_error "Log group '$LOG_GROUP' not found in CloudWatch"
        print_error "This could mean:"
        print_error "1. The EC2 instance hasn't started logging yet"
        print_error "2. CloudWatch agent failed to start"
        print_error "3. IAM permissions are insufficient"
        return 1
    fi
    
    print_success "Log group found: $LOG_GROUP"
    echo
    
    # List all streams in the log group
    print_info "Available log streams:"
    aws logs describe-log-streams \
        --log-group-name "$LOG_GROUP" \
        --query "logStreams[].{StreamName:logStreamName,LastEvent:lastEventTime,Size:storedBytes}" \
        --output table
}

# Function to view logs
view_logs() {
    local log_type=$1
    local follow_flag=$2
    local lines_count=${3:-100}
    
    if [[ -z "${LOG_STREAMS[$log_type]}" ]]; then
        print_error "Invalid log type: $log_type"
        show_usage
        exit 1
    fi
    
    local log_stream="${LOG_STREAMS[$log_type]}"
    print_info "Viewing log stream: $log_stream"
    
    # Check if log stream exists
    if ! aws logs describe-log-streams \
        --log-group-name "$LOG_GROUP" \
        --log-stream-name-prefix "$log_stream" \
        --query "logStreams[?logStreamName=='$log_stream'].logStreamName" \
        --output text | grep -q "$log_stream"; then
        print_warning "Log stream '$log_stream' not found"
        print_warning "This could mean:"
        print_warning "1. The EC2 instance hasn't started this service yet"
        print_warning "2. The service failed to start"
        print_warning "3. CloudWatch agent configuration issue"
        echo
        print_info "Available log streams:"
        aws logs describe-log-streams --log-group-name "$LOG_GROUP" --query "logStreams[].logStreamName" --output table
        return 1
    fi
    
    if [[ "$follow_flag" == "true" ]]; then
        print_info "Following log stream (Ctrl+C to stop)..."
        echo "================================================================="
        aws logs tail "$LOG_GROUP" --log-stream-names "$log_stream" --follow
    else
        print_info "Showing last $lines_count lines..."
        echo "================================================================="
        aws logs tail "$LOG_GROUP" --log-stream-names "$log_stream" --since 24h | tail -n "$lines_count"
    fi
}

# Parse command line arguments
LOG_TYPE=""
FOLLOW_FLAG="false"
LINES_COUNT=100

while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_usage
            exit 0
            ;;
        --list)
            list_streams
            exit 0
            ;;
        --follow|-f)
            FOLLOW_FLAG="true"
            shift
            ;;
        --lines|-n)
            if [[ -n $2 && $2 =~ ^[0-9]+$ ]]; then
                LINES_COUNT=$2
                shift 2
            else
                print_error "Invalid number of lines: $2"
                exit 1
            fi
            ;;
        user-data|mongodb-setup|mongod|backup|cloud-init|cloud-init-output)
            if [[ -z "$LOG_TYPE" ]]; then
                LOG_TYPE=$1
            else
                print_error "Multiple log types specified"
                exit 1
            fi
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# If no log type specified, show usage
if [[ -z "$LOG_TYPE" ]]; then
    show_usage
    exit 1
fi

# Main execution
print_info "MongoDB CloudWatch Log Viewer"
print_info "Instance ID: $INSTANCE_ID"
print_info "Log Group: $LOG_GROUP"
echo

view_logs "$LOG_TYPE" "$FOLLOW_FLAG" "$LINES_COUNT"
