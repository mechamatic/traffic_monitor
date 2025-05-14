#!/bin/bash
set -euo pipefail

SCRIPT_SRC="traffic_monitor.sh"
SERVICE_SRC="traffic_monitor.service"

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root (e.g., sudo $0)"
  exit 1
fi

echo "Updating package lists..."
apt-get update

echo "Installing iptables..."
apt-get install -y iptables iftop tmux vim

echo "Copying $SCRIPT_SRC to /usr/local/bin/traffic_monitor.sh"
cp "$SCRIPT_SRC" /usr/local/bin/traffic_monitor.sh
chmod +x /usr/local/bin/traffic_monitor.sh

echo "Copying $SERVICE_SRC to /etc/systemd/system/traffic_monitor.service"
cp "$SERVICE_SRC" /etc/systemd/system/traffic_monitor.service

echo "Reloading systemd daemon..."
systemctl daemon-reload

echo "Enabling traffic_monitor service to start at boot..."
systemctl enable traffic_monitor.service

echo "Starting traffic_monitor service now..."
systemctl start traffic_monitor.service

echo "Checking status of traffic_monitor service..."
systemctl status traffic_monitor.service --no-pager
