# Secure Outbound-Only Email Setup Guide

Complete guide for configuring secure, compliant outbound email delivery using Postfix.

## Prerequisites

- Ubuntu/Debian server with Postfix installed
- Domain name with DNS control
- Static IP address
- Root or sudo access

## 1. DNS Configuration

### 1.1 SPF Record

Add an SPF record to prevent email spoofing:

```dns
Type: TXT
Name: werktoej.dk
Value: v=spf1 ip4:YOUR_SERVER_IP -all
```

Replace `YOUR_SERVER_IP` with your server's actual IP address.

### 1.2 DKIM Setup

Install and configure DKIM signing:

```bash
# Install OpenDKIM
sudo apt update
sudo apt install opendkim opendkim-tools

# Create directory structure
sudo mkdir -p /etc/opendkim/keys/werktoej.dk

# Generate DKIM keys
sudo opendkim-genkey -t -s mail -d werktoej.dk -D /etc/opendkim/keys/werktoej.dk/

# Set proper permissions
sudo chown -R opendkim:opendkim /etc/opendkim/keys/
sudo chmod 600 /etc/opendkim/keys/werktoej.dk/mail.private
```

Configure OpenDKIM (`/etc/opendkim.conf`):

```conf
Domain werktoej.dk
KeyFile /etc/opendkim/keys/werktoej.dk/mail.private
Selector mail
Socket local:/var/spool/postfix/opendkim/opendkim.sock
PidFile /run/opendkim/opendkim.pid
TrustAnchorFile /usr/share/dns/root.key
UserID opendkim
```

Create signing table (`/etc/opendkim/signing.table`):

```
*@werktoej.dk mail._domainkey.werktoej.dk
```

Create key table (`/etc/opendkim/key.table`):

```
mail._domainkey.werktoej.dk werktoej.dk:mail:/etc/opendkim/keys/werktoej.dk/mail.private
```

Create trusted hosts (`/etc/opendkim/trusted.hosts`):

```
127.0.0.1
localhost
werktoej.dk
```

Get the DKIM public key:

```bash
sudo cat /etc/opendkim/keys/werktoej.dk/mail.txt
```

Add the DKIM DNS record:

```dns
Type: TXT
Name: mail._domainkey.werktoej.dk
Value: (copy the value from mail.txt, remove quotes and line breaks)
```

### 1.3 DMARC Policy

Add a DMARC record for email authentication:

```dns
Type: TXT
Name: _dmarc.werktoej.dk
Value: v=DMARC1; p=reject; rua=mailto:dmarc@werktoej.dk; fo=1; adkim=s; aspf=s
```

### 1.4 MX Record (Optional)

If you want to explicitly reject incoming mail:

```dns
Type: MX
Name: werktoej.dk
Priority: 10
Value: reject.werktoej.dk
```

## 2. Postfix Security Configuration

### 2.1 Main Configuration

Edit `/etc/postfix/main.cf`:

```conf
# Basic Settings
myhostname = dokku
mydomain = werktoej.dk
myorigin = $mydomain

# Outbound only - disable incoming mail
inet_interfaces = loopback-only
mydestination = localhost

# Network restrictions
mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128

# TLS Security
smtp_tls_security_level = may
smtp_tls_session_cache_database = btree:${data_directory}/smtp_scache
smtp_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
smtp_tls_ciphers = high
smtp_tls_exclude_ciphers = aNULL, eNULL, EXPORT, DES, RC4, MD5, PSK, SRP, DSS, AECDH, ADH
smtp_tls_CApath = /etc/ssl/certs

# Rate limiting and resource controls
default_destination_concurrency_limit = 5
smtp_destination_rate_delay = 1s
default_process_limit = 50
maximal_queue_lifetime = 1d
bounce_queue_lifetime = 1d

# Message size and security limits
message_size_limit = 25600000
mailbox_size_limit = 0

# Security restrictions
smtpd_reject_unlisted_recipient = yes
disable_vrfy_command = yes
smtpd_helo_required = yes

# DKIM Integration
milter_default_action = accept
milter_protocol = 6
smtpd_milters = local:opendkim/opendkim.sock
non_smtpd_milters = local:opendkim/opendkim.sock

# Logging
mail_log_prefix = %s/%s%{mail_name}
```

