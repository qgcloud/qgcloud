#!/bin/bash

# 安装BBR加速
install_bbr() {
    echo "安装BBR加速..."
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p
    if [ $? -eq 0 ]; then
        echo "BBR加速已启用。"
    else
        echo "BBR加速启用失败。"
        exit 1
    fi
}

# 安装Shadowsocks
install_shadowsocks() {
    echo "安装Shadowsocks..."
    apt-get update
    apt-get install -y python3 python3-pip
    pip3 install shadowsocks
    if [ $? -eq 0 ]; then
        echo "Shadowsocks安装成功。"
    else
        echo "Shadowsocks安装失败。"
        exit 1
    fi
}

# 创建配置文件
create_config_file() {
    local port=$1
    local password=$2
    local method=$3

    echo "创建配置文件..."
    cat > /etc/shadowsocks.json <<EOF
{
    "server": "0.0.0.0",
    "server_port": $port,
    "password": "$password",
    "timeout": 300,
    "method": "$method",
    "fast_open": true,
    "workers": 1
}
EOF
    if [ $? -eq 0 ]; then
        echo "配置文件创建成功。"
    else
        echo "配置文件创建失败。"
        exit 1
    fi
}

# 启动Shadowsocks服务
start_shadowsocks() {
    echo "启动Shadowsocks服务..."
    ssserver -c /etc/shadowsocks.json -d start
    if [ $? -eq 0 ]; then
        echo "Shadowsocks服务已启动。"
    else
        echo "Shadowsocks服务启动失败。"
        exit 1
    fi
}

# 生成二维码
generate_qr_code() {
    local port=$1
    local password=$2
    local method=$3
    local server_ip=$(curl -s https://api.ipify.org)

    echo "生成二维码..."
    pip3 install qrcode[pil]
    qrcode -t UTF8 "ss://${method}:${password}@${server_ip}:${port}" -o /root/ss_qr.png
    if [ $? -eq 0 ]; then
        echo "二维码已生成并保存到 /root/ss_qr.png"
    else
        echo "二维码生成失败。"
        exit 1
    fi
}

# 主函数
main() {
    read -p "请输入端口号（默认1111）: " port
    port=${port:-1111}
    read -p "请输入密码（默认Aa778409）: " password
    password=${password:-Aa778409}
    read -p "请输入加密方法（默认aes-256-gcm）: " method
    method=${method:-aes-256-gcm}

    install_bbr
    install_shadowsocks
    create_config_file $port "$password" "$method"
    start_shadowsocks
    generate_qr_code $port "$password" "$method"
}

# 执行主函数
main
