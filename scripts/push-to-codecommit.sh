#!/bin/bash
set -e

# Script to initialize git repository and push code to CodeCommit
# Usage: ./scripts/push-to-codecommit.sh [region]

REGION="${1:-us-gov-west-1}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=========================================="
echo "CodeCommit Repository Setup"
echo "=========================================="
echo "Region: $REGION"
echo "Project Root: $PROJECT_ROOT"
echo

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ ERROR: AWS CLI is not installed"
    echo "Please install AWS CLI: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo "❌ ERROR: git is not installed"
    echo "Please install git: https://git-scm.com/downloads"
    exit 1
fi

# Get CodeCommit repository URL from Terraform output
echo "📡 Fetching CodeCommit repository URL from Terraform..."
cd "$PROJECT_ROOT"

if [ ! -f "terraform.tfstate" ]; then
    echo "❌ ERROR: terraform.tfstate not found"
    echo "Please run 'terraform apply' first to create the CodeCommit repository"
    exit 1
fi

REPO_NAME=$(terraform output -raw codecommit_repository_name 2>/dev/null || echo "")

if [ -z "$REPO_NAME" ]; then
    echo "❌ ERROR: Could not get CodeCommit repository name"
    echo "Make sure the codecommit module is included and applied"
    exit 1
fi

# Check if git-remote-codecommit is installed
if command -v git-remote-codecommit &> /dev/null; then
    echo "✅ git-remote-codecommit is installed, using codecommit:// protocol"
    REPO_URL="codecommit::$REGION://$REPO_NAME"
    USE_GRC=true
else
    echo "⚠️  git-remote-codecommit not found, falling back to HTTPS with credential helper"
    echo "   For better IAM role support, install: pip install git-remote-codecommit"
    REPO_URL=$(terraform output -raw codecommit_clone_url_http 2>/dev/null || echo "")
    USE_GRC=false

    if [ -z "$REPO_URL" ]; then
        echo "❌ ERROR: Could not get CodeCommit repository URL"
        exit 1
    fi

    # Configure git credential helper for CodeCommit (HTTPS method)
    echo "🔧 Configuring git credential helper for CodeCommit..."
    git config --global credential.helper '!aws codecommit credential-helper $@'
    git config --global credential.UseHttpPath true
fi

echo "✅ Repository URL: $REPO_URL"
echo "✅ Repository Name: $REPO_NAME"
echo

# Check if already in a git repository
if [ -d ".git" ]; then
    echo "📁 Git repository already initialized"

    # Check if codecommit remote exists
    if git remote | grep -q "codecommit"; then
        echo "🔗 CodeCommit remote already configured"
        CURRENT_REMOTE=$(git remote get-url codecommit)
        echo "   Current remote: $CURRENT_REMOTE"

        if [ "$CURRENT_REMOTE" != "$REPO_URL" ]; then
            echo "🔄 Updating CodeCommit remote URL..."
            git remote set-url codecommit "$REPO_URL"
        fi
    else
        echo "➕ Adding CodeCommit remote..."
        git remote add codecommit "$REPO_URL"
    fi
else
    echo "🆕 Initializing new git repository..."
    git init
    git remote add codecommit "$REPO_URL"

    # Create .gitignore if it doesn't exist
    if [ ! -f ".gitignore" ]; then
        echo "📝 Creating .gitignore..."
        cat > .gitignore << 'EOF'
# Terraform
.terraform/
*.tfstate
*.tfstate.*
*.tfvars
*.tfvars.json
.terraform.lock.hcl
crash.log
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# Sensitive files
*.pem
*.key
*.crt
*.p12
*.pfx
credentials.json
secrets.yaml

# OS files
.DS_Store
Thumbs.db
*.swp
*.swo
*~

# IDE
.vscode/
.idea/
*.iml

# Backup files
*.backup
*.bak
EOF
    fi
fi

# Show current status
echo
echo "📊 Current git status:"
git status

# Add all files (respecting .gitignore)
echo
echo "➕ Adding files to git..."
git add .

# Check if there are changes to commit
if git diff --staged --quiet; then
    echo "ℹ️  No changes to commit"
else
    echo "💾 Committing changes..."
    COMMIT_MSG="Infrastructure code commit - $(date '+%Y-%m-%d %H:%M:%S')"
    git commit -m "$COMMIT_MSG"
fi

# Get current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

# If not on main branch, create/switch to main
if [ "$CURRENT_BRANCH" != "main" ]; then
    echo "🔀 Switching to main branch..."
    git checkout -b main 2>/dev/null || git checkout main
fi

# Push to CodeCommit
echo
echo "🚀 Pushing code to CodeCommit..."
echo "   Repository: $REPO_NAME"
echo "   Branch: main"
echo

if git push codecommit main; then
    echo
    echo "=========================================="
    echo "✅ SUCCESS!"
    echo "=========================================="
    echo "Code pushed to CodeCommit repository: $REPO_NAME"
    echo
    echo "Repository URL: $REPO_URL"
    echo
    echo "To clone this repository:"
    echo "  git clone $REPO_URL"
    echo
    echo "📋 Checkov security scan will run automatically on push to main branch"
    echo
    echo "To view Checkov scan results:"
    echo "  aws codebuild list-builds-for-project \\"
    echo "    --project-name \$(terraform output -raw codecommit_codebuild_project_name) \\"
    echo "    --region $REGION"
    echo
    echo "To view logs:"
    echo "  aws logs tail /aws/codebuild/\$(terraform output -raw codecommit_codebuild_project_name) \\"
    echo "    --follow \\"
    echo "    --region $REGION"
    echo "=========================================="
else
    echo
    echo "=========================================="
    echo "❌ ERROR: Failed to push to CodeCommit"
    echo "=========================================="
    echo
    echo "Common issues:"
    echo "1. AWS credentials not configured"
    echo "   - Run: aws sts get-caller-identity --region $REGION"
    echo "   - Configure: aws configure"
    echo
    echo "2. No permissions to push to CodeCommit"
    echo "   - Ensure your IAM user/role has codecommit:GitPush permission"
    echo
    echo "3. Using IAM roles without IAM user?"
    echo "   - Install git-remote-codecommit: pip install git-remote-codecommit"
    echo "   - Then run this script again"
    echo
    echo "4. Git credential helper not configured (HTTPS method)"
    echo "   - Run: git config --global credential.helper '!aws codecommit credential-helper \$@'"
    echo "   - Run: git config --global credential.UseHttpPath true"
    echo "=========================================="
    exit 1
fi
