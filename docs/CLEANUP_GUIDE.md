# Infrastructure Cleanup Guide

This guide explains how to properly destroy the infrastructure to avoid common errors.

## Common Destroy Errors

### 1. SageMaker User Profile Deletion Error

**Error Message:**
```
Error: deleting SageMaker User Profile: ResourceInUse: User profile cannot be deleted while there are active Apps or Spaces
```

**Cause:** SageMaker Studio has running apps or spaces that must be deleted before the user profile can be removed.

**Solution:** Run the cleanup script before `terraform destroy`:

```bash
# Get your domain ID
DOMAIN_ID=$(terraform output -raw sagemaker_domain_id)

# Run cleanup script
./scripts/cleanup-sagemaker.sh us-gov-west-1 $DOMAIN_ID

# Wait for cleanup to complete (check status)
aws sagemaker list-apps --domain-id-equals $DOMAIN_ID --region us-gov-west-1

# Once all apps show Status='Deleted', proceed with destroy
terraform destroy
```

### 2. Subnet Deletion Error

**Error Message:**
```
Error: deleting subnet: DependencyViolation: The subnet has dependencies and cannot be deleted
```

**Cause:** Network interfaces (ENIs) from EMR, SageMaker, or ECS are still attached to the subnets.

**Solution:** Run the dependency checker script:

```bash
# Check what's blocking subnet deletion
./scripts/check-subnet-dependencies.sh us-gov-west-1 <project-name>

# This will show:
# - All network interfaces in your subnets
# - What resources (EMR/SageMaker/ECS) own them
# - Recommended cleanup actions
```

**Quick Fix:**
```bash
# Step 1: Destroy compute resources first
terraform destroy -target=module.emr -target=module.sagemaker -target=module.ecs

# Step 2: Wait 5 minutes for ENIs to be released
sleep 300

# Step 3: Retry full destroy
terraform destroy
```

### 3. EMR Security Group Deletion Error

**Error Message:**
```
Error: deleting Security Group: DependencyViolation: resource has a dependent object
```

**Cause:** The EMR cluster's EC2 instances haven't fully terminated, leaving network interfaces attached to the security groups.

**Solution Options:**

#### Option 1: Wait and Retry (Recommended)
```bash
# Terminate the EMR cluster first
terraform destroy -target=module.emr

# Wait 2-5 minutes for instances to fully terminate
sleep 300

# Then destroy the rest
terraform destroy
```

#### Option 2: Manual Cleanup
```bash
# Get the security group ID
SG_ID=$(terraform show | grep "emr-master-sg" | grep "sg-" | awk '{print $3}' | tr -d '"')

# Check for attached network interfaces
aws ec2 describe-network-interfaces \
  --filters "Name=group-id,Values=$SG_ID" \
  --region us-gov-west-1

# If network interfaces exist, wait for them to be released
# Or manually detach/delete them via AWS Console

# Then retry destroy
terraform destroy
```

#### Option 3: Force Delete (Use with Caution)
```bash
# Remove the security group from Terraform state
terraform state rm module.networking.aws_security_group.emr_master
terraform state rm module.networking.aws_security_group.emr_slave

# Manually delete the security groups via AWS Console or CLI
aws ec2 delete-security-group --group-id $SG_ID --region us-gov-west-1

# Then destroy the rest
terraform destroy
```

## Recommended Destroy Procedure

Follow these steps in order to minimize errors:

### Step 1: Clean Up SageMaker Studio
```bash
# Get domain ID
DOMAIN_ID=$(terraform output -raw sagemaker_domain_id)

# Run cleanup script
./scripts/cleanup-sagemaker.sh us-gov-west-1 $DOMAIN_ID

# Verify cleanup is complete
aws sagemaker list-apps --domain-id-equals $DOMAIN_ID --region us-gov-west-1 \
  --query 'Apps[?Status!=`Deleted`]' --output table
```

### Step 2: Terminate EMR Cluster
```bash
# Destroy EMR cluster first
terraform destroy -target=module.emr

# Wait for termination to complete (check AWS Console)
# Or monitor via CLI:
aws emr list-clusters --active --region us-gov-west-1
```

### Step 3: Verify Network Cleanup
```bash
# Check for remaining dependencies
./scripts/check-subnet-dependencies.sh us-gov-west-1 <project-name>

# Wait 3-5 minutes for network interfaces to be released
sleep 300
```

### Step 4: Destroy Remaining Infrastructure
```bash
# Now destroy everything else
terraform destroy
```

## Troubleshooting Subnet Deletion

### Check What's Blocking Subnets

