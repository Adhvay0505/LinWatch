#!/bin/bash

# Check if Zenity is installed
if ! command -v zenity >/dev/null 2>&1; then
    echo "Zenity is not installed. Please install it (e.g., sudo apt install zenity)"
    exit 1
fi

#########################
# Show Header Branding with bold, centered title simulation
#########################
# Add newlines before and after to simulate vertical centering

zenity --info --title="LinWatch" --width=400 --height=150 \
    --text="\n\n<b>$TITLE</b>\n\nA Linux System Information Utility"

#########################
# Gather system information
#########################
kernel=$(uname -r)
cpu=$(lscpu | grep "Model name" | awk -F ':' '{print $2}' | xargs)
arch=$(lscpu | grep "^Architecture" | awk '{print $2}')
cpu_count=$(lscpu | grep "^CPU(s):" | awk '{print $2}')
cpu_summary="Kernel: <b>$kernel</b>
Arch: $arch
CPUs: $cpu_count
CPU Model: $cpu"

read -r total used free shared buff_cache avail <<< $(free -h | awk '/^Mem:/ {print $2, $3, $4, $5, $6, $7}')
used_percent=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2 * 100}')
ram_summary="RAM Used: <b>${used} / ${total}</b>
Free: $free (${used_percent}% used)"

read -r dsize dused davail dperc <<< $(df -h / | awk 'NR==2 {print $2, $3, $4, $5}')
disk_summary="Disk Used: <b>${dused} / ${dsize}</b>
Free: $davail (${dperc} used)"

upt=$(uptime -p)
uptime_summary="Uptime: <b>$upt</b>"

