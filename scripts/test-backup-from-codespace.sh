#!/bin/bash
set -e

# MongoDB Backup Schedule Testing (from Codespace)
# Tests S3 public access and triggers remote backup execution

# Colors for output  
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}===============================================${NC}"
    echo -e "${BLUE}   MongoDB Backup Schedule Verification${NC}" 
    echo -e "${BLUE}===============================================${NC}"
    echo
}

# Get infrastructure info from Terraform
get_infrastructure_info() {
    log_info "Getting infrastructure information..."
    
    cd terraform
    
    # Get outputs from Terraform
    MONGODB_INSTANCE_ID=$(terraform output -raw mongodb_instance_id 2>/dev/null || echo "")
    MONGODB_PRIVATE_IP=$(terraform output -raw mongodb_private_ip 2>/dev/null || echo "")  
    S3_BACKUP_BUCKET=$(terraform output -raw s3_backup_bucket_name 2>/dev/null || echo "")
    S3_PUBLIC_URL=$(terraform output -raw s3_backup_public_url 2>/dev/null || echo "")
    
    cd ..
    
    echo "Infrastructure Details:"
    echo "  MongoDB Instance ID: ${MONGODB_INSTANCE_ID}"
    echo "  MongoDB Private IP:  ${MONGODB_PRIVATE_IP}"
    echo "  S3 Backup Bucket:    ${S3_BACKUP_BUCKET}" 
    echo "  S3 Public URL:       ${S3_PUBLIC_URL}"
    echo
}

# Test S3 bucket accessibility 
test_s3_access() {
    log_info "Testing S3 bucket access..."
    
    # Check if bucket exists
    if aws s3 ls "s3://$S3_BACKUP_BUCKET/" &>/dev/null; then
        log_success "S3 bucket is accessible"
    else
        log_error "S3 bucket is not accessible"
        return 1
    fi
    
    # Check backups folder
    log_info "Checking for existing backups..."
    aws s3 ls "s3://$S3_BACKUP_BUCKET/backups/" --recursive || {
        log_warning "No backups folder or files found yet"
    }
    echo
}

# Test public access to S3 bucket
test_public_access() {
    log_info "Testing public access to S3 bucket..."
    
    BUCKET_PUBLIC_URL="${S3_PUBLIC_URL}/backups/"
    
    # Test if we can access the public URL
    if curl -s -I "$BUCKET_PUBLIC_URL" | grep -q "200\|403"; then
        log_info "Public URL is reachable: $BUCKET_PUBLIC_URL"
    else
        log_warning "Public URL may not be accessible: $BUCKET_PUBLIC_URL"
    fi
    
    # Test if latest backup exists and is publicly accessible
    LATEST_URL="${S3_PUBLIC_URL}/backups/latest.tar.gz"
    if curl -s -I "$LATEST_URL" | grep -q "200"; then
        log_success "Latest backup is publicly accessible!"
        echo "  URL: $LATEST_URL"
    else
        log_info "No latest backup found or not yet publicly accessible"
        echo "  Will be available at: $LATEST_URL"
    fi
    echo
}

# Check MongoDB instance status
check_instance_status() {
    log_info "Checking MongoDB EC2 instance status..."
    
    INSTANCE_STATE=$(aws ec2 describe-instances \
        --instance-ids "$MONGODB_INSTANCE_ID" \
        --query 'Reservations[0].Instances[0].State.Name' \
        --output text)
    
    if [[ "$INSTANCE_STATE" == "running" ]]; then
        log_success "MongoDB instance is running"
    else
        log_error "MongoDB instance is not running: $INSTANCE_STATE"
        return 1
    fi
    echo
}

# Test manual backup execution via SSM
test_manual_backup() {
    log_info "Triggering manual backup on MongoDB instance..."
    
    COMMAND_ID=$(aws ssm send-command \
        --instance-ids "$MONGODB_INSTANCE_ID" \
        --document-name "AWS-RunShellScript" \
        --parameters 'commands=["sudo /opt/mongodb-backup/backup.sh"]' \
        --query 'Command.CommandId' \
        --output text)
    
    if [[ -n "$COMMAND_ID" ]]; then
        log_success "Manual backup command sent successfully"
        echo "  Command ID: $COMMAND_ID"
        echo "  Monitor with: aws ssm get-command-invocation --instance-id $MONGODB_INSTANCE_ID --command-id $COMMAND_ID"
        echo
        
        # Wait a moment and check initial status
        log_info "Checking command status..."
        sleep 5
        
        aws ssm get-command-invocation \
            --instance-id "$MONGODB_INSTANCE_ID" \
            --command-id "$COMMAND_ID" \
            --query '{Status:Status,StatusDetails:StatusDetails}' \
            --output table || log_warning "Could not get command status"
            
    else
        log_error "Failed to send manual backup command"
        return 1
    fi
    echo
}

# Check cron configuration
check_cron_schedule() {
    log_info "Checking cron schedule configuration..."
    
    COMMAND_ID=$(aws ssm send-command \
        --instance-ids "$MONGODB_INSTANCE_ID" \
        --document-name "AWS-RunShellScript" \
        --parameters 'commands=["sudo cat /etc/crontab | grep backup || echo \"No backup cron in /etc/crontab\""]' \
        --query 'Command.CommandId' \
        --output text)
    
    if [[ -n "$COMMAND_ID" ]]; then
        log_info "Cron check command sent"
        echo "  Command ID: $COMMAND_ID" 
        echo "  Get results: aws ssm get-command-invocation --instance-id $MONGODB_INSTANCE_ID --command-id $COMMAND_ID"
    fi
    echo
}

# Generate public URLs for tech team
show_public_urls() {
    log_info "Public URLs for Tech Team Access:"
    echo
    echo "📁 Browse all backups:"
    echo "   ${S3_PUBLIC_URL}/backups/"
    echo  
    echo "📦 Latest backup download:"
    echo "   ${S3_PUBLIC_URL}/backups/latest.tar.gz"
    echo
    echo "📅 Daily backup format:"  
    echo "   ${S3_PUBLIC_URL}/backups/daily-YYYY-MM-DD.tar.gz"
    echo
    echo "🔍 Test public access:"
    echo "   curl -I ${S3_PUBLIC_URL}/backups/latest.tar.gz"
    echo
}

# Main execution
main() {
    print_header
    
    # Prerequisites check
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI not found"
        exit 1
    fi
    
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform not found"  
        exit 1
    fi
    
    # Run tests
    get_infrastructure_info
    check_instance_status
    test_s3_access
    test_public_access
    check_cron_schedule
    test_manual_backup
    show_public_urls
    
    log_success "Backup schedule verification completed!"
    echo
    log_info "Next steps:"
    echo "  1. Monitor manual backup execution in CloudWatch logs"
    echo "  2. Verify backup appears in S3 within a few minutes"
    echo "  3. Test public access URLs with tech team"
    echo "  4. Scheduled backups run daily at 2:00 AM UTC"
    echo
}

# Execute
main "$@"
