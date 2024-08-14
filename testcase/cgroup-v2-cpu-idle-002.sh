#!/bin/bash
###############################################################################
# @用例ID: 20240805-223054-480591007
# @用例名称: cgroup-v2-cpu-idle-002
# @用例级别: 2
# @用例标签: cgroup-v2 cpu idle
# @用例类型: 测试cpu.idle接口文件，不设置SCHD_IDLE调度策略
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

CGROUP="cgroup-v2-cpu-idle-002"
CHILD0="$CGROUP/child0"
CHILD1="$CGROUP/child1"
TMP_FILE=$(mktemp)

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

    # @测试步骤:5: 启动一个占用CPU的进程，并将其放入CHILD0
    {
        while true; do :; done
    } &
    task_pid1=$!
    echo $task_pid1 >"$CGROUP_TOPDIR"/$CHILD0/cgroup.procs

    # @测试步骤:6: 启动另一个占用CPU的进程并将其放入CHILD1
    {
        while true; do :; done
    } &
    task_pid2=$!
    echo $task_pid2 >"$CGROUP_TOPDIR"/$CHILD1/cgroup.procs

    # @测试步骤:7: 使用top命令循环获取task_pid的cpu利用率
    total_cpu_usage=0
    for _ in $(seq 1 10); do
        top -b -n 1 -p $task_pid1 >"$TMP_FILE"
        cpu_usage=$(grep -A 1 "%CPU" "$TMP_FILE" | tail -n 1 | awk '{print $9}')
        total_cpu_usage=$(echo "$total_cpu_usage + $cpu_usage" | bc)
        sleep 1
    done
    aver_cpu_usage=$(echo "scale=2; $total_cpu_usage / 10" | bc)
    msg "average CPU usage: $aver_cpu_usage"

    # @预期结果:1: 在误差范围内，task_pid1的cpu利用率不为0
    assert_true [ "$(echo "$aver_cpu_usage > 0" | bc)" -eq 1 ]

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
    # @清理工作: 删除临时文件
    rm "$TMP_FILE"
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
