#!/usr/bin/env bash
#
# init.sh -- first-run setup for the Native Mobile AI Workspace.
#
# 1. Pick which AI tool you use (Cursor / Factory.ai / both) and remove the
#    adapter folder(s) you don't need.
# 2. Replace placeholder tokens (<ORG>, <BACKEND_REPO>, ...) across the workspace.
#
# Idempotent and safe: supports --dry-run, confirms destructive actions, and
# detects when tokens have already been replaced.
#
set -euo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SELF_REL="scripts/init.sh"

info()  { printf '\033[34m[init]\033[0m %s\n' "$*"; }
ok()    { printf '\033[32m[init]\033[0m %s\n' "$*"; }
warn()  { printf '\033[33m[init]\033[0m %s\n' "$*"; }
error() { printf '\033[31m[init]\033[0m %s\n' "$*" >&2; exit 1; }

# --- Defaults / args ---
TOOL=""
ORG=""
WORKSPACE_REPO=""
BACKEND_REPO=""
IOS_REPO=""
ANDROID_REPO=""
TRACKER_BASE_URL=""
WORKER_MODEL=""
REVIEWER_MODEL=""
DRY_RUN=0
ASSUME_YES=0

usage() {
  cat <<'EOF'
Usage: ./scripts/init.sh [options]

Interactive when run with no options. Flags enable non-interactive use (CI):

  --tool <cursor|factory|both>   Which adapter(s) to keep
  --org <handle>                 GitHub org or personal handle
  --workspace-repo <name>        This workspace's repo name (for spec URLs)
  --backend <name>               Backend repo name
  --ios <name>                   iOS repo name
  --android <name>               Android repo name
  --tracker-url <url>            Optional issue tracker base URL (e.g. https://you.atlassian.net)
  --worker-model <slug>          Factory worker (Forge) model slug
  --reviewer-model <slug>        Factory reviewer (Sentinel) model slug
  --dry-run                      Print planned changes without writing
  --yes                          Skip confirmation prompts
  -h, --help                     Show this help
EOF
  exit "${1:-0}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --tool) TOOL="${2:-}"; shift 2;;
    --org) ORG="${2:-}"; shift 2;;
    --workspace-repo) WORKSPACE_REPO="${2:-}"; shift 2;;
    --backend) BACKEND_REPO="${2:-}"; shift 2;;
    --ios) IOS_REPO="${2:-}"; shift 2;;
    --android) ANDROID_REPO="${2:-}"; shift 2;;
    --tracker-url) TRACKER_BASE_URL="${2:-}"; shift 2;;
    --worker-model) WORKER_MODEL="${2:-}"; shift 2;;
    --reviewer-model) REVIEWER_MODEL="${2:-}"; shift 2;;
    --dry-run) DRY_RUN=1; shift;;
    --yes|-y) ASSUME_YES=1; shift;;
    -h|--help) usage 0;;
    *) error "Unknown option: $1 (use --help)";;
  esac
done

cd "$WORKSPACE_DIR"

INTERACTIVE=0
[ -t 0 ] && [ -z "$TOOL$ORG$BACKEND_REPO$IOS_REPO$ANDROID_REPO" ] && INTERACTIVE=1

ask() {
  # ask <var-name> <prompt> <default>
  local __var="$1" __prompt="$2" __default="${3:-}" __reply
  if [ -n "${!__var}" ]; then return; fi          # already set via flag
  if [ "$INTERACTIVE" = "0" ]; then return; fi      # non-interactive: leave blank
  if [ -n "$__default" ]; then
    read -r -p "$__prompt [$__default]: " __reply || true
    __reply="${__reply:-$__default}"
  else
    read -r -p "$__prompt: " __reply || true
  fi
  printf -v "$__var" '%s' "$__reply"
}

# --- Tool selection ---
if [ -z "$TOOL" ] && [ "$INTERACTIVE" = "1" ]; then
  echo "Which AI tool will you use in this workspace?"
  echo "  1) Cursor      (keep .cursor/, remove .factory/)"
  echo "  2) Factory.ai  (keep .factory/, remove .cursor/)"
  echo "  3) Both        (keep both)"
  read -r -p "Choice [1/2/3]: " choice || true
  case "$choice" in
    1) TOOL="cursor";;
    2) TOOL="factory";;
    3) TOOL="both";;
    *) error "Invalid choice: $choice";;
  esac
fi
TOOL="${TOOL:-both}"

case "$TOOL" in
  cursor) REMOVE=(".factory");;
  factory) REMOVE=(".cursor");;
  both) REMOVE=();;
  *) error "Invalid --tool: $TOOL (expected cursor|factory|both)";;
esac

# --- Gather token values ---
ask ORG               "GitHub org / personal handle"            ""
ask WORKSPACE_REPO    "This workspace's repo name"              "native-mobile-ai-workspace"
ask BACKEND_REPO      "Backend repo name"                        ""
ask IOS_REPO          "iOS repo name"                            ""
ask ANDROID_REPO      "Android repo name"                        ""
ask TRACKER_BASE_URL  "Issue tracker base URL (optional, blank to skip)" ""
ask WORKER_MODEL      "Factory worker (Forge) model slug (optional)"     ""
ask REVIEWER_MODEL    "Factory reviewer (Sentinel) model slug (optional)" ""

