# MongoDB EC2 Instance Troubleshooting Guide

## Overview
This guide helps troubleshoot the MongoDB EC2 instance deployment and connectivity issues in the Tasky application infrastructure.

## Quick Status Check

### 1. Check Terraform Outputs
After running `terraform apply`, check the outputs for troubleshooting information:
```bash
cd terraform
terraform output mongodb_troubleshooting
terraform output mongodb_cloudwatch_logs
terraform output mongodb_instance_id
terraform output mongodb_private_ip
```

### 2. Connect to EC2 Instance
Use AWS Systems Manager Session Manager to connect to the MongoDB instance:
```bash
# Get the instance ID from terraform output
INSTANCE_ID=$(terraform output -raw mongodb_instance_id)

# Connect to the instance
aws ssm start-session --target $INSTANCE_ID
```

### 3. Run Built-in Status Check
Once connected to the instance, run the comprehensive status check:
```bash
sudo /opt/mongodb-backup/status-check.sh
```

## CloudWatch Logs Access

### Available Log Streams
The MongoDB instance streams logs to CloudWatch under the log group `/aws/ec2/mongodb`:

1. **user-data.log** - Initial setup script execution
2. **mongodb-setup.log** - Detailed MongoDB installation logs  
3. **mongod.log** - MongoDB server logs
4. **backup.log** - Backup operation logs
5. **cloud-init.log** - Cloud-init execution logs
6. **cloud-init-output.log** - Cloud-init output logs

### Viewing Logs via AWS CLI
```bash
# List all log streams
aws logs describe-log-streams --log-group-name '/aws/ec2/mongodb'

# View user-data execution in real-time
INSTANCE_ID=$(terraform output -raw mongodb_instance_id)
aws logs tail '/aws/ec2/mongodb' --log-stream-names "${INSTANCE_ID}/user-data.log" --follow

# View MongoDB setup logs
aws logs tail '/aws/ec2/mongodb' --log-stream-names "${INSTANCE_ID}/mongodb-setup.log" --follow

# View MongoDB server logs
aws logs tail '/aws/ec2/mongodb' --log-stream-names "${INSTANCE_ID}/mongod.log" --follow
```

### Viewing Logs via AWS Console
1. Go to AWS CloudWatch Console
2. Navigate to Logs → Log groups
3. Find `/aws/ec2/mongodb`
4. Select the appropriate log stream based on your instance ID

## Common Issues and Solutions

### Issue 1: User-data Script Not Executing
**Symptoms:**
- No logs appearing in CloudWatch
- MongoDB not installed on the instance

**Troubleshooting Steps:**
1. Check cloud-init logs:
```bash
aws logs tail '/aws/ec2/mongodb' --log-stream-names "${INSTANCE_ID}/cloud-init-output.log" --follow
```

2. On the instance, check cloud-init status:
```bash
cloud-init status
cat /var/log/cloud-init.log
cat /var/log/cloud-init-output.log
```

3. Verify user-data was passed correctly:
```bash
curl -s http://169.254.169.254/latest/user-data
```

**Common Causes:**
- EC2 instance lacking internet access for package downloads
- IAM permissions insufficient for CloudWatch agent
- Terraform user-data encoding issues

### Issue 2: MongoDB Installation Failed
**Symptoms:**
- User-data logs show MongoDB installation errors
- MongoDB service not running

**Troubleshooting Steps:**
1. Check MongoDB installation logs:
```bash
aws logs tail '/aws/ec2/mongodb' --log-stream-names "${INSTANCE_ID}/mongodb-setup.log" --follow
```

2. On the instance, check MongoDB service status:
```bash
systemctl status mongod
journalctl -u mongod -f
```

3. Check MongoDB log file:
```bash
sudo tail -f /var/log/mongodb/mongod.log
```

**Common Causes:**
- Package repository unreachable
- Disk space issues
- Port 27017 already in use
- Permission issues with data directory

### Issue 3: MongoDB Authentication Issues
**Symptoms:**
- MongoDB installed but authentication failing
- Application cannot connect to database

**Troubleshooting Steps:**
1. Test MongoDB connectivity without authentication:
```bash
mongo --eval "db.adminCommand('ismaster')"
```

2. Test with authentication:
```bash
mongo tasky --username taskyadmin --password TaskySecure123! --authenticationDatabase tasky --eval "db.stats()"
```

3. Check user creation logs in user-data or MongoDB logs

