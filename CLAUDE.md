# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Terraform Infrastructure as Code (IaC)** project that deploys a comprehensive machine learning platform on **AWS GovCloud**. The infrastructure includes SageMaker, EMR, ECS, Neptune, and supporting services with private networking, VPC endpoints, and automated security scanning.

**Target Environment**: AWS GovCloud (us-gov-west-1 or us-gov-east-1)
**Terraform Version**: >= 1.5.0
**AWS Provider**: ~> 5.0

## Key Commands

### Terraform Operations
```bash
# Initialize and install modules
terraform init

# Validate configuration
terraform validate

# Format all Terraform files
terraform fmt -recursive

# Review changes before apply
terraform plan

# Apply infrastructure changes
terraform apply

# Destroy all infrastructure (see cleanup procedures in docs/CLEANUP_GUIDE.md)
terraform destroy

# View outputs
terraform output
terraform output -raw <output_name>
```

### Utility Scripts
```bash
# Check available SageMaker instance types for a region
./scripts/check-sagemaker-instance-types.sh us-gov-west-1

# Push code to CodeCommit and trigger Checkov security scan
./scripts/push-to-codecommit.sh us-gov-west-1

# For IAM role-based auth (no IAM user), install git-remote-codecommit first:
pip install git-remote-codecommit
./scripts/push-to-codecommit.sh us-gov-west-1

# Copy SageMaker images from public ECR to private ECR (optional)
./scripts/copy-sagemaker-images.sh us-gov-west-1 <account-id> <project-name>

# Clean up EFS mounts before destroy (if using custom EFS)
./scripts/cleanup-efs.sh

# Check subnet dependencies before destroy
./scripts/check-subnet-dependencies.sh
```

## Architecture

### Module Structure
The infrastructure is organized into 8 independent Terraform modules:

1. **networking** - VPC, subnets, security groups, VPC endpoints, NAT gateway, bastion host
2. **s3** - 4 S3 buckets (landing zone, SageMaker, EMR logs, ECS artifacts)
3. **iam** - IAM roles and policies for all services
4. **sagemaker** - SageMaker Domain, user profiles, spaces, lifecycle configs, ECR repos for custom images
5. **emr** - EMR cluster with spot instances and auto-scaling
6. **ecs** - ECS cluster with ECR repositories
7. **neptune** - Neptune graph database cluster (optional)
8. **codecommit** - CodeCommit repository with automated Checkov security scanning

### Key Architectural Patterns

**Private Networking**: All resources are in private subnets. Internet access is provided via NAT Gateway (optional). AWS service access is through VPC endpoints (S3, SageMaker, EMR, ECS, ECR, etc.).

**Security-First Design**:
- All security groups have `revoke_rules_on_delete = true` to prevent circular dependencies during destroy
- All S3 buckets have `force_destroy = true` for automated cleanup
- VPC endpoints eliminate public internet traffic for AWS services
- IAM roles follow least-privilege principle

**SageMaker Image Strategy**:
- ECR repositories are created for custom SageMaker images (datascience-r, distribution-cpu)
- Domain uses default SageMaker Studio images with lifecycle configs for kernel installation
- Lifecycle config (`r_and_spark_setup`) automatically installs R, PySpark, SparkR, and Neptune kernels
- Images are NOT automatically copied - use `scripts/copy-sagemaker-images.sh` if needed

**Neptune Version Handling**:
- Default version: "1.2.1.0" (GovCloud-compatible)
- Parameter group family is dynamically computed from engine version using regex
- Local variable `neptune_family` extracts major.minor version (e.g., "1.2.1.0" → "neptune1.2")

## Important Configuration Details

### GovCloud-Specific Constraints

**Instance Types**: Not all AWS instance types are available in GovCloud. Always verify:
- SageMaker: Use `ml.t3.medium`, `ml.m5.*`, `ml.c5.*` families
- EMR: Use `m5.*`, `c5.*`, `r5.*` families
- Neptune: Use `db.r5.*` family

**Neptune Versions**: GovCloud supports 1.0, 1.1, 1.2 (not 1.3). The code automatically handles parameter group family extraction.

**Accelerated Compute**: GPU instances (ml.g4dn, ml.p3) have been removed from space templates due to GovCloud limitations.

### Critical Dependencies

**Module Load Order**:
1. S3 buckets must exist before IAM (for bucket ARN references)
2. IAM roles must exist before SageMaker/EMR/ECS
3. Networking must exist before any compute resources
4. ECR repositories are created but images are NOT automatically populated

