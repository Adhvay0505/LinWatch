# 🛡️ LinWatch Security Audit Report

**Generated:** Tue Feb 10 15:08:10 +04 2026  
**Hostname:** 61a2e4f8f037  
**Kernel:** 6.18.8-200.fc43.x86_64  
**Distribution:** ubuntu  

---

## 📊 System Overview

| Property | Value |
|----------|-------|
| ⏰ **Uptime** | up 2 hours, 6 minutes |
| 🔄 **Last Reboot** | Feb 10 |
| 👤 **Current User** | root |
| 💻 **CPU Cores** | 12 |
| 🧠 **Memory** | 14Gi/4.0Gi used |

## 👥 User Account Security

### Users with Login Shells

| Username | UID | Home Directory | Shell |
|----------|-----|----------------|-------|
| root | 0 | root | /root:/bin/bash |
| ubuntu | 1000 | Ubuntu | /home/ubuntu:/bin/bash |

### Users with Root Privileges (UID 0)

| Username | Home Directory | Risk Level |
|----------|----------------|------------|
| root | /root | ✅ Expected |

### Accounts Without Passwords

✅ All accounts have passwords configured

## 🔥 Network Security Analysis

### Listening Services (Risk Assessment)

| Port | Protocol | Service | User | Risk Level |
|------|----------|---------|------|------------|

### Network Connections Summary

- **Established Connections:** 1
- **Listening Services:** 0

### Top Connection Sources

| 443 | 1 connections | 🟢 Normal |

## 🔥 Firewall Security Status

### ❌ No Firewall Detected

**Recommendation:** Install and configure a firewall (ufw, firewalld, or iptables)

## 🔐 SSH Security Configuration

### ❌ SSH Configuration Not Found

**Possible Reasons:**
- SSH server not installed
- SSH daemon using different configuration path
- Insufficient permissions to read config

## 📁 File Permissions Security

### SUID Executables (Elevated Privilege Files)

| File Path | Expected | Risk Level | Action |
|-----------|----------|------------|--------|
| /usr/bin/chfn | ❌ Unexpected | 🔴 High | Remove if unnecessary |
| /usr/bin/chsh | ❌ Unexpected | 🔴 High | Remove if unnecessary |
| /usr/bin/gpasswd | ❌ Unexpected | 🔴 High | Remove if unnecessary |
| /usr/bin/mount | ✅ Expected | 🟢 Low | Keep |
| /usr/bin/newgrp | ❌ Unexpected | 🔴 High | Remove if unnecessary |
| /usr/bin/passwd | ✅ Expected | 🟢 Low | Keep |
| /usr/bin/su | ✅ Expected | 🟢 Low | Keep |
| /usr/bin/umount | ✅ Expected | 🟢 Low | Keep |
| /usr/bin/sudo | ✅ Expected | 🟢 Low | Keep |
| /usr/lib/openssh/ssh-keysign | ❌ Unexpected | 🔴 High | Remove if unnecessary |
| /usr/lib/dbus-1.0/dbus-daemon-launch-helper | ❌ Unexpected | 🔴 High | Remove if unnecessary |
| /usr/lib/polkit-1/polkit-agent-helper-1 | ❌ Unexpected | 🔴 High | Remove if unnecessary |

### World-Writable Files (Security Risk)

⚠️ **CRITICAL SECURITY RISK:** Found world-writable files:

