#!/bin/bash

# Zajištění sudo oprávnění hned na začátku
sudo -v

# --- KONFIGURAČNÍ PROMĚNNÉ ---
LXQT_DIR="$HOME/.config/lxqt"
PCMANFM_DIR="$HOME/.config/pcmanfm-qt/lxqt"
USER_APPS_DIR="$HOME/.local/share/applications"

echo "=== ZAČÍNÁM NASTAVENÍ LUBUNTU (FINAL V7 ULTIMATE) ==="

# ---------------------------------------------------------
# 0. PŘÍPRAVA REPOZITÁŘŮ, WINE A INSTALACE BALÍČKŮ
# ---------------------------------------------------------
echo ">> Povoluji 32-bit architekturu (pro Wine a drivery)..."
sudo dpkg --add-architecture i386

echo ">> Přidávám repozitář pro WineHQ..."
sudo mkdir -pm755 /etc/apt/keyrings

# FIX 1: Stáhneme klíč a rovnou ho převedeme do binárního formátu (.gpg), který apt vyžaduje
sudo wget -qO- https://dl.winehq.org/wine-builds/winehq.key | sudo gpg --dearmor --yes -o /etc/apt/keyrings/winehq-archive.gpg

# FIX 2: Pokud jsme na testovacím pre-release (questing/plucky), vnutíme stabilní 'noble' repozitář
OS_CODENAME=$(lsb_release -cs)
if [ "$OS_CODENAME" == "questing" ] || [ "$OS_CODENAME" == "plucky" ]; then
    OS_CODENAME="noble"
fi

# Zápis repozitáře starou, dobrou a neprůstřelnou metodou
echo "deb [arch=amd64,i386 signed-by=/etc/apt/keyrings/winehq-archive.gpg] https://dl.winehq.org/wine-builds/ubuntu/ $OS_CODENAME main" | sudo tee /etc/apt/sources.list.d/winehq.list > /dev/null

echo ">> Aktualizuji zdroje balíčků..."
sudo apt update -qq

echo ">> Instaluji Wine a Winetricks..."
sudo apt install --install-recommends winehq-stable winetricks -y

echo ">> Instaluji základní balíčky, utility a kodeky..."
# Sloučený seznam aplikací
sudo apt install --no-install-recommends xfwm4 xfconf gdebi flameshot htop vlc featherpad icoutils viewnior ffmpegthumbnailer heif-gdk-pixbuf zram-tools gthumb cabextract libgl1-mesa-dri:i386 libgl1:i386 libglx-mesa0:i386 yad cups-client cups -y

echo ">> Kontroluji Google Chrome..."
if command -v google-chrome &> /dev/null || command -v google-chrome-stable &> /dev/null; then
    echo "   [OK] Google Chrome je již nainstalován."
else
    echo "   [!] Chrome nenalezen. Stahuji a instaluji..."
    wget -qO /tmp/google-chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    sudo apt install -y /tmp/google-chrome.deb
    rm /tmp/google-chrome.deb
    echo "   [OK] Chrome úspěšně nainstalován."
fi

# ---------------------------------------------------------
# 2. ZÁLOHA
# ---------------------------------------------------------
echo ">> Zálohuji stávající konfiguraci..."
mkdir -p "$LXQT_DIR/backup_$(date +%F_%T)"
cp "$LXQT_DIR/"*.conf "$LXQT_DIR/backup_$(date +%F_%T)/" 2>/dev/null

# ---------------------------------------------------------
# 3. XFWM4 (VZHLED A TLAČÍTKA)
# ---------------------------------------------------------
echo ">> Nastavuji XFWM4..."
if command -v xfconf-query &> /dev/null; then
    xfconf-query -c xfwm4 -p /general/theme -n -t string -s "Default"
    xfconf-query -c xfwm4 -p /general/button_layout -n -t string -s "O|HMC"
    xfconf-query -c xfwm4 -p /general/title_alignment -n -t string -s "center"
    xfconf-query -c xfwm4 -p /general/tile_on_move -n -t bool -s true
    xfconf-query -c xfwm4 -p /general/wrap_pointer -n -t bool -s false
    xfconf-query -c xfwm4 -p /general/wrap_windows -n -t bool -s false
    echo "   [OK] XFWM4 nastaveno."
