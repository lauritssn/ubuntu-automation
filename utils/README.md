# System Utilities

This folder contains utility scripts for system security, account management, and monitoring that are deployed during the installation process.

## Scripts

### `show_locked_accounts.sh`
**Purpose**: Display account lockout status and recent failed login attempts

**Features**:
- Shows locked user accounts using faillock (Ubuntu 24.04+)
- Displays failed login attempt counts per user
- Shows recent authentication failures from journal logs
- Provides instructions for unlocking accounts

**Usage**: 
```bash
sudo /srv/apps/scripts/show_locked_accounts.sh
```

### `unlock_account.sh`
**Purpose**: Reset account lockout for a specific user

**Features**:
- Validates user existence before attempting unlock
- Uses faillock to reset lockout counter (Ubuntu 24.04+)
- Provides clear success/failure feedback

**Usage**:
```bash
sudo /srv/apps/scripts/unlock_account.sh <username>
# Example: sudo /srv/apps/scripts/unlock_account.sh john
```

### `show_sudo_usage.sh`
**Purpose**: Display recent sudo usage for security auditing

**Features**:
- Shows recent sudo commands from sudo.log (last 20 entries)
- Falls back to systemd journal if sudo.log not available
- Provides information about sudo I/O log locations

**Usage**:
```bash
sudo /srv/apps/scripts/show_sudo_usage.sh
```

### `show_fail2ban_status.sh`
**Purpose**: Comprehensive fail2ban monitoring and management utility

**Features**:
- Complete service status and jail monitoring
- Display currently banned IPs across all jails (SSH, WireGuard, Recidive, Postfix)
- Recent ban/unban activity analysis
- Security events summary with attack statistics
- Configuration validation and testing
- IP unbanning functionality
- SSH-specific security analysis
- WireGuard VPN attack monitoring

**Usage**:
```bash
# Show comprehensive status (default)
sudo /srv/apps/scripts/show_fail2ban_status.sh

# Show specific information
sudo ./show_fail2ban_status.sh jails              # Active jails status
sudo ./show_fail2ban_status.sh bans               # Currently banned IPs
sudo ./show_fail2ban_status.sh recent             # Recent ban activity
sudo ./show_fail2ban_status.sh events             # Security events summary
sudo ./show_fail2ban_status.sh config             # Configuration summary
sudo ./show_fail2ban_status.sh test               # Test configuration
sudo ./show_fail2ban_status.sh ssh                # SSH security overview
sudo ./show_fail2ban_status.sh wireguard          # WireGuard security

# Management operations
sudo ./show_fail2ban_status.sh unban 192.168.1.100        # Unban IP from all jails
sudo ./show_fail2ban_status.sh unban 192.168.1.100 sshd   # Unban IP from specific jail

# Help
./show_fail2ban_status.sh help
```

**Monitored Jails**:
- **sshd**: SSH protection (aggressive mode, 3 attempts, 2h ban)
- **wireguard**: WireGuard VPN protection (5 attempts, 1h ban) 
- **recidive**: Repeat offenders (3 attempts, 1 week ban)
- **postfix-sasl-aggressive**: Email authentication (2 attempts, 4h ban)

### `add_user.sh`
**Purpose**: Comprehensive user creation with security features

**Features**:
- Creates users with sudo privileges
- SSH key setup and validation
- Optional 2FA (Google Authenticator) configuration
- Optional WireGuard VPN client setup
- Automated password generation
- Interactive and command-line modes

**Usage**:
```bash
# Interactive mode (recommended)
sudo /srv/apps/scripts/add_user.sh --interactive

# Command line examples
sudo /srv/apps/scripts/add_user.sh -u john
sudo /srv/apps/scripts/add_user.sh -u jane -p mypassword
sudo /srv/apps/scripts/add_user.sh -u bob --no-2fa --no-wireguard
```

## Installation

These scripts are automatically deployed to `/srv/apps/scripts/` when the `account_security.sh` subscript runs during the main installation process.

## Security Notes

- All scripts require root/sudo privileges to function properly
- Scripts are designed for Ubuntu 24.04+ which uses faillock instead of pam_tally2
- The scripts respect the security configuration established by the account_security subscript 