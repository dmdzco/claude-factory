#!/usr/bin/env bash
#===============================================================================
# Claude Factory - Status Script
# Shows the current status of all droid worktrees
#===============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load project configuration
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

#-------------------------------------------------------------------------------
# Helper Functions
#-------------------------------------------------------------------------------

print_header() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

status_icon() {
    if [[ "$1" == "yes" || "$1" == "clean" ]]; then
        echo -e "${GREEN}●${NC}"
    else
        echo -e "${RED}○${NC}"
    fi
}

#-------------------------------------------------------------------------------
# Status Checks
#-------------------------------------------------------------------------------

check_worktree_status() {
    print_header "Droid Worktree Status"

    if [[ ! -d "$TARGET_REPO_PATH" ]]; then
        echo -e "${RED}Target repository not found: ${TARGET_REPO_PATH}${NC}"
        return
    fi

    cd "$TARGET_REPO_PATH"

    printf "%-20s %-10s %-30s %-15s\n" "DROID" "EXISTS" "BRANCH" "STATUS"
    printf "%-20s %-10s %-30s %-15s\n" "─────" "──────" "──────" "──────"

    for i in $(seq 1 $NUM_DROIDS); do
        local worktree_path="${REPO_PARENT_DIR}/${PROJECT_NAME}-${i}"
        local name="${PROJECT_NAME}-${i}"
        local exists="no"
        local branch="-"
        local status="-"

        if [[ -d "$worktree_path" ]]; then
            exists="yes"

            if [[ -f "${worktree_path}/.git" ]] || [[ -d "${worktree_path}/.git" ]]; then
                branch=$(cd "$worktree_path" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "detached")

                local changes=$(cd "$worktree_path" && git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
                if [[ "$changes" -eq 0 ]]; then
                    status="clean"
                else
                    status="${changes} changes"
                fi
            fi
        fi

        local icon=$(status_icon "$exists")
        printf "%s %-18s %-10s %-30s %-15s\n" "$icon" "$name" "$exists" "${branch:0:30}" "$status"
    done

    echo ""
    echo -e "${BLUE}Git Worktree List:${NC}"
    git worktree list 2>/dev/null || echo "  (could not list worktrees)"
    echo ""
}

check_claude_status() {
    print_header "Claude CLI Status"

    if command -v claude &> /dev/null; then
        echo -e "${GREEN}●${NC} Claude CLI installed: $(which claude)"
    else
        echo -e "${RED}○${NC} Claude CLI not found"
        echo "  Install with: npm install -g @anthropic-ai/claude-code"
    fi

    if [[ -d ~/.claude ]] && [[ -n "$(ls -A ~/.claude 2>/dev/null)" ]]; then
        echo -e "${GREEN}●${NC} Claude credentials found"
    else
        echo -e "${RED}○${NC} Claude credentials not found"
        echo "  Run 'claude' to authenticate"
    fi

    echo ""
}

check_coordination_status() {
    print_header "Coordination Status"

    local state_file="${SCRIPT_DIR}/factory-state.json"
    if [[ ! -f "$state_file" ]]; then
        echo -e "${YELLOW}No coordination state found. Run ./cf-init-coordination.sh${NC}"
        return
    fi

    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}jq not installed - cannot display coordination state${NC}"
        return
    fi

    echo -e "${BLUE}Droid States:${NC}"
    jq -r '.droids | to_entries[] | "  Droid \(.key): \(.value.status)\(if .value.task != "" then " - " + .value.task else "" end)"' "$state_file"

    echo ""
    echo -e "${BLUE}File Claims:${NC}"
    local claim_count
    claim_count=$(jq '.claims | length' "$state_file")
    if [[ "$claim_count" -eq 0 ]]; then
        echo "  (no files claimed)"
    else
        jq -r '.claims | to_entries[] | "  \(.key) → Droid \(.value.droid) (since \(.value.claimed_at))"' "$state_file"
    fi
    echo ""
}

show_quick_commands() {
    print_header "Quick Commands"

    echo "Setup droids:         ./cf-setup.sh"
    echo "Open all droids:      ./cf-dispatch.sh"
    echo "Open one droid:       ./cf-dispatch.sh --droid 1"
    echo "Reset worktrees:      ./cf-reset.sh"
    echo ""
    echo "Manual droid start:"
    for i in $(seq 1 $NUM_DROIDS); do
        echo "  cd ${REPO_PARENT_DIR}/${PROJECT_NAME}-${i} && claude --dangerously-skip-permissions"
    done
    echo ""
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------

main() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          CLAUDE FACTORY - STATUS                              ║${NC}"
    echo -e "${CYAN}║          Project: ${PROJECT_NAME}$(printf '%*s' $((38 - ${#PROJECT_NAME})) '')║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"

    check_claude_status
    check_coordination_status
    check_worktree_status
    show_quick_commands
}

main "$@"
