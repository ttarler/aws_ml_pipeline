# General Variables
variable "project_name" {
  description = "Name of the project (used for resource naming)"
  type        = string
  default     = "govcloud-ml-platform"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region (use us-gov-west-1 or us-gov-east-1 for GovCloud)"
  type        = string
  default     = "us-gov-west-1"
}

variable "aws_partition" {
  description = "AWS partition (aws or aws-us-gov)"
  type        = string
  default     = "aws-us-gov"
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Networking Variables
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (for bastion host)"
  type        = list(string)
  default     = ["10.0.101.0/24"]
}

variable "enable_bastion" {
  description = "Whether to create a bastion host for SSH access to EMR"
  type        = bool
  default     = false
}

variable "bastion_instance_type" {
  description = "Instance type for bastion host"
  type        = string
  default     = "t3.micro"
}

variable "bastion_key_name" {
  description = "EC2 key pair name for bastion host (required if enable_bastion is true)"
  type        = string
  default     = ""
}

variable "enable_nat_gateway" {
  description = "Whether to create a NAT Gateway for private subnet internet access (required for EMR bootstrap to reach external/internal repositories)"
  type        = bool
  default     = true
}

variable "custom_dns_servers" {
  description = "List of custom DNS server IPs for VPC DHCP options"
  type        = list(string)
  default     = []
}

# SageMaker Variables
variable "sagemaker_jupyter_instance_type" {
  description = "Instance type for SageMaker Jupyter Server"
  type        = string
  default     = "system"
}

variable "sagemaker_kernel_gateway_instance_type" {
  description = "Instance type for SageMaker Kernel Gateway"
  type        = string
  default     = "ml.m5.large"
}

variable "sagemaker_notebook_instance_type" {
  description = "Instance type for SageMaker Notebook (common GovCloud types: ml.m5.large, ml.m5.xlarge, ml.m5.2xlarge)"
  type        = string
  default     = "ml.m5.large"
}

variable "sagemaker_create_notebook_instance" {
  description = "Whether to create a SageMaker Notebook instance for EMR connectivity"
  type        = bool
  default     = false
}

variable "sagemaker_enable_feature_store" {
  description = "Whether to enable SageMaker Feature Store"
  type        = bool
  default     = false
}

# EMR Variables
variable "enable_emr" {
  description = "Whether to create EMR cluster"
  type        = bool
  default     = true
}

variable "emr_release_label" {
  description = "EMR release label (e.g., emr-7.10.0)"
  type        = string
  default     = "emr-7.10.0"
}

variable "emr_applications" {
  description = "List of EMR applications to install"
  type        = list(string)
  default     = ["Hadoop", "Spark", "Livy", "Hive", "JupyterHub", "JupyterEnterpriseGateway"]
}

variable "emr_create_bootstrap_script" {
  description = "Whether to create a default bootstrap script"
  type        = bool
  default     = true
}

variable "emr_ec2_key_name" {
  description = "EC2 key pair name for SSH access to EMR cluster (leave empty for no SSH access)"
  type        = string
  default     = ""
}

variable "emr_master_instance_type" {
  description = "Instance type for EMR master node"
  type        = string
  default     = "m5.xlarge"
}

variable "emr_master_ebs_size" {
  description = "EBS volume size for EMR master node (GB)"
  type        = number
  default     = 100
}

variable "emr_core_instance_type" {
  description = "Instance type for EMR core nodes"
  type        = string
  default     = "m5.xlarge"
}

variable "emr_core_instance_count" {
  description = "Number of EMR core instances"
  type        = number
  default     = 2
}

variable "emr_core_ebs_size" {
  description = "EBS volume size for EMR core nodes (GB)"
  type        = number
  default     = 100
}

variable "emr_core_use_spot" {
  description = "Whether to use spot instances for EMR core nodes"
  type        = bool
  default     = false
}

variable "emr_core_spot_bid_price" {
  description = "Bid price for EMR core spot instances"
  type        = string
  default     = ""
}

variable "emr_enable_task_spot_instances" {
  description = "Whether to enable EMR task spot instances"
  type        = bool
  default     = true
}

variable "emr_task_instance_type" {
  description = "Instance type for EMR task nodes"
  type        = string
  default     = "m5.xlarge"
}

variable "emr_task_instance_count" {
  description = "Initial number of EMR task instances"
  type        = number
  default     = 2
}

variable "emr_task_ebs_size" {
  description = "EBS volume size for EMR task nodes (GB)"
  type        = number
  default     = 100
}

variable "emr_task_spot_bid_price" {
  description = "Bid price for EMR task spot instances"
  type        = string
  default     = "0.15"
}

variable "emr_task_min_capacity" {
  description = "Minimum capacity for EMR task instance group"
  type        = number
  default     = 1
}

variable "emr_task_max_capacity" {
  description = "Maximum capacity for EMR task instance group"
  type        = number
  default     = 10
}

variable "emr_enable_managed_scaling" {
  description = "Whether to enable EMR managed scaling"
  type        = bool
  default     = false
}

variable "emr_managed_scaling_min_capacity" {
  description = "Minimum capacity for EMR managed scaling"
  type        = number
  default     = 2
}

variable "emr_managed_scaling_max_capacity" {
  description = "Maximum capacity for EMR managed scaling"
  type        = number
  default     = 10
}

variable "emr_managed_scaling_max_ondemand" {
  description = "Maximum on-demand capacity for EMR managed scaling"
  type        = number
  default     = 2
}

# ECS Variables
variable "ecs_ecr_repositories" {
  description = "List of ECR repository names to create"
  type        = list(string)
  default     = ["ml-workload", "data-processing", "model-serving"]
}

variable "ecs_create_sample_task" {
  description = "Whether to create a sample ECS task definition"
  type        = bool
  default     = false
}

variable "ecs_create_sample_service" {
  description = "Whether to create a sample ECS service"
  type        = bool
  default     = false
}

variable "ecs_task_cpu" {
  description = "CPU units for ECS task (256, 512, 1024, 2048, 4096)"
  type        = string
  default     = "1024"
}

variable "ecs_task_memory" {
  description = "Memory for ECS task in MiB (512, 1024, 2048, 4096, 8192, etc.)"
  type        = string
  default     = "2048"
}

variable "ecs_service_desired_count" {
  description = "Desired count for ECS service"
  type        = number
  default     = 1
}

variable "ecs_enable_scheduled_tasks" {
  description = "Whether to enable scheduled ECS tasks"
  type        = bool
  default     = false
}

variable "ecs_schedule_expression" {
  description = "CloudWatch Events schedule expression (e.g., rate(1 hour), cron(0 12 * * ? *))"
  type        = string
  default     = "rate(1 hour)"
}
