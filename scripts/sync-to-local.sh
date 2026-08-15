#!/usr/bin/env bash
#
# sync-to-local.sh — re-sync dev-forge skills/ into a target directory.
#
# Usage:
#   ./scripts/sync-to-local.sh <target-dir>            # symlink skills/ into target
#   ./scripts/sync-to-local.sh <target-dir> --dry-run  # print the links that would run
#   ./scripts/sync-to-local.sh <target-dir> --absolute # link with absolute targets
#   ./scripts/sync-to-local.sh <target-dir> --list     # count already-linked skills
#   ./scripts/sync-to-local.sh --help                  # show this help
#
# The companion to install.sh for after a `git pull`: install.sh creates the
# links once; sync-to-local.sh re-creates them so the target keeps pointing at
# the fresh checkout. Default link targets are relative (they survive repo
# clones and CI checkouts); pass --absolute when the target lives outside this
# repo — in particular when it is reached through a symlinked root (macOS
# /var -> /private/var, /tmp -> /private/tmp), where no relative path exists.
#
# Inherits install.sh's hardened patterns: refuses to overwrite a real
# directory that shares a skill name (macOS `ln -sfn` would silently nest a
# same-named symlink inside it) and self-checks every link after creation.
#
set -euo pipefail

# Companion tool that ships inside the repo (scripts/ next to skills/) — the
# root is always one level up; no install.sh-style signature walk-up needed.
# (M3: deliberately kept simple — this script is only ever run from a checkout.)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_SRC="$REPO_ROOT/skills"

DRY_RUN=false
USE_ABSOLUTE=false
SHOW_LIST=false
TARGET=""

usage() {
  awk 'NR == 1 { next } /^set -euo pipefail$/ { exit } { print }' "$0" | sed 's/^# \{0,1\}//'
}

die() {
  echo "error: $*" >&2
  exit 1
}

