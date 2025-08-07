# Ubuntu 24.04 Server Automation

This project provides a comprehensive automation suite for Ubuntu 24.04 server installation and hardening. It transforms a fresh Ubuntu server into a secure, production-ready system with modern security practices, monitoring tools, and optional services like Docker and Wireguard VPN.

## 🎯 Overview

The automation script installs and configures:

- **Security hardening** with modern Ubuntu 24.04 practices and mandatory SSH 2FA (root login disabled)
- **Multi-factor authentication** with Authenticator integration for SSH
- **User management** with comprehensive user addition script (sudo + 2FA + VPN)
- **Antivirus protection** with ClamAV and Maldet (independent scanning with optional engine sharing)
- **Intrusion detection** with RKHunter and Fail2Ban
- **Firewall protection** with UFW (IPv6 enabled)
- **System monitoring** with comprehensive Slack notifications and optional Netdata
- **Real-time alerting** with intelligent Slack integration for all monitoring activities
- **Wireguard VPN** for secure remote access to services
- **Automated scheduling** with systemd timers and instant notifications
- **Comprehensive logging** with systemd journal integration

## 🚀 Quick Start

### Prerequisites

- Fresh Ubuntu 24.04 server with OpenSSH server installed
- Root access (or sudo privileges)
- Internet connection for package downloads

### Installation

1. **Connect to your server** as root (or use `sudo su root`)

2. **Update system and install Git:**

   ```bash
   apt-get update
   apt-get install git
   ```

3. **Clone the repository:**

   ```bash
   cd /tmp
   git clone https://github.com/lauritssn/ubuntu-automation.git
   ```

4. **Run the installation:**

   ```bash
   cd ubuntu-automation
   bash install.sh
   ```

5. **Follow the interactive prompts** to configure your server according to your needs.

## 🔄 Installation Status Tracking

The automation includes a robust status tracking system that prevents re-installing modules that completed successfully:

### Status Management

- **Automatic tracking:** Each module's success/failure status is recorded
- **Smart retry:** Failed modules can be retried without affecting successful ones
- **Skip successful:** Successfully installed modules are automatically skipped on subsequent runs
- **Status log location:** `/srv/apps/scripts/installation_status.log`

### Viewing Installation Status

```bash

# View current installation status

./view_install_status.sh

# View help and all options

./view_install_status.sh help

```

### Managing Module Status

```bash
# Reset specific module (force reinstall)
./view_install_status.sh reset-module Docker_Installation

# Reset all modules (force complete reinstall)
./view_install_status.sh reset
```

### Status Indicators

- ✅ **SUCCESS:** Module installed successfully, will be skipped
- ❌ **FAILED:** Module installation failed, will be retried
- ⏭️ **SKIPPED:** Module was skipped by user choice

## 📋 Installation Modules

The automation suite is modular, allowing you to choose which components to install:

### 🔒 Core Security Module

**Components:** General system settings, SSH hardening with optional 2FA, shared memory protection, sysctl tuning

**What it does:**

- Hardens SSH configuration with Ubuntu 24.04 best practices
- **Optional SSH 2FA:** Authenticator integration for enhanced security
- Configures secure shared memory to prevent privilege escalation
- Optimizes kernel parameters for server security
- Installs essential monitoring tools (htop, iotop, build tools)
- Sets up proper timezone and NTP synchronization

**SSH 2FA Features:**

- **Authenticator integration:** Compatible with Google Authenticator, Authy, and other TOTP apps
- **Multi-factor authentication:** Requires both SSH key AND 2FA code
- **QR code generation:** Easy mobile app setup with visual QR codes
- **Emergency backup codes:** Secure recovery options
- **User management scripts:** Easy setup for additional users
- **Sudo user creation:** Automatically creates sudo user and disables root SSH login
- **Security hardening:** Combines public key authentication with 2FA

**Recommended:** ✅ Yes - Essential for any production server (2FA highly recommended for enhanced security)

### 🦠 Antivirus & Malware Protection

**Components:** ClamAV, Maldet (independent scanners with optional engine sharing)

**What it does:**

