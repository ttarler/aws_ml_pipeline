# Data source for current region
data "aws_region" "current" {}

# Data source for AWS account ID
data "aws_caller_identity" "current" {}

# ECR Repositories for SageMaker Images
# These will store copies of public SageMaker images for use in the domain
resource "aws_ecr_repository" "sagemaker_datascience" {
  name                 = "${var.project_name}/sagemaker-datascience-r"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-sagemaker-datascience-r"
      Purpose     = "SageMaker Data Science Image with R"
      Environment = var.environment
    }
  )
}

resource "aws_ecr_repository" "sagemaker_distribution_cpu" {
  name                 = "${var.project_name}/sagemaker-distribution-cpu"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-sagemaker-distribution-cpu"
      Purpose     = "SageMaker Distribution CPU Image"
      Environment = var.environment
    }
  )
}

resource "aws_ecr_repository" "sagemaker_distribution_gpu" {
  name                 = "${var.project_name}/sagemaker-distribution-gpu"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-sagemaker-distribution-gpu"
      Purpose     = "SageMaker Distribution GPU Image"
      Environment = var.environment
    }
  )
}

# ECR Lifecycle Policy to keep only recent images
resource "aws_ecr_lifecycle_policy" "sagemaker_images" {
  for_each = {
    datascience      = aws_ecr_repository.sagemaker_datascience.name
    distribution_cpu = aws_ecr_repository.sagemaker_distribution_cpu.name
    distribution_gpu = aws_ecr_repository.sagemaker_distribution_gpu.name
  }

  repository = each.value

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 3 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 3
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Local variables for instance type validation and ECR image URIs
locals {
  # ECR image URIs for SageMaker
  ecr_account_id = data.aws_caller_identity.current.account_id
  ecr_region     = data.aws_region.current.name

  sagemaker_datascience_image_uri = "${local.ecr_account_id}.dkr.ecr.${local.ecr_region}.amazonaws.com/${var.project_name}/sagemaker-datascience-r:latest"
  sagemaker_cpu_image_uri         = "${local.ecr_account_id}.dkr.ecr.${local.ecr_region}.amazonaws.com/${var.project_name}/sagemaker-distribution-cpu:latest"
  sagemaker_gpu_image_uri         = "${local.ecr_account_id}.dkr.ecr.${local.ecr_region}.amazonaws.com/${var.project_name}/sagemaker-distribution-gpu:latest"

  # Common SageMaker instance types available in AWS GovCloud
  govcloud_compatible_notebook_types = [
    "ml.t3.medium",
    "ml.t3.large",
    "ml.t3.xlarge",
    "ml.m5.large",
    "ml.m5.xlarge",
    "ml.m5.2xlarge",
    "ml.m5.4xlarge",
    "ml.c5.large",
    "ml.c5.xlarge",
    "ml.c5.2xlarge"
  ]

  # General purpose CPU instances for spaces
  general_purpose_instances = [
    "ml.t3.medium",
    "ml.t3.large",
    "ml.t3.xlarge",
    "ml.t3.2xlarge",
    "ml.m5.large",
    "ml.m5.xlarge",
    "ml.m5.2xlarge",
    "ml.m5.4xlarge",
    "ml.m5.8xlarge",
    "ml.m5.12xlarge",
    "ml.c5.large",
    "ml.c5.xlarge",
    "ml.c5.2xlarge",
    "ml.c5.4xlarge",
    "ml.c5.9xlarge"
  ]
}

# SageMaker Domain
resource "aws_sagemaker_domain" "main" {
  domain_name = "${var.project_name}-domain"
  auth_mode   = "IAM"
  vpc_id      = var.vpc_id
  subnet_ids  = var.subnet_ids

  default_user_settings {
    execution_role  = var.execution_role_arn
    security_groups = [var.security_group_id]

    jupyter_server_app_settings {
      default_resource_spec {
        instance_type = var.jupyter_instance_type
      }
    }

    kernel_gateway_app_settings {
      default_resource_spec {
        instance_type               = var.kernel_gateway_instance_type
        sagemaker_image_arn         = aws_sagemaker_image.datascience_r.arn
        sagemaker_image_version_arn = aws_sagemaker_image_version.datascience_r.arn
      }

      # Use custom image for R kernel
      custom_image {
        image_name            = aws_sagemaker_image.datascience_r.id
        app_image_config_name = aws_sagemaker_app_image_config.datascience_r.app_image_config_name
      }
    }

    sharing_settings {
      notebook_output_option = "Allowed"
      s3_output_path         = "s3://${var.sagemaker_bucket_id}/shared-notebooks"
    }
  }

  default_space_settings {
    execution_role  = var.execution_role_arn
    security_groups = [var.security_group_id]

    # JupyterLab settings for spaces (includes R kernel support)
    # Using default SageMaker Studio images (no custom image ARN needed)
    jupyter_lab_app_settings {
      default_resource_spec {
        instance_type = "ml.t3.medium"
      }

      # Enable R kernel and data science tools by default
      code_repository {
        repository_url = "https://github.com/aws/sagemaker-distribution.git"
      }
    }

    # Kernel Gateway settings for notebook instances
    # Uses custom ECR image with R kernel support
    kernel_gateway_app_settings {
      default_resource_spec {
        instance_type               = var.kernel_gateway_instance_type
        sagemaker_image_arn         = aws_sagemaker_image.datascience_r.arn
        sagemaker_image_version_arn = aws_sagemaker_image_version.datascience_r.arn
        lifecycle_config_arn        = aws_sagemaker_studio_lifecycle_config.r_and_spark_setup.arn
      }

      # Use custom image for R kernel
      custom_image {
        image_name            = aws_sagemaker_image.datascience_r.id
        app_image_config_name = aws_sagemaker_app_image_config.datascience_r.app_image_config_name
      }

      lifecycle_config_arns = [aws_sagemaker_studio_lifecycle_config.r_and_spark_setup.arn]
    }

    # JupyterServer settings for backward compatibility
    jupyter_server_app_settings {
      default_resource_spec {
        instance_type = var.jupyter_instance_type
      }
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-sagemaker-domain"
    }
  )

  depends_on = [
    aws_sagemaker_image_version.datascience_r,
    aws_sagemaker_image_version.distribution_cpu,
    aws_sagemaker_image_version.distribution_gpu,
    aws_sagemaker_app_image_config.datascience_r
  ]
}

# SageMaker User Profile
resource "aws_sagemaker_user_profile" "default" {
  domain_id         = aws_sagemaker_domain.main.id
  user_profile_name = "default-user"
  user_settings {
    execution_role  = var.studio_user_role_arn
    security_groups = [var.security_group_id]

    jupyter_server_app_settings {
      default_resource_spec {
        instance_type = var.jupyter_instance_type
      }
    }

    kernel_gateway_app_settings {
      default_resource_spec {
        instance_type = var.kernel_gateway_instance_type
      }
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-default-user-profile"
    }
  )

  lifecycle {
    # Prevent deletion if there are running apps or spaces
    # Users must manually delete apps/spaces before destroying
    prevent_destroy = false
  }
}

# SageMaker Studio Lifecycle Config for R, Spark, and Neptune setup
resource "aws_sagemaker_studio_lifecycle_config" "r_and_spark_setup" {
  studio_lifecycle_config_name     = "${var.project_name}-r-spark-setup"
  studio_lifecycle_config_app_type = "KernelGateway"
  studio_lifecycle_config_content = base64encode(<<-EOF
    #!/bin/bash
    set -e

    echo "=========================================="
    echo "Installing R Kernel and Data Science Tools"
    echo "=========================================="

    # Install R kernel and essential packages
    echo "Installing R base and IRkernel..."
    conda install -y -c conda-forge \
      r-base \
      r-irkernel \
      r-essentials \
      r-tidyverse \
      r-ggplot2 \
      r-caret \
      r-data.table \
      r-dplyr \
      r-devtools \
      r-shiny \
      r-rmarkdown

    # Register R kernel with Jupyter
    echo "Registering R kernel with Jupyter..."
    R -e "IRkernel::installspec(user = FALSE, displayname = 'R')"

    # Install additional R packages for machine learning
    echo "Installing additional R packages..."
    R -e "install.packages(c('randomForest', 'xgboost', 'mlr3', 'keras'), repos='https://cloud.r-project.org/')"

    # Install Spark and PySpark
    echo "Installing PySpark..."
    pip install pyspark findspark py4j

    # Install Sparkmagic for EMR connection (if EMR is configured)
    if [ -n "${var.emr_master_dns}" ]; then
      echo "Configuring Sparkmagic for EMR connection..."
      pip install sparkmagic

      # Configure Sparkmagic
      mkdir -p ~/.sparkmagic
      cat > ~/.sparkmagic/config.json <<EOL
      {
        "kernel_python_credentials" : {
          "username": "",
          "password": "",
          "url": "http://${var.emr_master_dns}:8998",
          "auth": "None"
        },
        "kernel_scala_credentials" : {
          "username": "",
          "password": "",
          "url": "http://${var.emr_master_dns}:8998",
          "auth": "None"
        },
        "kernel_r_credentials" : {
          "username": "",
          "password": "",
          "url": "http://${var.emr_master_dns}:8998",
          "auth": "None"
        },
        "custom_headers" : {
          "X-Requested-By": "livy"
        },
        "session_configs" : {
          "driverMemory": "1000M",
          "executorCores": 2
        }
      }
EOL

      # Install Sparkmagic kernels
      echo "Installing Sparkmagic kernels..."
      jupyter-kernelspec install --sys-prefix \$(pip show sparkmagic | grep Location | cut -d' ' -f2)/sparkmagic/kernels/pysparkkernel
      jupyter-kernelspec install --sys-prefix \$(pip show sparkmagic | grep Location | cut -d' ' -f2)/sparkmagic/kernels/sparkrkernel

      # Install SparkR kernel
      R -e "install.packages('SparkR', repos='https://cloud.r-project.org/')"
    fi

    # Install Neptune Python libraries (if Neptune is enabled)
    if [ "${var.enable_neptune_kernel}" = "true" ]; then
      echo "Installing Neptune graph database libraries..."
      pip install gremlinpython SPARQLWrapper neptune-python-utils
    fi

    # Verify installations
    echo ""
    echo "=========================================="
    echo "Kernel Installation Summary:"
    echo "=========================================="
    jupyter kernelspec list

    echo ""
    echo "✅ R, Spark, and Neptune setup complete!"
    echo "=========================================="
  EOF
  )

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-r-spark-lifecycle"
    }
  )
}

