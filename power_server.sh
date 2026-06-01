#!/data/data/com.termux/files/usr/bin/bash
TARGET=$1
ACTION=$2

# Ensure your Termux paths are active
export PATH=/data/data/com.termux/files/usr/bin:$PATH

if [ "$ACTION" == "on" ]; then
    # Wake up the Large LLM server using wakeonlan
    [ "$TARGET" == "large" ] && wakeonlan 11:22:33:44:55:66
elif [ "$ACTION" == "off" ]; then
    # Termux can use its local SSH keys to gracefully shut down the Proxmox/LLM node
    [ "$TARGET" == "large" ] && ssh -i $HOME/.ssh/id_rsa user@192.168.1.50 "sudo shutdown -h now"
fi
