# exe-handler

Dubbelklik op een `.exe`, `.com`, `.bat` of `.msi` en het programma start gewoon, op Linux. DOS-programma's,
oude en nieuwe Windows-programma's, op een gewone PC (x86-64) en op een Raspberry Pi of ander ARM64-bord.

*English summary below.*

## Installeren

```bash
git clone https://github.com/davyschroeder/exe-handler.git
cd exe-handler
./install.sh
```

Het script vraagt om je wachtwoord (sudo) waar nodig. Daarna kun je meteen `.exe`-bestanden dubbelklikken.
Opties: `--yes` (geen vragen), `--dry-run` (alleen laten zien wat er zou gebeuren), `--no-binfmt` (zie onder).

## Wat het doet

Het kijkt **in** het bestand (de header), niet naar de naam, en kiest dan zelf:

| Soort programma | Start met |
|---|---|
| DOS (`.exe`, `.com`, `.bat`, ook met DOS-extenders zoals DOS4GW) | **DOSBox-X** |
| Windows 64-bit en 32-bit | **Wine** |
| Windows 16-bit (Windows 3.x) | Wine; op ARM via **otvdm** |
| `.msi`-installatie | Wine `msiexec` |
| Opdrachtregelprogramma | Wine in een terminalvenster dat open blijft |

Op een **ARM64**-computer (Raspberry Pi 4/5 enz.) draait Windows-software via **Box64** (vertaalt x86-64 naar ARM)
met een vaste, geteste Wine-versie (11.4, x86-64 WoW64-build van Kron4ek). Box64 komt uit de apt-bron van
Pi-Apps-Coders; op andere distributies wordt Box64 uit de broncode gebouwd.

### Wat install.sh installeert en instelt

1. **Basisgereedschap**: zenity (meldingen), curl, xz/unzip, xrandr.
2. **DOSBox-X** uit de pakketbron; als die er niet is via Flatpak, anders gewone DOSBox.
3. **Wine**:
   - x86-64 (Ubuntu/Zorin/Debian/Mint): `wine`, `wine64` en `wine32:i386` (zet i386 aan), plus winetricks;
     Fedora/Arch/openSUSE: het `wine`-pakket.
   - ARM64: Box64, Wine 11.4 in `/opt/exe-handler/wine` (download gecontroleerd met sha256), de ARM-bibliotheken
     die Wine nodig heeft, en `wine`/`winecfg`/... als gewone opdrachten. Plus otvdm voor 16-bit programma's.
   - Raspberry Pi 5 met 16K-geheugenpagina's: biedt aan om `kernel=kernel8.img` in te stellen (Wine heeft 4K nodig).
4. **`/usr/local/bin/exe-handler`** (dit programma) en `/etc/exe-handler.conf` (welke Wine/DOSBox gebruikt wordt).
5. **Dubbelklikken**: een `.desktop`-bestand voor alle exe-bestandstypen, standaard gemaakt voor jouw gebruiker
   (gaat ook boven Wine's eigen loader of Zorin's "Windows App Support"-melding). Rechtsklik heeft
   *Openen in DOSBox* en *Openen in Wine* om zelf te kiezen.
6. **Kernelregel (binfmt_misc)**: elk bestand dat met "MZ" begint en uitvoerbaar is, gaat naar exe-handler.
   Daardoor werken ook `.exe`-bestanden op exFAT/NTFS-schijven (waar alles "uitvoerbaar" is) en `./spel.exe`
   in een terminal. Uitzetten met `--no-binfmt`.
7. **Wine-map** `~/.wine` wordt alvast aangemaakt, zodat de eerste dubbelklik snel is.

### Vensters, volledig scherm, minimaliseren

- **Windows-programma's** krijgen de normale titelbalk van je bureaublad, dus minimaliseren, maximaliseren,
  verslepen en sluiten werken. In volledig scherm wordt de muis niet vastgehouden, dus **Alt+Tab** werkt.
- **Oude Visual Basic-programma's** (VB3 t/m VB6) crashen met *"Run-time error 6: Overflow"* op schermen breder
  of hoger dan 2184 pixels (ook twee monitoren naast elkaar). exe-handler herkent ze en start ze altijd in een
  eigen venster van 1600x900 (kleiner als je scherm kleiner is).
- **DOS-programma's**: venster dat je kunt vergroten/maximaliseren (het beeld schaalt mee), **F12+F** = volledig
  scherm aan/uit, klik in het venster om de muis te vangen (Ctrl+F10 laat los). Het DOSBox-X-menu is verborgen; instellingen staan in
  `~/.config/exe-handler/dos.conf`.
- Programma's gebouwd voor Windows 95 t/m XP krijgen automatisch Windows-versie "XP" (minder installatiefouten).

- **Spellen die de schermresolutie wisselen** (oude DirectDraw-spellen naar 640x480): Wine 10 en nieuwer bootst die
  wissel na (`EmulateModeset`), je echte monitor en de indeling van meerdere schermen blijven zoals ze zijn. Als
  vangnet zet exe-handler na afloop de monitoren terug als een programma ze toch heeft veranderd (bijvoorbeeld na
  een crash).
