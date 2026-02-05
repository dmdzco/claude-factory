#!/usr/bin/env bash
#===============================================================================
# Claude Factory - Attach to Agent
# Opens a view of an agent's worktree
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

print_usage() {
    cat << EOF
${CYAN}Claude Factory - Attach to Agent${NC}

Usage:
  $(basename "$0") <agent-id> [mode]

Modes:
  watch     Watch the agent's log file (default)
  shell     Open a bash shell in the worktree
  claude    Start interactive Claude session

Examples:
  $(basename "$0") 1           # Watch agent 1's output
  $(basename "$0") 2 shell     # Shell into agent 2's worktree
  $(basename "$0") 3 claude    # Interactive Claude with agent 3

Tip: Open multiple terminal tabs and run this in each with different
     agent IDs to monitor all agents simultaneously.

EOF
}

# Check arguments
if [[ $# -lt 1 ]]; then
    print_usage
    exit 1
fi

AGENT_ID="$1"
MODE="${2:-watch}"

# Validate agent ID
if [[ ! "$AGENT_ID" =~ ^[0-9]+$ ]] || [[ "$AGENT_ID" -lt 1 ]] || [[ "$AGENT_ID" -gt "$NUM_AGENTS" ]]; then
    echo -e "${RED}Error: Agent ID must be between 1 and ${NUM_AGENTS}${NC}"
    exit 1
fi

WORKTREE_DIR="${REPO_PARENT_DIR}/${PROJECT_NAME}-agent-${AGENT_ID}"

# Check if worktree exists
if [[ ! -d "$WORKTREE_DIR" ]]; then
    echo -e "${RED}Error: Worktree not found at ${WORKTREE_DIR}${NC}"
    echo "Run ./setup.sh first"
    exit 1
fi

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Agent ${AGENT_ID} - ${MODE} mode${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

case "$MODE" in
    watch)
        LOG_FILE="${SCRIPT_DIR}/logs/agent-${AGENT_ID}.log"
        echo -e "${BLUE}Watching agent log... (Ctrl+C to exit)${NC}"
        echo -e "${YELLOW}Note: Output appears when agent is running a task${NC}"
        echo ""
        touch "$LOG_FILE"
        tail -f "$LOG_FILE"
        ;;

    shell)
        echo -e "${BLUE}Opening shell in worktree... (type 'exit' to leave)${NC}"
        echo ""
        cd "$WORKTREE_DIR" && exec bash
        ;;

    claude)
        echo -e "${BLUE}Starting Claude session... (type 'exit' to leave)${NC}"
        echo ""
        cd "$WORKTREE_DIR" && claude --dangerously-skip-permissions --model "$DEFAULT_MODEL"
        ;;

    *)
        echo -e "${RED}Unknown mode: ${MODE}${NC}"
        print_usage
        exit 1
        ;;
esac
