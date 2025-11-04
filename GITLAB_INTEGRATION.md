# GitLab Integration Guide

This guide explains how to integrate GitLab with your AWS GovCloud ML Platform for Docker container management and CI/CD workflows.

## Overview

The infrastructure includes:
- ECR repositories for storing Docker images
- ECS cluster for running containerized workloads
- Secrets Manager for storing GitLab credentials
- IAM roles with appropriate permissions

## Setup Instructions

### 1. Configure GitLab Credentials

After deploying the infrastructure, update the GitLab credentials in AWS Secrets Manager:

```bash
# Get the secret ARN from Terraform outputs
terraform output gitlab_credentials_secret_arn

# Update the secret with your GitLab credentials
aws secretsmanager update-secret \
  --secret-id <secret-arn> \
  --secret-string '{
    "gitlab_url": "https://gitlab.com",
    "gitlab_token": "your-gitlab-access-token",
    "gitlab_project_id": "your-project-id"
  }' \
  --region us-gov-west-1
```

### 2. Create GitLab Access Token

1. Log in to your GitLab instance
2. Go to **Settings** > **Access Tokens**
3. Create a new token with the following scopes:
   - `api` - Full API access
   - `read_repository` - Read repository
   - `write_repository` - Write repository
   - `read_registry` - Read container registry
   - `write_registry` - Write container registry

