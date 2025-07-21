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
    local ports=("${!5}")

    if [[ $tunnel_type == "6to4" ]]; then
        if [[ $server_type == "iran" ]]; then
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
            commands+=(
                "iptables -t nat -A PREROUTING -j DNAT --to-destination 192.168.168.2"
                "iptables -t nat -A POSTROUTING -j MASQUERADE"
            )
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
        )
        for port in "${ports[@]}"; do
            commands+=("iptables -t nat -A PREROUTING -p tcp --dport $port -j DNAT --to-destination $iran_ip")
        done
        commands+=(
            "iptables -t nat -A PREROUTING -j DNAT --to-destination $foreign_ip"
            "iptables -t nat -A POSTROUTING -j MASQUERADE"
        )
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

    echo -e "\033[92mTunnel installation successful.\033[0m"
}

uninstall_tunnel() {
    local server_type=$1

    if [[ $server_type == "iran" ]]; then
        ip tunnel del 6to4_iran 2>/dev/null
        ip -6 tunnel del GRE6Tun_iran 2>/dev/null
    elif [[ $server_type == "foreign" ]]; then
        ip tunnel del 6to4_Forign 2>/dev/null
        ip -6 tunnel del GRE6Tun_Forign 2>/dev/null
    fi

    iptables -t nat -D PREROUTING -p tcp --dport 22 -j DNAT --to-destination 192.168.168.1 2>/dev/null
    iptables -t nat -D PREROUTING -j DNAT --to-destination 192.168.168.2 2>/dev/null
    iptables -t nat -D POSTROUTING -j MASQUERADE 2>/dev/null
    iptables -D INPUT --proto icmp -j DROP 2>/dev/null

    if [[ -f "/etc/rc.local" ]]; then
        rm -f /etc/rc.local
        echo -e "\033[92mRemoved /etc/rc.local file.\033[0m"
    fi

    echo -e "\033[92mTunnel and related settings uninstalled successfully for server type: $server_type.\033[0m"
}

uninstall_specific_tunnel() {
    echo -e "\033[94mList of existing tunnels:\033[0m"
    ip tunnel show
    read -p $'\033[93mEnter the tunnel name you want to remove (or type "back" to return): \033[0m' tun_name
    if [[ "$tun_name" == "back" ]]; then
        return
    fi

    ip tunnel del "$tun_name" 2>/dev/null
    if [[ $? -eq 0 ]]; then
        echo -e "\033[92mTunnel '$tun_name' removed successfully.\033[0m"
    else
        echo -e "\033[91mFailed to remove tunnel '$tun_name'. It may not exist.\033[0m"
    fi
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
    echo -e "\033[94mTunnel System Installer/Uninstaller\033[0m"
    echo -e "\033[93m-----------------------------------------\033[0m"
    read -p $'\033[93mWhat would you like to do?\n\033[92m1. Install\n\033[91m2. Uninstall\n\033[94m3. Scripts\n\033[0mEnter the number of your choice: ' choice

    if [[ $choice != "1" && $choice != "2" && $choice != "3" ]]; then
        echo -e "\033[91mInvalid action. Please enter '1', '2', or '3'.\033[0m"
        sleep 2
        main_menu
        return
    fi

    if [[ $choice == "1" ]]; then
        install_menu
    elif [[ $choice == "2" ]]; then
        uninstall_menu
    elif [[ $choice == "3" ]]; then
        scripts_menu
    fi
}