| File Path | Directory | Severity | Recommended Action |
|-----------|-----------|-----------|-------------------|
| /root/.local/share/opencode/bin/node_modules/pyright/index.js | /root/.local/share/opencode/bin/node_modules/pyright | 🔴 Critical | Restrict permissions immediately |
| /root/.local/share/opencode/bin/node_modules/pyright/langserver.index.js | /root/.local/share/opencode/bin/node_modules/pyright | 🔴 Critical | Restrict permissions immediately |
| /root/.local/share/opencode/bin/node_modules/bash-language-server/out/cli.js | /root/.local/share/opencode/bin/node_modules/bash-language-server/out | 🔴 Critical | Restrict permissions immediately |
| /root/.local/share/opencode/bin/node_modules/editorconfig/bin/editorconfig | /root/.local/share/opencode/bin/node_modules/editorconfig/bin | 🔴 Critical | Restrict permissions immediately |
| /root/.local/share/opencode/bin/node_modules/vscode-languageserver/bin/installServerIntoExtension | /root/.local/share/opencode/bin/node_modules/vscode-languageserver/bin | 🔴 Critical | Restrict permissions immediately |
| /root/.local/share/opencode/bin/node_modules/semver/bin/semver.js | /root/.local/share/opencode/bin/node_modules/semver/bin | 🔴 Critical | Restrict permissions immediately |
| /root/.cache/opencode/node_modules/pino/bin.js | /root/.cache/opencode/node_modules/pino | 🔴 Critical | Restrict permissions immediately |
| /root/.cache/opencode/node_modules/semver/bin/semver.js | /root/.cache/opencode/node_modules/semver/bin | 🔴 Critical | Restrict permissions immediately |
| /root/.cache/opencode/node_modules/is-inside-container/cli.js | /root/.cache/opencode/node_modules/is-inside-container | 🔴 Critical | Restrict permissions immediately |
| /root/.cache/opencode/node_modules/is-docker/cli.js | /root/.cache/opencode/node_modules/is-docker | 🔴 Critical | Restrict permissions immediately |
| /root/.bun/install/cache/is-inside-container@1.0.0@@@1/cli.js | /root/.bun/install/cache/is-inside-container@1.0.0@@@1 | 🔴 Critical | Restrict permissions immediately |
| /root/.bun/install/cache/is-docker@3.0.0@@@1/cli.js | /root/.bun/install/cache/is-docker@3.0.0@@@1 | 🔴 Critical | Restrict permissions immediately |
| /root/.bun/install/cache/semver@7.7.3@@@1/bin/semver.js | /root/.bun/install/cache/semver@7.7.3@@@1/bin | 🔴 Critical | Restrict permissions immediately |
| /root/.bun/install/cache/pino@10.2.1@@@1/bin.js | /root/.bun/install/cache/pino@10.2.1@@@1 | 🔴 Critical | Restrict permissions immediately |
| /root/.bun/install/cache/pyright@1.1.408@@@1/index.js | /root/.bun/install/cache/pyright@1.1.408@@@1 | 🔴 Critical | Restrict permissions immediately |

### Additional Permission Analysis

#### Critical System Files Permissions

| File | Expected Permissions | Current Permissions | Status |
|------|---------------------|---------------------|--------|
| /etc/passwd | Depends | -rw-r--r-- | ✅ OK |
| /etc/shadow | Depends | -rw-r----- | 🔴 Insecure |
| /etc/group | Depends | -rw-r--r-- | ⚠️ Unknown |
| /etc/gshadow | Depends | -rw-r----- | 🔴 Insecure |
| /etc/sudoers | Depends | -r--r----- | ✅ OK |

## 🔐 Authentication Security Analysis

### Failed Login Attempts Analysis

⚠️ **No authentication log found**

**Common log locations:**
- /var/log/auth.log (Debian/Ubuntu)
- /var/log/secure (RHEL/CentOS/Fedora)

### Recent Successful Logins


## 🛠️ Security Tools Status

### Installed Security Tools

| Tool | Status | Purpose | Recommendation |
|------|--------|---------|----------------|
| rkhunter | ✅ Installed | Rootkit detection | ✅ Keep updated |
| chkrootkit | ✅ Installed | Additional rootkit scanning | ✅ Keep updated |
| ClamAV | ✅ Installed | Malware/virus scanning | ✅ Keep definitions updated |
| fail2ban | ❌ Missing | SSH brute force protection | 🔧 Install for SSH protection |
| Firewall | ❌ Missing | Network traffic filtering | 🔧 Install UFW or Firewalld |

### Security Coverage Assessment