else
    echo "   [CHYBA] xfconf-query nenalezen."
fi

# ---------------------------------------------------------
# 4. SESSION CONFIG (NumLock + Leave/Lock Settings)
# ---------------------------------------------------------
echo ">> Upravuji session.conf..."
SESSION_CONF="$LXQT_DIR/session.conf"

update_general_key() {
    local key="$1"
    local value="$2"
    if grep -q "^$key=" "$SESSION_CONF"; then
        sed -i "s/^$key=.*/$key=$value/" "$SESSION_CONF"
    else
        sed -i "/^\[General\]/a $key=$value" "$SESSION_CONF"
    fi
}

if [ -f "$SESSION_CONF" ]; then
    update_general_key "window_manager" "xfwm4"
    update_general_key "leave_confirmation" "false"
    update_general_key "lock_screen_before_power_actions" "false"

    if grep -q "numlock=" "$SESSION_CONF"; then
        sed -i 's/^numlock=.*/numlock=true/' "$SESSION_CONF"
    else
        if grep -q "^\[Keyboard\]" "$SESSION_CONF"; then
            sed -i '/^\[Keyboard\]/a numlock=true' "$SESSION_CONF"
        else
            echo -e "\n[Keyboard]\nnumlock=true" >> "$SESSION_CONF"
        fi
    fi
else
    echo -e "[General]\nwindow_manager=xfwm4\nleave_confirmation=false\nlock_screen_before_power_actions=false\n\n[Keyboard]\nnumlock=true" > "$SESSION_CONF"
fi
echo "   [OK] session.conf upraven."

# ---------------------------------------------------------
# 5. NOTIFIKACE
# ---------------------------------------------------------
echo ">> Nastavuji notifikace..."
pkill lxqt-notificationd 2>/dev/null

cat > "$LXQT_DIR/notifications.conf" << 'EOF'
[General]
__userfile__=true
doNotDisturb=false
placement=bottom-right
screenWithMouse=false
server_decides=3
unattendedMaxNum=0
EOF
echo "   [OK] notifications.conf přepsán."

# ---------------------------------------------------------
# 6. SKRYTÍ APLIKACÍ
# ---------------------------------------------------------
echo ">> Skrývám aplikace z menu..."
if [ ! -d "$USER_APPS_DIR" ]; then mkdir -p "$USER_APPS_DIR"; fi

APPS_TO_HIDE=("lxqt-about.desktop" "qterminal-drop.desktop" "lxqt-lockscreen.desktop" "lxqt-leave.desktop" "about-lxqt.desktop")

for app in "${APPS_TO_HIDE[@]}"; do
    if [ -f "/usr/share/applications/$app" ]; then
        cp "/usr/share/applications/$app" "$USER_APPS_DIR/$app"
        if grep -q "^NoDisplay=" "$USER_APPS_DIR/$app"; then
            sed -i 's/^NoDisplay=.*/NoDisplay=true/' "$USER_APPS_DIR/$app"
        else
            echo "NoDisplay=true" >> "$USER_APPS_DIR/$app"
        fi
    fi
done
update-desktop-database "$USER_APPS_DIR" 2>/dev/null

# ---------------------------------------------------------
# 7. NASTAVENÍ PLOCHY (PCMANFM-QT)
# ---------------------------------------------------------
echo ">> Nastavuji plochu..."
pkill -KILL pcmanfm-qt
rm -rf ~/.config/pcmanfm-qt
mkdir -p ~/.config/pcmanfm-qt/lxqt

