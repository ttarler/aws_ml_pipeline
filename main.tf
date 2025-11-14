terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment and configure for remote state storage
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "govcloud-ml-platform/terraform.tfstate"
  #   region         = "us-gov-west-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

provider "aws" {
  region = var.aws_region

  # Uncomment for AWS GovCloud
  # endpoints {
  #   sts = "https://sts.us-gov-west-1.amazonaws.com"
  #   s3  = "https://s3.us-gov-west-1.amazonaws.com"
  # }

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Get available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# Networking Module
module "networking" {
  source = "./modules/networking"

  project_name          = var.project_name
  vpc_cidr              = var.vpc_cidr
  private_subnet_cidrs  = var.private_subnet_cidrs
  public_subnet_cidrs   = var.public_subnet_cidrs
  availability_zones    = slice(data.aws_availability_zones.available.names, 0, max(length(var.private_subnet_cidrs), length(var.public_subnet_cidrs)))
  aws_region            = var.aws_region
  enable_bastion        = var.enable_bastion
  bastion_instance_type = var.bastion_instance_type
  bastion_key_name      = var.bastion_key_name
  enable_nat_gateway    = var.enable_nat_gateway
  custom_dns_servers    = var.custom_dns_servers

  tags = var.tags
}

# S3 Module
module "s3" {
  source = "./modules/s3"

  project_name = var.project_name
  account_id   = data.aws_caller_identity.current.account_id
  environment  = var.environment

  tags = var.tags
}

# IAM Module
module "iam" {
  source = "./modules/iam"

  project_name        = var.project_name
  aws_region          = var.aws_region
  account_id          = data.aws_caller_identity.current.account_id
  partition           = var.aws_partition
  s3_landing_zone_arn = module.s3.landing_zone_bucket_arn
  s3_sagemaker_arn    = module.s3.sagemaker_bucket_arn
  s3_emr_logs_arn     = module.s3.emr_logs_bucket_arn
  s3_quicksight_arn   = module.s3.quicksight_bucket_arn

  tags = var.tags
}

# SageMaker Module
module "sagemaker" {
  source = "./modules/sagemaker"

  project_name                    = var.project_name
  environment                     = var.environment
  vpc_id                          = module.networking.vpc_id
  subnet_ids                      = module.networking.private_subnet_ids
  security_group_id               = module.networking.sagemaker_security_group_id
  execution_role_arn              = module.iam.sagemaker_execution_role_arn
  studio_user_role_arn            = module.iam.sagemaker_studio_user_role_arn
  sagemaker_bucket_id             = module.s3.sagemaker_bucket_id
  jupyter_instance_type           = var.sagemaker_jupyter_instance_type
  kernel_gateway_instance_type    = var.sagemaker_kernel_gateway_instance_type
  notebook_instance_type          = var.sagemaker_notebook_instance_type
  notebook_direct_internet_access = var.sagemaker_notebook_direct_internet_access
  create_notebook_instance        = var.sagemaker_create_notebook_instance
  enable_feature_store            = var.sagemaker_enable_feature_store
  create_space_templates          = var.sagemaker_create_space_templates
  enable_neptune_kernel           = var.enable_neptune
  neptune_endpoint                = var.enable_neptune ? module.neptune[0].cluster_endpoint : ""
  emr_master_dns                  = var.enable_emr ? module.emr[0].master_public_dns : ""

  tags = var.tags

  depends_on = [module.iam]
}

# Neptune Module
module "neptune" {
  count  = var.enable_neptune ? 1 : 0
  source = "./modules/neptune"

  project_name              = var.project_name
  subnet_ids                = module.networking.private_subnet_ids
  neptune_security_group_id = module.networking.neptune_security_group_id
  instance_class            = var.neptune_instance_class
  instance_count            = var.neptune_instance_count
  backup_retention_period   = var.neptune_backup_retention_period
  skip_final_snapshot       = var.neptune_skip_final_snapshot

  tags = var.tags

  depends_on = [module.networking]
}

# EMR Module
module "emr" {
  count  = var.enable_emr ? 1 : 0
  source = "./modules/emr"

  project_name                  = var.project_name
  environment                   = var.environment
  emr_release_label             = var.emr_release_label
  emr_applications              = var.emr_applications
  subnet_ids                    = module.networking.private_subnet_ids
  emr_master_security_group_id  = module.networking.emr_master_security_group_id
  emr_slave_security_group_id   = module.networking.emr_slave_security_group_id
  emr_service_security_group_id = module.networking.emr_service_security_group_id
  emr_service_role_arn          = module.iam.emr_service_role_arn
  emr_ec2_instance_profile_name = module.iam.emr_ec2_instance_profile_name
  emr_autoscaling_role_arn      = module.iam.emr_autoscaling_role_arn
  emr_logs_bucket_id            = module.s3.emr_logs_bucket_id
  bootstrap_scripts_bucket      = module.s3.emr_logs_bucket_id
  create_bootstrap_script       = var.emr_create_bootstrap_script
  ec2_key_name                  = var.emr_ec2_key_name
  master_instance_type          = var.emr_master_instance_type
  master_ebs_size               = var.emr_master_ebs_size
  core_instance_type            = var.emr_core_instance_type
  core_instance_count           = var.emr_core_instance_count
  core_ebs_size                 = var.emr_core_ebs_size
  core_use_spot                 = var.emr_core_use_spot
  core_spot_bid_price           = var.emr_core_spot_bid_price
  enable_task_spot_instances    = var.emr_enable_task_spot_instances
  task_instance_type            = var.emr_task_instance_type
  task_instance_count           = var.emr_task_instance_count
  task_ebs_size                 = var.emr_task_ebs_size
  task_spot_bid_price           = var.emr_task_spot_bid_price
  task_min_capacity             = var.emr_task_min_capacity
  task_max_capacity             = var.emr_task_max_capacity
  enable_managed_scaling        = var.emr_enable_managed_scaling
  managed_scaling_min_capacity  = var.emr_managed_scaling_min_capacity
  managed_scaling_max_capacity  = var.emr_managed_scaling_max_capacity
  managed_scaling_max_ondemand  = var.emr_managed_scaling_max_ondemand

  tags = var.tags

  depends_on = [module.iam, module.s3]
}

# ECS Module
module "ecs" {
  source = "./modules/ecs"

  project_name            = var.project_name
  aws_region              = var.aws_region
  subnet_ids              = module.networking.private_subnet_ids
  security_group_id       = module.networking.ecs_security_group_id
  task_execution_role_arn = module.iam.ecs_task_execution_role_arn
  task_role_arn           = module.iam.ecs_task_role_arn
  landing_zone_bucket_id  = module.s3.landing_zone_bucket_id
  ecr_repositories        = var.ecs_ecr_repositories
  create_sample_task      = var.ecs_create_sample_task
  create_sample_service   = var.ecs_create_sample_service
  task_cpu                = var.ecs_task_cpu
  task_memory             = var.ecs_task_memory
  service_desired_count   = var.ecs_service_desired_count
  enable_scheduled_tasks  = var.ecs_enable_scheduled_tasks
  schedule_expression     = var.ecs_schedule_expression

  tags = var.tags

  depends_on = [module.iam]
}

# CodeCommit Module with Checkov Security Scanning
module "codecommit" {
  source = "./modules/codecommit"

  project_name         = var.project_name
  environment          = var.environment
  aws_region           = var.aws_region
  aws_partition        = var.aws_partition
  account_id           = var.account_id
  artifacts_bucket_arn = module.s3.ecs_artifacts_bucket_arn
  enable_auto_checkov  = var.codecommit_enable_auto_checkov

  tags = var.tags

  depends_on = [module.s3]
}

# QuickSight Module
module "quicksight" {
  count  = var.enable_quicksight ? 1 : 0
  source = "./modules/quicksight"

  project_name              = var.project_name
  aws_region                = var.aws_region
  account_id                = data.aws_caller_identity.current.account_id
  quicksight_bucket_id      = module.s3.quicksight_bucket_id
  quicksight_bucket_arn     = module.s3.quicksight_bucket_arn
  quicksight_user_arn       = var.quicksight_user_arn
  enable_athena_integration = var.quicksight_enable_athena
  athena_workgroup          = var.quicksight_athena_workgroup

  tags = var.tags

  depends_on = [module.s3, module.iam]
}