- **Security Tools Coverage:** 3/3 (99%)

✅ **Excellent:** All major security tools are installed

## 🔍 Rootkit Hunter (rkhunter) Analysis

### Scan Results

**Updating rkhunter definitions...**
⚠️ Failed to update definitions

⚠️ **Warnings detected during scan**

| Check | Result | Severity | Action |
|-------|--------|----------|--------|
| warning | Warning | 🟡 Medium | Review |
| warning | Warning | 🟡 Medium | Review |
| warning | Warning | 🟡 Medium | Review |
| warning | Warning | 🟡 Medium | Review |
| warning | Warning | 🟡 Medium | Review |
| warning | Warning | 🟡 Medium | Review |
| warning | Warning | 🟡 Medium | Review |
| warning | Warning | 🟡 Medium | Review |

#### Technical Details

<details>
<summary>Click to expand full rkhunter output</summary>

```
Warning: The command '/usr/bin/lwp-request' has been replaced by a script: /usr/bin/lwp-request: Perl script text executable
Warning: The kernel modules directory '/lib/modules' is missing or empty.
Warning: User 'clamav' has been added to the passwd file.
Warning: User 'postfix' has been added to the passwd file.
Warning: Group 'clamav' has been added to the group file.
Warning: Group 'postfix' has been added to the group file.
Warning: Group 'postdrop' has been added to the group file.
Warning: No running system logging daemon has been found.
```
</details>

## 🔍 Chkrootkit Analysis

### Scan Results Summary

| Status | Count | Risk Level |
|--------|-------|------------|
| ✅ Clean | 88 checks | 🟢 Low |
| ⚠️ Suspicious | 12 checks | 🟡 Medium |
| ❌ Infected | 0 checks | 🔴 Critical |

### Detailed Findings

| Check | Result | File | Action |
|-------|--------|------|--------|
| Searching | ⚠️ SUSPICIOUS | for | 🔍 Investigate further |
| Searching | ⚠️ SUSPICIOUS | for | 🔍 Investigate further |
| Searching | ⚠️ SUSPICIOUS | for | 🔍 Investigate further |
| Searching | ⚠️ SUSPICIOUS | for | 🔍 Investigate further |
| WARNING: | ⚠️ SUSPICIOUS | The | 🔍 Investigate further |
| Searching | ⚠️ SUSPICIOUS | for | 🔍 Investigate further |
| WARNING: | ⚠️ SUSPICIOUS | chkdirs: | 🔍 Investigate further |
| WARNING: | ⚠️ SUSPICIOUS | It | 🔍 Investigate further |
| Checking | ⚠️ SUSPICIOUS | `sniffer'... | 🔍 Investigate further |
| WARNING: | ⚠️ SUSPICIOUS | Output | 🔍 Investigate further |
| Checking | ⚠️ SUSPICIOUS | `chkutmp'... | 🔍 Investigate further |
| WARNING: | ⚠️ SUSPICIOUS | chkutmp | 🔍 Investigate further |

#### Technical Scan Output

<details>
<summary>Click to expand full chkrootkit output</summary>

