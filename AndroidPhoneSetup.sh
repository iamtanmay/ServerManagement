#Termux
termux-setup-storage
pkg install termux-api -y
pkg install termux-boot -y
mkdir -p ~/.termux/boot

#SSH
pkg install openssh -y
printf "#!/data/data/com.termux/files/usr/bin/sh\ntermux-wake-lock\nsshd" > ~/.termux/boot/start-ssh.sh
chmod +x ~/.termux/boot/start-ssh.sh
pkg install tur-repo -y
pkg update

#Git
pkg install git -y

#ServerManagement
git clone https://github.com/iamtanmay/ServerManagement.git
cd ServerManagement
git pull
cd ..

#Websocat
wget https://github.com/vi/websocat/releases/download/v4.0.0-alpha3/websocat.aarch64-linux-android
chmod +x websocat*
mv websocat* $PREFIX/bin/websocat
websocat --version

#Homepage (Homelab dashboard)
pkg install nodejs-lts -y
git clone https://github.com/gethomepage/homepage.git
cd homepage
npm install -g pnpm
pnpm install
pnpm run build
cd ..

cp $HOME/ServerManagement/services.yaml $HOME/homepage/config/
cp $HOME/ServerManagement/widgets.yaml $HOME/homepage/config/
cp $HOME/ServerManagement/power_server.sh $HOME/homepage/config/
cp $HOME/ServerManagement/server_stats.sh $HOME/homepage/config/

#Create service
mkdir -p $PREFIX/var/service/homepage/log
mkdir -p /data/data/com.termux/files/home/homepage/logs

cat << 'EOF' >> $PREFIX/var/service/homepage/run
#!/data/data/com.termux/files/usr/bin/sh
exec 2>&1
termux-wake-lock

# Hardcode environment variables into the daemon environment
export PATH=/data/data/com.termux/files/usr/bin:$PATH
export HOSTNAME=0.0.0.0
export HOMEPAGE_CONFIG_DIR=/data/data/com.termux/files/home/homepage/config
export HOMEPAGE_ALLOWED_HOSTS="*"
export NODE_ENV=production

exec node /data/data/com.termux/files/home/homepage/.next/standalone/server.js
EOF

# Logger
cat << 'EOF' >> $PREFIX/var/service/homepage/log/run
#!/data/data/com.termux/files/usr/bin/sh

exec svlogd -tt /data/data/com.termux/files/home/homepage/logs
EOF

chmod +x $PREFIX/var/service/homepage/run
chmod +x $PREFIX/var/service/homepage/log/run
sv stop homepage
sv-disable homepage
sv-enable homepage
sv start homepage
sv restart homepage

#Homepage Webhook service
pip install flask flask-cors --break-system-packages
mkdir -p $PREFIX/var/service/homepage_webhook/log

cat << 'EOF' > $PREFIX/var/service/homepage_webhook/run
#!/data/data/com.termux/files/usr/bin/sh
exec 2>&1
termux-wake-lock

exec python3 /data/data/com.termux/files/home/ServerManagement/homepage_webhook_server.py
EOF

chmod +x $PREFIX/var/service/homepage_webhook/run
source $PREFIX/etc/profile.d/start-services.sh
pkill -f "runsv"
sv-enable homepage_webhook
sv start homepage_webhook

#Logger
cat << 'EOF' > $PREFIX/var/service/homepage_webhook/log/run
#!/data/data/com.termux/files/usr/bin/sh
exec svlogd -tt ./main
EOF

chmod +x $PREFIX/var/service/homepage_webhook/log/run
mkdir -p $PREFIX/var/service/homepage_webhook/log/main
sv restart homepage_webhook



#uDocker
pkg install udocker -y
mkdir -p /data/data/com.termux/files/home/matter-data
udocker pull ghcr.io/matter-js/python-matter-server:8.1.2
udocker create --name=matter-server ghcr.io/matter-js/python-matter-server:8.1.2
udocker setup --execmode=P1 matter-server

#Matter server (doesn't work)
udocker run \
  --user=root \
  -v /data/data/com.termux/files/home/matter-data:/data \
  matter-server \
  --storage-path /data \
  --paa-root-cert-dir /data/credentials \
  --bluetooth-adapter 999 \
  --disable-server-interactions

#Exec
udocker run -i -t --user=root --entrypoint=/bin/sh matter-server

