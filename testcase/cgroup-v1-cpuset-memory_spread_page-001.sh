#!/bin/bash
###############################################################################
# @用例ID: 20240719-105612-324932394
# @用例名称: cgroup-v1-cpuset-memory_spread_page-001
# @用例级别: 2
# @用例标签: cgroup-v1 cpuset memory_spread_page
# @用例类型: 测试cpuset.memory_spread_page接口文件，测试不将page cache平均分布道各个节点中
###############################################################################
[ -z "$TST_TS_TOPDIR" ] && {
    TST_TS_TOPDIR="$(realpath "$(dirname "$0")/..")"
    export TST_TS_TOPDIR
}
[ -z "$CGROUP_TOPDIR" ] && {
    CGROUP_TOPDIR="/sys/fs/cgroup"
    export CGROUP_TOPDIR
}
# shellcheck source=/dev/null
source "${TST_TS_TOPDIR}/tst_common/lib/common.sh" || exit 1
# shellcheck source=/dev/null
source "${TST_TS_TOPDIR}/tst_lib/other_common.sh" || exit 1
###############################################################################

CGROUP="cgroup-v1-cpuset-memory_spread_page-001"

tc_setup() {
    msg "this is tc_setup"
    # @预置条件: 检查cgroup版本是否为cgroup v1
    if ! check_cgroup_version_is_v1; then
        skip_test "cgroup版本不是v1"
    fi
    # @预置条件：检查numactl命令是否存在
    if ! is_numactl_installed; then
        skip_test "numactl 未安装, 请先安装numactl"
    fi
    # @预置条件：检查是否支持NUMA
    numa_nodes=$(numactl -H | grep "available" | cut -d' ' -f2)
    if [ "$numa_nodes" = "0" ]; then
        skip_test "系统不支持NUMA架构"
    fi
    # @预置条件：检查NUMA节点数量是否大于1
    if [ "$numa_nodes" -lt 2 ]; then
        skip_test "系统NUMA节点数量小于2"
    fi

    # @预置条件: 创建新的cgroup
    mkdir "$CGROUP_TOPDIR"/cpuset/$CGROUP
    # @预置条件: 获取系统cpu的数量
    cpu_nums=$(grep -c ^processor /proc/cpuinfo)
    msg "cpu_nums: $cpu_nums"
    for_cpu_nums=$((cpu_nums - 2))

    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 获取cpu online list
    file_path="$CGROUP_TOPDIR"/cpuset/cpuset.effective_cpus
    cpu_online_list=$(get_online_cpu_list "$file_path")
    msg "cpu_online_list: $cpu_online_list"

    # @测试步骤:2: 获取没被独占的一个在线cpu
    ret=-1
    for i in $(seq 0 "$for_cpu_nums"); do
        first_online_cpu=$(echo "$cpu_online_list" | awk -v col="$((i + 1))" '{print $col}')
        msg "first_online_cpu: $first_online_cpu"
        if [ -z "$first_online_cpu" ]; then
            skip_test "没有足够的在线cpu"
        fi

        echo "$first_online_cpu" >"$CGROUP_TOPDIR"/cpuset/$CGROUP/cpuset.cpus && ret=0 && break
    done
    if [ $ret -ne 0 ]; then
        skip_test "没有可独占的CPU"
    fi

    # @测试步骤:3: 独占该CPU
    echo 1 >"$CGROUP_TOPDIR"/cpuset/cpuset.cpu_exclusive
    echo 1 >"$CGROUP_TOPDIR"/cpuset/$CGROUP/cpuset.cpu_exclusive

    # @测试步骤:4: 获取mem online list
    file_path="$CGROUP_TOPDIR"/cpuset/cpuset.effective_mems
    mem_online_list=$(get_online_mem_list "$file_path")
    msg "mem_online_list: $mem_online_list"

    # @测试步骤:5: 获取两个在线mem
    first_online_mem=$(echo "$mem_online_list" | awk '{print $1}')
    msg "first_online_mem: $first_online_mem"
    second_online_cpu=$(echo "$mem_online_list" | awk '{print $2}')
    msg "second_online_cpu: $second_online_cpu"
    echo "$first_online_mem-$second_online_cpu" >"$CGROUP_TOPDIR"/cpuset/$CGROUP/cpuset.mems

    # @测试步骤:6: 获取numa node0和numa node1的FilePages
    node0_pagecache=$(numastat -m | grep FilePages | awk '{print $2}')
    node1_pagecache=$(numastat -m | grep FilePages | awk '{print $3}')
    msg "node0_pagecache: $node0_pagecache"
    msg "node1_pagecache: $node1_pagecache"

    # @测试步骤:7: 运行一个需要申请page cache的程序
    "$TST_TS_TOPDIR"/tst_lib/cgroup_util/bin/alloc_pagecache 100M &
    task_pid=$!
    echo $task_pid >"$CGROUP_TOPDIR"/cpuset/$CGROUP/cgroup.procs
    sleep 2

    # @测试步骤:8: 不断检查numa节点的FilePages大小
    total_node0_pagecache=0
    total_node1_pagecache=0
    for _ in $(seq 1 8); do
        node0_current_pagecache=$(numastat -m | grep FilePages | awk '{print $2}')
        node1_current_pagecache=$(numastat -m | grep FilePages | awk '{print $3}')
        total_node0_pagecache=$(echo "$node0_current_pagecache + $total_node0_pagecache" | bc)
        total_node1_pagecache=$(echo "$node1_current_pagecache + $total_node1_pagecache" | bc)
        sleep 1
    done
    aver_node0_pagecache=$(echo "scale=2; $total_node0_pagecache / 8" | bc)
    aver_node1_pagecache=$(echo "scale=2; $total_node1_pagecache / 8" | bc)
    msg "aver_node0_pagecache: $aver_node0_pagecache"
    msg "aver_node1_pagecache: $aver_node1_pagecache"

    # @预期结果:1: 在误差允许的范围内，node0_diff = 100, node1_diff < 3
    node0_diff=$(echo "scale=2; $aver_node0_pagecache - $node0_pagecache" | bc)
    abs_node0_diff=${node0_diff//-/}
    node1_diff=$(echo "scale=2; $aver_node1_pagecache - $node1_pagecache" | bc)
    abs_node1_diff=${node1_diff//-/}
    if [ "$(echo "$abs_node0_diff >= 98" | bc)" -eq 1 ] && [ "$(echo "$abs_node1_diff <= 102" | bc)" -eq 1 ]; then
        assert_true [ "$(echo "$abs_node1_diff < 3" | bc)" -eq 1 ]
    else
        assert_false [ true ]
    fi

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    sleep 1
    # @清理动作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/cpuset/$CGROUP
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
