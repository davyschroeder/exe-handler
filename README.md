# exe-handler

Dubbelklik op een `.exe`, `.com`, `.bat` of `.msi` en het programma start gewoon, op Linux. DOS-programma's,
oude en nieuwe Windows-programma's, op een gewone PC (x86-64) en op een Raspberry Pi of ander ARM64-bord.

*English summary below.*

## Installeren

```bash
curl -fsSL https://raw.githubusercontent.com/davyschroeder/exe-handler/main/install.sh | bash
```

Dat ene commando haalt alles op en installeert alles wat nodig is (Wine of Box64 + Wine, DOSBox-X, otvdm,
cnc-ddraw, DXVK, Vulkan). Git is niet nodig. Met een eigen kopie kan het ook:
`git clone https://github.com/davyschroeder/exe-handler.git && cd exe-handler && ./install.sh`.

Het script vraagt één keer om je wachtwoord (sudo) en laat per stap zien wat het doet. Daarna kun je meteen
`.exe`-bestanden dubbelklikken.

| Optie | Wat |
|---|---|
| `--dry-run` | alleen laten zien wat er zou gebeuren |
| `--yes` | geen vragen stellen |
| `--update` | de nieuwste versie van GitHub installeren, inclusief nieuwe onderdelen die erbij gekomen zijn |
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
4. **cnc-ddraw** (x86 en ARM64) in `/opt/exe-handler/cnc-ddraw`, voor oude DirectDraw-spellen (download gecontroleerd
   met sha256).
5. **DXVK** 3.1.1 in `/opt/exe-handler/dxvk` (x86 en ARM64, download gecontroleerd met sha256), automatisch
   gebruikt voor Direct3D-spellen (zie hieronder).
6. **`/usr/local/bin/exe-handler`** (dit programma) en `/etc/exe-handler.conf` (welke Wine/DOSBox gebruikt wordt).
7. **Dubbelklikken**: een `.desktop`-bestand voor alle exe-bestandstypen, standaard gemaakt voor jouw gebruiker
   (gaat ook boven Wine's eigen loader of Zorin's "Windows App Support"-melding). Rechtsklik heeft
   *Openen in DOSBox* en *Openen in Wine* om zelf te kiezen.
8. **Kernelregel (binfmt_misc)**: elk bestand dat met "MZ" begint en uitvoerbaar is, gaat naar exe-handler.
   Daardoor werken ook `.exe`-bestanden op exFAT/NTFS-schijven (waar alles "uitvoerbaar" is) en `./spel.exe`
   in een terminal. Uitzetten met `--no-binfmt`.
9. **Wine-map** `~/.wine` wordt alvast aangemaakt, zodat de eerste dubbelklik snel is.

Alles wat stil op de achtergrond draait, komt in een logbestand in `/tmp`; het pad staat aan het begin en het eind.

## Windows-programma's

- **Vensters**: de normale titelbalk van je bureaublad, dus minimaliseren, maximaliseren, verslepen en sluiten
  werken. In volledig scherm wordt de muis niet vastgehouden, dus **Alt+Tab** werkt.
