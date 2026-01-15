#!/usr/bin/env bash
#===============================================================================
# Claude Factory - Setup Script
# Multi-agent orchestration for any project
# Uses HTTPS + GH_TOKEN for authentication (no SSH complexity)
#===============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="${SCRIPT_DIR}/logs"

# Load project configuration
if [[ -f "${SCRIPT_DIR}/factory.conf" ]]; then
    source "${SCRIPT_DIR}/factory.conf"
else
    echo -e "${RED}[ERROR]${NC} factory.conf not found!"
    echo "Copy factory.conf.example to factory.conf and configure it."
    exit 1
fi

# Derived configuration
TARGET_REPO_PATH="${PARENT_DIR}/${TARGET_REPO:-$PROJECT_NAME}"

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

    # Check for .env file with GH_TOKEN - create if missing
    if [[ ! -f "${SCRIPT_DIR}/.env" ]] || ! grep -q "GH_TOKEN=" "${SCRIPT_DIR}/.env" 2>/dev/null; then
        log_warning "No GitHub token configured!"
        echo ""
        echo "Agents need a Personal Access Token with WRITE permissions to push code."
        echo ""
        echo "Create one at: https://github.com/settings/tokens"
        echo "  - For Fine-grained: Select repo → Contents: Read and write"
        echo "  - For Classic: Check 'repo' scope"
        echo ""
        read -p "Paste your GitHub token here: " GH_TOKEN

        if [[ -z "$GH_TOKEN" ]]; then
            log_error "No token provided. Cannot continue."
            exit 1
        fi

        # Save to .env
        echo "GH_TOKEN=$GH_TOKEN" > "${SCRIPT_DIR}/.env"
        chmod 600 "${SCRIPT_DIR}/.env"
        log_success "Token saved to .env"
    fi

    # Source .env and verify token exists
    source "${SCRIPT_DIR}/.env"
    if [[ -z "${GH_TOKEN:-}" ]]; then
        log_error "GH_TOKEN not set in .env file!"
        exit 1
    fi
    log_success "GitHub token configured"

    # Check if Docker is running
    if ! docker info > /dev/null 2>&1; then
        log_error "Docker is not running. Please start Docker Desktop and try again."
        exit 1
    fi
    log_success "Docker is running"

    # Check if docker-compose is available
    if ! docker compose version &> /dev/null; then
        log_error "docker compose is not available. Please install Docker Desktop."
        exit 1
    fi
    log_success "Docker Compose is available"

    # Check if target repo exists
    if [[ ! -d "$TARGET_REPO_PATH" ]]; then
        log_error "Target repository not found at: $TARGET_REPO_PATH"
        log_error "Please ensure the ${TARGET_REPO:-$PROJECT_NAME} folder exists parallel to claude-factory"
        exit 1
    fi
    log_success "Target repository found: ${TARGET_REPO:-$PROJECT_NAME}"

    # Check if it's a Git repository
    if [[ ! -d "${TARGET_REPO_PATH}/.git" ]]; then
        log_error "${TARGET_REPO:-$PROJECT_NAME} folder is not a Git repository"
        exit 1
    fi
    log_success "${TARGET_REPO:-$PROJECT_NAME} is a valid Git repository"

    # Check for Claude credentials
    if [[ -d ~/.claude ]]; then
        log_success "Claude credentials found"
    else
        log_warning "Claude credentials not found (~/.claude/)"
        log_warning "Run 'claude' in your terminal and log in first."
    fi

    # Create logs directory
    mkdir -p "$LOG_DIR"
}

#-------------------------------------------------------------------------------
# Ensure remote uses HTTPS (not SSH)
#-------------------------------------------------------------------------------

