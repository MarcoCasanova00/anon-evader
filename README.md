# Anon-Evader Suite v1.0

A lightweight, standalone anonymization toolkit extracted from killchain-hub framework logic. Provides Tor-based connection anonymization, leak prevention, and user isolation without the complexity of a full penetration testing framework.

## 🚀 Features

- **Tor-based Anonymization**: Routes traffic through Tor network using proxychains4/torsocks
- **User Isolation**: Dedicated `anon` user with hardened environment
- **DNS Leak Prevention**: Forces DNS through Tor to prevent ISP monitoring
- **IPv6 Leak Prevention**: Disables IPv6 to maintain anonymity
- **Connection Testing**: Verify anonymity with IP checks
- **Quick Command Execution**: Run individual commands through proxy
- **Status Monitoring**: Real-time anonymization status checking

## 📁 Files

- `anon-evader.sh` - Main anonymization setup and management tool
- `proxy-runner.sh` - Quick proxy command execution
- `anon-status.sh` - Comprehensive status checker

## 🔧 Installation

### Prerequisites

- Linux system (Ubuntu, Debian, Kali, Arch, etc.)
- Root/sudo access for initial setup
- Bash shell

### Quick Install

```bash
# Download the tools
git clone https://github.com/your-repo/anon-evader.git
cd anon-evader

# Make executable
chmod +x *.sh

# Run setup (requires sudo)
sudo ./anon-evader.sh
```

### Manual Install

```bash
# Copy to system directory
sudo cp *.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/anon-evader.sh
sudo chmod +x /usr/local/bin/proxy-runner.sh
sudo chmod +x /usr/local/bin/anon-status.sh
```

## 🎮 Usage

### 1. Initial Setup

```bash
# Full setup (recommended for first time)
sudo ./anon-evader.sh
# Select option 1: Full Setup

# Quick setup (if dependencies already installed)
sudo ./anon-evader.sh
# Select option 2: Quick Anonymize
```

### 2. Switch to Anonymized User

```bash
# From main menu
sudo ./anon-evader.sh
# Select option 3: Switch to Anon User

# Or directly
sudo -u anon bash
```

### 3. Run Commands Through Proxy

```bash
# Using proxy-runner (recommended)
./proxy-runner.sh curl -s ifconfig.me
./proxy-runner.sh -p torsocks nmap -sS target.com
./proxy-runner.sh -t wget http://example.com  # Test first

# Using anon user aliases (when logged in as anon)
curl ifconfig.me           # Automatically uses proxychains
nmap target.com           # Automatically uses proxychains
curl-tor ifconfig.me      # Uses torsocks
```

### 4. Check Status

```bash
# Comprehensive status check
./anon-status.sh

# Quick anonymity test
sudo ./anon-evader.sh
# Select option 4: Test Anonymity

# Show current status
sudo ./anon-evader.sh
# Select option 5: Show Status
```

### 5. Restore Normal Configuration

```bash
sudo ./anon-evader.sh
# Select option 6: Restore Normal Configuration
```

## 🛡️ Security Features

### User Isolation

- Dedicated `anon` user with separate home directory
- Disabled bash history (`HISTSIZE=0`)
- Custom prompt showing anonymized state
- Limited permissions with sudo access when needed

### Network Anonymity

- **Tor Routing**: All traffic through Tor network
- **DNS Protection**: DNS queries forced through Tor (127.0.0.1)
- **IPv6 Prevention**: IPv6 disabled to prevent leaks
- **Multiple Proxy Methods**: proxychains4, proxychains, torsocks

### Leak Prevention

- DNS leak prevention via `/etc/resolv.conf` modification
- IPv6 leak prevention via sysctl configuration
- Process monitoring for potentially leaking services
- Backup and restore functionality for all configurations

## 📊 Status Indicators

The status checker provides color-coded feedback:

