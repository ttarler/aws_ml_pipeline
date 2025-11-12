# EMR Cluster
resource "aws_emr_cluster" "main" {
  name          = "${var.project_name}-emr-cluster"
  release_label = var.emr_release_label
  applications  = var.emr_applications

  service_role     = var.emr_service_role_arn
  autoscaling_role = var.emr_autoscaling_role_arn != "" ? var.emr_autoscaling_role_arn : null

  termination_protection            = false
  keep_job_flow_alive_when_no_steps = true
  log_uri                           = "s3://${var.emr_logs_bucket_id}/logs/"

  # Force EMR to wait for termination before considering destroy complete
  # This helps prevent security group deletion errors
  lifecycle {
    create_before_destroy = false
  }

  ec2_attributes {
    subnet_id                         = var.subnet_ids[0]
    emr_managed_master_security_group = var.emr_master_security_group_id
    emr_managed_slave_security_group  = var.emr_slave_security_group_id
    service_access_security_group     = var.emr_service_security_group_id
    instance_profile                  = var.emr_ec2_instance_profile_name
    key_name                          = var.ec2_key_name != "" ? var.ec2_key_name : null
  }

  master_instance_group {
    name           = "master"
    instance_type  = var.master_instance_type
    instance_count = 1

    ebs_config {
      size                 = var.master_ebs_size
      type                 = "gp3"
      volumes_per_instance = 1
    }
  }

  core_instance_group {
    name           = "core"
    instance_type  = var.core_instance_type
    instance_count = var.core_instance_count

    ebs_config {
      size                 = var.core_ebs_size
      type                 = "gp3"
      volumes_per_instance = 1
    }

    bid_price = var.core_use_spot ? var.core_spot_bid_price : null
  }

  # Bootstrap action to configure EMR for SageMaker connectivity
  dynamic "bootstrap_action" {
    for_each = var.create_bootstrap_script ? [1] : []
    content {
      name = "Install Livy and configure for SageMaker"
      path = "s3://${var.bootstrap_scripts_bucket}/bootstrap-emr-sagemaker.sh"

      args = [
        "--sagemaker-enabled",
        "true"
      ]
    }
  }

  # Configure EMR with custom settings
  configurations_json = jsonencode([
    {
      "Classification" : "livy-conf",
      "Properties" : {
        "livy.server.session.timeout" : "2h",
        "livy.spark.master" : "yarn",
        "livy.spark.deploy-mode" : "cluster"
      }
    },
    {
      "Classification" : "spark-defaults",
      "Properties" : {
        "spark.dynamicAllocation.enabled" : "true",
        "spark.executor.instances" : "2",
        "spark.executor.memory" : "2g",
        "spark.executor.cores" : "2",
        "spark.driver.memory" : "2g"
      }
    },
    {
      "Classification" : "spark-hive-site",
      "Properties" : {
        "hive.metastore.client.factory.class" : "com.amazonaws.glue.catalog.metastore.AWSGlueDataCatalogHiveClientFactory"
      }
    },
    {
      "Classification" : "hadoop-env",
      "Configurations" : [
        {
          "Classification" : "export",
          "Properties" : {
            "JAVA_HOME" : "/usr/lib/jvm/java-1.8.0"
          }
        }
      ]
    }
  ])

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-emr-cluster"
      Environment = var.environment
    }
  )

  depends_on = [aws_s3_object.bootstrap_script]
}

