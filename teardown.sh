#!/usr/bin/env bash
#===============================================================================
# Claude Factory - Teardown Script
# Removes worktrees and optionally branches
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
    echo -e "${RED}[ERROR]${NC} factory.conf not found! Run ./configure.sh first."
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

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

print_header() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_usage() {
    cat << EOF
${CYAN}Claude Factory - Teardown Script${NC}

Usage:
  $(basename "$0") [OPTIONS]

Options:
  --full               Remove worktrees AND delete branches + coordination state
  --force              Skip confirmation prompts
  -h, --help           Show this help message

Default behavior: Remove worktrees only (branches preserved)

EOF
}

#-------------------------------------------------------------------------------
# Teardown Functions
#-------------------------------------------------------------------------------

check_uncommitted_changes() {
    local has_changes=false

    for i in $(seq 1 $NUM_AGENTS); do
        local worktree_path="${REPO_PARENT_DIR}/${PROJECT_NAME}-agent-${i}"

        if [[ -d "$worktree_path" ]]; then
            local changes=$(cd "$worktree_path" && git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
            if [[ "$changes" -gt 0 ]]; then
                has_changes=true
                log_warning "${PROJECT_NAME}-agent-${i} has ${changes} uncommitted change(s)"
            fi
        fi
    done

    if [[ "$has_changes" == "true" ]]; then
        echo ""
        log_warning "Some worktrees have uncommitted changes!"
        log_warning "These will be LOST if you proceed."
        return 1
    fi

    return 0
}

remove_worktrees() {
    print_header "Removing Git Worktrees"

    if [[ ! -d "$TARGET_REPO_PATH" ]]; then
        log_error "Target repository not found at: $TARGET_REPO_PATH"
        return 1
    fi

    cd "$TARGET_REPO_PATH"

    for i in $(seq 1 $NUM_AGENTS); do
        local worktree_path="${REPO_PARENT_DIR}/${PROJECT_NAME}-agent-${i}"

        if [[ -d "$worktree_path" ]]; then
            log_info "Removing worktree: ${PROJECT_NAME}-agent-${i}"

            if git worktree remove "$worktree_path" --force 2>/dev/null; then
                log_success "Removed worktree: ${PROJECT_NAME}-agent-${i}"
            else
                log_warning "Git worktree remove failed, cleaning manually..."
                rm -rf "$worktree_path"
                git worktree prune 2>/dev/null || true
                log_success "Manually removed: ${PROJECT_NAME}-agent-${i}"
            fi
        else
            log_info "Worktree not found: ${PROJECT_NAME}-agent-${i}"
        fi
    done

    # Prune any stale worktree references
    log_info "Pruning stale worktree references..."
    git worktree prune 2>/dev/null || true

    log_success "All worktrees removed"
}

remove_branches() {
    print_header "Cleaning Up Branches"

    cd "$TARGET_REPO_PATH"

    for i in $(seq 1 $NUM_AGENTS); do
        local branch="feat/agent-${i}-workspace"

        if git show-ref --verify --quiet "refs/heads/${branch}"; then
            log_info "Deleting branch: $branch"
            git branch -D "$branch" 2>/dev/null || log_warning "Could not delete $branch"
        fi
    done
}

remove_coordination_state() {
    print_header "Cleaning Coordination State"

    local state_file="${SCRIPT_DIR}/factory-state.json"
    local lock_file="${state_file}.lock"

    if [[ -f "$state_file" ]]; then
        rm -f "$state_file"
        log_success "Removed factory-state.json"
    fi

    if [[ -f "$lock_file" ]]; then
        rm -f "$lock_file"
        log_success "Removed lock file"
    fi
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------

main() {
    local full_teardown=false
    local force=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --full)
                full_teardown=true
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            -h|--help)
                print_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done

    print_header "Claude Factory - Teardown"

    if [[ "$full_teardown" == "true" ]]; then
        echo -e "${YELLOW}WARNING: Full teardown will:${NC}"
        echo "  1. Remove all Git worktrees"
        echo "  2. Delete workspace branches"
        echo "  3. Clear coordination state"
        echo ""

        if ! check_uncommitted_changes && [[ "$force" != "true" ]]; then
            echo ""
            read -p "Are you sure you want to proceed? (y/N) " -n 1 -r
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Teardown cancelled"
                exit 0
            fi
        elif [[ "$force" != "true" ]]; then
            read -p "Proceed with full teardown? (y/N) " -n 1 -r
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Teardown cancelled"
                exit 0
            fi
        fi

        remove_worktrees
        remove_branches
        remove_coordination_state

        print_header "Full Teardown Complete"
        echo "To start fresh, run: ./setup.sh"
    else
        log_info "Removing worktrees only (branches preserved)"
        echo "Use --full to also remove branches and coordination state"
        echo ""

        if ! check_uncommitted_changes && [[ "$force" != "true" ]]; then
            echo ""
            read -p "Proceed? (y/N) " -n 1 -r
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Teardown cancelled"
                exit 0
            fi
        fi

        remove_worktrees

        print_header "Worktrees Removed"
        echo "Branches preserved. To recreate worktrees, run: ./setup.sh"
    fi
}

main "$@"
