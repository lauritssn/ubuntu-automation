# Ansible Migration Guide for Ubuntu Automation

This document provides a comprehensive overview for converting this bash-based Ubuntu 24.04 automation suite into Ansible playbooks with proper separation of concerns.

---

## Process Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                        UBUNTU 24.04 SERVER HARDENING FLOW                           │
└─────────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────┐
│   PHASE 1:      │
│   FOUNDATION    │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│  1. System Update          ──►  2. Package Installation  ──►  3. Journald Config    │
│  (system_update.sh)            (packages_install.sh)         (journald_config.sh)   │
│                                                                                      │
│  • apt update/upgrade          • Core utilities              • Log retention: 13mo  │
│  • autoremove                  • Build tools                 • File rotation: daily │
│  • Security patches            • Security packages           • Max files: 400       │
└─────────────────────────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────┐
│   PHASE 2:      │
│   HARDENING     │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│  4. Network Security       ──►  5. Account Security     ──►  6. SSH Security        │
│  (network_security.sh)         (account_security.sh)        (ssh_security.sh)       │
│                                                                                      │
│  • Sysctl hardening            • Password policies          • Disable root login    │
│  • IP forwarding OFF           • Account lockout (5 tries)  • Key-only auth         │
│  • ICMP disabled               • Sudo security + logging    • 2FA integration       │
│  • TCP SYN cookies             • Session timeout (30min)    • Modern ciphers only   │
│  • DNS security                • faillock configuration     • Rate limiting         │
│  • Iptables logging            • Root password locked       • Privilege separation  │
└─────────────────────────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────┐
│   PHASE 3:      │
│   TIME & MEMORY │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│  7. NTP Installation       ──►  8. Secure Shared Memory ──►  9. Swap Configuration  │
│  (ntp_install.sh)              (secure_shared_memory.sh)    (swap_install.sh)       │
│                                                                                      │
│  • systemd-timesyncd           • /dev/shm noexec,nosuid     • Dynamic sizing        │
│  • Custom NTP servers          • fstab modification         • ZRAM detection        │
│  • Chrony removal              • Prevents priv escalation   • Swappiness tuning     │
└─────────────────────────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────┐
│   PHASE 4:      │
│   SECURITY      │
│   TOOLS         │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│  10. Maldet               ──►  11. ClamAV               ──►  12. RKHunter            │
│  (maldet_install.sh)           (clamav_install.sh)          (rkhunter_install.sh)   │
│                                                                                      │
│  • Download from rfxn.com      • Install from apt          • Rootkit scanner        │
│  • Signature updates           • freshclam daemon          • Property updates       │
│  • ClamAV engine optional      • Database ownership        • Email alerts           │
│  • Email notifications         • Exclusion handling        • Weekly scans           │
└─────────────────────────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│  13. Fail2Ban             ──►  14. Postfix                                           │
│  (fail2ban_install.sh)         (postfix_install.sh)                                  │
│                                                                                      │
│  • SSH protection              • Local mail relay                                    │
│  • Port scan detection         • System notifications                               │
│  • WireGuard protection        • Root mail forwarding                               │
│  • Recidive (repeat ban)       • Security alerts                                    │
└─────────────────────────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────┐
│   PHASE 5:      │
│   OPTIONAL      │
│   SERVICES      │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│  15. Podman (Optional)    ──►  16. Netdata (Optional)   ──►  17. WireGuard (Opt)    │
│  (podman_install.sh)           (netdata_install.sh)         (wireguard_install.sh) │
│                                                                                      │
│  • Rootless containers         • Real-time monitoring      • VPN server setup       │
│  • Dedicated 'podman' user     • Web dashboard             • Key generation         │
│  • Socket activation           • VPN-only access           • Client management      │
│  • RKHunter whitelisting       • Metrics collection        • IP forwarding          │
└─────────────────────────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────┐
│   PHASE 6:      │
│   MONITORING &  │
│   AUTOMATION    │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│  18. Lightweight Monitoring ─►  19. Systemd Timers      ──►  20. UFW Firewall       │
│  (lightweight_monitoring.sh)   (systemd_timers.sh)          (ufw_configure.sh)      │
│                                                                                      │
│  • sysstat, nethogs, ncdu      • ClamAV weekly scan        • Default deny incoming  │
│  • System health scripts       • RKHunter daily scan       • SSH restricted to      │
│  • Disk/swap monitoring        • Maldet scans               secure subnet          │
│  • Bash aliases                • Health checks hourly      • WireGuard routing      │
│  • Slack notifications         • Disk checks 5-min         • IPv6 enabled           │
└─────────────────────────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              INSTALLATION COMPLETE                                   │
│                                                                                      │
│  Post-Install: User Management (add_user.sh)                                        │
│  • Create users with/without sudo                                                   │
│  • Setup SSH 2FA per user                                                           │
│  • Create WireGuard VPN profiles                                                    │
│  • VPN-only clients (no system account)                                             │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Ansible Role Structure (Recommended)

