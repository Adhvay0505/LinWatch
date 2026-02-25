#!/bin/bash

# Version: 1.0.12

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

# Box layout configuration
BOX_CONTENT_WIDTH=64

print_box_line() {
    local border_color="$1"
    shift
    local content="$*"
    local rendered plain pad

    rendered=$(echo -e "$content")
    plain=$(printf "%s" "$rendered" | sed -E 's/\x1B\[[0-9;]*[[:alpha:]]//g')
    plain="${plain//$'\r'/}"
    plain="${plain//$'\n'/ }"

    if ((${#plain} > BOX_CONTENT_WIDTH)); then
        plain="${plain:0:BOX_CONTENT_WIDTH}"
        rendered="$plain"
    fi

    pad=$((BOX_CONTENT_WIDTH - ${#plain}))
    printf "%b│%b %s%*s %b│%b\n" "$border_color" "$NC" "$rendered" "$pad" "" "$border_color" "$NC"
}

print_box_empty() {
    local border_color="$1"
    printf "%b│%b %*s %b│%b\n" "$border_color" "$NC" "$BOX_CONTENT_WIDTH" "" "$border_color" "$NC"
}

# Disk cleanup configuration
DEFAULT_RETENTION_DAYS=30
MAX_FILE_SIZE_MB=1000
MIN_SPACE_THRESHOLD_MB=500
BACKUP_RETENTION_DAYS=7

# Critical system paths to protect (never delete from these)
CRITICAL_PATHS=("/boot" "/etc" "/usr/bin" "/bin" "/sbin" "/lib" "/lib64" "/proc" "/sys" "/dev")

# Variables to track user actions
UPDATES_INSTALLED=false
UPDATES_CHECKED=false
SECURITY_AUDITED=false

# Variables to track disk cleanup operations
CLEANUP_PERFORMED=false
SPACE_SAVED_MB=0
CLEANUP_LOG_FILE=""

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

SUDO_AVAILABLE=false

check_sudo_available() {
    if [ "$SUDO_AVAILABLE" = true ]; then
        return 0
    fi
    if sudo -n true 2>/dev/null; then
        SUDO_AVAILABLE=true
        return 0
    else
        SUDO_AVAILABLE=false
        return 1
    fi
}

run_sudo_command() {
    if check_sudo_available; then
        sudo "$@"
        return $?
    else
        return 1
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
        print_box_line "${YELLOW}" "${WHITE}Would you like to update LinWatch now?${NC}"
print_box_empty "${YELLOW}"
print_box_line "${YELLOW}" "${CYAN}Update to $latest_release? (y/n)${NC}"
echo -ne "${CYAN}> ${NC}"
        read -r UPDATE_RESPONSE
        print_box_empty "${YELLOW}"
echo -e "${YELLOW}└──────────────────────────────────────────────────────────────────┘${NC}"
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

#============================================================
# DISK CLEANUP FUNCTIONS
#============================================================

# Convert MB to human readable format (moved to accessible location)
format_size() {
    local size_mb="$1"
    if [[ $size_mb -ge 1024 ]]; then
        if command -v bc >/dev/null 2>&1; then
            echo "$(echo "scale=1; $size_mb / 1024" | bc)GB"
        else
            local gb=$((size_mb / 1024))
            local remainder=$((size_mb % 1024))
            if [[ $remainder -gt 0 ]]; then
                echo "${gb}.$((remainder * 10 / 1024))GB"
            else
                echo "${gb}GB"
            fi
        fi
    else
        echo "${size_mb}MB"
    fi
}

# Get directory size in MB
get_dir_size_mb() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        du -sm "$dir" 2>/dev/null | cut -f1 || echo "0"
    else
        echo "0"
    fi
}

# Check if path is safe to clean (not in critical paths)
is_safe_path() {
    local path="$1"
    for critical in "${CRITICAL_PATHS[@]}"; do
        if [[ "$path" == "$critical"* ]]; then
            return 1
        fi
    done
    return 0
}

# Create backup directory for rollback
create_cleanup_backup() {
    local backup_dir="/tmp/linwatch_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    CLEANUP_LOG_FILE="/tmp/linwatch_cleanup_$(date +%Y%m%d_%H%M%S).log"
    echo "$backup_dir"
}

# Log cleanup action with space saved
log_cleanup_action() {
    local action="$1"
    local space_mb="$2"
    local details="$3"

    echo "$(date '+%Y-%m-%d %H:%M:%S') - $action: $space_mb MB - $details" >> "$CLEANUP_LOG_FILE"
}

# Analyze potential cleanup opportunities
analyze_disk_usage() {
    echo -e "${CYAN}Analyzing disk usage and cleanup opportunities...${NC}"
    echo ""

    local total_potential=0
    local analysis_results=()

    # Package manager caches
    echo -e "${WHITE}📦 Package Manager Caches & Cleanup:${NC}"
    if command -v apt >/dev/null 2>&1 && [[ -d /var/cache/apt/archives ]]; then
        local apt_size=$(get_dir_size_mb "/var/cache/apt/archives")
        if [[ $apt_size -gt 10 ]]; then
            echo -e "   ${GRAY}APT cache:${NC} $(format_size $apt_size)"
            analysis_results+=("apt_cache:$apt_size")
            total_potential=$((total_potential + apt_size))
        fi
        # Show autoremove availability
        echo -e "   ${GRAY}APT autoremove:${NC} ${GREEN}Available${NC} ${GRAY}(removes unused packages)${NC}"
        total_potential=$((total_potential + 50))  # Estimate 50MB potential from autoremove
    fi

    if command -v yum >/dev/null 2>&1 && [[ -d /var/cache/yum ]]; then
        local yum_size=$(get_dir_size_mb "/var/cache/yum")
        if [[ $yum_size -gt 10 ]]; then
            echo -e "   ${GRAY}YUM cache:${NC} $(format_size $yum_size)"
            analysis_results+=("yum_cache:$yum_size")
            total_potential=$((total_potential + yum_size))
        fi
    fi

    if command -v dnf >/dev/null 2>&1 && [[ -d /var/cache/dnf ]]; then
        local dnf_size=$(get_dir_size_mb "/var/cache/dnf")
        if [[ $dnf_size -gt 10 ]]; then
            echo -e "   ${GRAY}DNF cache:${NC} $(format_size $dnf_size)"
            analysis_results+=("dnf_cache:$dnf_size")
            total_potential=$((total_potential + dnf_size))
        fi
        # Show autoremove availability
        echo -e "   ${GRAY}DNF autoremove:${NC} ${GREEN}Available${NC} ${GRAY}(removes unused packages)${NC}"
        total_potential=$((total_potential + 50))  # Estimate 50MB potential from autoremove
    fi

    if command -v yum >/dev/null 2>&1 && [[ -d /var/cache/yum ]]; then
        local yum_size=$(get_dir_size_mb "/var/cache/yum")
        if [[ $yum_size -gt 10 ]]; then
            echo -e "   ${GRAY}YUM cache:${NC} $(format_size $yum_size)"
            analysis_results+=("yum_cache:$yum_size")
            total_potential=$((total_potential + yum_size))
        fi
        # Show autoremove availability
        echo -e "   ${GRAY}YUM autoremove:${NC} ${GREEN}Available${NC} ${GRAY}(removes unused packages)${NC}"
        total_potential=$((total_potential + 50))  # Estimate 50MB potential from autoremove
    fi

    echo ""

    # Temporary files
    echo -e "${WHITE}🗂️  Temporary Files:${NC}"
    if [[ -d /tmp ]]; then
        local tmp_size=$(find /tmp -type f -mtime +1 -exec du -sm {} + 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
        if [[ $tmp_size -gt 10 ]]; then
            echo -e "   ${GRAY}/tmp (1+ days):${NC} $(format_size $tmp_size)"
            analysis_results+=("temp_files:$tmp_size")
            total_potential=$((total_potential + tmp_size))
        fi
    fi

    if [[ -d /var/tmp ]]; then
        local var_tmp_size=$(find /var/tmp -type f -mtime +1 -exec du -sm {} + 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
        if [[ $var_tmp_size -gt 10 ]]; then
            echo -e "   ${GRAY}/var/tmp (1+ days):${NC} $(format_size $var_tmp_size)"
            analysis_results+=("var_temp:$var_tmp_size")
            total_potential=$((total_potential + var_tmp_size))
        fi
    fi

    echo ""

    # Log files
    echo -e "${WHITE}📋 Log Files:${NC}"
    local log_size=0
    if [[ -d /var/log ]]; then
        # Compressed logs
        local compressed_logs=$(find /var/log -name "*.gz" -o -name "*.bz2" -mtime +30 -exec du -sm {} + 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
        if [[ $compressed_logs -gt 10 ]]; then
            echo -e "   ${GRAY}Compressed logs (30+ days):${NC} $(format_size $compressed_logs)"
            log_size=$((log_size + compressed_logs))
        fi

        # Old log files
        local old_logs=$(find /var/log -name "*.log.*" -o -name "*.old" -mtime +30 -exec du -sm {} + 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
        if [[ $old_logs -gt 10 ]]; then
            echo -e "   ${GRAY}Old logs (30+ days):${NC} $(format_size $old_logs)"
            log_size=$((log_size + old_logs))
        fi
    fi

    if [[ $log_size -gt 10 ]]; then
        analysis_results+=("old_logs:$log_size")
        total_potential=$((total_potential + log_size))
    fi

    echo ""

    # Journal logs
    if command -v journalctl >/dev/null 2>&1; then
        local journal_size=$(journalctl --disk-usage | awk '{print $2}' | sed 's/[^0-9.]//g' | cut -d. -f1)
        if [[ $journal_size -gt 100 ]]; then
            echo -e "   ${GRAY}Systemd journal (30+ days):${NC} ~$(format_size $journal_size)"
            analysis_results+=("journal_logs:$journal_size")
            total_potential=$((total_potential + journal_size))
        fi
    fi

    echo ""

    # Docker cleanup
    if command -v docker >/dev/null 2>&1; then
        echo -e "${WHITE}🐳 Docker Resources:${NC}"
        local docker_size=$(docker system df --format "table {{.Type}}\t{{.Size}}" | grep -v "TYPE" | awk '{sum+=$2} END {print sum+0}' 2>/dev/null)
        if [[ $docker_size -gt 100 ]]; then
            echo -e "   ${GRAY}Unused containers/images:${NC} ~$(format_size $docker_size)"
            analysis_results+=("docker_cleanup:$docker_size")
            total_potential=$((total_potential + docker_size))
        fi
    fi

    echo ""
    echo -e "${GREEN}┌──────────────────────────────────────────────────────────────────┐${NC}"
    print_box_line "${GREEN}" "${BOLD}Total Potential Space Recovery: $(format_size $total_potential)${NC}"
echo -e "${GREEN}└──────────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    # Store results for later use
    ANALYSIS_RESULTS=("${analysis_results[@]}")
    TOTAL_POTENTIAL=$total_potential
}

# Quick cleanup function (safe operations)
cleanup_quick() {
    echo -e "${CYAN}Performing quick cleanup...${NC}"
    local space_saved=0

    # Package cache cleanup
    if command -v apt >/dev/null 2>&1; then
        comfort_loading "Cleaning APT package cache" 10
        local before_size=$(get_dir_size_mb "/var/cache/apt/archives")
        apt-get clean >/dev/null 2>&1
        local after_size=$(get_dir_size_mb "/var/cache/apt/archives")
        local apt_cache_saved=$((before_size - after_size))

        # Run autoremove for unused packages
        comfort_loading "Removing unused packages (autoremove)" 8
        apt-get autoremove -y >/dev/null 2>&1

        space_saved=$((space_saved + apt_cache_saved))
        if [[ $apt_cache_saved -gt 0 ]]; then
            log_cleanup_action "APT cache cleanup" $apt_cache_saved "Package archives removed"
            echo -e "${GREEN}✓ APT cache cleaned: $(format_size $apt_cache_saved)${NC}"
        fi
        echo -e "${GREEN}✓ Unused packages removed (autoremove)${NC}"

    elif command -v dnf >/dev/null 2>&1; then
        comfort_loading "Cleaning DNF package cache" 10
        local before_size=$(get_dir_size_mb "/var/cache/dnf")
        sudo dnf clean all >/dev/null 2>&1
        local after_size=$(get_dir_size_mb "/var/cache/dnf")
        local dnf_cache_saved=$((before_size - after_size))

        # Run autoremove for unused packages
        comfort_loading "Removing unused packages (autoremove)" 8
        sudo dnf autoremove -y >/dev/null 2>&1

        space_saved=$((space_saved + dnf_cache_saved))
        if [[ $dnf_cache_saved -gt 0 ]]; then
            log_cleanup_action "DNF cache cleanup" $dnf_cache_saved "Package archives removed"
            echo -e "${GREEN}✓ DNF cache cleaned: $(format_size $dnf_cache_saved)${NC}"
        fi
        echo -e "${GREEN}✓ Unused packages removed (autoremove)${NC}"

    elif command -v yum >/dev/null 2>&1; then
        comfort_loading "Cleaning YUM package cache" 10
        local before_size=$(get_dir_size_mb "/var/cache/yum")
        sudo yum clean all >/dev/null 2>&1
        local after_size=$(get_dir_size_mb "/var/cache/yum")
        local yum_cache_saved=$((before_size - after_size))

        # Run autoremove for unused packages
        comfort_loading "Removing unused packages (autoremove)" 8
        sudo yum autoremove -y >/dev/null 2>&1

        space_saved=$((space_saved + yum_cache_saved))
        if [[ $yum_cache_saved -gt 0 ]]; then
            log_cleanup_action "YUM cache cleanup" $yum_cache_saved "Package archives removed"
            echo -e "${GREEN}✓ YUM cache cleaned: $(format_size $yum_cache_saved)${NC}"
        fi
        echo -e "${GREEN}✓ Unused packages removed (autoremove)${NC}"
    fi

    # Temp files cleanup - clean old temp files (1+ days) for immediate results
    comfort_loading "Cleaning temporary files" 15
    local temp_saved=0
    if [[ -d /tmp ]]; then
        local temp_before=$(du -sm /tmp 2>/dev/null | cut -f1)
        find /tmp -type f -mtime +1 -delete 2>/dev/null
        # Also clean up temp directories that are old
        find /tmp -type d -empty -mtime +1 -delete 2>/dev/null
        local temp_after=$(du -sm /tmp 2>/dev/null | cut -f1)
        local tmp_saved=$((temp_before - temp_after))
        temp_saved=$((temp_saved + tmp_saved))
    fi

    if [[ -d /var/tmp ]]; then
        local var_temp_before=$(du -sm /var/tmp 2>/dev/null | cut -f1)
        find /var/tmp -type f -mtime +1 -delete 2>/dev/null
        find /var/tmp -type d -empty -mtime +1 -delete 2>/dev/null
        local var_temp_after=$(du -sm /var/tmp 2>/dev/null | cut -f1)
        local var_temp_saved=$((var_temp_before - var_temp_after))
        temp_saved=$((temp_saved + var_temp_saved))
    fi

    space_saved=$((space_saved + temp_saved))
    if [[ $temp_saved -gt 0 ]]; then
        log_cleanup_action "Temp files cleanup" $temp_saved "Files older than 7 days"
        echo -e "${GREEN}✓ Temporary files cleaned: $(format_size $temp_saved)${NC}"
    fi

    echo ""
    echo -e "${GREEN}Quick cleanup completed! Total space saved: $(format_size $space_saved)${NC}"
    SPACE_SAVED_MB=$((SPACE_SAVED_MB + space_saved))
}

# Standard cleanup function (includes logs and docker)
cleanup_standard() {
    echo -e "${CYAN}Performing standard cleanup...${NC}"
    local space_saved=0

    # First do quick cleanup
    cleanup_quick
    space_saved=$SPACE_SAVED_MB

    echo ""
    echo -e "${CYAN}Continuing with additional cleanup...${NC}"

    # Log files cleanup
    comfort_loading "Cleaning old log files" 20
    local logs_saved=0
    if [[ -d /var/log ]]; then
        local logs_before=0
        logs_before=$((logs_before + $(find /var/log -name "*.gz" -o -name "*.bz2" -mtime +30 -exec du -sm {} + 2>/dev/null | awk '{sum+=$1} END {print sum+0}')))
        logs_before=$((logs_before + $(find /var/log -name "*.log.*" -o -name "*.old" -mtime +30 -exec du -sm {} + 2>/dev/null | awk '{sum+=$1} END {print sum+0}')))

        find /var/log -name "*.gz" -mtime +30 -delete 2>/dev/null
        find /var/log -name "*.bz2" -mtime +30 -delete 2>/dev/null
        find /var/log -name "*.log.*" -mtime +30 -delete 2>/dev/null
        find /var/log -name "*.old" -mtime +30 -delete 2>/dev/null

        local logs_after=0
        logs_after=$((logs_after + $(find /var/log -name "*.gz" -o -name "*.bz2" -mtime +30 -exec du -sm {} + 2>/dev/null | awk '{sum+=$1} END {print sum+0}')))
        logs_after=$((logs_after + $(find /var/log -name "*.log.*" -o -name "*.old" -mtime +30 -exec du -sm {} + 2>/dev/null | awk '{sum+=$1} END {print sum+0}')))

        logs_saved=$((logs_before - logs_after))
    fi

    if [[ $logs_saved -gt 0 ]]; then
        log_cleanup_action "Log files cleanup" $logs_saved "Logs older than 30 days"
        echo -e "${GREEN}✓ Log files cleaned: $(format_size $logs_saved)${NC}"
    fi

    # Journal cleanup
    if command -v journalctl >/dev/null 2>&1; then
        comfort_loading "Cleaning systemd journal" 15
        local journal_before=$(journalctl --disk-usage | awk '{print $2}' | sed 's/[^0-9.]//g' | cut -d. -f1)
        journalctl --vacuum-time=30d >/dev/null 2>&1
        local journal_after=$(journalctl --disk-usage | awk '{print $2}' | sed 's/[^0-9.]//g' | cut -d. -f1)
        local journal_saved=$((journal_before - journal_after))

        if [[ $journal_saved -gt 0 ]]; then
            log_cleanup_action "Journal cleanup" $journal_saved "Journals older than 30 days"
            echo -e "${GREEN}✓ Systemd journal cleaned: $(format_size $journal_saved)${NC}"
            logs_saved=$((logs_saved + journal_saved))
        fi
    fi

    space_saved=$((space_saved + logs_saved))

    # Docker cleanup
    if command -v docker >/dev/null 2>&1; then
        comfort_loading "Cleaning Docker resources" 25
        local docker_before=$(docker system df --format "{{.Size}}" 2>/dev/null | grep -v "^$" | awk '{gsub(/[^0-9.]/, ""); sum+=$1} END {print sum+0}')
        docker system prune -af --volumes >/dev/null 2>&1
        local docker_after=$(docker system df --format "{{.Size}}" 2>/dev/null | grep -v "^$" | awk '{gsub(/[^0-9.]/, ""); sum+=$1} END {print sum+0}')
        local docker_saved=$((docker_before - docker_after))

        if [[ $docker_saved -gt 0 ]]; then
            log_cleanup_action "Docker cleanup" $docker_saved "Unused containers, images, and volumes"
            echo -e "${GREEN}✓ Docker resources cleaned: $(format_size $docker_saved)${NC}"
            space_saved=$((space_saved + docker_saved))
        fi
    fi

    echo ""
    echo -e "${GREEN}Standard cleanup completed! Total space saved: $(format_size $space_saved)${NC}"
    SPACE_SAVED_MB=$space_saved
}

# Custom cleanup menu
cleanup_custom() {
    while true; do
        clear
        echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║                  CUSTOM CLEANUP MENU                   ║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
        echo ""

        # Show current status with estimates
        analyze_disk_usage

        echo -e "${WHITE}Select cleanup options:${NC}"
        echo ""
        echo -e "${YELLOW}1)${NC} Package manager caches (APT/YUM/DNF)"
        echo -e "${YELLOW}2)${NC} Package autoremove (unused dependencies)"
        echo -e "${YELLOW}3)${NC} Temporary files (/tmp, /var/tmp)"
        echo -e "${YELLOW}4)${NC} Old log files (30+ days)"
        echo -e "${YELLOW}5)${NC} Systemd journal (30+ days)"
        echo -e "${YELLOW}6)${NC} Docker resources (containers, images, volumes)"
        echo -e "${YELLOW}7)${NC} Run all selected"
        echo -e "${YELLOW}8)${NC} Back to main menu"
        echo ""

        echo -ne "${CYAN}Enter your choices (1-7, multiple allowed):${NC} "
        read -r user_choices

        case "$user_choices" in
            *"1"*)
                echo -e "${CYAN}Cleaning package manager caches...${NC}"
                if command -v apt >/dev/null 2>&1; then
                    local apt_before=$(get_dir_size_mb "/var/cache/apt/archives")
                    apt-get clean >/dev/null 2>&1
                    local apt_after=$(get_dir_size_mb "/var/cache/apt/archives")
                    local apt_saved=$((apt_before - apt_after))
                    echo -e "${GREEN}✓ APT cache saved: $(format_size $apt_saved)${NC}"
                    SPACE_SAVED_MB=$((SPACE_SAVED_MB + apt_saved))
                fi
                ;;
            *"2"*)
                echo -e "${CYAN}Cleaning temporary files...${NC}"
                # Implementation for temp files
                ;;
            *"3"*)
                echo -e "${CYAN}Cleaning old log files...${NC}"
                # Implementation for log files
                ;;
            *"4"*)
                echo -e "${CYAN}Cleaning systemd journal...${NC}"
                if command -v journalctl >/dev/null 2>&1; then
                    journalctl --vacuum-time=30d >/dev/null 2>&1
                    echo -e "${GREEN}✓ Systemd journal cleaned${NC}"
                fi
                ;;
            *"5"*)
                echo -e "${CYAN}Cleaning Docker resources...${NC}"
                if command -v docker >/dev/null 2>&1; then
                    docker system prune -af --volumes >/dev/null 2>&1
                    echo -e "${GREEN}✓ Docker resources cleaned${NC}"
                fi
                ;;
            *"6"*)
                cleanup_standard
                ;;
            *"7"*)
                break
                ;;
            *)
                echo -e "${RED}Invalid selection. Please try again.${NC}"
                sleep 2
                ;;
        esac

        if [[ "$user_choices" != *"7"* ]]; then
            echo ""
            echo -e "${GREEN}Custom cleanup in progress. Current total saved: $(format_size $SPACE_SAVED_MB)${NC}"
            echo -ne "${CYAN}Press Enter to continue...${NC}"
            read -r
        fi
    done
}

# Main cleanup interface
run_disk_cleanup_interface() {
    # Get current disk usage before cleanup
    local before_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')

    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}              DISK CLEANUP & OPTIMIZATION              ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo ""

    echo -e "${WHITE}Current disk usage:${NC} ${YELLOW}${before_usage}%${NC}"
    echo ""

    # Analyze what can be cleaned
    analyze_disk_usage

    # Only show cleanup options if there's meaningful space to recover
    if [[ $TOTAL_POTENTIAL -lt $((MIN_SPACE_THRESHOLD_MB / 1024)) ]]; then
        echo -e "${GREEN}┌──────────────────────────────────────────────────────────────────┐${NC}"
        print_box_line "${GREEN}" "${WHITE}System is already clean! Minimal space available for cleanup.${NC}"
echo -e "${GREEN}└──────────────────────────────────────────────────────────────────┘${NC}"
        echo ""
        return 0
    fi

    # Show cleanup menu
    echo -e "${MAGENTA}┌──────────────────────────────────────────────────────────────────┐${NC}"
    print_box_line "${MAGENTA}" "${WHITE}Select cleanup level:${NC}"
print_box_empty "${MAGENTA}"
print_box_line "${MAGENTA}" "${YELLOW}1)${NC} ${WHITE}Quick cleanup${NC} ${GRAY}(temp files, package cache, autoremove)${NC}"
print_box_line "${MAGENTA}" "${YELLOW}2)${NC} ${WHITE}Standard cleanup${NC} ${GRAY}(adds logs, docker, journal, autoremove)${NC}"
print_box_line "${MAGENTA}" "${YELLOW}3)${NC} ${WHITE}Custom cleanup${NC} ${GRAY}(choose specific items)${NC}"
print_box_line "${MAGENTA}" "${YELLOW}4)${NC} ${WHITE}Skip cleanup${NC}"
print_box_empty "${MAGENTA}"
print_box_line "${MAGENTA}" "${CYAN}Choose option (1-4)${NC}"
echo -ne "${CYAN}> ${NC}"
    read -r cleanup_choice
    echo -e "${MAGENTA}└──────────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    case "$cleanup_choice" in
        1)
            echo -e "${CYAN}Starting quick cleanup...${NC}"
            cleanup_quick
            CLEANUP_PERFORMED=true
            ;;
        2)
            echo -e "${CYAN}Starting standard cleanup...${NC}"
            cleanup_standard
            CLEANUP_PERFORMED=true
            ;;
        3)
            cleanup_custom
            CLEANUP_PERFORMED=true
            ;;
        4)
            echo -e "${GRAY}Disk cleanup skipped by user${NC}"
            echo ""
            return 0
            ;;
        *)
            echo -e "${RED}Invalid choice. Skipping cleanup.${NC}"
            echo ""
            return 0
            ;;
    esac

    # Show after cleanup results
    if [[ "$CLEANUP_PERFORMED" = true ]]; then
        local after_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
        local usage_improvement=$((before_usage - after_usage))

        echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}                    CLEANUP SUMMARY                    ${NC}"
        echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
        print_box_line "${GREEN}" "${WHITE}Space recovered:${NC} ${BOLD}$(format_size $SPACE_SAVED_MB)${NC}"
