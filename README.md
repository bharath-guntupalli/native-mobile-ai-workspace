# Native Mobile AI Workspace

A reusable, tool-agnostic **orchestration workspace** for AI-driven development across multiple repositories — a backend service plus iOS and Android apps, by default. It gives an AI agent (and you) a consistent playbook for planning work, implementing it in isolated worktrees, reviewing it, and opening PRs across repos.

Works with both **[Factory.ai](https://factory.ai)** and **[Cursor](https://cursor.com)**. Pick one (or keep both) — see [TOOLING.md](TOOLING.md).

> This is a template. Clone it, run `./scripts/init.sh`, and replace the placeholders with your repos.

---

## How it works

You plan inline; workers and reviewers do the rest.

```
You: "plan <TICKET-KEY>"   (or "plan: <rough idea>")
  └── plan skill (inline)        -- explores repos, writes a spec, waits for your approval
        └── Forge (worker)         -- implements in a worktree, runs quality gates, pushes the branch
              └── Sentinel (review) -- reviews the diff, files fix tasks or opens the PR
```

- **One epic per spec**, features per implementation unit, a review task per feature.
- **Parallel** when the dependency graph allows; **autonomous** fix loops between worker and reviewer.
- Every PR follows [Conventional Commits](https://www.conventionalcommits.org/), links to its spec, and (optionally) to an issue tracker.

See [GUIDE.md](GUIDE.md) for worked examples and [AGENTS.md](AGENTS.md) for the full playbook.

---

## Clone everything into one parent folder

The agent resolves repos via relative `../<repo>` paths from `workspace.json`, so this workspace and all managed repos must be **siblings** in one parent folder:

```
my-project/                      ← one parent folder
├── native-mobile-ai-workspace/  ← this repo (the orchestrator)
├── <BACKEND_REPO>/              ← your backend service
├── <IOS_REPO>/                  ← your iOS app
└── <ANDROID_REPO>/              ← your Android app
```

```bash
mkdir my-project && cd my-project
git clone git@github.com:<ORG>/native-mobile-ai-workspace.git
cd native-mobile-ai-workspace
```

`./scripts/setup.sh` clones the sibling repos for you (from `workspace.json`).

---

## Quickstart

```bash
# 1. First-run setup: pick your tool + fill in placeholders
./scripts/init.sh

# 2. Clone sibling repos and (optionally) install Beads
./scripts/setup.sh

# 3. Verify
./scripts/status.sh
```

### Prerequisites

- **Required:** `git`, `gh` (GitHub CLI, authenticated via `gh auth login`), `jq`
- **Recommended:** [`bd` (Beads)](https://github.com/steveyegge/beads) — the task tracker. If it's not installed, the workspace falls back to the [`TASKS.md`](TASKS.md) markdown tracker automatically. New to Beads? Read [docs/BEADS.md](docs/BEADS.md) for a beginner-friendly intro.

---

## Placeholders to replace

`./scripts/init.sh` handles these for you (interactively or via flags). The full list, if you ever replace them by hand:

| Token | Meaning |
|-------|---------|
| `<ORG>` | Your GitHub org or personal handle |
| `<WORKSPACE_REPO>` | This workspace's repo name (used in spec URLs) |
| `<BACKEND_REPO>` | Your backend repo name |
| `<IOS_REPO>` | Your iOS repo name |
| `<ANDROID_REPO>` | Your Android repo name |
| `<TRACKER_BASE_URL>` | Optional issue-tracker base URL (e.g. `https://you.atlassian.net`) |
| `<WORKER_MODEL>` / `<REVIEWER_MODEL>` | Factory droid model slugs (in `.factory/droids/`) |

Non-interactive example:

```bash
./scripts/init.sh --tool cursor \
  --org myhandle --workspace-repo native-mobile-ai-workspace \
  --backend my-api --ios my-ios --android my-android
```

Add/remove managed repos any time by editing [workspace.json](workspace.json).

---

## Choosing your tool

`init.sh` keeps the adapter you pick and removes the other:

- **Cursor** → keeps `.cursor/` (rules, skills, hooks, commands), removes `.factory/`
- **Factory.ai** → keeps `.factory/` (droids, skills, settings), removes `.cursor/`
- **Both** → keeps both (safe; each tool ignores the other's folder)

Details and the full mapping are in [TOOLING.md](TOOLING.md).

---

## Layout

```
.
├── AGENTS.md          # the playbook (read by both tools)
├── GUIDE.md           # human workflow guide
├── TOOLING.md         # Factory vs Cursor mapping
├── README.md
├── LICENSE            # MIT
├── workspace.json     # managed repos (siblings)
├── TASKS.md           # markdown fallback tracker (no-bd mode)
├── specs/             # specs (template + yours)
├── scripts/           # init / setup / sync / status / worktree / reset
├── .factory/          # Factory.ai adapter (droids, skills, settings.json)
└── .cursor/           # Cursor adapter (rules, skills, hooks.json, mcp.json, commands)
```

---

## Issue tracker (optional)

An issue tracker (Jira, Linear, GitHub Issues, …) is optional. Configure it as an MCP integration to let the planner fetch tickets by key; otherwise drive work from a description plus the spec and task IDs. See [GUIDE.md](GUIDE.md) → "Issue tracker integration".

---

## License

[MIT](LICENSE).
