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

output "accelerated_compute_space_name" {
  description = "Name of the accelerated compute GPU space template (accelerated-compute-gpu-template) with R, Spark, and Neptune kernels"
  value       = var.create_space_templates ? aws_sagemaker_space.accelerated_compute_template[0].space_name : null
}

output "lifecycle_config_name" {
  description = "Name of the lifecycle config that installs R, Spark, and Neptune kernels"
  value       = aws_sagemaker_studio_lifecycle_config.r_and_spark_setup.studio_lifecycle_config_name
}

output "general_purpose_instance_types" {
  description = "List of general purpose CPU instance types for spaces"
  value       = local.general_purpose_instances
}

output "accelerated_compute_instance_types" {
  description = "List of accelerated compute (GPU) instance types for spaces"
  value       = local.accelerated_compute_instances
}
