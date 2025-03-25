#!/bin/sh
set -e

echo "[*] Installing Signal, script for use on Tails..."

# Check persistence
if [ ! -d "/live/persistence/TailsData_unlocked" ]; then
  echo "[-] Persistence is not unlocked. Enable it and reboot first."
  exit 1
fi

# Check/install flatpak
if ! command -v flatpak >/dev/null 2>&1; then
  echo "[*] Installing flatpak..."
  sudo apt update && sudo apt install -y flatpak
fi

# Add flatpak to Additional Software
if ! grep -q "^flatpak$" /live/persistence/TailsData_unlocked/live-additional-software.conf 2>/dev/null; then
  echo "[*] Adding flatpak to Additional Software..."
  echo flatpak | sudo tee -a /live/persistence/TailsData_unlocked/live-additional-software.conf > /dev/null
fi

# Set up persistent flatpak directories
echo "[*] Setting up persistent directories..."
mkdir -p ~/Persistent/flatpak ~/Persistent/app ~/.local/share ~/.var
rm -rf --one-file-system ~/.local/share/flatpak
ln -sf ~/Persistent/flatpak ~/.local/share/flatpak
ln -sf ~/Persistent/app ~/.var/app

# Add flathub and install Signal
echo "[*] Installing Signal from Flathub..."
torify flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
torify flatpak install -y flathub org.signal.Signal

# Create Signal launch script
echo "[*] Creating launcher script..."
cat > ~/Persistent/signal.sh <<'EOF'
#!/bin/sh
export HTTP_PROXY=socks://127.0.0.1:9050
export HTTPS_PROXY=socks://127.0.0.1:9050
flatpak run org.signal.Signal
EOF
chmod +x ~/Persistent/signal.sh

# Set up autostart and desktop entry (requires Dotfiles)
echo "[*] Setting up desktop integration..."
mkdir -p /live/persistence/TailsData_unlocked/dotfiles/.config/autostart
mkdir -p /live/persistence/TailsData_unlocked/dotfiles/.local/share/applications

# Autostart: re-link dirs at login
cat > /live/persistence/TailsData_unlocked/dotfiles/.config/autostart/FlatpakSetup.desktop <<'EOF'
[Desktop Entry]
Name=Flatpak Setup
Comment=Ensures flatpak dirs are linked on startup
Exec=/live/persistence/TailsData_unlocked/Persistent/install-signal-on-tails.sh
Terminal=false
Type=Application
EOF

# GNOME launcher entry
cat > /live/persistence/TailsData_unlocked/dotfiles/.local/share/applications/Signal.desktop <<'EOF'
[Desktop Entry]
Name=Signal Messenger
GenericName=Private Chat App
Exec=/home/amnesia/Persistent/signal.sh
Terminal=false
Type=Application
Icon=/home/amnesia/.local/share/flatpak/app/org.signal.Signal/current/active/files/share/icons/hicolor/128x128/apps/org.signal.Signal.png
EOF

echo "[✓] All done!"
echo "→ You can launch Signal from the app menu or by running ~/Persistent/signal.sh"
echo "→ It will auto-link and be available after reboot if Dotfiles persistence is enabled."
