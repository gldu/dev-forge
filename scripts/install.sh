#!/usr/bin/env bash
#
# install.sh — one-command installer for dev-forge (skills + platform manifests)
#
# Usage:
#   ./scripts/install.sh                 # auto-detect platform, install globally
#   ./scripts/install.sh --global        # user-level install (default)
#   ./scripts/install.sh --project       # project-level install (.agents/skills/)
#   ./scripts/install.sh --platform NAME # target a specific platform
#   ./scripts/install.sh --list          # list installable platforms
#   ./scripts/install.sh --help          # show this help
#
# Auto-detects the platform from environment variables:
#   CLAUDE_PLUGIN_ROOT / CURSOR_PLUGIN_ROOT / COPILOT_CLI / OPENCODE_CONFIG_DIR
# Falls back to an interactive numbered menu when none can be detected.
#
# Skill paths follow the README installation table. Global paths live under
# $HOME; project paths are written relative to this repo (symlinks use
# relative targets so they survive repo clones / CI checkouts).
#
# This script links BOTH forge-* skills and using-dev-forge — one skill
# beyond the README "Option 1" snippet (forge-* only); the script is the
# source of truth.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Locate the repo root by walking up from SCRIPT_DIR. A candidate is only
# accepted if its skills/ dir carries the dev-forge signature (forge-* or
# using-dev-forge) — a bare skills/ in an unrelated ancestor repo must not be
# silently linked (nested-repo misdetection). (I4)
REPO_ROOT=""
_candidate_dir="$SCRIPT_DIR"
_has_sig=""
for _depth in 1 2 3 4 5; do
  if [[ -d "$_candidate_dir/skills" ]]; then
    _has_sig=""
    for _sig in "$_candidate_dir"/skills/forge-* "$_candidate_dir"/skills/using-dev-forge; do
      if [[ -d "$_sig" ]]; then
        _has_sig=1
        break
      fi
    done
    if [[ -n "$_has_sig" ]]; then
      REPO_ROOT="$_candidate_dir"
      break
    fi
  fi
  [[ "$_candidate_dir" == "/" ]] && break
  _candidate_dir="$(dirname "$_candidate_dir")"
done
if [[ -z "$REPO_ROOT" ]]; then
  echo "error: could not locate this repo's 'skills/' directory; install.sh must live inside the dev-forge repo (e.g. <repo>/scripts/install.sh)" >&2
  exit 1
fi
SKILLS_SRC="$REPO_ROOT/skills"

# org placeholder — replace <org> with the real GitHub org before publishing
ORG_PLACEHOLDER="<org>"

MODE="global"
PLATFORM=""
SHOW_LIST=false

usage() {
  awk 'NR == 1 { next } /^set -euo pipefail$/ { exit } { print }' "$0" | sed 's/^# \{0,1\}//'
}

die() {
  echo "error: $*" >&2
  exit 1
}

valid_platform() {
  case "$1" in
    claude | codex | lingma | antigravity | opencode | pi | cursor | copilot | devin | kimi | hermes | gemini | grok)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Global (user-level) skill path per platform, relative to $HOME.
# Source of truth: README "## Installation" table.
global_skills_path() {
  case "$1" in
    claude)
      # Claude Code
      echo ".claude/skills"
      ;;
    codex)
      # Codex CLI — primary path is ~/.agents/skills; legacy ~/.codex/skills is
      # still read by older CLI versions but deprecated, so we always link here.
      echo ".agents/skills"
      ;;
    lingma)
      echo ".lingma/skills"
      ;;
    antigravity)
      # unified across AGY / IDE / CLI
      echo ".gemini/config/skills"
      ;;
    opencode)
      echo ".config/opencode/skills"
      ;;
    pi)
      echo ".pi/agent/skills"
      ;;
    grok)
      # Grok Build TUI — also reads ~/.agents/skills
      echo ".grok/skills"
      ;;
    *)
      # cursor / copilot / devin / kimi / hermes / gemini have no standard
      # global skills load path — manifest-only registration.
      echo ""
      ;;
  esac
}