- **ClamAV:** Real-time antivirus scanning with automatic signature updates
- **Maldet:** Independent Linux malware detection that can optionally use ClamAV engine
- **Architecture:** Both tools maintain separate signature databases and run independently
- **Scheduling:** Weekly system scans via systemd timers
- **Alerting:** Email notifications for detected threats

**Recommended:** ✅ Yes - Critical for server security

### 🔍 Intrusion Detection & Response

**Components:** RKHunter, Fail2Ban

**What it does:**

- **RKHunter:** Scans for rootkits, backdoors, and local exploits
- **Fail2Ban:** Automatically bans IP addresses after failed login attempts
- **Monitoring:** Daily and weekly security scans
- **Alerting:** Email notifications for security incidents
- **Integration:** Works with UFW firewall for automatic IP blocking

**Recommended:** ✅ Yes - Essential for detecting and preventing attacks

### 🔥 Firewall Protection (UFW)

**Components:** UFW firewall with Ubuntu 24.04 optimizations

**What it does:**

- **Default policy:** Deny incoming, allow outgoing
- **IPv6 support:** Full IPv4 and IPv6 protection
- **Service access:** HTTP (80) and HTTPS (443) open to world
- **SSH restriction:** Port 22 restricted to specified secure subnet only
- **VPN integration:** Wireguard subnet gets full internal access
- **Logging:** Security event logging for monitoring

**Recommended:** ✅ Yes - Absolutely critical for server security

### 💾 Memory Management & Swap

**Components:** Intelligent swap configuration for Ubuntu 24.04

**What it does:**

- **Dynamic sizing:** Calculates optimal swap based on RAM (4-16GB servers)
- **Modern creation:** Uses `fallocate` for faster allocation
- **ZRAM integration:** Detects and optimizes for Ubuntu 24.04 ZRAM
- **Memory tuning:** Server-optimized swappiness and memory parameters
- **Monitoring:** Automated swap usage alerts via systemd timers

**Swap sizing logic:**

- ≤4GB RAM: Equal swap size for safety
- 4-8GB RAM: Equal swap size for balance
- 8-16GB RAM: 6GB safety buffer
- \>16GB RAM: 4GB emergency buffer

**Recommended:** ✅ Yes - Prevents out-of-memory crashes

### 🐳 Container Support (Podman)

**Components:** Podman with modern Ubuntu 24.04 setup

**What it does:**

- **Podman Installation:** Rootless container engine (Docker-compatible alternative)
- **Rootless by default:** Enhanced security with user namespaces
- **Docker compatibility:** Drop-in replacement for most Docker commands
- **Systemd integration:** Native systemd socket activation and service management
- **No daemon:** Direct container execution without background daemon
- **Pod support:** Kubernetes-style pod management capabilities
- **Security:** Proper user permissions and group management

**Recommended:** 🤔 Optional - Enhanced security container platform

### 📊 System Monitoring

**Components:** Lightweight monitoring tools with comprehensive Slack notifications and optional Netdata

**Lightweight monitoring includes:**

- **htop, iotop:** Interactive process and I/O monitoring
- **sysstat:** Historical system statistics
- **nethogs:** Network bandwidth monitoring per process
- **ncdu:** Disk usage analyzer
- **System health script:** Automated health checks with intelligent alerting
- **Swap usage monitoring:** Memory pressure detection and alerting
- **Disk space monitoring:** Proactive storage monitoring with alerts
- **Security monitoring:** Comprehensive scripts for SSH, Fail2Ban, and network security
- **Service testing:** Validation scripts for all installed components

**📱 Slack Integration Features:**

- **Real-time notifications:** Instant alerts for all monitoring activities
- **Smart status tracking:** Start/finish notifications with duration tracking
- **Intelligent alerting:** Warning and critical thresholds with context
- **Visual indicators:** Emoji-based status (🔍 start, ✅ success, ⚠️ warning, 🚨 critical)
- **Centralized monitoring:** All alerts go to #monitoring channel
- **Detailed context:** Hostname, metrics, and actionable information

**Monitored metrics with Slack alerts:**

- **System Health:** Load average, memory usage, disk space, service status
- **Security Scans:** ClamAV antivirus, RKHunter intrusion detection
- **Resource Usage:** Swap utilization, disk space consumption
- **Service Health:** Critical service failures and system errors

**Netdata (optional):**

