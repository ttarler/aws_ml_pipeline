# S3 Bucket for Access Logs
resource "aws_s3_bucket" "access_logs" {
  bucket        = "${var.project_name}-access-logs-${var.account_id}"
  force_destroy = true

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-access-logs"
      Purpose     = "S3 Access Logs"
      Environment = var.environment
    }
  )
}

# Enable versioning for access logs bucket
resource "aws_s3_bucket_versioning" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption for access logs bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != "" ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn != "" ? var.kms_key_arn : null
    }
    bucket_key_enabled = var.kms_key_arn != "" ? true : false
  }
}

# Block public access for access logs bucket
resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policy for access logs bucket
resource "aws_s3_bucket_lifecycle_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

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
      sse_algorithm     = var.kms_key_arn != "" ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn != "" ? var.kms_key_arn : null
    }
    bucket_key_enabled = var.kms_key_arn != "" ? true : false
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

# Enable access logging for landing zone bucket
resource "aws_s3_bucket_logging" "landing_zone" {
  bucket = aws_s3_bucket.landing_zone.id

  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "landing-zone/"
}

# Lifecycle policy for landing zone bucket
resource "aws_s3_bucket_lifecycle_configuration" "landing_zone" {
  bucket = aws_s3_bucket.landing_zone.id

  rule {
    id     = "expire-old-data"
    status = "Enabled"

    filter {}

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
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
      sse_algorithm     = var.kms_key_arn != "" ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn != "" ? var.kms_key_arn : null
    }
    bucket_key_enabled = var.kms_key_arn != "" ? true : false
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

# Enable access logging for SageMaker bucket
resource "aws_s3_bucket_logging" "sagemaker" {
  bucket = aws_s3_bucket.sagemaker.id

  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "sagemaker/"
}

# Lifecycle policy for SageMaker bucket
resource "aws_s3_bucket_lifecycle_configuration" "sagemaker" {
  bucket = aws_s3_bucket.sagemaker.id

  rule {
    id     = "expire-old-artifacts"
    status = "Enabled"

    filter {}

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
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
      sse_algorithm     = var.kms_key_arn != "" ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn != "" ? var.kms_key_arn : null
    }
    bucket_key_enabled = var.kms_key_arn != "" ? true : false
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

# Enable access logging for EMR logs bucket
resource "aws_s3_bucket_logging" "emr_logs" {
  bucket = aws_s3_bucket.emr_logs.id

  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "emr-logs/"
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

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
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
      sse_algorithm     = var.kms_key_arn != "" ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn != "" ? var.kms_key_arn : null
    }
    bucket_key_enabled = var.kms_key_arn != "" ? true : false
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

# Enable access logging for ECS artifacts bucket
resource "aws_s3_bucket_logging" "ecs_artifacts" {
  bucket = aws_s3_bucket.ecs_artifacts.id

  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "ecs-artifacts/"
}

# Lifecycle policy for ECS artifacts bucket
resource "aws_s3_bucket_lifecycle_configuration" "ecs_artifacts" {
  bucket = aws_s3_bucket.ecs_artifacts.id

  rule {
    id     = "expire-old-artifacts"
    status = "Enabled"

    filter {}

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

