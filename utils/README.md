# System Utilities

This folder contains utility scripts for system security, account management, and monitoring that are deployed during the installation process to `/srv/apps/scripts/`.

## System Management Scripts

### `view_install_log.sh`

**Purpose**: View installation logs with filtering and search capabilities

**Features**:

- List all installation logs with timestamps
- View complete logs or filtered sections
- Search for specific patterns in logs
- Summary view for quick status checking

**Usage**:

```bash
/srv/apps/scripts/view_install_log.sh --list     # List all logs
/srv/apps/scripts/view_install_log.sh --summary  # Show summary
/srv/apps/scripts/view_install_log.sh --help     # Show all options
```

### `view_install_status.sh`

**Purpose**: Check installation module status and manage failed installations

**Features**:

- Display status of all installation modules
- Reset specific modules to force reinstallation
- Reset all modules for complete reinstall
- Track successful, failed, and skipped modules

**Usage**:

```bash
/srv/apps/scripts/view_install_status.sh                    # Show status
/srv/apps/scripts/view_install_status.sh reset-module SSH   # Reset specific module
/srv/apps/scripts/view_install_status.sh reset              # Reset all modules
```

### `system_health_check.sh`

**Purpose**: Comprehensive system health monitoring with Slack integration

**Features**:

- CPU load and memory usage monitoring
- Disk space checking with thresholds
- Service status validation
- Slack notifications for alerts
- Systemd timer integration

**Usage**:

```bash
/srv/apps/scripts/system_health_check.sh  # Manual health check
```

## User & Account Management

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
/srv/apps/scripts/add_user.sh --interactive

# Command line examples
/srv/apps/scripts/add_user.sh -u john
/srv/apps/scripts/add_user.sh -u jane -p mypassword
/srv/apps/scripts/add_user.sh -u bob --no-2fa --no-wireguard
```

### `unlock_account.sh`

**Purpose**: Reset account lockout for a specific user

**Features**:

- Validates user existence before attempting unlock
- Uses faillock to reset lockout counter (Ubuntu 24.04+)
- Provides clear success/failure feedback

**Usage**:

```bash
/srv/apps/scripts/unlock_account.sh <username>
# Example: /srv/apps/scripts/unlock_account.sh john
```

### `show_locked_accounts.sh`

**Purpose**: Display account lockout status and recent failed login attempts

**Features**:

- Shows locked user accounts using faillock (Ubuntu 24.04+)
- Displays failed login attempt counts per user
- Shows recent authentication failures from journal logs
- Provides instructions for unlocking accounts

**Usage**:

```bash
/srv/apps/scripts/show_locked_accounts.sh
```

### `show_sudo_usage.sh`

**Purpose**: Display recent sudo usage for security auditing

**Features**:

- Shows recent sudo commands from sudo.log (last 20 entries)
- Falls back to systemd journal if sudo.log not available
- Provides information about sudo I/O log locations

**Usage**:

```bash
/srv/apps/scripts/show_sudo_usage.sh
```

## SSH & 2FA Management

### `setup_user_2fa.sh`

**Purpose**: Configure 2FA authentication for existing users

**Features**:

- Sets up Google Authenticator for users
- Generates QR codes for mobile apps
- Creates emergency backup codes
- Integrates with SSH configuration

**Usage**:

```bash
/srv/apps/scripts/setup_user_2fa.sh <username>
```

### `show_2fa_qr.sh`

**Purpose**: Display 2FA QR codes for user authentication setup

**Features**:

- Shows QR code for current or specified user
- Compatible with Google Authenticator, Authy, etc.
- Displays in terminal for easy mobile scanning

**Usage**:

```bash
/srv/apps/scripts/show_2fa_qr.sh [username]  # Show QR for user or current user
```

### `disable_user_2fa.sh`

**Purpose**: Remove 2FA authentication from user accounts

**Features**:

- Safely removes Google Authenticator configuration
- Maintains SSH access without 2FA requirement
- Provides confirmation of changes

**Usage**:

```bash
/srv/apps/scripts/disable_user_2fa.sh <username>
```

## Security Monitoring

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
/srv/apps/scripts/show_fail2ban_status.sh

# Show specific information
/srv/apps/scripts/show_fail2ban_status.sh jails      # Active jails status
/srv/apps/scripts/show_fail2ban_status.sh bans       # Currently banned IPs
/srv/apps/scripts/show_fail2ban_status.sh recent     # Recent ban activity
/srv/apps/scripts/show_fail2ban_status.sh events     # Security events summary

# Management operations
/srv/apps/scripts/show_fail2ban_status.sh unban 192.168.1.100  # Unban IP
```

