#!/usr/bin/env bash
#===============================================================================
# Claude Factory - Initialize Coordination
# Creates the factory-state.json file for droid coordination
#===============================================================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Claude Factory - Initializing Coordination${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Check dependencies
if ! command -v jq &> /dev/null; then
    echo -e "${RED}[ERROR]${NC} jq is required for the coordination system."
    echo "Install with: brew install jq (macOS) or apt-get install jq (Linux)"
    exit 1
fi

STATE_FILE="${SCRIPT_DIR}/factory-state.json"

log_info "Creating coordination state for ${NUM_DROIDS} droids..."

# Build droids JSON dynamically
DROIDS_JSON="{}"
for i in $(seq 1 $NUM_DROIDS); do
    DROIDS_JSON=$(echo "$DROIDS_JSON" | jq \
        --arg id "$i" \
        --arg branch "feat/droid-${i}-workspace" \
        '.[$id] = {"status": "idle", "task": "", "branch": $branch, "last_update": ""}')
done

# Create the full state file
jq -n --argjson droids "$DROIDS_JSON" '{
    "droids": $droids,
    "claims": {},
    "messages": [],
    "tasks": {"high": [], "normal": [], "low": []}
}' > "$STATE_FILE"

log_success "Coordination state initialized!"
echo ""
echo "State file: ${STATE_FILE}"
echo ""
echo "Droid coordination commands:"
echo "  ./cf-claim.sh <droid-id> <file>     Claim a file before editing"
echo "  ./cf-release.sh <droid-id> [file]   Release a claim (or all claims)"
echo "  ./cf-status.sh                      View current state"
echo ""
