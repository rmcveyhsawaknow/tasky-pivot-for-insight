# MongoDB Backup Schedule - Technical Documentation

## Overview
The MongoDB backup system automatically creates daily backups of the database and stores them in a publicly accessible S3 bucket, as required by the technical exercise specifications.

## Architecture

### Components
1. **MongoDB EC2 Instance**: Hosts the MongoDB database
2. **S3 Bucket**: Stores backups with public read access
3. **Cron Job**: Schedules daily backups at 2:00 AM UTC
4. **Backup Script**: Performs the actual backup and upload process

### Backup Flow
```
MongoDB Database → mongodump → tar.gz → S3 Upload → Public Access
```

## S3 Bucket Configuration

### Public Access Policy
The S3 bucket is configured with public read access to meet the technical exercise requirement that the tech team can browse and retrieve backups.

**Bucket Policy Features:**
- Public read access for all objects in the `backups/` folder
- Versioning enabled for backup history
- Lifecycle policy: 30-day retention for current versions, 7-day for old versions
- Public URLs follow pattern: `https://[bucket-name].s3.amazonaws.com/backups/[backup-file]`

### Backup File Structure
```
s3://[bucket-name]/backups/
├── mongodb-backup-20250121-140000.tar.gz
├── mongodb-backup-20250122-140000.tar.gz
├── daily-2025-01-21.tar.gz              # Daily reference copy
├── daily-2025-01-22.tar.gz
└── latest.tar.gz                        # Always points to most recent backup
```

## Scheduled Backup Process

### Cron Configuration
- **Schedule**: `0 2 * * * root /opt/mongodb-backup/backup.sh`
- **Frequency**: Daily at 2:00 AM UTC
- **User**: root (required for system access)
- **Log**: `/var/log/mongodb-backup.log`

### Backup Script Process
1. **Initialize**: Create timestamp and temporary directories
2. **Database Dump**: Use `mongodump` with authentication
3. **Compression**: Create tar.gz archive
4. **Upload**: Upload to S3 with three copies:
   - Timestamped backup: `mongodb-backup-YYYYMMDD-HHMMSS.tar.gz`
   - Daily backup: `daily-YYYY-MM-DD.tar.gz`
   - Latest backup: `latest.tar.gz`
5. **Cleanup**: Remove local temporary files
6. **Logging**: Record all operations with timestamps

### Error Handling
- Retry logic for network operations
- Comprehensive logging of all steps
- CloudWatch log integration for monitoring
- Cleanup of partial files on failure

## Public Access URLs

### Browsing Backups
- **Bucket Listing**: `https://[bucket-name].s3.amazonaws.com/backups/`
- **Latest Backup**: `https://[bucket-name].s3.amazonaws.com/backups/latest.tar.gz`

### Example URLs (actual bucket name)
```
https://tasky-dev-v9-mongodb-backup-9lyiss0a.s3.amazonaws.com/backups/
https://tasky-dev-v9-mongodb-backup-9lyiss0a.s3.amazonaws.com/backups/latest.tar.gz
https://tasky-dev-v9-mongodb-backup-9lyiss0a.s3.amazonaws.com/backups/mongodb-backup-20250721-143157.tar.gz
```

## Testing & Verification

### Manual Testing Steps
1. **Trigger Manual Backup**:
   ```bash
   sudo /opt/mongodb-backup/backup.sh
   ```

2. **Check Backup Upload**:
   ```bash
   aws s3 ls s3://[bucket-name]/backups/ --recursive
   ```

3. **Test Public Access**:
   ```bash
   curl -I https://[bucket-name].s3.amazonaws.com/backups/latest.tar.gz
   ```

4. **Download and Verify**:
   ```bash
   wget https://[bucket-name].s3.amazonaws.com/backups/latest.tar.gz
   tar -tzf latest.tar.gz
   ```

### Automated Testing
Use the provided test script:
```bash
/workspaces/tasky-pivot-for-insight/scripts/test-backup-schedule.sh
```

This script will:
- Verify environment setup
- Test manual backup execution
- Check cron configuration
- Validate S3 public access
- Generate test documentation

## Monitoring & Logs

### Log Locations
- **Backup Process**: `/var/log/mongodb-backup.log`
- **MongoDB**: `/var/log/mongodb/mongod.log`
- **System**: `/var/log/user-data.log`

### CloudWatch Integration
All logs are automatically forwarded to CloudWatch Logs:
- Log Group: `/aws/ec2/mongodb`
- Log Streams by instance ID and log type

### Status Checking
```bash
# Check backup script status
/opt/mongodb-backup/status-check.sh

# View recent backup logs
tail -f /var/log/mongodb-backup.log

# Check cron status
systemctl status crond
```

## Security Considerations

### Public Access Design
- Only the `backups/` folder has public read access
- No write permissions for public users
- Versioning protects against accidental overwrites
- Lifecycle policies prevent unlimited storage growth

### Authentication
- MongoDB dumps use authenticated connections
- EC2 instance has IAM role for S3 access
- No hardcoded credentials in scripts

## Troubleshooting

### Common Issues
1. **Backup Not Running**: Check cron service and permissions
2. **S3 Upload Fails**: Verify IAM role and S3 bucket policy
3. **Public Access Denied**: Check bucket public access block settings
4. **MongoDB Connection**: Verify database credentials and connectivity

### Diagnostic Commands
```bash
# Check MongoDB connectivity
mongo go-mongodb --username taskyadmin --password TaskySecure123!

# Test S3 permissions
aws s3 ls s3://[bucket-name]/

# Check cron logs
tail /var/log/cron
```

## Recovery Process

### Restoring from Backup
1. Download backup file:
   ```bash
   wget https://[bucket-name].s3.amazonaws.com/backups/latest.tar.gz
   ```

2. Extract backup:
   ```bash
   tar -xzf latest.tar.gz
   ```

3. Restore database:
   ```bash
   mongorestore --host localhost:27017 --db go-mongodb \
     --username taskyadmin --password TaskySecure123! \
     --authenticationDatabase go-mongodb \
     mongodb-backup-*/go-mongodb/
   ```

### Disaster Recovery
- Backups are stored in S3 with versioning
- Cross-region replication can be enabled if needed
- Point-in-time recovery available through backup history

## Technical Exercise Compliance

### Requirements Met
✅ **Public S3 Access**: Bucket and objects are publicly readable  
✅ **Tech Team Browsing**: Can browse backups via public URLs  
✅ **Automated Backups**: Daily scheduled backups via cron  
✅ **Reliable Storage**: S3 with versioning and lifecycle management  
✅ **Monitoring**: CloudWatch logs and comprehensive error handling  

### URLs for Tech Team Review
The tech team can browse and download backups using these public URLs:
- Browse all backups: `https://tasky-dev-v9-mongodb-backup-9lyiss0a.s3.amazonaws.com/backups/`
- Latest backup: `https://tasky-dev-v9-mongodb-backup-9lyiss0a.s3.amazonaws.com/backups/latest.tar.gz`
- Daily backups: `https://tasky-dev-v9-mongodb-backup-9lyiss0a.s3.amazonaws.com/backups/daily-YYYY-MM-DD.tar.gz`

**✅ TESTED & VERIFIED**: All URLs are publicly accessible and working as of July 21, 2025
