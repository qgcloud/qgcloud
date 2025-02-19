#!/bin/bash
#
#   Dante Socks5 Server AutoInstall
#   -- Owner:       https://www.inet.no/dante
#   -- Provider:    https://sockd.info
#   -- Author:      Lozy

# Check if user is root
if [ $(id -u) != "0" ]; then
    echo "Error: You must be root to run this script, please use root to install"
    exit 1
fi

# Define URLs for script sources
REQUEST_SERVER="https://raw.githubusercontent.com/Lozy/danted/master"
SCRIPT_SERVER="https://public.sockd.info"
SYSTEM_RECOGNIZE=""

# Check if --no-github flag is provided
[ "$1" == "--no-github" ] && REQUEST_SERVER=${SCRIPT_SERVER}

# Function to enable BBR
enable_bbr() {
    echo "Enabling TCP BBR congestion control..."
    # Add BBR settings to sysctl configuration
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    # Apply changes immediately
    sysctl -p
    if [ $? -eq 0 ]; then
        echo "BBR enabled successfully."
    else
        echo "[Error] Failed to enable BBR."
        exit 1
    fi
}

# Detect OS
if [ -s "/etc/os-release" ]; then
    os_name=$(sed -n 's/PRETTY_NAME="\(.*\)"/\1/p' /etc/os-release)
    if [ -n "$(echo ${os_name} | grep -Ei 'Debian|Ubuntu')" ]; then
        printf "Current OS: %s\n" "${os_name}"
        SYSTEM_RECOGNIZE="debian"
    elif [ -n "$(echo ${os_name} | grep -Ei 'CentOS')" ]; then
        printf "Current OS: %s\n" "${os_name}"
        SYSTEM_RECOGNIZE="centos"
    else
        printf "Current OS: %s is not supported.\n" "${os_name}"
    fi
elif [ -s "/etc/issue" ]; then
    if [ -n "$(grep -Ei 'CentOS' /etc/issue)" ]; then
        printf "Current OS: %s\n" "$(grep -Ei 'CentOS' /etc/issue)"
        SYSTEM_RECOGNIZE="centos"
    else
        printf "+++++++++++++++++++++++\n"
        cat /etc/issue
        printf "+++++++++++++++++++++++\n"
        printf "[Error] Current OS: is not available to support.\n"
    fi
else
    printf "[Error] (/etc/os-release) OR (/etc/issue) not exist!\n"
    printf "[Error] Current OS: is not available to support.\n"
fi

# Enable BBR if OS is recognized
if [ -n "$SYSTEM_RECOGNIZE" ]; then
    enable_bbr
    echo "Downloading installation script for ${SYSTEM_RECOGNIZE}..."
    wget -qO- --no-check-certificate ${REQUEST_SERVER}/install_${SYSTEM_RECOGNIZE}.sh | bash -s -- $*
    if [ $? -ne 0 ]; then
        echo "[Error] Failed to download or execute the installation script."
        exit 1
    fi
else
    printf "[Error] Installing terminated\n"
    exit 1
fi

exit 0
