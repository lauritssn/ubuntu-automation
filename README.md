# Ubuntu 24.04 Server Automation

This project provides a comprehensive automation suite for Ubuntu 24.04 server installation and hardening. It transforms a fresh Ubuntu server into a secure, production-ready system with modern security practices, monitoring tools, and optional services like Docker and Wireguard VPN.

## 🎯 Overview

The automation script installs and configures:
- **Security hardening** with modern Ubuntu 24.04 practices and optional SSH 2FA
- **Multi-factor authentication** with Authenticator integration for SSH
- **Antivirus protection** with ClamAV and Maldet integration
- **Intrusion detection** with RKHunter and Fail2Ban
- **Firewall protection** with UFW (IPv6 enabled)
- **System monitoring** with comprehensive Slack notifications and optional Netdata
- **Real-time alerting** with intelligent Slack integration for all monitoring activities
- **Docker support** with rootless mode and custom data directories
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
**Components:** ClamAV, Maldet (integrated with ClamAV backend)

**What it does:**
- **ClamAV:** Real-time antivirus scanning with automatic signature updates
- **Maldet:** Linux malware detection using ClamAV as scanning engine
- **Integration:** Maldet signatures enhance ClamAV detection capabilities
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

### 🐳 Docker Support
**Components:** Docker CE with modern Ubuntu 24.04 setup

**What it does:**
- **Installation:** Latest Docker CE with proper GPG verification
- **Docker Compose:** v2 plugin installation
- **Rootless mode:** Optional rootless Docker for enhanced security
- **Custom storage:** Configurable Docker data directory
- **Security:** Proper user permissions and group management

**Configuration options:**
- **Root mode:** Traditional Docker (requires root privileges)
- **Rootless mode:** User-space Docker (enhanced security, some limitations)
- **Data directory:** Custom location for Docker images/containers

**Recommended:** 🤔 Optional - Only if you plan to use containers

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
- **VPN access:** Accessible via Wireguard VPN only (port 19999)

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

#### Docker Configuration
```bash
# Choose installation mode
Rootless Docker: Enhanced security, some limitations
Root Docker: Full functionality, requires root privileges

# Custom data directory
Default: /var/lib/docker
Custom: /mnt/docker (or your preferred location)
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
2. Choose to create a sudo user (recommended for security)
3. Install an Authenticator app on your mobile device (Google Authenticator, Authy, etc.)
4. Scan the QR code displayed during installation
5. Save emergency backup codes in a secure location
6. Test login in a new session before closing current session

# 2FA Management Commands
/srv/apps/scripts/setup_user_2fa.sh <username>    # Setup 2FA for additional users
/srv/apps/scripts/show_2fa_qr.sh [username]       # Display QR code again
/srv/apps/scripts/disable_user_2fa.sh <username>  # Disable 2FA for a user
```

**2FA Authentication Flow:**
1. **SSH Key Authentication:** Your private key authenticates your identity
2. **2FA Code Entry:** Enter 6-digit code from your Authenticator app
3. **Access Granted:** Both factors must succeed for login

**Security Benefits:**
- **Enhanced protection:** Even if SSH key is compromised, 2FA prevents access
- **Time-based codes:** TOTP codes change every 30 seconds
- **Emergency recovery:** Backup scratch codes for emergency access
- **User-specific:** Each user has their own 2FA configuration
- **Root login disabled:** When sudo user is created, root SSH access is automatically disabled
- **Sudo access:** Use 'sudo su -' for root privileges after logging in as sudo user

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

### Viewing Installation Logs
```bash
# View complete installation log
journalctl -t ubuntu-automation-[TIMESTAMP] --no-pager

# View installation summary
journalctl -t ubuntu-automation-[TIMESTAMP] INSTALL_STEP=summary --no-pager

# View only errors
journalctl -t ubuntu-automation-[TIMESTAMP] -p warning --no-pager

# Use the log viewer script
./view_install_log.sh --list
./view_install_log.sh --summary
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
/usr/local/bin/clamav-scan.sh
/usr/local/bin/rkhunter-scan.sh
/usr/local/bin/rkhunter-update.sh

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

### SSH 2FA Management
```bash
# Setup 2FA for new users
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
- **Docker rootless:** Slight performance overhead but enhanced security
- **Custom Docker storage:** Use faster storage for better performance
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