# Print the path from directory $1 to $SKILLS_SRC in relative form, so
# symlinks use relative targets that survive repo clones and CI checkouts.
# Pure bash — no GNU realpath needed. Mirrors scripts/install.sh. (I3)
relative_target() {
  local from="$1"
  local to="$SKILLS_SRC"
  local from_parts to_parts
  local common=0 i="" up="" rest=""
  local IFS='/'
  from="${from%/}"
  to="${to%/}"
  read -r -a from_parts <<< "${from#/}"
  read -r -a to_parts <<< "${to#/}"
  while [[ $common -lt ${#from_parts[@]} && $common -lt ${#to_parts[@]} && "${from_parts[$common]}" == "${to_parts[$common]}" ]]; do
    common=$((common + 1))
  done
  i=$common
  while [[ $i -lt ${#from_parts[@]} ]]; do
    up="${up}../"
    i=$((i + 1))
  done
  i=$common
  while [[ $i -lt ${#to_parts[@]} ]]; do
    rest="${rest}${to_parts[$i]}"
    i=$((i + 1))
    [[ $i -lt ${#to_parts[@]} ]] && rest="${rest}/"
  done
  echo "${up}${rest}"
}

# Re-link every dev-forge skill (forge-* + using-dev-forge) into $target.
sync_skills() {
  local target="$1"
  local count=0 d name link_target="" target_abs=""

  if [[ ! -d "$SKILLS_SRC" ]]; then
    die "skills directory not found: $SKILLS_SRC"
  fi

  if [[ "$DRY_RUN" != true ]]; then
    mkdir -p "$target" || die "could not create target directory: $target"
  fi
  # Normalize to an absolute path so relative targets are computed against
  # the real location (handles '.' / '..' in the argument). A missing target
  # is fatal even under --dry-run — the preview would be fabricated (I1).
  if ! target_abs="$(cd "$target" 2>&1 && pwd)"; then
    die "target directory does not exist (and --dry-run does not create it): $target"
  fi
  target="$target_abs"

  # M1/M2: never sync into the skills source directory or one of its
  # subdirectories — the links would point at themselves or a parent.
  if [[ "$target" == "$SKILLS_SRC" || "$target" == "$SKILLS_SRC/"* ]]; then
    die "refusing to sync into the skills source directory (or a subdirectory): $target"
  fi

  if [[ "$USE_ABSOLUTE" == true ]]; then
    link_target="$SKILLS_SRC"
  else
    link_target="$(relative_target "$target")"
    # C1: relative targets are only valid when a PHYSICAL walk from $target
    # through $link_target lands on $SKILLS_SRC. Text-counting `../` breaks
    # under symlinked roots (macOS /var -> /private/var, /tmp -> /private/tmp):
    # every link would silently dangle while `[[ -L ]]` still passes. The -P
    # flags are load-bearing: plain (logical) cd resolves `..` against the
    # textual $PWD and misses this — verified false negative on bash 3.2.57.
    if ! ( cd -P "$target" && cd -P "$link_target" 2>/dev/null &&
           [[ "$(pwd -P)" == "$(cd -P "$SKILLS_SRC" && pwd -P)" ]] ); then
      die "cannot express $SKILLS_SRC relative to $target (symlinked path on macOS); use --absolute"
    fi
  fi

  for d in "$SKILLS_SRC"/forge-* "$SKILLS_SRC"/using-dev-forge; do
    [[ -d "$d" ]] || continue
    name="$(basename "$d")"
    # C1: macOS `ln -sfn` silently nests a same-named real directory instead
    # of failing — refuse it up front. Existing symlinks pass through, so
    # idempotent re-runs are unaffected.
    if [[ -e "$target/$name" && ! -L "$target/$name" ]]; then
      die "refusing to overwrite existing non-symlink '$target/$name' (real file/dir); move it aside first"
    fi
    if [[ "$DRY_RUN" == true ]]; then
      printf 'ln -sfn %s/%s %s/%s\n' "$link_target" "$name" "$target" "$name"
    else
      ln -sfn "$link_target/$name" "$target/$name" || die "failed to link '$link_target/$name' -> '$target/$name'"
      # M5: post-link self-check — the entry must be a symlink AND resolve.
      # The -e test follows the link with kernel semantics, so a dangling
      # relative link can never pass (defense in depth for C1).
      [[ -L "$target/$name" ]] || die "self-check failed: '$target/$name' is not a symlink after sync"
      [[ -e "$target/$name" ]] || die "self-check failed: '$target/$name' is a DANGLING link (relative base '$link_target' does not resolve); use --absolute"
    fi
    count=$((count + 1))
  done

  if [[ "$DRY_RUN" == true ]]; then
    echo "dry-run: would link ${count} skills -> $target"
  else
    echo "synced ${count} skills -> $target"
  fi
}

# Count dev-forge skills already linked in $target (idempotency / sanity check).
list_linked() {
  local target="$1"
  local linked=0 total=0
  local d name

  if [[ ! -d "$target" ]]; then
    echo "no dev-forge skills linked in $target (target directory does not exist)"
    return 0
  fi

  for d in "$SKILLS_SRC"/forge-* "$SKILLS_SRC"/using-dev-forge; do
    [[ -d "$d" ]] || continue
    total=$((total + 1))
    name="$(basename "$d")"
    if [[ -L "$target/$name" ]]; then
      linked=$((linked + 1))
    fi
  done

  echo "${linked}/${total} dev-forge skills linked in $target"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        DRY_RUN=true
        ;;
      --absolute)
        USE_ABSOLUTE=true
        ;;
      --list)
        SHOW_LIST=true
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      -*)
        die "unknown option: $1 (see --help)"
        ;;
      *)
        if [[ -n "$TARGET" ]]; then
          die "unexpected argument: $1 (only one target directory is allowed)"
        fi
        TARGET="$1"
        ;;
    esac
    shift
  done
}

main() {
  parse_args "$@"

  if [[ "$SHOW_LIST" == true ]]; then
    if [[ -z "$TARGET" ]]; then
      usage
      exit 1
    fi
    list_linked "$TARGET"
    exit 0
  fi

  if [[ -z "$TARGET" ]]; then
    usage
    exit 1
  fi

  sync_skills "$TARGET"
}

main "$@"
