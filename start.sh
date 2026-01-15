#!/usr/bin/env bash
#===============================================================================
# Donna AI Factory - Start
# Sets up everything and opens 5 terminal tabs with Claude sessions
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

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

print_header() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------

print_header "Donna AI Factory - Full Start"

echo "This will:"
echo "  1. Create Git worktrees (if needed)"
echo "  2. Build & start Docker containers"
echo "  3. Open 5 terminal tabs with Claude sessions"
echo ""

# Step 1: Run setup (creates worktrees, starts containers)
log_info "Running setup..."
"${SCRIPT_DIR}/setup.sh"

# Step 2: Initialize coordination file if not present
DONNA_REPO="$(dirname "$SCRIPT_DIR")/donna"
if [[ ! -f "${DONNA_REPO}/FACTORY.md" ]]; then
    log_info "Initializing coordination file..."
    "${SCRIPT_DIR}/init-coordination.sh"
fi

# Step 3: Open terminal tabs with Claude sessions
print_header "Opening Agent Terminals"

# Detect terminal application using TERM_PROGRAM
if [[ "$TERM_PROGRAM" == "iTerm.app" ]]; then
    TERMINAL="iterm"
    log_info "Detected iTerm2"
elif [[ "$TERM_PROGRAM" == "Apple_Terminal" ]]; then
    TERMINAL="terminal"
    log_info "Detected Terminal.app"
elif [[ -d "/Applications/iTerm.app" ]]; then
    TERMINAL="iterm"
    log_info "Detected iTerm2"
elif [[ -d "/Applications/Utilities/Terminal.app" ]]; then
    TERMINAL="terminal"
    log_info "Detected Terminal.app"
else
    log_error "No supported terminal found"
    echo ""
    echo "Please open 5 terminal tabs manually and run:"
    for i in 1 2 3 4 5; do
        echo "  Tab ${i}: cd ${SCRIPT_DIR} && ./agent.sh ${i}"
    done
    exit 0
fi

log_info "Opening 5 tabs with Claude sessions..."

if [[ "$TERMINAL" == "iterm" ]]; then
    osascript <<EOF
tell application "iTerm"
    activate

    -- Create new window with first agent
    set newWindow to (create window with default profile)
    tell current session of newWindow
        set name to "Agent 1"
        write text "cd '${SCRIPT_DIR}' && ./agent.sh 1"
    end tell

    -- Create tabs for agents 2-5
    repeat with i from 2 to 5
        tell newWindow
            set newTab to (create tab with default profile)
            tell current session of newTab
                set name to "Agent " & i
                write text "cd '${SCRIPT_DIR}' && ./agent.sh " & i
            end tell
        end tell
    end repeat

    -- Select first tab
    tell newWindow
        select first tab
    end tell
end tell
EOF

elif [[ "$TERMINAL" == "terminal" ]]; then
    osascript <<EOF
tell application "Terminal"
    activate

    -- First tab (new window)
    do script "cd '${SCRIPT_DIR}' && ./agent.sh 1"
    delay 0.5

    -- Create tabs for agents 2-5
    repeat with i from 2 to 5
        tell application "System Events" to keystroke "t" using command down
        delay 0.3
        do script "cd '${SCRIPT_DIR}' && ./agent.sh " & i in front window
    end repeat
end tell
EOF
fi

print_header "Factory Started!"

echo -e "${GREEN}5 Claude agents are now running in separate tabs.${NC}"
echo ""
echo "Each agent:"
echo "  • Has its own Git branch (feat/agent-X-workspace)"
echo "  • Coordinates via FACTORY.md"
echo "  • Runs with --dangerously-skip-permissions"
echo ""
echo "Tips:"
echo "  • Give each agent a different task/area to work on"
echo "  • They'll claim files in FACTORY.md to avoid conflicts"
echo "  • Type directly in each tab to interact with that agent"
echo ""
echo "Commands:"
echo "  ./status.sh      - Check all agents"
echo "  ./teardown.sh    - Stop everything"
echo ""
