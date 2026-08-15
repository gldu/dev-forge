#!/usr/bin/env bash
#
# test-install.sh — verifies scripts/install.sh (commit 6b33e30, the real CLI:
# --global / --project modes + --platform) inside isolated mktemp dirs. The
# real repo and the real user environment are never written to.
#
# Coverage:
#   * project mode, default shared path (.agents/skills) — 22 symlinks
#     (21 forge-* + using-dev-forge), relative targets, and PHYSICAL
#     resolution via cd -P / pwd -P (the guard that historical install.sh /
#     sync-to-local.sh runs were FAILed on: macOS /var -> /private/var
#     symlinked root silently dangles text-counted relative links while
#     `[[ -L ]]` still passes).
#   * idempotency — a second run re-links in place: still 22 symlinks, no
#     nesting (guards the macOS `ln -sfn` silent-nest regression).
#   * project mode, --platform claude -> .claude/skills (platform-specific
#     path from the README installation table).
#   * global mode with a fake $HOME -> $FAKE_HOME/.claude/skills (absolute
#     targets into the real repo's skills/).
#   * negatives — unknown platform and empty --platform must exit non-zero.
#
# bash 3.2.57 (macOS /bin/bash) compatible AND Linux (ubuntu-latest, P3.3 CI)
# compatible: no mapfile, no GNU-only tools, mktemp under ${TMPDIR:-/tmp}.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INSTALLER="$REPO_ROOT/scripts/install.sh"

PASS_COUNT=0
FAIL_COUNT=0
TMP_DIR=""
TMP_REPO=""
FAKE_HOME=""
SKILLS_SRC=""
EXPECTED_COUNT=""

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

# Physical path of a directory, resolving every symlink on the way
# (the cd -P / pwd -P guard from sync-to-local.sh). Returns non-zero and
# prints nothing when $1 does not exist / does not resolve.
physical() {
  local p="$1"
  ( cd -P "$p" && pwd -P )
}