install_menu() {
    clear
    echo -e "\033[94mInstall Menu\033[0m"
    echo -e "\033[93m-----------------------------------------\033[0m"
    echo -e "\033[92m1. 6to4\033[0m"
    echo -e "\033[91m2. iptables\033[0m"
    echo -e "\033[90m3. Back\033[0m"
    read -r tunnel_type

    if [[ $tunnel_type != "1" && $tunnel_type != "2" && $tunnel_type != "3" ]]; then
        echo -e "\033[91mInvalid choice. Please enter '1', '2', or '3'.\033[0m"
        sleep 2
        install_menu
        return
    fi

    if [[ $tunnel_type == "3" ]]; then
        main_menu
        return
    fi

    # لیست تونل های موجود با اسم و IP تونل شده نمایش داده میشه
    echo -e "\033[94mAvailable tunnels:\033[0m"
    # مثال ساخت آرایه تونل‌ها (در عمل از جایی بخوانید)
    # format: "name|ip|type"
    tunnels=(
        "iran_tunnel|192.168.168.1|iran"
        "foreign_tunnel|192.168.168.2|foreign"
    )

    echo "Choose server type:"
    for i in "${!tunnels[@]}"; do
        IFS='|' read -r name ip type <<< "${tunnels[$i]}"
        echo "$((i+1)). $name - IP: $ip"
    done
    read -p "Enter the number of your server: " server_choice

    if ! [[ "$server_choice" =~ ^[1-9][0-9]*$ ]] || ((server_choice < 1 || server_choice > ${#tunnels[@]})); then
        echo -e "\033[91mInvalid choice. Please enter a valid number.\033[0m"
        sleep 2
        install_menu
        return
    fi

    IFS='|' read -r name iran_ip foreign_ip <<< "${tunnels[$((server_choice-1))]}"

    # چون نوع سرور تو آرایه داریم، مستقیم مقدار می‌گیریم
    server_type="${tunnels[$((server_choice-1))]}"
    IFS='|' read -r _ _ server_type <<< "${tunnels[$((server_choice-1))]}"

    echo -e "Enter ports separated by space (e.g. 80 443 22):"
    read -a ports

    install_tunnel "$iran_ip" "$foreign_ip" "$server_type" "$tunnel_type" ports[@]

    sleep 3
    main_menu
}

uninstall_menu() {
    clear
    echo -e "\033[94mUninstall Menu\033[0m"
    echo -e "\033[93m-----------------------------------------\033[0m"
    echo -e "\033[92m1. Remove all tunnels\033[0m"
    echo -e "\033[91m2. Remove specific tunnel\033[0m"
    echo -e "\033[90m3. Back\033[0m"
    read -r uninstall_choice

    if [[ $uninstall_choice != "1" && $uninstall_choice != "2" && $uninstall_choice != "3" ]]; then
        echo -e "\033[91mInvalid choice. Please enter '1', '2', or '3'.\033[0m"
        sleep 2
        uninstall_menu
        return
    fi

    if [[ $uninstall_choice == "1" ]]; then
        echo -e "\033[94mAvailable tunnels:\033[0m"
        tunnels=(
            "iran_tunnel|192.168.168.1|iran"
            "foreign_tunnel|192.168.168.2|foreign"
        )
        for i in "${!tunnels[@]}"; do
            IFS='|' read -r name ip type <<< "${tunnels[$i]}"
            echo "$((i+1)). $name - IP: $ip"
        done
        read -p "Enter the number of your server: " server_choice

        if ! [[ "$server_choice" =~ ^[1-9][0-9]*$ ]] || ((server_choice < 1 || server_choice > ${#tunnels[@]})); then
            echo -e "\033[91mInvalid choice. Please enter a valid number.\033[0m"
            sleep 2
            uninstall_menu
            return
        fi

        IFS='|' read -r _ _ server_type <<< "${tunnels[$((server_choice-1))]}"
        uninstall_tunnel "$server_type"
        sleep 3
        main_menu
    elif [[ $uninstall_choice == "2" ]]; then
        uninstall_specific_tunnel
        sleep 3
        main_menu
    elif [[ $uninstall_choice == "3" ]]; then
        main_menu
    fi
}

scripts_menu() {
    clear
    echo -e "\033[94mScripts Menu\033[0m"
    echo -e "\033[93m-----------------------------------------\033[0m"
    echo -e "1. Sanaei Script"
    echo -e "2. Alireza Script"
    echo -e "3. Ghost Script"
    echo -e "4. PfTun Script"
    echo -e "5. Reverse Script"
    echo -e "6. ISP Blocker Script"
    echo -e "7. Back"
    read -p "Enter your choice: " script_choice

    case $script_choice in
        1) install_sanaie_script ;;
        2) install_alireza_script ;;
        3) install_ghost_script ;;
        4) install_pftun_script ;;
        5) install_reverse_script ;;
        6) install_ispblocker_script ;;
        7) main_menu ;;
        *) echo -e "\033[91mInvalid choice.\033[0m"; sleep 2; scripts_menu ;;
    esac

    sleep 3
    main_menu
}

main_menu
