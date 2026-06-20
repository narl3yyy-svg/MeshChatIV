#!/usr/bin/env bash
set -euo pipefail

# MeshChatIV Install Script
# Supports Ubuntu/Debian and Arch Linux
# Requires Node.js >= 24

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

MIN_NODE_VERSION=24

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO="$ID"
    elif command -v lsb_release &>/dev/null; then
        DISTRO=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
    else
        DISTRO="unknown"
    fi
}

check_node_version() {
    if command -v node &>/dev/null; then
        NODE_VERSION=$(node --version | sed 's/v//' | cut -d. -f1)
        if [ "$NODE_VERSION" -ge "$MIN_NODE_VERSION" ]; then
            ok "Node.js v$(node --version | sed 's/v//' | cut -d. -f1) found (v$MIN_NODE_VERSION+ required)"
            return 0
        fi
        warn "Node.js v$(node --version | sed 's/v//') found, but v$MIN_NODE_VERSION+ is required"
    fi
    return 1
}

install_node_ubuntu() {
    info "Installing Node.js v24.x on Ubuntu/Debian..."

    # Step 1: Try the distro's default nodejs package (Ubuntu 26.04+ has v24)
    if command -v apt-cache &>/dev/null; then
        local apt_node_version
        apt_node_version=$(apt-cache show nodejs 2>/dev/null | grep '^Version:' | head -1 | sed 's/^Version: *\([0-9]*\).*/\1/')
        if [ -n "$apt_node_version" ] && [ "$apt_node_version" -ge 24 ]; then
            info "Distro package nodejs v${apt_node_version}.x available — installing..."
            sudo apt-get install -y -qq nodejs npm 2>/dev/null || sudo apt-get install -y -qq nodejs
            if command -v node &>/dev/null || command -v nodejs &>/dev/null; then
                ok "Node.js installed from distro packages"
                return 0
            fi
        fi
    fi

    # Step 2: Try NodeSource
    info "Trying NodeSource repository..."
    if curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash - 2>/dev/null; then
        sudo apt-get install -y -qq nodejs npm 2>/dev/null || sudo apt-get install -y -qq nodejs
        # Some Ubuntu versions provide nodejs but not the 'node' symlink
        if ! command -v node &>/dev/null && command -v nodejs &>/dev/null; then
            sudo ln -sf "$(command -v nodejs)" /usr/local/bin/node
        fi
        # Ensure npm is available (may be a separate package)
        if ! command -v npm &>/dev/null; then
            sudo apt-get install -y -qq npm 2>/dev/null || true
        fi
        if command -v node &>/dev/null; then
            ok "Node.js v$(node --version | sed 's/v//') installed from NodeSource"
            return 0
        fi
    else
        warn "NodeSource repository unavailable"
    fi

    # Step 3: Fall back to nvm (most reliable for any Ubuntu version)
    info "Installing Node.js via nvm (Node Version Manager)..."
    export NVM_DIR="$HOME/.nvm"
    if [ ! -s "$NVM_DIR/nvm.sh" ]; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
    fi
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        . "$NVM_DIR/nvm.sh"
        nvm install 24 --default 2>/dev/null || nvm install 24 2>/dev/null || {
            err "nvm install failed"
            exit 1
        }
        # Symlink into /usr/local/bin so sudo commands can find node
        local nvm_node
        nvm_node="$NVM_DIR/versions/node/$(nvm current 2>/dev/null)/bin/node"
        if [ -f "$nvm_node" ]; then
            sudo ln -sf "$nvm_node" /usr/local/bin/node
            sudo ln -sf "$(dirname "$nvm_node")/npm" /usr/local/bin/npm 2>/dev/null || true
            sudo ln -sf "$(dirname "$nvm_node")/npx" /usr/local/bin/npx 2>/dev/null || true
            sudo ln -sf "$(dirname "$nvm_node")/corepack" /usr/local/bin/corepack 2>/dev/null || true
        fi
        export PATH="/usr/local/bin:$PATH"
        if command -v node &>/dev/null; then
            ok "Node.js v$(node --version | sed 's/v//') installed via nvm"
            return 0
        fi
    fi

    err "All installation methods failed — install Node.js v24+ manually from https://nodejs.org"
    exit 1
}

install_node_arch() {
    info "Installing Node.js v24 on Arch Linux..."
    sudo pacman -S --noconfirm nodejs-lts-jod npm 2>/dev/null || {
        warn "LTS package not found, installing nodejs..."
        sudo pacman -S --noconfirm nodejs npm
    }
    ok "Node.js installed: $(node --version)"
}

