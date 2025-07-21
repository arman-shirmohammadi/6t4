#!/bin/bash

# Function to detect local IP (Iran) and foreign IP
get_ips() {
    local_ip=$(curl -s --max-time 4 https://ifconfig.me)
    foreign_ip=$(curl -s --max-time 4 https://api.ipify.org)

    [[ -z "$local_ip" ]] && local_ip="Not Detected"
    [[ -z "$foreign_ip" ]] && foreign_ip="Not Detected"

    echo -e "\033[92mDetected Local IP: $local_ip\033[0m"
    echo -e "\033[96mDetected Foreign IP: $foreign_ip\033[0m"
}

# Function to show existing tunnels
list_tunnels() {
    echo -e "\033[94mAvailable tunnels:\033[0m"
    ip -6 tunnel show | awk '{print $1}' | while read line; do
        ip_address=$(ip -6 addr show dev "$line" | grep -oP 'inet6 \K[\da-f:]+')
        echo -e "Tunnel: $line - IP: ${ip_address:-Not Assigned}"
    done
    echo
    read -p "Press Enter to return..."
}

# Function to install a tunnel (simplified example)
install_tunnel() {
    read -p "Enter Tunnel Name: " tunnel_name
    read -p "Enter Local IPv6 Address (e.g., 2001:470:1f0b:xxxx::2): " ipv6_addr
    read -p "Enter Remote IPv4 (Tunnel Server IP): " remote_ip

    ip tunnel add "$tunnel_name" mode sit remote "$remote_ip" ttl 255
    ip link set "$tunnel_name" up
    ip -6 addr add "$ipv6_addr" dev "$tunnel_name"
    ip -6 route add ::/0 dev "$tunnel_name"

    echo -e "\033[92mTunnel $tunnel_name installed successfully.\033[0m"
    sleep 1
}

# Function to uninstall all tunnels
uninstall_all_tunnels() {
    echo -e "\033[91mRemoving all tunnels...\033[0m"
    ip -6 tunnel show | awk '{print $1}' | while read tun; do
        ip tunnel del "$tun" 2>/dev/null && echo "Deleted tunnel: $tun"
    done
    rm -f /etc/rc.local
    echo -e "\033[92mAll tunnels removed and /etc/rc.local deleted.\033[0m"
    sleep 2
}

# Function to uninstall specific tunnel
uninstall_specific_tunnel() {
    echo -e "\033[93mExisting tunnels:\033[0m"
    tunnels=( $(ip -6 tunnel show | awk '{print $1}') )
    select tun in "${tunnels[@]}" "Back"; do
        if [[ "$tun" == "Back" ]]; then return; fi
        if [[ -n "$tun" ]]; then
            ip tunnel del "$tun" && echo -e "\033[92mTunnel $tun deleted.\033[0m"
            break
        fi
    done
    sleep 1
}

# Main menu function
main_menu() {
    while true; do
        clear
        echo -e "\033[94m====== 6to4 Tunnel Manager ======\033[0m"
        get_ips
        echo -e "\n1. Install Tunnel"
        echo -e "2. Uninstall Specific Tunnel"
        echo -e "3. Uninstall All Tunnels"
        echo -e "4. List Existing Tunnels"
        echo -e "5. Exit"
        read -p "Enter choice: " choice
        case $choice in
            1) install_tunnel ;;
            2) uninstall_specific_tunnel ;;
            3) uninstall_all_tunnels ;;
            4) list_tunnels ;;
            5) exit 0 ;;
            *) echo -e "\033[91mInvalid choice.\033[0m"; sleep 1 ;;
        esac
    done
}

main_menu
