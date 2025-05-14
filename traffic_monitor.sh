#!/bin/bash
# traffic_monitor.sh
# Usage: traffic_monitor.sh <interface> <log_user>
# Example: traffic_monitor.sh eth0 myuser

set -euo pipefail

INTERFACE="${1:-eth0}"
LOG_USER="${2:-$(whoami)}"
USER_HOME="/home/$LOG_USER"
LOG_DIR="$USER_HOME/traffic_logs"
mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/traffic_$(date +%F).log"
CHAIN="TRAFFIC_MONITOR"

# Check running as root (required for iptables)
if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: Must run as root"
  exit 1
fi

# Ensure log file is writable by $LOG_USER
touch "$LOG_FILE"
chown "$LOG_USER":"$LOG_USER" "$LOG_FILE"

setup_iptables() {
  # Create custom chain if does not exist
  if ! iptables -L $CHAIN -n &>/dev/null; then
    echo "Creating iptables chain: $CHAIN"
    iptables -N $CHAIN
  fi

  for direction in INPUT OUTPUT; do
    if ! iptables -L $direction -n --line-numbers | grep -q "$CHAIN"; then
      echo "Inserting $CHAIN chain into $direction"
      iptables -I $direction 1 -j $CHAIN
    fi
  done

  if ! iptables -L $CHAIN -v -n | grep -q "iif=$INTERFACE"; then
    echo "Adding rule to monitor incoming traffic on $INTERFACE"
    iptables -A $CHAIN -i $INTERFACE -j RETURN
  fi

  if ! iptables -L $CHAIN -v -n | grep -q "oif=$INTERFACE"; then
    echo "Adding rule to monitor outgoing traffic on $INTERFACE"
    iptables -A $CHAIN -o $INTERFACE -j RETURN
  fi
}

read_traffic() {
  iptables -L $CHAIN -vxn -t filter | tail -n +3 | while read -r line; do
    pkts=$(echo "$line" | awk '{print $1}')
    bytes=$(echo "$line" | awk '{print $2}')
    in_if=$(echo "$line" | awk '{print $6}')
    out_if=$(echo "$line" | awk '{print $7}')
    if [ "$in_if" == "$INTERFACE" ]; then
      direction="IN"
    elif [ "$out_if" == "$INTERFACE" ]; then
      direction="OUT"
    else
      direction="UNKNOWN"
    fi
    echo "$direction $pkts packets, $bytes bytes"
  done
}

reset_counters() {
  iptables -Z $CHAIN
}

setup_iptables

echo "Monitoring traffic on interface $INTERFACE"
echo "Logging to $LOG_FILE"

# Initialize log file with header if empty
if ! grep -q '^Timestamp IN_bytes OUT_bytes' "$LOG_FILE" 2>/dev/null; then
  echo "Timestamp IN_bytes OUT_bytes" >> "$LOG_FILE"
fi

reset_counters

while true; do
  traffic=$(read_traffic)

  IN_bytes=0
  OUT_bytes=0
  while read -r line; do
    dir=$(echo "$line" | awk '{print $1}')
    bytes=$(echo "$line" | awk '{print $4}')
    if [ "$dir" == "IN" ]; then
      IN_bytes=$bytes
    elif [ "$dir" == "OUT" ]; then
      OUT_bytes=$bytes
    fi
  done <<< "$traffic"

  echo "$(date '+%Y-%m-%d %H:%M:%S') $IN_bytes $OUT_bytes" >> "$LOG_FILE"
  chown "$LOG_USER":"$LOG_USER" "$LOG_FILE"

  reset_counters
  sleep 3600
done

LOGROTATE_CONF="/etc/logrotate.d/traffic_monitor"

sudo tee $LOGROTATE_CONF > /dev/null <<EOF
/home/$LOG_USER/traffic_logs/traffic_*.log {
    daily
    rotate 7
    missingok
    notifempty
    compress
    delaycompress
    sharedscripts
    postrotate
        # No reload or restart required
    endscript
}
EOF

sudo chmod 644 $LOGROTATE_CONF
echo "Logrotate config created at $LOGROTATE_CONF"
