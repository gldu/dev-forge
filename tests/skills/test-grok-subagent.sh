#!/usr/bin/env bash
#
# test-grok-subagent.sh — regression net for Grok Build TUI subagent dispatch.
#
# Bug: using-dev-forge told the agent to write the platform-neutral
#   Subagent (general-purpose):
# template, then translate via a tool-mapping file. Grok Build was not in
# the platform table and had no grok-tools.md, so the agent either emitted
# the template as prose or fell back to inline work. The native tool is
# spawn_subagent (subagent_type: "general-purpose").
#
# This suite asserts the mapping exists and is wired from SKILL.md, so a
# missing Grok row cannot silently return.
#
# bash 3.2.57 (macOS /bin/bash) compatible; no external dependencies.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILL="$REPO_ROOT/skills/using-dev-forge/SKILL.md"
GROK_TOOLS="$REPO_ROOT/skills/using-dev-forge/references/grok-tools.md"

PASS_COUNT=0
FAIL_COUNT=0

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

# M8: this test takes no arguments.
[[ $# -eq 0 ]] || die "unexpected argument(s): $*"

[[ -f "$SKILL" ]] || die "using-dev-forge SKILL.md not found: $SKILL"

# --- 1. grok-tools.md must exist ---

if [[ -f "$GROK_TOOLS" ]]; then
  pass "grok-tools.md exists"
else
  fail "grok-tools.md missing (Grok Build has no subagent mapping)"
fi

# --- 2. SKILL.md platform table must name Grok Build + spawn_subagent ---

if grep -q 'Grok Build' "$SKILL" && grep -q 'spawn_subagent' "$SKILL"; then
  pass "SKILL.md platform table names Grok Build and spawn_subagent"
else
  fail "SKILL.md does not map Grok Build TUI to spawn_subagent"
fi

# --- 3. SKILL.md must list grok-tools.md in the mapping-file list ---

if grep -q 'grok-tools.md' "$SKILL"; then
  pass "SKILL.md lists grok-tools.md"
else
  fail "SKILL.md does not list grok-tools.md in tool mapping files"
fi

# Remaining assertions need the mapping file. Skip them with explicit FAILs
# when it is absent so a missing file is one failure plus these, not a
# cascade of "file not found" noise from grep.
if [[ ! -f "$GROK_TOOLS" ]]; then
  fail "cannot assert grok-tools.md contents: file missing"
  echo "GROK SUBAGENT TESTS: $FAIL_COUNT failure(s), $PASS_COUNT passed" >&2
  exit 1
fi

# --- 4. grok-tools.md must translate the platform-neutral template ---

if grep -q 'Subagent (general-purpose)' "$GROK_TOOLS" \
  && grep -q 'spawn_subagent' "$GROK_TOOLS"; then
  pass "grok-tools.md maps Subagent (general-purpose) to spawn_subagent"
else
  fail "grok-tools.md does not map Subagent (general-purpose) to spawn_subagent"
fi

# --- 5. grok-tools.md must name the wait/collect tool ---

if grep -q 'get_command_or_subagent_output' "$GROK_TOOLS"; then
  pass "grok-tools.md names get_command_or_subagent_output"
else
  fail "grok-tools.md does not tell the agent how to collect subagent results"
fi

# --- 6. grok-tools.md must forbid emitting the template as prose ---

if grep -Eqi 'never emit|do not write|not as (prose|text)|never write' "$GROK_TOOLS"; then
  pass "grok-tools.md forbids emitting the template as prose"
else
  fail "grok-tools.md does not forbid writing Subagent (general-purpose) as text"
fi

# --- summary ---

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo "GROK SUBAGENT TESTS: $FAIL_COUNT failure(s), $PASS_COUNT passed" >&2
  exit 1
fi
echo "PASS: all $PASS_COUNT grok subagent checks passed"
echo "ALL GROK SUBAGENT TESTS PASSED"
