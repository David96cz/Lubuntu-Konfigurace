# Odstřelí všechny procesy uživatele (pro jistotu)
sudo pkill -u teststrejda

# Smaže uživatele i s jeho domovskou složkou
sudo userdel -r teststrejda

# Vytvoří ho znovu (tady zadej heslo)
sudo adduser teststrejda

# Přidá ho do skupiny sudo (aby mohl instalovat věci)
sudo usermod -aG sudo teststrejda
