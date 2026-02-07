#!/usr/bin/env bash
#===============================================================================
# Claude Factory - Release file claim(s) for a droid
# Usage: ./cf-release.sh <droid-id> [file-path]
#   If file-path omitted, releases ALL claims for that droid
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
    echo -e "${RED}[ERROR]${NC} factory.conf not found! Run ./cf-configure.sh first."
    exit 1
fi

STATE_FILE="${SCRIPT_DIR}/factory-state.json"

# Check arguments
if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename "$0") <droid-id> [file-path]"
    echo ""
    echo "Releases a file claim. If no file specified, releases ALL claims for the droid."
    echo ""
    echo "Examples:"
    echo "  $(basename "$0") 1 src/auth.js    # Release specific file"
    echo "  $(basename "$0") 1                # Release all files for droid 1"
    echo "  $(basename "$0") external src/config.js  # External instance release"
    exit 1
fi

DROID_ID="$1"
FILE_PATH="${2:-}"

# Validate droid ID (numeric factory IDs like 1, 2, 3 or string IDs like "external", "cowork")
if [[ ! "$DROID_ID" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo -e "${RED}[ERROR]${NC} Droid ID must be alphanumeric (letters, numbers, hyphens, underscores)"
    exit 1
fi

# Check dependencies
if ! command -v jq &> /dev/null; then
    echo -e "${RED}[ERROR]${NC} jq is required. Install with: brew install jq (macOS) or apt-get install jq (Linux)"
    exit 1
fi

# Check state file exists
if [[ ! -f "$STATE_FILE" ]]; then
    echo -e "${RED}[ERROR]${NC} factory-state.json not found. Run ./cf-init-coordination.sh first."
    exit 1
fi

# Acquire lock
LOCK_FILE="${STATE_FILE}.lock"
exec 200>"$LOCK_FILE"
if ! flock -w 5 200; then
    echo -e "${RED}[ERROR]${NC} Could not acquire lock. Another operation may be in progress."
    exit 1
fi

TEMP_FILE=$(mktemp)

if [[ -n "$FILE_PATH" ]]; then
    # Release specific file
    EXISTING_DROID=$(jq -r --arg fp "$FILE_PATH" '.claims[$fp].droid // empty' "$STATE_FILE")

    if [[ -z "$EXISTING_DROID" ]]; then
        echo -e "${YELLOW}[WARNING]${NC} File is not claimed: ${FILE_PATH}"
        flock -u 200
        rm -f "$TEMP_FILE"
        exit 0
    fi

    if [[ "$EXISTING_DROID" != "$DROID_ID" ]]; then
        echo -e "${RED}[ERROR]${NC} File is claimed by Droid ${EXISTING_DROID}, not Droid ${DROID_ID}: ${FILE_PATH}"
        flock -u 200
        rm -f "$TEMP_FILE"
        exit 1
    fi

    jq --arg fp "$FILE_PATH" 'del(.claims[$fp])' "$STATE_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$STATE_FILE"
    echo -e "${GREEN}[RELEASED]${NC} Droid ${DROID_ID} released: ${FILE_PATH}"
else
    # Release ALL claims for this droid
    CLAIMED_FILES=$(jq -r --arg droid "$DROID_ID" '.claims | to_entries[] | select(.value.droid == $droid) | .key' "$STATE_FILE")

    if [[ -z "$CLAIMED_FILES" ]]; then
        echo -e "${YELLOW}[WARNING]${NC} Droid ${DROID_ID} has no active claims."
        flock -u 200
        rm -f "$TEMP_FILE"
        exit 0
    fi

    jq --arg droid "$DROID_ID" '.claims |= with_entries(select(.value.droid != $droid))' "$STATE_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$STATE_FILE"

    echo -e "${GREEN}[RELEASED]${NC} Droid ${DROID_ID} released all claims:"
    echo "$CLAIMED_FILES" | while read -r f; do
        echo "  - ${f}"
    done
fi

# Release lock
flock -u 200