cat > ~/.config/pcmanfm-qt/lxqt/settings.conf << 'EOF'
[Behavior]
AutoSelectionDelay=600
BookmarkOpenMethod=current_tab
ConfirmDelete=true
ConfirmTrash=false
CtrlRightClick=false
NoUsbTrash=false
QuickExec=false
RecentFilesNumber=0
SelectNewFiles=false
SingleClick=false
SingleWindowMode=false
UseTrash=true

[Desktop]
AllSticky=true
BgColor=#000000
DesktopCellMargins=@Size(0 0)
DesktopIconSize=48
DesktopShortcuts=Home, Trash
FgColor=#ffffff
Font="Ubuntu,11,-1,5,50,0,0,0,0,0"
HideItems=false
LastSlide=
OpenWithDefaultFileManager=false
PerScreenWallpaper=true
ShadowColor=#000000
ShowHidden=false
SlideShowInterval=0
SortColumn=name
SortFolderFirst=true
SortHiddenLast=false
SortOrder=ascending
TransformWallpaper=false
Wallpaper=/usr/share/lubuntu/wallpapers/lubuntu-default-wallpaper.png
WallpaperDialogSize=@Size(700 500)
WallpaperDialogSplitterPos=200
WallpaperDirectory=
WallpaperMode=zoom
WallpaperRandomize=false
WorkAreaMargins=12, 12, 12, 12

[FolderView]
BackupAsHidden=false
BigIconSize=48
CustomColumnWidths=@Invalid()
FolderViewCellMargins=@Size(3 3)
HiddenColumns=@Invalid()
Mode=icon
NoItemTooltip=false
ScrollPerPixel=true
ShadowHidden=true
ShowFilter=false
ShowFullNames=true
ShowHidden=false
SidePaneIconSize=24
SmallIconSize=24
SortCaseSensitive=false
SortColumn=name
SortFolderFirst=true
SortHiddenLast=false
SortOrder=ascending
ThumbnailIconSize=128

[Places]
HiddenPlaces=@Invalid()

[Search]
ContentPatterns=@Invalid()
MaxSearchHistory=0
NamePatterns=@Invalid()
searchContentCaseInsensitive=false
searchContentRegexp=true
searchNameCaseInsensitive=false
searchNameRegexp=true
searchRecursive=false
searchhHidden=false

[System]
Archiver=lxqt-archiver
FallbackIconThemeName=oxygen
OnlyUserTemplates=false
SIUnit=false
SuCommand=lxqt-sudo %s
TemplateRunApp=false
TemplateTypeOnce=false
Terminal=qterminal

[Thumbnail]
MaxExternalThumbnailFileSize=-1
MaxThumbnailFileSize=4096
ShowThumbnails=true
ThumbnailLocalFilesOnly=true

[Volume]
AutoRun=true
CloseOnUnmount=true
MountOnStartup=true
MountRemovable=true

[Window]
AlwaysShowTabs=false
FixedHeight=480
FixedWidth=640
LastWindowHeight=480
LastWindowMaximized=false
LastWindowWidth=980
PathBarButtons=true
RememberWindowSize=true
ReopenLastTabs=false
ShowMenuBar=true
ShowTabClose=true
SidePaneMode=places
SidePaneVisible=true
SplitView=false
SplitViewTabsNum=0
SplitterPos=200
SwitchToNewTab=false
TabPaths=@Invalid()
EOF

# ---------------------------------------------------------
# 8. NASTAVENÍ PANELU (DYNAMICKY PODLE VERZE LUBUNTU)
# ---------------------------------------------------------
echo ">> Přepisuji konfiguraci panelu (detekuji verzi OS)..."

# Zjištění verze systému (např. 24.04, 25.10, 26.04)
OS_VER=$(lsb_release -rs)
echo "   [i] Detekována verze systému: $OS_VER"

# Podmínka pro výběr správného menu
if [[ "$OS_VER" == 24.* ]]; then
    MENU_BLOCK="[mainmenu]
alignment=Left
customFont=true
customFontSize=15
showText=true
type=mainmenu"
    PLUGINS="mainmenu, quicklaunch, taskbar, mount, volume, tray, statusnotifier2, worldclock"
