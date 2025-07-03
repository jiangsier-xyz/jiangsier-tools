#!/usr/bin/env bash

set -e

# ========== Default Configuration ==========
HOSTS=("nas.example.com")
FRP_DASHBOARD_HOST="frp.example.com"
FRP_VERSION="0.62.1"
INSTALL_DIR="/opt/frp"

FRPS_PORT=17000
FRPS_VHOST_HTTP_PORT=18080
FRPS_VHOST_HTTPS_PORT=18443
FRPS_DASHBOARD_PORT=17500
FRPS_DASHBOARD_USER="admin"
FRPS_DASHBOARD_PASS="frp@imp123"
FRPS_TOKEN="frp-064797"
SSH_REMOTE_USER="jiangsier"
SSH_REMOTE_PORT=18022

NGINX_AVAILABLE_PATH="/etc/nginx/sites-available"
NGINX_ENABLED_PATH="/etc/nginx/sites-enabled"

# ========== Usage Help ==========
print_help() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  --hosts HOST1,HOST2,..."
  echo "  --frp-dashboard-host HOST"
  echo "  --frp-version VERSION"
  echo "  --install-dir PATH"
  echo "  --frps-port PORT"
  echo "  --http-port PORT"
  echo "  --https-port PORT"
  echo "  --dashboard-port PORT"
  echo "  --dashboard-user USER"
  echo "  --dashboard-pass PASSWORD"
  echo "  --token TOKEN"
  echo "  --ssh-user USER"
  echo "  --ssh-port PORT"
  echo "  -h, --help                Show this help message"
  echo ""
  echo "Example:"
  echo "  $0 --hosts nas.example.com \\"
  echo "    --frp-dashboard-host frp.example.com \\"
  echo "    --frp-version 0.62.1 \\"
  echo "    --install-dir /opt/frp \\"
  echo "    --frps-port 17000 \\"
  echo "    --http-port 18080 \\"
  echo "    --https-port 18443 \\"
  echo "    --dashboard-port 17500 \\"
  echo "    --dashboard-user admin \\"
  echo "    --dashboard-pass pass123 \\"
  echo "    --token mytoken \\"
  echo "    --ssh-user user \\"
  echo "    --ssh-port 2222"

  exit 0
}

# ========== Parse Arguments ==========
while [[ $# -gt 0 ]]; do
  case "$1" in
    --hosts) IFS=',' read -ra HOSTS <<< "$2"; shift 2 ;;
    --frp-dashboard-host) FRP_DASHBOARD_HOST="$2"; shift 2 ;;
    --frp-version) FRP_VERSION="$2"; shift 2 ;;
    --install-dir) INSTALL_DIR="$2"; shift 2 ;;
    --frps-port) FRPS_PORT="$2"; shift 2 ;;
    --http-port) FRPS_VHOST_HTTP_PORT="$2"; shift 2 ;;
    --https-port) FRPS_VHOST_HTTPS_PORT="$2"; shift 2 ;;
    --dashboard-port) FRPS_DASHBOARD_PORT="$2"; shift 2 ;;
    --dashboard-user) FRPS_DASHBOARD_USER="$2"; shift 2 ;;
    --dashboard-pass) FRPS_DASHBOARD_PASS="$2"; shift 2 ;;
    --token) FRPS_TOKEN="$2"; shift 2 ;;
    --ssh-user) SSH_REMOTE_USER="$2"; shift 2 ;;
    --ssh-port) SSH_REMOTE_PORT="$2"; shift 2 ;;
    -h|--help) print_help ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

DOMAIN="${HOSTS[0]#*.}"

# ========== Install Dependencies ==========
apt update
apt install -y nginx curl unzip

# ========== Download and Install frps ==========
cd /opt
curl -LO https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_amd64.tar.gz
tar -xzf frp_${FRP_VERSION}_linux_amd64.tar.gz
rm -f frp_${FRP_VERSION}_linux_amd64.tar.gz
mv frp_${FRP_VERSION}_linux_amd64 frp

# ========== Configure frps ==========
sudo mkdir -p "${INSTALL_DIR}"
sudo cat > ${INSTALL_DIR}/frps.yml <<EOF
bindPort: ${FRPS_PORT}
vhostHTTPPort: ${FRPS_VHOST_HTTP_PORT}
vhostHTTPSPort: ${FRPS_VHOST_HTTPS_PORT}

webServer:
  port: ${FRPS_DASHBOARD_PORT}
  user: ${FRPS_DASHBOARD_USER}
  password: ${FRPS_DASHBOARD_PASS}

log:
  to: /var/log/frps.log
  level: info

auth:
  method: token
  token: ${FRPS_TOKEN}

transport:
  maxPoolCount: 5
EOF

# ========== Setup systemd service ==========
sudo cat > /etc/systemd/system/frps.service <<EOF
[Unit]
Description=FRP Server Service
After=network.target

[Service]
Type=simple
ExecStart=${INSTALL_DIR}/frps --config=${INSTALL_DIR}/frps.yml
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable frps
sudo systemctl restart frps

# ========== Configure Nginx for Hosts ==========
for HOST in "${HOSTS[@]}"; do
cat > ${NGINX_AVAILABLE_PATH}/${HOST} <<EOF
server {
    listen 443 ssl;
    server_name ${HOST};

    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:${FRPS_VHOST_HTTP_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

server {
    listen 80;
    server_name ${HOST};
    return 301 https://\$host\$request_uri;
}
EOF

  ln -sf ${NGINX_AVAILABLE_PATH}/${HOST} ${NGINX_ENABLED_PATH}
done

# ========== Configure Nginx for Dashboard ==========
cat > ${NGINX_AVAILABLE_PATH}/${FRP_DASHBOARD_HOST} <<EOF
server {
    listen 443 ssl;
    server_name ${FRP_DASHBOARD_HOST};

    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:${FRPS_DASHBOARD_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

server {
    listen 80;
    server_name ${FRP_DASHBOARD_HOST};
    return 301 https://\$host\$request_uri;
}
EOF

ln -sf ${NGINX_AVAILABLE_PATH}/${FRP_DASHBOARD_HOST} ${NGINX_ENABLED_PATH}

# ========== Reload Nginx ==========
nginx -t && sudo systemctl reload nginx

# ========== Final Output ==========
HOST_URLS=()
for HOST in "${HOSTS[@]}"; do
  HOST_URLS+=("https://${HOST}")
done

echo "✅ FRP server successfully installed"
echo "🔐 HTTPS hosts configured: ${HOST_URLS[*]}"
echo "🚀 SSH access: ssh -p ${SSH_REMOTE_PORT} ${SSH_REMOTE_USER}@${HOSTS[0]}"
echo "📊 Dashboard: https://${FRP_DASHBOARD_HOST} (user: ${FRPS_DASHBOARD_USER})"
