# Donna AI Factory - Complete Instructions

> **DO NOT MODIFY THIS FILE** - Permanent reference for setup and troubleshooting.

---

## Quick Start (3 Steps)

```bash
cd donna-factory

# 1. Set up GitHub token (one time)
./setup-token.sh

# 2. Create worktrees and start containers
./setup.sh

# 3. Open agent terminals
./dispatch.sh
```

---

## Daily Usage

### Start Working
```bash
cd donna-factory
./setup.sh        # Start containers (skip if already running)
./dispatch.sh     # Open 5 terminal tabs with Claude agents
```

### Send Tasks
```bash
./dispatch.sh "Your task here"              # Send to all agents
./dispatch.sh --agent 1 "Specific task"     # Send to one agent
./dispatch.sh --model opus "Complex task"   # Use Opus model
./dispatch.sh --wait "Task"                 # Wait for completion
```

### Stop Working
```bash
./teardown.sh     # Stop all containers
```

### Reset (If Things Break)
```bash
./reset.sh        # Clean up worktrees (preserves commits)
./setup.sh        # Recreate everything
```

---

## GitHub Token Setup

Agents need a Personal Access Token with **write** permissions to push code.

### Create Token

**Option 1 - Fine-grained token (Recommended):**
1. Go to: https://github.com/settings/tokens?type=beta
2. Click "Generate new token"
3. Name: "Donna Factory"
4. Repository access: "Only select repositories" → select `donna`
5. Permissions → Repository permissions → **Contents: Read and write**
6. Generate and copy

**Option 2 - Classic token:**
1. Go to: https://github.com/settings/tokens
2. Click "Generate new token (classic)"
3. Check the **`repo`** scope
4. Generate and copy

### Save Token

```bash
cd donna-factory
nano .env
```

Type this line (replace with your token):
```
GH_TOKEN=ghp_your_token_here
```

Save: `Ctrl+X`, then `Y`, then `Enter`

---

## Update Token (When It Expires or Has Wrong Permissions)

### Step 1: Edit .env
```bash
cd donna-factory
nano .env
```
Replace the old token with the new one. Save: `Ctrl+X`, `Y`, `Enter`

### Step 2: Force Restart Containers
```bash
docker compose down
unset GH_TOKEN
docker compose up -d --force-recreate
```

**IMPORTANT:** You must run `unset GH_TOKEN` to clear any cached value, otherwise Docker may use the old token.

### Step 3: Verify New Token is Active
```bash
docker compose config | grep GH_TOKEN
```
This should show your NEW token (not the old one).

### Step 4: Test Push Permission
```bash
docker exec -it donna-agent-1 bash -c "cd /workspace && git push --dry-run origin HEAD"
```

**Success looks like:**
```
Everything up-to-date
```
or
```
To https://github.com/user/donna.git
   abc123..def456  HEAD -> feat/agent-1-workspace
```

**Failure looks like:**
```
remote: Write access to repository not granted.
fatal: unable to access '...': The requested URL returned error: 403
```

If it fails, your token doesn't have write permissions. Create a new one.

---

## Troubleshooting

### Token Not Updating in Containers

Docker caches environment variables. You MUST do all of these:

```bash
docker compose down
unset GH_TOKEN
docker compose up -d --force-recreate
```

Verify it worked:
```bash
docker compose config | grep GH_TOKEN
# Should show NEW token

docker exec donna-agent-1 cat /home/agent/.git-credentials
# Should show: https://oauth2:NEW_TOKEN@github.com
```

### "GH_TOKEN not set"
```bash
./setup-token.sh
```

### "Docker is not running"
Start Docker Desktop, then retry.

### 403 Error on Push (Write Access Not Granted)
Your token doesn't have write permissions:
1. Go to GitHub → Settings → Tokens
2. Check your token has **Contents: Read and write** (fine-grained) or **repo** scope (classic)
3. Create new token if needed
4. Update `.env` and restart containers (see "Update Token" section above)

### "Worktree already used at /workspace"
```bash
./reset.sh
./setup.sh
```

### Container Won't Start
```bash
docker compose logs agent-1
```

### Check What's Actually in Container
```bash
# Check git credentials
docker exec donna-agent-1 cat /home/agent/.git-credentials

# Check environment
docker exec donna-agent-1 env | grep TOKEN

# Test git auth
docker exec -it donna-agent-1 bash -c "cd /workspace && git push --dry-run origin HEAD"
```

---

## Architecture Overview

```
parent-folder/
├── donna/                  # Main repository
├── donna-agent-1/          # Worktree (feat/agent-1-workspace)
├── donna-agent-2/          # Worktree (feat/agent-2-workspace)
├── donna-agent-3/          # Worktree (feat/agent-3-workspace)
├── donna-agent-4/          # Worktree (feat/agent-4-workspace)
├── donna-agent-5/          # Worktree (feat/agent-5-workspace)
└── donna-factory/          # Orchestration
    ├── .env                # GitHub token (gitignored)
    ├── docker-compose.yml  # Container definitions
    ├── Dockerfile          # Container image
    ├── entrypoint.sh       # Container startup script
    ├── setup.sh            # Full setup
    ├── setup-token.sh      # Token configuration
    ├── dispatch.sh         # Task dispatcher
    ├── reset.sh            # Safe reset
    ├── teardown.sh         # Stop containers
    ├── CLAUDE.md           # Agent instructions
    ├── FACTORY.md          # Coordination hub
    └── INSTRUCTIONS.md     # This file
```

### How It Works

1. **Git Worktrees**: Each agent has its own directory/branch. They share `.git` database but don't conflict.

2. **Docker Containers**: Each agent runs in isolation with Claude Code CLI.

3. **HTTPS + Token Auth**: Uses GitHub PAT (not SSH). Simpler in Docker.

4. **FACTORY.md Coordination**: Agents claim files here to avoid conflicts.

---

## All Commands Reference

| Command | Description |
|---------|-------------|
| `./setup-token.sh` | Configure GitHub authentication |
| `./setup.sh` | Create worktrees and start containers |
| `./dispatch.sh` | Open terminal tabs for all agents |
| `./dispatch.sh "task"` | Send task to all agents |
| `./dispatch.sh --agent N "task"` | Send task to agent N (1-5) |
| `./dispatch.sh --model opus "task"` | Use opus/sonnet/haiku |
| `./dispatch.sh --wait "task"` | Wait for completion |
| `./dispatch.sh --interactive --agent N` | Interactive session |
| `./reset.sh` | Clean up (preserves commits) |
| `./teardown.sh` | Stop containers |

### Docker Commands
| Command | Description |
|---------|-------------|
| `docker compose down` | Stop containers |
| `docker compose up -d` | Start containers |
| `docker compose up -d --force-recreate` | Restart with fresh config |
| `docker compose config \| grep GH_TOKEN` | Check token Docker sees |
| `docker compose logs agent-1` | View logs |
| `docker exec -it donna-agent-1 bash` | Shell into container |

---

## Agent Branches

- Agent 1: `feat/agent-1-workspace`
- Agent 2: `feat/agent-2-workspace`
- Agent 3: `feat/agent-3-workspace`
- Agent 4: `feat/agent-4-workspace`
- Agent 5: `feat/agent-5-workspace`

Review branches before merging to main!

---

## Security Notes

- Agents run with `--dangerously-skip-permissions` (full autonomy)
- Review agent commits before merging
- `.env` is gitignored (never committed)
- Use minimum necessary token permissions

---

*Last updated: January 2025*