**Common Causes:**
- Incorrect credentials in terraform variables
- Database name mismatch (should be 'tasky')
- Authentication database configuration issues

### Issue 4: CloudWatch Agent Not Working
**Symptoms:**
- No logs appearing in CloudWatch
- CloudWatch agent installation errors

**Troubleshooting Steps:**
1. Check CloudWatch agent status on instance:
```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -m ec2 -a query-config
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -a query-config
```

2. Check CloudWatch agent logs:
```bash
sudo tail -f /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log
```

3. Verify IAM permissions for CloudWatch

**Common Causes:**
- Insufficient IAM permissions
- CloudWatch agent configuration errors
- Network connectivity issues to CloudWatch endpoints

## Manual Recovery Steps

### If User-Data Failed to Complete
1. Connect to the instance via SSM
2. Download and run the user-data script manually:
```bash
# Download the user-data script
curl -s http://169.254.169.254/latest/user-data > /tmp/user-data.sh

# Make it executable
chmod +x /tmp/user-data.sh

# Run it manually (set variables first)
export MONGODB_USERNAME="taskyadmin"
export MONGODB_PASSWORD="TaskySecure123!"
export BACKUP_BUCKET_NAME="your-backup-bucket-name"

# Execute the script
sudo -E /tmp/user-data.sh
```

### If MongoDB Users Need Recreation
1. Connect to MongoDB as admin:
```bash
mongo admin --username admin --password TaskySecure123!
```

2. Create/recreate the tasky database user:
```javascript
use tasky
db.createUser({
  user: 'taskyadmin',
  pwd: 'TaskySecure123!',
  roles: [ { role: 'readWrite', db: 'tasky' } ]
});
```

### Force Terraform Resource Recreation
If the instance is in a bad state, you can force Terraform to recreate it:
```bash
terraform taint module.mongodb_ec2.aws_instance.mongodb
terraform apply
```

## Verification Checklist

After troubleshooting, verify the following:

- [ ] MongoDB service is running: `systemctl is-active mongod`
- [ ] MongoDB is accepting connections: `mongo --eval "db.adminCommand('ismaster')"`
- [ ] Authentication works: `mongo tasky --username taskyadmin --password TaskySecure123! --authenticationDatabase tasky --eval "db.stats()"`
- [ ] CloudWatch agent is running and sending logs
- [ ] Port 27017 is open and listening: `netstat -tlnp | grep :27017`
- [ ] Application can connect from EKS cluster

## Application Connection Test

To test if the Tasky application can connect to MongoDB:

1. Get the MongoDB connection URI:
```bash
terraform output -raw mongodb_connection_string
```

2. Test from within the EKS cluster (use a test pod):
```bash
kubectl run test-mongodb --rm -i --tty --image=mongo:4.0 --restart=Never -- mongo "mongodb://taskyadmin:TaskySecure123!@<mongodb-private-ip>:27017/tasky" --eval "db.stats()"
```

## End-to-End Application Testing

### Testing UI Data Flow to MongoDB

After deploying the application, perform these steps to verify the complete data flow from UI to MongoDB:

1. **Access the Tasky Application:**
   ```bash
   # Get the application URL from the load balancer
   kubectl get service -n tasky
   # Or if using ingress
   kubectl get ingress -n tasky
   ```

2. **Create Test Data via UI:**
   - Navigate to the application URL in your browser
   - Create a user account (if registration is enabled) or log in
   - Create several todo items with different names and statuses:
     - "Test item 1"
     - "Verify database integration"
     - "Check MongoDB connectivity"
     - "End-to-end testing"

3. **Verify Data Persistence in MongoDB:**

   **Method 1: Direct SSH to EC2 Instance**
   ```bash
   # Connect to MongoDB EC2 instance via SSM
   INSTANCE_ID=$(terraform output -raw mongodb_instance_id)
   aws ssm start-session --target $INSTANCE_ID
   
   # Once connected to the instance, access MongoDB
   mongo mongodb://taskyadmin:TaskySecure123!@localhost:27017/tasky
   ```

   **Method 2: From Local Machine (if VPN/direct access configured)**
   ```bash
   # Get MongoDB private IP
   MONGODB_IP=$(terraform output -raw mongodb_private_ip)
   
   # Connect via mongo client
   mongo mongodb://taskyadmin:TaskySecure123!@${MONGODB_IP}:27017/tasky
   ```