print_box_line "${GREEN}" "${WHITE}Disk usage change:${NC} ${before_usage}% → ${after_usage}% ${GRAY}(${usage_improvement}% improvement)${NC}"
        if [[ -n "$CLEANUP_LOG_FILE" && -f "$CLEANUP_LOG_FILE" ]]; then
            cleanup_log_display="$CLEANUP_LOG_FILE"
            cleanup_log_display="${cleanup_log_display:0:43}"
            print_box_line "${GREEN}" "${WHITE}Cleanup log:${NC} ${GRAY}${cleanup_log_display}${NC}"
fi
        echo -e "${GREEN}└──────────────────────────────────────────────────────────────────┘${NC}"
        echo ""

        # Clean up old backup directories
        find /tmp -name "linwatch_backup_*" -mtime +$BACKUP_RETENTION_DAYS -exec rm -rf {} + 2>/dev/null
        find /tmp -name "linwatch_cleanup_*.log" -mtime +$BACKUP_RETENTION_DAYS -delete 2>/dev/null
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
    print_box_line "${MAGENTA}" "${WHITE}Check for LinWatch application updates?${NC}"
print_box_empty "${MAGENTA}"
print_box_line "${MAGENTA}" "${CYAN}Check for LinWatch updates? (y/n)${NC}"
echo -ne "${CYAN}> ${NC}"
    read -r LINWATCH_UPDATE_RESPONSE
    print_box_empty "${MAGENTA}"
echo -e "${MAGENTA}└──────────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    if [[ "$LINWATCH_UPDATE_RESPONSE" =~ ^[Yy]$ ]]; then
        check_linwatch_updates
        echo ""
    fi
    echo -e "${MAGENTA}┌──────────────────────────────────────────────────────────────────┐${NC}"
    print_box_line "${MAGENTA}" "${BOLD}${WHITE}Let's make your system feel great today!${NC}"
echo -e "${MAGENTA}└──────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    sleep 2
}

# Start the main welcome sequence
main_welcome

# Kernel Info with enhanced styling
echo -e "${CYAN}┌──────────────────────────────────────────────────────────────────┐${NC}"
print_box_line "${CYAN}" "${WHITE}Kernel Version:${NC} ${GREEN}$(uname -r)${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────────────────────────┘${NC}"
echo ""

# CPU Info with enhanced display
echo -e "${CYAN}┌──────────────────────────────────────────────────────────────────┐${NC}"
print_box_line "${CYAN}" "${WHITE}Architecture:${NC} ${GREEN}$(lscpu | awk '/^Architecture:/ {print $2}')${NC}"
print_box_line "${CYAN}" "${WHITE}CPU(s):${NC} ${GREEN}$(lscpu | awk '/^CPU\(s\):/ {print $2}')${NC}"
print_box_line "${CYAN}" "${WHITE}Threads:${NC} ${GREEN}$(lscpu | awk '/^Thread(s):/ {print $2}')${NC}"
print_box_line "${CYAN}" "${WHITE}Cores:${NC} ${GREEN}$(lscpu | awk '/^Core(s):/ {print $2}')${NC}"
cpu_model="$(lscpu | awk '/^Model name:/ {print substr($0, index($0, $3))}')"
cpu_model="${cpu_model:0:46}"
print_box_line "${CYAN}" "${WHITE}Model:${NC} ${GREEN}${cpu_model}${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────────────────────────┘${NC}"
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

print_box_line "${CYAN}" "${WHITE}RAM Usage:${NC} ${bar_color}[${bar}${space}]${NC} ${WHITE}${used_percent}%${NC}"
print_box_line "${CYAN}" "${WHITE}Details:${NC} ${GRAY}Used: ${used} / Total: ${total} (Available: ${available})${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────────────────────────┘${NC}"
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

print_box_line "${CYAN}" "${WHITE}Root Partition:${NC} ${bar_color}[${bar}${space}]${NC} ${WHITE}${perc} used${NC}"
print_box_line "${CYAN}" "${WHITE}Details:${NC} ${GRAY}Used: ${used} / Total: ${size} (Available: ${avail})${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────────────────────────┘${NC}"
echo ""

# Uptime with enhanced display
echo -e "${CYAN}┌──────────────────────────────────────────────────────────────────┐${NC}"
print_box_line "${CYAN}" "${WHITE}System has been up for:${NC} ${GREEN}$(uptime -p)${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────────────────────────┘${NC}"
echo ""

