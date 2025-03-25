#!/bin/sh
set -e

PERSISTENT_DIR="/live/persistence/TailsData_unlocked/Persistent"
DOTFILES_DIR="/live/persistence/TailsData_unlocked/dotfiles"
STATE_FILE="$PERSISTENT_DIR/.signal-setup-state"
SCRIPT_PATH="$(readlink -f "$0")"
ADD_SOFT_CONF="/live/persistence/TailsData_unlocked/live-additional-software.conf"

echo "THIS IS UNFINSIHED AND MAY BREAK, CONTINUE WITH CAUTION"
echo "[*] Signal Setup Script for Tails"

# === Check persistence features ===
if [ ! -d "$PERSISTENT_DIR" ]; then
  echo "[-] Persistence is not enabled. Enable 'Personal Data' and reboot before running this."
  exit 1
fi

if [ ! -d "$DOTFILES_DIR" ]; then
  echo "[-] Dotfiles persistence is not enabled. Enable it and reboot before continuing."
  exit 1
fi

# === Check script is running from Persistent ===
case "$SCRIPT_PATH" in
  "$PERSISTENT_DIR"/*|"$HOME/Persistent"/*)
    ;;
  *)
    echo "[-] This script must be inside your Persistent folder to work properly."
    echo "    Please move it to ~/Persistent and run it from there."
    exit 1
    ;;
esac

# === Step 1: Setup before reboot ===
if [ ! -f "$STATE_FILE" ]; then
  echo "[*] Step 1: Installing flatpak and preparing system..."

  # Install flatpak if needed
  if ! command -v flatpak >/dev/null 2>&1; then
    echo "[*] Installing flatpak..."
    sudo apt update && sudo apt install -y flatpak
  else
    echo "[*] Flatpak already installed."
  fi

  # Add flatpak to Additional Software and suppress prompt
  echo "[*] Adding flatpak to Additional Software (no prompt)..."
  if ! grep -q "^flatpak$" "$ADD_SOFT_CONF" 2>/dev/null; then
    echo flatpak | sudo tee -a "$ADD_SOFT_CONF" > /dev/null
  fi
  sudo touch /live/persistence/TailsData_unlocked/live-additional-software.dpkg-install-done

  # Set up symlinks
  echo "[*] Linking flatpak data directories..."
  mkdir -p "$PERSISTENT_DIR/flatpak" "$PERSISTENT_DIR/app" "$HOME/.local/share" "$HOME/.var"
  rm -rf --one-file-system "$HOME/.local/share/flatpak"
  rm -rf --one-file-system "$HOME/.var/app"
  ln -sf "$PERSISTENT_DIR/flatpak" "$HOME/.local/share/flatpak"
  ln -sf "$PERSISTENT_DIR/app" "$HOME/.var/app"

  # Signal launcher script
  echo "[*] Creating launcher script..."
  cat > "$PERSISTENT_DIR/signal.sh" <<EOF
#!/bin/sh
export HTTP_PROXY=socks://127.0.0.1:9050
export HTTPS_PROXY=socks://127.0.0.1:9050
flatpak run org.signal.Signal
EOF
  chmod +x "$PERSISTENT_DIR/signal.sh"

  # Autostart entry
  mkdir -p "$DOTFILES_DIR/.config/autostart"
  cat > "$DOTFILES_DIR/.config/autostart/FlatpakSetup.desktop" <<EOF
[Desktop Entry]
Name=Flatpak Setup
Comment=Relinks persistent flatpak folders and installs Signal
Exec=$SCRIPT_PATH
Terminal=false
Type=Application
EOF

  # Desktop icon
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

  # Write state
  touch "$STATE_FILE"

  echo "[✓] Step 1 complete. Please REBOOT now."
  echo "    After reboot, this script will finish installing Signal automatically."
  exit 0
fi

# === Step 2: After reboot — wait for flatpak ===
echo "[*] Step 2: Waiting for flatpak to be ready..."

# Wait up to 60 seconds for flatpak to become available
i=0
while ! command -v flatpak >/dev/null 2>&1; do
  sleep 2
  i=$((i+2))
  if [ $i -ge 60 ]; then
    echo "[-] Flatpak not available after 60 seconds. Try running the script again later."
    exit 1
  fi
done

echo "[*] Flatpak is ready — continuing setup..."

# Re-link dirs (just in case)
mkdir -p "$PERSISTENT_DIR/flatpak" "$PERSISTENT_DIR/app" "$HOME/.local/share" "$HOME/.var"
rm -rf --one-file-system "$HOME/.local/share/flatpak"
rm -rf --one-file-system "$HOME/.var/app"
ln -sf "$PERSISTENT_DIR/flatpak" "$HOME/.local/share/flatpak"
ln -sf "$PERSISTENT_DIR/app" "$HOME/.var/app"

# Install Signal
echo "[*] Installing Signal from Flathub..."
torify flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
torify flatpak install -y flathub org.signal.Signal

# Cleanup
rm -f "$STATE_FILE"

echo "[✓] Signal installed!"
echo "→ You can launch Signal from the Applications menu or run signal.sh in the persistance folder"
echo ""
echo "🕐 Heads up: Signal may take ~30 seconds to open after boot. Be patient!"
echo "And don't delete any of the files put in the persistance folder, you can delete this script tho."
