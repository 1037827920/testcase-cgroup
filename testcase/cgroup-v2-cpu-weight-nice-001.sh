#!/bin/bash
###############################################################################
# @用例ID: 20240804-175245-433198185
# @用例名称: cgroup-v2-cpu-weight-nice-001
# @用例级别: 2
# @用例标签: cgroup-v2 cpu weight nice
# @用例类型: 测试cpu.weight.nice接口文件
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

CGROUP="cgroup-v2-cpu-weight-nice-001"
CHILD0="$CGROUP/child0"
CHILD1="$CGROUP/child1"

tc_setup() {
    msg "this is tc_setup"
    # @预置条件: 检查cgroup版本是否为cgroup v2
    if ! check_cgroup_version_is_v2; then
        skip_test "cgroup版本不是v2"
    fi

    # @预置条件: 创建cgroup
    mkdir "$CGROUP_TOPDIR"/$CGROUP
    # @预置条件: 检查当前cgroup是否能启用cpu控制器
    if ! check_string_in_file "cpu" "$CGROUP_TOPDIR/cgroup.controllers"; then
        skip_test "当前cgroup不能启用cpu控制器"
    fi
    # @预置条件: 启用cpu控制器
    echo "+cpu" >"$CGROUP_TOPDIR"/cgroup.subtree_control || return 1
    echo "+cpu" >"$CGROUP_TOPDIR"/$CGROUP/cgroup.subtree_control || return 1
    # @预置条件: 获取系统cpu的数量
    cpu_nums=$(grep -c ^processor /proc/cpuinfo)
    msg "cpu_nums: $cpu_nums"
    for_cpu_nums=$((cpu_nums - 2))

    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 获取cpu online list
    file_path="$CGROUP_TOPDIR"/$CGROUP/cpuset.cpus.effective
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

        echo "$first_online_cpu" >"$CGROUP_TOPDIR"/$CGROUP/cpuset.cpus && ret=0 && break
    done
    if [ $ret -ne 0 ]; then
        skip_test "没有可独占的CPU"
    fi

    # @测试步骤:3: 独占该CPU
    echo "root" >"$CGROUP_TOPDIR"/$CGROUP/cpuset.cpus.partition

    # @测试步骤:4: 创建子cgroup
    mkdir "$CGROUP_TOPDIR"/$CHILD0
    mkdir "$CGROUP_TOPDIR"/$CHILD1

    # @测试步骤:5: 对不同的cgroup设置不同的cpu.weight.nice值
    echo 10 >"$CGROUP_TOPDIR"/$CHILD0/cpu.weight.nice
    echo 0 >"$CGROUP_TOPDIR"/$CHILD1/cpu.weight.nice

    # @测试步骤:6: 启动两个占用CPU的进程，并将其放入不同的cgroup，保证两个进程在同一个CPU核心上运行
    {
        while true; do :; done
    } &
    task_pid1=$!
    echo $task_pid1 >"$CGROUP_TOPDIR"/"$CHILD0"/cgroup.procs
    {
        while true; do :; done
    } &
    task_pid2=$!
    echo $task_pid2 >"$CGROUP_TOPDIR"/"$CHILD1"/cgroup.procs

    sleep 3

    # @测试步骤:7: 获取两个cgroup的CPU使用时间
    cpu_usage_usec1=$(grep usage_usec "$CGROUP_TOPDIR"/"$CHILD0"/cpu.stat | awk '{print $2}')
    cpu_usage_usec2=$(grep usage_usec "$CGROUP_TOPDIR"/"$CHILD1"/cpu.stat | awk '{print $2}')
    msg "cpu usage usec1: $cpu_usage_usec1"
    msg "cpu usage usec2: $cpu_usage_usec2"

    # @预期结果:1: 验证CPU使用时间比例是否符合预期，cgroup1小于cgroup2
    assert_true [ "$cpu_usage_usec1" -lt "$cpu_usage_usec2" ]

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 清理后台进程
    kill -9 "$task_pid1" "$task_pid2"
    sleep 1
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/$CHILD0
    rmdir "$CGROUP_TOPDIR"/$CHILD1
    rmdir "$CGROUP_TOPDIR"/$CGROUP
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