4. Copy the token (you won't be able to see it again)

### 3. Configure GitLab CI/CD

Create a `.gitlab-ci.yml` file in your GitLab project:

```yaml
variables:
  AWS_DEFAULT_REGION: us-gov-west-1
  ECR_REGISTRY: <your-account-id>.dkr.ecr.us-gov-west-1.amazonaws.com
  ECR_REPOSITORY: govcloud-ml-platform-ml-workload
  IMAGE_TAG: $CI_COMMIT_SHORT_SHA

stages:
  - build
  - deploy

before_script:
  - apt-get update -y
  - apt-get install -y python3-pip
  - pip3 install awscli
  - aws --version

build:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  script:
    # Login to ECR
    - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY

    # Build Docker image
    - docker build -t $ECR_REPOSITORY:$IMAGE_TAG .
    - docker tag $ECR_REPOSITORY:$IMAGE_TAG $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
    - docker tag $ECR_REPOSITORY:$IMAGE_TAG $ECR_REGISTRY/$ECR_REPOSITORY:latest

    # Push to ECR
    - docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
    - docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest
  only:
    - main
    - develop

deploy:
  stage: deploy
  image: python:3.9
  script:
    # Update ECS service to use new image
    - pip install boto3
    - python deploy_ecs.py
  only:
    - main
  dependencies:
    - build
```

### 4. Create ECS Deployment Script

Create `deploy_ecs.py` in your GitLab project:

```python
#!/usr/bin/env python3
import boto3
import os
import json

# Configuration
region = os.environ.get('AWS_DEFAULT_REGION', 'us-gov-west-1')
cluster_name = os.environ.get('ECS_CLUSTER_NAME', 'govcloud-ml-platform-ecs-cluster')
service_name = os.environ.get('ECS_SERVICE_NAME', 'govcloud-ml-platform-ml-service')
family = os.environ.get('TASK_FAMILY', 'govcloud-ml-platform-ml-workload')
image = os.environ.get('IMAGE_URI')

# Initialize clients
ecs = boto3.client('ecs', region_name=region)

def update_service():
    """Update ECS service to use new task definition"""

    # Get current task definition
    response = ecs.describe_task_definition(taskDefinition=family)
    task_def = response['taskDefinition']

    # Update container image
    for container in task_def['containerDefinitions']:
        if container['name'] == 'ml-container':
            container['image'] = image

    # Register new task definition
    new_task_def = ecs.register_task_definition(
        family=family,
        taskRoleArn=task_def['taskRoleArn'],
        executionRoleArn=task_def['executionRoleArn'],
        networkMode=task_def['networkMode'],
        containerDefinitions=task_def['containerDefinitions'],
        requiresCompatibilities=task_def['requiresCompatibilities'],
        cpu=task_def['cpu'],
        memory=task_def['memory']
    )

    new_task_def_arn = new_task_def['taskDefinition']['taskDefinitionArn']
    print(f"Registered new task definition: {new_task_def_arn}")

    # Update service
    response = ecs.update_service(
        cluster=cluster_name,
        service=service_name,
        taskDefinition=new_task_def_arn,
        forceNewDeployment=True
    )

    print(f"Updated service: {service_name}")
    print(f"Deployment ID: {response['service']['deployments'][0]['id']}")

if __name__ == '__main__':
    if not image:
        print("ERROR: IMAGE_URI environment variable not set")
        exit(1)

    update_service()
```

### 5. Configure GitLab Variables

In your GitLab project, go to **Settings** > **CI/CD** > **Variables** and add:

| Variable | Value | Protected | Masked |
|----------|-------|-----------|--------|
| `AWS_ACCESS_KEY_ID` | Your AWS access key | ✓ | ✓ |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret key | ✓ | ✓ |
| `AWS_DEFAULT_REGION` | us-gov-west-1 | ✗ | ✗ |
| `ECS_CLUSTER_NAME` | govcloud-ml-platform-ecs-cluster | ✗ | ✗ |
| `ECS_SERVICE_NAME` | govcloud-ml-platform-ml-service | ✗ | ✗ |

### 6. Docker Image Structure

Example `Dockerfile` for ML workloads:

```dockerfile
FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV AWS_DEFAULT_REGION=us-gov-west-1

# Run application
CMD ["python", "main.py"]
```

Example `requirements.txt`:

```
boto3>=1.28.0
pandas>=2.0.0
numpy>=1.24.0
scikit-learn>=1.3.0
sagemaker>=2.180.0
```

### 7. Example ML Workload

Create `main.py`:

```python
#!/usr/bin/env python3
import boto3
import pandas as pd
import logging
import os

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# AWS Configuration
region = os.environ.get('AWS_DEFAULT_REGION', 'us-gov-west-1')
landing_zone_bucket = os.environ.get('S3_LANDING_ZONE_BUCKET')

# Initialize clients
s3 = boto3.client('s3', region_name=region)
sagemaker = boto3.client('sagemaker', region_name=region)

def process_data():
    """Process data from landing zone"""
    logger.info(f"Processing data from bucket: {landing_zone_bucket}")

    # Download data from S3
    s3.download_file(
        landing_zone_bucket,
        'raw/input_data.csv',
        '/tmp/input_data.csv'
    )

    # Process data
    df = pd.read_csv('/tmp/input_data.csv')
    logger.info(f"Loaded {len(df)} rows")

    # Perform transformations
    processed_df = df.dropna()

    # Upload processed data
    processed_df.to_csv('/tmp/processed_data.csv', index=False)
    s3.upload_file(
        '/tmp/processed_data.csv',
        landing_zone_bucket,
        'processed/processed_data.csv'
    )

    logger.info("Data processing complete")

if __name__ == '__main__':
    try:
        process_data()
    except Exception as e:
        logger.error(f"Error processing data: {e}")
        raise
```

## GitLab Runner Configuration

### Option 1: Use GitLab.com Shared Runners

If using GitLab.com, shared runners are available by default. Ensure your AWS credentials are properly configured in CI/CD variables.

### Option 2: Self-Hosted GitLab Runner in AWS

For better performance and security, deploy a GitLab Runner in your VPC:

1. Launch an EC2 instance in a private subnet
2. Install GitLab Runner:

```bash
# Download the binary
sudo curl -L --output /usr/local/bin/gitlab-runner https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-linux-amd64

# Give it permissions to execute
sudo chmod +x /usr/local/bin/gitlab-runner

# Create a GitLab CI user
sudo useradd --comment 'GitLab Runner' --create-home gitlab-runner --shell /bin/bash

# Install and run as service
sudo gitlab-runner install --user=gitlab-runner --working-directory=/home/gitlab-runner
sudo gitlab-runner start
```

3. Register the runner:

```bash
sudo gitlab-runner register \
  --non-interactive \
  --url "https://gitlab.com/" \
  --registration-token "YOUR_REGISTRATION_TOKEN" \
  --executor "docker" \
  --docker-image docker:latest \
  --description "aws-govcloud-runner" \
  --docker-privileged
```

## Security Best Practices

### 1. IAM Roles for Service Accounts

Instead of using access keys, use IAM roles:

```hcl
# Add to your Terraform configuration
resource "aws_iam_role" "gitlab_runner" {
  name = "${var.project_name}-gitlab-runner-role"

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
}

resource "aws_iam_instance_profile" "gitlab_runner" {
  name = "${var.project_name}-gitlab-runner-profile"
  role = aws_iam_role.gitlab_runner.name
}
```

### 2. Least Privilege Permissions

Grant only necessary permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecs:UpdateService",
        "ecs:DescribeServices",
        "ecs:DescribeTaskDefinition",
        "ecs:RegisterTaskDefinition"
      ],
      "Resource": "*"
    }
  ]
}
```

### 3. Secret Rotation

Regularly rotate GitLab tokens and AWS credentials:

```bash
# Rotate GitLab token monthly
aws secretsmanager rotate-secret \
  --secret-id <secret-arn> \
  --rotation-lambda-arn <lambda-arn> \
  --rotation-rules AutomaticallyAfterDays=30
