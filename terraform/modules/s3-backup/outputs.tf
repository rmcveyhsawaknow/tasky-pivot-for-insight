output "bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.backup.bucket
}

output "bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.backup.arn
}

output "public_url" {
  description = "S3 bucket public URL"
  value       = "https://${aws_s3_bucket.backup.bucket}.s3.amazonaws.com"
}
