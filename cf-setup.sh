#!/usr/bin/env bash
#===============================================================================
# Claude Factory - Setup Script
# Creates git worktrees for parallel Claude droids
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
LOG_DIR="${SCRIPT_DIR}/logs"

# Load project configuration (auto-configure if missing)
if [[ ! -f "${SCRIPT_DIR}/factory.conf" ]]; then
    echo -e "${YELLOW}[INFO]${NC} No factory.conf found. Running interactive configuration..."
    echo ""
    "${SCRIPT_DIR}/cf-configure.sh" "$@"
    # Re-parse args below since cf-configure.sh consumed the path arg
    set --
fi
source "${SCRIPT_DIR}/factory.conf"

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

log_header() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

#-------------------------------------------------------------------------------
# Pre-flight Checks
#-------------------------------------------------------------------------------

preflight_checks() {
    log_header "Pre-flight Checks"

    # Check if target repo exists
    if [[ ! -d "$TARGET_REPO_PATH" ]]; then
        log_error "Target repository not found at: $TARGET_REPO_PATH"
        log_error "Run ./cf-configure.sh to fix your project path."
        exit 1
    fi
    log_success "Target repository found: $TARGET_REPO_PATH"

    # Check if it's a Git repository
    if [[ ! -d "${TARGET_REPO_PATH}/.git" ]]; then
        log_error "$TARGET_REPO_PATH is not a Git repository"
        exit 1
    fi
    log_success "$PROJECT_NAME is a valid Git repository"

    # Check for Claude CLI
    if ! command -v claude &> /dev/null; then
        log_error "Claude CLI not found. Install with: npm install -g @anthropic-ai/claude-code"
        exit 1
    fi
    log_success "Claude CLI installed"

    # Check for Claude auth
    if [[ -d ~/.claude ]] && [[ -n "$(ls -A ~/.claude 2>/dev/null)" ]]; then
        log_success "Claude credentials found"
    else
        log_warning "Claude credentials not found. Run 'claude' to authenticate first."
    fi

    # Check for git
    if ! command -v git &> /dev/null; then
        log_error "Git not found"
        exit 1
    fi
    log_success "Git installed"

    # Check for jq (needed for coordination)
    if ! command -v jq &> /dev/null; then
        log_error "jq not found. Install with: brew install jq (macOS) or apt-get install jq (Linux)"
        exit 1
    fi
    log_success "jq installed"

    # Create logs directory
    mkdir -p "$LOG_DIR"
}

#-------------------------------------------------------------------------------
# Git Worktree Setup
#-------------------------------------------------------------------------------

setup_worktrees() {
    log_header "Setting Up Git Worktrees"

    cd "$TARGET_REPO_PATH"

    # Fetch latest from remote
    log_info "Fetching latest changes from remote..."
    git fetch --all --prune 2>/dev/null || log_warning "Could not fetch from remote (offline?)"

    # Get the current branch name for the base
    local base_branch
    base_branch=$(git branch --show-current)
    log_info "Base branch: $base_branch"

    for i in $(seq 1 $NUM_DROIDS); do
        local worktree_path="${REPO_PARENT_DIR}/${PROJECT_NAME}-droid-${i}"
        local branch_name="feat/droid-${i}-workspace"

        if [[ -d "$worktree_path" ]]; then
            log_info "Worktree already exists: ${PROJECT_NAME}-droid-${i}"

            if git worktree list | grep -q "$worktree_path"; then
                log_success "Verified worktree: ${PROJECT_NAME}-droid-${i}"
            else
                log_warning "Directory exists but is not a worktree. Cleaning up..."
                rm -rf "$worktree_path"
                create_worktree "$worktree_path" "$branch_name" "$base_branch"
            fi
        else
            create_worktree "$worktree_path" "$branch_name" "$base_branch"
        fi
    done

    log_info "Listing all worktrees:"
    git worktree list
}