install_ubuntu_deps() {
    info "Installing dependencies for Ubuntu/Debian..."

    sudo apt-get update -qq

    sudo apt-get install -y -qq \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        git \
        curl \
        build-essential \
        pkg-config \
        libssl-dev \
        libsodium-dev \
        libffi-dev \
        fonts-noto-color-emoji \
        || { err "Failed to install Ubuntu dependencies"; exit 1; }

    if ! check_node_version; then
        install_node_ubuntu
    fi

    # Ensure npm is available (may be missing on minimal Ubuntu installs)
    if ! command -v npm &>/dev/null; then
        info "Installing npm..."
        sudo apt-get install -y -qq npm 2>/dev/null || true
    fi
    # Install pnpm — try corepack first (built into Node 24+), fallback to npm

    if ! command -v pnpm &>/dev/null; then
        if command -v corepack &>/dev/null; then
            info "Enabling pnpm via corepack..."
            sudo corepack enable pnpm 2>/dev/null || true
        fi
        if ! command -v pnpm &>/dev/null; then
            info "Installing pnpm via npm..."
            sudo npm install -g pnpm
        fi
    fi

    if command -v pnpm &>/dev/null; then
        ok "pnpm: $(pnpm --version)"
    else
        warn "pnpm not found — frontend build will fail"
    fi

    if ! command -v uv &>/dev/null; then
        info "Installing uv (Python package manager)..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
        export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
        # Symlink uv to /usr/local/bin so it persists in the user's PATH
        if [ -f "$HOME/.cargo/bin/uv" ]; then
            sudo ln -sf "$HOME/.cargo/bin/uv" /usr/local/bin/uv
        elif [ -f "$HOME/.local/bin/uv" ]; then
            sudo ln -sf "$HOME/.local/bin/uv" /usr/local/bin/uv
        fi
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
        git \
        curl \
        base-devel \
        pkg-config \
        openssl \
        libsodium \
        libffi \
        noto-fonts-emoji \
        || { err "Failed to install Arch dependencies"; exit 1; }

    if ! check_node_version; then
        install_node_arch
    fi
    # Install pnpm — try corepack first (built into Node 24+), fallback to npm

    if ! command -v pnpm &>/dev/null; then
        if command -v corepack &>/dev/null; then
            info "Enabling pnpm via corepack..."
            sudo corepack enable pnpm 2>/dev/null || true
        fi
        if ! command -v pnpm &>/dev/null; then
            info "Installing pnpm via npm..."
            sudo npm install -g pnpm
        fi
    fi

    if command -v pnpm &>/dev/null; then
        ok "pnpm: $(pnpm --version)"
    else
        warn "pnpm not found — frontend build will fail"
    fi

    if ! command -v uv &>/dev/null; then
        info "Installing uv (Python package manager)..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
        export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
        # Symlink uv to /usr/local/bin so it persists in the user's PATH
        if [ -f "$HOME/.cargo/bin/uv" ]; then
            sudo ln -sf "$HOME/.cargo/bin/uv" /usr/local/bin/uv
        elif [ -f "$HOME/.local/bin/uv" ]; then
            sudo ln -sf "$HOME/.local/bin/uv" /usr/local/bin/uv
        fi
    fi

    ok "Arch dependencies installed."
}

install_project() {
    info "Installing MeshChatIV project dependencies..."
    cd "$(dirname "$0")/.."

    # Ensure Node.js/npm/pnpm are on PATH
    export PATH="/usr/local/bin:$HOME/.nvm/versions/node/$(node --version 2>/dev/null)/bin:$PATH"

    # Install Node.js dependencies
    info "Running: pnpm install"
    pnpm install

    # Build frontend assets
    info "Running: pnpm run build-frontend"
    pnpm run build-frontend

    # Install Python dependencies
    info "Setting up Python virtual environment..."
    uv sync --group dev 2>/dev/null || {
        warn "uv sync failed, trying pip install..."
        pip install --user -r requirements.txt 2>/dev/null || pip install -r requirements.txt
    }

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
echo -e "${BLUE}HOW TO RUN:${NC}"
echo ""
echo "  cd /path/to/MeshChatIV"
echo "  uv run python -m meshchatx.meshchat --headless --host 127.0.0.1"
echo ""
echo -e "${BLUE}Then open ${GREEN}http://127.0.0.1:8000${NC}${BLUE} in your browser.${NC}"
echo ""
echo -e "${BLUE}For desktop (Electron) mode:${NC}"
echo "  pnpm run electron"
echo ""
echo -e "${BLUE}TROUBLESHOOTING:${NC}"
echo "  - Make sure ports 4242 (TCP) and 4966 (RNS) are open in your firewall"
echo "  - For IPv4 direct connect, use the 'Direct Connect' tab in File Window"
echo "  - Default RNS config uses IPv6 AutoInterface - add TCP interfaces manually"
echo ""
