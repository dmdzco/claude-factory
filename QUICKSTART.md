# Donna AI Factory - Quick Start

## One Command to Start Everything

```bash
cd donna-factory
./start.sh
```

This will:
1. Create Git worktrees for each agent (if needed)
2. Build & start Docker containers
3. Set up FACTORY.md coordination file
4. Open **5 terminal tabs**, each with an interactive Claude session

---

## What You'll See

After running `./start.sh`, you'll have:

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

---

## Giving Agents Tasks

Just type in each tab! Example workflow:

**Tab 1 (Agent 1):**
```
You: "Work on the authentication module in src/auth/.
     Implement OAuth2 login flow."
```

**Tab 2 (Agent 2):**
```
You: "Write unit tests for all functions in src/utils/.
     Aim for 90% coverage."
```

**Tab 3 (Agent 3):**
```
You: "Review src/api/ for security vulnerabilities.
     Fix any issues you find."
```

And so on...

---

## How Agents Avoid Conflicts

Agents coordinate through `FACTORY.md`:

1. Before editing files, agents update FACTORY.md to "claim" them
2. Other agents see the claim and don't touch those files
3. When done, agents release their claims

The `CLAUDE.md` file in each workspace reminds agents of this protocol.

---

## Commands Reference

| Command | What it does |
|---------|--------------|
| `./start.sh` | **Full startup** - setup + open 5 Claude tabs |
| `./setup.sh` | Just setup (no tabs) |
| `./agent.sh 1` | Open Claude session for agent 1 |
| `./status.sh` | Check all agents & worktrees |
| `./teardown.sh` | Stop containers (keep worktrees) |
| `./teardown.sh --full` | Stop & remove everything |

---

## First Time? Do This:

```bash
# 1. Pre-build Docker image (slow, but only once)
./prebuild.sh

# 2. Start the factory
./start.sh
```

After the first build, `./start.sh` will be fast (~10 seconds).

---

## Tips

- **Give clear, scoped tasks** - "Work on src/auth/" is better than "improve the code"
- **Check FACTORY.md** - See what each agent is working on
- **Review before merging** - Always check agent branches before merging to main
- **One area per agent** - Assign different modules to avoid conflicts

---

## Stopping

Close the terminal tabs, then:

```bash
./teardown.sh           # Stop containers, keep worktrees
# or
./teardown.sh --full    # Remove everything
```