# Assert every dev-forge skill is a symlink under $1 that physically resolves
# to the matching directory under $2, that the count matches EXPECTED_COUNT,
# and that no nested same-name entry exists. $3 = 1 when link targets are
# expected to be RELATIVE (project mode), 0 for absolute (global mode).
# Emits a diagnostic per problem.
assert_links() {
  local dest="$1" skills_src="$2" expect_relative="$3"
  local count=0 name="" real="" expected="" rl="" d=""

  for d in "$skills_src"/forge-* "$skills_src"/using-dev-forge; do
    [[ -d "$d" ]] || continue
    name="$(basename "$d")"

    if [[ ! -L "$dest/$name" ]]; then
      echo "expected symlink but found: $dest/$name" >&2
      return 1
    fi
    count=$((count + 1))

    if ! real="$(physical "$dest/$name" 2>/dev/null)"; then
      echo "dangling or unresolvable link: $dest/$name (target: $(readlink "$dest/$name" 2>/dev/null || echo '<none>'))" >&2
      return 1
    fi
    if ! expected="$(physical "$skills_src/$name" 2>/dev/null)"; then
      echo "skills source does not resolve: $skills_src/$name" >&2
      return 1
    fi
    if [[ "$real" != "$expected" ]]; then
      echo "link $dest/$name resolves to '$real' but expected '$expected'" >&2
      return 1
    fi

    if [[ -e "$dest/$name/$name" ]]; then
      echo "nested same-name entry (macOS ln -sfn nest bug): $dest/$name/$name" >&2
      return 1
    fi
  done

  if [[ "$count" -ne "$EXPECTED_COUNT" ]]; then
    echo "expected $EXPECTED_COUNT links in $dest, found $count" >&2
    return 1
  fi

  # Project-mode link targets must be relative (relative links survive repo
  # moves / CI checkouts); global mode uses absolute targets.
  rl="$(readlink "$dest/using-dev-forge" 2>/dev/null || true)"
  if [[ "$expect_relative" == 1 && -n "$rl" && "$rl" == /* ]]; then
    echo "project link target is absolute (expected relative): $dest/using-dev-forge -> $rl" >&2
    return 1
  fi

  return 0
}

# Runner: run a command, count pass/fail, print captured diagnostics indented.
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

# --- project mode, default shared path ---

run_project_default() {
  local dest="$TMP_REPO/.agents/skills"
  if ! "$TMP_REPO/scripts/install.sh" --project > "$TMP_DIR/proj1.log" 2>&1; then
    echo "install.sh --project exited non-zero; log:" >&2
    cat "$TMP_DIR/proj1.log" >&2
    return 1
  fi
  if ! grep -q "linked ${EXPECTED_COUNT} skills" "$TMP_DIR/proj1.log"; then
    echo "install.sh output missing 'linked ${EXPECTED_COUNT} skills'; log:" >&2
    cat "$TMP_DIR/proj1.log" >&2
    return 1
  fi
  assert_links "$dest" "$SKILLS_SRC" 1 || return 1
  return 0
}

# --- idempotency ---

run_project_idempotent() {
  local dest="$TMP_REPO/.agents/skills"
  if ! "$TMP_REPO/scripts/install.sh" --project > "$TMP_DIR/proj2.log" 2>&1; then
    echo "second install.sh --project exited non-zero; log:" >&2
    cat "$TMP_DIR/proj2.log" >&2
    return 1
  fi
  assert_links "$dest" "$SKILLS_SRC" 1 || return 1
  return 0
}

# --- project mode, platform-specific path ---

run_project_claude() {
  local dest="$TMP_REPO/.claude/skills"
  if ! "$TMP_REPO/scripts/install.sh" --project --platform claude > "$TMP_DIR/proj-claude.log" 2>&1; then
    echo "install.sh --project --platform claude exited non-zero; log:" >&2
    cat "$TMP_DIR/proj-claude.log" >&2
    return 1
  fi
  assert_links "$dest" "$SKILLS_SRC" 1 || return 1
  return 0
}

# --- global mode with fake HOME ---

run_global_claude() {
  local dest="$FAKE_HOME/.claude/skills"
  # Global mode installs under $HOME; a fake HOME keeps the real user env
  # untouched. Targets are absolute (real repo skills/).
  if ! env HOME="$FAKE_HOME" "$INSTALLER" --global --platform claude > "$TMP_DIR/global.log" 2>&1; then
    echo "install.sh --global --platform claude exited non-zero; log:" >&2
    cat "$TMP_DIR/global.log" >&2
    return 1
  fi
  assert_links "$dest" "$REPO_ROOT/skills" 0 || return 1
  return 0
}

# --- negatives ---

run_negative_unknown_platform() {
  if "$TMP_REPO/scripts/install.sh" --project --platform bogus > "$TMP_DIR/neg1.log" 2>&1; then
    echo "expected non-zero exit for unknown platform, got 0" >&2
    return 1
  fi
  return 0
}

run_negative_empty_platform() {
  if "$TMP_REPO/scripts/install.sh" --project --platform "" > "$TMP_DIR/neg2.log" 2>&1; then
    echo "expected non-zero exit for empty --platform, got 0" >&2
    return 1
  fi
  return 0
}

# --- setup: isolated temp repo copy + fake HOME ---

[[ -f "$INSTALLER" ]] || die "install.sh not found: $INSTALLER"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/df-install-test.XXXXXX")"
TMP_REPO="$TMP_DIR/repo"
FAKE_HOME="$TMP_DIR/fake-home"
mkdir -p "$TMP_REPO" "$FAKE_HOME"

# install.sh locates its repo by walking up from its own location and probing
# for the skills/ signature, so a temp copy of scripts/ + skills/ is a fully
# valid install target. The real repo is only READ for the global test.
cp -R "$REPO_ROOT/scripts" "$REPO_ROOT/skills" "$TMP_REPO/"

SKILLS_SRC="$TMP_REPO/skills"
EXPECTED_COUNT="$(ls -d "$SKILLS_SRC"/forge-* "$SKILLS_SRC"/using-dev-forge 2>/dev/null | wc -l | tr -d ' ')"
[[ "$EXPECTED_COUNT" -gt 0 ]] || die "no skills found in temp repo copy: $SKILLS_SRC"

# --- run the checks ---

check "project install (default .agents/skills) creates $EXPECTED_COUNT resolving symlinks" \
  run_project_default

check "project re-run is idempotent (still $EXPECTED_COUNT links, no nesting)" \
  run_project_idempotent

check "project install --platform claude links into .claude/skills" \
  run_project_claude

check "global install (fake HOME) links into .claude/skills" \
  run_global_claude

check "unknown platform exits non-zero" \
  run_negative_unknown_platform

check "empty --platform exits non-zero" \
  run_negative_empty_platform

# --- summary ---

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo "INSTALL TESTS: $FAIL_COUNT failure(s), $PASS_COUNT passed" >&2
  exit 1
fi
echo "PASS: all $PASS_COUNT install checks passed"
echo "ALL INSTALL TESTS PASSED"