- **Real-time monitoring:** Web-based dashboards
- **Metrics collection:** CPU, memory, disk, network, services
- **Alerting:** Built-in notification system
- **VPN access:** Accessible via Wireguard VPN only (port 51820)

**Recommended:** ✅ Lightweight tools with Slack always, Netdata for advanced monitoring needs

### 🔐 Wireguard VPN Server

**Components:** Full Wireguard VPN server setup

**What it does:**

- **Server setup:** Complete Wireguard server configuration
- **Key management:** Automatic server and client key generation
- **Network routing:** IP forwarding and routing for VPN clients
- **Client tools:** Easy client configuration and QR code generation
- **Service access:** VPN clients get full access to all internal services
- **Security:** External access limited to ports 22, 80, 443, and 51820 (Wireguard)

**Use cases:**

- Secure remote access to monitoring tools (Netdata)
- Administrative access to server services
- Secure file transfers and database access
- Mobile device connectivity with QR codes

**Recommended:** ✅ Yes - Essential for secure remote administration

### ⏰ Systemd Timers

**Components:** Modern scheduling with comprehensive Slack notifications

**What it does:**

- **Better logging:** Integrated with systemd journal
- **Reliability:** Persistent execution and error handling
- **Control:** Easy enable/disable/status checking
- **Dependencies:** Proper service dependency management
- **Real-time alerts:** Instant Slack notifications for all activities

**Scheduled tasks with Slack notifications:**

- **ClamAV Antivirus:** Weekly full system scan with threat detection alerts
- **RKHunter Security:** Daily intrusion scans and weekly database updates
- **System Health Check:** Hourly comprehensive health monitoring
- **Swap Usage Monitor:** Hourly memory pressure monitoring
- **Disk Space Monitor:** Every 5 minutes with storage alerts

**📱 Notification Schedule:**

- **Every 5 minutes:** Disk space monitoring
- **Hourly:** System health checks, swap usage monitoring
- **Daily:** RKHunter security scans
- **Weekly:** ClamAV antivirus scans, RKHunter database updates

**Alert Types:**

- 🔄 **Start notifications:** When each task begins
- ✅ **Success notifications:** When tasks complete successfully
- ⚠️ **Warning alerts:** For elevated metrics or minor issues
- 🚨 **Critical alerts:** For immediate attention (virus detection, service failures)

**Recommended:** ✅ Yes - Superior to traditional cronjobs with modern alerting

### 📧 Email Configuration

**Components:** Postfix for system notifications

**What it does:**

- **SMTP setup:** Local mail relay configuration
- **Security alerts:** Email notifications for security events
- **System notifications:** Automated alerts for system issues
- **Integration:** Works with all security and monitoring tools

**Recommended:** ✅ Yes - Essential for receiving security alerts

## 🔧 Configuration Guide

### Basic Configuration

The installation script will prompt you for:

1. **Standardized paths:** Uses `/srv/apps/` directory structure
2. **Timezone:** Server timezone (default: Europe/Copenhagen)
3. **NTP servers:** Time synchronization servers
4. **Email configuration:** Domain and alert email address
5. **Component selection:** Choose which modules to install

### Advanced Configuration

#### Podman Configuration

```bash
# Podman is installed in rootless mode by default
# Runs as dedicated 'podman' user for enhanced security
# No daemon required - containers run directly

# Using Podman
podman-user ps -a                    # List containers
podman-user run hello-world          # Run test container
podman-user pull nginx               # Pull container image
podman-user images                   # List images

# Check Podman status
podman-status                        # Comprehensive status check

# Socket management (for systemd integration)
podman-socket list                   # List socket services
podman-socket status                 # Check socket status
podman-socket start traefik-http     # Start socket service
```

#### Wireguard VPN Configuration

```bash
# VPN subnet configuration
Default: 10.66.66.0/24
Custom: Your preferred private subnet

# Client management
Add clients: /usr/local/bin/add-wg-client <username>
Remove clients: /usr/local/bin/remove-wg-client <username>
Generate QR codes: qrencode -t ansiutf8 < /etc/wireguard/clients/<username>.conf
```

#### SSH 2FA Configuration

