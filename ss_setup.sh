#!/bin/bash

# 检查操作系统类型和版本
os=""
version=""

if [ -f /etc/os-release ]; then
    . /etc/os-release
    os=$ID
    version=$VERSION_ID
elif [ -f /etc/centos-release ]; then
    os="centos"
    version=$(rpm -q --queryformat '%{VERSION}' centos-release | cut -d. -f1)
else
    echo "不支持的操作系统"
    exit 1
fi

# 下载和安装 gost
wget https://github.com/go-gost/gost/releases/download/v3.0.0-rc8/gost_3.0.0-rc8_linux_amd64v3.tar.gz
tar -zxvf gost_3.0.0-rc8_linux_amd64v3.tar.gz
mv gost /usr/local/bin/
chmod +x /usr/local/bin/gost

# 删除下载的压缩文件
rm -f gost_3.0.0-rc8_linux_amd64v3.tar.gz

# 检查参数数量
if [ "$#" -ne 3 ]; then
    echo "使用方法: $0 <socks5user> <socks5password> <socks5port>"
    exit 1
fi

# 获取参数
SOCKS5_USER=$1
SOCKS5_PASSWORD=$2
SOCKS5_PORT=$3

# 创建 Systemd 服务
echo "[Unit]
Description=Gost Proxy Service
After=network.target

[Service]
ExecStart=/usr/local/bin/gost \
-L \"http://$SOCKS5_USER:$SOCKS5_PASSWORD@:2080?limiter.in=20MB&limiter.out=20MB&climiter=11\" \
-L \"socks5://$SOCKS5_USER:$SOCKS5_PASSWORD@:$SOCKS5_PORT?udp=true&limiter.in=20MB&limiter.out=20MB&climiter=11\" \
-L \"ss://aes-128-gcm:pass@:8338?limiter.in=20MB&limiter.out=20MB&climiter=11\" \
-L \"ssu+udp://aes-128-gcm:pass@:8338?limiter.in=20MB&limiter.out=20MB&climiter=11\"
Restart=always

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/gost.service

# 根据操作系统进行特定操作
if [[ "$os" == "ubuntu" || "$os" == "debian" ]]; then
    echo "Detected $os $version"
    sudo systemctl daemon-reload
    sudo systemctl enable gost
    sudo systemctl start gost
elif [[ "$os" == "centos" ]]; then
    if [[ "$version" -ge 7 && "$version" -le 9 ]]; then
        echo "Detected CentOS $version"
        sudo systemctl daemon-reload
        sudo systemctl enable gost
        sudo systemctl start gost
    else
        echo "不支持的 CentOS 版本"
        exit 1
    fi
else
    echo "不支持的操作系统"
    exit 1
fi
