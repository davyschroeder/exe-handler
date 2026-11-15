#!/usr/bin/env bash
# exe-handler installer: makes .exe/.com/.bat/.msi files (DOS and Windows) open with a double click on Linux.
# Works on x86 PCs (64-bit) and ARM64 boards such as the Raspberry Pi 4/5.
# Run as a normal user:   ./install.sh          (asks for sudo where needed)
# Options:  --yes        no questions (accept defaults)
#           --dry-run    only show what would happen
#           --no-binfmt  do not register .exe files with the kernel (see README)
#           --warmup-at-login     get Wine ready in the background after every login: with several monitors the
#                                 first Windows program then starts without stutter (--no-warmup-at-login removes it)
#           --update     only replace the exe-handler program with the newest version from GitHub
set -euo pipefail

YES=0; DRY=0; BINFMT=1; WARMUP=0; UPDATE=0
for a in "$@"; do
  case "$a" in
    --yes|-y) YES=1 ;;
    --dry-run|-n) DRY=1 ;;
    --no-binfmt) BINFMT=0 ;;
    --warmup-at-login) WARMUP=1 ;;
    --no-warmup-at-login) WARMUP=-1 ;;
    --update|-u) UPDATE=1 ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) echo "Unknown option: $a" >&2; exit 2 ;;
  esac
done

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPT=/opt/exe-handler
BIN=/usr/local/bin/exe-handler
CONF=/etc/exe-handler.conf
DESKTOP=/usr/local/share/applications/exe-handler.desktop
MIMES="application/x-ms-dos-executable;application/x-msdownload;application/x-dosexec;application/x-msdos-program;application/vnd.microsoft.portable-executable;application/x-ms-ne-executable;application/x-msi;application/x-bat;application/x-com;"
OTVDM_URL=https://github.com/otya128/winevdm/releases/download/v0.9.0/otvdm-v0.9.0.zip
BOX64_REPO=https://pi-apps-coders.github.io/box64-debs
# Wine for ARM64 (x86-64 build run by Box64). Pinned: Wine 11.22 fails under Box64 0.4.5
# (set_mem_area_state assertion); 11.4 is tested on a Raspberry Pi 5.
WINE_ARM_VERSION=11.4
WINE_ARM_SHA256=5c5f7019754403ac50b05bad7ab568b680a504cd886e0590b05882d2bf054b25
OTVDM_SHA256=842b11aed5fa81f3e1d4272e0ee7d37f1a5a8f936de825309dda672835e16fd4
CNC_VERSION=v7.1.0.0
CNC_URL=https://github.com/FunkyFr3sh/cnc-ddraw/releases/download/$CNC_VERSION/cnc-ddraw.zip
CNC_SHA256=0b13ab89a64c9918189b1dadd449ef6ed3cb3b7b19cabd96d8adbd95505bb908

