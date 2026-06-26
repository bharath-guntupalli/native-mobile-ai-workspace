---
name: plan
description: >
  Plan a feature, bug fix, or task from an issue-tracker ticket or a rough idea, then orchestrate
  workers and reviewers. Use when the user says "plan <TICKET-KEY>", "plan bd-XXXX", "plan: <idea>",
  or "scope <TICKET-KEY>". Explores the affected repos, writes a spec, creates tasks after approval,
  and dispatches the worker/reviewer skills via the Task tool.
---

# Plan (Cursor)

Inline planning for this multi-repo workspace. Read `AGENTS.md` for the shared playbook (task types, label routing, spec/PR rules). This skill covers the Cursor-specific flow.

## Task tracking
Use Beads (`bd`) when installed; otherwise `TASKS.md` (manual IDs like `T-001`). Check with `command -v bd`.

## Inputs
- `plan <TICKET-KEY>` / `plan <TICKET-KEY>: <context>` / `plan: <idea>` / `plan bd-XXXX`.
- If unclear, run `bd ready --json` and ask which item to tackle.

## Workflow

1. **Gather context.** If a ticket key is given and an issue-tracker MCP is configured (Jira, Linear, etc.), fetch its details. Tracker integration is optional — otherwise use the user's description. Read `workspace.json` for repos.
2. **Explore** each relevant sibling repo (`../<repo>`) with search/read tools. Identify files to change and the per-repo test/lint commands (see `AGENTS.md`). Prefer launching parallel `explore` subagents via the Task tool for breadth.
3. **Write the spec**: `cp specs/_template.md specs/<KEY>.md` and fill Context, Acceptance Criteria, Work Breakdown (per repo), Test Plan, Rollout, Open Questions.
4. **Present to the human (GATE).** Show the spec path, scope (N files across M repos), the planned task DAG, and open questions. Wait for explicit approval before creating tasks.
5. **Push the spec (GATE).** `git add specs/<KEY>.md && git commit -m "docs: add spec [<KEY>]" && git push origin main` so the PR can link to `https://github.com/<ORG>/<WORKSPACE_REPO>/blob/main/specs/<KEY>.md`.
6. **Create tasks** (after approval): one epic (`role:architect`), one feature per implementation unit (`role:coder`, `repo:<name>`), one review task per feature (`role:reviewer`, `depends_on` its feature). Wire inter-feature deps for sequential work. See `AGENTS.md` and the `.factory/skills/plan/SKILL.md` for exact `bd create` invocations (identical commands).
7. **Dispatch via the Task tool.** Parallelization is implied:
   - For each ready feature, launch a worker: `Task(subagent_type="generalPurpose", description="Work on <id>", prompt="Read .cursor/skills/worker/SKILL.md and implement <id>: <title>")`. Launch independent features in parallel (multiple Task calls in one message).
   - When a feature completes, automatically launch a reviewer on its review task: `Task(..., prompt="Read .cursor/skills/reviewer/SKILL.md and review <review-id>")`.
   - If the reviewer files bug tasks, dispatch a worker to fix them, then re-dispatch the reviewer. Loop until clean, then it opens the PR.
8. **Report** a summary table (plain PR URLs, no status column, only rows that produced PRs). Close the epic when all children are closed.

## Rules
- Never create tasks before the human approves the spec. Never implement here — only plan and dispatch.
- Every spec produces exactly one epic; every implementation unit is a feature under it.
- Always `--json` on bd commands; never `bd edit`. Issue-tracker linkage is optional (`--external-ref ticket-<KEY>` when used).
