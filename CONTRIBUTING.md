# Contributing to WireGuard Azure Deployment Automation

Thank you for your interest in contributing to this project! This document provides guidelines for contributing.

## How to Contribute

### Reporting Issues

Before creating an issue, please:

1. **Search existing issues** - Check if the issue has already been reported
2. **Use issue templates** - Follow the provided templates when available
3. **Provide details** - Include relevant information:
   - Operating system and version
   - Azure CLI version
   - WireGuard version
   - Steps to reproduce
   - Expected vs actual behavior
   - Error messages and logs

### Feature Requests

We welcome feature suggestions! When proposing a feature:

1. **Explain the use case** - Why is this feature needed?
2. **Describe the solution** - How should it work?
3. **Consider alternatives** - What other approaches did you consider?
4. **Note breaking changes** - Will this affect existing users?

### Submitting Pull Requests

#### Before You Start

1. **Check existing PRs** - Someone might already be working on it
2. **Open an issue first** - Discuss significant changes before implementing
3. **Fork the repository** - Make changes in your own fork

#### Pull Request Process

1. **Create a feature branch** - Use descriptive branch names:
   - `feature/add-ipv6-support`
   - `fix/azure-cli-timeout`
   - `docs/improve-readme`

2. **Make your changes**:
   - Follow existing code style
   - Keep changes focused and atomic
   - Update documentation as needed
   - Add comments for complex logic

3. **Test your changes**:
   - Test scripts in a clean Azure environment
   - Verify WireGuard configurations work
   - Check for edge cases
   - Ensure no sensitive data is included

4. **Commit your changes**:
   - Write clear, descriptive commit messages
   - Use conventional commits format (preferred):
     - `feat: add IPv6 support to VPN configuration`
     - `fix: resolve Azure CLI timeout issue`
     - `docs: update deployment guide`
   - Keep commits logical and focused

5. **Submit the PR**:
   - Provide a clear title and description
   - Reference related issues (`Fixes #123`)
   - Explain what changed and why
   - Note any breaking changes
   - Add screenshots/examples if helpful

#### Code Style Guidelines

**Shell Scripts:**
- Use `#!/bin/bash` shebang
- Use 4-space indentation
- Quote variables: `"${variable}"`
- Check command success: `|| { echo "Error"; exit 1; }`
- Add comments for complex operations
- Validate input parameters

**Documentation:**
- Use clear, concise language
- Include code examples
- Keep formatting consistent
- Test all commands before documenting

#### Testing Requirements

Before submitting a PR, verify:

- [ ] Scripts run without errors
- [ ] Generated WireGuard configs are valid
- [ ] Azure resources deploy successfully
- [ ] Documentation is accurate
- [ ] No sensitive data is committed
- [ ] .gitignore patterns work correctly

### Security Considerations

- **Never commit private keys** - Even in examples
- **Sanitize logs** - Remove credentials before sharing
- **Review dependencies** - Ensure third-party tools are trustworthy
- **Report security issues privately** - See [SECURITY.md](SECURITY.md)

## Code Review Process

All submissions require review before merging:

1. **Automated checks** - Must pass (when CI/CD is configured)
2. **Maintainer review** - Code quality and design review
3. **Testing** - Functional verification in Azure
4. **Documentation review** - Ensure docs are updated

## Development Setup

### Prerequisites

- **Azure CLI** installed and configured (see README.md for installation instructions)
- **WireGuard tools** installed (optional, for local testing)
- **Bash shell:**
  - Linux/macOS: Native bash/zsh terminal
  - Windows: WSL (Windows Subsystem for Linux), Git Bash, or compatible shell
- **jq** installed (for JSON processing)
- Azure subscription with appropriate permissions

### Testing Locally

```bash
# Clone your fork
git clone https://github.com/your-username/wireguard-azure.git
cd wireguard-azure

# Make changes
# ... edit files ...

# Test deployment script
cd tools
./deploy-wireguard-azure.sh

# Verify configuration generation
# Check output in wireguard-configs-* directory
```

### Cleanup After Testing

**macOS/Linux/WSL:**
```bash
# Delete test Azure resources
az group delete --name your-test-resource-group --yes

# Remove generated configs (not committed due to .gitignore)
rm -rf tools/wireguard-configs-*/
```

**Windows (PowerShell):**
```powershell
# Delete test Azure resources
az group delete --name your-test-resource-group --yes

# Remove generated configs (not committed due to .gitignore)
Remove-Item -Recurse -Force tools/wireguard-configs-*
```

## Community Guidelines

- **Be respectful** - Treat all contributors with respect
- **Be patient** - Maintainers are volunteers
- **Be constructive** - Provide helpful feedback
- **Be collaborative** - Work together to improve the project

## Questions?

If you have questions about contributing:

1. Check existing documentation
2. Search closed issues
3. Open a discussion or issue
4. Reach out to maintainers

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to making WireGuard deployment on Azure easier and more secure!
