#!/usr/bin/env bash

# 颜色定义
Green_font_prefix="\033[32m"
Red_font_prefix="\033[31m"
Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"

# 检查是否为 root 用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${Error} 当前用户不是 root 用户，请切换到 root 用户后重新运行脚本！"
        exit 1
    fi
}

# 检测系统
check_sys() {
    if [[ -f /etc/redhat-release ]]; then
        release="centos"
    elif grep -q -E -i "debian" /etc/issue; then
        release="debian"
    elif grep -q -E -i "ubuntu" /etc/issue; then
        release="ubuntu"
    else
        echo -e "${Error} 当前系统不支持，请使用 CentOS/Debian/Ubuntu 系统！"
        exit 1
    fi
}

# 安装 Shadowsocks
install_ss() {
    echo -e "${Info} 开始安装 Shadowsocks..."
    if [[ ${release} == "centos" ]]; then
        yum install -y python-pip
    else
        apt-get update
        apt-get install -y python-pip
    fi
    pip install shadowsocks
    echo -e "${Info} Shadowsocks 安装完成！"
}

# 配置 Shadowsocks
config_ss() {
    echo -e "${Info} 配置 Shadowsocks..."
    local public_ip=$(curl -s https://api.ipify.org)  # 获取公网IP
    cat > /etc/shadowsocks.json <<EOF
{
    "server": "0.0.0.0",
    "server_port": 8388,
    "password": "yourpassword",
    "timeout": 300,
    "method": "aes-256-cfb"
}
EOF
    echo -e "${Info} 配置完成，端口：8388，密码：yourpassword，加密方式：aes-256-cfb，公网IP：${public_ip}"
}

# 启动 Shadowsocks
start_ss() {
    echo -e "${Info} 启动 Shadowsocks..."
    nohup ssserver -c /etc/shadowsocks.json > /var/log/shadowsocks.log 2>&1 &
    echo -e "${Info} Shadowsocks 已启动，日志路径：/var/log/shadowsocks.log"
}

# 安装 qrencode
install_qrencode() {
    echo -e "${Info} 安装 qrencode..."
    if [[ ${release} == "centos" ]]; then
        yum install -y qrencode
    else
        apt-get install -y qrencode
    fi
    echo -e "${Info} qrencode 安装完成！"
}

# 生成二维码
generate_qrcode() {
    echo -e "${Info} 生成 Shadowsocks 二维码..."
    local public_ip=$(curl -s https://api.ipify.org)  # 再次获取公网IP
    local ss_url="ss://$(echo -n "aes-256-cfb:yourpassword@${public_ip}:8388" | base64 | tr -d '\n')"
    qrencode -o /root/shadowsocks_qr.png "${ss_url}"
    echo -e "${Info} 二维码已生成，路径：/root/shadowsocks_qr.png"
    echo -e "${Info} 二维码链接：${ss_url}"
}

# 主菜单
main_menu() {
    check_root
    check_sys
    install_ss
    config_ss
    start_ss
    install_qrencode
    generate_qrcode
    echo -e "${Info} Shadowsocks + 二维码生成完成！"
}

main_menu