# Project-level skill path per platform, relative to the repo this script
# ships in. Source of truth: README "## Installation" table.
project_skills_path() {
  case "$1" in
    claude)
      echo ".claude/skills"
      ;;
    codex)
      echo ".agents/skills"
      ;;
    lingma)
      echo ".lingma/skills"
      ;;
    antigravity)
      # workspace root; backward-compatible with .agent/skills
      echo ".agents/skills"
      ;;
    opencode)
      echo ".opencode/skills"
      ;;
    pi)
      echo ".pi/skills"
      ;;
    grok)
      echo ".grok/skills"
      ;;
    *)
      echo ""
      ;;
  esac
}

# Print the path from directory $1 to $SKILLS_SRC in relative form, so
# project-mode symlinks use relative targets (they survive repo clones and CI
# checkouts). Pure bash — no GNU realpath needed. (I3)
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

# Symlink every skill directory (forge-* + using-dev-forge) into $dest.
# Symlinks keep the installed skills in sync with the repo. Single loop over
# a glob list instead of two copy-pasted loops (M8). NOTE: this script also
# links using-dev-forge, which the README "Option 1" snippet does not show
# (M7 — README is handled separately; the script is the source of truth).
#
# $2 is the link-target base: absolute $SKILLS_SRC in global mode, a relative
# path in project mode (I3).
install_skills() {
  local dest="$1" base="$2"
  local count=0 d name

  if [[ ! -d "$SKILLS_SRC" ]]; then
    die "skills directory not found: $SKILLS_SRC"
  fi

  mkdir -p "$dest"

  for d in "$SKILLS_SRC"/forge-* "$SKILLS_SRC"/using-dev-forge; do
    [[ -d "$d" ]] || continue
    name="$(basename "$d")"
    # C1: macOS `ln -sfn` silently nests a same-named real directory instead
    # of failing — refuse it up front. Existing symlinks pass through, so
    # idempotent re-runs are unaffected.
    if [[ -e "$dest/$name" && ! -L "$dest/$name" ]]; then
      die "refusing to overwrite existing non-symlink '$dest/$name' (real file/dir); move it aside first"
    fi
    ln -sfn "$base/$name" "$dest/$name" || die "failed to link '$base/$name' -> '$dest/$name'"
    # M5: post-install self-check — the entry must actually be a symlink now.
    [[ -L "$dest/$name" ]] || die "self-check failed: '$dest/$name' is not a symlink after install"
    count=$((count + 1))
  done

  echo "  linked $count skills -> $dest"
  echo "  (symlinks into $SKILLS_SRC — stays in sync with the repo)"
}

detect_platform() {
  if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
    echo "claude"
    return 0
  fi
  if [[ -n "${CURSOR_PLUGIN_ROOT:-}" ]]; then
    echo "cursor"
    return 0
  fi
  if [[ -n "${COPILOT_CLI:-}" ]]; then
    echo "copilot"
    return 0
  fi
  if [[ -n "${OPENCODE_CONFIG_DIR:-}" ]]; then
    echo "opencode"
    return 0
  fi
  if [[ -t 0 ]]; then
    interactive_platform_menu
  else
    # M2: no stderr echo here — main() reports the final error via || die
    return 1
  fi
}

# Interactive numbered menu; prompts go to stderr so the platform name is the
# only thing printed on stdout (detect_platform is called in $(...)).
interactive_platform_menu() {
  local platforms=(claude codex lingma antigravity opencode pi grok cursor copilot)
  local last="${#platforms[@]}"
  local i=1
  local p
  local choice=""

  echo "No platform auto-detected from environment; choose one:" >&2
  for p in "${platforms[@]}"; do
    printf '  %2d) %s\n' "$i" "$p" >&2
    i=$((i + 1))
  done
  printf '  %2d) quit\n' "$((last + 1))" >&2
  printf 'Select [1-%d]: ' "$((last + 1))" >&2
  IFS= read -r choice

  # M3: "quit" is a clean, explicit abort — sentinel handled in main(), so it
  # never falls through to the "could not auto-detect platform" error path.
  if [[ "$choice" == "quit" ]] || [[ "$choice" == "$((last + 1))" ]]; then
    echo "__dev_forge_quit__"
    return 0
  fi

  if [[ ! "$choice" =~ ^[0-9]+$ ]] || ((choice < 1 || choice > last)); then
    echo "invalid selection" >&2
    echo ""
    return 1
  fi
  echo "${platforms[$((choice - 1))]}"
}

