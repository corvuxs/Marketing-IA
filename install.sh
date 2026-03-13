#!/usr/bin/env bash
set -euo pipefail

# ============================================================
#  Marketing-IA — AI-powered Marketing Assistant
#  Install script
#  Usage: curl -fsSL https://raw.githubusercontent.com/zubair-trabzada/ai-marketing-claude/main/install.sh | bash
# ============================================================

REPO_URL="https://github.com/zubair-trabzada/ai-marketing-claude"
INSTALL_DIR="${HOME}/.marketing-ia"
BIN_DIR="${HOME}/.local/bin"
CONFIG_DIR="${HOME}/.config/marketing-ia"
PYTHON_MIN_VERSION="3.9"
NODE_MIN_VERSION="18"

# ── colours ─────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${BLUE}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }

# ── banner ───────────────────────────────────────────────────
print_banner() {
  echo -e "${BOLD}${BLUE}"
  echo "  ╔══════════════════════════════════════════╗"
  echo "  ║        Marketing-IA  Installer           ║"
  echo "  ║   AI-powered Marketing Assistant         ║"
  echo "  ╚══════════════════════════════════════════╝"
  echo -e "${RESET}"
}

# ── helpers ──────────────────────────────────────────────────
command_exists() { command -v "$1" &>/dev/null; }

version_ge() {
  # Returns 0 if $1 >= $2 (both in X.Y format)
  printf '%s\n%s' "$2" "$1" | sort -C -V
}

# ── OS detection ─────────────────────────────────────────────
detect_os() {
  OS="unknown"
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if command_exists apt-get; then
      OS="debian"
    elif command_exists dnf; then
      OS="fedora"
    elif command_exists yum; then
      OS="rhel"
    elif command_exists pacman; then
      OS="arch"
    else
      OS="linux"
    fi
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
  else
    error "Unsupported operating system: $OSTYPE"
  fi
  info "Detected OS: ${OS}"
}

# ── dependency installation ──────────────────────────────────
install_system_deps() {
  case "$OS" in
    debian)
      info "Updating apt and installing system dependencies…"
      sudo apt-get update -qq
      sudo apt-get install -y -qq git curl python3 python3-pip python3-venv nodejs npm
      ;;
    fedora)
      info "Installing system dependencies via dnf…"
      sudo dnf install -y git curl python3 python3-pip nodejs npm
      ;;
    rhel)
      info "Installing system dependencies via yum…"
      sudo yum install -y git curl python3 python3-pip nodejs npm
      ;;
    arch)
      info "Installing system dependencies via pacman…"
      sudo pacman -Sy --noconfirm git curl python python-pip nodejs npm
      ;;
    macos)
      if ! command_exists brew; then
        info "Installing Homebrew…"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      fi
      info "Installing system dependencies via Homebrew…"
      brew install git python node
      ;;
    *)
      warn "Cannot auto-install dependencies for OS '${OS}'. Please install git, Python ≥${PYTHON_MIN_VERSION}, and Node.js ≥${NODE_MIN_VERSION} manually."
      ;;
  esac
}

# ── requirement checks ───────────────────────────────────────
check_requirements() {
  local missing=()

  # git
  if ! command_exists git; then
    missing+=("git")
  fi

  # python
  if command_exists python3; then
    PY_VER="$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')"
    if ! version_ge "$PY_VER" "$PYTHON_MIN_VERSION"; then
      missing+=("python>=${PYTHON_MIN_VERSION} (found ${PY_VER})")
    fi
  else
    missing+=("python>=${PYTHON_MIN_VERSION}")
  fi

  # node (optional but recommended for the web dashboard)
  if command_exists node; then
    NODE_VER="$(node --version | sed 's/v//' | cut -d. -f1)"
    if [[ "$NODE_VER" -lt "$NODE_MIN_VERSION" ]]; then
      warn "Node.js ${NODE_MIN_VERSION}+ recommended (found v${NODE_VER}). The web dashboard may not work."
    fi
  else
    warn "Node.js not found. The web dashboard will not be available."
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    warn "Missing requirements: ${missing[*]}"
    read -r -p "Attempt automatic installation? [Y/n] " response
    response="${response:-Y}"
    if [[ "$response" =~ ^[Yy]$ ]]; then
      install_system_deps
    else
      error "Please install the missing requirements and re-run the installer."
    fi
  else
    success "All requirements satisfied."
  fi
}

# ── clone / update repo ──────────────────────────────────────
fetch_repo() {
  if [[ -d "${INSTALL_DIR}/.git" ]]; then
    info "Updating existing installation at ${INSTALL_DIR}…"
    git -C "$INSTALL_DIR" pull --ff-only origin main
  else
    info "Cloning Marketing-IA into ${INSTALL_DIR}…"
    git clone --depth 1 "$REPO_URL" "$INSTALL_DIR"
  fi
  success "Source code ready."
}