```
ansible-ubuntu-hardening/
├── inventories/
│   ├── production/
│   │   ├── hosts.yml
│   │   └── group_vars/
│   │       └── all.yml
│   └── staging/
│       └── hosts.yml
├── roles/
│   ├── common/                    # Foundation packages & updates
│   ├── journald/                  # Log retention configuration
│   ├── network_security/          # Sysctl & network hardening
│   ├── account_security/          # PAM, password policies, faillock
│   ├── ssh_security/              # SSH hardening + 2FA
│   ├── ntp/                       # Time synchronization
│   ├── swap/                      # Swap file configuration
│   ├── secure_memory/             # /dev/shm hardening
│   ├── clamav/                    # Antivirus
│   ├── maldet/                    # Malware detection
│   ├── rkhunter/                  # Rootkit hunter
│   ├── fail2ban/                  # Intrusion prevention
│   ├── postfix/                   # Mail relay
│   ├── monitoring/                # Lightweight monitoring + scripts
│   ├── systemd_timers/            # Scheduled tasks
│   ├── ufw/                       # Firewall
│   ├── podman/                    # Container runtime (optional)
│   ├── wireguard/                 # VPN server (optional)
│   ├── netdata/                   # Advanced monitoring (optional)
│   └── user_management/           # User creation tasks
├── playbooks/
│   ├── site.yml                   # Full installation
│   ├── security-only.yml          # Just security hardening
│   ├── add-user.yml               # User management
│   └── vpn-client.yml             # VPN-only client creation
└── files/                         # Config file templates
```

---

## Module Details & Conversion Notes

### PHASE 1: Foundation

#### 1. System Update (`common` role)

**Goal:** Ensure system is fully patched with latest security updates.

**Source:** `subscripts/system_update.sh`

**Ansible Tasks:**
```yaml
- name: Update apt cache
  ansible.builtin.apt:
    update_cache: yes
    cache_valid_time: 3600

- name: Upgrade all packages
  ansible.builtin.apt:
    upgrade: dist

- name: Remove unused packages
  ansible.builtin.apt:
    autoremove: yes
```

**Cautions:**
- Use `cache_valid_time` to prevent unnecessary updates
- Consider using `apt_with_lock_retry` pattern for CI/CD environments where multiple apt processes may conflict
- May require reboot after kernel updates - handle with `ansible.builtin.reboot` and `wait_for_connection`

---

#### 2. Package Installation (`common` role)

**Goal:** Install all required packages for the hardening suite.

**Source:** `subscripts/packages_install.sh`

**Package Groups:**
| Category | Packages |
|----------|----------|
| Essential | curl, wget, git, unzip, tar, gzip |
| Build Tools | gcc, build-essential, libc6-dev, dkms, linux-headers-generic |
| Monitoring | htop, iotop, sysstat, acct, atop |
| Security | openssl, sqlite3, libsqlite3-dev |
| Perl/Network | perl, libnet-ssleay-perl, libauthen-pam-perl, libpam-runtime, libio-pty-perl |
| SSH/2FA | libpam-google-authenticator, pamtester, qrencode |
| Firewall | ufw, fail2ban |
| Antivirus | clamav, clamav-daemon, clamav-freshclam |

**Cautions:**
- Install in logical groups to track failures
- Pre-configure debconf for postfix to avoid interactive prompts:
  ```yaml
  - name: Preconfigure postfix
    ansible.builtin.debconf:
      name: postfix
      question: "postfix/main_mailer_type"
      value: "Internet Site"
      vtype: select
  ```

---

#### 3. Journald Configuration (`journald` role)