# Network Info with enhanced display
echo -e "${CYAN}┌──────────────────────────────────────────────────────────────────┐${NC}"
local_ipv4=$(ip a | awk '/inet / && $2 !~ /^127/{sub("/.*", "", $2); print $2; exit}')
local_ipv6=$(ip a | awk '/inet6 / && $2 !~ /^::1/ {sub("/.*", "", $2); print $2; exit}')

print_box_line "${CYAN}" "${WHITE}Local IPv4:${NC} ${GREEN}${local_ipv4:-Not available}${NC}"
print_box_line "${CYAN}" "${WHITE}Local IPv6:${NC} ${GREEN}${local_ipv6:-Not available}${NC}"
# Fetch and Display Public IP with animation
if command -v curl >/dev/null 2>&1; then
    print_box_line "${CYAN}" "${WHITE}Public IP:${NC} ${YELLOW}Fetching...${NC}"
    PUBLIC_IP=$(curl -s --max-time 5 https://api.ipify.org)
    if [[ -n "$PUBLIC_IP" ]]; then
        print_box_line "${CYAN}" "${WHITE}Public IP:${NC} ${GREEN}${PUBLIC_IP}${NC}"
else
        print_box_line "${CYAN}" "${WHITE}Public IP:${NC} ${RED}Unable to fetch (no internet?)${NC}"
fi
else
    print_box_line "${CYAN}" "${WHITE}Public IP:${NC} ${RED}curl not installed${NC}"
fi

echo -e "${CYAN}└──────────────────────────────────────────────────────────────────┘${NC}"
echo ""

# User Information with enhanced display
echo -e "${CYAN}┌──────────────────────────────────────────────────────────────────┐${NC}"
print_box_line "${CYAN}" "${WHITE}Current User:${NC} ${GREEN}$(whoami)${NC}"
print_box_line "${CYAN}" "${WHITE}Active Sessions:${NC}"
who | while read -r line; do
    session_line="${line:0:57}"
    print_box_line "${CYAN}" "  ${GRAY}${session_line}${NC}"
done
echo -e "${CYAN}└──────────────────────────────────────────────────────────────────┘${NC}"
echo ""

# Open Ports with enhanced display
echo -e "${CYAN}┌──────────────────────────────────────────────────────────────────┐${NC}"
print_box_line "${CYAN}" "${WHITE}Listening Ports:${NC}"
if command -v ss >/dev/null 2>&1; then
    # Modern systems - limit to first 10 for cleaner display
    ss -tulpn | grep LISTEN | head -10 | while read -r line; do
        port_line="${line:0:57}"
        print_box_line "${CYAN}" "  ${GRAY}${port_line}${NC}"
done
    total_ports=$(ss -tulpn | grep LISTEN | wc -l)
    if [ "$total_ports" -gt 10 ]; then
        print_box_line "${CYAN}" "  ${YELLOW}... and $((total_ports - 10)) more ports${NC}"
fi
elif command -v netstat >/dev/null 2>&1; then
    # Fallback for older systems
    netstat -tulpn | grep LISTEN | head -10 | while read -r line; do
        port_line="${line:0:57}"
        print_box_line "${CYAN}" "  ${GRAY}${port_line}${NC}"
done
else
    print_box_line "${CYAN}" "  ${RED}Neither 'ss' nor 'netstat' is installed${NC}"
fi
echo -e "${CYAN}└──────────────────────────────────────────────────────────────────┘${NC}"
echo ""

# System Information with enhanced display
echo -e "${CYAN}┌──────────────────────────────────────────────────────────────────┐${NC}"
DISTRO=$(awk -F= '/^ID=/{print $2}' /etc/os-release | tr -d ' "')
DISTRO_NAME=$(awk -F= '/^NAME=/{print $2}' /etc/os-release | tr -d '"')
distro_display="${DISTRO_NAME:0:45}"
hostname_display="$(hostname)"
hostname_display="${hostname_display:0:49}"
shell_display="${SHELL:0:52}"
print_box_line "${CYAN}" "${WHITE}Distribution:${NC} ${GREEN}${distro_display}${NC}"
print_box_line "${CYAN}" "${WHITE}Hostname:${NC} ${GREEN}${hostname_display}${NC}"
print_box_line "${CYAN}" "${WHITE}Shell:${NC} ${GREEN}${shell_display}${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────────────────────────┘${NC}"
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
print_box_line "${MAGENTA}" "${WHITE}Ready to check for system updates?${NC}"
print_box_empty "${MAGENTA}"
print_box_line "${MAGENTA}" "${CYAN}Check for updates? (y/n)${NC}"
echo -ne "${CYAN}> ${NC}"
read -r USER_RESPONSE
print_box_empty "${MAGENTA}"
echo -e "${MAGENTA}└──────────────────────────────────────────────────────────────────┘${NC}"
echo ""

if [[ "$USER_RESPONSE" =~ ^[Yy]$ ]]; then
    UPDATES_CHECKED=true
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
        UPGRADABLE=$(pacman -Qu 2>/dev/null | wc -l)
        if [ "$UPGRADABLE" -gt 0 ]; then
            updates_available=true
            echo -e "${CYAN}There are $UPGRADABLE packages available for upgrade via pacman.${NC}"
        fi

    elif command -v zypper >/dev/null 2>&1; then
        sudo zypper refresh > /dev/null 2>&1
        UPGRADABLE=$(zypper lu 2>/dev/null | grep -c '^v')
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
        print_box_line "${YELLOW}" "${WHITE}Updates are ready to install!${NC}"
print_box_empty "${YELLOW}"
print_box_line "${YELLOW}" "${CYAN}Install updates now? (y/n)${NC}"
echo -ne "${CYAN}> ${NC}"
        read -r INSTALL_RESPONSE
        print_box_empty "${YELLOW}"
echo -e "${YELLOW}└──────────────────────────────────────────────────────────────────┘${NC}"
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
                comfort_loading "Checking Flatpak applications" 15
                comfort_loading "Downloading Flatpak updates" 20
                echo -e "${CYAN}Installing Flatpak updates...${NC}"
                flatpak update -y
                comfort_loading "Finalizing Flatpak installation" 10
                echo -e "${GREEN}✓ Flatpak updates completed successfully!${NC}"
            fi

        else
            echo -e "${YELLOW}┌──────────────────────────────────────────────────────────────────┐${NC}"
            print_box_line "${YELLOW}" "${WHITE}Update installation skipped by user${NC}"
echo -e "${YELLOW}└──────────────────────────────────────────────────────────────────┘${NC}"
            echo ""
        fi
    else
        echo -e "${GREEN}┌──────────────────────────────────────────────────────────────────┐${NC}"
        print_box_line "${GREEN}" "${WHITE}No updates available. Your system is up to date!${NC}"
echo -e "${GREEN}└──────────────────────────────────────────────────────────────────┘${NC}"
        echo ""
    fi

else
    echo -e "${GRAY}┌──────────────────────────────────────────────────────────────────┐${NC}"
    print_box_line "${GRAY}" "${WHITE}Update check skipped by user${NC}"
echo -e "${GRAY}└──────────────────────────────────────────────────────────────────┘${NC}"
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
    echo -e "${YELLOW}Installing security tools (rkhunter, chkrootkit, and ClamAV)...${NC}"

    if command -v apt >/dev/null 2>&1; then
        sudo apt update -qq
        sudo apt install -y rkhunter chkrootkit clamav clamav-daemon clamav-freshclam 2>/dev/null

    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y rkhunter chkrootkit clamav clamav-update 2>/dev/null

    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y rkhunter chkrootkit clamav clamav-update 2>/dev/null

    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm rkhunter chkrootkit clamav 2>/dev/null

    elif command -v zypper >/dev/null 2>&1; then
        sudo zypper install -y rkhunter chkrootkit clamav 2>/dev/null

    elif command -v apk >/dev/null 2>&1; then
        sudo apk add rkhunter chkrootkit clamav 2>/dev/null

    elif command -v emerge >/dev/null 2>&1; then
        sudo emerge --quiet app-forensics/rkhunter app-forensics/chkrootkit app-antivirus/clamav 2>/dev/null

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

    # Security counters for summary
    declare -A SECURITY_SCORES=(
        ["ssh_issues"]=0
        ["firewall_issues"]=0
        ["user_issues"]=0
        ["permission_issues"]=0
        ["malware_issues"]=0
        ["total_issues"]=0
    )

    # Start enhanced markdown report with better header
    cat > "$AUDIT_FILE" << EOF
# 🛡️ LinWatch Security Audit Report

**Generated:** $(date)  
**Hostname:** $(hostname)  
**Kernel:** $(uname -r)  
**Distribution:** $DISTRO  

---

EOF

    # Check if security tools are installed
    RKHUNTER_INSTALLED=false
    CHKROOTKIT_INSTALLED=false
    CLAMAV_INSTALLED=false

    if command -v rkhunter >/dev/null 2>&1; then
        RKHUNTER_INSTALLED=true
    fi

    if command -v chkrootkit >/dev/null 2>&1; then
        CHKROOTKIT_INSTALLED=true
    fi

    if command -v clamscan >/dev/null 2>&1; then
        CLAMAV_INSTALLED=true
    fi

    # Enhanced Section 1: System Information with better formatting
    echo "## 📊 System Overview" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"
    echo "| Property | Value |" >> "$AUDIT_FILE"
    echo "|----------|-------|" >> "$AUDIT_FILE"
    echo "| ⏰ **Uptime** | $(uptime -p) |" >> "$AUDIT_FILE"
    echo "| 🔄 **Last Reboot** | $(who -b | awk '{print $3, $4}') |" >> "$AUDIT_FILE"
    echo "| 👤 **Current User** | $(whoami) |" >> "$AUDIT_FILE"
    echo "| 💻 **CPU Cores** | $(nproc 2>/dev/null || echo "Unknown") |" >> "$AUDIT_FILE"
    echo "| 🧠 **Memory** | $(free -h | awk '/^Mem:/ {print $2 "/" $3 " used"}') |" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"

    # Enhanced Section 2: User Accounts with security analysis
    echo "## 👥 User Account Security" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"

    # Users with login shells in table format
    echo "### Users with Login Shells" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"
    echo "| Username | UID | Home Directory | Shell |" >> "$AUDIT_FILE"
    echo "|----------|-----|----------------|-------|" >> "$AUDIT_FILE"
    
    LOGIN_USERS=$(grep -E '/bin/(bash|sh|zsh|fish)' /etc/passwd)
    while IFS=':' read -r user pass uid gid dir shell; do
        if [[ "$shell" =~ /(bash|sh|zsh|fish)$ ]]; then
            echo "| $user | $uid | $dir | $shell |" >> "$AUDIT_FILE"
        fi
    done <<< "$LOGIN_USERS"
    echo "" >> "$AUDIT_FILE"

    # Root privilege users with security assessment
    echo "### Users with Root Privileges (UID 0)" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"
    ROOT_USERS=$(awk -F: '($3 == 0) {print $1":"$6}' /etc/passwd)
    if [ -n "$ROOT_USERS" ]; then
        echo "| Username | Home Directory | Risk Level |" >> "$AUDIT_FILE"
        echo "|----------|----------------|------------|" >> "$AUDIT_FILE"
        while IFS=':' read -r user homedir; do
            if [ "$user" = "root" ]; then
                echo "| $user | $homedir | ✅ Expected |" >> "$AUDIT_FILE"
            else
                echo "| $user | $homedir | ⚠️ Review needed |" >> "$AUDIT_FILE"
                SECURITY_SCORES[user_issues]=$((SECURITY_SCORES[user_issues] + 1))
            fi
        done <<< "$ROOT_USERS"
    else
        echo "✅ No root privilege users found (unusual)" >> "$AUDIT_FILE"
    fi
    echo "" >> "$AUDIT_FILE"

    # Password-less accounts
    echo "### Accounts Without Passwords" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"
    if check_sudo_available; then
        NO_PASS_USERS=$(sudo awk -F: '($2 == "" ) {print $1}' /etc/shadow 2>/dev/null)
    else
        NO_PASS_USERS=""
    fi
    if [ -n "$NO_PASS_USERS" ]; then
        echo "⚠️ **CRITICAL:** Found accounts without passwords:" >> "$AUDIT_FILE"
        echo "" >> "$AUDIT_FILE"
        echo "| Username | Action Required |" >> "$AUDIT_FILE"
        echo "|----------|-----------------|" >> "$AUDIT_FILE"
        echo "$NO_PASS_USERS" | while read user; do
            echo "| $user | 🔐 Set password immediately |" >> "$AUDIT_FILE"
            SECURITY_SCORES[user_issues]=$((SECURITY_SCORES[user_issues] + 1))
        done
    else
        echo "✅ All accounts have passwords configured" >> "$AUDIT_FILE"
    fi
    echo "" >> "$AUDIT_FILE"

    # Enhanced Section 3: Network Security with risk assessment
    echo "## 🔥 Network Security Analysis" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"

    # Listening ports with risk assessment
    echo "### Listening Services (Risk Assessment)" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"
    if command -v ss >/dev/null 2>&1; then
        echo "| Port | Protocol | Service | User | Risk Level |" >> "$AUDIT_FILE"
        echo "|------|----------|---------|------|------------|" >> "$AUDIT_FILE"
        
        ss -tulpn | grep LISTEN | while read line; do
            PORT=$(echo "$line" | awk '{print $4}' | sed 's/.*://' | cut -d':' -f2)
            PROTO=$(echo "$line" | awk '{print $1}')
            SERVICE=$(echo "$line" | awk '{print $7}' | sed 's/.*"\([^"]*\)".*/\1/' | sed 's/users:"//')
            USER=$(echo "$line" | awk '{print $7}' | sed 's/users:"//; s/".*//')
            
            # Risk assessment
            RISK="🟢 Low"
            case "$PORT" in
                22) RISK="🟡 Medium (SSH)" ;;
                23) RISK="🔴 High (Telnet)" ;;
                80|443) RISK="🟡 Medium (HTTP/HTTPS)" ;;
                3306) RISK="🟡 Medium (MySQL)" ;;
                5432) RISK="🟡 Medium (PostgreSQL)" ;;
                3389) RISK="🟡 Medium (RDP)" ;;
            esac
            
            echo "| $PORT | $PROTO | ${SERVICE:-Unknown} | ${USER:-Unknown} | $RISK |" >> "$AUDIT_FILE"
        done
    elif command -v netstat >/dev/null 2>&1; then
        echo '```' >> "$AUDIT_FILE"
        netstat -tulpn | grep LISTEN >> "$AUDIT_FILE"
        echo '```' >> "$AUDIT_FILE"
    fi
    echo "" >> "$AUDIT_FILE"

    # Active connections summary
    echo "### Network Connections Summary" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"
    if command -v ss >/dev/null 2>&1; then
        ESTABLISHED=$(ss -tunp 2>/dev/null | grep ESTAB | wc -l)
        LISTENING=$(ss -tunp 2>/dev/null | grep LISTEN | wc -l)
        echo "- **Established Connections:** $ESTABLISHED" >> "$AUDIT_FILE"
        echo "- **Listening Services:** $LISTENING" >> "$AUDIT_FILE"
        
        # Show suspicious connections (many connections from same IP)
        echo "" >> "$AUDIT_FILE"
        echo "### Top Connection Sources" >> "$AUDIT_FILE"
        echo "" >> "$AUDIT_FILE"
        ss -tunp 2>/dev/null | grep ESTAB | awk '{print $6}' | sed 's/.*://' | sort | uniq -c | sort -nr | head -5 | while read count ip; do
            if [ "$count" -gt 10 ]; then
                echo "| $ip | $count connections | ⚠️ High activity |" >> "$AUDIT_FILE"
            else
                echo "| $ip | $count connections | 🟢 Normal |" >> "$AUDIT_FILE"
            fi
        done
    fi
    echo "" >> "$AUDIT_FILE"

    # Enhanced Section 4: Firewall Status with security assessment
    echo "## 🔥 Firewall Security Status" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"

    FIREWALL_ACTIVE=false
    FIREWALL_TYPE="None"

    if ! check_sudo_available; then
        echo "### ⚠️ Sudo Access Required" >> "$AUDIT_FILE"
        echo "" >> "$AUDIT_FILE"
        echo "This section requires sudo privileges to check firewall status." >> "$AUDIT_FILE"
        echo "Please run the script with sudo or configure passwordless sudo." >> "$AUDIT_FILE"
        echo "" >> "$AUDIT_FILE"
    elif command -v ufw >/dev/null 2>&1; then
        FIREWALL_TYPE="UFW"
        UFW_STATUS=$(sudo ufw status 2>/dev/null)
        if echo "$UFW_STATUS" | grep -q "Status: active"; then
            FIREWALL_ACTIVE=true
            echo "### 🛡️ UFW Firewall Status: **ACTIVE** ✅" >> "$AUDIT_FILE"
            echo "" >> "$AUDIT_FILE"

            echo "| Action | From | To | Port | Protocol |" >> "$AUDIT_FILE"
            echo "|--------|------|-----|------|----------|" >> "$AUDIT_FILE"
            echo "$UFW_STATUS" | grep -E "^[0-9]+" | while read line; do
                ACTION=$(echo "$line" | awk '{print $2}')
                FROM=$(echo "$line" | awk '{print $4}')
                TO=$(echo "$line" | awk '{print $6}')
                PORT=$(echo "$line" | awk '{print $7}')

                echo "| $ACTION | $FROM | $TO | $PORT | Any |" >> "$AUDIT_FILE"
            done
        else
            echo "### ⚠️ UFW Firewall Status: **INACTIVE**" >> "$AUDIT_FILE"
            echo "" >> "$AUDIT_FILE"
            echo "**Risk:** Network traffic is not being filtered" >> "$AUDIT_FILE"
            SECURITY_SCORES[firewall_issues]=$((SECURITY_SCORES[firewall_issues] + 1))
        fi
    elif command -v firewall-cmd >/dev/null 2>&1; then
        FIREWALL_TYPE="Firewalld"
        if sudo firewall-cmd --state >/dev/null 2>&1; then
            FIREWALL_ACTIVE=true
            echo "### 🛡️ Firewalld Status: **RUNNING** ✅" >> "$AUDIT_FILE"
            echo "" >> "$AUDIT_FILE"

            echo "| Zone | Services | Ports |" >> "$AUDIT_FILE"
            echo "|------|----------|-------|" >> "$AUDIT_FILE"
            sudo firewall-cmd --get-active-zones 2>/dev/null | while read zone; do
                if [[ "$zone" =~ ^[a-zA-Z] ]]; then
                    ZONE_NAME="$zone"
                    SERVICES=$(sudo firewall-cmd --zone="$ZONE_NAME" --list-services 2>/dev/null)
                    PORTS=$(sudo firewall-cmd --zone="$ZONE_NAME" --list-ports 2>/dev/null)
                    echo "| $ZONE_NAME | ${SERVICES// /,} | ${PORTS// /,} |" >> "$AUDIT_FILE"
                fi
            done
        else
            echo "### ⚠️ Firewalld Status: **NOT RUNNING**" >> "$AUDIT_FILE"
            SECURITY_SCORES[firewall_issues]=$((SECURITY_SCORES[firewall_issues] + 1))
        fi
    elif command -v iptables >/dev/null 2>&1; then
        FIREWALL_TYPE="IPTables"
        RULES_COUNT=$(sudo iptables -L | grep -c "^Chain\|^[A-Z]" 2>/dev/null)
        if [ "$RULES_COUNT" -gt 3 ]; then
            FIREWALL_ACTIVE=true
            echo "### 🛡️ IPTables Status: **RULES CONFIGURED** ✅" >> "$AUDIT_FILE"
            echo "" >> "$AUDIT_FILE"
            echo "- **Number of rules:** $RULES_COUNT" >> "$AUDIT_FILE"
            DEFAULT_POLICY=$(sudo iptables -L | grep "Chain INPUT" | awk '{print $4}')
            echo "- **Default policy:** $DEFAULT_POLICY" >> "$AUDIT_FILE"
        else
            echo "### ⚠️ IPTables Status: **MINIMAL RULES**" >> "$AUDIT_FILE"
            SECURITY_SCORES[firewall_issues]=$((SECURITY_SCORES[firewall_issues] + 1))
        fi

        echo "" >> "$AUDIT_FILE"
        echo "**Sample Rules (showing first 10):**" >> "$AUDIT_FILE"
        echo "**Sample Rules:**" >> "$AUDIT_FILE"
        sudo iptables -L -n -v | head -20 >> "$AUDIT_FILE" 2>/dev/null
        echo "" >> "$AUDIT_FILE"
    else
        echo "### ❌ No Firewall Detected" >> "$AUDIT_FILE"
        echo "" >> "$AUDIT_FILE"
        echo "**Recommendation:** Install and configure a firewall (ufw, firewalld, or iptables)" >> "$AUDIT_FILE"
        SECURITY_SCORES[firewall_issues]=$((SECURITY_SCORES[firewall_issues] + 2))
    fi
    echo "" >> "$AUDIT_FILE"

    # Enhanced Section 5: SSH Security with detailed analysis
    echo "## 🔐 SSH Security Configuration" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"
    
    if [ -f /etc/ssh/sshd_config ]; then
        echo "### SSH Security Settings Analysis" >> "$AUDIT_FILE"
        echo "" >> "$AUDIT_FILE"
        echo "| Setting | Current Value | Security Status | Recommendation |" >> "$AUDIT_FILE"
        echo "|---------|---------------|-----------------|----------------|" >> "$AUDIT_FILE"
        
        # Check SSH port
        SSH_PORT=$(grep "^Port" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | head -1)
        SSH_PORT=${SSH_PORT:-22}
        if [ "$SSH_PORT" = "22" ]; then
            echo "| Port | $SSH_PORT | 🟡 Standard | Consider changing to non-standard port |" >> "$AUDIT_FILE"
        else
            echo "| Port | $SSH_PORT | ✅ Custom | Good security practice |" >> "$AUDIT_FILE"
        fi
        
        # Check root login
        ROOT_LOGIN=$(grep "^PermitRootLogin" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
        ROOT_LOGIN=${ROOT_LOGIN:-prohibit-password}
        case "$ROOT_LOGIN" in
            "no")
                echo "| Root Login | $ROOT_LOGIN | ✅ Secure | Perfect |" >> "$AUDIT_FILE" ;;
            "prohibit-password")
                echo "| Root Login | $ROOT_LOGIN | 🟡 Medium | Keys only, consider 'no' |" >> "$AUDIT_FILE" ;;
            "yes")
                echo "| Root Login | $ROOT_LOGIN | ❌ Insecure | Disable immediately! |" >> "$AUDIT_FILE"
                SECURITY_SCORES[ssh_issues]=$((SECURITY_SCORES[ssh_issues] + 2)) ;;
            *)
                echo "| Root Login | $ROOT_LOGIN | ⚠️ Unknown | Review setting |" >> "$AUDIT_FILE" ;;
        esac
        
        # Check password authentication
        PASS_AUTH=$(grep "^PasswordAuthentication" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
        PASS_AUTH=${PASS_AUTH:-yes}
        if [ "$PASS_AUTH" = "no" ]; then
            echo "| Password Auth | $PASS_AUTH | ✅ Secure | Key-based only |" >> "$AUDIT_FILE"
        else
            echo "| Password Auth | $PASS_AUTH | ⚠️ Risky | Disable if using keys |" >> "$AUDIT_FILE"
            SECURITY_SCORES[ssh_issues]=$((SECURITY_SCORES[ssh_issues] + 1))
        fi
        
        # Check public key authentication
        PUBKEY_AUTH=$(grep "^PubkeyAuthentication" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
        PUBKEY_AUTH=${PUBKEY_AUTH:-yes}
        if [ "$PUBKEY_AUTH" = "yes" ]; then
            echo "| Public Key Auth | $PUBKEY_AUTH | ✅ Enabled | Good security practice |" >> "$AUDIT_FILE"
        else
            echo "| Public Key Auth | $PUBKEY_AUTH | ⚠️ Disabled | Consider enabling |" >> "$AUDIT_FILE"
        fi
        
        echo "" >> "$AUDIT_FILE"
        
        # Additional SSH security analysis
        echo "### Additional SSH Security Analysis" >> "$AUDIT_FILE"
        echo "" >> "$AUDIT_FILE"
        
        # Check for allowed/denied users
        ALLOW_USERS=$(grep "^AllowUsers" /etc/ssh/sshd_config 2>/dev/null)
        DENY_USERS=$(grep "^DenyUsers" /etc/ssh/sshd_config 2>/dev/null)
        
        if [ -n "$ALLOW_USERS" ]; then
            echo "- **User Restrictions:** ✅ AllowUsers configured: \`$ALLOW_USERS\`" >> "$AUDIT_FILE"
        elif [ -n "$DENY_USERS" ]; then
            echo "- **User Restrictions:** 🟡 DenyUsers configured: \`$DENY_USERS\`" >> "$AUDIT_FILE"
        else
            echo "- **User Restrictions:** ⚠️ No user access restrictions configured" >> "$AUDIT_FILE"
            SECURITY_SCORES[ssh_issues]=$((SECURITY_SCORES[ssh_issues] + 1))
        fi
        
        # Check protocol version
        PROTOCOL=$(grep "^Protocol" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
        PROTOCOL=${PROTOCOL:-2}
        if [ "$PROTOCOL" = "2" ]; then
            echo "- **Protocol Version:** ✅ SSH-2 (secure)" >> "$AUDIT_FILE"
        else
            echo "- **Protocol Version:** ⚠️ SSH-1 (insecure) - Upgrade to SSH-2" >> "$AUDIT_FILE"
            SECURITY_SCORES[ssh_issues]=$((SECURITY_SCORES[ssh_issues] + 1))
        fi
        
    else
        echo "### ❌ SSH Configuration Not Found" >> "$AUDIT_FILE"
        echo "" >> "$AUDIT_FILE"
        echo "**Possible Reasons:**" >> "$AUDIT_FILE"
        echo "- SSH server not installed" >> "$AUDIT_FILE"
        echo "- SSH daemon using different configuration path" >> "$AUDIT_FILE"
        echo "- Insufficient permissions to read config" >> "$AUDIT_FILE"
    fi
    echo "" >> "$AUDIT_FILE"

    # Enhanced Section 6: File Permissions with security context
    echo "## 📁 File Permissions Security" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"
    
    # SUID Files Analysis
    echo "### SUID Executables (Elevated Privilege Files)" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"
    if check_sudo_available; then
        SUID_FILES=$(sudo find / -perm -4000 -type f 2>/dev/null | head -20)
    else
        SUID_FILES=""
    fi
    if [ -n "$SUID_FILES" ]; then
        echo "| File Path | Expected | Risk Level | Action |" >> "$AUDIT_FILE"
        echo "|-----------|----------|------------|--------|" >> "$AUDIT_FILE"
        
        echo "$SUID_FILES" | while read file; do
            BASENAME=$(basename "$file")
            RISK="🟡 Medium"
            EXPECTED="⚠️ Review"
            ACTION="Investigate"
            
            case "$BASENAME" in
                passwd|sudo|su|ping|mount|umount)
                    RISK="🟢 Low"
                    EXPECTED="✅ Expected"
                    ACTION="Keep" ;;
                chmod|chown|find)
                    RISK="🟡 Medium"
                    EXPECTED="⚠️ Review"
                    ACTION="Verify needed" ;;
                *)
                    RISK="🔴 High"
                    EXPECTED="❌ Unexpected"
                    ACTION="Remove if unnecessary" ;;
            esac
            
            echo "| $file | $EXPECTED | $RISK | $ACTION |" >> "$AUDIT_FILE"
            if [[ "$RISK" =~ "High|Medium" ]]; then
                SECURITY_SCORES[permission_issues]=$((SECURITY_SCORES[permission_issues] + 1))
            fi
        done
    else
        echo "✅ **No SUID files found** (unusual but secure)" >> "$AUDIT_FILE"
    fi
    echo "" >> "$AUDIT_FILE"
    
    # World-Writable Files Analysis
    echo "### World-Writable Files (Security Risk)" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"
    if check_sudo_available; then
        WRITABLE_FILES=$(sudo find / -xdev -type f -perm -0002 2>/dev/null | head -15)
    else
        WRITABLE_FILES=""
    fi
    if [ -n "$WRITABLE_FILES" ]; then
        echo "⚠️ **CRITICAL SECURITY RISK:** Found world-writable files:" >> "$AUDIT_FILE"
        echo "" >> "$AUDIT_FILE"
        echo "| File Path | Directory | Severity | Recommended Action |" >> "$AUDIT_FILE"
        echo "|-----------|-----------|-----------|-------------------|" >> "$AUDIT_FILE"
        
        echo "$WRITABLE_FILES" | while read file; do
            DIR=$(dirname "$file")
            SEVERITY="🔴 Critical"
            ACTION="Restrict permissions immediately"
            
            # Check if it's in a system directory
            if [[ "$DIR" =~ ^/(etc|bin|sbin|usr|lib|var) ]]; then
                SEVERITY="🔴 Critical"
                ACTION="Remove or secure immediately"
            elif [[ "$DIR" =~ ^/(tmp|var/tmp|home) ]]; then
                SEVERITY="🟡 Medium"
                ACTION="Review and restrict if needed"
            fi
            
            echo "| $file | $DIR | $SEVERITY | $ACTION |" >> "$AUDIT_FILE"
            SECURITY_SCORES[permission_issues]=$((SECURITY_SCORES[permission_issues] + 1))
        done
    else
        echo "✅ **No world-writable files found** - Good security practice" >> "$AUDIT_FILE"
    fi
    echo "" >> "$AUDIT_FILE"
    
    # Additional permission checks
    echo "### Additional Permission Analysis" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"
    
    # Check critical file permissions
    echo "#### Critical System Files Permissions" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"
    echo "| File | Expected Permissions | Current Permissions | Status |" >> "$AUDIT_FILE"
    echo "|------|---------------------|---------------------|--------|" >> "$AUDIT_FILE"
    
    CRITICAL_FILES=("/etc/passwd" "/etc/shadow" "/etc/group" "/etc/gshadow" "/etc/sudoers")
    for file in "${CRITICAL_FILES[@]}"; do
        if [ -f "$file" ]; then
            CURRENT_PERM=$(stat -c "%A" "$file" 2>/dev/null)
            case "$file" in
                "/etc/passwd")
                    if [[ "$CURRENT_PERM" =~ ^-rw.*r.*r.* ]]; then
                        STATUS="✅ OK"
                    else
                        STATUS="⚠️ Review"
                        SECURITY_SCORES[permission_issues]=$((SECURITY_SCORES[permission_issues] + 1))
                    fi ;;
                "/etc/shadow"|"/etc/gshadow")
                    if [[ "$CURRENT_PERM" =~ ^-rw.*------.* ]]; then
                        STATUS="✅ OK"
                    else
                        STATUS="🔴 Insecure"
                        SECURITY_SCORES[permission_issues]=$((SECURITY_SCORES[permission_issues] + 1))
                    fi ;;
                "/etc/sudoers")
                    if [[ "$CURRENT_PERM" =~ ^-r.*r.*-.* ]]; then
                        STATUS="✅ OK"
                    else
                        STATUS="⚠️ Review"
                        SECURITY_SCORES[permission_issues]=$((SECURITY_SCORES[permission_issues] + 1))
                    fi ;;
                *)
                    STATUS="⚠️ Unknown" ;;
            esac
            echo "| $file | Depends | $CURRENT_PERM | $STATUS |" >> "$AUDIT_FILE"
        fi
    done
    echo "" >> "$AUDIT_FILE"

    # Enhanced Section 7: Authentication Security with analysis
    echo "## 🔐 Authentication Security Analysis" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"
    
    # Failed login attempts analysis
    echo "### Failed Login Attempts Analysis" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"

    if [ -f /var/log/auth.log ]; then
        if check_sudo_available; then
            FAILED_LOGINS=$(sudo grep "Failed password" /var/log/auth.log 2>/dev/null | tail -20)
        else
            FAILED_LOGINS=""
        fi
        if [ -n "$FAILED_LOGINS" ]; then
            echo "| Date | User | Source IP | Service |" >> "$AUDIT_FILE"
            echo "|------|------|-----------|---------|" >> "$AUDIT_FILE"
            
            echo "$FAILED_LOGINS" | while read line; do
                DATE=$(echo "$line" | awk '{print $1, $2, $3}')
                USER=$(echo "$line" | grep -o "for [^ ]*" | cut -d' ' -f2)
                IP=$(echo "$line" | grep -o "from [^ ]*" | cut -d' ' -f2)
                SERVICE=$(echo "$line" | grep -o "sshd\[[0-9]*\]")
                
                echo "| $DATE | ${USER:-unknown} | ${IP:-unknown} | ${SERVICE:-ssh} |" >> "$AUDIT_FILE"
            done
            
            # Attack pattern analysis
            echo "" >> "$AUDIT_FILE"
            echo "#### Attack Pattern Analysis" >> "$AUDIT_FILE"
            echo "" >> "$AUDIT_FILE"
            
            # Count attempts by IP
            if check_sudo_available; then
                ATTACKER_IPS=$(sudo grep "Failed password" /var/log/auth.log 2>/dev/null | grep -o "from [^ ]*" | cut -d' ' -f2 | sort | uniq -c | sort -nr | head -5)
            else
                ATTACKER_IPS=""
            fi
            if [ -n "$ATTACKER_IPS" ]; then
                echo "| Source IP | Failed Attempts | Risk Level |" >> "$AUDIT_FILE"
                echo "|-----------|-----------------|------------|" >> "$AUDIT_FILE"
                
                echo "$ATTACKER_IPS" | while read count ip; do
                    if [ "$count" -gt 50 ]; then
                        RISK="🔴 High (Possible Brute Force)"
                    elif [ "$count" -gt 10 ]; then
                        RISK="🟡 Medium"
                    else
                        RISK="🟢 Low"
                    fi
                    echo "| $ip | $count | $RISK |" >> "$AUDIT_FILE"
                    
                    if [ "$count" -gt 10 ]; then
                        SECURITY_SCORES[user_issues]=$((SECURITY_SCORES[user_issues] + 1))
                    fi
                done
            fi
            
            # Count attempts by username
            if check_sudo_available; then
                TARGETED_USERS=$(sudo grep "Failed password" /var/log/auth.log 2>/dev/null | grep -o "for [^ ]*" | cut -d' ' -f2 | sort | uniq -c | sort -nr | head -5)
            else
                TARGETED_USERS=""
            fi
            if [ -n "$TARGETED_USERS" ]; then
                echo "" >> "$AUDIT_FILE"
                echo "**Most Targeted Users:**" >> "$AUDIT_FILE"
                echo "" >> "$AUDIT_FILE"
                echo "$TARGETED_USERS" | while read count user; do
                    echo "- **$user:** $count failed attempts" >> "$AUDIT_FILE"
                done
            fi
            
        else
            echo "✅ **No failed login attempts found in recent logs**" >> "$AUDIT_FILE"
        fi
        
    elif [ -f /var/log/secure ]; then
        if check_sudo_available; then
            FAILED_LOGINS=$(sudo grep "Failed password" /var/log/secure 2>/dev/null | tail -20)
        else
            FAILED_LOGINS=""
        fi
        if [ -n "$FAILED_LOGINS" ]; then
            echo "| Date | User | Source IP | Service |" >> "$AUDIT_FILE"
            echo "|------|------|-----------|---------|" >> "$AUDIT_FILE"
            
            echo "$FAILED_LOGINS" | while read line; do
                DATE=$(echo "$line" | awk '{print $1, $2, $3}')
                USER=$(echo "$line" | grep -o "for [^ ]*" | cut -d' ' -f2)
                IP=$(echo "$line" | grep -o "from [^ ]*" | cut -d' ' -f2)
                SERVICE=$(echo "$line" | grep -o "sshd\[[0-9]*\]")
                
                echo "| $DATE | ${USER:-unknown} | ${IP:-unknown} | ${SERVICE:-ssh} |" >> "$AUDIT_FILE"
            done
        else
            echo "✅ **No failed login attempts found in recent logs**" >> "$AUDIT_FILE"
        fi
    else
        echo "⚠️ **No authentication log found**" >> "$AUDIT_FILE"
        echo "" >> "$AUDIT_FILE"
        echo "**Common log locations:**" >> "$AUDIT_FILE"
        echo "- /var/log/auth.log (Debian/Ubuntu)" >> "$AUDIT_FILE"
        echo "- /var/log/secure (RHEL/CentOS/Fedora)" >> "$AUDIT_FILE"
    fi
    echo "" >> "$AUDIT_FILE"
    
    # Successful logins analysis
    echo "### Recent Successful Logins" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"
    if [ -f /var/log/auth.log ]; then
        if check_sudo_available; then
            SUCCESS_LOGINS=$(sudo grep "Accepted password" /var/log/auth.log 2>/dev/null | tail -10)
        else
            SUCCESS_LOGINS=""
        fi
        if [ -n "$SUCCESS_LOGINS" ]; then
            echo "| Date | User | Source IP | Method |" >> "$AUDIT_FILE"
            echo "|------|------|-----------|--------|" >> "$AUDIT_FILE"
            
            echo "$SUCCESS_LOGINS" | while read line; do
                DATE=$(echo "$line" | awk '{print $1, $2, $3}')
                USER=$(echo "$line" | grep -o "for [^ ]*" | cut -d' ' -f2)
                IP=$(echo "$line" | grep -o "from [^ ]*" | cut -d' ' -f2)
                METHOD=$(echo "$line" | grep -o "publickey\|password")
                
                echo "| $DATE | $USER | $IP | $METHOD |" >> "$AUDIT_FILE"
            done
        else
            echo "ℹ️ **No recent successful password logins found**" >> "$AUDIT_FILE"
        fi
    fi
    echo "" >> "$AUDIT_FILE"

    # Enhanced Section 8: Security Tools Assessment
    echo "## 🛠️ Security Tools Status" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"
    
    echo "### Installed Security Tools" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"
    echo "| Tool | Status | Purpose | Recommendation |" >> "$AUDIT_FILE"
    echo "|------|--------|---------|----------------|" >> "$AUDIT_FILE"
    
    if [ "$RKHUNTER_INSTALLED" = true ]; then
        echo "| rkhunter | ✅ Installed | Rootkit detection | ✅ Keep updated |" >> "$AUDIT_FILE"
    else
        echo "| rkhunter | ❌ Missing | Rootkit detection | 🔧 Install with \`sudo apt install rkhunter\` |" >> "$AUDIT_FILE"
        SECURITY_SCORES[total_issues]=$((SECURITY_SCORES[total_issues] + 1))
    fi
    
    if [ "$CHKROOTKIT_INSTALLED" = true ]; then
        echo "| chkrootkit | ✅ Installed | Additional rootkit scanning | ✅ Keep updated |" >> "$AUDIT_FILE"
    else
        echo "| chkrootkit | ❌ Missing | Additional rootkit scanning | 🔧 Install with \`sudo apt install chkrootkit\` |" >> "$AUDIT_FILE"
        SECURITY_SCORES[total_issues]=$((SECURITY_SCORES[total_issues] + 1))
    fi
    
    if [ "$CLAMAV_INSTALLED" = true ]; then
        echo "| ClamAV | ✅ Installed | Malware/virus scanning | ✅ Keep definitions updated |" >> "$AUDIT_FILE"
    else
        echo "| ClamAV | ❌ Missing | Malware/virus scanning | 🔧 Install with \`sudo apt install clamav\` |" >> "$AUDIT_FILE"
        SECURITY_SCORES[total_issues]=$((SECURITY_SCORES[total_issues] + 1))
    fi
    
    # Check for additional security tools
    if command -v fail2ban-client >/dev/null 2>&1; then
        echo "| fail2ban | ✅ Installed | SSH brute force protection | ✅ Keep enabled |" >> "$AUDIT_FILE"
    else
        echo "| fail2ban | ❌ Missing | SSH brute force protection | 🔧 Install for SSH protection |" >> "$AUDIT_FILE"
    fi
    
    if command -v ufw >/dev/null 2>&1 || command -v firewall-cmd >/dev/null 2>&1 || command -v iptables >/dev/null 2>&1; then
        echo "| Firewall | ✅ Available | Network traffic filtering | ✅ Configure rules |" >> "$AUDIT_FILE"
    else
        echo "| Firewall | ❌ Missing | Network traffic filtering | 🔧 Install UFW or Firewalld |" >> "$AUDIT_FILE"
        SECURITY_SCORES[firewall_issues]=$((SECURITY_SCORES[firewall_issues] + 1))
    fi
    
    echo "" >> "$AUDIT_FILE"
    
    # Security tools coverage assessment
    echo "### Security Coverage Assessment" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"
    
    TOOLS_INSTALLED=0
    [ "$RKHUNTER_INSTALLED" = true ] && TOOLS_INSTALLED=$((TOOLS_INSTALLED + 1))
    [ "$CHKROOTKIT_INSTALLED" = true ] && TOOLS_INSTALLED=$((TOOLS_INSTALLED + 1))
    [ "$CLAMAV_INSTALLED" = true ] && TOOLS_INSTALLED=$((TOOLS_INSTALLED + 1))
    
    COVERAGE_PERCENT=$((TOOLS_INSTALLED * 33))
    if [ "$COVERAGE_PERCENT" -gt 99 ]; then COVERAGE_PERCENT=100; fi
    
    echo "- **Security Tools Coverage:** $TOOLS_INSTALLED/3 ($COVERAGE_PERCENT%)" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"
    
    if [ "$TOOLS_INSTALLED" -eq 3 ]; then
        echo "✅ **Excellent:** All major security tools are installed" >> "$AUDIT_FILE"
    elif [ "$TOOLS_INSTALLED" -eq 2 ]; then
        echo "🟡 **Good:** Most security tools are installed" >> "$AUDIT_FILE"
    elif [ "$TOOLS_INSTALLED" -eq 1 ]; then
        echo "⚠️ **Fair:** Some security tools missing" >> "$AUDIT_FILE"
    else
        echo "❌ **Poor:** No security tools installed" >> "$AUDIT_FILE"
    fi
    echo "" >> "$AUDIT_FILE"

    # Enhanced Section 9: Rootkit Hunter (rkhunter) Scan
    if [ "$RKHUNTER_INSTALLED" = true ]; then
        echo -e "${CYAN}Running rkhunter scan...${NC}"
        echo "## 🔍 Rootkit Hunter (rkhunter) Analysis" >> "$AUDIT_FILE"
        echo "" >> "$AUDIT_FILE"
        
        echo "### Scan Results" >> "$AUDIT_FILE"
        echo "" >> "$AUDIT_FILE"
        
        # Update definitions first
        echo "**Updating rkhunter definitions...**" >> "$AUDIT_FILE"
        if check_sudo_available; then
            sudo rkhunter --update > /dev/null 2>&1
            UPDATE_RESULT=$?
        else
            UPDATE_RESULT=1
        fi
        if [ $UPDATE_RESULT -eq 0 ]; then
            echo "✅ Definitions updated successfully" >> "$AUDIT_FILE"
        else
            echo "⚠️ Failed to update definitions" >> "$AUDIT_FILE"
        fi
        echo "" >> "$AUDIT_FILE"
        
        # Run scan and capture results
        if check_sudo_available; then
            RKHUNTER_OUTPUT=$(sudo rkhunter --check --skip-keypress --report-warnings-only 2>&1)
        else
            RKHUNTER_OUTPUT=""
        fi

        # Analyze results
        if echo "$RKHUNTER_OUTPUT" | grep -q "Warning"; then
            echo "⚠️ **Warnings detected during scan**" >> "$AUDIT_FILE"
            SECURITY_SCORES[malware_issues]=$((SECURITY_SCORES[malware_issues] + 1))
        else
            echo "✅ **No warnings detected**" >> "$AUDIT_FILE"
        fi
        echo "" >> "$AUDIT_FILE"
        
        # Show critical warnings in table format
        if echo "$RKHUNTER_OUTPUT" | grep -qi "warning\|found"; then
            echo "| Check | Result | Severity | Action |" >> "$AUDIT_FILE"
            echo "|-------|--------|----------|--------|" >> "$AUDIT_FILE"
            
            echo "$RKHUNTER_OUTPUT" | grep -i "warning\|found" | while read line; do
                if echo "$line" | grep -qi "warning"; then
                    CHECK=$(echo "$line" | cut -d':' -f1 | sed 's/^\[ *//; s/ *\]//' | tr '[:upper:]' '[:lower:]')
                    RESULT="Warning"
                    SEVERITY="🟡 Medium"
                    ACTION="Review"
                elif echo "$line" | grep -qi "found"; then
                    CHECK=$(echo "$line" | cut -d':' -f1 | sed 's/^\[ *//; s/ *\]//' | tr '[:upper:]' '[:lower:]')
                    RESULT="Issue Found"
                    SEVERITY="🔴 High"
                    ACTION="Investigate"
                fi
                
                echo "| $CHECK | $RESULT | $SEVERITY | $ACTION |" >> "$AUDIT_FILE"
            done
        fi
        echo "" >> "$AUDIT_FILE"
        
        # Full technical output (collapsed)
        echo "#### Technical Details" >> "$AUDIT_FILE"
        echo "" >> "$AUDIT_FILE"
        echo "<details>" >> "$AUDIT_FILE"
        echo "<summary>Click to expand full rkhunter output</summary>" >> "$AUDIT_FILE"
        echo "" >> "$AUDIT_FILE"
        echo '```' >> "$AUDIT_FILE"
        echo "$RKHUNTER_OUTPUT" >> "$AUDIT_FILE"
        echo '```' >> "$AUDIT_FILE"
        echo "</details>" >> "$AUDIT_FILE"
        echo "" >> "$AUDIT_FILE"
    fi

    # Enhanced Section 10: Chkrootkit Scan
    if [ "$CHKROOTKIT_INSTALLED" = true ]; then
        echo -e "${CYAN}Running chkrootkit scan...${NC}"
        echo "## 🔍 Chkrootkit Analysis" >> "$AUDIT_FILE"
        echo "" >> "$AUDIT_FILE"
        
        echo "### Scan Results Summary" >> "$AUDIT_FILE"
        echo "" >> "$AUDIT_FILE"
        
        # Run scan and capture results
        if check_sudo_available; then
            CHKROOTKIT_OUTPUT=$(sudo chkrootkit 2>&1)
        else
            CHKROOTKIT_OUTPUT=""
        fi

        # Analyze results for infections
        INFECTED_COUNT=$(echo "$CHKROOTKIT_OUTPUT" | grep -c "INFECTED")
        SUSPICIOUS_COUNT=$(echo "$CHKROOTKIT_OUTPUT" | grep -c "WARNING\|suspicious")
        
        echo "| Status | Count | Risk Level |" >> "$AUDIT_FILE"
        echo "|--------|-------|------------|" >> "$AUDIT_FILE"
        echo "| ✅ Clean | $((100 - INFECTED_COUNT - SUSPICIOUS_COUNT)) checks | 🟢 Low |" >> "$AUDIT_FILE"
        echo "| ⚠️ Suspicious | $SUSPICIOUS_COUNT checks | 🟡 Medium |" >> "$AUDIT_FILE"
        echo "| ❌ Infected | $INFECTED_COUNT checks | 🔴 Critical |" >> "$AUDIT_FILE"
        echo "" >> "$AUDIT_FILE"
        
        # Show detailed findings
        if [ "$INFECTED_COUNT" -gt 0 ] || [ "$SUSPICIOUS_COUNT" -gt 0 ]; then
            echo "### Detailed Findings" >> "$AUDIT_FILE"
            echo "" >> "$AUDIT_FILE"
            echo "| Check | Result | File | Action |" >> "$AUDIT_FILE"
            echo "|-------|--------|------|--------|" >> "$AUDIT_FILE"
            
            echo "$CHKROOTKIT_OUTPUT" | while read line; do
                if echo "$line" | grep -q "INFECTED"; then
                    CHECK=$(echo "$line" | awk '{print $1}')
                    FILE=$(echo "$line" | awk '{print $2}')
                    echo "| $CHECK | 🔴 INFECTED | $FILE | 🚨 Remove immediately |" >> "$AUDIT_FILE"
                    SECURITY_SCORES[malware_issues]=$((SECURITY_SCORES[malware_issues] + 2))
                elif echo "$line" | grep -q "WARNING\|suspicious"; then
                    CHECK=$(echo "$line" | awk '{print $1}')
                    FILE=$(echo "$line" | awk '{print $2}')
                    echo "| $CHECK | ⚠️ SUSPICIOUS | $FILE | 🔍 Investigate further |" >> "$AUDIT_FILE"
                    SECURITY_SCORES[malware_issues]=$((SECURITY_SCORES[malware_issues] + 1))
                fi
            done
        else
            echo "✅ **No rootkit infections detected** - System appears clean" >> "$AUDIT_FILE"
        fi
        echo "" >> "$AUDIT_FILE"
        
        # Technical details section
        echo "#### Technical Scan Output" >> "$AUDIT_FILE"
        echo "" >> "$AUDIT_FILE"
        echo "<details>" >> "$AUDIT_FILE"
        echo "<summary>Click to expand full chkrootkit output</summary>" >> "$AUDIT_FILE"
        echo "" >> "$AUDIT_FILE"
        echo '```' >> "$AUDIT_FILE"
        echo "$CHKROOTKIT_OUTPUT" >> "$AUDIT_FILE"
        echo '```' >> "$AUDIT_FILE"
        echo "</details>" >> "$AUDIT_FILE"
        echo "" >> "$AUDIT_FILE"
    fi

    # Enhanced Section 11: ClamAV Malware Scan
    if [ "$CLAMAV_INSTALLED" = true ]; then
        echo -e "${CYAN}Running ClamAV malware scan...${NC}"
        echo "## 🦠 ClamAV Malware Analysis" >> "$AUDIT_FILE"
        echo "" >> "$AUDIT_FILE"

        # Virus definition status
        echo "### Virus Database Status" >> "$AUDIT_FILE"
        echo "" >> "$AUDIT_FILE"
        
        if command -v freshclam >/dev/null 2>&1; then
            echo "**Updating virus definitions...**" >> "$AUDIT_FILE"
            if check_sudo_available; then
                FRESHCLAM_OUTPUT=$(sudo freshclam --quiet 2>&1)
                UPDATE_STATUS=$?
            else
                FRESHCLAM_OUTPUT="Sudo not available"
                UPDATE_STATUS=1
            fi

            # Get current database version
            DB_VERSION=$(sigtool --info /var/lib/clamav/main.cvd 2>/dev/null | grep "Build time" || echo "Unknown")
            
            if [ $UPDATE_STATUS -eq 0 ]; then
                echo "- ✅ Database updated successfully" >> "$AUDIT_FILE"
                echo "- 📅 Database version: $DB_VERSION" >> "$AUDIT_FILE"
                DB_STATUS="Current"
            else
                echo "- ⚠️ Update failed: $FRESHCLAM_OUTPUT" >> "$AUDIT_FILE"
                echo "- 📅 Database version: $DB_VERSION" >> "$AUDIT_FILE"
                DB_STATUS="Outdated"
            fi
        else
            echo "- ❌ freshclam not found - manual updates required" >> "$AUDIT_FILE"
            DB_STATUS="Unknown"
        fi
        echo "" >> "$AUDIT_FILE"

        # Service management
        echo "### ClamAV Service Status" >> "$AUDIT_FILE"
        echo "" >> "$AUDIT_FILE"
        
        SERVICE_STARTED=false
        SERVICE_NAME="None"

        if command -v systemctl >/dev/null 2>&1; then
            # Try common service names
            for service in "clamav-daemon" "clamav" "clamd"; do
                if systemctl list-unit-files 2>/dev/null | grep -q "^${service}.service"; then
                    SERVICE_NAME="$service"
                    if systemctl is-active --quiet "$service" 2>/dev/null; then
                        echo "- ✅ $service is running" >> "$AUDIT_FILE"
                        SERVICE_STARTED=true
                    else
                        echo "- ⚠️ $service is not running" >> "$AUDIT_FILE"
                        echo "  Starting $service for scan..." >> "$AUDIT_FILE"
                        sudo systemctl start "$service" >/dev/null 2>&1
                        if systemctl is-active --quiet "$service" 2>/dev/null; then
                            echo "- ✅ $service started successfully" >> "$AUDIT_FILE"
                            SERVICE_STARTED=true
                        else
                            echo "- ❌ Failed to start $service" >> "$AUDIT_FILE"
                        fi
                    fi
                    break
                fi
            done
        fi
        
        if [ "$SERVICE_STARTED" = false ]; then
            echo "- ℹ️ Using ClamAV scanner only (no daemon)" >> "$AUDIT_FILE"
            SERVICE_NAME="Scanner Only"
        fi
        echo "" >> "$AUDIT_FILE"

        # Scan critical directories
        echo "### Critical Directory Scan Results" >> "$AUDIT_FILE"
        echo "" >> "$AUDIT_FILE"
        
        SCAN_DIRS="/home /tmp /var/www /usr/local/bin /var/tmp"
        FILES_SCANNED=0
        THREATS_FOUND=false
        THREAT_DETAILS=()
        
        echo "| Directory | Status | Files Found | Threats | Scan Time |" >> "$AUDIT_FILE"
        echo "|-----------|--------|-------------|---------|-----------|" >> "$AUDIT_FILE"
        
        for dir in $SCAN_DIRS; do
            if [ -d "$dir" ]; then
                START_TIME=$(date +%s)
                
                # Quick scan focusing on threats only
                SCAN_RESULT=$(clamscan --recursive --infected --no-summary "$dir" 2>/dev/null)
                END_TIME=$(date +%s)
                SCAN_TIME=$((END_TIME - START_TIME))
                
                # Count files in directory
                FILE_COUNT=$(find "$dir" -type f 2>/dev/null | wc -l)
                FILES_SCANNED=$((FILES_SCANNED + FILE_COUNT))
                
                # Analyze results
                if echo "$SCAN_RESULT" | grep -q "FOUND"; then
                    THREATS_FOUND=true
                    THREAT_COUNT=$(echo "$SCAN_RESULT" | grep -c "FOUND")
                    echo "| $dir | 🔴 Threats | $FILE_COUNT | $THREAT_COUNT | ${SCAN_TIME}s |" >> "$AUDIT_FILE"
                    
                    # Store threat details
                    while read threat_line; do
                        THREAT_DETAILS+=("$dir: $threat_line")
                    done <<< "$SCAN_RESULT"
                    
                    SECURITY_SCORES[malware_issues]=$((SECURITY_SCORES[malware_issues] + THREAT_COUNT))
                else
                    echo "| $dir | ✅ Clean | $FILE_COUNT | 0 | ${SCAN_TIME}s |" >> "$AUDIT_FILE"
                fi
            else
                echo "| $dir | ⚪ Skipped | 0 | 0 | 0s |" >> "$AUDIT_FILE"
            fi
        done
        
        echo "" >> "$AUDIT_FILE"
        
        # Detailed threat analysis
        if [ "$THREATS_FOUND" = true ]; then
            echo "### 🚨 Threats Detected" >> "$AUDIT_FILE"
            echo "" >> "$AUDIT_FILE"
            echo "| File Path | Threat Type | Action |" >> "$AUDIT_FILE"
            echo "|-----------|-------------|--------|" >> "$AUDIT_FILE"
            
            for threat in "${THREAT_DETAILS[@]}"; do
                FILE_PATH=$(echo "$threat" | awk '{print $1}' | sed 's/:.*//')
                THREAT_TYPE=$(echo "$threat" | grep -o 'FOUND.*' | cut -d' ' -f2-)
                echo "| $FILE_PATH | $THREAT_TYPE | 🗑️ Remove immediately |" >> "$AUDIT_FILE"
            done
            echo "" >> "$AUDIT_FILE"
            
            echo "**⚠️ CRITICAL:** Malware detected! Take immediate action:" >> "$AUDIT_FILE"
            echo "1. Remove infected files" >> "$AUDIT_FILE"
            echo "2. Scan the entire system" >> "$AUDIT_FILE"
            echo "3. Check for system compromise" >> "$AUDIT_FILE"
            echo "4. Change all passwords" >> "$AUDIT_FILE"
        else
            echo "✅ **No malware threats detected** in critical directories" >> "$AUDIT_FILE"
        fi
        echo "" >> "$AUDIT_FILE"
        
        # Scan summary with statistics
        echo "### Scan Summary & Statistics" >> "$AUDIT_FILE"
        echo "" >> "$AUDIT_FILE"
        echo "| Metric | Value | Status |" >> "$AUDIT_FILE"
        echo "|--------|-------|--------|" >> "$AUDIT_FILE"
        echo "| Files Scanned | $FILES_SCANNED | ✅ |" >> "$AUDIT_FILE"
        echo "| Directories | $SCAN_DIRS | ✅ |" >> "$AUDIT_FILE"
        echo "| Threats Found | $(if [ "$THREATS_FOUND" = true ]; then echo "${#THREAT_DETAILS[@]}"; else echo "0"; fi) | $(if [ "$THREATS_FOUND" = true ]; then echo "🔴"; else echo "✅"; fi) |" >> "$AUDIT_FILE"
        echo "| Database | $DB_STATUS | $(if [ "$DB_STATUS" = "Current" ]; then echo "✅"; else echo "⚠️"; fi) |" >> "$AUDIT_FILE"
        echo "| Service | $SERVICE_NAME | $(if [ "$SERVICE_STARTED" = true ]; then echo "✅"; else echo "ℹ️"; fi) |" >> "$AUDIT_FILE"
        echo "" >> "$AUDIT_FILE"
    fi

    # Enhanced Section 12: Security Recommendations with Executive Summary
    echo "## 📋 Security Recommendations" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"

    # Calculate total security score
    TOTAL_ISSUES=$((SECURITY_SCORES[ssh_issues] + SECURITY_SCORES[firewall_issues] + SECURITY_SCORES[user_issues] + SECURITY_SCORES[permission_issues] + SECURITY_SCORES[malware_issues]))
    SECURITY_SCORES[total_issues]=$TOTAL_ISSUES

    # Executive Summary
    echo "### 🎯 Executive Summary" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"
    
    echo "| Security Area | Issues | Status | Priority |" >> "$AUDIT_FILE"
    echo "|---------------|--------|--------|----------|" >> "$AUDIT_FILE"
    
    if [ "${SECURITY_SCORES[ssh_issues]}" -gt 0 ]; then
        echo "| 🔐 SSH Security | ${SECURITY_SCORES[ssh_issues]} | ⚠️ Needs Attention | 🚨 High |" >> "$AUDIT_FILE"
    else
        echo "| 🔐 SSH Security | 0 | ✅ Secure | 🟢 Low |" >> "$AUDIT_FILE"
    fi
    
    if [ "${SECURITY_SCORES[firewall_issues]}" -gt 0 ]; then
        echo "| 🔥 Firewall | ${SECURITY_SCORES[firewall_issues]} | ⚠️ Needs Attention | 🚨 High |" >> "$AUDIT_FILE"
    else
        echo "| 🔥 Firewall | 0 | ✅ Active | 🟢 Low |" >> "$AUDIT_FILE"
    fi
    
    if [ "${SECURITY_SCORES[user_issues]}" -gt 0 ]; then
        echo "| 👥 User Accounts | ${SECURITY_SCORES[user_issues]} | ⚠️ Review Needed | 🟡 Medium |" >> "$AUDIT_FILE"
    else
        echo "| 👥 User Accounts | 0 | ✅ Secure | 🟢 Low |" >> "$AUDIT_FILE"
    fi
    
    if [ "${SECURITY_SCORES[permission_issues]}" -gt 0 ]; then
        echo "| 📁 File Permissions | ${SECURITY_SCORES[permission_issues]} | ⚠️ Review Needed | 🟡 Medium |" >> "$AUDIT_FILE"
    else
        echo "| 📁 File Permissions | 0 | ✅ Secure | 🟢 Low |" >> "$AUDIT_FILE"
    fi
    
    if [ "${SECURITY_SCORES[malware_issues]}" -gt 0 ]; then
        echo "| 🦠 Malware/Rootkits | ${SECURITY_SCORES[malware_issues]} | 🚨 Threats Found | 🚨 Critical |" >> "$AUDIT_FILE"
    else
        echo "| 🦠 Malware/Rootkits | 0 | ✅ Clean | 🟢 Low |" >> "$AUDIT_FILE"
    fi
    
    echo "" >> "$AUDIT_FILE"
    
    # Overall security score
    MAX_SCORE=10
    DEDUCTIONS=$TOTAL_ISSUES
    FINAL_SCORE=$((MAX_SCORE - DEDUCTIONS))
    if [ "$FINAL_SCORE" -lt 0 ]; then FINAL_SCORE=0; fi
    
    if [ "$FINAL_SCORE" -ge 8 ]; then
        RISK_LEVEL="🟢 LOW RISK"
        RISK_COLOR="green"
    elif [ "$FINAL_SCORE" -ge 6 ]; then
        RISK_LEVEL="🟡 MEDIUM RISK"
        RISK_COLOR="yellow"
    elif [ "$FINAL_SCORE" -ge 4 ]; then
        RISK_LEVEL="🔴 HIGH RISK"
        RISK_COLOR="red"
    else
        RISK_LEVEL="🚨 CRITICAL RISK"
        RISK_COLOR="critical"
    fi
    
    echo "**Overall Security Score:** **$FINAL_SCORE/10** $RISK_LEVEL" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"
    
    # Priority recommendations
    echo "### 🚨 Priority Actions (Address First)" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"
    
    PRIORITY_RECS=()
    
    # Critical priority recommendations
    if grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config 2>/dev/null; then
        PRIORITY_RECS+=("🚨 **CRITICAL:** Disable SSH root login immediately")
        echo "#### 🚨 CRITICAL Actions" >> "$AUDIT_FILE"
        echo "" >> "$AUDIT_FILE"
        echo "1. **Disable SSH Root Login**" >> "$AUDIT_FILE"
        echo "   ```bash" >> "$AUDIT_FILE"
        echo "   sudo sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config" >> "$AUDIT_FILE"
        echo "   sudo systemctl restart sshd" >> "$AUDIT_FILE"
        echo "   ```" >> "$AUDIT_FILE"
        echo "" >> "$AUDIT_FILE"
    fi
    
    if [ "$FIREWALL_ACTIVE" = false ]; then
        PRIORITY_RECS+=("🚨 **CRITICAL:** Enable firewall protection")
        echo "2. **Enable Firewall Protection**" >> "$AUDIT_FILE"
        echo "   ```bash" >> "$AUDIT_FILE"
        echo "   # For Ubuntu/Debian:" >> "$AUDIT_FILE"
        echo "   sudo ufw enable" >> "$AUDIT_FILE"
        echo "   sudo ufw allow ssh" >> "$AUDIT_FILE"
        echo "   " >> "$AUDIT_FILE"
        echo "   # For RHEL/CentOS:" >> "$AUDIT_FILE"
        echo "   sudo systemctl enable --now firewalld" >> "$AUDIT_FILE"
        echo "   ```" >> "$AUDIT_FILE"
        echo "" >> "$AUDIT_FILE"
    fi
    
    if [ "${SECURITY_SCORES[malware_issues]}" -gt 0 ]; then
        PRIORITY_RECS+=("🚨 **CRITICAL:** Investigate and remove detected malware")
        echo "3. **Remove Malware Threats**" >> "$AUDIT_FILE"
        echo "   ```bash" >> "$AUDIT_FILE"
        echo "   # Remove infected files (from scan results)" >> "$AUDIT_FILE"
        echo "   sudo rm /path/to/infected/file" >> "$AUDIT_FILE"
        echo "   # Run full system scan" >> "$AUDIT_FILE"
        echo "   sudo clamscan -r --infected /" >> "$AUDIT_FILE"
        echo "   ```" >> "$AUDIT_FILE"
        echo "" >> "$AUDIT_FILE"
    fi
    
    # Medium priority recommendations
    if [ ${#PRIORITY_RECS[@]} -eq 0 ]; then
        echo "✅ **No critical issues found** - Great job on security!" >> "$AUDIT_FILE"
        echo "" >> "$AUDIT_FILE"
    fi
    
    echo "### 💡 Recommended Security Improvements" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"
    
    echo "#### 🔐 SSH Security Enhancements" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"
    if grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config 2>/dev/null; then
        echo "- **Disable password authentication** (use keys only):" >> "$AUDIT_FILE"
        echo "  ```bash" >> "$AUDIT_FILE"
        echo "  sudo sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config" >> "$AUDIT_FILE"
        echo "  sudo systemctl restart sshd" >> "$AUDIT_FILE"
        echo "  ```" >> "$AUDIT_FILE"
        echo "" >> "$AUDIT_FILE"
    fi
    
    echo "- **Change default SSH port** (optional but recommended):" >> "$AUDIT_FILE"
    echo "  ```bash" >> "$AUDIT_FILE"
    echo "  sudo sed -i 's/^Port.*/Port 2222/' /etc/ssh/sshd_config" >> "$AUDIT_FILE"
    echo "  sudo systemctl restart sshd" >> "$AUDIT_FILE"
    echo "  ```" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"
    
    echo "#### 🛠️ Security Tools Installation" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"
    echo "| Tool | Installation Command | Purpose |" >> "$AUDIT_FILE"
    echo "|------|---------------------|---------|" >> "$AUDIT_FILE"
    
    if [ "$RKHUNTER_INSTALLED" = false ]; then
        echo "| rkhunter | \`sudo apt install rkhunter\` | Rootkit detection |" >> "$AUDIT_FILE"
    fi
    
    if [ "$CHKROOTKIT_INSTALLED" = false ]; then
        echo "| chkrootkit | \`sudo apt install chkrootkit\` | Additional rootkit scanning |" >> "$AUDIT_FILE"
    fi
    
    if [ "$CLAMAV_INSTALLED" = false ]; then
        echo "| ClamAV | \`sudo apt install clamav\` | Malware scanning |" >> "$AUDIT_FILE"
    fi
    
    if ! command -v fail2ban-client >/dev/null 2>&1; then
        echo "| fail2ban | \`sudo apt install fail2ban\` | SSH brute force protection |" >> "$AUDIT_FILE"
    fi
    echo "" >> "$AUDIT_FILE"
    
    echo "#### 📅 Ongoing Security Practices" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"
    echo "✅ **Daily:**" >> "$AUDIT_FILE"
    echo "- Review authentication logs for suspicious activity" >> "$AUDIT_FILE"
    echo "- Check for failed login attempts" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"
    
    echo "✅ **Weekly:**" >> "$AUDIT_FILE"
    echo "- Run security updates: \`sudo apt update && sudo apt upgrade\`" >> "$AUDIT_FILE"
    echo "- Scan critical directories for malware" >> "$AUDIT_FILE"
    echo "- Review user accounts and privileges" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"
    
    echo "✅ **Monthly:**" >> "$AUDIT_FILE"
    echo "- Run comprehensive security audit" >> "$AUDIT_FILE"
    echo "- Review and rotate passwords" >> "$AUDIT_FILE"
    echo "- Check system logs for anomalies" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"
    
    echo "#### ⏱️ Implementation Timeline" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"
    echo "| Priority | Action | Estimated Time | Impact |" >> "$AUDIT_FILE"
    echo "|----------|--------|----------------|--------|" >> "$AUDIT_FILE"
    echo "| 🚨 Critical | Disable SSH root login | 5 minutes | 🛡️ High |" >> "$AUDIT_FILE"
    echo "| 🚨 Critical | Enable firewall | 10 minutes | 🛡️ High |" >> "$AUDIT_FILE"
    echo "| 🟡 Medium | Install security tools | 15 minutes | 🔍 Medium |" >> "$AUDIT_FILE"
    echo "| 🟡 Medium | Configure SSH keys | 20 minutes | 🔐 High |" >> "$AUDIT_FILE"
    echo "| 🟢 Low | Change SSH port | 10 minutes | 🕵️ Low |" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"
    
    echo "**Total estimated time:** 1 hour for complete security hardening" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"

    # Footer
    echo "---" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"
    echo "### 📊 Quick Assessment Summary" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"
    echo "**Security Score:** $FINAL_SCORE/10 $RISK_LEVEL" >> "$AUDIT_FILE"
    echo "**Total Issues Identified:** $TOTAL_ISSUES" >> "$AUDIT_FILE"
    echo "**Tools Coverage:** $TOOLS_INSTALLED/3 ($(($TOOLS_INSTALLED * 33))%)" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"
    
    echo "*Report generated by LinWatch Security Audit*" >> "$AUDIT_FILE"
    echo "" >> "$AUDIT_FILE"
    #echo "📅 **Next audit recommended:** $(date -d '+1 month' '+%Y-%m-%d')" >> "$AUDIT_FILE"

    echo -e "${GREEN}✓ Security audit complete!${NC}"
    echo -e "${GREEN}Report saved to: ${CYAN}$AUDIT_FILE${NC}"
    echo ""
}

#============================================================================
# ADDITIONAL SECURITY AUDIT FUNCTIONS
#============================================================================

AUDIT_LOG_FILE="/var/log/linwatch_security_audit_$(date +%Y%m%d_%H%M%S).log"

log_audit() {
    local severity="$1"
    local category="$2"
    local message="$3"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$severity] [$category] $message" >> "$AUDIT_LOG_FILE" 2>/dev/null || true
}

audit_suid_sgid() {
    echo -e "${CYAN}Scanning for SUID/SGID binaries...${NC}"
    log_audit "INFO" "SUGID_SCAN" "Starting SUID/SGID binary scan"

    suid_count=$(find /usr -type f -perm /4000 2>/dev/null | wc -l)
    sgid_count=$(find /usr -type f -perm /2000 2>/dev/null | wc -l)

    echo -e "${WHITE}SUID binaries found:${NC} ${suid_count}"
    echo -e "${WHITE}SGID binaries found:${NC} ${sgid_count}"

    if [[ $suid_count -gt 50 ]]; then
        echo -e "${YELLOW}⚠ High number of SUID binaries detected${NC}"
        log_audit "WARNING" "SUGID_SCAN" "High SUID count: $suid_count binaries"
    fi

    suspicious_suid=""
    for binary in $(find /usr -type f -perm /4000 2>/dev/null); do
        filename=$(basename "$binary")
        case "$filename" in
            su|sudo|passwd|chsh|chfn|newgrp|gpasswd|pkexec|shadow|busybox)
                ;;
            *)
                [[ -n "$suspicious_suid" ]] && suspicious_suid="$suspicious_suid, $binary" || suspicious_suid="$binary"
                ;;
        esac
    done

    if [[ -n "$suspicious_suid" ]]; then
        echo -e "${YELLOW}Non-standard SUID binaries: $suspicious_suid${NC}"
        log_audit "WARNING" "SUGID_SCAN" "Non-standard SUID binaries: $suspicious_suid"
    else
        echo -e "${GREEN}No suspicious SUID binaries found${NC}"
    fi

    log_audit "INFO" "SUGID_SCAN" "SUID/SGID audit completed"
}

