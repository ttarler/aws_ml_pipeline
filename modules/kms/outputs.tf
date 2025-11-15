output "cloudwatch_logs_key_id" {
  description = "ID of the CloudWatch Logs KMS key"
  value       = aws_kms_key.cloudwatch_logs.id
}

output "cloudwatch_logs_key_arn" {
  description = "ARN of the CloudWatch Logs KMS key"
  value       = aws_kms_key.cloudwatch_logs.arn
}

output "s3_key_id" {
  description = "ID of the S3 KMS key"
  value       = aws_kms_key.s3.id
}

output "s3_key_arn" {
  description = "ARN of the S3 KMS key"
  value       = aws_kms_key.s3.arn
}

output "ecr_key_id" {
  description = "ID of the ECR KMS key"
  value       = aws_kms_key.ecr.id
}

output "ecr_key_arn" {
  description = "ARN of the ECR KMS key"
  value       = aws_kms_key.ecr.arn
}

output "sagemaker_key_id" {
  description = "ID of the SageMaker KMS key"
  value       = aws_kms_key.sagemaker.id
}

output "sagemaker_key_arn" {
  description = "ARN of the SageMaker KMS key"
  value       = aws_kms_key.sagemaker.arn
}

output "neptune_key_id" {
  description = "ID of the Neptune KMS key"
  value       = aws_kms_key.neptune.id
}

output "neptune_key_arn" {
  description = "ARN of the Neptune KMS key"
  value       = aws_kms_key.neptune.arn
}

output "ecs_key_id" {
  description = "ID of the ECS KMS key"
  value       = aws_kms_key.ecs.id
}

output "ecs_key_arn" {
  description = "ARN of the ECS KMS key"
  value       = aws_kms_key.ecs.arn
}