### `show_ssh_attacks.sh`

**Purpose**: Display recent SSH attack attempts and patterns

**Usage**:

```bash
/srv/apps/scripts/show_ssh_attacks.sh
```

### `show_ssh_security.sh`

**Purpose**: SSH security configuration overview and status

**Usage**:

```bash
/srv/apps/scripts/show_ssh_security.sh
```

### `show_network_security.sh`

**Purpose**: Network security status and firewall configuration display

**Usage**:

```bash
/srv/apps/scripts/show_network_security.sh
```

## Antivirus & Malware Protection

### `clamav-scan.sh`

**Purpose**: ClamAV antivirus scanning with Slack integration

**Features**:

- Full system scanning with exclusions
- Slack notifications for start/completion/threats
- Detailed threat reporting
- Systemd timer integration

**Usage**:

```bash
/srv/apps/scripts/clamav-scan.sh  # Manual scan
```

### `clamav-update.sh`

**Purpose**: Update ClamAV virus signatures

**Features**:

- Automatic signature database updates
- Slack notifications for update status
- Error handling and reporting

**Usage**:

```bash
/srv/apps/scripts/clamav-update.sh  # Manual update
```

### `maldet-scan.sh`

**Purpose**: Linux Malware Detect scanning

**Features**:

- Specialized Linux malware detection
- Integration with ClamAV engine (optional)
- Slack notifications and reporting

**Usage**:

```bash
/srv/apps/scripts/maldet-scan.sh  # Manual malware scan
```

### `maldet-update.sh`

**Purpose**: Update Maldet signatures and configuration

**Usage**:

```bash
/srv/apps/scripts/maldet-update.sh  # Update malware signatures
```

## Intrusion Detection

### `rkhunter-scan.sh`

**Purpose**: Rootkit and intrusion detection scanning

**Features**:

- Comprehensive rootkit scanning
- System integrity checking
- Slack notifications for threats
- Automated daily scanning

**Usage**:

```bash
/srv/apps/scripts/rkhunter-scan.sh  # Manual rootkit scan
```

### `rkhunter-update.sh`

**Purpose**: Update RKHunter database and signatures

**Usage**:

```bash
/srv/apps/scripts/rkhunter-update.sh  # Update detection database
```

## Resource Monitoring

### `check_disk_space.sh`

**Purpose**: Monitor disk usage with threshold alerts

**Features**:

- Configurable warning/critical thresholds
- Slack notifications for alerts
- Multiple filesystem monitoring
- 5-minute interval checking

**Usage**:

```bash
/srv/apps/scripts/check_disk_space.sh  # Manual disk check
```

### `check_swap_usage.sh`

**Purpose**: Track memory pressure and swap utilization

**Features**:

- Memory usage monitoring
- Swap usage threshold alerts
- Slack notifications for high usage
- Hourly monitoring integration

**Usage**:

```bash
/srv/apps/scripts/check_swap_usage.sh  # Manual swap check
```

## Network & VPN Tools

### `add-wg-client`

**Purpose**: Add new WireGuard VPN clients

**Features**:

- Automatic key generation
- Client configuration creation
- QR code generation for mobile
- IP address assignment

**Usage**:

```bash
add-wg-client <username>  # Add new VPN client
```

### `remove-wg-client`

**Purpose**: Remove WireGuard VPN clients

**Features**:

- Safe client removal
- Configuration cleanup
- Server configuration updates

**Usage**:

