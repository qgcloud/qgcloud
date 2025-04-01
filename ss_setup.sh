#!/bin/bash

# 设置 PATH 环境变量
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# 配置参数
ss_password='dm6688'
ss_method='aes-256-gcm'
ss_protocol='auth_sha1_v4_compatible'
ss_protocol_param='200'
ss_obfs='tls1.2_ticket_auth_compatible'
ss_server_port='1111'
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
    echo "正在安装必要的依赖项..."
    apt update
    apt install -y net-tools iptables qrencode build-essential libevent-dev libssl-dev libsodium-dev git
    if [ $? -ne 0 ]; then
        echo "错误：依赖项安装失败，请检查错误信息。"
        exit 1
    fi
}

# 从 GitHub 下载并安装 Shadowsocks-libev
install_shadowsocks_libev() {
    echo "正在从 GitHub 下载并安装 Shadowsocks-libev..."
    git clone https://github.com/shadowsocks/shadowsocks-libev.git
    if [ $? -ne 0 ]; then
        echo "错误：无法从 GitHub 克隆 Shadowsocks-libev 仓库。"
        exit 1
    fi

    cd shadowsocks-libev
    ./autogen.sh
    ./configure --prefix=/usr/local/shadowsocks-libev --with-libevent --with-openssl --with-libsodium
    make
    if [ $? -ne 0 ]; then
        echo "错误：编译 Shadowsocks-libev 失败。"
        exit 1
    fi
    make install
    if [ $? -ne 0 ]; then
        echo "错误：安装 Shadowsocks-libev 失败。"
        exit 1
    fi
    cd ..
}

# 添加防火墙规则
add_iptables() {
    echo "正在配置防火墙规则..."
    iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${ss_server_port} -j ACCEPT
    iptables -I INPUT -m state --state NEW -m udp -p udp --dport ${ss_server_port} -j ACCEPT
    if [ $? -ne 0 ]; then
        echo "错误：配置防火墙规则失败。"
        exit 1
    fi

    # 安装 iptables-persistent 并保存规则
    apt install -y iptables-persistent
    if [ $? -ne 0 ]; then
        echo "警告：安装 iptables-persistent 失败，但防火墙规则已临时生效。"
    else
        iptables-save > /etc/iptables/rules.v4
        echo "防火墙规则已保存。"
    fi
}

# URL 安全的 Base64 编码
urlsafe_base64() {
    echo -n "$1" | base64 | tr '+/' '-_' | tr -d '='
}

# 生成 SS 链接和二维码
generate_ss_link() {
    echo "正在生成 SS 链接和二维码..."
    SSbase64=$(urlsafe_base64 "${ss_method}:${ss_password}@${ss_server_ip}:${ss_server_port}")
    SSurl="ss://${SSbase64}"
    qrencode -o ${qr_folder}/ss.png -s 8 "${SSurl}"
    if [ $? -ne 0 ]; then
        echo "警告：生成 SS 二维码失败，但链接已生成。"
    fi
    echo "${SSurl}" >> url.txt
    echo "SS 链接已生成：${SSurl}"
    echo "SS 二维码已生成，路径为：${qr_folder}/ss.png"
}

# 生成 SSR 链接和二维码
generate_ssr_link() {
    echo "正在生成 SSR 链接和二维码..."
    SSRprotocol=$(echo ${ss_protocol} | sed 's/_compatible//g')
    SSRobfs=$(echo ${ss_obfs} | sed 's/_compatible//g')
    SSRPWDbase64=$(urlsafe_base64 "${ss_password}")
    remarkBase64=$(urlsafe_base64 "gfw-breaker [${ss_server_ip}]")
    SSRbase64=$(urlsafe_base64 "${ss_server_ip}:${ss_server_port}:${SSRprotocol}:${ss_method}:${SSRobfs}:${SSRPWDbase64}/?remarks=${remarkBase64}")
    SSRurl="ssr://${SSRbase64}"
    qrencode -o ${qr_folder}/ssr.png -s 8 "${SSRurl}"
    if [ $? -ne 0 ]; then
        echo "警告：生成 SSR 二维码失败，但链接已生成。"
    fi
    echo "${SSRurl}" >> url.txt
    echo "SSR 链接已生成：${SSRurl}"
    echo "SSR 二维码已生成，路径为：${qr_folder}/ssr.png"
}

# 写入配置文件
write_configuration() {
    echo "正在写入配置文件..."
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
    "additional_ports": {},
    "timeout": 120,
    "udp_timeout": 60,
    "dns_ipv6": false,
    "connect_verbose_info": 0,
    "redirect": "",
    "fast_open": false
}
EOF
    if [ $? -ne 0 ]; then
        echo "错误：写入配置文件失败。"
        exit 1
    fi
    echo "配置文件已写入：${config_user_file}"
}

# 启动 Shadowsocks-libev 服务
start_service() {
    echo "正在启动 Shadowsocks-libev 服务..."
    ss-server -c ${config_user_file} -u -f /var/run/shadowsocks.pid
    if [ $? -ne 0 ]; then
        echo "错误：启动 Shadowsocks-libev 服务失败。"
        exit 1
    fi
    echo "Shadowsocks-libev 服务已启动。"
}

# 查看日志
view_logs() {
    echo "查看 Shadowsocks-libev 日志..."
    tail -f ${ssr_log_file}
}

# 主函数
main() {
    echo "开始安装和配置 Shadowsocks-libev..."
    install_dependencies
    install_shadowsocks_libev
    write_configuration
    add_iptables
    generate_ss_link
    generate_ssr_link
    start_service
    echo "安装和配置完成！"
}

# 执行主函数
main
