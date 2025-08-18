#!/usr/bin/env bash

set -e

# ========== Default Configuration ==========
FRP_VERSION="0.62.1"
FRP_DIR="/opt/frp"
FRPS_SERVER_ADDR="nas.example.com"
FRPS_SERVER_PORT=17000
FRPS_TOKEN="mytoken"
LOCAL_IP="127.0.0.1"
SSH_REMOTE_PORT=18022
NAS_LOCAL_PORT=9999
WEB_DOMAIN="nas.example.com"

# ========== Constants ==========
FRP_TAR="frp_${FRP_VERSION}_linux_amd64.tar.gz"
FRP_URL="https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/${FRP_TAR}"
FRPC_BIN="${FRP_DIR}/frpc"
FRPC_CONF="${FRP_DIR}/frpc.yml"
SYSTEMD_SERVICE="/etc/systemd/system/frpc.service"

# ========== Parse Arguments ==========
print_help() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  --frp-version VERSION"
  echo "  --install-dir DIR"
  echo "  --server-addr DOMAIN"
  echo "  --server-port PORT"
  echo "  --token TOKEN"
  echo "  --local-ip IP"
  echo "  --ssh-port PORT"
  echo "  --nas-port PORT"
  echo "  --web-domain DOMAIN"
  echo "  -h, --help"
  echo ""
  echo "Example:"
  echo "  $0 --frp-version 0.62.1 \\"
  echo "    --install-dir /opt/frp \\"
  echo "    --server-addr nas.example.com \\"
  echo "    --server-port 17000 \\"
  echo "    --token frp-token \\"
  echo "    --local-ip 127.0.0.1 \\"
  echo "    --ssh-port 18022 \\"
  echo "    --nas-port 9999 \\"
  echo "    --web-domain nas.example.com"
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --frp-version) FRP_VERSION="$2"; shift 2 ;;
    --install-dir) FRP_DIR="$2"; shift 2 ;;
    --server-addr) FRPS_SERVER_ADDR="$2"; shift 2 ;;
    --server-port) FRPS_SERVER_PORT="$2"; shift 2 ;;
    --token) FRPS_TOKEN="$2"; shift 2 ;;
    --local-ip) LOCAL_IP="$2"; shift 2 ;;
    --ssh-port) SSH_REMOTE_PORT="$2"; shift 2 ;;
    --nas-port) NAS_LOCAL_PORT="$2"; shift 2 ;;
    --web-domain) WEB_DOMAIN="$2"; shift 2 ;;
    -h|--help) print_help ;;
    *) echo "Unknown option: $1"; print_help ;;
  esac
done

# Update derived constants
FRP_TAR="frp_${FRP_VERSION}_linux_amd64.tar.gz"
FRP_URL="https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/${FRP_TAR}"
FRPC_BIN="${FRP_DIR}/frpc"
FRPC_CONF="${FRP_DIR}/frpc.yml"

# ========== Check root ==========
if [[ $EUID -ne 0 ]]; then
  echo "❌ Please run this script as root (use sudo)."
  exit 1
fi

# ========== Install required tools ==========
apt update -y
apt install -y curl tar

# ========== Download and install frpc ==========
mkdir -p "$FRP_DIR"
cd /tmp || exit
echo "📦 Downloading frpc..."
curl -LO "$FRP_URL"
tar -xzf "$FRP_TAR"
cp "frp_${FRP_VERSION}_linux_amd64/frpc" "$FRPC_BIN"
chmod +x "$FRPC_BIN"

# ========== Write frpc config ==========
cat > "$FRPC_CONF" <<EOF
serverAddr: ${FRPS_SERVER_ADDR}
serverPort: ${FRPS_SERVER_PORT}

auth:
  method: token
  token: ${FRPS_TOKEN}

log:
  to: /var/log/frpc.log
  level: info

proxies:
  - name: ssh
    type: tcp
    localIP: ${LOCAL_IP}
    localPort: 22
    remotePort: ${SSH_REMOTE_PORT}

  - name: nas-web
    type: http
    localIP: ${LOCAL_IP}
    localPort: ${NAS_LOCAL_PORT}
    customDomains:
      - ${WEB_DOMAIN}
EOF

echo "✅ Configuration written to ${FRPC_CONF}"

# ========== Write systemd unit ==========
cat > "$SYSTEMD_SERVICE" <<EOF
[Unit]
Description=FRP Client Service
After=network.target

[Service]
ExecStart=${FRPC_BIN} -c ${FRPC_CONF}
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# ========== Start frpc ==========
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable frpc
systemctl restart frpc

echo "✅ frpc service started and enabled"
systemctl status frpc --no-pager