say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mXX\033[0m %s\n' "$*" >&2; exit 1; }
run()  { if [ $DRY = 1 ]; then echo "   [dry-run] $*"; else "$@"; fi; }

# ---------- telling what is going on ----------
T0=$(date +%s); STEP=0; TOTAL=8
ILOG=$(mktemp /tmp/exe-handler-install.XXXXXX.log)     # full output of everything that runs quietly
elapsed() { local t=$(( $(date +%s) - ${1:-$T0} )); printf '%d:%02d' $((t / 60)) $((t % 60)); }
step() { STEP=$((STEP + 1)); printf '\n\033[1;34m[%d/%d]\033[0m \033[1m%s\033[0m  \033[2m(%s)\033[0m\n' "$STEP" "$TOTAL" "$*" "$(elapsed)"; }
doing() { printf '   \033[36m->\033[0m %s\n' "$*"; }
ok()    { printf '   \033[32mok\033[0m %s\n' "$*"; }
# busy "what" command...: run a quiet command and show that it is still working, with a running clock
busy() {
  local what=$1 t rc; shift; t=$(date +%s)
  if [ $DRY = 1 ]; then echo "   [dry-run] $*"; return 0; fi
  echo "### $what: $*" >>"$ILOG"
  "$@" >>"$ILOG" 2>&1 &
  local pid=$!
  while kill -0 $pid 2>/dev/null; do
    if [ -t 1 ]; then printf '\r   \033[36m..\033[0m %s  %s ' "$what" "$(elapsed "$t")"; fi
    sleep 1
  done
  wait $pid; rc=$?
  [ -t 1 ] && printf '\r\033[K'
  if [ $rc = 0 ]; then ok "$what ($(elapsed "$t"))"; else warn "$what failed after $(elapsed "$t") (details: $ILOG)"; fi
  return $rc
}
SUDO=""; [ "$(id -u)" = 0 ] || SUDO=sudo
sudo_run() { if [ -n "$SUDO" ]; then run sudo "$@"; else run "$@"; fi; }
ask() { [ $YES = 1 ] && return 0; read -r -p "$1 [Y/n] " r; [[ ! "$r" =~ ^[nN] ]]; }

# ---------- --update: just the program itself, from GitHub ----------
if [ $UPDATE = 1 ]; then
  URL=https://raw.githubusercontent.com/davyschroeder/exe-handler/main/exe-handler
  [ -e "$BIN" ] || die "exe-handler is not installed yet; run ./install.sh without --update first."
  TMP=$(mktemp)
  say "Downloading the newest exe-handler from GitHub"
  if command -v curl >/dev/null; then curl -fsSL -o "$TMP" "$URL" || die "Download failed: $URL"
  else wget -q -O "$TMP" "$URL" || die "Download failed: $URL"; fi
  head -1 "$TMP" | grep -q python3 || die "The download is not the exe-handler program; nothing changed."
  if cmp -s "$TMP" "$BIN"; then
    say "Already the newest version."
  else
    sudo_run install -m 755 "$TMP" "$BIN"
    say "exe-handler updated."
  fi
  rm -f "$TMP"
  say "Done."
  exit 0
fi

# ---------- what machine is this ----------
ARCH=$(uname -m)
case "$ARCH" in
  x86_64|amd64) ARCH=x86_64 ;;
  aarch64|arm64) ARCH=aarch64 ;;
  i?86) ARCH=i686 ;;
  armv7l|armv6l) ARCH=arm32 ;;
esac
PM=""
for p in apt-get dnf pacman zypper; do command -v $p >/dev/null && { PM=$p; break; }; done
[ -n "$PM" ] || die "No supported package manager found (apt, dnf, pacman, zypper)."
MODEL=$( { tr -d '\0' </proc/device-tree/model; } 2>/dev/null || true)
PAGESIZE=$(getconf PAGESIZE)
say "Machine: $ARCH${MODEL:+ ($MODEL)}, package manager: $PM, page size: $PAGESIZE"

pkg_install() {  # install packages, ignore the ones that do not exist on this distro
  case $PM in
    apt-get) sudo_run env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@" ;;
    dnf)     sudo_run dnf install -y "$@" ;;
    pacman)  sudo_run pacman -S --needed --noconfirm "$@" ;;
    zypper)  sudo_run zypper --non-interactive install "$@" ;;
  esac
}
pkg_have() { case $PM in apt-get) dpkg -s "$1" 2>/dev/null | grep -q '^Status: install ok installed' ;; pacman) pacman -Qi "$1" >/dev/null 2>&1 ;; *) rpm -q "$1" >/dev/null 2>&1 ;; esac; }
pkg_try() {
  local p
  for p in "$@"; do
    if pkg_have "$p"; then echo "   =  $p (already installed)"
    elif [ $DRY = 1 ]; then echo "   [dry-run] install package $p"
    else busy "installing package $p" pkg_install "$p" || true
    fi
  done
}

[ "$ARCH" = aarch64 ] && TOTAL=7
[ $BINFMT = 1 ] || TOTAL=$((TOTAL - 1))
echo "   Everything that runs quietly is written to $ILOG"
if [ -n "$SUDO" ] && [ $DRY = 0 ]; then
  if sudo -n true 2>/dev/null; then
    doing "sudo works without a password here"
  else
    doing "asking for your password once (sudo); it is remembered until the script is done"
    sudo -v || die "sudo is needed to install programs"
  fi
  ( while sleep 50; do sudo -n true 2>/dev/null || exit; done ) &     # keep sudo alive during long steps
  KEEP=$!; trap 'kill $KEEP 2>/dev/null' EXIT
