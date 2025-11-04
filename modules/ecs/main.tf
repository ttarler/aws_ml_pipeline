# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-ecs-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"

      log_configuration {
        cloud_watch_log_group_name = aws_cloudwatch_log_group.ecs.name
      }
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-ecs-cluster"
    }
  )
}

# ECS Cluster Capacity Providers
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

# CloudWatch Log Group for ECS
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/aws/ecs/${var.project_name}"
  retention_in_days = 30

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-ecs-logs"
    }
  )
}

# ECR Repository for Docker images
resource "aws_ecr_repository" "main" {
  count = length(var.ecr_repositories)
  name  = "${var.project_name}-${var.ecr_repositories[count.index]}"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  image_tag_mutability = "MUTABLE"

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.ecr_repositories[count.index]}"
    }
  )
}

# ECR Lifecycle Policy
resource "aws_ecr_lifecycle_policy" "main" {
  count      = length(var.ecr_repositories)
  repository = aws_ecr_repository.main[count.index].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Expire untagged images older than 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Sample ECS Task Definition for ML workloads
resource "aws_ecs_task_definition" "ml_workload" {
  count                    = var.create_sample_task ? 1 : 0
  family                   = "${var.project_name}-ml-workload"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = "ml-container"
      image     = "${length(aws_ecr_repository.main) > 0 ? aws_ecr_repository.main[0].repository_url : "public.ecr.aws/docker/library/python:3.11"}:latest"
      essential = true

      environment = [
        {
          name  = "AWS_DEFAULT_REGION"
          value = var.aws_region
        },
        {
          name  = "S3_LANDING_ZONE_BUCKET"
          value = var.landing_zone_bucket_id
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ml-workload"
        }
      }

      mountPoints = []
      volumesFrom = []
    }
  ])

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-ml-workload-task"
    }
  )
}

# ECS Service for ML workload
resource "aws_ecs_service" "ml_workload" {
  count           = var.create_sample_service ? 1 : 0
  name            = "${var.project_name}-ml-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.ml_workload[0].arn
  desired_count   = var.service_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [var.security_group_id]
    assign_public_ip = false
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-ml-service"
    }
  )
}

# Secrets Manager secret for GitLab credentials
resource "aws_secretsmanager_secret" "gitlab_credentials" {
  name        = "${var.project_name}/gitlab-credentials"
  description = "GitLab credentials for CI/CD integration"

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-gitlab-credentials"
    }
  )
}

# Secrets Manager secret version (placeholder - users should update)
resource "aws_secretsmanager_secret_version" "gitlab_credentials" {
  secret_id = aws_secretsmanager_secret.gitlab_credentials.id
  secret_string = jsonencode({
    gitlab_url        = var.gitlab_url
    gitlab_token      = "PLACEHOLDER_UPDATE_ME"
    gitlab_project_id = "PLACEHOLDER_UPDATE_ME"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# CloudWatch Event Rule for scheduled ECS tasks
resource "aws_cloudwatch_event_rule" "scheduled_task" {
  count               = var.enable_scheduled_tasks ? 1 : 0
  name                = "${var.project_name}-scheduled-ml-task"
  description         = "Trigger ECS task on schedule"
  schedule_expression = var.schedule_expression

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-scheduled-task-rule"
    }
  )
}

# CloudWatch Event Target
resource "aws_cloudwatch_event_target" "scheduled_task" {
  count     = var.enable_scheduled_tasks ? 1 : 0
  rule      = aws_cloudwatch_event_rule.scheduled_task[0].name
  target_id = "ECSTask"
  arn       = aws_ecs_cluster.main.arn
  role_arn  = var.events_role_arn

  ecs_target {
    task_count          = 1
    task_definition_arn = var.create_sample_task ? aws_ecs_task_definition.ml_workload[0].arn : var.scheduled_task_definition_arn
    launch_type         = "FARGATE"

    network_configuration {
      subnets          = var.subnet_ids
      security_groups  = [var.security_group_id]
      assign_public_ip = false
    }
  }
}

# IAM Role for CloudWatch Events
resource "aws_iam_role" "events" {
  count = var.enable_scheduled_tasks && var.events_role_arn == "" ? 1 : 0
  name  = "${var.project_name}-ecs-events-role"

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
      Name = "${var.project_name}-ecs-events-role"
    }
  )
}

# IAM Policy for CloudWatch Events
resource "aws_iam_role_policy" "events" {
  count = var.enable_scheduled_tasks && var.events_role_arn == "" ? 1 : 0
  name  = "${var.project_name}-ecs-events-policy"
  role  = aws_iam_role.events[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:RunTask"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "ecs:cluster" = aws_ecs_cluster.main.arn
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          var.task_execution_role_arn,
          var.task_role_arn
        ]
      }
    ]
  })
}
