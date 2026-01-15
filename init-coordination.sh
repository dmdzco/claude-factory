#!/usr/bin/env bash
#===============================================================================
# Donna AI Factory - Initialize Coordination
# Sets up FACTORY.md in the main repo and syncs to all worktrees
#===============================================================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
DONNA_REPO="${PARENT_DIR}/donna"
NUM_AGENTS=5

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Initializing Factory Coordination${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Check if main repo exists
if [[ ! -d "$DONNA_REPO" ]]; then
    echo "Error: Donna repository not found at $DONNA_REPO"
    exit 1
fi

# Copy FACTORY.md to main repo
log_info "Copying FACTORY.md to main repository..."
cp "${SCRIPT_DIR}/FACTORY.md" "${DONNA_REPO}/FACTORY.md"

# Commit it
cd "$DONNA_REPO"
log_info "Committing FACTORY.md..."

# Check if it's already tracked
if git ls-files --error-unmatch FACTORY.md > /dev/null 2>&1; then
    log_info "FACTORY.md already tracked, updating..."
    git add FACTORY.md
    git commit -m "chore: Update factory coordination file" 2>/dev/null || log_warning "No changes to commit"
else
    git add FACTORY.md
    git commit -m "chore: Add factory coordination file"
fi

# Push to origin
log_info "Pushing to origin..."
git push origin main 2>/dev/null || log_warning "Could not push (offline or no remote?)"

# Sync all worktrees
log_info "Syncing worktrees..."
for i in $(seq 1 $NUM_AGENTS); do
    worktree="${PARENT_DIR}/donna-agent-${i}"
    if [[ -d "$worktree" ]]; then
        log_info "  Syncing donna-agent-${i}..."
        cd "$worktree"
        git fetch origin 2>/dev/null || true
        git rebase origin/main 2>/dev/null || git pull origin main --rebase 2>/dev/null || log_warning "Could not sync agent-${i}"
    fi
done

echo ""
log_success "Coordination initialized!"
echo ""
echo "FACTORY.md is now available in:"
echo "  - Main repo: ${DONNA_REPO}/FACTORY.md"
for i in $(seq 1 $NUM_AGENTS); do
    echo "  - Agent ${i}: ${PARENT_DIR}/donna-agent-${i}/FACTORY.md"
done
echo ""
echo "Agents will now coordinate through this file."
