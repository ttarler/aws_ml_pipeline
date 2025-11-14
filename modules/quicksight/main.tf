# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}

# Data source to get current AWS region
data "aws_region" "current" {}

# QuickSight Data Source for S3
resource "aws_quicksight_data_source" "s3_data_source" {
  data_source_id = "${var.project_name}-s3-datasource"
  name           = "${var.project_name}-s3-data"
  type           = "S3"

  parameters {
    s3 {
      manifest_file_location {
        bucket = var.quicksight_bucket_id
        key    = "manifests/default-manifest.json"
      }
    }
  }

  # Only add permissions if user ARN is provided
  dynamic "permission" {
    for_each = var.quicksight_user_arn != "" ? [1] : []
    content {
      principal = var.quicksight_user_arn
      actions = [
        "quicksight:DescribeDataSource",
        "quicksight:DescribeDataSourcePermissions",
        "quicksight:PassDataSource",
        "quicksight:UpdateDataSource",
        "quicksight:DeleteDataSource",
        "quicksight:UpdateDataSourcePermissions"
      ]
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-quicksight-s3-datasource"
    }
  )
}

# QuickSight Data Source for Athena (for querying S3 data)
resource "aws_quicksight_data_source" "athena_data_source" {
  count          = var.enable_athena_integration ? 1 : 0
  data_source_id = "${var.project_name}-athena-datasource"
  name           = "${var.project_name}-athena-data"
  type           = "ATHENA"

  parameters {
    athena {
      work_group = var.athena_workgroup
    }
  }

  # Only add permissions if user ARN is provided
  dynamic "permission" {
    for_each = var.quicksight_user_arn != "" ? [1] : []
    content {
      principal = var.quicksight_user_arn
      actions = [
        "quicksight:DescribeDataSource",
        "quicksight:DescribeDataSourcePermissions",
        "quicksight:PassDataSource",
        "quicksight:UpdateDataSource",
        "quicksight:DeleteDataSource",
        "quicksight:UpdateDataSourcePermissions"
      ]
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-quicksight-athena-datasource"
    }
  )
}

# QuickSight Folder for organizing dashboards
resource "aws_quicksight_folder" "main" {
  folder_id   = "${var.project_name}-dashboards"
  name        = "${var.project_name} Dashboards"
  folder_type = "SHARED"

  # Only add permissions if user ARN is provided
  dynamic "permissions" {
    for_each = var.quicksight_user_arn != "" ? [1] : []
    content {
      principal = var.quicksight_user_arn
      actions = [
        "quicksight:CreateFolder",
        "quicksight:DescribeFolder",
        "quicksight:UpdateFolder",
        "quicksight:DeleteFolder",
        "quicksight:CreateFolderMembership",
        "quicksight:DeleteFolderMembership",
        "quicksight:DescribeFolderPermissions",
        "quicksight:UpdateFolderPermissions"
      ]
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-quicksight-folder"
    }
  )
}

# Sample manifest file for S3 data source
resource "aws_s3_object" "sample_manifest" {
  bucket = var.quicksight_bucket_id
  key    = "manifests/default-manifest.json"
  content = jsonencode({
    fileLocations = [
      {
        URIPrefixes = [
          "s3://${var.quicksight_bucket_id}/data/"
        ]
      }
    ]
    globalUploadSettings = {
      format         = "CSV"
      delimiter      = ","
      textqualifier  = "\""
      containsHeader = "true"
    }
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-quicksight-manifest"
    }
  )
}

# Sample README file in the data folder
resource "aws_s3_object" "data_readme" {
  bucket  = var.quicksight_bucket_id
  key     = "data/README.txt"
  content = <<-EOT
    QuickSight Data Bucket

    This bucket is used for storing data that will be visualized in Amazon QuickSight.

    Folder Structure:
    - data/: Store your CSV, JSON, or Parquet files here
    - manifests/: QuickSight manifest files for S3 data sources
    - exports/: QuickSight dashboard exports and analysis exports

    Integration with SageMaker:
    - Upload processed data from SageMaker to the data/ folder
    - Update the manifest file to include new data sources
    - Refresh QuickSight datasets to see the latest data

    Supported File Formats:
    - CSV (with headers)
    - JSON
    - Parquet
    - TSV

    For more information, see the QuickSight documentation.
  EOT

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-quicksight-readme"
    }
  )
}
