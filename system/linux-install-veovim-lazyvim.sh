#!/usr/bin/env bash
# linux-install-neovim-lazyvim.sh
# Installs Neovim (latest stable) + LazyVim on Ubuntu via apt + direct downloads.
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
if [[ "$(uname)" != "Linux" ]]; then
  err "This script is for Linux only."
  exit 1
fi

if ! command -v lsb_release &>/dev/null; then
  sudo apt-get update -y
  sudo apt-get install -y lsb-release
fi

DISTRO_ID="$(lsb_release -is 2>/dev/null || true)"
if [[ "${DISTRO_ID,,}" != "ubuntu" ]]; then
  err "This script targets Ubuntu (detected: ${DISTRO_ID:-unknown})."
  exit 1
fi

# --- Helper: sudo-or-apt ---
apt_install() {
  sudo apt-get install -y "$@"
}

# --- apt update ---
info "Updating apt package index…"
sudo apt-get update -y

# --- Neovim (latest stable via PPA) ---
if ! command -v nvim &>/dev/null; then
  info "Adding neovim PPA (stable)…"
  sudo add-apt-repository -y ppa:neovim-ppa/stable
  sudo apt-get update -y
  info "Installing Neovim…"
  apt_install neovim
else
  info "Neovim already installed: $(nvim --version | head -1)"
  warn "Upgrading to latest…"
  sudo apt-get install -y --only-upgrade neovim
fi

info "Neovim version: $(nvim --version | head -1)"

# --- git (needed for LazyVim plugin manager) ---
if ! command -v git &>/dev/null; then
  warn "git not found — installing…"
  apt_install git
fi

# --- Build tools (tree-sitter parsers, telescope-fzf-native, etc.) ---
if ! command -v make &>/dev/null; then
  info "Installing build tools (build-essential, cmake, unzip)…"
  apt_install build-essential cmake unzip
fi

# --- Nerd Font (required for LazyVim icons) ---
FONT_DIR="${HOME}/.local/share/fonts"
FONT_NAME="JetBrainsMono"
FONT_ZIP="JetBrainsMono.zip"
mkdir -p "${FONT_DIR}"

if fc-list 2>/dev/null | grep -qi "JetBrainsMono Nerd Font"; then
  info "Nerd Font already installed: JetBrains Mono"
else
  info "Installing JetBrains Mono Nerd Font (required for icons)…"
  TMP_DIR="$(mktemp -d)"
  curl -fsSL -o "${TMP_DIR}/${FONT_ZIP}" \
    "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${FONT_ZIP}"
  unzip -q -o "${TMP_DIR}/${FONT_ZIP}" -d "${FONT_DIR}"
  rm -rf "${TMP_DIR}"
  fc-cache -f "${FONT_DIR}" >/dev/null 2>&1 || true
  warn "Set 'JetBrainsMono Nerd Font' in your terminal settings!"
fi

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

# --- LazyVim-recommended CLI tools ---
info "Installing necessary tools."

# fd: Ubuntu packages it as `fd-find` with binary `fdfind`; symlink to `fd`.
if ! command -v fd &>/dev/null && ! command -v fdfind &>/dev/null; then
  apt_install fd-find
fi
if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
  mkdir -p "${HOME}/.local/bin"
  ln -sf "$(command -v fdfind)" "${HOME}/.local/bin/fd"
fi

command -v rg &>/dev/null     || apt_install ripgrep
command -v fzf &>/dev/null    || apt_install fzf
command -v tree-sitter &>/dev/null || apt_install tree-sitter

# lazygit: not in Ubuntu apt — grab the latest release from GitHub.
if ! command -v lazygit &>/dev/null; then
  info "Installing lazygit from GitHub releases…"
  LAZYGIT_VERSION="$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest \
    | grep -Po '"tag_name":\s*"v\K[^"]+')"
  LAZYGIT_ARCH="$(uname -m)"
  case "$LAZYGIT_ARCH" in
    x86_64)  LAZYGIT_ARCH="x86_64" ;;
    aarch64) LAZYGIT_ARCH="arm64" ;;
    *) err "Unsupported architecture for lazygit: $LAZYGIT_ARCH"; exit 1 ;;
  esac
  TMP_DIR="$(mktemp -d)"
  curl -fsSL -o "${TMP_DIR}/lazygit.tar.gz" \
    "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_${LAZYGIT_ARCH}.tar.gz"
  tar -xzf "${TMP_DIR}/lazygit.tar.gz" -C "${TMP_DIR}" lazygit
  sudo install -m 0755 "${TMP_DIR}/lazygit" /usr/local/bin/lazygit
  rm -rf "${TMP_DIR}"
fi

# gdu: not reliably in Ubuntu apt — grab the latest release from GitHub.
if ! command -v gdu &>/dev/null; then
  info "Installing gdu from GitHub releases…"
  GDU_ARCH="$(uname -m)"
  case "$GDU_ARCH" in
    x86_64)  GDU_ARCH="amd64" ;;
    aarch64) GDU_ARCH="arm64" ;;
    *) err "Unsupported architecture for gdu: $GDU_ARCH"; exit 1 ;;
  esac
  TMP_DIR="$(mktemp -d)"
  curl -fsSL -o "${TMP_DIR}/gdu.tar.gz" \
    "https://github.com/dundee/gdu/releases/latest/download/gdu_linux_${GDU_ARCH}.tgz"
  tar -xzf "${TMP_DIR}/gdu.tar.gz" -C "${TMP_DIR}"
  sudo install -m 0755 "${TMP_DIR}/gdu" /usr/local/bin/gdu
  rm -rf "${TMP_DIR}"
fi

# --- First launch: auto-install plugins ---
info "Launching Neovim to install plugins (this may take a minute)…"
nvim --headless "+Lazy! sync" +qa

echo ""
info "Done! Open Neovim with:  nvim"
info "LazyVim docs: https://www.lazyvim.org/"