**Destroy Order Issues**:
- Security groups reference each other - solved with `revoke_rules_on_delete = true`
- VPC endpoints depend on subnets - lifecycle rules prevent dependency cycles
- See `docs/CLEANUP_GUIDE.md` for detailed cleanup procedures

### Variable Configuration

**Required Variables** (no defaults):
- `project_name` - Unique identifier for all resources
- `account_id` - 12-digit AWS account ID

**Critical Networking Variables**:
- `enable_nat_gateway` - Must be `true` for EMR to reach external repos
- `private_subnet_cidrs` - Must have 3 subnets for multi-AZ deployment
- `custom_dns_servers` - For environments with custom DNS requirements

**Feature Flags**:
- `enable_emr = true/false` - EMR cluster
- `enable_neptune = true/false` - Neptune graph database
- `enable_bastion = true/false` - Bastion host for SSH access
- `enable_quicksight = true/false` - QuickSight resources
- `sagemaker_create_notebook_instance = true/false` - Dedicated notebook for EMR connectivity

## Common Modification Patterns

### Adding a New S3 Bucket

1. Add resource to `modules/s3/main.tf` following existing pattern (bucket, versioning, encryption, public access block)
2. Add output to `modules/s3/outputs.tf`
3. If IAM access needed, add bucket ARN variable to `modules/iam/variables.tf` and update relevant policies
4. Pass bucket output from root `main.tf` to IAM module

### Adding a New VPC Endpoint

1. Add to `modules/networking/main.tf` using existing `aws_vpc_endpoint` pattern
2. Set `service_name` to correct AWS service (check GovCloud service names)
3. Set `vpc_endpoint_type = "Interface"` or `"Gateway"` as appropriate
4. Associate with private subnets and VPC endpoint security group
5. Add output to `modules/networking/outputs.tf` if needed by other modules

### Modifying Security Group Rules

1. Edit ingress/egress blocks in `modules/networking/main.tf`
2. Ensure `revoke_rules_on_delete = true` is set (required for clean destroy)
3. Use `lifecycle` blocks to ignore transient changes if needed
4. Test destroy operation after changes to verify no dependency issues

### Adding Instance Types

1. Update local variables in relevant module (e.g., `govcloud_compatible_notebook_types` in `modules/sagemaker/main.tf`)
2. Verify instance type availability in GovCloud using AWS CLI or console
3. Update documentation if adding new compute tier

## Tag Value Constraints

AWS SageMaker Space tags have strict regex validation:
- **No commas** in tag values
- **No special characters** like colons, dashes in certain contexts
- **Keep descriptions simple** - use spaces instead of commas for lists

Example of compliant tags:
```hcl
tags = {
  Name        = "${var.project_name}-resource-name"
  Type        = "GeneralPurpose"
  Description = "Template for CPU workloads with R Spark and Neptune"  # No commas!
}
```

## Testing and Validation

### Pre-Apply Validation
```bash
# Format check
terraform fmt -check -recursive

# Validate configuration
terraform validate

# Generate plan
terraform plan -out=tfplan

# Review plan for unexpected changes
terraform show tfplan
```

### Post-Apply Verification
```bash
# Check all outputs
terraform output

# Verify critical resources
aws sagemaker list-domains --region us-gov-west-1
aws emr list-clusters --active --region us-gov-west-1
aws s3 ls | grep <project-name>
```

## Troubleshooting

### Common Issues

**"Module not installed"**: Run `terraform init` to download module dependencies

**Tag regex validation errors**: Remove commas and special characters from tag values

**Image version errors**: SageMaker Image Version resources reference ECR images that don't exist yet. The code now uses default SageMaker images with lifecycle configs instead.

**Neptune version unavailable**: Change `neptune_engine_version` to GovCloud-supported version (1.0.x, 1.1.x, 1.2.x)

**Circular dependency during destroy**: Check security group references and subnet dependencies. Use lifecycle `ignore_changes` or `revoke_rules_on_delete` as needed.

**S3 bucket not empty on destroy**: All buckets have `force_destroy = true` which automatically empties buckets before deletion