#Proot
pkg install proot-distro -y
proot-distro install ubuntu
proot-distro login ubuntu

#Docker
pkg update && pkg upgrade
pkg install openssh git curl wget qemu-utils qemu-common qemu-system-x86_64-headless -y
mkdir alpine && cd $_
wget https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86_64/alpine-virt-3.23.4-x86_64.iso
qemu-img create -f qcow2 alpine.img 4G
qemu-system-x86_64 -machine q35 -m 1024 -smp cpus=2 -cpu qemu64 \
  -drive if=pflash,format=raw,read-only,file=$PREFIX/share/qemu/edk2-x86_64-code.fd \
  -netdev user,id=n1,hostfwd=tcp::2222-:22 -device virtio-net,netdev=n1 \
  -cdrom alpine-virt-3.23.4-x86_64.iso \
  -nographic -serial mon:stdio alpine.img

#Login with user root (no password)
#Press enter for defaults
setup-interfaces
wget https://gist.githubusercontent.com/oofnikj/e79aef095cd08756f7f26ed244355d62/raw/answerfile
sed -i -E 's/(local kernel_opts)=.*/\1="console=ttyS0"/' /sbin/setup-disk
setup-alpine -f answerfile
qemu-system-x86_64 -machine q35 -m 1024 -smp cpus=2 -cpu qemu64 \
  -drive if=pflash,format=raw,read-only,file=$PREFIX/share/qemu/edk2-x86_64-code.fd \
  -netdev user,id=n1,hostfwd=tcp::2222-:22 -device virtio-net,netdev=n1 \
  -nographic alpine.img

apk update && apk add docker
service docker start
rc-update add docker

export PATH=$PATH:$(pwd)/udocker

#Prom Node Exporter
pkg install prometheus-node-exporter
wget https://github.com

# Extract the files
tar xvfz node_exporter-1.8.2.linux-armv7.tar.gz

# Move the binary to your path
mv node_exporter-1.8.2.linux-armv7/node_exporter $PREFIX/bin/

node_exporter &
curl localhost:9100/metrics


#Gitea


#NGINX
pkg install nginx python
touch ~/whitelist.conf

/data/data/com.termux/files/usr/etc/nginx/nginx.conf

http {
    # Define a custom log format to include real IPs
    log_format combined_syslog '$remote_addr - $remote_user [$time_local] '
                               '"$request" $status $body_bytes_sent '
                               '"$http_referer" "$http_user_agent"';

    # Export logs to your remote server via Syslog
    access_log syslog:server=100.x.y.z:514,facility=local7,tag=nginx,severity=info combined_syslog;

    server {
        listen 8080; # Termux often uses high ports by default
        server_name your-phone.ts.net;

        # 1. ALWAYS ALLOW TAILSCALE DEVICES
        allow 100.64.0.0/10;

        # 2. ALLOW INDIVIDUAL APPROVED IPs
        include /data/data/com.termux/files/home/whitelist.conf;

        # 3. DENY ALL OTHERS
        deny all;

        location / {
            # Proxy to your other servers/containers
            proxy_pass http://100.x.y.z:target_port;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }

        # Your internal Approval Dashboard (proxied to your central server)
        location /admin {
            auth_basic "Admin Restricted";
            auth_basic_user_file /data/data/com.termux/files/usr/etc/nginx/.htpasswd;
            proxy_pass http://100.x.y.z:5000; 
        }
    }
}


#Tailscale

#100.115.26.71
#100.76.255.48

#Admin Dashboard

NGINX

server {
    listen 80;
    server_name your-phone.ts.net;

    # The magic line:
    include /data/data/com.termux/files/home/whitelist.conf;
    
    # Block everyone else by default
    deny all;

    location /admin {
        # Only YOU can see the dashboard via Basic Auth
        auth_basic "Admin Area";
        auth_basic_user_file /etc/nginx/.htpasswd;
        proxy_pass http://your-central-server-ip:5000/;
    }

    location / {
        proxy_pass http://your-other-containers;
    }
}



from flask import Flask, render_template_string, request
import subprocess

app = Flask(__name__)

WHITELIST_PATH = "/etc/nginx/whitelist.conf"
PENDING_PATH = "/tmp/pending_ips.txt"

HTML_PAGE = """
<h1>Homelab Gateway Approvals</h1>
<ul>
{% for ip in ips %}
    <li>{{ ip }} <a href="/approve?ip={{ ip }}"><button>Approve</button></a></li>
{% endfor %}
</ul>
"""

@app.route('/')
def index():
    with open(PENDING_PATH, 'r') as f:
        ips = f.read().splitlines()
    return render_template_string(HTML_PAGE, ips=ips)

@app.route('/approve')
def approve():
    ip = request.args.get('ip')
    # Add to NGINX whitelist
    with open(WHITELIST_PATH, 'a') as f:
        f.write(f"allow {ip};\n")
    # Reload NGINX on the phone via SSH
    subprocess.run(["tailscale", "ssh", "root@phone-name", "nginx -s reload"])
    return f"IP {ip} Approved! <a href='/'>Back</a>"

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)



