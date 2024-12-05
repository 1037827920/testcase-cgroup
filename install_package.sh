#!/bin/bash

# 检查系统是否有yum命令
if command -v yum &> /dev/null; then
    package_manager="yum"
else
    package_manager="apt"
    apt update
fi

# 定义要安装的软件包及其安装命令
if [ "$package_manager" == "yum" ]; then
    packages=(
        "git"
        "numactl"
        "iperf3"
        "iproute-tc"
        "perf"
        "sysstat"
        "make"
        "gcc"
        "bc"
    )
else
    packages=(
        "git"
        "numactl"
        "iperf3"
        "iproute2"
        "linux-tools-common"
        "sysstat"
        "make"
        "gcc"
        "bc"
    )
fi

# 遍历软件包列表并安装
for package in "${packages[@]}"; do
    echo "Installing $package..."
    if [ "$package_manager" == "yum" ]; then
        yum install -y "$package"
    else
        apt install -y "$package"
    fi
done

echo "All packages installed successfully!"
