#!/usr/bin/env bash
#
# test-session-start.sh — validates hooks/session-start JSON output per platform.
#
# Written against the REAL interface (post P1.3, commit 45aa140 "修复
# session-start explicit platform params"): the hook takes an explicit platform
# flag (--cursor / --claude / empty) and falls back to env-var detection
# (CURSOR_PLUGIN_ROOT / CLAUDE_PLUGIN_ROOT / COPILOT_CLI). The plugin root is
# always derived from the script's own location, so no fake install tree is
# needed — environment isolation is what matters here (no leaked vars, no
# pollution of the caller's environment).
#
# Verified output shapes (matching the actual script):
#   --cursor / CURSOR_PLUGIN_ROOT        -> {"additional_context": "..."}
#   --claude / CLAUDE_PLUGIN_ROOT        -> {"hookSpecificOutput": {...}}
#   default (SDK standard)               -> {"additionalContext": "..."}
#   COPILOT_CLI + CLAUDE_PLUGIN_ROOT     -> default (Copilot guard wins)
#
# Note on the negative test: hooks/session-start deliberately exits 0 for any
# argument (unknown flags fall through to the SDK-default branch), so the
# negative assertion here is "unknown flag must NOT be misrouted to a
# platform-specific shape" — not "must exit non-zero".
#
# bash 3.2.57 (macOS /bin/bash) compatible. python3 is used only for JSON
# parsing (the script's output is the JSON being validated).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$REPO_ROOT/hooks/session-start"

PASS_COUNT=0
FAIL_COUNT=0
TMP_DIR=""

trap 'rm -rf "${TMP_DIR:-}"' EXIT

die() {
  echo "error: $*" >&2
  exit 1
}

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  echo "PASS: $1"
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  echo "FAIL: $1" >&2
}

# Run the hook with a clean platform env (no leaked CURSOR/CLAUDE/COPILOT vars
# can silently steer the branch selection).
run_hook() {
  env -u CLAUDE_PLUGIN_ROOT -u CURSOR_PLUGIN_ROOT -u COPILOT_CLI "$HOOK" "$@"
}

# Capture the output of an arbitrary command into a file. Aborts the suite on
# a non-zero exit — the hook under test is expected to always terminate 0.
capture() {
  local file="$1"
  shift
  if ! "$@" > "$file" 2>&1; then
    echo "error: command exited non-zero: $*" >&2
    exit 1
  fi
}

# --- assertion helpers (each echoes a diagnostic on failure, returns 0/1) ---

assert_cursor_json() {
  local file="$1"
  python3 - "$file" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    d = json.load(f)
assert "additional_context" in d, \
    "cursor JSON missing top-level 'additional_context' (got keys: %s)" % sorted(d.keys())
assert "hookSpecificOutput" not in d, \
    "cursor JSON must not contain 'hookSpecificOutput'"
v = d["additional_context"]
assert isinstance(v, str) and v.strip(), "additional_context must be a non-empty string"
assert "using-dev-forge" in v, "additional_context should mention the using-dev-forge skill"
assert len(v) > 500, "additional_context looks truncated (len %d)" % len(v)
PY
}

assert_claude_json() {
  local file="$1"
  python3 - "$file" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    d = json.load(f)
assert "hookSpecificOutput" in d, \
    "claude JSON missing 'hookSpecificOutput' (got keys: %s)" % sorted(d.keys())
assert "additional_context" not in d, "claude JSON must not contain 'additional_context'"
hso = d["hookSpecificOutput"]
assert isinstance(hso, dict), "hookSpecificOutput must be an object"
assert hso.get("hookEventName") == "SessionStart", \
    "hookSpecificOutput.hookEventName should be 'SessionStart' (got %r)" % hso.get("hookEventName")
v = hso.get("additionalContext")
assert isinstance(v, str) and v.strip(), \
    "hookSpecificOutput.additionalContext must be a non-empty string"
assert "using-dev-forge" in v, \
    "hookSpecificOutput.additionalContext should mention the using-dev-forge skill"
assert len(v) > 500, "hookSpecificOutput.additionalContext looks truncated (len %d)" % len(v)
PY
}

