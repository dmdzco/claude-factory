#!/usr/bin/env bash
#===============================================================================
# Donna AI Factory - Open Dashboard
# Opens 5 terminal tabs, one for each agent (macOS)
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-watch}"

echo "Opening agent dashboard with mode: ${MODE}"
echo ""

# Detect terminal application
if [[ -d "/Applications/iTerm.app" ]]; then
    TERMINAL="iterm"
elif [[ -d "/Applications/Utilities/Terminal.app" ]]; then
    TERMINAL="terminal"
else
    echo "No supported terminal found. Please open tabs manually:"
    echo ""
    for i in 1 2 3 4 5; do
        echo "  Tab ${i}: cd ${SCRIPT_DIR} && ./attach.sh ${i} ${MODE}"
    done
    exit 0
fi

if [[ "$TERMINAL" == "iterm" ]]; then
    # iTerm2 - use AppleScript to open tabs
    osascript <<EOF
tell application "iTerm"
    activate

    -- Create new window with first agent
    set newWindow to (create window with default profile)
    tell current session of newWindow
        write text "cd '${SCRIPT_DIR}' && ./attach.sh 1 ${MODE}"
    end tell

    -- Create tabs for agents 2-5
    repeat with i from 2 to 5
        tell newWindow
            set newTab to (create tab with default profile)
            tell current session of newTab
                write text "cd '${SCRIPT_DIR}' && ./attach.sh " & i & " ${MODE}"
            end tell
        end tell
    end repeat

    -- Select first tab
    tell newWindow
        select first tab
    end tell
end tell
EOF
    echo "✅ Opened iTerm2 window with 5 agent tabs"

elif [[ "$TERMINAL" == "terminal" ]]; then
    # Terminal.app - use AppleScript
    osascript <<EOF
tell application "Terminal"
    activate

    -- First tab (new window)
    do script "cd '${SCRIPT_DIR}' && ./attach.sh 1 ${MODE}"
    set agentWindow to front window

    -- Create tabs for agents 2-5
    repeat with i from 2 to 5
        tell application "System Events" to keystroke "t" using command down
        delay 0.3
        do script "cd '${SCRIPT_DIR}' && ./attach.sh " & i & " ${MODE}" in front window
    end repeat

    -- Select first tab
    tell application "System Events" to keystroke "1" using command down
end tell
EOF
    echo "✅ Opened Terminal.app window with 5 agent tabs"
fi

echo ""
echo "Each tab is now attached to an agent in '${MODE}' mode."
echo ""
echo "Quick reference:"
echo "  watch  - See live task output"
echo "  shell  - Bash shell in container"
echo "  claude - Interactive Claude session"
echo ""
echo "To dispatch tasks from your main terminal:"
echo "  ./dispatch.sh --agent 1 \"Your task here\""
