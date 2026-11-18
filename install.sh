#!/usr/bin/env bash
# Installs the Zomboid Host app (pzhost) on Debian 13 (also Ubuntu / Arch Linux).
#   ./install.sh             install and open the app
#   ./install.sh --no-launch install only (used by "Update this app")
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/pzhost"
mkdir -p "$LOG_DIR"
exec 3>&1 4>&2
exec > >(tee -a "$LOG_DIR/install.log") 2>&1
echo "==== install.sh $(date '+%F %T') from $SRC ===="

if [[ $EUID -eq 0 ]]; then
  echo "Run ./install.sh as your normal user (not with sudo). It will ask for your password." >&2
  exit 1
fi
export PATH="/usr/local/sbin:/usr/sbin:/sbin:${PATH}"
if command -v apt-get >/dev/null; then PKG=apt
elif command -v pacman >/dev/null; then PKG=pacman
else echo "This app is for Debian / Ubuntu / Arch Linux (apt or pacman not found)." >&2; exit 1; fi

# Debian often has no working sudo for the first user if a root password was set during install.
if ! command -v sudo >/dev/null || ! sudo -v; then
  cat >&2 <<EOF

sudo is not set up for user "$(id -un)". Fix it once, then run ./install.sh again:
  su -                                  # enter the ROOT password
  apt install -y sudo
  usermod -aG sudo $(id -un)
  exit
Then LOG OUT and log back in (or reboot).
EOF
  exit 1
fi

echo "Installing Zomboid Host… (your password is needed to copy the app into /usr/local/bin)"
sudo install -Dm755 "$SRC/pzhost" /usr/local/bin/pzhost

# Needed for error reports and app updates.
if [[ $PKG == apt ]]; then
  if ! command -v git >/dev/null || ! command -v gh >/dev/null; then
    sudo apt-get update && sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y git gh \
      || echo "Warning: could not install git/gh (error reports will be saved to a file instead)."
  fi
else
  missing=()
  for p in git github-cli; do pacman -Qi "$p" >/dev/null 2>&1 || missing+=("$p"); done
  if (( ${#missing[@]} )); then
    sudo pacman -S --needed --noconfirm "${missing[@]}" || echo "Warning: could not install ${missing[*]} (error reports will be saved to a file instead)."
  fi
fi
if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  gh auth setup-git >/dev/null 2>&1 || true
fi

CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/pzhost"
mkdir -p "$CONF_DIR"
echo "$SRC" >"$CONF_DIR/source_dir"

# App menu entry + icon + desktop shortcut
install -Dm644 "$SRC/assets/pzhost.svg" "$HOME/.local/share/icons/hicolor/scalable/apps/pzhost.svg"
install -Dm644 "$SRC/assets/pzhost.desktop" "$HOME/.local/share/applications/pzhost.desktop"
DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")"
if [[ -d $DESKTOP_DIR ]]; then
  install -Dm755 "$SRC/assets/pzhost.desktop" "$DESKTOP_DIR/pzhost.desktop"
  gio set "$DESKTOP_DIR/pzhost.desktop" metadata::trusted true 2>/dev/null || true
fi
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

echo
echo "✔ Installed: pzhost $(/usr/local/bin/pzhost version | awk '{print $2}')"
echo "  Open it from the app menu (\"Zomboid Host\"), the desktop icon, or type: pzhost"
echo

[[ ${1:-} == --no-launch ]] && exit 0
exec 1>&3 2>&4
exec /usr/local/bin/pzhost