```bash
remove-wg-client <username>  # Remove VPN client
```

### `enable_ip_forwarding.sh`

**Purpose**: Configure IP forwarding for VPN functionality

### `ufw.sh`

**Purpose**: Firewall rule management script

## Container Management (Podman)

### `podman-user`

**Purpose**: Execute Podman commands as the podman user with proper environment setup

**Features**:

- Automatic user detection (runs directly if executed as podman user, uses sudo otherwise)
- Socket management and automatic startup
- Proper environment variable configuration
- Full Docker command compatibility

**Installation**: Copied to `/usr/local/bin/podman-user` during Podman installation

**Usage**:

```bash
podman-user ps -a                    # List containers
podman-user run hello-world          # Run test container
podman-user images                   # List images
podman-user system prune             # Clean up resources
```

### `podman-status`

**Purpose**: Comprehensive Podman installation and service status diagnostics

**Features**:

- User and environment validation
- Socket service status checking
- Socket file verification
- Version information display
- Container and network status

**Installation**: Copied to `/usr/local/bin/podman-status` during Podman installation

**Usage**:

```bash
podman-status  # Show complete Podman system status
```

### `podman-socket`

**Purpose**: Manage socket-activated containers and systemd services

**Features**:

- List socket units and container services
- Start/stop/restart socket services
- Enable/disable services for boot
- View service logs
- Full systemd integration

**Installation**: Copied to `/usr/local/bin/podman-socket` during Podman installation

**Usage**:

```bash
podman-socket list                   # List socket services
podman-socket status [service]       # Check service status
podman-socket start traefik-http     # Start socket service
podman-socket logs traefik           # View service logs
```

### `socket-setup.sh`

**Purpose**: Create systemd socket units for socket-activated containers with dual-stack IPv4/IPv6 support

**Features**:

- Automatic IPv4 and IPv6 listener configuration
- Service name validation (alphanumeric, hyphens, underscores)
- Port number validation (1-65535 range)
- User verification (must run as podman user)
- Multiple port support for complex services
- Comprehensive usage instructions and next steps

**Installation**: Available in multiple locations:
- User-specific: `/home/podman/.local/bin/socket-setup.sh`
- System-wide: `/srv/apps/scripts/socket-setup.sh`
- Compatibility symlink: `/home/podman/.config/containers/socket-setup.sh`

**Usage**:

```bash
# Must be run as podman user
sudo su - podman

# Create socket for single port service
socket-setup.sh nginx 80

# Create socket for multi-port service (like Traefik)
socket-setup.sh traefik 80 443 8080

# Get help and examples
socket-setup.sh --help
```

**Output**: Creates `~/.config/systemd/user/<service-name>.socket` with IPv4 and IPv6 listeners

## Testing & Validation

### `test_services.sh`

**Purpose**: Comprehensive validation of all installed services

**Features**:

- Tests all security services
- Validates configurations
- Reports service health
- Identifies potential issues

**Usage**:

```bash
/srv/apps/scripts/test_services.sh  # Test all services
```

### `test_ssh_security.sh`

**Purpose**: Validate SSH security configuration

**Usage**:

```bash
/srv/apps/scripts/test_ssh_security.sh  # Test SSH security
```

### `test_network_security.sh`

**Purpose**: Validate network security settings

**Usage**:

```bash
/srv/apps/scripts/test_network_security.sh  # Test network security
```

## Installation & Location

These scripts are automatically deployed to `/srv/apps/scripts/` during the installation process. The deployment happens through various subscripts:

- **Account Security**: User management and SSH scripts
- **Security Tools**: Antivirus, intrusion detection, and monitoring scripts
- **Network Setup**: VPN and firewall management tools
- **System Setup**: Health monitoring and status scripts

## Security Notes

- All scripts require root/sudo privileges to function properly
- Scripts are designed for Ubuntu 24.04+ with modern security practices
- Slack integration requires webhook configuration during installation
- Scripts follow standardized logging to `/srv/apps/logs/`
- All utilities include comprehensive `--help` documentation