**Goal:** Configure systemd journal retention for 13 months with daily rotation.

**Source:** `subscripts/journald_config.sh`

**Key Settings:**
```ini
[Journal]
SystemMaxFiles=400
MaxRetentionSec=13month
MaxFileSec=1day
```

**Cautions:**
- Backup existing config before modification
- Restart `systemd-journald` service after changes
- Validate config with `systemd-analyze verify` if available

---

### PHASE 2: Hardening

#### 4. Network Security (`network_security` role)

**Goal:** Harden kernel network parameters and enable port scan detection.

**Source:** `subscripts/network_security.sh`

**Key Files:**
- `/etc/sysctl.d/30-enhanced-network-security.conf`
- `/etc/systemd/resolved.conf.d/security.conf`
- `/etc/network/if-pre-up.d/network-security`

**Sysctl Settings:**
| Setting | Value | Purpose |
|---------|-------|---------|
| net.ipv4.ip_forward | 0 | Disable routing (VPN enables separately) |
| net.ipv4.tcp_syncookies | 1 | SYN flood protection |
| net.ipv4.conf.all.rp_filter | 1 | Reverse path filtering |
| net.ipv4.icmp_echo_ignore_all | 1 | Block ping responses |
| net.ipv4.conf.all.accept_source_route | 0 | Block source routing |
| net.ipv4.conf.all.accept_redirects | 0 | Block ICMP redirects |

**Iptables Rules for Port Scan Detection:**
- SYN scan logging
- Stealth scan detection (FIN, NULL, XMAS)
- Port probing detection
- SYN flood protection

**Cautions:**
- IP forwarding is **disabled by default** - WireGuard role re-enables it via `/etc/sysctl.d/40-wireguard.conf`
- ICMP is disabled - may affect monitoring systems that rely on ping
- Install `iptables-persistent` to persist rules across reboots
- Test sysctl settings don't break existing applications

---

#### 5. Account Security (`account_security` role)

**Goal:** Configure password policies, account lockout, and sudo security.

**Source:** `subscripts/account_security.sh`

**Components:**

| Component | Configuration |
|-----------|---------------|
| Password Quality | `/etc/security/pwquality.conf` - 12+ chars, complexity |
| Account Lockout | `/etc/security/faillock.conf` - 5 attempts, 10min lockout |
| Sudo Security | `/etc/sudoers.d/security-policies` - logging, TTY required |
| Session Timeout | `/etc/profile.d/session-timeout.sh` - 30min idle logout |
| Login Defaults | `/etc/login.defs` - 90 day password max, yescrypt encryption |

**Cautions:**
- Use `pam-auth-update --enable faillock` on Ubuntu 24.04 (not pam_tally2)
- Root password is **locked** - ensure sudo users exist first
- Test PAM changes in a separate session before disconnecting
- Backup all PAM files before modification - mistakes can lock you out
- Create `/var/run/faillock` directory with correct permissions

---

#### 6. SSH Security (`ssh_security` role)

**Goal:** Harden SSH with key-only auth, 2FA, and modern cryptography.

**Source:** `subscripts/ssh_security.sh`

**SSH Configuration (`/etc/ssh/sshd_config`):**
```
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication yes
AuthenticationMethods publickey publickey,keyboard-interactive
MaxAuthTries 5
LoginGraceTime 2m
AllowAgentForwarding no
AllowTcpForwarding no
X11Forwarding no
```

**2FA PAM Configuration:**
Add to `/etc/pam.d/sshd`:
```
auth required pam_google_authenticator.so
```

**Cautions:**
- **CRITICAL:** Always test SSH in a new session before closing current session
- Root login is **completely disabled** - create admin users first
- 2FA requires `libpam-google-authenticator` package
- Create `/run/sshd` directory with correct permissions
- Keep a console/IPMI backup access method
- Modern ciphers may break very old SSH clients

---

### PHASE 3: Time & Memory

#### 7. NTP Installation (`ntp` role)

**Goal:** Configure time synchronization using systemd-timesyncd.

**Source:** `subscripts/ntp_install.sh`

**Ansible Approach:**
```yaml
- name: Enable NTP synchronization
  ansible.builtin.command: timedatectl set-ntp true

- name: Configure NTP servers
  ansible.builtin.template:
    src: timesyncd.conf.j2
    dest: /etc/systemd/timesyncd.conf
  notify: restart systemd-timesyncd
```

