# AWS GovCloud ML Platform - Terraform Infrastructure

This Terraform Infrastructure as Code (IaC) project deploys a comprehensive machine learning platform on AWS GovCloud with the following components:

- **Amazon SageMaker** with Studio and domain configuration
- **Amazon EMR** with spot instance support for distributed data processing
- **Amazon ECS** for containerized workloads
- **Private VPC** with optional NAT Gateway for secure internet access
- **S3 Landing Zone** for data storage

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS GovCloud VPC                         │
│                       (Private Subnets Only)                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────┐      ┌──────────────────┐                │
│  │  SageMaker       │◄────►│  EMR Cluster     │                │
│  │  Studio Domain   │      │  - Master Node   │                │
│  │  - Notebooks     │      │  - Core Nodes    │                │
│  │  - Model Registry│      │  - Spot Task     │                │
│  └────────┬─────────┘      │    Nodes         │                │
│           │                └────────┬─────────┘                │
│           │                         │                            │
│           │                         │                            │
│  ┌────────▼────────────────────────▼──────┐                    │
│  │         S3 Landing Zone                 │                    │
│  │  - Raw Data                             │                    │
│  │  - Processed Data                       │                    │
│  │  - Model Artifacts                      │                    │
│  └─────────────────────────────────────────┘                    │
│                         │                                         │
│           ┌─────────────▼───────────────┐                       │
│           │  ECS Cluster (Fargate)      │                       │
│           │  - ML Workloads             │                       │
│           │  - Data Processing          │                       │
│           │  - Model Serving            │                       │
│           └─────────────────────────────┘                       │
│                         │                                         │
│  ┌──────────────────────▼─────────────────────────┐            │
│  │  VPC Endpoints (Private AWS Service Access)     │            │
│  │  - S3, SageMaker, EMR, ECS, ECR, CloudWatch     │            │
│  └──────────────────────────────────────────────────┘            │
└─────────────────────────────────────────────────────────────────┘
```

## Features

### 1. Private Networking
- VPC with private subnets and optional NAT Gateway for internet access
- VPC endpoints for all AWS services (S3, SageMaker, EMR, ECS, ECR, CloudWatch, etc.)
- Security groups configured for least privilege access
- All inter-service communication through private networking
- Optional bastion host for SSH access to EMR clusters
- Configurable custom DNS servers via DHCP options

### 2. Amazon SageMaker
- SageMaker Domain and Studio setup
- Pre-configured for EMR connectivity via Livy/SparkMagic
- **Space templates with R and RSpark kernels** for statistical computing and distributed R workloads
- **Support for both general purpose CPU and accelerated compute (GPU) instances**
- User profiles with appropriate IAM roles
- Model Registry for versioning
- Optional Feature Store for ML feature management
- Optional Notebook instances with configurable internet access (via NAT Gateway or direct)

### 3. Amazon EMR
- Base EMR cluster with configurable instance types
- Support for spot instances on task nodes for cost optimization
- Auto-scaling configuration for dynamic workload management
- Pre-configured with Spark, Livy, Hive, and JupyterHub
- Bootstrap scripts for SageMaker integration
- S3 integration for data access in landing zone

### 4. Amazon ECS
- ECS Cluster with Fargate support
- ECR repositories for Docker images
- Sample task definitions and services
- Secrets Manager for credential management
- Optional scheduled tasks for recurring workloads

### 5. S3 Storage
- Landing zone bucket for raw and processed data
- SageMaker bucket for model artifacts
- EMR logs bucket with lifecycle policies
- ECS artifacts bucket for container configurations
- Server-side encryption enabled on all buckets
- Versioning enabled for data protection

## Prerequisites

- Terraform >= 1.5.0
- AWS CLI configured with GovCloud credentials
- Appropriate IAM permissions to create resources
- AWS GovCloud account access

## Deployment Instructions

### 1. Clone or Initialize the Repository

```bash
cd aws-govcloud-ml-platform
```

### 2. Configure Variables

Copy the example variables file and customize it:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your specific configuration:

```hcl
project_name = "my-ml-platform"
environment  = "dev"
aws_region   = "us-gov-west-1"

# Update other variables as needed
```

### 3. Configure Backend (Optional but Recommended)

For production deployments, configure remote state storage in `main.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "govcloud-ml-platform/terraform.tfstate"
    region         = "us-gov-west-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

### 4. Initialize Terraform

```bash
terraform init
```

### 5. Review the Plan

