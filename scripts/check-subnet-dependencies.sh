#!/bin/bash
# Script to check for dependencies blocking subnet deletion
# This helps identify what's preventing terraform destroy from deleting subnets

set -e

REGION=${1:-us-gov-west-1}
PROJECT_NAME=${2}

if [ -z "$PROJECT_NAME" ]; then
  echo "Usage: $0 <region> <project-name>"
  echo "Example: $0 us-gov-west-1 govcloud-ml-platform"
  echo ""
  echo "To get your project name:"
  echo "  grep 'project_name =' terraform.tfvars"
  exit 1
fi

echo "Checking subnet dependencies for project: $PROJECT_NAME"
echo "Region: $REGION"
echo ""

# Get VPC ID
VPC_ID=$(aws ec2 describe-vpcs \
  --region "$REGION" \
  --filters "Name=tag:Name,Values=${PROJECT_NAME}-vpc" \
  --query 'Vpcs[0].VpcId' \
  --output text)

if [ "$VPC_ID" = "None" ] || [ -z "$VPC_ID" ]; then
  echo "ERROR: VPC not found for project $PROJECT_NAME"
  exit 1
fi

echo "Found VPC: $VPC_ID"
echo ""

# Get all subnets in the VPC
echo "=== Subnets in VPC ==="
SUBNETS=$(aws ec2 describe-subnets \
  --region "$REGION" \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'Subnets[*].[SubnetId,CidrBlock,Tags[?Key==`Name`].Value|[0]]' \
  --output text)

echo "$SUBNETS"
echo ""

# Check each subnet for network interfaces
while IFS=$'\t' read -r SUBNET_ID CIDR NAME; do
  if [ -n "$SUBNET_ID" ] && [ "$SUBNET_ID" != "None" ]; then
    echo "=== Checking Subnet: $NAME ($SUBNET_ID) ==="

    # Find all network interfaces in this subnet
    ENIS=$(aws ec2 describe-network-interfaces \
      --region "$REGION" \
      --filters "Name=subnet-id,Values=$SUBNET_ID" \
      --query 'NetworkInterfaces[*].[NetworkInterfaceId,Status,Description,Attachment.InstanceId,Attachment.AttachmentId]' \
      --output text)

    if [ -n "$ENIS" ]; then
      echo "  ⚠️  Found network interfaces (blocking deletion):"
      echo "$ENIS" | while IFS=$'\t' read -r ENI_ID STATUS DESC INSTANCE_ID ATTACHMENT_ID; do
        echo "    - ENI: $ENI_ID"
        echo "      Status: $STATUS"
        echo "      Description: $DESC"
        if [ -n "$INSTANCE_ID" ] && [ "$INSTANCE_ID" != "None" ]; then
          echo "      Attached to Instance: $INSTANCE_ID"
        fi
        if [ -n "$ATTACHMENT_ID" ] && [ "$ATTACHMENT_ID" != "None" ]; then
          echo "      Attachment ID: $ATTACHMENT_ID"
        fi

        # Check if it's an EMR or SageMaker ENI
        if [[ "$DESC" == *"EMR"* ]] || [[ "$DESC" == *"ElasticMapReduce"* ]]; then
          echo "      Type: EMR Network Interface"
          echo "      Action: Wait for EMR cluster to fully terminate"
        elif [[ "$DESC" == *"SageMaker"* ]]; then
          echo "      Type: SageMaker Network Interface"
          echo "      Action: Stop all SageMaker apps and notebooks"
        elif [[ "$DESC" == *"ECS"* ]]; then
          echo "      Type: ECS Network Interface"
          echo "      Action: Stop all ECS tasks"
        elif [[ "$DESC" == *"Lambda"* ]]; then
          echo "      Type: Lambda Network Interface"
          echo "      Action: Wait for Lambda functions to complete"
        else
          echo "      Type: Unknown"
          echo "      Action: May need manual deletion"
        fi
        echo ""
      done
    else
      echo "  ✓ No network interfaces found - subnet can be deleted"
    fi
    echo ""
  fi
done <<< "$SUBNETS"

# Check for running EMR clusters
echo "=== EMR Clusters ==="
EMR_CLUSTERS=$(aws emr list-clusters \
  --region "$REGION" \
  --active \
  --query 'Clusters[*].[Id,Name,Status.State]' \
  --output text)

