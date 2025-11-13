output "repository_id" {
  description = "ID of the CodeCommit repository"
  value       = aws_codecommit_repository.infrastructure.repository_id
}

output "repository_name" {
  description = "Name of the CodeCommit repository"
  value       = aws_codecommit_repository.infrastructure.repository_name
}

output "repository_arn" {
  description = "ARN of the CodeCommit repository"
  value       = aws_codecommit_repository.infrastructure.arn
}

output "clone_url_http" {
  description = "HTTP clone URL for the repository"
  value       = aws_codecommit_repository.infrastructure.clone_url_http
}

output "clone_url_ssh" {
  description = "SSH clone URL for the repository"
  value       = aws_codecommit_repository.infrastructure.clone_url_ssh
}

output "codebuild_project_name" {
  description = "Name of the CodeBuild project for Checkov scanning"
  value       = aws_codebuild_project.checkov.name
}

output "codebuild_project_arn" {
  description = "ARN of the CodeBuild project for Checkov scanning"
  value       = aws_codebuild_project.checkov.arn
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group for Checkov scan results"
  value       = aws_cloudwatch_log_group.codebuild_checkov.name
}
