termux-setup-storage
pkg install termux-api
pkg install termux-boot
mkdir -p ~/.termux/boot
printf "#!/data/data/com.termux/files/usr/bin/sh\ntermux-wake-lock\nsshd" > ~/.termux/boot/start-ssh.sh
chmod +x ~/.termux/boot/start-ssh.sh


#Matter Server


#Docker


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

nginx

#Tailscale


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