if [ -n "$EMR_CLUSTERS" ]; then
  echo "⚠️  Active EMR clusters found:"
  echo "$EMR_CLUSTERS"
  echo ""
  echo "Terminate clusters with:"
  echo "  terraform destroy -target=module.emr"
else
  echo "✓ No active EMR clusters"
fi
echo ""

# Check for SageMaker resources
echo "=== SageMaker Resources ==="

# Check for domains
DOMAINS=$(aws sagemaker list-domains \
  --region "$REGION" \
  --query 'Domains[*].[DomainId,DomainName,Status]' \
  --output text)

if [ -n "$DOMAINS" ]; then
  echo "SageMaker Domains:"
  while IFS=$'\t' read -r DOMAIN_ID DOMAIN_NAME STATUS; do
    if [ -n "$DOMAIN_ID" ]; then
      echo "  - $DOMAIN_NAME ($DOMAIN_ID) - Status: $STATUS"

      # Check for running apps
      APPS=$(aws sagemaker list-apps \
        --region "$REGION" \
        --domain-id-equals "$DOMAIN_ID" \
        --query 'Apps[?Status!=`Deleted`].[AppName,AppType,Status]' \
        --output text)

      if [ -n "$APPS" ]; then
        echo "    ⚠️  Running apps:"
        echo "$APPS" | while IFS=$'\t' read -r APP_NAME APP_TYPE APP_STATUS; do
          echo "      - $APP_NAME ($APP_TYPE) - $APP_STATUS"
        done
        echo "    Action: Run cleanup script:"
        echo "      ./scripts/cleanup-sagemaker.sh $REGION $DOMAIN_ID"
      else
        echo "    ✓ No running apps"
      fi
    fi
  done <<< "$DOMAINS"
else
  echo "✓ No SageMaker domains found"
fi
echo ""

# Check for notebook instances
NOTEBOOKS=$(aws sagemaker list-notebook-instances \
  --region "$REGION" \
  --query 'NotebookInstances[?NotebookInstanceStatus!=`Deleted`].[NotebookInstanceName,NotebookInstanceStatus]' \
  --output text)

if [ -n "$NOTEBOOKS" ]; then
  echo "⚠️  SageMaker Notebook Instances:"
  echo "$NOTEBOOKS"
  echo "Action: Stop notebooks before destroying"
else
  echo "✓ No active notebook instances"
fi
echo ""

# Check for ECS tasks
echo "=== ECS Tasks ==="
ECS_CLUSTERS=$(aws ecs list-clusters \
  --region "$REGION" \
  --query 'clusterArns[*]' \
  --output text)

if [ -n "$ECS_CLUSTERS" ]; then
  for CLUSTER in $ECS_CLUSTERS; do
    CLUSTER_NAME=$(echo "$CLUSTER" | awk -F'/' '{print $2}')
    if [[ "$CLUSTER_NAME" == *"$PROJECT_NAME"* ]]; then
      TASKS=$(aws ecs list-tasks \
        --region "$REGION" \
        --cluster "$CLUSTER" \
        --query 'taskArns[*]' \
        --output text)

      if [ -n "$TASKS" ]; then
        echo "⚠️  Running tasks in cluster $CLUSTER_NAME:"
        echo "$TASKS"
        echo "Action: Stop ECS tasks before destroying"
      else
        echo "✓ No running tasks in $CLUSTER_NAME"
      fi
    fi
  done
else
  echo "✓ No ECS clusters found"
fi
echo ""

# Summary
echo "========================================"
echo "SUMMARY & RECOMMENDED ACTIONS"
echo "========================================"
echo ""
echo "1. Stop all running resources:"
echo "   - EMR clusters: terraform destroy -target=module.emr"
echo "   - SageMaker apps: ./scripts/cleanup-sagemaker.sh $REGION <domain-id>"
echo "   - SageMaker notebooks: Stop via AWS Console or CLI"
echo "   - ECS tasks: Stop via AWS Console or CLI"
echo ""
echo "2. Wait 3-5 minutes for network interfaces to be released"
echo ""
echo "3. Verify all ENIs are deleted:"
echo "   aws ec2 describe-network-interfaces --region $REGION --filters Name=vpc-id,Values=$VPC_ID"
echo ""
echo "4. Retry terraform destroy:"
echo "   terraform destroy"
echo ""
echo "For manual ENI cleanup (last resort), see docs/CLEANUP_GUIDE.md"
