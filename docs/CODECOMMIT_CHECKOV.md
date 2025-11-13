# CodeCommit Repository with Checkov Security Scanning

## Overview

The infrastructure automatically creates an AWS CodeCommit repository with integrated Checkov security scanning. Every push to the main branch triggers an automated security scan of your infrastructure code using Checkov, a static code analysis tool for infrastructure-as-code.

## What's Included

### 1. CodeCommit Repository
**Repository Name**: `<project-name>-infrastructure`

**Purpose**: Version control for your infrastructure as code (Terraform files)

**Features**:
- Fully managed Git repository in AWS GovCloud
- Integrated with AWS IAM for authentication
- Automatic backup and high availability
- Secure storage of infrastructure code

### 2. CodeBuild Project for Checkov
**Project Name**: `<project-name>-checkov`

**Purpose**: Automated security scanning of infrastructure code

**Scans For**:
- Security misconfigurations
- Compliance violations
- Best practice violations
- Secrets in code
- Hardcoded credentials
- Insecure resource configurations
- Missing encryption
- Overly permissive policies
- And 1000+ other security checks

**Build Environment**:
- Compute: BUILD_GENERAL1_SMALL (2 vCPUs, 3 GB RAM)
- Image: aws/codebuild/standard:7.0
- Platform: Amazon Linux 2023
- Timeout: 15 minutes

### 3. Automated Scanning on Push
**Trigger**: Push to main branch

**Process**:
1. Developer pushes code to CodeCommit
2. EventBridge detects push event
3. CodeBuild project is triggered
4. Checkov scans all Terraform files
5. Results logged to CloudWatch
6. Build passes or fails based on findings

**EventBridge Rule**:
- Monitors: `referenceCreated` and `referenceUpdated` events
- Filters: Only main branch updates
- Action: Triggers CodeBuild project

## Getting Started

### Step 1: Deploy Infrastructure

First, deploy the infrastructure including the CodeCommit repository:

```bash
terraform init
terraform apply
```

This will create:
- CodeCommit repository
- CodeBuild project with Checkov
- IAM roles and permissions
- EventBridge rules for automation
- CloudWatch log groups

### Step 2: Push Code to CodeCommit

Use the provided script to initialize and push your code:

```bash
# Push code to CodeCommit
./scripts/push-to-codecommit.sh us-gov-west-1
```

The script will:
1. Configure git credential helper for CodeCommit
2. Initialize git repository (if needed)
3. Add CodeCommit as a remote
4. Commit all files (respecting .gitignore)
5. Push to main branch
6. Trigger automatic Checkov scan

### Step 3: View Scan Results

After pushing, view the Checkov scan results:

```bash
# Get the latest build ID
aws codebuild list-builds-for-project \
  --project-name $(terraform output -raw codecommit_codebuild_project_name) \
  --region us-gov-west-1 \
  --max-items 1

# View build logs
aws logs tail $(terraform output -raw codecommit_checkov_logs) \
  --follow \
  --region us-gov-west-1
```

Or view in AWS Console:
- Go to CodeBuild → Build projects
- Click on `<project-name>-checkov`
- View build history and logs

## Manual Checkov Scan

To run Checkov manually without pushing to CodeCommit:

```bash
# Install Checkov locally
pip install checkov

# Run scan on your Terraform files
checkov --directory . --framework terraform

# Generate detailed report
checkov \
  --directory . \
  --framework terraform \
  --output cli \
  --output junitxml \
  --output-file-path console,checkov-report.xml
```

## Understanding Checkov Results

### Output Format

Checkov provides a detailed report with:

```
Check: CKV_AWS_19: "Ensure all data stored in S3 bucket is encrypted"
	PASSED for resource: aws_s3_bucket.landing_zone
	File: /modules/s3/main.tf:2-14

Check: CKV_AWS_18: "Ensure S3 bucket has access logging"
	FAILED for resource: aws_s3_bucket.landing_zone
	File: /modules/s3/main.tf:2-14
```

### Severity Levels

- **CRITICAL**: Immediate security risk, must fix
- **HIGH**: Significant security concern, should fix soon
- **MEDIUM**: Best practice violation, fix when possible
- **LOW**: Minor improvement, nice to have

