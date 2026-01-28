# WireGuard VPN - Azure Deployment Tool

**Tool Type:** Reusable, production-ready (maintained, never archived)
**Purpose:** Automated WireGuard VPN server deployment on Azure

---

## WireGuard VPN on Azure - Self-Managed Deployment

> **One-command deployment of WireGuard VPN on Azure with wg-easy web interface**

Automated deployment script that creates a fully functional WireGuard VPN server on Azure in 7-10 minutes, complete with web management interface. Works from any network - **no SSH access required** for deployment or management.

---

## 🚀 Quick Start

```bash
# 1. Login to Azure
az login

# 2. Deploy WireGuard VPN
./deploy-wireguard-azure-vm.sh -p "YourSecurePassword123"

# 3. Access Web UI to create peers and connect!
```

**That's it!** Access the Web UI to create your peers with QR codes

---

## ✨ Features

- ✅ **One-command deployment** - Fully automated setup in 7-10 minutes
- ✅ **No SSH required** - Works from any network (corporate, public WiFi, etc.)
- ✅ **wg-easy web UI** - Manage peers through browser interface with QR codes
- ✅ **Easy peer creation** - Create unlimited peers via Web UI
- ✅ **Azure CLI management** - All operations via Azure CLI (no SSH port required)
- ✅ **Private DNS support** - Internal name resolution
- ✅ **Interactive region selection** - Choose from 30+ Azure regions
- ✅ **Auto-subscription detection** - No hardcoded credentials
- ✅ **QR code generation** - Built into Web UI for easy mobile setup
- ✅ **Comprehensive cleanup** - One-command teardown
- ✅ **Cost estimation** - Know costs before deploying (~$15-26/month)

---

## 📋 What You Get

### Infrastructure
- Ubuntu 22.04 VM (B1s: 1 vCPU, 1 GB RAM)
- Docker 29.0+ with WireGuard + wg-easy container
- Public IP with static allocation
- Network Security Group (SSH, WireGuard UDP/51820, Web UI TCP/51821)
- Private DNS zone for internal resolution (optional)
- Fully configured via Azure CLI (no SSH required)

### Management Tools
- Web UI at `http://<your-ip>:51821` for peer management
- Azure CLI for VM operations (works from any network)
- Docker container management via `az vm run-command`
- One-command cleanup script

### Security
- WireGuard modern cryptography (ChaCha20, Poly1305)
- Password protected Web UI with bcrypt hashing
- SSH key authentication (VM access if needed)
- All VPN traffic encrypted end-to-end
- NSG rules restrict access to required ports only

---

## 📦 Project Structure

```
.
├── deploy-wireguard-azure-vm.sh     # Main deployment script (no SSH required)
├── README.md                        # This file
├── scripts/                         # Supporting scripts
│   ├── cleanup-wireguard.sh        # Complete teardown with dry-run support
│   ├── cleanup-partial-deployment.sh # Clean up failed deployments
│   └── regenerate-configs-v2.sh    # Download configs for existing peers
└── docs/                           # Documentation
    └── DEPLOYMENT-GUIDE.md         # 📖 Complete usage guide
```

---

## 🛠️ Prerequisites

**Required Tools:**