# Copy the opencode plugin into the target opencode plugins dir.
# Never aborts the install if the copy fails — skills are the primary payload.
# The destination honours OPENCODE_CONFIG_DIR when set (I2); there is no
# caller-supplied override (the sole call site never passes one).
install_opencode_plugin() {
  local dest="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}/plugins"
  local src="$REPO_ROOT/.opencode/plugins/dev-forge.js"

  if [[ ! -f "$src" ]]; then
    echo "  [manifest] opencode plugin source not found: $src (skipping)"
    return 0
  fi

  if mkdir -p "$dest" && cp "$src" "$dest/dev-forge.js"; then
    echo "  [manifest] opencode plugin installed -> $dest/dev-forge.js"
  else
    echo "  [warn] could not copy opencode plugin to $dest (skipping, install continues)"
  fi
}

manifest_path() {
  case "$1" in
    devin) echo ".devin-plugin/plugin.json" ;;
    kimi) echo ".kimi-plugin/plugin.json" ;;
    hermes) echo ".hermes-plugin/plugin.yaml" ;;
    pi) echo ".pi/extensions/dev-forge.ts" ;;
    gemini) echo "gemini-extension.json" ;;
    cursor) echo ".cursor-plugin/plugin.json" ;;
    copilot) echo "" ;; # M1: no in-repo manifest yet — return nothing, never a path
  esac
}

# Register / point at the platform manifest. Global mode only — project
# installs ship the manifests in-repo already.
manifest_registration() {
  case "$1" in
    claude)
      echo ""
      echo "  [manifest] Claude Code plugin marketplace:"
      if [[ "$ORG_PLACEHOLDER" == "<org>" ]]; then
        echo "  [warn] ORG_PLACEHOLDER still contains the literal '<org>' — edit scripts/install.sh before publishing"
      fi
      echo "    claude plugin marketplace add ${ORG_PLACEHOLDER}/dev-forge"
      echo "    claude plugin install dev-forge"
      echo "    (hooks ship with the plugin; source: .claude-plugin/marketplace.json)"
      ;;
    cursor)
      echo ""
      echo "  [manifest] Cursor plugin: copy .cursor-plugin/ into ~/.cursor/plugins/"
      echo "    mkdir -p ~/.cursor/plugins && cp -R \"$REPO_ROOT/.cursor-plugin/\"* ~/.cursor/plugins/"
      ;;
    codex)
      echo ""
      echo "  [manifest] Codex plugin: pair .codex-plugin/ with ~/.codex/plugins/"
      echo "    mkdir -p ~/.codex/plugins && cp \"$REPO_ROOT/.codex-plugin/plugin.json\" ~/.codex/plugins/"
      ;;
    opencode)
      echo ""
      install_opencode_plugin
      ;;
    devin | kimi | hermes | pi | gemini)
      echo ""
      echo "  [manifest] $1 manifest lives in the repo; install per its platform docs:"
      echo "    $REPO_ROOT/$(manifest_path "$1")"
      ;;
    copilot)
      echo ""
      echo "  [manifest] copilot: no in-repo manifest yet; nothing to register"
      ;;
  esac
}

list_platforms() {
  echo "Installable platforms (skill paths from the README installation table):"
  echo ""
  echo "  Platform     Global                          Project"
  echo "  -----------  ------------------------------  ----------------"
  echo "  claude       ~/.claude/skills                .claude/skills"
  echo "  codex        ~/.agents/skills                .agents/skills"
  echo "  lingma       ~/.lingma/skills                .lingma/skills"
  echo "  antigravity  ~/.gemini/config/skills         .agents/skills"
  echo "  opencode     ~/.config/opencode/skills       .opencode/skills"
  echo "  pi           ~/.pi/agent/skills              .pi/skills"
  echo "  grok         ~/.grok/skills                  .grok/skills"
  echo ""
  echo "  Manifest-only platforms (no standard skills path): cursor, copilot,"
  echo "  devin, kimi, hermes, gemini — registered per platform docs."
  echo ""
  echo "  --global  (default) installs to your home dir; --project installs"
  echo "  in-repo for team distribution (.agents/skills is the shared path"
  echo "  recognized by Codex / Antigravity / OpenCode / Pi / Grok)."
}

