# Ubuntu Automation Scripts Testing Guide

This guide provides detailed instructions for testing each subscript individually on your Ubuntu 24.04 server.

## Prerequisites

### Server Requirements

- Fresh Ubuntu 24.04 LTS server
- Root access or sudo privileges
- Minimum 2GB RAM and 20GB disk space
- Internet connectivity for package downloads

### Preparation Steps

1. **Clone the repository:**

   ```bash
   git clone <your-repo-url>
   cd ubuntu-automation
   ```

2. **Set execute permissions:**

   ```bash
   chmod +x subscripts/*.sh
   chmod +x utils/**/*.sh
   ```

3. **Create required directories:**

   ```bash
   sudo mkdir -p /srv/apps/{logs,scripts,backups}
   sudo mkdir -p /var/log/{clamav,maldet,rkhunter}
   ```

4. **Create required directories:**

   ```bash
   # Create the directories first with proper permissions
   sudo mkdir -p /srv/apps/{logs,scripts,backups}
   sudo chmod 755 /srv/apps/{logs,scripts,backups}
   sudo mkdir -p /var/log/{clamav,maldet,rkhunter}
   ```

   **Note:** You don't need to manually source the shared functions when testing individual subscripts. Each subscript will automatically source the shared functions when executed.

## Testing Individual Subscripts

**Note:** All subscripts should be executed using the `run_subscript.sh` wrapper to ensure proper sourcing of shared functions:

```bash
# Use run_subscript.sh wrapper (recommended method)
sudo ./run_subscript.sh <script_name>

# Example:
sudo ./run_subscript.sh system_update.sh
```

### 1. System Update (`system_update.sh`)

**Purpose:** Updates system packages and kernel

**Prerequisites:** None
**Estimated time:** 5-15 minutes

```bash
# Test system update
sudo ./run_subscript.sh system_update.sh

# Verify
apt list --upgradable
uname -r  # Check kernel version
```

**Expected results:**

- All packages updated to latest versions
- System reboot may be required for kernel updates

---

### 2. Package Installation (`packages_install.sh`)

**Purpose:** Installs essential system packages and development tools

**Prerequisites:** system_update.sh completed
**Estimated time:** 3-8 minutes

```bash
# Test package installation
sudo ./run_subscript.sh packages_install.sh

# Verify installations
htop --version
iotop --version
git --version
curl --version
```

**Expected results:**

- Essential packages installed: htop, iotop, git, curl, build-essential, etc.
- Development tools available

---

### 3. Network Security (`network_security.sh`)

**Purpose:** Configures comprehensive network hardening

**Prerequisites:** None
**Estimated time:** 1-2 minutes

```bash
# Test network security
sudo ./run_subscript.sh network_security.sh

# Verify sysctl settings
sudo sysctl net.ipv4.tcp_syncookies
sudo sysctl net.ipv4.conf.all.rp_filter
sudo sysctl net.ipv4.icmp_echo_ignore_all

# Test monitoring scripts
sudo /srv/apps/scripts/show_network_security.sh
sudo /srv/apps/scripts/test_network_security.sh
```

**Expected results:**

- Network security sysctl settings applied
- ICMP ping disabled, SYN cookies enabled
- Monitoring scripts functional

---

### 4. Account Security (`account_security.sh`)

**Purpose:** Configures password policies, account lockouts, and sudo security

**Prerequisites:** None
**Estimated time:** 2-3 minutes

```bash
# Test account security
sudo ./run_subscript.sh account_security.sh

# Verify password policies
sudo cat /etc/security/pwquality.conf
sudo cat /etc/security/faillock.conf

# Test sudo logging
sudo cat /etc/sudoers.d/security-policies
sudo ls -la /var/log/sudo-io/

# Test monitoring scripts (installed by account_security.sh)
sudo /srv/apps/scripts/show_sudo_usage.sh
sudo /srv/apps/scripts/show_locked_accounts.sh
```

**Expected results:**

- Strong password policies enforced
- Account lockout after 5 failed attempts
- Sudo commands logged with I/O recording

---

### 5. SSH Security (`ssh_security.sh`)

**Purpose:** Hardens SSH configuration and provides 2FA utilities

**Prerequisites:** account_security.sh completed
**Estimated time:** 2-4 minutes

