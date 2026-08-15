#!/usr/bin/env bash
#
# check-skills.sh — structural consistency checker for all dev-forge skills
#
# Verifies every skill directory under skills/ (21 × forge-* + using-dev-forge):
#
#   1. Each skill directory contains SKILL.md
#   2. SKILL.md frontmatter declares `name` + `description`; `name` matches
#      the directory name
#   3. `description` starts with "Use when"
#   4. Every path reference in SKILL.md resolves to a real file — both the
#      local form (references/xxx.md) and the cross-skill forms
#      (skills/<name>/references/... and <name>/references/...)
#   5. Cross-references between skills (mentions of forge-* / using-dev-forge)
#      resolve to real skill directories
#   6. The same reference checks run on every file under references/ (a bare
#      references/xxx.md inside a references file is resolved same-skill
#      first, then cross-skill by basename — mirrored files live elsewhere)
#
# Usage:
#   ./scripts/check-skills.sh          # run all checks
#   ./scripts/check-skills.sh --strict # add strict checks (see below)
#   ./scripts/check-skills.sh --help   # show this help
#
# --strict additionally verifies:
#   - the frontmatter block starts on line 1 (file begins with `---`)
#   - every skill has a non-empty references/ directory
#   - every referenced file is non-empty
#
# Exit status: 0 when all checks pass, 1 otherwise. FAIL lines and the failure
# summary go to stderr so the "all N skills OK" line stays machine-parseable on
# stdout (tests/CI assert on exit status + that line).
#
# bash 3.2 (macOS /bin/bash) compatible: no mapfile/readarray, no GNU-only
# tools; `local` declarations are kept at the top of every function.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_DIR="$REPO_ROOT/skills"

STRICT=false
FAIL_COUNT=0

usage() {
  awk 'NR == 1 { next } /^set -euo pipefail$/ { exit } { print }' "$0" | sed 's/^# \{0,1\}//'
}

die() {
  echo "error: $*" >&2
  exit 1
}