### Common Checks

**S3 Buckets**:
- ✅ Encryption enabled
- ✅ Versioning enabled
- ✅ Public access blocked
- ⚠️ Access logging (optional)
- ⚠️ Lifecycle policies (optional)

**IAM Roles/Policies**:
- ✅ Least privilege principle
- ✅ No wildcard permissions
- ✅ MFA for sensitive operations
- ⚠️ Password policies

**VPC/Networking**:
- ✅ Flow logs enabled
- ✅ Security group rules not overly permissive
- ✅ No default VPC usage
- ⚠️ Network ACLs configured

**Compute Resources**:
- ✅ Encryption at rest
- ✅ Encryption in transit
- ✅ IMDSv2 for EC2
- ⚠️ Monitoring enabled

## Customizing Checkov Scans

### Modify Scan Behavior

Edit `modules/codecommit/buildspec-checkov.yml` to customize:

**Fail build on high severity findings**:
```yaml
build:
  commands:
    - checkov \
        --directory . \
        --framework terraform \
        --hard-fail-on HIGH,CRITICAL
```

**Skip specific checks**:
```yaml
build:
  commands:
    - checkov \
        --directory . \
        --framework terraform \
        --skip-check CKV_AWS_18,CKV_AWS_19
```

**Scan specific directories only**:
```yaml
build:
  commands:
    - checkov \
        --directory modules/ \
        --framework terraform
```

### Suppress Findings in Code

Add inline suppressions in Terraform files:

```hcl
resource "aws_s3_bucket" "example" {
  bucket = "my-bucket"

  # Suppress specific Checkov check
  #checkov:skip=CKV_AWS_18:Access logging not required for this bucket
}
```

## Automated Scanning Configuration

### Enable/Disable Auto-Scanning

In `terraform.tfvars`:

```hcl
# Enable automatic scanning on push to main
codecommit_enable_auto_checkov = true

# Disable automatic scanning (manual only)
codecommit_enable_auto_checkov = false
```

### Trigger Manual Scan

Even with auto-scanning disabled, you can trigger manual scans:

```bash
# Start a build manually
aws codebuild start-build \
  --project-name $(terraform output -raw codecommit_codebuild_project_name) \
  --region us-gov-west-1
```

## Working with CodeCommit

### Clone Repository

```bash
# Configure git credential helper
git config --global credential.helper '!aws codecommit credential-helper $@'
git config --global credential.UseHttpPath true

# Clone the repository
git clone $(terraform output -raw codecommit_clone_url_http)
```

### Daily Workflow

```bash
# Make changes to infrastructure code
vim main.tf

# Commit changes
git add .
git commit -m "Update infrastructure configuration"

# Push to CodeCommit (triggers Checkov scan)
git push codecommit main

# View scan results
aws logs tail $(terraform output -raw codecommit_checkov_logs) \
  --follow \
  --region us-gov-west-1
```

### Create Feature Branches

```bash
# Create feature branch
git checkout -b feature/new-module

# Make changes and commit
git add .
git commit -m "Add new module"

# Push feature branch (no Checkov scan - only main branch)
git push codecommit feature/new-module

# After review, merge to main (triggers Checkov scan)
git checkout main
git merge feature/new-module
git push codecommit main
```

## Security Best Practices

### 1. Never Commit Secrets

Add to `.gitignore`:
```
*.tfvars
*.tfvars.json
credentials.json
*.pem
*.key
*.crt
secrets.yaml
```

### 2. Use Variables for Sensitive Data

Instead of:
```hcl
resource "aws_db_instance" "example" {
  password = "MyPassword123"  # ❌ Never do this
}
```

Use:
```hcl
resource "aws_db_instance" "example" {
  password = var.db_password  # ✅ Use variables
}
```

### 3. Review Scan Results Before Deploy

Always check Checkov results before applying changes:
```bash
# Local scan before push
checkov --directory . --framework terraform

# If clean, push to CodeCommit
git push codecommit main

# Verify scan passed in CodeBuild
aws codebuild batch-get-builds \
  --ids $(aws codebuild list-builds-for-project \
    --project-name $(terraform output -raw codecommit_codebuild_project_name) \
    --max-items 1 \
    --query 'ids[0]' \
    --output text \
    --region us-gov-west-1) \
  --region us-gov-west-1 \
  --query 'builds[0].buildStatus'
```

