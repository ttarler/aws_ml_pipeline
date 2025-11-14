output "domain_id" {
  description = "ID of the SageMaker domain"
  value       = aws_sagemaker_domain.main.id
}

output "domain_arn" {
  description = "ARN of the SageMaker domain"
  value       = aws_sagemaker_domain.main.arn
}

output "domain_url" {
  description = "URL of the SageMaker domain"
  value       = aws_sagemaker_domain.main.url
}

output "user_profile_arn" {
  description = "ARN of the default user profile"
  value       = aws_sagemaker_user_profile.default.arn
}

output "notebook_instance_name" {
  description = "Name of the notebook instance"
  value       = var.create_notebook_instance ? aws_sagemaker_notebook_instance.emr_connector[0].name : null
}

output "notebook_instance_url" {
  description = "URL of the notebook instance"
  value       = var.create_notebook_instance ? aws_sagemaker_notebook_instance.emr_connector[0].url : null
}

output "model_package_group_name" {
  description = "Name of the model package group"
  value       = aws_sagemaker_model_package_group.models.model_package_group_name
}

output "model_package_group_arn" {
  description = "ARN of the model package group"
  value       = aws_sagemaker_model_package_group.models.arn
}

output "feature_group_name" {
  description = "Name of the feature group"
  value       = var.enable_feature_store ? aws_sagemaker_feature_group.ml_features[0].feature_group_name : null
}

output "govcloud_compatible_instance_types" {
  description = "List of SageMaker instance types commonly available in AWS GovCloud"
  value       = local.govcloud_compatible_notebook_types
}

output "general_purpose_space_name" {
  description = "Name of the general purpose CPU space template (general-purpose-cpu-template) with R, Spark, and Neptune kernels"
  value       = var.create_space_templates ? aws_sagemaker_space.general_purpose_template[0].space_name : null
}

output "lifecycle_config_name" {
  description = "Name of the lifecycle config that installs R, Spark, and Neptune kernels"
  value       = aws_sagemaker_studio_lifecycle_config.r_and_spark_setup.studio_lifecycle_config_name
}

output "lifecycle_config_r_spark_arn" {
  description = "ARN of the R and Spark lifecycle configuration"
  value       = aws_sagemaker_studio_lifecycle_config.r_and_spark_setup.arn
}

output "lifecycle_config_python_barebones_name" {
  description = "Name of the barebones Python kernel lifecycle config"
  value       = aws_sagemaker_studio_lifecycle_config.python_barebones.studio_lifecycle_config_name
}

output "lifecycle_config_python_barebones_arn" {
  description = "ARN of the barebones Python kernel lifecycle configuration"
  value       = aws_sagemaker_studio_lifecycle_config.python_barebones.arn
}

output "general_purpose_instance_types" {
  description = "List of general purpose CPU instance types for spaces"
  value       = local.general_purpose_instances
}

# ECR Repository Outputs
output "ecr_datascience_r_repository_url" {
  description = "URL of the ECR repository for SageMaker Data Science R image"
  value       = aws_ecr_repository.sagemaker_datascience.repository_url
}

output "ecr_distribution_cpu_repository_url" {
  description = "URL of the ECR repository for SageMaker Distribution CPU image"
  value       = aws_ecr_repository.sagemaker_distribution_cpu.repository_url
}

# SageMaker Image Outputs
output "sagemaker_datascience_image_arn" {
  description = "ARN of the SageMaker Data Science R image"
  value       = aws_sagemaker_image.datascience_r.arn
}

output "sagemaker_distribution_cpu_image_arn" {
  description = "ARN of the SageMaker Distribution CPU image"
  value       = aws_sagemaker_image.distribution_cpu.arn
}
