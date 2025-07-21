# ==============================================================================
# ALB MODULE OUTPUTS
# ==============================================================================

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_hosted_zone_id" {
  description = "Hosted zone ID of the Application Load Balancer"
  value       = aws_lb.main.zone_id
}

output "alb_security_group_id" {
  description = "Security group ID of the Application Load Balancer"
  value       = aws_security_group.alb.id
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.app.arn
}

output "target_group_arn_suffix" {
  description = "ARN suffix of the target group for CloudWatch metrics"
  value       = aws_lb_target_group.app.arn_suffix
}

output "application_url" {
  description = "Application URL (HTTP or HTTPS based on SSL configuration)"
  value       = var.ssl_certificate_arn != null ? "https://${aws_lb.main.dns_name}" : "http://${aws_lb.main.dns_name}"
}

output "custom_domain_url" {
  description = "Custom domain URL if DNS record is created"
  value       = var.create_dns_record && var.domain_name != null ? (var.ssl_certificate_arn != null ? "https://${var.domain_name}" : "http://${var.domain_name}") : null
}

output "health_check_path" {
  description = "Health check path used by the target group"
  value       = aws_lb_target_group.app.health_check[0].path
}
