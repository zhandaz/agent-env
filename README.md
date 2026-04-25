# agent-env

Personal terminal + Claude Code setup. Per-node install brings a new machine to
the same baseline in a few minutes.

## What's here

```
tmux/.tmux.conf         -> ~/.tmux.conf
tmux/copy-osc52         -> ~/.tmux/copy-osc52
claude/settings.json    -> ~/.claude/settings.json
glow/glow.yml           -> ~/.config/glow/glow.yml
install.sh              one-shot installer
```

Node-specific things (statusline command paths, sandbox allowlists, etc.) are
intentionally left out. They live in `~/.claude/settings.local.json` on each
node and are never committed.

## Quick install

```bash
git clone https://github.com/zhandaz/agent-env.git ~/software/agent-env
cd ~/software/agent-env
./install.sh
```

The script symlinks the config files into place and installs `glow` into
`~/.local/bin` if it is not already available.

## Manual install

If you prefer explicit steps:

```bash
# 1. Symlink configs
mkdir -p ~/.tmux ~/.claude ~/.config/glow
ln -sf ~/software/agent-env/tmux/.tmux.conf      ~/.tmux.conf
ln -sf ~/software/agent-env/tmux/copy-osc52      ~/.tmux/copy-osc52
ln -sf ~/software/agent-env/claude/settings.json ~/.claude/settings.json
ln -sf ~/software/agent-env/glow/glow.yml        ~/.config/glow/glow.yml

# 2. Reload tmux (if running)
tmux source-file ~/.tmux.conf
```

## Shell setup

`~/.local/bin` should be on your `PATH` so `glow` (and other user binaries) are
discoverable. Add this to `~/.bashrc` (or `~/.zshrc`) if missing:

```bash
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac
```

## Installing glow

`install.sh` handles this, but if you want to do it manually:

```bash
# Pick the archive matching your arch: Linux_arm64, Linux_x86_64, etc.
VERSION=v2.1.2
ARCH=arm64  # or x86_64
cd /tmp
curl -L -o glow.tar.gz \
  "https://github.com/charmbracelet/glow/releases/download/${VERSION}/glow_${VERSION#v}_Linux_${ARCH}.tar.gz"
tar -xzf glow.tar.gz
mkdir -p ~/.local/bin
mv glow_*/glow ~/.local/bin/
rm -rf glow_* glow.tar.gz
```

## Clipboard / OSC 52

tmux is configured to push selections to the outer terminal's clipboard via
OSC 52, but **not** through tmux's native `set-clipboard on` path: that
silently drops on the Mac -> mosh -> slurm-node stack (mosh's predictive
sync layer appears to interfere with the capability probe tmux issues
before emitting clipboard writes).

Instead, copy keys (`y` in copy-mode, mouse-drag release) pipe the
selection through `~/.tmux/copy-osc52`, which:

1. base64-encodes stdin
2. emits `\ePtmux;\e\e]52;c;<b64>\a\e\\` (OSC 52 wrapped in tmux DCS
   passthrough) to the pane's tty

tmux unwraps the DCS, sends the inner `\e]52;c;<b64>\a` straight to the
outer terminal. mosh forwards. iTerm2 (or any OSC 52-capable terminal)
sets the clipboard. `Cmd+V` on the Mac pastes.

This requires:

- `allow-passthrough on` in tmux (set in `tmux/.tmux.conf`)
- `set-clipboard off` (or it would race with the helper)
- An outer terminal that honors OSC 52 — iTerm2, Ghostty, WezTerm, Kitty,
  Alacritty all do; Apple Terminal.app does not
- mosh **1.4.0+** (earlier versions strip OSC 52)

If you upgrade mosh / tmux / iTerm2 and want to try the simpler native
path, flip `set-clipboard on` and remove the helper invocation from the
two copy-mode bindings. If `printf '\e]52;c;%s\a' "$(printf test|base64)"`
inside tmux pastes on `Cmd+V`, the native path is back.

## Per-node overrides

Anything that depends on the specific machine (statusline scripts, sandbox
`allowedDomains`, extra WebFetch permissions) goes in
`~/.claude/settings.local.json`. Claude Code merges it over the committed
`settings.json`, so keep node-specific values there and never commit that file.

Example `settings.local.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash /path/on/this/node/.claude/statusline-command.sh"
  },
  "sandbox": {
    "network": {
      "allowedDomains": ["api.github.com", "github.com"]
    }
  }
}
```
