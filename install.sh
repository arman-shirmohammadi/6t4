#!/bin/bash

# تعریف آرایه تونل‌ها
tunnels=(
    "iran_tunnel|192.168.168.1|iran"
    "foreign_tunnel|192.168.168.2|foreign"
)

# تابع نمونه نصب تونل
install_tunnel() {
    local ip="$1"
    local type="$2"
    echo "Installing tunnel at IP: $ip with type: $type"
    # اینجا کد نصب تونل رو بذار
}

# تابع نمونه حذف تونل
remove_tunnel() {
    local ip="$1"
    local type="$2"
    echo "Removing tunnel at IP: $ip with type: $type"
    # اینجا کد حذف تونل رو بذار
}

# منوی انتخاب تونل
select_tunnel_menu() {
    clear
    echo "Available tunnels:"
    for i in "${!tunnels[@]}"; do
        IFS='|' read -r name ip type <<< "${tunnels[$i]}"
        echo "$((i+1)). $name - IP: $ip"
    done

    read -p "Enter the number of your server: " server_choice

    # اعتبارسنجی ورودی
    if ! [[ "$server_choice" =~ ^[1-9][0-9]*$ ]] || (( server_choice < 1 || server_choice > ${#tunnels[@]} )); then
        echo "Invalid choice. Please enter a valid number."
        sleep 2
        select_tunnel_menu
        return
    fi

    IFS='|' read -r name ip server_type <<< "${tunnels[$((server_choice-1))]}"
    echo "You chose: $name ($ip), type: $server_type"

    # انتخاب عملیات
    echo "Choose operation:"
    echo "1) Install tunnel"
    echo "2) Remove tunnel"
    read -p "Enter choice: " op_choice

    case $op_choice in
        1) install_tunnel "$ip" "$server_type" ;;
        2) remove_tunnel "$ip" "$server_type" ;;
        *) echo "Invalid operation choice." ;;
    esac
}

# اجرای منو
select_tunnel_menu