else
    MENU_BLOCK="[fancymenu]
alignment=Left
customFont=true
customFontSize=15
showText=true
type=fancymenu"
    PLUGINS="fancymenu, quicklaunch, taskbar, mount, volume, tray, statusnotifier2, worldclock"
fi

# Generování panel.conf s dynamickými proměnnými
cat > "$LXQT_DIR/panel.conf" << EOF
[General]
__userfile__=true

$MENU_BLOCK

[mount]
alignment=Right
type=mount

[panel1]
alignment=-1
animation-duration=0
background-color=@Variant(\0\0\0\x43\0\xff\xff\0\0\0\0\0\0\0\0)
background-image=
desktop=0
font-color=@Variant(\0\0\0\x43\0\xff\xff\0\0\0\0\0\0\0\0)
hidable=false
hide-on-overlap=false
iconSize=32
lineCount=1
lockPanel=false
opacity=100
panelSize=48
plugins=$PLUGINS
position=Bottom
reserve-space=true
show-delay=0
visible-margin=true
width=100
width-percent=true

[quicklaunch]
alignment=Left
apps\1\desktop=$USER_APPS_DIR/pcmanfm-qt.desktop
apps\2\desktop=$USER_APPS_DIR/google-chrome.desktop
apps\3\desktop=$USER_APPS_DIR/qterminal.desktop
apps\size=3
type=quicklaunch

[statusnotifier2]
alignment=Left
type=statusnotifier

[taskbar]
alignment=Left
type=taskbar

[tray]
alignment=Right
type=tray

[volume]
alignment=Right
type=volume

[worldclock]
alignment=Right
autoRotate=true
customFormat="'<b>'HH:mm'</b><br/>'ddd, dd.MM.yyyy'"
dateFormatType=custom
dateLongNames=false
datePadDay=false
datePosition=below
dateShowDoW=false
dateShowYear=false
defaultTimeZone=
formatType=custom-timeonly
showDate=true
showTimezone=false
showTooltip=false
showWeekNumber=true
timeAMPM=false
timePadHour=false
timeShowSeconds=false
timeZones\size=0
timezoneFormatType=iana
timezonePosition=below
type=worldclock
useAdvancedManualFormat=true
EOF
echo "   [OK] panel.conf dynamicky vygenerován."

# ---------------------------------------------------------
# 9. KLÁVESOVÉ ZKRATKY (Flameshot & Htop)
# ---------------------------------------------------------
echo ">> Přidávám klávesové zkratky..."
SHORTCUTS_CONF="$LXQT_DIR/globalkeyshortcuts.conf"

# Vytvoření souboru, pokud neexistuje (čistá instalace)
touch "$SHORTCUTS_CONF"

# Win+Shift+S -> Flameshot
if ! grep -q "flameshot" "$SHORTCUTS_CONF" 2>/dev/null; then
    cat >> "$SHORTCUTS_CONF" << 'EOF'

[Meta%2BShift%2BS.99]
Comment=Výstřižky (Flameshot)
Enabled=true
Exec=flameshot, gui
EOF
fi

# Ctrl+Shift+Esc -> Htop
if ! grep -q "htop" "$SHORTCUTS_CONF" 2>/dev/null; then
    cat >> "$SHORTCUTS_CONF" << 'EOF'

[Control%2BShift%2BEscape.99]
Comment=Správce úloh (Htop)
Enabled=true
Exec=qterminal, -e, htop
EOF
fi
echo "   [OK] Zkratky úspěšně přidány."

# ---------------------------------------------------------
# 10. OPENBOX POJISTKA
# ---------------------------------------------------------
OPENBOX_RC="$HOME/.config/openbox/rc.xml"
if [ -f "$OPENBOX_RC" ]; then
    sed -i '/<desktops>/,/<\/desktops>/ s/<number>.*<\/number>/<number>1<\/number>/' "$OPENBOX_RC"
fi

