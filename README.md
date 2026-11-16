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

Het script vraagt één keer om je wachtwoord (sudo) en laat per stap zien wat het doet. Daarna kun je meteen
`.exe`-bestanden dubbelklikken.

| Optie | Wat |
|---|---|
| `--dry-run` | alleen laten zien wat er zou gebeuren |
| `--yes` | geen vragen stellen |
| `--update` | alleen het programma exe-handler vervangen door de nieuwste versie van GitHub |
| `--warmup-at-login` | Wine na elke login alvast klaarzetten (zie *Haperen bij het starten*); weg met `--no-warmup-at-login` |
| `--no-binfmt` | de kernelregel voor uitvoerbare `.exe`-bestanden overslaan |

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
met een vaste, geteste Wine-versie (11.4, x86-64 WoW64-build van Kron4ek; nieuwere versies starten nog niet onder
Box64). Box64 komt uit de apt-bron van Pi-Apps-Coders; op andere distributies wordt Box64 uit de broncode gebouwd.

### Wat install.sh installeert en instelt

1. **Basisgereedschap**: zenity (meldingen), curl, xz/unzip, en voor de vensters `xrandr`, `xwininfo`, `wmctrl`,
   `xdotool` en ImageMagick; een kleine klankbank (SoundFont) voor MIDI-muziek.
2. **DOSBox-X** uit de pakketbron; als die er niet is via Flatpak, anders gewone DOSBox.
3. **Wine**:
   - x86-64 (Ubuntu/Zorin/Debian/Mint): `wine`, `wine64` en `wine32:i386` (zet i386 aan), plus winetricks;
     Fedora/Arch/openSUSE: het `wine`-pakket.
   - ARM64: Box64, Wine 11.4 in `/opt/exe-handler/wine` (download gecontroleerd met sha256), de ARM-bibliotheken
     die Wine nodig heeft, en `wine`/`winecfg`/... als gewone opdrachten. Plus otvdm voor 16-bit programma's.
   - Raspberry Pi 5 met 16K-geheugenpagina's: biedt aan om `kernel=kernel8.img` in te stellen (Wine heeft 4K nodig).
4. **cnc-ddraw** (alleen x86) in `/opt/exe-handler/cnc-ddraw`, voor oude DirectDraw-spellen (download gecontroleerd
   met sha256).
5. **`/usr/local/bin/exe-handler`** (dit programma) en `/etc/exe-handler.conf` (welke Wine/DOSBox gebruikt wordt).
6. **Dubbelklikken**: een `.desktop`-bestand voor alle exe-bestandstypen, standaard gemaakt voor jouw gebruiker
   (gaat ook boven Wine's eigen loader of Zorin's "Windows App Support"-melding). Rechtsklik heeft
   *Openen in DOSBox* en *Openen in Wine* om zelf te kiezen.
7. **Kernelregel (binfmt_misc)**: elk bestand dat met "MZ" begint en uitvoerbaar is, gaat naar exe-handler.
   Daardoor werken ook `.exe`-bestanden op exFAT/NTFS-schijven (waar alles "uitvoerbaar" is) en `./spel.exe`
   in een terminal. Uitzetten met `--no-binfmt`.
8. **Wine-map** `~/.wine` wordt alvast aangemaakt, zodat de eerste dubbelklik snel is.

Alles wat stil op de achtergrond draait, komt in een logbestand in `/tmp`; het pad staat aan het begin en het eind.

## Windows-programma's

- **Vensters**: de normale titelbalk van je bureaublad, dus minimaliseren, maximaliseren, verslepen en sluiten
  werken. In volledig scherm wordt de muis niet vastgehouden, dus **Alt+Tab** werkt.