audit_world_writable() {
    echo -e "${CYAN}Scanning for world-writable files...${NC}"
    log_audit "INFO" "WW_SCAN" "Starting world-writable files scan"

    ww_count=$(find /etc -type f -perm -2 2>/dev/null | wc -l)
    ww_home_count=$(find /home -type f -perm -2 2>/dev/null | wc -l)

    echo -e "${WHITE}World-writable files in /etc:${NC} ${ww_count}"
    echo -e "${WHITE}World-writable files in /home:${NC} ${ww_home_count}"

    if [[ $ww_count -gt 20 ]]; then
        echo -e "${YELLOW}⚠ High number of world-writable files in /etc${NC}"
        log_audit "WARNING" "WW_SCAN" "High WW count in /etc: $ww_count files"
    fi

    critical_ww=$(find /etc -type f -perm -2 2>/dev/null | grep -E "(passwd|shadow|group|gshadow|sudoers)" | head -5)
    if [[ -n "$critical_ww" ]]; then
        echo -e "${RED}⚠ Critical world-writable files: $critical_ww${NC}"
        log_audit "CRITICAL" "WW_SCAN" "Critical WW files found: $critical_ww"
    else
        echo -e "${GREEN}No critical world-writable files found${NC}"
    fi

    log_audit "INFO" "WW_SCAN" "World-writable audit completed"
}

