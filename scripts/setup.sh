#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE_JSON="$WORKSPACE_DIR/workspace.json"

info()  { printf '\033[34m[setup]\033[0m %s\n' "$*"; }
ok()    { printf '\033[32m[setup]\033[0m %s\n' "$*"; }
warn()  { printf '\033[33m[setup]\033[0m %s\n' "$*"; }
error() { printf '\033[31m[setup]\033[0m %s\n' "$*" >&2; exit 1; }

# --- Tool checks ---

info "Checking required tools..."

for tool in git gh jq; do
  if ! command -v "$tool" &>/dev/null; then
    error "Required tool not found: $tool. Please install it and re-run."
  fi
done
ok "git, gh, jq are installed"

if ! gh auth status &>/dev/null; then
  warn "gh is not authenticated. Run: gh auth login (continuing anyway)"
else
  ok "GitHub CLI authenticated"
fi

# --- Beads (optional, recommended) ---

if command -v bd &>/dev/null; then
  ok "bd (beads) already installed: $(bd version 2>/dev/null || echo 'unknown version')"
  BD_AVAILABLE=1
else
  warn "bd (beads) not found. It is the recommended task tracker but is optional."
  if command -v brew &>/dev/null; then
    info "Attempting to install bd via brew..."
    if brew install beads 2>/dev/null; then
      ok "bd installed"
      BD_AVAILABLE=1
    else
      warn "brew install failed."
      BD_AVAILABLE=0
    fi
  elif command -v npm &>/dev/null; then
    info "Attempting to install bd via npm..."
    if npm install -g @beads/bd 2>/dev/null; then
      ok "bd installed"
      BD_AVAILABLE=1
    else
      warn "npm install failed."
      BD_AVAILABLE=0
    fi
  else
    BD_AVAILABLE=0
  fi

  if [ "${BD_AVAILABLE}" = "0" ]; then
    warn "Continuing without bd. Track work in TASKS.md instead (see AGENTS.md -> Task Tracking)."
    warn "To install bd later: https://github.com/steveyegge/beads"
  fi
fi

# --- Clone repos ---

info "Checking managed repositories..."

PARENT_DIR="$(dirname "$WORKSPACE_DIR")"

jq -c '.repos[]' "$WORKSPACE_JSON" | while IFS= read -r repo; do
  name=$(echo "$repo" | jq -r '.name')
  url=$(echo "$repo"  | jq -r '.url')
  path=$(echo "$repo" | jq -r '.path')

  # path is relative to workspace dir (e.g., "../my-backend")
  abs_path="$(cd "$WORKSPACE_DIR" && realpath -m "$path" 2>/dev/null || echo "$PARENT_DIR/$name")"

  if [[ "$url" == *"<"* ]]; then
    warn "$name: still a placeholder URL ($url). Run ./scripts/init.sh or edit workspace.json."
    continue
  fi

  if [ -d "$abs_path/.git" ]; then
    ok "$name: already present at $abs_path"
  else
    info "$name: cloning from $url..."
    git clone "$url" "$abs_path"
    ok "$name: cloned"
  fi
done

# --- Beads init ---

cd "$WORKSPACE_DIR"
if command -v bd &>/dev/null; then
  if [ -d ".beads" ]; then
    ok "Beads already initialized (.beads/ exists)"
  else
    info "Initializing Beads..."
    bd init --quiet 2>/dev/null || bd init || warn "bd init failed; you can run it manually later"
    ok "Beads initialized"
  fi
fi

echo ""
ok "Setup complete. Run ./scripts/status.sh to verify all repos."
