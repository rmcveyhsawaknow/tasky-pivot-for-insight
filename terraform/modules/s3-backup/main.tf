locals {
  bucket_name = "${var.project_name}-${var.environment}-${var.stack_version}-mongodb-backup-${random_string.bucket_suffix.result}"
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# S3 Bucket for MongoDB backups
resource "aws_s3_bucket" "backup" {
  bucket = local.bucket_name

  tags = merge(var.tags, {
    Name    = "${var.project_name}-${var.environment}-${var.stack_version}-mongodb-backup"
    Purpose = "MongoDB backup storage with public read access"
  })
}

# S3 Bucket versioning
resource "aws_s3_bucket_versioning" "backup" {
  bucket = aws_s3_bucket.backup.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket public access configuration
resource "aws_s3_bucket_public_access_block" "backup" {
  bucket = aws_s3_bucket.backup.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# S3 Bucket policy for public read access
resource "aws_s3_bucket_policy" "backup_public_read" {
  bucket = aws_s3_bucket.backup.id

  depends_on = [aws_s3_bucket_public_access_block.backup]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.backup.arn}/*"
      }
    ]
  })
}

# S3 Bucket lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "backup" {
  bucket = aws_s3_bucket.backup.id

  rule {
    id     = "backup_lifecycle"
    status = "Enabled"

    filter {
      prefix = "backups/"
    }

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}
