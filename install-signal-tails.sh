#!/bin/sh
set -e

PERSISTENT_DIR="/live/persistence/TailsData_unlocked/Persistent"
DOTFILES_DIR="/live/persistence/TailsData_unlocked/dotfiles"
STATE_FILE="$PERSISTENT_DIR/.signal-setup-state"
SCRIPT_PATH="$(readlink -f "$0")"

echo ""
echo "Signal Messenger Setup for Tails"
echo "--------------------------------"

# === Check required persistence ===
if [ ! -d "$PERSISTENT_DIR" ]; then
  echo "ERROR: Persistence not enabled. Enable 'Personal Data' and reboot before using this script."
  exit 1
fi

if [ ! -d "$DOTFILES_DIR" ]; then
  echo "ERROR: Dotfiles persistence not enabled. Enable 'Dotfiles' and reboot before using this script."
  exit 1
fi

# === Check script location ===
case "$SCRIPT_PATH" in
  "$PERSISTENT_DIR"/*|"$HOME/Persistent"/*)
    ;;
  *)
    echo "ERROR: This script must be inside your Persistent folder to work reliably."
    echo "       Move it to ~/Persistent and run it from there."
    exit 1
    ;;
esac

# === Step 1: Initial Setup ===
if [ ! -f "$STATE_FILE" ]; then
  echo "Step 1: Installing flatpak and setting up persistence..."

  # Install flatpak
  if ! command -v flatpak >/dev/null 2>&1; then
    echo "Installing flatpak..."
    sudo apt update && sudo apt install -y flatpak
  else
    echo "Flatpak already installed."
  fi

  # Set up persistent flatpak data dirs
  echo "Setting up persistent flatpak directories..."
  mkdir -p "$PERSISTENT_DIR/flatpak" "$PERSISTENT_DIR/app" "$HOME/.local/share" "$HOME/.var"
  rm -rf --one-file-system "$HOME/.local/share/flatpak"
  rm -rf --one-file-system "$HOME/.var/app"
  ln -sf "$PERSISTENT_DIR/flatpak" "$HOME/.local/share/flatpak"
  ln -sf "$PERSISTENT_DIR/app" "$HOME/.var/app"

  # Create Signal launcher script
  echo "Creating Signal launcher script..."
  cat > "$PERSISTENT_DIR/signal.sh" <<EOF
#!/bin/sh
export HTTP_PROXY=socks://127.0.0.1:9050
export HTTPS_PROXY=socks://127.0.0.1:9050
flatpak run org.signal.Signal
EOF
  chmod +x "$PERSISTENT_DIR/signal.sh"

  # GNOME launcher
  mkdir -p "$DOTFILES_DIR/.local/share/applications"
  cat > "$DOTFILES_DIR/.local/share/applications/Signal.desktop" <<EOF
[Desktop Entry]
Name=Signal Messenger
GenericName=Private Chat App
Exec=$PERSISTENT_DIR/signal.sh
Terminal=false
Type=Application
Icon=$HOME/.local/share/flatpak/app/org.signal.Signal/current/active/files/share/icons/hicolor/128x128/apps/org.signal.Signal.png
EOF

  # Save state
  touch "$STATE_FILE"

  echo ""
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  echo "IMPORTANT: Right now, Tails will prompt you to add flatpak to additional software."
  echo "           You MUST click 'Install Every Time' in the prompt or Signal will not work."
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  echo ""
  echo "Step 1 complete."
  echo "Please REBOOT now, then run this script again to finish installing Signal."
  exit 0
fi

# === Step 2: After Reboot ===
echo "Step 2: Waiting for flatpak to finish loading..."

# Wait until flatpak is available (max 120 sec)
echo "Waiting up to 2 minutes for Additional Software to finish loading..."
i=0
while ! command -v flatpak >/dev/null 2>&1; do
  sleep 2
  i=$((i+2))
  if [ $i -ge 120 ]; then
    echo "ERROR: Flatpak still isn't available after 2 minutes. Try running the script again manually later."
    exit 1
  fi
done

# Re-ensure symlinks (just in case)
mkdir -p "$PERSISTENT_DIR/flatpak" "$PERSISTENT_DIR/app" "$HOME/.local/share" "$HOME/.var"
rm -rf --one-file-system "$HOME/.local/share/flatpak"
rm -rf --one-file-system "$HOME/.var/app"
ln -sf "$PERSISTENT_DIR/flatpak" "$HOME/.local/share/flatpak"
ln -sf "$PERSISTENT_DIR/app" "$HOME/.var/app"

# Install Signal
echo "Installing Signal via Flatpak..."
torify flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
torify flatpak install -y flathub org.signal.Signal

# Cleanup
rm -f "$STATE_FILE"

echo ""
echo "Signal is now fully installed!"
echo "You can launch it from the Applications menu or run:"
echo "   $PERSISTENT_DIR/signal.sh"
echo ""
echo "Note:"
echo " - The first time you open Signal after a reboot, it may take ~30 seconds to launch."
echo " - This is normal. Just be patient — it's loading via Flatpak over Tor."
echo ""

# === Optional cleanup ===
read -p "Do you want to remove this setup script now? [y/N]: " CLEANUP
if echo "$CLEANUP" | grep -iq "^y"; then
  echo "Removing setup script..."
  rm -f "$SCRIPT_PATH"
  echo "Cleanup complete! Signal will still be in your app menu."
else
  echo "You can leave the script in ~/Persistent in case you want to reinstall or fix later."
fi
