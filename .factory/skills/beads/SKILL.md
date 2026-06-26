---
name: beads
description: >
  Dolt-powered issue tracker for multi-session work with dependencies and persistent
  memory across conversation compaction. Use when work spans sessions, has blockers,
  or needs context recovery after compaction. Trigger with "create task", "what's
  ready", "track this work", "resume after compaction". Use whenever managing
  multi-session work, tracking dependencies, or recovering context.
---

# Beads — Persistent Task Memory for AI Agents

Graph-based issue tracker that survives conversation compaction. Provides persistent memory for multi-session work with complex dependencies.

> If `bd` is not installed in this workspace, use the `TASKS.md` markdown tracker instead (same epic -> feature -> review structure). Check with `command -v bd`.

## bd vs ephemeral TODOs

**Decision test**: "Will I need this context in 2 weeks?" YES = bd, NO = an ephemeral in-session TODO list.

| bd (persistent) | ephemeral TODO |
|-----------------|----------------|
| Multi-session, dependencies, compaction survival | Single-session linear tasks |
| Dolt-backed, syncable | Conversation-scoped |

## Prerequisites

```bash
bd --version   # requires v0.60.0+
```

- **bd CLI** installed and in PATH
- **Initialization**: `bd init` run once (humans do this, not agents)

## CLI Reference

- Run `bd memories` for persistent learned context (auto-loaded by the session hook).
- Run `bd <command> --help` for specific command usage.

Essential commands: `bd ready`, `bd create`, `bd show`, `bd update`, `bd close`, `bd dep add`.

## Session Protocol

1. `bd ready` — find unblocked work
2. `bd show <id>` — get full context
3. `bd update <id> --claim` — claim and start work atomically
4. Add notes as you work (critical for compaction survival)
5. `bd close <id> --reason "..."` — complete task

## Output

Append `--json` to any command for structured output. Use `bd show <id> --long` for extended metadata. Status icons: `○` open, `◐` in_progress, `●` blocked, `✓` closed, `❄` deferred.

## Error Handling

| Error | Fix |
|-------|-----|
| `database not found` | `bd init <name>` in workspace root |
| `not in a git repository` | `git init` first |
| `disk I/O error (522)` | Move `.beads/` off cloud-synced filesystem |
| Status updates lag | Use server mode: `bd dolt start` |
| `dolt is locked` | `pkill -9 -f dolt; rm -f ~/bd-data/.dolt/dolt.lock; bd status` |

## Examples

**Track a multi-session feature:**
```bash
bd create "OAuth integration" -t epic -p 1 --json
bd create "Token storage" -t task --deps blocks:<oauth-id> --json
bd ready --json
bd update <id> --claim --json
bd close <id> --reason "Implemented with refresh tokens" --json
```

**Recover after compaction:** `bd list --status in_progress --json` then `bd show <id> --long`.

**Discover work mid-task:** `bd create "Found bug" -t bug -p 1 --deps discovered-from:<current-id> --json`.

## Validation

If `bd --version` reports newer than `0.60.0`, run `bd <command> --help` for current CLI guidance.
