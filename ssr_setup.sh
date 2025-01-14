#!/bin/bash

# 安装ShadowsocksR
install_shadowsocks_r() {
    echo "安装ShadowsocksR..."
    apt-get update
    apt-get install -y python3 python3-pip
    pip3 install shadowsocks
    if [ $? -eq 0 ]; then
        echo "ShadowsocksR安装成功。"
    else
        echo "ShadowsocksR安装失败。"
        exit 1
    fi
}

# 创建配置文件
create_config_file() {
    local port=$1
    local password=$2
    local method=$3
    local protocol=$4
    local obfs=$5

    echo "创建配置文件..."
    cat > /etc/shadowsocks.json <<EOF
{
    "server": "0.0.0.0",
    "server_port": $port,
    "password": "$password",
    "timeout": 300,
    "method": "$method",
    "protocol": "$protocol",
    "protocol_param": "",
    "obfs": "$obfs",
    "obfs_param": "",
    "redirect": "",
    "dns_ipv6": false,
    "fast_open": false,
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

# 启动ShadowsocksR服务
start_shadowsocks_r() {
    echo "启动ShadowsocksR服务..."
    ssserver -c /etc/shadowsocks.json -d start
    if [ $? -eq 0 ]; then
        echo "ShadowsocksR服务已启动。"
    else
        echo "ShadowsocksR服务启动失败。"
        exit 1
    fi
}

# 主函数
main() {
    read -p "请输入端口号（默认8388）: " port
    port=${port:-8388}
    read -p "请输入密码（默认Aa778409）: " password
    password=${password:-Aa778409}
    read -p "请输入加密方法（默认aes-256-cfb）: " method
    method=${method:-aes-256-cfb}
    read -p "请输入协议（默认origin）: " protocol
    protocol=${protocol:-origin}
    read -p "请输入混淆（默认plain）: " obfs
    obfs=${obfs:-plain}

    install_shadowsocks_r
    create_config_file $port "$password" "$method" "$protocol" "$obfs"
    start_shadowsocks_r
}

# 执行主函数
main
