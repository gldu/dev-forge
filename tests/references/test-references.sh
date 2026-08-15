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
# Resolution semantics (mirroring scripts/check-skills.sh):
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

FAIL_COUNT=0
CHECKED=0

fail() {
  echo "FAIL: $*" >&2
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

[[ -d "$SKILLS_DIR" ]] || { echo "error: skills directory not found: $SKILLS_DIR" >&2; exit 1; }

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

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo "REFERENCES TESTS: $FAIL_COUNT failure(s), $CHECKED skills checked" >&2
  exit 1
fi
echo "PASS: $CHECKED skills checked, all reference paths resolve"
echo "ALL REFERENCES TESTS PASSED"
