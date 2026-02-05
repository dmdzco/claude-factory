#!/usr/bin/env bash
#===============================================================================
# Claude Factory - Interactive Configuration
# Collects project information and writes factory.conf
#
# Usage:
#   ./configure.sh                    # Interactive prompts
#   ./configure.sh /path/to/project   # Configure for specific project
#   ./configure.sh --reset            # Reconfigure from scratch
#===============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_FILE="${SCRIPT_DIR}/factory.conf"

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

print_header() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

#-------------------------------------------------------------------------------
# Resolve a path to absolute
#-------------------------------------------------------------------------------
resolve_path() {
    local input="$1"

    # Expand ~ to home directory
    if [[ "$input" == "~"* ]]; then
        input="${HOME}${input:1}"
    fi

    # Resolve to absolute path
    if [[ "$input" == /* ]]; then
        echo "$input"
    else
        echo "$(cd "$SCRIPT_DIR" && cd "$input" 2>/dev/null && pwd)" || echo ""
    fi
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------

main() {
    local target_path=""
    local force_reset=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --reset)
                force_reset=true
                shift
                ;;
            -h|--help)
                echo "Usage: $(basename "$0") [OPTIONS] [/path/to/project]"
                echo ""
                echo "Interactively configures Claude Factory for a project."
                echo ""
                echo "Arguments:"
                echo "  /path/to/project   Path to the target git repository"
                echo ""
                echo "Options:"
                echo "  --reset            Reconfigure even if factory.conf exists"
                echo "  -h, --help         Show this help"
                echo ""
                echo "Examples:"
                echo "  $(basename "$0") ../donna2"
                echo "  $(basename "$0") /Users/me/code/myproject"
                echo "  $(basename "$0") --reset"
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                exit 1
                ;;
            *)
                target_path="$1"
                shift
                ;;
        esac
    done

    # Check if factory.conf already exists
    if [[ -f "$CONF_FILE" ]] && [[ "$force_reset" != "true" ]]; then
        source "$CONF_FILE"
        echo -e "${YELLOW}factory.conf already exists:${NC}"
        echo "  Project:    ${PROJECT_NAME:-unset}"
        echo "  Target:     ${TARGET_REPO_PATH:-${TARGET_REPO:-unset}}"
        echo "  Agents:     ${NUM_AGENTS:-unset}"
        echo "  Model:      ${DEFAULT_MODEL:-unset}"
        echo ""
        read -p "Reconfigure? (y/N) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Keeping existing configuration."
            exit 0
        fi
    fi

    print_header "Claude Factory - Configuration"

    #---------------------------------------------------------------------------
    # Step 1: Get target repository path
    #---------------------------------------------------------------------------
    if [[ -z "$target_path" ]]; then
        echo -e "${BLUE}Where is your project?${NC}"
        echo "  Enter the path to the git repository you want agents to work on."
        echo "  (Relative or absolute paths accepted)"
        echo ""
        read -p "Project path: " target_path
        echo ""
    fi

    if [[ -z "$target_path" ]]; then
        log_error "No project path provided."
        exit 1
    fi

    # Resolve to absolute path
    local resolved_path
    resolved_path=$(resolve_path "$target_path")

    if [[ -z "$resolved_path" ]] || [[ ! -d "$resolved_path" ]]; then
        log_error "Directory not found: $target_path"
        exit 1
    fi

    # Validate it's a git repository
    if [[ ! -d "${resolved_path}/.git" ]] && ! git -C "$resolved_path" rev-parse --git-dir &>/dev/null; then
        log_error "Not a git repository: $resolved_path"
        log_error "Claude Factory requires a git repository to create worktrees."
        exit 1
    fi

    log_success "Found git repository: $resolved_path"

    #---------------------------------------------------------------------------
    # Step 2: Get project name
    #---------------------------------------------------------------------------
    local default_name
    default_name=$(basename "$resolved_path")

    echo ""
    echo -e "${BLUE}Project name${NC} (used for worktree directory naming)"
    echo "  Worktrees will be created as: ${default_name}-agent-1, ${default_name}-agent-2, ..."
    echo ""
    read -p "Project name [${default_name}]: " project_name
    project_name="${project_name:-$default_name}"

    # Sanitize: only allow alphanumeric, hyphens, underscores, dots
    if [[ ! "$project_name" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        log_error "Project name must only contain letters, numbers, hyphens, underscores, or dots."
        exit 1
    fi

    log_success "Project name: $project_name"

    #---------------------------------------------------------------------------
    # Step 3: Number of agents
    #---------------------------------------------------------------------------
    echo ""
    echo -e "${BLUE}How many parallel agents?${NC} (1-10)"
    read -p "Number of agents [3]: " num_agents
    num_agents="${num_agents:-3}"

    if [[ ! "$num_agents" =~ ^[0-9]+$ ]] || [[ "$num_agents" -lt 1 ]] || [[ "$num_agents" -gt 10 ]]; then
        log_error "Agent count must be between 1 and 10"
        exit 1
    fi

    log_success "Agents: $num_agents"

    #---------------------------------------------------------------------------
    # Step 4: Default model
    #---------------------------------------------------------------------------
    echo ""
    echo -e "${BLUE}Default Claude model${NC}"
    echo "  1) sonnet  (fast, recommended)"
    echo "  2) opus    (most capable)"
    echo "  3) haiku   (fastest, cheapest)"
    echo ""
    read -p "Model [sonnet]: " model_choice
    model_choice="${model_choice:-sonnet}"

    case "$model_choice" in
        1|sonnet) model_choice="sonnet" ;;
        2|opus)   model_choice="opus" ;;
        3|haiku)  model_choice="haiku" ;;
        *)
            log_error "Invalid model. Choose: sonnet, opus, or haiku"
            exit 1
            ;;
    esac

    log_success "Model: $model_choice"

    #---------------------------------------------------------------------------
    # Step 5: Write factory.conf
    #---------------------------------------------------------------------------
    echo ""
    log_info "Writing factory.conf..."

    cat > "$CONF_FILE" << EOF
#===============================================================================
# Claude Factory - Configuration
# Generated by configure.sh on $(date +"%Y-%m-%d %H:%M:%S")
#===============================================================================

# Project name (used for worktree directories and branch names)
# Worktrees: ${project_name}-agent-1/, ${project_name}-agent-2/, ...
# Branches:  feat/agent-1-workspace, feat/agent-2-workspace, ...
PROJECT_NAME="${project_name}"

# Absolute path to the target git repository
TARGET_REPO_PATH="${resolved_path}"

# Number of parallel agents (1-10)
NUM_AGENTS=${num_agents}

# Default Claude model (sonnet, opus, haiku)
DEFAULT_MODEL="${model_choice}"
EOF

    log_success "Configuration saved to factory.conf"

    #---------------------------------------------------------------------------
    # Summary
    #---------------------------------------------------------------------------
    print_header "Configuration Complete"

    echo "  Project:     ${project_name}"
    echo "  Repository:  ${resolved_path}"
    echo "  Agents:      ${num_agents}"
    echo "  Model:       ${model_choice}"
    echo ""
    echo "  Worktrees will be created at:"
    local worktree_parent
    worktree_parent=$(dirname "$resolved_path")
    for i in $(seq 1 "$num_agents"); do
        echo "    ${worktree_parent}/${project_name}-agent-${i}/"
    done
    echo ""
    echo -e "${GREEN}Run ./start.sh to set up worktrees and launch agents!${NC}"
    echo ""
}

main "$@"
