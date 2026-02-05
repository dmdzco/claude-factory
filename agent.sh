#!/usr/bin/env bash
#===============================================================================
# Claude Factory - Agent Session
# Starts an interactive Claude session for a specific agent
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
    echo -e "${RED}[ERROR]${NC} factory.conf not found! Run ./configure.sh first."
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
    echo "Usage: $0 <agent-id>"
    echo "  agent-id: 1-${NUM_AGENTS}"
    exit 1
fi

AGENT_ID="$1"

# Validate
if [[ ! "$AGENT_ID" =~ ^[0-9]+$ ]] || [[ "$AGENT_ID" -lt 1 ]] || [[ "$AGENT_ID" -gt "$NUM_AGENTS" ]]; then
    echo -e "${RED}Error: Agent ID must be between 1 and ${NUM_AGENTS}${NC}"
    exit 1
fi

WORKTREE_DIR="${REPO_PARENT_DIR}/${PROJECT_NAME}-agent-${AGENT_ID}"
BRANCH="feat/agent-${AGENT_ID}-workspace"

echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}           CLAUDE FACTORY - AGENT ${AGENT_ID}${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Check if worktree exists
if [[ ! -d "$WORKTREE_DIR" ]]; then
    echo -e "${RED}Error: Worktree not found at ${WORKTREE_DIR}${NC}"
    echo "Run ./setup.sh first"
    exit 1
fi

echo -e "${GREEN}Worktree:${NC}  ${WORKTREE_DIR}"
echo -e "${GREEN}Branch:${NC}    ${BRANCH}"
echo -e "${GREEN}Model:${NC}     ${DEFAULT_MODEL}"
echo ""
echo -e "${YELLOW}─────────────────────────────────────────────────────────────────${NC}"
echo -e "${YELLOW}  AGENT PROTOCOL REMINDER${NC}"
echo -e "${YELLOW}─────────────────────────────────────────────────────────────────${NC}"
echo ""
echo "  1. Claim files before editing: ../$(basename "$SCRIPT_DIR")/claim.sh ${AGENT_ID} <file>"
echo "  2. Don't touch files claimed by other agents"
echo "  3. Release claims when done: ../$(basename "$SCRIPT_DIR")/release.sh ${AGENT_ID}"
echo "  4. Check status: ../$(basename "$SCRIPT_DIR")/status.sh"
echo ""
echo -e "${YELLOW}─────────────────────────────────────────────────────────────────${NC}"
echo ""
echo -e "${BLUE}Starting Claude session...${NC}"
echo ""

# Start Claude in the worktree directory
cd "$WORKTREE_DIR"
claude --dangerously-skip-permissions --model "$DEFAULT_MODEL"

# If Claude exits, show message
echo ""
echo -e "${YELLOW}Claude session ended.${NC}"
echo ""
echo "To restart: $(dirname "$0")/agent.sh ${AGENT_ID}"
echo "To stop all: $(dirname "$0")/teardown.sh"