fi
if [ $PM = apt-get ]; then
  busy "refreshing the package list (apt update)" $SUDO apt-get update -qq || true
fi

# ---------- basic tools ----------
step "Basic tools: dialogs, download, unpack, window tools, sound font"
case $PM in
  apt-get) pkg_try zenity curl ca-certificates xz-utils unzip python3 desktop-file-utils xdg-utils gpg x11-xserver-utils x11-utils wmctrl xdotool imagemagick timgm6mb-soundfont ;;
  *)       pkg_try zenity curl xz unzip python3 desktop-file-utils xdg-utils xrandr xorg-xrandr wmctrl xdotool xorg-xwininfo imagemagick ImageMagick soundfont-fluid fluid-soundfont-gm ;;
esac

# ---------- DOSBox-X for DOS programs ----------
DOSBOX_CMD=""
step "DOSBox-X for DOS programs and games"
if command -v dosbox-x >/dev/null; then
  DOSBOX_CMD=dosbox-x
else
  busy "installing package dosbox-x" pkg_install dosbox-x && DOSBOX_CMD=dosbox-x || true
  if [ -z "$DOSBOX_CMD" ] && [ $DRY = 1 ]; then DOSBOX_CMD=dosbox-x; fi
  if [ -z "$DOSBOX_CMD" ]; then
    warn "dosbox-x is not in the package sources, trying Flatpak"
    pkg_try flatpak
    if command -v flatpak >/dev/null; then
      sudo_run flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
      if sudo_run flatpak install -y --noninteractive flathub com.dosbox_x.DOSBox-X; then
        sudo_run flatpak override --filesystem=host com.dosbox_x.DOSBox-X   # may open programs anywhere
        DOSBOX_CMD="flatpak run com.dosbox_x.DOSBox-X"
      fi
    fi
  fi
  if [ -z "$DOSBOX_CMD" ]; then
    warn "DOSBox-X not available, using plain DOSBox"
    busy "installing package dosbox" pkg_install dosbox && DOSBOX_CMD=dosbox || warn "no DOSBox at all: DOS programs will not run"
  fi
fi
[ -n "$DOSBOX_CMD" ] && ok "DOS programs will use: $DOSBOX_CMD" || warn "no DOSBox available"

# ---------- Wine for Windows programs ----------
WINE_CMD=""; OTVDM_DIR=""
install_wine_x86() {
  step "Wine for Windows programs (64- and 32-bit)"
  case $PM in
    apt-get)
      if command -v wine >/dev/null && dpkg -s wine32:i386 >/dev/null 2>&1; then
        echo "   =  wine with 32-bit support (already installed: $(wine --version 2>/dev/null))"; WINE_CMD=wine; return
      fi
      doing "switching on 32-bit packages (i386), needed for 32-bit Windows programs"
      # 32-bit Windows programs need the i386 part of Wine
      if [ "$(dpkg --print-foreign-architectures | grep -c i386)" = 0 ]; then
        sudo_run dpkg --add-architecture i386; sudo_run apt-get update -qq
      fi
      if command -v wine >/dev/null && dpkg -s wine32:i386 >/dev/null 2>&1; then echo "   =  wine with 32-bit support (already installed)"
      else busy "installing Wine with 32-bit support (the biggest download, several minutes)" pkg_install wine wine64 wine32:i386 || busy "installing Wine" pkg_install wine; fi ;;
    pacman)
      command -v wine >/dev/null && { WINE_CMD=wine; return; }
      grep -q '^\[multilib\]' /etc/pacman.conf || warn "enable [multilib] in /etc/pacman.conf for 32-bit programs"
      pkg_install wine ;;
    *) command -v wine >/dev/null || pkg_install wine ;;
  esac
  pkg_try winetricks
  WINE_CMD=wine
}

