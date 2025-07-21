#!/bin/bash

function get_current_ip() {
    local current_ip
    current_ip=$(curl -s https://api.ipify.org)
    echo "$current_ip"
}

install_tunnel() {
    local iran_ip=$1
    local foreign_ips=("${!2}") # دریافت آرایه IPهای سرورهای خارجی
    local server_type=$3
    local tunnel_type=$4
    local ports=("${!5}") # دریافت آرایه پورت‌ها

    if [[ $tunnel_type == "6to4" ]]; then
        if [[ $server_type == "iran" ]]; then
            for idx in "${!foreign_ips[@]}"; do
                local foreign_ip=${foreign_ips[$idx]}
                local port=${ports[$idx]}
                echo "Setting up 6to4 tunnel to Foreign IP $foreign_ip on port $port..."

                commands=(
                    "ip tunnel add 6to4_iran_$idx mode sit remote $foreign_ip local $iran_ip"
                    "ip -6 addr add 2002:a00:100::1/64 dev 6to4_iran_$idx"
                    "ip link set 6to4_iran_$idx mtu 1480"
                    "ip link set 6to4_iran_$idx up"
                    "ip -6 tunnel add GRE6Tun_iran_$idx mode ip6gre remote 2002:a00:100::2 local 2002:a00:100::1"
                    "ip addr add 192.168.168.$((2*idx+1))/30 dev GRE6Tun_iran_$idx"
                    "ip link set GRE6Tun_iran_$idx mtu 1436"
                    "ip link set GRE6Tun_iran_$idx up"
                    "sysctl -w net.ipv4.ip_forward=1"
                    "iptables -t nat -A PREROUTING -p tcp --dport $port -j DNAT --to-destination 192.168.168.$((2*idx+1))"
                    "iptables -t nat -A PREROUTING -j DNAT --to-destination 192.168.168.$((2*idx+2))"
                    "iptables -t nat -A POSTROUTING -j MASQUERADE"
                )

                for command in "${commands[@]}"; do
                    echo "Executing: $command"
                    eval "$command"
                    if [[ $? -ne 0 ]]; then
                        echo -e "\033[91mError executing: $command\033[0m"
                        return 1
                    fi
                done
            done

        elif [[ $server_type == "foreign" ]]; then
            # برای حالت foreign فرض کردیم فقط یک foreign_ip داریم ولی میشه مشابه ایران هم توسعه داد
            commands=(
                "ip tunnel add 6to4_Foreign mode sit remote $iran_ip local ${foreign_ips[0]}"
                "ip -6 addr add 2002:a00:100::2/64 dev 6to4_Foreign"
                "ip link set 6to4_Foreign mtu 1480"
                "ip link set 6to4_Foreign up"
                "ip -6 tunnel add GRE6Tun_Foreign mode ip6gre remote 2002:a00:100::1 local 2002:a00:100::2"
                "ip addr add 192.168.168.2/30 dev GRE6Tun_Foreign"
                "ip link set GRE6Tun_Foreign mtu 1436"
                "ip link set GRE6Tun_Foreign up"
                "iptables -A INPUT --proto icmp -j DROP"
            )

            for command in "${commands[@]}"; do
                echo "Executing: $command"
                eval "$command"
                if [[ $? -ne 0 ]]; then
                    echo -e "\033[91mError executing: $command\033[0m"
                    return 1
                fi
            done
        fi
    elif [[ $tunnel_type == "iptables" ]]; then
        commands=(
            "sysctl -w net.ipv4.ip_forward=1"
            "iptables -t nat -A PREROUTING -p tcp --dport 22 -j DNAT --to-destination $iran_ip"
            "iptables -t nat -A PREROUTING -j DNAT --to-destination ${foreign_ips[0]}"
            "iptables -t nat -A POSTROUTING -j MASQUERADE"
        )
        for command in "${commands[@]}"; do
            echo "Executing: $command"
            eval "$command"
            if [[ $? -ne 0 ]]; then
                echo -e "\033[91mError executing: $command\033[0m"
                return 1
            fi
        done
    fi

    # ذخیره دستورات در rc.local برای بوت شدن
    if [[ -f "/etc/rc.local" ]]; then
        read -p "File /etc/rc.local already exists. Do you want to overwrite it? (y/n): " overwrite
        if [[ $overwrite != "y" && $overwrite != "yes" ]]; then
            echo "Stopped process."
            sleep 5
            return
        fi
    fi

    echo "#!/bin/bash" > /etc/rc.local
    for idx in "${!foreign_ips[@]}"; do
        if [[ $server_type == "iran" && $tunnel_type == "6to4" ]]; then
            echo "ip tunnel add 6to4_iran_$idx mode sit remote ${foreign_ips[$idx]} local $iran_ip" >> /etc/rc.local
            echo "ip -6 addr add 2002:a00:100::1/64 dev 6to4_iran_$idx" >> /etc/rc.local
            echo "ip link set 6to4_iran_$idx mtu 1480" >> /etc/rc.local
            echo "ip link set 6to4_iran_$idx up" >> /etc/rc.local
            echo "ip -6 tunnel add GRE6Tun_iran_$idx mode ip6gre remote 2002:a00:100::2 local 2002:a00:100::1" >> /etc/rc.local
            echo "ip addr add 192.168.168.$((2*idx+1))/30 dev GRE6Tun_iran_$idx" >> /etc/rc.local
            echo "ip link set GRE6Tun_iran_$idx mtu 1436" >> /etc/rc.local
            echo "ip link set GRE6Tun_iran_$idx up" >> /etc/rc.local
            echo "sysctl -w net.ipv4.ip_forward=1" >> /etc/rc.local
            echo "iptables -t nat -A PREROUTING -p tcp --dport ${ports[$idx]} -j DNAT --to-destination 192.168.168.$((2*idx+1))" >> /etc/rc.local
            echo "iptables -t nat -A PREROUTING -j DNAT --to-destination 192.168.168.$((2*idx+2))" >> /etc/rc.local
            echo "iptables -t nat -A POSTROUTING -j MASQUERADE" >> /etc/rc.local
        fi
    done
    echo "exit 0" >> /etc/rc.local
    chmod +x /etc/rc.local

    echo -e "\033[92mTunnel installation successful.\033[0m"
}

uninstall_tunnel() {
    local server_type=$1

    # حذف تانل‌ها و قوانین مرتبط
    if [[ $server_type == "iran" ]]; then
        # حذف همه تونل‌های با اسم 6to4_iran_* و GRE6Tun_iran_*
        ip tunnel show | grep 6to4_iran_ | awk '{print $1}' | while read -r tun; do
            ip tunnel del "$tun"
            echo "Deleted tunnel: $tun"
        done
        ip tunnel show | grep GRE6Tun_iran_ | awk '{print $1}' | while read -r tun; do
            ip tunnel del "$tun"
            echo "Deleted tunnel: $tun"
        done

        # پاک کردن قوانین iptables مرتبط (در صورت وجود)
        iptables -t nat -D PREROUTING -p tcp --dport 22 -j DNAT --to-destination 192.168.168.1 2>/dev/null
        iptables -t nat -F POSTROUTING 2>/dev/null
        iptables -t nat -F PREROUTING 2>/dev/null

    elif [[ $server_type == "foreign" ]]; then
        ip tunnel show | grep 6to4_Foreign | awk '{print $1}' | while read -r tun; do
            ip tunnel del "$tun"
            echo "Deleted tunnel: $tun"
