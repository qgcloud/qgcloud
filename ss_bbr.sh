#!/bin/bash

RED="\033[31m"      # Error message
GREEN="\033[32m"    # Success message
YELLOW="\033[33m"   # Warning message
BLUE="\033[36m"     # Info message
PLAIN='\033[0m'

NAME="shadowsocks-libev"
CONFIG_FILE="/etc/${NAME}/config.json"
SERVICE_FILE="/etc/systemd/system/${NAME}.service"

V6_PROXY=""
IP=$(curl -sL -4 ip.sb)
if [[ "$?" != "0" ]]; then
    IP=$(curl -sL -6 ip.sb)
    V6_PROXY="https://gh.hijk.art/"
fi

colorEcho() {
    echo -e "${1}${@:2}${PLAIN}"
}

checkSystem() {
    if [[ $(id -u) != 0 ]]; then
        colorEcho $RED " 请以 root 身份运行此脚本"
        exit 1
    fi

    if ! command -v apt &>/dev/null; then
        colorEcho $RED " 不支持的 Linux 系统。请使用基于 Debian/Ubuntu 的系统。"
        exit 1
    fi
}

installSS() {
    colorEcho $GREEN " 安装 Shadowsocks-libev..."
    apt update
    apt install -y software-properties-common
    add-apt-repository -y ppa:max-c-lv/shadowsocks-libev
    apt update
    apt install -y shadowsocks-libev
}

configSS() {
    mkdir -p /etc/shadowsocks-libev
    cat > $CONFIG_FILE <<EOF
{
    "server": "0.0.0.0",
    "server_port": 1111,
    "password": "dm66887777",
    "timeout": 600,
    "method": "aes-256-gcm",
    "mode": "tcp_and_udp",
    "nameserver":"8.8.8.8",
    "fast_open": true
}
EOF
}

createService() {
    cat > $SERVICE_FILE <<EOF
[Unit]
Description=Shadowsocks-libev
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/ss-server -c $CONFIG_FILE
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now shadowsocks-libev
}

installBBR() {
    colorEcho $GREEN " 安装并启用 BBR..."
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p
    colorEcho $GREEN " BBR 已启用！"
}

showInfo() {
    colorEcho $GREEN " Shadowsocks-libev 已安装并启动成功！"
    echo " 配置信息如下："
    echo " IP: $IP"
    echo " 端口: 1111"
    echo " 密码: dm66887777"
    echo " 加密方式: aes-256-gcm"
}

showQR() {
    LINK="ss://$(echo -n "aes-256-gcm:dm66887777@${IP}:1111" | base64 -w 0)"
    QR_FILE="/root/ss_protocol.png"
    qrencode -o "$QR_FILE" "$LINK"
    colorEcho $GREEN " 二维码已生成，路径为：$QR_FILE"
    colorEcho $GREEN " 二维码链接: $LINK"
}

main() {
    checkSystem
    installSS
    configSS
    createService
    installBBR
    showInfo
    showQR
}

main
