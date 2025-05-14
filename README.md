# traffic_monitor
traffic monitoring

Before running the install script ensure you edit "traffic_monitor.service to replace <NetworkInterface> with the interface name that you want to be monitored

To install logging service, run "sudo ./install_traffic_monitor.sh"

iftop will be installed for real time monitoring:
	Run "sudo iftop -i <Interface>" to view real time traffic usage.

Logging is accomplished via iptables. Logs are written to /home/pi/traffic_logs/* on an hourly basis

Tmux and vim are installed for conveniance.

After installation, this script will run as a systemd service and be started automatically at each boot.


