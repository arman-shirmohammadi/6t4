#!/bin/bash

function get_current_ip() {
    curl -s https://api.ipify.org
}

function install_tunnel() {
    local iran_ip=$1
    local foreign_ip=$2
    local server_type=$3
    local tunnel_type=$4

    echo "Installing tunnel type: $tunnel_type on server: $server_type"
    case $tunnel_type in
        6to4)
            if [[ $server_type == iran ]]; then
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
            else
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
            ;;
        sit)
            if [[ $server_type == iran ]]; then
                commands=(
                    "ip tunnel add sit_iran mode sit remote $foreign_ip local $iran_ip ttl 255"
                    "ip link set sit_iran up"
                    "ip addr add 10.0.0.1/24 dev sit_iran"
                    "sysctl -w net.ipv4.ip_forward=1"
                )
            else
                commands=(
                    "ip tunnel add sit_foreign mode sit remote $iran_ip local $foreign_ip ttl 255"
                    "ip link set sit_foreign up"
                    "ip addr add 10.0.0.2/24 dev sit_foreign"
                )
            fi
            ;;
        gre6)
            if [[ $server_type == iran ]]; then
                commands=(
                    "ip -6 tunnel add gre6_iran mode ip6gre remote $foreign_ip local $iran_ip ttl 255"
                    "ip -6 addr add 2001:db8:1::1/64 dev gre6_iran"
                    "ip link set gre6_iran up"
                    "sysctl -w net.ipv6.conf.all.forwarding=1"
                )
            else
                commands=(
                    "ip -6 tunnel add gre6_foreign mode ip6gre remote $iran_ip local $foreign_ip ttl 255"
                    "ip -6 addr add 2001:db8:1::2/64 dev gre6_foreign"
                    "ip link set gre6_foreign up"
                )
            fi
            ;;
        iptables)
            commands=(
                "sysctl -w net.ipv4.ip_forward=1"
                "iptables -t nat -A PREROUTING -p tcp --dport 22 -j DNAT --to-destination $iran_ip"
                "iptables -t nat -A PREROUTING -j DNAT --to-destination $foreign_ip"
                "iptables -t nat -A POSTROUTING -j MASQUERADE"
            )
            ;;
        *)
            echo "Tunnel type $tunnel_type not recognized!"
            return 1
            ;;
    esac

    for cmd in "${commands[@]}"; do
        echo "Running: $cmd"
        eval "$cmd"
        if [[ $? -ne 0 ]]; then
            echo -e "\033[91mError executing: $cmd\033[0m"
            return 1
        fi
    done

    # Save commands to /etc/rc.local
    echo "#!/bin/bash" > /etc/rc.local
    for cmd in "${commands[@]}"; do
        echo "$cmd" >> /etc/rc.local
    done
    echo "exit 0" >> /etc/rc.local
    chmod +x /etc/rc.local

    echo -e "\033[92mTunnel installed successfully.\033[0m"
}

uninstall_tunnel() {
    if [[ -f /etc/rc.local ]]; then
        rm -f /etc/rc.local
        echo -e "\033[92mTunnel uninstalled successfully.\033[0m"
    else
        echo -e "\033[93mNo /etc/rc.local file found.\033[0m"
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
        echo -e "\033[94mMain Menu\033[0m"
        echo -e "\033[92m1. Install Tunnel"
        echo -e "\033[91m2. Uninstall Tunnel"
        echo -e "\033[96m3. Scripts"
        echo -e "\033[90m4. Exit\033[0m"
        read -p $'\033[93mChoose an option: \033[0m' choice
        case $choice in
            1) install_tunnel_menu ;;
            2) uninstall_tunnel_menu ;;
            3) scripts_menu ;;
            4) echo "Bye!"; exit 0 ;;
            *) echo -e "\033[91mInvalid input.\033[0m"; sleep 2 ;;
        esac
    done
}

install_tunnel_menu() {
    while true; do
        clear
        echo -e "\033[94mSelect Tunnel Type to Install:\033[0m"
        echo -e "\033[92m1. 6to4"
        echo -e "\033[93m2. sit"
        echo -e "\033[95m3. gre6"
        echo -e "\033[96m4. iptables"
        echo -e "\033[90m5. Back\033[0m"
        read -p $'\033[93mEnter number: \033[0m' tunnel_choice
        case $tunnel_choice in
            1) tunnel_type="6to4" ;;
            2) tunnel_type="sit" ;;
            3) tunnel_type="gre6" ;;
            4) tunnel_type="iptables" ;;
            5) return ;;
            *) echo -e "\033[91mInvalid input.\033[0m"; sleep 2; continue ;;
        esac

        echo -e "\033[93mSelect server type:\n\033[92m1. Iran\n\033[91m2. Foreign\n\033[90m3. Back\033[0m"
        read -p $'\033[93mEnter number: \033[0m' server_choice
        case $server_choice in
            1)
                server_type="iran"
                iran_ip=$(get_current_ip)
                echo -e "\033[93mDetected Iran IP: $iran_ip\033[0m"
                read -p $'\033[93mEnter Foreign IP: \033[0m' foreign_ip
                ;;
            2)
                server_type="foreign"
                foreign_ip=$(get_current_ip)
                echo -e "\033[93mDetected Foreign IP: $foreign_ip\033[0m"
                read -p $'\033[93mEnter Iran IP: \033[0m' iran_ip
                ;;
            3) continue ;;
            *)
                echo -e "\033[91mInvalid input.\033[0m"
                sleep 2
                continue
                ;;
        esac

        install_tunnel "$iran_ip" "$foreign_ip" "$server_type" "$tunnel_type"
        read -p "Press Enter to continue..."
    done
}

uninstall_tunnel_menu() {
    while true; do
        clear
        echo -e "\033[91mUninstall Tunnel (removes /etc/rc.local)\033[0m"
        echo -e "1. Confirm Uninstall\n2. Back"
        read -p "Choose: " uninstall_choice
        case $uninstall_choice in
            1) uninstall_tunnel; read -p "Press Enter to continue..." ;;
            2) return ;;
            *) echo "Invalid input"; sleep 1 ;;
        esac
    done
}

scripts_menu() {
    while true; do
        clear
        echo -e "\033[96mScripts Menu:\033[0m"
        echo -e "1. Sanaei Script (3x-ui)"
        echo -e "2. Alireza Script (x-ui)"
        echo -e "3. Ghost Script"
        echo -e "4. PF-TUN Script"
        echo -e "5. Reverse Tunnel Script"
        echo -e "6. ISP Blocker Script"
        echo -e "7. Back"
        read -p "Choose script to install: " script_choice
        case $script_choice in
            1) install_sanaie_script ;;
            2) install_alireza_script ;;
            3) install_ghost_script ;;
            4) install_pftun_script ;;
            5) install_reverse_script ;;
            6) install_ispblocker_script ;;
            7) return ;;
            *) echo -e "\033[91mInvalid input.\033[0m"; sleep 2 ;;
        esac
        read -p "Press Enter to continue..."
    done
}

# Run the main menu loop
main_menu
