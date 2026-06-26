#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE_JSON="$WORKSPACE_DIR/workspace.json"

info() { printf '\033[34m[sync]\033[0m %s\n' "$*"; }
ok()   { printf '\033[32m[sync]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[sync]\033[0m %s\n' "$*"; }

jq -c '.repos[]' "$WORKSPACE_JSON" | while IFS= read -r repo; do
  name=$(echo "$repo"   | jq -r '.name')
  path=$(echo "$repo"   | jq -r '.path')
  branch=$(echo "$repo" | jq -r '.default_branch')

  abs_path="$(cd "$WORKSPACE_DIR" && realpath -m "$path" 2>/dev/null || echo "$(dirname "$WORKSPACE_DIR")/$name")"

  if [ ! -d "$abs_path/.git" ]; then
    warn "$name: not found at $abs_path (run setup.sh)"
    continue
  fi

  current_branch=$(git -C "$abs_path" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

  if [ "$current_branch" != "$branch" ]; then
    warn "$name: on branch '$current_branch', not '$branch' -- skipping pull"
    continue
  fi

  info "$name: pulling $branch..."
  git -C "$abs_path" pull --rebase --quiet
  ok "$name: up to date"
done
