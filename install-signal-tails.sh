#!/bin/sh
set -e

PERSISTENT_DIR="/live/persistence/TailsData_unlocked/Persistent"
DOTFILES_DIR="/live/persistence/TailsData_unlocked/dotfiles"
STATE_FILE="$PERSISTENT_DIR/.signal-setup-state"
SCRIPT_PATH="$(readlink -f "$0")"
ADD_SOFT_CONF="/live/persistence/TailsData_unlocked/live-additional-software.conf"

echo ""
echo "📦 Signal Messenger Setup for Tails"
echo "────────────────────────────────────"

# === Check required persistence ===
if [ ! -d "$PERSISTENT_DIR" ]; then
  echo "❌ Persistence not enabled. Enable 'Personal Data' and reboot before using this script."
  exit 1
fi

if [ ! -d "$DOTFILES_DIR" ]; then
  echo "❌ Dotfiles persistence not enabled. Enable 'Dotfiles' and reboot before using this script."
  exit 1
fi

# === Check script location ===
case "$SCRIPT_PATH" in
  "$PERSISTENT_DIR"/*|"$HOME/Persistent"/*)
    ;;
  *)
    echo "❌ This script must be inside your Persistent folder to work reliably."
    echo "   Move it to ~/Persistent and run it from there."
    exit 1
    ;;
esac

# === Step 1: Initial Setup ===
if [ ! -f "$STATE_FILE" ]; then
  echo "🔧 Step 1: Installing flatpak and setting up persistence..."

  # Install flatpak
  if ! command -v flatpak >/dev/null 2>&1; then
    echo "➕ Installing flatpak..."
    sudo apt update && sudo apt install -y flatpak
  else
    echo "✅ Flatpak already installed."
  fi

  # Add to Additional Software silently
  if ! grep -q "^flatpak$" "$ADD_SOFT_CONF" 2>/dev/null; then
    echo "➕ Adding flatpak to Additional Software..."
    echo flatpak | sudo tee -a "$ADD_SOFT_CONF" > /dev/null
  fi
  sudo touch /live/persistence/TailsData_unlocked/live-additional-software.dpkg-install-done

  # Set up persistent flatpak data dirs
  echo "📁 Setting up persistent flatpak directories..."
  mkdir -p "$PERSISTENT_DIR/flatpak" "$PERSISTENT_DIR/app" "$HOME/.local/share" "$HOME/.var"
  rm -rf --one-file-system "$HOME/.local/share/flatpak"
  rm -rf --one-file-system "$HOME/.var/app"
  ln -sf "$PERSISTENT_DIR/flatpak" "$HOME/.local/share/flatpak"
  ln -sf "$PERSISTENT_DIR/app" "$HOME/.var/app"

  # Create Signal launcher script
  echo "🖱️ Creating Signal launcher script..."
  cat > "$PERSISTENT_DIR/signal.sh" <<EOF
#!/bin/sh
export HTTP_PROXY=socks://127.0.0.1:9050
export HTTPS_PROXY=socks://127.0.0.1:9050
flatpak run org.signal.Signal
EOF
  chmod +x "$PERSISTENT_DIR/signal.sh"

  # Autostart flatpak symlink fixer
  mkdir -p "$DOTFILES_DIR/.config/autostart"
  cat > "$DOTFILES_DIR/.config/autostart/FlatpakSetup.desktop" <<EOF
[Desktop Entry]
Name=Flatpak Setup
Comment=Relinks persistent flatpak folders and completes Signal install
Exec=$SCRIPT_PATH
Terminal=false
Type=Application
EOF

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
  echo "✅ Step 1 complete!"
  echo "🔁 Please REBOOT now. After reboot, this script will finish installing Signal automatically."
  exit 0
fi

# === Step 2: After Reboot ===
echo "🚀 Step 2: Waiting for flatpak to finish loading..."

# Wait until flatpak is available (max 60 sec)
i=0
while ! command -v flatpak >/dev/null 2>&1; do
  sleep 2
  i=$((i+2))
  [ $i -ge 60 ] && echo "❌ Flatpak not available after 60 seconds. Try again later." && exit 1
done

# Re-ensure symlinks (just in case)
mkdir -p "$PERSISTENT_DIR/flatpak" "$PERSISTENT_DIR/app" "$HOME/.local/share" "$HOME/.var"
rm -rf --one-file-system "$HOME/.local/share/flatpak"
rm -rf --one-file-system "$HOME/.var/app"
ln -sf "$PERSISTENT_DIR/flatpak" "$HOME/.local/share/flatpak"
ln -sf "$PERSISTENT_DIR/app" "$HOME/.var/app"

# Install Signal
echo "📦 Installing Signal via Flatpak..."
torify flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
torify flatpak install -y flathub org.signal.Signal

# Cleanup
rm -f "$STATE_FILE"

# Remove autostart entry (no longer needed)
rm -f "$DOTFILES_DIR/.config/autostart/FlatpakSetup.desktop"

echo ""
echo "✅ Signal is now fully installed!"
echo "🎉 You can launch it from the Applications menu or run:"
echo "   $PERSISTENT_DIR/signal.sh"
echo ""
echo "💡 Note:"
echo "   • The first time you open Signal after a reboot, it may take ~30 seconds to launch."
echo "   • This is normal. Just be patient — it’s loading via Flatpak over Tor."
echo ""

# === Optional cleanup ===
read -p "🧹 Do you want to remove this setup script now? [y/N]: " CLEANUP
if echo "$CLEANUP" | grep -iq "^y"; then
  echo "🗑️  Removing setup script..."
  rm -f "$SCRIPT_PATH"
  echo "✅ Cleanup complete! Signal will still be in your app menu."
else
  echo "👍 You can leave the script in ~/Persistent in case you want to reinstall/fix later."
fi
