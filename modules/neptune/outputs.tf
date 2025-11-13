output "cluster_id" {
  description = "The Neptune cluster identifier"
  value       = aws_neptune_cluster.main.id
}

output "cluster_arn" {
  description = "The Neptune cluster ARN"
  value       = aws_neptune_cluster.main.arn
}

output "cluster_endpoint" {
  description = "The Neptune cluster endpoint"
  value       = aws_neptune_cluster.main.endpoint
}

output "cluster_reader_endpoint" {
  description = "The Neptune cluster reader endpoint"
  value       = aws_neptune_cluster.main.reader_endpoint
}

output "cluster_port" {
  description = "The Neptune cluster port"
  value       = aws_neptune_cluster.main.port
}

output "cluster_resource_id" {
  description = "The Neptune cluster resource ID"
  value       = aws_neptune_cluster.main.cluster_resource_id
}

output "instance_ids" {
  description = "List of Neptune instance IDs"
  value       = aws_neptune_cluster_instance.main[*].id
}

output "instance_endpoints" {
  description = "List of Neptune instance endpoints"
  value       = aws_neptune_cluster_instance.main[*].endpoint
}

output "neptune_subnet_group_name" {
  description = "Name of the Neptune subnet group"
  value       = aws_neptune_subnet_group.main.name
}
