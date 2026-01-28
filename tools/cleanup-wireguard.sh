#!/bin/bash

################################################################################
# WireGuard VPN Cleanup Script
# Comprehensive teardown of all WireGuard VPN resources
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

print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

RESOURCE_GROUP="rg-wireguard-vpn"
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -g|--resource-group)
            RESOURCE_GROUP="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            cat << EOF
Usage: $0 [OPTIONS]

Cleanup WireGuard VPN deployment by deleting all resources

Options:
    -g, --resource-group NAME    Resource group name (default: rg-wireguard-vpn)
    --dry-run                    Show what would be deleted without actually deleting
    -h, --help                   Show this help message

Examples:
    # Delete default resource group
    $0

    # Dry run to see what would be deleted
    $0 --dry-run

    # Delete custom resource group
    $0 -g "my-wireguard-rg"

EOF
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

print_header "WireGuard VPN Cleanup"

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    print_error "Azure CLI is not installed"
    exit 1
fi

# Check if logged in
if ! az account show &> /dev/null; then
    print_error "Not logged in to Azure"
    echo "Please run: az login"
    exit 1
fi

print_success "Azure CLI is available and authenticated"

# Check if resource group exists
print_info "Checking for resource group: ${RESOURCE_GROUP}"

if ! az group exists --name "${RESOURCE_GROUP}" -o tsv | grep -q "true"; then
    print_info "Resource group '${RESOURCE_GROUP}' does not exist"
    print_success "Nothing to clean up!"
    exit 0
fi

print_success "Found resource group '${RESOURCE_GROUP}'"

# Get resource list
echo ""
print_info "Resources found in '${RESOURCE_GROUP}':"
echo ""

RESOURCES=$(az resource list -g "${RESOURCE_GROUP}" --query '[].{Name:name, Type:type, Location:location}' -o table)

if [ -z "$RESOURCES" ] || [ "$RESOURCES" = "[]" ]; then
    print_info "No resources found in resource group"
else
    echo "$RESOURCES"
fi

echo ""

# Get Key Vaults in the resource group (special handling needed)
KEY_VAULTS=$(az keyvault list -g "${RESOURCE_GROUP}" --query '[].name' -o tsv 2>/dev/null)

if [ -n "$KEY_VAULTS" ]; then
    echo ""
    print_info "Key Vaults that will be soft-deleted:"
    for vault in $KEY_VAULTS; do
        echo "  - $vault"
    done
    echo ""
    print_warning "Note: Key Vaults will be soft-deleted and can be recovered for 90 days"
    print_info "To permanently delete: az keyvault purge --name <vault-name>"
fi

# Count resources
RESOURCE_COUNT=$(az resource list -g "${RESOURCE_GROUP}" --query 'length(@)' -o tsv)

echo ""
print_header "Cleanup Summary"
echo ""
echo "Resource Group:      ${RESOURCE_GROUP}"
echo "Resources to delete: ${RESOURCE_COUNT}"

if [ -n "$KEY_VAULTS" ]; then
    VAULT_COUNT=$(echo "$KEY_VAULTS" | wc -l | tr -d ' ')
    echo "Key Vaults:          ${VAULT_COUNT} (will be soft-deleted)"
fi

echo ""

# Dry run mode
if [ "$DRY_RUN" = true ]; then
    print_warning "DRY RUN MODE - No resources will be deleted"
    print_info "Remove --dry-run flag to perform actual deletion"
    exit 0
fi

# Confirmation prompt
print_warning "This will permanently delete the resource group and ALL resources within it!"
echo ""
read -p "Type 'yes' to confirm deletion: " CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
    print_info "Cleanup cancelled by user"
    exit 0
fi

# Perform deletion
echo ""
print_header "Deleting Resources"

print_info "Initiating resource group deletion..."
print_info "This will run in the background and may take 5-10 minutes"

az group delete \
    --name "${RESOURCE_GROUP}" \
    --yes \
    --no-wait

print_success "Resource group deletion initiated"

echo ""
print_info "Deletion is running in the background"
print_info "You can close this terminal - deletion will continue"

echo ""
print_info "To check deletion status:"
echo "  az group show -n ${RESOURCE_GROUP}"
echo ""
print_info "To monitor deletion progress:"
echo "  watch 'az resource list -g ${RESOURCE_GROUP} --query \"length(@)\" -o tsv'"

echo ""

if [ -n "$KEY_VAULTS" ]; then
    echo ""
    print_info "After deletion completes, Key Vaults will be in soft-deleted state"
    print_info "To list soft-deleted vaults:"
    echo "  az keyvault list-deleted"
    echo ""
    print_info "To permanently purge a vault:"
    for vault in $KEY_VAULTS; do
        echo "  az keyvault purge --name ${vault}"
    done
fi

echo ""
print_success "Cleanup process started successfully!"

# Clean up any local configuration directories
echo ""
print_info "Checking for local WireGuard configuration directories..."

CONFIG_DIRS=$(find . -maxdepth 1 -type d -name "wireguard-configs-*" 2>/dev/null)

if [ -n "$CONFIG_DIRS" ]; then
    echo ""
    print_warning "Found local WireGuard configuration directories:"
    echo "$CONFIG_DIRS"
    echo ""
    read -p "Delete these local configuration directories? (yes/no): " DELETE_LOCAL

    if [[ "$DELETE_LOCAL" =~ ^[Yy][Ee][Ss]$ ]]; then
        for dir in $CONFIG_DIRS; do
            rm -rf "$dir"
            print_success "Deleted: $dir"
        done
    else
        print_info "Local configuration directories preserved"
    fi
else
    print_info "No local configuration directories found"
fi

echo ""
print_header "Cleanup Complete"
echo ""
print_success "WireGuard VPN cleanup initiated successfully!"
echo ""
