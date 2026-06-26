#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE_JSON="$WORKSPACE_DIR/workspace.json"

info() { printf '\033[34m[reset]\033[0m %s\n' "$*"; }
ok()   { printf '\033[32m[reset]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[reset]\033[0m %s\n' "$*"; }
err()  { printf '\033[31m[reset]\033[0m %s\n' "$*"; }

jq -c '.repos[]' "$WORKSPACE_JSON" | while IFS= read -r repo; do
  name=$(echo "$repo"   | jq -r '.name')
  path=$(echo "$repo"   | jq -r '.path')
  branch=$(echo "$repo" | jq -r '.default_branch')

  abs_path="$(cd "$WORKSPACE_DIR" && realpath -m "$path" 2>/dev/null || echo "$(dirname "$WORKSPACE_DIR")/$name")"

  if [ ! -d "$abs_path/.git" ]; then
    warn "$name: not found at $abs_path (run setup.sh)"
    continue
  fi

  if [ -n "$(git -C "$abs_path" status --porcelain 2>/dev/null)" ]; then
    warn "$name: has uncommitted changes -- skipping"
    continue
  fi

  info "$name: fetching origin..."
  if ! git -C "$abs_path" fetch origin --quiet 2>/dev/null; then
    err "$name: fetch failed"
    continue
  fi

  current_branch=$(git -C "$abs_path" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

  if [ "$current_branch" != "$branch" ]; then
    info "$name: switching from '$current_branch' to '$branch'..."
    if ! git -C "$abs_path" checkout "$branch" --quiet 2>/dev/null; then
      err "$name: failed to checkout '$branch'"
      continue
    fi
  fi

  git -C "$abs_path" pull --rebase --quiet
  ok "$name: on $branch, up to date"
done