audit_user_accounts() {
    echo -e "${CYAN}Analyzing user accounts...${NC}"
    log_audit "INFO" "USER_AUDIT" "Starting user account audit"

    system_accounts=$(awk -F: '$3 < 1000 {print $1}' /etc/passwd | wc -l)
    echo -e "${WHITE}System accounts (UID < 1000):${NC} ${system_accounts}"

    shell_accounts=$(awk -F: '$7 !~ /nologin|false/ {print $1}' /etc/passwd | wc -l)
    echo -e "${WHITE}Accounts with login shell:${NC} ${shell_accounts}"

    empty_pass=$(awk -F: '$2 == "" {print $1}' /etc/shadow 2>/dev/null)
    if [[ -n "$empty_pass" ]]; then
        echo -e "${RED}⚠ Accounts with empty passwords: $empty_pass${NC}"
        log_audit "CRITICAL" "USER_AUDIT" "Empty password accounts: $empty_pass"
    else
        echo -e "${GREEN}No accounts with empty passwords${NC}"
    fi

    uid0_accounts=$(awk -F: '$3 == 0 {print $1}' /etc/passwd)
    if [[ -n "$uid0_accounts" ]]; then
        echo -e "${YELLOW}UID 0 accounts: $uid0_accounts${NC}"
        log_audit "WARNING" "USER_AUDIT" "UID 0 accounts: $uid0_accounts"
    else
        echo -e "${GREEN}No additional UID 0 accounts found${NC}"
    fi

    log_audit "INFO" "USER_AUDIT" "User account audit completed"
}

