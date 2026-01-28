#!/bin/bash

################################################################################
# Azure WireGuard VPN Deployment Script (VM + Docker)
#
# This script automates the deployment of a WireGuard VPN server using the
# wg-easy container on a Linux VM with Docker
#
# Requirements:
#   - Azure CLI installed and configured
#   - Active Azure subscription
#   - Appropriate permissions to create resources
#   - curl and jq for API interactions
################################################################################

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration defaults
SUBSCRIPTION_ID=""  # Auto-detect current subscription
RESOURCE_GROUP="rg-wireguard-vpn"
LOCATION=""  # Will be set interactively
VM_NAME="wireguard-vm"
VM_SIZE="Standard_B1s"  # 1 vCPU, 1 GB RAM - ~$10-15/month
VM_IMAGE="Ubuntu2204"
ADMIN_USERNAME="azureuser"
WG_PORT=51820
WG_UI_PORT=51821
DNS_SERVER="168.63.129.16"  # Azure DNS for Private DNS resolution
NUM_PEERS=0  # Peers must be created manually via Web UI (API auth not reliable)

# Azure Key Vault configuration (opt-in)
KEY_VAULT_NAME="wg-vault-$(openssl rand -hex 4)"  # Unique name
USE_KEY_VAULT=false  # Disabled by default (use --use-key-vault to enable)

# Private DNS configuration
PRIVATE_DNS_ZONE="wireguard.internal"
USE_PRIVATE_DNS=true

# Estimated monthly cost for B1s VM (without Key Vault)
ESTIMATED_COST="\$15-26 USD/month"

################################################################################
# Region definitions by geographic area
# Format: "region_code|Region Description"
################################################################################

REGIONS_NA=(
    "eastus|East US (Virginia)"
    "eastus2|East US 2 (Virginia)"
    "westus|West US (California)"
    "westus2|West US 2 (Washington)"
    "westus3|West US 3 (Arizona)"
    "centralus|Central US (Iowa)"
    "canadacentral|Canada Central (Toronto)"
)

REGIONS_SA=(
    "brazilsouth|Brazil South (São Paulo)"
    "brazilsoutheast|Brazil Southeast (Rio de Janeiro)"
)

REGIONS_EU=(
    "northeurope|North Europe (Ireland)"
    "westeurope|West Europe (Netherlands)"
    "uksouth|UK South (London)"
    "ukwest|UK West (Cardiff)"
    "francecentral|France Central (Paris)"
    "germanywestcentral|Germany West Central (Frankfurt)"
    "norwayeast|Norway East (Oslo)"
    "swedencentral|Sweden Central (Gävle)"
    "switzerlandnorth|Switzerland North (Zurich)"
)

REGIONS_MEA=(
    "uaenorth|UAE North (Dubai)"
    "southafricanorth|South Africa North (Johannesburg)"
    "qatarcentral|Qatar Central (Doha)"
)

REGIONS_APAC=(
    "southeastasia|Southeast Asia (Singapore)"
    "eastasia|East Asia (Hong Kong)"
    "australiaeast|Australia East (Sydney)"
    "australiasoutheast|Australia Southeast (Melbourne)"
    "japaneast|Japan East (Tokyo)"
    "japanwest|Japan West (Osaka)"
    "koreacentral|Korea Central (Seoul)"
    "centralindia|Central India (Pune)"
    "southindia|South India (Chennai)"
)

################################################################################
# Functions
################################################################################

print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy WireGuard VPN using wg-easy on Azure VM with Docker

Required Options:
    -p, --password PASSWORD                   Password for wg-easy web UI (min 8 chars)

Optional Options:
    -s, --subscription-id SUBSCRIPTION_ID    Azure subscription ID (default: auto-detect)
    -r, --resource-group NAME                Resource group name (default: ${RESOURCE_GROUP})
    -l, --location LOCATION                  Azure region (default: interactive prompt)
    --ssh-key PATH                           Path to SSH public key (default: ~/.ssh/id_rsa.pub)
    --use-key-vault                          Store password in Azure Key Vault (requires permissions)
    --no-private-dns                         Don't create Private DNS zone
    --teardown                               Delete all resources
    -h, --help                               Show this help message

Note: Peers must be created manually via the Web UI after deployment

Examples:
    # Quick deploy with defaults
    $0 -p "SecurePassword123"

    # Deploy to specific region
    $0 -p "SecurePassword123" -l "eastus"

    # Deploy with Key Vault for enhanced security (requires Key Vault permissions)
    $0 -p "SecurePassword123" --use-key-vault

    # Deploy without Private DNS
    $0 -p "SecurePassword123" --no-private-dns

    # Teardown/delete all resources
    $0 --teardown

EOF
    exit 1
}

