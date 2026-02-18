# Claude Factory - Quick Start

## Start Everything

```bash
cd claude-factory
./cf-start.sh
```

This will:
1. Create Git worktrees for each droid (if needed)
2. Initialize coordination state
3. Launch all droids in a tmux session (2 per window, side-by-side)

## What You'll See

After running `./cf-start.sh`, you'll be attached to a tmux session with droids paired in windows:

```
┌──────────────────────────────────────────────────────────────────┐
│  Window: droids-1-2                                              │
│  ┌──────────────────────────┬───────────────────────────────┐    │
│  │  Droid 1                 │  Droid 2                      │    │
│  │  Branch: feat/droid-1    │  Branch: feat/droid-2         │    │
│  │  > claude session        │  > claude session             │    │
│  │  ready for input...      │  ready for input...           │    │
│  └──────────────────────────┴───────────────────────────────┘    │
│                                                                  │
│  Window: droids-3-4    Window: droids-5-6    ...                 │
└──────────────────────────────────────────────────────────────────┘
```

Each pane is a live Claude session. Switch panes with `Ctrl-b <arrow>` and windows with `Ctrl-b n`/`p`.

## Giving Droids Tasks

Switch to a pane and type directly:

**Droid 1 (left pane):** "Work on the authentication module in src/auth/. Implement OAuth2 login flow."

**Droid 2 (right pane):** "Write unit tests for all functions in src/utils/. Aim for 90% coverage."

**Droid 3 (next window):** "Review src/api/ for security vulnerabilities. Fix any issues you find."

## How Droids Avoid Conflicts

Droids coordinate through `factory-state.json` using helper scripts:

1. Before editing files, droids run `cf-claim.sh` to claim them
2. Other droids see the claim and don't touch those files
3. When done, droids run `cf-release.sh` to release their claims

## Commands Reference

| Command | What it does |
|---------|--------------|
| `./cf-start.sh` | Full startup — setup + launch tmux session |
| `./cf-setup.sh` | Just setup (no tmux) |
| `./cf-setup.sh -n 5` | Setup with 5 droids |
| `./cf-dispatch.sh` | Launch droids in tmux (2 per window) |
| `./cf-status.sh` | Check all droids and claims |
| `./cf-claim.sh 1 src/file.js` | Claim a file for droid 1 |
| `./cf-release.sh 1` | Release all claims for droid 1 |
| `./cf-teardown.sh` | Kill tmux + remove worktrees (keep branches) |
| `./cf-teardown.sh --full` | Kill tmux + remove everything |

## Tips

- **Give clear, scoped tasks** — "Work on src/auth/" is better than "improve the code"
- **Check status** — Run `./cf-status.sh` to see what each droid is working on
- **Review before merging** — Always check droid branches before merging to main
- **One area per droid** — Assign different modules to avoid conflicts

## Stopping

Detach from tmux with `Ctrl-b d`, then:

```bash
./cf-teardown.sh           # Kill tmux session + remove worktrees (keep branches)
# or
./cf-teardown.sh --full    # Kill tmux + remove everything
```

To reattach without tearing down:

```bash
tmux attach -t myapp-factory   # replace myapp with your PROJECT_NAME
```