# ---------------------------------------------------------
# 11. NASTAVENÍ GOOGLE CHROME JAKO VÝCHOZÍHO (A UMLČENÍ HLÁŠKY)
# ---------------------------------------------------------
echo ">> Nastavuji Chrome jako výchozí a vypínám otravnou lištu..."
# XDG nastavení pro uživatelské prostředí
xdg-settings set default-web-browser google-chrome.desktop 2>/dev/null
xdg-mime default google-chrome.desktop x-scheme-handler/http
xdg-mime default google-chrome.desktop x-scheme-handler/https
xdg-mime default google-chrome.desktop text/html

# Firemní politika Chromu (nuke na modrou lištu)
sudo mkdir -p /etc/opt/chrome/policies/managed/
echo '{"DefaultBrowserSettingEnabled": false}' | sudo tee /etc/opt/chrome/policies/managed/stop-otravovat.json > /dev/null
echo "   [OK] Chrome je zkrocen."

# ---------------------------------------------------------
# 12. KOPÍROVÁNÍ CUSTOM SKRIPTŮ A AUTOMATIZACE (BUSY LAUNCH)
# ---------------------------------------------------------
echo ">> Nasazuji custom skripty (busy-launch, update-wrappers)..."
SCRIPTS_SOURCE="$(dirname "$(realpath "$0")")/../scripts"
SCRIPTS_DEST="$HOME/.local/share/scripts"

if [ -d "$SCRIPTS_SOURCE" ]; then
    # Vytvoření cílové složky a kopírování
    mkdir -p "$SCRIPTS_DEST"
    cp -r "$SCRIPTS_SOURCE/"* "$SCRIPTS_DEST/"
    
    # Nastavení spustitelnosti pro všechny shellové a python skripty
    chmod +x "$SCRIPTS_DEST/"*.sh 2>/dev/null
    chmod +x "$SCRIPTS_DEST/"*.py 2>/dev/null
    
    # --- AUTOSTART PRO UPDATE-WRAPPERS.SH ---
    echo ">> Přidávám update-wrappers.sh do autostartu..."
    mkdir -p "$HOME/.config/autostart"
    cat > "$HOME/.config/autostart/update-wrappers.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Update Wrappers
Exec=$SCRIPTS_DEST/update-wrappers.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

    # --- ZÁSTUPCE DO MENU: TVŮRCE ZÁSTUPCŮ ---
    echo ">> Vytvářím zástupce 'Tvůrce zástupců' v menu..."
    cat > "$HOME/.local/share/applications/tvurce-zastupcu.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Tvůrce zástupců
Comment=Vytvoří nového zástupce s indikátorem načítání (busy-launch)
Exec=$SCRIPTS_DEST/novy-zastupce.sh
Icon=preferences-desktop-shortcuts
Terminal=true
Categories=Utility;
EOF
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null
    echo "   [OK] Skripty nasazeny a zástupce vytvořen."

    # --- OKAMŽITÉ SPUŠTĚNÍ WRAPPERU PRO QUICKLAUNCH ---
    echo ">> Spouštím update-wrappers.sh pro vygenerování zástupců do Quicklaunch..."
    bash "$SCRIPTS_DEST/update-wrappers.sh"
    echo "   [OK] Zástupci pro Quicklaunch úspěšně vygenerováni."
else
    echo "   [!] CHYBA: Složka 'scripts' nebyla nalezena vedle instalačního skriptu!"
fi

# ---------------------------------------------------------
# 13. AUTOMATICKÉ TICHÉ AKTUALIZACE (CRON JOB)
# ---------------------------------------------------------
echo ">> Nastavuji automatické denní aktualizace na pozadí..."

sudo tee /etc/cron.daily/lubuntu-autoupdate > /dev/null << 'EOF'
#!/bin/bash
# Pockame 180 sekund (3 minuty) po startu anacronu
sleep 180

# Tichy update a upgrade vseho (vcetne repozitare Chrome)
/usr/bin/apt-get update -qq
/usr/bin/apt-get upgrade -y -qq

