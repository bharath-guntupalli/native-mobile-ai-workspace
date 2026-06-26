#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE_JSON="$WORKSPACE_DIR/workspace.json"

usage() {
  echo "Usage: $0 <repo-name> <branch-name>"
  echo ""
  echo "Creates (or attaches to) a git worktree for the given repo and branch."
  echo "Worktree is created at: ./worktrees/<repo-name>/<branch-name>/"
  echo ""
  echo "Available repos:"
  jq -r '.repos[].name' "$WORKSPACE_JSON" | sed 's/^/  /'
  exit 1
}

[ $# -ne 2 ] && usage

REPO_NAME="$1"
BRANCH="$2"

# Validate repo exists in manifest, and read its default branch
REPO_PATH=$(jq -r --arg name "$REPO_NAME" '.repos[] | select(.name == $name) | .path' "$WORKSPACE_JSON")
BASE_BRANCH=$(jq -r --arg name "$REPO_NAME" '.repos[] | select(.name == $name) | .default_branch' "$WORKSPACE_JSON")
if [ -z "$REPO_PATH" ]; then
  echo "Error: '$REPO_NAME' not found in workspace.json" >&2
  usage
fi
[ -z "$BASE_BRANCH" ] || [ "$BASE_BRANCH" = "null" ] && BASE_BRANCH="main"

abs_repo="$(cd "$WORKSPACE_DIR" && realpath -m "$REPO_PATH" 2>/dev/null || echo "$(dirname "$WORKSPACE_DIR")/$REPO_NAME")"

if [ ! -d "$abs_repo/.git" ]; then
  echo "Error: repo not found at $abs_repo. Run ./scripts/setup.sh first." >&2
  exit 1
fi

WORKTREE_DIR="$WORKSPACE_DIR/worktrees/$REPO_NAME/$BRANCH"

if [ -d "$WORKTREE_DIR" ]; then
  echo "Worktree already exists: $WORKTREE_DIR"
  echo "cd $WORKTREE_DIR"
  exit 0
fi

mkdir -p "$(dirname "$WORKTREE_DIR")"

# Check if branch already exists in the repo
if git -C "$abs_repo" show-ref --verify --quiet "refs/heads/$BRANCH"; then
  echo "Branch '$BRANCH' exists -- attaching worktree..."
  git -C "$abs_repo" worktree add "$WORKTREE_DIR" "$BRANCH"
else
  echo "Creating new branch '$BRANCH' and worktree (based on origin/$BASE_BRANCH)..."
  git -C "$abs_repo" fetch origin "$BASE_BRANCH"
  git -C "$abs_repo" worktree add -b "$BRANCH" "$WORKTREE_DIR" "origin/$BASE_BRANCH"
fi

echo ""
echo "Worktree ready. Navigate with:"
echo "  cd $WORKTREE_DIR"
echo ""
echo "To remove when done:"
echo "  git -C $abs_repo worktree remove $WORKTREE_DIR"
echo "  git -C $abs_repo branch -d $BRANCH   # after PR merged"
