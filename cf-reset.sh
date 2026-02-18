#!/usr/bin/env bash
#===============================================================================
# Claude Factory - Reset Worktrees
# Removes all droid worktrees (including stale/moved ones) while preserving
# branch commits. Run ./cf-setup.sh afterwards to recreate them cleanly.
#===============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

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
${CYAN}Claude Factory - Reset Worktrees${NC}

Usage:
  $(basename "$0") [OPTIONS]

Options:
  --delete-branches    Also delete the droid branches (commits will be lost)
  --force              Skip confirmation prompts
  -h, --help           Show this help message

Default behavior: Remove all droid worktrees, preserve branches and commits.
EOF
}

#-------------------------------------------------------------------------------
# Core Functions
#-------------------------------------------------------------------------------

# Find all worktrees associated with droid branches, even at unexpected paths
find_droid_worktrees() {
    cd "$TARGET_REPO_PATH"
    for i in $(seq 1 "$NUM_DROIDS"); do
        local branch="feat/droid-${i}-workspace"
        # Search for this branch in the porcelain worktree list
        git worktree list --porcelain 2>/dev/null | awk -v branch="refs/heads/${branch}" -v droid_num="$i" '
            /^worktree / { wt = substr($0, 10) }
            $0 == "branch " branch { print droid_num "\t" wt }
        '
    done
}

# Check for uncommitted changes across all droid worktrees
check_uncommitted() {
    local has_changes=false

    # Check expected paths
    for i in $(seq 1 "$NUM_DROIDS"); do
        local worktree_path="${REPO_PARENT_DIR}/${PROJECT_NAME}-droid-${i}"
        if [[ -d "$worktree_path" ]]; then
            local changes
            changes=$(cd "$worktree_path" && git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
            if [[ "$changes" -gt 0 ]]; then
                has_changes=true
                log_warning "Droid ${i} (${worktree_path}) has ${changes} uncommitted change(s)"
            fi
        fi
    done

    # Also check worktrees at unexpected paths
    while IFS=$'\t' read -r droid_num wt_path; do
        local expected="${REPO_PARENT_DIR}/${PROJECT_NAME}-droid-${droid_num}"
        if [[ "$wt_path" != "$expected" ]] && [[ -d "$wt_path" ]]; then
            local changes
            changes=$(cd "$wt_path" && git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
            if [[ "$changes" -gt 0 ]]; then
                has_changes=true
                log_warning "Droid ${droid_num} at stale path (${wt_path}) has ${changes} uncommitted change(s)"
            fi
        fi
    done < <(find_droid_worktrees)

    if [[ "$has_changes" == "true" ]]; then
        return 1
    fi
    return 0
}

remove_all_droid_worktrees() {
    cd "$TARGET_REPO_PATH"

    # 1. Remove worktrees at expected paths
    for i in $(seq 1 "$NUM_DROIDS"); do
        local worktree_path="${REPO_PARENT_DIR}/${PROJECT_NAME}-droid-${i}"
        if [[ -d "$worktree_path" ]]; then
            log_info "Removing worktree: ${worktree_path}"
            git worktree remove "$worktree_path" --force 2>/dev/null || {
                log_warning "  git worktree remove failed, cleaning manually..."
                rm -rf "$worktree_path"
            }
            log_success "  Removed: $(basename "$worktree_path")"
        fi
    done

    # 2. Remove worktrees at unexpected/stale paths (e.g. after project rename)
    while IFS=$'\t' read -r droid_num wt_path; do
        if [[ -d "$wt_path" ]]; then
            log_info "Removing stale worktree for droid ${droid_num}: ${wt_path}"
            git worktree remove "$wt_path" --force 2>/dev/null || {
                log_warning "  git worktree remove failed, cleaning manually..."
                rm -rf "$wt_path"
            }
            log_success "  Removed stale: ${wt_path}"
        fi
    done < <(find_droid_worktrees)

    # 3. Prune any remaining stale references
    git worktree prune 2>/dev/null || true

    # 4. Clean up any leftover .git/worktrees metadata
    for i in $(seq 1 "$NUM_DROIDS"); do
        local meta=".git/worktrees/${PROJECT_NAME}-droid-${i}"
        if [[ -d "$meta" ]]; then
            rm -rf "$meta"
            log_info "  Cleaned metadata: ${PROJECT_NAME}-droid-${i}"
        fi
    done

    git worktree prune 2>/dev/null || true
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------

main() {
    local delete_branches=false
    local force=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --delete-branches)
                delete_branches=true
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

    print_header "Claude Factory - Reset Worktrees"
    echo "Project: ${PROJECT_NAME}"
    echo "Droids:  ${NUM_DROIDS}"
    echo ""

    if [[ ! -d "$TARGET_REPO_PATH" ]]; then
        log_error "Target repository not found at: $TARGET_REPO_PATH"
        exit 1
    fi

    # Show current state
    log_info "Current droid branches:"
    cd "$TARGET_REPO_PATH"
    for i in $(seq 1 "$NUM_DROIDS"); do
        local branch="feat/droid-${i}-workspace"
        if git show-ref --verify --quiet "refs/heads/${branch}" 2>/dev/null; then
            local commit
            commit=$(git log -1 --format="%h %s" "$branch" 2>/dev/null || echo "unknown")
            echo "  Droid ${i}: $commit"
        else
            echo "  Droid ${i}: (no branch)"
        fi
    done
    echo ""

    log_info "Current worktrees:"
    git worktree list
    echo ""

    # Check for uncommitted changes
    if ! check_uncommitted && [[ "$force" != "true" ]]; then
        echo ""
        read -p "Worktrees have uncommitted changes. Proceed anyway? (y/N) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Reset cancelled."
            exit 0
        fi
    fi

    # Remove worktrees
    remove_all_droid_worktrees

    # Optionally delete branches
    if [[ "$delete_branches" == "true" ]]; then
        log_info "Deleting droid branches..."
        for i in $(seq 1 "$NUM_DROIDS"); do
            local branch="feat/droid-${i}-workspace"
            if git show-ref --verify --quiet "refs/heads/${branch}" 2>/dev/null; then
                git branch -D "$branch" 2>/dev/null || log_warning "Could not delete $branch"
                log_info "  Deleted: $branch"
            fi
        done
    fi

    # Reset coordination state
    if [[ -f "${SCRIPT_DIR}/factory-state.json" ]]; then
        log_info "Resetting coordination state..."
        "${SCRIPT_DIR}/cf-init-coordination.sh"
    fi

    # Final state
    echo ""
    log_info "Final worktree list:"
    git worktree list
    echo ""

    if [[ "$delete_branches" == "true" ]]; then
        log_success "Reset complete! Worktrees and branches removed."
    else
        log_success "Reset complete! Worktrees removed, branches preserved."
    fi
    echo ""
    echo "Run ./cf-setup.sh to recreate worktrees."
    echo ""
}

main "$@"
