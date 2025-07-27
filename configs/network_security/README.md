# Network Security Configuration for Ubuntu 24.04

## Overview

This directory contains network security configuration files optimized for Ubuntu 24.04 systems, following modern sysctl.d naming conventions and best practices.

## Files

### `30-enhanced-network-security.conf`
Enhanced network security sysctl configuration file. Uses the `30-` prefix to load after Ubuntu's system `10-network-security.conf` and complement rather than conflict with system defaults.

**Features configured:**
- IP forwarding disabled (default secure state)
- Source routing disabled (prevents routing attacks) 
- ICMP responses disabled (reduces attack surface)
- TCP SYN cookies enabled (SYN flood protection)
- Reverse path filtering enabled (anti-spoofing)
- Network buffer limits configured for security
- IPv6 security hardening
- ARP security settings
- Kernel and filesystem security enhancements

### `resolved-security.conf`
DNS security configuration for systemd-resolved, including:
- Secure DNS servers (Cloudflare and Quad9)
- DNS over TLS support
- DNSSEC validation
- DNS cache protection

## Ubuntu 24.04 Sysctl Best Practices

Ubuntu 24.04 follows these sysctl configuration conventions:

1. **Numbered prefixes**: Files in `/etc/sysctl.d/` use numbered prefixes (e.g., `10-`, `30-`, `99-`) to control load order
2. **System compatibility**: Uses `30-` prefix to load after system defaults and complement existing settings
3. **Conflict avoidance**: Proper naming prevents conflicts with package-installed configurations
4. **Modular approach**: Separate files for different functionality rather than one large configuration

### Compatibility Notes

- **Reverse Path Filtering**: Ubuntu 24.04 system default uses `rp_filter=2` (loose mode) which provides security while maintaining compatibility with complex networking setups like VPNs and multi-homed servers
- **No Overrides**: This configuration complements rather than overrides Ubuntu's security defaults

## Load Order

- `10-*`: Early system settings (security, core network)
- `30-*`: Application-specific settings
- `99-*`: Override settings (use sparingly)

Settings in higher-numbered files override those in lower-numbered files. 