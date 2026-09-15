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

Uninstall Orby completely from your system and clean up all residual files.

Options:
  --keep-config  Keep user configuration and cache files (preserves settings).
  --clean-build  Also remove the local 'build/' directory in the source tree.
  --prefix <DIR> Specific prefix to target for uninstallation.
  -y, --yes      Assume yes to all prompts and run non-interactively.
  -h, --help     Show this help message.

Examples:
  $0                 # Complete uninstall (removes binary, icons, desktop entry, caches)
  $0 --clean-build   # Also removes CMake build directory
  $0 --keep-config   # Removes application but preserves user configs
EOF
    exit 0
}

KEEP_CONFIG=0
CLEAN_BUILD=0
CUSTOM_PREFIX=""
ASSUME_YES=0

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --keep-config)
            KEEP_CONFIG=1
            ;;
        --clean-build)
            CLEAN_BUILD=1
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
        -y|--yes)
            ASSUME_YES=1
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

# Resolve script dir and project root if running from repo
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"
PROJECT_ROOT=""
if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/../CMakeLists.txt" ]]; then
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

log_info "Starting Orby uninstallation..."

# 1. Terminate any running Orby instance
if pgrep -x "orby" >/dev/null 2>&1; then
    log_info "Stopping running Orby process..."
    pkill -x "orby" 2>/dev/null || true
    sleep 0.5
    if pgrep -x "orby" >/dev/null 2>&1; then
        pkill -9 -x "orby" 2>/dev/null || true
    fi
    log_ok "Terminated running Orby process."
fi

# Terminate any orphaned spoofed sleep background processes
if pkill -f "31536000" >/dev/null 2>&1; then
    log_ok "Terminated lingering spoofed processes."
fi

# 2. Collect potential installation prefixes
PREFIXES=()
if [[ -n "$CUSTOM_PREFIX" ]]; then
    PREFIXES+=("$CUSTOM_PREFIX")
else
    # Check user local, system local, and /usr
    PREFIXES+=("$HOME/.local" "/usr/local" "/usr")
fi

REMOVED_FILES=0
APP_DIRS_TO_UPDATE=()
ICON_DIRS_TO_UPDATE=()

# 3. Remove installed binaries, desktop files, icons, and licenses
for p in "${PREFIXES[@]}"; do
    BIN_FILE="$p/bin/orby"
    DESKTOP_FILE="$p/share/applications/orby.desktop"
    ICON_SVG="$p/share/icons/hicolor/scalable/apps/orby.svg"
    ICON_PNG="$p/share/icons/hicolor/256x256/apps/orby.png"
    LICENSE_DIR="$p/share/licenses/orby"

    if [[ -f "$BIN_FILE" ]]; then
        if rm -f "$BIN_FILE" 2>/dev/null; then
            echo -e " ${GREEN}✓${NC} Removed binary ($BIN_FILE)"
            REMOVED_FILES=$((REMOVED_FILES + 1))
        else
            log_warn "Permission denied removing $BIN_FILE (may need sudo)."
        fi
    fi

    if [[ -f "$DESKTOP_FILE" ]]; then
        if rm -f "$DESKTOP_FILE" 2>/dev/null; then
            echo -e " ${GREEN}✓${NC} Removed desktop entry ($DESKTOP_FILE)"
            REMOVED_FILES=$((REMOVED_FILES + 1))
            APP_DIRS_TO_UPDATE+=("$p/share/applications")
        else
            log_warn "Permission denied removing $DESKTOP_FILE (may need sudo)."
        fi
    fi

    if [[ -f "$ICON_SVG" ]]; then
        if rm -f "$ICON_SVG" "$p/share/icons/hicolor/scalable/apps/orby-tray.svg" "$p/share/icons/hicolor/scalable/apps/orby-tray-dark.svg" 2>/dev/null; then
            echo -e " ${GREEN}✓${NC} Removed SVG icons"
            REMOVED_FILES=$((REMOVED_FILES + 1))
            ICON_DIRS_TO_UPDATE+=("$p/share/icons/hicolor")
        else
            log_warn "Permission denied removing SVG icons (may need sudo)."
        fi
    fi

    if [[ -f "$ICON_PNG" ]]; then
        if rm -f "$ICON_PNG" 2>/dev/null; then
            echo -e " ${GREEN}✓${NC} Removed PNG icon ($ICON_PNG)"
            REMOVED_FILES=$((REMOVED_FILES + 1))
            ICON_DIRS_TO_UPDATE+=("$p/share/icons/hicolor")
            # Clean up empty directory if empty
            rmdir "$p/share/icons/hicolor/256x256/apps" 2>/dev/null || true
            rmdir "$p/share/icons/hicolor/256x256" 2>/dev/null || true
        else
            log_warn "Permission denied removing PNG icon (may need sudo)."
        fi
    fi

    if [[ -d "$LICENSE_DIR" ]]; then
        rm -rf "$LICENSE_DIR" 2>/dev/null || true
    fi
done

if [[ $REMOVED_FILES -eq 0 ]]; then
    log_info "No installed program files were found in target prefixes."
fi

# 4. Clean configuration, cache, and residual runtime trash
if [[ $KEEP_CONFIG -eq 0 ]]; then
    log_info "Cleaning configuration, cache, and runtime state..."
    
    DIRS_TO_CLEAN=(
        "${XDG_CONFIG_HOME:-$HOME/.config}/orby"
        "${XDG_CONFIG_HOME:-$HOME/.config}/Orby"
        "${XDG_CACHE_HOME:-$HOME/.cache}/orby"
        "${XDG_CACHE_HOME:-$HOME/.cache}/Orby"
        "${XDG_DATA_HOME:-$HOME/.local/share}/orby"
        "${XDG_DATA_HOME:-$HOME/.local/share}/Orby"
        "${XDG_STATE_HOME:-$HOME/.local/state}/orby"
        "${XDG_STATE_HOME:-$HOME/.local/state}/Orby"
    )

    CLEANED_DIRS=0
    for dir in "${DIRS_TO_CLEAN[@]}"; do
        if [[ -d "$dir" ]]; then
            rm -rf "$dir"
            echo -e " ${GREEN}✓${NC} Cleaned $dir"
            CLEANED_DIRS=$((CLEANED_DIRS + 1))
        fi
    done

    if [[ $CLEANED_DIRS -eq 0 ]]; then
        echo -e " ${GREEN}✓${NC} No leftover config/cache directories found."
    fi
else
    log_info "Preserving user configuration and cache files (--keep-config specified)."
fi

# 5. Clean local build directory if requested
if [[ $CLEAN_BUILD -eq 1 && -n "$PROJECT_ROOT" && -d "$PROJECT_ROOT/build" ]]; then
    log_info "Removing build directory: $PROJECT_ROOT/build"
    rm -rf "$PROJECT_ROOT/build"
    echo -e " ${GREEN}✓${NC} Cleaned build directory"
fi

# 6. Update desktop and icon caches
for app_dir in "${APP_DIRS_TO_UPDATE[@]}"; do
    if [[ -d "$app_dir" ]] && command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$app_dir" >/dev/null 2>&1 || true
    fi
done

for icon_dir in "${ICON_DIRS_TO_UPDATE[@]}"; do
    if [[ -d "$icon_dir" ]] && command -v gtk-update-icon-cache >/dev/null 2>&1; then
        gtk-update-icon-cache -f -t -q "$icon_dir" >/dev/null 2>&1 || true
    fi
done

echo ""
log_ok "Uninstallation complete! System is clean."
