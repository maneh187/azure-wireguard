# Security Policy

## Reporting Security Vulnerabilities

We take the security of this WireGuard Azure deployment automation project seriously. If you discover a security vulnerability, please report it responsibly.

### How to Report

**Please do NOT open a public GitHub issue for security vulnerabilities.**

Instead, please report security issues by:

1. **Email**: Send details to the repository maintainer via GitHub
2. **GitHub Security Advisories**: Use the "Report a vulnerability" button in the Security tab (if available)

### What to Include

When reporting a security vulnerability, please include:

- Description of the vulnerability
- Steps to reproduce the issue
- Potential impact
- Suggested fix (if available)

### Response Timeline

- **Initial Response**: Within 48 hours
- **Status Update**: Within 7 days
- **Fix Timeline**: Varies by severity (critical issues prioritized)

### Security Scope

This project automates WireGuard VPN deployment on Azure. Security concerns include:

- **In Scope**:
  - Vulnerabilities in deployment scripts
  - Insecure default configurations
  - Credential exposure risks
  - Azure resource permission issues
  - WireGuard configuration weaknesses

- **Out of Scope**:
  - Vulnerabilities in WireGuard itself (report to [WireGuard project](https://www.wireguard.com/))
  - Azure platform vulnerabilities (report to Microsoft)
  - Third-party dependencies (report to respective projects)

## Security Best Practices

When using this automation tool:

1. **Never commit WireGuard configuration files** - The .gitignore is configured to prevent this
2. **Rotate keys regularly** - Regenerate WireGuard keys periodically
3. **Secure your Azure credentials** - Use Azure Key Vault or secure credential storage
4. **Review generated configs** - Verify configurations before deployment
5. **Monitor access logs** - Track WireGuard connection attempts
6. **Keep software updated** - Regularly update WireGuard and Azure CLI tools

## Known Security Considerations

- Generated WireGuard configurations contain private keys - handle securely
- Azure credentials must be properly secured (never hardcode in scripts)
- Network Security Groups should be properly configured to limit access
- SSH keys for VM access should be protected

## Security Updates

Security patches will be released as needed. Watch this repository for security announcements.
