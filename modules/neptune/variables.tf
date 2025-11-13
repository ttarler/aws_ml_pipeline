variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for Neptune"
  type        = list(string)
}

variable "neptune_security_group_id" {
  description = "Security group ID for Neptune"
  type        = string
}

variable "neptune_engine_version" {
  description = "Neptune engine version (format: neptune1.x) - GovCloud supports 1.0, 1.1, 1.2"
  type        = string
  default     = "1.2.1.0"
}

variable "instance_class" {
  description = "Instance class for Neptune (e.g., db.r5.large)"
  type        = string
  default     = "db.r5.large"
}

variable "instance_count" {
  description = "Number of Neptune instances to create"
  type        = number
  default     = 1
}

variable "backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "preferred_backup_window" {
  description = "Preferred backup window"
  type        = string
  default     = "03:00-04:00"
}

variable "preferred_maintenance_window" {
  description = "Preferred maintenance window"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on deletion"
  type        = bool
  default     = false
}

variable "apply_immediately" {
  description = "Apply changes immediately"
  type        = bool
  default     = false
}

variable "auto_minor_version_upgrade" {
  description = "Enable auto minor version upgrades"
  type        = bool
  default     = true
}

variable "iam_database_authentication_enabled" {
  description = "Enable IAM database authentication"
  type        = bool
  default     = true
}

variable "enable_audit_log" {
  description = "Enable audit logging"
  type        = bool
  default     = true
}

variable "query_timeout" {
  description = "Query timeout in milliseconds"
  type        = number
  default     = 120000
}

variable "enable_cloudwatch_logs" {
  description = "Enable CloudWatch logs for audit"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption (optional)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
