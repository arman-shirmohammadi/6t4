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
    local port_list=$5

    IFS=',' read -ra ports <<< "$port_list"

    if [[ $tunnel_type == "6to4" ]]; then
        if [[ $server_type == "iran" ]]; then
            commands=(
                "ip tunnel add 6to4_iran mode sit remote $foreign_ip local $iran_ip",
                "ip -6 addr add 2002:a00:100::1/64 dev 6to4_iran",
                "ip link set 6to4_iran mtu 1480",
                "ip link set 6to4_iran up",
                "ip -6 tunnel add GRE6Tun_iran mode ip6gre remote 2002:a00:100::2 local 2002:a00:100::1",
                "ip addr add 192.168.168.1/30 dev GRE6Tun_iran",
                "ip link set GRE6Tun_iran mtu 1436",
                "ip link set GRE6Tun_iran up",
                "sysctl net.ipv4.ip_forward=1"
            )
            for port in "${ports[@]}"; do
                commands+=("iptables -t nat -A PREROUTING -p tcp --dport $port -j DNAT --to-destination 192.168.168.1")
            done
            commands+=("iptables -t nat -A POSTROUTING -j MASQUERADE")

        elif [[ $server_type == "foreign" ]]; then
            commands=(
                "ip tunnel add 6to4_Forign mode sit remote $iran_ip local $foreign_ip",
                "ip -6 addr add 2002:a00:100::2/64 dev 6to4_Forign",
                "ip link set 6to4_Forign mtu 1480",
                "ip link set 6to4_Forign up",
                "ip -6 tunnel add GRE6Tun_Forign mode ip6gre remote 2002:a00:100::1 local 2002:a00:100::2",
                "ip addr add 192.168.168.2/30 dev GRE6Tun_Forign",
                "ip link set GRE6Tun_Forign mtu 1436",
                "ip link set GRE6Tun_Forign up",
                "iptables -A INPUT --proto icmp -j DROP"
            )
            for port in "${ports[@]}"; do
                commands+=("iptables -t nat -A PREROUTING -p tcp --dport $port -j DNAT --to-destination 192.168.168.2")
            done
            commands+=("iptables -t nat -A POSTROUTING -j MASQUERADE")
        fi
    fi

    for command in "${commands[@]}"; do
        eval "$command"
    done

    if [[ -f "/etc/rc.local" ]]; then
        read -p "File /etc/rc.local already exists. Do you want to overwrite it? (y/n): " overwrite
        if [[ $overwrite != "y" && $overwrite != "yes" ]]; then
            echo "Stopped process."
            sleep 5
            return
        fi
    fi

    echo "#! /bin/bash" > /etc/rc.local
    for command in "${commands[@]}"; do
        echo "$command" >> /etc/rc.local
    done
    echo "exit 0" >> /etc/rc.local
    chmod +x /etc/rc.local

    echo -e "\033[92mSuccessful\033[0m"
}

install_menu() {
    clear
    echo -e "\033[94mInstall Menu\033[0m"
    echo -e "\033[93m-----------------------------------------\033[0m"
    echo -e "\033[92m1. 6to4\033[0m"
    echo -e "\033[91m2. Back\033[0m"
    read -r tunnel_type

    if [[ $tunnel_type == "1" ]]; then
        tunnel_type="6to4"
    elif [[ $tunnel_type == "2" ]]; then
        main_menu
        return
    else
        echo -e "\033[91mInvalid tunnel type.\033[0m"
        return
    fi

    echo -e "\033[93mSelect your server type:\n\033[92m1. Iran\033[0m\n\033[91m2. Foreign\033[0m\n\033[90m3. Back\033[0m"
    read -r server_type

    if [[ $server_type == "1" ]]; then
        server_type="iran"
        iran_ip=$(get_current_ip)
        echo -e "\033[93mIran server IP address: $iran_ip\033[0m"
        read -p $'\033[93mEnter Foreign server IP address: \033[0m' foreign_ip
    elif [[ $server_type == "2" ]]; then
        server_type="foreign"
        foreign_ip=$(get_current_ip)
        echo -e "\033[93mForeign server IP address: $foreign_ip\033[0m"
        read -p $'\033[93mEnter Iran server IP address: \033[0m' iran_ip
    elif [[ $server_type == "3" ]]; then
        main_menu
        return
    else
        echo -e "\033[91mInvalid server type.\033[0m"
        return
    fi

    read -p $'\033[93mEnter comma-separated list of ports (e.g. 22,443,80): \033[0m' port_list

    install_tunnel "$iran_ip" "$foreign_ip" "$server_type" "$tunnel_type" "$port_list"
    main_menu
}

main_menu() {
    clear
    echo -e "\033[94mTunnel System Installer\033[0m"
    echo -e "\033[93m-----------------------------------------\033[0m"
    echo -e "\033[92m1. Install\033[0m"
    echo -e "\033[91m2. Exit\033[0m"
    read -p "Enter your choice: " choice

    case $choice in
        1) install_menu ;;
        2) exit ;;
        *) echo -e "\033[91mInvalid choice.\033[0m" ;;
    esac
}

main_menu