install_box64() {
  command -v box64 >/dev/null && { echo "   box64 already installed"; return; }
  if [ $PM = apt-get ]; then
    local p=box64-generic-arm
    case "$MODEL" in *"Raspberry Pi 4"*) p=box64-rpi4arm64 ;; *"Raspberry Pi 3"*) p=box64-rpi3arm64 ;; esac
    doing "adding the Box64 package source $BOX64_REPO and installing $p"
    run bash -c "curl -fsSL $BOX64_REPO/KEY.gpg | $SUDO gpg --dearmor --yes -o /usr/share/keyrings/box64-archive-keyring.gpg"
    run bash -c "printf 'Types: deb\nURIs: $BOX64_REPO/debian\nSuites: ./\nSigned-By: /usr/share/keyrings/box64-archive-keyring.gpg\n' | $SUDO tee /etc/apt/sources.list.d/box64.sources >/dev/null"
    sudo_run apt-get update -qq
    busy "installing package $p" pkg_install "$p"
  else
    doing "building Box64 from source: this takes 5-15 minutes"
    pkg_try git cmake gcc gcc-c++ make python3
    local b; b=$(mktemp -d)
    run git clone --depth 1 https://github.com/ptitSeb/box64 "$b/box64"
    run cmake -S "$b/box64" -B "$b/build" -DARM_DYNAREC=ON -DCMAKE_BUILD_TYPE=RelWithDebInfo
    run make -C "$b/build" -j"$(nproc)"
    sudo_run make -C "$b/build" install
    sudo_run systemctl restart systemd-binfmt 2>/dev/null || true
  fi
}

install_wine_arm64() {
  step "Wine for ARM64: x86-64 Wine running in Box64, and otvdm for 16-bit programs"
  install_box64
  doing "native ARM libraries that Box64 hands to Wine (graphics, sound, fonts, encryption)"
  case $PM in
    apt-get) pkg_try libx11-6 libxext6 libxrender1 libxrandr2 libxi6 libxcursor1 libxcomposite1 libxinerama1 \
                     libxfixes3 libxxf86vm1 libfreetype6 libfontconfig1 libgl1 libegl1 libvulkan1 libasound2t64 libasound2 \
                     libpulse0 libgnutls30t64 libgnutls30 libdbus-1-3 libudev1 libsdl2-2.0-0 cabextract ;;
    *) pkg_try freetype fontconfig mesa-libGL alsa-lib pulseaudio-libs gnutls SDL2 cabextract ;;
  esac
  if [ -x "$OPT/wine/bin/wine" ]; then
    echo "   Wine already in $OPT/wine"
  else
    local url="https://github.com/Kron4ek/Wine-Builds/releases/download/$WINE_ARM_VERSION/wine-$WINE_ARM_VERSION-amd64-wow64.tar.xz"
    doing "downloading Wine $WINE_ARM_VERSION (about 190 MB): $url"
    local t; t=$(mktemp -d)
    run curl -fL --progress-bar -o "$t/wine.tar.xz" "$url"
    if [ $DRY = 0 ]; then
      echo "$WINE_ARM_SHA256  $t/wine.tar.xz" | sha256sum -c --quiet - || die "Wine download does not match the expected sha256"
    fi
    sudo_run mkdir -p "$OPT/wine"
    busy "unpacking Wine to $OPT/wine" $SUDO tar -xJf "$t/wine.tar.xz" -C "$OPT/wine" --strip-components=1
    rm -rf "$t"
  fi
  doing "making wine, winecfg, regedit ... available as normal commands in /usr/local/bin"
  for c in wine wineserver winecfg wineboot regedit msiexec winepath; do
    command -v $c >/dev/null && [ "$(readlink -f "$(command -v $c)")" != "/usr/local/bin/$c" ] && continue
    run bash -c "printf '#!/bin/sh\nexport BOX64_LOG=\${BOX64_LOG:-0} BOX64_NOBANNER=1\nexec box64 $OPT/wine/bin/$c \"\$@\"\n' | $SUDO tee /usr/local/bin/$c >/dev/null"
    sudo_run chmod 755 /usr/local/bin/$c
  done
  WINE_CMD="box64 $OPT/wine/bin/wine"
  # 16-bit Windows programs: Box64 cannot run 16-bit code, otvdm emulates it
  if [ ! -f "$OPT/otvdm/otvdmw.exe" ]; then
    doing "downloading otvdm for 16-bit Windows programs: $OTVDM_URL"
    local t; t=$(mktemp -d)
    run curl -fsSL -o "$t/otvdm.zip" "$OTVDM_URL"
    if [ $DRY = 0 ]; then
      echo "$OTVDM_SHA256  $t/otvdm.zip" | sha256sum -c --quiet - || die "otvdm download does not match the expected sha256"
    fi
    run unzip -q "$t/otvdm.zip" -d "$t/x"
    sudo_run mkdir -p "$OPT/otvdm"
    run bash -c "$SUDO cp -r \"$t\"/x/*/. $OPT/otvdm/"
    rm -rf "$t"
  fi
  OTVDM_DIR="$OPT/otvdm"
}

