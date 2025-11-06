output "cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.main.id
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecr_repository_urls" {
  description = "URLs of ECR repositories"
  value       = aws_ecr_repository.main[*].repository_url
}

output "ecr_repository_arns" {
  description = "ARNs of ECR repositories"
  value       = aws_ecr_repository.main[*].arn
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.ecs.name
}

output "task_definition_arn" {
  description = "ARN of the sample task definition"
  value       = var.create_sample_task ? aws_ecs_task_definition.ml_workload[0].arn : null
}

output "service_name" {
  description = "Name of the ECS service"
  value       = var.create_sample_service ? aws_ecs_service.ml_workload[0].name : null
}

output "events_role_arn" {
  description = "ARN of the CloudWatch Events role"
  value       = var.enable_scheduled_tasks && var.events_role_arn == "" ? aws_iam_role.events[0].arn : var.events_role_arn
}
