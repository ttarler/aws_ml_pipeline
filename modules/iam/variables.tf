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

variable "partition" {
  description = "AWS partition (aws or aws-us-gov)"
  type        = string
  default     = "aws-us-gov"
}

variable "s3_landing_zone_arn" {
  description = "ARN of the S3 landing zone bucket"
  type        = string
}

variable "s3_sagemaker_arn" {
  description = "ARN of the S3 SageMaker bucket"
  type        = string
}

variable "s3_emr_logs_arn" {
  description = "ARN of the S3 EMR logs bucket"
  type        = string
}

variable "s3_quicksight_arn" {
  description = "ARN of the S3 QuickSight bucket"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
