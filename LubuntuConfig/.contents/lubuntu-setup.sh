#!/bin/bash

# Zajištění sudo oprávnění hned na začátku
sudo -v

# --- ABSOLUTNÍ CESTY K TVÝM SLOŽKÁM ---
BASE_DIR="$(dirname "$(realpath "$0")")" # Ukazuje do složky .contents
ROOT_DIR="$(dirname "$BASE_DIR")"        # Ukazuje o úroveň výš (hlavní složka)
CONFIG_DIR="$BASE_DIR/.config"
SCRIPTS_DIR="$BASE_DIR/.scripts"

# --- SYSTÉMOVÉ PROMĚNNÉ ---
LXQT_DIR="$HOME/.config/lxqt"
PCMANFM_DIR="$HOME/.config/pcmanfm-qt/lxqt"
USER_APPS_DIR="$HOME/.local/share/applications"
LOCAL_BIN="$HOME/.local/bin"

# --- NAČTENÍ KONFIGURACE Z TEXTÁKU ---
CONFIG_TXT="$ROOT_DIR/setup-config.txt"

if [ -f "$CONFIG_TXT" ]; then
    echo ">> Načítám seznamy balíčků a nastavení z $CONFIG_TXT..."
    BALICKY=$(sed -n '/^\[INSTALL\]/,/^\[/p' "$CONFIG_TXT" | grep -v '^\[.*\]' | grep -vE '^\s*#|^\s*$' | xargs)
    SMRTIHLAV=$(sed -n '/^\[REMOVE\]/,/^\[/p' "$CONFIG_TXT" | grep -v '^\[.*\]' | grep -vE '^\s*#|^\s*$' | xargs)
    BROWSER_URL=$(sed -n '/^\[SETTINGS\]/,/^\[/p' "$CONFIG_TXT" | grep '^BROWSER_URL=' | cut -d'=' -f2-)
    
    # Načtení pole pro aplikace ke skrytí
    APPS_TO_HIDE_STR=$(sed -n '/^\[HIDE\]/,/^\[/p' "$CONFIG_TXT" | grep -v '^\[.*\]' | grep -vE '^\s*#|^\s*$' | xargs)
    read -r -a APPS_TO_HIDE <<< "$APPS_TO_HIDE_STR"
else
    echo "[!] VAROVÁNÍ: Soubor $CONFIG_TXT nebyl nalezen! Použiji záložní (hardcoded) hodnoty."
    BALICKY="xfwm4 xfconf gdebi flameshot htop vlc featherpad icoutils viewnior ffmpegthumbnailer heif-gdk-pixbuf zram-tools gthumb cabextract libgl1-mesa-dri:i386 libgl1:i386 libglx-mesa0:i386 yad cups-client cups brightnessctl libnotify-bin copyq"
    SMRTIHLAV="xscreensaver lximage-qt qlipper imagemagick vim yad"
    APPS_TO_HIDE=("lxqt-about.desktop" "qterminal-drop.desktop" "lxqt-lockscreen.desktop" "lxqt-leave.desktop")
fi

if [ -z "$BROWSER_URL" ]; then
    BROWSER_URL="https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
