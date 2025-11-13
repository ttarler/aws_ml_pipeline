# S3 Bucket for Landing Zone
resource "aws_s3_bucket" "landing_zone" {
  bucket        = "${var.project_name}-landing-zone-${var.account_id}"
  force_destroy = true

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-landing-zone"
      Purpose     = "Data Landing Zone"
      Environment = var.environment
    }
  )
}

# Enable versioning for landing zone bucket
resource "aws_s3_bucket_versioning" "landing_zone" {
  bucket = aws_s3_bucket.landing_zone.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption for landing zone bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "landing_zone" {
  bucket = aws_s3_bucket.landing_zone.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access for landing zone bucket
resource "aws_s3_bucket_public_access_block" "landing_zone" {
  bucket = aws_s3_bucket.landing_zone.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket for SageMaker
resource "aws_s3_bucket" "sagemaker" {
  bucket        = "${var.project_name}-sagemaker-${var.account_id}"
  force_destroy = true

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-sagemaker"
      Purpose     = "SageMaker Artifacts"
      Environment = var.environment
    }
  )
}

# Enable versioning for SageMaker bucket
resource "aws_s3_bucket_versioning" "sagemaker" {
  bucket = aws_s3_bucket.sagemaker.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption for SageMaker bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "sagemaker" {
  bucket = aws_s3_bucket.sagemaker.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access for SageMaker bucket
resource "aws_s3_bucket_public_access_block" "sagemaker" {
  bucket = aws_s3_bucket.sagemaker.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket for EMR Logs
resource "aws_s3_bucket" "emr_logs" {
  bucket        = "${var.project_name}-emr-logs-${var.account_id}"
  force_destroy = true

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-emr-logs"
      Purpose     = "EMR Cluster Logs"
      Environment = var.environment
    }
  )
}

# Enable versioning for EMR logs bucket
resource "aws_s3_bucket_versioning" "emr_logs" {
  bucket = aws_s3_bucket.emr_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption for EMR logs bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "emr_logs" {
  bucket = aws_s3_bucket.emr_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access for EMR logs bucket
resource "aws_s3_bucket_public_access_block" "emr_logs" {
  bucket = aws_s3_bucket.emr_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policy for EMR logs (optional - retain logs for 90 days)
resource "aws_s3_bucket_lifecycle_configuration" "emr_logs" {
  bucket = aws_s3_bucket.emr_logs.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    # Apply to all objects in the bucket
    filter {}

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# S3 Bucket for ECS/Docker artifacts
resource "aws_s3_bucket" "ecs_artifacts" {
  bucket        = "${var.project_name}-ecs-artifacts-${var.account_id}"
  force_destroy = true

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-ecs-artifacts"
      Purpose     = "ECS/Docker Artifacts"
      Environment = var.environment
    }
  )
}

# Enable versioning for ECS artifacts bucket
resource "aws_s3_bucket_versioning" "ecs_artifacts" {
  bucket = aws_s3_bucket.ecs_artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption for ECS artifacts bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "ecs_artifacts" {
  bucket = aws_s3_bucket.ecs_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access for ECS artifacts bucket
resource "aws_s3_bucket_public_access_block" "ecs_artifacts" {
  bucket = aws_s3_bucket.ecs_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
