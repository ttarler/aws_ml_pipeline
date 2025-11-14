variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
}

variable "quicksight_bucket_id" {
  description = "ID of the QuickSight S3 bucket"
  type        = string
}

variable "quicksight_bucket_arn" {
  description = "ARN of the QuickSight S3 bucket"
  type        = string
}

variable "quicksight_user_arn" {
  description = "ARN of the QuickSight user (format: arn:aws:quicksight:region:account-id:user/namespace/username)"
  type        = string
  default     = ""
}

variable "enable_athena_integration" {
  description = "Enable Athena integration for querying S3 data"
  type        = bool
  default     = false
}

variable "athena_workgroup" {
  description = "Athena workgroup name for QuickSight queries"
  type        = string
  default     = "primary"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
