#!/usr/bin/env bash
#===============================================================================
# Claude Factory - Task Dispatch Script
# Sends tasks to Claude Code agents running in Docker containers
#===============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"

# Load project configuration
if [[ -f "${SCRIPT_DIR}/factory.conf" ]]; then
    source "${SCRIPT_DIR}/factory.conf"
else
    echo -e "${RED}[ERROR]${NC} factory.conf not found!"
    echo "Copy factory.conf.example to factory.conf and configure it."
    exit 1
fi

# Agent system prompt - injected before every task
read -r -d '' AGENT_SYSTEM_PROMPT << 'SYSEOF' || true
## FACTORY AGENT PROTOCOL

You are Agent-$AGENT_ID in the Claude Factory. Before doing ANY work:

1. **Sync first:**
   git fetch origin && git pull origin main --rebase 2>/dev/null || true

2. **Check coordination:**
   Read FACTORY.md in the workspace root. Check the "Claimed Files" table.
   DO NOT edit any file that another agent has claimed.

3. **Claim your files:**
   Before editing files, update FACTORY.md:
   - Set your status to 🔵 Working
   - Add files to the Claimed Files table
   - Commit and push: git add FACTORY.md && git commit -m "chore: Agent-$AGENT_ID claiming work" && git push

4. **Work and commit:**
   Make small, frequent commits with clear messages.

5. **When done:**
   Update FACTORY.md: set status to ✅ Done, remove file claims, push.

If a file you need is claimed by another agent, add a message to FACTORY.md's
"Agent Messages" section and work on something else.

---

SYSEOF

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

log_agent() {
    local agent_id="$1"
    local message="$2"
    echo -e "${MAGENTA}[AGENT-${agent_id}]${NC} $message"
}

print_usage() {
    cat << EOF
${CYAN}Claude Factory - Task Dispatcher${NC}

Usage:
  $(basename "$0") [OPTIONS] "PROMPT"

Options:
  -a, --agent <N>      Send task to specific agent (1-${NUM_AGENTS})
  -m, --model <MODEL>  Claude model to use (default: ${DEFAULT_MODEL})
                       Options: sonnet, opus, haiku
  -p, --parallel       Run all agents in parallel (default)
  -s, --sequential     Run agents sequentially
  -w, --wait           Wait for all agents to complete
  -f, --file <FILE>    Read prompt from file
  -i, --interactive    Run in interactive mode (opens agent shell)
  --no-protocol        Skip injecting factory coordination protocol
  --raw                Send raw prompt without any additions
  --dry-run            Show what would be executed without running
  -h, --help           Show this help message

Examples:
  # Send a task to all agents in parallel
  $(basename "$0") "Review the codebase and identify bugs"

  # Send a task to specific agent
  $(basename "$0") --agent 1 "Work on GitHub issue #42"

  # Send task with specific model
  $(basename "$0") --model opus "Refactor the authentication module"

  # Read complex prompt from file
  $(basename "$0") --file task.md

  # Interactive session with agent 2
  $(basename "$0") --agent 2 --interactive

  # Raw prompt without factory protocol
  $(basename "$0") --raw "Just answer: what files are in this repo?"

EOF
}

#-------------------------------------------------------------------------------
# Task Execution
#-------------------------------------------------------------------------------

check_container_running() {
    local agent_id="$1"
    local container="${PROJECT_NAME}-agent-${agent_id}"

    if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        log_error "Container ${container} is not running"
        log_error "Run ./setup.sh first to start the containers"
        return 1
    fi
    return 0
}

build_prompt() {
    local agent_id="$1"
    local user_prompt="$2"
    local include_protocol="$3"

    if [[ "$include_protocol" == "true" ]]; then
        # Substitute $AGENT_ID in the system prompt
        local agent_protocol="${AGENT_SYSTEM_PROMPT//\$AGENT_ID/$agent_id}"
        echo "${agent_protocol}

## YOUR TASK

${user_prompt}"
    else
        echo "$user_prompt"
    fi
}

