#!/bin/sh
set -e

PERSISTENT_DIR="/live/persistence/TailsData_unlocked/Persistent"
DOTFILES_DIR="/live/persistence/TailsData_unlocked/dotfiles"
SCRIPT_PATH="$(readlink -f "$0")"

echo ""
echo "This will uninstall Signal, Flatpak, and all related configuration from your Tails system."
echo "Press Ctrl+C now to cancel."
echo "Continuing in 6 seconds..."
sleep 6

echo ""
echo "Uninstalling Signal Messenger and Flatpak from Tails"
echo "----------------------------------------------------"

# Stop Signal if running
if pgrep -f org.signal.Signal >/dev/null 2>&1; then
  echo "Signal is currently running. Stopping it..."
  flatpak kill org.signal.Signal 2>/dev/null || pkill -f org.signal.Signal
else
  echo "Signal is not running."
fi

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

# Important warning about Additional Software
echo ""
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "!!! IMPORTANT: Tails will likely show a notification asking if you want to"
echo "!!! remove 'flatpak' from Additional Software. You MUST click 'Remove' or"
echo "!!! Tails will reinstall flatpak again at next boot."
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo ""

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
