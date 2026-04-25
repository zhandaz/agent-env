#!/usr/bin/env bash
# Install agent-env configs and glow binary.
# Idempotent: safe to run repeatedly. Backs up any existing non-symlink files.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GLOW_VERSION="v2.1.2"

log() { printf '\033[1;34m[agent-env]\033[0m %s\n' "$*"; }

# ---------- symlinks ----------

link() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [[ -L "$dst" ]]; then
    local current
    current="$(readlink "$dst")"
    if [[ "$current" == "$src" ]]; then
      log "already linked: $dst"
      return
    fi
    rm "$dst"
  elif [[ -e "$dst" ]]; then
    local backup="${dst}.bak.$(date +%Y%m%d%H%M%S)"
    log "backing up existing $dst -> $backup"
    mv "$dst" "$backup"
  fi
  ln -s "$src" "$dst"
  log "linked: $dst -> $src"
}

link "$REPO_DIR/tmux/.tmux.conf"      "$HOME/.tmux.conf"
link "$REPO_DIR/tmux/copy-osc52"      "$HOME/.tmux/copy-osc52"
link "$REPO_DIR/claude/settings.json" "$HOME/.claude/settings.json"
link "$REPO_DIR/glow/glow.yml"        "$HOME/.config/glow/glow.yml"

# ---------- PATH check ----------

case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *)
    log "note: \$HOME/.local/bin is not on your PATH"
    log "add to ~/.bashrc or ~/.zshrc:"
    echo '    export PATH="$HOME/.local/bin:$PATH"'
    ;;
esac

# ---------- glow ----------

if command -v glow >/dev/null 2>&1; then
  log "glow already installed: $(command -v glow)"
else
  log "installing glow $GLOW_VERSION to ~/.local/bin"
  mkdir -p "$HOME/.local/bin"

  case "$(uname -m)" in
    x86_64)  arch="x86_64" ;;
    aarch64) arch="arm64"  ;;
    arm64)   arch="arm64"  ;;
    *) log "unsupported arch: $(uname -m). install glow manually."; exit 1 ;;
  esac

  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  url="https://github.com/charmbracelet/glow/releases/download/${GLOW_VERSION}/glow_${GLOW_VERSION#v}_Linux_${arch}.tar.gz"
  curl -fsSL -o "$tmp/glow.tar.gz" "$url"
  tar -xzf "$tmp/glow.tar.gz" -C "$tmp"
  mv "$tmp"/glow_*/glow "$HOME/.local/bin/glow"
  chmod +x "$HOME/.local/bin/glow"
  log "installed: $HOME/.local/bin/glow"
fi

# ---------- tmux reload ----------

if [[ -n "${TMUX:-}" ]]; then
  tmux source-file "$HOME/.tmux.conf"
  log "reloaded tmux config"
fi

log "done. per-node overrides go in ~/.claude/settings.local.json"