execute_task() {
    local agent_id="$1"
    local prompt="$2"
    local model="$3"
    local wait_flag="$4"
    local include_protocol="$5"
    local container="${PROJECT_NAME}-agent-${agent_id}"
    local log_file="${LOG_DIR}/agent-${agent_id}-$(date +%Y%m%d-%H%M%S).log"

    # Check if container is running
    check_container_running "$agent_id" || return 1

    log_agent "$agent_id" "Dispatching task..."

    # Build the full prompt
    local full_prompt
    full_prompt=$(build_prompt "$agent_id" "$prompt" "$include_protocol")

    # Escape for shell - handle single quotes
    full_prompt="${full_prompt//\'/\'\\\'\'}"

    # Build the claude command
    local claude_cmd="claude --dangerously-skip-permissions --model ${model} -p"

    if [[ "$wait_flag" == "true" ]]; then
        # Run in foreground and capture output
        log_agent "$agent_id" "Running task (waiting for completion)..."
        log_agent "$agent_id" "Log file: ${log_file}"

        if docker exec -t "$container" bash -c "${claude_cmd} '${full_prompt}'" 2>&1 | tee "$log_file"; then
            log_success "Agent ${agent_id} completed task"
            return 0
        else
            log_error "Agent ${agent_id} task failed"
            return 1
        fi
    else
        # Run in background
        log_agent "$agent_id" "Task dispatched in background"
        log_agent "$agent_id" "Log file: ${log_file}"

        # Use nohup inside the container to keep it running
        docker exec -d "$container" bash -c "${claude_cmd} '${full_prompt}' > /tmp/task-output.log 2>&1"

        return 0
    fi
}

dispatch_all_parallel() {
    local prompt="$1"
    local model="$2"
    local wait_flag="$3"
    local include_protocol="$4"

    log_info "Dispatching task to all ${NUM_AGENTS} agents in parallel..."
    echo ""

    local pids=()

    for i in $(seq 1 $NUM_AGENTS); do
        (
            execute_task "$i" "$prompt" "$model" "$wait_flag" "$include_protocol"
        ) &
        pids+=($!)
    done

    if [[ "$wait_flag" == "true" ]]; then
        log_info "Waiting for all agents to complete..."
        local failed=0
        for pid in "${pids[@]}"; do
            if ! wait "$pid"; then
                ((failed++))
            fi
        done

        echo ""
        if [[ $failed -eq 0 ]]; then
            log_success "All agents completed successfully"
        else
            log_warning "${failed} agent(s) failed"
        fi
    else
        log_info "Tasks dispatched to all agents"
        log_info "Check status with: ./status.sh"
    fi
}

dispatch_all_sequential() {
    local prompt="$1"
    local model="$2"
    local wait_flag="$3"
    local include_protocol="$4"

    log_info "Dispatching task to all ${NUM_AGENTS} agents sequentially..."
    echo ""

    local failed=0
    for i in $(seq 1 $NUM_AGENTS); do
        if ! execute_task "$i" "$prompt" "$model" "$wait_flag" "$include_protocol"; then
            ((failed++))
        fi
        echo ""
    done

    if [[ $failed -eq 0 ]]; then
        log_success "All agents completed successfully"
    else
        log_warning "${failed} agent(s) failed"
    fi
}

run_interactive() {
    local agent_id="$1"
    local container="${PROJECT_NAME}-agent-${agent_id}"

    check_container_running "$agent_id" || exit 1

    log_info "Starting interactive session with Agent ${agent_id}..."
    log_info "Type 'exit' to leave the session"
    echo ""

    docker exec -it "$container" bash -c "cd /workspace && claude --dangerously-skip-permissions"
}

