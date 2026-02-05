# Claude Factory - Coordination System

Agent coordination uses a JSON lockfile (`factory-state.json`) stored in the factory directory, outside the git repo. This avoids merge conflicts that occur with in-repo coordination files.

## How It Works

The `factory-state.json` file tracks:
- **Agent status** — idle, working, done
- **File claims** — which agent owns which files
- **Messages** — inter-agent communication
- **Task queue** — prioritized task list

## Commands

| Command | Description |
|---------|-------------|
| `./claim.sh <agent-id> <file>` | Claim a file before editing |
| `./release.sh <agent-id> [file]` | Release a claim (or all claims for agent) |
| `./status.sh` | View current coordination state |
| `./init-coordination.sh` | Reset coordination state |

## Agent IDs

Factory agents use numeric IDs (1, 2, 3...) matching their worktree number. External Claude instances — those running outside the factory — can use any alphanumeric string as their agent ID (e.g. `external`, `cowork`, `main-repo`). Both types share the same `factory-state.json` lockfile and coordinate through the same `claim.sh`/`release.sh` scripts.

## Sync Protocol

1. **Before starting work:** `git fetch origin && git rebase origin/main`
2. **Claim your files:** `./claim.sh <id> <file-path>`
3. **During work:** Commit frequently with clear messages
4. **Before touching shared files:** Check claims via `./status.sh`
5. **When finished:** Release claims with `./release.sh <id>`, push final commits
