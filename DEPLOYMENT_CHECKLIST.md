# AWS GovCloud ML Platform - Deployment Checklist

Use this checklist to ensure a successful deployment of your AWS GovCloud ML Platform.

## Pre-Deployment Checklist

### AWS Account Setup
- [ ] AWS GovCloud account is active and accessible
- [ ] AWS CLI is installed and configured for GovCloud
  ```bash
  aws configure --profile govcloud
  # Set region to us-gov-west-1 or us-gov-east-1
  ```
- [ ] AWS credentials have necessary permissions to create:
  - [ ] VPC and networking resources
  - [ ] IAM roles and policies
  - [ ] S3 buckets
  - [ ] SageMaker domains
  - [ ] EMR clusters
  - [ ] ECS clusters
  - [ ] ECR repositories
  - [ ] Secrets Manager secrets
  - [ ] CloudWatch log groups

### Terraform Setup
- [ ] Terraform >= 1.5.0 is installed
  ```bash
  terraform version
  ```
- [ ] Terraform AWS provider is available
- [ ] Backend for Terraform state is configured (recommended for production)

### Configuration Files
- [ ] `terraform.tfvars` file is created from `terraform.tfvars.example`
- [ ] Project name is set and unique
- [ ] AWS region is set to GovCloud region (us-gov-west-1 or us-gov-east-1)
- [ ] VPC CIDR does not conflict with existing networks
- [ ] Instance types are available in chosen region
- [ ] All required variables are set

### Cost Considerations
- [ ] Reviewed instance types and quantities
- [ ] Understood cost implications of:
  - [ ] SageMaker Studio instances
  - [ ] EMR cluster (on-demand vs spot)
  - [ ] ECS Fargate tasks
  - [ ] Data transfer and storage
- [ ] Budget alerts are configured in AWS Billing

## Deployment Steps

### Step 1: Initialize Terraform
- [ ] Navigate to project directory
  ```bash
  cd aws-govcloud-ml-platform
  ```
- [ ] Initialize Terraform
  ```bash
  terraform init
  ```
- [ ] Verify initialization successful
- [ ] Review `.terraform` directory creation

### Step 2: Validate Configuration
- [ ] Validate Terraform configuration
  ```bash
  terraform validate
  ```
- [ ] Fix any validation errors
- [ ] Run Terraform format (optional)
  ```bash
  terraform fmt -recursive
  ```

### Step 3: Review Plan
- [ ] Generate Terraform plan
  ```bash
  terraform plan -out=tfplan
  ```
- [ ] Review all resources to be created
- [ ] Verify resource counts match expectations
  - [ ] VPC: 1
  - [ ] Subnets: 3 private subnets
  - [ ] Security Groups: 6 (VPC endpoints, SageMaker, EMR master/slave/service, ECS)
  - [ ] VPC Endpoints: ~15 endpoints
  - [ ] S3 Buckets: 4 (landing zone, SageMaker, EMR logs, ECS artifacts)
  - [ ] IAM Roles: 8+ roles
  - [ ] SageMaker Domain: 1
  - [ ] EMR Cluster: 1 (if enabled)
  - [ ] ECS Cluster: 1
  - [ ] ECR Repositories: 3 (or as configured)
- [ ] Check for any unexpected changes or deletions

### Step 4: Apply Configuration
- [ ] Apply Terraform configuration
  ```bash
  terraform apply tfplan
  ```
- [ ] Monitor apply progress (may take 20-30 minutes)
- [ ] Wait for successful completion
- [ ] Note any errors or warnings

### Step 5: Verify Deployment
- [ ] Check Terraform outputs
  ```bash
  terraform output
  ```
- [ ] Save important outputs:
  - [ ] VPC ID
  - [ ] SageMaker Domain URL
  - [ ] EMR Cluster ID
  - [ ] ECS Cluster name
  - [ ] S3 bucket names
  - [ ] ECR repository URLs

### Step 6: Verify Resources in AWS Console
- [ ] VPC and Networking
  - [ ] VPC exists with correct CIDR
  - [ ] Private subnets created in multiple AZs
  - [ ] Route tables configured
  - [ ] VPC endpoints are active
  - [ ] Security groups have correct rules

- [ ] S3 Buckets
  - [ ] All 4 buckets created
  - [ ] Encryption enabled
  - [ ] Versioning enabled
  - [ ] Public access blocked

- [ ] IAM Roles
  - [ ] All roles created
  - [ ] Trust relationships correct
  - [ ] Policies attached

- [ ] SageMaker
  - [ ] Domain is active
  - [ ] User profile exists
  - [ ] Execution role attached

- [ ] EMR (if enabled)
  - [ ] Cluster is running or starting
  - [ ] Master and core nodes provisioning
  - [ ] Logs being written to S3

- [ ] ECS
  - [ ] Cluster is active
  - [ ] ECR repositories created
  - [ ] CloudWatch log groups created

## Post-Deployment Configuration

### Access SageMaker Studio
- [ ] Navigate to SageMaker console
- [ ] Open SageMaker Studio domain
- [ ] Select user profile
- [ ] Launch Studio
- [ ] Verify Studio loads successfully
- [ ] Create test notebook
- [ ] Verify kernel launches

### Test EMR Connectivity (if enabled)
- [ ] Note EMR master node DNS from outputs
- [ ] In SageMaker Studio, create new notebook
- [ ] Select SparkMagic kernel
- [ ] Test connection to EMR
  ```python
  %%spark
  sc.version
  ```