```

## Monitoring and Debugging

### View GitLab CI/CD Logs

1. Go to your GitLab project
2. Navigate to **CI/CD** > **Pipelines**
3. Click on the pipeline you want to inspect
4. View logs for each job

### View ECS Deployment Status

```bash
# Describe ECS service
aws ecs describe-services \
  --cluster govcloud-ml-platform-ecs-cluster \
  --services govcloud-ml-platform-ml-service \
  --region us-gov-west-1

# View CloudWatch logs
aws logs tail /aws/ecs/govcloud-ml-platform \
  --follow \
  --region us-gov-west-1
```

### Debug Docker Build Issues

```bash
# Test Docker build locally
docker build -t test-image .

# Test Docker run locally
docker run --rm test-image

# Push manually to ECR
aws ecr get-login-password --region us-gov-west-1 | \
  docker login --username AWS --password-stdin <ecr-url>
docker push <ecr-url>/ml-workload:latest
```

## Advanced Integration Patterns

### Multi-Environment Deployments

Use GitLab environments for dev/staging/prod:

```yaml
deploy-dev:
  stage: deploy
  script:
    - python deploy_ecs.py
  environment:
    name: development
  only:
    - develop

deploy-prod:
  stage: deploy
  script:
    - python deploy_ecs.py
  environment:
    name: production
  only:
    - main
  when: manual
```

### Automated Testing

Add testing stage before deployment:

```yaml
test:
  stage: test
  script:
    - pip install pytest
    - pytest tests/
  coverage: '/TOTAL.*\s+(\d+%)$/'
```

### Blue-Green Deployments

Implement blue-green deployments for zero-downtime:

```python
def blue_green_deploy():
    # Create new task definition (green)
    new_task_def = register_task_definition()

    # Create new service (green)
    create_service(new_task_def)

    # Wait for health checks
    wait_for_healthy()

    # Switch traffic
    update_load_balancer()

    # Decommission old service (blue)
    delete_old_service()
```

## Troubleshooting

### Common Issues

1. **ECR Authentication Failed**
   - Verify AWS credentials in GitLab CI/CD variables
   - Check IAM permissions for ECR access

2. **ECS Service Update Failed**
   - Verify task definition is valid
   - Check ECS service exists and is active
   - Review IAM role permissions

3. **Docker Build Timeout**
   - Optimize Dockerfile (use multi-stage builds)
   - Increase GitLab runner timeout
   - Use Docker layer caching

## References

- [GitLab CI/CD Documentation](https://docs.gitlab.com/ee/ci/)
- [AWS ECR Documentation](https://docs.aws.amazon.com/ecr/)
- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [GitLab Runner Documentation](https://docs.gitlab.com/runner/)