**Cautions:**
- Remove chrony if installed (conflicts with timesyncd)
- Verify NTP is working: `timedatectl status`

---

#### 8. Secure Shared Memory (`secure_memory` role)

**Goal:** Prevent privilege escalation via /dev/shm.

**Source:** `subscripts/secure_shared_memory_install.sh`

**fstab Entry:**
```
tmpfs /dev/shm tmpfs defaults,noexec,nosuid 0 0
```

**Cautions:**
- Some applications may require exec on /dev/shm (rare)
- **Requires reboot** to take effect
- Backup fstab before modification

---

#### 9. Swap Configuration (`swap` role)

**Goal:** Create optimally-sized swap file with server-tuned parameters.

**Source:** `subscripts/swap_install.sh`

**Sizing Logic:**
| RAM | Swap Size | Reason |
|-----|-----------|--------|
| ≤4GB | Equal to RAM | Memory safety |
| 4-8GB | Equal to RAM | Balance |
| 8-16GB | 6GB | Safety buffer |
| >16GB | 4GB | Emergency buffer |

**Sysctl Settings:**
```
vm.swappiness=60
vm.vfs_cache_pressure=50
vm.dirty_ratio=15
vm.dirty_background_ratio=5
```

**Cautions:**
- Remove existing swap files/entries before creating new
- Use `fallocate` for fast allocation, fallback to `dd`
- Check for ZRAM (Ubuntu 24.04 default) and account for it

---

### PHASE 4: Security Tools

#### 10. Maldet Installation (`maldet` role)

**Goal:** Install Linux Malware Detect with optional ClamAV engine integration.

**Source:** `subscripts/maldet_install.sh`

**Installation:**
1. Download from `https://www.rfxn.com/downloads/maldetect-current.tar.gz`
2. Extract and run `install.sh`
3. Configure `/usr/local/maldetect/conf.maldet`

**Key Configuration:**
```bash
email_alert=1
email_addr="admin@example.com"
quar_hits=1
quar_clean=1
scan_clamscan=1           # Use ClamAV engine
scan_clamscan_daemon=1    # Use ClamAV daemon
autoupdate_signatures=1
```

**Cautions:**
- Downloaded from external source - verify integrity
- Signature download may fail on first attempt (network issues) - implement retries
- `inotify-tools` package required
- Clean up `/tmp/maldetect-*` after installation

---

#### 11. ClamAV Installation (`clamav` role)

**Goal:** Install and configure ClamAV antivirus with proper database setup.

**Source:** `subscripts/clamav_install.sh`

**Service Order:**
1. Stop both services
2. Fix config files (remove `Example` line)
3. Set directory permissions (`clamav:clamav`)
4. Run `freshclam` manually
5. Start `clamav-freshclam` first
6. Wait for it to be ready
7. Start `clamav-daemon`

**Cautions:**
- **COMMON ISSUE:** Database ownership problems
  ```bash
  chown -R clamav:clamav /var/lib/clamav/
  ```
- Comment out `Example` line in both config files
- Needs ~300MB+ disk space for databases
- `freshclam` must complete before daemon starts
- Create `/var/run/clamav` with correct permissions
- First database download takes 5-10 minutes

---

#### 12. RKHunter Installation (`rkhunter` role)

**Goal:** Install rootkit scanner with automated updates.

**Source:** `subscripts/rkhunter_install.sh`

**Config Files:**
- `/etc/default/rkhunter` - Daily scan settings
- `/etc/rkhunter.conf` - Scan configuration

**Key Tasks:**
```bash
rkhunter --update         # Update signatures
rkhunter --propupd        # Update file properties
rkhunter --check          # Initial scan
```

**Cautions:**
- Comment out `WEB_CMD` line to allow remote updates
- Will generate warnings for Podman binaries - whitelist them
- Exit codes can be misleading (warnings ≠ failures)
- Run `--propupd` after any system changes

---

#### 13. Fail2Ban Installation (`fail2ban` role)

**Goal:** Configure intrusion prevention with SSH, WireGuard, and port scan protection.

**Source:** `subscripts/fail2ban_install.sh`

