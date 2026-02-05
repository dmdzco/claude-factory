#!/usr/bin/env bash
#===============================================================================
# Claude Factory - Claim a file for an agent
# Usage: ./claim.sh <agent-id> <file-path>
#===============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration
if [[ -f "${SCRIPT_DIR}/factory.conf" ]]; then
    source "${SCRIPT_DIR}/factory.conf"
else
    echo -e "${RED}[ERROR]${NC} factory.conf not found! Run ./configure.sh first."
    exit 1
fi

STATE_FILE="${SCRIPT_DIR}/factory-state.json"

# Check arguments
if [[ $# -lt 2 ]]; then
    echo "Usage: $(basename "$0") <agent-id> <file-path>"
    echo ""
    echo "Claims a file so other agents won't edit it."
    echo ""
    echo "Examples:"
    echo "  $(basename "$0") 1 src/auth.js"
    echo "  $(basename "$0") 2 lib/utils.py"
    echo "  $(basename "$0") external src/config.js   # External Claude instance"
    exit 1
fi

AGENT_ID="$1"
FILE_PATH="$2"

# Validate agent ID (numeric factory IDs like 1, 2, 3 or string IDs like "external", "cowork")
if [[ ! "$AGENT_ID" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo -e "${RED}[ERROR]${NC} Agent ID must be alphanumeric (letters, numbers, hyphens, underscores)"
    exit 1
fi

# Check dependencies
if ! command -v jq &> /dev/null; then
    echo -e "${RED}[ERROR]${NC} jq is required. Install with: brew install jq (macOS) or apt-get install jq (Linux)"
    exit 1
fi

# Check state file exists
if [[ ! -f "$STATE_FILE" ]]; then
    echo -e "${RED}[ERROR]${NC} factory-state.json not found. Run ./init-coordination.sh first."
    exit 1
fi

# Acquire lock for atomic read-modify-write
LOCK_FILE="${STATE_FILE}.lock"
exec 200>"$LOCK_FILE"
if ! flock -w 5 200; then
    echo -e "${RED}[ERROR]${NC} Could not acquire lock. Another operation may be in progress."
    exit 1
fi

# Check if file is already claimed
EXISTING_AGENT=$(jq -r --arg fp "$FILE_PATH" '.claims[$fp].agent // empty' "$STATE_FILE")

if [[ -n "$EXISTING_AGENT" ]]; then
    if [[ "$EXISTING_AGENT" == "$AGENT_ID" ]]; then
        echo -e "${YELLOW}[WARNING]${NC} Agent ${AGENT_ID} already has this file claimed: ${FILE_PATH}"
        flock -u 200
        exit 0
    else
        CLAIMED_AT=$(jq -r --arg fp "$FILE_PATH" '.claims[$fp].claimed_at // "unknown"' "$STATE_FILE")
        echo -e "${RED}[CONFLICT]${NC} File already claimed by Agent ${EXISTING_AGENT} (since ${CLAIMED_AT}): ${FILE_PATH}"
        flock -u 200
        exit 1
    fi
fi

# Add the claim
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TEMP_FILE=$(mktemp)
jq --arg fp "$FILE_PATH" \
   --arg agent "$AGENT_ID" \
   --arg ts "$TIMESTAMP" \
   '.claims[$fp] = {"agent": $agent, "claimed_at": $ts}' \
   "$STATE_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$STATE_FILE"

# Release lock
flock -u 200

echo -e "${GREEN}[CLAIMED]${NC} Agent ${AGENT_ID} claimed: ${FILE_PATH}"
