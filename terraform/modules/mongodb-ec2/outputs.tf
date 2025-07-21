output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.mongodb.id
}

output "private_ip" {
  description = "EC2 instance private IP"
  value       = aws_instance.mongodb.private_ip
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.mongodb.id
}

output "iam_role_arn" {
  description = "IAM role ARN"
  value       = aws_iam_role.mongodb.arn
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch log group name for MongoDB logs"
  value       = aws_cloudwatch_log_group.mongodb.name
}

output "cloudwatch_log_group_arn" {
  description = "CloudWatch log group ARN"
  value       = aws_cloudwatch_log_group.mongodb.arn
}

output "mongodb_connection_uri" {
  description = "MongoDB connection URI for applications"
  value       = "mongodb://${var.mongodb_username}:${var.mongodb_password}@${aws_instance.mongodb.private_ip}:27017/${var.mongodb_database_name}"
  sensitive   = true
}

output "mongodb_host" {
  description = "MongoDB host (private IP)"
  value       = aws_instance.mongodb.private_ip
}

output "mongodb_port" {
  description = "MongoDB port"
  value       = "27017"
}

output "mongodb_database" {
  description = "MongoDB database name"
  value       = var.mongodb_database_name
}

output "troubleshooting_commands" {
  description = "Useful commands for troubleshooting the MongoDB instance"
  value = {
    ssm_connect        = "aws ssm start-session --target ${aws_instance.mongodb.id}"
    view_logs          = "aws logs describe-log-streams --log-group-name '${aws_cloudwatch_log_group.mongodb.name}'"
    tail_user_data     = "aws logs tail '${aws_cloudwatch_log_group.mongodb.name}' --log-stream-names '${aws_instance.mongodb.id}/user-data.log' --follow"
    tail_mongodb_setup = "aws logs tail '${aws_cloudwatch_log_group.mongodb.name}' --log-stream-names '${aws_instance.mongodb.id}/mongodb-setup.log' --follow"
    tail_mongodb_log   = "aws logs tail '${aws_cloudwatch_log_group.mongodb.name}' --log-stream-names '${aws_instance.mongodb.id}/mongod.log' --follow"
    view_cloud_init    = "aws logs tail '${aws_cloudwatch_log_group.mongodb.name}' --log-stream-names '${aws_instance.mongodb.id}/cloud-init-output.log' --follow"
    status_check       = "Run '/opt/mongodb-backup/status-check.sh' on the instance via SSM"
  }
}
