#!/bin/bash

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Variable to track if updates were installed
UPDATES_INSTALLED=false

# Header
cat << "EOF"


██      ██ ███    ██ ██     ██  █████  ████████  ██████ ██   ██
██      ██ ████   ██ ██     ██ ██   ██    ██    ██      ██   ██
██      ██ ██ ██  ██ ██  █  ██ ███████    ██    ██      ███████
██      ██ ██  ██ ██ ██ ███ ██ ██   ██    ██    ██      ██   ██
███████ ██ ██   ████  ███ ███  ██   ██    ██     ██████ ██   ██


EOF
echo ""

# Kernel Info
echo -e "${CYAN}Kernel version:${NC}"
uname -r
echo ""

# CPU Info
echo -e "${CYAN}CPU Info:${NC}"
lscpu | grep -E '^Architecture|^CPU\(s\)|^Thread|^Core|^Model name'
echo ""

# Memory Info
read -r total used free shared buff_cache available <<< $(free -h | awk '/^Mem:/ {print $2, $3, $4, $5, $6, $7}')
used_percent=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2 * 100}')
bar_length=30
filled=$(( used_percent * bar_length / 100 ))
empty=$(( bar_length - filled ))
bar=$(printf "%0.s#" $(seq 1 $filled))
space=$(printf "%0.s-" $(seq 1 $empty))
echo -e "${CYAN}RAM Usage:${NC}"
echo -e "${WHITE}[${bar}${space}]${NC} ${CYAN}${used_percent}% used${NC}"
echo -e "${WHITE}Used: ${used} / Total: ${total} (Available: ${available})${NC}"
echo ""

# Disk Usage
echo -e "${CYAN}Disk Usage:${NC}"
read -r size used avail perc <<< $(df -h / | awk 'NR==2 {print $2, $3, $4, $5}')
used_percent=${perc%\%}
bar_length=30
filled=$(( used_percent * bar_length / 100 ))
empty=$(( bar_length - filled ))
bar=$(printf "%0.s#" $(seq 1 $filled))
space=$(printf "%0.s-" $(seq 1 $empty))
echo -e "${WHITE}[${bar}${space}]${NC} ${CYAN}${perc} used${NC}"
echo -e "${WHITE}Used: ${used} / Total: ${size} (Available: ${avail})${NC}"
echo ""

# Uptime
echo -e "${CYAN}Uptime:${NC}"
uptime -p
echo ""

# Network Info
echo -e "${CYAN}Network Info:${NC}"
ip a | awk '/inet / && $2 !~ /^127/{sub("/.*", "", $2); print "IPV4: " $2} /inet6 / && $2 !~ /^::1/ {sub("/.*", "", $2); print "IPV6: " $2}'

