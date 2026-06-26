# Agent Playbook: <WORKSPACE_REPO>

This is a **generic, tool-agnostic orchestration workspace** for AI-driven development across multiple repositories (a backend service plus iOS and Android apps, by default). It contains planning conventions, implementation specs, task tracking, and agent configuration for working across repos.

It works with both **Factory.ai** and **Cursor**. Both tools read this `AGENTS.md`, so the playbook below is the single source of truth. The tool-specific wiring lives in `.factory/` and `.cursor/` (see `TOOLING.md`).

> First time here? Run `./scripts/init.sh` to pick your tool, then replace placeholders. See `README.md`.

---

## Workspace Layout

```
<parent-folder>/
├── <WORKSPACE_REPO>/      ← You are here (the orchestrator)
├── <BACKEND_REPO>/        ← Backend service
├── <IOS_REPO>/            ← iOS app
└── <ANDROID_REPO>/        ← Android app
```

All managed repos are declared in `workspace.json`. Read it to discover repo names, URLs, default branches, and relative paths.

```bash
cat workspace.json | jq '.repos[] | {name, path, default_branch}'
```

All repos are expected to be cloned as **siblings** of this workspace (see `README.md` -> "Clone everything into one parent folder"). Agents resolve repo paths via the `../<repo>` entries in `workspace.json`.

---

## Navigating Repos

For normal single-repo work, `cd` to the sibling:

```bash
cd ../<BACKEND_REPO>
```

For parallel work on a feature branch without switching the main checkout, use the worktree helper:

```bash
./scripts/worktree.sh <BACKEND_REPO> agent/<task-id>-add-auth
# Creates: ./worktrees/<BACKEND_REPO>/agent/<task-id>-add-auth/
cd ./worktrees/<BACKEND_REPO>/agent/<task-id>-add-auth/
```

The worktree is a full git checkout of the sibling repo on a new branch -- changes there are visible to `git` in `../<BACKEND_REPO>`.

---

## Task Tracking

This workspace uses **Beads (`bd`)** for task tracking by default. Do NOT create ad-hoc markdown TODO lists when `bd` is available.

**If `bd` is not installed**, fall back to the `TASKS.md` markdown tracker in this workspace. It mirrors the same epic -> feature -> review structure and the same role labels. Everything in the playbook below maps 1:1 onto `TASKS.md` items (use manual IDs like `T-001` in place of `bd-XXXX`).

Check availability with `command -v bd`.

### Key commands (Beads)

```bash
# Find ready (unblocked) work
bd ready --json

# Claim a task atomically before starting
bd update <id> --claim --json

# Create a new task
bd create "Title" --description="Details" -t feature|bug|task|epic|chore -p 0-4 --json

# Use stdin for descriptions with backticks or special characters
echo 'Description with `backticks`' | bd create "Title" --description=- --json

# Link discovered work to its source
bd create "Found issue" -p 2 --deps discovered-from:<id> --json

# Complete a task
bd close <id> --reason "Done" --json
```

### Priority reference
- `0` Critical (broken builds, data loss, security)
- `1` High (major features, important bugs)
- `2` Medium (default)
- `3` Low
- `4` Backlog

### Rules
- Always use `--json` flag for programmatic output
- Never use `bd edit` (opens interactive editor, agents cannot use it)
- Always use `bd update --claim` before starting work on a task
- File issues for remaining work before ending a session

---

## Implementation Specs

Specs live in `specs/` in this workspace repo. Before implementing a non-trivial feature, create a spec:

```bash
cp specs/_template.md specs/<TICKET-KEY-or-task-id>.md
# Fill in the spec, then implement from it
```

The plan skill can generate specs from a ticket or task ID automatically.

### Spec must be pushed before any PR that references it

PRs live in sibling repos; specs live here. For a reviewer to click through from a PR to the spec, the spec must exist on `origin/main` of this workspace **before** the PR is opened. Immediately after creating or updating a spec:

```bash
git add specs/<KEY>.md
git commit -m "docs: add spec for <short title> [<KEY>]"
git push origin main
```

Reference the spec in PR bodies and task descriptions with the absolute GitHub URL so the link is clickable:

```
https://github.com/<ORG>/<WORKSPACE_REPO>/blob/main/specs/<KEY>.md
```

Never reference a spec that only exists locally -- the link will 404 for everyone else.

---

## Branch Naming

```
agent/<task-id>-<short-description>
```

Examples:
- `agent/bd-a1b2-add-auth`
- `agent/T-014-fix-timeout`

---

## Creating PRs

PRs are opened by the reviewer agent (Sentinel) after code review passes. If opening manually:

- Always create PRs from within the target repo's worktree, not from this workspace root
- PR title MUST follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/). Include the ticket key when an issue tracker is in use: `<type>: description [<TICKET-KEY>]`
  - Types: `feat`, `fix`, `chore`, `refactor`, `test`, `docs`, `perf`, `ci`, `build`, `style`