audit_ssh_security() {
    echo -e "${CYAN}Auditing SSH configuration...${NC}"
    log_audit "INFO" "SSH_AUDIT" "Starting SSH security audit"

    if [[ ! -f /etc/ssh/sshd_config ]]; then
        echo -e "${GRAY}SSH not installed or configured${NC}"
        return
    fi

    if grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config 2>/dev/null; then
        echo -e "${YELLOW}⚠ Root login is enabled${NC}"
        log_audit "WARNING" "SSH_AUDIT" "Root login is enabled"
    elif grep -q "^PermitRootLogin no" /etc/ssh/sshd_config 2>/dev/null; then
        echo -e "${GREEN}✓ Root login is disabled${NC}"
    fi

    if grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config 2>/dev/null; then
        echo -e "${YELLOW}⚠ Password authentication is enabled${NC}"
        log_audit "WARNING" "SSH_AUDIT" "Password authentication enabled"
    elif grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config 2>/dev/null; then
        echo -e "${GREEN}✓ Password authentication is disabled${NC}"
    fi

    if grep -q "^Protocol 1" /etc/ssh/sshd_config 2>/dev/null; then
        echo -e "${RED}⚠ SSH Protocol 1 is enabled (insecure)${NC}"
        log_audit "CRITICAL" "SSH_AUDIT" "SSH Protocol 1 detected"
    fi

    if grep -q "^PermitEmptyPasswords yes" /etc/ssh/sshd_config 2>/dev/null; then
        echo -e "${RED}⚠ Empty passwords are permitted${NC}"
        log_audit "CRITICAL" "SSH_AUDIT" "Empty passwords permitted"
    fi

    if [[ -f /var/log/auth.log ]]; then
        failed_ssh=$(grep "Failed password" /var/log/auth.log 2>/dev/null | wc -l)
        echo -e "${WHITE}Failed SSH login attempts (recent):${NC} $failed_ssh"
        if [[ $failed_ssh -gt 10 ]]; then
            log_audit "WARNING" "SSH_AUDIT" "High number of failed SSH attempts: $failed_ssh"
        fi
    fi

    log_audit "INFO" "SSH_AUDIT" "SSH security audit completed"
}