#Monitoring








#NodeJS matter controller setup
mkdir /data/data/com.termux/files/home/matter && cd /data/data/com.termux/files/home/
pkg update && pkg upgrade
pkg install nodejs-lts tmux -y
npm i @matter/nodejs-shell

#Give permissions to Termux to discover Network
#Install ADB on PC. Your phone should be connected via USB and have Developer settings -> USB Debugging set to allow
#sudo apt update && sudo apt install android-tools-adb android-tools-fastboot -y && adb devices
#Your phone will show a popup, click allow. Run the command again
#adb devices
#adb -s ZY22GVS867 shell "pm grant com.termux android.permission.ACCESS_FINE_LOCATION; device_config put activity_manager max_phantom_processes 2147483647"
#Sanity test if Termux can discover the network
pkg install mdns-scan
mdns-scan

alias matter='(node ~/matter/node_modules/@matter/nodejs-shell/dist/esm/app.js)'
matter

#Your router should be set up to give this device a static IP address
#On Desktop start the matter server which is already paired with the matter device
#Send this commission window request and copy the 8 digit PIN from the docker logs
#echo '{"message_id": "2", "command": "set_wifi_credentials", "args": {"ssid": "Pradhan", "credentials": "xxxxxx"}}' | websocat ws://localhost:5580/ws
#echo '{"message_id": "1", "command": "open_commissioning_window", "args": {"node_id": 9}}' | websocat --exit-on-eof ws://localhost:5580/ws
#Sanity check - shows devices which are in commission window
discover commissionable
#Get the -D value, the discriminator and use the PIN from the docker logs
commission pair 3 --setupPinCode 66163303 --discriminator 3307
config logfile set /data/data/com.termux/files/home/matter/matter_events.log

#Restart the shell with tmux for detached persistent logging
exit

tmux
matter
config loglevel set "info"
nodes log 3

#Ctrl + B, then tap D to detach

#Log management
#Log
cat ~/matter/matter_events.log | grep INFO
#Tail
tail -f -n 10 ~/matter/matter_events.log | grep --line-buffered INFO
#Clearing logs
truncate -s 0 ~/matter/matter_events.log

#Commands
#Format is 'commands onoff on <NodeId> 1'
commands onoff off 3 1
##To DELETE all configuration from the Matter controller - rm -rf /data/data/com.termux/files/home/.matter/shell-0

#Scripting command to turn the plug on/off
alias matter='(node ~/matter/node_modules/@matter/nodejs-shell/dist/esm/app.js)'
{ echo "commands onoff on 3 1"; sleep 15; } | matter
{ echo "commands onoff off 3 1"; sleep 15; } | matter


#Service
pkg update && pkg install termux-services -y

mkdir -p $PREFIX/var/service/matter-shell/

cat << 'EOF' > $PREFIX/var/service/matter-shell/run
#!/data/data/com.termux/files/usr/bin/bash

# Ensure the named pipe exists
if [ ! -p "$HOME/matter_pipe" ]; then
    mkfifo "$HOME/matter_pipe"
fi

# Run a clean background stream wrapper
tail -f "$HOME/matter_pipe" | node "$HOME/matter/node_modules/@matter/nodejs-shell/dist/esm/app.js" > /dev/null 2>&1
EOF

chmod +x $PREFIX/var/service/matter-shell/run
source $PREFIX/etc/profile.d/start-services.sh
pkill -f "runsv"
sv-enable matter-shell
sv down matter-shell
sv up matter-shell
sv status matter-shell

