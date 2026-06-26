---
name: gh
description: Fetch details from a GitHub URL using the gh CLI and act on them. Use when the user provides a GitHub URL (PR, issue, workflow run, or CI job) with a follow-up instruction like "analyze", "fix test failures", "summarize", or "what failed". Handles all GitHub resource types via gh CLI — avoids fetch truncation issues on large logs.
---

# gh — GitHub URL Fetch and Act

Parse a GitHub URL, fetch its details via `gh` CLI, then carry out the user's instruction (analyze, fix, summarize, etc.).

## Prerequisites

- `gh` CLI must be authenticated (`gh auth status`)
- Must be run from inside a git repository (or `-R owner/repo` will be inferred from the URL)

## Step 1: Parse the URL

Strip any query string (`?pr=N`, `?tab=...`) from the URL before parsing.

Extract from the URL path:
- `owner` and `repo` → used as `-R owner/repo` when the current repo doesn't match
- Resource type and ID

| URL Pattern | Resource Type |
|---|---|
| `.../actions/runs/{run_id}/job/{job_id}` | CI job |
| `.../actions/runs/{run_id}` | CI workflow run |
| `.../pull/{number}` | Pull request |
| `.../issues/{number}` | Issue |

**Cross-repo**: If the URL's `owner/repo` differs from the current git repo (check with `git remote get-url origin`), append `-R {owner}/{repo}` to all `gh` commands.

## Step 2: Fetch resource details

### CI job URL (`.../actions/runs/{run_id}/job/{job_id}`)

```bash
gh run view -j {job_id} --log-failed [-R owner/repo]
```

If the job passed (no failed output), fetch the full log instead:

```bash
gh run view -j {job_id} --log [-R owner/repo]
```

### CI workflow run URL (`.../actions/runs/{run_id}`)

Get the run summary and identify failed jobs:

```bash
gh run view {run_id} --json conclusion,status,displayTitle,jobs \
  --jq '{conclusion, status, title: .displayTitle, failed_jobs: [.jobs[] | select(.conclusion == "failure") | {name, databaseId, url}]}' \
  [-R owner/repo]
```

Then fetch failed logs for each failed job:

```bash
gh run view -j {job_id} --log-failed [-R owner/repo]
```

### Pull request URL (`.../pull/{number}`)

```bash
gh pr view {number} --json number,title,state,body,headRefName,baseRefName,author,labels,statusCheckRollup [-R owner/repo]
```

To also get the diff for review or fixing:

```bash
gh pr diff {number} [-R owner/repo]
```

### Issue URL (`.../issues/{number}`)

```bash
gh issue view {number} --json number,title,state,body,labels,assignees,comments [-R owner/repo]
```

## Step 3: Present findings and act on the instruction

Summarize what you found clearly before taking action. Example format for a CI failure:

```
Run #<id> — FAILED
Failed job: tests

Failure:
  <test name>
  <file:line>
  <assertion / error message>
```

Then proceed with the user's instruction (fix, analyze, summarize, etc.).

## Error Handling

| Situation | Action |
|---|---|
| `gh auth status` fails | Stop and tell the user to run `gh auth login` |
| URL pattern not recognized | Tell the user the URL type is unsupported and list what is supported |
| `--log-failed` returns nothing (job passed) | Fall back to `--log` or report the job passed |
| Run has >25 failed jobs | `gh` CLI will warn; fetch logs for each job individually if needed |
| Cross-repo and no `-R` given | Extract `owner/repo` from URL and add `-R` flag automatically |
