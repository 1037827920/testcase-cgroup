#!/bin/bash
###############################################################################
# @用例ID: 20240711-102849-220066922
# @用例名称: cgroup-v1-cpu-shares
# @用例级别: 1
# @用例标签: cgroup-v1 cpu shares
# @用例类型: 测试cpu.shares接口文件
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

CGROUP="cgroup-v1-cpu-shares"
CHILD0="$CGROUP/child0"
CHILD1="$CGROUP/child1"

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

    # @预置条件：创建cgroup
    mkdir "$CGROUP_TOPDIR"/cpu/$CGROUP
    mkdir "$CGROUP_TOPDIR"/cpuset/$CGROUP
    mkdir "$CGROUP_TOPDIR"/cpu/$CHILD0
    mkdir "$CGROUP_TOPDIR"/cpuset/$CHILD0
    mkdir "$CGROUP_TOPDIR"/cpu/$CHILD1
    mkdir "$CGROUP_TOPDIR"/cpuset/$CHILD1
    # @预置条件: 设置cpuset.mems文件
    echo 0 >"$CGROUP_TOPDIR"/cpuset/$CGROUP/cpuset.mems
    echo 0 >"$CGROUP_TOPDIR"/cpuset/$CHILD0/cpuset.mems
    echo 0 >"$CGROUP_TOPDIR"/cpuset/$CHILD1/cpuset.mems
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
    echo "$first_online_cpu" >"$CGROUP_TOPDIR"/cpuset/$CHILD0/cpuset.cpus
    echo "$first_online_cpu" >"$CGROUP_TOPDIR"/cpuset/$CHILD1/cpuset.cpus

    # @测试步骤:3: 独占该CPU
    echo 1 >"$CGROUP_TOPDIR"/cpuset/cpuset.cpu_exclusive
    echo 1 >"$CGROUP_TOPDIR"/cpuset/$CGROUP/cpuset.cpu_exclusive

    # 测试步骤:4: 对不同的cgroup设置不同的cpu.shares值
    echo 2048 >"$CGROUP_TOPDIR"/cpu/"$CHILD0"/cpu.shares
    echo 512 >"$CGROUP_TOPDIR"/cpu/"$CHILD1"/cpu.shares

    # @测试步骤:5: 启动两个占用CPU的进程，并将其放入不同的cgroup
    {
        while true; do :; done
    } &
    task_pid0=$!
    echo $task_pid0 >"$CGROUP_TOPDIR"/cpu/"$CHILD0"/cgroup.procs
    echo $task_pid0 >"$CGROUP_TOPDIR"/cpuset/"$CHILD0"/cgroup.procs
    {
        while true; do :; done
    } &
    task_pid1=$!
    echo $task_pid1 >"$CGROUP_TOPDIR"/cpu/"$CHILD1"/cgroup.procs
    echo $task_pid1 >"$CGROUP_TOPDIR"/cpuset/"$CHILD1"/cgroup.procs
    sleep 3

    # @测试步骤:6: 获取两个cgroup的CPU使用时间
    usage1=$(cat "$CGROUP_TOPDIR"/cpu/"$CHILD0"/cpuacct.usage)
    usage2=$(cat "$CGROUP_TOPDIR"/cpu/"$CHILD1"/cpuacct.usage)

    msg "usage1: $usage1"
    msg "usage2: $usage2"

    # @预期结果:1: 验证CPU使用时间比例是否符合预期，4：1
    usage_ratio=$(echo "scale=2; $usage1 / $usage2" | bc)
    usage_ratio=$(printf "%.0f" "$usage_ratio")
    expected_ratio=4
    assert_true [ "$(echo "$usage_ratio >= $expected_ratio" | bc)" -eq 1 ]

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 清理后台进程
    kill -9 "$task_pid0" "$task_pid1"
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/cpu/$CHILD0
    rmdir "$CGROUP_TOPDIR"/cpu/$CHILD1
    rmdir "$CGROUP_TOPDIR"/cpu/$CGROUP
    rmdir "$CGROUP_TOPDIR"/cpuset/$CHILD0
    rmdir "$CGROUP_TOPDIR"/cpuset/$CHILD1
    rmdir "$CGROUP_TOPDIR"/cpuset/$CGROUP
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
