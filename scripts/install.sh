#!/usr/bin/env bash
set -euo pipefail

# MeshChatIV Install Script
# Supports Ubuntu/Debian and Arch Linux

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO="$ID"
        DISTRO_LIKE="$ID_LIKE"
    elif command -v lsb_release &>/dev/null; then
        DISTRO=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
    else
        DISTRO="unknown"
    fi
}

install_ubuntu_deps() {
    info "Installing dependencies for Ubuntu/Debian..."

    sudo apt-get update -qq

    sudo apt-get install -y -qq \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        nodejs \
        npm \
        git \
        curl \
        build-essential \
        pkg-config \
        libssl-dev \
        libsodium-dev \
        libffi-dev \
        fonts-noto-color-emoji \
        || { err "Failed to install Ubuntu dependencies"; exit 1; }

    if ! command -v pnpm &>/dev/null; then
        info "Installing pnpm via corepack..."
        sudo corepack enable
        sudo corepack prepare pnpm@latest --activate 2>/dev/null || true
        if ! command -v pnpm &>/dev/null; then
            info "Falling back to npm-based pnpm install..."
            sudo npm install -g pnpm
        fi
    fi

    if ! command -v uv &>/dev/null; then
        info "Installing uv (Python package manager)..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
        export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
    fi

    ok "Ubuntu dependencies installed."
}

install_arch_deps() {
    info "Installing dependencies for Arch Linux..."

    sudo pacman -Syu --noconfirm

    sudo pacman -S --noconfirm \
        python \
        python-pip \
        python-virtualenv \
        nodejs \
        npm \
        git \
        curl \
        base-devel \
        pkg-config \
        openssl \
        libsodium \
        libffi \
        noto-fonts-emoji \
        || { err "Failed to install Arch dependencies"; exit 1; }

    if ! command -v pnpm &>/dev/null; then
        info "Installing pnpm..."
        sudo npm install -g pnpm
    fi

    if ! command -v uv &>/dev/null; then
        info "Installing uv (Python package manager)..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
        export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
    fi

    ok "Arch dependencies installed."
}

install_project() {
    info "Installing MeshChatIV project dependencies..."

    cd "$(dirname "$0")/.."

    # Install Node.js dependencies
    pnpm install --frozen-lockfile 2>/dev/null || pnpm install

    # Install Python dependencies
    uv sync --group dev 2>/dev/null || pip install -r requirements.txt 2>/dev/null || {
        warn "Trying pip install directly..."
        pip install --user -r requirements.txt
    }

    # Build frontend
    info "Building frontend assets..."
    pnpm run build-frontend 2>/dev/null || pnpm run build 2>/dev/null || warn "Frontend build skipped (try manually with 'pnpm run build-frontend')"

    ok "MeshChatIV installation complete!"
}

# --- Main ---

echo ""
echo "========================================"
echo "  MeshChatIV - Reticulum MeshChat Setup"
echo "========================================"
echo ""

detect_distro

case "$DISTRO" in
    ubuntu|debian|linuxmint|pop|elementary|zorin)
        install_ubuntu_deps
        ;;
    arch|archarm|manjaro|endeavouros|artix|garuda)
        install_arch_deps
        ;;
    *)
        warn "Unknown distribution: $DISTRO"
        warn "Attempting generic install..."
        install_ubuntu_deps
        ;;
esac

install_project

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  MeshChatIV is ready!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "To run MeshChatIV:"
echo ""
echo "  cd /path/to/MeshChatIV"
echo "  uv run python -m meshchatx.meshchat --headless --host 127.0.0.1"
echo ""
echo "Then open http://127.0.0.1:8000 in your browser."
echo ""
echo "For desktop mode (Electron):"
echo "  pnpm run electron"
echo ""
