#!/usr/bin/env bash
#===============================================================================
# Claude Factory - Task Dispatch Script
# Opens each droid in its own tmux window (tab)
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
    echo -e "${RED}[ERROR]${NC} factory.conf not found! Run ./cf-configure.sh first."
    exit 1
fi

# Support both new-style (TARGET_REPO_PATH) and old-style (TARGET_REPO) config
if [[ -z "${TARGET_REPO_PATH:-}" ]]; then
    PARENT_DIR="$(dirname "$SCRIPT_DIR")"
    TARGET_REPO_PATH="${PARENT_DIR}/${TARGET_REPO:-$PROJECT_NAME}"
fi
REPO_PARENT_DIR="$(dirname "$TARGET_REPO_PATH")"

# tmux session name
TMUX_SESSION="${PROJECT_NAME}-factory"

#-------------------------------------------------------------------------------
# Helper Functions
#-------------------------------------------------------------------------------

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

print_usage() {
    cat << EOF
${CYAN}Claude Factory - Task Dispatcher (tmux)${NC}

Usage:
  $(basename "$0") [OPTIONS]

Options:
  -d, --droid <N>      Open only specific droid (1-${NUM_DROIDS})
  -m, --model <MODEL>  Claude model (default: ${DEFAULT_MODEL})
                       Options: sonnet, opus, haiku
  -h, --help           Show this help

Examples:
  # Open all droids in tmux (1 per tab/window)
  $(basename "$0")

  # Open specific droid in its own tmux window
  $(basename "$0") --droid 1

  # Use a different model
  $(basename "$0") --model opus

tmux Controls:
  Ctrl-b w          List all windows (tabs)
  Ctrl-b n / p      Next / previous window (tab)
  Ctrl-b d          Detach from session

Reattach:
  tmux attach -t ${TMUX_SESSION}

EOF
}

#-------------------------------------------------------------------------------
# Auth Check
#-------------------------------------------------------------------------------

check_claude_auth() {
    log_info "Checking Claude authentication..."

    # Quick auth check: run a minimal prompt and see if it succeeds
    if claude -p "ok" --max-turns 1 &>/dev/null; then
        log_success "Claude authentication verified"
        return 0
    fi

    echo ""
    log_error "Claude authentication failed!"
    log_error "Droids will not be able to start without valid credentials."
    echo ""
    echo -e "  Fix with one of:"
    echo -e "    1. Run ${CYAN}claude /login${NC} to authenticate via browser"
    echo -e "    2. Set ${CYAN}export ANTHROPIC_API_KEY=\"sk-ant-...\"${NC} in your shell"
    echo ""
    exit 1
}

#-------------------------------------------------------------------------------
# tmux Dispatch
#-------------------------------------------------------------------------------

dispatch_droids_tmux() {
    local specific_droid="${1:-}"

    # Check for tmux
    if ! command -v tmux &> /dev/null; then
        log_error "tmux not found. Install with: brew install tmux (macOS) or apt-get install tmux (Linux)"
        exit 1
    fi

    # Kill existing session if present
    if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
        log_warning "Existing tmux session '${TMUX_SESSION}' found. Killing it..."
        tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true
    fi

    local claude_cmd="claude --dangerously-skip-permissions --model ${DEFAULT_MODEL}"

    # Handle single-droid dispatch
    if [[ -n "$specific_droid" ]]; then
        local worktree_path="${REPO_PARENT_DIR}/${PROJECT_NAME}-${specific_droid}"
        if [[ ! -d "$worktree_path" ]]; then
            log_error "Worktree not found: $worktree_path"
            log_error "Run ./cf-setup.sh first"
            exit 1
        fi

        tmux new-session -d -s "$TMUX_SESSION" -n "droid-${specific_droid}" -c "$worktree_path"
        tmux send-keys -t "$TMUX_SESSION:droid-${specific_droid}" "$claude_cmd" C-m
        log_success "Droid ${specific_droid} launched in tmux window"
        tmux attach -t "$TMUX_SESSION"
        return
    fi

    # Multi-droid dispatch: 1 droid per window (tab)
    log_info "Launching ${NUM_DROIDS} droids in tmux (1 per tab)..."
    echo ""

    local i=1

    while [[ $i -le $NUM_DROIDS ]]; do
        local worktree="${REPO_PARENT_DIR}/${PROJECT_NAME}-${i}"
        local window_name="droid-${i}"

        # Validate worktree
        if [[ ! -d "$worktree" ]]; then
            log_warning "Worktree not found: $worktree - skipping droid ${i}"
            i=$((i + 1))
            continue
        fi

        if [[ $i -eq 1 ]]; then
            # First window: create the session
            tmux new-session -d -s "$TMUX_SESSION" -n "$window_name" -c "$worktree"
        else
            # Subsequent windows (tabs)
            tmux new-window -t "$TMUX_SESSION" -n "$window_name" -c "$worktree"
        fi

        # Start claude in this window
        tmux send-keys -t "$TMUX_SESSION:${window_name}" "$claude_cmd" C-m
        log_success "Droid ${i} → tab '${window_name}'"

        i=$((i + 1))
    done

    # Select the first window
    tmux select-window -t "$TMUX_SESSION:0"

    echo ""
    log_success "All droids launched in tmux session '${TMUX_SESSION}'"
    echo ""
    log_info "Attaching to tmux session..."
    log_info "Switch tabs: Ctrl-b n/p | Detach: Ctrl-b d | Reattach: tmux attach -t ${TMUX_SESSION}"
    echo ""

    # Attach to the session
    tmux attach -t "$TMUX_SESSION"
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------

main() {
    local droid_id=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--droid)
                droid_id="$2"
                if [[ ! "$droid_id" =~ ^[0-9]+$ ]] || [[ "$droid_id" -lt 1 ]] || [[ "$droid_id" -gt "$NUM_DROIDS" ]]; then
                    log_error "Droid ID must be between 1 and ${NUM_DROIDS}"
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
                shift
                ;;
        esac
    done

    # Create logs directory
    mkdir -p "$LOG_DIR"

    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Claude Factory - Dispatching Droids (tmux)${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    log_info "Project: ${PROJECT_NAME}"
    log_info "Model: ${DEFAULT_MODEL}"
    log_info "Session: ${TMUX_SESSION}"
    if [[ -n "$droid_id" ]]; then
        log_info "Droid: ${droid_id}"
    else
        log_info "Droids: 1-${NUM_DROIDS} (1 per tab)"
    fi
    echo ""

    check_claude_auth
    echo ""

    dispatch_droids_tmux "$droid_id"
}

main "$@"