# Fetch and Display Public IP (Requires internet connection)
if command -v curl >/dev/null 2>&1; then
    PUBLIC_IP=$(curl -s https://api.ipify.org)
    if [[ -n "$PUBLIC_IP" ]]; then
        echo -e "${CYAN}Public IP:${NC} $PUBLIC_IP"
    else
        echo -e "${RED}Public IP: Unable to fetch (no internet?)${NC}"
    fi
else
    echo -e "${RED}curl not installed. Cannot fetch public IP.${NC}"
fi

echo ""

# Logged in users
echo -e "${CYAN}Logged In:${NC}"
who
echo -e "${CYAN}Current User:${NC}"
whoami
echo ""

# Open Ports
echo -e "${CYAN}Open Network Ports:${NC}"
if command -v ss >/dev/null 2>&1; then
    # Modern systems
    ss -tulpn | grep LISTEN
elif command -v netstat >/dev/null 2>&1; then
    # Fallback for older systems
    netstat -tulpn | grep LISTEN
else
    echo -e "${RED}Neither 'ss' nor 'netstat' is installed. Unable to list open ports.${NC}"
fi
echo ""


# Detect the OS/Distro
DISTRO=$(awk -F= '/^ID=/{print $2}' /etc/os-release | tr -d ' "')
echo -e "${CYAN}Detected Distro:${NC} ${DISTRO}"
echo ""

# Last Update Date
get_last_update() {
    if command -v apt >/dev/null 2>&1; then
        echo -e "${CYAN}APT (Debian/Ubuntu) Last Update:${NC}"
        grep -i "Start-Date" /var/log/apt/history.log 2>/dev/null | tail -1 | cut -d ' ' -f2- || echo "Unable to determine"

    elif command -v dnf >/dev/null 2>&1; then
        echo -e "${CYAN}DNF (Fedora/RHEL) Last Update:${NC}"
        grep "Updated:" /var/log/dnf.rpm.log 2>/dev/null | tail -1 || echo "Unable to determine"

    elif command -v yum >/dev/null 2>&1; then
        echo -e "${CYAN}YUM (Older RHEL/CentOS) Last Update:${NC}"
        grep Updated /var/log/yum.log 2>/dev/null | tail -1 || echo "Unable to determine"

    elif command -v pacman >/dev/null 2>&1; then
        echo -e "${CYAN}Pacman (Arch) Last Update:${NC}"
        grep -i upgraded /var/log/pacman.log 2>/dev/null | tail -1 || echo "Unable to determine"

    elif command -v zypper >/dev/null 2>&1; then
        echo -e "${CYAN}Zypper (openSUSE) Last Update:${NC}"
        grep -iE "install|update" /var/log/zypp/history 2>/dev/null | tail -1 || echo "Unable to determine"

    elif command -v apk >/dev/null 2>&1; then
        echo -e "${CYAN}APK (Alpine Linux) Last Update:${NC}"
        grep -i "apk" ~/.ash_history 2>/dev/null | tail -1 || echo "No log found"

    elif command -v snap >/dev/null 2>&1; then
        echo -e "${CYAN}Snap Packages Last Update:${NC}"
        snap list --all 2>/dev/null | grep -i installed | tail -1 || echo "Unable to determine"

    elif command -v emerge >/dev/null 2>&1; then
        echo -e "${CYAN}Emerge (Gentoo) Last Update:${NC}"
        tail -1 /var/log/emerge.log 2>/dev/null || echo "Unable to determine"

    else
        echo -e "${RED}Package manager not recognized. Cannot determine last update.${NC}"
    fi
}

get_last_update
echo ""

# Ask user if they want to look for updates
echo -ne "${CYAN}Do you want to check for available updates? (y/n): ${NC}"
read -r USER_RESPONSE

if [[ "$USER_RESPONSE" =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}Checking for updates...${NC}"

    updates_available=false

    if command -v apt >/dev/null 2>&1; then
        sudo apt update -qq
        UPGRADABLE=$(apt list --upgradable 2>/dev/null | grep -v "Listing" | wc -l)
        if [ "$UPGRADABLE" -gt 0 ]; then
            updates_available=true
            echo -e "${CYAN}There are $UPGRADABLE packages available for upgrade.${NC}"
        fi

    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf check-update > /dev/null 2>&1
        if [ $? -eq 100 ]; then
            updates_available=true
            echo -e "${CYAN}There are updates available via dnf.${NC}"
        fi

    elif command -v yum >/dev/null 2>&1; then
        sudo yum check-update > /dev/null 2>&1
        if [ $? -eq 100 ]; then
            updates_available=true
            echo -e "${CYAN}There are updates available via yum.${NC}"
        fi

    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Sy --noconfirm > /dev/null 2>&1
        UPGRADABLE=$(pacman -Qu | wc -l)
        if [ "$UPGRADABLE" -gt 0 ]; then
            updates_available=true
            echo -e "${CYAN}There are $UPGRADABLE packages available for upgrade via pacman.${NC}"
        fi

    elif command -v zypper >/dev/null 2>&1; then
        sudo zypper refresh > /dev/null 2>&1
        UPGRADABLE=$(zypper lu | grep -c '^v')
        if [ "$UPGRADABLE" -gt 0 ]; then
            updates_available=true
            echo -e "${CYAN}There are $UPGRADABLE packages available for upgrade via zypper.${NC}"
        fi

    elif command -v apk >/dev/null 2>&1; then
        sudo apk update > /dev/null 2>&1
        updates_available=true
        echo -e "${CYAN}Updates may be available via apk.${NC}"

    elif command -v emerge >/dev/null 2>&1; then
        sudo emerge --sync > /dev/null 2>&1
        updates_available=true
        echo -e "${CYAN}Sync completed for Gentoo. Run 'emerge -uDNav @world' to check for upgrades.${NC}"

    else
        echo -e "${RED}Package manager not recognized. Cannot check for updates.${NC}"
    fi


# If updates are available, ask user if they wish to update
    if [ "$updates_available" = true ]; then
        echo -ne "${CYAN}Do you want to install the updates now? (y/n): ${NC}"
        read -r INSTALL_RESPONSE

        if [[ "$INSTALL_RESPONSE" =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}Installing updates...${NC}"

            if command -v apt >/dev/null 2>&1; then
                sudo apt upgrade -y

            elif command -v dnf >/dev/null 2>&1; then
                sudo dnf upgrade -y

            elif command -v yum >/dev/null 2>&1; then
                sudo yum update -y

            elif command -v pacman >/dev/null 2>&1; then
                sudo pacman -Syu --noconfirm

            elif command -v zypper >/dev/null 2>&1; then
                sudo zypper update -y

            elif command -v apk >/dev/null 2>&1; then
                sudo apk upgrade

            elif command -v emerge >/dev/null 2>&1; then
                echo -e "${CYAN}For Gentoo, please run manually:${NC} sudo emerge -uDNav @world"
            fi

            # Mark that updates were installed
            UPDATES_INSTALLED=true
            echo -e "${GREEN}Updates installed successfully!${NC}"

        else
            echo -e "${GREEN}Update installation skipped.${NC}"
        fi
    else
        echo -e "${GREEN}No updates available. Your system is up to date.${NC}"
    fi

else
    echo -e "${GREEN}Skipping update check.${NC}"
fi

echo ""

#============================================================================
# SECURITY FEATURES
#============================================================================

echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}            SECURITY AUDIT & TOOLS                     ${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo ""

# Function to install security tools
install_security_tools() {
    echo -e "${YELLOW}Installing security tools (rkhunter and chkrootkit)...${NC}"

    if command -v apt >/dev/null 2>&1; then
        sudo apt update -qq
        sudo apt install -y rkhunter chkrootkit 2>/dev/null

    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y rkhunter chkrootkit 2>/dev/null

    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y rkhunter chkrootkit 2>/dev/null

    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm rkhunter chkrootkit 2>/dev/null

    elif command -v zypper >/dev/null 2>&1; then
        sudo zypper install -y rkhunter chkrootkit 2>/dev/null

    elif command -v apk >/dev/null 2>&1; then
        sudo apk add rkhunter chkrootkit 2>/dev/null

    elif command -v emerge >/dev/null 2>&1; then
        sudo emerge --quiet app-forensics/rkhunter app-forensics/chkrootkit 2>/dev/null

    else
        echo -e "${RED}Package manager not recognized. Cannot install security tools.${NC}"
        return 1
    fi

    echo -e "${GREEN}Security tools installed successfully!${NC}"
}

# Function to perform security audit
perform_security_audit() {
    AUDIT_FILE="linwatch-security-audit-$(date +%Y%m%d-%H%M%S).md"

    echo -e "${GREEN}Performing security audit...${NC}"
    echo -e "${YELLOW}This may take several minutes. Audit report will be saved to: $AUDIT_FILE${NC}"
    echo ""

    # Start markdown report
    cat > "$AUDIT_FILE" << EOF
# Linwatch Security Audit Report
**Generated:** $(date)
**Hostname:** $(hostname)
**Kernel:** $(uname -r)
**Distribution:** $DISTRO

---

EOF

    # Check if security tools are installed
    RKHUNTER_INSTALLED=false
    CHKROOTKIT_INSTALLED=false

    if command -v rkhunter >/dev/null 2>&1; then
        RKHUNTER_INSTALLED=true
    fi

    if command -v chkrootkit >/dev/null 2>&1; then
        CHKROOTKIT_INSTALLED=true
    fi

    # Section 1: System Information
    echo "## 1. System Information" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"
    echo "- **Uptime:** $(uptime -p)" >> "$AUDIT_FILE"
    echo "- **Last Reboot:** $(who -b | awk '{print $3, $4}')" >> "$AUDIT_FILE"
    echo "- **Current User:** $(whoami)" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"

    # Section 2: User Accounts
    echo "## 2. User Account Analysis" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"
    echo "### Users with Login Shell" >> "$AUDIT_FILE"
    echo '```' >> "$AUDIT_FILE"
    grep -E '/bin/(bash|sh|zsh|fish)' /etc/passwd >> "$AUDIT_FILE"
    echo '```' >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"

    echo "### Users with UID 0 (Root Privileges)" >> "$AUDIT_FILE"
    echo '```' >> "$AUDIT_FILE"
    awk -F: '($3 == 0) {print $1}' /etc/passwd >> "$AUDIT_FILE"
    echo '```' >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"

    echo "### Accounts Without Passwords" >> "$AUDIT_FILE"
    echo '```' >> "$AUDIT_FILE"
    sudo awk -F: '($2 == "" ) {print $1}' /etc/shadow 2>/dev/null >> "$AUDIT_FILE" || echo "Permission denied" >> "$AUDIT_FILE"
    echo '```' >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"

    # Section 3: Open Ports and Services
    echo "## 3. Network Security" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"
    echo "### Listening Ports" >> "$AUDIT_FILE"
    echo '```' >> "$AUDIT_FILE"
    if command -v ss >/dev/null 2>&1; then
        ss -tulpn | grep LISTEN >> "$AUDIT_FILE"
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tulpn | grep LISTEN >> "$AUDIT_FILE"
    fi
    echo '```' >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"

    echo "### Active Network Connections" >> "$AUDIT_FILE"
    echo '```' >> "$AUDIT_FILE"
    if command -v ss >/dev/null 2>&1; then
        ss -tunp 2>/dev/null | head -20 >> "$AUDIT_FILE"
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tunp 2>/dev/null | head -20 >> "$AUDIT_FILE"
    fi
    echo '```' >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"

    # Section 4: Firewall Status
    echo "## 4. Firewall Status" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"

    if command -v ufw >/dev/null 2>&1; then
        echo "### UFW Status" >> "$AUDIT_FILE"
        echo '```' >> "$AUDIT_FILE"
        sudo ufw status verbose >> "$AUDIT_FILE" 2>/dev/null
        echo '```' >> "$AUDIT_FILE"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        echo "### Firewalld Status" >> "$AUDIT_FILE"
        echo '```' >> "$AUDIT_FILE"
        sudo firewall-cmd --state >> "$AUDIT_FILE" 2>/dev/null
        sudo firewall-cmd --list-all >> "$AUDIT_FILE" 2>/dev/null
        echo '```' >> "$AUDIT_FILE"
    elif command -v iptables >/dev/null 2>&1; then
        echo "### IPTables Rules" >> "$AUDIT_FILE"
        echo '```' >> "$AUDIT_FILE"
        sudo iptables -L -n -v >> "$AUDIT_FILE" 2>/dev/null
        echo '```' >> "$AUDIT_FILE"
    else
        echo "**No firewall detected or not accessible**" >> "$AUDIT_FILE"
    fi
    echo "" >> "$AUDIT_FILE"

    # Section 5: SSH Configuration
    echo "## 5. SSH Security" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"
    if [ -f /etc/ssh/sshd_config ]; then
        echo "### Key SSH Settings" >> "$AUDIT_FILE"
        echo '```' >> "$AUDIT_FILE"
        grep -E '^(PermitRootLogin|PasswordAuthentication|PubkeyAuthentication|Port|AllowUsers|DenyUsers)' /etc/ssh/sshd_config 2>/dev/null >> "$AUDIT_FILE"
        echo '```' >> "$AUDIT_FILE"
    else
        echo "**SSH config not found**" >> "$AUDIT_FILE"
    fi
    echo "" >> "$AUDIT_FILE"

    # Section 6: File Permissions (SUID/SGID)
    echo "## 6. Suspicious File Permissions" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"
    echo "### SUID Files (First 20)" >> "$AUDIT_FILE"
    echo '```' >> "$AUDIT_FILE"
    sudo find / -perm -4000 -type f 2>/dev/null | head -20 >> "$AUDIT_FILE"
    echo '```' >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"

    echo "### World-Writable Files (First 20)" >> "$AUDIT_FILE"
    echo '```' >> "$AUDIT_FILE"
    sudo find / -xdev -type f -perm -0002 2>/dev/null | head -20 >> "$AUDIT_FILE"
    echo '```' >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"

    # Section 7: Failed Login Attempts
    echo "## 7. Authentication Security" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"
    echo "### Recent Failed Login Attempts" >> "$AUDIT_FILE"
    echo '```' >> "$AUDIT_FILE"
    if [ -f /var/log/auth.log ]; then
        sudo grep "Failed password" /var/log/auth.log 2>/dev/null | tail -10 >> "$AUDIT_FILE"
    elif [ -f /var/log/secure ]; then
        sudo grep "Failed password" /var/log/secure 2>/dev/null | tail -10 >> "$AUDIT_FILE"
    else
        echo "No authentication log found" >> "$AUDIT_FILE"
    fi
    echo '```' >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"

    # Section 8: Installed Security Tools
    echo "## 8. Security Tools Status" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"
    echo "- **rkhunter:** $(if $RKHUNTER_INSTALLED; then echo "Installed ✓"; else echo "Not Installed ✗"; fi)" >> "$AUDIT_FILE"
    echo "- **chkrootkit:** $(if $CHKROOTKIT_INSTALLED; then echo "Installed ✓"; else echo "Not Installed ✗"; fi)" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"

    # Section 9: Rootkit Scan (rkhunter)
    if [ "$RKHUNTER_INSTALLED" = true ]; then
        echo -e "${CYAN}Running rkhunter scan...${NC}"
        echo "## 9. Rootkit Hunter (rkhunter) Scan" >> "$AUDIT_FILE"
        echo "" >> "$AUDIT_FILE"
        echo '```' >> "$AUDIT_FILE"
        sudo rkhunter --update > /dev/null 2>&1
        sudo rkhunter --check --skip-keypress --report-warnings-only >> "$AUDIT_FILE" 2>&1
        echo '```' >> "$AUDIT_FILE"
        echo "" >> "$AUDIT_FILE"
    fi

    # Section 10: Rootkit Scan (chkrootkit)
    if [ "$CHKROOTKIT_INSTALLED" = true ]; then
        echo -e "${CYAN}Running chkrootkit scan...${NC}"
        echo "## 10. Chkrootkit Scan" >> "$AUDIT_FILE"
        echo "" >> "$AUDIT_FILE"
        echo '```' >> "$AUDIT_FILE"
        sudo chkrootkit >> "$AUDIT_FILE" 2>&1
        echo '```' >> "$AUDIT_FILE"
        echo "" >> "$AUDIT_FILE"
    fi

    # Section 11: Recommendations
    echo "## 11. Security Recommendations" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"

    RECOMMENDATIONS=()

    # Check SSH root login
    if grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config 2>/dev/null; then
        RECOMMENDATIONS+=("- ⚠️ **Disable SSH root login:** Set \`PermitRootLogin no\` in /etc/ssh/sshd_config")
    fi

    # Check password authentication
    if grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config 2>/dev/null; then
        RECOMMENDATIONS+=("- ⚠️ **Consider disabling SSH password authentication:** Use key-based authentication only")
    fi

    # Check firewall
    FIREWALL_ACTIVE=false
    if command -v ufw >/dev/null 2>&1 && sudo ufw status 2>/dev/null | grep -q "Status: active"; then
        FIREWALL_ACTIVE=true
    elif command -v firewall-cmd >/dev/null 2>&1 && sudo firewall-cmd --state 2>/dev/null | grep -q "running"; then
        FIREWALL_ACTIVE=true
    fi

    if [ "$FIREWALL_ACTIVE" = false ]; then
        RECOMMENDATIONS+=("- ⚠️ **Enable firewall:** Configure ufw, firewalld, or iptables")
    fi

    # Check if security tools are installed
    if [ "$RKHUNTER_INSTALLED" = false ]; then
        RECOMMENDATIONS+=("- 💡 **Install rkhunter:** Rootkit detection tool")
    fi

    if [ "$CHKROOTKIT_INSTALLED" = false ]; then
        RECOMMENDATIONS+=("- 💡 **Install chkrootkit:** Additional rootkit scanning")
    fi

    RECOMMENDATIONS+=("- 💡 **Keep system updated:** Regularly run system updates")
    RECOMMENDATIONS+=("- 💡 **Review user accounts:** Remove unused accounts and check privileges")
    RECOMMENDATIONS+=("- 💡 **Monitor logs:** Regularly check /var/log/auth.log or /var/log/secure")
    RECOMMENDATIONS+=("- 💡 **Use strong passwords:** Enforce password complexity policies")

    if [ ${#RECOMMENDATIONS[@]} -eq 0 ]; then
        echo "✅ No immediate recommendations. System appears well-configured." >> "$AUDIT_FILE"
    else
        for rec in "${RECOMMENDATIONS[@]}"; do
            echo "$rec" >> "$AUDIT_FILE"
        done
    fi

    echo "" >> "$AUDIT_FILE"

    # Footer
    echo "---" >> "$AUDIT_FILE"
    echo "*Report generated by Linwatch Security Audit*" >> "$AUDIT_FILE"

    echo -e "${GREEN}✓ Security audit complete!${NC}"
    echo -e "${GREEN}Report saved to: ${CYAN}$AUDIT_FILE${NC}"
    echo ""
}

# Main security menu
echo -ne "${CYAN}Would you like to perform a security audit? (y/n): ${NC}"
read -r SECURITY_RESPONSE

if [[ "$SECURITY_RESPONSE" =~ ^[Yy]$ ]]; then

    # Check if tools are installed
    TOOLS_MISSING=false

    if ! command -v rkhunter >/dev/null 2>&1; then
        TOOLS_MISSING=true
        echo -e "${YELLOW}rkhunter is not installed.${NC}"
    fi

    if ! command -v chkrootkit >/dev/null 2>&1; then
        TOOLS_MISSING=true
        echo -e "${YELLOW}chkrootkit is not installed.${NC}"
    fi

    if [ "$TOOLS_MISSING" = true ]; then
        echo -ne "${CYAN}Would you like to install missing security tools? (y/n): ${NC}"
        read -r INSTALL_TOOLS

        if [[ "$INSTALL_TOOLS" =~ ^[Yy]$ ]]; then
            install_security_tools
            echo ""
        fi
    fi

    # Perform the audit
    perform_security_audit

else
    echo -e "${GREEN}Security audit skipped.${NC}"
fi

echo ""

#============================================================================
# REBOOT PROMPT (After everything is complete)
#============================================================================

# Now ask about reboot if updates were installed
if [ "$UPDATES_INSTALLED" = true ]; then
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -ne "${CYAN}Updates were installed. Do you wish to reboot the system now? (y/n): ${NC}"
    read -r REBOOT_RESPONSE
    if [[ "$REBOOT_RESPONSE" =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Rebooting system...${NC}"
        sudo reboot
    else
        echo -e "${YELLOW}Reboot skipped. Please remember to reboot later to apply all updates.${NC}"
    fi
    echo ""
fi

echo -e "${GREEN}Linwatch complete!${NC}"
