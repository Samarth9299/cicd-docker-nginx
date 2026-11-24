#!/usr/bin/env bash
# One-time setup of a fresh Ubuntu 22.04/24.04 EC2 instance.
# Installs Docker, Nginx and Certbot, configures the reverse proxy and
# (optionally) a free Let's Encrypt certificate.
#
# Usage (on the server):
#   sudo ./setup-ec2.sh                       # HTTP only, use the public IP
#   sudo ./setup-ec2.sh app.example.com you@example.com   # with SSL
set -euo pipefail

DOMAIN="${1:-}"
EMAIL="${2:-}"
DEPLOY_USER="${SUDO_USER:-ubuntu}"

if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo." >&2
  exit 1
fi

echo "==> Installing Docker, Nginx, Certbot"
apt-get update -y
apt-get install -y docker.io nginx certbot python3-certbot-nginx curl
systemctl enable --now docker nginx

# Let the deploy user run docker without sudo (used by GitHub Actions over SSH)
usermod -aG docker "$DEPLOY_USER"

echo "==> Configuring Nginx reverse proxy"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVER_NAME="${DOMAIN:-_}"
sed "s/__SERVER_NAME__/${SERVER_NAME}/" "$SCRIPT_DIR/../nginx/app.conf" \
  > /etc/nginx/sites-available/app
ln -sf /etc/nginx/sites-available/app /etc/nginx/sites-enabled/app
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx

if [[ -n "$DOMAIN" ]]; then
  if [[ -z "$EMAIL" ]]; then
    echo "Pass an email for Let's Encrypt as the 2nd argument." >&2
    exit 1
  fi
  echo "==> Requesting Let's Encrypt certificate for $DOMAIN"
  # Your domain's DNS A record must already point to this server's public IP
  certbot --nginx -d "$DOMAIN" -m "$EMAIL" --agree-tos --non-interactive --redirect
fi

# The deploy script is copied here by setup and called by GitHub Actions
install -m 0755 "$SCRIPT_DIR/deploy.sh" /usr/local/bin/deploy-app

echo
echo "Done. Log out and back in once so '$DEPLOY_USER' picks up the docker group."
