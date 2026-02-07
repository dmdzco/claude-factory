# Claude Factory

Multi-droid orchestration system that runs parallel Claude Code CLI instances, each with their own Git worktree.

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
./cf-setup.sh

# 4. Open droid terminals
./cf-dispatch.sh
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

# Number of parallel droids (1-10)
NUM_DROIDS=3

# Default Claude model (sonnet, opus, haiku)
DEFAULT_MODEL="sonnet"

# Target repository directory (relative to parent of this factory directory)
TARGET_REPO="myapp"
```

You can also set droid count via CLI: `./cf-setup.sh -n 5`

## Directory Structure

**Before setup:**
```
~/code/
├── myapp/              # Your existing git repository
└── claude-factory/     # This tool
```

**After `./cf-setup.sh`:**
```
~/code/
├── myapp/              # Your main repository (unchanged)
├── myapp-1/      # Worktree → branch: feat/droid-1-workspace
├── myapp-2/      # Worktree → branch: feat/droid-2-workspace
├── myapp-3/      # Worktree → branch: feat/droid-3-workspace
└── claude-factory/     # Orchestration scripts
    ├── factory.conf
    ├── factory-state.json  # Coordination state (auto-generated)
    └── .env                # GitHub token (gitignored)
```

## How It Works

Each droid gets its own Git worktree (a separate working directory on its own branch, sharing the same `.git` history). Claude CLI runs directly in each worktree with `--dangerously-skip-permissions` for full autonomy.

Droids coordinate through `factory-state.json` — a lockfile that tracks file claims, droid status, and messages. Helper scripts (`cf-claim.sh`, `cf-release.sh`) provide atomic, conflict-free coordination.

## Commands

| Command | Description |
|---------|-------------|
| `./cf-setup.sh` | Create worktrees for all droids |
| `./cf-setup.sh -n 5` | Set droid count to 5 and create worktrees |
| `./cf-dispatch.sh` | Open terminal tab for each droid |
| `./cf-dispatch.sh --droid 1` | Open terminal for specific droid |
| `./cf-dispatch.sh --model opus` | Use a specific model |
| `./cf-status.sh` | Show status of all droids and claims |
| `./cf-claim.sh <id> <file>` | Claim a file for a droid |
| `./cf-release.sh <id> [file]` | Release a file claim (or all claims) |
| `./cf-reset.sh` | Clean up worktrees (preserves commits) |
| `./cf-teardown.sh` | Remove worktrees (preserves branches) |
| `./cf-teardown.sh --full` | Remove worktrees, branches, and state |

## Droid Coordination

Droids coordinate through `factory-state.json` using helper scripts:

```bash
# Droid 1 claims a file before editing
./cf-claim.sh 1 src/auth.js

# Check current claims
./cf-status.sh

# Release when done
./cf-release.sh 1 src/auth.js
# or release all claims: ./cf-release.sh 1
```

### External Droids

Claude instances running outside the factory can participate in coordination using a string ID:

```bash
# External Claude instance claims a file
./cf-claim.sh external src/config.js

# Check current claims
./cf-status.sh

# Release when done
./cf-release.sh external
```

The `CLAUDE.md` file in each workspace instructs droids on this protocol.

## GitHub Token Setup

If droids need to push code, they need a Personal Access Token:

1. Go to https://github.com/settings/tokens?type=beta
2. Generate a fine-grained token with Contents: Read and write
3. Run `./cf-setup-token.sh` to save it, or manually edit `.env`

## Troubleshooting

**"factory.conf not found"** — Run `cp factory.conf.example factory.conf` and edit it.

**"Target repository not found"** — Your repo must exist parallel to claude-factory: `ls ../myapp`

**"jq not found"** — Install with `brew install jq` (macOS) or `apt-get install jq` (Linux).

**Worktree issues / detached HEAD** — Run `./cf-reset.sh` then `./cf-setup.sh`.

**403 error on push** — Your token needs write permissions. Regenerate with `repo` scope.

## Security Notes

- Droids run with `--dangerously-skip-permissions` (full autonomy)
- Review droid commits before merging to main
- `.env` and `factory.conf` are gitignored
- Use minimum necessary token permissions

## License

MIT