4. **Verify Records in MongoDB:**
   
   Once connected to MongoDB, run these verification commands:
   
   ```javascript
   // Check you're in the correct database
   db
   
   // List all collections
   show collections
   
   // View all todos created via UI
   db.todos.find().pretty()
   
   // Count total todos
   db.todos.count()
   
   // View user records
   db.user.find().pretty()
   
   // Check todos by status
   db.todos.find({"status": "pending"}).pretty()
   db.todos.find({"status": "completed"}).pretty()
   
   // Find todos by user (replace with actual userid from your data)
   db.todos.find({"userid": "YOUR_USER_OBJECT_ID"}).pretty()
   
   // Test aggregation - group todos by status
   db.todos.aggregate([
     {"$group": {"_id": "$status", "count": {"$sum": 1}}}
   ])
   
   // Test join operation - get todos with user info
   db.todos.aggregate([
     {
       "$lookup": {
         "from": "user",
         "localField": "userid", 
         "foreignField": "_id",
         "as": "user_info"
       }
     }
   ]).pretty()
   ```

5. **Test CRUD Operations via UI and Verify:**
   
   **Create Operation:**
   - Add a new todo via UI
   - Verify in MongoDB: `db.todos.find().sort({"_id": -1}).limit(1).pretty()`
   
   **Update Operation (if supported):**
   - Mark a todo as completed via UI
   - Verify in MongoDB: `db.todos.find({"status": "completed"}).pretty()`
   
   **Delete Operation (if supported):**
   - Delete a todo via UI
   - Verify in MongoDB: `db.todos.count()` (should decrease)

6. **Real-time Data Verification:**
   
   Keep a MongoDB session open while using the UI:
   ```javascript
   // Watch for changes in real-time (MongoDB 4.0+ with replica sets)
   // For simple polling, run this repeatedly:
   db.todos.find().count()
   
   // Or check the latest created todo
   db.todos.find().sort({"_id": -1}).limit(1).pretty()
   ```

7. **Common Expected Results:**
   ```javascript
   // Expected todo document structure:
   {
     "_id": ObjectId("687d3aed475631a5269f8e91"),
     "name": "Test item created via UI",
     "status": "pending", // or "completed"
     "userid": "687d3ae2447eea89b3d27023"
   }
   
   // Expected user document structure:
   {
     "_id": ObjectId("687d3ae2447eea89b3d27023"),
     "username": "testuser",
     "email": "test@example.com",
     // other user fields...
   }
   ```

### Troubleshooting UI to Database Connection Issues

**If todos created in UI don't appear in MongoDB:**

1. **Check Application Logs:**
   ```bash
   # Get pod logs
   kubectl logs -n tasky -l app=tasky --tail=100
   
   # Follow logs in real-time while testing UI
   kubectl logs -n tasky -l app=tasky -f
   ```

2. **Verify Database Connection String:**
   ```bash
   # Check if the app has correct MongoDB connection details
   kubectl get configmap -n tasky -o yaml
   kubectl get secret -n tasky -o yaml
   ```

3. **Test Network Connectivity from Pod:**
   ```bash
   # Get a shell in the application pod
   kubectl exec -it -n tasky deployment/tasky -- /bin/sh
   
   # Test MongoDB connectivity from within the pod
   nc -zv <mongodb-private-ip> 27017
   
   # Or test with mongo client if available
   mongo mongodb://taskyadmin:TaskySecure123!@<mongodb-private-ip>:27017/tasky --eval "db.stats()"
   ```

4. **Common Issues:**
   - Security group not allowing traffic from EKS to EC2 on port 27017
   - Incorrect MongoDB connection string in application configuration
   - Authentication credentials mismatch
   - Database name mismatch (should be 'tasky')
   - MongoDB service not running on EC2 instance

**Success Indicators:**
- ✅ Todos created in UI appear immediately in MongoDB queries
- ✅ User authentication works both in UI and MongoDB
- ✅ Real-time updates reflect correctly between UI and database
- ✅ All CRUD operations function end-to-end
- ✅ Data persists after application restarts

## Performance Monitoring

Monitor MongoDB performance through CloudWatch metrics and logs:

1. **Key Metrics to Watch:**
   - CPU utilization
   - Memory usage
   - Disk I/O
   - Network connections

2. **Log Patterns to Monitor:**
   - Connection attempts
   - Authentication failures
   - Slow queries
   - Error messages

## Contact and Support

For additional help:
1. Review the detailed logs in CloudWatch
2. Check the Terraform configuration for any mismatched variables
3. Ensure network connectivity between EKS and EC2
4. Verify security group rules allow traffic on port 27017
