#!/bin/bash
set -e

# Log all output to /var/log/user-data.log
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting MongoDB 4.0.x installation on Amazon Linux 2..."

# Function to retry commands
retry_command() {
    local max_attempts=3
    local delay=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt of $max_attempts..."
        if "$@"; then
            echo "Command succeeded on attempt $attempt"
            return 0
        else
            echo "Command failed on attempt $attempt"
            if [ $attempt -lt $max_attempts ]; then
                echo "Waiting $delay seconds before retry..."
                sleep $delay
            fi
            attempt=$((attempt + 1))
        fi
    done
    
    echo "Command failed after $max_attempts attempts"
    return 1
}

# Wait for network connectivity
echo "Waiting for network connectivity..."
retry_command ping -c 3 amazon.com

# Update system with retry
echo "Updating system packages..."
retry_command yum update -y

# Install AWS CLI v2 with retry
echo "Installing AWS CLI v2..."
retry_command curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf aws awscliv2.zip

# Create MongoDB repository file
cat > /etc/yum.repos.d/mongodb-org-4.0.repo << 'EOF'
[mongodb-org-4.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/amazon/2/mongodb-org/4.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-4.0.asc
EOF

# Install MongoDB 4.0.28 (legacy version as required) with retry
echo "Installing MongoDB 4.0.28..."
retry_command yum install -y mongodb-org-4.0.28 mongodb-org-server-4.0.28 mongodb-org-shell-4.0.28 mongodb-org-mongos-4.0.28 mongodb-org-tools-4.0.28

# Prevent MongoDB from being updated
echo "exclude=mongodb-org,mongodb-org-server,mongodb-org-shell,mongodb-org-mongos,mongodb-org-tools" >> /etc/yum.conf

# Configure MongoDB
mkdir -p /data/db
chown -R mongod:mongod /data/db
chmod 755 /data/db

# Create MongoDB configuration file
cat > /etc/mongod.conf << 'EOF'
storage:
  dbPath: /data/db
  journal:
    enabled: true

systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log

net:
  port: 27017
  bindIp: 0.0.0.0

processManagement:
  timeZoneInfo: /usr/share/zoneinfo

security:
  authorization: enabled
EOF

# Start and enable MongoDB
systemctl start mongod
systemctl enable mongod

# Wait for MongoDB to start
sleep 10

# Create admin user and tasky database user
mongo admin --eval "
db.createUser({
  user: 'admin',
  pwd: '${MONGODB_PASSWORD}',
  roles: [ { role: 'userAdminAnyDatabase', db: 'admin' }, 'readWriteAnyDatabase' ]
});
"

mongo tasky --eval "
db.createUser({
  user: '${MONGODB_USERNAME}',
  pwd: '${MONGODB_PASSWORD}',
  roles: [ { role: 'readWrite', db: 'tasky' } ]
});
"

# Create backup script
mkdir -p /opt/mongodb-backup
cat > /opt/mongodb-backup/backup.sh << 'EOF'
#!/bin/bash
set -e

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/tmp/mongodb-backup-$TIMESTAMP"
BACKUP_FILE="mongodb-backup-$TIMESTAMP.tar.gz"
S3_BUCKET="${BACKUP_BUCKET_NAME}"

echo "Starting MongoDB backup at $(date)"

# Create backup directory
mkdir -p $BACKUP_DIR

# Dump database with authentication
mongodump --host localhost:27017 --db tasky --username ${MONGODB_USERNAME} --password ${MONGODB_PASSWORD} --authenticationDatabase tasky --out $BACKUP_DIR

# Create tarball
cd /tmp
tar -czf $BACKUP_FILE mongodb-backup-$TIMESTAMP/

# Upload to S3
aws s3 cp $BACKUP_FILE s3://$S3_BUCKET/backups/$BACKUP_FILE

# Create latest link
aws s3 cp s3://$S3_BUCKET/backups/$BACKUP_FILE s3://$S3_BUCKET/backups/latest.tar.gz

# Cleanup local files
rm -rf $BACKUP_DIR $BACKUP_FILE

echo "Backup completed successfully and uploaded to S3"
echo "Public URL: https://$S3_BUCKET.s3.amazonaws.com/backups/$BACKUP_FILE"
EOF

# Make backup script executable
chmod +x /opt/mongodb-backup/backup.sh

# Setup daily backup cron job
echo "0 2 * * * root /opt/mongodb-backup/backup.sh >> /var/log/mongodb-backup.log 2>&1" >> /etc/crontab

# Install CloudWatch agent with retry
echo "Installing CloudWatch agent..."
retry_command yum install -y amazon-cloudwatch-agent

# Create CloudWatch agent configuration
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/mongodb/mongod.log",
            "log_group_name": "/aws/ec2/mongodb",
            "log_stream_name": "mongod.log"
          },
          {
            "file_path": "/var/log/mongodb-backup.log",
            "log_group_name": "/aws/ec2/mongodb",
            "log_stream_name": "backup.log"
          }
        ]
      }
    }
  }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

echo "MongoDB 4.0.x installation and configuration completed successfully!"
echo "MongoDB is running on port 27017 with authentication enabled"
echo "Backup script configured to run daily at 2 AM"
