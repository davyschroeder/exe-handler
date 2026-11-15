#!/usr/bin/env bash
# Removes what install.sh added. Wine, DOSBox-X, Box64 and your ~/.wine folder are kept
# (remove them with your package manager / rm -rf ~/.wine if you want).
set -u
SUDO=""; [ "$(id -u)" = 0 ] || SUDO=sudo
$SUDO rm -f /usr/local/bin/exe-handler /etc/exe-handler.conf /usr/local/share/applications/exe-handler.desktop \
            /usr/local/share/mime/packages/exe-handler.xml /etc/binfmt.d/exe-handler.conf /etc/binfmt.d/zz-exe-handler.conf
[ -e /proc/sys/fs/binfmt_misc/exe-handler ] && echo -1 | $SUDO tee /proc/sys/fs/binfmt_misc/exe-handler >/dev/null
command -v update-mime-database >/dev/null && $SUDO update-mime-database /usr/local/share/mime
command -v update-desktop-database >/dev/null && $SUDO update-desktop-database /usr/local/share/applications
sed -i '/exe-handler.desktop/d' "$HOME/.config/mimeapps.list" 2>/dev/null
echo "exe-handler removed. Optional: sudo rm -rf /opt/exe-handler (ARM Wine + otvdm), rm -rf ~/.config/exe-handler"
