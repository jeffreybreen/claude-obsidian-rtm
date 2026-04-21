# claude-obsidian-rtm

A Claude Code slash command (`/rtm`) that syncs tasks tagged `#todo` from an Obsidian vault to Remember The Milk.

## What it does

Two phases in one pass:

- **Push:** Finds `- [ ] ... #todo` lines without `[rtm_task_id::...]`, creates them in RTM under a list matching the vault name, and writes the RTM task\_id back onto the line.
- **Echo:** Finds `- [ ] ... #todo [rtm_task_id::...]` lines (unchecked, with ID), checks RTM for completion status, and marks them `- [x]` in Obsidian if done.

## Prerequisites

- RTM Pro account
- RTM's official hosted MCP server registered with Claude Code:
  ```bash
  claude mcp add --transport http rememberthemilk https://www.rememberthemilk.com/mcp
  ```
  Then `/mcp` in Claude Code, sign in via browser. OAuth token is managed by the MCP client automatically.

## Install

```bash
git clone <repo-url>
cd claude-obsidian-rtm
./scripts/deploy-claude.sh
```

This copies `claude/commands/rtm.md` into `~/.claude/commands/` (global scope). Then use `/rtm` in any vault.

Alternatively, copy `claude/commands/rtm.md` into a specific vault's `.claude/commands/` for project-scoped use.

## Conventions

- `#todo` on a checkbox line = real task (vs. checklist item).
- `[rtm_task_id::12345678]` = Dataview inline field tracking sync state.
- Vault name = RTM list name (derived from working directory, no config needed).
- Tasks born in RTM stay in RTM -- no import of foreign tasks.
- Completion echo is one-way: RTM to Obsidian, only for tasks that originated in Obsidian.

## How vault-to-list mapping works

The command uses the vault name (current working directory name) as the RTM list name. No configuration. If the list doesn't exist in RTM, the command creates it.
