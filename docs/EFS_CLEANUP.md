# EFS Mount Target Automatic Cleanup

## Overview

AWS SageMaker Studio automatically creates EFS (Elastic File System) file systems for user home directories. These EFS file systems create **mount targets** in private subnets, which in turn create **Elastic Network Interfaces (ENIs)** that can prevent subnet deletion during `terraform destroy`.

This infrastructure includes **automatic EFS cleanup** to prevent these common errors.

## How It Works

### Automatic Cleanup (Default Behavior)

A `null_resource` in the networking module (`modules/networking/main.tf`) automatically handles EFS cleanup:

1. **During `terraform destroy`**:
   - The destroy provisioner detects all EFS mount targets in your VPC
   - Deletes mount targets before subnets are destroyed
   - Waits 45 seconds for full deletion
   - Allows subnet deletion to proceed without errors

2. **Dependency Chain**:
   ```
   terraform destroy execution order:
   1. SageMaker Domain & Apps destroyed
   2. EMR Cluster destroyed
   3. ECS Services destroyed
   4. null_resource.efs_cleanup destroyed → RUNS CLEANUP SCRIPT
   5. Private Subnets destroyed (now clean, no mount targets)
   6. VPC destroyed
   ```

3. **What You'll See**:
   ```
   ==========================================
   EFS Mount Target Cleanup
   ==========================================
   Project: your-project-name
   Region: us-gov-west-1
   VPC: vpc-xxxxx

   🗑️  Deleting mount target: fsmt-xxxxx (EFS: fs-xxxxx, Subnet: subnet-xxxxx)
   🗑️  Deleting mount target: fsmt-yyyyy (EFS: fs-xxxxx, Subnet: subnet-yyyyy)
   🗑️  Deleting mount target: fsmt-zzzzz (EFS: fs-xxxxx, Subnet: subnet-zzzzz)

   Deleted 3 mount target(s)
   ⏳ Waiting 45 seconds for mount targets to be fully deleted...
   ✅ EFS cleanup complete
   ==========================================
   ```

### Manual Cleanup (If Needed)

If automatic cleanup fails or you need to clean up manually:

```bash
# Run the cleanup script manually
./scripts/cleanup-efs.sh us-gov-west-1 <project-name>

# Example
./scripts/cleanup-efs.sh us-gov-west-1 govcloud-ml-platform
```

## Files Involved

### 1. Cleanup Script
**Location**: `scripts/cleanup-efs.sh`

**What it does**:
- Finds all EFS file systems in the region
- Identifies mount targets in your project's VPC
- Deletes mount targets
- Optionally deletes EFS file systems tagged with your project
- Waits for cleanup to complete

**Usage**:
```bash
./scripts/cleanup-efs.sh <aws-region> <project-name>
```

### 2. Null Resource
**Location**: `modules/networking/main.tf` (lines 1012-1084)

**Key features**:
- Destroy-time provisioner that runs before subnet deletion
- Falls back to inline cleanup if script not found
- Depends on private subnets (ensures correct destroy order)
- Uses trigger to track VPC changes

### 3. Documentation
- **Main README**: Documents automatic cleanup feature
- **CLEANUP_GUIDE.md**: Detailed troubleshooting for EFS-related errors
- **This file**: Technical reference for the EFS cleanup system

## Why EFS Mount Targets Block Subnet Deletion

1. **SageMaker creates EFS automatically**:
   - Each SageMaker Domain creates an EFS file system
   - EFS stores user home directories and notebooks
   - File system is not visible in Terraform state

2. **Mount targets create ENIs**:
   - EFS creates one mount target per subnet (for high availability)
   - Each mount target creates an ENI in the subnet
   - ENIs prevent subnet deletion

3. **Normal Terraform destroy fails**:
   ```
   Error: deleting subnet subnet-xxxxx: DependencyViolation:
   The subnet 'subnet-xxxxx' has dependencies and cannot be deleted.
   ```

4. **Our solution**:
   - Automatically detects and removes mount targets
   - Runs before subnet destruction
   - Prevents the error from occurring

## Troubleshooting

### Check for EFS Resources

```bash
# List all EFS file systems
aws efs describe-file-systems --region us-gov-west-1

# List mount targets for a specific file system
aws efs describe-mount-targets \
    --file-system-id fs-xxxxx \
    --region us-gov-west-1

# Find which subnet a mount target is in
aws efs describe-mount-targets \
    --file-system-id fs-xxxxx \
    --query 'MountTargets[*].[MountTargetId,SubnetId,IpAddress]' \
    --output table \
    --region us-gov-west-1
```

### Verify Cleanup Worked

```bash
# After running cleanup, check for remaining mount targets
aws efs describe-mount-targets --region us-gov-west-1

# Should return empty list or only mount targets from other VPCs
```

### Manual Mount Target Deletion

If you need to manually delete a specific mount target:

```bash
# Delete a specific mount target
aws efs delete-mount-target \
    --mount-target-id fsmt-xxxxx \
    --region us-gov-west-1

# Wait for deletion (usually takes 30-60 seconds)
sleep 45

# Verify it's deleted
aws efs describe-mount-targets \
    --mount-target-id fsmt-xxxxx \
    --region us-gov-west-1
# Should return: An error occurred (MountTargetNotFound)
```

### Check Subnet Dependencies

Use the subnet dependency checker to see what's blocking deletion:

```bash
./scripts/check-subnet-dependencies.sh us-gov-west-1 <project-name>
```

This will show:
- All ENIs in your subnets
- What created each ENI (EFS, EMR, SageMaker, ECS, etc.)
- Recommended cleanup actions

## Best Practices

1. **Let automatic cleanup run**: Don't interrupt `terraform destroy` during EFS cleanup
2. **Wait for SageMaker apps to terminate**: Run `./scripts/cleanup-sagemaker.sh` first
3. **Check cleanup output**: Review the EFS cleanup messages during destroy
4. **Verify before retry**: If destroy fails, check for remaining mount targets before retrying
5. **Keep the script**: The `cleanup-efs.sh` script can be used independently of Terraform

## Advanced: How the Dependency Chain Works

The `null_resource` uses Terraform's dependency graph to ensure correct destroy order:

```hcl
resource "null_resource" "efs_cleanup" {
  triggers = {
    vpc_id       = aws_vpc.main.id
    project_name = var.project_name
    region       = var.aws_region
  }

  provisioner "local-exec" {
    when    = destroy
    command = "..."  # Cleanup script
  }

  depends_on = [
    aws_subnet.private  # Must exist before this resource during create
  ]
}
```

**During Create**:
1. VPC created
2. Subnets created
3. null_resource created (does nothing)

**During Destroy** (reverse order):
1. Resources using subnets destroyed (SageMaker, EMR, ECS)
2. null_resource destroyed → **CLEANUP SCRIPT RUNS**
3. Subnets destroyed (now free of mount targets)
4. VPC destroyed

## Related Documentation

- [Main README - Destroying Infrastructure](../README.md#destroying-infrastructure)
- [Cleanup Guide - EFS Mount Target Deletion](CLEANUP_GUIDE.md#2-efs-mount-target-deletion-error)
- [Cleanup Guide - Subnet Deletion](CLEANUP_GUIDE.md#3-subnet-deletion-error-general)

## Support

If you encounter issues with EFS cleanup:

1. Check the [CLEANUP_GUIDE.md](CLEANUP_GUIDE.md) for detailed troubleshooting
2. Verify AWS CLI credentials have EFS permissions
3. Check CloudWatch logs for SageMaker Domain deletion status
4. Ensure no apps or spaces are running in SageMaker Studio
