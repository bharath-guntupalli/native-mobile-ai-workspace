# Workspace: Human Workflow Guide

A practical guide for planning and shipping work using the AI agent orchestration system in this workspace. Works with both Factory.ai and Cursor (see `TOOLING.md`).

---

## What this system does

You plan work inline using the `plan` skill, which explores codebases, writes specs, and creates tasks after your approval. Once approved, workers (Forge) are dispatched in parallel when possible, and reviewers (Sentinel) auto-dispatch when workers finish. Every PR follows Conventional Commits and links to a spec (and a ticket, if you use an issue tracker). You stay in the loop at the planning gate and can check in at any point.

```
You: "plan <TICKET-KEY>"  (or "plan: <rough idea>")
  └── plan skill (inline)        -- gathers context, explores repos, writes spec, waits for your approval
        └── Forge (parallel)       -- implements in worktrees, pushes branches
              └── Sentinel (auto)  -- reviews code, creates fix tasks or opens PRs
                    └── Forge (auto fix loop if needed)
```

---

## One-time setup

### Prerequisites

```bash
brew install gh jq        # required
brew install beads        # recommended (task tracker); falls back to TASKS.md if absent
gh auth login
```

### First run

```bash
./scripts/init.sh         # pick Factory / Cursor / both, replace placeholders
./scripts/setup.sh        # clone sibling repos, init beads (if installed)
```

### Verify setup

```bash
command -v bd && bd status   # if using beads
./scripts/status.sh          # check all repos are cloned and clean
```

---

## workspace.json

`workspace.json` is the registry of all repos managed by this workspace. Agents, scripts, and the plan skill all read it to discover repos, their locations, and default branches.

```json
{
  "org": "<ORG>",
  "repos": [
    {
      "name": "<BACKEND_REPO>",
      "url": "git@github.com:<ORG>/<BACKEND_REPO>.git",
      "default_branch": "main",
      "path": "../<BACKEND_REPO>",
      "description": "Backend service"
    }
  ]
}
```

### Field reference

| Field | Purpose |
|-------|---------|
| `org` | GitHub organization or personal handle. Used by scripts and PR creation. |
| `name` | Short repo name. Used as the key in worktree paths and `repo:` labels. |
| `url` | Git clone URL. Used by `setup.sh` to clone missing repos. |
| `default_branch` | Branch that PRs target. Not always `main`. |
| `path` | Relative path from the workspace root to the repo checkout. Always a sibling directory (`../repo-name`). |
| `description` | Human-readable summary. Shown in status output and used by agents for context. |

### Expectations

- **All repos must be cloned as siblings.** The workspace expects repos at the paths declared in `workspace.json`. Run `./scripts/setup.sh` to clone any missing ones.
- **Keep it up to date.** If a new repo enters scope, add it here. Scripts like `sync.sh` and `status.sh` iterate over this file.
- **Agents rely on it.** The plan skill reads `workspace.json` to understand which repos exist and where they live.
- **`path` is relative to the workspace root.** Use `../` to reference sibling directories. Don't use absolute paths.
- **`default_branch` matters for PRs.** Workers and reviewers use this to determine the base branch when creating PRs.

### Quick inspection

```bash
cat workspace.json | jq '.repos[] | {name, path, default_branch}'
./scripts/status.sh
```

---

## Core commands cheat sheet

```bash
# See work ready for agents (unblocked)        [beads]
bd ready

# See the task graph for an epic                [beads]
bd show <epic-id> --json

# Check active worktrees
git -C ../<BACKEND_REPO> worktree list

# Workspace health
./scripts/status.sh
```

(Without beads, track the same information in `TASKS.md`.)

---

## Workflow Examples

### Example 1: Ship a feature from a ticket

The most common flow: take a ticket (or idea), plan it, and dispatch agents to implement.

> "plan <TICKET-KEY>"

Or with extra context:

> "plan <TICKET-KEY>: add support for business hours to the backend API"

The plan skill runs inline and will:
- Gather the ticket details (via an MCP integration if configured) or use your description
- Explore the codebase
- Write `specs/<TICKET-KEY>.md`
- Present you with a summary and list of proposed tasks

Then review the spec, ask questions, request changes, or say:

> "Approved. Create the tasks and dispatch workers."

The plan skill then creates the task chain (epic -> features -> review tasks), dispatches Forge on features in parallel (when the DAG allows), auto-dispatches Sentinel when features finish, and reports back with a summary table of PRs.

---

### Example 2: Cross-repo feature (multiple PRs, one ticket)

When a feature touches multiple repos (e.g., adding a field that requires changes in both the backend and the iOS app):

