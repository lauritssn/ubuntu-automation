# Known Issues

This document lists known issues that users may encounter when using the Ubuntu automation scripts, along with explanations and workarounds where applicable.

## PAM `pam_lastlog.so` Errors (Ubuntu 24.04)

### Issue Description
Users may see the following errors in their system logs:
```
login[1663]: PAM unable to dlopen(pam_lastlog.so): /usr/lib/security/pam_lastlog.so: cannot open shared object file: No such file or directory
login[1663]: PAM adding faulty module: pam_lastlog.so
```

### Root Cause
This is a **known Ubuntu 24.04 (Noble) system issue**, not caused by the automation scripts:

- `pam_lastlog.so` was removed by upstream PAM in version 1.5.3
- Ubuntu 24.04's default system configuration still references this removed module
- The error comes from `/etc/pam.d/login`, not from our automation configurations

### Impact
- **No functional impact**: Logins work normally despite the error
- **Cosmetic issue only**: Generates harmless error messages in logs
- **Does not affect automation**: Our scripts use modern PAM modules correctly

### Our Implementation
The automation scripts **correctly use modern PAM modules**:
- Uses `pam_faillock.so` instead of deprecated `pam_tally2`
- Leverages `pam-auth-update --enable faillock` for proper Ubuntu 24.04 configuration
- Does not reference or configure `pam_lastlog.so` anywhere

### References
- [Ubuntu Bug #2063257](https://bugs.launchpad.net/ubuntu/+source/shadow/+bug/2063257)
- [Debian Bug #1070869](https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=1070869)
- [Ubuntu SRU Bug #2087549](https://bugs.launchpad.net/ubuntu/+source/shadow/+bug/2087549)

### Manual Fix (Optional)
If you want to eliminate the error messages, you can manually edit `/etc/pam.d/login` and remove any lines containing `pam_lastlog.so`. However, this is not necessary as the error is harmless.

---

## SSH Configuration Notes

### PrintLastLog Setting
The automation scripts configure SSH with `PrintLastLog yes` in the SSH daemon configuration. This is **not related** to the PAM `pam_lastlog.so` error above. This SSH setting simply tells SSH to display last login information when users connect via SSH.

---

## Reporting Issues

If you encounter issues that you believe are caused by the automation scripts:

1. Check if the issue is listed in this document
2. Review the installation logs in `/srv/apps/logs/`
3. Use the monitoring scripts in `/srv/apps/scripts/` to diagnose system state
4. Report new issues with relevant log excerpts and system information

Remember: The automation scripts are designed for Ubuntu server environments and should not be tested or run in local development environments. 