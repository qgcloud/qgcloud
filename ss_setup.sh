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

# 安装依赖
install_dependencies() {
    echo "安装必要的依赖..."
    apt-get update
    apt-get install -y curl qrencode docker.io
    if [ $? -eq 0 ]; then
        echo "依赖安装成功。"
    else
        echo "依赖安装失败。"
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
    local port=$1
    local password=$2
    local method=$3
    local server_ip=$(curl -s https://api.ipify.org)

    # 检查并删除已存在的同名容器
    if docker ps -a --format '{{.Names}}' | grep -q "^shadowsocks$"; then
        echo "检测到已存在的同名容器，正在删除..."
        docker rm -f shadowsocks
        if [ $? -ne 0 ]; then
            echo "删除容器失败，请手动删除容器后重试。"
            exit 1
        fi
    fi

    # 确保端口已释放
    echo "检查端口 $port 是否已被释放..."
    if ! timeout 1 bash -c "nc -zv 0.0.0.0 $port" &> /dev/null; then
        echo "端口 $port 已释放，可以继续。"
    else
        echo "端口 $port 仍然被占用，正在尝试释放..."
        if pid=$(lsof -t -i :$port); then
            echo "端口 $port 被 PID $pid 占用，正在杀死进程..."
            sudo kill -9 $pid
            if [ $? -eq 0 ]; then
                echo "已杀死占用端口 $port 的进程。"
            else
                echo "无法杀死占用端口 $port 的进程，请手动释放端口。"
                exit 1
            fi
        else
            echo "无法确定占用端口 $port 的进程，请手动检查端口占用情况。"
            exit 1
        fi
    fi


    # 创建 Docker 容器
    docker run -d --name shadowsocks \
        -p $port:$port \
        -v /etc/shadowsocks.json:/etc/shadowsocks.json \
        --restart unless-stopped \
        mritd/shadowsocks -c /etc/shadowsocks.json -d start

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
    local ss_link="ss://${method}:${password}@${server_ip}:${port}"
    echo $ss_link | qrencode -o /root/ss_qr.png
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
    install_dependencies
    create_config_file $port "$password" "$method"
    start_shadowsocks $port "$password" "$method"
    generate_qr_code $port "$password" "$method"
}

# 执行主函数
main
