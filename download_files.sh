#!/bin/bash

# 远程文件路径
remote_file="/root/client.ovpn"
# 本地目录
local_dir="D:/abc"
# 云服务器的用户名
username="root"
# 云服务器的密码
password="Aa778409@"

# 读取ips.txt文件中的每个IP地址
while read -r ip; do
    echo "Downloading from $ip"
    # 使用scp下载文件，并重命名文件名为IP+文件名
    # 注意：这种方法不安全，因为它在命令行中暴露了密码
    scp ${password}@${ip}:${remote_file} ${local_dir}/${ip}-${remote_file##*/}
done < ips.txt