# Record one failure. Failures always go to stderr; main() turns the count
# into the exit status and the summary line.
fail() {
  echo "FAIL: $*" >&2
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

# Print the value of the `name:` frontmatter field, or "" when absent.
# Line-1 guard uses the same boundary regex as the closing delimiter so CRLF
# files (`---\r`) parse as frontmatter; values are right-trimmed so CRLF `\r`
# and trailing spaces never false-FAIL (YAML trims both).
frontmatter_name() {
  awk '
    NR == 1 && $0 !~ /^---[[:space:]]*$/ { exit }
    NR == 1 { next }
    /^---[[:space:]]*$/ { exit }
    /^name:[[:space:]]*/ { sub(/^name:[[:space:]]*/, ""); sub(/[[:space:]]+$/, ""); print; exit }
  ' "$1"
}

# Print the value of the `description:` frontmatter field, or "" when absent.
frontmatter_description() {
  awk '
    NR == 1 && $0 !~ /^---[[:space:]]*$/ { exit }
    NR == 1 { next }
    /^---[[:space:]]*$/ { exit }
    /^description:[[:space:]]*/ { sub(/^description:[[:space:]]*/, ""); sub(/[[:space:]]+$/, ""); print; exit }
  ' "$1"
}

# Resolve a path token extracted from a markdown file to the absolute target
# file, or "" when the token does not parse to a known location.
# $1 = token, $2 = skill dir (context), $3 = 1 when the token came from a
# references/ file (enables the cross-skill basename fallback).
ref_target() {
  local token="$1" skill_dir="$2" in_refs="$3"
  local base="" d="" found=""

  case "$token" in
    skills/*)
      # skills/<name>/references/... — resolved from the repo root
      echo "$REPO_ROOT/$token"
      ;;
    forge-*/* | using-dev-forge/*)
      # <name>/references/... — resolved from the skills dir
      echo "$REPO_ROOT/skills/$token"
      ;;
    references/*)
      # references/... — resolved from this skill's dir first
      if [[ -e "$skill_dir/$token" ]]; then
        echo "$skill_dir/$token"
      elif [[ "$in_refs" == 1 ]]; then
        # Inside a references/ file a bare references/xxx.md may point at the
        # canonical copy living in another skill (mirrored files). Fall back
        # to a cross-skill basename lookup.
        base="${token#references/}"
        for d in "$SKILLS_DIR"/*/references; do
          if [[ -e "$d/$base" ]]; then
            found="$d/$base"
            break
          fi
        done
        # `if` (not `&&`) so the function returns 0 even when nothing is
        # found — a failing ref_target would abort the caller under set -e.
        if [[ -n "$found" ]]; then
          echo "$found"
        fi
      fi
      ;;
  esac
}

# Check every path reference inside $1 resolves to a real file.
# $2 = skill dir, $3 = skill name, $4 = 1 when $1 lives inside references/
# (passed through to ref_target to enable the cross-skill fallback).
check_file_refs() {
  local file="$1" skill_dir="$2" name="$3" in_refs="${4:-0}"
  local matches="" match="" lineno="" token="" target=""

  # One combined alternation: the longer forms (skills/... and
  # <name>/references/...) are listed first and consume the whole path, so the
  # bare references/... alternative never re-matches inside them (grep -o
  # yields non-overlapping matches). Glob patterns (forge-*, <name>) do not
  # match at all — `*`/`<` are not part of the path character class.
  matches="$(grep -nEo '(skills/)?(forge-[A-Za-z0-9_-]+|using-dev-forge)/references/[A-Za-z0-9_./-]+|references/[A-Za-z0-9_./-]+' "$file" | sort -u || true)"

  while IFS= read -r match; do
    [[ -n "$match" ]] || continue
    lineno="${match%%:*}"
    token="${match#*:}"
    # A path never ends in an ASCII dot — strip stray sentence punctuation
    # that the greedy character class may have swallowed (glob-safe: removes
    # any run of trailing dots, one at a time).
    while [[ "$token" == *. ]]; do
      token="${token%.}"
    done
    target="$(ref_target "$token" "$skill_dir" "$in_refs" || true)"
    if [[ -z "$target" || ! -e "$target" ]]; then
      fail "$name: $file:$lineno: broken reference '$token' (target file not found)"
      continue
    fi
    if [[ "$STRICT" == true && ! -s "$target" ]]; then
      fail "$name: $file:$lineno: referenced file '$token' is empty (strict)"
    fi
  done <<< "$matches"
}

# Every mention of a forge-* / using-dev-forge skill name must correspond to a
# real skill directory. Globs like `forge-*` never match (the token regex
# requires letters/digits/`-` right after "forge-"), and mentions inside path
# tokens like `forge-x/references/y.md` are real skills anyway.
check_skill_mentions() {
  local file="$1" name="$2"
  local matches="" match="" lineno="" token=""

  matches="$(grep -nEo 'forge-[A-Za-z0-9_-]+|using-dev-forge' "$file" | sort -u || true)"

  while IFS= read -r match; do
    [[ -n "$match" ]] || continue
    lineno="${match%%:*}"
    token="${match#*:}"
    [[ -d "$SKILLS_DIR/$token" ]] || fail "$name: $file:$lineno: references unknown skill '$token' (no skills/$token directory)"
  done <<< "$matches"
}

check_frontmatter() {
  local file="$1" name="$2"
  local fm_name="" fm_desc="" first=""

  fm_name="$(frontmatter_name "$file")"
  fm_desc="$(frontmatter_description "$file")"

  if [[ -z "$fm_name" ]]; then
    fail "$name: $file: frontmatter missing 'name:' field"
  elif [[ "$fm_name" != "$name" ]]; then
    fail "$name: $file: frontmatter name '$fm_name' != directory name '$name'"
  fi

  if [[ -z "$fm_desc" ]]; then
    fail "$name: $file: frontmatter missing 'description:' field"
  elif [[ "$fm_desc" != "Use when"* ]]; then
    fail "$name: $file: frontmatter description must start with 'Use when' (got: '${fm_desc:0:60}')"
  fi

  if [[ "$STRICT" == true ]]; then
    first="$(head -n 1 "$file")"
    # Same boundary regex as the awk frontmatter parsers, so CRLF (`---\r`)
    # does not false-FAIL strict mode.
    [[ "$first" =~ ^---[[:space:]]*$ ]] || fail "$name: $file: frontmatter must start on line 1 (strict)"
  fi
}

check_skill() {
  local dir="$1" name="$2"
  local skill_md="$dir/SKILL.md" ref_dir="$dir/references"
  local rf="" ref_count=""

  if [[ ! -f "$skill_md" ]]; then
    fail "$name: SKILL.md missing (expected $skill_md)"
    return 0
  fi

  check_frontmatter "$skill_md" "$name"
  check_file_refs "$skill_md" "$dir" "$name" 0
  check_skill_mentions "$skill_md" "$name"

  if [[ ! -d "$ref_dir" ]]; then
    if [[ "$STRICT" == true ]]; then
      fail "$name: missing references/ directory (strict)"
    fi
    return 0
  fi

  while IFS= read -r rf; do
    [[ -n "$rf" ]] || continue
    check_file_refs "$rf" "$dir" "$name" 1
    check_skill_mentions "$rf" "$name"
  done < <(find "$ref_dir" -type f -name '*.md' | sort)

  if [[ "$STRICT" == true ]]; then
    ref_count="$(find "$ref_dir" -type f | wc -l | tr -d ' ')"
    [[ "$ref_count" -gt 0 ]] || fail "$name: references/ directory is empty (strict)"
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --strict)
        STRICT=true
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      --)
        break
        ;;
      -*)
        die "unknown option: $1"
        ;;
      *)
        die "unexpected argument: $1"
        ;;
    esac
    shift
  done
}

main() {
  parse_args "$@"

  [[ -d "$SKILLS_DIR" ]] || die "skills directory not found: $SKILLS_DIR"

  local skills=()
  local dir="" name=""
  for dir in "$SKILLS_DIR"/*/; do
    [[ -d "$dir" ]] || continue
    name="$(basename "$dir")"
    skills+=("$name")
  done

  if [[ ${#skills[@]} -eq 0 ]]; then
    die "no skill directories found under $SKILLS_DIR"
  fi

  for name in "${skills[@]}"; do
    check_skill "$SKILLS_DIR/$name" "$name"
  done

  if [[ "$FAIL_COUNT" -gt 0 ]]; then
    echo "check-skills: $FAIL_COUNT failure(s)" >&2
    exit 1
  fi
  echo "check-skills: all ${#skills[@]} skills OK"
}

main "$@"