- **PR body MUST follow the target repo's PR template** (see below), and MUST include the ticket link (if any), task ID(s), and a link to the spec

### Always follow the target repo's PR template

Before running `gh pr create`, check the target repo for a PR template and use its headings verbatim as the body skeleton. Fill each section with content relevant to the change; do not invent new top-level sections. Search paths (first hit wins):

```bash
ls .github/pull_request_template.md \
   .github/PULL_REQUEST_TEMPLATE.md \
   PULL_REQUEST_TEMPLATE.md \
   .github/PULL_REQUEST_TEMPLATE/ 2>/dev/null
```

If `.github/PULL_REQUEST_TEMPLATE/` is a directory, each `.md` file inside is a named template; pick the one matching your change type (e.g. `bugfix.md`, `feature.md`) or ask the human.

If no template exists, use the generic body shown below. Either way, the body MUST include:
- A ticket link (when applicable): `[<TICKET-KEY>](<TRACKER_BASE_URL>/browse/<TICKET-KEY>)`
- Task IDs (feature + review task)
- A clickable spec link on `origin/main` of this workspace: `https://github.com/<ORG>/<WORKSPACE_REPO>/blob/main/specs/<KEY>.md`

```bash
cd ./worktrees/<BACKEND_REPO>/agent/<task-id>-desc/

# Fallback body only when no PR template exists in the target repo:
gh pr create \
  --title "feat: add auth [<TICKET-KEY>]" \
  --body "## Summary
What this PR does.

## Ticket
[<TICKET-KEY>](<TRACKER_BASE_URL>/browse/<TICKET-KEY>)

## Spec
https://github.com/<ORG>/<WORKSPACE_REPO>/blob/main/specs/<TICKET-KEY>.md

## Tasks
- <feature task id>
- <review task id>" \
  --base main
```

> Issue tracker linkage is **optional**. If you don't use one, omit the ticket sections and drive work from the spec + task ID alone.

---

## Cross-Repo Work

When a feature spans multiple repos:

1. Create an epic: `bd create "Epic: ..." -t epic -p 1 --labels role:architect --json`
2. Create child feature tasks per repo: `bd create "Add X to repo-a" -t feature --labels role:coder --parent <epic-id> --json`
3. Create review tasks per feature: `bd create "Review: repo-a changes" -t task --labels role:reviewer --parent <epic-id> --json` then `bd dep add <review-task> <feature>`
4. Add inter-feature dependencies if sequential: `bd dep add <gql-feature> <domain-feature>`
5. Use worktrees for each repo to work in parallel if needed
6. Create one PR per repo, all referencing the epic

---

## Per-Repo Commands

Run these from within the repo directory or its worktree. Always run before marking a task done.

**Replace the placeholders below with your project's real commands.** These are starting points by platform.

| Repo | Test | Lint / Format check | Build |
|------|------|---------------------|-------|
| `<BACKEND_REPO>` | `<test command>` | `<lint command>` | `<build command>` |
| `<IOS_REPO>` | `xcodebuild ... test` (Xcode) | `swiftlint` | `xcodebuild ... build` |
| `<ANDROID_REPO>` | `./gradlew test` | `ktlint` (or `./gradlew ktlintCheck`) | `./gradlew assemble` |

Example backend command sets (pick what matches your stack and put it in the table above):

```bash
# .NET (REST)
dotnet build
dotnet test
dotnet format --verify-no-changes

# Node / TypeScript (GraphQL or REST)
npm ci
npm run lint
npm test
npm run build
```

---

## Agent Workflow

This workspace uses an inline planning skill and two specialized worker/reviewer agents.

### Roles

| Role | Invoked by | Does |
|------|------------|------|
| `plan` (skill) | Human: "plan <TICKET-KEY>" or "plan: <idea>" | Explores repos, writes spec, creates tasks after approval, dispatches workers |
| worker — **Forge** | Orchestrator (after plan approval) | Implements in a worktree, runs quality gates, pushes branch |
| reviewer — **Sentinel** | Orchestrator (automatically after Forge completes) | Reviews code, creates fix tasks or opens PR |

> On **Factory.ai**, Forge and Sentinel are droids defined in `.factory/droids/`. On **Cursor**, they are skills in `.cursor/skills/` dispatched as Task subagents. The behavior is identical; only the dispatch mechanism differs. See `TOOLING.md`.

### Orchestration Flow

```
Human: "plan <TICKET-KEY>"
  → plan skill runs inline (explores code, writes spec)
  → Human approves spec
  → Epic + feature tasks + review tasks created from spec
  → Forge dispatched on features (parallel when DAG allows)
  → Sentinel dispatched on review tasks when features complete
  → If issues: bug tasks created → Forge fixes → Sentinel re-reviews
  → If clean: PR opened
  → Summary table presented to human
```