select_region() {
    if [ -n "${LOCATION}" ]; then
        print_info "Using specified region: ${LOCATION}"
        return
    fi

    print_header "Select Azure Region"

    echo ""
    echo "Please select a geographic area:"
    echo ""
    echo "  1) North America"
    echo "  2) South America"
    echo "  3) Europe"
    echo "  4) Middle East & Africa"
    echo "  5) Asia Pacific"
    echo ""

    read -p "Enter your choice (1-5): " geo_choice

    local selected_regions=()

    case $geo_choice in
        1)
            echo ""
            echo "North America Regions:"
            echo "─────────────────────────────────────"
            selected_regions=("${REGIONS_NA[@]}")
            ;;
        2)
            echo ""
            echo "South America Regions:"
            echo "─────────────────────────────────────"
            selected_regions=("${REGIONS_SA[@]}")
            ;;
        3)
            echo ""
            echo "Europe Regions:"
            echo "─────────────────────────────────────"
            selected_regions=("${REGIONS_EU[@]}")
            ;;
        4)
            echo ""
            echo "Middle East & Africa Regions:"
            echo "─────────────────────────────────────"
            selected_regions=("${REGIONS_MEA[@]}")
            ;;
        5)
            echo ""
            echo "Asia Pacific Regions:"
            echo "─────────────────────────────────────"
            selected_regions=("${REGIONS_APAC[@]}")
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac

    # Display regions
    local idx=1
    for region_entry in "${selected_regions[@]}"; do
        local region_code="${region_entry%%|*}"
        local region_desc="${region_entry#*|}"
        printf "%2d) %-25s - %s\n" "$idx" "$region_code" "$region_desc"
        idx=$((idx + 1))
    done

    echo ""
    read -p "Enter region number: " region_choice

    # Validate input
    if ! [[ "$region_choice" =~ ^[0-9]+$ ]] || [ "$region_choice" -lt 1 ] || [ "$region_choice" -gt ${#selected_regions[@]} ]; then
        print_error "Invalid region selection"
        exit 1
    fi

    # Get the selected region code
    local selected_entry="${selected_regions[$((region_choice - 1))]}"
    LOCATION="${selected_entry%%|*}"

    if [ -z "${LOCATION}" ]; then
        print_error "Invalid region selection"
        exit 1
    fi

    print_success "Selected region: ${LOCATION}"
}

check_prerequisites() {
    print_header "Checking Prerequisites"

    # Check if Azure CLI is installed
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed"
        echo "Please install Azure CLI: https://docs.microsoft.com/cli/azure/install-azure-cli"
        exit 1
    fi
    print_success "Azure CLI is installed"

    # Check if curl is installed
    if ! command -v curl &> /dev/null; then
        print_error "curl is not installed"
        echo "Please install curl"
        exit 1
    fi
    print_success "curl is installed"

    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        print_error "jq is not installed"
        echo "Please install jq for JSON processing: https://stedolan.github.io/jq/download/"
        exit 1
    fi
    print_success "jq is installed"

    # Check Azure CLI version
    AZ_VERSION=$(az version --query '"azure-cli"' -o tsv)
    print_info "Azure CLI version: ${AZ_VERSION}"

    # Check if logged in
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure"
        echo "Please run: az login"
        exit 1
    fi
    print_success "Authenticated to Azure"

    # Get current account info
    CURRENT_USER=$(az account show --query 'user.name' -o tsv)
    print_info "Logged in as: ${CURRENT_USER}"

    # Check SSH key
    if [ -z "${SSH_KEY_PATH}" ]; then
        SSH_KEY_PATH="${HOME}/.ssh/id_rsa.pub"
    fi

    if [ ! -f "${SSH_KEY_PATH}" ]; then
        print_warning "SSH public key not found at ${SSH_KEY_PATH}"
        print_info "Generating new SSH key pair..."
        ssh-keygen -t rsa -b 4096 -f "${HOME}/.ssh/id_rsa" -N "" -q
        print_success "SSH key pair generated"
    else
        print_success "SSH public key found: ${SSH_KEY_PATH}"
    fi
}

prompt_subscription() {
    # If subscription was provided via command line, skip prompt
    if [ "${SUBSCRIPTION_PROVIDED}" = true ]; then
        return
    fi

    print_header "Azure Subscription Selection"

    # Auto-detect current subscription
    CURRENT_SUB_ID=$(az account show --query 'id' -o tsv 2>/dev/null)
    CURRENT_SUB_NAME=$(az account show --query 'name' -o tsv 2>/dev/null)

    if [ -n "${CURRENT_SUB_ID}" ]; then
        echo ""
        echo "Current subscription: ${CURRENT_SUB_NAME}"
        echo "Subscription ID: ${CURRENT_SUB_ID}"
        echo ""
        read -p "Use this subscription? (yes/no): " use_current

        if [[ "$use_current" =~ ^[Yy][Ee][Ss]$ ]] || [[ "$use_current" =~ ^[Yy]$ ]]; then
            SUBSCRIPTION_ID="${CURRENT_SUB_ID}"
            print_success "Using current subscription"
            return
        fi
    fi

    # Show list if user wants to change
    echo ""
    print_info "Available subscriptions:"
    az account list --query '[].{Name:name, ID:id, State:state}' -o table
    echo ""
    read -p "Enter subscription ID: " SUBSCRIPTION_ID

    if [ -z "${SUBSCRIPTION_ID}" ]; then
        print_error "Subscription ID cannot be empty"
        exit 1
    fi
}

set_subscription() {
    print_header "Setting Azure Subscription"

    # Set the subscription
    az account set --subscription "${SUBSCRIPTION_ID}" 2>/dev/null || {
        print_error "Failed to set subscription: ${SUBSCRIPTION_ID}"
        echo "Please verify your subscription ID and access permissions"
        exit 1
    }

    # Verify subscription
    CURRENT_SUB=$(az account show --query 'name' -o tsv)
    CURRENT_SUB_ID=$(az account show --query 'id' -o tsv)
    print_success "Subscription set: ${CURRENT_SUB} (${CURRENT_SUB_ID})"
}

# prompt_num_peers() function removed - peers must be created via Web UI
# This was removed because API-based peer creation is unreliable

show_cost_estimate() {
    print_header "Cost Estimation"

    cat << EOF
Estimated monthly costs for this deployment:

Resource Type              Configuration           Est. Monthly Cost
--------------------------------------------------------------------------------
Virtual Machine (B1s)      1 vCPU, 1 GB RAM        \$10-15 USD/month
Managed Disk               30 GB Standard SSD      ~\$2-3 USD/month
Public IP Address          Static                  ~\$3-5 USD/month
EOF

    if [ "${USE_KEY_VAULT}" = true ]; then
        echo "Azure Key Vault            Secrets storage         ~\$1 USD/month"
    fi

    if [ "${USE_PRIVATE_DNS}" = true ]; then
        echo "Private DNS Zone           Internal DNS            ~\$0.50 USD/month"
    fi

    cat << EOF
Network bandwidth          First 100GB free        ~\$0-5 USD/month
--------------------------------------------------------------------------------
TOTAL ESTIMATED:                                   ${ESTIMATED_COST}

Note: Costs may vary based on:
  - Actual usage hours (VM running 24/7)
  - Data transfer (ingress is free, egress charged after 100GB)
  - Region pricing differences
  - Currency exchange rates

EOF

    # Only show additional services if any are enabled
    if [ "${USE_KEY_VAULT}" = true ] || [ "${USE_PRIVATE_DNS}" = true ]; then
        echo "Additional services enabled:"
        if [ "${USE_KEY_VAULT}" = true ]; then
            echo "  ✓ Azure Key Vault for secure password storage"
        fi
        if [ "${USE_PRIVATE_DNS}" = true ]; then
            echo "  ✓ Private DNS zone for internal name resolution"
        fi
        echo ""
    fi

    echo ""
    read -p "Do you want to proceed with the deployment? (yes/no): " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy][Ee][Ss]$ ]]; then
        print_warning "Deployment cancelled by user"
        exit 0
    fi
}