**Jails Configured:**
| Jail | Max Attempts | Ban Time | Purpose |
|------|--------------|----------|---------|
| sshd | 3 | 2 hours | SSH brute force |
| wireguard | 5 | 1 hour | VPN attacks |
| portscan | 3 | 24 hours | Scan detection |
| recidive | 3 | 1 week | Repeat offenders |

**Custom Filters:**
- `/etc/fail2ban/filter.d/wireguard.conf`
- `/etc/fail2ban/filter.d/portscan.conf`

**Cautions:**
- Test configuration: `fail2ban-client --test`
- Ensure log files exist before enabling jails
- Works with iptables logging from network_security role

---

#### 14. Postfix Installation (`postfix` role)

**Goal:** Configure local mail relay for system notifications.

**Source:** `subscripts/postfix_install.sh`

**Configuration:**
```bash
myhostname = server.example.com
mydomain = example.com
inet_interfaces = loopback-only
mydestination = localhost
```

**Cautions:**
- Pre-configure debconf to avoid interactive prompts
- Configure `/etc/aliases` for root mail forwarding
- Run `newaliases` after alias changes
- Test with: `echo "Test" | mail -s "Test" admin@example.com`

---

### PHASE 5: Optional Services

#### 15. Podman Installation (`podman` role)

**Goal:** Install rootless container runtime with dedicated user.

**Source:** `subscripts/podman_install.sh`

**Setup:**
1. Install packages: `podman, uidmap, dbus-user-session, crun, buildah, skopeo`
2. Create `podman` user
3. Configure subuid/subgid (100000:65536)
4. Create container configs in `/home/podman/.config/containers/`
5. Enable user lingering for systemd user services
6. Create management scripts: `podman-user`, `podman-status`, `podman-socket`

**Cautions:**
- Requires `loginctl enable-linger podman`
- Socket activation needs proper XDG_RUNTIME_DIR
- Add binaries to RKHunter whitelist
- Whitelist `/dev/shm/libpod_*` in RKHunter
- IP forwarding must be enabled for container networking

---

#### 16. WireGuard Installation (`wireguard` role)

**Goal:** Configure VPN server with client management.

**Source:** `subscripts/wireguard_install.sh`

**Setup:**
1. Install packages: `wireguard, wireguard-tools, qrencode`
2. Generate server keys in `/etc/wireguard/`
3. Create `wg0.conf` with NAT rules
4. Enable IP forwarding via `/etc/sysctl.d/40-wireguard.conf`
5. Install client management scripts

**Default Subnet:** `10.66.66.0/24`

**Cautions:**
- Server IP is `X.X.X.1` in the subnet
- PostUp/PostDown iptables rules use detected default interface
- Client configs stored in `/etc/wireguard/clients/`
- This role **re-enables IP forwarding** (overrides network_security)

---

### PHASE 6: Monitoring & Automation

#### 17. Lightweight Monitoring (`monitoring` role)

**Goal:** Install monitoring tools and health check scripts.

**Source:** `subscripts/lightweight_monitoring_install.sh`

**Packages:** `sysstat, nethogs, ncdu, tree`

**Scripts Deployed:**
- `/srv/apps/scripts/system_health_check.sh`
- `/srv/apps/scripts/check_disk_space.sh`
- `/srv/apps/scripts/check_swap_usage.sh`

**Bash Aliases:**
```bash
alias syshealth='/srv/apps/scripts/system_health_check.sh'
alias diskcheck='/srv/apps/scripts/check_disk_space.sh'
```

**Cautions:**
- Enable sysstat: `ENABLED="true"` in `/etc/default/sysstat`
- Replace `{{SLACK_WEBHOOK_URL}}` placeholder in scripts

---

#### 18. Systemd Timers (`systemd_timers` role)

**Goal:** Configure scheduled security scans and health checks.

**Source:** `subscripts/systemd_timers_install.sh`

**Timer Schedule:**
| Timer | Frequency | Purpose |
|-------|-----------|---------|
| disk-space-monitor | 5 minutes | Storage alerts |
| swap-monitor | Hourly | Memory pressure |
| system-health-check | Hourly | Overall health |
| rkhunter-scan | Daily | Rootkit detection |
| clamav-scan | Weekly | Antivirus scan |
| rkhunter-update | Weekly | Update signatures |
| maldet-scan | Weekly | Malware detection |
| maldet-update | Weekly | Update signatures |

