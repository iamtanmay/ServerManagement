#!/bin/bash

# Loads server configuration from disk and allows remote management of servers
# Shows the Online/Offline status of all servers in config, and allows to start (and connect) or stop them
# Functions - 
# connect_server Wake up a server on WLAN or Matter smartplug cycle, then connect via SSH and VNC
# stop_server Suspend or PowerOff a server
# probe_ssh checks the connection to a server via nc
# get_status refreshes the Online/Offline status of all servers in servers.conf

# Designed to run on a Gateway server, e.g an android phone running Tailscale
# Gateway server is designed to control the subnet with other servers inside

# Load server configuration
CONFIG_FILE="./servers.conf"

#Get directory of this script
CURRENT_DIR="$(dirname "$0")"

if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    echo "Error: $CONFIG_FILE not found."
    exit 1
fi

SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q"

# Check connection to a server via nc
probe_ssh(){
	local IP="$1"
	local PORT="$2"

	if timeout 0.8 nc -z "$IP" "$PORT" > /dev/null 2>&1; then
		return 0
	else
		return 1
	fi
}

# Refreshes the Online/Offline status of all servers in servers.conf
get_status() {
    for s in "${SERVERS[@]}"; do
        # Read the values FIRST
        IFS="|" read -r ID TITLE IP PORT USER PASS CMDSTOP MAC <<< "$s"
        
        # Now check the status
	if probe_ssh "$IP" "$PORT"; then
            echo "  [$ID] $TITLE [$IP] - ONLINE"
        else
            echo "  [$ID] $TITLE [$IP] - OFFLINE"
        fi
    done
}

# Suspend or PowerOff a server
stop_server() {
	local TITLE="$1"
	local IP="$2"
	local PORT="$3"
	local USER="$4"
	local PASS="$5"
	local CMDSTOP="$6"

	gnome-terminal --tab --title="$TITLE" -- bash -c \
	"sshpass -p '$PASS' ssh -t $SSH_OPTS $USER@$IP -p $PORT \"echo '$PASS' | $CMDSTOP\""
}

# Wake up a server on WLAN or Matter smartplug cycle, then connect via SSH and VNC
# SSH startup command in server config loops a Power monitor, traps and fallback to bash terminal after exiting monitor
# Overhead package power is defined as a constant. CPU and GPU power displayed as well as total
connect_server() {
	local TITLE="$1"
	local IP="$2"
	local PORT="$3"
	local USER="$4"
	local PASS="$5"
	local LOCAL_SCRIPT="$6"

	connect_server_ssh "$TITLE" "$IP" "$PORT" "$USER" "$PASS" "$LOCAL_SCRIPT"
	connect_server_vnc "$TITLE" "$IP" "$PORT" "$USER" "$PASS"
}

connect_server_ssh() {
	local TITLE="$1"
	local IP="$2"
	local PORT="$3"
	local USER="$4"
	local PASS="$5"
	local LOCAL_SCRIPT="$6"
	local REMOTE_TEMP="./temp.sh"

	if [[ ! -f "$LOCAL_SCRIPT" ]]; then
		echo "Error: $LOCAL_SCRIPT not found."
		sleep 2
		return 1
	fi

	# Copy script to remote machine
	sshpass -p "$PASS" scp $SSH_OPTS -P "$PORT" "$LOCAL_SCRIPT" "$USER@$IP:$REMOTE_TEMP" >/dev/null 2>&1

	# Launch SSH terminal
	gnome-terminal --tab --title="$TITLE" -- bash -c \
	"sshpass -p '$PASS' ssh -t $SSH_OPTS $USER@$IP -p $PORT \"chmod +x $REMOTE_TEMP; $REMOTE_TEMP; rm -f $REMOTE_TEMP; bash\""
}

send_ssh_command()
{
	local IP="$1"
	local PORT="$2"
	local USER="$3"
	local PASS="$4"
	local COMMAND="$5"

	sshpass -p "$PASS" ssh -t $SSH_OPTS $USER@$IP -p $PORT "$COMMAND"
}