- 🟢 **GREEN**: Component working correctly
- 🔴 **RED**: Component failed or misconfigured  
- 🟡 **YELLOW**: Warning or suboptimal configuration
- 🔵 **BLUE**: Information section headers

## ⚙️ Configuration

### Proxy Methods

- **proxychains4** (default): Most reliable, supports TCP/UDP
- **torsocks**: Lightweight, TCP-only
- **direct**: No proxy (not recommended for anonymous operations)

### Customization

Edit environment in `/home/anon/.bashrc`:

```bash
# Custom aliases
alias my-scan='proxychains4 nmap -sS -p 80,443'

# Custom tools
alias proxy-curl='proxychains4 curl'
alias proxy-wget='proxychains4 wget'
```

## 🔍 Troubleshooting

### Tor Not Starting

```bash
# Check Tor service
sudo systemctl status tor

# Start manually
sudo systemctl start tor

# Alternative start method
sudo tor &
```

### Proxychains Not Working

```bash
# Test proxychains
proxychains4 curl -s ifconfig.me

# Check configuration
cat /etc/proxychains4.conf
```

### DNS Issues

```bash
# Check DNS config
cat /etc/resolv.conf

# Restore normal DNS (temporary)
sudo chattr -i /etc/resolv.conf
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
```

### IPv6 Leaks

```bash
# Check IPv6 status
sysctl net.ipv6.conf.all.disable_ipv6

# Disable IPv6 manually
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
```

## 🚨 Important Notes

### Before Use

1. **Test First**: Always run anonymity tests before operations
2. **Verify Configuration**: Use `anon-status.sh` to verify setup
3. **Backup**: Original configurations backed up to `/tmp/anon-backups/`

### During Use

1. **Stay in Anon User**: Use the dedicated `anon` user for all operations
2. **Monitor Status**: Periodically check anonymity status
3. **Use Provided Tools**: Use `proxy-runner.sh` for consistent proxy usage

### After Use

1. **Restore Configuration**: Use option 6 to restore normal settings
2. **Clear Logs**: Remove temporary logs from `/tmp/`
3. **Exit Anon User**: Return to normal user account

## 📝 Example Workflows

### Basic Anonymous Scan

```bash
# 1. Setup
sudo ./anon-evader.sh  # Option 1 or 2

# 2. Switch to anon user
sudo ./anon-evader.sh  # Option 3

# 3. Verify anonymity
./proxy-runner.sh -t curl -s ifconfig.me

# 4. Run scan
./proxy-runner.sh nmap -sS target.com

# 5. Check results
cat nmap_results.txt
```

### Quick Anonymized Commands

```bash
# Test current IP
./proxy-runner.sh curl -s ifconfig.me

# Download anonymously
./proxy-runner.sh wget -O file.pdf http://example.com/file.pdf

# Port scan through Tor
./proxy-runner.sh -p torsocks nmap -sT -Pn target.com

# Test different proxy methods
./proxy-runner.sh -p proxychains curl -s ifconfig.me
./proxy-runner.sh -p torsocks curl -s ifconfig.me
```

## 🔄 Maintenance

### Regular Tasks

- Update Tor configuration periodically
- Check for system updates that might affect anonymity
- Verify proxy tool functionality
- Clean up logs and temporary files

### Backup Locations

- Original configurations: `/tmp/anon-backups/`
- Session logs: `/tmp/anon-evader.log`
- Command logs: `/tmp/proxy-runner.log`

## 🤝 Contributing

This tool is extracted from the killchain-hub framework. Contributions welcome for:
- Additional proxy methods
- Enhanced status checking
- Better error handling
- Documentation improvements

## ⚠️ Disclaimer

This tool is for educational purposes and authorized security testing only. Users are responsible for ensuring compliance with local laws and regulations. The authors are not responsible for misuse or illegal activities.

## 📄 License

MIT License - see LICENSE file for details.

---

**Made for ethical hackers and security professionals** 🎯