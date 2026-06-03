#!/usr/bin/env python3
"""
Homepage Server Management API
Generic endpoint: GET /<action>/<server_id>
Maps directly to: server_management_utilities.sh <server_id> <action>

Run in Termux: python server_management_api.py
"""

import subprocess
import logging
from flask import Flask, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

SCRIPT = "/data/data/com.termux/files/home/ServerManagement/server_management_utilities.sh"


@app.route("/<action>/<int:server_id>", methods=["GET", "POST"])
def run_action(action: str, server_id: int):
    """Execute: SCRIPT <server_id> <action>"""
    cmd = [SCRIPT, str(server_id), action]
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


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok", "script": SCRIPT})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=9001, debug=False)
