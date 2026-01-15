#!/usr/bin/env bash
#===============================================================================
# Donna AI Factory - Attach to Agent
# Opens a live view of an agent's activity
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

print_usage() {
    cat << EOF
${CYAN}Donna AI Factory - Attach to Agent${NC}

Usage:
  $(basename "$0") <agent-id> [mode]

Modes:
  watch     Watch the task output log (default)
  shell     Open a bash shell in the container
  claude    Start interactive Claude session
  logs      Show Docker container logs

Examples:
  $(basename "$0") 1           # Watch agent 1's output
  $(basename "$0") 2 shell     # Shell into agent 2
  $(basename "$0") 3 claude    # Interactive Claude with agent 3
  $(basename "$0") 4 logs      # Docker logs for agent 4

Tip: Open 5 terminal tabs and run this in each with different agent IDs
     to monitor all agents simultaneously.

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
if [[ ! "$AGENT_ID" =~ ^[1-5]$ ]]; then
    echo -e "${RED}Error: Agent ID must be 1-5${NC}"
    exit 1
fi

CONTAINER="donna-agent-${AGENT_ID}"

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo -e "${RED}Error: Container ${CONTAINER} is not running${NC}"
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
        echo -e "${BLUE}Watching task output... (Ctrl+C to exit)${NC}"
        echo -e "${YELLOW}Note: Output appears when agent is running a task${NC}"
        echo ""
        # Create the log file if it doesn't exist, then tail it
        docker exec "$CONTAINER" bash -c "touch /tmp/task-output.log && tail -f /tmp/task-output.log"
        ;;

    shell)
        echo -e "${BLUE}Opening shell... (type 'exit' to leave)${NC}"
        echo ""
        docker exec -it "$CONTAINER" bash -c "cd /workspace && exec bash"
        ;;

    claude)
        echo -e "${BLUE}Starting Claude session... (type 'exit' to leave)${NC}"
        echo ""
        docker exec -it "$CONTAINER" bash -c "cd /workspace && claude --dangerously-skip-permissions"
        ;;

    logs)
        echo -e "${BLUE}Docker container logs... (Ctrl+C to exit)${NC}"
        echo ""
        docker logs -f "$CONTAINER"
        ;;

    *)
        echo -e "${RED}Unknown mode: ${MODE}${NC}"
        print_usage
        exit 1
        ;;
esac
