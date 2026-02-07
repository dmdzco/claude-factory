#!/usr/bin/env bash
#===============================================================================
# Claude Factory - GitHub Token Setup
# Creates a Personal Access Token with write permissions for git push
#===============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Claude Factory - GitHub Token Setup${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}GitHub CLI (gh) is not installed.${NC}"
    echo ""
    echo "Install it with:"
    echo "  brew install gh"
    echo ""
    exit 1
fi

# Check current auth status
echo "Checking GitHub CLI authentication..."
if gh auth status &> /dev/null; then
    GH_USER=$(gh api user --jq '.login' 2>/dev/null || echo "unknown")
    echo -e "${GREEN}✓ Logged in as: ${BLUE}$GH_USER${NC}"
else
    echo -e "${YELLOW}GitHub CLI is not authenticated.${NC}"
    echo ""
    echo "Please log in to GitHub..."
    gh auth login
fi

echo ""
echo -e "${YELLOW}The droids need a token with WRITE permissions to push code.${NC}"
echo ""
echo "You have two options:"
echo ""
echo "  1. Create a new Fine-grained Personal Access Token (recommended)"
echo "     - Go to: https://github.com/settings/tokens?type=beta"
echo "     - Click 'Generate new token'"
echo "     - Name: 'Claude Factory'"
echo "     - Repository access: Select your target repository"
echo "     - Permissions → Repository permissions → Contents: Read and write"
echo "     - Click 'Generate token' and copy it"
echo ""
echo "  2. Create a Classic token with 'repo' scope"
echo "     - Go to: https://github.com/settings/tokens"
echo "     - Click 'Generate new token (classic)'"
echo "     - Select 'repo' scope"
echo "     - Generate and copy the token"
echo ""

read -p "Paste your GitHub token here: " GH_TOKEN

if [[ -z "$GH_TOKEN" ]]; then
    echo -e "${RED}No token provided. Exiting.${NC}"
    exit 1
fi

# Validate token has some access
echo ""
echo "Validating token..."
if curl -s -H "Authorization: token $GH_TOKEN" https://api.github.com/user | grep -q '"login"'; then
    TOKEN_USER=$(curl -s -H "Authorization: token $GH_TOKEN" https://api.github.com/user | grep '"login"' | cut -d'"' -f4)
    echo -e "${GREEN}✓ Token is valid for user: ${TOKEN_USER}${NC}"
else
    echo -e "${RED}Token appears invalid. Please check and try again.${NC}"
    exit 1
fi

# Save to .env file
ENV_FILE="${SCRIPT_DIR}/.env"
echo "GH_TOKEN=$GH_TOKEN" > "$ENV_FILE"
chmod 600 "$ENV_FILE"

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✓ Token saved to .env file${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Next steps:"
echo ""
echo "  1. Run setup and open droid terminals:"
echo "     ./cf-setup.sh"
echo "     ./cf-dispatch.sh"
echo ""
echo -e "${YELLOW}Note: The .env file is in .gitignore and won't be committed.${NC}"
echo ""