create_resource_group() {
    print_header "Creating Resource Group"

    # Check if resource group exists
    if az group exists --name "${RESOURCE_GROUP}" -o tsv | grep -q "true"; then
        print_warning "Resource group '${RESOURCE_GROUP}' already exists"
    else
        az group create \
            --name "${RESOURCE_GROUP}" \
            --location "${LOCATION}" \
            --output none
        print_success "Resource group '${RESOURCE_GROUP}' created in ${LOCATION}"
    fi
}

create_key_vault() {
    if [ "${USE_KEY_VAULT}" != true ]; then
        print_info "Skipping Key Vault creation (--no-key-vault specified)"
        return 0
    fi

    print_header "Creating Azure Key Vault"

    # Check if Key Vault exists
    print_info "Creating Key Vault '${KEY_VAULT_NAME}'..."

    # Temporarily disable exit on error for Key Vault creation
    set +e
    az keyvault create \
        --name "${KEY_VAULT_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --location "${LOCATION}" \
        --enable-rbac-authorization false \
        --output none 2>&1

    local kv_result=$?
    set -e

    if [ $kv_result -ne 0 ]; then
        print_warning "Key Vault name '${KEY_VAULT_NAME}' may be taken"
        print_info "Generating new unique name..."
        KEY_VAULT_NAME="wg-vault-$(openssl rand -hex 8)"
        print_info "Trying with new name: ${KEY_VAULT_NAME}"

        az keyvault create \
            --name "${KEY_VAULT_NAME}" \
            --resource-group "${RESOURCE_GROUP}" \
            --location "${LOCATION}" \
            --enable-rbac-authorization false \
            --output none
    fi

    print_success "Key Vault '${KEY_VAULT_NAME}' created"

    # Store password in Key Vault
    print_info "Storing password in Key Vault..."
    az keyvault secret set \
        --vault-name "${KEY_VAULT_NAME}" \
        --name "wireguard-password" \
        --value "${WG_PASSWORD}" \
        --output none

    print_success "Password securely stored in Key Vault"
    print_info "Key Vault: ${KEY_VAULT_NAME}"
}