create_worktree() {
    local worktree_path="$1"
    local branch_name="$2"
    local base_branch="$3"

    log_info "Creating worktree for: $(basename "$worktree_path")"

    # Check if the branch is already checked out in another worktree
    local existing_worktree
    existing_worktree=$(git worktree list --porcelain | awk -v branch="refs/heads/${branch_name}" '
        /^worktree / { wt = substr($0, 10) }
        $0 == "branch " branch { print wt }
    ')

    if [[ -n "$existing_worktree" ]]; then
        if [[ "$existing_worktree" == "$worktree_path" ]]; then
            log_info "  Worktree already exists at the correct path"
            log_success "Verified worktree: $(basename "$worktree_path")"
            return 0
        fi

        log_warning "  Branch '$branch_name' is already used by worktree at: $existing_worktree"

        if [[ -d "$existing_worktree" ]]; then
            log_info "  Removing stale worktree at: $existing_worktree"
            git worktree remove "$existing_worktree" --force 2>/dev/null || {
                log_warning "  git worktree remove failed, cleaning manually..."
                rm -rf "$existing_worktree"
            }
        fi
        git worktree prune 2>/dev/null || true
        log_success "  Cleared stale worktree reference"
    fi

    if git show-ref --verify --quiet "refs/heads/${branch_name}"; then
        log_info "  Using existing local branch: $branch_name"
        git worktree add "$worktree_path" "$branch_name"
    elif git show-ref --verify --quiet "refs/remotes/origin/${branch_name}"; then
        log_info "  Checking out remote branch: $branch_name"
        git worktree add "$worktree_path" "$branch_name"
    else
        log_info "  Creating new branch: $branch_name (from $base_branch)"
        git worktree add -b "$branch_name" "$worktree_path" "$base_branch"
    fi

    log_success "Created worktree: $(basename "$worktree_path")"
}

#-------------------------------------------------------------------------------
# Print Summary
#-------------------------------------------------------------------------------

print_summary() {
    log_header "Setup Complete!"

    echo -e "${GREEN}Your Claude Factory is ready!${NC}"
    echo ""
    echo "Project: ${PROJECT_NAME}"
    echo "Droids:  ${NUM_DROIDS}"
    echo ""
    echo "Quick Commands:"
    echo "  - Open droid terminals:       ./cf-dispatch.sh"
    echo "  - Check status:               ./cf-status.sh"
    echo "  - Reset (keep commits):       ./cf-reset.sh"
    echo ""
    echo "Droid Worktrees:"
    for i in $(seq 1 $NUM_DROIDS); do
        echo "  - Droid ${i}: ${REPO_PARENT_DIR}/${PROJECT_NAME}-droid-${i}"
    done
    echo ""
    echo -e "${GREEN}Run ./cf-dispatch.sh to open all droid terminals!${NC}"
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n)
                local new_count="$2"
                if [[ ! "$new_count" =~ ^[0-9]+$ ]] || [[ "$new_count" -lt 1 ]] || [[ "$new_count" -gt 10 ]]; then
                    log_error "Droid count must be between 1 and 10"
                    exit 1
                fi
                NUM_DROIDS="$new_count"
                # Save back to factory.conf (portable sed)
                if [[ "$(uname)" == "Darwin" ]]; then
                    sed -i '' "s/^NUM_DROIDS=.*/NUM_DROIDS=${NUM_DROIDS}/" "${SCRIPT_DIR}/factory.conf"
                else
                    sed -i "s/^NUM_DROIDS=.*/NUM_DROIDS=${NUM_DROIDS}/" "${SCRIPT_DIR}/factory.conf"
                fi
                log_info "Updated NUM_DROIDS=${NUM_DROIDS} in factory.conf"
                shift 2
                ;;
            -h|--help)
                echo "Usage: $(basename "$0") [-n <num_droids>] [-h]"
                echo ""
                echo "Options:"
                echo "  -n <NUM>   Set number of droids (1-10), saves to factory.conf"
                echo "  -h, --help Show this help"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    log_header "Claude Factory Setup"
    echo "Project: ${PROJECT_NAME}"
    echo "Droids:  ${NUM_DROIDS}"
    echo ""

    preflight_checks
    setup_worktrees
    print_summary
}

main "$@"