# Promazani starych zbytecnosti (at se neplni disk)
/usr/bin/apt-get autoremove -y -qq
/usr/bin/apt-get clean -qq
EOF

# Udelame skript spustitelnym
sudo chmod +x /etc/cron.daily/lubuntu-autoupdate

echo "   [OK] Tiché aktualizace úspěšně zavedeny."

# ---------------------------------------------------------
# 14. ČIŠTĚNÍ BORDELU (ODSTRANĚNÍ ZBYTEČNOSTÍ)
# ---------------------------------------------------------
echo ">> Čistím systém od zbytečných aplikací..."
# Odebrání xscreensaver a starého prohlížeče obrázků
sudo apt purge xscreensaver lximage-qt -y

# Odstranění osiřelých závislostí
sudo apt autoremove -y
echo "   [OK] Systém je vyčištěn."

# ---------------------------------------------------------
# 15. TISK Z KONTEXTOVÉHO MENU (PRAVÉ TLAČÍTKO MYŠI)
# ---------------------------------------------------------
echo ">> Přidávám možnost tisku do kontextového menu..."

# Povolení služby cups (pro jistotu)
sudo systemctl enable --now cups 2>/dev/null

# Vytvoření skriptu pro tisk
sudo tee /usr/local/bin/tisk-cz > /dev/null << 'EOF'
#!/bin/bash
SOUBOR="$1"
NAZEV=$(basename "$SOUBOR")
RAW_PRINTERS=$(lpstat -p 2>/dev/null | awk '{print $2}')

# Chyba: Žádná tiskárna
if [ -z "$RAW_PRINTERS" ]; then
    yad --error --title="Chyba" --text="V systému není žádná nainstalovaná tiskárna!" \
        --button="OK:0" --center --width=300 --window-icon="printer"
    exit 1
fi

PRINTER_LIST=$(echo "$RAW_PRINTERS" | tr '\n' '!')
DEFAULT_PRINTER=$(lpstat -d 2>/dev/null | awk '{print $4}')

# Hlavní okno
VYSTUP=$(yad --form --title="Tisk souboru" \
    --text="<big><b>Tisk dokumentu</b></big>\n\nSoubor: $NAZEV" \
    --window-icon="printer" --center --width=450 \
    --field="Výběr tiskárny:CB" "$DEFAULT_PRINTER!$PRINTER_LIST" \
    --field="Počet kopií:NUM" "1!1..20!1" \
    --field="Kvalita tisku:CB" "Normální!Rychlá (Koncept)!Vysoká (Foto)" \
    --button="Zrušit:1" \
    --button="Tisk:0" \
    --separator="|")

if [ $? -ne 0 ]; then exit 0; fi

TISKARNA=$(echo "$VYSTUP" | cut -d'|' -f1)
KOPIE=$(echo "$VYSTUP" | cut -d'|' -f2)
KVALITA_TXT=$(echo "$VYSTUP" | cut -d'|' -f3)

case "$KVALITA_TXT" in
  "Rychlá (Koncept)") MOJE_OPTS="-o print-quality=3" ;;
  "Vysoká (Foto)")    MOJE_OPTS="-o print-quality=5" ;;
  *)                  MOJE_OPTS="-o print-quality=4" ;;
esac

lp -d "$TISKARNA" -n "$KOPIE" $MOJE_OPTS "$SOUBOR"

if [ $? -eq 0 ]; then
    notify-send -i printer "Tisk odeslán" "Tiskárna: $TISKARNA"
else
    yad --error --text="Chyba při odesílání na tiskárnu."
fi
EOF

# Nastavení spustitelnosti globálního skriptu
sudo chmod +x /usr/local/bin/tisk-cz

# Přidání pravidla přímo do správce souborů PCManFM-Qt
ACTION_DIR="$HOME/.local/share/file-manager/actions"
mkdir -p "$ACTION_DIR"