1. **Azure CLI** - Install for your platform:
   - **macOS:** `brew install azure-cli`
   - **Linux (Debian/Ubuntu):** `curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash`
   - **Linux (RPM-based):** `curl -sL https://aka.ms/InstallAzureCLIRPM | sudo bash`
   - **Windows:** Download from [Azure CLI installer](https://aka.ms/installazurecliwindows) or use `winget install -e --id Microsoft.AzureCLI`
   - **Verify:** `az --version`

2. **jq** - JSON processor:
   - **macOS:** `brew install jq`
   - **Linux (Debian/Ubuntu):** `sudo apt-get install jq`
   - **Linux (RPM-based):** `sudo yum install jq` or `sudo dnf install jq`
   - **Windows:** Download from [jq releases](https://stedolan.github.io/jq/download/) or use `winget install jqlang.jq`
   - **Verify:** `jq --version`

3. **curl** - Usually pre-installed on all platforms
   - **Windows:** Included in Windows 10/11 by default
   - **Verify:** `curl --version`

**Additional Requirements:**
- Active Azure subscription with appropriate permissions
- Bash shell (Linux/macOS native, Windows: WSL, Git Bash, or PowerShell alternative)

**Network Requirements:**
- HTTPS (port 443) access for Azure CLI
- No SSH (port 22) access required - works from any network!

**Cost:**
- Approximately **$15-26 USD/month** (default configuration)
- First 100GB bandwidth free
- Can reduce costs by stopping VM when not in use (`az vm deallocate`)
- See cost breakdown below for details

---

## 📖 Documentation

**For detailed instructions, see [DEPLOYMENT-GUIDE.md](docs/DEPLOYMENT-GUIDE.md)**

Topics covered:
- ✅ Prerequisites and setup
- ✅ Deployment options and examples
- ✅ Connecting from desktop/mobile
- ✅ Managing peers and the VPN
- ✅ Troubleshooting common issues
- ✅ Cost optimization tips
- ✅ Security best practices

---

## 🎯 Usage Examples

### Basic Deployment (Recommended)

```bash
# Deploy with defaults - interactive region selection
./deploy-wireguard-azure-vm.sh -p "YourSecurePassword123"

# After deployment, access the Web UI to create peers
```

### Specify Region

```bash
# Deploy to specific region (UAE North in this example)
./deploy-wireguard-azure-vm.sh -p "YourPassword" -l "uaenorth"

# Other popular regions: eastus, westeurope, uksouth, southeastasia
```

### Minimal Deployment

```bash
# No Private DNS (simpler, saves $0.50/month)
./deploy-wireguard-azure-vm.sh -p "YourPassword" --no-private-dns
```

### Custom Configuration

```bash
# Specify everything
./deploy-wireguard-azure-vm.sh \
  -p "YourPassword" \
  -s "your-subscription-id" \
  -r "my-vpn-rg" \
  -l "westus2" \
  --ssh-key "/path/to/key.pub"
```

### Advanced: Key Vault (Optional)

```bash
# Store password in Azure Key Vault (requires Key Vault permissions)
# Adds $1/month to costs
./deploy-wireguard-azure-vm.sh -p "YourPassword" --use-key-vault
```

### Cleanup

```bash
# Preview what will be deleted
./scripts/cleanup-wireguard.sh --dry-run

# Delete everything
./scripts/cleanup-wireguard.sh

# Or use deployment script
./deploy-wireguard-azure-vm.sh --teardown
```

---

## 🔐 Security Notes

**Current setup is suitable for:**
- ✅ Personal VPN usage
- ✅ Testing and development
- ✅ Small team deployments

**For production use, consider:**
- Restrict NSG rules to specific IPs
- Enable Azure Bastion for SSH access
- Implement high availability with multiple VMs
- Add Azure Firewall for traffic inspection
- Enable Network Watcher and logging
- See [DEPLOYMENT-GUIDE.md](docs/DEPLOYMENT-GUIDE.md) for details

---

## 💰 Cost Breakdown

| Resource | Monthly Cost | Included by Default |
|----------|--------------|---------------------|
| VM (B1s) | $10-15 | ✅ |
| Managed Disk (30GB) | $2-3 | ✅ |
| Public IP (Static) | $3-5 | ✅ |
| Private DNS | $0.50 | ✅ |
| Bandwidth (100GB free) | $0-5 | ✅ |
| **TOTAL (default)** | **$15-26** | |
| Key Vault (optional) | $1 | ❌ Use --use-key-vault |

**Save costs:**
- Stop VM when not in use: `az vm deallocate -g rg-wireguard-vpn -n wireguard-vm`
- Skip Private DNS: `--no-private-dns` (saves $0.50/month)
- Don't use Key Vault: default behavior (already excluded)

---

## 🆘 Troubleshooting

### Common Issues

**Can't access Web UI:**
```bash
# Wait 60 seconds after deployment for container startup
curl -I http://<your-ip>:51821

# Check VM is running
az vm show -g rg-wireguard-vpn -n wireguard-vm --query "powerState" -o tsv
```

**VPN not connecting:**
```bash
# Check WireGuard container logs (no SSH required)
az vm run-command invoke -g rg-wireguard-vpn -n wireguard-vm \
  --command-id RunShellScript --scripts 'sudo docker logs wg-easy' \
  --query "value[0].message" -o tsv
```

**Container not running:**
```bash
# Check container status
az vm run-command invoke -g rg-wireguard-vpn -n wireguard-vm \
  --command-id RunShellScript --scripts 'sudo docker ps -a' \
  --query "value[0].message" -o tsv

# Restart container if needed
az vm run-command invoke -g rg-wireguard-vpn -n wireguard-vm \
  --command-id RunShellScript --scripts 'sudo docker restart wg-easy' \
  --query "value[0].message" -o tsv
```

**For more troubleshooting, see [DEPLOYMENT-GUIDE.md](docs/DEPLOYMENT-GUIDE.md#troubleshooting)**

---

## 🎓 How It Works

1. **Deploy Azure Resources:**
   - Resource group, VNet, NSG, Public IP, VM
   - Private DNS zone (optional) for internal resolution
   - All created via Azure CLI in parallel where possible

2. **Install Docker on VM:**
   - Ubuntu 22.04 with Docker CE 29.0+
   - Installed via `az vm run-command` (no SSH required)
   - Uses Azure's internal infrastructure (HTTPS/443 only)

3. **Deploy wg-easy Container:**
   - Privileged container with NET_ADMIN capability
   - Bcrypt password hashing (wg-easy v14+ requirement)
   - Persistent storage at `$HOME/.wg-easy:/etc/wireguard`
   - Deployed via `az vm run-command`

4. **Manage Peers:**
   - Access Web UI at `http://<ip>:51821`
   - Create unlimited peers with one click
   - Download .conf files or scan QR codes
   - All peer management via browser

**Key Innovation:** No SSH access required for any operation. Everything uses `az vm run-command invoke` which works via Azure's internal routing (HTTPS/443), making it compatible with corporate networks, public WiFi, and firewalls that block SSH.

---

## 🔄 What's New (Enhanced Version)

**Major improvements:**
- ✅ **No SSH required** - Deploy and manage from any network via Azure CLI
- ✅ **Universal network compatibility** - Works from corporate networks, public WiFi, firewalls
- ✅ **Auto-detect subscription** - No hardcoded subscription IDs
- ✅ **Private DNS support** - Azure-native internal DNS
- ✅ **Web UI peer creation** - Simple and reliable browser-based management
- ✅ **Azure propagation handling** - Strategic delays prevent deployment failures
- ✅ **Enhanced cleanup script** - Better resource validation and dry-run mode
- ✅ **Comprehensive documentation** - Full deployment guide + no-SSH technical details
- ✅ **Improved error handling** - Robust validation and recovery mechanisms

---

## 📚 Additional Resources

- **WireGuard:** https://www.wireguard.com/
- **wg-easy:** https://github.com/wg-easy/wg-easy
- **Azure CLI:** https://docs.microsoft.com/cli/azure/
- **Cost Calculator:** https://azure.microsoft.com/pricing/calculator/

---



## 🎯 Next Steps

1. **Deploy your VPN:**
   ```bash
   ./deploy-wireguard-azure-vm.sh -p "YourPassword"
   ```

2. **Connect your first device:**
   - Create a peer in the Web UI
   - Desktop: Import the `.conf` file
   - Mobile: Scan the QR code

3. **Access Web UI for management:**
   - Open `http://<your-ip>:51821`
   - Add more peers as needed

4. **When finished:**
   ```bash
   ./scripts/cleanup-wireguard.sh
   ```

---

## 🌐 Universal Network Compatibility

This deployment script works from **any network** - no SSH port required!

✅ Works from:
- Corporate networks with strict firewalls
- Public WiFi (coffee shops, airports, hotels)
- Networks that block SSH (port 22)
- Any location with HTTPS (port 443) access

See [DEPLOYMENT-GUIDE.md](docs/DEPLOYMENT-GUIDE.md) for technical details on how Azure CLI `run-command` enables this.

---

**Questions? Check [DEPLOYMENT-GUIDE.md](docs/DEPLOYMENT-GUIDE.md) for complete documentation!**

**Estimated deployment time:** 7-10 minutes
**Estimated monthly cost:** $15-26 USD
**Difficulty level:** Beginner-friendly
**Network requirements:** HTTPS only (no SSH needed)
