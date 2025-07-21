#!/bin/bash

create_tunnel() {
    clear
    echo -e "\033[92m🌐 Create 6to4 Tunnel\033[0m"

    echo -e "\033[93mEnter local IPv4 address (e.g., Iran server):\033[0m"
    read -r local_ip
    [[ -z "$local_ip" ]] && { echo -e "\033[91m❌ Local IP cannot be empty.\033[0m"; sleep 2; main_menu; return; }

    echo -e "\033[93mEnter remote IPv4 address (e.g., Foreign server):\033[0m"
    read -r remote_ip
    [[ -z "$remote_ip" ]] && { echo -e "\033[91m❌ Remote IP cannot be empty.\033[0m"; sleep 2; main_menu; return; }

    echo -e "\033[93mEnter tunnel name (e.g., 6to4_foreign):\033[0m"
    read -r tunnel_name
    [[ -z "$tunnel_name" ]] && { echo -e "\033[91m❌ Tunnel name cannot be empty.\033[0m"; sleep 2; main_menu; return; }

    echo -e "\033[93mEnter list of ports to forward (comma-separated, e.g., 22,443,8080):\033[0m"
    read -r port_list
    [[ -z "$port_list" ]] && { echo -e "\033[91m❌ Port list cannot be empty.\033[0m"; sleep 2; main_menu; return; }

    ip tunnel add "$tunnel_name" mode sit local "$local_ip" remote "$remote_ip" ttl 255
    ip link set "$tunnel_name" up
    ip addr add 2002:$(printf '%02X%02X:%02X%02X' ${local_ip//./ })::1/64 dev "$tunnel_name"
    
    echo -e "\033[92m✅ Tunnel '$tunnel_name' created.\033[0m"

    for port in $(echo "$port_list" | tr ',' ' '); do
        ip6tables -A FORWARD -p tcp --dport "$port" -j ACCEPT
        ip6tables -A FORWARD -p udp --dport "$port" -j ACCEPT
    done

    echo -e "\033[92m✅ Ports forwarded: $port_list\033[0m"
    sleep 2
    main_menu
}

list_tunnels_menu() {
    clear
    echo -e "\033[94m📋 Existing Tunnels\033[0m"

    local tunnels=()
    local count=1

    while IFS= read -r line; do
        name=$(echo "$line" | awk '{print $1}' | sed 's/://')
        [[ "$name" == "sit0" || -z "$name" ]] && continue
        ip_info=$(ip tunnel show "$name" | grep -oP "remote \K\S+")
        label="$name"
        [[ -n "$ip_info" ]] && label="$name ($ip_info)"
        tunnels+=("$name")
        echo -e "$count) $label"
        ((count++))
    done < <(ip tunnel show)

    if [[ ${#tunnels[@]} -eq 0 ]]; then
        echo -e "\033[93m⚠️ No active tunnels found.\033[0m"
        sleep 2
        main_menu
        return
    fi

    echo -e "\033[93mEnter the number of the tunnel you want to delete (or leave empty to cancel):\033[0m"
    read -r delete_index

    if [[ -z "$delete_index" ]]; then
        echo -e "\033[93m⚠️ No tunnel deleted.\033[0m"
        sleep 2
        main_menu
        return
    fi

    if ! [[ "$delete_index" =~ ^[0-9]+$ ]] || ((delete_index < 1 || delete_index > ${#tunnels[@]})); then
        echo -e "\033[91m❌ Invalid selection.\033[0m"
        sleep 2
        main_menu
        return
    fi

    selected_tunnel="${tunnels[$((delete_index-1))]}"
    ip link delete "$selected_tunnel" 2>/dev/null && \
    echo -e "\033[92m✅ Tunnel '$selected_tunnel' deleted successfully.\033[0m" || \
    echo -e "\033[91m❌ Failed to delete '$selected_tunnel'.\033[0m"

    sleep 2
    main_menu
}

main_menu() {
    clear
    echo -e "\033[96m===== 6to4 Tunnel Manager =====\033[0m"
    echo "1) ➕ Create Tunnel"
    echo "2) ❌ Delete Tunnel"
    echo "3) 🚪 Exit"
    echo -n "Select an option: "
    read -r option

    case "$option" in
        1) create_tunnel ;;
        2) list_tunnels_menu ;;
        3) exit 0 ;;
        *) echo -e "\033[91m❌ Invalid option!\033[0m"; sleep 1; main_menu ;;
    esac
}

main_menu