install_global() {
  local platform="$1"
  local rel_path=""
  local dest=""

  rel_path="$(global_skills_path "$platform")"
  if [[ -n "$rel_path" ]]; then
    dest="$HOME/$rel_path"
    # I2: OPENCODE_CONFIG_DIR is what detect_platform keys on — install into
    # the same base so the install doesn't "succeed" in the wrong place.
    if [[ "$platform" == "opencode" && -n "${OPENCODE_CONFIG_DIR:-}" ]]; then
      dest="$OPENCODE_CONFIG_DIR/skills"
      echo "  [warn] OPENCODE_CONFIG_DIR is set; installing opencode skills to $dest (overrides $HOME/.config/opencode/skills)"
    fi
    echo "[1/2] installing skills for '$platform' -> $dest"
    install_skills "$dest" "$SKILLS_SRC"
  else
    echo "[1/2] '$platform' has no standard global skills path; skills skipped"
  fi

  echo "[2/2] manifest registration for '$platform'"
  manifest_registration "$platform"
}

install_project() {
  local platform="$1"
  local rel_path=""
  local dest=""
  local link_base=""

  if [[ -z "$platform" ]]; then
    rel_path=".agents/skills"
    dest="$REPO_ROOT/$rel_path"
    echo "[project] installing skills to shared path -> $dest"
    link_base="$(relative_target "$dest")"
    install_skills "$dest" "$link_base"
    return 0
  fi

  rel_path="$(project_skills_path "$platform")"
  if [[ -z "$rel_path" ]]; then
    echo "[project] '$platform' has no project-level skills path; skills skipped"
    if [[ -n "$(manifest_path "$platform")" ]]; then
      echo "          (manifest stays in the repo: $REPO_ROOT/$(manifest_path "$platform"))"
    else
      echo "          (no in-repo manifest for '$platform')"
    fi
    return 0
  fi

  dest="$REPO_ROOT/$rel_path"
  echo "[project] installing skills for '$platform' -> $dest"
  link_base="$(relative_target "$dest")"
  install_skills "$dest" "$link_base"

  # I1: project-mode opencode — the plugin already ships at
  # $REPO_ROOT/.opencode/plugins/dev-forge.js (global mode copies it to the
  # user's config via manifest_registration); here only the hint applies.
  if [[ "$platform" == "opencode" ]]; then
    echo ""
    echo "  [manifest] opencode plugin (project)"
    if [[ -f "$REPO_ROOT/.opencode/plugins/dev-forge.js" ]]; then
      echo "  [manifest] plugin ships in-repo: $REPO_ROOT/.opencode/plugins/dev-forge.js"
    else
      echo "  [warn] opencode plugin source not found: $REPO_ROOT/.opencode/plugins/dev-forge.js"
    fi
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --global)
        MODE="global"
        ;;
      --project)
        MODE="project"
        ;;
      --platform)
        shift
        [[ $# -ge 1 ]] || die "option --platform requires an argument"
        PLATFORM="$1"
        # M4: reject an explicitly empty value, e.g. --platform ""
        [[ -n "$PLATFORM" ]] || die "option --platform requires a non-empty argument"
        ;;
      --list)
        SHOW_LIST=true
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

  if [[ "$SHOW_LIST" == true ]]; then
    list_platforms
    exit 0
  fi

  if [[ -z "$PLATFORM" && "$MODE" == "global" ]]; then
    PLATFORM="$(detect_platform)" || die "could not auto-detect platform; pass --platform <name> (see --list)"
    if [[ "$PLATFORM" == "__dev_forge_quit__" ]]; then
      echo "install aborted."
      exit 0
    fi
    echo "detected platform: $PLATFORM"
  fi

  if [[ -n "$PLATFORM" ]]; then
    valid_platform "$PLATFORM" || die "unknown platform: $PLATFORM (see --list)"
  fi

  if [[ "$MODE" == "global" ]]; then
    install_global "$PLATFORM"
  else
    install_project "$PLATFORM"
  fi

  echo ""
  echo "dev-forge install complete. Restart the CLI (or reopen the IDE) and type '/' to confirm the loaded skills."
}

main "$@"
