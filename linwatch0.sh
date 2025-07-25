#!/bin/bash

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

# Header
cat << "EOF"
    __    _     _       __      __       __
   / /   (_)___| |     / /___ _/ /______/ /_
  / /   / / __ \ | /| / / __ `/ __/ ___/ __ \
 / /___/ / / / / |/ |/ / /_/ / /_/ /__/ / / /
/_____/_/_/ /_/|__/|__/\__,_/\__/\___/_/ /_/

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

# Detect the OS/Distro
DISTRO=$(awk -F= '/^ID=/{print $2}' /etc/os-release | tr -d ' "')
echo -e "${CYAN}Detected Distro:${NC} ${DISTRO}"
echo ""

# Last Update Date
get_last_update() {
    if command -v apt >/dev/null 2>&1; then
        echo -e "${CYAN}APT (Debian/Ubuntu) Last Update:${NC}"
        grep -i "Start-Date" /var/log/apt/history.log | tail -1 | cut -d ' ' -f2-

    elif command -v dnf >/dev/null 2>&1; then
        echo -e "${CYAN}DNF (Fedora/RHEL) Last Update:${NC}"
        grep "Updated:" /var/log/dnf.rpm.log | tail -1

    elif command -v yum >/dev/null 2>&1; then
        echo -e "${CYAN}YUM (Older RHEL/CentOS) Last Update:${NC}"
        grep Updated /var/log/yum.log | tail -1

    elif command -v pacman >/dev/null 2>&1; then
        echo -e "${CYAN}Pacman (Arch) Last Update:${NC}"
        grep -i upgraded /var/log/pacman.log | tail -1

    elif command -v zypper >/dev/null 2>&1; then
        echo -e "${CYAN}Zypper (openSUSE) Last Update:${NC}"
        grep -iE "install|update" /var/log/zypp/history | tail -1

    elif command -v apk >/dev/null 2>&1; then
        echo -e "${CYAN}APK (Alpine Linux) Last Update:${NC}"
        grep -i "apk" ~/.ash_history 2>/dev/null | tail -1 || echo "No log found"

    elif command -v snap >/dev/null 2>&1; then
        echo -e "${CYAN}Snap Packages Last Update:${NC}"
        snap list --all | grep -i installed | tail -1

    elif command -v emerge >/dev/null 2>&1; then
        echo -e "${CYAN}Emerge (Gentoo) Last Update:${NC}"
        tail -1 /var/log/emerge.log

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

            #once updates compelete, ask the user to reboot the system
            echo -ne "${CYAN}Updates are complete, do you wish to reboot the system now? (Y/N): ${NC}"
            read -r REBOOT_RESPONSE
            if [[ "$REBOOT_RESPONSE" =~ ^[Yy]$ ]]; then
                echo -e "${GREEN}Rebooting system...${NC}"
                sudo reboot
            else
                echo -e "${GREEN}Reboot skipped...${NC}"
            fi

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
