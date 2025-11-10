output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "private_route_table_id" {
  description = "ID of private route table"
  value       = aws_route_table.private.id
}

output "sagemaker_security_group_id" {
  description = "ID of SageMaker security group"
  value       = aws_security_group.sagemaker.id
}

output "emr_master_security_group_id" {
  description = "ID of EMR master security group"
  value       = aws_security_group.emr_master.id
}

output "emr_slave_security_group_id" {
  description = "ID of EMR slave security group"
  value       = aws_security_group.emr_slave.id
}

output "emr_service_security_group_id" {
  description = "ID of EMR service security group"
  value       = aws_security_group.emr_service.id
}

output "ecs_security_group_id" {
  description = "ID of ECS security group"
  value       = aws_security_group.ecs.id
}

output "vpc_endpoints_security_group_id" {
  description = "ID of VPC endpoints security group"
  value       = aws_security_group.vpc_endpoints.id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "bastion_public_ip" {
  description = "Public IP of bastion host"
  value       = var.enable_bastion ? aws_instance.bastion[0].public_ip : null
}

output "bastion_instance_id" {
  description = "Instance ID of bastion host"
  value       = var.enable_bastion ? aws_instance.bastion[0].id : null
}

output "bastion_security_group_id" {
  description = "Security group ID of bastion host"
  value       = var.enable_bastion ? aws_security_group.bastion[0].id : null
}