```bash
# Test SSH security
sudo ./run_subscript.sh ssh_security.sh

# Verify SSH configuration
sudo cat /etc/ssh/sshd_config | grep -E "(PermitRootLogin|PasswordAuthentication|PubkeyAuthentication)"

# Test SSH monitoring scripts (only available after running ssh_security.sh)
sudo /srv/apps/scripts/show_ssh_security.sh
sudo /srv/apps/scripts/test_ssh_security.sh

# Test 2FA utilities (optional - only available after running ssh_security.sh with 2FA enabled)
sudo /srv/apps/scripts/setup_user_2fa.sh testuser
```

**Expected results:**

- Root login disabled, password auth disabled
- SSH hardened with modern algorithms
- 2FA management scripts available

---

### 6. NTP Installation (`ntp_install.sh`)

**Purpose:** Configures time synchronization

**Prerequisites:** None
**Estimated time:** 1-2 minutes

```bash
# Test NTP installation
sudo ./run_subscript.sh ntp_install.sh

# Verify time synchronization
timedatectl status
systemctl status systemd-timesyncd
```

**Expected results:**

- NTP synchronization enabled
- Correct timezone configured
- Time accurately synchronized

---

### 7. Security Tools Installation

#### Secure Shared Memory (`secure_shared_memory_install.sh`)

```bash
# Test secure shared memory
sudo ./run_subscript.sh secure_shared_memory_install.sh

# Verify
mount | grep tmpfs
cat /etc/fstab | grep tmpfs
```

#### Maldet Installation (`maldet_install.sh`)

**Estimated time:** 3-5 minutes

```bash
# Set email for testing
export EMAIL_DOMAIN="yourdomain.com"
export INFO_EMAIL="admin@yourdomain.com"

# Test Maldet installation
sudo ./run_subscript.sh maldet_install.sh

# Verify
maldet --version
ls -la /usr/local/maldetect/

# Test scanning functionality (may return empty if no files in /tmp)
sudo maldet --scan-all /tmp

# Verify user access is enabled
grep "scan_user_access" /usr/local/maldetect/conf.maldet

# Check /etc/default/maldet permissions
ls -la /etc/default/maldet

# If you get "public scanning is enabled but paths do not exist" error:
sudo maldet --mkpubpaths
```

#### ClamAV Installation (`clamav_install.sh`)

**Estimated time:** 5-10 minutes

```bash
# Test ClamAV installation
sudo ./run_subscript.sh clamav_install.sh

# Verify
clamscan --version
systemctl status clamav-daemon
sudo /usr/local/bin/clamav-scan.sh  # Test scan
```

#### RKHunter Installation (`rkhunter_install.sh`)

**Estimated time:** 2-4 minutes

```bash
# Test RKHunter installation
sudo ./run_subscript.sh rkhunter_install.sh

# Verify
rkhunter --version
sudo rkhunter --check --sk  # Quick test
```

#### Fail2Ban Installation (`fail2ban_install.sh`)

**Estimated time:** 2-3 minutes

```bash
# Test Fail2Ban installation
sudo ./run_subscript.sh fail2ban_install.sh

# Verify
systemctl status fail2ban
sudo fail2ban-client status

# Use monitoring script (installed by fail2ban_install.sh)
sudo /srv/apps/scripts/show_fail2ban_status.sh

# Alternative: use from source location if not installed
# sudo ./utils/monitoring/show_fail2ban_status.sh
```

#### Postfix Installation (`postfix_install.sh`)

**Estimated time:** 2-4 minutes

```bash
# Test Postfix installation
sudo ./run_subscript.sh postfix_install.sh

# Verify
systemctl status postfix
echo "Test email" | mail -s "Test" root
```

---

### 8. Swap Installation (`swap_install.sh`)

**Purpose:** Creates encrypted swap file

**Prerequisites:** None
**Estimated time:** 2-5 minutes

```bash
# Test swap installation
sudo ./run_subscript.sh swap_install.sh

# Verify
swapon --show
free -h
cat /proc/swaps
```

**Expected results:**

- Encrypted swap file created and active
- Memory management optimized

---

### 9. Lightweight Monitoring (`lightweight_monitoring_install.sh`)

**Purpose:** Installs basic monitoring tools and scripts

**Prerequisites:** packages_install.sh completed
**Estimated time:** 3-5 minutes

```bash
# Test monitoring installation
sudo ./run_subscript.sh lightweight_monitoring_install.sh

# Verify
sudo /usr/local/bin/check_disk_space.sh
sudo /usr/local/bin/system_health_check.sh
```