> "plan <TICKET-KEY>: expose inventory count via the API. This will need changes in both <BACKEND_REPO> (add the data query) and <IOS_REPO> (display the count)."

The planner creates an epic with feature tasks per repo and review tasks:

```
Epic: inventory count [<TICKET-KEY>]                  role:architect
  ├── Feature: Add inventory query [<BACKEND_REPO>]   role:coder
  │     └── Task: Review backend changes               role:reviewer (depends_on Feature)
  ├── Feature: Display count in iOS [<IOS_REPO>]       role:coder (depends_on backend Feature)
  │     └── Task: Review iOS changes                    role:reviewer (depends_on Feature)
```

Forge is dispatched in parallel on independent features. Each gets its own worktree. When a feature completes, its review task unblocks and Sentinel is dispatched automatically. Two separate PRs get opened, both referencing the ticket.

---

### Example 3: Quick bug fix

For small, well-understood bugs you can skip the full planner and just describe the problem.

> "<TICKET-KEY>: search returns 500 when query is empty. It's a missing nil guard in the search controller in <BACKEND_REPO>. Create the tasks and fix it."

The agent will create the epic, bug task, and review task with proper labels and dependencies, dispatch Forge to implement the fix, and auto-dispatch Sentinel to review and open the PR.

---

### Example 4: Exploratory planning (no ticket yet)

When you want to understand scope before committing to a ticket:

> "I want to explore adding response caching to the backend API. Give me a work breakdown and rough estimate."

The planner explores the codebase and produces `specs/caching-exploration.md` with affected components, proposed approach, risk areas, and a rough breakdown into tasks.

---

### Example 5: Checking in on in-progress work

Ask the agent instead of running raw commands:

> "What's the status of the <TICKET-KEY> epic?"
> "What tasks are ready for work?"
> "Show me the active worktrees."

If you prefer raw output:

```bash
bd ready --json                              # unblocked, unclaimed work (beads)
bd show <id> --json                          # full task details + deps (beads)
git -C ../<BACKEND_REPO> worktree list
```

---

## Agent quick reference

| Role | Agent Name | Label | When invoked | What it does |
|------|-----------|-------|-------------|--------------|
| Planner | (inline skill) | `role:architect` | Human: "plan ..." | Gathers context, explores repos, writes spec, creates tasks, dispatches workers |
| Worker | **Forge** | `role:coder` | Auto: after plan approval | Picks up features/bugs, implements in worktree, runs tests, pushes branch |
| Reviewer | **Sentinel** | `role:reviewer` | Auto: after feature completes | Picks up review tasks, reviews code, creates bug tasks or opens PR |

**Usage:**
- "plan ..." → plan skill runs inline, handles the full flow
- Forge and Sentinel dispatch automatically -- you don't need to invoke them manually
- For ad-hoc work: "work on <id>" or "review <id>" still works
- All agents claim before starting and close when done

---

## Worktree management

Worktrees are created per-task under `./worktrees/<repo>/<branch>/`. They persist until you manually clean them up.

```bash
# List worktrees for a repo
git -C ../<BACKEND_REPO> worktree list

# Remove after PR is merged
git -C ../<BACKEND_REPO> worktree remove \
  ./worktrees/<BACKEND_REPO>/agent/<task-id>-desc/

# Delete the remote branch after merge
git -C ../<BACKEND_REPO> push origin --delete agent/<task-id>-desc
```

---

## Issue tracker integration (optional)

An issue tracker (Jira, Linear, GitHub Issues, etc.) is **optional**. If you configure one as an MCP integration:

- When you say "plan <TICKET-KEY>", the plan skill can fetch the ticket details on-the-fly
- Tasks are linked to the ticket via `--external-ref` (beads) or `ref:<TICKET-KEY>` (TASKS.md)
- PRs include the ticket key in the title and body

If you don't use a tracker, drive everything from a description plus the spec and task IDs.

---

## Troubleshooting

**Task is blocked and shouldn't be (beads):**
```bash
bd show <id> --json   # check deps
bd dep list <id>      # see what's blocking it
```

**Worktree is in a bad state:**
```bash
cd ./worktrees/<repo>/agent/<branch>/
git status
git stash   # or reset if needed
```

**Beads commands fail ("no database selected" or "dolt is locked"):**
```bash
pkill -9 -f dolt; rm -f ~/bd-data/.dolt/dolt.lock; bd status
```

**Need to start over on a task (beads):**
```bash
bd reopen <id> --json
bd update <id> --notes "Restarting: <reason>" --json
```
