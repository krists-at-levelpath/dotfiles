#!/usr/bin/env bash
# Dotfiles installer. Run by `coder dotfiles` on every workspace start, so it
# must stay idempotent. Coder runs it from the cloned repo directory
# (~/.config/coderv2/dotfiles by default), which is where the symlinks point.
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"
REPO="$PWD"

log() { printf '\033[0;1m[dotfiles]\033[0m %s\n' "$*"; }

# --- Symlink every top-level dotfile into $HOME --------------------------------
# Mirrors what `coder dotfiles` does when no install script exists: skip .git*
# except .gitconfig, back up real files once, overwrite stale symlinks.
link_dotfiles() {
  local f target
  for f in "$REPO"/.??*; do
    f="$(basename "$f")"
    case "$f" in
      .gitconfig) ;;
      .git | .git*) continue ;;
    esac
    target="$HOME/$f"
    if [ -e "$target" ] && [ ! -L "$target" ]; then
      log "backing up existing $target to $target.bak"
      mv "$target" "$target.bak"
    fi
    ln -sfn "$REPO/$f" "$target"
    log "linked $target -> $REPO/$f"
  done
}

# --- Packages ------------------------------------------------------------------
# Add Debian/Ubuntu packages here. Installed only if the command is missing.
# Format: "<command-to-check>:<apt-package>".
PACKAGES=(
  "tmux:tmux"
  "vim:vim"
)

have_sudo() {
  [ "$(id -u)" -eq 0 ] || sudo -n true 2>/dev/null
}

install_packages() {
  local entry cmd pkg missing=()
  for entry in "${PACKAGES[@]}"; do
    cmd="${entry%%:*}"
    pkg="${entry##*:}"
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$pkg")
  done
  [ "${#missing[@]}" -eq 0 ] && { log "all packages present"; return; }

  if ! command -v apt-get >/dev/null 2>&1; then
    log "apt-get not available, skipping: ${missing[*]}"
    return
  fi
  if ! have_sudo; then
    log "no passwordless sudo, cannot install: ${missing[*]}"
    return
  fi

  local SUDO=""
  [ "$(id -u)" -eq 0 ] || SUDO="sudo"
  log "installing: ${missing[*]}"
  export DEBIAN_FRONTEND=noninteractive
  $SUDO apt-get update -qq
  $SUDO apt-get install -y -qq --no-install-recommends "${missing[@]}"
}

link_dotfiles
install_packages
log "done"
