variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for SageMaker"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for SageMaker"
  type        = string
}

variable "execution_role_arn" {
  description = "ARN of SageMaker execution role"
  type        = string
}

variable "studio_user_role_arn" {
  description = "ARN of SageMaker Studio user role"
  type        = string
}

variable "sagemaker_bucket_id" {
  description = "ID of the SageMaker S3 bucket"
  type        = string
}

variable "jupyter_instance_type" {
  description = "Instance type for Jupyter Server"
  type        = string
  default     = "system"
}

variable "kernel_gateway_instance_type" {
  description = "Instance type for Kernel Gateway"
  type        = string
  default     = "ml.t3.medium"
}

variable "notebook_instance_type" {
  description = "Instance type for SageMaker Notebook"
  type        = string
  default     = "ml.t3.medium"
}

variable "create_notebook_instance" {
  description = "Whether to create a SageMaker Notebook instance"
  type        = bool
  default     = false
}

variable "enable_feature_store" {
  description = "Whether to enable SageMaker Feature Store"
  type        = bool
  default     = false
}

variable "emr_master_dns" {
  description = "DNS name of EMR master node"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
