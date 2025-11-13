# S3 Bucket Automatic Cleanup

## Overview

The infrastructure is configured to ensure **all S3 buckets are automatically emptied and deleted** during `terraform destroy`. This prevents common "BucketNotEmpty" errors that occur when Terraform tries to delete a bucket that still contains objects.

## How It Works

### 1. Force Destroy Attribute

All S3 bucket resources have the `force_destroy = true` attribute:

```hcl
resource "aws_s3_bucket" "emr_logs" {
  bucket        = "${var.project_name}-emr-logs-${var.account_id}"
  force_destroy = true  # Automatically empty bucket before deletion

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-emr-logs"
      Purpose     = "EMR Cluster Logs"
      Environment = var.environment
    }
  )
}
```

This is applied to all four S3 buckets:
- **Landing Zone Bucket** (`aws_s3_bucket.landing_zone`)
- **SageMaker Bucket** (`aws_s3_bucket.sagemaker`)
- **EMR Logs Bucket** (`aws_s3_bucket.emr_logs`)
- **ECS Artifacts Bucket** (`aws_s3_bucket.ecs_artifacts`)

### 2. What Force Destroy Does

When `force_destroy = true`:
- **During `terraform destroy`**: Terraform automatically deletes all objects (including all versions if versioning is enabled) before deleting the bucket
- **No manual intervention required**: You don't need to empty buckets manually or run cleanup scripts
- **Handles versioned objects**: Even buckets with versioning enabled are properly cleaned

## Buckets Covered

### 1. Landing Zone Bucket
**Name**: `<project-name>-landing-zone-<account-id>`

**Purpose**: Data ingestion and initial data landing

**Contents Automatically Deleted**:
- Raw data files
- Ingested datasets
- Temporary staging files
- All versions of objects (versioning enabled)

**Configuration**:
- Force destroy: ✅ Enabled
- Versioning: ✅ Enabled
- Encryption: ✅ AES256
- Public access: ❌ Blocked

### 2. SageMaker Bucket
**Name**: `<project-name>-sagemaker-<account-id>`

**Purpose**: SageMaker artifacts, models, and outputs

**Contents Automatically Deleted**:
- Trained models
- Training job artifacts
- Processing job outputs
- Model registry artifacts
- Notebook outputs
- All versions of objects (versioning enabled)

**Configuration**:
- Force destroy: ✅ Enabled
- Versioning: ✅ Enabled
- Encryption: ✅ AES256
- Public access: ❌ Blocked

### 3. EMR Logs Bucket
**Name**: `<project-name>-emr-logs-<account-id>`

**Purpose**: EMR cluster logs and outputs

**Contents Automatically Deleted**:
- EMR cluster logs
- Spark application logs
- Step execution logs
- Bootstrap action logs
- All versions of logs (versioning enabled)

**Configuration**:
- Force destroy: ✅ Enabled
- Versioning: ✅ Enabled
- Encryption: ✅ AES256
- Public access: ❌ Blocked
- Lifecycle: Logs expire after 90 days

### 4. ECS Artifacts Bucket
**Name**: `<project-name>-ecs-artifacts-<account-id>`

**Purpose**: ECS/Docker artifacts and container configurations

**Contents Automatically Deleted**:
- Container configurations
- Task definition artifacts
- Application deployment files
- All versions of artifacts (versioning enabled)

**Configuration**:
- Force destroy: ✅ Enabled
- Versioning: ✅ Enabled
- Encryption: ✅ AES256
- Public access: ❌ Blocked

## Destroy Order

When you run `terraform destroy`, S3 buckets are cleaned up early in the process:

