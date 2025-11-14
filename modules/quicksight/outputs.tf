output "s3_data_source_id" {
  description = "ID of the QuickSight S3 data source"
  value       = aws_quicksight_data_source.s3_data_source.id
}

output "s3_data_source_arn" {
  description = "ARN of the QuickSight S3 data source"
  value       = aws_quicksight_data_source.s3_data_source.arn
}

output "athena_data_source_id" {
  description = "ID of the QuickSight Athena data source (if enabled)"
  value       = var.enable_athena_integration ? aws_quicksight_data_source.athena_data_source[0].id : null
}

output "athena_data_source_arn" {
  description = "ARN of the QuickSight Athena data source (if enabled)"
  value       = var.enable_athena_integration ? aws_quicksight_data_source.athena_data_source[0].arn : null
}

output "folder_id" {
  description = "ID of the QuickSight folder for dashboards"
  value       = aws_quicksight_folder.main.folder_id
}

output "folder_arn" {
  description = "ARN of the QuickSight folder for dashboards"
  value       = aws_quicksight_folder.main.arn
}

output "data_bucket_path" {
  description = "S3 path where data should be uploaded for QuickSight visualization"
  value       = "s3://${var.quicksight_bucket_id}/data/"
}

output "manifest_file_path" {
  description = "S3 path to the manifest file for QuickSight S3 data source"
  value       = "s3://${var.quicksight_bucket_id}/manifests/default-manifest.json"
}
