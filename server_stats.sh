#!/data/data/com.termux/files/usr/bin/bash
export PATH=/data/data/com.termux/files/usr/bin:$PATH

# Ping the server first to avoid SSH hanging if it is dead
if ! ping -c 1 -W 1 192.168.1.103 > /dev/null 2>&1; then
    echo "LLM Small: Offline"
else
    # Pull current active status or VRAM via remote SSH command execution
    MODEL=$(ssh -i $HOME/.ssh/id_rsa user@192.168.1.103 "curl -s http://localhost:11434/api/tags | jq -r '.models[0].name'" 2>/dev/null)
    echo "Loaded Model: ${MODEL:-None}"
fi
