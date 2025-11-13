#!/bin/bash
set -e

# Script to copy SageMaker images from public ECR to private ECR repositories
# Usage: ./scripts/copy-sagemaker-images.sh [region] [account-id] [project-name]

REGION="${1:-us-gov-west-1}"
ACCOUNT_ID="${2}"
PROJECT_NAME="${3}"

if [ -z "$ACCOUNT_ID" ] || [ -z "$PROJECT_NAME" ]; then
    echo "Usage: $0 <region> <account-id> <project-name>"
    echo "Example: $0 us-gov-west-1 123456789012 ml-platform"
    exit 1
fi

echo "=========================================="
echo "SageMaker Image Copy to Private ECR"
echo "=========================================="
echo "Region: $REGION"
echo "Account ID: $ACCOUNT_ID"
echo "Project: $PROJECT_NAME"
echo

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ ERROR: Docker is not installed or not in PATH"
    echo "Please install Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    echo "❌ ERROR: Docker daemon is not running"
    echo "Please start Docker Desktop or the Docker daemon"
    exit 1
fi

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ ERROR: AWS CLI is not installed"
    echo "Please install AWS CLI: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

echo "✅ Docker and AWS CLI are available"
echo

# ECR repository URIs
DATASCIENCE_REPO="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${PROJECT_NAME}/sagemaker-datascience-r"
CPU_REPO="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${PROJECT_NAME}/sagemaker-distribution-cpu"
GPU_REPO="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${PROJECT_NAME}/sagemaker-distribution-gpu"

# Public ECR image URIs (these are examples - adjust based on actual SageMaker public images)
# For GovCloud, we'll use the commercial region public images and copy them
PUBLIC_DATASCIENCE="public.ecr.aws/sagemaker/sagemaker-datascience-r:latest"
PUBLIC_CPU="public.ecr.aws/sagemaker/sagemaker-distribution:latest-cpu"
PUBLIC_GPU="public.ecr.aws/sagemaker/sagemaker-distribution:latest-gpu"

# Note: Since GovCloud doesn't have direct access to public ECR, we need to pull from commercial region first
# This script assumes you're running from a system that can access both commercial AWS and GovCloud

echo "📦 Images to copy:"
echo "  1. Data Science (R): ${PUBLIC_DATASCIENCE}"
echo "  2. Distribution CPU: ${PUBLIC_CPU}"
echo "  3. Distribution GPU: ${PUBLIC_GPU}"
echo
echo "📍 Destination repositories:"
echo "  1. ${DATASCIENCE_REPO}"
echo "  2. ${CPU_REPO}"
echo "  3. ${GPU_REPO}"
echo

# Login to private ECR (GovCloud)
echo "🔐 Logging in to private ECR in GovCloud..."
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
echo "✅ Logged in to private ECR"
echo

# Login to public ECR
echo "🔐 Logging in to public ECR..."
aws ecr-public get-login-password --region us-east-1 | docker login --username AWS --password-stdin public.ecr.aws
echo "✅ Logged in to public ECR"
echo