ensure_https_remote() {
    local repo_path="$1"
    cd "$repo_path"

    local current_url
    current_url=$(git remote get-url origin 2>/dev/null || echo "")

    if [[ "$current_url" == git@github.com:* ]]; then
        # Convert SSH to HTTPS: git@github.com:user/repo.git -> https://github.com/user/repo.git
        local repo_part="${current_url#git@github.com:}"
        local https_url="https://github.com/${repo_part}"
        git remote set-url origin "$https_url"
        log_info "  Converted remote to HTTPS: $https_url"
    elif [[ "$current_url" == https://github.com/* ]]; then
        log_info "  Remote already using HTTPS"
    fi
}

#-------------------------------------------------------------------------------
# Git Worktree Setup
#-------------------------------------------------------------------------------

setup_worktrees() {
    log_header "Setting Up Git Worktrees"

    cd "$TARGET_REPO_PATH"

    # Ensure main repo uses HTTPS
    log_info "Ensuring HTTPS remote..."
    ensure_https_remote "$TARGET_REPO_PATH"

    # Fetch latest from remote
    log_info "Fetching latest changes from remote..."
    git fetch --all --prune 2>/dev/null || log_warning "Could not fetch from remote (offline?)"

    # Get the current branch name for the base
    local base_branch
    base_branch=$(git branch --show-current)
    log_info "Base branch: $base_branch"

    for i in $(seq 1 $NUM_AGENTS); do
        local worktree_path="${PARENT_DIR}/${PROJECT_NAME}-agent-${i}"
        local branch_name="feat/agent-${i}-workspace"

        if [[ -d "$worktree_path" ]]; then
            log_info "Worktree already exists: ${PROJECT_NAME}-agent-${i}"

            if git worktree list | grep -q "$worktree_path"; then
                log_success "Verified worktree: ${PROJECT_NAME}-agent-${i}"
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

    # Copy CLAUDE.md for agent instructions
    if [[ -f "${SCRIPT_DIR}/CLAUDE.md" ]]; then
        cp "${SCRIPT_DIR}/CLAUDE.md" "${worktree_path}/CLAUDE.md"
        log_info "  Added CLAUDE.md with agent instructions"
    fi
}

#-------------------------------------------------------------------------------
# Coordination Setup
#-------------------------------------------------------------------------------

setup_coordination() {
    log_header "Setting Up Coordination"

    if [[ ! -f "${TARGET_REPO_PATH}/FACTORY.md" ]]; then
        log_info "Adding FACTORY.md to main repository..."
        if [[ -f "${SCRIPT_DIR}/FACTORY.md" ]]; then
            cp "${SCRIPT_DIR}/FACTORY.md" "${TARGET_REPO_PATH}/FACTORY.md"
            cd "$TARGET_REPO_PATH"
            git add FACTORY.md
            git commit -m "chore: Add factory coordination file" || true
            git push origin "$(git branch --show-current)" 2>/dev/null || log_warning "Could not push (offline?)"
            log_success "FACTORY.md added to main repo"
        fi
    else
        log_success "FACTORY.md already exists"
    fi

    log_info "Syncing FACTORY.md to all worktrees..."
    for i in $(seq 1 $NUM_AGENTS); do
        local worktree_path="${PARENT_DIR}/${PROJECT_NAME}-agent-${i}"
        if [[ -d "$worktree_path" ]]; then
            cd "$worktree_path"
            git fetch origin 2>/dev/null || true
            git checkout origin/main -- FACTORY.md 2>/dev/null || \
                cp "${TARGET_REPO_PATH}/FACTORY.md" "${worktree_path}/FACTORY.md" 2>/dev/null || true
        fi
    done
    log_success "All worktrees synced"
}

#-------------------------------------------------------------------------------
# Docker Setup
#-------------------------------------------------------------------------------

generate_docker_compose() {
    log_info "Generating docker-compose.yml for ${NUM_AGENTS} agents..."

    cat > "${SCRIPT_DIR}/docker-compose.yml" << HEADER
# Claude Factory - Multi-Agent Orchestration
# Auto-generated for project: ${PROJECT_NAME}
# Uses HTTPS + GH_TOKEN for authentication

services:
HEADER

    for i in $(seq 1 $NUM_AGENTS); do
        cat >> "${SCRIPT_DIR}/docker-compose.yml" << SERVICE
  # Agent ${i}
  agent-${i}:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: ${PROJECT_NAME}-agent-${i}
    hostname: ${PROJECT_NAME}-agent-${i}
    volumes:
      - ../${PROJECT_NAME}-agent-${i}:/workspace:rw
      - ../${TARGET_REPO:-$PROJECT_NAME}/.git:/workspace/../${TARGET_REPO:-$PROJECT_NAME}/.git:rw
      - ~/.claude:/home/agent/.claude:rw
      - ~/.gitconfig:/home/agent/.gitconfig:ro
    environment:
      - AGENT_ID=${i}
      - AGENT_NAME=${PROJECT_NAME}-agent-${i}
      - FACTORY_MODE=true
      - PROJECT_NAME=${PROJECT_NAME}
      - GH_TOKEN=\${GH_TOKEN:-}
      - GITHUB_TOKEN=\${GH_TOKEN:-}
    networks:
      - factory-network
    restart: unless-stopped
    stdin_open: true
    tty: true

SERVICE
    done

    cat >> "${SCRIPT_DIR}/docker-compose.yml" << FOOTER
networks:
  factory-network:
    name: ${PROJECT_NAME}-factory-network
    driver: bridge
FOOTER

    log_success "Generated docker-compose.yml"
}

setup_docker() {
    log_header "Building and Starting Docker Containers"

    cd "$SCRIPT_DIR"

    # Generate docker-compose.yml based on configuration
    generate_docker_compose

    # Clear any cached environment variables
    unset GH_TOKEN 2>/dev/null || true

    # Source .env to get fresh token
    source "${SCRIPT_DIR}/.env"
    export GH_TOKEN

    # Stop any existing containers first
    log_info "Stopping any existing containers..."
    docker compose down 2>/dev/null || true

    log_info "Building Docker image..."
    if docker compose build 2>&1 | tee "${LOG_DIR}/docker-build.log"; then
        log_success "Docker image built successfully"
    else
        log_error "Failed to build Docker image. Check ${LOG_DIR}/docker-build.log"
        exit 1
    fi

    # Force recreate to ensure fresh environment variables
    log_info "Starting containers with fresh environment..."
    if docker compose up -d --force-recreate 2>&1 | tee "${LOG_DIR}/docker-up.log"; then
        log_success "Containers started successfully"
    else
        log_error "Failed to start containers. Check ${LOG_DIR}/docker-up.log"
        exit 1
    fi

    log_info "Waiting for containers to be ready..."
    sleep 5

    local running_count
    running_count=$(docker compose ps --status running -q | wc -l | tr -d ' ')

    if [[ "$running_count" -eq "$NUM_AGENTS" ]]; then
        log_success "All $NUM_AGENTS agents are running"
    else
        log_warning "Only $running_count of $NUM_AGENTS containers are running"
        docker compose ps
    fi

    # Verify token made it into containers
    log_info "Verifying token is configured in containers..."
    if docker exec ${PROJECT_NAME}-agent-1 test -f /home/agent/.git-credentials 2>/dev/null; then
        log_success "Git credentials configured in containers"
    else
        log_warning "Git credentials may not be configured - check token"
    fi
}

#-------------------------------------------------------------------------------
# Verification
#-------------------------------------------------------------------------------

verify_setup() {
    log_header "Verifying Setup"

    cd "$SCRIPT_DIR"

    for i in $(seq 1 $NUM_AGENTS); do
        local container="${PROJECT_NAME}-agent-${i}"

        if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            log_success "Container ${container} is running"

            # Check git auth is working
            if docker exec "$container" test -f /home/agent/.git-credentials 2>/dev/null; then
                log_success "  - Git credentials configured"
            else
                log_warning "  - Git credentials not found (push may fail)"
            fi

            # Verify claude is installed
            if docker exec "$container" which claude > /dev/null 2>&1; then
                log_success "  - claude-code CLI installed"
            fi

            # Check workspace mount
            if docker exec "$container" test -d /workspace 2>/dev/null; then
                log_success "  - Workspace mounted"
            fi
        else
            log_error "Container ${container} is not running"
        fi
    done
}

#-------------------------------------------------------------------------------
# Print Summary
#-------------------------------------------------------------------------------

print_summary() {
    log_header "Setup Complete!"

    echo -e "${GREEN}Your Claude Factory is ready!${NC}"
    echo ""
    echo "Project: ${PROJECT_NAME}"
    echo ""
    echo "Quick Commands:"
    echo "  - Open agent terminals:       ./dispatch.sh"
    echo "  - Send task to all agents:    ./dispatch.sh \"Your task here\""
    echo "  - Stop all agents:            ./teardown.sh"
    echo "  - Reset (keep commits):       ./reset.sh"
    echo ""
    echo "Agent Branches:"
    for i in $(seq 1 $NUM_AGENTS); do
        echo "  - Agent ${i}: feat/agent-${i}-workspace"
    done
    echo ""
    echo -e "${GREEN}Agents can now commit AND push to GitHub!${NC}"
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------

main() {
    log_header "Claude Factory Setup"
    echo "Project: ${PROJECT_NAME}"
    echo "Agents:  ${NUM_AGENTS}"
    echo ""

    preflight_checks
    setup_worktrees
    setup_coordination
    setup_docker
    verify_setup
    print_summary
}

main "$@"
