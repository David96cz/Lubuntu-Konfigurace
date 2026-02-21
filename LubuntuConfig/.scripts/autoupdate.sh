# ---------------------------------------------------------
# 13. AUTOMATICKÉ TICHÉ AKTUALIZACE (CRON JOB)
# ---------------------------------------------------------
echo ">> Nastavuji automatické denní aktualizace na pozadí..."

sudo cat > /etc/cron.daily/lubuntu-autoupdate << 'EOF'
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