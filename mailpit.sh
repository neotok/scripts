#!/bin/bash

# Configuration par défaut
MAILPIT_USER=${MAILPIT_USER:-mailpit}
MAILPIT_DB_PATH=${MAILPIT_DB_PATH:-/var/lib/mailpit/mailpit.db}
MAILPIT_PORT=${MAILPIT_PORT:-8025}

# Arrêter en cas d'erreur
set -euo pipefail

# Vérifier si on est root
if [[ $EUID -ne 0 ]]; then
   echo "Ce script doit être exécuté en tant que root"
   exit 1
fi

# Vérifier si curl est installé
if ! command -v curl &> /dev/null; then
    echo "Erreur: curl n'est pas installé"
    exit 1
fi

echo "Création de l'utilisateur $MAILPIT_USER..."
sudo groupadd --system $MAILPIT_USER 2>/dev/null || true
sudo useradd --system --no-create-home --gid $MAILPIT_USER $MAILPIT_USER 2>/dev/null || true

echo "Configuration du répertoire de données..."
sudo mkdir -p $(dirname $MAILPIT_DB_PATH)
sudo chown -R $MAILPIT_USER:$MAILPIT_USER $(dirname $MAILPIT_DB_PATH)

echo "Installation de Mailpit..."
sudo sh < <(curl -sL https://raw.githubusercontent.com/axllent/mailpit/develop/install.sh)

echo "Configuration du service systemd..."
cat <<EOF | sudo tee /etc/systemd/system/mailpit.service > /dev/null
[Unit]
Description=Mailpit server

[Service]
ExecStart=/usr/local/bin/mailpit -d $MAILPIT_DB_PATH --listen 127.0.0.1:$MAILPIT_PORT
Restart=always
# Restart service after 10 seconds if service crashes
RestartSec=10
SyslogIdentifier=mailpit
User=$MAILPIT_USER
Group=$MAILPIT_USER

[Install]
WantedBy=multi-user.target
EOF

echo "Démarrage du service..."
sudo systemctl daemon-reload
sudo systemctl enable mailpit.service && sudo systemctl start mailpit.service

# Vérifier que le service démarre correctement
echo "🔍 Vérification de l'installation..."
sleep 2

if sudo systemctl is-active --quiet mailpit.service; then
    echo "Mailpit installé et démarré avec succès!"
    echo "Interface web disponible sur http://localhost:$MAILPIT_PORT"
    echo "Base de données: $MAILPIT_DB_PATH"
    echo "Utilisateur: $MAILPIT_USER"
else
    echo "Erreur lors du démarrage de Mailpit"
    echo "Vérifiez les logs avec: sudo journalctl -u mailpit.service"
    exit 1
fi
