---
name: plan
description: >
  Plan a feature, bug fix, or task from an issue-tracker ticket or a rough idea. Explores the
  affected codebases, writes a detailed spec, creates tasks after approval, and offers to dispatch
  workers. MUST be invoked when the user says "plan <TICKET-KEY>", "plan bd-XXXX", "plan: <idea>",
  "scope <TICKET-KEY>", or any variation of "plan" followed by a ticket key, task ID, or a
  description of work that needs scoping. This skill handles ALL planning -- do not manually
  explore code, write specs, or create tasks without invoking this skill first.
---

# Plan

You are performing inline planning for this workspace. Your job is to understand a ticket or rough idea, explore the affected codebases, write a detailed spec, and -- only after the human approves -- create tasks and dispatch workers.

---

## Task Tracking

This workspace uses **Beads (`bd`)** by default. If `bd` is not installed, use the `TASKS.md` markdown tracker (same structure, manual IDs like `T-001`). Check with `command -v bd`.

---

## Inputs

You will be invoked with one of:
- A ticket: `plan <TICKET-KEY>`
- A ticket + extra context: `plan <TICKET-KEY>: add GraphQL field for business hours`
- A rough idea (no ticket): `plan: explore adding Redis caching to <BACKEND_REPO>`
- A task ID that already exists: `plan bd-XXXX`

If invoked without a clear target, run `bd ready --json` and ask the human which unplanned item to tackle.

---

## Type Semantics

| Type | Purpose | Required fields |
|------|---------|----------------|
| `epic` | Planned body of work from a spec | Title, description, acceptance criteria |
| `feature` | Implementation work (code changes) | Title, description, acceptance criteria, design notes |
| `bug` | Defect found during review or implementation | Title, description, repro steps |
| `task` | Administrative/lightweight work (reviews, PRs, cleanup) | Title, short description |

## Label Routing

| Label | Agent | Picks up |
|-------|-------|----------|
| `role:architect` | Orchestrator / plan skill | Epics, planning |
| `role:coder` | worker (Forge) | Features, bugs |
| `role:reviewer` | reviewer (Sentinel) | Review tasks |

---

## Workflow

### Step 1: Gather context

If a ticket key is provided and an issue-tracker MCP is configured (Jira, Linear, etc.), fetch the ticket details (summary, description, acceptance criteria, linked issues). Issue tracker integration is **optional** -- if none is configured, work from the user's description.

If a task ID is provided, use `bd show <id> --json`.

```bash
cat workspace.json | jq '.repos[] | {name, path}'
```

### Step 2: Explore the codebase

- Navigate to each relevant sibling repo (`../repo-name`)
- Use search/read tools to understand the current implementation
- Identify all files that will change
- Check test patterns and lint tooling (see AGENTS.md "Per-Repo Commands")

### Step 3: Write the spec

```bash
cp specs/_template.md specs/<ticket-key-or-id>.md
```

The spec must include: Context (problem + ticket link if any + why now), Acceptance Criteria (testable checkboxes), Work Breakdown (one section per repo with specific file changes), Test Plan (exact commands), Rollout (migration/flags/order), and Open Questions.

For cross-repo work touching 3+ repos, flag as high-complexity and propose breaking into child tasks per repo.

### Step 4: Present to human (GATE)

Tell the human: where the spec is, scope summary (N files across M repos), estimated task count + dependency structure (show the planned DAG), and any open questions.

**Wait for the human to say "approved" or request changes before proceeding.**

### Step 4.5: Commit and push the spec (GATE)

Before creating tasks or dispatching workers, make the spec visible on `origin/main` so every task and PR can cross-link to it.

```bash
git add specs/<KEY>.md
git commit -m "docs: add spec for <short title> [<KEY>]"
git push origin main
```

Spec URL pattern to use in task descriptions and PR bodies:
```
https://github.com/<ORG>/<WORKSPACE_REPO>/blob/main/specs/<KEY>.md
```

Never dispatch workers against a spec that only exists locally.

### Step 5: Create tasks (after approval)

Create all tasks using direct `bd create` calls (or `TASKS.md` entries in the fallback).

#### 5a. Create the epic

