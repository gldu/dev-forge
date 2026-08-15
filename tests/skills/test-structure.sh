#!/usr/bin/env bash
#
# test-structure.sh — runs scripts/check-skills.sh (the structural consistency
# checker, commit 927a2a4) and asserts its documented exit contract:
#
#   exit 0  -> all skills structurally OK, success line "all N skills OK" on
#              stdout (machine-parseable; failures go to stderr)
#   exit 1  -> at least one structural failure
#
# On failure the checker's own FAIL output is dumped verbatim for diagnosis.
# The success-line assertion uses the skill count the checker actually reports
# (currently 22), so the grep stays valid if the skill set grows.
#
# bash 3.2.57 (macOS /bin/bash) compatible; no external dependencies.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CHECKER="$REPO_ROOT/scripts/check-skills.sh"

TMP_DIR=""
STATUS=0

trap 'rm -rf "${TMP_DIR:-}"' EXIT

die() {
  echo "error: $*" >&2
  exit 1
}

[[ -f "$CHECKER" ]] || die "check-skills.sh not found: $CHECKER"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/df-structure-test.XXXXXX")"

EXPECTED_SKILLS="$(ls -d "$REPO_ROOT"/skills/*/ 2>/dev/null | wc -l | tr -d ' ')"
[[ -n "$EXPECTED_SKILLS" && "$EXPECTED_SKILLS" -gt 0 ]] \
  || die "no skill directories found under $REPO_ROOT/skills"

# Run the checker; capture stdout (success line) and stderr (FAIL lines)
# separately so the exit-0 contract can be asserted against stdout alone.
if "$CHECKER" > "$TMP_DIR/out" 2> "$TMP_DIR/err"; then
  STATUS=0
else
  STATUS=$?
fi

if [[ "$STATUS" -ne 0 ]]; then
  echo "FAIL: check-skills.sh exited $STATUS (expected 0)" >&2
  echo "--- check-skills.sh stdout ---" >&2
  cat "$TMP_DIR/out" >&2
  echo "--- check-skills.sh stderr ---" >&2
  cat "$TMP_DIR/err" >&2
  exit 1
fi

if ! grep -q "all ${EXPECTED_SKILLS} skills OK" "$TMP_DIR/out"; then
  echo "FAIL: check-skills.sh stdout missing 'all ${EXPECTED_SKILLS} skills OK'" >&2
  echo "--- check-skills.sh stdout ---" >&2
  cat "$TMP_DIR/out" >&2
  exit 1
fi

echo "PASS: check-skills.sh exit 0, all ${EXPECTED_SKILLS} skills OK"
echo "ALL STRUCTURE TESTS PASSED"