```bash
terraform plan
```

Review the resources that will be created.

### 6. Deploy the Infrastructure

```bash
terraform apply
```

Type `yes` when prompted to confirm the deployment.

### 7. Capture Outputs

After successful deployment, Terraform will display important outputs:

```bash
terraform output
```

Save these outputs for accessing your infrastructure.

## Post-Deployment Configuration

### 1. Access SageMaker Studio

1. Navigate to the SageMaker console in AWS GovCloud
2. Open SageMaker Studio using the domain URL from outputs
3. Create a new user profile or use the default profile
4. Launch Studio

### 2. Use SageMaker Studio Spaces

SageMaker Studio includes pre-configured spaces with multiple kernels:

**Available Kernels:**
- **Python** (Data Science) - Standard Python with scientific libraries
- **R** - Statistical computing and data analysis
- **RSpark** - R with Spark for distributed computing on EMR
- **PySpark** - Python with Spark integration

**Creating a Space:**
1. Navigate to SageMaker Studio in AWS Console
2. Click **Spaces** → **Create space**
3. Choose a template:
   - **general-purpose-template** - CPU instances (ml.m5.*, ml.c5.*, ml.t3.*)
   - **accelerated-compute-template** - GPU instances (ml.g4dn.*, ml.g5.*, ml.p3.*)
4. Select appropriate instance type for your workload
5. Launch and start coding

**Using R with Spark on EMR:**
```r
library(SparkR)

# Read data from S3 using Spark
df <- read.df("s3://your-bucket/data/dataset.csv",
              source = "csv", header = "true")

# Distributed processing
result <- df %>%
  filter(df$value > 100) %>%
  groupBy(df$category) %>%
  agg(avg(df$amount))

# Collect to local R dataframe
local_data <- collect(result)
```

For detailed usage, see [SageMaker Spaces with R and RSpark Kernels](docs/SAGEMAKER_SPACES_KERNELS.md)

### 3. Push Docker Images to ECR

```bash
# Get ECR login
aws ecr get-login-password --region us-gov-west-1 | \
  docker login --username AWS --password-stdin <ecr-url>

# Build and tag your image
docker build -t ml-workload .
docker tag ml-workload:latest <ecr-url>/ml-workload:latest

# Push to ECR
docker push <ecr-url>/ml-workload:latest
```

### 5. Upload Data to Landing Zone

```bash
aws s3 cp local-data/ s3://<landing-zone-bucket>/raw/ --recursive
```

## Destroying Infrastructure

To properly destroy the infrastructure and avoid common errors, follow the cleanup procedure in [docs/CLEANUP_GUIDE.md](docs/CLEANUP_GUIDE.md).

**Quick cleanup:**
```bash
# Step 1: Clean up SageMaker apps and spaces first
./scripts/cleanup-sagemaker.sh us-gov-west-1 $(terraform output -raw sagemaker_domain_id)

# Step 2: Wait for cleanup to complete (apps show Status='Deleted')
aws sagemaker list-apps --domain-id-equals $(terraform output -raw sagemaker_domain_id) --region us-gov-west-1

# Step 3: Destroy infrastructure
terraform destroy
```

**Common destroy errors and solutions:**
- **SageMaker user profile error**: Run the cleanup script to delete apps and spaces first
- **Subnet dependency error**: Check for attached network interfaces with `./scripts/check-subnet-dependencies.sh`
- **EMR security group error**: Wait 3-5 minutes after EMR termination for network interfaces to be released
- For detailed troubleshooting, see [docs/CLEANUP_GUIDE.md](docs/CLEANUP_GUIDE.md)

**Troubleshooting subnet deletion:**
```bash
# Identify what's blocking subnet deletion
./scripts/check-subnet-dependencies.sh us-gov-west-1 <project-name>

# Destroy compute resources first, then networking
terraform destroy -target=module.emr -target=module.sagemaker -target=module.ecs
sleep 300  # Wait for ENIs to be released
terraform destroy
```

## Configuration Options

### EMR Spot Instances

The infrastructure supports spot instances for cost optimization:

- **Task Nodes**: Configured for spot instances by default
- **Core Nodes**: Can be configured for spot (set `emr_core_use_spot = true`)
- **Auto-scaling**: Task nodes auto-scale based on YARN memory utilization

### SageMaker Features

Optional SageMaker features can be enabled:

