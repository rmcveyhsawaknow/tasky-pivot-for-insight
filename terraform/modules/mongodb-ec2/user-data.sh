#!/bin/bash
set -e
LOG_FILE="/var/log/user-data.log"
MONGODB_LOG_FILE="/var/log/mongodb-setup.log"
touch $LOG_FILE $MONGODB_LOG_FILE
chmod 644 $LOG_FILE $MONGODB_LOG_FILE

log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE $MONGODB_LOG_FILE
}
log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a $LOG_FILE $MONGODB_LOG_FILE >&2
}
log_success() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $1" | tee -a $LOG_FILE $MONGODB_LOG_FILE
}

exec > >(tee -a $LOG_FILE | logger -t user-data -s 2>/dev/console) 2>&1

log_info "Starting MongoDB 4.0.x install"
log_info "Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)"

retry_cmd() {
    local max_attempts=3
    local delay=10
    local attempt=1
    local desc="$1"
    shift
    
    while [ $attempt -le $max_attempts ]; do
        if "$@"; then
            log_success "Command succeeded: $desc"
            return 0
        else
            log_error "Command failed attempt $attempt: $desc"
            if [ $attempt -lt $max_attempts ]; then
                sleep $delay
            fi
            attempt=$((attempt + 1))
        fi
    done
    log_error "Command failed after $max_attempts attempts: $desc"
    return 1
}

log_info "Installing CloudWatch agent"
retry_cmd "CloudWatch install" yum install -y amazon-cloudwatch-agent

log_info "Testing network"
retry_cmd "Network test" ping -c 3 amazon.com

log_info "Updating packages"
retry_cmd "Package update" yum update -y

log_info "Installing AWS CLI v2"
retry_cmd "AWS CLI download" curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf aws awscliv2.zip

