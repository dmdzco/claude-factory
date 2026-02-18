# Claude Factory - Coordination System

Droid coordination uses a JSON lockfile (`factory-state.json`) stored in the factory directory, outside the git repo. This avoids merge conflicts that occur with in-repo coordination files.

## How It Works

The `factory-state.json` file tracks:
- **Droid status** — idle, working, done
- **File claims** — which droid owns which files
- **Messages** — inter-droid communication
- **Task queue** — prioritized task list

## Commands

| Command | Description |
|---------|-------------|
| `./cf-claim.sh <droid-id> <file>` | Claim a file before editing |
| `./cf-release.sh <droid-id> [file]` | Release a claim (or all claims for droid) |
| `./cf-status.sh` | View current coordination state |
| `./cf-init-coordination.sh` | Reset coordination state |

## Droid IDs

Factory droids use numeric IDs (1, 2, 3...) matching their worktree number. External Claude instances — those running outside the factory — can use any alphanumeric string as their droid ID (e.g. `external`, `cowork`, `main-repo`). Both types share the same `factory-state.json` lockfile and coordinate through the same `cf-claim.sh`/`cf-release.sh` scripts.

## tmux Session Layout

Each droid gets its own tmux window (tab) in a single session (`{PROJECT_NAME}-factory`):

```
Tab: droid-1       Tab: droid-2       Tab: droid-3       Tab: droid-4
┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│   Droid 1    │  │   Droid 2    │  │   Droid 3    │  │   Droid 4    │
└──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘
```

Navigate with `Ctrl-b n`/`p` (next/previous tab) or `Ctrl-b w` (list all tabs). Detach with `Ctrl-b d`, reattach with `tmux attach -t {PROJECT_NAME}-factory`.

## Sync Protocol

1. **Before starting work:** `git fetch origin && git rebase origin/main`
2. **Claim your files:** `./cf-claim.sh <id> <file-path>`
3. **During work:** Commit frequently with clear messages
4. **Before touching shared files:** Check claims via `./cf-status.sh`
5. **When finished:** Release claims with `./cf-release.sh <id>`, push final commits
