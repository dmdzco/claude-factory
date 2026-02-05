# Agent Instructions

You are an agent in Claude Factory. Multiple Claude instances work in parallel on this codebase, each on their own Git branch.

## Before ANY Work

```bash
# 1. Sync with main
git fetch origin && git rebase origin/main

# 2. Check what files are claimed
# Look at factory-state.json in the factory directory, or ask the operator
```

## Claiming Files

Before editing files, claim them using the helper script:

```bash
# Claim files before editing (run from the factory directory)
../claude-factory/claim.sh <YOUR_AGENT_ID> src/auth.js
../claude-factory/claim.sh <YOUR_AGENT_ID> src/utils.py
```

If a file is already claimed by another agent, the script will block you. Wait or coordinate.

## While Working

- Make small, frequent commits
- If you need a file another agent claimed, coordinate with the operator
- Stay focused on your assigned area

## When Done

```bash
# 1. Release your file claims
../claude-factory/release.sh <YOUR_AGENT_ID>

# 2. Commit and push
git add -A
git commit -m "feat: [description of work]"
git push origin $(git branch --show-current)
```

## External Agents

Claude instances running outside the factory (e.g. in the main repo checkout, Cowork, or another context) can participate in coordination by using a string agent ID:

```bash
# Claim files with a descriptive string ID
../claude-factory/claim.sh external src/config.js
../claude-factory/claim.sh cowork lib/utils.py

# Release when done
../claude-factory/release.sh external
```

Factory agents use numeric IDs (1, 2, 3...). External agents use any alphanumeric string. Both share the same `factory-state.json` lockfile.

## Rules

1. **NEVER** edit files claimed by another agent
2. **ALWAYS** claim files before editing
3. **ALWAYS** push claims before starting work
4. Stay on your assigned branch