# SageMaker Image for Data Science with R (from private ECR)
resource "aws_sagemaker_image" "datascience_r" {
  image_name = "${var.project_name}-datascience-r"
  role_arn   = var.execution_role_arn

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-datascience-r-image"
    }
  )

  depends_on = [
    aws_ecr_repository.sagemaker_datascience
  ]
}

# SageMaker Image Version for Data Science R
resource "aws_sagemaker_image_version" "datascience_r" {
  image_name = aws_sagemaker_image.datascience_r.id
  base_image = local.sagemaker_datascience_image_uri

  depends_on = [
    aws_sagemaker_image.datascience_r
  ]
}

# SageMaker App Image Config for Data Science R
resource "aws_sagemaker_app_image_config" "datascience_r" {
  app_image_config_name = "${var.project_name}-datascience-r-config"

  kernel_gateway_image_config {
    kernel_spec {
      name         = "ir"
      display_name = "R (SageMaker Distribution)"
    }

    file_system_config {
      default_gid = 100
      default_uid = 1000
      mount_path  = "/home/sagemaker-user"
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-datascience-r-config"
    }
  )
}

# SageMaker Image for CPU Distribution (from private ECR)
resource "aws_sagemaker_image" "distribution_cpu" {
  image_name = "${var.project_name}-distribution-cpu"
  role_arn   = var.execution_role_arn

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-distribution-cpu-image"
    }
  )

  depends_on = [
    aws_ecr_repository.sagemaker_distribution_cpu
  ]
}

