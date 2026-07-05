#!/bin/bash

#Usage
#./server_management_utilities.sh <IP> <Function>
# Functions - 
#	probe_ssh
#	get_status
#	wake_server
#	stop_server
#	send_ssh_command
#	connect_server
#	connect_server_ssh
#	connect_server_vnc
#	switch_smart_plug_on
#	switch_smart_plug_off
#	switch_smart_plug_restart

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <Function> <ServerID> [Optional: <Command>]"
    echo "Functions:"
    echo "	probe_ssh"
    echo "	get_status"
    echo "	wake_server"
    echo "	stop_server"
    echo "	send_ssh_command"
    echo "	connect_server"
    echo "	connect_server_ssh"
    echo "	connect_server_vnc"
    echo "	switch_smart_plug_on"
    echo "	switch_smart_plug_off"
    echo "	switch_smart_plug_restart"
    exit 1
fi

# Load server configuration


#Get directory of this script
CURRENT_DIR="$(dirname "$0")"
CONFIG_FILE="${CURRENT_DIR}/servers.conf"
SMART_PLUG_STATUS=""


if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    echo "Error: $CONFIG_FILE not found."
    exit 1
fi

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
	echo "  $SMART_PLUG_STATUS"
}

# Suspend or PowerOff a server (Termux/Background Safe)
stop_server() {
	local TITLE="$1"
	local IP="$2"
	local PORT="$3"
	local USER="$4"
	local PASS="$5"
	local CMDSTOP="$6"

	# Execute the SSH command silently in the background without needing a Linux GUI
	sshpass -p '$PASS' ssh $SSH_OPTS "$USER@$IP" -p "$PORT" "echo '$PASS' | $CMDSTOP" > /dev/null 2>&1 &
}


# Wakeup a server
wake_server() {
	local TITLE="$1"
	local IP="$2"
	local PORT="$3"
	local USER="$4"
	local PASS="$5"
	local MAC="$6"

	for i in {1..100}; do
		# Use -i to target the broadcast address of your subnet
		wakeonlan -i 192.168.1.255 "$MAC"
		SUCCESS=false
		if probe_ssh "$IP" "$PORT"; then
			SUCCESS=true
			break
		fi						
	done
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
	"sshpass -p '$PASS' ssh -t $SSH_OPTS $USER@$IP -p $PORT \"chmod +x $REMOTE_TEMP; $REMOTE_TEMP $PASS; rm -f $REMOTE_TEMP; bash\""
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
	local script_dir
	script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

	echo "Debug: Looking for script in $script_dir"

	case "$switch" in
		"on")     "${script_dir}/switch_matter_smartplug.sh" 1 ;;
		"off")    "${script_dir}/switch_matter_smartplug.sh" 0 ;;
		"status") "${script_dir}/switch_matter_smartplug.sh" -1 ;;
		*)        echo "Error: Invalid option '$switch'. Use on|off|status." >&2; return 1 ;;
	esac
}

#Main

for s in "${SERVERS[@]}"; do
	IFS="|" read -r ID TITLE IP PORT USER PASS CMDSTOP MAC <<< "$s"

	if [[ " $2 " == " $ID " ]]; then
		if [[ "$1" == "probe_ssh" ]]; then
			probe_ssh "$IP" "$PORT"
		elif [[ "$1" == "get_status" ]]; then
			get_status "${SERVERS[@]}"
		elif [[ "$1" == "wake_server" ]]; then
			wake_server "$TITLE" "$IP" "$PORT" "$USER" "$PASS" "$MAC"
		elif [[ "$1" == "stop_server" ]]; then
			stop_server "$TITLE" "$IP" "$PORT" "$USER" "$PASS" "$CMDSTOP"
		elif [[ "$1" == "send_ssh_command" ]]; then
			send_ssh_command "$IP" "$PORT" "$USER" "$PASS" "$3"
		elif [[ "$1" == "connect_server" ]]; then
			connect_server "$TITLE" "$IP" "$PORT" "$USER" "$PASS" "${CURRENT_DIR}/server${SELECTION}_startup.sh"
		elif [[ "$1" == "connect_server_ssh" ]]; then
			connect_server_ssh "$TITLE" "$IP" "$PORT" "$USER" "$PASS" "${CURRENT_DIR}/server${SELECTION}_startup.sh"
		elif [[ "$1" == "connect_server_vnc" ]]; then
			connect_server_vnc "$TITLE" "$IP" "$PORT" "$USER" "$PASS"
		elif [[ "$1" == "switch_smart_plug_on" ]]; then
			switch_smart_plug "on"
		elif [[ "$1" == "switch_smart_plug_off" ]]; then
			switch_smart_plug "off"
		elif [[ "$1" == "switch_smart_plug_restart" ]]; then
			switch_smart_plug "off"
			sleep 5
			switch_smart_plug "on"
		fi
	fi
done
