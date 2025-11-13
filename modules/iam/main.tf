# SageMaker Execution Role
resource "aws_iam_role" "sagemaker_execution" {
  name = "${var.project_name}-sagemaker-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "sagemaker.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-sagemaker-execution-role"
    }
  )
}

# SageMaker Execution Role Policy
resource "aws_iam_role_policy" "sagemaker_execution" {
  name = "${var.project_name}-sagemaker-execution-policy"
  role = aws_iam_role.sagemaker_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${var.s3_landing_zone_arn}",
          "${var.s3_landing_zone_arn}/*",
          "${var.s3_sagemaker_arn}",
          "${var.s3_sagemaker_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:${var.partition}:logs:${var.aws_region}:${var.account_id}:log-group:/aws/sagemaker/*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticmapreduce:ListInstances",
          "elasticmapreduce:DescribeCluster",
          "elasticmapreduce:ListSteps"
        ]
        Resource = "arn:${var.partition}:elasticmapreduce:${var.aws_region}:${var.account_id}:cluster/*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticmapreduce:RunJobFlow",
          "elasticmapreduce:AddJobFlowSteps",
          "elasticmapreduce:TerminateJobFlows"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          aws_iam_role.emr_service.arn,
          aws_iam_role.emr_ec2.arn
        ]
        Condition = {
          StringLike = {
            "iam:PassedToService" = "elasticmapreduce.amazonaws.com"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "neptune-db:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach AWS managed policy for SageMaker full access
resource "aws_iam_role_policy_attachment" "sagemaker_full_access" {
  role       = aws_iam_role.sagemaker_execution.name
  policy_arn = "arn:${var.partition}:iam::aws:policy/AmazonSageMakerFullAccess"
}

# Additional SageMaker permissions for Studio apps and spaces
resource "aws_iam_role_policy" "sagemaker_studio_permissions" {
  name = "${var.project_name}-sagemaker-studio-permissions"
  role = aws_iam_role.sagemaker_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sagemaker:CreateApp",
          "sagemaker:DeleteApp",
          "sagemaker:DescribeApp",
          "sagemaker:CreateSpace",
          "sagemaker:UpdateSpace",
          "sagemaker:DeleteSpace",
          "sagemaker:DescribeSpace",
          "sagemaker:ListSpaces",
          "sagemaker:AddTags",
          "sagemaker:DeleteTags",
          "sagemaker:ListTags"
        ]
        Resource = [
          "arn:${var.partition}:sagemaker:${var.aws_region}:${var.account_id}:app/*",
          "arn:${var.partition}:sagemaker:${var.aws_region}:${var.account_id}:space/*",
          "arn:${var.partition}:sagemaker:${var.aws_region}:${var.account_id}:domain/*",
          "arn:${var.partition}:sagemaker:${var.aws_region}:${var.account_id}:user-profile/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sagemaker:CreatePresignedDomainUrl",
          "sagemaker:DescribeDomain",
          "sagemaker:DescribeUserProfile",
          "sagemaker:ListApps",
          "sagemaker:ListDomains",
          "sagemaker:ListUserProfiles"
        ]
        Resource = "*"
      }
    ]
  })
}

# SageMaker Studio Domain Execution Role
resource "aws_iam_role" "sagemaker_studio_user" {
  name = "${var.project_name}-sagemaker-studio-user-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "sagemaker.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-sagemaker-studio-user-role"
    }
  )
}

# Attach policies to Studio user role
resource "aws_iam_role_policy_attachment" "sagemaker_studio_full_access" {
  role       = aws_iam_role.sagemaker_studio_user.name
  policy_arn = "arn:${var.partition}:iam::aws:policy/AmazonSageMakerFullAccess"
}