```
ROOTDIR is `/'
Checking `amd'...                                           not found
Checking `basename'...                                      not infected
Checking `biff'...                                          not found
Checking `chfn'...                                          not infected
Checking `chsh'...                                          not infected
Checking `cron'...                                          not found
Checking `crontab'...                                       not found
Checking `date'...                                          not infected
Checking `du'...                                            not infected
Checking `dirname'...                                       not infected
Checking `echo'...                                          not infected
Checking `egrep'...                                         not infected
Checking `env'...                                           not infected
Checking `find'...                                          not infected
Checking `fingerd'...                                       not found
Checking `gpm'...                                           not found
Checking `grep'...                                          not infected
Checking `hdparm'...                                        not found
Checking `su'...                                            not infected
Checking `ifconfig'...                                      not infected
Checking `inetd'...                                         not infected
Checking `inetdconf'...                                     not found
Checking `identd'...                                        not found
Checking `init'...                                          not infected
Checking `killall'...                                       not infected
Checking `ldsopreload'...                                   not infected
Checking `login'...                                         not infected
Checking `ls'...                                            not infected
Checking `lsof'...                                          not infected
Checking `mail'...                                          not infected
Checking `mingetty'...                                      not found
Checking `netstat'...                                       not infected
Checking `named'...                                         not found
Checking `passwd'...                                        not infected
Checking `pidof'...                                         not infected
Checking `pop2'...                                          not found
Checking `pop3'...                                          not found
Checking `ps'...                                            not infected
Checking `pstree'...                                        not infected
Checking `rpcinfo'...                                       not found
Checking `rlogind'...                                       not found
Checking `rshd'...                                          not found
Checking `slogin'...                                        not infected
Checking `sendmail'...                                      not infected
Checking `sshd'...                                          not infected
Checking `syslogd'...                                       not found
Checking `tar'...                                           not infected
Checking `tcpd'...                                          not found
Checking `tcpdump'...                                       RTNETLINK answers: Invalid argument
not infected
Checking `top'...                                           not infected
Checking `telnetd'...                                       not found
Checking `timed'...                                         not found
Checking `traceroute'...                                    not found
Checking `vdir'...                                          not infected
Checking `w'...                                             not infected
Checking `write'...                                         not found
Checking `aliens'...                                        started
Searching for suspicious files in /dev...                   not found
Searching for known suspicious directories...               not found
Searching for known suspicious files...                     not found
Searching for sniffer's logs...                             not found
Searching for HiDrootkit rootkit...                         not found
Searching for t0rn rootkit...                               not found
Searching for t0rn v8 (or variation)...                     not found
Searching for Lion rootkit...                               not found
Searching for RSHA rootkit...                               not found
Searching for RH-Sharpe rootkit...                          not found
Searching for Ambient (ark) rootkit...                      not found
Searching for suspicious files and dirs...                  WARNING

WARNING: The following suspicious files and directories were found:
/usr/lib/ruby/vendor_ruby/rubygems/optparse/.document
/usr/lib/ruby/vendor_ruby/rubygems/ssl_certs/.document
/usr/lib/ruby/vendor_ruby/rubygems/tsort/.document

Searching for LPD Worm...                                   not found
Searching for Ramen Worm rootkit...                         not found
Searching for Maniac rootkit...                             not found
Searching for RK17 rootkit...                               not found
Searching for Ducoci rootkit...                             not found
Searching for Adore Worm...                                 not found
Searching for ShitC Worm...                                 not found
Searching for Omega Worm...                                 not found
Searching for Sadmind/IIS Worm...                           not found
Searching for MonKit...                                     not found
Searching for Showtee rootkit...                            not found
Searching for OpticKit...                                   not found
Searching for T.R.K...                                      not found
Searching for Mithra rootkit...                             not found
Searching for OBSD rootkit v1...                            not tested
Searching for LOC rootkit...                                not found
Searching for Romanian rootkit...                           not found
Searching for HKRK rootkit...                               not found
Searching for Suckit rootkit...                             not found
Searching for Volc rootkit...                               not found
Searching for Gold2 rootkit...                              not found
Searching for TC2 rootkit...                                not found
Searching for Anonoying rootkit...                          not found
Searching for ZK rootkit...                                 not found
Searching for ShKit rootkit...                              not found
Searching for AjaKit rootkit...                             not found
Searching for zaRwT rootkit...                              not found
Searching for Madalin rootkit...                            not found
Searching for Fu rootkit...                                 not found
Searching for Kenga3 rootkit...                             not found
Searching for ESRK rootkit...                               not found
Searching for rootedoor...                                  not found
Searching for ENYELKM rootkit...                            not found
Searching for common ssh-scanners...                        not found
Searching for Linux/Ebury 1.4 - Operation Windigo...        not tested
Searching for Linux/Ebury 1.6...                            not found
Searching for 64-bit Linux Rootkit...                       not found
Searching for 64-bit Linux Rootkit modules...               not found
Searching for Mumblehard...                                 not found
Searching for Backdoor.Linux.Mokes.a...                     not found
Searching for Malicious TinyDNS...                          not found
Searching for Linux.Xor.DDoS...                             not found
Searching for Linux.Proxy.1.0...                            not found
Searching for CrossRAT...                                   not found
Searching for Hidden Cobra...                               not found
Searching for Rocke Miner rootkit...                        not found
Searching for PWNLNX4 lkm rootkit...                        not found
Searching for PWNLNX6 lkm rootkit...                        not found
Searching for Umbreon lrk...                                not found
Searching for Kinsing.a backdoor rootkit...                 not found
Searching for RotaJakiro backdoor rootkit...                not found
Searching for Syslogk LKM rootkit...                        not found
Searching for Kovid LKM rootkit...                          not tested
Searching for Tsunami DDoS Malware rootkit...               not found
Searching for Linux BPF Door...                             not found
Searching for suspect PHP files...                          /usr/bin/find: ‘/var/tmp’: No such file or directory
not found
Searching for zero-size shell history files...              not found
Searching for hardlinked shell history files...             not found
Checking `aliens'...                                        finished
Checking `asp'...                                           not infected
Checking `bindshell'...                                     RTNETLINK answers: Invalid argument
RTNETLINK answers: Invalid argument
RTNETLINK answers: Invalid argument
RTNETLINK answers: Invalid argument
RTNETLINK answers: Invalid argument
RTNETLINK answers: Invalid argument
RTNETLINK answers: Invalid argument
RTNETLINK answers: Invalid argument
RTNETLINK answers: Invalid argument
RTNETLINK answers: Invalid argument
RTNETLINK answers: Invalid argument
RTNETLINK answers: Invalid argument
RTNETLINK answers: Invalid argument
RTNETLINK answers: Invalid argument
RTNETLINK answers: Invalid argument
RTNETLINK answers: Invalid argument
RTNETLINK answers: Invalid argument
RTNETLINK answers: Invalid argument
RTNETLINK answers: Invalid argument
RTNETLINK answers: Invalid argument
RTNETLINK answers: Invalid argument
RTNETLINK answers: Invalid argument
RTNETLINK answers: Invalid argument
RTNETLINK answers: Invalid argument
RTNETLINK answers: Invalid argument
RTNETLINK answers: Invalid argument
RTNETLINK answers: Invalid argument
RTNETLINK answers: Invalid argument
RTNETLINK answers: Invalid argument
RTNETLINK answers: Invalid argument
RTNETLINK answers: Invalid argument
RTNETLINK answers: Invalid argument
not found
Checking `lkm'...                                           started
Searching for Adore LKM...                                  not tested
Searching for sebek LKM (Adore based)...                    not tested
Searching for knark LKM rootkit...                          not found
Searching for for hidden processes with chkproc...          not found
Searching for for hidden directories using chkdirs...       WARNING

WARNING: chkdirs: Possible LKM Trojan installed:
WARNING: It seems you are using BTRFS, if this is true chkdirs can't help you to find hidden files/dirs

Checking `lkm'...                                           finished
Checking `rexedcs'...                                       not found
Checking `sniffer'...                                       WARNING

