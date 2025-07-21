#!/bin/bash

function get_current_ip() {
    local current_ip
    current_ip=$(curl -s https://api.ipify.org)
    echo "$current_ip"
}

install_tunnel() {
    local iran_ip=$1
    local foreign_ip=$2
    local server_type=$3
    local tunnel_type=$4

    if [[ $tunnel_type == "6to4" ]]; then
        if [[ $server_type == "iran" ]]; then
            echo -e "\033[93mEnter comma-separated list of ports to forward (e.g., 22,443,80):\033[0m"
            read -r port_list
            IFS=',' read -ra ports <<< "$port_list"

            commands=(
                "ip tunnel add 6to4_iran mode sit remote $foreign_ip local $iran_ip"
                "ip -6 addr add 2002:a00:100::1/64 dev 6to4_iran"
                "ip link set 6to4_iran mtu 1480"
                "ip link set 6to4_iran up"
                "ip -6 tunnel add GRE6Tun_iran mode ip6gre remote 2002:a00:100::2 local 2002:a00:100::1"
                "ip addr add 192.168.168.1/30 dev GRE6Tun_iran"
                "ip link set GRE6Tun_iran mtu 1436"
                "ip link set GRE6Tun_iran up"
                "sysctl net.ipv4.ip_forward=1"
            )

            for port in "${ports[@]}"; do
                commands+=("iptables -t nat -A PREROUTING -p tcp --dport $port -j DNAT --to-destination 192.168.168.1")
            done

            commands+=("iptables -t nat -A POSTROUTING -j MASQUERADE")

        elif [[ $server_type == "foreign" ]]; then
            commands=(
                "ip tunnel add 6to4_Forign mode sit remote $iran_ip local $foreign_ip"
                "ip -6 addr add 2002:a00:100::2/64 dev 6to4_Forign"
                "ip link set 6to4_Forign mtu 1480"
                "ip link set 6to4_Forign up"
                "ip -6 tunnel add GRE6Tun_Forign mode ip6gre remote 2002:a00:100::1 local 2002:a00:100::2"
                "ip addr add 192.168.168.2/30 dev GRE6Tun_Forign"
                "ip link set GRE6Tun_Forign mtu 1436"
                "ip link set GRE6Tun_Forign up"
                "iptables -A INPUT --proto icmp -j DROP"
            )
        fi
    elif [[ $tunnel_type == "iptables" ]]; then
        commands=(
            "sysctl net.ipv4.ip_forward=1"
            "iptables -t nat -A PREROUTING -p tcp --dport 22 -j DNAT --to-destination $iran_ip"
            "iptables -t nat -A PREROUTING -j DNAT --to-destination $foreign_ip"
            "iptables -t nat -A POSTROUTING -j MASQUERADE"
        )
    fi

    for command in "${commands[@]}"; do
        eval "$command"
    done

    if [[ -f "/etc/rc.local" ]]; then
        read -p "File /etc/rc.local already exists. Overwrite? (y/n): " overwrite
        [[ "$overwrite" != "y" && "$overwrite" != "yes" ]] && echo "Stopped." && sleep 2 && return
    fi

    echo "#! /bin/bash" > /etc/rc.local
    for command in "${commands[@]}"; do
        echo "$command" >> /etc/rc.local
    done
    echo "exit 0" >> /etc/rc.local
    chmod +x /etc/rc.local

    echo -e "\033[92m✅ Tunnel installation completed.\033[0m"
}

uninstall_tunnel() {
    local server_type=$1

    if [[ $server_type == "iran" ]]; then
        ip link delete 6to4_iran 2>/dev/null
        ip link delete GRE6Tun_iran 2>/dev/null
    elif [[ $server_type == "foreign" ]]; then
        ip link delete 6to4_Forign 2>/dev/null
        ip link delete GRE6Tun_Forign 2>/dev/null
    fi

    iptables -t nat -F
    iptables -F

    [[ -f /etc/rc.local ]] && rm /etc/rc.local

    echo -e "\033[92m✅ Tunnel for $server_type removed.\033[0m"
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

    echo -e "\033[93mEnter number of tunnel to delete (or leave empty):\033[0m"
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
    echo -e "\033[92m✅ '$selected_tunnel' deleted.\033[0m" || \
    echo -e "\033[91m❌ Failed to delete '$selected_tunnel'.\033[0m"

    sleep 2
    main_menu
}

install_sanaie_script() {
    bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
}

install_alireza_script() {
    bash <(curl -Ls https://raw.githubusercontent.com/alireza0/x-ui/master/install.sh)
}

install_ghost_script() {
    bash <(curl -Ls https://github.com/masoudgb/Gost-ip6/raw/main/Gost.sh)
}

install_pftun_script() {
    bash <(curl -s https://raw.githubusercontent.com/opiran-club/pf-tun/main/pf-tun.sh --ipv4)
}

install_reverse_script() {
    bash <(curl -fsSL https://raw.githubusercontent.com/Ptechgithub/ReverseTlsTunnel/main/RtTunnel.sh)
}

install_ispblocker_script() {
    bash <(curl -s https://raw.githubusercontent.com/Kiya6955/IR-ISP-Blocker/main/ir-isp-blocker.sh)
}

main_menu() {
    clear
    echo -e "\033[94m🚀 Tunnel Manager\033[0m"
    echo -e "\033[92m1. Install\033[0m"
    echo -e "\033[91m2. Uninstall\033[0m"
    echo -e "\033[94m3. Scripts\033[0m"
    echo -e "\033[95m4. List/Delete Tunnels\033[0m"
    read -p $'\033[93mChoose: \033[0m' choice

    case $choice in
        1) install_menu ;;
        2) uninstall_menu ;;
        3) scripts_menu ;;
        4) list_tunnels_menu ;;
        *) echo -e "\033[91m❌ Invalid.\033[0m"; sleep 2; main_menu ;;
    esac
}

install_menu() {
    clear
    echo -e "\033[94m🛠️ Install Menu\033[0m"
    echo -e "\033[92m1. 6to4"
    echo -e "\033[91m2. iptables"
    echo -e "\033[90m3. Back\033[0m"
    read -r tunnel_type

    case $tunnel_type in
        1) tunnel_type="6to4" ;;
        2) tunnel_type="iptables" ;;
        3) main_menu; return ;;
        *) echo -e "\033[91mInvalid.\033[0m"; return ;;
    esac

    echo -e "\033[93mSelect server:\n\033[92m1. Iran\n\033[91m2. Foreign\n\033[90m3. Back\033[0m"
    read -r server_type

    case $server_type in
        1)
            server_type="iran"
            iran_ip=$(get_current_ip)
            echo -e "\033[93mIran IP: $iran_ip\033[0m"
            read -p $'\033[93mEnter Foreign IP: \033[0m' foreign_ip
            ;;
        2)
            server_type="foreign"
            foreign_ip=$(get_current_ip)
            echo -e "\033[93mForeign IP: $foreign_ip\033[0m"
            read -p $'\033[93mEnter Iran IP: \033[0m' iran_ip
            ;;
        3) install_menu; return ;;
        *) echo -e "\033[91mInvalid.\033[0m"; return ;;
    esac

    install_tunnel "$iran_ip" "$foreign_ip" "$server_type" "$tunnel_type"
    main_menu
}