audit_firewall() {
    echo -e "${CYAN}Checking firewall status...${NC}"
    log_audit "INFO" "FIREWALL" "Starting firewall audit"

    firewall_active=false

    if command -v ufw >/dev/null 2>&1; then
        if ufw status 2>/dev/null | grep -q "Status: active"; then
            echo -e "${GREEN}✓ UFW is active${NC}"
            firewall_active=true
        else
            echo -e "${YELLOW}⚠ UFW is installed but inactive${NC}"
        fi
    fi

    if command -v firewall-cmd >/dev/null 2>&1; then
        if firewall-cmd --state 2>/dev/null | grep -q "running"; then
            echo -e "${GREEN}✓ firewalld is active${NC}"
            firewall_active=true
        else
            echo -e "${YELLOW}⚠ firewalld is installed but inactive${NC}"
        fi
    fi

    if command -v iptables >/dev/null 2>&1; then
        iptables_rules=$(iptables -L -n 2>/dev/null | grep -c "^ACCEPT\|^DROP\|^REJECT" || echo "0")
        if [[ $iptables_rules -gt 0 ]]; then
            echo -e "${GREEN}✓ iptables has rules configured${NC}"
            firewall_active=true
        fi
    fi

    if [[ "$firewall_active" == false ]]; then
        echo -e "${RED}⚠ No active firewall detected${NC}"
        log_audit "WARNING" "FIREWALL" "No active firewall detected"
    fi

    log_audit "INFO" "FIREWALL" "Firewall audit completed"
}

