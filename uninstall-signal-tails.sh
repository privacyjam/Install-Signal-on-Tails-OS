#!/bin/sh
set -e

PERSISTENT_DIR="/live/persistence/TailsData_unlocked/Persistent"
DOTFILES_DIR="/live/persistence/TailsData_unlocked/dotfiles"
SCRIPT_PATH="$(readlink -f "$0")"

echo ""
echo "Uninstalling Signal Messenger and Flatpak from Tails"
echo "----------------------------------------------------"

# Remove Signal flatpak app
if flatpak list | grep -q org.signal.Signal; then
  echo "Removing Signal..."
  flatpak uninstall -y org.signal.Signal || true
else
  echo "Signal not installed via flatpak."
fi

# Remove flathub repo (optional)
flatpak remote-delete --user flathub 2>/dev/null || true

# Remove flatpak (apt package)
if dpkg -s flatpak >/dev/null 2>&1; then
  echo "Removing flatpak (apt)..."
  sudo apt remove -y flatpak
else
  echo "Flatpak not installed via apt."
fi

# Delete persistent flatpak data
echo "Cleaning up persistent storage..."
rm -rf "$PERSISTENT_DIR/flatpak"
rm -rf "$PERSISTENT_DIR/app"
rm -f "$PERSISTENT_DIR/flatpak-setup.sh"
rm -f "$PERSISTENT_DIR/signal.sh"
rm -f "$PERSISTENT_DIR/.signal-setup-state"

# Remove GNOME app launcher
rm -f "$DOTFILES_DIR/.local/share/applications/Signal.desktop"

# Remove autostart entry
rm -f "$DOTFILES_DIR/.config/autostart/FlatpakSetup.desktop"

# Remove broken symlinks (if still present)
rm -rf "$HOME/.local/share/flatpak"
rm -rf "$HOME/.var/app"

echo ""
echo "Uninstall complete."
echo "Flatpak and Signal have been removed from your Tails system."

# === Optional cleanup ===
read -p "Do you want to delete this uninstall script now? [y/N]: " CLEANUP
if echo "$CLEANUP" | grep -iq "^y"; then
  echo "Removing uninstall script..."
  rm -f "$SCRIPT_PATH"
  echo "Cleanup complete."
else
  echo "You can leave this script in ~/Persistent in case you want to use it again."
fi