# --- Build replacement map (only non-empty values are applied) ---
TOKENS=()
VALUES=()
add_pair() { if [ -n "$2" ]; then TOKENS+=("$1"); VALUES+=("$2"); fi; }
add_pair "<ORG>"               "$ORG"
add_pair "<WORKSPACE_REPO>"    "$WORKSPACE_REPO"
add_pair "<BACKEND_REPO>"      "$BACKEND_REPO"
add_pair "<IOS_REPO>"          "$IOS_REPO"
add_pair "<ANDROID_REPO>"      "$ANDROID_REPO"
add_pair "<TRACKER_BASE_URL>"  "$TRACKER_BASE_URL"
add_pair "<WORKER_MODEL>"      "$WORKER_MODEL"
add_pair "<REVIEWER_MODEL>"    "$REVIEWER_MODEL"

# --- Confirm ---
echo ""
info "Plan:"
echo "    Tool      : $TOOL"
if [ "${#REMOVE[@]}" -gt 0 ]; then
  echo "    Remove    : ${REMOVE[*]}"
else
  echo "    Remove    : (nothing)"
fi
if [ "${#TOKENS[@]}" -gt 0 ]; then
  for i in "${!TOKENS[@]}"; do echo "    Replace   : ${TOKENS[$i]} -> ${VALUES[$i]}"; done
else
  echo "    Replace   : (no token values provided)"
fi
[ "$DRY_RUN" = "1" ] && warn "DRY RUN -- no changes will be written."
echo ""

if [ "$DRY_RUN" = "0" ] && [ "$ASSUME_YES" = "0" ] && [ "$INTERACTIVE" = "1" ]; then
  read -r -p "Proceed? [y/N]: " confirm || true
  case "$confirm" in y|Y|yes|YES) ;; *) error "Aborted.";; esac
fi

# --- sed in-place portability (BSD/macOS vs GNU) ---
sed_inplace() {
  if sed --version >/dev/null 2>&1; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}

# --- Collect target files (bash 3.2 compatible; macOS ships 3.2) ---
FILES=()
while IFS= read -r __f; do
  [ -n "$__f" ] && FILES+=("$__f")
done < <(
  find . \
    \( -path './.git' -o -path './worktrees' \) -prune -o \
    -type f \( -name '*.md' -o -name '*.json' -o -name '*.mdc' -o -name '*.sh' -o -name 'LICENSE' \) -print \
    | grep -v "^\./$SELF_REL$"
)

# --- Apply token replacements ---
if [ "${#TOKENS[@]}" -eq 0 ]; then
  warn "No token values provided; skipping token replacement."
else
  total=0
  for token in "${TOKENS[@]}"; do
    count=$({ grep -rl --fixed-strings "$token" "${FILES[@]}" 2>/dev/null || true; } | wc -l | tr -d ' ')
    total=$((total + count))
  done
  if [ "$total" -eq 0 ]; then
    ok "Tokens already replaced (nothing to do)."
  else
    for i in "${!TOKENS[@]}"; do
      token="${TOKENS[$i]}"; value="${VALUES[$i]}"
      matches=$(grep -rl --fixed-strings "$token" "${FILES[@]}" 2>/dev/null || true)
      [ -z "$matches" ] && continue
      while IFS= read -r f; do
        [ -z "$f" ] && continue
        if [ "$DRY_RUN" = "1" ]; then
          n=$(grep -c --fixed-strings "$token" "$f" 2>/dev/null || echo 0)
          echo "    would replace $token in $f ($n)"
        else
          # escape sed-special chars in the replacement value
          esc_token=$(printf '%s' "$token" | sed 's/[.[\*^$/]/\\&/g')
          esc_value=$(printf '%s' "$value" | sed 's/[&/\]/\\&/g')
          sed_inplace "s/$esc_token/$esc_value/g" "$f"
        fi
      done <<< "$matches"
    done
    [ "$DRY_RUN" = "0" ] && ok "Token replacement complete."
  fi
fi

# --- Remove unused adapter(s) ---
for dir in "${REMOVE[@]}"; do
  if [ -d "$dir" ]; then
    if [ "$DRY_RUN" = "1" ]; then
      echo "    would remove $dir/"
    else
      rm -rf "$dir"
      ok "Removed $dir/"
    fi
  fi
done

# --- Next steps ---
echo ""
ok "init complete."
echo ""
echo "Next steps:"
echo "  1) Review workspace.json and AGENTS.md for anything left to fill in."
echo "  2) Run ./scripts/setup.sh to clone sibling repos (and install beads if desired)."
case "$TOOL" in
  cursor)  echo "  3) Open this folder in Cursor. Rules in .cursor/rules load automatically.";;
  factory) echo "  3) Open this folder in Factory.ai. Droids/skills in .factory/ are available.";;
  both)    echo "  3) See TOOLING.md for enabling Cursor vs Factory.ai.";;
esac
