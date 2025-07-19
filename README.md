# Ubuntu 24.04 Server Automation

This project provides a comprehensive automation suite for Ubuntu 24.04 server installation and hardening. It transforms a fresh Ubuntu server into a secure, production-ready system with modern security practices, monitoring tools, and optional services like Docker and Wireguard VPN.

## 🎯 Overview

The automation script installs and configures:
- **Security hardening** with modern Ubuntu 24.04 practices
- **Antivirus protection** with ClamAV and Maldet integration
- **Intrusion detection** with RKHunter and Fail2Ban
- **Firewall protection** with UFW (IPv6 enabled)
- **System monitoring** with lightweight tools and optional Netdata
- **Docker support** with rootless mode and custom data directories
- **Wireguard VPN** for secure remote access to services
- **Automated scheduling** with systemd timers instead of cronjobs
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

## 📋 Installation Modules

The automation suite is modular, allowing you to choose which components to install:

### 🔒 Core Security Module
**Components:** General system settings, SSH hardening, shared memory protection, sysctl tuning

**What it does:**
- Hardens SSH configuration with Ubuntu 24.04 best practices
- Configures secure shared memory to prevent privilege escalation
- Optimizes kernel parameters for server security
- Installs essential monitoring tools (htop, iotop, build tools)
- Sets up proper timezone and NTP synchronization

**Recommended:** ✅ Yes - Essential for any production server

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
**Components:** Lightweight monitoring tools and optional Netdata

**Lightweight monitoring includes:**
- **htop, iotop:** Interactive process and I/O monitoring
- **sysstat:** Historical system statistics
- **nethogs:** Network bandwidth monitoring per process
- **ncdu:** Disk usage analyzer
- **System health script:** Automated health checks via systemd timers
- **Disk space monitoring:** Automated disk space monitoring with Slack notifications

**Netdata (optional):**
- **Real-time monitoring:** Web-based dashboards
- **Metrics collection:** CPU, memory, disk, network, services
- **Alerting:** Built-in notification system
- **VPN access:** Accessible via Wireguard VPN only (port 19999)

**Recommended:** ✅ Lightweight tools always, Netdata for advanced monitoring needs

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
**Components:** Modern scheduling replacing traditional cronjobs

**What it replaces:**
- Traditional cron-based security scans
- Monitoring script scheduling
- System maintenance tasks

**Benefits:**
- **Better logging:** Integrated with systemd journal
- **Reliability:** Persistent execution and error handling
- **Control:** Easy enable/disable/status checking
- **Dependencies:** Proper service dependency management

**Scheduled tasks:**
- **ClamAV:** Weekly full system antivirus scan
- **RKHunter:** Daily security scans and weekly updates
- **System health:** Periodic system health checks
- **Swap monitoring:** Hourly swap usage monitoring
- **Disk space monitoring:** Every 5 minutes with Slack alerts

**Recommended:** ✅ Yes - Superior to traditional cronjobs

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
# Run system health check manually
/srv/apps/scripts/system_health_check.sh

# Check swap usage
/srv/apps/scripts/check_swap_usage.sh

# Check disk space manually
/srv/apps/scripts/check_disk_space.sh

# Use monitoring aliases (available after installation)
syshealth    # Full system health report
diskcheck    # Manual disk space check with Slack notifications
sysstatus    # Service status
sysload      # System load monitoring
netstat      # Network connections
processes    # Top processes by CPU usage
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
- Create an issue on GitHub with relevant log excerpts

---

**Note:** This automation is specifically designed and tested for Ubuntu 24.04 LTS. While it may work on other versions, Ubuntu 24.04 is the supported platform for all features and optimizations.