resource "aws_iam_role_policy" "sagemaker_studio_user" {
  name = "${var.project_name}-sagemaker-studio-user-policy"
  role = aws_iam_role.sagemaker_studio_user.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${var.s3_landing_zone_arn}",
          "${var.s3_landing_zone_arn}/*",
          "${var.s3_sagemaker_arn}",
          "${var.s3_sagemaker_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "elasticmapreduce:*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          aws_iam_role.emr_service.arn,
          aws_iam_role.emr_ec2.arn
        ]
        Condition = {
          StringLike = {
            "iam:PassedToService" = "elasticmapreduce.amazonaws.com"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "sagemaker:CreateApp",
          "sagemaker:DeleteApp",
          "sagemaker:DescribeApp",
          "sagemaker:CreateSpace",
          "sagemaker:UpdateSpace",
          "sagemaker:DeleteSpace",
          "sagemaker:DescribeSpace",
          "sagemaker:ListSpaces",
          "sagemaker:AddTags",
          "sagemaker:DeleteTags",
          "sagemaker:ListTags"
        ]
        Resource = [
          "arn:${var.partition}:sagemaker:${var.aws_region}:${var.account_id}:app/*",
          "arn:${var.partition}:sagemaker:${var.aws_region}:${var.account_id}:space/*",
          "arn:${var.partition}:sagemaker:${var.aws_region}:${var.account_id}:domain/*",
          "arn:${var.partition}:sagemaker:${var.aws_region}:${var.account_id}:user-profile/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sagemaker:CreatePresignedDomainUrl",
          "sagemaker:DescribeDomain",
          "sagemaker:DescribeUserProfile",
          "sagemaker:ListApps",
          "sagemaker:ListDomains",
          "sagemaker:ListUserProfiles"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "neptune-db:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# EMR Service Role
resource "aws_iam_role" "emr_service" {
  name = "${var.project_name}-emr-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "elasticmapreduce.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-emr-service-role"
    }
  )
}

# Attach AWS managed policy for EMR service role
resource "aws_iam_role_policy_attachment" "emr_service" {
  role       = aws_iam_role.emr_service.name
  policy_arn = "arn:${var.partition}:iam::aws:policy/service-role/AmazonElasticMapReduceRole"
}

# Additional EMR Service policy for S3 bootstrap scripts
resource "aws_iam_role_policy" "emr_service_s3" {
  name = "${var.project_name}-emr-service-s3-policy"
  role = aws_iam_role.emr_service.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${var.s3_emr_logs_arn}",
          "${var.s3_emr_logs_arn}/*"
        ]
      }
    ]
  })
}

# EMR EC2 Instance Profile Role
resource "aws_iam_role" "emr_ec2" {
  name = "${var.project_name}-emr-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-emr-ec2-role"
    }
  )
}

# Attach AWS managed policy for EMR EC2 role
resource "aws_iam_role_policy_attachment" "emr_ec2_default" {
  role       = aws_iam_role.emr_ec2.name
  policy_arn = "arn:${var.partition}:iam::aws:policy/service-role/AmazonElasticMapReduceforEC2Role"
}

# Additional EMR EC2 policy for S3 and CloudWatch
resource "aws_iam_role_policy" "emr_ec2_custom" {
  name = "${var.project_name}-emr-ec2-custom-policy"
  role = aws_iam_role.emr_ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${var.s3_landing_zone_arn}",
          "${var.s3_landing_zone_arn}/*",
          "${var.s3_emr_logs_arn}",
          "${var.s3_emr_logs_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "ec2:DescribeVolumes",
          "ec2:DescribeTags",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}

# EMR EC2 Instance Profile
resource "aws_iam_instance_profile" "emr_ec2" {
  name = "${var.project_name}-emr-ec2-instance-profile"
  role = aws_iam_role.emr_ec2.name

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-emr-ec2-instance-profile"
    }
  )
}

# EMR Auto Scaling Role
resource "aws_iam_role" "emr_autoscaling" {
  name = "${var.project_name}-emr-autoscaling-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "elasticmapreduce.amazonaws.com",
            "application-autoscaling.amazonaws.com"
          ]
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-emr-autoscaling-role"
    }
  )
}

# Attach AWS managed policy for EMR autoscaling
resource "aws_iam_role_policy_attachment" "emr_autoscaling" {
  role       = aws_iam_role.emr_autoscaling.name
  policy_arn = "arn:${var.partition}:iam::aws:policy/service-role/AmazonElasticMapReduceforAutoScalingRole"
}

# ECS Task Execution Role
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.project_name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-ecs-task-execution-role"
    }
  )
}

# Attach AWS managed policy for ECS task execution
resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:${var.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Additional ECS task execution policy for Secrets Manager
resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  name = "${var.project_name}-ecs-task-execution-secrets-policy"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:${var.partition}:secretsmanager:${var.aws_region}:${var.account_id}:secret:${var.project_name}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:${var.partition}:logs:${var.aws_region}:${var.account_id}:log-group:/aws/ecs/${var.project_name}/*"
      }
    ]
  })
}

# ECS Task Role (for the actual containers)
resource "aws_iam_role" "ecs_task" {
  name = "${var.project_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-ecs-task-role"
    }
  )
}

# ECS Task Role Policy
resource "aws_iam_role_policy" "ecs_task" {
  name = "${var.project_name}-ecs-task-policy"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${var.s3_landing_zone_arn}",
          "${var.s3_landing_zone_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:${var.partition}:logs:${var.aws_region}:${var.account_id}:log-group:/aws/ecs/${var.project_name}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}
