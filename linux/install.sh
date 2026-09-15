#!/usr/bin/env bash
set -Eeuo pipefail

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

trap 'log_error "An error occurred on line $LINENO. Exiting."; exit 1' ERR

show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Install Orby on Linux with desktop menu and icon theme integration.

Options:
  --user         Install for the current user only (~/.local). [Default for non-root]
  --system       Install system-wide (/usr/local). [Default for root]
  --prefix <DIR> Install to a custom directory prefix (e.g. /usr, /opt/orby).
  --build        Force rebuild of the project even if binary exists.
  --clean        Remove previous build directory before building.
  -h, --help     Show this help message.

Examples:
  $0                 # Automatic user or system install based on privileges
  $0 --build         # Rebuild and install
  sudo $0 --system   # System-wide install to /usr/local
EOF
    exit 0
}

# Resolve project root regardless of where script is called from
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# Verify required project files exist
if [[ ! -f "CMakeLists.txt" || ! -f "linux/orby.desktop" || ! -f "icons/orby.svg" || ! -f "icons/orby.png" ]]; then
    log_error "Could not find project files in $PROJECT_ROOT."
    exit 1
fi

FORCE_BUILD=0
CLEAN_BUILD=0
CUSTOM_PREFIX=""
INSTALL_MODE=""

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --user)
            INSTALL_MODE="user"
            ;;
        --system)
            INSTALL_MODE="system"
            ;;
        --prefix)
            if [[ -n "${2:-}" ]]; then
                CUSTOM_PREFIX="$2"
                shift
            else
                log_error "--prefix requires a path argument."
                exit 1
            fi
            ;;
        --build)
            FORCE_BUILD=1
            ;;
        --clean)
            CLEAN_BUILD=1
            ;;
        -h|--help)
            show_help
            ;;
        *)
            log_error "Unknown parameter: $1"
            show_help
            ;;
    esac
    shift
done

# Check required build commands
REQUIRED_CMDS=("cmake" "install" "sed" "nproc" "chmod")
for cmd in "${REQUIRED_CMDS[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log_error "Required command '$cmd' is not installed or not in PATH."
        exit 1
    fi
done

# Determine installation paths
if [[ -n "$CUSTOM_PREFIX" ]]; then
    PREFIX="$CUSTOM_PREFIX"
elif [[ "$INSTALL_MODE" == "system" ]] || [[ "$EUID" -eq 0 && "$INSTALL_MODE" != "user" ]]; then
    PREFIX="/usr/local"
else
    PREFIX="$HOME/.local"
fi

BIN_DIR="$PREFIX/bin"
APP_DIR="$PREFIX/share/applications"
ICON_SCALABLE_DIR="$PREFIX/share/icons/hicolor/scalable/apps"
ICON_PNG_DIR="$PREFIX/share/icons/hicolor/256x256/apps"
ICON_THEME_DIR="$PREFIX/share/icons/hicolor"

# Check write permissions for target prefix
if [[ ! -w "$PREFIX" && -d "$PREFIX" ]] || { [[ ! -d "$PREFIX" ]] && ! mkdir -p "$PREFIX" 2>/dev/null; }; then
    log_error "Cannot write to prefix '$PREFIX'. Try running with sudo or use '--user'."
    exit 1
fi

# Clean previous build if requested
if [[ $CLEAN_BUILD -eq 1 && -d "build" ]]; then
    log_info "Cleaning previous build directory..."
    rm -rf build
fi

EXECUTABLE_PATH="build/orby"

# Build if necessary
if [[ ! -f "$EXECUTABLE_PATH" || $FORCE_BUILD -eq 1 ]]; then
    log_info "Configuring and compiling Orby (Release)..."
    cmake -B build -DCMAKE_BUILD_TYPE=Release
    cmake --build build -j"$(nproc)"
    log_ok "Compilation successful."
else
    log_info "Existing binary found at $EXECUTABLE_PATH. Skipping build. (Use --build to rebuild)"
fi

# Verify executable exists
if [[ ! -f "$EXECUTABLE_PATH" ]]; then
    log_error "Executable not found at $EXECUTABLE_PATH after build."
    exit 1
