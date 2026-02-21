#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_LIST="$SCRIPT_DIR/packages.txt"

BUILD_DIR="./install_tmp"

# --- 1. Initialization ---

ensure_prerequisites() {
    echo ":: Ensuring base-devel and git are installed..."
    sudo pacman -Syu --needed --noconfirm base-devel git
}

init_foundation() {
    FOUNDATION_LIST="$SCRIPT_DIR/foundation.txt"
    if [ ! -f "$FOUNDATION_LIST" ]; then
        echo ":: Fresh system detected. Creating foundation list..."
        paru -Syu --noconfirm
        paru -Qqe | sort > "$FOUNDATION_LIST"
        echo ":: Foundation list saved with $(wc -l < "$FOUNDATION_LIST") packages."
    fi
}

install_paru() {
    if ! command -v paru &> /dev/null; then
        echo ":: paru not found. Installing from AUR..."
        mkdir -p "$BUILD_DIR"
        pushd "$BUILD_DIR" > /dev/null
        if [ ! -d "paru" ]; then
            git clone https://aur.archlinux.org/paru.git
        fi
        pushd paru > /dev/null
        makepkg -si --noconfirm
        popd > /dev/null
        popd > /dev/null
        rm -rf "$BUILD_DIR"
        echo ":: paru installed successfully."
    fi
}

# --- 2. Package Management ---

sync_packages() {
    if [ -f "$PACKAGE_LIST" ]; then
        echo ":: Syncing packages from $PACKAGE_LIST..."
        DESIRED_PACKAGES=$(grep -v '^#' "$PACKAGE_LIST" | grep -v '^$' | awk '{print $1}')

        if [ -n "$DESIRED_PACKAGES" ]; then
            echo "$DESIRED_PACKAGES" | paru -Syu --needed --noconfirm -
            echo ":: Package sync complete."
        else
            echo ":: No packages found in $PACKAGE_LIST."
        fi
    else
        echo "Error: $PACKAGE_LIST not found."
        exit 1
    fi
}

cleanup_system() {
    echo ":: Cleaning up unintended packages..."

    local current_explicit=$(mktemp)
    local desired_and_foundation=$(mktemp)

    paru -Qqe | sort > "$current_explicit"

    {
        grep -v '^#' "$PACKAGE_LIST" | grep -v '^$' | awk '{print $1}' || true
        grep -v '^#' "$SCRIPT_DIR/foundation.txt" | grep -v '^$' | awk '{print $1}' || true
    } | sort -u > "$desired_and_foundation"

    local to_remove
    to_remove=$(comm -23 "$current_explicit" "$desired_and_foundation")

    if [ -n "$to_remove" ]; then
        echo ":: Found unintended packages to remove:"
        echo "$to_remove"

        if ! paru -Rs --noconfirm $to_remove; then
            echo ":: Warning: Some packages could not be removed (check dependencies)."
        fi
    else
        echo ":: System is clean."
    fi

    rm "$current_explicit" "$desired_and_foundation"
    echo ":: Running paru cleanup for orphans and cache..."
    paru -c --noconfirm
}

# --- 3. Configuration ---

# setup_configs() {
#     echo "Setting up configurations..."
#     mkdir -p "$HOME/.config/hypr"
#     ln -sf "$SCRIPT_DIR/config/hypr/hyprland.conf" "$HOME/.config/hypr/hyprland.conf"
#     echo "Configurations linked successfully."
# }

# --- Main Entry Point ---

main() {
    ensure_prerequisites
    install_paru
    init_foundation
    sync_packages
    cleanup_system
#     setup_configs
    echo ":: System configuration successful."
}

main
