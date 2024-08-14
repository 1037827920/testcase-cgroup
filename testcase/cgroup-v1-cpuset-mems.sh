#!/bin/bash
###############################################################################
# @用例ID: 20240714-191803-023497569
# @用例名称: cgroup-v1-cpuset-mems
# @用例级别: 1
# @用例标签: cgroup-v1 cpuset mems
# @用例类型: 测试cpuset.mems接口文件
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

CGROUP="cgroup-v1-cpuset-mems"

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

    # @预置条件: 创建一个新的cgroup
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

    # @测试步骤:3: 设置root cgroup和CGROUP的cpuset.cpu_exclusive为1
    echo 1 >"$CGROUP_TOPDIR"/cpuset/cpuset.cpu_exclusive
    echo 1 >"$CGROUP_TOPDIR"/cpuset/$CGROUP/cpuset.cpu_exclusive

    # @测试步骤:4: 获取mem online list
    file_path="$CGROUP_TOPDIR"/cpuset/cpuset.effective_mems
    mem_online_list=$(get_online_mem_list "$file_path")
    msg "mem_online_list: $mem_online_list"

    # @测试步骤:5: 获取两个在线mem
    first_online_mem=$(echo "$mem_online_list" | awk '{print $1}')
    msg "first_online_mem: $first_online_mem"

    # @测试步骤:6: 设置CGROUP的cpuset.mems
    echo "$first_online_mem" >"$CGROUP_TOPDIR"/cpuset/$CGROUP/cpuset.mems

    # @测试步骤:7: 启动一个进程并将其放入cgroup
    {
        while true; do :; done
    } &
    task_pid=$!
    echo $task_pid >"$CGROUP_TOPDIR"/cpuset/$CGROUP/cgroup.procs
    sleep 1

    # @测试步骤:8: 获取进程绑定的NUMA节点的内存使用量
    memory_usage=$(numastat -p $task_pid | awk -v col="$((first_online_mem + 2))" 'END{print $col}')

    # @预期结果:1: memory_usage大于0
    assert_true [ "$(echo "$memory_usage > 0" | bc)" -eq 1 ]

    # @测试步骤:3: 检查进程绑定的NUMA节点
    mems_allowed=$(cat /proc/$task_pid/status | grep "Mems_allowed_list" | awk '{print $2}')

    # @预测结果:2: 验证进程是否只在指定的内存节点上运行
    if [ "$mems_allowed" = "$first_online_mem" ]; then
        msg "进程绑定到NUMA节点1"
        assert_true [ true ]
    else
        msg "进程未绑定到NUMA节点1"
        return 1 # 测试失败
    fi

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 清空后台进程
    kill -9 "$task_pid"
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/cpuset/$CGROUP
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