Key principles:
- **Planning runs inline** in the orchestration session (not as a subagent) so the human can interact naturally
- **Parallelization is implied** -- independent features in the DAG are dispatched simultaneously
- **Sentinel auto-dispatches** -- when a feature is done, its review task unblocks and Sentinel is dispatched
- **Fix loops are autonomous** -- Sentinel creates bug tasks, Forge fixes them, Sentinel re-reviews, all without human intervention

### Task Type Semantics

| Type | Purpose | Required fields | Label |
|------|---------|----------------|-------|
| `epic` | Planned body of work from a spec | Title, description, acceptance criteria | `role:architect` |
| `feature` | Implementation work (code changes) | Title, description, acceptance criteria, design notes | `role:coder` |
| `bug` | Defect found during review or implementation | Title, description, repro steps (steps/expected/actual) | `role:coder` |
| `task` | Admin/lightweight work (reviews, PRs, cleanup) | Title, short description | `role:reviewer` (for reviews) |

### Label Routing

Every task gets a `role:` label indicating which agent picks it up:

- `role:architect` -- orchestrator / plan skill (epics, planning)
- `role:coder` -- Forge worker (features, bugs)
- `role:reviewer` -- Sentinel reviewer (review tasks)

### Discipline

Non-negotiable rules for all agents:

1. **Always claim before starting**: `bd update <id> --claim --json`
2. **Always close when done**: `bd close <id> --reason "..." --json`
3. **No dangling tasks**: every task created must eventually be closed or deferred
4. **No orphan work**: every feature/bug/task must be a child of an epic

(With the `TASKS.md` fallback, "claim" = mark `[~]`, "close" = mark `[x]`, and parentage is expressed by nesting under the epic.)

### Structure produced by the planner

```
Epic: <feature> [<TICKET-KEY>]            role:architect
  ├── Feature: <impl in repo-a>           role:coder
  │     ├── Task: Review <repo-a changes> role:reviewer (depends_on Feature)
  │     └── Bug: <issue found in review>  role:coder (created by reviewer if issues found)
  ├── Feature: <impl in repo-b>           role:coder (depends_on repo-a Feature if sequential)
  │     └── Task: Review <repo-b changes> role:reviewer (depends_on Feature)
  ...
```

### Summary Table Format

When presenting results, use this format:

```
| Task | ID | PR |
|------|----|----|
| iOS distributed tracing | bd-6ux | https://github.com/<ORG>/<IOS_REPO>/pull/266 |
| Backend propagation | bd-9hk | https://github.com/<ORG>/<BACKEND_REPO>/pull/359 |
```

- PR column: plain URL only (no markdown link syntax -- it doesn't render inline)
- No status column: an open PR implies reviewer approval
- Only include rows for tasks that produce PRs

### Key invariants

- A feature is NOT done until its branch is pushed and the review task is unblocked
- A review task is NOT done until a PR is open (and linked to the ticket, if one is used)
- Every PR title must follow Conventional Commits (and contain the ticket key when applicable)
- Forge creates worktrees; Sentinel reuses them; humans clean them up after merge
- Every agent must claim before starting and close when done -- no dangling tasks

---

## Session Completion ("Landing the Plane")

Before ending a session:

1. File tasks for any remaining or discovered work
2. Run each modified repo's tests and lint
3. Update task statuses (close finished, update in-progress)
4. Push all branches: `git push` from each modified repo/worktree
5. Verify: `./scripts/status.sh` should show no uncommitted changes

Work is NOT complete until branches are pushed and PRs are open. Never leave work stranded locally.

---

## Available Scripts

| Script | Usage | Description |
|--------|-------|-------------|
| `init.sh` | `./scripts/init.sh` | First-run: pick tool (Factory/Cursor/both), replace placeholders |
| `setup.sh` | `./scripts/setup.sh` | Bootstrap: clone repos, install bd (optional) |
| `sync.sh` | `./scripts/sync.sh` | Pull latest on all repos |
| `status.sh` | `./scripts/status.sh` | Git status across all repos |
| `worktree.sh` | `./scripts/worktree.sh <repo> <branch>` | Create/attach worktree |
| `reset.sh` | `./scripts/reset.sh` | Reset clean repos to their default branch |

---

## Worktree Cleanup

When done with a worktree:

```bash
git -C ../<BACKEND_REPO> worktree remove ./worktrees/<BACKEND_REPO>/agent/<task-id>-desc/
git -C ../<BACKEND_REPO> branch -d agent/<task-id>-desc   # after PR merged
```

---

## Response Style

- Never emit a message that only announces a tool call. Call the tool.
- Never narrate readiness ("I now have the complete picture", "Let me present the spec").
- Never editorialize tool results ("Good,", "Excellent", "This is interesting").
- Never echo tool output the user already saw.
- Reports list outcomes (PR URL, task status), not process steps ("Actions taken: 1. Claimed...").
- One-line results get one line, not headers and bullets.
- No closing pleasantries.
