#!/bin/bash
# Script to check available SageMaker instance types in your AWS region
# Usage: ./check-sagemaker-instance-types.sh [region]

REGION=${1:-us-gov-west-1}

echo "Checking SageMaker notebook instance types available in region: $REGION"
echo "=================================================================="
echo ""

# Check Service Quotas for SageMaker notebook instances
echo "Querying Service Quotas for SageMaker notebook instances..."
echo ""

# Get all SageMaker quotas
aws service-quotas list-service-quotas \
    --service-code sagemaker \
    --region "$REGION" \
    --query 'Quotas[?contains(QuotaName, `notebook instance`) && Value > `0`].[QuotaName,Value]' \
    --output table 2>/dev/null || {
    echo "Error: Unable to query Service Quotas. Make sure you have the necessary permissions."
    echo ""
    echo "Alternatively, try these common instance types for GovCloud:"
    echo "  - ml.t3.medium"
    echo "  - ml.t3.large"
    echo "  - ml.m5.large (recommended)"
    echo "  - ml.m5.xlarge"
    echo "  - ml.m5.2xlarge"
    echo "  - ml.c5.large"
    echo "  - ml.c5.xlarge"
    exit 1
}

echo ""
echo "Note: A quota value > 0 indicates the instance type is available in your region."
echo ""
echo "Recommended instance types for GovCloud:"
echo "  - ml.m5.large (default)"
echo "  - ml.m5.xlarge"
echo "  - ml.m5.2xlarge"
echo ""
echo "To change the instance type, update terraform.tfvars:"
echo '  sagemaker_notebook_instance_type = "ml.m5.large"'