## Troubleshooting

### Push to CodeCommit Fails

**Error**: `fatal: unable to access 'https://git-codecommit.us-gov-west-1.amazonaws.com/...': The requested URL returned error: 403`

**Solution**:
```bash
# Configure git credential helper
git config --global credential.helper '!aws codecommit credential-helper $@'
git config --global credential.UseHttpPath true

# Verify AWS credentials
aws sts get-caller-identity --region us-gov-west-1

# Ensure IAM user/role has codecommit:GitPush permission
```

### Checkov Scan Fails

**Error**: Build fails with Checkov errors

**Solution**:
1. View the detailed logs in CloudWatch
2. Identify which checks are failing
3. Fix the issues or suppress false positives
4. Re-push to trigger new scan

```bash
# View detailed logs
aws logs tail $(terraform output -raw codecommit_checkov_logs) \
  --since 1h \
  --region us-gov-west-1
```

### EventBridge Not Triggering Scan

**Check EventBridge Rule**:
```bash
# List rules
aws events list-rules \
  --name-prefix $(terraform output -raw project_name) \
  --region us-gov-west-1

# Check rule targets
aws events list-targets-by-rule \
  --rule <rule-name> \
  --region us-gov-west-1
```

**Re-enable Auto-Scanning**:
```hcl
# In terraform.tfvars
codecommit_enable_auto_checkov = true
```

```bash
terraform apply
```

## CloudWatch Logs

### View Real-Time Logs

```bash
# Follow logs in real-time
aws logs tail /aws/codebuild/$(terraform output -raw project_name)-checkov \
  --follow \
  --region us-gov-west-1
```

### Search Logs

```bash
# Search for specific findings
aws logs filter-log-events \
  --log-group-name /aws/codebuild/$(terraform output -raw project_name)-checkov \
  --filter-pattern "FAILED" \
  --region us-gov-west-1
```

### Export Logs

```bash
# Export logs to S3 for analysis
aws logs create-export-task \
  --log-group-name /aws/codebuild/$(terraform output -raw project_name)-checkov \
  --from 1672531200000 \
  --to 1675209600000 \
  --destination $(terraform output -raw ecs_artifacts_bucket_id) \
  --destination-prefix checkov-logs \
  --region us-gov-west-1
```

## Cost Optimization

### Build Costs

**CodeBuild Pricing** (us-gov-west-1):
- BUILD_GENERAL1_SMALL: ~$0.005 per build minute
- Average scan time: 2-5 minutes
- Cost per scan: ~$0.01 - $0.025

**Monthly Estimate**:
- 100 pushes/month: ~$1-2.50/month
- 500 pushes/month: ~$5-12.50/month

**Free Tier**: 100 build minutes/month free

### Reduce Costs

1. **Disable auto-scanning** for development:
   ```hcl
   codecommit_enable_auto_checkov = false
   ```

2. **Use smaller build instance** (if possible)

3. **Scan on schedule** instead of every push:
   - Modify EventBridge rule to run daily/weekly
   - Use CloudWatch Events scheduled expression

## Related Documentation

- [Main README](../README.md) - General infrastructure overview
- [Cleanup Guide](CLEANUP_GUIDE.md) - Destroying infrastructure
- [S3 Bucket Cleanup](S3_BUCKET_CLEANUP.md) - S3 automatic cleanup
- [Checkov Documentation](https://www.checkov.io/documentation.html) - Official Checkov docs
- [AWS CodeCommit](https://docs.aws.amazon.com/codecommit/latest/userguide/welcome.html) - Official AWS docs

## Summary

✅ **Automated security scanning** with Checkov on every push
✅ **Fully managed** Git repository in AWS GovCloud
✅ **Integrated** with EventBridge and CodeBuild
✅ **Comprehensive** coverage of 1000+ security checks
✅ **Easy setup** with provided scripts
✅ **CloudWatch** logging for detailed scan results
✅ **Customizable** scan behavior and suppressions
✅ **Cost-effective** with AWS Free Tier

Your infrastructure code is automatically scanned for security issues, ensuring compliance and best practices are maintained!
