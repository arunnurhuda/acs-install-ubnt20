#!/usr/bin/env bash

# Author: arun.nurhuda

set -xe

# Update and install required packages
sudo apt update && sudo apt install -y dirmngr \
    gnupg \
    apt-transport-https \
    ca-certificates \
    software-properties-common \
    build-essential \
    python3 \
    python3-pip \
    python3-dev

# Install NodeJS
echo "Installing NodeJS..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt update && sudo apt install -y nodejs
echo ""

# Setting npm version
echo "Setting npm version"
NPM_VERSION=$(npm search -g npm | grep -wi ^npm | grep -iw "install modules package manager package.json" | cut -d'|' -f5 | cut -d' ' -f2)
sudo npm install -g npm@$NPM_VERSION

# Install node-gyp
sudo npm install -g node-gyp

# Install MongoDB
wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | sudo apt-key add -
echo "deb [ arch=amd64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
sudo apt update && sudo apt install -y mongodb-org
sudo systemctl enable --now mongod
sudo systemctl status mongod --no-pager
echo "wait 5 seconds"
sleep 5
sudo mongo --eval 'db.runCommand({ connectionStatus: 1 })'
echo ""

# Install GenieACS
echo "Installing GenieACS..."
sudo npm install -g genieacs
sudo useradd --system --no-create-home --user-group genieacs || true
sudo mkdir -p /opt/genieacs
sudo mkdir -p /opt/genieacs/ext
sudo cat << EOF > /opt/genieacs/genieacs.env
GENIEACS_CWMP_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-cwmp-access.log
GENIEACS_NBI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-nbi-access.log
GENIEACS_FS_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-fs-access.log
GENIEACS_UI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-ui-access.log
GENIEACS_DEBUG_FILE=/var/log/genieacs/genieacs-debug.yaml
NODE_OPTIONS=--enable-source-maps
GENIEACS_EXT_DIR=/opt/genieacs/ext
GENIEACS_UI_JWT_SECRET=secret
EOF

sudo chown genieacs. /opt/genieacs -R
sudo chmod 600 /opt/genieacs/genieacs.env
sudo mkdir -p /var/log/genieacs
sudo chown genieacs. /var/log/genieacs

# Create systemd unit files

## CWMP
sudo cat << EOF > /etc/systemd/system/genieacs-cwmp.service
[Unit]
Description=GenieACS CWMP
After=network.target
 
[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/genieacs-cwmp
 
[Install]
WantedBy=default.target
EOF

## NBI
sudo cat << EOF > /etc/systemd/system/genieacs-nbi.service
[Unit]
Description=GenieACS NBI
After=network.target
 
[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/genieacs-nbi
 
[Install]
WantedBy=default.target
EOF

## FS
sudo cat << EOF > /etc/systemd/system/genieacs-fs.service
[Unit]
Description=GenieACS FS
After=network.target
 
[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/genieacs-fs
 
[Install]
WantedBy=default.target
EOF

## UI
sudo cat << EOF > /etc/systemd/system/genieacs-ui.service
[Unit]
Description=GenieACS UI
After=network.target
 
[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/genieacs-ui
 
[Install]
WantedBy=default.target
EOF

# Config logrotate
sudo cat << EOF > /etc/logrotate.d/genieacs
/var/log/genieacs/*.log /var/log/genieacs/*.yaml {
    daily
    rotate 30
    compress
    delaycompress
    dateext
}
EOF

# Finish installation
echo "Finishing GenieACS installation..."
sudo systemctl daemon-reload
sudo systemctl enable --now genieacs-{cwmp,fs,ui,nbi}

# Output access URL
IPv4=$(ip route | grep -i ^default | cut -d' ' -f9)
echo "#### GenieACS UI access: http://$IPv4:3000 ####"