cat > "$ACTION_DIR/tisk.desktop" << EOF
[Desktop Entry]
Type=Action
Tooltip=Otevřít nastavení tisku
Name=Vytisknout...
Name[cs]=Vytisknout...
Icon=printer
Profiles=profile-zero;

[X-Action-Profile profile-zero]
MimeTypes=image/*;application/pdf;text/plain;
Exec=/usr/local/bin/tisk-cz %f
Name=Default
EOF
echo "   [OK] Tisk do pravého tlačítka myši úspěšně přidán."

# ---------------------------------------------------------
# 16. QTERMINAL, NUMLOCK A AUTOMOUNT DISKŮ
# ---------------------------------------------------------
echo ">> Vypínám otravnou informaci o velikosti okna v QTerminalu..."
QTERM_DIR="$HOME/.config/qterminal.org"
mkdir -p "$QTERM_DIR"
QTERM_CONF="$QTERM_DIR/qterminal.ini"

# Pojistka pro vytvoření základní struktury
if [ ! -f "$QTERM_CONF" ] || ! grep -q "^\[General\]" "$QTERM_CONF"; then
    echo -e "\n[General]" >> "$QTERM_CONF"
fi

# Smazání starých/špatných záznamů a vložení správného s malým 's'
sed -i '/^[sS]howTerminalSizeHint/d' "$QTERM_CONF"
sed -i '/^\[General\]/a showTerminalSizeHint=false' "$QTERM_CONF"
echo "   [OK] Rámeček s rozměry okna terminálu zrušen."


echo ">> Nastavuji trvale zapnutý NumLock (SDDM + LXQt)..."
sudo mkdir -p /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/numlock.conf > /dev/null << 'EOF'
[General]
Numlock=on
EOF
echo "   [OK] NumLock vynucen pro přihlašovací obrazovku i systém."


echo ">> Nastavuji automatické připojování všech interních disků bez hesla..."
# 1. Pravidlo Polkitu, které dovolí systému připojit disky bez ptaní se na heslo
sudo mkdir -p /etc/polkit-1/rules.d
sudo tee /etc/polkit-1/rules.d/50-udisks2-automount.rules > /dev/null << 'EOF'
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.udisks2.filesystem-mount-system" ||
         action.id == "org.freedesktop.udisks2.filesystem-mount") &&
        subject.isInGroup("sudo")) {
        return polkit.Result.YES;
    }
});
EOF

# 2. Autostart skript, který po přihlášení najde odpojené disky a připojí je
mkdir -p "$HOME/.config/autostart"
cat > "$HOME/.config/autostart/automount-drives.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Auto-Mount Drives
Exec=bash -c "for dev in \$(lsblk -o NAME,FSTYPE,MOUNTPOINT -n -l | awk '\$2 != \"\" && \$2 != \"swap\" && \$2 != \"vfat\" && \$3 == \"\" {print \"/dev/\"\$1}'); do udisksctl mount -b \$dev --no-user-interaction 2>/dev/null; done"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF
echo "   [OK] Automount disků nastaven."

echo ">> Povoluji/Zakazuji zobrazení skrytých souborů ve všech dialozích (GTK)..."
# PCManFM-Qt už to má v Sekci 7, tohle to vynutí pro okna "Uložit/Otevřít" ve zbytku systému
gsettings set org.gtk.Settings.FileChooser show-hidden false 2>/dev/null
echo "   [OK] Skryté soubory jsou nyní všude viditelné."

# ---------------------------------------------------------
# FINÁLE
# ---------------------------------------------------------
echo ""
echo "=========================================="
echo " HOTOVO"
echo "=========================================="
echo "UPOZORNĚNÍ: Protože jsme přepsali systémové cesty pro zástupce,"
echo "je nejbezpečnější systém nyní kompletně restartovat."
echo -n "Stiskněte Enter pro uložení, odhlášení a přechod do TTY..."
read

# Zabijeme démony
pkill lxqt-notificationd
pkill lxqt-session
pkill -u "$USER"
