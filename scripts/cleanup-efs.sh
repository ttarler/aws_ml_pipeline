#!/bin/bash
set -e

# Script to clean up EFS mount targets that may block subnet deletion
# This is typically needed for SageMaker-created EFS file systems

REGION="${1:-us-gov-west-1}"
PROJECT_NAME="${2}"

if [ -z "$PROJECT_NAME" ]; then
    echo "Usage: $0 <aws-region> <project-name>"
    echo "Example: $0 us-gov-west-1 govcloud-ml-platform"
    exit 1
fi

echo "=================================================="
echo "EFS Mount Target Cleanup for: $PROJECT_NAME"
echo "Region: $REGION"
echo "=================================================="

# Get VPC ID for the project
VPC_ID=$(aws ec2 describe-vpcs \
    --region "$REGION" \
    --filters "Name=tag:Project,Values=$PROJECT_NAME" \
    --query 'Vpcs[0].VpcId' \
    --output text 2>/dev/null || echo "")

if [ -z "$VPC_ID" ] || [ "$VPC_ID" = "None" ]; then
    echo "⚠️  No VPC found for project: $PROJECT_NAME"
    echo "EFS cleanup may not be necessary or VPC already deleted."
    exit 0
fi

echo "Found VPC: $VPC_ID"
echo ""

# Get all EFS file systems
echo "Searching for EFS file systems..."
EFS_IDS=$(aws efs describe-file-systems \
    --region "$REGION" \
    --query 'FileSystems[*].FileSystemId' \
    --output text 2>/dev/null || echo "")

if [ -z "$EFS_IDS" ]; then
    echo "✅ No EFS file systems found"
    exit 0
fi

# Check each EFS for mount targets in our VPC
MOUNT_TARGETS_DELETED=0
for FS_ID in $EFS_IDS; do
    echo "Checking EFS: $FS_ID"

    # Get mount targets for this file system
    MOUNT_TARGETS=$(aws efs describe-mount-targets \
        --region "$REGION" \
        --file-system-id "$FS_ID" \
        --query 'MountTargets[*].[MountTargetId,SubnetId]' \
        --output text 2>/dev/null || echo "")

    if [ -z "$MOUNT_TARGETS" ]; then
        continue
    fi

    # Check if any mount targets are in our VPC
    while IFS=$'\t' read -r MT_ID SUBNET_ID; do
        # Get VPC for this subnet
        MT_VPC=$(aws ec2 describe-subnets \
            --region "$REGION" \
            --subnet-ids "$SUBNET_ID" \
            --query 'Subnets[0].VpcId' \
            --output text 2>/dev/null || echo "")

        if [ "$MT_VPC" = "$VPC_ID" ]; then
            echo "  🗑️  Deleting mount target: $MT_ID (subnet: $SUBNET_ID)"
            aws efs delete-mount-target \
                --region "$REGION" \
                --mount-target-id "$MT_ID" 2>/dev/null || echo "    ⚠️  Failed to delete (may already be deleted)"
            MOUNT_TARGETS_DELETED=$((MOUNT_TARGETS_DELETED + 1))
        fi
    done <<< "$MOUNT_TARGETS"
done

if [ $MOUNT_TARGETS_DELETED -eq 0 ]; then
    echo "✅ No mount targets to delete"
else
    echo ""
    echo "Deleted $MOUNT_TARGETS_DELETED mount target(s)"
    echo ""
    echo "⏳ Waiting 30 seconds for mount targets to be fully deleted..."
    sleep 30
    echo "✅ Mount target cleanup complete"
fi

# Optional: Delete EFS file systems tagged with the project
echo ""
echo "Checking for EFS file systems to delete..."
for FS_ID in $EFS_IDS; do
    # Check if this EFS has the project tag
    PROJECT_TAG=$(aws efs describe-tags \
        --region "$REGION" \
        --file-system-id "$FS_ID" \
        --query "Tags[?Key=='Project'].Value" \
        --output text 2>/dev/null || echo "")

    if [ "$PROJECT_TAG" = "$PROJECT_NAME" ]; then
        echo "  🗑️  Deleting EFS file system: $FS_ID"
        aws efs delete-file-system \
            --region "$REGION" \
            --file-system-id "$FS_ID" 2>/dev/null || echo "    ⚠️  Failed to delete (may have mount targets still attached)"
    fi
done

echo ""
echo "=================================================="
echo "EFS cleanup complete!"
echo "=================================================="
echo ""
echo "Next steps:"
echo "  1. Verify mount targets are deleted:"
echo "     aws efs describe-mount-targets --region $REGION"
echo ""
echo "  2. Check for remaining network interfaces:"
echo "     ./scripts/check-subnet-dependencies.sh $REGION $PROJECT_NAME"
echo ""
echo "  3. Continue with terraform destroy"
echo ""
