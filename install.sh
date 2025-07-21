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
            commands=(
                "ip tunnel add 6to4_iran mode sit remote $foreign_ip local $iran_ip ttl 255"
                "ip -6 addr add 2002:a00:100::1/64 dev 6to4_iran"
                "ip link set 6to4_iran mtu 1480"
                "ip link set 6to4_iran up"
                "ip -6 tunnel add GRE6Tun_iran mode ip6gre remote 2002:a00:100::2 local 2002:a00:100::1 ttl 255"
                "ip addr add 192.168.168.1/30 dev GRE6Tun_iran"
                "ip link set GRE6Tun_iran mtu 1436"
                "ip link set GRE6Tun_iran up"
                "sysctl -w net.ipv4.ip_forward=1"
                "iptables -t nat -A PREROUTING -p tcp --dport 22 -j DNAT --to-destination 192.168.168.1"
                "iptables -t nat -A PREROUTING -j DNAT --to-destination 192.168.168.2"
                "iptables -t nat -A POSTROUTING -j MASQUERADE"
            )
        elif [[ $server_type == "foreign" ]]; then
            commands=(
                "ip tunnel add 6to4_foreign mode sit remote $iran_ip local $foreign_ip ttl 255"
                "ip -6 addr add 2002:a00:100::2/64 dev 6to4_foreign"
                "ip link set 6to4_foreign mtu 1480"
                "ip link set 6to4_foreign up"
                "ip -6 tunnel add GRE6Tun_foreign mode ip6gre remote 2002:a00:100::1 local 2002:a00:100::2 ttl 255"
                "ip addr add 192.168.168.2/30 dev GRE6Tun_foreign"
                "ip link set GRE6Tun_foreign mtu 1436"
                "ip link set GRE6Tun_foreign up"
                "iptables -A INPUT -p icmp -j DROP"
            )
        fi
    elif [[ $tunnel_type == "iptables" ]]; then
        commands=(
            "sysctl -w net.ipv4.ip_forward=1"
            "iptables -t nat -A PREROUTING -p tcp --dport 22 -j DNAT --to-destination $iran_ip"
            "iptables -t nat -A PREROUTING -j DNAT --to-destination $foreign_ip"
            "iptables -t nat -A POSTROUTING -j MASQUERADE"
        )
    fi

    for command in "${commands[@]}"; do
        echo "Running: $command"
        eval "$command"
        if [[ $? -ne 0 ]]; then
            echo -e "\033[91mError running command: $command\033[0m"
            return 1
        fi
    done

    if [[ -f "/etc/rc.local" ]]; then
        read -p "File /etc/rc.local already exists. Do you want to overwrite it? (y/n): " overwrite
        if [[ $overwrite != "y" && $overwrite != "yes" ]]; then
            echo "Stopped process."
            sleep 5
            return
        fi
    fi

    echo "#!/bin/bash" > /etc/rc.local
    for command in "${commands[@]}"; do
        echo "$command" >> /etc/rc.local
    done
    echo "exit 0" >> /etc/rc.local
    chmod +x /etc/rc.local

    echo -e "\033[92mInstallation successful.\033[0m"
}

uninstall_tunnel() {
    local server_type=$1

    if [[ -f /etc/rc.local ]]; then
        rm -f /etc/rc.local
        echo -e "\033[92mUninstalled successfully.\033[0m"
    else
        echo -e "\033[93mNo /etc/rc.local file found to remove.\033[0m"
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
    while true; do
        clear
        echo -e "\033[94mTunnel System Installer/Uninstaller\033[0m"
        echo -e "\033[93m-----------------------------------------\033[0m"
        echo -e "\033[92m1. Install"
        echo -e "\033[91m2. Uninstall"
        echo -e "\033[94m3. Scripts"
        echo -e "\033[90m4. Exit\033[0m"
        read -p $'\033[93mWhat would you like to do? Enter the number: \033[0m' choice

        case $choice in
            1) install_menu ;;
            2) uninstall_menu ;;
            3) scripts_menu ;;
            4) echo "Exiting..."; exit 0 ;;
            *) echo -e "\033[91mInvalid choice. Please enter a valid number.\033[0m"; sleep 2 ;;
        esac
    done
}