**Expected results:**

- Monitoring scripts installed and functional
- System health checks operational

---

### 10. Systemd Timers (`systemd_timers_install.sh`)

**Purpose:** Sets up automated scanning and monitoring

**Prerequisites:** Security tools installed
**Estimated time:** 1-2 minutes

```bash
# Test systemd timers
sudo ./run_subscript.sh systemd_timers_install.sh

# Verify
systemctl list-timers | grep -E "(clamav|maldet|rkhunter)"
systemctl status clamav-scan.timer
```

**Expected results:**

- Automated scanning timers active
- Daily security scans scheduled

---

### 11. UFW Installation (`ufw_install.sh`)

**Purpose:** Configures firewall with intelligent rules

**Prerequisites:** All other services installed
**Estimated time:** 1-2 minutes

```bash
# Test UFW installation (run last!)
sudo ./run_subscript.sh ufw_install.sh

# Verify
sudo ufw status verbose
sudo ufw status numbered
```

**Expected results:**

- Firewall enabled with secure defaults
- SSH access preserved
- Service-specific rules applied

---

### 12. Optional Services

#### Docker Installation (`docker_install.sh`)

**Estimated time:** 3-8 minutes

```bash
# Test Docker installation
export DOCKER_DATA_ROOT="/var/lib/docker"
export DOCKER_ROOTLESS="N"
sudo ./run_subscript.sh docker_install.sh

# Verify
docker --version
systemctl status docker
docker run hello-world
```

#### Netdata Installation (`netdata_install.sh`)

**Estimated time:** 5-10 minutes

```bash
# Test Netdata installation
sudo ./run_subscript.sh netdata_install.sh

# Verify
systemctl status netdata
curl http://localhost:19999
```

#### WireGuard Installation (`wireguard_install.sh`)

**Estimated time:** 2-4 minutes

```bash
# Test WireGuard installation
export WIREGUARD_SUBNET="10.66.66.0/24"
sudo ./run_subscript.sh wireguard_install.sh

# Verify
systemctl status wg-quick@wg0
wg show
add-wg-client testclient
```

#### Dokku Installation (`dokku_install.sh`)

**Estimated time:** 5-15 minutes

```bash
# Test Dokku installation
sudo ./run_subscript.sh dokku_install.sh

# Verify
dokku version
dokku apps:list
```

## Testing Strategy Recommendations

### 1. **Snapshot Testing**

- Take VM snapshots before each test
- Restore snapshot between major tests
- Keep a clean baseline for comparison

### 2. **Incremental Testing**

- Test core security scripts first (network, account, SSH)
- Add monitoring and tools incrementally
- Test UFW last (affects network connectivity)

### 3. **Integration Testing**

- After individual testing, run full installation
- Verify all services work together
- Test cross-dependencies

### 4. **Rollback Testing**

- Test on disposable VMs/containers
- Have backup/restore procedures ready
- Document any issues encountered

## Troubleshooting Common Issues

### Permission Issues

```bash
# Fix permission issues
sudo chown -R root:root /srv/apps/
sudo chmod +x /srv/apps/scripts/*.sh
```

### Missing Dependencies

```bash
# Install missing packages manually
sudo apt update
sudo apt install -y curl wget git
```

### Service Startup Issues

```bash
# Check service status
systemctl status <service-name>
journalctl -u <service-name> -f
```

### Network Connectivity Issues

```bash
# If UFW blocks access, reset firewall
sudo ufw --force reset
sudo ufw allow ssh
sudo ufw enable
```

## Test Results Documentation

Create a test log for each script:

```bash
# Example test log format
echo "=== Testing account_security.sh ===" >> test_results.log
echo "Date: $(date)" >> test_results.log
echo "Status: SUCCESS/FAILED" >> test_results.log
echo "Issues: None/Description" >> test_results.log
echo "Notes: Additional observations" >> test_results.log
echo "" >> test_results.log
```

## Post-Testing Cleanup

After testing, clean up test environment:

```bash
# Remove test users
sudo userdel -r testuser

# Reset firewall if needed
sudo ufw --force reset

# Clean up test files
sudo rm -rf /tmp/test_*

# Review logs
sudo journalctl --since "1 hour ago" | grep -i error
```

This testing approach ensures each subscript works correctly in isolation and provides confidence for full system deployment.
