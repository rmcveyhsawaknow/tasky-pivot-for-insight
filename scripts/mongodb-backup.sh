#!/bin/bash
set -e

# Configuration
MONGODB_HOST="${MONGODB_HOST:-localhost}"
MONGODB_PORT="${MONGODB_PORT:-27017}"
MONGODB_DATABASE="${MONGODB_DATABASE:-go-mongodb}"
MONGODB_USERNAME="${MONGODB_USERNAME:-taskyadmin}"
MONGODB_PASSWORD="${MONGODB_PASSWORD:-TaskySecure123!}"
S3_BUCKET="${S3_BUCKET:-tasky-dev-mongodb-backup}"
AWS_REGION="${AWS_REGION:-us-east-2}"

# Generate timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DATE_ONLY=$(date +%Y-%m-%d)
BACKUP_DIR="/tmp/mongodb-backup-$TIMESTAMP"
BACKUP_FILE="mongodb-backup-$DATE_ONLY-$TIMESTAMP.tar.gz"

echo "Starting MongoDB backup at $(date)"
echo "Backup configuration:"
echo "  MongoDB Host: $MONGODB_HOST:$MONGODB_PORT"
echo "  Database: $MONGODB_DATABASE"
echo "  S3 Bucket: $S3_BUCKET"
echo "  AWS Region: $AWS_REGION"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Dump database with authentication
echo "Creating MongoDB dump..."
mongodump \
  --host "$MONGODB_HOST:$MONGODB_PORT" \
  --db "$MONGODB_DATABASE" \
  --username "$MONGODB_USERNAME" \
  --password "$MONGODB_PASSWORD" \
  --authenticationDatabase "$MONGODB_DATABASE" \
  --out "$BACKUP_DIR" \
  --quiet

# Create tarball
echo "Creating compressed archive..."
cd /tmp
tar -czf "$BACKUP_FILE" "mongodb-backup-$TIMESTAMP/"

# Get file size for logging
FILE_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo "Backup file size: $FILE_SIZE"

# Upload to S3
echo "Uploading to S3..."
aws s3 cp "$BACKUP_FILE" "s3://$S3_BUCKET/backups/$BACKUP_FILE" --region "$AWS_REGION"

# Create latest symlink
echo "Creating latest backup reference..."
aws s3 cp "s3://$S3_BUCKET/backups/$BACKUP_FILE" "s3://$S3_BUCKET/backups/latest.tar.gz" --region "$AWS_REGION"

# Create daily backup reference
aws s3 cp "s3://$S3_BUCKET/backups/$BACKUP_FILE" "s3://$S3_BUCKET/backups/daily-$DATE_ONLY.tar.gz" --region "$AWS_REGION"

# Generate public URLs
PUBLIC_URL="https://$S3_BUCKET.s3.$AWS_REGION.amazonaws.com/backups/$BACKUP_FILE"
LATEST_URL="https://$S3_BUCKET.s3.$AWS_REGION.amazonaws.com/backups/latest.tar.gz"

echo "Backup completed successfully!"
echo "Public URLs:"
echo "  Timestamped: $PUBLIC_URL"
echo "  Latest: $LATEST_URL"

# Cleanup local files
echo "Cleaning up local files..."
rm -rf "$BACKUP_DIR" "$BACKUP_FILE"

# Log completion
echo "MongoDB backup completed at $(date)"
echo "Backup uploaded to: s3://$S3_BUCKET/backups/$BACKUP_FILE"

# Return public URL for use in other scripts
echo "$PUBLIC_URL"
