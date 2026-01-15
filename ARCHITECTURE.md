# Donna AI Factory - Architecture Overview

## Directory Structure

```
~/Projects/                          # Your projects root (adjust as needed)
├── donna/                           # Main Donna repository (source of truth)
│   ├── .git/                        # Git directory
│   ├── apps/
│   ├── modules/
│   ├── adapters/
│   └── ...
│
├── donna-factory/                   # Control center (this folder)
│   ├── Dockerfile                   # Agent container definition
│   ├── docker-compose.yml           # Multi-agent orchestration
│   ├── setup.sh                     # Initialize worktrees & start containers
│   ├── dispatch.sh                  # Send tasks to agents
│   ├── status.sh                    # Check agent status
│   ├── teardown.sh                  # Clean shutdown
│   └── logs/                        # Agent output logs
│
├── donna-agent-1/                   # Git Worktree for Agent 1
│   └── (full donna codebase)        # Branch: feat/agent-1-workspace
│
├── donna-agent-2/                   # Git Worktree for Agent 2
│   └── (full donna codebase)        # Branch: feat/agent-2-workspace
│
├── donna-agent-3/                   # Git Worktree for Agent 3
│   └── (full donna codebase)        # Branch: feat/agent-3-workspace
│
├── donna-agent-4/                   # Git Worktree for Agent 4
│   └── (full donna codebase)        # Branch: feat/agent-4-workspace
│
└── donna-agent-5/                   # Git Worktree for Agent 5
    └── (full donna codebase)        # Branch: feat/agent-5-workspace
```

## How It Works

### Git Worktrees
Each agent gets its own worktree - a separate working directory linked to the same
Git repository. This allows:
- Parallel development without file conflicts
- Each agent works on its own branch
- Easy merging back to main when work is complete

### Docker Containers
Each agent runs in its own container with:
- Node.js runtime (for claude-code CLI)
- Git and GitHub CLI for version control
- Your SSH keys mounted (read-only) for Git authentication
- Your Claude credentials mounted for API access
- The worktree mounted as the workspace

### Headless Mode
Containers run with `tail -f /dev/null` to stay alive in the background.
You send commands to them via `docker exec`, allowing:
- Persistent sessions
- Multiple commands over time
- Background processing

## Quick Start

```bash
# 1. Initialize everything
./setup.sh

# 2. Send a task to all agents
./dispatch.sh "Review the codebase and identify potential improvements"

# 3. Send a task to specific agent
./dispatch.sh --agent 1 "Work on GitHub issue #42"

# 4. Check status
./status.sh

# 5. Shut down when done
./teardown.sh
```

## Security Notes

- SSH keys are mounted read-only
- Claude credentials are mounted read-only
- The `--dangerously-skip-permissions` flag is required for autonomous operation
- Review agent outputs before merging to main