# ── python virtual environment & packages ───────────────────
setup_python() {
  info "Setting up Python virtual environment…"
  python3 -m venv "${INSTALL_DIR}/.venv"
  # shellcheck source=/dev/null
  source "${INSTALL_DIR}/.venv/bin/activate"

  pip install --quiet --upgrade pip

  if [[ -f "${INSTALL_DIR}/requirements.txt" ]]; then
    info "Installing Python dependencies…"
    pip install --quiet -r "${INSTALL_DIR}/requirements.txt"
  fi
  success "Python environment ready."
}

# ── node / npm packages ──────────────────────────────────────
setup_node() {
  if ! command_exists node; then
    return
  fi
  if [[ -f "${INSTALL_DIR}/package.json" ]]; then
    info "Installing Node.js dependencies…"
    npm --prefix "$INSTALL_DIR" install --silent
    success "Node.js dependencies installed."
  fi
}

# ── configuration ────────────────────────────────────────────
setup_config() {
  mkdir -p "$CONFIG_DIR"
  local cfg="${CONFIG_DIR}/config.env"

  if [[ -f "$cfg" ]]; then
    info "Existing configuration found at ${cfg}. Skipping."
    return
  fi

  info "Creating default configuration at ${cfg}…"
  cat > "$cfg" <<'EOF'
# Marketing-IA configuration
# Set your Anthropic API key below or export it in your shell profile.
ANTHROPIC_API_KEY=

# Optional: default Claude model
# MARKETING_IA_MODEL=claude-opus-4-6

# Optional: output language (e.g. en, fr, de, es)
# MARKETING_IA_LANG=en
EOF

  warn "Remember to add your ANTHROPIC_API_KEY to ${cfg}"
  success "Configuration file created."
}

# ── CLI wrapper ──────────────────────────────────────────────
install_cli() {
  mkdir -p "$BIN_DIR"
  local wrapper="${BIN_DIR}/marketing-ia"

  info "Installing CLI wrapper to ${wrapper}…"
  cat > "$wrapper" <<EOF
#!/usr/bin/env bash
# Marketing-IA launcher
INSTALL_DIR="${INSTALL_DIR}"
CONFIG_FILE="${CONFIG_DIR}/config.env"

if [[ -f "\${CONFIG_FILE}" ]]; then
  # shellcheck source=/dev/null
  set -a; source "\${CONFIG_FILE}"; set +a
fi

source "\${INSTALL_DIR}/.venv/bin/activate"
exec python3 "\${INSTALL_DIR}/main.py" "\$@"
EOF
  chmod +x "$wrapper"
  success "CLI wrapper installed."
}

# ── PATH setup ───────────────────────────────────────────────
ensure_path() {
  if [[ ":${PATH}:" != *":${BIN_DIR}:"* ]]; then
    warn "${BIN_DIR} is not in your PATH."
    local shell_rc
    case "${SHELL:-bash}" in
      */zsh)  shell_rc="${HOME}/.zshrc" ;;
      */fish) shell_rc="${HOME}/.config/fish/config.fish" ;;
      *)      shell_rc="${HOME}/.bashrc" ;;
    esac
    echo "" >> "$shell_rc"
    echo "# Marketing-IA" >> "$shell_rc"
    echo "export PATH=\"${BIN_DIR}:\$PATH\"" >> "$shell_rc"
    info "Added ${BIN_DIR} to PATH in ${shell_rc}."
    info "Run: source ${shell_rc}   (or open a new terminal)"
  fi
}

# ── uninstall helper ─────────────────────────────────────────
uninstall() {
  warn "Removing Marketing-IA…"
  rm -rf "$INSTALL_DIR" "$CONFIG_DIR" "${BIN_DIR}/marketing-ia"
  success "Marketing-IA has been removed."
  exit 0
}

# ── entry point ──────────────────────────────────────────────
main() {
  print_banner

  # Allow --uninstall flag
  if [[ "${1:-}" == "--uninstall" ]]; then
    uninstall
  fi

  detect_os
  check_requirements
  fetch_repo
  setup_python
  setup_node
  setup_config
  install_cli
  ensure_path

  echo ""
  echo -e "${BOLD}${GREEN}Installation complete!${RESET}"
  echo ""
  echo -e "  Run ${BOLD}marketing-ia --help${RESET} to get started."
  echo -e "  Edit ${BOLD}${CONFIG_DIR}/config.env${RESET} to add your Anthropic API key."
  echo ""
  echo -e "  GitHub: ${REPO_URL}"
  echo ""
}

main "$@"