```bash
# SSH 2FA with Authenticator setup
1. Enable SSH 2FA during installation when prompted
2. Root SSH login is automatically DISABLED for security
3. Create users after installation: /srv/apps/scripts/add_user.sh --interactive
4. Install an Authenticator app on your mobile device (Google Authenticator, Authy, etc.)
5. Scan the QR code displayed during user creation
6. Save emergency backup codes in a secure location
7. Test login with new user in a new session before closing current session

# 2FA Management Commands (for regular users only)
/srv/apps/scripts/setup_user_2fa.sh <username>    # Setup 2FA for existing users
/srv/apps/scripts/show_2fa_qr.sh [username]       # Display QR code again
/srv/apps/scripts/disable_user_2fa.sh <username>  # Disable 2FA for a user
```

**2FA Authentication Flow:**

1. **SSH Key Authentication:** Your private key authenticates your identity
2. **2FA Code Entry:** Enter 6-digit code from your Authenticator app
3. **Access Granted:** Both factors must succeed for login

**Security Benefits:**

- **Root access disabled:** Root SSH login is completely disabled for security
- **Enhanced protection:** Even if SSH key is compromised, 2FA prevents access
- **Time-based codes:** TOTP codes change every 30 seconds
- **Emergency recovery:** Backup scratch codes for emergency access
- **User-specific:** Each user has their own 2FA configuration
- **Sudo access:** All users get sudo privileges and can become root with 'sudo su -'

#### User Management

```bash
# Comprehensive user addition script (after initial installation)
/srv/apps/scripts/add_user.sh --interactive    # Interactive mode with prompts
/srv/apps/scripts/add_user.sh -u username      # Quick user creation
/srv/apps/scripts/add_user.sh --help           # Show all options

# The script automatically:
1. Creates user account with home directory
2. Adds user to sudo group (full admin privileges)
3. Sets up SSH directory with proper permissions
4. Configures SSH 2FA (if system has 2FA enabled)
5. Creates WireGuard VPN access (if WireGuard is installed)
6. Generates secure password (or accepts custom password)
7. Displays QR codes for 2FA and VPN setup
```

**User Creation Features:**

- **Sudo access:** Users can run commands with sudo and access root via 'sudo su -'
- **SSH 2FA integration:** Automatically configures 2FA if the system supports it
- **WireGuard VPN:** Creates VPN config for secure remote access
- **Secure defaults:** Auto-generated passwords, proper file permissions
- **Validation:** Username format checking, duplicate prevention
- **Interactive mode:** Step-by-step prompts for all configuration options
- **Flexible options:** Skip 2FA or VPN setup if not needed

**Security Notes:**

- Root SSH login is completely DISABLED for security
- Each user gets individual 2FA configuration (separate QR codes and backup codes)
- VPN access is isolated per user with unique IP addresses
- SSH key authentication is required in addition to 2FA
- All users get sudo privileges and can become root with 'sudo su -'

#### Slack Monitoring Configuration

```bash
# Slack webhook setup for monitoring notifications
1. Create a Slack app at https://api.slack.com/apps
2. Add "Incoming Webhooks" feature to your app
3. Create a webhook for your #monitoring channel
4. Copy the webhook URL (starts with https://hooks.slack.com/services/)
5. Enable Slack monitoring during installation

# Example webhook URL format:
https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX
```

**Slack Notification Types:**

- 🔄 **Start notifications:** Task beginning (hourly/daily/weekly)
- ✅ **Success notifications:** Task completion with duration
- ⚠️ **Warning alerts:** Elevated metrics (high memory, disk space, etc.)
- 🚨 **Critical alerts:** Immediate attention needed (viruses, service failures)

**Notification Frequency:**

- **Every 5 minutes:** Disk space monitoring (warnings/errors only)
- **Hourly:** System health and swap monitoring (all statuses)
- **Daily:** RKHunter security scans (all statuses)
- **Weekly:** ClamAV antivirus scans and RKHunter updates (all statuses)

#### Firewall Configuration

```bash
# SSH access restriction
SECURE_SUBNET: Replace with your management IP/subnet
Example: 192.168.1.0/24 or 203.0.113.100/32

# Service access via VPN
All internal services accessible through Wireguard VPN
External access limited to: 22 (SSH), 80 (HTTP), 443 (HTTPS), 51820 (Wireguard)
```

