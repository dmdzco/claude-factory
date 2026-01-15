# Claude Factory

Multi-agent orchestration system that runs parallel Claude Code CLI instances in Docker containers, each with their own Git worktree. **Works with any project.**

## Quick Start

```bash
# 1. Clone this repo
git clone https://github.com/yourusername/claude-factory.git
cd claude-factory

# 2. Configure for your project
cp factory.conf.example factory.conf
nano factory.conf  # Set PROJECT_NAME to your repo name

# 3. Run setup (will prompt for GitHub token)
./setup.sh

# 4. Open agent terminals
./dispatch.sh
```

## Configuration

Edit `factory.conf` to customize:

```bash
# Project name - creates containers like: myapp-agent-1, myapp-agent-2, etc.
PROJECT_NAME="myapp"

# Number of parallel agents (1-10)
NUM_AGENTS=5

# Default Claude model
DEFAULT_MODEL="sonnet"

# Target repository (folder name, must exist parallel to claude-factory)
TARGET_REPO="myapp"
```

## How It Works

Each agent runs in a Docker container with:
- Its own Git worktree (isolated branch)
- Claude Code CLI for autonomous coding
- Git credentials for committing AND pushing

Authentication uses **HTTPS with a GitHub Personal Access Token** (not SSH). This is simpler and more reliable in Docker.

## Directory Structure

```
parent-folder/
├── myapp/                  # Your main repository
├── myapp-agent-1/          # Worktree for Agent 1
├── myapp-agent-2/          # Worktree for Agent 2
├── myapp-agent-3/          # Worktree for Agent 3
├── myapp-agent-4/          # Worktree for Agent 4
├── myapp-agent-5/          # Worktree for Agent 5
└── claude-factory/         # This folder (orchestration)
    ├── factory.conf        # Your project configuration
    ├── setup.sh            # Create worktrees & start containers
    ├── dispatch.sh         # Open terminal tabs for agents
    ├── reset.sh            # Clean up (preserves commits)
    ├── teardown.sh         # Stop containers
    └── .env                # Your GitHub token (gitignored)
```

## Commands

| Command | Description |
|---------|-------------|
| `./setup.sh` | Create worktrees and start containers |
| `./dispatch.sh` | Open terminal tab for each agent |
| `./dispatch.sh "task"` | Send a task to all agents |
| `./dispatch.sh --agent 1 "task"` | Send task to specific agent |
| `./dispatch.sh --model opus "task"` | Use a specific model |
| `./reset.sh` | Clean up worktrees (keeps commits) |
| `./teardown.sh` | Stop all containers |

## GitHub Token Setup

Agents need a Personal Access Token with **write** permissions to push code.

### Create Token

**Option 1 - Fine-grained token (Recommended):**
1. Go to: https://github.com/settings/tokens?type=beta
2. Click "Generate new token"
3. Repository access: Select your target repo
4. Permissions → Repository permissions → **Contents: Read and write**
5. Generate and copy

**Option 2 - Classic token:**
1. Go to: https://github.com/settings/tokens
2. Click "Generate new token (classic)"
3. Check the **`repo`** scope
4. Generate and copy

The setup script will prompt you to paste your token on first run.

## Troubleshooting

### "GH_TOKEN not set"
Run `./setup.sh` - it will prompt for your token.

### "Docker is not running"
Start Docker Desktop before running setup.

### 403 Error on Push
Your token doesn't have write permissions. Create a new one with correct scopes.

### Token Not Updating in Containers
```bash
docker compose down
unset GH_TOKEN
docker compose up -d --force-recreate
```

### Worktree Issues
```bash
./reset.sh      # Clean up worktrees
./setup.sh      # Recreate everything
```

### Container Won't Start
```bash
docker compose logs agent-1
```

## Requirements

- Docker Desktop
- Claude Code CLI (`npm install -g @anthropic-ai/claude-code`)
- Authenticated with Claude (`claude` and log in)
- GitHub Personal Access Token with write access

## Agent Coordination

Agents use `FACTORY.md` in your repo to coordinate:
- Claim files before editing to avoid conflicts
- Check what other agents are working on
- Leave messages for other agents

## Security Notes

- Agents run with `--dangerously-skip-permissions` (full autonomy)
- Review agent commits before merging
- `.env` is gitignored (never committed)
- Use minimum necessary token permissions

## License

MIT
