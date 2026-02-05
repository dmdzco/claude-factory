# Claude Factory - Quick Start

## Start Everything

```bash
cd claude-factory
./start.sh
```

This will:
1. Create Git worktrees for each agent (if needed)
2. Initialize coordination state
3. Open terminal tabs, each with an interactive Claude session

## What You'll See

After running `./start.sh`, you'll have terminal tabs, one per agent:

```
┌─────────────────────────────────────────────────────────────────┐
│  Tab 1: Agent 1        │  Tab 2: Agent 2        │  Tab 3: ...  │
│  Branch: feat/agent-1  │  Branch: feat/agent-2  │              │
│  ─────────────────     │  ─────────────────     │              │
│  > claude session      │  > claude session      │              │
│  ready for input...    │  ready for input...    │              │
└─────────────────────────────────────────────────────────────────┘
```

Each tab is a live Claude session. Type directly to give that agent tasks.

## Giving Agents Tasks

Just type in each tab:

**Tab 1 (Agent 1):** "Work on the authentication module in src/auth/. Implement OAuth2 login flow."

**Tab 2 (Agent 2):** "Write unit tests for all functions in src/utils/. Aim for 90% coverage."

**Tab 3 (Agent 3):** "Review src/api/ for security vulnerabilities. Fix any issues you find."

## How Agents Avoid Conflicts

Agents coordinate through `factory-state.json` using helper scripts:

1. Before editing files, agents run `claim.sh` to claim them
2. Other agents see the claim and don't touch those files
3. When done, agents run `release.sh` to release their claims

## Commands Reference

| Command | What it does |
|---------|--------------|
| `./start.sh` | Full startup — setup + open Claude tabs |
| `./setup.sh` | Just setup (no tabs) |
| `./setup.sh -n 5` | Setup with 5 agents |
| `./dispatch.sh` | Open agent terminal tabs |
| `./status.sh` | Check all agents and claims |
| `./claim.sh 1 src/file.js` | Claim a file for agent 1 |
| `./release.sh 1` | Release all claims for agent 1 |
| `./teardown.sh` | Remove worktrees (keep branches) |
| `./teardown.sh --full` | Remove everything |

## Tips

- **Give clear, scoped tasks** — "Work on src/auth/" is better than "improve the code"
- **Check status** — Run `./status.sh` to see what each agent is working on
- **Review before merging** — Always check agent branches before merging to main
- **One area per agent** — Assign different modules to avoid conflicts

## Stopping

Close the terminal tabs, then:

```bash
./teardown.sh           # Remove worktrees, keep branches
# or
./teardown.sh --full    # Remove everything
```
