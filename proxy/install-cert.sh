#!/usr/bin/env bash
set -e

# ========= Default Configuration ==========
CERTBOT_HOME="/opt/certbot-venv"
PROVIDER=""
DOMAIN="example.com"
EMAIL="admin@example.com"

# Aliyun defaults
ALIYUN_ACCESS_KEY_ID=""
ALIYUN_ACCESS_KEY_SECRET=""

# Azure defaults
AZURE_CLIENT_ID=""
AZURE_SECRET=""
AZURE_TENANT_ID=""
AZURE_SUBSCRIPTION_ID=""
AZURE_RESOURCE_GROUP=""

# ========= Help Message ==========
print_help() {
  echo "Usage: $0 --provider aliyun|azure --domain DOMAIN --email EMAIL [OPTIONS]"
  echo ""
  echo "Required:"
  echo "  --provider                 DNS provider to use: aliyun or azure"
  echo "  --domain                   The base domain (e.g., example.com)"
  echo "  --email                    Email for Let's Encrypt registration"
  echo ""
  echo "Aliyun-specific options:"
  echo "  --aliyun-access-key-id     Your Aliyun access key ID"
  echo "  --aliyun-access-key-secret Your Aliyun access key secret"
  echo ""
  echo "Azure-specific options:"
  echo "  --azure-client-id          Azure Service Principal client ID"
  echo "  --azure-secret             Azure Service Principal secret"
  echo "  --azure-tenant-id          Azure tenant ID"
  echo "  --azure-subscription-id    Azure subscription ID"
  echo "  --azure-resource-group     Azure DNS zone resource group"
  echo ""
  echo "General:"
  echo "  -h, --help                 Show this help message and exit"
  echo ""
  echo "Example (Aliyun):"
  echo "  $0 --provider aliyun \\"
  echo "    --domain example.com \\"
  echo "    --email admin@example.com \\"
  echo "    --aliyun-access-key-id YOUR_KEY \\"
  echo "    --aliyun-access-key-secret YOUR_SECRET"
  echo ""
  echo "Example (Azure):"
  echo "  $0 --provider azure \\"
  echo "    --domain example.com \\"
  echo "    --email admin@example.com \\"
  echo "    --azure-client-id ID \\"
  echo "    --azure-secret SECRET \\"
  echo "    --azure-tenant-id TENANT \\"
  echo "    --azure-subscription-id SUB_ID \\"
  echo "    --azure-resource-group RG_NAME"
  echo ""
}

# ========= Parse Arguments ==========
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) print_help; exit 0 ;;
    --provider) PROVIDER="$2"; shift 2 ;;
    --domain) DOMAIN="$2"; shift 2 ;;
    --email) EMAIL="$2"; shift 2 ;;

    --aliyun-access-key-id) ALIYUN_ACCESS_KEY_ID="$2"; shift 2 ;;
    --aliyun-access-key-secret) ALIYUN_ACCESS_KEY_SECRET="$2"; shift 2 ;;

    --azure-client-id) AZURE_CLIENT_ID="$2"; shift 2 ;;
    --azure-secret) AZURE_SECRET="$2"; shift 2 ;;
    --azure-tenant-id) AZURE_TENANT_ID="$2"; shift 2 ;;
    --azure-subscription-id) AZURE_SUBSCRIPTION_ID="$2"; shift 2 ;;
    --azure-resource-group) AZURE_RESOURCE_GROUP="$2"; shift 2 ;;

    *) echo "Unknown option: $1"; echo ""; print_help; exit 1 ;;
  esac
done

# ========= Check Required Parameters ==========
if [[ -z "$PROVIDER" || -z "$DOMAIN" || -z "$EMAIL" ]]; then
  echo "❌ Missing required parameters: --provider, --domain, --email"
  echo ""
  print_help
  exit 1
fi

# ========= Install Certbot and Plugin ==========
apt update
apt install -y python3-venv unzip curl

python3 -m venv "${CERTBOT_HOME}"
source "${CERTBOT_HOME}/bin/activate"
pip install --upgrade pip

# ========= Handle Provider Logic ==========
mkdir -p ~/.secrets/certbot

if [[ "$PROVIDER" == "aliyun" ]]; then
  pip install -y --break-system-packages --ignore-installed certbot certbot-dns-aliyun

  cat > ~/.secrets/certbot/aliyun.ini <<EOF
dns_aliyun_access_key = ${ALIYUN_ACCESS_KEY_ID}
dns_aliyun_access_key_secret = ${ALIYUN_ACCESS_KEY_SECRET}
EOF
  chmod 600 ~/.secrets/certbot/aliyun.ini

  certbot certonly \
    --authenticator dns-aliyun \
    --dns-aliyun-credentials ~/.secrets/certbot/aliyun.ini \
    --dns-aliyun-propagation-seconds 60 \
    -d "*.${DOMAIN}" -d "${DOMAIN}" \
    --agree-tos --non-interactive --email "${EMAIL}" \
    --server https://acme-v02.api.letsencrypt.org/directory

elif [[ "$PROVIDER" == "azure" ]]; then
  pip install -y --break-system-packages --ignore-installed azure-mgmt-dns==8.2.0 certbot certbot-dns-azure

  cat > ~/.secrets/certbot/azure.ini <<EOF
dns_azure_sp_client_id = ${AZURE_CLIENT_ID}
dns_azure_sp_client_secret = ${AZURE_SECRET}
dns_azure_tenant_id = ${AZURE_TENANT_ID}
dns_azure_environment = "AzurePublicCloud"
dns_azure_zone1 = ${DOMAIN}:/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}
EOF
  chmod 600 ~/.secrets/certbot/azure.ini

  certbot certonly \
    --authenticator dns-azure \
    --dns-azure-credentials ~/.secrets/certbot/azure.ini \
    --dns-azure-propagation-seconds 60 \
    -d "*.${DOMAIN}" -d "${DOMAIN}" \
    --agree-tos --non-interactive --email "${EMAIL}" \
    --server https://acme-v02.api.letsencrypt.org/directory

else
  echo "❌ Unsupported provider: $PROVIDER"
  deactivate
  exit 1
fi

# ========= Result ==========
if [ -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]; then
  echo "✅ Certificate successfully issued for ${DOMAIN}"
  echo "  Cert Path: /etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
  echo "  Key Path : /etc/letsencrypt/live/${DOMAIN}/privkey.pem"
else
  echo "❌ Certificate request failed for ${DOMAIN}. Please check the logs."
fi

deactivate
