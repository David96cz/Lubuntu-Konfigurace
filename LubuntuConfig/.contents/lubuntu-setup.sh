#!/bin/bash

# Zajištění sudo oprávnění hned na začátku
sudo -v

# --- ABSOLUTNÍ CESTY K TVÝM NOVÝM SLOŽKÁM ---
BASE_DIR="$(dirname "$(realpath "$0")")"
CONFIG_DIR="$BASE_DIR/.config"
SCRIPTS_DIR="$BASE_DIR/.scripts"

# --- SYSTÉMOVÉ PROMĚNNÉ ---
LXQT_DIR="$HOME/.config/lxqt"
PCMANFM_DIR="$HOME/.config/pcmanfm-qt/lxqt"
USER_APPS_DIR="$HOME/.local/share/applications"
LOCAL_BIN="$HOME/.local/bin"

# Definice balíčků
BALICKY="xfwm4 xfconf gdebi flameshot htop vlc featherpad icoutils viewnior ffmpegthumbnailer heif-gdk-pixbuf zram-tools gthumb cabextract libgl1-mesa-dri:i386 libgl1:i386 libglx-mesa0:i386 yad cups-client cups brightnessctl libnotify-bin copyq"
SMRTIHLAV="xscreensaver lximage-qt qlipper imagemagick vim"

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

if ! command -v google-chrome &> /dev/null; then
    wget -qO /tmp/google-chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    sudo apt install -y /tmp/google-chrome.deb
    rm /tmp/google-chrome.deb
fi

# ---------------------------------------------------------
# 2. ZÁLOHA A APLIKACE TVÝCH .CONFIG SOUBORŮ
# ---------------------------------------------------------
echo ">> Zálohuji stávající konfiguraci..."
mkdir -p "$LXQT_DIR/backup_$(date +%F_%T)"
cp "$LXQT_DIR/"*.conf "$LXQT_DIR/backup_$(date +%F_%T)/" 2>/dev/null

echo ">> Nasazuji čisté konfigurační soubory z .config..."

pkill lxqt-notificationd 2>/dev/null
cp "$CONFIG_DIR/notifications.conf" "$LXQT_DIR/notifications.conf"

pkill -KILL pcmanfm-qt 2>/dev/null
rm -rf "$PCMANFM_DIR"
mkdir -p "$PCMANFM_DIR"
cp "$CONFIG_DIR/pcmanfm-qt.conf" "$PCMANFM_DIR/settings.conf"

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
# 3. KOPÍROVÁNÍ VLASTNÍCH SKRIPTŮ Z .SCRIPTS
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
# 4. SKRYTÍ APLIKACÍ Z MENU
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
echo "   [OK] Aplikace skryty."

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
# 7. XFWM4 A PRAVIDLA PRO TOUCHPAD
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

echo ">> Nastavuji pravidla pro touchpad..."
sudo mkdir -p /etc/X11/xorg.conf.d
sudo tee /etc/X11/xorg.conf.d/40-libinput-touchpad.conf > /dev/null << 'EOF'
Section "InputClass"
    Identifier "libinput touchpad catchall"
    MatchIsTouchpad "on"
    Driver "libinput"
    Option "ClickMethod" "clickfinger"
    Option "Tapping" "on"
EndSection
EOF

# ---------------------------------------------------------
# 8. TISK, CHROME A AUTOSTART APLIKACÍ
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
# 9. ČIŠTĚNÍ BORDELU
# ---------------------------------------------------------
echo ">> Čistím systém od zbytečných aplikací..."
for balicek in $SMRTIHLAV; do
    sudo apt purge "$balicek" -y || true
done
sudo apt autoremove --purge -y
sudo apt clean
echo "   [OK] Systém je vyčištěn od všeho balastu."

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
