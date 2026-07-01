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

if [[ "$EUID" -eq 0 ]]; then
    BIN_DIR="/usr/local/bin"
    APP_DIR="/usr/local/share/applications"
    ICON_DIR="/usr/local/share/icons/hicolor/scalable/apps"
else
    BIN_DIR="$HOME/.local/bin"
    APP_DIR="$HOME/.local/share/applications"
    ICON_DIR="$HOME/.local/share/icons/hicolor/scalable/apps"
fi

log_info "Uninstalling Orby..."

if [[ -f "$BIN_DIR/Orby-Linux" ]]; then
    rm -f "$BIN_DIR/Orby-Linux"
    echo " ✓ removed executable"
else
    log_warn "Executable not found at $BIN_DIR/Orby-Linux"
fi

if [[ -f "$APP_DIR/orby.desktop" ]]; then
    rm -f "$APP_DIR/orby.desktop"
    echo " ✓ removed desktop entry"
else
    log_warn "Desktop entry not found at $APP_DIR/orby.desktop"
fi

if [[ -f "$ICON_DIR/orby.svg" ]]; then
    rm -f "$ICON_DIR/orby.svg"
    echo " ✓ removed icon"
else
    log_warn "Icon not found at $ICON_DIR/orby.svg"
fi

# Update desktop caches
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$APP_DIR" || log_warn "Failed to update desktop database."
fi

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f -t "$ICON_DIR/../.." || log_warn "Failed to update icon cache."
fi

log_ok "Uninstallation complete. Configuration files have not been deleted."