install_cnc_ddraw() {
  # old DirectDraw games: scaled window instead of a 320x200/640x480 mode switch (see cnc_ddraw in exe-handler)
  [ -f "$OPT/cnc-ddraw/ddraw.dll" ] && { step "cnc-ddraw for old DirectDraw games"; echo "   =  already in $OPT/cnc-ddraw"; return; }
  step "cnc-ddraw $CNC_VERSION for old DirectDraw games"
  doing "downloading $CNC_URL and checking its sha256"
  local t; t=$(mktemp -d)
  run curl -fsSL -o "$t/cnc.zip" "$CNC_URL" || { warn "cnc-ddraw download failed, skipped"; return; }
  if [ $DRY = 0 ]; then
    echo "$CNC_SHA256  $t/cnc.zip" | sha256sum -c --quiet - || { warn "cnc-ddraw download does not match the expected sha256, skipped"; return; }
  fi
  run unzip -q "$t/cnc.zip" ddraw.dll -d "$t/x"
  sudo_run mkdir -p "$OPT/cnc-ddraw"
  sudo_run install -m 644 "$t/x/ddraw.dll" "$OPT/cnc-ddraw/ddraw.dll"
  rm -rf "$t"
}

case $ARCH in
  x86_64|i686) install_wine_x86; install_cnc_ddraw ;;
  aarch64)
    install_wine_arm64
    if [ "$PAGESIZE" != 4096 ]; then
      warn "This kernel uses ${PAGESIZE}-byte memory pages; Wine needs 4096."
      if [ -f /boot/firmware/config.txt ] && [[ "$MODEL" == *"Raspberry Pi 5"* ]]; then
        if ask "Switch the Raspberry Pi 5 to the 4K-page kernel (kernel=kernel8.img, needs a reboot)?"; then
          run bash -c "grep -q '^kernel=kernel8.img' /boot/firmware/config.txt || echo 'kernel=kernel8.img' | $SUDO tee -a /boot/firmware/config.txt >/dev/null"
          NEED_REBOOT=1
        fi
      else
        warn "Use a kernel with 4K pages for Windows programs. DOS programs work anyway."
      fi
    fi ;;
  *) warn "Windows programs are not supported on $ARCH (only x86 and ARM64). DOS programs will work." ;;
esac
[ -n "$WINE_CMD" ] && ok "Windows programs will use: $WINE_CMD" || warn "no Wine available"

# ---------- the handler itself ----------
step "The exe-handler program itself"
doing "copying exe-handler to $BIN and writing $CONF"
sudo_run install -m 755 "$SRC/exe-handler" "$BIN"
run bash -c "printf '# written by exe-handler install.sh\nARCH=%s\nWINE=%s\nDOSBOX=%s\nOTVDM=%s\n' '$ARCH' '$WINE_CMD' '$DOSBOX_CMD' '$OTVDM_DIR' | $SUDO tee $CONF >/dev/null"