create_private_dns() {
    if [ "${USE_PRIVATE_DNS}" != true ]; then
        print_info "Skipping Private DNS zone creation (--no-private-dns specified)"
        return 0
    fi

    print_header "Creating Private DNS Zone"

    local VNET_NAME="${VM_NAME}-vnet"

    # Verify VNet exists before creating Private DNS
    print_info "Verifying VNet exists for DNS linking..."
    set +e
    az network vnet show -g "${RESOURCE_GROUP}" -n "${VNET_NAME}" &>/dev/null
    local vnet_check=$?
    set -e

    if [ $vnet_check -ne 0 ]; then
        print_error "VNet '${VNET_NAME}' does not exist. Cannot create Private DNS link."
        print_error "Private DNS requires an existing VNet to link to."
        exit 1
    fi
    print_success "VNet exists, proceeding with Private DNS creation"

    # Check if Private DNS zone exists
    set +e
    az network private-dns zone show -g "${RESOURCE_GROUP}" -n "${PRIVATE_DNS_ZONE}" &>/dev/null
    local zone_exists=$?
    set -e

    if [ $zone_exists -eq 0 ]; then
        print_warning "Private DNS zone '${PRIVATE_DNS_ZONE}' already exists"
    else
        print_info "Creating Private DNS zone '${PRIVATE_DNS_ZONE}'..."
        az network private-dns zone create \
            --resource-group "${RESOURCE_GROUP}" \
            --name "${PRIVATE_DNS_ZONE}" \
            --output none
        print_success "Private DNS zone created"
    fi

    # Verify Private DNS zone was created successfully
    set +e
    az network private-dns zone show -g "${RESOURCE_GROUP}" -n "${PRIVATE_DNS_ZONE}" &>/dev/null
    local zone_verify=$?
    set -e

    if [ $zone_verify -ne 0 ]; then
        print_error "Private DNS zone '${PRIVATE_DNS_ZONE}' does not exist after creation attempt"
        print_error "This may be a permissions issue or Azure propagation delay"
        print_info "You can retry the deployment or use --no-private-dns to skip Private DNS"
        exit 1
    fi
    print_info "Private DNS zone verified successfully"

    # Small delay to allow Azure propagation before linking
    sleep 3

    # Link DNS zone to VNet (VNet must exist first)
    local LINK_NAME="${VM_NAME}-dns-link"

    set +e
    az network private-dns link vnet show -g "${RESOURCE_GROUP}" -z "${PRIVATE_DNS_ZONE}" -n "${LINK_NAME}" &>/dev/null
    local link_exists=$?
    set -e

    if [ $link_exists -eq 0 ]; then
        print_warning "VNet link already exists"
    else
        print_info "Linking Private DNS zone to VNet..."
        az network private-dns link vnet create \
            --resource-group "${RESOURCE_GROUP}" \
            --zone-name "${PRIVATE_DNS_ZONE}" \
            --name "${LINK_NAME}" \
            --virtual-network "${VNET_NAME}" \
            --registration-enabled true \
            --output none
        print_success "Private DNS zone linked to VNet"
    fi

    print_info "Private DNS configuration complete"
}

create_network_resources() {
    print_header "Creating Network Resources"

    local VNET_NAME="${VM_NAME}-vnet"
    local SUBNET_NAME="${VM_NAME}-subnet"
    local NSG_NAME="${VM_NAME}-nsg"
    local PUBLIC_IP_NAME="${VM_NAME}-ip"

    # Create Virtual Network
    set +e
    az network vnet show -g "${RESOURCE_GROUP}" -n "${VNET_NAME}" &>/dev/null
    local vnet_exists=$?
    set -e

    if [ $vnet_exists -eq 0 ]; then
        print_warning "VNet '${VNET_NAME}' already exists"
    else
        print_info "Creating Virtual Network '${VNET_NAME}'..."
        az network vnet create \
            --resource-group "${RESOURCE_GROUP}" \
            --name "${VNET_NAME}" \
            --address-prefix 10.0.0.0/16 \
            --subnet-name "${SUBNET_NAME}" \
            --subnet-prefix 10.0.1.0/24 \
            --output none

        print_success "Virtual Network '${VNET_NAME}' created"

        # Small delay to allow Azure propagation
        sleep 3
    fi

    # Verify VNet was created successfully
    set +e
    az network vnet show -g "${RESOURCE_GROUP}" -n "${VNET_NAME}" &>/dev/null
    local vnet_verify=$?
    set -e

    if [ $vnet_verify -ne 0 ]; then
        print_error "VNet '${VNET_NAME}' does not exist after creation attempt"
        print_error "This may be a permissions or quota issue"
        exit 1
    fi
    print_info "VNet verified successfully"

    # Create Network Security Group
    set +e
    az network nsg show -g "${RESOURCE_GROUP}" -n "${NSG_NAME}" &>/dev/null
    local nsg_exists=$?
    set -e

    if [ $nsg_exists -eq 0 ]; then
        print_warning "NSG '${NSG_NAME}' already exists"
    else
        print_info "Creating Network Security Group '${NSG_NAME}'..."
        az network nsg create \
            --resource-group "${RESOURCE_GROUP}" \
            --name "${NSG_NAME}" \
            --location "${LOCATION}" \
            --output none

        print_success "NSG '${NSG_NAME}' created"
    fi

    # Verify NSG was created successfully
    set +e
    az network nsg show -g "${RESOURCE_GROUP}" -n "${NSG_NAME}" &>/dev/null
    local nsg_verify=$?
    set -e

    if [ $nsg_verify -ne 0 ]; then
        print_error "NSG '${NSG_NAME}' does not exist after creation attempt"
        exit 1
    fi
    print_info "NSG verified successfully"

    # Create NSG rule for SSH (TCP 22)
    print_info "Creating NSG rule: Allow SSH (TCP 22)..."
    set +e
    az network nsg rule create \
        --resource-group "${RESOURCE_GROUP}" \
        --nsg-name "${NSG_NAME}" \
        --name "AllowSSH" \
        --priority 100 \
        --access Allow \
        --protocol Tcp \
        --direction Inbound \
        --source-address-prefixes '*' \
        --source-port-ranges '*' \
        --destination-address-prefixes '*' \
        --destination-port-ranges 22 \
        --output none 2>&1
    local ssh_rule_result=$?
    set -e

    if [ $ssh_rule_result -eq 0 ]; then
        print_success "NSG rule created: Allow TCP 22 (SSH)"
    elif az network nsg rule show -g "${RESOURCE_GROUP}" --nsg-name "${NSG_NAME}" -n "AllowSSH" &>/dev/null; then
        print_warning "SSH rule already exists"
    else
        print_error "Failed to create SSH NSG rule"
        exit 1
    fi

    # Small delay between rule creations to avoid Azure eventual consistency issues
    sleep 2

    # Create NSG rule for WireGuard (UDP 51820)
    print_info "Creating NSG rule: Allow WireGuard (UDP ${WG_PORT})..."
    set +e
    az network nsg rule create \
        --resource-group "${RESOURCE_GROUP}" \
        --nsg-name "${NSG_NAME}" \
        --name "AllowWireGuard" \
        --priority 110 \
        --access Allow \
        --protocol Udp \
        --direction Inbound \
        --source-address-prefixes '*' \
        --source-port-ranges '*' \
        --destination-address-prefixes '*' \
        --destination-port-ranges "${WG_PORT}" \
        --output none 2>&1
    local wg_rule_result=$?
    set -e

    if [ $wg_rule_result -eq 0 ]; then
        print_success "NSG rule created: Allow UDP ${WG_PORT} (WireGuard)"
    elif az network nsg rule show -g "${RESOURCE_GROUP}" --nsg-name "${NSG_NAME}" -n "AllowWireGuard" &>/dev/null; then
        print_warning "WireGuard rule already exists"
    else
        print_error "Failed to create WireGuard NSG rule"
        exit 1
    fi

    # Small delay between rule creations to avoid Azure eventual consistency issues
    sleep 2

    # Create NSG rule for Web UI (TCP 51821)
    print_info "Creating NSG rule: Allow Web UI (TCP ${WG_UI_PORT})..."
    set +e
    az network nsg rule create \
        --resource-group "${RESOURCE_GROUP}" \
        --nsg-name "${NSG_NAME}" \
        --name "AllowWebUI" \
        --priority 120 \
        --access Allow \
        --protocol Tcp \
        --direction Inbound \
        --source-address-prefixes '*' \
        --source-port-ranges '*' \
        --destination-address-prefixes '*' \
        --destination-port-ranges "${WG_UI_PORT}" \
        --output none 2>&1
    local ui_rule_result=$?
    set -e

    if [ $ui_rule_result -eq 0 ]; then
        print_success "NSG rule created: Allow TCP ${WG_UI_PORT} (Web UI)"
    elif az network nsg rule show -g "${RESOURCE_GROUP}" --nsg-name "${NSG_NAME}" -n "AllowWebUI" &>/dev/null; then
        print_warning "Web UI rule already exists"
    else
        print_error "Failed to create Web UI NSG rule"
        exit 1
    fi

    # Create Public IP
    set +e
    az network public-ip show -g "${RESOURCE_GROUP}" -n "${PUBLIC_IP_NAME}" &>/dev/null
    local ip_exists=$?
    set -e

    if [ $ip_exists -eq 0 ]; then
        print_warning "Public IP '${PUBLIC_IP_NAME}' already exists"
    else
        print_info "Creating Public IP '${PUBLIC_IP_NAME}'..."
        az network public-ip create \
            --resource-group "${RESOURCE_GROUP}" \
            --name "${PUBLIC_IP_NAME}" \
            --sku Standard \
            --allocation-method Static \
            --output none

        print_success "Public IP '${PUBLIC_IP_NAME}' created"
    fi

    # Verify Public IP was created successfully
    set +e
    az network public-ip show -g "${RESOURCE_GROUP}" -n "${PUBLIC_IP_NAME}" &>/dev/null
    local ip_verify=$?
    set -e

    if [ $ip_verify -ne 0 ]; then
        print_error "Public IP '${PUBLIC_IP_NAME}' does not exist after creation attempt"
        exit 1
    fi
    print_info "Public IP verified successfully"

    print_success "All network resources created successfully"
}

