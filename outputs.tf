# Networking Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = module.networking.private_subnet_ids
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.networking.public_subnet_ids
}

output "bastion_public_ip" {
  description = "Public IP of bastion host (if enabled)"
  value       = module.networking.bastion_public_ip
}

output "bastion_instance_id" {
  description = "Instance ID of bastion host (if enabled)"
  value       = module.networking.bastion_instance_id
}

# S3 Outputs
output "landing_zone_bucket_name" {
  description = "Name of the landing zone S3 bucket"
  value       = module.s3.landing_zone_bucket_id
}

output "sagemaker_bucket_name" {
  description = "Name of the SageMaker S3 bucket"
  value       = module.s3.sagemaker_bucket_id
}

output "emr_logs_bucket_name" {
  description = "Name of the EMR logs S3 bucket"
  value       = module.s3.emr_logs_bucket_id
}

output "ecs_artifacts_bucket_name" {
  description = "Name of the ECS artifacts S3 bucket"
  value       = module.s3.ecs_artifacts_bucket_id
}

# IAM Outputs
output "sagemaker_execution_role_arn" {
  description = "ARN of SageMaker execution role"
  value       = module.iam.sagemaker_execution_role_arn
}

output "emr_service_role_arn" {
  description = "ARN of EMR service role"
  value       = module.iam.emr_service_role_arn
}

output "ecs_task_execution_role_arn" {
  description = "ARN of ECS task execution role"
  value       = module.iam.ecs_task_execution_role_arn
}

# SageMaker Outputs
output "sagemaker_domain_id" {
  description = "ID of the SageMaker domain"
  value       = module.sagemaker.domain_id
}

output "sagemaker_domain_url" {
  description = "URL of the SageMaker domain"
  value       = module.sagemaker.domain_url
}

output "sagemaker_user_profile_arn" {
  description = "ARN of the default SageMaker user profile"
  value       = module.sagemaker.user_profile_arn
}

output "sagemaker_notebook_instance_url" {
  description = "URL of the SageMaker notebook instance (if created)"
  value       = module.sagemaker.notebook_instance_url
}

output "sagemaker_model_registry_name" {
  description = "Name of the SageMaker model package group"
  value       = module.sagemaker.model_package_group_name
}

# EMR Outputs
output "emr_cluster_id" {
  description = "ID of the EMR cluster (if created)"
  value       = var.enable_emr ? module.emr[0].cluster_id : null
}

output "emr_cluster_name" {
  description = "Name of the EMR cluster (if created)"
  value       = var.enable_emr ? module.emr[0].cluster_name : null
}

output "emr_master_dns" {
  description = "Public DNS of the EMR master node (if created)"
  value       = var.enable_emr ? module.emr[0].master_public_dns : null
}

output "emr_master_public_dns" {
  description = "Public DNS of the EMR master node (if created) - alias for emr_master_dns"
  value       = var.enable_emr ? module.emr[0].master_public_dns : null
}

output "emr_log_uri" {
  description = "S3 URI for EMR logs (if created)"
  value       = var.enable_emr ? module.emr[0].log_uri : null
}

# ECS Outputs
output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = module.ecs.cluster_arn
}

output "ecr_repository_urls" {
  description = "URLs of ECR repositories"
  value       = module.ecs.ecr_repository_urls
}

# Connection Information
output "connection_info" {
  description = "Connection information for accessing the platform"
  value = {
    sagemaker_studio_url = module.sagemaker.domain_url
    emr_master_dns       = var.enable_emr ? module.emr[0].master_public_dns : "EMR not enabled"
    bastion_public_ip    = var.enable_bastion ? module.networking.bastion_public_ip : "Bastion not enabled"
    ecs_cluster          = module.ecs.cluster_name
    landing_zone_bucket  = module.s3.landing_zone_bucket_id
  }
}

# Instructions
output "next_steps" {
  description = "Next steps for using the infrastructure"
  value = <<-EOT
    Infrastructure deployed successfully!

    Next Steps:
    1. Access SageMaker Studio at: ${module.sagemaker.domain_url}
    2. Upload data to the landing zone bucket: s3://${module.s3.landing_zone_bucket_id}/
    ${var.enable_emr && var.enable_bastion ? "3. SSH to EMR via bastion:\n       ssh -i bastion-key.pem ec2-user@${module.networking.bastion_public_ip}\n       ssh -i emr-key.pem hadoop@${module.emr[0].master_public_dns}" : var.enable_emr ? "3. Connect to EMR cluster: ${module.emr[0].cluster_id} (bastion not enabled)" : "3. EMR cluster not enabled"}
    4. Push Docker images to ECR repositories: ${join(", ", module.ecs.ecr_repository_urls)}

    For more information, see the README.md file.
  EOT
}
