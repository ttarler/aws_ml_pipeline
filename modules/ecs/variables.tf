variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for ECS tasks"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for ECS tasks"
  type        = string
}

variable "task_execution_role_arn" {
  description = "ARN of ECS task execution role"
  type        = string
}

variable "task_role_arn" {
  description = "ARN of ECS task role"
  type        = string
}

variable "landing_zone_bucket_id" {
  description = "ID of the landing zone S3 bucket"
  type        = string
}

variable "ecr_repositories" {
  description = "List of ECR repository names to create"
  type        = list(string)
  default     = ["ml-workload", "data-processing", "model-serving"]
}

variable "create_sample_task" {
  description = "Whether to create a sample ECS task definition"
  type        = bool
  default     = false
}

variable "create_sample_service" {
  description = "Whether to create a sample ECS service"
  type        = bool
  default     = false
}

variable "task_cpu" {
  description = "CPU units for ECS task"
  type        = string
  default     = "1024"
}

variable "task_memory" {
  description = "Memory for ECS task (MiB)"
  type        = string
  default     = "2048"
}

variable "service_desired_count" {
  description = "Desired count for ECS service"
  type        = number
  default     = 1
}

variable "gitlab_url" {
  description = "GitLab URL for CI/CD integration"
  type        = string
  default     = "https://gitlab.com"
}

variable "enable_scheduled_tasks" {
  description = "Whether to enable scheduled ECS tasks"
  type        = bool
  default     = false
}

variable "schedule_expression" {
  description = "CloudWatch Events schedule expression"
  type        = string
  default     = "rate(1 hour)"
}

variable "scheduled_task_definition_arn" {
  description = "ARN of task definition for scheduled tasks"
  type        = string
  default     = ""
}

variable "events_role_arn" {
  description = "ARN of IAM role for CloudWatch Events"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
