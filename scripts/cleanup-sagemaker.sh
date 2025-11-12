#!/bin/bash
# Cleanup script for SageMaker Studio resources before terraform destroy
# This script deletes all running apps and spaces to allow proper teardown

set -e

REGION=${1:-us-gov-west-1}
DOMAIN_ID=${2}

if [ -z "$DOMAIN_ID" ]; then
  echo "Usage: $0 <region> <domain-id>"
  echo "Example: $0 us-gov-west-1 d-xxxxxxxxxxxxx"
  echo ""
  echo "To get your domain ID, run:"
  echo "  terraform output sagemaker_domain_id"
  exit 1
fi

echo "Cleaning up SageMaker Studio resources in domain: $DOMAIN_ID"
echo "Region: $REGION"
echo ""

# Delete all spaces
echo "Finding and deleting spaces..."
SPACES=$(aws sagemaker list-spaces \
  --domain-id "$DOMAIN_ID" \
  --region "$REGION" \
  --query 'Spaces[].SpaceName' \
  --output text)

if [ -n "$SPACES" ]; then
  for SPACE in $SPACES; do
    echo "  Deleting space: $SPACE"

    # First, delete all apps in the space
    SPACE_APPS=$(aws sagemaker list-apps \
      --domain-id-equals "$DOMAIN_ID" \
      --space-name-equals "$SPACE" \
      --region "$REGION" \
      --query 'Apps[?Status!=`Deleted`].[AppType,AppName]' \
      --output text)

    if [ -n "$SPACE_APPS" ]; then
      echo "$SPACE_APPS" | while read -r APP_TYPE APP_NAME; do
        if [ -n "$APP_TYPE" ] && [ -n "$APP_NAME" ]; then
          echo "    Deleting app: $APP_NAME (type: $APP_TYPE)"
          aws sagemaker delete-app \
            --domain-id "$DOMAIN_ID" \
            --space-name "$SPACE" \
            --app-type "$APP_TYPE" \
            --app-name "$APP_NAME" \
            --region "$REGION" 2>/dev/null || true
        fi
      done
    fi

    # Wait a moment for apps to start deleting
    sleep 5

    # Delete the space
    aws sagemaker delete-space \
      --domain-id "$DOMAIN_ID" \
      --space-name "$SPACE" \
      --region "$REGION" 2>/dev/null || true
  done
else
  echo "  No spaces found"
fi

echo ""

# Delete all apps for all user profiles
echo "Finding and deleting apps from user profiles..."
USER_PROFILES=$(aws sagemaker list-user-profiles \
  --domain-id-equals "$DOMAIN_ID" \
  --region "$REGION" \
  --query 'UserProfiles[].UserProfileName' \
  --output text)

if [ -n "$USER_PROFILES" ]; then
  for USER_PROFILE in $USER_PROFILES; do
    echo "  Checking user profile: $USER_PROFILE"

    PROFILE_APPS=$(aws sagemaker list-apps \
      --domain-id-equals "$DOMAIN_ID" \
      --user-profile-name-equals "$USER_PROFILE" \
      --region "$REGION" \
      --query 'Apps[?Status!=`Deleted`].[AppType,AppName]' \
      --output text)

    if [ -n "$PROFILE_APPS" ]; then
      echo "$PROFILE_APPS" | while read -r APP_TYPE APP_NAME; do
        if [ -n "$APP_TYPE" ] && [ -n "$APP_NAME" ]; then
          echo "    Deleting app: $APP_NAME (type: $APP_TYPE)"
          aws sagemaker delete-app \
            --domain-id "$DOMAIN_ID" \
            --user-profile-name "$USER_PROFILE" \
            --app-type "$APP_TYPE" \
            --app-name "$APP_NAME" \
            --region "$REGION" 2>/dev/null || true
        fi
      done
    else
      echo "    No apps found"
    fi
  done
else
  echo "  No user profiles found"
fi

echo ""
echo "Cleanup initiated. Apps and spaces are being deleted."
echo "This may take several minutes to complete."
echo ""
echo "To verify all apps are deleted, run:"
echo "  aws sagemaker list-apps --domain-id-equals $DOMAIN_ID --region $REGION"
echo ""
echo "Once all apps show Status='Deleted', you can run:"
echo "  terraform destroy"
