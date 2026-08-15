#!/usr/bin/env bash
#
# test-references.sh — independent verification that every path reference in
# every SKILL.md (and every references/*.md file) resolves to a real file.
#
# This is a from-scratch re-implementation of the reference-resolution
# semantics documented in scripts/check-skills.sh (same token forms and
# resolution order), so a future regression in the checker's own reference
# logic is caught here — double insurance next to test-structure.sh.
#
# Resolution semantics (mirroring scripts/check-skills.sh — keep in sync:
# ref_target at check-skills.sh L89-125, check_file_refs at L130-160; the
# synthetic-corpus cross-check in verify_corpus() below re-runs BOTH this
# mirror and the real checker over the same fixture and fails on any drift):
#   skills/<name>/references/...   -> repo root
#   <name>/references/...          -> skills dir
#   references/... in a SKILL.md   -> this skill's dir (no fallback)
#   references/... in a references file -> this skill's dir first, then a
#                                          cross-skill basename fallback
#
# bash 3.2.57 (macOS /bin/bash) compatible; no external dependencies.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILLS_DIR="$REPO_ROOT/skills"
CHECKER="$REPO_ROOT/scripts/check-skills.sh"

FAIL_COUNT=0
CHECKED=0
TMP_DIR=""

trap 'rm -rf "${TMP_DIR:-}"' EXIT

die() {
  echo "error: $*" >&2
  exit 1
}

