# WireGuard VPN on Azure - Quick Start Guide

Self-managed WireGuard VPN deployment on Azure with wg-easy web interface, Private DNS support, and Azure CLI-based management. **Works from any network - no SSH required for deployment or management.**

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Prerequisites](#prerequisites)
3. [Deployment](#deployment)
4. [Accessing Your VPN](#accessing-your-vpn)
5. [Managing Your VPN](#managing-your-vpn)
6. [Cleanup](#cleanup)
7. [Troubleshooting](#troubleshooting)
8. [Estimated Cost Breakdown](#estimated-cost-breakdown)

---

## Quick Start

**Deploy in 2 commands:**

```bash
# 1. Login to Azure
az login

# 2. Deploy WireGuard VPN VM (takes 7-10 minutes)
./deploy-wireguard-azure-vm.sh -p "YourSecurePassword123"

# 3. Follow the onscreen prompts to select location. Once deployed connect to the WG-Easy Interface and begin adding your peers!
```

That's it! Your VPN is ready to use.

---

## Prerequisites

### Required Tools

1. **Azure CLI** - For managing Azure resources

   **macOS:**
   ```bash
   brew install azure-cli
   ```

   **Linux (Debian/Ubuntu):**
   ```bash
   curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
   ```

   **Linux (RPM-based - RHEL/CentOS/Fedora):**
   ```bash
   curl -sL https://aka.ms/InstallAzureCLIRPM | sudo bash
   ```

   **Windows:**
   - Download: [Azure CLI installer](https://aka.ms/installazurecliwindows)
   - Or using winget: `winget install -e --id Microsoft.AzureCLI`
   - Or using PowerShell: `Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'`

   **Verify installation:**
   ```bash
   az --version
   ```

2. **jq** - For JSON processing

   **macOS:**
   ```bash
   brew install jq
   ```

   **Linux (Debian/Ubuntu):**
   ```bash
   sudo apt-get install jq
   ```

   **Linux (RPM-based - RHEL/CentOS/Fedora):**
   ```bash
   sudo yum install jq
   # or
   sudo dnf install jq
   ```

   **Windows:**
   - Download: [jq releases](https://stedolan.github.io/jq/download/)
   - Or using winget: `winget install jqlang.jq`
   - Or using Chocolatey: `choco install jq`
   - Place `jq.exe` in your PATH

   **Verify installation:**
   ```bash
   jq --version
   ```

3. **curl** - Usually pre-installed

   **macOS/Linux:**
   ```bash
   curl --version
   ```

   **Windows:**
   - Included in Windows 10/11 by default
   - Verify: `curl --version` in PowerShell or Command Prompt

### Azure Requirements

- **Active Azure subscription** with sufficient permissions
- **Ability to create resources**: VMs, VNets, NSGs, Public IPs, Private DNS zones
- **Cost awareness**: ~$15-26/month (see [Cost Breakdown][def])

### Network Requirements

- **HTTPS (port 443) access** for Azure CLI communication
- **No SSH access required** - Deployment and management work via Azure CLI
- **Works from any network**: Corporate firewalls, public WiFi, networks that block SSH
- **Works from any network**: Corporate firewalls, public WiFi, networks that block SSH

### First Time Setup

**macOS/Linux:**
```bash
# Login to Azure
az login

# Verify you're logged in
az account show

# List available subscriptions (if you have multiple)
az account list --output table
```

**Windows (PowerShell/Command Prompt/Git Bash):**
```powershell
# Login to Azure
az login

# Verify you're logged in
az account show

# List available subscriptions (if you have multiple)
az account list --output table
```

**Windows (WSL - Windows Subsystem for Linux):**
- Use the same Linux commands as above
- WSL provides a full Linux environment on Windows

---

## Deployment

### Shell Requirements

**macOS/Linux:**
- Use Terminal or your preferred shell (bash/zsh)

**Windows:**
- **Option 1 (Recommended):** Use WSL (Windows Subsystem for Linux)
  - Install: `wsl --install` in PowerShell as Administrator
  - Provides full Linux compatibility
- **Option 2:** Use Git Bash (included with Git for Windows)
- **Option 3:** Use PowerShell with bash compatibility (may require script adaptations)

### Basic Deployment

**Simplest deployment** (uses all defaults):

```bash
./deploy-wireguard-azure-vm.sh -p "YourSecurePassword123"
```

This will:
- ✅ Auto-detect your current Azure subscription
- ✅ Prompt you to select a region interactively
- ✅ Create Private DNS zone for internal resolution
- ✅ Deploy and configure via Azure CLI (no SSH required)

### Advanced Options

**Specify everything on command line:**

```bash
./deploy-wireguard-azure-vm.sh \
  -p "YourSecurePassword123" \
  -l "eastus" \
  -s "your-subscription-id"
```

**Deploy with Azure Key Vault** (optional, for enhanced security):

```bash
./deploy-wireguard-azure-vm.sh -p "YourPassword" --use-key-vault
```

**Deploy without Private DNS** (saves $0.50/month):

```bash
./deploy-wireguard-azure-vm.sh -p "YourPassword" --no-private-dns
```

**Use custom resource group and SSH key:**

```bash
./deploy-wireguard-azure-vm.sh \
  -p "YourPassword" \
  -r "my-vpn-rg" \
  --ssh-key "/path/to/your/key.pub"
```

**Note on SSH Keys:**
- **macOS/Linux:** Keys usually in `~/.ssh/id_rsa.pub`
- **Windows:** Keys in `%USERPROFILE%\.ssh\id_rsa.pub` or `C:\Users\YourName\.ssh\id_rsa.pub`
- Generate if needed:
  - All platforms: `ssh-keygen -t rsa -b 4096`
  - Or use Azure's generated key by omitting the `--ssh-key` parameter

### Command-Line Options

```
Required:
  -p, --password PASSWORD          Web UI password (min 8 chars)

Optional:
  -s, --subscription-id ID         Azure subscription (default: auto-detect)
  -r, --resource-group NAME        Resource group (default: rg-wireguard-vpn)
  -l, --location REGION            Azure region (default: interactive prompt)
  --ssh-key PATH                   SSH public key path
  --no-key-vault                   Skip Key Vault creation
  --no-private-dns                 Skip Private DNS creation
  --teardown                       Delete all resources
  -h, --help                       Show help
```

### What Gets Deployed

The script creates:

1. **Resource Group** - Container for all resources
2. **Azure Key Vault** (optional) - Secure password storage
3. **Virtual Network** (10.0.0.0/16) with subnet
4. **Network Security Group** - Firewall rules for:
   - SSH (port 22)
   - WireGuard (UDP 51820)
   - Web UI (TCP 51821)
5. **Public IP Address** (Static) - For VPN endpoint
6. **Network Interface** - VM's network card
7. **Virtual Machine** (Ubuntu 22.04, B1s size)
8. **Docker** + **wg-easy container** - WireGuard server
9. **Private DNS Zone** (optional) - Internal name resolution

---

## Accessing Your VPN

### After Deployment

The script outputs:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  WireGuard VPN Deployment Complete!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

VM Name:             wireguard-vm
Public IP:           20.123.45.67
WireGuard Endpoint:  20.123.45.67:51820
Web UI:              http://20.123.45.67:51821
Web UI Password:     YourSecurePassword123
Key Vault:           wg-vault-a1b2c3d4
```

### Using Your Configuration Files

After creating peers in the Web UI, you can download the `.conf` file or scan the QR code directly from the browser.

### Desktop Setup (Windows/macOS/Linux)

1. **Install WireGuard:**

   **Windows:**
   - Download installer from [WireGuard for Windows](https://www.wireguard.com/install/)
   - Or use winget: `winget install WireGuard.WireGuard`
   - Or use Chocolatey: `choco install wireguard`

   **macOS:**
   - Using Homebrew: `brew install wireguard-tools`
   - Or download from [Mac App Store](https://apps.apple.com/us/app/wireguard/id1451685025)
   - Or download from [WireGuard website](https://www.wireguard.com/install/)

   **Linux (Debian/Ubuntu):**
   ```bash
   sudo apt-get update
   sudo apt-get install wireguard
   ```

   **Linux (RPM-based - RHEL/CentOS/Fedora):**
   ```bash
   sudo yum install wireguard-tools
   # or
   sudo dnf install wireguard-tools
   ```

   **Linux (Arch):**
   ```bash
   sudo pacman -S wireguard-tools
   ```

2. **Import Configuration:**

   **Windows:**
   - Open WireGuard application
   - Click "Add Tunnel" → "Import tunnel(s) from file"
   - Select your `.conf` file
   - Click "Activate" button

   **macOS:**
   - Open WireGuard application
   - Click "Add Tunnel" or "Import from file"
   - Select your `.conf` file
   - Click "Activate" or toggle the switch

   **Linux (GUI):**
   - Open WireGuard GUI (if installed)
   - Import the `.conf` file
   - Activate the connection

   **Linux (Command Line):**
   ```bash
   # Copy config to WireGuard directory
   sudo cp your-config.conf /etc/wireguard/wg0.conf

   # Start the VPN
   sudo wg-quick up wg0

   # Enable at boot (optional)
   sudo systemctl enable wg-quick@wg0

   # Check status
   sudo wg show
   ```

3. **Verify Connection:**

   **All Platforms:**
   - Visit: https://ifconfig.me or https://whatismyip.com
   - Should show your Azure VM's public IP
   - Or use command line:

   **Windows (PowerShell):**
   ```powershell
   (Invoke-WebRequest -Uri "https://ifconfig.me").Content
   ```

   **macOS/Linux:**
   ```bash
   curl ifconfig.me
   ```

### Mobile Setup (iOS/Android)

1. **Install WireGuard App:**
   - iOS: App Store
   - Android: Google Play Store

2. **Scan QR Code:**
   - Open WireGuard app
   - Tap "+" button
   - Select "Create from QR code"
   - Open the `.svg` file on your computer and scan it

3. **Connect:**
   - Tap the toggle to connect
   - Allow VPN configuration when prompted

### Web UI Management

Access the web interface at `http://<YOUR_IP>:51821`

**Features:**
- Create/delete clients
- View connection status
- Download configs or QR codes
- Monitor bandwidth usage
- See connected peers

---

## Managing Your VPN

### Add More Peers

**Via Web UI (easiest):**
1. Go to `http://<YOUR_IP>:51821`
2. Login with your password
3. Click "Add Client"
4. Name your client (e.g., "iPhone", "Laptop")
5. Download config or scan QR code

**Via Script:**
Use the `regenerate-configs-v2.sh` script to download all existing configs.

### Retrieve Password from Key Vault

If you used `--use-key-vault` during deployment:

```bash
az keyvault secret show \
  --vault-name wg-vault-a1b2c3d4 \
  --name wireguard-password \
  --query value -o tsv
```

### View Container Logs (Azure CLI - No SSH required)

```bash
az vm run-command invoke \
  -g rg-wireguard-vpn \
  -n wireguard-vm \
  --command-id RunShellScript \
  --scripts 'sudo docker logs wg-easy' \
  --query "value[0].message" -o tsv
```

### Restart WireGuard (Azure CLI - No SSH required)

```bash
az vm run-command invoke \
  -g rg-wireguard-vpn \
  -n wireguard-vm \
  --command-id RunShellScript \
  --scripts 'sudo docker restart wg-easy' \
  --query "value[0].message" -o tsv
```

### Check Container Status (Azure CLI - No SSH required)

```bash
az vm run-command invoke \
  -g rg-wireguard-vpn \
  -n wireguard-vm \
  --command-id RunShellScript \
  --scripts 'sudo docker ps' \
  --query "value[0].message" -o tsv
```

### SSH to VM (Optional - if available on your network)

If SSH is available on your network:

**macOS/Linux:**
```bash
ssh azureuser@<PUBLIC_IP>
```

**Windows:**
- **PowerShell/Command Prompt:** `ssh azureuser@<PUBLIC_IP>` (Windows 10/11 includes OpenSSH)
- **PuTTY:** Use PuTTY client (download from [putty.org](https://www.putty.org/))
  - Host: `<PUBLIC_IP>`
  - Port: `22`
  - Connection type: SSH
  - Load your private key in Connection → SSH → Auth
- **WSL:** `ssh azureuser@<PUBLIC_IP>` (same as Linux)

**Note:** SSH is not required for deployment or management. All operations can be performed via Azure CLI from any network.

### Stop/Start VM (Save Costs)

**Stop VM when not in use:**
```bash
az vm stop -g rg-wireguard-vpn -n wireguard-vm
az vm deallocate -g rg-wireguard-vpn -n wireguard-vm
```

**Start VM:**
```bash
az vm start -g rg-wireguard-vpn -n wireguard-vm
```

**Note:** After restart, the public IP remains the same (static IP).

### Update WireGuard Container

**Via Azure CLI (works from any network):**

```bash
# Get current public IP
PUBLIC_IP=$(az network public-ip show -g rg-wireguard-vpn -n wireguard-vm-ip --query ipAddress -o tsv)

# Update container via Azure CLI
az vm run-command invoke \
  -g rg-wireguard-vpn \
  -n wireguard-vm \
  --command-id RunShellScript \
  --scripts "
sudo docker pull ghcr.io/wg-easy/wg-easy:latest
sudo docker stop wg-easy
sudo docker rm wg-easy
sudo docker run -d \
  --name=wg-easy \
  --cap-add=NET_ADMIN \
  --cap-add=SYS_MODULE \
  --sysctl='net.ipv4.conf.all.src_valid_mark=1' \
  --sysctl='net.ipv4.ip_forward=1' \
  -e WG_HOST='${PUBLIC_IP}' \
  -e PASSWORD_HASH='<YOUR_HASH>' \
  -v \$HOME/.wg-easy:/etc/wireguard \
  -p 51820:51820/udp \
  -p 51821:51821/tcp \
  --restart unless-stopped \
  ghcr.io/wg-easy/wg-easy:latest
echo 'Container updated successfully'
" \
  --query "value[0].message" -o tsv
```

**Via SSH (if available on your network):**

```bash
ssh azureuser@<PUBLIC_IP>
sudo docker pull ghcr.io/wg-easy/wg-easy:latest
sudo docker stop wg-easy
sudo docker rm wg-easy
# Run new container (use the docker run command from deployment)
```

---

## Cleanup

### Complete Teardown

**Using deployment script:**
```bash
./deploy-wireguard-azure-vm.sh --teardown
```

**Using cleanup script (recommended):**
```bash
./cleanup-wireguard.sh
```

**Features:**
- ✅ Shows all resources before deletion
- ✅ Dry-run mode to preview
- ✅ Handles Key Vault soft-delete
- ✅ Offers to delete local config files
- ✅ Runs in background

**Dry run (preview only):**
```bash
./cleanup-wireguard.sh --dry-run
```

**Custom resource group:**
```bash
./cleanup-wireguard.sh -g "my-vpn-rg"
```

### Manual Cleanup

```bash
# Delete resource group and all resources
az group delete --name rg-wireguard-vpn --yes --no-wait

# Check deletion status
az group show -n rg-wireguard-vpn

# Purge soft-deleted Key Vault (optional)
az keyvault purge --name wg-vault-a1b2c3d4
```

### Clean Local Files

```bash
# Remove generated config directories
rm -rf wireguard-configs-*
```

---

## Troubleshooting

### Universal Network Compatibility

This deployment works from **any network** - no SSH required. All management operations use Azure CLI via HTTPS (port 443).

**Supported networks:**
- ✅ Corporate networks with strict firewalls
- ✅ Public WiFi (coffee shops, airports, hotels)
- ✅ Networks that block SSH (port 22)
- ✅ VPN-restricted environments

**Only requirement:** HTTPS (port 443) access for Azure CLI

### Can't Access Web UI

**Check 1: Wait 60 seconds** - Container may still be starting

**Check 2: Verify container is running (Azure CLI - no SSH required)**
```bash
az vm run-command invoke \
  -g rg-wireguard-vpn \
  -n wireguard-vm \
  --command-id RunShellScript \
  --scripts 'sudo docker ps' \
  --query "value[0].message" -o tsv
```

**Check 3: Check container logs (Azure CLI - no SSH required)**
```bash
az vm run-command invoke \
  -g rg-wireguard-vpn \
  -n wireguard-vm \
  --command-id RunShellScript \
  --scripts 'sudo docker logs wg-easy' \
  --query "value[0].message" -o tsv
```

**Check 4: Test port**

**macOS/Linux:**
```bash
curl -I http://<PUBLIC_IP>:51821
```

**Windows (PowerShell):**
```powershell
Invoke-WebRequest -Uri "http://<PUBLIC_IP>:51821" -Method Head
```

**Windows (Command Prompt with curl):**
```bash
curl -I http://<PUBLIC_IP>:51821
```

**Check 5: VM is running**
```bash
az vm show -g rg-wireguard-vpn -n wireguard-vm --query "powerState" -o tsv
```

### VPN Not Connecting

**Check 1: Verify endpoint is correct**
- Endpoint should be: `<PUBLIC_IP>:51820`
- Protocol: UDP
- Make sure no typos in config

**Check 2: Check WireGuard is running (Azure CLI - no SSH required)**
```bash
az vm run-command invoke \
  -g rg-wireguard-vpn \
  -n wireguard-vm \
  --command-id RunShellScript \
  --scripts 'sudo docker logs wg-easy | tail -20' \
  --query "value[0].message" -o tsv
```

**Check 3: NSG rules allow UDP 51820**
```bash
az network nsg rule show \
  -g rg-wireguard-vpn \
  --nsg-name wireguard-vm-nsg \
  -n AllowWireGuard
```

**Check 4: Firewall on your device**
- Ensure your local firewall isn't blocking WireGuard
- Try from a different network

### Peer Creation Fails

**Check 1: Password is correct**
- If using `--use-key-vault`, retrieve password:
  ```bash
  az keyvault secret show --vault-name <VAULT> --name wireguard-password --query value -o tsv
  ```

**Check 2: Web UI is accessible**
```bash
curl -I http://<PUBLIC_IP>:51821
```

**Check 3: Try creating peer via Web UI manually**

### Can't SSH to VM (Optional troubleshooting)

If you need SSH access (not required for deployment):

**Check 1: VM is running**
```bash
az vm show -g rg-wireguard-vpn -n wireguard-vm --query "powerState" -o tsv
```

**Check 2: NSG rules allow SSH**
```bash
az network nsg rule list -g rg-wireguard-vpn --nsg-name wireguard-vm-nsg -o table
```

**Check 3: SSH key permissions**
```bash
chmod 600 ~/.ssh/id_rsa
```

**Note:** If your network blocks SSH (port 22), use Azure CLI `az vm run-command` instead (see examples above)

### Script Fails During Deployment

**Common Issues:**

1. **Quota exceeded:**
   - Check subscription quota: `az vm list-usage --location eastus -o table`
   - Try different VM size or region

2. **Region not available:**
   - Choose different region during interactive prompt

3. **Permission denied:**
   - Verify you have Contributor role on subscription
   - Check: `az role assignment list --assignee <YOUR_EMAIL>`

### Get Deployment Logs

```bash
# Check resource group deployment
az deployment group list -g rg-wireguard-vpn -o table

# View specific deployment
az deployment group show -g rg-wireguard-vpn -n <DEPLOYMENT_NAME>
```

---

## Estimated Cost Breakdown

### Monthly Costs (Default Deployment)

| Resource | Configuration | Monthly Cost | Included |
|----------|---------------|--------------|----------|
| Virtual Machine | B1s (1 vCPU, 1 GB RAM) | $10-15 | ✅ |
| Managed Disk | 30 GB Standard SSD | $2-3 | ✅ |
| Public IP | Static | $3-5 | ✅ |
| Private DNS Zone | Internal DNS | $0.50 | ✅ |
| Network Bandwidth | First 100GB free | $0-5 | ✅ |
| **TOTAL (default)** | | **$15-26/month** | |

### Optional Add-ons

| Resource | Configuration | Monthly Cost | Flag |
|----------|---------------|--------------|------|
| Azure Key Vault | Secrets storage | $1 | `--use-key-vault` |

### Cost Optimization Tips

1. **Stop VM when not in use:**
   ```bash
   az vm deallocate -g rg-wireguard-vpn -n wireguard-vm
   ```
   Saves ~$10/month if used only 8 hours/day

2. **Skip Private DNS:** Use `--no-private-dns` (saves $0.50/month)

3. **Don't use Key Vault:** Default behavior (Key Vault adds $1/month if enabled with `--use-key-vault`)

4. **Use Spot VMs:** Up to 90% discount (may be evicted)

5. **Choose cheaper regions:** East US typically cheaper than North Europe

### Cost Monitoring

```bash
# View current month costs
az consumption usage list \
  --start-date "2025-11-01" \
  --end-date "2025-11-30" \
  -o table

# Set up cost alert (in Azure Portal)
# Billing → Cost Management → Budgets → Create Budget
```

---

## Security Considerations

### Current Security Posture

**✅ Secure:**
- WireGuard uses modern cryptography (Curve25519, ChaCha20, Poly1305)
- Passwords optionally stored in Azure Key Vault (encrypted at rest) with `--use-key-vault`
- SSH key-based authentication (no password login)
- All VPN traffic encrypted
- Deployment and management via Azure CLI (HTTPS/443) - no SSH required

**⚠️ Be Aware:**
- SSH port (22) open to internet by default - Not required for deployment, can be restricted
- Web UI port (51821) open to internet - Consider VPN-only access or IP restrictions
- Single VM (no high availability) - Single point of failure
- Basic network setup - For production, add more layers

### Improving Security

**1. Restrict SSH Access:**
```bash
# Update NSG to allow SSH only from your IP
az network nsg rule update \
  -g rg-wireguard-vpn \
  --nsg-name wireguard-vm-nsg \
  -n AllowSSH \
  --source-address-prefixes "<YOUR_IP>/32"
```

**2. Restrict Web UI Access:**
```bash
# Update NSG to allow Web UI only from your IP
az network nsg rule update \
  -g rg-wireguard-vpn \
  --nsg-name wireguard-vm-nsg \
  -n AllowWebUI \
  --source-address-prefixes "<YOUR_IP>/32"
```

**3. Enable Azure Monitor:**
```bash
# Enable VM insights for security monitoring
az vm extension set \
  --resource-group rg-wireguard-vpn \
  --vm-name wireguard-vm \
  --name OmsAgentForLinux \
  --publisher Microsoft.EnterpriseCloud.Monitoring
```

**4. Regular Updates (Azure CLI - no SSH required):**
```bash
# Update system packages
az vm run-command invoke \
  -g rg-wireguard-vpn \
  -n wireguard-vm \
  --command-id RunShellScript \
  --scripts 'sudo apt update && sudo apt upgrade -y' \
  --query "value[0].message" -o tsv

# Update WireGuard container (see "Update WireGuard Container" section above)
```

**5. Backup Configurations (Azure CLI - no SSH required):**
```bash
# Create backup on VM
az vm run-command invoke \
  -g rg-wireguard-vpn \
  -n wireguard-vm \
  --command-id RunShellScript \
  --scripts 'cd ~ && tar czf wg-backup.tar.gz .wg-easy' \
  --query "value[0].message" -o tsv

# Download backup (requires SSH or alternative file transfer method)
# Option 1: Use Azure CLI with base64 encoding for small configs
# Option 2: Enable SSH temporarily if available on your network
# Option 3: Use Azure Storage Blob for larger backups
```

---

## Additional Resources

- **WireGuard Official:** https://www.wireguard.com/
- **wg-easy GitHub:** https://github.com/wg-easy/wg-easy
- **Azure CLI Docs:** https://docs.microsoft.com/cli/azure/
- **Azure Pricing Calculator:** https://azure.microsoft.com/pricing/calculator/

---

## Support

For issues:
1. Check [Troubleshooting](#troubleshooting) section
2. Check wg-easy issues: https://github.com/wg-easy/wg-easy/issues

---

**Document Version:** 2.0
**Last Updated:** January 13, 2025
**Script Version:** Azure CLI-based deployment (no SSH required)

**Major Updates:**
- v2.0 (Jan 13, 2025): Azure CLI management approach, Key Vault now optional, universal network compatibility, SSH-free deployment and management
- v1.0 (Nov 13, 2025): Initial deployment guide with Key Vault + Private DNS


[def]: #cost-breakdown