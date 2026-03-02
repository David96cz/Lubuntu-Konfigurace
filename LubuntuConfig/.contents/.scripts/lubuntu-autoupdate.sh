#!/bin/bash

# Pockame 120 sekund (2 minuty) po startu anacronu
sleep 120

# Vypne jakékoliv interaktivní dotazy (aby to v cronu nečekalo na Enter)
export DEBIAN_FRONTEND=noninteractive

# Stáhne čerstvé seznamy balíků
apt-get update -qq

# Provede tvrdý full-upgrade přesně jako tvůj manuální příkaz.
# Ty "Dpkg" parametry zajistí, že pokud se systém zeptá, jestli přepsat konfigurační soubor,
# automaticky zvolí výchozí/starou možnost a nezasekne se.
apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" full-upgrade

# Uklidí po sobě staré a nepotřebné balíky
apt-get autoremove -y -qq
apt-get autoclean -qq