uninstall_menu() {
    clear
    echo -e "\033[94m🗑️ Uninstall Menu\033[0m"
    echo -e "\033[92m1. Iran"
    echo -e "\033[91m2. Foreign"
    echo -e "\033[90m3. Back\033[0m"
    read -r server_type

    case $server_type in
        1) uninstall_tunnel "iran" ;;
        2) uninstall_tunnel "foreign" ;;
        3) main_menu; return ;;
        *) echo -e "\033[91mInvalid.\033[0m"; return ;;
    esac
    main_menu
}

scripts_menu() {
    clear
    echo -e "\033[94m🧩 Scripts Menu\033[0m"
    echo -e "\033[92m1. Sanaie"
    echo -e "\033[34m2. Alireza"
    echo -e "\033[36m3. Ghost"
    echo -e "\033[33m4. PFTUN"
    echo -e "\033[35m5. Reverse"
    echo -e "\033[34m6. ISP Blocker"
    echo -e "\033[90m7. Back\033[0m"
    read -p $'\033[93mChoose: \033[0m' script_choice

    case $script_choice in
        1) install_sanaie_script ;;
        2) install_alireza_script ;;
        3) install_ghost_script ;;
        4) install_pftun_script ;;
        5) install_reverse_script ;;
        6) install_ispblocker_script ;;
        7) main_menu; return ;;
        *) echo -e "\033[91mInvalid.\033[0m" ;;
    esac
    main_menu
}

main_menu
