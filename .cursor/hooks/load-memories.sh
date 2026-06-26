#!/usr/bin/env bash
# Loads persistent Beads memories at session start / before compaction.
# No-ops gracefully when bd is not installed (markdown TASKS.md fallback).
set -euo pipefail

# Consume hook stdin (JSON) so the pipe doesn't block.
cat >/dev/null 2>&1 || true

if command -v bd >/dev/null 2>&1; then
  memories="$(bd memories 2>/dev/null || true)"
  if [ -n "$memories" ]; then
    printf '%s' "$memories" | jq -Rs '{additional_context: .}' 2>/dev/null || true
  fi
fi

exit 0