**Lifecycle config execution failed with exit code 2**: The lifecycle configuration script (which installs R, Spark, and Neptune kernels) has been updated to handle errors gracefully. The script now:
- Uses `set +e` instead of `set -e` to continue on non-critical errors
- Logs all installation attempts to `/tmp/*.log` files
- Always exits with code 0 to allow kernel to start even if some packages fail
- Falls back to user-level R kernel installation if system-level fails
- Provides warnings for failed installations instead of hard failures

To debug lifecycle config issues in SageMaker Studio, check the logs in:
- `/tmp/conda-install.log` - Conda package installation
- `/tmp/r-kernel-install.log` - R kernel registration
- `/tmp/r-packages.log` - Additional R packages
- `/tmp/pip-install.log` - PySpark installation
- `/tmp/sparkmagic-install.log` - Sparkmagic installation
- `/tmp/neptune-install.log` - Neptune libraries

**QuickSight permissions length error (1-256 range)**: If you get an error about permissions length when deploying QuickSight resources, it's because the `quicksight_user_arn` variable is empty. The QuickSight resources now use dynamic permissions blocks that skip permission configuration if no user ARN is provided. You can:
1. Leave `quicksight_user_arn` empty (default) - resources will be created without user permissions
2. Add permissions later via AWS Console or AWS CLI
3. Or set `quicksight_user_arn` in terraform.tfvars to your QuickSight user ARN (format: `arn:aws:quicksight:region:account-id:user/namespace/username`)

**QuickSight unable to access manifest file**: An S3 bucket policy has been added to grant QuickSight service and the QuickSight IAM role access to read the manifest file and data from the QuickSight S3 bucket. This policy allows:
- QuickSight service principal to access bucket contents
- QuickSight IAM role to read objects and list buckets
If you still get access errors, verify:
1. The manifest file exists at `s3://<project>-quicksight-<account-id>/manifests/default-manifest.json`
2. The QuickSight IAM role has been created: `<project>-quicksight-role`
3. Your QuickSight account subscription is active in the region

**CodeCommit authentication prompts for credentials**: If you don't have an IAM user (using IAM roles, SSO, or federated auth), you'll be prompted for credentials when pushing to CodeCommit. Solutions:

1. **Install git-remote-codecommit** (Recommended for role-based auth):
   ```bash
   pip install git-remote-codecommit
   ./scripts/push-to-codecommit.sh us-gov-west-1
   ```
   The script will automatically detect and use `codecommit://` protocol instead of `https://`

2. **Verify AWS credentials work**:
   ```bash
   aws sts get-caller-identity --region us-gov-west-1
   ```
   If this fails, configure AWS CLI: `aws configure`

3. **Check IAM permissions** - Your role/user needs:
   - `codecommit:GitPull`
   - `codecommit:GitPush`

4. **Manual git-remote-codecommit usage**:
   ```bash
   # After installing git-remote-codecommit
   git clone codecommit::us-gov-west-1://your-repo-name

   # Or add as remote
   git remote add codecommit codecommit::us-gov-west-1://your-repo-name
   git push codecommit main
   ```

### Debug Commands
```bash
# Enable Terraform debug logging
export TF_LOG=DEBUG
terraform plan

# Check specific module outputs
terraform output -module=networking

# Validate specific file
terraform validate -json | jq
```

## Documentation

**Key Documentation Files**:
- `README.md` - Complete deployment guide and feature overview
- `DEPLOYMENT_CHECKLIST.md` - Step-by-step deployment validation
- `docs/CLEANUP_GUIDE.md` - Automated cleanup features and destroy procedures
- `docs/CODECOMMIT_CHECKOV.md` - Security scanning setup and usage
- `docs/SAGEMAKER_SPACE_TEMPLATES.md` - SageMaker space configuration
- `docs/NEPTUNE_SETUP.md` - Neptune database setup and connectivity
- `docs/S3_BUCKET_CLEANUP.md` - S3 bucket cleanup details

## State Management

**Local State**: By default, state is stored locally in `terraform.tfstate`

**Remote State** (Recommended for production):
Uncomment and configure the S3 backend in `main.tf`:
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

Then run `terraform init -migrate-state` to move local state to S3.

## Code Style

- Use 2-space indentation (already configured in .editorconfig if present)
- Run `terraform fmt -recursive` before committing
- Use descriptive resource names: `${var.project_name}-<resource-type>-<identifier>`
- Add comments for complex logic, especially regex or dynamic blocks
- Always include `tags` merge pattern for resource tagging
- Use `count` or `for_each` for conditional resources, not `if` statements