ip4=$(ip a | awk '/inet / && $2 !~ /^127/ {sub("/.*", "", $2); print $2; exit}')
ip6=$(ip a | awk '/inet6 / && $2 !~ /^::1/ {sub("/.*", "", $2); print $2; exit}')
public_ip="(unknown)"
if command -v curl >/dev/null 2>&1; then
    public_ip=$(curl -s https://api.ipify.org)
fi
net_summary="LAN IP: <b>$ip4</b>
IPv6: $ip6
Public IP: $public_ip"

logged_users=$(who | awk '{print $1 "@" $2}' | tr '\n' '\n')
cur_user=$(whoami)
user_summary="Current User: <b>$cur_user</b>
Logged in: $logged_users"

DISTRO=$(awk -F= '/^ID=/{print $2}' /etc/os-release | tr -d ' "')
distro_summary="Detected Distro: <b>$DISTRO</b>"

#########################
# Function to get last update date/time based on package manager
#########################
get_last_update() {
    if command -v apt >/dev/null 2>&1; then
        date=$(grep -i "Start-Date" /var/log/apt/history.log | tail -1 | cut -d ' ' -f2-)
        echo "APT Last Update: <b>${date:-No Record}</b>"
    elif command -v dnf >/dev/null 2>&1; then
        date=$(grep "Updated:" /var/log/dnf.rpm.log | tail -1)
        echo "DNF Last Update: <b>${date:-No Record}</b>"
    elif command -v yum >/dev/null 2>&1; then
        date=$(grep Updated /var/log/yum.log | tail -1)
        echo "YUM Last Update: <b>${date:-No Record}</b>"
    elif command -v pacman >/dev/null 2>&1; then
        date=$(grep -i upgraded /var/log/pacman.log | tail -1)
        echo "Pacman Last Update: <b>${date:-No Record}</b>"
    elif command -v zypper >/dev/null 2>&1; then
        date=$(grep -iE "install|update" /var/log/zypp/history | tail -1)
        echo "Zypper Last Update: <b>${date:-No Record}</b>"
    elif command -v apk >/dev/null 2>&1; then
        date=$(grep -i "apk" ~/.ash_history 2>/dev/null | tail -1)
        echo "APK Last Update: <b>${date:-No Record}</b>"
    elif command -v snap >/dev/null 2>&1; then
        date=$(snap list --all | grep -i installed | tail -1)
        echo "Snap Last Update: <b>${date:-No Record}</b>"
    elif command -v emerge >/dev/null 2>&1; then
        date=$(tail -1 /var/log/emerge.log)
        echo "Emerge Last Update: <b>${date:-No Record}</b>"
    else
        echo "Package manager not recognized"
    fi
}
last_update_summary=$(get_last_update)

#########################
# Show Main Summary dialog
#########################
zenity --info --title="LinWatch \u2013 System Summary" --width=480 --height=460 --text="
$cpu_summary

$ram_summary

$disk_summary

$uptime_summary

$net_summary

$user_summary

$distro_summary

$last_update_summary
" --no-wrap

#########################
# Update check and install logic
#########################
if zenity --question --title="LinWatch \u2013 Updates" --width=330 \
    --text="Would you like to check for available system updates?"; then

    updates_available=false
    update_list=""

    if command -v apt >/dev/null 2>&1; then
        zenity --info --no-wrap --title="LinWatch" --text="Checking for APT package updates..."
        sudo apt update -qq
        UPGRADABLE=$(apt list --upgradable 2>/dev/null | grep -v "Listing" | wc -l)
        if [ "$UPGRADABLE" -gt 0 ]; then
            updates_available=true
            update_list=$(apt list --upgradable 2>/dev/null | grep -v "Listing" | cut -d/ -f1 | xargs)
        fi
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf check-update > /tmp/dnf_update 2>&1
        if [ $? -eq 100 ]; then
            updates_available=true
            update_list=$(awk '{print $1}' /tmp/dnf_update | grep -E '^[a-zA-Z0-9_.-]+' | xargs)
        fi
    elif command -v yum >/dev/null 2>&1; then
        sudo yum check-update > /tmp/yum_update 2>&1
        if [ $? -eq 100 ]; then
            updates_available=true
            update_list=$(awk '{print $1}' /tmp/yum_update | grep -E '^[a-zA-Z0-9_.-]+' | xargs)
        fi
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Sy --noconfirm > /dev/null 2>&1
        UPGRADABLE=$(pacman -Qu | wc -l)
        if [ "$UPGRADABLE" -gt 0 ]; then
            updates_available=true
            update_list=$(pacman -Qu | awk '{print $1}' | xargs)
        fi
    elif command -v zypper >/dev/null 2>&1; then
        sudo zypper refresh > /dev/null 2>&1
        UPGRADABLE=$(zypper lu | grep -c '^v')
        if [ "$UPGRADABLE" -gt 0 ]; then
            updates_available=true
            update_list=$(zypper lu | grep '^v' | awk '{print $3}' | xargs)
        fi
    elif command -v apk >/dev/null 2>&1; then
        sudo apk update >/dev/null 2>&1
        updates_available=true
        update_list="(Check terminal for details. Run 'apk upgrade' to install.)"
    elif command -v emerge >/dev/null 2>&1; then
        sudo emerge --sync > /dev/null 2>&1
        updates_available=true
        update_list="(Gentoo: Please check manually with 'emerge -uDNav @world')"
    else
        zenity --error --title="LinWatch" --text="No supported package manager found."
    fi

    if [ "$updates_available" = true ]; then
        zenity --info --title="Updates Found" --no-wrap \
            --text="Available updates:\n$update_list"
        if zenity --question --title="Install Updates?" --text="Would you like to install all available updates now?"; then
            if command -v apt >/dev/null 2>&1; then
                zenity --info --text="Upgrading packages (APT)..."
                sudo apt upgrade -y | zenity --progress --pulsate --auto-close --title="Upgrading..."
            elif command -v dnf >/dev/null 2>&1; then
                sudo dnf upgrade -y | zenity --progress --pulsate --auto-close --title="Upgrading..."
            elif command -v yum >/dev/null 2>&1; then
                sudo yum update -y | zenity --progress --pulsate --auto-close --title="Upgrading..."
            elif command -v pacman >/dev/null 2>&1; then
                sudo pacman -Syu --noconfirm | zenity --progress --pulsate --auto-close --title="Upgrading..."
            elif command -v zypper >/dev/null 2>&1; then
                sudo zypper update -y | zenity --progress --pulsate --auto-close --title="Upgrading..."
            elif command -v apk >/dev/null 2>&1; then
                sudo apk upgrade | zenity --progress --pulsate --auto-close --title="Upgrading..."
            elif command -v emerge >/dev/null 2>&1; then
                zenity --warning --text="Gentoo users: Please upgrade manually."
            fi

            # Ask for reboot after upgrades
            if zenity --question --title="Reboot" --text="Install complete. Reboot now?"; then
                zenity --info --text="Rebooting..."
                sudo reboot
            else
                zenity --info --text="Reboot skipped."
            fi
        else
            zenity --info --title="LinWatch" --text="Update installation skipped."
        fi
    else
        zenity --info --title="LinWatch" --text="System is already up to date."
    fi
else
    zenity --info --title="LinWatch" --text="Update check skipped."
fi

exit 0