- **Windows-versie**: programma's gebouwd voor Windows 95 t/m XP krijgen automatisch "XP" (minder installatiefouten).
- **Oude DirectDraw-spellen** (Windows 95-XP, bijvoorbeeld Jazz Jackrabbit 2) vragen het scherm om 320x200 of
  640x480 in 256 kleuren; moderne schermen weigeren dat ("Could not set video mode"). exe-handler zet
  eenmalig [cnc-ddraw](https://github.com/FunkyFr3sh/cnc-ddraw) (`ddraw.dll` + `ddraw.ini`) naast het spel: het
  spel draait dan in een gewoon venster dat je kunt vergroten en maximaliseren, het beeld schaalt mee. Gebruik de
  maximaliseerknop voor een groot beeld; de eigen volledig-scherm-toets van het spel (Alt+Enter) werkt dan niet.
  Uitzetten per spel: maak een leeg bestand `exe-handler.no-ddraw` naast de .exe en verwijder `ddraw.dll`/`ddraw.ini`.
  Ook op ARM64: cnc-ddraw is x86-Windows-code net als het spel en draait onder Box64. Een starter die zelf niet
  tekent (Red Alert 2: `Ra2.exe` start `game.exe`) krijgt het ook, als er een oud DirectDraw-spel naast staat. Staat
  er al een cnc-ddraw naast het spel (bijvoorbeeld zelf geplaatst), dan zorgt exe-handler dat Wine die laadt.
- **Ontbrekende DLL**: stopt een programma meteen, dan kijkt exe-handler welke DLL's het nodig heeft die niet naast
  het programma, niet in de Wine-map en niet in Wine zelf zitten, en noemt die bij naam (bijvoorbeeld *"CNCS32.DLL
  ontbreekt"*). Oude programma's rekenden vaak op een DLL die Windows 95/98 of een ander programma al had
  geplaatst (MFC30.DLL, CNCS32.DLL); zet dat bestand naast de .exe of in `~/.wine/drive_c/windows/syswow64`
  (32-bit) of `system32` (64-bit).
- **Direct3D-spellen** krijgen vanzelf [DXVK](https://github.com/doitsujin/dxvk) (Direct3D via Vulkan) als dat
  beter werkt dan Wine's eigen Direct3D. exe-handler kijkt in de .exe en in de DLL's die het spel uit zijn eigen map
  laadt (Unity-spellen hebben hun Direct3D in `UnityPlayer.dll`):
  - **Direct3D 10/11** (Unity-spellen, foutmelding *"failed to create device"*): altijd DXVK. Heeft de grafische
    kaart een functie niet die DXVK nodig heeft (de Raspberry Pi 5 mist `multiDrawIndirect`), dan gebruikt DXVK
    Mesa's software-Vulkan (llvmpipe): het spel start, maar traag.
  - **Direct3D 8/9**: DXVK alleen als de grafische kaart het aankan; anders is Wine's eigen Direct3D sneller.

  exe-handler zet de DLL's eenmalig naast het spel (lijstje in `exe-handler.dxvk`). Zelf kiezen: zet de .exe in
  `dxvk.conf` (altijd DXVK) of `no-dxvk.conf` (nooit), of maak een leeg bestand `exe-handler.no-dxvk` naast de .exe.
  `exe-handler --check spel.exe` laat zien wat exe-handler kiest.
- **Andere programma's die de schermresolutie wisselen**: Wine 10 en nieuwer bootst die wissel na
  (`EmulateModeset`), je echte monitor en de indeling van meerdere schermen blijven zoals ze zijn. Als vangnet zet
  exe-handler na afloop de monitoren terug als een programma ze toch heeft veranderd (bijvoorbeeld na een crash).
- **Oude Visual Basic-programma's** (VB3 t/m VB6) crashen met *"Run-time error 6: Overflow"* op schermen breder
  of hoger dan 2184 pixels (ook twee monitoren naast elkaar). Is je hele bureaublad kleiner, dan draaien ze gewoon direct.
  Anders start exe-handler ze in een eigen Wine-bureaublad van 1600x900. Wine 10 toont dat schermvullend en zonder rand;
  exe-handler maakt er een gewoon venster met titelbalk van dat precies om het programma past, en schuift Wine's
  eigen titelbalk uit beeld, zodat je één venster ziet (op X11).
- **Visual Basic-runtime één map hoger** (zoals op shareware-cd's, `VBRUN300.DLL` naast de spelmappen) wordt gevonden.
  Voor 16-bit programma's zet exe-handler die runtime eenmalig in `C:\windows\system` van Wine (zoals Windows 3.1
  dat deed); bestaande bestanden worden niet overschreven.
- **Gedeelde DLL's van Windows 3.1** (`BWCC.DLL`, `CTL3DV2.DLL`, VBX-besturingselementen): een 16-bit programma dat
  er een noemt die niet naast het programma, niet in Wine en niet in otvdm zit, krijgt die uit de map erboven of
  een map ernaast (op shareware-cd's zit `BWCC.DLL` bij één spel en missen de andere hem), eenmalig in
  `C:\windows\system`. Voorbeeld: Flip'em vindt `BWCC.DLL` bij 8-Ball Pool.
- **Programma in een Wine-map**: staat een programma in `.../drive_c/...` van een Wine-map (geïnstalleerd met een
  installer), dan draait het in die Wine-map, met de DLL's en registerinstellingen die de installer daar zette.
- **Crash bij de start onder Box64**: wordt Wine binnen 30 seconden door een crash-signaal gestopt (gezien bij de
  eerste start van een Unity-spel), dan start exe-handler het één keer opnieuw.
- **DDrawCompat**: heruitgaven van oude spellen (bijvoorbeeld Red Alert 2) brengen een eigen `ddraw.dll` mee, een
  hulpmiddel voor Windows 10/11 dat in Wine meteen crasht. exe-handler herkent die, hernoemt hem naar
  `ddraw.dll.DDrawCompat` (terugzetten = terug hernoemen) en gebruikt cnc-ddraw; zonder cnc-ddraw Wine's eigen
  DirectDraw.
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
  snelheid naar het jaartal van het programma (jaren 80: 3000 cycles, 1994 en later: 20000; bij een `.bat` het
  jaartal van het programma dat die start); zet zelf een getal bij
  `cycles` in `dos.conf` om dat vast te zetten.
- **MIDI-muziek**: DOSBox-X krijgt de klankbank (SoundFont) van het systeem aangewezen; zonder blijven spellen met
  General MIDI-muziek stil.
- **Netwerkshare en opslaan**: via Bestanden (`smb://...`, gvfs) kan een programma bestaande bestanden niet
  wijzigen. Een DOS-SETUP die zijn stuurbestanden aanpast (Epic Pinball) of een spel dat een savebestand bijwerkt,
  mislukt dan stil ("Please run SETUP!"). Is dezelfde share ook vast gekoppeld (cifs, bijvoorbeeld `/mnt/nas`), dan
  gebruikt exe-handler automatisch dat pad en werkt opslaan wel.
- **Programma's op een netwerkshare** die je in Bestanden opent (`smb://...`): DOSBox-X kan niet tegen de dubbele
  punt in zo'n pad; exe-handler koppelt de map via een snelkoppeling in `~/.cache/exe-handler/dos/`.
- Instellingen: `~/.config/exe-handler/dos.conf` (wordt bij de eerste DOS-start aangemaakt).

## Per programma aanpassen (optioneel)

| Bestand | Waar | Wat |
|---|---|---|
| `exe-handler.start` | naast de .exe | regels `Game.exe = Loader.exe [opties]`: start de loader (met opties) als je Game.exe opent; `{screen}` wordt de resolutie van je hoofdscherm, bv. `StarTopia.exe = StarTopia.exe /r{screen}x32` |
| `exe-handler.reg` | naast de .exe | registerbestand dat vóór elke start wordt ingelezen |
| `exe-handler.no-ddraw` | naast de .exe | leeg bestand: geen cnc-ddraw voor dit spel |
| `virtual-desktop.conf` | `~/.config/exe-handler/` | `spel.exe 1024x768`: in een eigen Wine-bureaublad van precies die grootte. Alleen nodig als een spel het zonder niet doet; zonder schalen klopt de muis (Red Alert 2 heeft het niet meer nodig: dat gaat via cnc-ddraw) |
| `exe-handler.no-dxvk` | naast de .exe | leeg bestand: nooit DXVK voor dit spel |
| `dxvk.conf` | `~/.config/exe-handler/` | `spel.exe` per regel: altijd DXVK, ook voor Direct3D 8/9 op een GPU die het niet aankan |
| `no-dxvk.conf` | `~/.config/exe-handler/` | `spel.exe` per regel: nooit DXVK, Wine's eigen Direct3D |
| `x11.conf` | `~/.config/exe-handler/` | `spel.exe` per regel: op een Wayland-bureaublad toch Wine's X11-weergave gebruiken (muis in sommige spellen) |
| `dos.conf` | `~/.config/exe-handler/` | DOSBox-X-instellingen |

Logboek: `~/.cache/exe-handler.log`. Werkt iets niet zoals verwacht, dan laat `exe-handler --check bestand.exe`
zien wat exe-handler ermee zou doen (type, Visual Basic, schermgrootte, eigen venster, en of dubbelklikken echt
via exe-handler gaat). Handmatig: `exe-handler [--dos|--wine] bestand.exe [argumenten]`.

## Bijwerken

`./install.sh --update` (of opnieuw het `curl … | bash`-commando) haalt de nieuwste versie van GitHub en
installeert die. Wat er al staat en actueel is, wordt overgeslagen; nieuwe onderdelen (bijvoorbeeld DXVK) en
nieuwere versies van DXVK, cnc-ddraw, otvdm of Wine komen erbij. Je instellingen en `~/.wine` blijven zoals ze zijn.

## Verwijderen

`./uninstall.sh` haalt exe-handler, de bestandskoppelingen, de kernelregel en het klaarzetten bij het inloggen
weg. Wine, DOSBox-X, Box64 en `~/.wine` blijven staan.

## Getest

- **Schone installatie in containers** (arm64 op een Raspberry Pi 5): Debian 13 en Ubuntu 24.04, met één
  `./install.sh --yes`. Getest: DOS (Commander Keen, ook via een `.bat`), 16-bit Windows (Stars!), 16-bit Visual
  Basic met de runtime één map hoger (WinPac), 32-bit Visual Basic (Poker Broker), DirectDraw (Jazz Jackrabbit 2),
  de melding bij een ontbrekende DLL (Vortex zonder MFC30.DLL), Direct3D 9 (Cossacks) en 64-bit Direct3D 11 met
  DXVK (Guinea Pig Boulder Garden). Een tweede `install.sh` duurt 7 seconden en slaat alles over.
- **x86-64 Ubuntu 24.04 in een container** (via qemu-emulatie op de Pi): de installatie (Wine 9.0, cnc-ddraw,
  DXVK, Vulkan) slaagt; DOS, `.bat`, 16-bit (Stars!), Visual Basic (Poker Broker) en de melding bij een ontbrekende
  DLL werken. Zwaardere spellen lopen onder qemu vast op de beperkte adresruimte van de Pi en zijn daar niet te testen.
- **Raspberry Pi 5** (Raspberry Pi OS / Debian 13, labwc/Wayland) als bureaublad, met een lege thuismap (geen eigen
  instellingen, nieuwe Wine-map): 46 programma's, waaronder 20 Windows 3.1-spellen en installers van een
  shareware-cd (Flip'em via de gedeelde BWCC.DLL), Red Alert 2 en Yuri's Revenge (cnc-ddraw in plaats van
  DDrawCompat, muis klopt), Cossacks, Diablo II (1.10 met PlugY en 1.14d), StarTopia, Guinea Pig Boulder Garden
  (DXVK), Vortex (in een Wine-map geïnstalleerd), kaartspellen en de Phantasmagoria-installer. Eerder ook Red Alert 2
  tot en met een gespeelde skirmish.
- **Zorin OS 18** (x86-64) met Wine 10 en drie monitoren: DOS-spellen vanaf een netwerkshare (Aladdin), 16-bit
  Windows (Jixxa, Tinyjong, WinPac), Visual Basic (Poker Broker), DirectDraw (Jazz Jackrabbit 2), starten zonder
  haperen.

Bekende beperkingen: niet elk Windows-programma draait in Wine. Het passend maken van vensters werkt op X11 (ook via XWayland), niet voor Wine's eigen Wayland-vensters.

## English summary

`install.sh` sets up Linux (x86-64 or ARM64) so that double-clicking DOS and Windows programs just works.

- **Choice by file header**: DOSBox-X for DOS, Wine for Windows (on ARM64: Wine 11.4 x86-64 via Box64, otvdm for
  16-bit), `msiexec` for `.msi`, a terminal for console programs.
- **Integration**: file associations, right-click "Open in DOSBox / Wine", a binfmt_misc rule for executable
  `.exe` files, the Wine folder prepared in advance.
- **Windows programs**: normal window decorations and Alt+Tab; old DirectDraw games in a scaled, resizable window
  through cnc-ddraw (x86 and ARM64, also for launchers such as Red Alert 2's, replacing a crashing DDrawCompat) instead of a 320x200/640x480 mode switch; old Visual Basic programs in a fitted virtual
  desktop window (they overflow on screens wider than 2184 pixels); the wineserver stays on so that only the first
  program of a session can stutter on multi-monitor desktops (`--warmup-at-login` moves that to the login).
- **Missing DLLs**: when a program stops right away, exe-handler names the DLLs it imports that are neither next
  to it, nor in the Wine folder, nor built into Wine (e.g. MFC30.DLL, CNCS32.DLL from the Windows 95/98 era).
  16-bit programs get shared Windows 3.1 DLLs/VBX controls (BWCC.DLL, ...) from neighbouring folders; a program
  installed inside a Wine folder runs in that Wine folder; a Box64 crash right at the start is retried once.
- **Direct3D games**: DXVK (Vulkan) is chosen automatically from what the .exe and its own DLLs (UnityPlayer.dll)
  use: always for Direct3D 10/11, for Direct3D 8/9 only when the GPU runs DXVK. On GPUs without
  `multiDrawIndirect` (Raspberry Pi 5) it falls back to llvmpipe, Mesa's software Vulkan (slow). Override per game
  with `dxvk.conf`, `no-dxvk.conf` or an `exe-handler.no-dxvk` file.
- **DOS programs**: resizable window, F12+F fullscreen, mouse caught on click (Ctrl+F10 releases), speed chosen
  from the program's date, a sound font for General MIDI, folders on network shares mounted through a symlink.

Install everything with one command: `curl -fsSL https://raw.githubusercontent.com/davyschroeder/exe-handler/main/install.sh | bash`
(or `./install.sh` in a clone; `--dry-run` to preview). `./install.sh --update` installs the newest version from
GitHub including any new parts; uninstall with `./uninstall.sh`.

Third-party software that the installer downloads: [Wine](https://www.winehq.org) builds by
[Kron4ek](https://github.com/Kron4ek/Wine-Builds), [Box64](https://github.com/ptitSeb/box64) via
[Pi-Apps-Coders/box64-debs](https://github.com/Pi-Apps-Coders/box64-debs),
[otvdm/winevdm](https://github.com/otya128/winevdm), [cnc-ddraw](https://github.com/FunkyFr3sh/cnc-ddraw),
[DXVK](https://github.com/doitsujin/dxvk),
[DOSBox-X](https://dosbox-x.com).

## Licentie / License

MIT, zie / see [LICENSE](LICENSE).
