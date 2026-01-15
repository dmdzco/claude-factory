#!/usr/bin/env bash
#===============================================================================
# Claude Factory - Safe Reset
# Fixes broken worktree references while preserving all commits
#===============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# Load project configuration
if [[ -f "${SCRIPT_DIR}/factory.conf" ]]; then
    source "${SCRIPT_DIR}/factory.conf"
else
    echo -e "${RED}[ERROR]${NC} factory.conf not found!"
    echo "Copy factory.conf.example to factory.conf and configure it."
    exit 1
fi

TARGET_REPO_PATH="${PARENT_DIR}/${TARGET_REPO:-$PROJECT_NAME}"

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

echo ""
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}  Claude Factory - Safe Reset (preserves commits)${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Project: ${PROJECT_NAME}"
echo ""

# Step 1: Stop containers
log_info "Stopping Docker containers..."
cd "$SCRIPT_DIR"
docker compose down 2>/dev/null || true

# Step 2: Show current branches with their commits
log_info "Current agent branches (commits will be preserved):"
cd "$TARGET_REPO_PATH"
for i in $(seq 1 $NUM_AGENTS); do
    branch="feat/agent-${i}-workspace"
    if git show-ref --verify --quiet "refs/heads/${branch}" 2>/dev/null; then
        commit=$(git log -1 --format="%h %s" "$branch" 2>/dev/null || echo "unknown")
        echo "  Agent ${i}: $commit"
    else
        echo "  Agent ${i}: (no branch yet)"
    fi
done
echo ""

# Step 3: FORCE remove all worktree metadata
log_info "Removing all worktree references..."
cd "$TARGET_REPO_PATH"

for i in $(seq 1 $NUM_AGENTS); do
    dir="${PARENT_DIR}/${PROJECT_NAME}-agent-${i}"
    worktree_meta=".git/worktrees/${PROJECT_NAME}-agent-${i}"

    # Remove the worktree directory
    if [[ -d "$dir" ]]; then
        rm -rf "$dir"
        log_info "  Removed directory: ${PROJECT_NAME}-agent-${i}"
    fi

    # FORCE remove worktree metadata from .git/worktrees/
    if [[ -d "$worktree_meta" ]]; then
        rm -rf "$worktree_meta"
        log_info "  Removed worktree metadata: ${PROJECT_NAME}-agent-${i}"
    fi
done

# Prune any remaining stale entries
git worktree prune 2>/dev/null || true

# Step 4: Delete and recreate branches to fix detached HEAD issues
log_info "Fixing any detached branches..."
cd "$TARGET_REPO_PATH"
current_branch=$(git branch --show-current)

for i in $(seq 1 $NUM_AGENTS); do
    branch="feat/agent-${i}-workspace"

    # If branch exists, save its commit and recreate it
    if git show-ref --verify --quiet "refs/heads/${branch}" 2>/dev/null; then
        # Get the commit the branch points to
        branch_commit=$(git rev-parse "$branch" 2>/dev/null || echo "")

        if [[ -n "$branch_commit" ]]; then
            # Delete and recreate the branch at the same commit
            git branch -D "$branch" 2>/dev/null || true
            git branch "$branch" "$branch_commit" 2>/dev/null || true
            log_info "  Fixed branch: $branch"
        fi
    fi
done

# Step 5: Verify branches
log_info "Verifying branches are preserved:"
for i in $(seq 1 $NUM_AGENTS); do
    branch="feat/agent-${i}-workspace"
    if git show-ref --verify --quiet "refs/heads/${branch}" 2>/dev/null; then
        commit=$(git log -1 --format="%h %s" "$branch" 2>/dev/null || echo "unknown")
        log_success "  $branch: $commit"
    else
        log_warning "  $branch: does not exist (will be created fresh)"
    fi
done

# Step 6: Show clean worktree list
echo ""
log_info "Current worktree list:"
git worktree list

echo ""
log_success "Reset complete! All commits preserved."
echo ""
echo "Now run ./setup.sh to recreate worktrees from existing branches."
echo ""
