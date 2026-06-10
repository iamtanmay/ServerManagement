#!/usr/bin/env python3
"""
Homepage Server Management API
Generic endpoint: GET /<action>/<server_id>
Maps directly to: server_management_utilities.sh <server_id> <action>
Run in Termux: python server_management_api.py
"""
import os
import subprocess
import logging
from flask import Flask, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
HOME_DIR = "/data/data/com.termux/files/home"
SCRIPT = "/data/data/com.termux/files/home/ServerManagement/server_management_utilities.sh"

#File Server
# --- SIMPLE HTML TEMPLATE TO BROWSE DIRECTORIES ---
DIR_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title>Termux Home Index</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { font-family: sans-serif; padding: 20px; background: #1e1e2e; color: #cdd6f4; }
        h1 { color: #f5c2e7; }
        ul { list-style-type: none; padding: 0; }
        li { padding: 8px 0; border-bottom: 1px solid #313244; }
        a { color: #89b4fa; text-decoration: none; font-size: 18px; }
        a:hover { text-decoration: underline; color: #b4befe; }
        .back { color: #a6e3a1; font-weight: bold; }
    </style>
</head>
<body>
    <h1>Index of ~/{{ path }}</h1>
    <ul>
        {% if path %}
        <li><a class="back" href="/{{ parent }}">📁 .. (Up One Level)</a></li>
        {% endif %}
        {% for item in items %}
        <li>
            {% if item.is_dir %}📁{% else %}📄{% endif %}
            <a href="/{{ path }}{{ '/' if path else '' }}{{ item.name }}">{{ item.name }}</a>
        </li>
        {% endfor %}
    </ul>
</body>
</html>
"""

# --- CATCH-ALL ROUTE FOR SERVING THE FULL $HOME DIRECTORY ---
@app.route('/', defaults={'path': ''}, methods=["GET"])
@app.route('/<path:path>', methods=["GET"])
def serve_home(path: str):
    """Serve any file or browse any folder inside $HOME"""
    full_path = os.path.join(HOME_DIR, path)

    # 1. Security Check: Block directory traversal out of $HOME
    if not os.path.abspath(full_path).startswith(os.path.abspath(HOME_DIR)):
        return jsonify({"success": False, "output": "Access denied"}), 403

    # 2. Check if the target exists
    if not os.path.exists(full_path):
        return jsonify({"success": False, "output": f"Not found: {path}"}), 404

    # 3. If it is a directory, show a clickable browser interface
    if os.path.isdir(full_path):
        try:
            items = []
            for item in sorted(os.listdir(full_path)):
                items.append({
                    "name": item,
                    "is_dir": os.path.isdir(os.path.join(full_path, item))
                })
            parent = os.path.dirname(path) if path else ""
            return render_template_string(DIR_TEMPLATE, path=path, items=items, parent=parent)
        except Exception as e:
            return jsonify({"success": False, "output": str(e)}), 500

    # 4. If it is a file, serve it directly (e.g., render images, stream scripts)
    dir_name = os.path.dirname(full_path)
    file_name = os.path.basename(full_path)
    return send_from_directory(dir_name, file_name)

#Server Management
@app.route("/<action>/<int:server_id>", methods=["GET", "POST"])
def run_action(action: str, server_id: int):
    """Execute: SCRIPT <server_id> <action>"""
    cmd = [SCRIPT, action, str(server_id)]
    logging.info("Running: %s", " ".join(cmd))
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        success = result.returncode == 0
        output = (result.stdout + result.stderr).strip()
        logging.info("[id=%d] %s -> rc=%d", server_id, action, result.returncode)
        return jsonify({
            "server_id": server_id,
            "action": action,
            "success": success,
            "returncode": result.returncode,
            "output": output or ("OK" if success else "No output"),
        })
    except subprocess.TimeoutExpired:
        return jsonify({"server_id": server_id, "action": action, "success": False,
                        "returncode": -1, "output": "Script timed out after 30s"}), 504
    except FileNotFoundError:
        return jsonify({"server_id": server_id, "action": action, "success": False,
                        "returncode": -1, "output": f"Script not found: {SCRIPT}"}), 500
    except Exception as e:
        logging.exception("Unexpected error")
        return jsonify({"server_id": server_id, "action": action, "success": False,
                        "returncode": -1, "output": str(e)}), 500

#Health Check
@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok", "script": SCRIPT})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=9001, debug=False)