## 📊 Post-Installation

### Installed Utility Scripts

The automation installs comprehensive utility scripts to `/srv/apps/scripts/` for system management:

#### System Management

- **`view_install_log.sh`** - View installation logs with filtering options
- **`view_install_status.sh`** - Check module installation status and reset failed modules
- **`system_health_check.sh`** - Comprehensive system health monitoring with Slack alerts

#### User & Account Management

- **`add_user.sh`** - Create users with sudo, 2FA, and VPN access (interactive/CLI modes)
- **`unlock_account.sh`** - Reset account lockouts using faillock
- **`show_locked_accounts.sh`** - Display locked accounts and failed login attempts
- **`show_sudo_usage.sh`** - Audit recent sudo command usage

#### SSH & 2FA Management

- **`setup_user_2fa.sh`** - Configure 2FA for existing users
- **`show_2fa_qr.sh`** - Display 2FA QR codes for mobile setup
- **`disable_user_2fa.sh`** - Remove 2FA from user accounts

#### Security Monitoring

- **`show_fail2ban_status.sh`** - Comprehensive Fail2Ban monitoring and IP management
- **`show_ssh_attacks.sh`** - Display recent SSH attack attempts
- **`show_ssh_security.sh`** - SSH security configuration overview
- **`show_network_security.sh`** - Network security status and firewall rules

#### Antivirus & Malware

- **`clamav-scan.sh`** - Manual/scheduled ClamAV system scans with Slack alerts
- **`clamav-update.sh`** - Update ClamAV signatures with notification
- **`maldet-scan.sh`** - Linux Malware Detect scans with reporting
- **`maldet-update.sh`** - Update Maldet signatures and configuration

#### Intrusion Detection

- **`rkhunter-scan.sh`** - Manual/scheduled rootkit scans with alerts
- **`rkhunter-update.sh`** - Update RKHunter database and signatures

#### Resource Monitoring

- **`check_disk_space.sh`** - Monitor disk usage with threshold alerts
- **`check_swap_usage.sh`** - Track memory pressure and swap utilization

#### Network & VPN Tools

- **`add-wg-client`** - Add new WireGuard VPN clients
- **`remove-wg-client`** - Remove WireGuard VPN clients
- **`enable_ip_forwarding.sh`** - Configure IP forwarding for VPN
- **`ufw.sh`** - Firewall rule management script

#### Container Management (Podman)

- **`podman-user`** - Execute Podman commands as the podman user with proper environment setup
- **`podman-status`** - Comprehensive Podman installation and service status check
- **`podman-socket`** - Manage socket-activated containers and services

#### Testing & Validation

- **`test_services.sh`** - Validate all installed services and configurations
- **`test_ssh_security.sh`** - Test SSH security configuration
- **`test_network_security.sh`** - Validate network security settings

All scripts include comprehensive help (`--help`) and are designed for Ubuntu 24.04 LTS.

### Viewing Installation Logs

```bash
# View complete installation log
journalctl -t ubuntu-automation-[TIMESTAMP] --no-pager

# View installation summary
journalctl -t ubuntu-automation-[TIMESTAMP] INSTALL_STEP=summary --no-pager

# View only errors
journalctl -t ubuntu-automation-[TIMESTAMP] -p warning --no-pager

# Use the log viewer script
/srv/apps/scripts/view_install_log.sh --list
/srv/apps/scripts/view_install_log.sh --summary
```

### Managing Systemd Timers

```bash
# List all timers
systemctl list-timers

# Check specific timer status
systemctl status clamav-scan.timer
systemctl status rkhunter-scan.timer
systemctl status system-health-check.timer
systemctl status swap-monitor.timer
systemctl status disk-space-monitor.timer

# View timer logs
journalctl -u clamav-scan.service --since yesterday
journalctl -u rkhunter-scan.service --since yesterday
journalctl -u disk-space-monitor.service --since yesterday
```

### Monitoring System Health

