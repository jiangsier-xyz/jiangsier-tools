#!/usr/bin/env bash
# mac-install-neovim-lazyvim.sh
# Installs Neovim (latest) + LazyVim on macOS via Homebrew.
# Safe to re-run: skips steps that are already done.

set -euo pipefail

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[✗]${NC} $*" >&2; }

# --- Pre-flight ---
if [[ "$(uname)" != "Darwin" ]]; then
  err "This script is for macOS only."
  exit 1
fi

# --- Homebrew ---
if ! command -v brew &>/dev/null; then
  warn "Homebrew not found — installing it now…"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Apple Silicon path setup
  if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
else
  info "Homebrew already installed."
fi

# --- Neovim (stable) ---
if brew list --versions neovim &>/dev/null; then
  info "Neovim already installed: $(nvim --version | head -1)"
  warn "Upgrading to latest…"
  brew upgrade neovim
else
  info "Installing Neovim via Homebrew…"
  brew install neovim
fi

info "Neovim version: $(nvim --version | head -1)"

# --- git (needed for LazyVim plugin manager) ---
if ! command -v git &>/dev/null; then
  warn "git not found — installing…"
  brew install git
fi

# --- Nerd Font (required for LazyVim icons) ---
FONT_NAME="font-jetbrains-mono-nerd-font"
if brew list --cask --versions "$FONT_NAME" &>/dev/null; then
  info "Nerd Font already installed: JetBrains Mono"
else
  info "Installing JetBrains Mono Nerd Font (required for icons)…"
  brew install --cask "$FONT_NAME"
fi
warn "Make sure to set 'JetBrainsMono Nerd Font' in your terminal settings!"

# --- LazyVim starter ---
LAZYVIM_DIR="${HOME}/.config/nvim"

if [[ -d "$LAZYVIM_DIR" ]]; then
  warn "Existing nvim config found at ${LAZYVIM_DIR}"
  read -rp "Back it up to ${LAZYVIM_DIR}.bak and continue? [Y/n] " answer
  answer=${answer:-Y}
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    mv "$LAZYVIM_DIR" "${LAZYVIM_DIR}.bak"
    info "Backed up to ${LAZYVIM_DIR}.bak"
  else
    err "Aborting — existing config preserved."
    exit 1
  fi
fi

info "Cloning LazyVim starter…"
git clone https://github.com/LazyVim/starter "$LAZYVIM_DIR"

# Remove the starter's .git so it doesn't interfere with your own config repo
rm -rf "${LAZYVIM_DIR}/.git"

info "LazyVim installed at ${LAZYVIM_DIR}"

# --- Disable neo-tree (use snacks explorer instead) ---
# LazyVim now uses snacks.nvim for file explorer, which is more modern.
# We disable neo-tree to avoid having two file browsers.
NEOTREE_PLUGIN_DIR="${LAZYVIM_DIR}/lua/plugins"
mkdir -p "$NEOTREE_PLUGIN_DIR"

cat > "${NEOTREE_PLUGIN_DIR}/disabled.lua" << 'LUAEOF'
return {
  { "nvim-neo-tree/neo-tree.nvim", enabled = false },
}
LUAEOF

info "Disabled neo-tree (using snacks explorer instead)."

# --- Show hidden files in snacks.nvim picker by default ---
cat > "${NEOTREE_PLUGIN_DIR}/snacks.lua" << 'LUAEOF'
return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      hidden = true,
    },
  },
}
LUAEOF

info "Configured snacks.nvim picker to include hidden files."

info "Installing necessary tools."
NONINTERACTIVE=1 brew install fd ripgrep fzf lazygit tree-sitter gdu

# --- First launch: auto-install plugins ---
info "Launching Neovim to install plugins (this may take a minute)…"
nvim --headless "+Lazy! sync" +qa

echo ""
info "Done! Open Neovim with:  nvim"
info "LazyVim docs: https://www.lazyvim.org/"