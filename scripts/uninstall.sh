#!/usr/bin/env bash
set -euo pipefail

# MeshChatIV Uninstall Script
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

confirm() {
    echo -e -n "${YELLOW}$1 [y/N]${NC} "
    read -r response
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

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

remove_ubuntu_packages() {
    info "Removing MeshChatIV system packages (Ubuntu/Debian)..."

    if confirm "Remove Node.js v24 (if installed via NodeSource for MeshChat)?"; then
        info "Removing NodeSource repository and Node.js..."
        sudo rm -f /etc/apt/sources.list.d/nodesource.list 2>/dev/null || true
        sudo apt-get remove --purge -y -qq nodejs 2>/dev/null || true
        sudo apt-get autoremove --purge -y -qq 2>/dev/null || true
        warn "If you installed Node.js via another method, remove it manually."
    fi

    if confirm "Remove pnpm (globally installed)?"; then
        sudo npm uninstall -g pnpm 2>/dev/null || true
    fi

    if confirm "Remove uv (globally installed)?"; then
        rm -f "$HOME/.cargo/bin/uv" "$HOME/.local/bin/uv" 2>/dev/null || true
        warn "uv binary removed. To fully remove uv, also check ~/.cargo and ~/.local directories."
    fi

    ok "Ubuntu packages removed."
}

remove_arch_packages() {
    info "Removing MeshChatIV system packages (Arch Linux)..."

    # Note: core dependencies like python, nodejs, git are usually needed
    # by other software, so we only remove optional tooling.

    if confirm "Remove pnpm?"; then
        sudo npm uninstall -g pnpm 2>/dev/null || sudo pacman -Rns --noconfirm pnpm 2>/dev/null || true
    fi

    if confirm "Remove uv?"; then
        rm -f "$HOME/.cargo/bin/uv" "$HOME/.local/bin/uv" 2>/dev/null || true
    fi

    ok "Arch packages removed."
}

remove_reticulum_config() {
    if confirm "Remove Reticulum configuration and identities (shared with other Reticulum apps)?"; then
        warn "This will remove ~/.reticulum entirely, affecting ALL Reticulum applications."
        if confirm "  Really remove ~/.reticulum?"; then
            rm -rf "$HOME/.reticulum"
            ok "Reticulum config removed."
        fi
    else
        if confirm "Remove MeshChat-added TCP interfaces from Reticulum config?"; then
            local rconfig="$HOME/.reticulum/config"
            if [ -f "$rconfig" ]; then
                # Create a backup
                cp "$rconfig" "${rconfig}.meshchat-backup-$(date +%s)"
                # Remove TCPClientInterface and TCPServerInterface sections added by MeshChat
                awk '
                    /^\[TCPClientInterface\]/ { skip=1 }
                    /^\[TCPServerInterface\]/ { skip=1 }
                    /^\[/ && !/^\[TCPClientInterface\]/ && !/^\[TCPServerInterface\]/ { skip=0 }
                    !skip { print }
                ' "$rconfig" > "${rconfig}.tmp" && mv "${rconfig}.tmp" "$rconfig"
                ok "TCP interfaces removed from Reticulum config."
            else
                warn "No Reticulum config found at ~/.reticulum/config"
            fi
        fi
    fi
}

remove_project_files() {
    info "Removing MeshChatIV project artifacts..."

    local project_dir
    project_dir="$(cd "$(dirname "$0")/.." && pwd)"

    if confirm "Remove node_modules directory?"; then
        rm -rf "$project_dir/node_modules"
        ok "node_modules removed."
    fi

    if confirm "Remove Python virtual environment (.venv)?"; then
        rm -rf "$project_dir/.venv"
        ok "Virtual environment removed."
    fi

    if confirm "Remove build artifacts (dist/ directory)?"; then
        rm -rf "$project_dir/dist"
        ok "Build artifacts removed."
    fi

    if confirm "Remove storage data directory?"; then
        rm -rf "$project_dir/storage"
        ok "Storage data removed."
    fi

    if confirm "Remove the entire MeshChatIV project directory?"; then
        cd /
        rm -rf "$project_dir"
        ok "Project directory removed."
        echo ""
        warn "The project directory has been deleted. You may need to cd to another directory."
        return 0
    fi

    ok "Project artifacts cleaned."
}

# --- Main ---

echo ""
echo "========================================"
echo "  MeshChatIV Uninstall"
echo "========================================"
echo ""

if ! confirm "This will remove MeshChatIV components. Continue?"; then
    echo "Uninstall cancelled."
    exit 0
fi

detect_distro

case "$DISTRO" in
    ubuntu|debian|linuxmint|pop|elementary|zorin)
        remove_ubuntu_packages
        ;;
    arch|archarm|manjaro|endeavouros|artix|garuda)
        remove_arch_packages
        ;;
    *)
        warn "Unknown distribution: $DISTRO"
        warn "Attempting generic cleanup..."
        remove_ubuntu_packages
        ;;
esac

remove_project_files

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  MeshChatIV uninstall complete.${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Note: Core system packages (python, nodejs, git, etc.) were kept"
echo "as they may be needed by other software."
echo ""
echo "----------------------------------------"
echo "  Uninstall Old MeshChatIV Version"
echo "----------------------------------------"
echo ""
echo "If you had an older MeshChatIV installation (before the new"
echo "RNS file sharing and Direct Connect features), it used the old"
echo "RNCP file handler and may have lxmf-based or older storage files."
echo ""
echo "To clean up from an old version, run these commands manually:"
echo ""
echo "  # Remove old storage (if any)"
echo "  rm -rf /path/to/MeshChatIV/storage"
echo ""
echo "  # Remove old virtual environment"
echo "  rm -rf /path/to/MeshChatIV/.venv"
echo ""
echo "  # Remove old Reticulum config (shared with other RNS apps)"
echo "  rm -rf ~/.reticulum"
echo ""
echo "  # Uninstall old system Node.js version (if v20 or older was used)"
echo "  # Ubuntu/Debian:"
echo "  sudo apt-get remove --purge nodejs"
echo "  # Arch:"
echo "  sudo pacman -Rns nodejs"
echo ""
echo "  # Remove globally installed npm packages from old installation"
echo "  sudo npm uninstall -g pnpm"
echo ""
echo "  # Remove the old project directory"
echo "  rm -rf /path/to/MeshChatIV"
echo ""
