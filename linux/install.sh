#!/usr/bin/env bash
set -e

# Orby Linux Installer

echo "Installing Orby..."

# Determine installation paths based on privileges
if [ "$EUID" -eq 0 ]; then
    BIN_DIR="/usr/local/bin"
    APP_DIR="/usr/local/share/applications"
    ICON_DIR="/usr/local/share/icons/hicolor/scalable/apps"
else
    BIN_DIR="$HOME/.local/bin"
    APP_DIR="$HOME/.local/share/applications"
    ICON_DIR="$HOME/.local/share/icons/hicolor/scalable/apps"
fi

echo "Building Orby..."
mkdir -p build
cd build
if cmake -DCMAKE_BUILD_TYPE=Release .. && cmake --build . -j$(nproc); then
    echo "✅ Build passed successfully!"
    cd ..
else
    echo "❌ Build failed! Please check the errors above."
    exit 1
fi

# Create target directories
mkdir -p "$BIN_DIR"
mkdir -p "$APP_DIR"
mkdir -p "$ICON_DIR"

# Install Executable
echo "Installing executable to $BIN_DIR/Orby-Linux"
cp build/Orby-Linux "$BIN_DIR/Orby-Linux"
chmod +x "$BIN_DIR/Orby-Linux"

# Install Icon
echo "Installing icon to $ICON_DIR/orby.svg"
cp icons/orby.svg "$ICON_DIR/orby.svg"

# Install Desktop Entry
echo "Installing desktop entry to $APP_DIR/orby.desktop"
cp linux/orby.desktop "$APP_DIR/orby.desktop"

# Update Exec and Icon paths in desktop file
sed -i "s|^Exec=.*|Exec=$BIN_DIR/Orby-Linux|g" "$APP_DIR/orby.desktop"
sed -i "s|^Icon=.*|Icon=$ICON_DIR/orby.svg|g" "$APP_DIR/orby.desktop"

# Update caches if utilities are present
if command -v update-desktop-database >/dev/null 2>&1; then
    echo "Updating desktop database..."
    update-desktop-database "$APP_DIR" || true
fi

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    echo "Updating icon cache..."
    gtk-update-icon-cache -f -t "$ICON_DIR/../.." || true
fi

echo "Installation complete! You can now launch Orby from your application menu."