- **Oude DirectDraw-spellen** (Windows 95-XP, bijvoorbeeld Jazz Jackrabbit 2) vragen het scherm om 320x200 of
  640x480 in 256 kleuren; moderne schermen weigeren dat ("Could not set video mode"). Op x86 zet exe-handler
  eenmalig [cnc-ddraw](https://github.com/FunkyFr3sh/cnc-ddraw) (`ddraw.dll` + `ddraw.ini`) naast het spel: het
  spel draait dan in een gewoon venster dat je kunt vergroten en maximaliseren, het beeld schaalt mee. Uitzetten
  per spel: maak een leeg bestand `exe-handler.no-ddraw` naast de .exe en verwijder `ddraw.dll`/`ddraw.ini`.
- **Programma's op een netwerkshare** die je in Bestanden opent (`smb://...`): DOSBox-X kan niet tegen de dubbele
  punt in zo'n pad; exe-handler koppelt de map via een snelkoppeling in `~/.cache/exe-handler/dos/`.
- **Snelheid van DOS-spellen**: DOSBox geeft oude (real-mode) spellen standaard de snelheid van een trage 286.
  exe-handler kiest de snelheid naar het jaartal van het programma (jaren 80: 3000 cycles, 1994 en later: 20000);
  zet zelf een getal bij `cycles` in `dos.conf` om dat vast te zetten.
- **Afsluiten van DOSBox-X** vraagt niet meer om bevestiging.
- **Muis in DOS-spellen** (Doom): klik in het venster en de muis wordt gevangen, zodat bewegen werkt; **Ctrl+F10**
  laat hem weer los.
- **MIDI-muziek**: DOSBox-X krijgt de klankbank (SoundFont) van het systeem aangewezen; zonder blijven spellen met
  General MIDI-muziek stil.
- **Het eigen venster voor Visual Basic-programma's**: Wine 10 toont zo'n virtueel bureaublad schermvullend en zonder
  rand op één monitor; exe-handler maakt er weer een gewoon venster met titelbalk van dat precies om het programma past, en schuift
  Wine's eigen titelbalk uit beeld zodat je één venster ziet (via `wmctrl`, `xdotool` en `xwininfo`, op X11).
- **Visual Basic-runtime één map hoger** (zoals op shareware-cd's, `VBRUN300.DLL` naast de spelmappen) wordt gevonden.

### Per programma aanpassen (optioneel)

| Bestand | Waar | Wat |
|---|---|---|
| `exe-handler.start` | naast de .exe | regels `Game.exe = Loader.exe`: start de loader als je Game.exe opent |
| `exe-handler.reg` | naast de .exe | registerbestand dat vóór elke start wordt ingelezen |
| `virtual-desktop.conf` | `~/.config/exe-handler/` | `spel.exe 1024x768`: in een eigen venster van die grootte (voor spellen die de resolutie wisselen) |
| `dos.conf` | `~/.config/exe-handler/` | DOSBox-X-instellingen |

Logboek: `~/.cache/exe-handler.log`. Werkt iets niet zoals verwacht, dan laat `exe-handler --check bestand.exe`
zien wat exe-handler ermee zou doen (type, Visual Basic, schermgrootte, eigen venster, en of dubbelklikken echt
via exe-handler gaat). Handmatig: `exe-handler [--dos|--wine] bestand.exe [argumenten]`.

### Bijwerken

`./install.sh --update` haalt de nieuwste versie van het programma exe-handler van GitHub en zet die op zijn
plek. Wine, DOSBox-X en de instellingen blijven zoals ze zijn.

### Verwijderen

`./uninstall.sh` haalt exe-handler, de bestandskoppelingen en de kernelregel weg. Wine, DOSBox-X, Box64 en
`~/.wine` blijven staan.

### Getest

- Raspberry Pi 5 (Raspberry Pi OS / Debian 13, arm64): schone installatie in een container; Wine 11.4 via Box64,
  32- en 64-bit, opdrachtregel en vensterprogramma's, DOSBox-X.

## English summary

`install.sh` sets up Linux (x86-64 or ARM64) so that double-clicking DOS and Windows programs just works:
DOSBox-X for DOS, Wine for Windows (on ARM64: Wine 11.4 x86-64 via Box64, otvdm for 16-bit), file associations,
a binfmt_misc rule for executable `.exe` files, normal window decorations (minimise/maximise) and Alt+Tab in
fullscreen, and an automatic virtual desktop for old Visual Basic programs on wide screens. Run `./install.sh`
(`--dry-run` to preview). Update the program with `./install.sh --update`, uninstall with `./uninstall.sh`.

Third-party software that the installer downloads: [Wine](https://www.winehq.org) builds by
[Kron4ek](https://github.com/Kron4ek/Wine-Builds), [Box64](https://github.com/ptitSeb/box64) via
[Pi-Apps-Coders/box64-debs](https://github.com/Pi-Apps-Coders/box64-debs),
[otvdm/winevdm](https://github.com/otya128/winevdm), [DOSBox-X](https://dosbox-x.com).

## Licentie / License

MIT, zie / see [LICENSE](LICENSE).
