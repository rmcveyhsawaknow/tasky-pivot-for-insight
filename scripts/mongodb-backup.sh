#!/bin/bash
set -e

# Configuration
MONGODB_HOST="${MONGODB_HOST:-localhost}"
MONGODB_PORT="${MONGODB_PORT:-27017}"
MONGODB_DATABASE="${MONGODB_DATABASE:-go-mongodb}"
MONGODB_USERNAME="${MONGODB_USERNAME:-taskyadmin}"
MONGODB_PASSWORD="${MONGODB_PASSWORD:-TaskySecure123!}"
S3_BUCKET="${S3_BUCKET:-tasky-dev-mongodb-backup}"
AWS_REGION="${AWS_REGION:-us-east-1}"

# Generate timestamp and Julian date
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
JULIAN_DATE=$(date +%Y%j)  # Year + Julian day (e.g., 2025202 for July 21, 2025)
BACKUP_DIR="/tmp/mongodb-backup-$TIMESTAMP"
JULIAN_BACKUP_FILE="cron_$JULIAN_DATE.tar.gz"

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

# Also create JSON export for easy demo viewing
mkdir -p "$BACKUP_DIR/json"
echo "Creating JSON exports for demo viewing..."
mongoexport \
  --host "$MONGODB_HOST:$MONGODB_PORT" \
  --db "$MONGODB_DATABASE" \
  --collection "todos" \
  --username "$MONGODB_USERNAME" \
  --password "$MONGODB_PASSWORD" \
  --authenticationDatabase "$MONGODB_DATABASE" \
  --jsonArray \
  --pretty \
  --out "$BACKUP_DIR/json/todos.json" \
  --quiet

mongoexport \
  --host "$MONGODB_HOST:$MONGODB_PORT" \
  --db "$MONGODB_DATABASE" \
  --collection "user" \
  --username "$MONGODB_USERNAME" \
  --password "$MONGODB_PASSWORD" \
  --authenticationDatabase "$MONGODB_DATABASE" \
  --jsonArray \
  --pretty \
  --out "$BACKUP_DIR/json/user.json" \
  --quiet

# Create demo README
cat > "$BACKUP_DIR/README_DEMO.txt" << EOF
MongoDB Backup for Tasky App Demo
Generated: $(date)
Julian Date: $JULIAN_DATE

DEMO VIEWING: Open json/todos.json in any text editor (Notepad, etc.)
This file contains all current tasks in readable JSON format!
EOF

# Create tarball
echo "Creating compressed archive..."
cd /tmp
tar -czf "latest.tar.gz" "mongodb-backup-$TIMESTAMP/"
tar -czf "$JULIAN_BACKUP_FILE" "mongodb-backup-$TIMESTAMP/"

# Get file size for logging
FILE_SIZE=$(du -h "latest.tar.gz" | cut -f1)
echo "Backup file size: $FILE_SIZE"

# Upload to S3
echo "Uploading to S3..."
# Upload latest.tar.gz (overwrites previous)
aws s3 cp "latest.tar.gz" "s3://$S3_BUCKET/backups/latest.tar.gz" --region "$AWS_REGION"

# Upload Julian date backup (preserves history)
aws s3 cp "$JULIAN_BACKUP_FILE" "s3://$S3_BUCKET/backups/$JULIAN_BACKUP_FILE" --region "$AWS_REGION"

# Generate public URLs
LATEST_URL="https://$S3_BUCKET.s3.$AWS_REGION.amazonaws.com/backups/latest.tar.gz"
JULIAN_URL="https://$S3_BUCKET.s3.$AWS_REGION.amazonaws.com/backups/$JULIAN_BACKUP_FILE"

echo "Backup completed successfully!"
echo "Public URLs:"
echo "  Latest (demo): $LATEST_URL"
echo "  This backup: $JULIAN_URL"

# Cleanup local files
echo "Cleaning up local files..."
rm -rf "$BACKUP_DIR" "latest.tar.gz" "$JULIAN_BACKUP_FILE"

# Log completion
echo "MongoDB backup completed at $(date)"
echo "Demo instructions: Download latest.tar.gz and open */json/todos.json in text editor"

# Return public URL for use in other scripts
echo "$LATEST_URL"