connect_server_vnc() {
	local TITLE="$1"
	local IP="$2"
	local PORT="$3"
	local USER="$4"
	local PASS="$5"

	if [[ "$TITLE" == "Android Server" ]]; then
		# Kill stale VNC servers and restart
		sshpass -p "$PASS" ssh $SSH_OPTS "$USER@$IP" -p "$PORT" "vncserver -kill :1; vncserver :1"
		sleep 5
		vncviewer "$IP:1" &
	elif [[ "$TITLE" == *"LLM Server"* ]]; then	
		# Kill stale VNC servers and restart, then login to session
		sshpass -p "$PASS" ssh $SSH_OPTS "$USER@$IP" -p "$PORT" "bash -c \"
		echo '$PASS' | sudo -S fuser -k 5901/tcp >/dev/null 2>&1
		rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 ~/.vnc/*.pid ~/.vnc/*.log
		vncserver :1 -geometry 1280x720 -localhost no -xstartup /etc/X11/Xsession
		sleep 5
		echo '$PASS' | sudo -S loginctl unlock-sessions >/dev/null 2>&1
		\""

		# Connect VNC viewer
		vncpasswd -f <<<"$PASS" > ~/.vnc_temp_pass && chmod 600 ~/.vnc_temp_pass
		nohup vncviewer -AutoSelect=0 -FullColor -passwd ~/.vnc_temp_pass "$IP:1" >/dev/null 2>&1 &
		(sleep 10 && rm -f ~/.vnc_temp_pass) &
	fi
}

switch_smart_plug() {
	local switch="$1"
	if [[ "$switch" == "on" ]]; then
		./switch_matter_smartplug 1
	fi
	if [[ "$switch" == "off" ]]; then
		./switch_matter_smartplug 0
	fi
}

# Main loop
ACTION=0
while [ "$ACTION" -ne 6 ]; do
	clear
	get_status "${SERVERS[@]}"

	# --- ACTION MENU ---
	echo "  ---------------- "
	echo "  CHOOSE OPERATION "
	echo "  ---------------- "
	echo "  1) Refresh status"
	echo "  2) Start server"
	echo "  3) New SSH connection"
	echo "  4) New VNC connection"
	echo "  5) Stop server"
	echo "  6) Restart Smart plug"
	echo "  7) Smart plug On"
	echo "  8) Smart plug Off"
	echo "  9) Exit"

	read -p "> " -t 15 ACTION || ACTION=1

	if [[ " $ACTION " != " 1 " ]] && [[ " $ACTION " != " 9" ]]; then
		# --- SELECTION MENU ---
		echo "Enter servers separated by space (e.g., 1 2 4) or 'all' or 'back':"
		read -p "> " SELECTION

		# --- PROCESS ---
		for s in "${SERVERS[@]}"; do
			IFS="|" read -r ID TITLE IP PORT USER PASS CMDSTOP MAC <<< "$s"

			if [[ "$SELECTION" != "back" ]]; then
				if [[ " $SELECTION " =~ " $ID " ]] || [[ "$SELECTION" == "all" ]]; then        
					echo -n "Checking $TITLE ($IP)... "
					if probe_ssh "$IP" "$PORT"; then
						# START
						if [[ " $ACTION " =~ " 2 " ]]; then
							connect_server "$TITLE" "$IP" "$PORT" "$USER" "$PASS" "${CURRENT_DIR}/server${SELECTION}_startup.sh"
						fi
						# SSH ONLY
						if [[ " $ACTION " =~ " 3 " ]]; then
							connect_server_ssh "$TITLE" "$IP" "$PORT" "$USER" "$PASS" "${CURRENT_DIR}/server${SELECTION}_startup.sh"
						fi
						# VNC ONLY
						if [[ " $ACTION " =~ " 4 " ]]; then
							connect_server_vnc "$TITLE" "$IP" "$PORT" "$USER" "$PASS"
						fi
						# STOP
						if [[ " $ACTION " =~ " 5 " ]]; then
							stop_server "$TITLE" "$IP" "$PORT" "$USER" "$PASS" "$CMDSTOP"
						fi
					else
						if [[ " $ACTION " =~ " 2 " ]]; then
							echo "OFFLINE -> Starting"

							#Wake on WLAN
							for i in {1..100}; do
								# Use -i to target the broadcast address of your subnet
								wakeonlan -i 192.168.1.255 "$MAC"
								SUCCESS=false
								if probe_ssh "$IP" "$PORT"; then
									connect_server "$TITLE" "$IP" "$PORT" "$USER" "$PASS" "${CURRENT_DIR}/server${SELECTION}_startup.sh"
									SUCCESS=true
									break
								fi						
							done

							if [ "$SUCCESS" = false ]; then
								echo "Timed out: Server did not respond to SSH in time."
							fi
						fi
					fi
				fi
			fi
		done
	fi
done

echo "Exiting..."
