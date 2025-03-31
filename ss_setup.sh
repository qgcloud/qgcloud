#!/bin/bash

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# 配置参数
ss_password='dm6688'
ss_method=aes-256-gcm
ss_protocol=auth_sha1_v4_compatible
ss_protocol_param=200
ss_obfs=tls1.2_ticket_auth_compatible
ss_server_port=1111
ss_server_ip=$(ip -4 addr show scope global | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)

# 目录路径
qr_folder="/usr/local/nginx/html/info"
ssr_folder="/usr/local/shadowsocksr"
ssr_ss_file="${ssr_folder}/shadowsocks"
config_file="${ssr_folder}/config.json"
config_folder="/etc/shadowsocksr"
config_user_file="${config_folder}/user-config.json"
ssr_log_file="${ssr_ss_file}/ssserver.log"

# 确保所需目录存在
mkdir -p ${qr_folder} ${config_folder}

# 安装必要的工具
install_dependencies() {
    apt update
    apt install -y net-tools iptables qrencode build-essential libevent-dev libssl-dev libsodium-dev git
}

# 从 GitHub 下载并安装 Shadowsocks-libev
install_shadowsocks_libev() {
    git clone https://github.com/shadowsocks/shadowsocks-libev.git
    cd shadowsocks-libev
    ./autogen.sh
    ./configure --prefix=/usr/local/shadowsocks-libev --with-libevent --with-openssl --with-libsodium
    make && make install
    cd ..
}

# 添加防火墙规则
add_iptables() {
    iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${ss_server_port} -j ACCEPT
    iptables -I INPUT -m state --state NEW -m udp -p udp --dport ${ss_server_port} -j ACCEPT
    # 保存规则
    apt install -y iptables-persistent
    iptables-save > /etc/iptables/rules.v4
}

# URL 安全的 Base64 编码
urlsafe_base64() {
    echo -n "$1" | base64 | tr '+/' '-_' | tr -d '='
}

# 生成 SS 链接和二维码
ss_link_qr() {
    SSbase64=$(urlsafe_base64 "${ss_method}:${ss_password}@${ss_server_ip}:${ss_server_port}")
    SSurl="ss://${SSbase64}"
    qrencode -o ${qr_folder}/ss.png -s 8 "${SSurl}"
    echo "${SSurl}" >> url.txt
    echo "SS 链接已生成：${SSurl}"
    echo "SS 二维码已生成，路径为：${qr_folder}/ss.png"
}

# 生成 SSR 链接和二维码
ssr_link_qr() {
    SSRprotocol=$(echo ${ss_protocol} | sed 's/_compatible//g')
    SSRobfs=$(echo ${ss_obfs} | sed 's/_compatible//g')
    SSRPWDbase64=$(urlsafe_base64 "${ss_password}")
    remarkBase64=$(urlsafe_base64 "gfw-breaker [${ss_server_ip}]")
    SSRbase64=$(urlsafe_base64 "${ss_server_ip}:${ss_server_port}:${SSRprotocol}:${ss_method}:${SSRobfs}:${SSRPWDbase64}/?remarks=${remarkBase64}")
    SSRurl="ssr://${SSRbase64}"
    qrencode -o ${qr_folder}/ssr.png -s 8 "${SSRurl}"
    echo "${SSRurl}" >> url.txt
    echo "SSR 链接已生成：${SSRurl}"
    echo "SSR 二维码已生成，路径为：${qr_folder}/ssr.png"
}

# 写入配置文件
write_configuration() {
    cat > ${config_user_file} <<-EOF
{
    "server": "${ss_server_ip}",
    "server_ipv6": "::",
    "server_port": ${ss_server_port},
    "local_address": "127.0.0.1",
    "local_port": 1080,

    "password": "${ss_password}",
    "method": "${ss_method}",
    "protocol": "${ss_protocol}",
    "protocol_param": "${ss_protocol_param}",
    "obfs": "${ss_obfs}",
    "obfs_param": "",
    "speed_limit_per_con": 0,
    "speed_limit_per_user": 0,

    "additional_ports" : {},
    "timeout": 120,
    "udp_timeout": 60,
    "dns_ipv6": false,
    "connect_verbose_info": 0,
    "redirect": "",
    "fast_open": false
}
EOF
}

# 主函数
main() {
    install_dependencies
    install_shadowsocks_libev
    write_configuration
    add_iptables
    ss_link_qr
    ssr_link_qr
}

# 执行主函数
main
