#!/bin/bash
#===============================================================================
# Donna AI Factory - Container Entrypoint
# SIMPLIFIED: Uses git credential store with GH_TOKEN for reliable auth
#===============================================================================

echo "[entrypoint] Starting container initialization..."

#-------------------------------------------------------------------------------
# 1. Fix Git worktree path (container sees /workspace, host sees different path)
#    ONLY fix the local .git file, NOT the shared worktree metadata
#-------------------------------------------------------------------------------

WORKTREE_GIT_FILE="/workspace/.git"
MAIN_GIT_DIR="/workspace/../donna/.git"

if [[ -f "$WORKTREE_GIT_FILE" ]]; then
    current_content=$(cat "$WORKTREE_GIT_FILE")
    worktree_name=$(echo "$current_content" | grep -oE 'donna-agent-[0-9]+' | head -1)

    if [[ -n "$worktree_name" ]]; then
        new_gitdir="gitdir: ${MAIN_GIT_DIR}/worktrees/${worktree_name}"

        if [[ "$current_content" != "$new_gitdir" ]]; then
            echo "[entrypoint] Fixing local worktree path for ${worktree_name}"
            echo "$new_gitdir" > "$WORKTREE_GIT_FILE"
        fi

        # NOTE: We intentionally do NOT modify the reverse reference in
        # .git/worktrees/*/gitdir because that would corrupt the host's
        # worktree list with container paths (/workspace)
    fi
fi

#-------------------------------------------------------------------------------
# 2. Configure Git authentication using credential store
#-------------------------------------------------------------------------------

if [[ -n "${GH_TOKEN:-}" ]]; then
    echo "[entrypoint] Configuring Git authentication with token..."

    git config --global credential.helper store

    CRED_FILE="/home/agent/.git-credentials"
    echo "https://oauth2:${GH_TOKEN}@github.com" > "$CRED_FILE"
    chmod 600 "$CRED_FILE"

    # Also configure gh CLI
    echo "$GH_TOKEN" | gh auth login --with-token 2>/dev/null || true

    echo "[entrypoint] Git authentication configured successfully"
else
    echo "[entrypoint] WARNING: GH_TOKEN not set - git push will fail!"
    echo "[entrypoint] Run ./setup-token.sh on your Mac to configure authentication"
fi

#-------------------------------------------------------------------------------
# 3. Ensure remote uses HTTPS (not SSH)
#-------------------------------------------------------------------------------

cd /workspace 2>/dev/null || true

if git remote get-url origin 2>/dev/null | grep -q "git@github.com"; then
    current_url=$(git remote get-url origin)
    https_url=$(echo "$current_url" | sed 's|git@github.com:|https://github.com/|')
    git remote set-url origin "$https_url"
    echo "[entrypoint] Converted remote to HTTPS: $https_url"
fi

echo "[entrypoint] Initialization complete"

exec "$@"