```bash
cat <<'EOF' | bd create "<feature> [<TICKET-KEY>]" \
  --type epic \
  --priority 1 \
  --labels role:architect \
  --external-ref ticket-<TICKET-KEY> \
  --spec-id specs/<TICKET-KEY>.md \
  --description=- \
  --json
## Context
<what this epic achieves and why>

## Ticket
<TICKET-KEY> (omit if no tracker)

## Spec
https://github.com/<ORG>/<WORKSPACE_REPO>/blob/main/specs/<TICKET-KEY>.md
EOF

echo '- [ ] All child features implemented and merged
- [ ] All review tasks closed with PRs open' | bd update <epic-id> --acceptance=- --json
```

Save the epic ID -- all subsequent tasks are children of it.

#### 5b. Create feature tasks (one per implementation unit)

```bash
cat <<'EOF' | bd create "<implementation unit> in <repo>" \
  --type feature \
  --priority 2 \
  --labels role:coder,repo:<repo-name> \
  --parent <epic-id> \
  --external-ref ticket-<TICKET-KEY> \
  --design "<implementation approach / design notes>" \
  --description=- \
  --json
## Context
Repo: <repo-name>

## What
<what to build>

## Files to Change
- <path>
- <path>
EOF

echo '- [ ] <criterion>
- [ ] Tests pass
- [ ] Lint/format clean
- [ ] Branch pushed' | bd update <feature-id> --acceptance=- --json
```

Add inter-feature dependencies if sequential:
```bash
bd dep add <dependent-feature-id> <prerequisite-feature-id>
```

#### 5c. Create review tasks (one per feature)

```bash
cat <<'EOF' | bd create "Review: <repo> changes" \
  --type task \
  --priority 2 \
  --labels role:reviewer,repo:<repo-name> \
  --parent <epic-id> \
  --external-ref ticket-<TICKET-KEY> \
  --description=- \
  --json
## Review Plan
<what to validate, edge cases, quality gates, acceptance checks, PR requirements>
EOF

bd dep add <review-task-id> <feature-id>
```

#### 5d. Verify the DAG

```bash
bd show <epic-id> --json
bd show <review-task-id> --json
```

Resulting structure:
```
Epic: <feature> [<TICKET-KEY>]               role:architect
  ├── Feature: <impl in repo-a>              role:coder
  │     └── Task: Review repo-a changes      role:reviewer (depends_on Feature)
  ├── Feature: <impl in repo-b>              role:coder (depends_on repo-a Feature)
  │     └── Task: Review repo-b changes      role:reviewer (depends_on Feature)
```

### Step 6: Offer to dispatch workers

Ask: "Tasks created. Want me to dispatch workers?"

Analyze the dependency graph:
- **Independent features**: dispatch workers (Forge) in parallel
- **Sequential features**: dispatch the first, then the next after completion
- Parallelization is implied -- don't ask, just do it when the DAG allows

Dispatch a worker: `Work on <id>: "<feature title>"`. Dispatch a reviewer: `Review <id>: "<review task title>"`. Forge and Sentinel use their identities automatically as `--assignee`.

When workers complete, **automatically dispatch reviewers** on the corresponding review task. If the reviewer approves it opens the PR; if it finds issues it creates bug tasks (`role:coder`) that block the review task, a worker fixes them, then the reviewer re-runs automatically.

### Step 7: Report results

```
| Task | ID | PR |
|------|----|----|
| <feature> | bd-XXXX | https://github.com/<ORG>/<repo>/pull/NNN |
```

PR column is a plain URL (no markdown link syntax). No status column. Only include rows that produce PRs.

After reporting, close the epic if all children are closed:
```bash
bd close <epic-id> --reason "All features implemented, all PRs open" --json
```

---

## Rules

- Never create tasks before the human approves the spec
- Never start implementing -- only plan (workers implement)
- Every spec produces exactly one epic; every implementation unit is a feature under that epic
- Use the correct type: `epic`, `feature`, `task` (reviews/admin), `bug` (defects)
- Features require full descriptions, acceptance criteria, and design notes
- Review tasks require a targeted review plan
- Always label with `role:architect`, `role:coder`, or `role:reviewer`
- Always use `--json` for all bd commands; never use `bd edit`
- Issue-tracker linkage is optional -- when used, set `--external-ref ticket-<KEY>` on the epic and propagate to children
- After workers finish, dispatch reviewers automatically
- Use plain URLs in summary tables
- All agents must claim before starting and close when done -- no dangling tasks