```
Destroy Order (Automatic):
┌─────────────────────────────────────────────────┐
│ 1. Compute Resources                            │
│    - SageMaker Domain & Apps                    │
│    - EMR Cluster                                │
│    - ECS Services & Tasks                       │
│    - Neptune Instances                          │
└─────────────────────────────────────────────────┘
            ↓
┌─────────────────────────────────────────────────┐
│ 2. S3 Buckets (Force Destroy)                   │
│    For each bucket:                             │
│    a. Delete all object versions                │
│    b. Delete all delete markers                 │
│    c. Delete the bucket                         │
└─────────────────────────────────────────────────┘
            ↓
┌─────────────────────────────────────────────────┐
│ 3. EFS Mount Targets                            │
│    - Cleanup script runs automatically          │
│    - Mount targets deleted from subnets         │
└─────────────────────────────────────────────────┘
            ↓
┌─────────────────────────────────────────────────┐
│ 4. VPC Resources                                │
│    - Route tables, security groups, gateways    │
│    - Subnets                                    │
│    - VPC (deleted last)                         │
└─────────────────────────────────────────────────┘
```

## Benefits

### ✅ No Manual Cleanup Required
- You don't need to manually empty buckets
- No need to run separate cleanup scripts for S3
- Just run `terraform destroy` and everything is handled

### ✅ Prevents Common Errors

**Without force_destroy**, you would see:
```
Error: deleting S3 Bucket (project-emr-logs-123456): BucketNotEmpty:
The bucket you tried to delete is not empty. You must delete all versions
in the bucket.
```

**With force_destroy**:
- Buckets are automatically emptied (all objects and versions deleted)
- Bucket deletion succeeds without errors
- Clean, one-step destruction process

### ✅ Handles Versioned Objects
- Automatically deletes all object versions
- Removes delete markers
- No manual intervention for versioned buckets

### ✅ Idempotent and Safe
- Can run `terraform destroy` multiple times
- Safe to interrupt and restart
- No orphaned buckets or objects

## What You'll See During Destroy

```bash
$ terraform destroy

# ... earlier resources destroyed ...

module.s3.aws_s3_bucket.emr_logs: Destroying... [id=ml-platform-emr-logs-123456]
module.s3.aws_s3_bucket.emr_logs: Still destroying... [10s elapsed]
module.s3.aws_s3_bucket.emr_logs: Still destroying... [20s elapsed]
module.s3.aws_s3_bucket.emr_logs: Destruction complete after 25s

module.s3.aws_s3_bucket.sagemaker: Destroying... [id=ml-platform-sagemaker-123456]
module.s3.aws_s3_bucket.sagemaker: Still destroying... [10s elapsed]
module.s3.aws_s3_bucket.sagemaker: Destruction complete after 15s

module.s3.aws_s3_bucket.landing_zone: Destroying... [id=ml-platform-landing-zone-123456]
module.s3.aws_s3_bucket.landing_zone: Destruction complete after 12s

module.s3.aws_s3_bucket.ecs_artifacts: Destroying... [id=ml-platform-ecs-artifacts-123456]
module.s3.aws_s3_bucket.ecs_artifacts: Destruction complete after 8s

# ... continues with other resources ...
```

**Note**: Deletion time depends on the number of objects in the bucket:
- Empty buckets: ~5-10 seconds
- Buckets with hundreds of objects: ~15-30 seconds
- Buckets with thousands of objects: ~1-2 minutes
- Buckets with versioning and many versions: ~2-5 minutes

## Data Safety Considerations

### ⚠️ Warning: Data Loss

The `force_destroy = true` attribute means:
- **All data in these buckets will be permanently deleted** during `terraform destroy`
- **No recovery is possible** after deletion
- **All versions are deleted** if versioning is enabled

### Best Practices Before Destroy

If you have important data in these buckets, back it up before running `terraform destroy`:

```bash
# Backup landing zone data
aws s3 sync s3://ml-platform-landing-zone-123456 ./backup/landing-zone/ \
  --region us-gov-west-1

# Backup SageMaker artifacts
aws s3 sync s3://ml-platform-sagemaker-123456 ./backup/sagemaker/ \
  --region us-gov-west-1

# Backup EMR logs
aws s3 sync s3://ml-platform-emr-logs-123456 ./backup/emr-logs/ \
  --region us-gov-west-1

# Backup ECS artifacts
aws s3 sync s3://ml-platform-ecs-artifacts-123456 ./backup/ecs-artifacts/ \
  --region us-gov-west-1
```

