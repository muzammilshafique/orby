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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

if ! command -v cmake >/dev/null 2>&1; then
    log_error "cmake command not found. Please install cmake."
    exit 1
fi

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
    VERSION=$(grep -oP 'project\(\s*Orby\s+VERSION\s+\K[0-9.]+' CMakeLists.txt || echo "1.0.0")
fi
# Strip leading 'v' if provided
VERSION="${VERSION#v}"

log_info "Packaging Orby version $VERSION for Debian/Ubuntu (.deb)..."

BUILD_DIR="$PROJECT_ROOT/build-deb-pkg"
mkdir -p "$BUILD_DIR"

cmake -B "$BUILD_DIR" -S "$PROJECT_ROOT" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCPACK_PACKAGE_VERSION="$VERSION"

cmake --build "$BUILD_DIR" -j"$(nproc)"

cd "$BUILD_DIR"
cpack -G DEB

mkdir -p "$PROJECT_ROOT/dist"
mv *.deb "$PROJECT_ROOT/dist/"

cd "$PROJECT_ROOT"
rm -rf "$BUILD_DIR"

log_ok "Debian package created successfully:"
ls -lh dist/*.deb
