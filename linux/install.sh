#!/usr/bin/env bash
set -Eeuo pipefail

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

trap 'log_error "An error occurred on line $LINENO. Exiting."; exit 1' ERR

show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --build    Force rebuild of the project."
    echo "  --clean    Remove the build directory before building."
    echo "  --help     Show this help message."
    exit 0
}

FORCE_BUILD=0
CLEAN_BUILD=0

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --build) FORCE_BUILD=1 ;;
        --clean) CLEAN_BUILD=1 ;;
        --help) show_help ;;
        *) log_error "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Verify we are in the project root
if [[ ! -f "CMakeLists.txt" || ! -f "linux/orby.desktop" || ! -f "icons/orby.svg" ]]; then
    log_error "Must be run from the project root containing CMakeLists.txt, linux/orby.desktop, and icons/orby.svg."
    exit 1
fi

# Check required dependencies
REQUIRED_CMDS=("cmake" "install" "sed" "nproc" "chmod")
for cmd in "${REQUIRED_CMDS[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log_error "Required command '$cmd' is not installed or not in PATH."
        exit 1
    fi
done

# Determine installation paths based on privileges
if [[ "$EUID" -eq 0 ]]; then
    BIN_DIR="/usr/local/bin"
    APP_DIR="/usr/local/share/applications"
    ICON_DIR="/usr/local/share/icons/hicolor/scalable/apps"
else
    BIN_DIR="$HOME/.local/bin"
    APP_DIR="$HOME/.local/share/applications"
    ICON_DIR="$HOME/.local/share/icons/hicolor/scalable/apps"
fi

if [[ $CLEAN_BUILD -eq 1 ]]; then
    log_info "Cleaning previous build directory..."
    rm -rf build
fi

EXECUTABLE_PATH="build/orby"

# Build if necessary
if [[ ! -f "$EXECUTABLE_PATH" || $FORCE_BUILD -eq 1 ]]; then
    log_info "Building Orby..."
    cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
    cmake --build build -j"$(nproc)"
    log_ok "Build successful."
else
    log_info "Release binary found. Skipping build. (Use --build to force rebuild)"
fi

# Verify executable exists
if [[ ! -f "$EXECUTABLE_PATH" ]]; then
    log_error "Executable not found at $EXECUTABLE_PATH after build."
    exit 1
fi

log_info "Installing Orby to $BIN_DIR..."

# Install Executable
install -Dm755 "$EXECUTABLE_PATH" "$BIN_DIR/orby"

# Install Icon
install -Dm644 "icons/orby.svg" "$ICON_DIR/orby.svg"

# Install Desktop Entry
install -Dm644 "linux/orby.desktop" "$APP_DIR/orby.desktop"

# Update paths in desktop file
sed -i "s|^Exec=.*|Exec=$BIN_DIR/orby|g" "$APP_DIR/orby.desktop"
sed -i "s|^Icon=.*|Icon=$ICON_DIR/orby.svg|g" "$APP_DIR/orby.desktop"

# Update desktop caches
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$APP_DIR" || log_warn "Failed to update desktop database."
else
    log_warn "update-desktop-database not found. Skipping cache update."
fi

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f -t "$ICON_DIR/../.." || log_warn "Failed to update icon cache."
else
    log_warn "gtk-update-icon-cache not found. Skipping cache update."
fi

log_info "Verifying installed files..."
[[ -f "$BIN_DIR/orby" ]] && echo " ✓ executable ($BIN_DIR/orby)" || log_error "Failed to verify executable."
[[ -f "$APP_DIR/orby.desktop" ]] && echo " ✓ desktop entry ($APP_DIR/orby.desktop)" || log_error "Failed to verify desktop entry."
[[ -f "$ICON_DIR/orby.svg" ]] && echo " ✓ icon ($ICON_DIR/orby.svg)" || log_error "Failed to verify icon."

log_ok "Installation complete! Orby is ready to use."