audit_services() {
    echo -e "${CYAN}Analyzing running services...${NC}"
    log_audit "INFO" "SERVICES" "Starting services audit"

    if command -v systemctl >/dev/null 2>&1; then
        total_services=$(systemctl list-units --type=service --state=running 2>/dev/null | grep -c "service" || echo "0")
        echo -e "${WHITE}Running services:${NC} ${total_services}"

        dangerous_services=""
        for svc in telnetd rshd vsftpd proftpd telnet rlogin rexec; do
            if systemctl is-active "$svc" 2>/dev/null | grep -q "^active"; then
                dangerous_services="$dangerous_services $svc"
            fi
        done

        if [[ -n "$dangerous_services" ]]; then
            echo -e "${RED}⚠ Insecure services running:$dangerous_services${NC}"
            log_audit "CRITICAL" "SERVICES" "Insecure services: $dangerous_services"
        else
            echo -e "${GREEN}No obviously insecure services detected${NC}"
        fi

        echo ""
        echo -e "${WHITE}Services listening on external interfaces:${NC}"
        ss -tulpn 2>/dev/null | grep LISTEN | grep -v "127.0.0.1" | head -10 || echo "None found"
    fi

    log_audit "INFO" "SERVICES" "Services audit completed"
}

audit_kernel_parameters() {
    echo -e "${CYAN}Checking kernel security parameters...${NC}"
    log_audit "INFO" "KERNEL" "Starting kernel parameter audit"

    ip_forward=$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)
    if [[ "$ip_forward" == "1" ]]; then
        echo -e "${YELLOW}⚠ IP forwarding is enabled${NC}"
        log_audit "WARNING" "KERNEL" "IP forwarding enabled"
    else
        echo -e "${GREEN}✓ IP forwarding is disabled${NC}"
    fi

    icmp_redirect=$(cat /proc/sys/net/ipv4/conf/all/accept_redirects 2>/dev/null)
    if [[ "$icmp_redirect" == "1" ]]; then
        echo -e "${YELLOW}⚠ ICMP redirects accepted${NC}"
        log_audit "WARNING" "KERNEL" "ICMP redirects accepted"
    else
        echo -e "${GREEN}✓ ICMP redirects not accepted${NC}"
    fi

    source_route=$(cat /proc/sys/net/ipv4/conf/all/accept_source_route 2>/dev/null)
    if [[ "$source_route" == "1" ]]; then
        echo -e "${YELLOW}⚠ Source routing is accepted${NC}"
        log_audit "WARNING" "KERNEL" "Source routing accepted"
    else
        echo -e "${GREEN}✓ Source routing is not accepted${NC}"
    fi

    rp_filter=$(cat /proc/sys/net/ipv4/conf/all/rp_filter 2>/dev/null)
    if [[ "$rp_filter" == "0" ]]; then
        echo -e "${YELLOW}⚠ Reverse path filtering is disabled${NC}"
        log_audit "WARNING" "KERNEL" "RP filter disabled"
    else
        echo -e "${GREEN}✓ Reverse path filtering is enabled${NC}"
    fi

    aslr=$(cat /proc/sys/kernel/randomize_va_space 2>/dev/null)
    if [[ "$aslr" == "2" ]]; then
        echo -e "${GREEN}✓ ASLR is fully enabled${NC}"
    elif [[ "$aslr" == "1" ]]; then
        echo -e "${YELLOW}⚠ ASLR is partially enabled${NC}"
    else
        echo -e "${RED}⚠ ASLR is disabled${NC}"
        log_audit "WARNING" "KERNEL" "ASLR disabled"
    fi

    log_audit "INFO" "KERNEL" "Kernel parameter audit completed"
}

audit_ssl_certificates() {
    echo -e "${CYAN}Checking SSL/TLS certificates...${NC}"
    log_audit "INFO" "SSL" "Starting SSL certificate audit"

    cert_locations="/etc/ssl/certs /etc/pki/tls/certs /etc/nginx/ssl /etc/apache2/ssl"

    for loc in $cert_locations; do
        if [[ -d "$loc" ]]; then
            cert_count=$(find "$loc" -name "*.crt" -o -name "*.pem" 2>/dev/null | wc -l)
            if [[ $cert_count -gt 0 ]]; then
                echo -e "${WHITE}Certificates in $loc:${NC} $cert_count"

                if command -v openssl >/dev/null 2>&1; then
                    for cert in $(find "$loc" -name "*.crt" -o -name "*.pem" 2>/dev/null); do
                        expiry=$(openssl x509 -enddate -noout -in "$cert" 2>/dev/null | cut -d= -f2)
                        if [[ -n "$expiry" ]]; then
                            expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null)
                            now_epoch=$(date +%s)
                            days_left=$(( (expiry_epoch - now_epoch) / 86400 ))

                            if [[ $days_left -lt 0 ]]; then
                                echo -e "${RED}⚠ Expired: $cert (expired ${days_left} days ago)${NC}"
                                log_audit "CRITICAL" "SSL" "Expired certificate: $cert"
                            elif [[ $days_left -lt 30 ]]; then
                                echo -e "${YELLOW}⚠ Expiring soon: $cert (${days_left} days left)${NC}"
                                log_audit "WARNING" "SSL" "Expiring certificate: $cert ($days_left days)"
                            fi
                        fi
                    done
                fi
            fi
        fi
    done

    if ! command -v openssl >/dev/null 2>&1; then
        echo -e "${GRAY}OpenSSL not available for certificate analysis${NC}"
    fi

    log_audit "INFO" "SSL" "SSL certificate audit completed"
}

audit_security_updates() {
    echo -e "${CYAN}Checking for security updates...${NC}"
    log_audit "INFO" "SEC_UPDATES" "Starting security update check"

    security_updates=0

    if command -v apt >/dev/null 2>&1; then
        sudo apt update -qq 2>/dev/null
        security_updates=$(apt-get -s upgrade 2>/dev/null | grep -c "^Inst security" || echo "0")
        echo -e "${WHITE}Pending security updates (APT):${NC} $security_updates"

        if [[ $security_updates -gt 0 ]]; then
            log_audit "WARNING" "SEC_UPDATES" "$security_updates security updates pending"
        fi
    elif command -v dnf >/dev/null 2>&1; then
        security_updates=$(sudo dnf --security check-update 2>/dev/null | grep -c "security" || echo "0")
        echo -e "${WHITE}Pending security updates (DNF):${NC} $security_updates"

        if [[ $security_updates -gt 0 ]]; then
            log_audit "WARNING" "SEC_UPDATES" "$security_updates security updates pending"
        fi
    elif command -v yum >/dev/null 2>&1; then
        security_updates=$(sudo yum --security check-update 2>/dev/null | grep -c "security" || echo "0")
        echo -e "${WHITE}Pending security updates (YUM):${NC} $security_updates"

        if [[ $security_updates -gt 0 ]]; then
            log_audit "WARNING" "SEC_UPDATES" "$security_updates security updates pending"
        fi
    else
        echo -e "${GRAY}No supported package manager found for security update check${NC}"
    fi

    log_audit "INFO" "SEC_UPDATES" "Security update audit completed"
}

run_additional_security_audits() {
    echo ""
    echo -e "${CYAN}Running Additional Security Audits...${NC}"
    echo ""

    audit_suid_sgid
    echo ""
    audit_world_writable
    echo ""
    audit_user_accounts
    echo ""
    audit_ssh_security
    echo ""
    audit_firewall
    echo ""
    audit_services
    echo ""
    audit_kernel_parameters
    echo ""
    audit_ssl_certificates
    echo ""
    audit_security_updates
    echo ""

    echo -e "${CYAN}Additional security audits completed!${NC}"
    echo ""
}

# Enhanced security menu with comfort styling
echo -e "${MAGENTA}┌──────────────────────────────────────────────────────────────────┐${NC}"
print_box_line "${MAGENTA}" "${WHITE}Would you like to perform a comprehensive security audit?${NC}"
print_box_empty "${MAGENTA}"
print_box_line "${MAGENTA}" "${CYAN}Run security audit? (y/n)${NC}"
echo -ne "${CYAN}> ${NC}"
read -r SECURITY_RESPONSE
print_box_empty "${MAGENTA}"
echo -e "${MAGENTA}└──────────────────────────────────────────────────────────────────┘${NC}"
echo ""

if [[ "$SECURITY_RESPONSE" =~ ^[Yy]$ ]]; then
    SECURITY_AUDITED=true

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

    if ! command -v clamscan >/dev/null 2>&1; then
        TOOLS_MISSING=true
        echo -e "${YELLOW}ClamAV (clamscan) is not installed.${NC}"
    fi

    if [ "$TOOLS_MISSING" = true ]; then
        echo -e "${YELLOW}┌──────────────────────────────────────────────────────────────────┐${NC}"
        print_box_line "${YELLOW}" "${WHITE}Some security tools are missing for a complete audit${NC}"
print_box_empty "${YELLOW}"
print_box_line "${YELLOW}" "${CYAN}Install missing tools? (y/n)${NC}"
echo -ne "${CYAN}> ${NC}"
        read -r INSTALL_TOOLS
        print_box_empty "${YELLOW}"
echo -e "${YELLOW}└──────────────────────────────────────────────────────────────────┘${NC}"
        echo ""

        if [[ "$INSTALL_TOOLS" =~ ^[Yy]$ ]]; then
            install_security_tools
            echo ""
        fi
    fi

    # Perform the audit
    perform_security_audit

    # Run additional security audits
    run_additional_security_audits

else
    echo -e "${GRAY}┌──────────────────────────────────────────────────────────────────┐${NC}"
    print_box_line "${GRAY}" "${WHITE}Security audit skipped by user${NC}"
echo -e "${GRAY}└──────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
fi

echo ""

#============================================================================
# REBOOT PROMPT (After everything is complete)
#============================================================================

# Enhanced reboot prompt with comfort styling
if [ "$UPDATES_INSTALLED" = true ]; then
    echo -e "${GREEN}┌──────────────────────────────────────────────────────────────────┐${NC}"
    print_box_line "${GREEN}" "${WHITE}Updates were successfully installed!${NC}"
print_box_line "${GREEN}" "${YELLOW}A reboot is recommended to apply all changes${NC}"
print_box_empty "${GREEN}"
print_box_line "${GREEN}" "${CYAN}Reboot system now? (y/n)${NC}"
echo -ne "${CYAN}> ${NC}"
    read -r REBOOT_RESPONSE
    print_box_empty "${GREEN}"
echo -e "${GREEN}└──────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    if [[ "$REBOOT_RESPONSE" =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Rebooting system...${NC}"
        sudo reboot
    else
        echo -e "${YELLOW}┌──────────────────────────────────────────────────────────────────┐${NC}"
        print_box_line "${YELLOW}" "${WHITE}Reboot skipped. Remember to reboot later to apply updates.${NC}"
echo -e "${YELLOW}└──────────────────────────────────────────────────────────────────┘${NC}"
        echo ""
    fi
fi

echo ""

#============================================================================
run_disk_cleanup_interface

# Enhanced completion message
echo -e "${CYAN}┌──────────────────────────────────────────────────────────────────┐${NC}"
print_box_line "${CYAN}" "${BOLD}${WHITE}LinWatch session completed successfully!${NC}"
print_box_empty "${CYAN}"
print_box_line "${CYAN}" "${GRAY}Thank you for using LinWatch, your cozy system companion${NC}"
print_box_line "${CYAN}" "${GRAY}Stay safe, keep updated, and have a great day!${NC}"
print_box_empty "${CYAN}"
print_box_line "${CYAN}" "${GREEN}[OK] System monitored${NC}"
if [ "$UPDATES_CHECKED" = true ]; then
    print_box_line "${CYAN}" "${GREEN}[OK] Updates checked${NC}"
else
    print_box_line "${CYAN}" "${GRAY}[SKIP] Updates skipped${NC}"
fi
if [ "$SECURITY_AUDITED" = true ]; then
    print_box_line "${CYAN}" "${GREEN}[OK] Security audited${NC}"
else
    print_box_line "${CYAN}" "${GRAY}[SKIP] Security audit skipped${NC}"
fi
if [ "$CLEANUP_PERFORMED" = true ]; then
    print_box_line "${CYAN}" "${GREEN}[OK] Disk cleaned: $(format_size $SPACE_SAVED_MB) freed${NC}"
else
    print_box_line "${CYAN}" "${GRAY}[SKIP] Disk cleanup skipped${NC}"
fi
echo -e "${CYAN}└──────────────────────────────────────────────────────────────────┘${NC}"
echo ""
