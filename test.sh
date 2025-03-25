#!/bin/sh
set -e

# === Paths ===
PERSISTENT_DIR="/live/persistence/TailsData_unlocked/Persistent"
DOTFILES_DIR="/live/persistence/TailsData_unlocked/dotfiles"
STATE_FILE="$PERSISTENT_DIR/.signal-setup-state"

SCRIPT_PATH="$(readlink -f "$0")"

echo "[*] Signal Setup Script for Tails"

# === Check that persistence is active ===
if [ ! -d "$PERSISTENT_DIR" ]; then
  echo "[-] Persistence is not enabled. Enable 'Personal Data' and reboot before running this."
  exit 1
fi

# === Check that the script is in persistent storage ===
case "$SCRIPT_PATH" in
  "$PERSISTENT_DIR"/*)
    # All good
    ;;
  *)
    echo "[-] This script is not located inside your Persistent storage."
    echo "    Please move it to: $PERSISTENT_DIR and run it from there."
    exit 1
    ;;
esac

# === Check that Dotfiles persistence is enabled ===
if [ ! -d "$DOTFILES_DIR" ]; then
  echo "[-] Dotfiles persistence is not enabled."
  echo "    Enable it via 'Configure Persistent Storage' and reboot before running this."
  exit 1
fi

# === Step 1: Initial Setup ===
if [ ! -f "$STATE_FILE" ]; then
  echo "[*] Step 1: Installing flatpak and setting up environment..."

  # Install flatpak if missing
  if ! command -v flatpak >/dev/null 2>&1; then
    echo "[*] Installing flatpak..."
    sudo apt update && sudo apt install -y flatpak
  else
    echo "[*] Flatpak already installed."
  fi

  # Add flatpak to Additional Software if not already listed
  ADD_SOFT_CONF="/live/persistence/TailsData_unlocked/live-additional-software.conf"
  if [ -w "$ADD_SOFT_CONF" ] && ! grep -q "^flatpak$" "$ADD_SOFT_CONF"; then
    echo "[*] Adding flatpak to Additional Software..."
    echo flatpak | sudo tee -a "$ADD_SOFT_CONF" > /dev/null
  else
    echo "[*] Flatpak already in Additional Software list."
  fi

  # Set up persistent Flatpak directories and symlinks
  echo "[*] Setting up persistent Flatpak directories..."
  mkdir -p "$PERSISTENT_DIR/flatpak" "$PERSISTENT_DIR/app" "$HOME/.local/share" "$HOME/.var"
  rm -rf --one-file-system "$HOME/.local/share/flatpak"
  rm -rf --one-file-system "$HOME/.var/app"
  ln -sf "$PERSISTENT_DIR/flatpak" "$HOME/.local/share/flatpak"
  ln -sf "$PERSISTENT_DIR/app" "$HOME/.var/app"

  # Create Signal launch script
  echo "[*] Creating Signal launch script..."
  cat > "$PERSISTENT_DIR/signal.sh" <<EOF
#!/bin/sh
export HTTP_PROXY=socks://127.0.0.1:9050
export HTTPS_PROXY=socks://127.0.0.1:9050
flatpak run org.signal.Signal
EOF
  chmod +x "$PERSISTENT_DIR/signal.sh"

  # Set up autostart + GNOME launcher
  echo "[*] Creating autostart and desktop entries..."
  mkdir -p "$DOTFILES_DIR/.config/autostart"
  cat > "$DOTFILES_DIR/.config/autostart/FlatpakSetup.desktop" <<EOF
[Desktop Entry]
Name=Flatpak Setup
Comment=Relinks flatpak folders on login
Exec=$SCRIPT_PATH
Terminal=false
Type=Application
EOF

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

  # Mark step 1 complete
  touch "$STATE_FILE"
  echo "[✓] FIRST PART Setup complete. Please REBOOT now, then run this script again to finish installing Signal."
  echo "Again, Reboot then run this again."
  exit 0
fi

# === Step 2: Install Signal ===
echo "[*] Step 2: Installing Signal via Flatpak..."

# Re-link flatpak dirs (just in case)
mkdir -p "$PERSISTENT_DIR/flatpak" "$PERSISTENT_DIR/app" "$HOME/.local/share" "$HOME/.var"
rm -rf --one-file-system "$HOME/.local/share/flatpak"
rm -rf --one-file-system "$HOME/.var/app"
ln -sf "$PERSISTENT_DIR/flatpak" "$HOME/.local/share/flatpak"
ln -sf "$PERSISTENT_DIR/app" "$HOME/.var/app"

# Install Signal from Flathub
torify flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
torify flatpak install -y flathub org.signal.Signal

# Cleanup
rm -f "$STATE_FILE"

echo "[✓] Signal has been successfully installed!"
echo "→ Launch it from the Applications menu or with:"
echo "   $PERSISTENT_DIR/signal.sh"
