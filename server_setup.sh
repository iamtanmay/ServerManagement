#!/bin/bash

# Usage: server_setup.sh SUDO_PASSWORD
# Sets up:
#   Power monitoring service
#   GPU drivers
#   Fans
#   Undervolting CPU
#   Permissions to read CPU power usage
#   nvitop, XRDP
#   Wake up on WLAN

# Check if password was provided
if [ -z "$1" ]; then
    echo "Usage: $0 <sudo_password>"
    exit 1
fi

PASS="$1"

#Change to root user
echo "$PASS" | sudo -S -s

#Drivers
#Factory reset the plug with 10 second long press
#Install websocat on your system
sudo wget -qO /usr/local/bin/websocat https://github.com/vi/websocat/releases/latest/download/websocat.x86_64-unknown-linux-musl
sudo chmod a+x /usr/local/bin/websocat
websocat --version

#Run the matter-server docker container with bluetooth access
#Sends the WiFi credentials to your server
#echo '{"message_id": "2", "command": "set_wifi_credentials", "args": {"ssid": "Pradhan", "credentials": "xxxxxx"}}' | websocat ws://localhost:5580/ws
#Bluetooth Pairs and commissions the device
#echo '{"message_id": "3", "command": "commission_with_code", "args": {"code": "10419441567"}}' | websocat --exit-on-eof ws://localhost:5580/ws

#OFF
#echo '{"message_id": "6", "command": "device_command", "args": {"node_id": 9, "endpoint_id": 1, "cluster_id": 6, "command_name": "Off", "payload": {}}}' | websocat --exit-on-eof ws://localhost:5580/ws
#ON
#echo '{"message_id": "5", "command": "device_command", "args": {"node_id": 9, "endpoint_id": 1, "cluster_id": 6, "command_name": "On", "payload": {}}}' | websocat --exit-on-eof ws://localhost:5580/ws

#Commission Window
#echo '{"message_id": "1", "command": "open_commissioning_window", "args": {"node_id": 9}}' | websocat --exit-on-eof ws://localhost:5580/ws

# Fans
# https://github.com/nbfc-linux/nbfc-linux
# sudo apt install lm-sensors -y
# sudo systemctl enable nbfc_service --now
# sudo nbfc start

# Intel undervolting
# sudo apt install powercap-utils -y
# sudo powercap-set -p intel-rapl -z 0 -c 0 -l 5000000
# sudo powercap-set intel-rapl -z 0 -e 1
# sudo apt install intel-undervolt -y
# sudo nano /etc/intel-undervolt.conf
# power package 5/5
# sudo intel-undervolt apply
# sudo systemctl enable --now intel-undervolt
# watch -n 1 "powercap-info -p intel-rapl -z 0"


#GTX 1070 Ubuntu
# sudo apt purge '^nvidia-.*'
# sudo apt install nvidia-driver-535 -y
# sudo nvidia-xconfig --cool-bits=28
# sudo nano /etc/modprobe.d/nvidia-power.conf
# options nvidia NVreg_EnableGpuFirmware=0
# sudo update-initramfs -u
# sudo reboot
# OR
# sudo systemctl stop gdm3
# sudo modprobe -r nvidia_drm
# sudo modprobe -r nvidia_modeset
# sudo rmmod nvidia_uvm nvidia_modeset nvidia
# sudo systemctl start gdm3



#GTX 3060

#7900 XTX

#MI50

#780M

#IntelHD

#Vulkan

#SSH and VNC Server
sudo apt update
sudo apt install openssh-server tigervnc-standalone-server tigervnc-common -y
mkdir -p ~/.vnc && echo 'localhost=no' > ~/.vnc/config
echo -e "$PASS\n$PASS" | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd

crontab -l 2>/dev/null | grep -v "vncserver :1" | crontab -

# Add a cron job to start the server at boot exactly how your connection script expects it
(crontab -l 2>/dev/null; echo "@reboot rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 ~/.vnc/*.pid ~/.vnc/*.log && /usr/bin/vncserver :1 -geometry 1280x720 -localhost no -xstartup /etc/X11/Xsession") | crontab -

# Run the server command immediately for the current uptime session
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 ~/.vnc/*.pid ~/.vnc/*.log
vncserver :1 -geometry 1280x720 -localhost no -xstartup /etc/X11/Xsession

sudo ufw allow ssh
sudo systemctl enable --now ssh.socket
    
# 1. Copy script to home and make it executable
cp -f "./PowerMonUbuntu.sh" "$HOME/power_monitor.sh" && chmod +x "$HOME/power_monitor.sh"

# 2. Create the service in system directory
touch /etc/systemd/system/power_monitor.service

# 3. Use sed to inject the user and absolute path into the service
sed -i "s|User=.*|User=$(whoami)|" /etc/systemd/system/power_monitor.service
sed -i "s|ExecStart=.*|ExecStart=$HOME/power_monitor.sh|" /etc/systemd/system/power_monitor.service

# 4. Reload, Enable, and Restart
systemctl daemon-reload
systemctl enable power_monitor.service
systemctl restart power_monitor.service

pip install nvitop --break-system-packages


# Configure sysfs
echo "mode class/powercap/intel-rapl:0/energy_uj = 0444" | echo "$PASS" | sudo -S tee -a /etc/sysfs.conf
chmod 444 /sys/class/powercap/intel-rapl:0/energy_uj

# Create udev rules
echo "$PASS" | sudo -S tee /etc/udev/rules.d/99-powercap.rules > /dev/null <<EOF
SUBSYSTEM=="powercap", ACTION=="add", RUN+="/bin/chmod -R 444 /sys/class/powercap/intel-rapl:0/energy_uj"
ACTION=="add", SUBSYSTEM=="net", KERNEL=="wl*", RUN+="/usr/bin/iw phy0 wowlan enable magic-packet"
EOF

# Reload rules and services
udevadm control --reload-rules
udevadm trigger --subsystem-match=powercap
systemctl daemon-reload
systemctl enable power-monitor.service
systemctl start power-monitor.service

#Setup Wakeup on WLAN
WLAN=$(ip -o link show | grep -o 'wl[^:]*' | head -n1)
PHY_NAME=$(iw dev | grep -o 'phy#[0-9]*' | tr -d '#')
MACADDR=$(ip link show $WLAN | grep -oP '(?<=link/ether )[:0-9a-fA-F]+')

echo "Server has the Interface $WLAN $PHY_NAME with address $MACADDR"

ethtool -s $WLAN wol g
iw $PHY_NAME wowlan enable magic-packet
nmcli connection modify 'Pradhan' wifi.wake-on-wlan magic
iw $PHY_NAME wowlan show
echo "If the previous message says WoWLAN is enabled with wake up on magic packet, then system is ready for Wakeup on WLAN"

# Identify the original user (who called the script)
ORIGINAL_USER=${SUDO_USER:-$USER}

echo "Switching back to $ORIGINAL_USER..."

# Dropping privileges for the final message or subsequent user-level tasks
sudo -u "$ORIGINAL_USER" bash <<EOF
    echo "Current user: \$(whoami)"
    echo "Configuration complete. No longer running as root."
EOF