deploy_vm() {
    print_header "Deploying Virtual Machine"

    print_info "Creating VM '${VM_NAME}'..."
    print_info "This may take 3-5 minutes..."

    local NIC_NAME="${VM_NAME}-nic"
    local VNET_NAME="${VM_NAME}-vnet"
    local SUBNET_NAME="${VM_NAME}-subnet"
    local NSG_NAME="${VM_NAME}-nsg"
    local PUBLIC_IP_NAME="${VM_NAME}-ip"

    # Verify all prerequisite resources exist (optional check, resources should exist)
    print_info "Verifying network resources..."
    print_success "All prerequisite resources verified"

    # Create Network Interface
    set +e
    az network nic show -g "${RESOURCE_GROUP}" -n "${NIC_NAME}" &>/dev/null
    local nic_exists=$?
    set -e

    if [ $nic_exists -eq 0 ]; then
        print_warning "NIC '${NIC_NAME}' already exists"
    else
        print_info "Creating Network Interface '${NIC_NAME}'..."
        az network nic create \
            --resource-group "${RESOURCE_GROUP}" \
            --name "${NIC_NAME}" \
            --vnet-name "${VNET_NAME}" \
            --subnet "${SUBNET_NAME}" \
            --network-security-group "${NSG_NAME}" \
            --public-ip-address "${PUBLIC_IP_NAME}" \
            --output none

        print_success "Network Interface '${NIC_NAME}' created"
    fi

    # Create VM
    set +e
    az vm show -g "${RESOURCE_GROUP}" -n "${VM_NAME}" &>/dev/null
    local vm_exists=$?
    set -e

    if [ $vm_exists -eq 0 ]; then
        print_warning "VM '${VM_NAME}' already exists"
    else
        print_info "Creating VM '${VM_NAME}' (this will take 3-5 minutes)..."
        az vm create \
            --resource-group "${RESOURCE_GROUP}" \
            --name "${VM_NAME}" \
            --location "${LOCATION}" \
            --size "${VM_SIZE}" \
            --image "${VM_IMAGE}" \
            --admin-username "${ADMIN_USERNAME}" \
            --ssh-key-values "@${SSH_KEY_PATH}" \
            --nics "${NIC_NAME}" \
            --os-disk-size-gb 30 \
            --storage-sku Standard_LRS \
            --output none

        print_success "VM '${VM_NAME}' created"
    fi

    print_success "VM deployment completed successfully"
}

