# Claude Factory - Quick Start

## Start Everything

```bash
cd claude-factory
./cf-start.sh
```

This will:
1. Create Git worktrees for each droid (if needed)
2. Initialize coordination state
3. Open terminal tabs, each with an interactive Claude session

## What You'll See

After running `./cf-start.sh`, you'll have terminal tabs, one per droid:

```
┌─────────────────────────────────────────────────────────────────┐
│  Tab 1: Droid 1        │  Tab 2: Droid 2        │  Tab 3: ...  │
│  Branch: feat/droid-1  │  Branch: feat/droid-2  │              │
│  ─────────────────     │  ─────────────────     │              │
│  > claude session      │  > claude session      │              │
│  ready for input...    │  ready for input...    │              │
└─────────────────────────────────────────────────────────────────┘
```

Each tab is a live Claude session. Type directly to give that droid tasks.

## Giving Droids Tasks

Just type in each tab:

**Tab 1 (Droid 1):** "Work on the authentication module in src/auth/. Implement OAuth2 login flow."

**Tab 2 (Droid 2):** "Write unit tests for all functions in src/utils/. Aim for 90% coverage."

**Tab 3 (Droid 3):** "Review src/api/ for security vulnerabilities. Fix any issues you find."

## How Droids Avoid Conflicts

Droids coordinate through `factory-state.json` using helper scripts:

1. Before editing files, droids run `cf-claim.sh` to claim them
2. Other droids see the claim and don't touch those files
3. When done, droids run `cf-release.sh` to release their claims

## Commands Reference

| Command | What it does |
|---------|--------------|
| `./cf-start.sh` | Full startup — setup + open Claude tabs |
| `./cf-setup.sh` | Just setup (no tabs) |
| `./cf-setup.sh -n 5` | Setup with 5 droids |
| `./cf-dispatch.sh` | Open droid terminal tabs |
| `./cf-status.sh` | Check all droids and claims |
| `./cf-claim.sh 1 src/file.js` | Claim a file for droid 1 |
| `./cf-release.sh 1` | Release all claims for droid 1 |
| `./cf-teardown.sh` | Remove worktrees (keep branches) |
| `./cf-teardown.sh --full` | Remove everything |

## Tips

- **Give clear, scoped tasks** — "Work on src/auth/" is better than "improve the code"
- **Check status** — Run `./cf-status.sh` to see what each droid is working on
- **Review before merging** — Always check droid branches before merging to main
- **One area per droid** — Assign different modules to avoid conflicts

## Stopping

Close the terminal tabs, then:

```bash
./cf-teardown.sh           # Remove worktrees, keep branches
# or
./cf-teardown.sh --full    # Remove everything
```