```bash
# Run system health check manually (with Slack notifications)
/srv/apps/scripts/system_health_check.sh

# Check swap usage (with Slack notifications)
/srv/apps/scripts/check_swap_usage.sh

# Check disk space manually (with Slack notifications)
/srv/apps/scripts/check_disk_space.sh

# Run security scans manually (with Slack notifications)
/srv/apps/scripts/clamav-scan.sh
/srv/apps/scripts/rkhunter-scan.sh
/srv/apps/scripts/rkhunter-update.sh

# Use monitoring aliases (available after installation)
syshealth    # Full system health report with Slack alerts
diskcheck    # Manual disk space check with Slack notifications
sysstatus    # Service status
sysload      # System load monitoring
netstat      # Network connections
processes    # Top processes by CPU usage
```

### 📱 Slack Monitoring Dashboard

All monitoring scripts send notifications to your configured Slack channel:

**Real-time Alerts:**

- **System health issues:** High load, memory usage, disk space warnings
- **Security threats:** Virus detection, intrusion attempts, failed services
- **Resource monitoring:** Swap usage, storage consumption
- **Task tracking:** Start/completion status for all scheduled tasks

**Sample Slack Messages:**

```
✅ System Health Check completed on server-01 - All systems healthy (Duration: 12s)
⚠️ WARNING: High Memory Usage on server-01 - Memory usage: 85%
🚨 CRITICAL: ClamAV Antivirus Scan on server-01 found 2 infected files! Check logs immediately.
🔄 RKHunter Security Scan started on server-01
```

### User Management

📖 **For comprehensive user management including SSH keys, 2FA setup, VPN access, and troubleshooting, see the [User Management Guide](docs/USER_MANAGEMENT.md)**

**Quick Commands:**

```bash
# Add a new user with sudo, 2FA, and WireGuard access (all-in-one script)
/srv/apps/scripts/add_user.sh --interactive          # Interactive mode
/srv/apps/scripts/add_user.sh -u john                # Create user 'john' with auto-generated password
/srv/apps/scripts/add_user.sh -u jane -p mypassword  # Create user 'jane' with specific password
/srv/apps/scripts/add_user.sh -u bob --no-2fa        # Create user 'bob' without 2FA
/srv/apps/scripts/add_user.sh --help                 # Show help and options
```

### SSH 2FA Management

```bash
# Setup 2FA for existing users
/srv/apps/scripts/setup_user_2fa.sh myuser

# Display QR code for existing user
/srv/apps/scripts/show_2fa_qr.sh myuser

# Display QR code for current user
/srv/apps/scripts/show_2fa_qr.sh

# Disable 2FA for a user
/srv/apps/scripts/disable_user_2fa.sh myuser

# Test SSH 2FA login (in a new terminal)
ssh -i ~/.ssh/mykey user@server
# Enter 2FA code when prompted: 123456

# If sudo user was created, login as sudo user instead of root
ssh -i ~/.ssh/mykey sudouser@server
# Enter 2FA code when prompted: 123456
# Use 'sudo su -' for root access
```

**2FA Troubleshooting:**

```bash
# Check SSH 2FA configuration
grep -E "(ChallengeResponseAuthentication|AuthenticationMethods|PermitRootLogin)" /etc/ssh/sshd_config

# View 2FA setup for a user
cat /home/username/.google_authenticator  # or /root/.google_authenticator for root

# Test SSH configuration
sshd -t

# Check SSH service status
systemctl status ssh

# Check if sudo user can access sudo
sudo -l  # when logged in as sudo user
```

**📖 For detailed SSH key setup, 2FA configuration, troubleshooting guides, and security best practices, see [docs/USER_MANAGEMENT.md](docs/USER_MANAGEMENT.md)**

### Wireguard VPN Management

```bash
# Add new VPN client
add-wg-client username

# Remove VPN client
remove-wg-client username

# View VPN status
systemctl status wg-quick@wg0

# View connected clients
wg show

# Generate QR code for mobile clients
qrencode -t ansiutf8 < /etc/wireguard/clients/username.conf
```

## 🔍 Security Features

### SSH Hardening

- Key-based authentication encouraged
- Root login restrictions
- Connection rate limiting
- Access restricted to secure subnet only

### System Hardening

- Secure shared memory configuration
- Kernel parameter tuning for security
- IPv6 firewall protection
- Service restriction and isolation

### Monitoring & Alerting

- Real-time threat detection
- Automated security scanning
- System health monitoring
- Email notifications for security events

### Network Security