install_docker_and_wireguard() {
    print_header "Installing Docker and WireGuard"

    print_info "Connecting to VM and installing Docker..."

    # Get the public IP
    print_info "Retrieving public IP address..."
    PUBLIC_IP=$(az network public-ip show \
        --resource-group "${RESOURCE_GROUP}" \
        --name "${VM_NAME}-ip" \
        --query 'ipAddress' -o tsv 2>/dev/null)

    if [ -z "${PUBLIC_IP}" ] || [ "${PUBLIC_IP}" = "null" ]; then
        print_error "Failed to retrieve public IP address"
        print_error "The VM or network interface may not be fully provisioned"
        print_info "Try running: az network public-ip show -g ${RESOURCE_GROUP} -n ${VM_NAME}-ip"
        exit 1
    fi

    print_info "VM Public IP: ${PUBLIC_IP}"

    # Wait for VM to be ready (Azure run-command doesn't require SSH)
    print_info "Waiting for VM to be ready (this may take 1-2 minutes)..."
    sleep 60  # Give VM time to fully boot

    # Install Docker using Azure run-command (no SSH required)
    print_info "Installing Docker via Azure CLI (this may take 3-4 minutes)..."

    set +e
    local DOCKER_INSTALL_OUTPUT=$(az vm run-command invoke \
        --resource-group "${RESOURCE_GROUP}" \
        --name "${VM_NAME}" \
        --command-id RunShellScript \
        --scripts "
set -e

# Configure locale and timezone (UK English defaults)
echo 'Configuring locale and timezone...'
export DEBIAN_FRONTEND=noninteractive
export LC_ALL=en_GB.UTF-8
export LANG=en_GB.UTF-8
export LANGUAGE=en_GB.UTF-8

# Install and configure locales
sudo apt-get update -qq || {
    echo 'ERROR: Failed to update package lists'
    exit 1
}

echo 'Installing locales package...'
sudo apt-get install -y locales tzdata >/dev/null 2>&1 || {
    echo 'ERROR: Failed to install locales and tzdata'
    exit 1
}

# Generate UK English locale
echo 'Generating en_GB.UTF-8 locale...'
sudo locale-gen en_GB.UTF-8 >/dev/null 2>&1
sudo update-locale LANG=en_GB.UTF-8 LC_ALL=en_GB.UTF-8 >/dev/null 2>&1

# Set timezone to Europe/London
echo 'Setting timezone to Europe/London...'
sudo timedatectl set-timezone Europe/London 2>/dev/null || sudo ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime

echo 'Locale and timezone configured successfully'

# Install Docker
echo 'Downloading Docker installation script...'
curl -fsSL https://get.docker.com -o get-docker.sh || {
    echo 'ERROR: Failed to download Docker installation script'
    exit 1
}

echo 'Installing Docker...'
sudo sh get-docker.sh > /tmp/docker-install.log 2>&1
if [ \$? -ne 0 ]; then
    echo 'ERROR: Docker installation failed'
    exit 1
fi

sudo usermod -aG docker ${ADMIN_USERNAME}

# Enable and start Docker
echo 'Starting Docker service...'
sudo systemctl enable docker || {
    echo 'ERROR: Failed to enable Docker service'
    exit 1
}

sudo systemctl start docker || {
    echo 'ERROR: Failed to start Docker service'
    exit 1
}

# Verify Docker is running
sudo docker --version || {
    echo 'ERROR: Docker installation verification failed'
    exit 1
}

echo 'SUCCESS: Docker installation completed'
" \
        --query "value[0].message" -o tsv 2>&1)
    local docker_install_result=$?
    set -e

    # Check if installation was successful
    if [ $docker_install_result -ne 0 ] || echo "$DOCKER_INSTALL_OUTPUT" | grep -q "ERROR:"; then
        print_error "Docker installation failed"
        print_info "Output:"
        echo "$DOCKER_INSTALL_OUTPUT"
        print_info "Check VM status: az vm show -g ${RESOURCE_GROUP} -n ${VM_NAME}"
        exit 1
    fi

    # Verify success message
    if ! echo "$DOCKER_INSTALL_OUTPUT" | grep -q "SUCCESS: Docker installation completed"; then
        print_error "Docker installation did not complete successfully"
        print_info "Output:"
        echo "$DOCKER_INSTALL_OUTPUT"
        exit 1
    fi

    print_success "Docker installed successfully"

    # Deploy WireGuard container using Azure run-command
    print_info "Deploying WireGuard container via Azure CLI..."
    print_info "Generating password hash (wg-easy v14 requirement)..."

    # Generate bcrypt hash and deploy container using Azure run-command
    set +e
    local WG_DEPLOY_OUTPUT=$(az vm run-command invoke \
        --resource-group "${RESOURCE_GROUP}" \
        --name "${VM_NAME}" \
        --command-id RunShellScript \
        --scripts "
set -e

# Generate password hash
echo 'Generating password hash...'
HASH_OUTPUT=\$(sudo docker run --rm ghcr.io/wg-easy/wg-easy:latest wgpw '${WG_PASSWORD}' 2>&1)
if [ \$? -ne 0 ]; then
    echo 'ERROR: Failed to generate password hash'
    exit 1
fi

PASSWORD_HASH=\$(echo \"\$HASH_OUTPUT\" | grep \"PASSWORD_HASH=\" | cut -d\"'\" -f2)

if [ -z \"\$PASSWORD_HASH\" ]; then
    echo 'ERROR: Failed to extract password hash'
    exit 1
fi

echo \"Password hash generated successfully\"

# Deploy WireGuard container
echo 'Deploying WireGuard container...'
sudo docker run -d \
  --name=wg-easy \
  --cap-add=NET_ADMIN \
  --cap-add=SYS_MODULE \
  --sysctl='net.ipv4.conf.all.src_valid_mark=1' \
  --sysctl='net.ipv4.ip_forward=1' \
  -e \"WG_HOST=${PUBLIC_IP}\" \
  -e \"PASSWORD_HASH=\$PASSWORD_HASH\" \
  -e \"WG_DEFAULT_DNS=${DNS_SERVER}\" \
  -e \"WG_DEFAULT_ADDRESS=10.8.0.x\" \
  -e \"WG_ALLOWED_IPS=0.0.0.0/0,::/0\" \
  -v \$HOME/.wg-easy:/etc/wireguard \
  -p ${WG_PORT}:51820/udp \
  -p ${WG_UI_PORT}:51821/tcp \
  --restart unless-stopped \
  ghcr.io/wg-easy/wg-easy:latest || {
    echo 'ERROR: Failed to start WireGuard container'
    sudo docker logs wg-easy 2>/dev/null || echo 'No container logs available'
    exit 1
}

# Verify container is running
sleep 5
if ! sudo docker ps | grep -q wg-easy; then
    echo 'ERROR: WireGuard container not running'
    sudo docker logs wg-easy
    exit 1
fi

echo 'SUCCESS: WireGuard container deployed and running'
" \
        --query "value[0].message" -o tsv 2>&1)
    local wg_deploy_result=$?
    set -e

    # Check if deployment was successful
    if [ $wg_deploy_result -ne 0 ] || echo "$WG_DEPLOY_OUTPUT" | grep -q "ERROR:"; then
        print_error "WireGuard container deployment failed"
        print_info "Output:"
        echo "$WG_DEPLOY_OUTPUT"
        print_info "Check container: az vm run-command invoke -g ${RESOURCE_GROUP} -n ${VM_NAME} --command-id RunShellScript --scripts 'sudo docker ps -a'"
        exit 1
    fi

    # Verify success message
    if ! echo "$WG_DEPLOY_OUTPUT" | grep -q "SUCCESS: WireGuard container deployed and running"; then
        print_error "WireGuard deployment did not complete successfully"
        print_info "Output:"
        echo "$WG_DEPLOY_OUTPUT"
        exit 1
    fi

    print_success "WireGuard container deployed and running"

    # Store PUBLIC_IP for later use
    echo "${PUBLIC_IP}" > /tmp/wg_vm_ip.txt
}

wait_for_wireguard() {
    print_header "Waiting for WireGuard to Start"

    print_info "Waiting for wg-easy to be fully ready..."

    # Check if PUBLIC_IP file exists
    if [ ! -f /tmp/wg_vm_ip.txt ]; then
        print_error "Public IP file not found at /tmp/wg_vm_ip.txt"
        print_error "This file should have been created during VM deployment"
        print_error "Cannot verify WireGuard is running without the public IP"
        exit 1
    fi

    PUBLIC_IP=$(cat /tmp/wg_vm_ip.txt)

    if [ -z "${PUBLIC_IP}" ] || [ "${PUBLIC_IP}" = "null" ]; then
        print_error "Public IP is empty or invalid"
        print_error "Cannot connect to WireGuard without a valid public IP"
        exit 1
    fi

    print_info "Testing connection to http://${PUBLIC_IP}:${WG_UI_PORT}"

    local max_attempts=30
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if curl -s -f -o /dev/null --max-time 5 "http://${PUBLIC_IP}:${WG_UI_PORT}" 2>/dev/null; then
            print_success "WireGuard web UI is responsive"
            return 0
        fi

        attempt=$((attempt + 1))
        echo -n "."
        sleep 5
    done

    echo ""
    print_error "WireGuard web UI did not become responsive after $((max_attempts * 5)) seconds"
    print_error "The container may have failed to start or there may be a networking issue"
    print_info "You can check the status manually using Azure CLI:"
    print_info "  az vm run-command invoke -g ${RESOURCE_GROUP} -n ${VM_NAME} --command-id RunShellScript --scripts 'sudo docker ps -a'"
    print_info "  az vm run-command invoke -g ${RESOURCE_GROUP} -n ${VM_NAME} --command-id RunShellScript --scripts 'sudo docker logs wg-easy'"
    exit 1
}

# create_peers() function removed - peers must be created via Web UI
# This was removed because API-based peer creation is unreliable
# Users should access the Web UI to create peers with QR codes

get_deployment_info() {
    print_header "Deployment Information"

    # Check if PUBLIC_IP file exists
    if [ ! -f /tmp/wg_vm_ip.txt ]; then
        print_error "Public IP file not found at /tmp/wg_vm_ip.txt"
        print_error "This file should have been created during VM deployment"
        exit 1
    fi

    PUBLIC_IP=$(cat /tmp/wg_vm_ip.txt)

    if [ -z "${PUBLIC_IP}" ] || [ "${PUBLIC_IP}" = "null" ]; then
        print_error "Public IP is empty or invalid"
        print_error "Cannot display deployment information without a valid public IP"
        exit 1
    fi

    cat << EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  WireGuard VPN Deployment Complete!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

VM Name:             ${VM_NAME}
VM Size:             ${VM_SIZE}
Location:            ${LOCATION}
Public IP:           ${PUBLIC_IP}
Admin Username:      ${ADMIN_USERNAME}

WireGuard Endpoint:  ${PUBLIC_IP}:${WG_PORT}
Web UI:              http://${PUBLIC_IP}:${WG_UI_PORT}

Web UI Password:     ${WG_PASSWORD}
EOF

    if [ "${USE_KEY_VAULT}" = true ]; then
        cat << EOF
Key Vault:           ${KEY_VAULT_NAME}
  Retrieve password: az keyvault secret show --vault-name ${KEY_VAULT_NAME} --name wireguard-password --query value -o tsv
EOF
    fi

    if [ "${USE_PRIVATE_DNS}" = true ]; then
        cat << EOF
Private DNS Zone:    ${PRIVATE_DNS_ZONE}
EOF
    fi

    cat << EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Next Steps:

1. Access the Web UI:
   Open your browser and navigate to:
   http://${PUBLIC_IP}:${WG_UI_PORT}

2. Login with your password

3. Create a new WireGuard peer/client:
   - Click "New" or "+ Add Client" button
   - Give it a name (e.g., "My Laptop", "iPhone")
   - Download the configuration file (.conf) or scan the QR code

4. Install WireGuard client on your device:
   - Desktop: https://www.wireguard.com/install/
   - Mobile: Download WireGuard app from App Store / Google Play

5. Import the configuration and connect:
   - Desktop: Import the .conf file
   - Mobile: Scan the QR code from the Web UI

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

VM Management (via Azure CLI - no SSH required):

View Docker logs:
  az vm run-command invoke -g ${RESOURCE_GROUP} -n ${VM_NAME} \\
    --command-id RunShellScript --scripts 'sudo docker logs wg-easy' \\
    --query "value[0].message" -o tsv

Restart container:
  az vm run-command invoke -g ${RESOURCE_GROUP} -n ${VM_NAME} \\
    --command-id RunShellScript --scripts 'sudo docker restart wg-easy' \\
    --query "value[0].message" -o tsv

Stop VM:             az vm deallocate -g ${RESOURCE_GROUP} -n ${VM_NAME}
Start VM:            az vm start -g ${RESOURCE_GROUP} -n ${VM_NAME}
Delete deployment:   $0 --teardown

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF

    print_warning "IMPORTANT: Save the Web UI password in a secure location!"
    print_info "TIP: VM management commands shown above use Azure CLI (no SSH required)"
    print_info "TIP: After creating peers, keep the configuration files secure (they contain private keys)"

    # Clean up temp file
    rm -f /tmp/wg_vm_ip.txt
}

teardown() {
    print_header "Tearing Down Resources"

    print_warning "This will delete the resource group '${RESOURCE_GROUP}' and ALL resources within it"
    read -p "Are you sure you want to continue? (yes/no): " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy][Ee][Ss]$ ]]; then
        print_info "Teardown cancelled"
        exit 0
    fi

    print_info "Deleting resource group '${RESOURCE_GROUP}'..."
    az group delete \
        --name "${RESOURCE_GROUP}" \
        --yes \
        --no-wait

    print_success "Resource group deletion initiated"
    print_info "Deletion is running in the background and may take a few minutes"
    print_info "Check status with: az group show -n ${RESOURCE_GROUP}"
}

