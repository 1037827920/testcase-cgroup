#!/bin/bash

if ! command -v yum &> /dev/null; then
    dnf install -y yum
fi
# 定义要安装的软件包及其安装命令
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

# 遍历软件包列表并安装
for package in "${packages[@]}"; do
    echo "Installing $package..."
    yum install -y "$package"
done

echo "All packages installed successfully!"
