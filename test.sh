#!/bin/sh
set -e

# === Paths ===
PERSISTENT_DIR="/live/persistence/TailsData_unlocked/Persistent"
DOTFILES_DIR="/live/persistence/TailsData_unlocked/dotfiles"
STATE_FILE="$PERSISTENT_DIR/.signal-setup-state"

echo "[*] Signal Setup Script for Tails"

# === Check persistence ===
if [ ! -d "$PERSISTENT_DIR" ]; then
  echo "[-] Persistence is not enabled. Enable 'Personal Data' and reboot before running this."
  exit 1
fi

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

  # Add to Additional Software if not already listed
  ADD_SOFT_CONF="/live/persistence/TailsData_unlocked/live-additional-software.conf"
  if [ -w "$ADD_SOFT_CONF" ] && ! grep -q "^flatpak$" "$ADD_SOFT_CONF"; then
    echo "[*] Adding flatpak to Additional Software..."
    echo flatpak | sudo tee -a "$ADD_SOFT_CONF" > /dev/null
  else
    echo "[*] Flatpak already in Additional Software list."
  fi

  # Create persistent flatpak data folders and symlinks
  echo "[*] Setting up flatpak directories..."
  mkdir -p "$PERSISTENT_DIR/flatpak" "$PERSISTENT_DIR/app" "$HOME/.local/share" "$HOME/.var"
  rm -rf --one-file-system "$HOME/.local/share/flatpak"
  rm -rf --one-file-system "$HOME/.var/app"
  ln -sf "$PERSISTENT_DIR/flatpak" "$HOME/.local/share/flatpak"
  ln -sf "$PERSISTENT_DIR/app" "$HOME/.var/app"

  # Create launcher script for Signal
  echo "[*] Creating launch script..."
  cat > "$PERSISTENT_DIR/signal.sh" <<EOF
#!/bin/sh
export HTTP_PROXY=socks://127.0.0.1:9050
export HTTPS_PROXY=socks://127.0.0.1:9050
flatpak run org.signal.Signal
EOF
  chmod +x "$PERSISTENT_DIR/signal.sh"

  # Create autostart entry
  echo "[*] Creating autostart and app menu entries..."
  mkdir -p "$DOTFILES_DIR/.config/autostart"
  cat > "$DOTFILES_DIR/.config/autostart/FlatpakSetup.desktop" <<EOF
[Desktop Entry]
Name=Flatpak Setup
Comment=Relinks flatpak folders on login
Exec=$PERSISTENT_DIR/install-signal-on-tails.sh
Terminal=false
Type=Application
EOF

  # Create GNOME application launcher
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

  # Mark state
  touch "$STATE_FILE"
  echo "[✓] Initial setup complete. Please REBOOT, then run this script again to finish Signal installation."
  exit 0
fi

# === Step 2: Install Signal ===
echo "[*] Step 2: Installing Signal via Flatpak..."

# Re-ensure flatpak dirs are linked
mkdir -p "$PERSISTENT_DIR/flatpak" "$PERSISTENT_DIR/app" "$HOME/.local/share" "$HOME/.var"
rm -rf --one-file-system "$HOME/.local/share/flatpak"
rm -rf --one-file-system "$HOME/.var/app"
ln -sf "$PERSISTENT_DIR/flatpak" "$HOME/.local/share/flatpak"
ln -sf "$PERSISTENT_DIR/app" "$HOME/.var/app"

# Install Signal from Flathub
torify flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
torify flatpak install -y flathub org.signal.Signal

# Clean up state file
rm -f "$STATE_FILE"

echo "[✓] Signal has been successfully installed!"
echo "→ You can launch it from the Applications menu or by running:"
echo "   $PERSISTENT_DIR/signal.sh"