open_terminal_tabs() {
    log_info "Opening terminal tabs for all agents..."
    echo ""

    # Detect terminal application
    if [[ "${TERM_PROGRAM:-}" == "Apple_Terminal" ]]; then
        # macOS Terminal.app - all tabs in same window
        # First, create a new window for agent 1
        local container="${PROJECT_NAME}-agent-1"
        check_container_running "1" || return 1

        osascript -e "
            tell application \"Terminal\"
                activate
                do script \"cd '$SCRIPT_DIR' && docker exec -it $container bash -c 'cd /workspace && claude --dangerously-skip-permissions'\"
            end tell
        " 2>/dev/null || log_warning "Could not open window for Agent 1"
        log_success "Opened tab for Agent 1"

        # Then add tabs 2-N to the front window
        for i in $(seq 2 $NUM_AGENTS); do
            container="${PROJECT_NAME}-agent-${i}"
            check_container_running "$i" || continue

            osascript -e "
                tell application \"Terminal\"
                    activate
                    tell application \"System Events\" to keystroke \"t\" using command down
                    delay 0.3
                    do script \"cd '$SCRIPT_DIR' && docker exec -it $container bash -c 'cd /workspace && claude --dangerously-skip-permissions'\" in front window
                end tell
            " 2>/dev/null || log_warning "Could not open tab for Agent ${i}"
            log_success "Opened tab for Agent ${i}"
        done

    elif [[ "${TERM_PROGRAM:-}" == "iTerm.app" ]] || [[ "${TERM_PROGRAM:-}" == "iTerm" ]]; then
        # iTerm2 - all tabs in same window
        # First agent opens in current window
        local container="${PROJECT_NAME}-agent-1"
        check_container_running "1" || return 1

        osascript -e "
            tell application \"iTerm\"
                activate
                tell current window
                    tell current session
                        write text \"cd '$SCRIPT_DIR' && docker exec -it $container bash -c 'cd /workspace && claude --dangerously-skip-permissions'\"
                    end tell
                end tell
            end tell
        " 2>/dev/null || log_warning "Could not open tab for Agent 1"
        log_success "Opened tab for Agent 1"

        # Remaining agents open as new tabs in same window
        for i in $(seq 2 $NUM_AGENTS); do
            container="${PROJECT_NAME}-agent-${i}"
            check_container_running "$i" || continue

            osascript -e "
                tell application \"iTerm\"
                    activate
                    tell current window
                        create tab with default profile
                        tell current session
                            write text \"cd '$SCRIPT_DIR' && docker exec -it $container bash -c 'cd /workspace && claude --dangerously-skip-permissions'\"
                        end tell
                    end tell
                end tell
            " 2>/dev/null || log_warning "Could not open tab for Agent ${i}"
            log_success "Opened tab for Agent ${i}"
        done

    else
        # Fallback: print commands for manual use
        log_warning "Unknown terminal. Run these commands manually in separate tabs:"
        echo ""
        for i in $(seq 1 $NUM_AGENTS); do
            echo "  # Agent ${i}:"
            echo "  docker exec -it ${PROJECT_NAME}-agent-${i} bash -c 'cd /workspace && claude --dangerously-skip-permissions'"
            echo ""
        done
    fi

    echo ""
    log_success "Terminal tabs opened! Each tab has an interactive Claude session."
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------

main() {
    # Default values
    local agent_id=""
    local model="$DEFAULT_MODEL"
    local parallel=true
    local wait_flag=false
    local interactive=false
    local dry_run=false
    local prompt_file=""
    local prompt=""
    local include_protocol=true

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
                model="$2"
                if [[ ! "$model" =~ ^(sonnet|opus|haiku)$ ]]; then
                    log_error "Invalid model. Choose: sonnet, opus, haiku"
                    exit 1
                fi
                shift 2
                ;;
            -p|--parallel)
                parallel=true
                shift
                ;;
            -s|--sequential)
                parallel=false
                shift
                ;;
            -w|--wait)
                wait_flag=true
                shift
                ;;
            -f|--file)
                prompt_file="$2"
                shift 2
                ;;
            -i|--interactive)
                interactive=true
                shift
                ;;
            --no-protocol)
                include_protocol=false
                shift
                ;;
            --raw)
                include_protocol=false
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
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
                prompt="$1"
                shift
                ;;
        esac
    done

    # Create logs directory
    mkdir -p "$LOG_DIR"

    # Handle interactive mode
    if [[ "$interactive" == "true" ]]; then
        if [[ -z "$agent_id" ]]; then
            log_error "Interactive mode requires --agent <N>"
            exit 1
        fi
        run_interactive "$agent_id"
        exit 0
    fi

    # Read prompt from file if specified
    if [[ -n "$prompt_file" ]]; then
        if [[ ! -f "$prompt_file" ]]; then
            log_error "Prompt file not found: $prompt_file"
            exit 1
        fi
        prompt=$(cat "$prompt_file")
    fi

    # If no prompt provided, open terminal tabs for interactive sessions
    if [[ -z "$prompt" ]]; then
        open_terminal_tabs
        exit 0
    fi

    # Show what would be executed in dry-run mode
    if [[ "$dry_run" == "true" ]]; then
        echo ""
        echo -e "${CYAN}=== DRY RUN ===${NC}"
        echo "Project: ${PROJECT_NAME}"
        echo "Model: $model"
        echo "Parallel: $parallel"
        echo "Wait: $wait_flag"
        echo "Include Protocol: $include_protocol"
        echo "Agent: ${agent_id:-all}"
        echo ""
        echo "--- Full prompt that would be sent ---"
        if [[ -n "$agent_id" ]]; then
            build_prompt "$agent_id" "$prompt" "$include_protocol"
        else
            build_prompt "1" "$prompt" "$include_protocol"
            echo ""
            echo "(Same prompt sent to all agents, with AGENT_ID substituted)"
        fi
        echo ""
        exit 0
    fi

    # Execute task
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Claude Factory - Task Dispatch${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    log_info "Project: ${PROJECT_NAME}"
    log_info "Model: $model"
    log_info "Protocol: $([ "$include_protocol" == "true" ] && echo "enabled" || echo "disabled")"
    log_info "Prompt: ${prompt:0:80}..."
    echo ""

    if [[ -n "$agent_id" ]]; then
        # Single agent
        execute_task "$agent_id" "$prompt" "$model" "$wait_flag" "$include_protocol"
    else
        # All agents
        if [[ "$parallel" == "true" ]]; then
            dispatch_all_parallel "$prompt" "$model" "$wait_flag" "$include_protocol"
        else
            dispatch_all_sequential "$prompt" "$model" "$wait_flag" "$include_protocol"
        fi
    fi
}

main "$@"