# Function to copy an image
copy_image() {
    local SOURCE_IMAGE=$1
    local DEST_REPO=$2
    local IMAGE_NAME=$3

    echo "=========================================="
    echo "📥 Copying: $IMAGE_NAME"
    echo "=========================================="

    echo "⬇️  Pulling from public ECR: $SOURCE_IMAGE"
    if docker pull "$SOURCE_IMAGE"; then
        echo "✅ Pull successful"
    else
        echo "⚠️  Warning: Failed to pull $SOURCE_IMAGE"
        echo "   This may be because the image doesn't exist in public ECR"
        echo "   Trying alternative image source..."

        # Try alternative source (SageMaker Studio image from AWS ECR)
        # For GovCloud, we may need to use different source images
        case $IMAGE_NAME in
            "Data Science R")
                # Use base Python Data Science image and we'll add R via lifecycle config
                SOURCE_IMAGE="public.ecr.aws/sagemaker/sagemaker-distribution:latest-cpu"
                echo "   Using alternative: $SOURCE_IMAGE"
                docker pull "$SOURCE_IMAGE" || return 1
                ;;
            *)
                return 1
                ;;
        esac
    fi

    echo "🏷️  Tagging image for private ECR: $DEST_REPO:latest"
    docker tag "$SOURCE_IMAGE" "$DEST_REPO:latest"

    echo "⬆️  Pushing to private ECR: $DEST_REPO:latest"
    if docker push "$DEST_REPO:latest"; then
        echo "✅ Push successful"
    else
        echo "❌ Failed to push to private ECR"
        return 1
    fi

    # Also tag with date for versioning
    DATE_TAG=$(date +%Y%m%d)
    echo "🏷️  Tagging with date: $DEST_REPO:$DATE_TAG"
    docker tag "$SOURCE_IMAGE" "$DEST_REPO:$DATE_TAG"
    docker push "$DEST_REPO:$DATE_TAG"

    echo "✅ $IMAGE_NAME copied successfully"
    echo
}

# Copy images
SUCCESS_COUNT=0
FAIL_COUNT=0

if copy_image "$PUBLIC_DATASCIENCE" "$DATASCIENCE_REPO" "Data Science R"; then
    ((SUCCESS_COUNT++))
else
    echo "⚠️  Data Science R image copy failed (will use lifecycle config instead)"
    ((FAIL_COUNT++))
fi

if copy_image "$PUBLIC_CPU" "$CPU_REPO" "Distribution CPU"; then
    ((SUCCESS_COUNT++))
else
    echo "❌ Distribution CPU image copy failed"
    ((FAIL_COUNT++))
fi

if copy_image "$PUBLIC_GPU" "$GPU_REPO" "Distribution GPU"; then
    ((SUCCESS_COUNT++))
else
    echo "❌ Distribution GPU image copy failed"
    ((FAIL_COUNT++))
fi

# Cleanup local images to save disk space
echo "🧹 Cleaning up local Docker images..."
docker image prune -f

echo
echo "=========================================="
echo "📊 Summary"
echo "=========================================="
echo "✅ Successfully copied: $SUCCESS_COUNT image(s)"
echo "❌ Failed: $FAIL_COUNT image(s)"
echo

if [ $SUCCESS_COUNT -gt 0 ]; then
    echo "=========================================="
    echo "✅ SUCCESS!"
    echo "=========================================="
    echo
    echo "SageMaker images have been copied to your private ECR repositories."
    echo
    echo "Next steps:"
    echo "1. Verify images in ECR:"
    echo "   aws ecr describe-images --repository-name ${PROJECT_NAME}/sagemaker-distribution-cpu --region $REGION"
    echo
    echo "2. Update your Terraform configuration to use these images"
    echo "3. Run 'terraform apply' to update SageMaker domain"
    echo
    echo "Image URIs:"
    echo "  Data Science: ${DATASCIENCE_REPO}:latest"
    echo "  CPU: ${CPU_REPO}:latest"
    echo "  GPU: ${GPU_REPO}:latest"
    echo "=========================================="
    exit 0
else
    echo "=========================================="
    echo "⚠️  WARNING"
    echo "=========================================="
    echo
    echo "No images were successfully copied."
    echo
    echo "This may be because:"
    echo "1. Public ECR images don't exist with these names"
    echo "2. Network connectivity issues"
    echo "3. Authentication problems"
    echo
    echo "For GovCloud, you may need to:"
    echo "1. Pull images from commercial AWS region first"
    echo "2. Copy images to an S3 bucket accessible from GovCloud"
    echo "3. Load images into GovCloud ECR from S3"
    echo
    echo "Alternatively, SageMaker can use the lifecycle configuration"
    echo "to install R and other packages at runtime instead of"
    echo "requiring custom Docker images."
    echo "=========================================="
    exit 1
fi
