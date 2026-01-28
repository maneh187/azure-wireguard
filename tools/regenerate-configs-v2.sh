#!/bin/bash

################################################################################
# WireGuard Config Regeneration Script v2
# Uses session-based authentication for wg-easy API
################################################################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }

# Get VM IP
PUBLIC_IP=$(az network public-ip show \
    --resource-group rg-wireguard-vpn \
    --name wireguard-vm-ip \
    --query 'ipAddress' -o tsv)

print_info "VM Public IP: ${PUBLIC_IP}"

# Prompt for password
echo ""
read -s -p "Enter WireGuard UI password: " WG_PASSWORD
echo ""

if [ -z "${WG_PASSWORD}" ]; then
    print_error "Password cannot be empty"
    exit 1
fi

API_URL="http://${PUBLIC_IP}:51821/api"
COOKIE_FILE="/tmp/wg-cookies.txt"

print_info "Authenticating..."

# Login and get session cookie
LOGIN_RESPONSE=$(curl -s -c "${COOKIE_FILE}" -X POST "${API_URL}/session" \
    -H "Content-Type: application/json" \
    -d "{\"password\":\"${WG_PASSWORD}\"}")

if echo "$LOGIN_RESPONSE" | grep -q '"success":true'; then
    print_success "Authentication successful"
else
    print_error "Authentication failed. Please check your password."
    rm -f "${COOKIE_FILE}"
    exit 1
fi

# Get list of existing clients
print_info "Fetching client list..."
CLIENTS_JSON=$(curl -s -b "${COOKIE_FILE}" "${API_URL}/wireguard/client")

# Check if we got clients
CLIENT_COUNT=$(echo "$CLIENTS_JSON" | jq '. | length' 2>/dev/null || echo "0")

if [ "$CLIENT_COUNT" -eq 0 ]; then
    print_warning "No clients found."
    print_info "Please create clients manually in the Web UI: ${API_URL%%/api}"
    print_info "Then run this script again to download their configurations."
    rm -f "${COOKIE_FILE}"
    exit 0
fi

if [ "$CLIENT_COUNT" -eq 0 ]; then
    print_info "No clients available. Exiting."
    rm -f "${COOKIE_FILE}"
    exit 0
fi

# Create output directory
OUTPUT_DIR="./wireguard-configs-$(date +%Y%m%d-%H%M%S)"
mkdir -p "${OUTPUT_DIR}"
print_info "Saving configurations to: ${OUTPUT_DIR}"
print_success "Found ${CLIENT_COUNT} client(s)"

# Download configs for each client
echo ""
print_info "Downloading configurations..."
echo ""

# Parse client IDs and names
echo "$CLIENTS_JSON" | jq -r '.[] | "\(.id)|\(.name)"' | while IFS='|' read -r CLIENT_ID CLIENT_NAME; do
    print_info "Downloading ${CLIENT_NAME}..."

    # Get configuration
    CONFIG=$(curl -s -b "${COOKIE_FILE}" "${API_URL}/wireguard/client/${CLIENT_ID}/configuration" 2>/dev/null)

    if [ -n "$CONFIG" ] && [ "$CONFIG" != "null" ] && [ "$CONFIG" != "" ]; then
        echo "$CONFIG" > "${OUTPUT_DIR}/${CLIENT_NAME}.conf"
        print_success "Configuration saved: ${CLIENT_NAME}.conf"

        # Get QR code
        curl -s -b "${COOKIE_FILE}" "${API_URL}/wireguard/client/${CLIENT_ID}/qrcode.svg" \
            -o "${OUTPUT_DIR}/${CLIENT_NAME}-qr.svg" 2>/dev/null

        if [ -f "${OUTPUT_DIR}/${CLIENT_NAME}-qr.svg" ] && [ -s "${OUTPUT_DIR}/${CLIENT_NAME}-qr.svg" ]; then
            print_success "QR code saved: ${CLIENT_NAME}-qr.svg"
        fi
    else
        print_error "Failed to download config for ${CLIENT_NAME}"
    fi

    sleep 0.5
done

# Create README
cat > "${OUTPUT_DIR}/README.txt" << EOF
WireGuard VPN Configuration Files
Generated: $(date)
=================================

This directory contains WireGuard configuration files for ${CLIENT_COUNT} client(s).

Files for each client:
  - client-name.conf     : WireGuard configuration file
  - client-name-qr.svg   : QR code (scan with mobile WireGuard app)

How to use:

Desktop (Windows/Mac/Linux):
  1. Install WireGuard from https://www.wireguard.com/install/
  2. Import the .conf file
  3. Click "Activate" to connect

Mobile (iOS/Android):
  1. Install WireGuard app from App Store / Google Play
  2. Tap "+" to add tunnel
  3. Select "Create from QR code"
  4. Scan the QR code from the -qr.svg file

WireGuard Server: ${PUBLIC_IP}:51820
Web UI: http://${PUBLIC_IP}:51821
Password: <YOUR_WEB_UI_PASSWORD>

=================================
EOF

# Cleanup
rm -f "${COOKIE_FILE}"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_success "All configurations downloaded!"
echo ""
print_info "Location: ${OUTPUT_DIR}"
echo ""
print_info "You can now:"
print_info "  - Import .conf files on desktop WireGuard clients"
print_info "  - Scan QR codes with mobile WireGuard app"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
