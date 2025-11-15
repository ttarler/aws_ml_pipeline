variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "emr_release_label" {
  description = "EMR release label"
  type        = string
  default     = "emr-7.10.0"
}

variable "emr_applications" {
  description = "List of EMR applications to install"
  type        = list(string)
  default     = ["Hadoop", "Spark", "Livy", "Hive", "JupyterHub", "JupyterEnterpriseGateway"]
}

variable "subnet_ids" {
  description = "List of subnet IDs for EMR"
  type        = list(string)
}

variable "emr_master_security_group_id" {
  description = "Security group ID for EMR master"
  type        = string
}

variable "emr_slave_security_group_id" {
  description = "Security group ID for EMR slaves"
  type        = string
}

variable "emr_service_security_group_id" {
  description = "Security group ID for EMR service"
  type        = string
}

variable "emr_service_role_arn" {
  description = "ARN of EMR service role"
  type        = string
}

variable "emr_ec2_instance_profile_name" {
  description = "Name of EMR EC2 instance profile"
  type        = string
}

variable "emr_autoscaling_role_arn" {
  description = "ARN of EMR autoscaling role"
  type        = string
  default     = ""
}

variable "emr_logs_bucket_id" {
  description = "ID of S3 bucket for EMR logs"
  type        = string
}

variable "bootstrap_scripts_bucket" {
  description = "S3 bucket for bootstrap scripts"
  type        = string
}

variable "create_bootstrap_script" {
  description = "Whether to create a default bootstrap script"
  type        = bool
  default     = true
}

variable "ec2_key_name" {
  description = "EC2 key pair name for SSH access to EMR cluster"
  type        = string
  default     = ""
}

# Master node configuration
variable "master_instance_type" {
  description = "Instance type for master node"
  type        = string
  default     = "m5.xlarge"
}

variable "master_ebs_size" {
  description = "EBS volume size for master node (GB)"
  type        = number
  default     = 100
}

# Core node configuration
variable "core_instance_type" {
  description = "Instance type for core nodes"
  type        = string
  default     = "m5.xlarge"
}

variable "core_instance_count" {
  description = "Number of core instances"
  type        = number
  default     = 2
}

variable "core_ebs_size" {
  description = "EBS volume size for core nodes (GB)"
  type        = number
  default     = 100
}

variable "core_use_spot" {
  description = "Whether to use spot instances for core nodes"
  type        = bool
  default     = false
}

variable "core_spot_bid_price" {
  description = "Bid price for core spot instances"
  type        = string
  default     = ""
}

# Task node configuration (spot instances)
variable "enable_task_spot_instances" {
  description = "Whether to enable task spot instances"
  type        = bool
  default     = true
}

variable "task_instance_type" {
  description = "Instance type for task nodes"
  type        = string
  default     = "m5.xlarge"
}

variable "task_instance_count" {
  description = "Initial number of task instances"
  type        = number
  default     = 2
}

variable "task_ebs_size" {
  description = "EBS volume size for task nodes (GB)"
  type        = number
  default     = 100
}

variable "task_spot_bid_price" {
  description = "Bid price for task spot instances"
  type        = string
  default     = "0.15"
}

variable "task_min_capacity" {
  description = "Minimum capacity for task instance group"
  type        = number
  default     = 1
}

variable "task_max_capacity" {
  description = "Maximum capacity for task instance group"
  type        = number
  default     = 10
}

# Managed scaling configuration
variable "enable_managed_scaling" {
  description = "Whether to enable EMR managed scaling"
  type        = bool
  default     = false
}

variable "managed_scaling_min_capacity" {
  description = "Minimum capacity for managed scaling"
  type        = number
  default     = 2
}

variable "managed_scaling_max_capacity" {
  description = "Maximum capacity for managed scaling"
  type        = number
  default     = 10
}

variable "managed_scaling_max_ondemand" {
  description = "Maximum on-demand capacity for managed scaling"
  type        = number
  default     = 2
}

variable "cloudwatch_kms_key_arn" {
  description = "ARN of KMS key for CloudWatch Logs encryption"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
