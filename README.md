# Claude Factory

Multi-agent orchestration system that runs parallel Claude Code CLI instances in Docker containers, each with their own Git worktree. **Works with any project.**

## Quick Start

```bash
# 1. Clone this repo next to your project
cd ~/code  # or wherever your projects live
git clone https://github.com/dmdzco/claude-factory.git

# 2. Configure for your project
cd claude-factory
cp factory.conf.example factory.conf
nano factory.conf  # Edit the settings (see below)

# 3. Run setup (will prompt for GitHub token on first run)
./setup.sh

# 4. Open agent terminals
./dispatch.sh
```

## Configuration

Edit `factory.conf` to customize for your project:

```bash
#===============================================================================
# Claude Factory - Configuration
#===============================================================================

# Project name - used for container names and worktree directories
# Example: PROJECT_NAME="myapp" creates:
#   - Containers: myapp-agent-1, myapp-agent-2, ...
#   - Worktrees:  ../myapp-agent-1/, ../myapp-agent-2/, ...
#   - Branches:   feat/agent-1-workspace, feat/agent-2-workspace, ...
PROJECT_NAME="myapp"

# Number of parallel agents (1-10)
# More agents = more parallel work, but more resources
NUM_AGENTS=5

# Default Claude model (sonnet, opus, haiku)
# opus = most capable, haiku = fastest/cheapest
DEFAULT_MODEL="sonnet"

# Target repository folder name
# Must exist at ../TARGET_REPO relative to claude-factory
# Usually same as PROJECT_NAME
TARGET_REPO="myapp"
```

### Configuration Examples

**Small API project (2 agents):**
```bash
PROJECT_NAME="my-api"
NUM_AGENTS=2
DEFAULT_MODEL="sonnet"
TARGET_REPO="my-api"
```

**Large monorepo (10 agents with Opus):**
```bash
PROJECT_NAME="enterprise-app"
NUM_AGENTS=10
DEFAULT_MODEL="opus"
TARGET_REPO="enterprise-app"
```

**When repo folder has different name:**
```bash
PROJECT_NAME="frontend"           # Used for container names
TARGET_REPO="acme-corp-frontend"  # Actual folder name
```

## Directory Structure

**Before setup:**
```
~/code/
├── myapp/              # Your existing git repository
└── claude-factory/     # This tool (just cloned)
```

**After `./setup.sh`:**
```
~/code/
├── myapp/              # Your main repository (unchanged)
├── myapp-agent-1/      # Worktree for Agent 1 (branch: feat/agent-1-workspace)
├── myapp-agent-2/      # Worktree for Agent 2 (branch: feat/agent-2-workspace)
├── myapp-agent-3/      # Worktree for Agent 3 (branch: feat/agent-3-workspace)
├── myapp-agent-4/      # Worktree for Agent 4 (branch: feat/agent-4-workspace)
├── myapp-agent-5/      # Worktree for Agent 5 (branch: feat/agent-5-workspace)
└── claude-factory/     # Orchestration scripts
    ├── factory.conf    # Your configuration
    ├── .env            # GitHub token (gitignored)
    └── ...
```

## How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                      Your Machine                            │
│                                                              │
│  myapp/                    ← Main repo (shared .git)        │
│  myapp-agent-1/            ← Worktree (isolated branch)     │
│  myapp-agent-2/            ← Worktree (isolated branch)     │
│  ...                                                         │
│                                                              │
│  ┌─────────────── Docker Containers ──────────────┐         │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐        │         │
│  │  │Agent 1  │  │Agent 2  │  │Agent 3  │  ...   │         │
│  │  │Claude   │  │Claude   │  │Claude   │        │         │
│  │  └────┬────┘  └────┬────┘  └────┬────┘        │         │
│  └───────┼───────────┼───────────┼───────────────┘         │
│          │           │           │                          │
│          ▼           ▼           ▼                          │
│    myapp-agent-1  myapp-agent-2  myapp-agent-3              │
│    (volume mounts to worktrees)                             │
└─────────────────────────────────────────────────────────────┘
```

Each agent:
- Runs in an isolated Docker container
- Has its own Git worktree (separate branch)
- Can commit AND push to GitHub autonomously
- Uses HTTPS + token authentication (simpler than SSH)

## Commands

| Command | Description |
|---------|-------------|
| `./setup.sh` | Create worktrees and start containers |
| `./dispatch.sh` | Open terminal tab for each agent |
| `./dispatch.sh "task"` | Send a task to all agents |
| `./dispatch.sh --agent 1 "task"` | Send task to specific agent |
| `./dispatch.sh --model opus "task"` | Use a specific model |
| `./status.sh` | Show status of all agents |
| `./reset.sh` | Clean up worktrees (preserves commits) |
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

### Update Token

If your token expires or you need to change it:

```bash
# Edit the token
nano .env   # Replace the GH_TOKEN value

# Restart containers with new token
docker compose down
unset GH_TOKEN
docker compose up -d --force-recreate
```

### Verify Token Works

```bash
# Test push (dry-run, won't actually push)
docker exec -it myapp-agent-1 bash -c "cd /workspace && git push --dry-run origin HEAD"
```

## Troubleshooting

### "factory.conf not found"
```bash
cp factory.conf.example factory.conf
nano factory.conf  # Set your PROJECT_NAME and TARGET_REPO
```

### "Target repository not found"
Your repo must exist parallel to claude-factory:
```bash
ls ../myapp  # Should show your repo contents
```

### "GH_TOKEN not set"
Run `./setup.sh` - it will prompt for your token.

### "Docker is not running"
Start Docker Desktop before running setup.

### 403 Error on Push
Your token doesn't have write permissions. Create a new one with `repo` scope or Contents: Read and write.

### Token Not Updating in Containers
```bash
docker compose down
unset GH_TOKEN                    # Clear cached value
docker compose up -d --force-recreate
```

### Container Name Conflict
```bash
# Remove old containers
docker ps -a --filter "name=myapp-agent" -q | xargs docker rm -f
docker network prune -f
./setup.sh
```

### Worktree Issues / Detached HEAD
```bash
./reset.sh      # Clean up worktrees (preserves commits)
./setup.sh      # Recreate everything
```

### Container Won't Start
```bash
docker compose logs agent-1
```

## Requirements

- **Docker Desktop** - For running agent containers
- **Git** - For worktree management
- **Claude Code CLI** - `npm install -g @anthropic-ai/claude-code`
- **Claude Authentication** - Run `claude` once and log in
- **GitHub Token** - With write access to your repo

## Agent Coordination

Agents use `FACTORY.md` in your repo to coordinate:
- Claim files before editing to avoid conflicts
- Check what other agents are working on
- Leave messages for other agents

## Switching Projects

To use Claude Factory with a different project:

```bash
# Edit configuration
nano factory.conf
# Change PROJECT_NAME and TARGET_REPO

# Reset and setup for new project
./teardown.sh
./reset.sh
./setup.sh
```

## Security Notes

- Agents run with `--dangerously-skip-permissions` (full autonomy)
- Review agent commits before merging to main
- `.env` is gitignored (never committed)
- `factory.conf` is gitignored (contains project-specific settings)
- Use minimum necessary token permissions

## License

MIT