WARNING: Output from ifpromisc:
/proc/3219/fd: Permission denied
lo: not promisc and no packet sniffer sockets
wlo1: not promisc and no packet sniffer sockets

Checking `w55808'...                                        not found
Checking `wted'...                                          not found
Checking `scalper'...                                       RTNETLINK answers: Invalid argument
not found
Checking `slapper'...                                       RTNETLINK answers: Invalid argument
not found
Checking `z2'...                                            not found
Checking `chkutmp'...                                       WARNING

WARNING: chkutmp output: 
failed opening utmp !

Checking `OSX_RSPLUG'...                                    not tested
```
</details>

## 🦠 ClamAV Malware Analysis

### Virus Database Status

**Updating virus definitions...**
- ✅ Database updated successfully
- 📅 Database version: Build time: 16 Dec 2025 23:18 +0000

### ClamAV Service Status

- ⚠️ clamav-daemon is not running
  Starting clamav-daemon for scan...
- ❌ Failed to start clamav-daemon
- ℹ️ Using ClamAV scanner only (no daemon)

### Critical Directory Scan Results

| Directory | Status | Files Found | Threats | Scan Time |
|-----------|--------|-------------|---------|-----------|
| /home | ✅ Clean | 3 | 0 | 9s |
| /tmp | ✅ Clean | 16 | 0 | 14s |
| /var/www | ⚪ Skipped | 0 | 0 | 0s |
| /usr/local/bin | ✅ Clean | 1 | 0 | 14s |
| /var/tmp | ⚪ Skipped | 0 | 0 | 0s |

