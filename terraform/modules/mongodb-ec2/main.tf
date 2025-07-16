# Data source for Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group for MongoDB
resource "aws_security_group" "mongodb" {
  name_prefix = "${var.project_name}-${var.environment}-mongodb-"
  vpc_id      = var.vpc_id

  # MongoDB port access from VPC
  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "MongoDB access from VPC"
  }

  # SSH access (optional, for troubleshooting)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "SSH access from VPC"
  }

  # Outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-${var.stack_version}-mongodb-sg"
  })
}

# IAM Role for MongoDB EC2 instance (Admin access as required)
resource "aws_iam_role" "mongodb" {
  name = "${var.project_name}-${var.environment}-${var.stack_version}-mongodb-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Attach AdministratorAccess policy (as required by exercise)
resource "aws_iam_role_policy_attachment" "mongodb_admin" {
  role       = aws_iam_role.mongodb.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "mongodb" {
  name = "${var.project_name}-${var.environment}-${var.stack_version}-mongodb-profile"
  role = aws_iam_role.mongodb.name

  tags = var.tags
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "mongodb" {
  name              = "/aws/ec2/mongodb"
  retention_in_days = 30

  tags = var.tags
}

# Render user data script with variables
locals {
  user_data = templatefile("${path.module}/user-data.sh", {
    MONGODB_USERNAME   = var.mongodb_username
    MONGODB_PASSWORD   = var.mongodb_password
    BACKUP_BUCKET_NAME = var.backup_bucket_name
  })
}

# EC2 Instance for MongoDB
resource "aws_instance" "mongodb" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  subnet_id              = var.private_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.mongodb.id]
  iam_instance_profile   = aws_iam_instance_profile.mongodb.name

  # Fixed: Remove base64encode as templatefile handles encoding properly
  user_data = local.user_data
  
  # Force replacement if user data changes
  user_data_replace_on_change = true

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true

    tags = merge(var.tags, {
      Name = "${var.project_name}-${var.environment}-${var.stack_version}-mongodb-root"
    })
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-${var.stack_version}-mongodb"
    Role = "database"
  })
}