Run the dependency checker:
```bash
./scripts/check-subnet-dependencies.sh us-gov-west-1 <project-name>
```

This script will show:
- All network interfaces in your subnets
- Which resources (EMR/SageMaker/ECS) own them
- Current status of each ENI
- Recommended actions

### Common ENI Types

**EMR Network Interfaces:**
- Description contains "EMR" or "ElasticMapReduce"
- Solution: Terminate EMR cluster and wait 5 minutes
- Command: `terraform destroy -target=module.emr`

**SageMaker Network Interfaces:**
- Description contains "SageMaker"
- Solution: Stop all SageMaker apps/notebooks
- Command: `./scripts/cleanup-sagemaker.sh <region> <domain-id>`

**ECS Network Interfaces:**
- Description contains "ECS" or "Fargate"
- Solution: Stop all ECS tasks
- Command: Stop tasks via AWS Console or CLI

### Manual ENI Deletion (Last Resort)

If ENIs are stuck in "available" state:

```bash
# List all ENIs in VPC
VPC_ID="vpc-xxxxx"
aws ec2 describe-network-interfaces \
  --region us-gov-west-1 \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'NetworkInterfaces[*].[NetworkInterfaceId,Status,Description]' \
  --output table

# Delete available (unattached) ENI
aws ec2 delete-network-interface \
  --network-interface-id eni-xxxxx \
  --region us-gov-west-1

# For attached ENIs, force detach first
aws ec2 detach-network-interface \
  --attachment-id eni-attach-xxxxx \
  --force \
  --region us-gov-west-1

# Then delete
aws ec2 delete-network-interface \
  --network-interface-id eni-xxxxx \
  --region us-gov-west-1
```

## Manual Cleanup Commands

If automated cleanup fails, use these commands:

### Delete All SageMaker Apps
```bash
DOMAIN_ID="your-domain-id"
REGION="us-gov-west-1"

# List all apps
aws sagemaker list-apps \
  --domain-id-equals $DOMAIN_ID \
  --region $REGION

# Delete specific app
aws sagemaker delete-app \
  --domain-id $DOMAIN_ID \
  --user-profile-name default-user \
  --app-type KernelGateway \
  --app-name default \
  --region $REGION
```

### Delete All Spaces
```bash
# List spaces
aws sagemaker list-spaces \
  --domain-id $DOMAIN_ID \
  --region $REGION

# Delete specific space
aws sagemaker delete-space \
  --domain-id $DOMAIN_ID \
  --space-name "my-space" \
  --region $REGION
```

### Check Network Interfaces
```bash
# Find network interfaces attached to security group
aws ec2 describe-network-interfaces \
  --filters "Name=group-id,Values=sg-xxxxx" \
  --region us-gov-west-1 \
  --query 'NetworkInterfaces[*].[NetworkInterfaceId,Status,Attachment.InstanceId]' \
  --output table
```

### Force Detach Network Interface (Last Resort)
```bash
# Get attachment ID
ATTACHMENT_ID=$(aws ec2 describe-network-interfaces \
  --network-interface-ids eni-xxxxx \
  --region us-gov-west-1 \
  --query 'NetworkInterfaces[0].Attachment.AttachmentId' \
  --output text)

# Detach
aws ec2 detach-network-interface \
  --attachment-id $ATTACHMENT_ID \
  --force \
  --region us-gov-west-1

# Delete network interface
aws ec2 delete-network-interface \
  --network-interface-id eni-xxxxx \
  --region us-gov-west-1
```

## Prevention Tips

1. **Always stop SageMaker apps** when not in use to avoid destroy issues
2. **Use the cleanup script** before destroying infrastructure
3. **Terminate EMR clusters separately** before destroying networking
4. **Wait for resources to fully terminate** before retrying destroy
5. **Check AWS Console** to verify resources are deleted before retrying

## Troubleshooting

### "Resource in use" errors
- Check AWS Console for any resources still running
- Wait 5-10 minutes and retry
- Use the cleanup script to automate deletion

### "Dependent object" errors
- Usually related to network interfaces or security groups
- Wait for EC2 instances to fully terminate
- Check for orphaned network interfaces

### "Timeout" errors during destroy
- Increase timeout with `-timeout=30m` flag
- Destroy resources in stages (EMR first, then networking)

## Getting Help

If you continue to experience issues:

1. Check AWS CloudTrail logs for detailed error messages
2. Review AWS Console for resources that didn't get deleted
3. Use `terraform state list` to see what resources Terraform is tracking
4. Consider using `terraform state rm` for stuck resources (then manually delete)