assert_sdk_json() {
  local file="$1"
  python3 - "$file" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    d = json.load(f)
assert "additionalContext" in d, \
    "SDK default JSON missing top-level 'additionalContext' (got keys: %s)" % sorted(d.keys())
assert "hookSpecificOutput" not in d, "SDK default JSON must not contain 'hookSpecificOutput'"
assert "additional_context" not in d, "SDK default JSON must not contain 'additional_context'"
v = d["additionalContext"]
assert isinstance(v, str) and v.strip(), "additionalContext must be a non-empty string"
assert "using-dev-forge" in v, "additionalContext should mention the using-dev-forge skill"
assert len(v) > 500, "additionalContext looks truncated (len %d)" % len(v)
PY
}

check() {
  local name="$1"
  local out=""
  shift
  if out="$("$@" 2>&1)"; then
    pass "$name"
  else
    fail "$name"
    if [[ -n "$out" ]]; then
      printf '%s\n' "$out" | sed 's/^/    /' >&2
    fi
  fi
}

# --- tests ---

[[ -x "$HOOK" ]] || die "hook not found or not executable: $HOOK"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/df-hook-test.XXXXXX")"

capture "$TMP_DIR/cursor.json" run_hook --cursor
check "cursor flag (--cursor) emits additional_context JSON" \
  assert_cursor_json "$TMP_DIR/cursor.json"

capture "$TMP_DIR/claude.json" run_hook --claude
check "claude flag (--claude) emits hookSpecificOutput JSON" \
  assert_claude_json "$TMP_DIR/claude.json"

capture "$TMP_DIR/default.json" run_hook
check "no flag emits SDK top-level additionalContext JSON" \
  assert_sdk_json "$TMP_DIR/default.json"

# Env-var fallbacks (the pre-P1.3 wiring path, still supported).
capture "$TMP_DIR/claude-env.json" \
  env -u CURSOR_PLUGIN_ROOT -u COPILOT_CLI CLAUDE_PLUGIN_ROOT="$TMP_DIR/fake-claude-root" "$HOOK"
check "CLAUDE_PLUGIN_ROOT env selects claude shape" \
  assert_claude_json "$TMP_DIR/claude-env.json"

capture "$TMP_DIR/cursor-env.json" \
  env -u CLAUDE_PLUGIN_ROOT -u COPILOT_CLI CURSOR_PLUGIN_ROOT="$TMP_DIR/fake-cursor-root" "$HOOK"
check "CURSOR_PLUGIN_ROOT env selects cursor shape" \
  assert_cursor_json "$TMP_DIR/cursor-env.json"

# Copilot guard: with COPILOT_CLI set, even CLAUDE_PLUGIN_ROOT must NOT select
# the claude branch — the SDK-standard shape wins.
capture "$TMP_DIR/copilot.json" \
  env -u CURSOR_PLUGIN_ROOT COPILOT_CLI=1 CLAUDE_PLUGIN_ROOT="$TMP_DIR/fake-claude-root" "$HOOK"
check "COPILOT_CLI overrides CLAUDE_PLUGIN_ROOT (SDK shape)" \
  assert_sdk_json "$TMP_DIR/copilot.json"

# Negative: unknown flags are not rejected by the hook (exit 0 by design), but
# must never be misrouted into a platform-specific shape.
capture "$TMP_DIR/bogus.json" run_hook --bogus-flag
check "unknown flag falls back to SDK shape, not misrouted (negative)" \
  assert_sdk_json "$TMP_DIR/bogus.json"

# --- summary ---

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo "HOOK TESTS: $FAIL_COUNT failure(s), $PASS_COUNT passed" >&2
  exit 1
fi
echo "PASS: all $PASS_COUNT hook checks passed"
echo "ALL HOOK TESTS PASSED"