# SageMaker Image Version for CPU Distribution
resource "aws_sagemaker_image_version" "distribution_cpu" {
  image_name = aws_sagemaker_image.distribution_cpu.id
  base_image = local.sagemaker_cpu_image_uri

  depends_on = [
    aws_sagemaker_image.distribution_cpu
  ]
}

# SageMaker Image for GPU Distribution (from private ECR)
resource "aws_sagemaker_image" "distribution_gpu" {
  image_name = "${var.project_name}-distribution-gpu"
  role_arn   = var.execution_role_arn

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-distribution-gpu-image"
    }
  )

  depends_on = [
    aws_ecr_repository.sagemaker_distribution_gpu
  ]
}

# SageMaker Image Version for GPU Distribution
resource "aws_sagemaker_image_version" "distribution_gpu" {
  image_name = aws_sagemaker_image.distribution_gpu.id
  base_image = local.sagemaker_gpu_image_uri

  depends_on = [
    aws_sagemaker_image.distribution_gpu
  ]
}

# SageMaker Notebook Instance (optional - for direct EMR access)
resource "aws_sagemaker_notebook_instance" "emr_connector" {
  count                  = var.create_notebook_instance ? 1 : 0
  name                   = "${var.project_name}-emr-connector"
  role_arn               = var.execution_role_arn
  instance_type          = var.notebook_instance_type
  subnet_id              = var.subnet_ids[0]
  security_groups        = [var.security_group_id]
  direct_internet_access = var.notebook_direct_internet_access
  volume_size            = 50

  # Lifecycle config disabled to prevent timeout issues in private subnets
  # The lifecycle script requires internet access to install packages
  # Configure EMR connectivity manually after notebook launches

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-emr-connector-notebook"
    }
  )
}

