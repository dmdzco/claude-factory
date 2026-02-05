#!/usr/bin/env bash
#===============================================================================
# Claude Factory - Task Dispatch Script
# Opens terminal tabs with Claude in each worktree (always interactive)
#===============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"

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

print_usage() {
    cat << EOF
${CYAN}Claude Factory - Task Dispatcher${NC}

Usage:
  $(basename "$0") [OPTIONS]

Options:
  -a, --agent <N>      Open only specific agent (1-${NUM_AGENTS})
  -m, --model <MODEL>  Claude model (default: ${DEFAULT_MODEL})
                       Options: sonnet, opus, haiku
  -h, --help           Show this help

Examples:
  # Open all agent terminals (interactive mode)
  $(basename "$0")

  # Open specific agent
  $(basename "$0") --agent 1

  # Use a different model
  $(basename "$0") --model opus

EOF
}

#-------------------------------------------------------------------------------
# Terminal Tab Functions
#-------------------------------------------------------------------------------

open_terminal_tabs() {
    local specific_agent="${1:-}"

    log_info "Opening terminal tabs for agents (interactive mode)..."
    echo ""

    # Build the claude command - always interactive
    local claude_cmd="claude --dangerously-skip-permissions --model ${DEFAULT_MODEL}"

    # Determine which agents to open
    local start_agent=1
    local end_agent=$NUM_AGENTS
    if [[ -n "$specific_agent" ]]; then
        start_agent=$specific_agent
        end_agent=$specific_agent
    fi

    # Detect terminal application
    if [[ "${TERM_PROGRAM:-}" == "Apple_Terminal" ]]; then
        open_macos_terminal "$claude_cmd" "$start_agent" "$end_agent"
    elif [[ "${TERM_PROGRAM:-}" == "iTerm.app" ]] || [[ "${TERM_PROGRAM:-}" == "iTerm" ]]; then
        open_iterm "$claude_cmd" "$start_agent" "$end_agent"
    else
        open_fallback "$claude_cmd" "$start_agent" "$end_agent"
    fi

    echo ""
    log_success "Terminal tabs opened! All agents in interactive mode."
}

open_macos_terminal() {
    local claude_cmd="$1"
    local start_agent="$2"
    local end_agent="$3"

    # First agent opens new window
    local i=$start_agent
    local worktree_path="${REPO_PARENT_DIR}/${PROJECT_NAME}-agent-${i}"

    if [[ ! -d "$worktree_path" ]]; then
        log_error "Worktree not found: $worktree_path"
        log_error "Run ./setup.sh first"
        exit 1
    fi

    local cmd="cd '$worktree_path' && $claude_cmd"

    osascript -e "
        tell application \"Terminal\"
            activate
            do script \"$cmd\"
        end tell
    " 2>/dev/null || log_warning "Could not open window for Agent ${i}"
    log_success "Opened tab for Agent ${i} (${PROJECT_NAME}-agent-${i})"

    # Remaining agents as tabs
    for i in $(seq $((start_agent + 1)) $end_agent); do
        worktree_path="${REPO_PARENT_DIR}/${PROJECT_NAME}-agent-${i}"

        if [[ ! -d "$worktree_path" ]]; then
            log_warning "Worktree not found: $worktree_path - skipping"
            continue
        fi

        cmd="cd '$worktree_path' && $claude_cmd"

        osascript -e "
            tell application \"Terminal\"
                activate
                tell application \"System Events\" to keystroke \"t\" using command down
                delay 0.3
                do script \"$cmd\" in front window
            end tell
        " 2>/dev/null || log_warning "Could not open tab for Agent ${i}"
        log_success "Opened tab for Agent ${i} (${PROJECT_NAME}-agent-${i})"
    done
}

open_iterm() {
    local claude_cmd="$1"
    local start_agent="$2"
    local end_agent="$3"

    # First agent in current window
    local i=$start_agent
    local worktree_path="${REPO_PARENT_DIR}/${PROJECT_NAME}-agent-${i}"

    if [[ ! -d "$worktree_path" ]]; then
        log_error "Worktree not found: $worktree_path"
        log_error "Run ./setup.sh first"
        exit 1
    fi

    local cmd="cd '$worktree_path' && $claude_cmd"

    osascript -e "
        tell application \"iTerm\"
            activate
            tell current window
                tell current session
                    write text \"$cmd\"
                end tell
            end tell
        end tell
    " 2>/dev/null || log_warning "Could not open tab for Agent ${i}"
    log_success "Opened tab for Agent ${i} (${PROJECT_NAME}-agent-${i})"

    # Remaining agents as new tabs
    for i in $(seq $((start_agent + 1)) $end_agent); do
        worktree_path="${REPO_PARENT_DIR}/${PROJECT_NAME}-agent-${i}"

        if [[ ! -d "$worktree_path" ]]; then
            log_warning "Worktree not found: $worktree_path - skipping"
            continue
        fi

        cmd="cd '$worktree_path' && $claude_cmd"

        osascript -e "
            tell application \"iTerm\"
                activate
                tell current window
                    create tab with default profile
                    tell current session
                        write text \"$cmd\"
                    end tell
                end tell
            end tell
        " 2>/dev/null || log_warning "Could not open tab for Agent ${i}"
        log_success "Opened tab for Agent ${i} (${PROJECT_NAME}-agent-${i})"
    done
}

open_fallback() {
    local claude_cmd="$1"
    local start_agent="$2"
    local end_agent="$3"

    log_warning "Unknown terminal. Run these commands manually in separate tabs:"
    echo ""

    for i in $(seq $start_agent $end_agent); do
        local worktree_path="${REPO_PARENT_DIR}/${PROJECT_NAME}-agent-${i}"
        echo "  # Agent ${i}:"
        echo "  cd '$worktree_path' && $claude_cmd"
        echo ""
    done
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------

main() {
    local agent_id=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -a|--agent)
                agent_id="$2"
                if [[ ! "$agent_id" =~ ^[0-9]+$ ]] || [[ "$agent_id" -lt 1 ]] || [[ "$agent_id" -gt "$NUM_AGENTS" ]]; then
                    log_error "Agent ID must be between 1 and ${NUM_AGENTS}"
                    exit 1
                fi
                shift 2
                ;;
            -m|--model)
                DEFAULT_MODEL="$2"
                if [[ ! "$DEFAULT_MODEL" =~ ^(sonnet|opus|haiku)$ ]]; then
                    log_error "Invalid model. Choose: sonnet, opus, haiku"
                    exit 1
                fi
                shift 2
                ;;
            -h|--help)
                print_usage
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
            *)
                # Ignore any positional arguments (prompts no longer used)
                shift
                ;;
        esac
    done

    # Create logs directory
    mkdir -p "$LOG_DIR"

    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Claude Factory - Opening Agents (Interactive Mode)${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    log_info "Project: ${PROJECT_NAME}"
    log_info "Model: ${DEFAULT_MODEL}"
    if [[ -n "$agent_id" ]]; then
        log_info "Agent: ${agent_id}"
    else
        log_info "Agents: 1-${NUM_AGENTS}"
    fi
    echo ""

    open_terminal_tabs "$agent_id"
}

main "$@"