- **Feature Store**: Set `sagemaker_enable_feature_store = true`
- **Notebook Instance**: Set `sagemaker_create_notebook_instance = true`
- **Space Templates**: Set `sagemaker_create_space_templates = true` (default)
  - Creates templates with R and RSpark kernels
  - Supports both CPU (general purpose) and GPU (accelerated compute) instances

**Available Space Instance Types:**

General Purpose (CPU):
```hcl
# Light development
ml.t3.medium, ml.t3.large, ml.t3.xlarge

# Standard workloads
ml.m5.large, ml.m5.xlarge, ml.m5.2xlarge, ml.m5.4xlarge

# Compute optimized
ml.c5.large, ml.c5.xlarge, ml.c5.2xlarge
```

Accelerated Compute (GPU):
```hcl
# Development/Testing
ml.g4dn.xlarge, ml.g4dn.2xlarge

# Production Training
ml.g5.xlarge, ml.g5.2xlarge, ml.g5.4xlarge

# Large-scale Deep Learning
ml.p3.2xlarge, ml.p3.8xlarge, ml.p3.16xlarge
```

See [docs/SAGEMAKER_SPACES_KERNELS.md](docs/SAGEMAKER_SPACES_KERNELS.md) for detailed usage guide.

### ECS Scheduled Tasks

Enable scheduled ECS tasks for recurring workloads:

```hcl
ecs_enable_scheduled_tasks = true
ecs_schedule_expression    = "rate(1 hour)"  # or cron expression
```

## Security Considerations

### Network Security
- All resources are deployed in private subnets
- No internet gateway or NAT gateway
- VPC endpoints for all AWS service access
- Security groups follow least privilege principle

### Data Security
- All S3 buckets have encryption enabled
- Public access blocked on all S3 buckets
- Secrets stored in AWS Secrets Manager
- IAM roles follow least privilege principle

### Compliance
- Designed for AWS GovCloud deployment
- FedRAMP compliant architecture
- Audit logging via CloudWatch

## Cost Optimization

### Spot Instances
- EMR task nodes use spot instances by default
- ECS can use Fargate Spot for additional savings
- Configure `core_use_spot = true` for maximum savings

### Auto-scaling
- EMR auto-scaling reduces costs during low utilization
- ECS services can scale to zero when not in use

### Lifecycle Policies
- EMR logs automatically expire after 90 days
- ECR images are cleaned up automatically

## Monitoring and Logging

All services send logs to CloudWatch:
- SageMaker: `/aws/sagemaker/*`
- EMR: `/aws/emr/<project-name>`
- ECS: `/aws/ecs/<project-name>`

## Troubleshooting

### EMR Connection Issues
- Verify security groups allow traffic between SageMaker and EMR
- Check EMR master node is running: `aws emr describe-cluster --cluster-id <cluster-id>`
- Verify Livy is running on port 8998

### SageMaker Domain Issues
- Ensure VPC endpoints are created successfully
- Check IAM roles have correct permissions
- Verify subnets are in different AZs

### ECS Task Failures
- Check CloudWatch logs for error messages
- Verify task execution role has ECR permissions
- Ensure VPC endpoints for ECR are working

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

⚠️ **Warning**: This will delete all resources including S3 buckets. Ensure you have backed up any important data.

## Module Structure

```
aws-govcloud-ml-platform/
├── main.tf                 # Root module
├── variables.tf            # Root variables
├── outputs.tf              # Root outputs
├── terraform.tfvars.example # Example configuration
├── README.md               # This file
└── modules/
    ├── networking/         # VPC, subnets, security groups, VPC endpoints
    ├── iam/                # IAM roles and policies
    ├── s3/                 # S3 buckets
    ├── sagemaker/          # SageMaker domain and Studio
    ├── emr/                # EMR cluster configuration
    └── ecs/                # ECS cluster and services
```

## Contributing

To extend this infrastructure:

1. Add new modules in the `modules/` directory
2. Update root `main.tf` to include new modules
3. Add variables to `variables.tf`
4. Document changes in this README

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review AWS GovCloud documentation
3. Check Terraform AWS provider documentation

## License

This project is provided as-is for use in AWS GovCloud environments.

## References

- [AWS GovCloud Documentation](https://docs.aws.amazon.com/govcloud-us/)
- [SageMaker Developer Guide](https://docs.aws.amazon.com/sagemaker/)
- [EMR Developer Guide](https://docs.aws.amazon.com/emr/)
- [ECS Developer Guide](https://docs.aws.amazon.com/ecs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
