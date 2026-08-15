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
# I1: a negative self-check runs the checker against a structurally broken
# fixture (missing `description:` frontmatter + a broken reference) inside a
# temp repo and asserts exit 1 with both problems flagged — so a regression
# that makes the checker ACCEPT broken skills fails this suite, not just a
# regression that rejects healthy ones.
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

# M8: this test takes no arguments — reject any with a clear message.
[[ $# -eq 0 ]] || die "unexpected argument(s): $*"

[[ -f "$CHECKER" ]] || die "check-skills.sh not found: $CHECKER"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/df-structure-test.XXXXXX")"

# shellcheck disable=SC2012  # ls parsing is safe: skill dir names are repo-controlled (forge-[A-Za-z0-9_-]+ / using-dev-forge), never non-alphanumeric
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

# I1 — negative self-check: the checker must REJECT a structurally broken
# skill (missing `description:` frontmatter + a broken reference), exit 1, and
# flag both problems. The checker locates skills/ relative to its own script
# location, so a throwaway copy in a temp repo exercises the fixture without
# touching the real repo.
BAD_REPO="$TMP_DIR/bad-repo"
mkdir -p "$BAD_REPO/scripts" "$BAD_REPO/skills/bad-skill"
cp "$CHECKER" "$BAD_REPO/scripts/check-skills.sh"
cat > "$BAD_REPO/skills/bad-skill/SKILL.md" <<'EOF'
---
name: bad-skill
---
# Bad skill

This skill has no description frontmatter and references a missing file:
references/ghost.md
EOF

if "$BAD_REPO/scripts/check-skills.sh" > "$TMP_DIR/bad-out" 2> "$TMP_DIR/bad-err"; then
  echo "FAIL: check-skills.sh exited 0 on the broken fixture (expected 1)" >&2
  echo "--- check-skills.sh stdout ---" >&2
  cat "$TMP_DIR/bad-out" >&2
  exit 1
fi
if ! grep -q "frontmatter missing 'description:' field" "$TMP_DIR/bad-err"; then
  echo "FAIL: broken fixture did not flag the missing description" >&2
  echo "--- check-skills.sh stderr ---" >&2
  cat "$TMP_DIR/bad-err" >&2
  exit 1
fi
if ! grep -q "broken reference 'references/ghost.md'" "$TMP_DIR/bad-err"; then
  echo "FAIL: broken fixture did not flag the broken reference" >&2
  echo "--- check-skills.sh stderr ---" >&2
  cat "$TMP_DIR/bad-err" >&2
  exit 1
fi

echo "PASS: negative self-check — checker exits 1 on broken skill (missing description + broken reference)"
echo "ALL STRUCTURE TESTS PASSED"