### 2.2 Master Configuration

Edit `/etc/postfix/master.cf` to ensure secure service configuration:

```conf
# SMTP service (outbound only)
smtp      unix  -       -       y       -       -       smtp
  -o smtp_fallback_relay=

# Submission service (if needed for authenticated sending)
submission inet n       -       y       -       -       smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
  -o smtpd_relay_restrictions=permit_sasl_authenticated,reject
```

## 3. Firewall Configuration

### 3.1 UFW Rules

Configure firewall for outbound-only email:

```bash
# Allow outbound SMTP connections
sudo ufw allow out 25/tcp comment "SMTP outbound"
sudo ufw allow out 587/tcp comment "SMTP submission outbound"
sudo ufw allow out 465/tcp comment "SMTPS outbound"

# Block inbound SMTP (if not already blocked)
sudo ufw deny in 25/tcp comment "Block inbound SMTP"
sudo ufw deny in 587/tcp comment "Block inbound submission"
sudo ufw deny in 465/tcp comment "Block inbound SMTPS"

# Check rules
sudo ufw status numbered
```

### 3.2 IPTables Rules (Alternative)

If using iptables directly:

```bash
# Allow outbound SMTP
iptables -A OUTPUT -p tcp --dport 25 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 587 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 465 -j ACCEPT

# Block inbound SMTP
iptables -A INPUT -p tcp --dport 25 -j DROP
iptables -A INPUT -p tcp --dport 587 -j DROP
iptables -A INPUT -p tcp --dport 465 -j DROP
```

## 4. Service Configuration

### 4.1 Start and Enable Services

```bash
# Enable and start OpenDKIM
sudo systemctl enable opendkim
sudo systemctl start opendkim

# Restart Postfix
sudo systemctl restart postfix

# Check service status
sudo systemctl status opendkim postfix
```

### 4.2 Create DKIM Socket Directory

```bash
# Create socket directory for Postfix
sudo mkdir -p /var/spool/postfix/opendkim
sudo chown opendkim:postfix /var/spool/postfix/opendkim
sudo chmod 750 /var/spool/postfix/opendkim
```

## 5. Monitoring and Logging

### 5.1 Log Rotation

Create `/etc/logrotate.d/postfix`:

```conf
/var/log/mail.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
    postrotate
        systemctl reload postfix
    endscript
}
```

### 5.2 Monitoring Script

Create `/usr/local/bin/check-mail-delivery.sh`:

```bash
#!/bin/bash
# Check for mail delivery issues

LOG_FILE="/var/log/mail.log"
ALERT_EMAIL="tools@werktoej.dk"
TEMP_FILE="/tmp/mail_issues.tmp"

# Check for bounced or deferred messages in the last hour
grep "$(date '+%b %d %H:')" "$LOG_FILE" | \
    grep -E "status=(bounced|deferred)" > "$TEMP_FILE"

if [ -s "$TEMP_FILE" ]; then
    {
        echo "Mail delivery issues detected on $(hostname) at $(date)"
        echo "----------------------------------------"
        cat "$TEMP_FILE"
    } | mail -s "Mail Delivery Alert - $(hostname)" "$ALERT_EMAIL"
fi

rm -f "$TEMP_FILE"
```

Make it executable and add to crontab:

```bash
sudo chmod +x /usr/local/bin/check-mail-delivery.sh

# Add to crontab (run every hour)
echo "0 * * * * /usr/local/bin/check-mail-delivery.sh" | sudo crontab -
```

## 6. Testing and Validation

### 6.1 Test Email Delivery

```bash
# Send test email
echo "Subject: Test Email from $(hostname)
This is a test email sent at $(date)" | sendmail tools@werktoej.dk

# Check queue
sudo postqueue -p

# Monitor logs
sudo tail -f /var/log/mail.log
```

### 6.2 DNS Validation

Test your DNS records:

```bash
# Check SPF
dig TXT werktoej.dk | grep spf

# Check DKIM
dig TXT mail._domainkey.werktoej.dk

# Check DMARC
dig TXT _dmarc.werktoej.dk
```

### 6.3 Online Testing Tools