#Add aliases to .bashrc
cat << 'EOF' >> ~/.bashrc

alias matter-on='echo "commands onoff on 3 1" > ~/matter_pipe'
alias matter-off='echo "commands onoff off 3 1" > ~/matter_pipe'
alias matter-status='sv status matter-shell'
alias matter-restart='sv restart matter-shell'
EOF

source ~/.bashrc






#Wake up on lan

#Wake up server via bluetooth
lsusb | grep Bluetooth
Bus 001 Device 004: ID 8087:0a2b Intel Corp. Bluetooth wireless interface

#To enable Wake on Bluetooth on your ASUS ROG GL702VS running Ubuntu 24.04, you must manually "arm" the specific USB port that controls your Intel Bluetooth adapter #(8087:0a2b).Your lsusb output shows the Bluetooth card is on Bus 001 Device 004. Since your grep result for 1-6 is the moto g23, your Bluetooth module is likely on #another 1-x port (often 1-7 or 1-9).

# Finds the sysfs path for the Intel Bluetooth module
for dev in /sys/bus/usb/devices/1-*; do
  if [ -f "$dev/idVendor" ] && [ "$(cat $dev/idVendor)" = "8087" ] && [ "$(cat $dev/idProduct)" = "0a2b" ]; then
    echo "Found Bluetooth at: $dev"
    echo "enabled" | sudo tee "$dev/power/wakeup"
  fi
done

#Found Bluetooth at: /sys/bus/usb/devices/1-9
#enabled
#Change sleep modes
#sudo nano /etc/default/grub
#GRUB_CMDLINE_LINUX_DEFAULT="quiet splash nomodeset mem_sleep_default=deep
#sudo grub-update
#echo deep | sudo tee /sys/power/mem_sleep
#echo s2idle | sudo tee /sys/power/mem_sleep
#sudo reboot now


echo 'ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="8087", ATTR{idProduct}=="0a2b", ATTR{power/wakeup}="enabled"' | sudo tee /etc/udev/rules.d/90-moto-wake.rules && sudo udevadm control --reload-rules && sudo udevadm trigger


pkg install android-tools -y
#Enable Wireless Debugging in Developer Options. Click it to get pairing code and IP/Port. Different port for Pairing/Connecting
#In Termux, pair the phone to itself
#The pairing port and connecting port are DIFFERENT !
adb pair 192.168.1.101:34503 089109
adb connect 192.168.1.101:43289

adb shell svc bluetooth disable
sleep 2
adb shell svc bluetooth enable



#Wake Up server via USB
#On the Server
echo 'ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="22b8", ATTR{idProduct}=="2e81", ATTR{power/wakeup}="enabled"' | sudo tee /etc/udev/rules.d/90-moto-wake.rules && sudo udevadm control --reload-rules && sudo udevadm trigger
# Enable wake for the specific port
grep -H . /sys/bus/usb/devices/*/product | grep "moto g23"
echo "enabled" | sudo tee /sys/bus/usb/devices/1-6/power/wakeup
# Enable wake for the parent hub (Bus 1)
echo "enabled" | sudo tee /sys/bus/usb/devices/usb1/power/wakeup

#Check if the device is enabled for S3 - Deep Sleep
cat /proc/acpi/wakeup | grep "XHC"

pkg install android-tools -y
#Enable Wireless Debugging in Developer Options. Click it to get pairing code and IP/Port. Different port for Pairing/Connecting
#In Termux, pair the phone to itself
#The pairing port and connecting port are DIFFERENT !
adb pair 192.168.1.101:34503 089109
adb connect 192.168.1.101:43289

nano wake-laptop.sh
#!/bin/bash
# Connect to phone's internal ADB
adb connect [IP:PORT]

# Force a USB 'Personality Change' to wake the laptop
echo "Sending wake signal..."
adb shell svc usb setFunctions rndis
sleep 1
adb shell svc usb setFunctions mtp
echo "Signal sent!"

chmod +x wake-laptop.sh


#Send Enter keypress to wake up the machine
adb shell hid keyboard press enter
#Send Spacebar keypress to wake up the machine
adb shell input keyevent 62

#Turn USB tethering on to wake up the machine
adb shell svc usb setFunctions rndis
adb shell svc usb setFunctions rndis && adb shell svc usb setFunctions mtp


