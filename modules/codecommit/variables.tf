variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "aws_partition" {
  description = "AWS partition (aws or aws-us-gov)"
  type        = string
  default     = "aws-us-gov"
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
}

variable "artifacts_bucket_arn" {
  description = "ARN of the S3 bucket for build artifacts"
  type        = string
}

variable "enable_auto_checkov" {
  description = "Enable automatic Checkov scanning on push to main branch"
  type        = bool
  default     = true
}

variable "cloudwatch_kms_key_arn" {
  description = "ARN of KMS key for CloudWatch Logs encryption"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
