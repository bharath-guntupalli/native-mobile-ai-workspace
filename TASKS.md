# Tasks (markdown fallback tracker)

This file is the **fallback task tracker** used only when [Beads (`bd`)](https://github.com/steveyegge/beads) is not installed. If `bd` is available, ignore this file and use `bd` instead (see `AGENTS.md` -> "Task Tracking").

Mirror the same structure `bd` uses: every unit of work belongs to an **epic**, each epic has **features** (implementation) and **review tasks**, and bugs are children of the epic. Use checkboxes for status.

## Conventions

- IDs: use short manual IDs like `T-001`, `T-002` (increment as you add).
- Status: `[ ]` open, `[~]` in progress, `[x]` done, `[-]` cancelled/deferred.
- Roles: tag each item with `role:architect` (planning/epics), `role:coder` (features/bugs), or `role:reviewer` (reviews).
- Link work to a ticket with `ref:<TICKET-KEY>` when an issue tracker is in use (optional).
- Branch naming stays the same: `agent/<task-id>-<short-description>`.

## Template

Copy this block per epic:

```markdown
## Epic: <title>  (T-001, role:architect, ref:<TICKET-KEY>)

Context: <why this work exists>
Acceptance:
- [ ] <epic-level criterion>

### Features
- [ ] T-002 role:coder repo:<BACKEND_REPO> — <feature title>
      Acceptance: <bullet list>; branch pushed; quality gates pass
- [ ] T-003 role:coder repo:<IOS_REPO> — <feature title> (depends on T-002)

### Reviews
- [ ] T-004 role:reviewer repo:<BACKEND_REPO> — Review T-002 (depends on T-002)
- [ ] T-005 role:reviewer repo:<IOS_REPO> — Review T-003 (depends on T-003)

### Bugs (added during implementation/review)
- [ ] T-006 role:coder repo:<BACKEND_REPO> — <bug title> (discovered-from T-004)
```

## Active work

<!-- Add epics below this line. -->
