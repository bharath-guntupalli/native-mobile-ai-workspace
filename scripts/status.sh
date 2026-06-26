#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE_JSON="$WORKSPACE_DIR/workspace.json"

pad() { printf '%-30s' "$1"; }

printf '\n'
printf '%s\n' "$(pad 'REPO') $(pad 'BRANCH') $(pad 'STATUS') AHEAD/BEHIND"
printf '%s\n' "$(printf '%.0s-' {1..70})"

jq -c '.repos[]' "$WORKSPACE_JSON" | while IFS= read -r repo; do
  name=$(echo "$repo" | jq -r '.name')
  path=$(echo "$repo" | jq -r '.path')

  abs_path="$(cd "$WORKSPACE_DIR" && realpath -m "$path" 2>/dev/null || echo "$(dirname "$WORKSPACE_DIR")/$name")"

  if [ ! -d "$abs_path/.git" ]; then
    printf '%s\n' "$(pad "$name") $(pad '---') NOT FOUND"
    continue
  fi

  branch=$(git -C "$abs_path" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

  if git -C "$abs_path" diff --quiet 2>/dev/null && git -C "$abs_path" diff --cached --quiet 2>/dev/null; then
    dirty="clean"
  else
    dirty="DIRTY"
  fi

  untracked=$(git -C "$abs_path" ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
  [ "$untracked" -gt 0 ] && dirty="$dirty+$untracked untracked"

  ahead_behind=$(git -C "$abs_path" rev-list --left-right --count "HEAD...@{upstream}" 2>/dev/null || echo "? ?")
  ahead=$(echo "$ahead_behind" | awk '{print $1}')
  behind=$(echo "$ahead_behind" | awk '{print $2}')
  ab_str="ahead:$ahead behind:$behind"

  printf '%s\n' "$(pad "$name") $(pad "$branch") $(pad "$dirty") $ab_str"
done

printf '\n'