# Lifecycle configuration for notebook instance
# Disabled by default to prevent timeout issues when installing packages in private subnets
# To enable: change count condition and uncomment lifecycle_config_name in notebook instance above
resource "aws_sagemaker_notebook_instance_lifecycle_configuration" "emr_setup" {
  count = 0 # Disabled - was: var.create_notebook_instance && var.emr_master_dns != "" ? 1 : 0
  name  = "${var.project_name}-emr-setup"

  on_start = base64encode(<<-EOF
    #!/bin/bash
    set -e

    # Configure EMR connectivity for notebook instance
    sudo -u ec2-user -i <<'USEREOF'
    source /home/ec2-user/anaconda3/bin/activate python3

    # Configure Sparkmagic for EMR connection (if sparkmagic is available)
    mkdir -p ~/.sparkmagic
    cat > ~/.sparkmagic/config.json <<EOL
    {
      "kernel_python_credentials" : {
        "username": "",
        "password": "",
        "url": "http://${var.emr_master_dns}:8998",
        "auth": "None"
      },
      "kernel_scala_credentials" : {
        "username": "",
        "password": "",
        "url": "http://${var.emr_master_dns}:8998",
        "auth": "None"
      },
      "session_configs" : {
        "driverMemory": "1000M",
        "executorCores": 2
      }
    }
    EOL

    # Note: Sparkmagic kernels can be installed manually after the notebook starts
    # This requires internet access which may not be available in private subnets

    echo "EMR configuration complete. EMR endpoint: http://${var.emr_master_dns}:8998"

    source /home/ec2-user/anaconda3/bin/deactivate
    USEREOF
  EOF
  )
}

# Note: Custom kernels for R, Spark, and Neptune are installed via lifecycle configuration
# rather than custom SageMaker images. This avoids the need to build and maintain Docker images.
# The lifecycle config installs:
# - R kernel (via conda)
# - Sparkmagic kernels for PySpark and SparkR (via pip)
# - Neptune Python libraries (gremlinpython, SPARQLWrapper)

# Space Settings Template for General Purpose CPU Instances
# This space template includes R kernel support and is optimized for CPU-based workloads
resource "aws_sagemaker_space" "general_purpose_template" {
  count      = var.create_space_templates ? 1 : 0
  domain_id  = aws_sagemaker_domain.main.id
  space_name = "general-purpose-cpu-template"

  space_settings {
    # JupyterLab app settings (primary interface for spaces)
    # Using default SageMaker Studio images (no custom image ARN needed)
    jupyter_lab_app_settings {
      default_resource_spec {
        instance_type = "ml.t3.medium"
      }

      # Default code repositories for R packages and examples
      code_repository {
        repository_url = "https://github.com/aws/sagemaker-distribution.git"
      }
    }

    # Kernel Gateway settings for R and Spark kernels
    # Uses custom ECR image with R kernel support
    kernel_gateway_app_settings {
      default_resource_spec {
        instance_type               = "ml.m5.xlarge"
        sagemaker_image_arn         = aws_sagemaker_image.datascience_r.arn
        sagemaker_image_version_arn = aws_sagemaker_image_version.datascience_r.arn
        lifecycle_config_arn        = aws_sagemaker_studio_lifecycle_config.r_and_spark_setup.arn
      }

      # Use custom image for R kernel
      custom_image {
        image_name            = aws_sagemaker_image.datascience_r.id
        app_image_config_name = aws_sagemaker_app_image_config.datascience_r.app_image_config_name
      }

      # Lifecycle config to install R, Spark, and Neptune kernels
      lifecycle_config_arns = [aws_sagemaker_studio_lifecycle_config.r_and_spark_setup.arn]
    }
  }

  tags = merge(
    var.tags,
    {
      Name         = "${var.project_name}-general-purpose-cpu-space"
      Type         = "GeneralPurpose"
      ComputeType  = "CPU"
      InstanceType = "ml.t3.medium - ml.m5.24xlarge"
      Kernels      = "Python, R, PySpark, SparkR, Neptune"
      Description  = "Template for CPU-based workloads with R, Spark, and Neptune kernels"
    }
  )
}


# SageMaker Feature Store (optional - for ML feature management)
resource "aws_sagemaker_feature_group" "ml_features" {
  count                          = var.enable_feature_store ? 1 : 0
  feature_group_name             = "${var.project_name}-ml-features"
  record_identifier_feature_name = "record_id"
  event_time_feature_name        = "event_time"

  feature_definition {
    feature_name = "record_id"
    feature_type = "String"
  }

  feature_definition {
    feature_name = "event_time"
    feature_type = "String"
  }

  online_store_config {
    enable_online_store = true
  }

  offline_store_config {
    s3_storage_config {
      s3_uri = "s3://${var.sagemaker_bucket_id}/feature-store"
    }
  }

  role_arn = var.execution_role_arn

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-ml-features"
    }
  )
}

# SageMaker Model Registry (for model versioning)
resource "aws_sagemaker_model_package_group" "models" {
  model_package_group_name        = "${var.project_name}-models"
  model_package_group_description = "Model package group for ${var.project_name}"

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-model-registry"
    }
  )
}
