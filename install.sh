#!/bin/bash

# مسیر فایل کانفیگ 6to4 و تونل‌ها
CONFIG_FILE="/etc/ip6tables/6to4.conf"

# تابع نمایش منو
show_menu() {
    clear
    echo "==== 6to4 Tunnel Manager ===="
    echo "1) Install 6to4 tunnels"
    echo "2) Show existing tunnels"
    echo "3) Delete a tunnel"
    echo "4) Uninstall 6to4"
    echo "5) Exit"
    echo "============================="
    echo -n "Enter your choice: "
}

# تابع نصب تونل‌ها با دریافت لیست IP سرورها و پورت‌ها
install_tunnels() {
    echo "Enter IPv4 addresses for your remote servers separated by space:"
    read -r -a servers

    echo "Enter ports for each server separated by space (order matters):"
    read -r -a ports

    if [ ${#servers[@]} -ne ${#ports[@]} ]; then
        echo "Error: Number of servers and ports must be the same."
        return
    fi

    echo "Installing tunnels..."
    echo "" > "$CONFIG_FILE"  # خالی کردن فایل کانفیگ

    for i in "${!servers[@]}"; do
        server_ip=${servers[$i]}
        port=${ports[$i]}
        tunnel_name="sit$i"

        # حذف تونل اگر وجود داشته باشد
        ip tunnel del "$tunnel_name" 2>/dev/null

        # ایجاد تونل
        ip tunnel add "$tunnel_name" mode sit remote "$server_ip" local $(hostname -I | awk '{print $1}') ttl 255
        ip link set "$tunnel_name" up

        # تنظیم آدرس‌ها (مثال زیر فقط نمونه است، بر اساس نیاز خود تغییر بده)
        ip addr add 192.88.99.$((i+1))/30 dev "$tunnel_name"

        # اگر می‌خواهید روت‌های IPv6 را اضافه کنید اینجا اضافه کنید
        # مثال: ip -6 route add ::/0 dev "$tunnel_name"

        # اضافه کردن به فایل کانفیگ
        echo "$tunnel_name $server_ip $port" >> "$CONFIG_FILE"

        echo "Tunnel $tunnel_name created for server $server_ip on port $port"
    done

    echo "All tunnels installed and configured."
    read -p "Press Enter to continue..."
}

# نمایش تونل‌های موجود
show_tunnels() {
    clear
    echo "Available tunnels:"
    if [ ! -f "$CONFIG_FILE" ] || [ ! -s "$CONFIG_FILE" ]; then
        echo "No tunnels configured."
    else
        nl -w3 -s". " "$CONFIG_FILE"
    fi
    echo "Press Enter to return..."
    read -r
}

# حذف تونل مشخص شده توسط کاربر
delete_tunnel() {
    if [ ! -f "$CONFIG_FILE" ] || [ ! -s "$CONFIG_FILE" ]; then
        echo "No tunnels to delete."
        read -p "Press Enter to continue..."
        return
    fi

    echo "Select a tunnel to delete:"
    nl -w3 -s". " "$CONFIG_FILE"
    echo -n "Enter tunnel number: "
    read -r num

    total=$(wc -l < "$CONFIG_FILE")
    if ! [[ "$num" =~ ^[0-9]+$ ]] || [ "$num" -lt 1 ] || [ "$num" -gt "$total" ]; then
        echo "Invalid selection."
        read -p "Press Enter to continue..."
        return
    fi

    line=$(sed -n "${num}p" "$CONFIG_FILE")
    tunnel_name=$(echo "$line" | awk '{print $1}')

    # حذف تونل
    ip tunnel del "$tunnel_name" 2>/dev/null

    # حذف از فایل کانفیگ
    sed -i "${num}d" "$CONFIG_FILE"

    echo "Tunnel $tunnel_name deleted."
    read -p "Press Enter to continue..."
}

# حذف کامل 6to4
uninstall_6to4() {
    echo "Deleting all tunnels..."

    if [ -f "$CONFIG_FILE" ]; then
        while IFS= read -r line; do
            tunnel_name=$(echo "$line" | awk '{print $1}')
            ip tunnel del "$tunnel_name" 2>/dev/null
        done < "$CONFIG_FILE"

        rm -f "$CONFIG_FILE"
        echo "All tunnels deleted and config file removed."
    else
        echo "No config file found. Nothing to uninstall."
    fi

    echo "6to4 tunnels uninstalled."
    read -p "Press Enter to continue..."
}

# اجرای منو و دریافت انتخاب کاربر
while true; do
    show_menu
    read -r choice
    case $choice in
        1) install_tunnels ;;
        2) show_tunnels ;;
        3) delete_tunnel ;;
        4) uninstall_6to4 ;;
        5) echo "Exiting..."; exit 0 ;;
        *) echo "Invalid choice, try again." ;;
    esac
done
