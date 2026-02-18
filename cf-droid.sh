#!/usr/bin/env bash
#===============================================================================
# Claude Factory - Droid Session
# Starts an interactive Claude session for a specific droid
#===============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration
if [[ -f "${SCRIPT_DIR}/factory.conf" ]]; then
    source "${SCRIPT_DIR}/factory.conf"
else
    echo -e "${RED}[ERROR]${NC} factory.conf not found! Run ./cf-configure.sh first."
    exit 1
fi

# Support both new-style (TARGET_REPO_PATH) and old-style (TARGET_REPO) config
if [[ -z "${TARGET_REPO_PATH:-}" ]]; then
    PARENT_DIR="$(dirname "$SCRIPT_DIR")"
    TARGET_REPO_PATH="${PARENT_DIR}/${TARGET_REPO:-$PROJECT_NAME}"
fi
REPO_PARENT_DIR="$(dirname "$TARGET_REPO_PATH")"

# Check argument
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <droid-id>"
    echo "  droid-id: 1-${NUM_DROIDS}"
    exit 1
fi

DROID_ID="$1"

# Validate
if [[ ! "$DROID_ID" =~ ^[0-9]+$ ]] || [[ "$DROID_ID" -lt 1 ]] || [[ "$DROID_ID" -gt "$NUM_DROIDS" ]]; then
    echo -e "${RED}Error: Droid ID must be between 1 and ${NUM_DROIDS}${NC}"
    exit 1
fi

WORKTREE_DIR="${REPO_PARENT_DIR}/${PROJECT_NAME}-droid-${DROID_ID}"
BRANCH="feat/droid-${DROID_ID}-workspace"

echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}           CLAUDE FACTORY - DROID ${DROID_ID}${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Check if worktree exists
if [[ ! -d "$WORKTREE_DIR" ]]; then
    echo -e "${RED}Error: Worktree not found at ${WORKTREE_DIR}${NC}"
    echo "Run ./cf-setup.sh first"
    exit 1
fi

echo -e "${GREEN}Worktree:${NC}  ${WORKTREE_DIR}"
echo -e "${GREEN}Branch:${NC}    ${BRANCH}"
echo -e "${GREEN}Model:${NC}     ${DEFAULT_MODEL}"
echo ""
echo -e "${YELLOW}─────────────────────────────────────────────────────────────────${NC}"
echo -e "${YELLOW}  DROID PROTOCOL REMINDER${NC}"
echo -e "${YELLOW}─────────────────────────────────────────────────────────────────${NC}"
echo ""
echo "  1. Claim files before editing: ../$(basename "$SCRIPT_DIR")/cf-claim.sh ${DROID_ID} <file>"
echo "  2. Don't touch files claimed by other droids"
echo "  3. Release claims when done: ../$(basename "$SCRIPT_DIR")/cf-release.sh ${DROID_ID}"
echo "  4. Check status: ../$(basename "$SCRIPT_DIR")/cf-status.sh"
echo ""
echo -e "${YELLOW}─────────────────────────────────────────────────────────────────${NC}"
echo ""
echo -e "${BLUE}Starting Claude session...${NC}"
echo ""

# Start Claude in the worktree directory
cd "$WORKTREE_DIR"
unset GH_TOKEN
claude --dangerously-skip-permissions --model "$DEFAULT_MODEL"

# If Claude exits, show message
echo ""
echo -e "${YELLOW}Claude session ended.${NC}"
echo ""
echo "To restart: $(dirname "$0")/cf-droid.sh ${DROID_ID}"
echo "To stop all: $(dirname "$0")/cf-teardown.sh"