log_info "Creating MongoDB repo"
cat > /etc/yum.repos.d/mongodb-org-4.0.repo << 'EOF'
[mongodb-org-4.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/amazon/2/mongodb-org/4.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-4.0.asc
EOF

log_info "Installing MongoDB 4.0.28"
retry_cmd "MongoDB install" yum install -y mongodb-org-4.0.28 mongodb-org-server-4.0.28 mongodb-org-shell-4.0.28 mongodb-org-mongos-4.0.28 mongodb-org-tools-4.0.28

log_info "Pinning MongoDB version"
echo "exclude=mongodb-org,mongodb-org-server,mongodb-org-shell,mongodb-org-mongos,mongodb-org-tools" >> /etc/yum.conf

log_info "Configuring MongoDB dirs"
mkdir -p /data/db
chown -R mongod:mongod /data/db
chmod 755 /data/db
mkdir -p /var/log/mongodb
chown -R mongod:mongod /var/log/mongodb

log_info "Creating MongoDB config"
cat > /etc/mongod.conf << 'EOF'
storage:
  dbPath: /data/db
  journal:
    enabled: true
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log
  logRotate: reopen
net:
  port: 27017
  bindIp: 0.0.0.0
processManagement:
  timeZoneInfo: /usr/share/zoneinfo
  fork: true
  pidFilePath: /var/run/mongodb/mongod.pid
security:
  authorization: enabled
EOF

log_info "Starting MongoDB"
systemctl start mongod
if systemctl is-active --quiet mongod; then
    log_success "MongoDB started"
else
    log_error "MongoDB failed to start"
    systemctl status mongod | tee -a $MONGODB_LOG_FILE
    exit 1
fi

systemctl enable mongod

log_info "Waiting for MongoDB ready"
for i in {1..30}; do
    if mongo --eval "db.adminCommand('ismaster')" > /dev/null 2>&1; then
        log_success "MongoDB ready"
        break
    fi
    sleep 2
done

if ! mongo --eval "db.adminCommand('ismaster')" > /dev/null 2>&1; then
    log_error "MongoDB failed to become ready"
    exit 1
fi

log_info "Creating admin user"
if mongo admin --eval "
db.createUser({
  user: 'admin',
  pwd: '${MONGODB_PASSWORD}',
  roles: [ { role: 'userAdminAnyDatabase', db: 'admin' }, 'readWriteAnyDatabase' ]
});
" > /dev/null 2>&1; then
    log_success "Admin user created"
else
    log_error "Failed to create admin user"
    exit 1
fi

log_info "Creating ${MONGODB_DATABASE_NAME} user"
if mongo admin --username admin --password ${MONGODB_PASSWORD} --authenticationDatabase admin --eval "
use ${MONGODB_DATABASE_NAME};
db.createUser({
  user: '${MONGODB_USERNAME}',
  pwd: '${MONGODB_PASSWORD}',
  roles: [ { role: 'readWrite', db: '${MONGODB_DATABASE_NAME}' } ]
});
" > /dev/null 2>&1; then
    log_success "${MONGODB_DATABASE_NAME} user created"
else
    if mongo ${MONGODB_DATABASE_NAME} --username admin --password ${MONGODB_PASSWORD} --authenticationDatabase admin --eval "
db.createUser({
  user: '${MONGODB_USERNAME}',
  pwd: '${MONGODB_PASSWORD}',
  roles: [ { role: 'readWrite', db: '${MONGODB_DATABASE_NAME}' } ]
});
" > /dev/null 2>&1; then
        log_success "${MONGODB_DATABASE_NAME} user created (alt method)"
    else
        log_error "Failed to create ${MONGODB_DATABASE_NAME} user"
        exit 1
    fi
fi

log_info "Testing connectivity"
if mongo ${MONGODB_DATABASE_NAME} --username ${MONGODB_USERNAME} --password ${MONGODB_PASSWORD} --authenticationDatabase ${MONGODB_DATABASE_NAME} --eval "db.stats()" > /dev/null 2>&1; then
    log_success "DB test passed"
else
    if mongo ${MONGODB_DATABASE_NAME} --username admin --password ${MONGODB_PASSWORD} --authenticationDatabase admin --eval "db.stats()" > /dev/null 2>&1; then
        log_success "DB test passed (admin)"
    else
        log_error "DB test failed"
        exit 1
    fi
fi

log_info "Creating enhanced demo backup script"
mkdir -p /opt/mongodb-backup
cat > /opt/mongodb-backup/backup.sh << 'EOF'
#!/bin/bash
set -e

# Configuration
MONGODB_HOST="$${MONGODB_HOST:-localhost}"
MONGODB_PORT="$${MONGODB_PORT:-27017}"
MONGODB_DATABASE="$${MONGODB_DATABASE:-${MONGODB_DATABASE_NAME}}"
MONGODB_USERNAME="$${MONGODB_USERNAME:-${MONGODB_USERNAME}}"
MONGODB_PASSWORD="$${MONGODB_PASSWORD:-${MONGODB_PASSWORD}}"
S3_BUCKET="$${S3_BUCKET:-${BACKUP_BUCKET_NAME}}"
AWS_REGION="$${AWS_REGION:-us-east-1}"

# Backup directory and logging
BACKUP_LOG="/var/log/mongodb-backup.log"
exec > >(tee -a "$$BACKUP_LOG") 2>&1

log_backup() {
    echo "[$$(date '+%Y-%m-%d %H:%M:%S')] $$1"
}

# Generate timestamp and Julian date for demo
TIMESTAMP=$$(date +%Y%m%d_%H%M%S)
JULIAN_DATE=$$(date +%Y%j)  # Year + Julian day (e.g., 2025202 for July 21, 2025)
BACKUP_DIR="/tmp/mongodb-backup-$$TIMESTAMP"
JULIAN_BACKUP_FILE="cron_$$JULIAN_DATE.tar.gz"

log_backup "Starting MongoDB backup for demo (5-minute interval)"
log_backup "Julian date: $$JULIAN_DATE"

# Create backup directory
mkdir -p $$BACKUP_DIR

# Create BSON dump (standard MongoDB backup)
log_backup "Creating MongoDB dump..."
if mongodump --host localhost:27017 --db $$MONGODB_DATABASE --username $$MONGODB_USERNAME --password $$MONGODB_PASSWORD --authenticationDatabase $$MONGODB_DATABASE --out $$BACKUP_DIR --quiet; then
    log_backup "BSON dump created successfully"
else
    # Fallback to admin user if main user fails
    if mongodump --host localhost:27017 --db $$MONGODB_DATABASE --username admin --password $$MONGODB_PASSWORD --authenticationDatabase admin --out $$BACKUP_DIR --quiet; then
        log_backup "BSON dump created (admin user)"
    else
        log_backup "ERROR: MongoDB dump failed"
        exit 1
    fi
fi

# Create JSON exports for easy demo viewing
mkdir -p $$BACKUP_DIR/json
log_backup "Creating JSON exports for demo viewing..."

# Export todos collection as readable JSON
if mongoexport --host localhost:27017 --db $$MONGODB_DATABASE --collection "todos" --username $$MONGODB_USERNAME --password $$MONGODB_PASSWORD --authenticationDatabase $$MONGODB_DATABASE --jsonArray --pretty --out $$BACKUP_DIR/json/todos.json --quiet; then
    log_backup "Todos JSON export created"
else
    # Fallback to admin user
    mongoexport --host localhost:27017 --db $$MONGODB_DATABASE --collection "todos" --username admin --password $$MONGODB_PASSWORD --authenticationDatabase admin --jsonArray --pretty --out $$BACKUP_DIR/json/todos.json --quiet || log_backup "Warning: Could not export todos JSON"
fi

# Export users collection as readable JSON
if mongoexport --host localhost:27017 --db $$MONGODB_DATABASE --collection "user" --username $$MONGODB_USERNAME --password $$MONGODB_PASSWORD --authenticationDatabase $$MONGODB_DATABASE --jsonArray --pretty --out $$BACKUP_DIR/json/user.json --quiet; then
    log_backup "User JSON export created"
else
    # Fallback to admin user
    mongoexport --host localhost:27017 --db $$MONGODB_DATABASE --collection "user" --username admin --password $$MONGODB_PASSWORD --authenticationDatabase admin --jsonArray --pretty --out $$BACKUP_DIR/json/user.json --quiet || log_backup "Warning: Could not export user JSON"
fi

# Create demo README with instructions
cat > $$BACKUP_DIR/README_DEMO.txt << DEMOEOF
MongoDB Backup for Tasky App Demo
Generated: $$(date)
Julian Date: $$JULIAN_DATE

=== DEMO VIEWING INSTRUCTIONS ===
1. Open json/todos.json in any text editor (Notepad, VS Code, etc.)
2. This file contains all current tasks in readable JSON format
3. Watch this file to see real-time demo changes!

Files included:
- json/todos.json     - All tasks (human-readable)
- json/user.json      - User data (human-readable) 
- $$MONGODB_DATABASE/  - Standard MongoDB BSON backup format

Demo schedule: Backups run every 5 minutes automatically
DEMOEOF

# Get document counts for logging
TODOS_COUNT=$$(mongo $$MONGODB_DATABASE --host localhost:27017 --username $$MONGODB_USERNAME --password $$MONGODB_PASSWORD --authenticationDatabase $$MONGODB_DATABASE --quiet --eval "db.todos.count()" 2>/dev/null || echo "0")
USERS_COUNT=$$(mongo $$MONGODB_DATABASE --host localhost:27017 --username $$MONGODB_USERNAME --password $$MONGODB_PASSWORD --authenticationDatabase $$MONGODB_DATABASE --quiet --eval "db.user.count()" 2>/dev/null || echo "0")
log_backup "Backup created - Todos: $$TODOS_COUNT, Users: $$USERS_COUNT"

# Create compressed archives
cd /tmp
log_backup "Creating compressed archives..."

# Create latest.tar.gz (overwrites previous - always current for demo)
tar -czf "latest.tar.gz" "mongodb-backup-$$TIMESTAMP/"

# Create Julian date backup (preserves history)
tar -czf "$$JULIAN_BACKUP_FILE" "mongodb-backup-$$TIMESTAMP/"

# Get file size for logging
FILE_SIZE=$$(du -h "latest.tar.gz" | cut -f1)
log_backup "Archive size: $$FILE_SIZE"

# Upload to S3
log_backup "Uploading to S3 bucket: $$S3_BUCKET"

# Upload latest.tar.gz (overwrites previous)
if aws s3 cp "latest.tar.gz" "s3://$$S3_BUCKET/backups/latest.tar.gz" --region $$AWS_REGION --quiet; then
    log_backup "✓ Uploaded latest.tar.gz (demo file)"
else
    log_backup "ERROR: Failed to upload latest.tar.gz"
    exit 1
fi

# Upload Julian date backup (preserves history)
if aws s3 cp "$$JULIAN_BACKUP_FILE" "s3://$$S3_BUCKET/backups/$$JULIAN_BACKUP_FILE" --region $$AWS_REGION --quiet; then
    log_backup "✓ Uploaded Julian backup: $$JULIAN_BACKUP_FILE"
else
    log_backup "ERROR: Failed to upload Julian backup"
    exit 1
fi

# Generate public URLs
LATEST_URL="https://$$S3_BUCKET.s3.$$AWS_REGION.amazonaws.com/backups/latest.tar.gz"
JULIAN_URL="https://$$S3_BUCKET.s3.$$AWS_REGION.amazonaws.com/backups/$$JULIAN_BACKUP_FILE"

log_backup "=== BACKUP COMPLETE ==="
log_backup "Public URLs:"
log_backup "  Latest (demo): $$LATEST_URL"
log_backup "  This backup: $$JULIAN_URL"
log_backup "Demo: Download latest.tar.gz and open */json/todos.json in text editor"

# Cleanup local files
rm -rf $$BACKUP_DIR latest.tar.gz $$JULIAN_BACKUP_FILE
log_backup "Local cleanup completed"
EOF

chmod +x /opt/mongodb-backup/backup.sh

# Schedule backup to run every 5 minutes for demo purposes
log_info "Configuring cron job for 5-minute backup schedule"
echo "*/5 * * * * root /opt/mongodb-backup/backup.sh" >> /etc/crontab

log_info "Backup system configured:"
log_info "  - Runs every 5 minutes automatically"
log_info "  - Creates latest.tar.gz (overwrites for demo)"
log_info "  - Creates Julian date backups (preserves history)"
log_info "  - Includes JSON exports for easy text viewing"

log_info "Configuring CloudWatch"
mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/user-data.log",
            "log_group_name": "/aws/ec2/mongodb",
            "log_stream_name": "{instance_id}/user-data.log",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/mongodb-setup.log",
            "log_group_name": "/aws/ec2/mongodb",
            "log_stream_name": "{instance_id}/mongodb-setup.log",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/mongodb/mongod.log",
            "log_group_name": "/aws/ec2/mongodb",
            "log_stream_name": "{instance_id}/mongod.log",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/mongodb-backup.log",
            "log_group_name": "/aws/ec2/mongodb",
            "log_stream_name": "{instance_id}/backup.log",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/cloud-init.log",
            "log_group_name": "/aws/ec2/mongodb",
            "log_stream_name": "{instance_id}/cloud-init.log",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/cloud-init-output.log",
            "log_group_name": "/aws/ec2/mongodb",
            "log_stream_name": "{instance_id}/cloud-init-output.log",
            "timezone": "UTC"
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "CWAgent",
    "metrics_collected": {
      "cpu": {
        "measurement": [
          "cpu_usage_idle",
          "cpu_usage_iowait",
          "cpu_usage_user",
          "cpu_usage_system"
        ],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": [
          "used_percent"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "diskio": {
        "measurement": [
          "io_time"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "mem": {
        "measurement": [
          "mem_used_percent"
        ],
        "metrics_collection_interval": 60
      },
      "netstat": {
        "measurement": [
          "tcp_established",
          "tcp_time_wait"
        ],
        "metrics_collection_interval": 60
      }
    }
  }
}
EOF

log_info "Starting CloudWatch agent"
if /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s; then
    log_success "CloudWatch started"
else
    log_error "CloudWatch failed"
fi

log_info "Creating status script"
cat > /opt/mongodb-backup/status-check.sh << 'EOF'
#!/bin/bash
echo "=== MongoDB Status Check ==="
echo "Timestamp: $$(date)"
echo "Instance ID: $$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
echo "Instance Type: $$(curl -s http://169.254.169.254/latest/meta-data/instance-type)"
echo "AZ: $$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)"
systemctl status mongod
ps aux | grep mongod | grep -v grep
netstat -tlnp | grep :27017
if mongo --eval "db.adminCommand('ismaster')" > /dev/null 2>&1; then
    echo "✓ MongoDB accepting connections"
else
    echo "✗ MongoDB NOT accepting connections"
fi
if mongo ${MONGODB_DATABASE_NAME} --username ${MONGODB_USERNAME} --password ${MONGODB_PASSWORD} --authenticationDatabase ${MONGODB_DATABASE_NAME} --eval "db.stats()" > /dev/null 2>&1; then
    echo "✓ DB auth success (${MONGODB_DATABASE_NAME} user)"
else
    if mongo ${MONGODB_DATABASE_NAME} --username admin --password ${MONGODB_PASSWORD} --authenticationDatabase admin --eval "db.stats()" > /dev/null 2>&1; then
        echo "✓ DB auth success (admin user)"
    else
        echo "✗ DB auth failed"
    fi
fi
df -h
free -h
tail -n 10 /var/log/mongodb/mongod.log
EOF

chmod +x /opt/mongodb-backup/status-check.sh

log_info "Running final status check"
/opt/mongodb-backup/status-check.sh | tee -a $MONGODB_LOG_FILE

log_success "MongoDB install complete"
log_info "URI: mongodb://${MONGODB_USERNAME}:${MONGODB_PASSWORD}@$$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4):27017/${MONGODB_DATABASE_NAME}"

touch /var/log/user-data-completed
