#!/usr/bin/env bash
#===============================================================================
# Donna AI Factory - Teardown Script
# Gracefully shuts down agents and optionally removes worktrees
#===============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
DONNA_REPO="${PARENT_DIR}/donna"
NUM_AGENTS=5

#-------------------------------------------------------------------------------
# Helper Functions
#-------------------------------------------------------------------------------

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_usage() {
    cat << EOF
${CYAN}Donna AI Factory - Teardown Script${NC}

Usage:
  $(basename "$0") [OPTIONS]

Options:
  --containers-only    Only stop containers, keep worktrees
  --full               Stop containers AND remove worktrees
  --force              Skip confirmation prompts
  -h, --help           Show this help message

Default behavior: Stop containers only (worktrees preserved)

EOF
}

#-------------------------------------------------------------------------------
# Teardown Functions
#-------------------------------------------------------------------------------

stop_containers() {
    print_header "Stopping Docker Containers"

    cd "$SCRIPT_DIR"

    # Check if any containers are running
    local running=$(docker compose ps -q 2>/dev/null | wc -l | tr -d ' ')

    if [[ "$running" -eq 0 ]]; then
        log_info "No containers running"
        return 0
    fi

    log_info "Stopping ${running} container(s)..."

    if docker compose down 2>&1; then
        log_success "All containers stopped"
    else
        log_warning "Some containers may not have stopped cleanly"
    fi

    # Verify all stopped
    local still_running=$(docker ps --filter "name=donna-agent" -q 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$still_running" -gt 0 ]]; then
        log_warning "${still_running} container(s) still running, forcing stop..."
        docker ps --filter "name=donna-agent" -q | xargs -r docker stop
        docker ps --filter "name=donna-agent" -q | xargs -r docker rm -f
    fi
}

check_uncommitted_changes() {
    local has_changes=false

    for i in $(seq 1 $NUM_AGENTS); do
        local worktree_path="${PARENT_DIR}/donna-agent-${i}"

        if [[ -d "$worktree_path" ]]; then
            local changes=$(cd "$worktree_path" && git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
            if [[ "$changes" -gt 0 ]]; then
                has_changes=true
                log_warning "donna-agent-${i} has ${changes} uncommitted change(s)"
            fi
        fi
    done

    if [[ "$has_changes" == "true" ]]; then
        echo ""
        log_warning "Some worktrees have uncommitted changes!"
        log_warning "These will be LOST if you proceed with --full teardown"
        return 1
    fi

    return 0
}

remove_worktrees() {
    print_header "Removing Git Worktrees"

    if [[ ! -d "$DONNA_REPO" ]]; then
        log_error "Donna repository not found at: $DONNA_REPO"
        return 1
    fi

    cd "$DONNA_REPO"

    for i in $(seq 1 $NUM_AGENTS); do
        local worktree_path="${PARENT_DIR}/donna-agent-${i}"

        if [[ -d "$worktree_path" ]]; then
            log_info "Removing worktree: donna-agent-${i}"

            # First try to remove via git
            if git worktree remove "$worktree_path" --force 2>/dev/null; then
                log_success "Removed worktree: donna-agent-${i}"
            else
                # Fallback: manual removal
                log_warning "Git worktree remove failed, cleaning manually..."
                rm -rf "$worktree_path"
                git worktree prune 2>/dev/null || true
                log_success "Manually removed: donna-agent-${i}"
            fi
        else
            log_info "Worktree not found: donna-agent-${i}"
        fi
    done

    # Prune any stale worktree references
    log_info "Pruning stale worktree references..."
    git worktree prune 2>/dev/null || true

    log_success "All worktrees removed"
}

remove_branches() {
    print_header "Cleaning Up Branches"

    cd "$DONNA_REPO"

    for i in $(seq 1 $NUM_AGENTS); do
        local branch="feat/agent-${i}-workspace"

        # Check if branch exists
        if git show-ref --verify --quiet "refs/heads/${branch}"; then
            log_info "Deleting branch: $branch"
            git branch -D "$branch" 2>/dev/null || log_warning "Could not delete $branch"
        fi
    done
}

cleanup_docker_resources() {
    print_header "Cleaning Docker Resources"

    log_info "Removing donna-factory network..."
    docker network rm donna-factory-network 2>/dev/null || true

    log_info "Removing dangling images..."
    docker image prune -f 2>/dev/null || true

    log_success "Docker resources cleaned"
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------

main() {
    local containers_only=true
    local full_teardown=false
    local force=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --containers-only)
                containers_only=true
                full_teardown=false
                shift
                ;;
            --full)
                containers_only=false
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

    print_header "Donna AI Factory - Teardown"

    if [[ "$full_teardown" == "true" ]]; then
        echo -e "${YELLOW}WARNING: Full teardown will:${NC}"
        echo "  1. Stop all Docker containers"
        echo "  2. Remove all Git worktrees"
        echo "  3. Delete workspace branches"
        echo "  4. Clean up Docker resources"
        echo ""

        # Check for uncommitted changes
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

        stop_containers
        remove_worktrees
        remove_branches
        cleanup_docker_resources

        print_header "Full Teardown Complete"
        echo "To start fresh, run: ./setup.sh"
    else
        log_info "Stopping containers only (worktrees preserved)"
        echo "Use --full to also remove worktrees and branches"
        echo ""

        stop_containers
        cleanup_docker_resources

        print_header "Containers Stopped"
        echo "Worktrees preserved. To restart, run: docker compose up -d"
    fi
}

main "$@"