fi

log_info "Installing Orby to: $PREFIX"

# Install binary
install -Dm755 "$EXECUTABLE_PATH" "$BIN_DIR/orby"
log_ok "Installed binary to $BIN_DIR/orby"

# Install icons (scalable SVG + 256x256 PNG for standard XDG icon theme compatibility)
install -Dm644 "icons/orby.svg" "$ICON_SCALABLE_DIR/orby.svg"
install -Dm644 "icons/orby-tray.svg" "$ICON_SCALABLE_DIR/orby-tray.svg"
install -Dm644 "icons/orby-tray-dark.svg" "$ICON_SCALABLE_DIR/orby-tray-dark.svg"
install -Dm644 "icons/orby.png" "$ICON_PNG_DIR/orby.png"
log_ok "Installed icons to $ICON_THEME_DIR"

# Install Desktop Entry
install -Dm644 "linux/orby.desktop" "$APP_DIR/orby.desktop"

# Set exact binary path for user installs to guarantee desktop launchers find it
if [[ "$PREFIX" == "$HOME/.local" || "$PREFIX" != "/usr" && "$PREFIX" != "/usr/local" ]]; then
    sed -i "s|^Exec=.*|Exec=$BIN_DIR/orby|g" "$APP_DIR/orby.desktop"
fi
log_ok "Installed desktop entry to $APP_DIR/orby.desktop"

# Install License
if [[ -f "LICENSE" ]]; then
    install -Dm644 "LICENSE" "$PREFIX/share/licenses/orby/LICENSE" 2>/dev/null || true
fi

# Ensure hicolor icon theme index exists so cache update succeeds
if [[ ! -f "$ICON_THEME_DIR/index.theme" ]]; then
    if [[ -f "/usr/share/icons/hicolor/index.theme" ]]; then
        ln -sf "/usr/share/icons/hicolor/index.theme" "$ICON_THEME_DIR/index.theme" 2>/dev/null || true
    fi
fi

# Update desktop database cache
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$APP_DIR" >/dev/null 2>&1 || log_warn "Could not update desktop database."
fi

# Update icon theme cache
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f -t -q "$ICON_THEME_DIR" >/dev/null 2>&1 || true
fi

# Verification of installed files
log_info "Verifying installed components..."
[[ -f "$BIN_DIR/orby" ]] && echo -e " ${GREEN}✓${NC} executable ($BIN_DIR/orby)" || log_error "Failed to verify binary."
[[ -f "$APP_DIR/orby.desktop" ]] && echo -e " ${GREEN}✓${NC} desktop entry ($APP_DIR/orby.desktop)" || log_error "Failed to verify desktop entry."
[[ -f "$ICON_SCALABLE_DIR/orby.svg" ]] && echo -e " ${GREEN}✓${NC} scalable icon ($ICON_SCALABLE_DIR/orby.svg)" || log_error "Failed to verify SVG icon."
[[ -f "$ICON_PNG_DIR/orby.png" ]] && echo -e " ${GREEN}✓${NC} 256x256 icon ($ICON_PNG_DIR/orby.png)" || log_error "Failed to verify PNG icon."

# Check if BIN_DIR is in PATH
PATH_FOUND=0
IFS=':' read -ra ADDR <<< "$PATH"
for p in "${ADDR[@]}"; do
    if [[ "${p%/}" == "${BIN_DIR%/}" ]]; then
        PATH_FOUND=1
        break
    fi
done

echo ""
log_ok "Orby installed successfully!"

if [[ $PATH_FOUND -eq 0 ]]; then
    log_warn "'$BIN_DIR' is not in your current PATH."
    echo -e "${CYAN}[TIP]${NC} To launch Orby directly by typing 'orby' in your terminal, add it to your PATH:"
    echo -e "      ${CYAN}echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> ~/.bashrc${NC}  (or ~/.zshrc)"
    echo -e "      or run directly via: ${CYAN}$BIN_DIR/orby${NC}"
else
    echo -e "You can now launch Orby from your application menu or via terminal with: ${CYAN}orby${NC}"
fi