✅ **No malware threats detected** in critical directories

### Scan Summary & Statistics

| Metric | Value | Status |
|--------|-------|--------|
| Files Scanned | 20 | ✅ |
| Directories | /home /tmp /var/www /usr/local/bin /var/tmp | ✅ |
| Threats Found | 0 | ✅ |
| Database | Current | ✅ |
| Service | Scanner Only | ℹ️ |

## 📋 Security Recommendations

### 🎯 Executive Summary

| Security Area | Issues | Status | Priority |
|---------------|--------|--------|----------|
| 🔐 SSH Security | 0 | ✅ Secure | 🟢 Low |
| 🔥 Firewall | 3 | ⚠️ Needs Attention | 🚨 High |
| 👥 User Accounts | 0 | ✅ Secure | 🟢 Low |
| 📁 File Permissions | 2 | ⚠️ Review Needed | 🟡 Medium |
| 🦠 Malware/Rootkits | 1 | 🚨 Threats Found | 🚨 Critical |

**Overall Security Score:** **4/10** 🔴 HIGH RISK

### 🚨 Priority Actions (Address First)

2. **Enable Firewall Protection**
   sudo ufw enable
   sudo ufw allow ssh
   
   # For RHEL/CentOS:
   sudo systemctl enable --now firewalld
   

3. **Remove Malware Threats**
   sudo rm /path/to/infected/file
   # Run full system scan
   sudo clamscan -r --infected /
   

### 💡 Recommended Security Improvements

#### 🔐 SSH Security Enhancements

- **Change default SSH port** (optional but recommended):
  

#### 🛠️ Security Tools Installation

| Tool | Installation Command | Purpose |
|------|---------------------|---------|
| fail2ban | `sudo apt install fail2ban` | SSH brute force protection |

#### 📅 Ongoing Security Practices

✅ **Daily:**
- Review authentication logs for suspicious activity
- Check for failed login attempts

✅ **Weekly:**
- Run security updates: `sudo apt update && sudo apt upgrade`
- Scan critical directories for malware
- Review user accounts and privileges

✅ **Monthly:**
- Run comprehensive security audit
- Review and rotate passwords
- Check system logs for anomalies

#### ⏱️ Implementation Timeline

| Priority | Action | Estimated Time | Impact |
|----------|--------|----------------|--------|
| 🚨 Critical | Disable SSH root login | 5 minutes | 🛡️ High |
| 🚨 Critical | Enable firewall | 10 minutes | 🛡️ High |
| 🟡 Medium | Install security tools | 15 minutes | 🔍 Medium |
| 🟡 Medium | Configure SSH keys | 20 minutes | 🔐 High |
| 🟢 Low | Change SSH port | 10 minutes | 🕵️ Low |

**Total estimated time:** 1 hour for complete security hardening

---

### 📊 Quick Assessment Summary

**Security Score:** 4/10 🔴 HIGH RISK
**Total Issues Identified:** 6
**Tools Coverage:** 3/3 (99%)

*Report generated by LinWatch Security Audit*

📅 **Next audit recommended:** 2026-03-10