# EMR Task Instance Group with Spot Instances
resource "aws_emr_instance_group" "task_spot" {
  count      = var.enable_task_spot_instances ? 1 : 0
  cluster_id = aws_emr_cluster.main.id
  name       = "task-spot"

  instance_type  = var.task_instance_type
  instance_count = var.task_instance_count

  ebs_config {
    size                 = var.task_ebs_size
    type                 = "gp3"
    volumes_per_instance = 1
  }

  bid_price = var.task_spot_bid_price

  autoscaling_policy = jsonencode({
    Constraints = {
      MinCapacity = var.task_min_capacity
      MaxCapacity = var.task_max_capacity
    }
    Rules = [
      {
        Name        = "ScaleUpOnYARNMemory"
        Description = "Scale up when YARN memory utilization is high"
        Action = {
          SimpleScalingPolicyConfiguration = {
            AdjustmentType    = "CHANGE_IN_CAPACITY"
            ScalingAdjustment = 1
            CoolDown          = 300
          }
        }
        Trigger = {
          CloudWatchAlarmDefinition = {
            ComparisonOperator = "GREATER_THAN"
            EvaluationPeriods  = 1
            MetricName         = "YARNMemoryAvailablePercentage"
            Namespace          = "AWS/ElasticMapReduce"
            Period             = 300
            Statistic          = "AVERAGE"
            Threshold          = 75.0
            Unit               = "PERCENT"
            Dimensions = [
              {
                Key   = "JobFlowId"
                Value = "$${emr.clusterId}"
              }
            ]
          }
        }
      },
      {
        Name        = "ScaleDownOnYARNMemory"
        Description = "Scale down when YARN memory utilization is low"
        Action = {
          SimpleScalingPolicyConfiguration = {
            AdjustmentType    = "CHANGE_IN_CAPACITY"
            ScalingAdjustment = -1
            CoolDown          = 300
          }
        }
        Trigger = {
          CloudWatchAlarmDefinition = {
            ComparisonOperator = "LESS_THAN"
            EvaluationPeriods  = 1
            MetricName         = "YARNMemoryAvailablePercentage"
            Namespace          = "AWS/ElasticMapReduce"
            Period             = 300
            Statistic          = "AVERAGE"
            Threshold          = 25.0
            Unit               = "PERCENT"
            Dimensions = [
              {
                Key   = "JobFlowId"
                Value = "$${emr.clusterId}"
              }
            ]
          }
        }
      }
    ]
  })
}

# CloudWatch Log Group for EMR
resource "aws_cloudwatch_log_group" "emr" {
  name              = "/aws/emr/${var.project_name}"
  retention_in_days = 30

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-emr-logs"
    }
  )
}

# S3 Bootstrap Script (placeholder - users should upload their own)
resource "aws_s3_object" "bootstrap_script" {
  count   = var.create_bootstrap_script ? 1 : 0
  bucket  = var.bootstrap_scripts_bucket
  key     = "bootstrap-emr-sagemaker.sh"
  content = <<-EOF
#!/bin/bash
set -x  # Print commands as they execute
exec > >(tee /var/log/bootstrap-actions.log)
exec 2>&1

echo "========================================="
echo "Starting bootstrap script at $(date)"
echo "========================================="

# Install Python3 if not present
echo "Installing Python3 and pip..."
sudo yum install -y python3 python3-pip || {
    echo "ERROR: Failed to install Python3 and pip"
    exit 1
}

echo "Python3 version: $(python3 --version)"

# Upgrade pip
echo "Upgrading pip..."
sudo python3 -m pip install --upgrade pip || {
    echo "WARNING: Failed to upgrade pip, continuing with existing version"
}

# Install additional Python packages for data science
echo "Installing Python packages: boto3 pandas numpy scikit-learn..."
sudo python3 -m pip install boto3 pandas numpy scikit-learn || {
    echo "ERROR: Failed to install Python packages"
    exit 1
}

echo "Verifying installations..."
python3 -c "import boto3; import pandas; import numpy; import sklearn; print('All packages imported successfully')" || {
    echo "ERROR: Package verification failed"
    exit 1
}

# Note: Livy is automatically installed and configured by EMR via applications list
# and configurations_json in the cluster definition

echo "========================================="
echo "Bootstrap completed successfully at $(date)"
echo "========================================="
exit 0
EOF

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-bootstrap-script"
    }
  )
}

# EMR Managed Scaling Policy (alternative to instance group autoscaling)
resource "aws_emr_managed_scaling_policy" "main" {
  count      = var.enable_managed_scaling ? 1 : 0
  cluster_id = aws_emr_cluster.main.id

  compute_limits {
    unit_type                       = "Instances"
    minimum_capacity_units          = var.managed_scaling_min_capacity
    maximum_capacity_units          = var.managed_scaling_max_capacity
    maximum_ondemand_capacity_units = var.managed_scaling_max_ondemand
    maximum_core_capacity_units     = var.core_instance_count
  }
}
