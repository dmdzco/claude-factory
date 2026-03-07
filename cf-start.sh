#!/usr/bin/env bash
#===============================================================================
# Claude Factory - Start
# Sets up everything and opens terminal tabs with Claude sessions
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

# Load configuration (auto-configure if missing)
if [[ ! -f "${SCRIPT_DIR}/factory.conf" ]]; then
    echo -e "${YELLOW}[INFO]${NC} No factory.conf found. Running interactive configuration..."
    echo ""
    "${SCRIPT_DIR}/cf-configure.sh" "$@"
fi
source "${SCRIPT_DIR}/factory.conf"

# Support both new-style (TARGET_REPO_PATH) and old-style (TARGET_REPO) config
if [[ -z "${TARGET_REPO_PATH:-}" ]]; then
    PARENT_DIR="$(dirname "$SCRIPT_DIR")"
    TARGET_REPO_PATH="${PARENT_DIR}/${TARGET_REPO:-$PROJECT_NAME}"
fi
REPO_PARENT_DIR="$(dirname "$TARGET_REPO_PATH")"

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

print_header "Claude Factory - Full Start"

echo "This will:"
echo "  1. Create Git worktrees (if needed)"
echo "  2. Initialize coordination state"
echo "  3. Launch ${NUM_DROIDS} droids (1 per terminal tab)"
echo ""

# Step 1: Run setup
log_info "Running setup..."
"${SCRIPT_DIR}/cf-setup.sh"

# Step 2: Initialize coordination if not present
if [[ ! -f "${SCRIPT_DIR}/factory-state.json" ]]; then
    log_info "Initializing coordination state..."
    "${SCRIPT_DIR}/cf-init-coordination.sh"
fi

# Step 3: Launch droids in tmux
print_header "Launching Droids in tmux"

TMUX_SESSION="${PROJECT_NAME}-factory"

echo -e "${GREEN}${NUM_DROIDS} Claude droids will launch (1 per terminal tab).${NC}"
echo ""
echo "Each droid:"
echo "  - Has its own Git branch (feat/droid-X-workspace)"
echo "  - Has its own terminal tab with a tmux session"
echo "  - Coordinates via factory-state.json (cf-claim.sh/cf-release.sh)"
echo "  - Runs with --dangerously-skip-permissions"
echo ""
echo "Controls (remote/SSH):"
echo "  tmux attach -t ${PROJECT_NAME}-factory    Attach to all droids"
echo "  Ctrl-b, <number>    Switch between droid windows"
echo "  Ctrl-b, w           List all droid windows"
echo "  Ctrl-b, d           Detach (droids keep running)"
echo ""
echo "Controls (local/macOS):"
echo "  Cmd+1-${NUM_DROIDS}             Switch between droid tabs"
echo ""
echo "Commands:"
echo "  ./cf-status.sh                            - Check all droids"
echo "  ./cf-teardown.sh                          - Stop everything"
echo ""

# Use cf-dispatch.sh to handle tmux session creation
"${SCRIPT_DIR}/cf-dispatch.sh"