# ---------- double click: desktop file + file types ----------
step "Double click: file types .exe .com .bat .msi open with exe-handler"
doing "desktop entry $DESKTOP (with right-click 'Open in DOSBox' / 'Open in Wine')"
sudo_run mkdir -p "$(dirname "$DESKTOP")"
run bash -c "cat > /tmp/exe-handler.desktop.$$ <<EOF
[Desktop Entry]
Type=Application
Name=Windows/DOS program
Name[nl]=Windows/DOS-programma
Comment=Open with Wine or DOSBox-X, chosen automatically
Comment[nl]=Openen met Wine of DOSBox-X, automatisch gekozen
Exec=$BIN %f
Icon=wine
Terminal=false
NoDisplay=true
MimeType=$MIMES
Actions=dos;wine;

[Desktop Action dos]
Name=Open in DOSBox
Name[nl]=Openen in DOSBox
Exec=$BIN --dos %f

[Desktop Action wine]
Name=Open in Wine
Name[nl]=Openen in Wine
Exec=$BIN --wine %f
EOF
$SUDO install -m 644 /tmp/exe-handler.desktop.$$ $DESKTOP; rm -f /tmp/exe-handler.desktop.$$"
doing "adding the file types .com and .bat, refreshing the file type databases"
run bash -c "cat > /tmp/exe-handler-mime.$$ <<'EOF'
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<mime-info xmlns=\"http://www.freedesktop.org/standards/shared-mime-info\">
  <mime-type type=\"application/x-com\"><comment>DOS program</comment><glob pattern=\"*.com\" weight=\"60\"/></mime-type>
  <mime-type type=\"application/x-bat\"><comment>DOS batch file</comment><glob pattern=\"*.bat\" weight=\"60\"/></mime-type>
