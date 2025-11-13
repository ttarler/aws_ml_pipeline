# CodeCommit Repository for Infrastructure Code
resource "aws_codecommit_repository" "infrastructure" {
  repository_name = "${var.project_name}-infrastructure"
  description     = "Infrastructure as Code repository for ${var.project_name} ML platform"

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-infrastructure-repo"
      Purpose     = "Infrastructure Code Repository"
      Environment = var.environment
    }
  )
}

# IAM Role for CodeBuild to run Checkov scans
resource "aws_iam_role" "codebuild_checkov" {
  name = "${var.project_name}-codebuild-checkov-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-codebuild-checkov-role"
    }
  )
}

# IAM Policy for CodeBuild
resource "aws_iam_role_policy" "codebuild_checkov" {
  role = aws_iam_role.codebuild_checkov.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:${var.aws_partition}:logs:${var.aws_region}:${var.account_id}:log-group:/aws/codebuild/${var.project_name}-checkov",
          "arn:${var.aws_partition}:logs:${var.aws_region}:${var.account_id}:log-group:/aws/codebuild/${var.project_name}-checkov:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "codecommit:GitPull",
          "codecommit:GetBranch",
          "codecommit:GetCommit",
          "codecommit:GetRepository",
          "codecommit:ListBranches"
        ]
        Resource = aws_codecommit_repository.infrastructure.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "${var.artifacts_bucket_arn}/*"
        ]
      }
    ]
  })
}

# CodeBuild Project for Checkov Security Scanning
resource "aws_codebuild_project" "checkov" {
  name          = "${var.project_name}-checkov"
  description   = "Checkov security scanning for infrastructure code"
  build_timeout = "15"
  service_role  = aws_iam_role.codebuild_checkov.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "CHECKOV_VERSION"
      value = "latest"
    }

    environment_variable {
      name  = "PROJECT_NAME"
      value = var.project_name
    }
  }

  source {
    type            = "CODECOMMIT"
    location        = aws_codecommit_repository.infrastructure.clone_url_http
    git_clone_depth = 1
    buildspec       = file("${path.module}/buildspec-checkov.yml")
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/${var.project_name}-checkov"
      stream_name = "checkov-scan"
    }
  }

  tags = merge(
    var.tags,
    {
      Name    = "${var.project_name}-checkov-build"
      Purpose = "Security Scanning"
    }
  )
}

# CloudWatch Log Group for CodeBuild
resource "aws_cloudwatch_log_group" "codebuild_checkov" {
  name              = "/aws/codebuild/${var.project_name}-checkov"
  retention_in_days = 30

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-checkov-logs"
    }
  )
}

# EventBridge Rule to trigger Checkov on push to main branch
resource "aws_cloudwatch_event_rule" "codecommit_main_push" {
  count       = var.enable_auto_checkov ? 1 : 0
  name        = "${var.project_name}-codecommit-main-push"
  description = "Trigger Checkov scan on push to main branch"

  event_pattern = jsonencode({
    source      = ["aws.codecommit"]
    detail-type = ["CodeCommit Repository State Change"]
    resources   = [aws_codecommit_repository.infrastructure.arn]
    detail = {
      event         = ["referenceCreated", "referenceUpdated"]
      referenceType = ["branch"]
      referenceName = ["main"]
    }
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-codecommit-trigger"
    }
  )
}

# EventBridge Target to invoke CodeBuild
resource "aws_cloudwatch_event_target" "codebuild_checkov" {
  count     = var.enable_auto_checkov ? 1 : 0
  rule      = aws_cloudwatch_event_rule.codecommit_main_push[0].name
  target_id = "TriggerCodeBuild"
  arn       = aws_codebuild_project.checkov.arn
  role_arn  = aws_iam_role.eventbridge_codebuild[0].arn
}

# IAM Role for EventBridge to trigger CodeBuild
resource "aws_iam_role" "eventbridge_codebuild" {
  count = var.enable_auto_checkov ? 1 : 0
  name  = "${var.project_name}-eventbridge-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-eventbridge-codebuild-role"
    }
  )
}

# IAM Policy for EventBridge to start CodeBuild
resource "aws_iam_role_policy" "eventbridge_codebuild" {
  count = var.enable_auto_checkov ? 1 : 0
  role  = aws_iam_role.eventbridge_codebuild[0].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "codebuild:StartBuild"
        ]
        Resource = aws_codebuild_project.checkov.arn
      }
    ]
  })
}
