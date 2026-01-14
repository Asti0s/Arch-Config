#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_LIST="$SCRIPT_DIR/packages.txt"

BUILD_DIR="$HOME/install_tmp"

# --- 1. Initialization ---

init_foundation() {
    FOUNDATION_LIST="$SCRIPT_DIR/foundation.txt"
    if [ ! -f "$FOUNDATION_LIST" ]; then
        echo "Fresh system detected. Creating foundation list from current packages..."
        pacman -Qqe > "$FOUNDATION_LIST"
        echo "Foundation list saved to $FOUNDATION_LIST"
    fi
}

install_paru() {
    if ! command -v paru &> /dev/null; then
        echo "paru not found, installing..."
        sudo pacman -Syu --needed --noconfirm base-devel
        mkdir -p "$BUILD_DIR"
        pushd "$BUILD_DIR" > /dev/null || exit
        git clone https://aur.archlinux.org/paru.git
        pushd paru > /dev/null || exit
        makepkg -si --noconfirm
        popd > /dev/null || exit
        popd > /dev/null || exit
        rm -rf "$BUILD_DIR"
    fi
}

# --- 2. Package Management ---

sync_packages() {
    if [ -f "$PACKAGE_LIST" ]; then
        echo "Updating system and sync with $PACKAGE_LIST..."
        DESIRED_PACKAGES=$(grep -v '^#' "$PACKAGE_LIST" | grep -v '^$' | awk '{print $1}')
        echo "$DESIRED_PACKAGES" | paru -Syu --needed --noconfirm --asexplicit -
    else
        echo "Error: $PACKAGE_LIST not found."
        exit 1
    fi
}

cleanup_system() {
    echo "Cleaning up unintended packages..."
    CURRENT_EXPLICIT_PACKAGES=$(pacman -Qqe)
    FOUNDATION_PACKAGES=$(grep -v '^#' "$SCRIPT_DIR/foundation.txt" | grep -v '^$' | awk '{print $1}')
    DESIRED_PACKAGES=$(grep -v '^#' "$PACKAGE_LIST" | grep -v '^$' | awk '{print $1}')

    for pkg in $CURRENT_EXPLICIT_PACKAGES; do
        # Don't remove packages that are in the list
        if echo "$DESIRED_PACKAGES" | grep -qw "$pkg"; then
            continue
        fi

        # Don't remove packages that were on the base system
        if echo "$FOUNDATION_PACKAGES" | grep -qw "$pkg"; then
            continue
        fi

        echo "Removing $pkg..."
        sudo pacman -Rs --noconfirm "$pkg"
    done

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
    install_paru
    init_foundation
    sync_packages
    cleanup_system
#     setup_configs
}

main