**Cautions:**
- Verify ClamAV daemon is running before enabling timers
- Each timer has a corresponding `.service` and `.timer` file
- Replace Slack webhook placeholder in all scripts
- Run `systemctl daemon-reload` after installing units

---

#### 19. UFW Firewall (`ufw` role)

**Goal:** Configure firewall with service-specific rules.

**Source:** `subscripts/ufw_configure.sh`

**Default Policy:**
- Deny incoming
- Allow outgoing
- IPv6 enabled
- Logging enabled

**Rule Logic:**
| Condition | Rule |
|-----------|------|
| Always | Loopback allowed |
| If Podman | Ports 80, 443 open to world |
| If SECURE_SUBNET set | SSH limited to that subnet |
| If no SECURE_SUBNET | SSH rate-limited from anywhere |
| If WireGuard | Port 51820/udp open, VPN subnet full access |

**Cautions:**
- **MUST be last** - depends on other installed services
- Enable with `ufw --force enable` (non-interactive)
- Test SSH access before enabling
- Backup existing rules before applying

---

## Variable Reference

### Required Variables

```yaml
# Email Configuration
email_domain: "example.com"
info_email: "admin@example.com"

# Network Security
secure_subnet: "192.168.1.0/24"      # SSH access restriction
secure_subnet_desc: "Office Network"

# Timezone
timezone: "Europe/Copenhagen"

# NTP
ntp_server: "dk.pool.ntp.org"
ntp_fallback: "pool.ntp.org"
```

### Optional Variables

```yaml
# Slack Integration
enable_slack_monitoring: false
slack_webhook_url: ""

# WireGuard VPN
do_wireguard_install: false
wireguard_subnet: "10.66.66.0/24"

# Optional Services
do_podman_install: false
do_netdata_install: false
do_ssh_2fa: true
```

---

## User Management

The `add_user.sh` script supports three user types:

### 1. Full User with Sudo
```bash
./add_user.sh -u admin --sudo
```
- System account with SSH access
- Sudo privileges
- Optional 2FA
- Optional WireGuard VPN

### 2. Standard User (No Sudo)
```bash
./add_user.sh -u developer --no-sudo
```
- System account with SSH access
- No sudo privileges
- Optional 2FA
- Optional WireGuard VPN

### 3. VPN-Only Client
```bash
./add_user.sh -u client1 --vpn-only
```
- No system account
- WireGuard config only
- QR code for mobile setup

### Ansible User Management Playbook

```yaml
# playbooks/add-user.yml
- hosts: servers
  vars:
    new_user:
      username: "developer"
      enable_sudo: false
      setup_2fa: true
      setup_vpn: true
  tasks:
    - name: Create user
      ansible.builtin.user:
        name: "{{ new_user.username }}"
        shell: /bin/bash
        create_home: yes

    - name: Add to sudo group
      ansible.builtin.user:
        name: "{{ new_user.username }}"
        groups: sudo
        append: yes
      when: new_user.enable_sudo

    - name: Setup SSH directory
      ansible.builtin.file:
        path: "/home/{{ new_user.username }}/.ssh"
        state: directory
        owner: "{{ new_user.username }}"
        mode: '0700'
```

---

## Critical Warnings

### 1. Order Matters
The installation order is critical. Key dependencies:
- **Account security** before SSH security (users need to exist)
- **Network security** before WireGuard (base sysctl first)
- **ClamAV** before systemd timers (daemon must be running)
- **UFW last** (needs to know what services are installed)

### 2. Don't Lock Yourself Out
- Always test SSH in a new session
- Keep console/IPMI access available
- Create admin user before disabling root
- Test PAM changes before disconnecting

### 3. AppArmor, Not SELinux
Ubuntu uses **AppArmor** by default, not SELinux. Don't install SELinux policies.

### 4. ClamAV Database Ownership
The most common ClamAV issue is database ownership:
```bash
chown -R clamav:clamav /var/lib/clamav/
```

### 5. Template Variables
Many scripts use `{{PLACEHOLDER}}` syntax. Ensure all are replaced:
- `{{SLACK_WEBHOOK_URL}}`
- `{{EMAIL_DOMAIN}}`
- `{{INFO_EMAIL}}`
- `{{SECURE_SUBNET}}`

