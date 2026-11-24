"""Small Flask app deployed by the CI/CD pipeline.

Endpoints:
  /         - HTML page showing the deployed version
  /health   - health check used by Docker, the deploy script and Nginx monitoring
  /api/info - JSON with version, commit and hostname (handy for verifying deploys)
"""

import os
import socket
from datetime import datetime, timezone

from flask import Flask, jsonify

app = Flask(__name__)

APP_VERSION = os.getenv("APP_VERSION", "dev")
GIT_SHA = os.getenv("GIT_SHA", "local")
STARTED_AT = datetime.now(timezone.utc).isoformat(timespec="seconds")


@app.get("/")
def index():
    return (
        "<!doctype html><html><head><meta charset='utf-8'>"
        "<title>CI/CD Demo</title></head>"
        "<body style='font-family:sans-serif;margin:40px'>"
        "<h1>CI/CD Pipeline: GitHub Actions &rarr; Docker &rarr; EC2 + Nginx</h1>"
        f"<p>Version: <b>{APP_VERSION}</b> &middot; Commit: <b>{GIT_SHA[:7]}</b></p>"
        f"<p>Container: {socket.gethostname()} &middot; Started: {STARTED_AT}</p>"
        "</body></html>"
    )


@app.get("/health")
def health():
    return jsonify(status="ok"), 200


@app.get("/api/info")
def info():
    return jsonify(
        version=APP_VERSION,
        commit=GIT_SHA,
        hostname=socket.gethostname(),
        started_at=STARTED_AT,
    )


if __name__ == "__main__":
    # Local development only; production uses gunicorn (see Dockerfile)
    app.run(host="0.0.0.0", port=8000, debug=False)
