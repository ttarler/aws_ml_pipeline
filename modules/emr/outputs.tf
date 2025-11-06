output "cluster_id" {
  description = "ID of the EMR cluster"
  value       = aws_emr_cluster.main.id
}

output "cluster_name" {
  description = "Name of the EMR cluster"
  value       = aws_emr_cluster.main.name
}

output "cluster_arn" {
  description = "ARN of the EMR cluster"
  value       = aws_emr_cluster.main.arn
}

output "master_public_dns" {
  description = "Public DNS of the master node"
  value       = aws_emr_cluster.main.master_public_dns
}

output "log_uri" {
  description = "S3 URI for EMR logs"
  value       = aws_emr_cluster.main.log_uri
}

output "task_instance_group_id" {
  description = "ID of the task instance group"
  value       = var.enable_task_spot_instances ? aws_emr_instance_group.task_spot[0].id : null
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.emr.name
}

output "emr_master_security_group_id" {
  description = "ID of EMR master security group"
  value       = var.emr_master_security_group_id
}

output "emr_slave_security_group_id" {
  description = "ID of EMR slave security group"
  value       = var.emr_slave_security_group_id
}

output "emr_service_security_group_id" {
  description = "ID of EMR service security group"
  value       = var.emr_service_security_group_id
}
