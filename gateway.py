import subprocess
import re
from flask import Flask, render_template_string, jsonify

app = Flask(__name__)

def parse_servers_conf():
    servers = []
    try:
        with open("servers.conf", "r") as f:
            content = f.read()
            # Regex to extract strings inside the SERVERS=( ... ) array
            matches = re.findall(r"'(.*?)'", content, re.DOTALL)
            for entry in matches:
                parts = entry.split('|')
                if len(parts) >= 7:
                    servers.append({
                        "id": parts[0], "name": parts[1], "ip": parts[2],
                        "port": parts[3], "user": parts[4], "pass": parts[5],
                        "stop_cmd": parts[6], "mac": parts[7]
                    })
    except Exception as e:
        print(f"Error reading config: {e}")
    return servers

def check_status(ip, port):
    cmd = f"timeout 0.8 nc -z {ip} {port}"
    result = subprocess.run(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return "Online" if result.returncode == 0 else "Offline"

@app.route('/')
def index():
    return render_template_string('''
        <h1>Server Gateway</h1>
        <div id="status-list">Loading...</div>
        <script>
            async function updateUI() {
                const res = await fetch('/api/status');
                const data = await res.json();
                document.getElementById('status-list').innerHTML = data.map(s => `
                    <div style="margin-bottom: 15px; border-bottom: 1px solid #ccc; padding: 10px;">
                        <strong>${s.name}</strong> [${s.ip}] - 
                        <span style="color: ${s.status === 'Online' ? 'green' : 'red'}">${s.status}</span>
                        <br>
                        <button onclick="trigger('${s.id}', 'start')">Start (WOL)</button>
                        <button onclick="trigger('${s.id}', 'stop')">Stop</button>
                    </div>
                `).join('');
            }
            async function trigger(id, action) {
                const res = await fetch(`/api/action/${id}/${action}`, {method: 'POST'});
                alert(await res.text());
            }
            setInterval(updateUI, 2000);
            updateUI();
        </script>
    ''')

@app.route('/api/status')
def status_api():
    servers = parse_servers_conf()
    for s in servers:
        s['status'] = check_status(s['ip'], s['port'])
    return jsonify(servers)

@app.route('/api/action/<sid>/<action>', methods=['POST'])
def action_api(sid, action):
    servers = parse_servers_conf()
    s = next((srv for srv in servers if srv['id'] == sid), None)
    if not s: return "Server not found", 404

    if action == "start" and s['mac']:
        # Requires: pkg install wol
        subprocess.run(["wol", s['mac']])
        return f"WOL packet sent to {s['mac']}"
    
    elif action == "stop" and s['stop_cmd']:
        # Uses SSH to run the Stop Command
        ssh_cmd = f"sshpass -p '{s['pass']}' ssh -p {s['port']} -o StrictHostKeyChecking=no {s['user']}@{s['ip']} '{s['stop_cmd']}'"
        subprocess.run(ssh_cmd, shell=True)
        return f"Stop command sent: {s['stop_cmd']}"
    
    return "Action not supported or missing data", 400

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)