fi
# Pojistka pro prázdné HIDE (kdyby sekce v texťáku chyběla)
if [ ${#APPS_TO_HIDE[@]} -eq 0 ]; then
    APPS_TO_HIDE=("lxqt-about.desktop" "qterminal-drop.desktop" "lxqt-lockscreen.desktop" "lxqt-leave.desktop")
fi

echo "=== ZAČÍNÁM NASTAVENÍ LUBUNTU (FINAL V8 ULTIMATE) ==="

# ---------------------------------------------------------
# 1. PŘÍPRAVA REPOZITÁŘŮ A INSTALACE
# ---------------------------------------------------------
echo ">> Čistím staré Wine stopy..."
sudo rm -f /etc/apt/keyrings/winehq-archive.key
sudo rm -f /etc/apt/keyrings/winehq-archive.gpg
sudo rm -f /etc/apt/sources.list.d/winehq*.sources
sudo rm -f /etc/apt/sources.list.d/winehq.list

echo ">> Přidávám repozitář pro WineHQ a instaluji aplikace..."
sudo dpkg --add-architecture i386
sudo mkdir -pm755 /etc/apt/keyrings
sudo wget -qO- https://dl.winehq.org/wine-builds/winehq.key | sudo gpg --dearmor --yes -o /etc/apt/keyrings/winehq-archive.gpg

OS_CODENAME=$(lsb_release -cs)
if [ "$OS_CODENAME" == "questing" ] || [ "$OS_CODENAME" == "plucky" ]; then OS_CODENAME="noble"; fi

echo "deb [arch=amd64,i386 signed-by=/etc/apt/keyrings/winehq-archive.gpg] https://dl.winehq.org/wine-builds/ubuntu/ $OS_CODENAME main" | sudo tee /etc/apt/sources.list.d/winehq.list > /dev/null

sudo apt update -qq
sudo apt install --install-recommends winehq-stable winetricks -y

for balicek in $BALICKY; do
    echo "--> Probíhá instalace: $balicek"
    sudo apt install --no-install-recommends "$balicek" -y || echo "[!] CHYBA: Přeskakuji $balicek..."
done

echo ">> Instaluji webový prohlížeč..."
if [ -n "$BROWSER_URL" ]; then
    wget -qO /tmp/browser.deb "$BROWSER_URL"
    sudo apt install -y /tmp/browser.deb
    rm /tmp/browser.deb
else
    echo "!! CHYBA: BROWSER_URL je prázdné, instalace prohlížeče přeskočena."
fi

# ---------------------------------------------------------
# 2. ČIŠTĚNÍ BORDELU
# ---------------------------------------------------------
echo ">> Čistím systém od zbytečných aplikací..."
for balicek in $SMRTIHLAV; do
    sudo apt purge "$balicek" -y || true
done
sudo apt autoremove --purge -y
sudo apt clean
echo "   [OK] Systém je vyčištěn od všeho balastu."

# ---------------------------------------------------------
# 3. ZÁLOHA A APLIKACE TVÝCH .CONFIG SOUBORŮ
# ---------------------------------------------------------
echo ">> Zálohuji stávající konfiguraci..."
mkdir -p "$LXQT_DIR/backup_$(date +%F_%T)"
cp "$LXQT_DIR/"*.conf "$LXQT_DIR/backup_$(date +%F_%T)/" 2>/dev/null

echo ">> Nasazuji čisté konfigurační soubory z .config..."

pkill lxqt-notificationd 2>/dev/null
cp "$CONFIG_DIR/notifications.conf" "$LXQT_DIR/notifications.conf"

echo ">> Aplikuji nastavení plochy..."

# 1. Zkopírujeme tvoje nové nastavení rovnou za běhu (přepíšeme mu ho pod rukama)
rm -rf "$PCMANFM_DIR"
mkdir -p "$PCMANFM_DIR"
cp "$CONFIG_DIR/pcmanfm-qt.conf" "$PCMANFM_DIR/settings.conf"

# 2. FATALITY: Zastřelíme ho signálem 9 (SIGKILL). Nestihne si uložit tu starou paměť na disk.
killall -9 pcmanfm-qt 2>/dev/null

# 3. Systém (lxqt-session) si všimne, že pcmanfm-qt umřel a okamžitě ho spustí znovu.
# My jen počkáme 1 vteřinu, aby to stihl udělat z toho našeho nového souboru.
sleep 1

# 4. Kdyby se náhodou nenastartoval sám, nakopneme ho ručně na pozadí
pgrep pcmanfm-qt >/dev/null || (pcmanfm-qt --desktop --show-desktop & disown)

echo ">> Nastavení plochy nahráno a aplikováno."

OS_VER=$(lsb_release -rs)
if [[ "$OS_VER" == 24.* ]]; then
    cp "$CONFIG_DIR/panel-24.conf" "$LXQT_DIR/panel.conf"
else
    cp "$CONFIG_DIR/panel-26.conf" "$LXQT_DIR/panel.conf"
fi

# Zkopírování tvého vlastního session.conf
cp "$CONFIG_DIR/session.conf" "$LXQT_DIR/session.conf" 2>/dev/null

echo "   [OK] Konfigurační soubory úspěšně přepsány."

# ---------------------------------------------------------
# 4. KOPÍROVÁNÍ VLASTNÍCH SKRIPTŮ Z .SCRIPTS
# ---------------------------------------------------------
echo ">> Nasazuji utilitky ze složky .scripts do systému..."

mkdir -p "$LOCAL_BIN"
cp -u "$SCRIPTS_DIR/"*.sh "$LOCAL_BIN/" 2>/dev/null
cp -u "$SCRIPTS_DIR/"*.py "$LOCAL_BIN/" 2>/dev/null
chmod +x "$LOCAL_BIN/"* 2>/dev/null

sudo cp "$SCRIPTS_DIR/print-in-menu.sh" /usr/local/bin/tisk-cz
sudo chmod +x /usr/local/bin/tisk-cz

sudo cp "$SCRIPTS_DIR/lubuntu-autoupdate.sh" /etc/cron.daily/lubuntu-autoupdate
sudo chmod +x /etc/cron.daily/lubuntu-autoupdate

echo "   [OK] Skripty rozdistribuovány."

# ---------------------------------------------------------
# 5. SKRYTÍ APLIKACÍ Z MENU
# ---------------------------------------------------------
echo ">> Skrývám aplikace z menu..."
if [ ! -d "$USER_APPS_DIR" ]; then mkdir -p "$USER_APPS_DIR"; fi

# Smyčka projede všechny .desktop soubory načtené z texťáku
for app in "${APPS_TO_HIDE[@]}"; do
    if [ -f "/usr/share/applications/$app" ]; then
        cp "/usr/share/applications/$app" "$USER_APPS_DIR/$app"
        if grep -q "^NoDisplay=" "$USER_APPS_DIR/$app"; then
            sed -i 's/^NoDisplay=.*/NoDisplay=true/' "$USER_APPS_DIR/$app"
        else
            echo "NoDisplay=true" >> "$USER_APPS_DIR/$app"
        fi
        echo "   [OK] Skryto: $app"
    else
        # Tohle tě ochrání před pádem – pokud se spleteš v názvu, jen to hodí info a jede se dál
        echo "   [-] Přeskakuji: $app (nenalezeno v /usr/share/applications/)"
    fi
done

update-desktop-database "$USER_APPS_DIR" 2>/dev/null
echo "   [OK] Aplikace úspěšně skryty."

# ---------------------------------------------------------
# 5. KLÁVESOVÉ ZKRATKY A JAS
# ---------------------------------------------------------
echo ">> Přidávám klávesové zkratky..."
SHORTCUTS_CONF="$LXQT_DIR/globalkeyshortcuts.conf"
touch "$SHORTCUTS_CONF"

if [ ! -s "$SHORTCUTS_CONF" ]; then
    cp /usr/share/lxqt/globalkeyshortcuts.conf "$SHORTCUTS_CONF" 2>/dev/null
fi

if ! grep -q "flameshot" "$SHORTCUTS_CONF" 2>/dev/null; then
    cat >> "$SHORTCUTS_CONF" << 'EOF'

[Meta%2BShift%2BS.99]
Comment=Výstřižky (Flameshot)
Enabled=true
Exec=flameshot, gui
EOF
fi

if ! grep -q "htop" "$SHORTCUTS_CONF" 2>/dev/null; then
    cat >> "$SHORTCUTS_CONF" << 'EOF'

[Control%2BShift%2BEscape.99]
Comment=Správce úloh (Htop)
Enabled=true
Exec=qterminal, -e, htop
EOF
fi

if ! grep -q "copyq show" "$SHORTCUTS_CONF" 2>/dev/null; then
    cat >> "$SHORTCUTS_CONF" << 'EOF'

[Meta%2BV.99]
Comment=CopyQ show
Enabled=true
Exec=copyq, show
EOF
fi

echo ">> Přepisuji nativní ovládání jasu na custom skript..."
sed -i 's/lxqt-config-brightness/brightness.sh/g' "$SHORTCUTS_CONF"
sudo chmod +s $(which brightnessctl)
sudo usermod -aG video $USER
echo "   [OK] Zkratky a jas nastaveny."

# ---------------------------------------------------------
# 6. QTERMINAL, NUMLOCK A AUTOMOUNT DISKŮ
# ---------------------------------------------------------
echo ">> Vypínám otravnou informaci o velikosti okna v QTerminalu..."
QTERM_DIR="$HOME/.config/qterminal.org"
mkdir -p "$QTERM_DIR"
QTERM_CONF="$QTERM_DIR/qterminal.ini"

if [ ! -f "$QTERM_CONF" ] || ! grep -q "^\[General\]" "$QTERM_CONF"; then
    echo -e "\n[General]" >> "$QTERM_CONF"
fi

sed -i '/^[sS]howTerminalSizeHint/d' "$QTERM_CONF"
sed -i '/^\[General\]/a showTerminalSizeHint=false' "$QTERM_CONF"

echo ">> Nastavuji trvale zapnutý NumLock (SDDM)..."
sudo mkdir -p /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/numlock.conf > /dev/null << 'EOF'
[General]
Numlock=on
EOF

echo ">> Nastavuji automatické připojování všech interních disků bez hesla..."
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

echo ">> Povoluji zobrazení skrytých souborů ve všech dialozích (GTK)..."
gsettings set org.gtk.Settings.FileChooser show-hidden false 2>/dev/null
echo "   [OK] Různá nastavení prostředí dokončena."

# ---------------------------------------------------------
# 7. XFWM4 
# ---------------------------------------------------------
echo ">> Nastavuji XFWM4..."
SESSION_CONF="$LXQT_DIR/session.conf"
if [ ! -f "$SESSION_CONF" ]; then
    echo -e "[General]\nwindow_manager=xfwm4" > "$SESSION_CONF"
else
    sed -i 's/^window_manager=.*/window_manager=xfwm4/' "$SESSION_CONF"
fi

if command -v xfconf-query &> /dev/null; then
    xfconf-query -c xfwm4 -p /general/theme -n -t string -s "Default"
    xfconf-query -c xfwm4 -p /general/button_layout -n -t string -s "O|HMC"
    xfconf-query -c xfwm4 -p /general/title_alignment -n -t string -s "center"
    xfconf-query -c xfwm4 -p /general/tile_on_move -n -t bool -s true
    xfconf-query -c xfwm4 -p /general/wrap_pointer -n -t bool -s false
    xfconf-query -c xfwm4 -p /general/wrap_windows -n -t bool -s false
fi

# ---------------------------------------------------------
# 8. PRAVIDLA PRO TOUCHPAD
# ---------------------------------------------------------

echo ">> 1. Nastavuji globální pravidla touchpadu (X11)..."
sudo mkdir -p /etc/X11/xorg.conf.d
# Vynucení clickfinger (zákaz rohů) pro všechny touchpady
sudo tee /etc/X11/xorg.conf.d/40-libinput-touchpad.conf > /dev/null << 'EOF'
Section "InputClass"
    Identifier "libinput touchpad catchall"
    MatchIsTouchpad "on"
    Driver "libinput"
    Option "ClickMethod" "clickfinger"
    Option "Tapping" "on"
EndSection
EOF

echo ">> 2. Detekuji touchpad a zapisuji výchozí hodnoty pro LXQt GUI..."
# Získání názvu touchpadu
TOUCHPAD_NAME=$(xinput list --name-only | grep -i "touchpad" | head -n 1)

if [ -n "$TOUCHPAD_NAME" ]; then
    echo "Nalezen touchpad pro GUI: $TOUCHPAD_NAME"
    
    # LXQt (QSettings) kóduje mezery jako %2520 a lomítka jako %252F
    FORMATTED_NAME=$(echo "$TOUCHPAD_NAME" | sed 's/\//%252F/g; s/ /%2520/g')
    
    LXQT_CONF="$HOME/.config/lxqt/session.conf"
    mkdir -p "$(dirname "$LXQT_CONF")"
    touch "$LXQT_CONF"

    # Pokud sekce [Touchpad] neexistuje, přidáme ji
    if ! grep -q "^\[Touchpad\]" "$LXQT_CONF"; then
        echo "" >> "$LXQT_CONF"
        echo "[Touchpad]" >> "$LXQT_CONF"
    fi

    # Zápis předvyplněných hodnot do session.conf (dvojité zpětné lomítko je kvůli bash echo escape)
    # Tyto hodnoty si načte GUI a uživatel je může dál měnit
    echo "${FORMATTED_NAME}\\naturalScrollingEnabled=1" >> "$LXQT_CONF"
    echo "${FORMATTED_NAME}\\tappingEnabled=1" >> "$LXQT_CONF"
    
    echo "Výchozí GUI hodnoty byly zapsány do $LXQT_CONF"
else
    echo "Varování: Žádný touchpad nebyl detekován, přeskočeno nastavení GUI."
fi

# ---------------------------------------------------------
# 9. TISK V MENU, CHROME HLÁŠKA O VÝCHOZÍM PROHLÍŽEČI A AUTOSTART APLIKACÍ
# ---------------------------------------------------------
echo ">> Aplikuji systémová zástupce a autostart..."

ACTION_DIR="$HOME/.local/share/file-manager/actions"
mkdir -p "$ACTION_DIR"
cat > "$ACTION_DIR/tisk.desktop" << EOF
[Desktop Entry]
Type=Action
Name=Vytisknout...
Icon=printer
Profiles=profile-zero;
[X-Action-Profile profile-zero]
MimeTypes=image/*;application/pdf;text/plain;
Exec=/usr/local/bin/tisk-cz %f
EOF

xdg-settings set default-web-browser google-chrome.desktop 2>/dev/null
sudo mkdir -p /etc/opt/chrome/policies/managed/
echo '{"DefaultBrowserSettingEnabled": false}' | sudo tee /etc/opt/chrome/policies/managed/stop-otravovat.json > /dev/null

AUTOSTART_DIR="$HOME/.config/autostart"
mkdir -p "$AUTOSTART_DIR"

cat > "$AUTOSTART_DIR/copyq.desktop" << EOF
[Desktop Entry]
Type=Application
Name=CopyQ
Exec=copyq
X-GNOME-Autostart-enabled=true
X-LXQt-Need-Tray=true
EOF

cat > "$AUTOSTART_DIR/update-wrappers.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Update Wrappers
Exec=update-wrappers.sh
X-GNOME-Autostart-enabled=true
EOF

bash "$LOCAL_BIN/update-wrappers.sh"

# --- ZÁSTUPCE DO MENU: TVŮRCE ZÁSTUPCŮ ---
    echo ">> Vytvářím zástupce 'Tvůrce zástupců' v menu..."
    cat > "$USER_APPS_DIR/tvurce-zastupcu.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Tvůrce zástupců
Comment=Vytvoří nového zástupce s indikátorem načítání (busy-launch)
Exec=new-shortcut.sh
Icon=preferences-desktop-shortcuts
Terminal=true
Categories=Utility;
EOF

update-desktop-database "$USER_APPS_DIR" 2>/dev/null

# ---------------------------------------------------------
# 10. AUTOLOGIN
# ---------------------------------------------------------

read -p "Chceš zajistit automatické přihlašování bez zobrazení login obrazovky a hesla? (A/n): " AUTOLOGIN_CHOICE

# Pokud uživatel zmáčkne Enter (prázdná volba), 'A' nebo 'a', provede se nastavení
if [[ -z "$AUTOLOGIN_CHOICE" || "$AUTOLOGIN_CHOICE" =~ ^[Aa]$ ]]; then
    echo ">> Nastavuji autologin pro uživatele $USER..."

    # Smazání případného duplicitního hlavního souboru (-f zajistí, že to nevyhodí chybu, pokud soubor neexistuje)
    sudo rm -f /etc/sddm.conf

    # Vytvoření složky, pokud by náhodou chyběla
    sudo mkdir -p /etc/sddm.conf.d

    # Zápis do správného konfiguračního souboru
    sudo tee /etc/sddm.conf.d/autologin.conf > /dev/null <<EOF
[Autologin]
User=$USER
Session=Lubuntu
Relogin=true
EOF

    echo ">> Autologin úspěšně nastaven."
else
    echo ">> Přeskakuji, musíš se vždycky přihlásit heslem při startu PC nebo při odhlášení..."
fi

# ---------------------------------------------------------
# 11. ODSTRANĚNÍ "O LXQT" Z FANCY MENU (Binární patch)
# ---------------------------------------------------------
echo ">> Kontrola verze systému pro aplikaci Fancy Menu patche..."
OS_CODENAME=$(lsb_release -cs)

if [[ "$OS_CODENAME" == "questing" || "$OS_CODENAME" == "plucky" ]]; then
    PATCHED_PANEL="./.config/lxqt-panel_amd64_no_about"
    if [ -f "$PATCHED_PANEL" ]; then
        echo ">> Detekováno Lubuntu 25.10+, nasazuji upravený lxqt-panel..."

        # 1. ZÁKLADNÍ TRIK: Přesuneme originál pryč. Tím se vyhneme chybě "Soubor je používán"
        sudo mv /usr/bin/lxqt-panel /usr/bin/lxqt-panel.bak

        # 2. Vložíme tvůj patch (teď už má volnou cestu)
        sudo cp "$PATCHED_PANEL" /usr/bin/lxqt-panel
        sudo chmod +x /usr/bin/lxqt-panel

        # 3. Odstřelíme ten starý běžící v paměti
        killall -9 lxqt-panel 2>/dev/null
        
        # 4. Počkáme sekundu a ověříme, jestli ho systém nahodil sám, případně mu pomůžeme
        sleep 1
        pgrep lxqt-panel >/dev/null || (lxqt-panel & disown)
        
        echo ">> Patch úspěšně aplikován. Pták je v pánu."
    else
        echo "!! VAROVÁNÍ: Soubor $PATCHED_PANEL nebyl nalezen! Přeskakuji..."
    fi
else
    echo ">> Starší verze systému ($OS_CODENAME), binární patch pro 25.10 vynechán."
fi

# ---------------------------------------------------------
# FINÁLE
# ---------------------------------------------------------
echo ""
echo "=========================================="
echo " HOTOVO - SKRIPT DOKONČEN SE VŠÍM VŠUDY"
echo "=========================================="
echo -n "Stiskněte Enter pro uložení, odhlášení a přechod do TTY..."
read

# Zabijeme démony a odhlásíme
pkill lxqt-notificationd
pkill lxqt-session
pkill -u "$USER"