- Comprehensive firewall rules
- VPN-only access to sensitive services
- External access limitation
- Network traffic monitoring

## 🔧 Troubleshooting

### Common Issues

**Installation fails with package errors:**

```bash
# Update package lists and retry
apt-get update
apt-get upgrade
```

**Firewall blocks legitimate access:**

```bash
# Check UFW status
ufw status numbered

# Modify rules in generated script
nano /srv/apps/scripts/ufw.sh
```

**Wireguard VPN not connecting:**

```bash
# Check Wireguard status
systemctl status wg-quick@wg0

# Check configuration
wg show

# View logs
journalctl -u wg-quick@wg0
```

**Email notifications not working:**

```bash
# Check postfix status
systemctl status postfix

# Test email sending
echo "Test" | mail -s "Test Subject" your-email@domain.com
```

### Log Locations

- **Installation logs:** `journalctl -t ubuntu-automation-*`
- **Security scan logs:** `/var/log/clamav/`, `journalctl -u rkhunter-*`
- **System logs:** `journalctl`, `/var/log/syslog`
- **UFW logs:** `journalctl -u ufw`
- **Wireguard logs:** `journalctl -u wg-quick@wg0`

## 📈 Performance Impact

### Resource Usage

- **Minimal CPU impact:** Security scans scheduled during low-usage periods
- **Memory usage:** ~200-500MB additional for security tools
- **Disk usage:** ~1-2GB for packages and logs
- **Network impact:** Negligible for normal operations

### Optimization Tips

- **Swap configuration:** Optimized for 4-16GB RAM servers
- **Systemd timers:** Better resource management than cronjobs

## 🔄 Updates & Maintenance

### Automatic Updates

- **ClamAV signatures:** Updated automatically via freshclam
- **RKHunter database:** Updated weekly via systemd timer
- **System packages:** Manual updates recommended

### Manual Maintenance

```bash
# Update security signatures
freshclam
rkhunter --update

# Review security scan results
journalctl -u clamav-scan.service --since "1 week ago"
journalctl -u rkhunter-scan.service --since "1 week ago"

# Update system packages
apt-get update && apt-get upgrade
```

## 📚 Advanced Topics

### Customizing Security Scans

Edit systemd timer configurations:

- `/etc/systemd/system/clamav-scan.timer`
- `/etc/systemd/system/rkhunter-scan.timer`

### Extending Monitoring

Add custom monitoring scripts to:

- `/srv/apps/scripts/`
- Create corresponding systemd timers for scheduling

### Network Hardening

Review and customize UFW rules in:

- `/srv/apps/scripts/ufw.sh`

## 📄 License

This project is licensed under the **Apache License Version 2.0**. See the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Test on Ubuntu 24.04
4. Submit a pull request

## 📞 Support

For issues and questions:

- Check the troubleshooting section above
- Review installation logs with `view_install_log.sh`
- Check installation status with `view_install_status.sh`
- Create an issue on GitHub with relevant log excerpts

---

**Note:** This automation is specifically designed and tested for Ubuntu 24.04 LTS. While it may work on other versions, Ubuntu 24.04 is the supported platform for all features and optimizations.

## Troubleshooting

### ClamAV Issues

ClamAV can sometimes cause startup problems, typically due to:

1. **ClamAV Database Issues**: Ownership or missing signature files
2. **Database File Ownership**: Mixed ownership of signature database files
3. **Incomplete Cleanup**: Leftover files from previous installations

**Common Solutions:**

```bash
# Check ClamAV status
sudo systemctl status clamav-daemon

# Run ClamAV diagnostics
sudo ./diagnose_clamav.sh

# Clean reinstall ClamAV
sudo ./run_subscript.sh clamav_install.sh

# If Maldet is installed, update signatures after ClamAV is working
sudo maldet --update-sigs
```

**Why ClamAV Causes Trouble:**

- **Permission Sensitivity**: The `clamav` user must have read access to all signature files
- **Database Integrity**: Missing or corrupted signature files can prevent daemon startup
- **Update Conflicts**: Concurrent updates can leave the system in an inconsistent state
- **Configuration Issues**: Incorrect paths or settings in daemon configuration

The installation script now includes robust cleanup and retry logic to handle these issues automatically.
