#!/bin/bash

function install_tunnel() {
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

    echo "" > /etc/rc.local
    chmod +x /etc/rc.local

    for command in "${commands[@]}"; do
        echo "
