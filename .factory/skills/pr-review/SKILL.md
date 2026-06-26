---
name: pr-review
description: >
  Run an AI-powered code review on a GitHub PR. Fetches the PR and its diff, analyzes the
  changes, posts findings as Conventional Comments inline on the PR, then asks the user to
  approve, request changes, or comment before submitting. Use when the user says "review PR",
  "review pull request", or provides a PR number or GitHub PR URL.
---

# PR Review

GitHub PR review workflow: fetch -> analyze -> inline comments -> submit.

## Step 1: Resolve the PR

Accept a PR number (`277`), a GitHub URL, or "the current PR".

```bash
gh pr view <number_or_url> --json number,url,title,headRefName,baseRefName,headRepositoryOwner,headRepository,state,isDraft,headRefOid \
  --jq '{number,url,title,headRefName,baseRefName,state,isDraft,headRefOid,repo:(.headRepositoryOwner.login+"/"+.headRepository.name)}'
```

- If `state == "MERGED"`: warn the user (review will be read-only) but continue.
- If `state == "CLOSED"`: stop and tell the user.
- If `isDraft == true`: note it but continue.

Remember: `PR_NUMBER`, `REPO`, `HEAD_BRANCH`, `BASE_BRANCH`, `HEAD_SHA`, `PR_URL`, `PR_TITLE`.

## Step 2: Fetch the diff and context

```bash
gh pr diff "$PR_NUMBER" -R "$REPO"
gh api "repos/$REPO/pulls/$PR_NUMBER/comments" --paginate   # existing inline comments
```

For full file context where needed, read the changed files (check out the branch in a worktree via `./scripts/worktree.sh` if you need a local working copy).

## Step 3: Analyze the diff

Review for:
1. **Correctness** -- logic bugs, edge cases, off-by-one, nil/null handling
2. **Security** -- secrets, injection, auth bypass, unvalidated input
3. **Error handling** -- graceful failures, appropriate logging
4. **Test coverage** -- new behaviors covered by meaningful tests
5. **Code quality** -- readable, idiomatic, consistent with surrounding code
6. **Performance** -- N+1 queries, missing indexes, unbounded loops

Produce findings as a list, each with: file path, line, label, subject, discussion, and an optional one-click-apply suggestion block.

## Step 4: Format findings as Conventional Comments

Each comment body:

1. `**<label> (<decorations>):** <subject>`
2. blank line + `<discussion>`
3. If you have a concrete fix, append a fenced ` ```suggestion ``` ` block **verbatim** (it produces a GitHub one-click apply). Keep it a fenced code block, not prose.

Labels: `issue` (blocking), `suggestion`, `nitpick`, `question`, `thought`, `praise`. Mark blocking vs non-blocking in the decorations.

Example:
```
**issue (blocking):** Missing null guard on `user`

`handler.go` line 42 dereferences `user` before checking the lookup result, which panics on a cache miss.

```suggestion
    if user == nil {
        return ErrNotFound
    }
```
```

## Step 5: Present summary and get the review decision

Show the user the full findings list (file, line, label, subject, a short code snippet, and the discussion). Then ask:

```
How would you like to submit this review?
  1. APPROVE
  2. REQUEST_CHANGES
  3. COMMENT
```

Offer a default review body: `"<summary> [<N> finding(s) posted as inline comments]"`. Accept or let the user customize.

## Step 6: Submit the review

Build the payload with `jq` (handles all quoting/escaping) and submit via `--input`. Inline comments use `path` + `line` (or `position` within the diff hunk); findings without a locatable line go in the review body.

```bash
jq -n \
  --arg commit_id "$HEAD_SHA" \
  --arg event "<APPROVE|REQUEST_CHANGES|COMMENT>" \
  --arg body "<final_body>" \
  --argjson comments '<JSON_array_of_inline_comments>' \
  '{commit_id: $commit_id, event: $event, body: $body, comments: $comments}' \
  > /tmp/pr-review-$PR_NUMBER.json

gh api "repos/$REPO/pulls/$PR_NUMBER/reviews" \
  --method POST \
  --input /tmp/pr-review-$PR_NUMBER.json \
  --jq '.html_url'
```

Print the returned review URL to the user.

## Error Handling

| Situation | Action |
|-----------|--------|
| `gh auth status` fails | Stop; tell the user to run `gh auth login` |
| `gh api` review POST fails | Show the error; let the user retry or copy the command |
| A finding's line isn't in the diff | Post it as a PR-level comment (no `position`/`line`) |
| Large diff | Review the highest-risk files first; note any files skipped |
