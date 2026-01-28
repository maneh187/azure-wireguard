#!/bin/bash

################################################################################
# Cleanup Partial WireGuard Deployment
# Removes all resources in the resource group
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

RESOURCE_GROUP="rg-wireguard-vpn"

print_info "Checking resource group: ${RESOURCE_GROUP}"

# Check if resource group exists
if ! az group exists --name "${RESOURCE_GROUP}" -o tsv | grep -q "true"; then
    print_info "Resource group '${RESOURCE_GROUP}' does not exist. Nothing to clean up."
    exit 0
fi

print_info "Found resource group '${RESOURCE_GROUP}'"
echo ""

# List all resources
print_info "Resources that will be deleted:"
az resource list -g "${RESOURCE_GROUP}" --query '[].{Name:name, Type:type}' -o table

echo ""
print_warning "This will delete ALL resources in '${RESOURCE_GROUP}'"
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy][Ee][Ss]$ ]]; then
    print_info "Cleanup cancelled"
    exit 0
fi

print_info "Deleting resource group '${RESOURCE_GROUP}'..."
az group delete \
    --name "${RESOURCE_GROUP}" \
    --yes \
    --no-wait

print_success "Resource group deletion initiated"
print_info "Deletion is running in the background and may take a few minutes"
echo ""
print_info "You can check the status with:"
echo "  az group show -n ${RESOURCE_GROUP}"
echo ""
print_info "Once deleted, you can redeploy with:"
echo "  ./deploy-wireguard-azure-vm.sh -p \"YourPassword\" -l \"eastus\""
