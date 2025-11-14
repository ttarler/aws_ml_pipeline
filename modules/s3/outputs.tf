output "landing_zone_bucket_id" {
  description = "ID of the landing zone S3 bucket"
  value       = aws_s3_bucket.landing_zone.id
}

output "landing_zone_bucket_arn" {
  description = "ARN of the landing zone S3 bucket"
  value       = aws_s3_bucket.landing_zone.arn
}

output "sagemaker_bucket_id" {
  description = "ID of the SageMaker S3 bucket"
  value       = aws_s3_bucket.sagemaker.id
}

output "sagemaker_bucket_arn" {
  description = "ARN of the SageMaker S3 bucket"
  value       = aws_s3_bucket.sagemaker.arn
}

output "emr_logs_bucket_id" {
  description = "ID of the EMR logs S3 bucket"
  value       = aws_s3_bucket.emr_logs.id
}

output "emr_logs_bucket_arn" {
  description = "ARN of the EMR logs S3 bucket"
  value       = aws_s3_bucket.emr_logs.arn
}

output "ecs_artifacts_bucket_id" {
  description = "ID of the ECS artifacts S3 bucket"
  value       = aws_s3_bucket.ecs_artifacts.id
}

output "ecs_artifacts_bucket_arn" {
  description = "ARN of the ECS artifacts S3 bucket"
  value       = aws_s3_bucket.ecs_artifacts.arn
}
