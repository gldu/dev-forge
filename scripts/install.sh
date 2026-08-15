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
# $HOME; project paths are written relative to this repo (copy this script
# into a target repo for in-repo team distribution).
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_SRC="$REPO_ROOT/skills"

# org placeholder — replace <org> with the real GitHub org before publishing
ORG_PLACEHOLDER="<org>"

MODE="global"
PLATFORM=""
SHOW_LIST=false

usage() {
  sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
}

die() {
  echo "error: $*" >&2
  exit 1
}

valid_platform() {
  case "$1" in
    claude | codex | lingma | antigravity | opencode | pi | cursor | copilot | devin | kimi | hermes | gemini)
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
    *)
      echo ""
      ;;
  esac
}

# Symlink every skill directory (forge-* + using-dev-forge) into $dest.
# Symlinks keep the installed skills in sync with the repo.
install_skills() {
  local dest="$1"
  local count=0
  local d

  if [[ ! -d "$SKILLS_SRC" ]]; then
    die "skills directory not found: $SKILLS_SRC"
  fi

  mkdir -p "$dest"

  for d in "$SKILLS_SRC"/forge-*; do
    [[ -d "$d" ]] || continue
    ln -sfn "$d" "$dest/$(basename "$d")"
    count=$((count + 1))
  done

  for d in "$SKILLS_SRC"/using-dev-forge; do
    [[ -d "$d" ]] || continue
    ln -sfn "$d" "$dest/$(basename "$d")"
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
    echo "could not auto-detect platform and stdin is not interactive; pass --platform <name> (see --list)" >&2
    return 1
  fi
}

# Interactive numbered menu; prompts go to stderr so the platform name is the
# only thing printed on stdout (detect_platform is called in $(...)).
interactive_platform_menu() {
  local platforms=(claude codex lingma antigravity opencode pi cursor copilot)
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

  if [[ ! "$choice" =~ ^[0-9]+$ ]] || ((choice < 1 || choice > last)); then
    echo "" >&2
    return 1
  fi
  echo "${platforms[$((choice - 1))]}"
}

# Copy the opencode plugin into the user's opencode plugins dir.
# Never aborts the install if the copy fails — skills are the primary payload.
install_opencode_plugin() {
  local src="$REPO_ROOT/.opencode/plugins/dev-forge.js"
  local dest="$HOME/.config/opencode/plugins"

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
    copilot) echo "(no in-repo manifest yet)" ;;
  esac
}

# Register / point at the platform manifest. Global mode only — project
# installs ship the manifests in-repo already.
manifest_registration() {
  case "$1" in
    claude)
      echo ""
      echo "  [manifest] Claude Code plugin marketplace:"
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
    devin | kimi | hermes | pi | gemini | copilot)
      echo ""
      echo "  [manifest] $1 manifest lives in the repo; install per its platform docs:"
      echo "    $REPO_ROOT/$(manifest_path "$1")"
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
  echo ""
  echo "  Manifest-only platforms (no standard skills path): cursor, copilot,"
  echo "  devin, kimi, hermes, gemini — registered per platform docs."
  echo ""
  echo "  --global  (default) installs to your home dir; --project installs"
  echo "  in-repo for team distribution (.agents/skills is the shared path"
  echo "  recognized by Codex / Antigravity / OpenCode / Pi)."
}

install_global() {
  local platform="$1"
  local rel_path=""
  local dest=""

  rel_path="$(global_skills_path "$platform")"
  if [[ -n "$rel_path" ]]; then
    dest="$HOME/$rel_path"
    echo "[1/2] installing skills for '$platform' -> $dest"
    install_skills "$dest"
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

  if [[ -z "$platform" ]]; then
    rel_path=".agents/skills"
    echo "[project] installing skills to shared path -> $REPO_ROOT/$rel_path"
    install_skills "$REPO_ROOT/$rel_path"
    return 0
  fi

  rel_path="$(project_skills_path "$platform")"
  if [[ -z "$rel_path" ]]; then
    echo "[project] '$platform' has no project-level skills path; skills skipped"
    echo "          (manifest stays in the repo: $REPO_ROOT/$(manifest_path "$platform"))"
    return 0
  fi

  echo "[project] installing skills for '$platform' -> $REPO_ROOT/$rel_path"
  install_skills "$REPO_ROOT/$rel_path"
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