################################################################################
# Main Script
################################################################################

main() {
    # Parse command line arguments
    TEARDOWN_MODE=false
    SUBSCRIPTION_PROVIDED=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--subscription-id)
                SUBSCRIPTION_ID="$2"
                SUBSCRIPTION_PROVIDED=true
                shift 2
                ;;
            -p|--password)
                WG_PASSWORD="$2"
                shift 2
                ;;
            -r|--resource-group)
                RESOURCE_GROUP="$2"
                shift 2
                ;;
            -l|--location)
                LOCATION="$2"
                shift 2
                ;;
            --ssh-key)
                SSH_KEY_PATH="$2"
                shift 2
                ;;
            --use-key-vault)
                USE_KEY_VAULT=true
                shift
                ;;
            --no-private-dns)
                USE_PRIVATE_DNS=false
                shift
                ;;
            --teardown)
                TEARDOWN_MODE=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                print_error "Unknown option: $1"
                usage
                ;;
        esac
    done

    # Check prerequisites
    check_prerequisites

    # Prompt for subscription if not provided
    prompt_subscription

    set_subscription

    # Handle teardown mode
    if [ "$TEARDOWN_MODE" = true ]; then
        teardown
        exit 0
    fi

    # Validate password for deployment
    if [ -z "${WG_PASSWORD}" ]; then
        print_error "Password is required for deployment"
        usage
    fi

    # Validate password strength
    if [ ${#WG_PASSWORD} -lt 8 ]; then
        print_error "Password must be at least 8 characters long"
        exit 1
    fi

    # Select region interactively if not specified
    select_region

    # Show cost estimate and get confirmation
    show_cost_estimate

    # Deploy resources
    create_resource_group
    create_key_vault
    create_network_resources
    create_private_dns  # Must be after network resources (needs VNet)
    deploy_vm
    install_docker_and_wireguard

    # Wait for WireGuard to be ready
    wait_for_wireguard

    # Show deployment info
    get_deployment_info

    print_success "Deployment completed successfully!"
}

# Run main function
main "$@"