fail() {
  echo "FAIL: $*" >&2
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

# M8: this test takes no arguments — reject any with a clear message.
[[ $# -eq 0 ]] || die "unexpected argument(s): $*"

[[ -d "$SKILLS_DIR" ]] || die "skills directory not found: $SKILLS_DIR"
[[ -f "$CHECKER" ]] || die "check-skills.sh not found: $CHECKER"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/df-refs-test.XXXXXX")"

# Resolve a path token to the absolute target file ("" when unknown).
# $1 = token, $2 = skill dir, $3 = in_refs (1 when token came from a
# references/ file, enabling the cross-skill basename fallback).
ref_target() {
  local token="$1" skill_dir="$2" in_refs="$3"
  local base="" d=""

  case "$token" in
    skills/*)
      echo "$REPO_ROOT/$token"
      ;;
    forge-*/* | using-dev-forge/*)
      echo "$SKILLS_DIR/$token"
      ;;
    references/*)
      if [[ -e "$skill_dir/$token" ]]; then
        echo "$skill_dir/$token"
      elif [[ "$in_refs" == 1 ]]; then
        base="${token#references/}"
        for d in "$SKILLS_DIR"/*/references; do
          if [[ -e "$d/$base" ]]; then
            echo "$d/$base"
            return 0
          fi
        done
      fi
      ;;
  esac
}

# Check every path reference inside $1.
check_file_refs() {
  local file="$1" skill_dir="$2" name="$3" in_refs="${4:-0}"
  local matches="" match="" lineno="" token="" target=""
  local ref_dir=""

  matches="$(grep -nEo '(skills/)?(forge-[A-Za-z0-9_-]+|using-dev-forge)/references/[A-Za-z0-9_./-]+|references/[A-Za-z0-9_./-]+' "$file" | sort -u || true)"

  while IFS= read -r match; do
    [[ -n "$match" ]] || continue
    lineno="${match%%:*}"
    token="${match#*:}"
    # A path never ends in an ASCII dot — strip stray sentence punctuation.
    while [[ "$token" == *. ]]; do
      token="${token%.}"
    done
    target="$(ref_target "$token" "$skill_dir" "$in_refs")"
    if [[ -z "$target" || ! -e "$target" ]]; then
      ref_dir="$(dirname "$file")"
      fail "$name: $ref_dir/$(basename "$file"):$lineno: broken reference '$token'"
    fi
  done <<< "$matches"
}

# Check every SKILL.md (and every references/*.md) under the skills dir
# currently pointed at by $SKILLS_DIR. Mirrors the checker's per-skill loop.
run_checks() {
  local dir="" name="" skill_md="" rf=""
  for dir in "$SKILLS_DIR"/*/; do
    [[ -d "$dir" ]] || continue
    name="$(basename "$dir")"
    skill_md="$dir/SKILL.md"

    if [[ ! -f "$skill_md" ]]; then
      fail "$name: SKILL.md missing"
      continue
    fi
    check_file_refs "$skill_md" "$dir" "$name" 0
    CHECKED=$((CHECKED + 1))

    if [[ -d "$dir/references" ]]; then
      while IFS= read -r rf; do
        [[ -n "$rf" ]] || continue
        check_file_refs "$rf" "$dir" "$name" 1
      done < <(find "$dir/references" -type f -name '*.md' | sort)
    fi
  done
}

# I2 — synthetic-corpus cross-check. Builds a small skills/ tree whose ONLY
# broken reference is `references/missing.md`, then runs BOTH this script's
# resolution logic and the real check-skills.sh against it and asserts both
# report the same broken-reference tokens. If the checker's ref_target /
# check_file_refs semantics drift away from the mirror here, the suite fails.
#
# KEEP IN SYNC with scripts/check-skills.sh:
#   ref_target      -> check-skills.sh L89-125
#   check_file_refs -> check-skills.sh L130-160
verify_corpus() {
  local corpus="$TMP_DIR/corpus"
  local self_err="$TMP_DIR/corpus-self.err"
  local checker_err="$TMP_DIR/corpus-checker.err"
  local expected="broken reference 'references/missing.md'"
  local self_tokens="" checker_tokens=""

  mkdir -p "$corpus/scripts" \
    "$corpus/skills/forge-a/references" \
    "$corpus/skills/forge-b/references"
  cp "$CHECKER" "$corpus/scripts/check-skills.sh"

  # Token coverage:
  #   references/own.md                    (same-skill)
  #   forge-b/references/shared.md         (cross-skill <name> form)
  #   skills/forge-b/references/shared.md  (repo-root form)
  #   references/shared.md in a refs file  (cross-skill basename fallback)
  #   references/missing.md                (broken — the only expected FAIL)
  cat > "$corpus/skills/forge-a/SKILL.md" <<'EOF'
---
name: forge-a
description: Use when testing corpus reference resolution
---
Uses references/own.md, forge-b/references/shared.md,
skills/forge-b/references/shared.md and references/missing.md
EOF
  cat > "$corpus/skills/forge-a/references/own.md" <<'EOF'
# own
See references/own.md and references/shared.md
EOF
  cat > "$corpus/skills/forge-b/SKILL.md" <<'EOF'
---
name: forge-b
description: Use when testing corpus reference resolution
---
Uses references/shared.md
EOF
  echo "# shared" > "$corpus/skills/forge-b/references/shared.md"

  # This script's own resolution logic, repointed at the corpus.
  (
    REPO_ROOT="$corpus"
    SKILLS_DIR="$corpus/skills"
    # Intentional: run_checks reuses the global counter names inside this
    # subshell so it needs no parameterization; the outer real-repo run's
    # FAIL_COUNT/CHECKED (read in the summary below) are never touched.
    # shellcheck disable=SC2030
    FAIL_COUNT=0
    # shellcheck disable=SC2030
    CHECKED=0
    run_checks
  ) >/dev/null 2> "$self_err"

  # The real checker against the same corpus — must exit 1 (one broken ref).
  if "$corpus/scripts/check-skills.sh" >/dev/null 2> "$checker_err"; then
    echo "FAIL: check-skills.sh exited 0 on the broken corpus (expected 1)" >&2
    return 1
  fi

  self_tokens="$(grep -o "broken reference '[^']*'" "$self_err" | sort -u || true)"
  checker_tokens="$(grep -o "broken reference '[^']*'" "$checker_err" | sort -u || true)"

  if [[ "$self_tokens" != "$expected" ]]; then
    echo "FAIL: mirror logic reported '$self_tokens' (expected '$expected')" >&2
    echo "--- mirror stderr ---" >&2
    cat "$self_err" >&2
    return 1
  fi
  if [[ "$checker_tokens" != "$expected" ]]; then
    echo "FAIL: check-skills.sh reported '$checker_tokens' (expected '$expected')" >&2
    echo "--- check-skills.sh stderr ---" >&2
    cat "$checker_err" >&2
    return 1
  fi
  if [[ "$self_tokens" != "$checker_tokens" ]]; then
    echo "FAIL: mirror and check-skills.sh disagree on broken references" >&2
    echo "--- mirror stderr ---" >&2
    cat "$self_err" >&2
    echo "--- check-skills.sh stderr ---" >&2
    cat "$checker_err" >&2
    return 1
  fi

  echo "PASS: corpus cross-check — mirror and check-skills.sh agree on the broken reference"
  return 0
}

# --- real repo (primary regression net) ---

run_checks

# shellcheck disable=SC2031  # outer real-repo counters; the corpus subshell's copies are local (see verify_corpus)
if [[ "$FAIL_COUNT" -gt 0 ]]; then
  # shellcheck disable=SC2031
  echo "REFERENCES TESTS: $FAIL_COUNT failure(s), $CHECKED skills checked" >&2
  exit 1
fi
# shellcheck disable=SC2031
echo "PASS: $CHECKED skills checked, all reference paths resolve"

# --- I2: mirror-vs-checker cross-check on a synthetic corpus ---

verify_corpus || exit 1

echo "ALL REFERENCES TESTS PASSED"