- [ ] Verify Spark connection successful
- [ ] Run simple Spark job

### Configure ECS and ECR
- [ ] Authenticate Docker to ECR
  ```bash
  aws ecr get-login-password --region us-gov-west-1 | \
    docker login --username AWS --password-stdin <ecr-url>
  ```
- [ ] Build sample Docker image
- [ ] Tag and push to ECR
- [ ] Verify image in ECR repository
- [ ] Test ECS task deployment

### Upload Test Data
- [ ] Create test dataset
- [ ] Upload to landing zone bucket
  ```bash
  aws s3 cp test-data.csv s3://<landing-zone-bucket>/raw/
  ```
- [ ] Verify upload successful
- [ ] Test data access from SageMaker
- [ ] Test data access from EMR

### Setup Monitoring
- [ ] Configure CloudWatch dashboards
- [ ] Set up CloudWatch alarms for:
  - [ ] EMR cluster health
  - [ ] ECS task failures
  - [ ] SageMaker endpoint errors
- [ ] Configure SNS topics for alerts
- [ ] Test alert notifications

### Security Configuration
- [ ] Review security group rules
- [ ] Verify no public internet access
- [ ] Check VPC flow logs (if enabled)
- [ ] Review IAM policies for least privilege
- [ ] Enable CloudTrail logging
- [ ] Configure AWS Config rules

## Testing Checklist

### Network Connectivity Tests
- [ ] Verify SageMaker can access S3 via VPC endpoint
- [ ] Verify EMR can access S3 via VPC endpoint
- [ ] Verify ECS tasks can access S3
- [ ] Verify SageMaker can connect to EMR
- [ ] Verify no outbound internet access from resources

### Functional Tests
- [ ] Run SageMaker notebook end-to-end
- [ ] Submit EMR job and verify completion
- [ ] Deploy ECS task and verify execution
- [ ] Test data pipeline from S3 to SageMaker to EMR

### Performance Tests
- [ ] Test EMR spot instance scaling
- [ ] Test SageMaker kernel launch time
- [ ] Test ECS task startup time
- [ ] Verify S3 access performance

## Documentation

### Project Documentation
- [ ] Document custom configurations
- [ ] Create architecture diagram for your specific setup
- [ ] Document any deviations from default configuration
- [ ] Create runbook for common operations

### Access Documentation
- [ ] Document how to access SageMaker Studio
- [ ] Document how to connect to EMR
- [ ] Document how to deploy to ECS
- [ ] Create user guide for data scientists

### Operational Procedures
- [ ] Document backup procedures
- [ ] Document disaster recovery plan
- [ ] Document scaling procedures
- [ ] Document troubleshooting steps

## Cleanup and Rollback

### Before Cleanup
- [ ] Backup any important data from S3 buckets
- [ ] Export any trained models
- [ ] Save CloudWatch logs if needed
- [ ] Document any issues for future deployments

### Cleanup Procedure
- [ ] Stop any running EMR jobs
- [ ] Stop any running ECS tasks
- [ ] Close SageMaker Studio apps
- [ ] Run terraform destroy
  ```bash
  terraform destroy
  ```
- [ ] Verify all resources deleted
- [ ] Check for any orphaned resources

### Rollback Plan
- [ ] Keep previous Terraform state backed up
- [ ] Document rollback procedure
- [ ] Test rollback in non-production first

## Compliance and Governance

### AWS GovCloud Compliance
- [ ] Verify deployment meets FedRAMP requirements
- [ ] Enable AWS Config for compliance monitoring
- [ ] Configure AWS Security Hub
- [ ] Enable GuardDuty (if available in GovCloud)

### Audit and Logging
- [ ] Enable CloudTrail for all regions
- [ ] Configure S3 access logging
- [ ] Enable VPC Flow Logs
- [ ] Configure log retention policies

### Access Control
- [ ] Implement MFA for all users
- [ ] Configure IAM password policy
- [ ] Review and document all IAM roles
- [ ] Implement least privilege access

## Support and Maintenance

### Ongoing Maintenance
- [ ] Schedule regular security patching
- [ ] Plan for Terraform state backup
- [ ] Schedule regular cost reviews
- [ ] Plan for capacity reviews

### Monitoring and Alerts
- [ ] Set up regular monitoring reviews
- [ ] Configure budget alerts
- [ ] Set up performance baselines
- [ ] Create incident response plan

### Knowledge Transfer
- [ ] Train team on infrastructure
- [ ] Document troubleshooting procedures
- [ ] Create FAQ document
- [ ] Schedule regular reviews

## Success Criteria

Deployment is considered successful when:
- [ ] All Terraform resources created without errors
- [ ] All AWS resources are accessible and functioning
- [ ] SageMaker Studio can be accessed and notebooks run
- [ ] EMR cluster is operational and accepts jobs
- [ ] ECS tasks can be deployed and executed
- [ ] Data can be uploaded to and accessed from S3
- [ ] Monitoring and alerting is operational
- [ ] Documentation is complete
- [ ] Team is trained on the platform

## Notes and Issues

Use this section to track any issues encountered during deployment:

| Date | Issue | Resolution | Notes |
|------|-------|------------|-------|
|      |       |            |       |

## Sign-off

- [ ] Infrastructure deployment reviewed and approved
- [ ] Security configuration reviewed and approved
- [ ] Cost analysis reviewed and approved
- [ ] Documentation reviewed and approved

**Deployed by:** _______________
**Date:** _______________
**Reviewed by:** _______________
**Date:** _______________
