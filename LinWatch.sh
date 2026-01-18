#!/bin/bash

# Version: 1.0.9

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
BOLD='\033[1m'
NC='\033[0m'

# Variable to track if updates were installed
UPDATES_INSTALLED=false

# Function to get current version from script
get_current_version() {
    if [[ -f "$0" ]]; then
        grep '^# Version:' "$0" | head -1 | sed -E 's/# Version: *v?//' || echo "1.0.6"
    else
        echo "1.0.6"
    fi
}

# Current version of LinWatch
CURRENT_VERSION=$(get_current_version)

# Function to get latest release from GitHub API
get_latest_release() {
    if command -v curl >/dev/null 2>&1; then
        LATEST_RELEASE=$(curl -s --max-time 10 "https://api.github.com/repos/Adhvay0505/LinWatch/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ -n "$LATEST_RELEASE" ]]; then
            echo "$LATEST_RELEASE"
        else
            echo ""
        fi
    else
        echo ""
    fi
}

# Function to update version in script
update_version_in_script() {
    local new_version="$1"
    local script_file="$0"
    
    if [[ -f "$script_file" ]]; then
        # Update version variable if it exists
        if grep -q '^CURRENT_VERSION=' "$script_file"; then
            sed -i "s/^CURRENT_VERSION=\"[^\"]*\"/CURRENT_VERSION=\"$new_version\"/" "$script_file"
        fi
        
        # Add or update version comment at the top of the script
        if grep -q '^# Version:' "$script_file"; then
            sed -i "s/^# Version:.*/# Version: $new_version/" "$script_file"
        else
            # Add version comment after the shebang line
            sed -i "2i# Version: $new_version" "$script_file"
        fi
    fi
}

# Function to compare versions
compare_versions() {
    local current="$1"
    local latest="$2"
    
    # Remove 'v' prefix if present
    current=${current#v}
    latest=${latest#v}
    
    # Split version numbers
    IFS='.' read -ra CURRENT_PARTS <<< "$current"
    IFS='.' read -ra LATEST_PARTS <<< "$latest"
    
    # Compare major, minor, patch
    for i in {0..2}; do
        local current_part=${CURRENT_PARTS[$i]:-0}
        local latest_part=${LATEST_PARTS[$i]:-0}
        
        if (( current_part < latest_part )); then
            return 1  # Update available
        elif (( current_part > latest_part )); then
            return 0  # Current is newer
        fi
    done
    
    return 0  # Versions are equal
}

# Function to download and install latest release
update_linwatch() {
    local latest_tag="$1"
    
    echo -e "${CYAN}Downloading LinWatch $latest_tag...${NC}"
    
    # Get download URL for the latest release
    DOWNLOAD_URL=$(curl -s --max-time 10 "https://api.github.com/repos/Adhvay0505/LinWatch/releases/latest" | grep '"browser_download_url":.*LinWatch\.sh' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [[ -z "$DOWNLOAD_URL" ]]; then
        echo -e "${RED}Failed to get download URL for LinWatch $latest_tag${NC}"
        return 1
    fi
    
    # Create backup of current script
    local backup_path="${0}.backup.$(date +%Y%m%d-%H%M%S)"
    echo -e "${YELLOW}Creating backup: $backup_path${NC}"
    cp "$0" "$backup_path"
    
    # Download the new version
    if curl -L --max-time 30 -o "${0}.new" "$DOWNLOAD_URL"; then
        # Make it executable
        chmod +x "${0}.new"
        
        # Replace the old script
        mv "${0}.new" "$0"
        
        # Update version information in the new script
        update_version_in_script "$latest_tag"
        
        echo -e "${GREEN}✓ LinWatch updated successfully to version $latest_tag!${NC}"
        echo -e "${GRAY}Backup saved to: $backup_path${NC}"
        echo -e "${YELLOW}Please restart LinWatch to use the new version.${NC}"
        return 0
    else
        echo -e "${RED}Failed to download LinWatch $latest_tag${NC}"
        # Remove incomplete download if it exists
        rm -f "${0}.new"
        return 1
    fi
}

# Function to check for LinWatch updates
check_linwatch_updates() {
    echo -e "${CYAN}Checking for LinWatch updates...${NC}"
    
    local latest_release
    latest_release=$(get_latest_release)
    
    if [[ -z "$latest_release" ]]; then
        echo -e "${YELLOW}Unable to check for updates (no internet connection or GitHub API unavailable)${NC}"
        return 1
    fi
    
    # Get current version from script file
    local current_version
    current_version=$(get_current_version)
    
    echo -e "${GRAY}Current version: $current_version${NC}"
    echo -e "${GRAY}Latest version: $latest_release${NC}"
    
    if compare_versions "$current_version" "$latest_release"; then
        echo -e "${GREEN}LinWatch is up to date!${NC}"
        return 0
    else
        echo -e "${YELLOW}A new version of LinWatch is available: $latest_release${NC}"
        echo -e "${MAGENTA}Release notes: https://github.com/Adhvay0505/LinWatch/releases/tag/$latest_release${NC}"
        
        echo -e "${YELLOW}┌──────────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${YELLOW}│${NC} ${WHITE}Would you like to update LinWatch now?${NC}"
        echo -e "${YELLOW}│${NC}"
        echo -ne "${YELLOW}│${NC} ${CYAN}Update to $latest_release? (y/n):${NC} "
        read -r UPDATE_RESPONSE
        echo -e "${YELLOW}│${NC}"
        echo -e "${YELLOW}└──────────────────────────────────────────────────────────────────${NC}"
        echo ""
        
        if [[ "$UPDATE_RESPONSE" =~ ^[Yy]$ ]]; then
            if update_linwatch "$latest_release"; then
                echo -e "${GREEN}Update completed! Restart LinWatch to use the new version.${NC}"
                exit 0
            else
                echo -e "${RED}Update failed. You can manually update from:${NC}"
                echo -e "${CYAN}https://github.com/Adhvay0505/LinWatch/releases/latest${NC}"
                return 1
            fi
        else
            echo -e "${GRAY}Update skipped by user${NC}"
            return 1
        fi
    fi
}

# Animated welcome function
welcome_animation() {
    clear
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local colors=("$CYAN" "$BLUE" "$GREEN" "$MAGENTA" "$YELLOW")
    
    for i in {1..20}; do
        frame=${frames[$((i % 10))]}
        color=${colors[$((i % 5))]}
        printf "\r${color}%s${NC} Initializing LinWatch..." "$frame"
        sleep 0.1
    done
    printf "\r${GREEN}✓${NC} LinWatch initialized successfully!\n"
    sleep 1
}

# Enhanced ASCII art with gradient effect
show_welcome_header() {
    clear
    echo -e "${CYAN}██╗     ██╗███╗   ██╗██╗    ██╗ █████╗ ████████╗ ██████╗██╗  ██╗${NC}"
    echo -e "${CYAN}██║     ██║████╗  ██║██║    ██║██╔══██╗╚══██╔══╝██╔════╝██║  ██║${NC}"
    echo -e "${CYAN}██║     ██║██╔██╗ ██║██║ █╗ ██║███████║   ██║   ██║     ███████║${NC}"
    echo -e "${CYAN}██║     ██║██║╚██╗██║██║███╗██║██╔══██║   ██║   ██║     ██╔══██║${NC}"
    echo -e "${CYAN}███████╗██║██║ ╚████║╚███╔███╔╝██║  ██║   ██║   ╚██████╗██║  ██║${NC}"
    echo -e "${CYAN}╚══════╝╚═╝╚═╝  ╚═══╝ ╚══╝╚══╝ ╚═╝  ╚═╝   ╚═╝    ╚═════╝╚═╝  ╚═╝${NC}"
    echo ""
    echo -e "${GRAY}                    ${BOLD}Linux System Monitor & Updater${NC}"
    echo -e "${GRAY}                      Version $CURRENT_VERSION | $(date '+%Y-%m-%d')${NC}"
    echo ""
    echo -e "${GREEN}●${NC} System Health: ${GREEN}OPTIMAL${NC}    ${BLUE}●${NC} Network: ${BLUE}CONNECTED${NC}    ${YELLOW}●${NC} Updates: ${YELLOW}CHECKING...${NC}"
    echo ""
}
# Comfortable loading animation
comfort_loading() {
    local message="$1"
    local duration="$2"
    
    echo -ne "${CYAN}$message${NC} "
    local chars=("⠁" "⠂" "⠄" "⡀" "⢀" "⠠" "⠐" "⠈")
    for i in $(seq 1 $duration); do
        printf "${GREEN}%s${NC}" "${chars[$((i % 8))]}"
        sleep 0.1
        printf "\b"
    done
    printf " ${GREEN}✓${NC}\n"
}

# Main welcome sequence
main_welcome() {
    welcome_animation
    show_welcome_header
    
    echo -e "${BOLD}${WHITE}Welcome to LinWatch!${NC}"
    echo -e "${GRAY}Your cozy companion for Linux system monitoring and maintenance.${NC}"
    echo ""
    
    comfort_loading "Preparing system diagnostics" 15
    comfort_loading "Loading security modules" 12
    comfort_loading "Initializing update checker" 10
    
    echo ""
    
    # Check for LinWatch updates
    echo -e "${MAGENTA}┌──────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${MAGENTA}│${NC} ${WHITE}Check for LinWatch application updates?${NC}"
    echo -e "${MAGENTA}│${NC}"
    echo -ne "${MAGENTA}│${NC} ${CYAN}Check for LinWatch updates? (y/n):${NC} "
    read -r LINWATCH_UPDATE_RESPONSE
    echo -e "${MAGENTA}│${NC}"
    echo -e "${MAGENTA}└──────────────────────────────────────────────────────────────────${NC}"
    echo ""
    
    if [[ "$LINWATCH_UPDATE_RESPONSE" =~ ^[Yy]$ ]]; then
        check_linwatch_updates
        echo ""
    fi
    echo -e "${MAGENTA}┌──────────────────────────────────────────────────────────────────${NC}"
    echo -e "${MAGENTA}│${NC} ${BOLD}${WHITE}Let's make your system feel great today!${NC}"
    echo -e "${MAGENTA}└─────────────────────────────────────────────────────────────────${NC}"
    echo ""
    sleep 2
}

# Start the main welcome sequence
main_welcome

# Kernel Info with enhanced styling
echo -e "${CYAN}┌──────────────────────────────────────────────────────────────────${NC}"
echo -e "${CYAN}│${NC} ${WHITE}Kernel Version:${NC} ${GREEN}$(uname -r)${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────────────────────────${NC}"
echo ""

# CPU Info with enhanced display
echo -e "${CYAN}┌──────────────────────────────────────────────────────────────────${NC}"
echo -e "${CYAN}│${NC} ${WHITE}Architecture:${NC} ${GREEN}$(lscpu | awk '/^Architecture:/ {print $2}')${NC}"
echo -e "${CYAN}│${NC} ${WHITE}CPU(s):${NC} ${GREEN}$(lscpu | awk '/^CPU\(s\):/ {print $2}')${NC}"
echo -e "${CYAN}│${NC} ${WHITE}Threads:${NC} ${GREEN}$(lscpu | awk '/^Thread(s):/ {print $2}')${NC}"
echo -e "${CYAN}│${NC} ${WHITE}Cores:${NC} ${GREEN}$(lscpu | awk '/^Core(s):/ {print $2}')${NC}"
echo -e "${CYAN}│${NC} ${WHITE}Model:${NC} ${GREEN}$(lscpu | awk '/^Model name:/ {print substr($0, index($0, $3))}')${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────────────────────────${NC}"
echo ""

# Memory Info with enhanced visualization
echo -e "${CYAN}┌──────────────────────────────────────────────────────────────────┐${NC}"
read -r total used free shared buff_cache available <<< $(free -h | awk '/^Mem:/ {print $2, $3, $4, $5, $6, $7}')
used_percent=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2 * 100}')
bar_length=40
filled=$(( used_percent * bar_length / 100 ))
empty=$(( bar_length - filled ))

# Color-coded memory bar
if [ "$used_percent" -lt 50 ]; then
    bar_color="${GREEN}"
elif [ "$used_percent" -lt 80 ]; then
    bar_color="${YELLOW}"
else
    bar_color="${RED}"
fi

bar=$(printf "%0.s█" $(seq 1 $filled))
space=$(printf "%0.s░" $(seq 1 $empty))

echo -e "${CYAN}│${NC} ${WHITE}RAM Usage:${NC} ${bar_color}[${bar}${space}]${NC} ${WHITE}${used_percent}%${NC}"
echo -e "${CYAN}│${NC} ${WHITE}Details:${NC} ${GRAY}Used: ${used} / Total: ${total} (Available: ${available})${NC}"
echo -e "${CYAN}└─────────────────────────────────────────────────────────────────${NC}"
echo ""

# Disk Usage with enhanced visualization
echo -e "${CYAN}┌──────────────────────────────────────────────────────────────────┐${NC}"
read -r size used avail perc <<< $(df -h / | awk 'NR==2 {print $2, $3, $4, $5}')
used_percent=${perc%\%}
bar_length=40
filled=$(( used_percent * bar_length / 100 ))
empty=$(( bar_length - filled ))

# Color-coded disk bar
if [ "$used_percent" -lt 60 ]; then
    bar_color="${GREEN}"
elif [ "$used_percent" -lt 85 ]; then
    bar_color="${YELLOW}"
else
    bar_color="${RED}"
fi

bar=$(printf "%0.s█" $(seq 1 $filled))
space=$(printf "%0.s░" $(seq 1 $empty))

echo -e "${CYAN}│${NC} ${WHITE}Root Partition:${NC} ${bar_color}[${bar}${space}]${NC} ${WHITE}${perc} used${NC}"
echo -e "${CYAN}│${NC} ${WHITE}Details:${NC} ${GRAY}Used: ${used} / Total: ${size} (Available: ${avail})${NC}"
echo -e "${CYAN}└─────────────────────────────────────────────────────────────────${NC}"
echo ""

# Uptime with enhanced display
echo -e "${CYAN}┌──────────────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│${NC} ${WHITE}System has been up for:${NC} ${GREEN}$(uptime -p)${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────────────────────────${NC}"
echo ""

# Network Info with enhanced display
echo -e "${CYAN}┌──────────────────────────────────────────────────────────────────┐${NC}"
local_ipv4=$(ip a | awk '/inet / && $2 !~ /^127/{sub("/.*", "", $2); print $2; exit}')
local_ipv6=$(ip a | awk '/inet6 / && $2 !~ /^::1/ {sub("/.*", "", $2); print $2; exit}')

echo -e "${CYAN}│${NC} ${WHITE}Local IPv4:${NC} ${GREEN}${local_ipv4:-Not available}${NC}"
echo -e "${CYAN}│${NC} ${WHITE}Local IPv6:${NC} ${GREEN}${local_ipv6:-Not available}${NC}"

# Fetch and Display Public IP with animation
if command -v curl >/dev/null 2>&1; then
    echo -ne "${CYAN}│${NC} ${WHITE}Public IP:${NC} ${YELLOW}Fetching...${NC}\r"
    PUBLIC_IP=$(curl -s --max-time 5 https://api.ipify.org)
    if [[ -n "$PUBLIC_IP" ]]; then
        echo -e "${CYAN}│${NC} ${WHITE}Public IP:${NC} ${GREEN}${PUBLIC_IP}${NC}"
    else
        echo -e "${CYAN}│${NC} ${WHITE}Public IP:${NC} ${RED}Unable to fetch (no internet?)${NC}"
    fi
else
    echo -e "${CYAN}│${NC} ${WHITE}Public IP:${NC} ${RED}curl not installed${NC}"
fi

echo -e "${CYAN}└─────────────────────────────────────────────────────────────────${NC}"
echo ""

# User Information with enhanced display
echo -e "${CYAN}┌──────────────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│${NC} ${WHITE}Current User:${NC} ${GREEN}$(whoami)${NC}"
echo -e "${CYAN}│${NC} ${WHITE}Active Sessions:${NC}"
who | while read line; do
    echo -e "${CYAN}│${NC}   ${GRAY}$line${NC}"
done
echo -e "${CYAN}└──────────────────────────────────────────────────────────────────${NC}"
echo ""

# Open Ports with enhanced display
echo -e "${CYAN}┌──────────────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│${NC} ${WHITE}Listening Ports:${NC}"
if command -v ss >/dev/null 2>&1; then
    # Modern systems - limit to first 10 for cleaner display
    ss -tulpn | grep LISTEN | head -10 | while read line; do
        echo -e "${CYAN}│${NC}   ${GRAY}$line${NC}"
    done
    total_ports=$(ss -tulpn | grep LISTEN | wc -l)
    if [ "$total_ports" -gt 10 ]; then
        echo -e "${CYAN}│${NC}   ${YELLOW}... and $((total_ports - 10)) more ports${NC}"
    fi
elif command -v netstat >/dev/null 2>&1; then
    # Fallback for older systems
    netstat -tulpn | grep LISTEN | head -10 | while read line; do
        echo -e "${CYAN}│${NC}   ${GRAY}$line${NC}"
    done
else
    echo -e "${CYAN}│${NC}   ${RED}Neither 'ss' nor 'netstat' is installed${NC}"
fi
echo -e "${CYAN}└──────────────────────────────────────────────────────────────────${NC}"
echo ""

# System Information with enhanced display
echo -e "${CYAN}┌──────────────────────────────────────────────────────────────────┐${NC}"
DISTRO=$(awk -F= '/^ID=/{print $2}' /etc/os-release | tr -d ' "')
DISTRO_NAME=$(awk -F= '/^NAME=/{print $2}' /etc/os-release | tr -d '"')
echo -e "${CYAN}│${NC} ${WHITE}Distribution:${NC} ${GREEN}$DISTRO_NAME${NC}"
echo -e "${CYAN}│${NC} ${WHITE}Hostname:${NC} ${GREEN}$(hostname)${NC}"
echo -e "${CYAN}│${NC} ${WHITE}Shell:${NC} ${GREEN}$SHELL${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────────────────────────${NC}"
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

# Enhanced update prompt with comfort styling
echo -e "${MAGENTA}┌──────────────────────────────────────────────────────────────────┐${NC}"
echo -e "${MAGENTA}│${NC} ${WHITE}Ready to check for system updates?${NC}"
echo -e "${MAGENTA}│${NC}"
echo -ne "${MAGENTA}│${NC} ${CYAN}Check for updates? (y/n):${NC} "
read -r USER_RESPONSE
echo -e "${MAGENTA}│${NC}"
echo -e "${MAGENTA}└──────────────────────────────────────────────────────────────────${NC}"
echo ""

if [[ "$USER_RESPONSE" =~ ^[Yy]$ ]]; then
    comfort_loading "Checking for system updates" 20
    echo ""

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
        echo -e "${YELLOW}┌──────────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${YELLOW}│${NC} ${WHITE}Updates are ready to install!${NC}"
        echo -e "${YELLOW}│${NC}"
        echo -ne "${YELLOW}│${NC} ${CYAN}Install updates now? (y/n):${NC} "
        read -r INSTALL_RESPONSE
        echo -e "${YELLOW}│${NC}"
        echo -e "${YELLOW}└──────────────────────────────────────────────────────────────────${NC}"
        echo ""

        if [[ "$INSTALL_RESPONSE" =~ ^[Yy]$ ]]; then
            comfort_loading "Installing system updates" 30
            echo ""

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
            
            # Check for Flatpak installation and update Flatpak packages
            if command -v flatpak >/dev/null 2>&1; then
                echo -e "${CYAN}Flatpak detected, checking for Flatpak updates...${NC}"
                flatpak update -y
                echo -e "${GREEN}Flatpak updates completed!${NC}"
            fi

        else
            echo -e "${YELLOW}┌──────────────────────────────────────────────────────────────────┐${NC}"
            echo -e "${YELLOW}│${NC} ${WHITE}Update installation skipped by user${NC}"
            echo -e "${YELLOW}└──────────────────────────────────────────────────────────────────${NC}"
            echo ""
        fi
    else
        echo -e "${GREEN}┌──────────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${GREEN}│${NC} ${WHITE}No updates available. Your system is up to date!${NC}"
        echo -e "${GREEN}└─────────────────────────────────────────────────────────────────${NC}"
        echo ""
    fi

else
    echo -e "${GRAY}┌──────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${GRAY}│${NC} ${WHITE}Update check skipped by user${NC}"
    echo -e "${GRAY}└──────────────────────────────────────────────────────────────────${NC}"
    echo ""
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
# LinWatch Security Audit Report
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
    echo "*Report generated by LinWatch Security Audit*" >> "$AUDIT_FILE"

    echo -e "${GREEN}✓ Security audit complete!${NC}"
    echo -e "${GREEN}Report saved to: ${CYAN}$AUDIT_FILE${NC}"
    echo ""
}

# Enhanced security menu with comfort styling
echo -e "${MAGENTA}┌──────────────────────────────────────────────────────────────────┐${NC}"
echo -e "${MAGENTA}│${NC} ${WHITE}Would you like to perform a comprehensive security audit?${NC}"
echo -e "${MAGENTA}│${NC}"
echo -ne "${MAGENTA}│${NC} ${CYAN}Run security audit? (y/n):${NC} "
read -r SECURITY_RESPONSE
echo -e "${MAGENTA}│${NC}"
echo -e "${MAGENTA}└──────────────────────────────────────────────────────────────────${NC}"
echo ""

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
        echo -e "${YELLOW}┌──────────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${YELLOW}│${NC} ${WHITE}Some security tools are missing for a complete audit${NC}"
        echo -e "${YELLOW}│${NC}"
        echo -ne "${YELLOW}│${NC} ${CYAN}Install missing tools? (y/n):${NC} "
        read -r INSTALL_TOOLS
        echo -e "${YELLOW}│${NC}"
        echo -e "${YELLOW}└──────────────────────────────────────────────────────────────────${NC}"
        echo ""

        if [[ "$INSTALL_TOOLS" =~ ^[Yy]$ ]]; then
            install_security_tools
            echo ""
        fi
    fi

    # Perform the audit
    perform_security_audit

else
    echo -e "${GRAY}┌──────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${GRAY}│${NC} ${WHITE}Security audit skipped by user${NC}"
    echo -e "${GRAY}└──────────────────────────────────────────────────────────────────${NC}"
    echo ""
fi

echo ""

#============================================================================
# REBOOT PROMPT (After everything is complete)
#============================================================================

# Enhanced reboot prompt with comfort styling
if [ "$UPDATES_INSTALLED" = true ]; then
    echo -e "${GREEN}┌──────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${GREEN}│${NC} ${WHITE}Updates were successfully installed!${NC}"
    echo -e "${GREEN}│${NC} ${YELLOW}A reboot is recommended to apply all changes${NC}"
    echo -e "${GREEN}│${NC}"
    echo -ne "${GREEN}│${NC} ${CYAN}Reboot system now? (y/n):${NC} "
    read -r REBOOT_RESPONSE
    echo -e "${GREEN}│${NC}"
    echo -e "${GREEN}└──────────────────────────────────────────────────────────────────${NC}"
    echo ""
    if [[ "$REBOOT_RESPONSE" =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Rebooting system...${NC}"
        sudo reboot
    else
        echo -e "${YELLOW}┌──────────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${YELLOW}│${NC} ${WHITE}Reboot skipped. Remember to reboot later to apply updates.${NC}"
        echo -e "${YELLOW}└──────────────────────────────────────────────────────────────────${NC}"
        echo ""
    fi
fi

# Enhanced completion message
echo -e "${CYAN}┌──────────────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│${NC} ${BOLD}${WHITE}LinWatch session completed successfully!${NC}"
echo -e "${CYAN}│${NC}"
echo -e "${CYAN}│${NC} ${GRAY}Thank you for using LinWatch - your cozy system companion${NC}"
echo -e "${CYAN}│${NC} ${GRAY}Stay safe, keep updated, and have a great day!${NC}"
echo -e "${CYAN}│${NC}"
echo -e "${CYAN}│${NC} ${GREEN}✓ System monitored${NC}"
echo -e "${CYAN}│${NC} ${GREEN}✓ Updates checked${NC}"
echo -e "${CYAN}│${NC} ${GREEN}✓ Security audited${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────────────────────────${NC}"
echo ""