</mime-info>
EOF
$SUDO install -D -m 644 /tmp/exe-handler-mime.$$ /usr/local/share/mime/packages/exe-handler.xml; rm -f /tmp/exe-handler-mime.$$"
command -v update-mime-database >/dev/null && sudo_run update-mime-database /usr/local/share/mime || true
command -v update-desktop-database >/dev/null && sudo_run update-desktop-database "$(dirname "$DESKTOP")" || true
# make exe-handler the default for the user (also overrides Wine's own "Wine Windows Program Loader")
TARGET_USER=${SUDO_USER:-$(id -un)}
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
as_user() { if [ "$(id -un)" = "$TARGET_USER" ]; then run "$@"; else run sudo -u "$TARGET_USER" HOME="$TARGET_HOME" "$@"; fi; }
if command -v xdg-mime >/dev/null && [ "$TARGET_USER" != root ]; then
  doing "making exe-handler the default program for these file types for user $TARGET_USER"
  as_user mkdir -p "$TARGET_HOME/.config"
  for m in ${MIMES//;/ }; do as_user xdg-mime default exe-handler.desktop "$m"; done
fi

# ---------- Wine ready at login (optional): no stutter at the first Windows program ----------
# The wineserver always stays on after the first Windows program, so only that first start of a session reads all
# monitors. With several monitors that freezes the desktop a few times; --warmup-at-login moves it to the login.
AUTOSTART=/etc/xdg/autostart/exe-handler-warmup.desktop
MONITORS=$( { xrandr --current 2>/dev/null | grep -c ' connected'; } || true)
if [ -n "$WINE_CMD" ] && [ $WARMUP = 1 ]; then
  doing "autostart entry: Wine gets ready in the background 20 seconds after login (exe-handler --warmup)"
  run bash -c "printf '[Desktop Entry]\nType=Application\nName=exe-handler warmup\nComment=Get Wine ready so Windows programs start without stutter\nExec=$BIN --warmup\nNoDisplay=true\nX-GNOME-Autostart-Delay=20\n' | $SUDO tee $AUTOSTART >/dev/null"
elif [ $WARMUP = -1 ] && [ -e $AUTOSTART ]; then
  doing "removing the autostart entry (Wine is no longer made ready at login)"
  sudo_run rm -f $AUTOSTART
elif [ -e $AUTOSTART ]; then
  echo "   =  Wine is made ready at login (chosen earlier; remove with --no-warmup-at-login)"
elif [ -n "$WINE_CMD" ] && [ "${MONITORS:-0}" -gt 1 ]; then
  TIP_WARMUP=1
fi

# ---------- kernel: let .exe files run like normal programs ----------
# File managers and exFAT/NTFS disks often mark .exe files as executable; the system then tries to run them
# directly and fails. With this rule the kernel hands every DOS/Windows program (starts with "MZ") to exe-handler.
if [ $BINFMT = 1 ] && [ -d /etc/binfmt.d ]; then
  step "Kernel rule: executable .exe files start via exe-handler (binfmt_misc)"
  # zz-: loaded after Wine's own rule (wine.conf) at boot, so exe-handler's rule is the one that counts
  [ -e /etc/binfmt.d/exe-handler.conf ] && sudo_run rm -f /etc/binfmt.d/exe-handler.conf
  doing "writing the rule (kept after a reboot) and switching it on now"
  run bash -c "echo ':exe-handler:M::MZ::$BIN:' | $SUDO tee /etc/binfmt.d/zz-exe-handler.conf >/dev/null"
  if [ -e /proc/sys/fs/binfmt_misc/register ] && [ ! -e /proc/sys/fs/binfmt_misc/exe-handler ]; then
    # Wine's own rule would catch the same files first; turn it off if present
    for w in wine windows windowsPE DOSWin; do
      [ -e /proc/sys/fs/binfmt_misc/$w ] && run bash -c "echo 0 | $SUDO tee /proc/sys/fs/binfmt_misc/$w >/dev/null"
    done
    run bash -c "echo ':exe-handler:M::MZ::$BIN:' | $SUDO tee /proc/sys/fs/binfmt_misc/register >/dev/null" || warn "could not register now; active after reboot"
  fi
fi

# ---------- prepare Wine for the user now, so the first double click is fast ----------
if [ -n "$WINE_CMD" ] && [ "$TARGET_USER" != root ] && { [ "$PAGESIZE" = 4096 ] || [ "$ARCH" != aarch64 ]; }; then
  if [ ! -e "$TARGET_HOME/.wine/drive_c/windows/system32/kernel32.dll" ]; then
    step "Wine folder ~/.wine for $TARGET_USER (one time)"
    busy "Wine is creating its Windows folder (1-3 minutes)" as_user env WINEDEBUG=-all BOX64_LOG=0 BOX64_NOBANNER=1 $WINE_CMD wineboot -u || warn "it will be tried again on the first start of a Windows program"
  else
    step "Wine folder ~/.wine for $TARGET_USER"; echo "   =  already there"
  fi
fi

printf '\n\033[1;32mDone in %s.\033[0m\n' "$(elapsed)"
echo "   DOS programs:      ${DOSBOX_CMD:-not available}"
echo "   Windows programs:  ${WINE_CMD:-not available}$(command -v ${WINE_CMD%% *} >/dev/null 2>&1 && [ "$ARCH" != aarch64 ] && echo "  ($(wine --version 2>/dev/null))")"
[ -f "$OPT/cnc-ddraw/ddraw.dll" ] && echo "   Old DirectDraw:    cnc-ddraw in $OPT/cnc-ddraw"
echo "   Details of this run: $ILOG"
if [ "${TIP_WARMUP:-0}" = 1 ]; then
  echo "   Tip: this computer has $MONITORS monitors. The first Windows program after login can make the desktop"
  echo "        stutter for a second or two. Run  ./install.sh --warmup-at-login  to move that to the login."
fi
echo "   Double-click a .exe, .com, .bat or .msi file; exe-handler picks Wine or DOSBox-X by itself."
echo "   Right-click > 'Open in DOSBox' / 'Open in Wine' forces a choice. Log: ~/.cache/exe-handler.log"
[ "${NEED_REBOOT:-0}" = 1 ] && warn "Reboot the Raspberry Pi to use the 4K kernel before starting Windows programs."
exit 0
