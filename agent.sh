#!/usr/bin/env bash
#===============================================================================
# Donna AI Factory - Agent Session
# Starts an interactive Claude session for a specific agent
#===============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check argument
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <agent-id>"
    echo "  agent-id: 1-5"
    exit 1
fi

AGENT_ID="$1"

# Validate
if [[ ! "$AGENT_ID" =~ ^[1-5]$ ]]; then
    echo -e "${RED}Error: Agent ID must be 1-5${NC}"
    exit 1
fi

CONTAINER="donna-agent-${AGENT_ID}"
BRANCH="feat/agent-${AGENT_ID}-workspace"

# Wait for container to be ready
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}           DONNA AI FACTORY - AGENT ${AGENT_ID}${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Check if container is running, wait if not
MAX_WAIT=30
WAITED=0
while ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; do
    if [[ $WAITED -ge $MAX_WAIT ]]; then
        echo -e "${RED}Error: Container ${CONTAINER} not running after ${MAX_WAIT}s${NC}"
        echo "Run ./setup.sh first"
        exit 1
    fi
    echo -e "${YELLOW}Waiting for container to start...${NC}"
    sleep 2
    ((WAITED+=2))
done

echo -e "${GREEN}Container:${NC} ${CONTAINER}"
echo -e "${GREEN}Branch:${NC}    ${BRANCH}"
echo -e "${GREEN}Workspace:${NC} /workspace"
echo ""
echo -e "${YELLOW}─────────────────────────────────────────────────────────────────${NC}"
echo -e "${YELLOW}  AGENT PROTOCOL REMINDER${NC}"
echo -e "${YELLOW}─────────────────────────────────────────────────────────────────${NC}"
echo ""
echo "  1. Read FACTORY.md before starting work"
echo "  2. Claim files before editing them"
echo "  3. Don't touch files claimed by other agents"
echo "  4. Update FACTORY.md when done"
echo ""
echo -e "${YELLOW}─────────────────────────────────────────────────────────────────${NC}"
echo ""
echo -e "${BLUE}Starting Claude session...${NC}"
echo ""

# Start Claude with the agent protocol as system context
docker exec -it "$CONTAINER" bash -c "
    cd /workspace

    # Set a custom prompt to show agent ID
    export PS1='[Agent-${AGENT_ID}] \w \$ '

    # Start Claude with protocol reminder
    claude --dangerously-skip-permissions
"

# If Claude exits, show message
echo ""
echo -e "${YELLOW}Claude session ended.${NC}"
echo ""
echo "To restart: ./agent.sh ${AGENT_ID}"
echo "To stop all: ./teardown.sh"