install_menu() {
    while true; do
        clear
        echo -e "\033[94mInstall Menu\033[0m"
        echo -e "\033[93m-----------------------------------------\033[0m"
        echo -e "\033[92m1. 6to4"
        echo -e "\033[91m2. iptables"
        echo -e "\033[90m3. Back\033[0m"
        read -p $'\033[93mSelect tunnel type (1-3): \033[0m' tunnel_choice

        case $tunnel_choice in
            1) tunnel_type="6to4";;
            2) tunnel_type="iptables";;
            3) return ;;
            *) echo -e "\033[91mInvalid input. Try again.\033[0m"; sleep 2; continue ;;
        esac

        echo -e "\033[93mSelect your server type:\n\033[92m1. Iran\033[0m\n\033[91m2. Foreign\033[0m\n\033[90m3. Back\033[0m"
        read -p $'\033[93mEnter the number of your server type: \033[0m' server_choice

        case $server_choice in
            1)
                server_type="iran"
                iran_ip=$(get_current_ip)
                echo -e "\033[93mDetected Iran server IP address: $iran_ip\033[0m"
                read -p $'\033[93mEnter Foreign server IP address: \033[0m' foreign_ip
                ;;
            2)
                server_type="foreign"
                foreign_ip=$(get_current_ip)
                echo -e "\033[93mDetected Foreign server IP address: $foreign_ip\033[0m"
                read -p $'\033[93mEnter Iran server IP address: \033[0m' iran_ip
                ;;
            3)
                continue
                ;;
            *)
                echo -e "\033[91mInvalid input. Try again.\033[0m"
                sleep 2
                continue
                ;;
        esac

        install_tunnel "$iran_ip" "$foreign_ip" "$server_type" "$tunnel_type"
        read -p "Press Enter to return to Install Menu..."
    done
}

uninstall_menu() {
    while true; do
        clear
        echo -e "\033[94mUninstall Menu\033[0m"
        echo -e "\033[93m-----------------------------------------\033[0m"
        echo -e "\033[92m1. Iran"
        echo -e "\033[91m2. Foreign"
        echo -e "\033[90m3. Back\033[0m"
        read -p $'\033[93mSelect the server type to uninstall (1-3): \033[0m' uninstall_choice

        case $uninstall_choice in
            1) server_type="iran" ;;
            2) server_type="foreign" ;;
            3) return ;;
            *) echo -e "\033[91mInvalid input. Try again.\033[0m"; sleep 2; continue ;;
        esac

        uninstall_tunnel "$server_type"
        read -p "Press Enter to return to Uninstall Menu..."
    done
}

scripts_menu() {
    while true; do
        clear
        echo -e "\033[94mScripts Menu\033[0m"
        echo -e "\033[93m-----------------------------------------\033[0m"
        echo -e "\033[92m1. Install Sanaie Script"
        echo -e "\033[94m2. Install Alireza Script"
        echo -e "\033[96m3. Install Ghost Script"
        echo -e "\033[93m4. Install PFTUN Script"
        echo -e "\033[95m5. Install Reverse Script"
        echo -e "\033[94m6. Install IR-ISPBLOCKER Script"
        echo -e "\033[90m7. Back\033[0m"
        read -p $'\033[93mEnter the number of your choice: \033[0m' script_choice

        case $script_choice in
            1) install_sanaie_script ;;
            2) install_alireza_script ;;
            3) install_ghost_script ;;
            4) install_pftun_script ;;
            5) install_reverse_script ;;
            6) install_ispblocker_script ;;
            7) return ;;
            *) echo -e "\033[91mInvalid choice. Please enter a number from 1 to 7.\033[0m"; sleep 2 ;;
        esac

        read -p "Press Enter to continue in Scripts Menu..."
    done
}

# Start the main menu
main_menu
