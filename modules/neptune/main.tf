# Local variables for Neptune version handling
locals {
  # Extract parameter group family from engine version
  # For version "1.2.1.0", family is "neptune1.2"
  # For version "1.0.x.x", family is "neptune1"
  neptune_family = "neptune${replace(var.neptune_engine_version, "/^(\\d+\\.\\d+).*/", "$1")}"
}

# Neptune Subnet Group
resource "aws_neptune_subnet_group" "main" {
  name       = "${var.project_name}-neptune-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-neptune-subnet-group"
    }
  )
}

# Neptune Cluster Parameter Group
resource "aws_neptune_cluster_parameter_group" "main" {
  family      = local.neptune_family
  name        = "${var.project_name}-neptune-cluster-params"
  description = "Neptune cluster parameter group for ${var.project_name}"

  parameter {
    name  = "neptune_enable_audit_log"
    value = var.enable_audit_log ? "1" : "0"
  }

  parameter {
    name  = "neptune_query_timeout"
    value = var.query_timeout
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-neptune-cluster-params"
    }
  )
}

# Neptune DB Parameter Group
resource "aws_neptune_parameter_group" "main" {
  family      = local.neptune_family
  name        = "${var.project_name}-neptune-db-params"
  description = "Neptune DB parameter group for ${var.project_name}"

  parameter {
    name  = "neptune_query_timeout"
    value = var.query_timeout
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-neptune-db-params"
    }
  )
}

# Neptune Cluster
resource "aws_neptune_cluster" "main" {
  cluster_identifier                  = "${var.project_name}-neptune-cluster"
  engine                              = "neptune"
  engine_version                      = var.neptune_engine_version
  backup_retention_period             = var.backup_retention_period
  preferred_backup_window             = var.preferred_backup_window
  preferred_maintenance_window        = var.preferred_maintenance_window
  skip_final_snapshot                 = var.skip_final_snapshot
  final_snapshot_identifier           = var.skip_final_snapshot ? null : "${var.project_name}-neptune-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  iam_database_authentication_enabled = var.iam_database_authentication_enabled
  apply_immediately                   = var.apply_immediately
  storage_encrypted                   = true
  kms_key_arn                         = var.kms_key_arn != "" ? var.kms_key_arn : null
  deletion_protection                 = true
  copy_tags_to_snapshot               = true

  neptune_subnet_group_name            = aws_neptune_subnet_group.main.name
  neptune_cluster_parameter_group_name = aws_neptune_cluster_parameter_group.main.name
  vpc_security_group_ids               = [var.neptune_security_group_id]

  enable_cloudwatch_logs_exports = var.enable_cloudwatch_logs ? ["audit"] : []

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-neptune-cluster"
    }
  )

  lifecycle {
    ignore_changes = [
      final_snapshot_identifier
    ]
  }
}

# Neptune Instances
resource "aws_neptune_cluster_instance" "main" {
  count              = var.instance_count
  cluster_identifier = aws_neptune_cluster.main.id
  instance_class     = var.instance_class
  engine             = "neptune"
  engine_version     = var.neptune_engine_version

  neptune_parameter_group_name = aws_neptune_parameter_group.main.name
  apply_immediately            = var.apply_immediately
  auto_minor_version_upgrade   = var.auto_minor_version_upgrade

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-neptune-instance-${count.index + 1}"
    }
  )
}

# CloudWatch Log Group for Neptune Audit Logs
resource "aws_cloudwatch_log_group" "neptune_audit" {
  count             = var.enable_cloudwatch_logs ? 1 : 0
  name              = "/aws/neptune/${var.project_name}/audit"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.cloudwatch_kms_key_arn != "" ? var.cloudwatch_kms_key_arn : null

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-neptune-audit-logs"
    }
  )
}
