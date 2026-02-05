# Claude Factory

Multi-agent orchestration system that runs parallel Claude Code CLI instances, each with their own Git worktree.

## Quick Start

```bash
# 1. Clone this repo next to your project
cd ~/code
git clone https://github.com/dmdzco/claude-factory.git

# 2. Configure for your project
cd claude-factory
cp factory.conf.example factory.conf
nano factory.conf  # Set PROJECT_NAME and TARGET_REPO

# 3. Run setup
./setup.sh

# 4. Open agent terminals
./dispatch.sh
```

## Requirements

- **Git** - For worktree management
- **jq** - For coordination state (`brew install jq` or `apt-get install jq`)
- **Claude Code CLI** - `npm install -g @anthropic-ai/claude-code`
- **Claude Authentication** - Run `claude` once and log in
- **GitHub Token** - With write access to your repo (optional, for pushing)

## Configuration

Edit `factory.conf`:

```bash
# Project name (used for worktree directories and branch names)
PROJECT_NAME="myapp"

# Number of parallel agents (1-10)
NUM_AGENTS=3

# Default Claude model (sonnet, opus, haiku)
DEFAULT_MODEL="sonnet"

# Target repository directory (relative to parent of this factory directory)
TARGET_REPO="myapp"
```

You can also set agent count via CLI: `./setup.sh -n 5`

## Directory Structure

**Before setup:**
```
~/code/
├── myapp/              # Your existing git repository
└── claude-factory/     # This tool
```

**After `./setup.sh`:**
```
~/code/
├── myapp/              # Your main repository (unchanged)
├── myapp-agent-1/      # Worktree → branch: feat/agent-1-workspace
├── myapp-agent-2/      # Worktree → branch: feat/agent-2-workspace
├── myapp-agent-3/      # Worktree → branch: feat/agent-3-workspace
└── claude-factory/     # Orchestration scripts
    ├── factory.conf
    ├── factory-state.json  # Coordination state (auto-generated)
    └── .env                # GitHub token (gitignored)
```

## How It Works

Each agent gets its own Git worktree (a separate working directory on its own branch, sharing the same `.git` history). Claude CLI runs directly in each worktree with `--dangerously-skip-permissions` for full autonomy.

Agents coordinate through `factory-state.json` — a lockfile that tracks file claims, agent status, and messages. Helper scripts (`claim.sh`, `release.sh`) provide atomic, conflict-free coordination.

## Commands

| Command | Description |
|---------|-------------|
| `./setup.sh` | Create worktrees for all agents |
| `./setup.sh -n 5` | Set agent count to 5 and create worktrees |
| `./dispatch.sh` | Open terminal tab for each agent |
| `./dispatch.sh --agent 1` | Open terminal for specific agent |
| `./dispatch.sh --model opus` | Use a specific model |
| `./status.sh` | Show status of all agents and claims |
| `./claim.sh <id> <file>` | Claim a file for an agent |
| `./release.sh <id> [file]` | Release a file claim (or all claims) |
| `./reset.sh` | Clean up worktrees (preserves commits) |
| `./teardown.sh` | Remove worktrees (preserves branches) |
| `./teardown.sh --full` | Remove worktrees, branches, and state |

## Agent Coordination

Agents coordinate through `factory-state.json` using helper scripts:

```bash
# Agent 1 claims a file before editing
./claim.sh 1 src/auth.js

# Check current claims
./status.sh

# Release when done
./release.sh 1 src/auth.js
# or release all claims: ./release.sh 1
```

### External Agents

Claude instances running outside the factory can participate in coordination using a string ID:

```bash
# External Claude instance claims a file
./claim.sh external src/config.js

# Check current claims
./status.sh

# Release when done
./release.sh external
```

The `CLAUDE.md` file in each workspace instructs agents on this protocol.

## GitHub Token Setup

If agents need to push code, they need a Personal Access Token:

1. Go to https://github.com/settings/tokens?type=beta
2. Generate a fine-grained token with Contents: Read and write
3. Run `./setup-token.sh` to save it, or manually edit `.env`

## Troubleshooting

**"factory.conf not found"** — Run `cp factory.conf.example factory.conf` and edit it.

**"Target repository not found"** — Your repo must exist parallel to claude-factory: `ls ../myapp`

**"jq not found"** — Install with `brew install jq` (macOS) or `apt-get install jq` (Linux).

**Worktree issues / detached HEAD** — Run `./reset.sh` then `./setup.sh`.

**403 error on push** — Your token needs write permissions. Regenerate with `repo` scope.

## Security Notes

- Agents run with `--dangerously-skip-permissions` (full autonomy)
- Review agent commits before merging to main
- `.env` and `factory.conf` are gitignored
- Use minimum necessary token permissions

## License

MIT
