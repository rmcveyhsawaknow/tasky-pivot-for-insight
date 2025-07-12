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
