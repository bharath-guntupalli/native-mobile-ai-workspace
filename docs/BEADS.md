# What is Beads? (and how to get started)

If you've never heard of **Beads**, start here. This doc explains what it is, why this workspace uses it, and the handful of things you actually need to know to be productive. You do **not** need to be a Beads expert to use this workspace.

> TL;DR: Beads (`bd`) is a small command-line **task tracker for AI agents**. It remembers work, dependencies, and progress across sessions so the agent doesn't lose the plot. It's **recommended but optional** — if you don't install it, this workspace falls back to a plain `TASKS.md` file.

---

## The 30-second version

When you ask an AI agent to do a big multi-step job ("build feature X across the backend and the iOS app"), two things tend to go wrong:

1. The agent forgets what it was doing after the conversation gets long (context gets compacted/trimmed).
2. There's no shared, durable list of "what's done, what's next, what's blocked."

Beads fixes both. It's a tiny database of **tasks** (it calls them *issues*) that lives in your repo. Each task has a type, a status, and can **depend on** other tasks. The agent reads it at the start of every session to remember where things stand, updates it as it works, and closes tasks when done.

Think of it as a **to-do list with a memory and a dependency graph**, designed for agents instead of humans.

---

## Why this workspace uses it

This workspace orchestrates work across several repos using three roles — a **planner**, a **worker** (Forge), and a **reviewer** (Sentinel). They hand work off to each other:

```
Plan → creates tasks → Worker implements → Reviewer reviews → PR opened
```

That handoff needs a shared source of truth that survives across sessions and agent dispatches. That's Beads. Every task carries a `role:` label so the right agent picks it up, and dependencies make sure a review only starts after its feature is built.

If this sounds heavy: it isn't. For day-to-day use you'll mostly just say things like *"plan CARS-123"* or *"what's ready?"* and let the agent run the `bd` commands for you.

---

## The mental model (5 concepts)

| Concept | What it means | Example |
|---|---|---|
| **Task / issue** | A unit of work with an ID like `bd-a1b2` | "Add hours endpoint to backend" |
| **Type** | What kind of work it is | `epic`, `feature`, `bug`, `task` |
| **Status** | Where it is in its life | `open` → `in_progress` → `closed` (also `blocked`, `deferred`) |
| **Dependency** | "This can't start until that's done" | Review task *depends on* its feature |
| **Label** | A tag; here we use `role:` to route work | `role:coder`, `role:reviewer` |

### Types, in this workspace

- **epic** — the whole body of work for one spec (the parent of everything else)
- **feature** — a concrete chunk of implementation (code changes)
- **bug** — a defect found during work or review
- **task** — lightweight/admin work, mainly **reviews**

### The shape work takes here

```
Epic: Add business hours
  ├── Feature: backend hours endpoint      (role:coder)
  │     └── Task: review backend changes   (role:reviewer, depends on the feature)
  └── Feature: show hours in iOS app       (role:coder, depends on backend feature)
        └── Task: review iOS changes        (role:reviewer, depends on the feature)
```

You don't build this by hand — the **plan** skill creates it for you after you approve a spec.

---

## Getting started

### 1. Install (recommended)

```bash
# macOS
brew install beads

# or via npm
npm install -g @beads/bd

# verify
bd --version        # needs v0.60.0+
```

If you skip this, see ["Don't want Beads?"](#dont-want-beads) below — everything still works.

### 2. Initialize it (once per workspace)

`./scripts/setup.sh` does this automatically. To do it by hand:

```bash
bd init
```

This creates a `.beads/` folder (already git-ignored where appropriate) that holds the task database.

### 3. The only commands you need to know

You can drive everything by talking to the agent, but here are the human-friendly basics:

```bash
bd ready            # what work is unblocked and ready to pick up?
bd list             # show all open tasks
bd show <id>        # full detail on one task (deps, notes, status)
bd update <id> --claim   # mark a task as "I'm working on this"
bd close <id> --reason "done"   # finish a task
```

Tip: add `--json` to any command for machine-readable output (agents always do this).

### 4. Day-to-day, you'll mostly just say:

- *"plan CARS-123"* — plan a ticket into tasks (the agent writes a spec first and waits for your OK)
- *"what's ready?"* — the agent runs `bd ready` and summarizes
- *"work on bd-a1b2"* — dispatch the worker
- *"what's the status of the epic?"* — the agent reads the graph and reports

The full human workflow with examples is in [`../GUIDE.md`](../GUIDE.md). The complete agent rules are in [`../AGENTS.md`](../AGENTS.md).

---

## Don't want Beads?

Totally fine. This workspace is designed to work without it.

- If `bd` isn't installed, track work in [`../TASKS.md`](../TASKS.md) instead. It uses the **exact same structure** (epics → features → reviews, same `role:` labels) with manual IDs like `T-001`.
- The agents check `command -v bd` and automatically use the markdown fallback when Beads is absent.
- You can adopt Beads later (or drop it entirely) without restructuring anything.

---

## A few gotchas worth knowing

- **`bd` runs inside a git repo.** Initialize git first if you see "not in a git repository."
- **Keep `.beads/` off cloud-synced folders** (Dropbox/iCloud). Sync daemons can corrupt the database (`disk I/O error`).
- **Don't use `bd edit`** — it opens an interactive editor that agents can't drive. Use `bd update ... --json` instead.
- **One epic per spec.** Every feature/bug/review lives under an epic — no orphan tasks.
- **Claim before you start, close when you're done.** This is the discipline that keeps the board honest, for both you and the agents.
- **`bd memories`** prints durable notes the agent has saved; this workspace runs it automatically at session start (via the Factory/Cursor hooks) so context survives long conversations.

---

## Learn more

- Project workflow and examples: [`../GUIDE.md`](../GUIDE.md)
- Full agent playbook: [`../AGENTS.md`](../AGENTS.md)
- Beads skill reference (commands, troubleshooting): [`../.factory/skills/beads/SKILL.md`](../.factory/skills/beads/SKILL.md)
- Beads upstream project: <https://github.com/steveyegge/beads>
