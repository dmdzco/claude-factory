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

# Clear Claude Code nesting-detection env vars so droids can launch inside tmux
unset CLAUDECODE CLAUDE_CODE_ENTRYPOINT CLAUDE_CODE_TEAMMATE_MODE 2>/dev/null || true

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

Controls:
  Cmd+1-${NUM_DROIDS}      Switch between droid tabs
  Ctrl-b d          Detach from a droid's tmux session

Reattach to a droid:
  tmux attach -t ${PROJECT_NAME}-droid-<N>

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

    local claude_cmd="claude --dangerously-skip-permissions --model ${DEFAULT_MODEL}"

    # Determine droids to launch
    local start_droid=1
    local end_droid=$NUM_DROIDS
    if [[ -n "$specific_droid" ]]; then
        start_droid=$specific_droid
        end_droid=$specific_droid
    fi

    # Detect if we're in a remote/headless session (SSH, no GUI)
    local remote_mode=false
    if [[ -n "${SSH_CONNECTION:-}" ]] || [[ -z "${TERM_PROGRAM:-}" ]] || [[ "${TERM_PROGRAM:-}" != "iTerm.app" && "${TERM_PROGRAM:-}" != "Apple_Terminal" ]]; then
        remote_mode=true
    fi

    if [[ "$remote_mode" == true ]]; then
        log_info "Remote/headless session detected — using unified tmux session"
        log_info "Launching droids as tmux windows in session '${TMUX_SESSION}'..."
    else
        log_info "Launching droids in separate terminal tabs (1 per tab)..."
    fi
    echo ""

    local i=$start_droid
    local first_window=true

    while [[ $i -le $end_droid ]]; do
        local worktree="${REPO_PARENT_DIR}/${PROJECT_NAME}-droid-${i}"
        local window_name="droid-${i}"

        # Validate worktree
        if [[ ! -d "$worktree" ]]; then
            log_warning "Worktree not found: $worktree - skipping droid ${i}"
            i=$((i + 1))
            continue
        fi

        if [[ "$remote_mode" == true ]]; then
            # --- Remote mode: all droids as windows in one tmux session ---
            if [[ "$first_window" == true ]]; then
                # Kill existing unified session if present
                if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
                    log_warning "Killing existing tmux session '${TMUX_SESSION}'..."
                    tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true
                fi
                # Create session with first droid
                tmux new-session -d -s "$TMUX_SESSION" -n "$window_name" -c "$worktree"
                tmux send-keys -t "${TMUX_SESSION}:${window_name}" "unset GH_TOKEN CLAUDECODE CLAUDE_CODE_ENTRYPOINT CLAUDE_CODE_TEAMMATE_MODE && $claude_cmd" C-m
                first_window=false
            else
                # Add subsequent droids as new windows in the same session
                tmux new-window -t "$TMUX_SESSION" -n "$window_name" -c "$worktree"
                tmux send-keys -t "${TMUX_SESSION}:${window_name}" "unset GH_TOKEN CLAUDECODE CLAUDE_CODE_ENTRYPOINT CLAUDE_CODE_TEAMMATE_MODE && $claude_cmd" C-m
            fi
            log_success "Droid ${i} → tmux window '${window_name}' in session '${TMUX_SESSION}'"
        else
            # --- Local mode: separate sessions + macOS terminal tabs ---
            local session_name="${PROJECT_NAME}-droid-${i}"

            # Kill existing tmux session for this droid if present
            if tmux has-session -t "$session_name" 2>/dev/null; then
                log_warning "Killing existing tmux session '${session_name}'..."
                tmux kill-session -t "$session_name" 2>/dev/null || true
            fi

            # Create a detached tmux session for this droid
            tmux new-session -d -s "$session_name" -c "$worktree"
            tmux send-keys -t "$session_name" "unset GH_TOKEN CLAUDECODE CLAUDE_CODE_ENTRYPOINT CLAUDE_CODE_TEAMMATE_MODE && $claude_cmd" C-m

            # Open a new terminal tab and attach to this droid's tmux session
            if [[ "$TERM_PROGRAM" == "iTerm.app" ]]; then
                osascript -e "
                    tell application \"iTerm\"
                        tell current window
                            create tab with default profile
                            tell current session
                                write text \"tmux attach -t ${session_name}\"
                            end tell
                        end tell
                    end tell
                " 2>/dev/null
            else
                # Apple Terminal (default)
                osascript -e "
                    tell application \"Terminal\"
                        activate
                        tell application \"System Events\" to keystroke \"t\" using command down
                        delay 0.3
                        do script \"tmux attach -t ${session_name}\" in front window
                    end tell
                " 2>/dev/null
            fi
            log_success "Droid ${i} → terminal tab (tmux session '${session_name}')"
            sleep 0.5
        fi

        i=$((i + 1))
    done

    echo ""
    if [[ "$remote_mode" == true ]]; then
        log_success "All droids launched in tmux session '${TMUX_SESSION}'"
        echo ""
        log_info "Attach with:  tmux attach -t ${TMUX_SESSION}"
        log_info "Switch droids: Ctrl-b, <window number>  (0=${start_droid}, 1=$((start_droid+1)), ...)"
        log_info "List windows:  Ctrl-b, w"
        log_info "Detach:        Ctrl-b, d"
    else
        log_success "All droids launched in separate terminal tabs"
        echo ""
        log_info "Switch tabs: Cmd+1-${NUM_DROIDS}"
        log_info "Each tab runs its own tmux session (detach: Ctrl-b d)"
    fi
    echo ""
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
