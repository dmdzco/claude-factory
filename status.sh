#!/usr/bin/env bash
#===============================================================================
# Donna AI Factory - Status Script
# Shows the current status of all agents and their worktrees
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
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
DONNA_REPO="${PARENT_DIR}/donna"
NUM_AGENTS=5

#-------------------------------------------------------------------------------
# Helper Functions
#-------------------------------------------------------------------------------

print_header() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

status_icon() {
    if [[ "$1" == "true" || "$1" == "running" ]]; then
        echo -e "${GREEN}●${NC}"
    else
        echo -e "${RED}○${NC}"
    fi
}

#-------------------------------------------------------------------------------
# Status Checks
#-------------------------------------------------------------------------------

check_docker_status() {
    print_header "Docker Container Status"

    printf "%-20s %-12s %-15s %-20s\n" "CONTAINER" "STATUS" "UPTIME" "IMAGE"
    printf "%-20s %-12s %-15s %-20s\n" "─────────" "──────" "──────" "─────"

    for i in $(seq 1 $NUM_AGENTS); do
        local container="donna-agent-${i}"
        local status="stopped"
        local uptime="-"
        local image="-"

        if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            status="running"
            uptime=$(docker ps --filter "name=${container}" --format '{{.Status}}' | head -1)
            image=$(docker ps --filter "name=${container}" --format '{{.Image}}' | head -1)
        fi

        local icon=$(status_icon "$status")
        printf "%s %-18s %-12s %-15s %-20s\n" "$icon" "$container" "$status" "${uptime:0:15}" "${image:0:20}"
    done

    echo ""
}

check_worktree_status() {
    print_header "Git Worktree Status"

    if [[ ! -d "$DONNA_REPO" ]]; then
        echo -e "${RED}Donna repository not found!${NC}"
        return
    fi

    cd "$DONNA_REPO"

    printf "%-20s %-10s %-30s %-15s\n" "WORKTREE" "EXISTS" "BRANCH" "STATUS"
    printf "%-20s %-10s %-30s %-15s\n" "────────" "──────" "──────" "──────"

    for i in $(seq 1 $NUM_AGENTS); do
        local worktree_path="${PARENT_DIR}/donna-agent-${i}"
        local name="donna-agent-${i}"
        local exists="no"
        local branch="-"
        local status="-"

        if [[ -d "$worktree_path" ]]; then
            exists="yes"

            if [[ -d "${worktree_path}/.git" ]] || [[ -f "${worktree_path}/.git" ]]; then
                branch=$(cd "$worktree_path" && git branch --show-current 2>/dev/null || echo "detached")

                # Get working tree status
                local changes=$(cd "$worktree_path" && git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
                if [[ "$changes" -eq 0 ]]; then
                    status="clean"
                else
                    status="${changes} changes"
                fi
            fi
        fi

        local icon=$(status_icon "$exists")
        printf "%s %-18s %-10s %-30s %-15s\n" "$icon" "$name" "$exists" "${branch:0:30}" "$status"
    done

    echo ""

    # Show full worktree list from git
    echo -e "${BLUE}Git Worktree List:${NC}"
    git worktree list 2>/dev/null || echo "  (could not list worktrees)"
    echo ""
}

check_resource_usage() {
    print_header "Resource Usage"

    local running_containers=$(docker ps --filter "name=donna-agent" --format '{{.Names}}' | wc -l | tr -d ' ')

    if [[ "$running_containers" -eq 0 ]]; then
        echo "No agents running"
        return
    fi

    echo -e "${BLUE}Container Resources:${NC}"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" \
        $(docker ps --filter "name=donna-agent" --format '{{.Names}}') 2>/dev/null || echo "  (stats unavailable)"

    echo ""
}

check_recent_logs() {
    print_header "Recent Activity"

    local log_dir="${SCRIPT_DIR}/logs"

    if [[ ! -d "$log_dir" ]] || [[ -z "$(ls -A "$log_dir" 2>/dev/null)" ]]; then
        echo "No log files found"
        return
    fi

    echo -e "${BLUE}Recent Log Files:${NC}"
    ls -lt "$log_dir" 2>/dev/null | head -10 | while read line; do
        echo "  $line"
    done

    echo ""
}

show_quick_commands() {
    print_header "Quick Commands"

    echo "Start agents:         ./setup.sh"
    echo "Send task:            ./dispatch.sh \"Your task\""
    echo "Send to one agent:    ./dispatch.sh --agent 1 \"Task\""
    echo "Interactive session:  ./dispatch.sh --agent 1 --interactive"
    echo "View logs:            docker compose logs -f agent-1"
    echo "Access shell:         docker exec -it donna-agent-1 bash"
    echo "Stop all agents:      ./teardown.sh"
    echo ""
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------

main() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          DONNA AI FACTORY - STATUS DASHBOARD                  ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"

    check_docker_status
    check_worktree_status
    check_resource_usage
    check_recent_logs
    show_quick_commands
}

main "$@"