### Production Environments

For production environments, consider:

1. **Disable force_destroy**:
   ```hcl
   resource "aws_s3_bucket" "landing_zone" {
     bucket        = "${var.project_name}-landing-zone-${var.account_id}"
     force_destroy = false  # Require manual bucket cleanup
   }
   ```

2. **Enable lifecycle policies** to archive old data to Glacier before deletion

3. **Set up cross-region replication** for critical data

4. **Use AWS Backup** for automated backups

## Troubleshooting

### Bucket Deletion Takes Too Long

**Cause**: Bucket contains many objects or versions

**What's happening**:
- Terraform is deleting all objects before deleting the bucket
- This can take time for buckets with thousands of objects

**Solution**: Wait for the operation to complete. If it takes more than 10 minutes:

```bash
# Check how many objects are in the bucket
aws s3 ls s3://ml-platform-emr-logs-123456 --recursive --summarize \
  --region us-gov-west-1

# For versioned buckets, check all versions
aws s3api list-object-versions \
  --bucket ml-platform-emr-logs-123456 \
  --region us-gov-west-1 \
  --output json | jq '.Versions | length'
```

### Bucket Deletion Still Fails

**Unlikely, but if it happens:**

1. **Check for bucket policies blocking deletion**:
   ```bash
   aws s3api get-bucket-policy \
     --bucket ml-platform-emr-logs-123456 \
     --region us-gov-west-1
   ```

2. **Check for object locks**:
   ```bash
   aws s3api get-object-lock-configuration \
     --bucket ml-platform-emr-logs-123456 \
     --region us-gov-west-1
   ```

3. **Manual cleanup** (last resort):
   ```bash
   # Empty the bucket manually
   aws s3 rm s3://ml-platform-emr-logs-123456 --recursive \
     --region us-gov-west-1

   # Delete all versions (if versioning enabled)
   aws s3api delete-objects \
     --bucket ml-platform-emr-logs-123456 \
     --delete "$(aws s3api list-object-versions \
       --bucket ml-platform-emr-logs-123456 \
       --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
       --region us-gov-west-1)" \
     --region us-gov-west-1

   # Retry destroy
   terraform destroy
   ```

### Verify Deletion

To verify all buckets are deleted:

```bash
# List all buckets with your project name
aws s3 ls | grep ml-platform

# Should return nothing if all buckets are deleted
```

## Files Modified

All changes are in `modules/s3/main.tf`:

1. **Lines 2-4**: Landing zone bucket with `force_destroy = true`
2. **Lines 47-49**: SageMaker bucket with `force_destroy = true`
3. **Lines 92-94**: EMR logs bucket with `force_destroy = true`
4. **Lines 155-157**: ECS artifacts bucket with `force_destroy = true`

## Related Documentation

- [Main README - Destroying Infrastructure](../README.md#destroying-infrastructure)
- [Cleanup Guide - Automatic Cleanup Features](CLEANUP_GUIDE.md#automatic-cleanup-features)
- [EFS Cleanup Documentation](EFS_CLEANUP.md)
- [Route Table Cleanup Documentation](ROUTE_TABLE_CLEANUP.md)

## Summary

✅ **All S3 buckets are automatically emptied and deleted**
✅ **No manual cleanup required**
✅ **Prevents BucketNotEmpty errors**
✅ **Handles versioned objects automatically**
✅ **Safe and idempotent**
✅ **Works seamlessly with terraform destroy**

⚠️ **Warning**: All data will be permanently deleted. Back up important data before destroy.

You can confidently run `terraform destroy` knowing that all S3 buckets will be cleaned up automatically!
