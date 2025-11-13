# Data source for current region
data "aws_region" "current" {}

# Local variables for instance type validation
locals {
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

  # Accelerated compute (GPU) instances for spaces
  accelerated_compute_instances = [
    "ml.g4dn.xlarge",
    "ml.g4dn.2xlarge",
    "ml.g4dn.4xlarge",
    "ml.g4dn.8xlarge",
    "ml.g4dn.12xlarge",
    "ml.g4dn.16xlarge",
    "ml.g5.xlarge",
    "ml.g5.2xlarge",
    "ml.g5.4xlarge",
    "ml.g5.8xlarge",
    "ml.g5.12xlarge",
    "ml.g5.16xlarge",
    "ml.p3.2xlarge",
    "ml.p3.8xlarge",
    "ml.p3.16xlarge"
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
        instance_type = var.kernel_gateway_instance_type
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

    kernel_gateway_app_settings {
      default_resource_spec {
        instance_type        = var.kernel_gateway_instance_type
        sagemaker_image_arn  = "arn:aws-us-gov:sagemaker:${data.aws_region.current.name}:aws:image/sagemaker-data-science-310-v1"
        lifecycle_config_arn = aws_sagemaker_studio_lifecycle_config.emr_connection.arn
      }

      # Custom image configurations for R and RSpark
      custom_image {
        image_name            = "r-kernel"
        app_image_config_name = aws_sagemaker_app_image_config.r_kernel.app_image_config_name
      }

      custom_image {
        image_name            = "rspark-kernel"
        app_image_config_name = aws_sagemaker_app_image_config.rspark_kernel.app_image_config_name
      }
    }

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

# SageMaker Studio Lifecycle Config for EMR connection
resource "aws_sagemaker_studio_lifecycle_config" "emr_connection" {
  studio_lifecycle_config_name     = "${var.project_name}-emr-connection"
  studio_lifecycle_config_app_type = "JupyterServer"
  studio_lifecycle_config_content = base64encode(<<-EOF
    #!/bin/bash
    set -e

    # Install Sparkmagic for EMR connection
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
    cd $(pip show sparkmagic | grep Location | cut -d' ' -f2)
    jupyter-kernelspec install sparkmagic/kernels/sparkkernel
    jupyter-kernelspec install sparkmagic/kernels/pysparkkernel
    jupyter-kernelspec install sparkmagic/kernels/sparkrkernel

    echo "EMR connection setup complete"
  EOF
  )

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-emr-connection-lifecycle"
    }
  )
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

# App Image Config for R Kernel
resource "aws_sagemaker_app_image_config" "r_kernel" {
  app_image_config_name = "${var.project_name}-r-kernel-config"

  kernel_gateway_image_config {
    kernel_spec {
      name         = "ir"
      display_name = "R"
    }

    file_system_config {
      default_gid = 100
      default_uid = 1000
      mount_path  = "/root"
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-r-kernel-config"
    }
  )
}

# App Image Config for RSpark Kernel
resource "aws_sagemaker_app_image_config" "rspark_kernel" {
  app_image_config_name = "${var.project_name}-rspark-kernel-config"

  kernel_gateway_image_config {
    kernel_spec {
      name         = "sparkr"
      display_name = "R with Spark"
    }

    file_system_config {
      default_gid = 100
      default_uid = 1000
      mount_path  = "/root"
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-rspark-kernel-config"
    }
  )
}

# Space Settings Template for General Purpose CPU Instances
resource "aws_sagemaker_space" "general_purpose_template" {
  count      = var.create_space_templates ? 1 : 0
  domain_id  = aws_sagemaker_domain.main.id
  space_name = "general-purpose-template"

  space_settings {
    kernel_gateway_app_settings {
      default_resource_spec {
        instance_type       = "ml.m5.large"
        sagemaker_image_arn = "arn:aws-us-gov:sagemaker:${data.aws_region.current.name}:aws:image/sagemaker-data-science-310-v1"
      }

      # Include all custom kernels
      custom_image {
        image_name            = "r-kernel"
        app_image_config_name = aws_sagemaker_app_image_config.r_kernel.app_image_config_name
      }

      custom_image {
        image_name            = "rspark-kernel"
        app_image_config_name = aws_sagemaker_app_image_config.rspark_kernel.app_image_config_name
      }

      lifecycle_config_arns = [aws_sagemaker_studio_lifecycle_config.emr_connection.arn]
    }

    jupyter_server_app_settings {
      default_resource_spec {
        instance_type = "system"
      }
    }
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-general-purpose-space"
      Type        = "GeneralPurpose"
      Description = "Template for CPU-based workloads with R and RSpark kernels"
    }
  )
}

# Space Settings Template for Accelerated Compute (GPU) Instances
resource "aws_sagemaker_space" "accelerated_compute_template" {
  count      = var.create_space_templates ? 1 : 0
  domain_id  = aws_sagemaker_domain.main.id
  space_name = "accelerated-compute-template"

  space_settings {
    kernel_gateway_app_settings {
      default_resource_spec {
        instance_type       = "ml.g4dn.xlarge"
        sagemaker_image_arn = "arn:aws-us-gov:sagemaker:${data.aws_region.current.name}:aws:image/sagemaker-data-science-310-v1"
      }

      # Include all custom kernels
      custom_image {
        image_name            = "r-kernel"
        app_image_config_name = aws_sagemaker_app_image_config.r_kernel.app_image_config_name
      }

      custom_image {
        image_name            = "rspark-kernel"
        app_image_config_name = aws_sagemaker_app_image_config.rspark_kernel.app_image_config_name
      }

      lifecycle_config_arns = [aws_sagemaker_studio_lifecycle_config.emr_connection.arn]
    }

    jupyter_server_app_settings {
      default_resource_spec {
        instance_type = "system"
      }
    }
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-accelerated-compute-space"
      Type        = "AcceleratedCompute"
      Description = "Template for GPU-accelerated workloads with R and RSpark kernels"
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