- **Windows-versie**: programma's gebouwd voor Windows 95 t/m XP krijgen automatisch "XP" (minder installatiefouten).
- **Oude DirectDraw-spellen** (Windows 95-XP, bijvoorbeeld Jazz Jackrabbit 2) vragen het scherm om 320x200 of
  640x480 in 256 kleuren; moderne schermen weigeren dat ("Could not set video mode"). Op x86 zet exe-handler
  eenmalig [cnc-ddraw](https://github.com/FunkyFr3sh/cnc-ddraw) (`ddraw.dll` + `ddraw.ini`) naast het spel: het
  spel draait dan in een gewoon venster dat je kunt vergroten en maximaliseren, het beeld schaalt mee. Gebruik de
  maximaliseerknop voor een groot beeld; de eigen volledig-scherm-toets van het spel (Alt+Enter) werkt dan niet.
  Uitzetten per spel: maak een leeg bestand `exe-handler.no-ddraw` naast de .exe en verwijder `ddraw.dll`/`ddraw.ini`.
- **Andere programma's die de schermresolutie wisselen**: Wine 10 en nieuwer bootst die wissel na
  (`EmulateModeset`), je echte monitor en de indeling van meerdere schermen blijven zoals ze zijn. Als vangnet zet
  exe-handler na afloop de monitoren terug als een programma ze toch heeft veranderd (bijvoorbeeld na een crash).
- **Oude Visual Basic-programma's** (VB3 t/m VB6) crashen met *"Run-time error 6: Overflow"* op schermen breder
  of hoger dan 2184 pixels (ook twee monitoren naast elkaar). Is je hele bureaublad kleiner, dan draaien ze gewoon direct.
  Anders start exe-handler ze in een eigen Wine-bureaublad van 1600x900. Wine 10 toont dat schermvullend en zonder rand;
  exe-handler maakt er een gewoon venster met titelbalk van dat precies om het programma past, en schuift Wine's
  eigen titelbalk uit beeld, zodat je één venster ziet (op X11).
- **Visual Basic-runtime één map hoger** (zoals op shareware-cd's, `VBRUN300.DLL` naast de spelmappen) wordt gevonden.
- **Haperen bij het starten**: start Wine vanaf nul, dan leest het een tiental keer alle monitoren opnieuw uit; bij
  meerdere schermen staat het bureaublad daarbij telkens even stil (gemeten op drie schermen: 12 keer, samen
  2 seconden). exe-handler laat de Wine-server daarom aanstaan na het eerste Windows-programma: alleen dat eerste
  programma van een sessie hapert nog. Met `./install.sh --warmup-at-login` wordt Wine 20 seconden na het inloggen
  alvast klaargezet en start ook het eerste programma soepel. Standaard staat dat uit; het installatiescript geeft
  een tip als het meer dan één scherm ziet.

## DOS-programma's

- **Venster**: vergroten en maximaliseren kan, het beeld schaalt mee. **Alt+Enter** = volledig scherm aan/uit. DOSBox-X
  heeft dat zelf op F12+F; exe-handler vangt Alt+Enter af en geeft het zo door (op X11). Het DOSBox-X-menu is verborgen. Het venster sluiten vraagt niet om bevestiging.
- **Muis**: klik in het venster en de muis wordt gevangen, zodat bewegen werkt in spellen als Doom; **Ctrl+F10**
  laat hem weer los.
- **Snelheid**: DOSBox geeft oude (real-mode) spellen standaard de snelheid van een trage 286. exe-handler kiest de
  snelheid naar het jaartal van het programma (jaren 80: 3000 cycles, 1994 en later: 20000); zet zelf een getal bij
  `cycles` in `dos.conf` om dat vast te zetten.
- **MIDI-muziek**: DOSBox-X krijgt de klankbank (SoundFont) van het systeem aangewezen; zonder blijven spellen met
  General MIDI-muziek stil.
- **Programma's op een netwerkshare** die je in Bestanden opent (`smb://...`): DOSBox-X kan niet tegen de dubbele
  punt in zo'n pad; exe-handler koppelt de map via een snelkoppeling in `~/.cache/exe-handler/dos/`.
- Instellingen: `~/.config/exe-handler/dos.conf` (wordt bij de eerste DOS-start aangemaakt).

## Per programma aanpassen (optioneel)

| Bestand | Waar | Wat |
|---|---|---|
| `exe-handler.start` | naast de .exe | regels `Game.exe = Loader.exe`: start de loader als je Game.exe opent |
| `exe-handler.reg` | naast de .exe | registerbestand dat vóór elke start wordt ingelezen |
| `exe-handler.no-ddraw` | naast de .exe | leeg bestand: geen cnc-ddraw voor dit spel |
| `virtual-desktop.conf` | `~/.config/exe-handler/` | `spel.exe 1024x768`: in een eigen Wine-bureaublad van die grootte |
| `x11.conf` | `~/.config/exe-handler/` | `spel.exe` per regel: op een Wayland-bureaublad toch Wine's X11-weergave gebruiken (muis in sommige spellen) |
| `dos.conf` | `~/.config/exe-handler/` | DOSBox-X-instellingen |

Logboek: `~/.cache/exe-handler.log`. Werkt iets niet zoals verwacht, dan laat `exe-handler --check bestand.exe`
zien wat exe-handler ermee zou doen (type, Visual Basic, schermgrootte, eigen venster, en of dubbelklikken echt
via exe-handler gaat). Handmatig: `exe-handler [--dos|--wine] bestand.exe [argumenten]`.

## Bijwerken

`./install.sh --update` haalt de nieuwste versie van het programma exe-handler van GitHub en zet die op zijn
plek. Wine, DOSBox-X en de instellingen blijven zoals ze zijn. Komt er een onderdeel bij (zoals cnc-ddraw), haal
dan de map opnieuw op (`git pull`) en draai `./install.sh` nog een keer; wat er al staat wordt overgeslagen.

## Verwijderen

`./uninstall.sh` haalt exe-handler, de bestandskoppelingen, de kernelregel en het klaarzetten bij het inloggen
weg. Wine, DOSBox-X, Box64 en `~/.wine` blijven staan.

## Getest

- **Raspberry Pi 5** (Raspberry Pi OS / Debian 13, arm64): schone installatie in een container; Wine 11.4 via
  Box64, 32- en 64-bit, opdrachtregel en vensterprogramma's.
- **Zorin OS 18** (x86-64) met Wine 10 en drie monitoren: DOS-spellen vanaf een netwerkshare (Aladdin), 16-bit
  Windows (Jixxa, Tinyjong, WinPac), Visual Basic (Poker Broker), DirectDraw (Jazz Jackrabbit 2), starten zonder
  haperen.

Bekende beperkingen: niet elk Windows-programma draait in Wine. cnc-ddraw is alleen op x86 getest en staat op
ARM uit. Het passend maken van vensters werkt op X11 (ook via XWayland), niet voor Wine's eigen Wayland-vensters.

## English summary

`install.sh` sets up Linux (x86-64 or ARM64) so that double-clicking DOS and Windows programs just works.

- **Choice by file header**: DOSBox-X for DOS, Wine for Windows (on ARM64: Wine 11.4 x86-64 via Box64, otvdm for
  16-bit), `msiexec` for `.msi`, a terminal for console programs.
- **Integration**: file associations, right-click "Open in DOSBox / Wine", a binfmt_misc rule for executable
  `.exe` files, the Wine folder prepared in advance.
- **Windows programs**: normal window decorations and Alt+Tab; old DirectDraw games in a scaled, resizable window
  through cnc-ddraw (x86) instead of a 320x200/640x480 mode switch; old Visual Basic programs in a fitted virtual
  desktop window (they overflow on screens wider than 2184 pixels); the wineserver stays on so that only the first
  program of a session can stutter on multi-monitor desktops (`--warmup-at-login` moves that to the login).
- **DOS programs**: resizable window, F12+F fullscreen, mouse caught on click (Ctrl+F10 releases), speed chosen
  from the program's date, a sound font for General MIDI, folders on network shares mounted through a symlink.

Run `./install.sh` (`--dry-run` to preview). Update the program with `./install.sh --update`, uninstall with
`./uninstall.sh`.

Third-party software that the installer downloads: [Wine](https://www.winehq.org) builds by
[Kron4ek](https://github.com/Kron4ek/Wine-Builds), [Box64](https://github.com/ptitSeb/box64) via
[Pi-Apps-Coders/box64-debs](https://github.com/Pi-Apps-Coders/box64-debs),
[otvdm/winevdm](https://github.com/otya128/winevdm), [cnc-ddraw](https://github.com/FunkyFr3sh/cnc-ddraw),
[DOSBox-X](https://dosbox-x.com).

## Licentie / License

MIT, zie / see [LICENSE](LICENSE).
