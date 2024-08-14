#!/bin/bash

# 检查是否以root用户运行
is_root() {
    if [ "$EUID" -ne 0 ]; then
        return 1
    fi
    return 0
}

# 检查是否安装了dd工具
is_dd_installed() {
    if ! command -v dd &> /dev/null; then
        return 1
    fi
    return 0
}

# 检查是否安装了tc工具
is_tc_installed() {
    if ! command -v tc &> /dev/null; then
        return 1
    fi
    return 0
}

# 检查是否安装了iperf3工具
is_iperf3_installed() {
    if ! command -v iperf3 &> /dev/null; then
        return 1
    fi
    return 0
}

# 检查是否安装了perf工具
is_perf_installed() {
    if ! command -v perf &> /dev/null; then
        return 1
    fi
    return 0
}

# 检查是否安装了numactl工具
is_numactl_installed() {
    if ! command -v numactl &> /dev/null; then
        return 1
    fi
    return 0
}

# 检查是否安装了numastat工具
is_numastat_installed() {
    if ! command -v numastat &> /dev/null; then
        return 1
    fi
    return 0
}

# 检查是否安装了mpstat命令
is_sysstat_installed() {
    if ! command -v mpstat &> /dev/null; then
        return 1
    fi
    return 0
}

# 检查是否安装了bc命令
is_bc_installed() {
    if ! command -v bc &> /dev/null; then
        return 1
    fi
    return 0
}

# 检查cgroup版本是否为cgroup v1
check_cgroup_version_is_v1() {
    if [ "$(stat -fc %T "$CGROUP_TOPDIR")" = "tmpfs" ]; then
        return 0
    else 
        return 1
    fi
}
# 检查cgroup版本是否为cgroup v2
check_cgroup_version_is_v2() {
    if [ "$(stat -fc %T "$CGROUP_TOPDIR")" = "cgroup2fs" ]; then
        return 0
    else 
        return 1
    fi
}

# 检查文件中是否包含指定字符串
check_string_in_file() {
    local string="$1"
    local file="$2"

    if grep -q "$string" "$file"; then
        return 0
    else
        return 1
    fi
}

# 获取cgroup可用的cpu列表
get_online_cpu_list() {
    local file_path=$1
    local cpu_effective
    local cpu_list=()

    cpu_effective=$(cat "$file_path")

    # 提取所有 CPU 序号
    IFS=',' read -r -a ranges <<< "$cpu_effective"
    for range in "${ranges[@]}"; do
        if [[ $range =~ ^[0-9]+-[0-9]+$ ]]; then
            # 处理范围格式，如 "0-1"
            IFS='-' read -r start end <<< "$range"
            for ((i=start; i<=end; i++)); do
                cpu_list+=("$i")
            done
        else
            # 处理单个 CPU 序号，如 "4"
            cpu_list+=("$range")
        fi
    done

    # 返回 cpu_list 数组
    echo "${cpu_list[@]}"
}

# 获取cgroup可用的mem列表
get_online_mem_list() {
    local file_path=$1
    local mem_effective
    local mem_list=()

    mem_effective=$(cat "$file_path")
    
    IFS=',' read -r -a ranges <<< "$mem_effective"
    for range in "${ranges[@]}"; do
        if [[ $range =~ ^[0-9]+-[0-9]+$ ]]; then
            IFS='-' read -r start end <<< "$range"
            for ((i=start; i<=end; i++)); do
                mem_list+=("$i")
            done
        else
            mem_list+=("$range")
        fi
    done

    echo "${mem_list[@]}"
}