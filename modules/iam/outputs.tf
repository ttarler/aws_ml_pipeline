output "sagemaker_execution_role_arn" {
  description = "ARN of SageMaker execution role"
  value       = aws_iam_role.sagemaker_execution.arn
}

output "sagemaker_studio_user_role_arn" {
  description = "ARN of SageMaker Studio user role"
  value       = aws_iam_role.sagemaker_studio_user.arn
}

output "emr_service_role_arn" {
  description = "ARN of EMR service role"
  value       = aws_iam_role.emr_service.arn
}

output "emr_ec2_role_arn" {
  description = "ARN of EMR EC2 role"
  value       = aws_iam_role.emr_ec2.arn
}

output "emr_ec2_instance_profile_name" {
  description = "Name of EMR EC2 instance profile"
  value       = aws_iam_instance_profile.emr_ec2.name
}

output "emr_ec2_instance_profile_arn" {
  description = "ARN of EMR EC2 instance profile"
  value       = aws_iam_instance_profile.emr_ec2.arn
}

output "emr_autoscaling_role_arn" {
  description = "ARN of EMR autoscaling role"
  value       = aws_iam_role.emr_autoscaling.arn
}

output "ecs_task_execution_role_arn" {
  description = "ARN of ECS task execution role"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_role_arn" {
  description = "ARN of ECS task role"
  value       = aws_iam_role.ecs_task.arn
}