### 6. Reboot Requirements
Some changes require reboot:
- `/dev/shm` mount options
- Kernel parameter changes
- PAM configuration changes

---

## Testing Strategy

### Pre-Deployment
1. Test in Vagrant/VM first
2. Use Ansible `--check` mode for dry runs
3. Validate templates with `ansible-lint`

### Post-Deployment Verification
```bash
# Test SSH access (new session!)
ssh -i key user@server

# Test 2FA
ssh user@server  # Should prompt for code

# Test firewall
ufw status verbose

# Test services
systemctl status clamav-daemon fail2ban postfix

# Test timers
systemctl list-timers

# Test VPN
wg show
```

---

## File Reference

### Configs Directory Structure
```
configs/
├── account_security/
│   ├── faillock.conf
│   ├── pwquality.conf
│   ├── security-policies
│   └── tmpfiles-faillock.conf
├── clamav/
│   └── clamav
├── fail2ban/
│   ├── filter.d/
│   │   ├── portscan.conf
│   │   └── wireguard.conf
│   └── jail.conf
├── network_security/
│   ├── 30-enhanced-network-security.conf
│   ├── 40-wireguard.conf
│   └── resolved-security.conf
├── rkhunter/
│   ├── rkhunter
│   └── rkhunter.conf
├── systemd/
│   ├── clamav-scan.service
│   ├── clamav-scan.timer
│   └── ... (other timer units)
└── templates/
    └── email-config.template
```

### Scripts Directory Structure
```
utils/
├── generators/
│   ├── add_client.sh          # WireGuard client generator
│   ├── network-interface-security.sh
│   └── session-timeout.sh
├── helpers/
│   ├── clamav-exclude-helper.sh
│   ├── script_helper_functions.sh
│   └── sed_helpers.sh
├── monitoring/
│   ├── scripts/               # Timer-executed scripts
│   │   ├── clamav-scan.sh
│   │   ├── check_disk_space.sh
│   │   ├── system_health_check.sh
│   │   └── ...
│   ├── show_fail2ban_status.sh
│   └── test_services.sh
├── network/
│   ├── add-wg-client
│   ├── remove-wg-client
│   └── ufw.sh
├── ssh/
│   ├── setup_user_2fa.sh
│   ├── show_2fa_qr.sh
│   └── disable_user_2fa.sh
└── user_management/
    ├── add_user.sh
    └── unlock_account.sh
```

---

## Quick Reference: Ansible Module Mapping

| Bash Operation | Ansible Module |
|----------------|----------------|
| apt-get install | `ansible.builtin.apt` |
| cp file | `ansible.builtin.copy` or `ansible.builtin.template` |
| sed -i | `ansible.builtin.lineinfile` or `ansible.builtin.replace` |
| systemctl | `ansible.builtin.systemd` |
| sysctl | `ansible.posix.sysctl` |
| ufw | `community.general.ufw` |
| useradd | `ansible.builtin.user` |
| chmod/chown | `ansible.builtin.file` |
| cat > file | `ansible.builtin.copy` with `content:` |
| command execution | `ansible.builtin.command` or `ansible.builtin.shell` |

---

## Estimated Ansible Roles

| Role | Complexity | Est. Tasks | Dependencies |
|------|------------|------------|--------------|
| common | Low | 10-15 | None |
| journald | Low | 5 | common |
| network_security | Medium | 20-25 | common |
| account_security | High | 30-40 | common |
| ssh_security | High | 25-35 | account_security |
| ntp | Low | 5-8 | common |
| swap | Medium | 15-20 | common |
| secure_memory | Low | 5 | common |
| clamav | High | 25-35 | common |
| maldet | Medium | 20-25 | common |
| rkhunter | Medium | 15-20 | common |
| fail2ban | Medium | 15-20 | network_security |
| postfix | Low | 10-15 | common |
| monitoring | Medium | 15-20 | common |
| systemd_timers | Medium | 20-30 | clamav, rkhunter, maldet, monitoring |
| ufw | Medium | 20-25 | All others |
| podman | High | 40-50 | common, rkhunter |
| wireguard | Medium | 20-25 | network_security |
| user_management | Medium | 20-25 | ssh_security, wireguard |

---

*Document Version: 1.0*
*Target: Ubuntu 24.04 LTS*
*Source Repository: ubuntu-automation*

