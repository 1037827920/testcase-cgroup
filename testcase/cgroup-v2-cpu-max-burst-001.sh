#!/bin/bash
###############################################################################
# @用例ID: 20240804-223507-640719663
# @用例名称: cgroup-v2-cpu-max-burst-001
# @用例级别: 1
# @用例标签: cgroup-v2 cpu max burst
# @用例类型: 测试cpu.max.burst接口文件，设置限制，并设置burst时间
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

CGROUP="cgroup-v2-cpu-max-burst-001"

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
    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 设置cpu.max值
    echo "100000 1000000" >"$CGROUP_TOPDIR"/$CGROUP/cpu.max

    # @测试步骤:2: 设置cpu.max.burst值
    echo "50000" >"$CGROUP_TOPDIR"/$CGROUP/cpu.max.burst

    # @测试步骤:3: 启动一个占用CPU的进程，并将其放入cgroup
    {
        while true; do :; done
    } &
    task_pid=$!
    echo $task_pid >"$CGROUP_TOPDIR"/$CGROUP/cgroup.procs
    sleep 3

    # @测试步骤:4: 读取cpu.stat文件
    cpu_stat=$(cat "$CGROUP_TOPDIR"/$CGROUP/cpu.stat)
    msg "cpu_stat: "
    msg "$cpu_stat"
    nr_bursts=$(echo "$cpu_stat" | grep nr_bursts | awk '{print $2}')
    burst_usec=$(echo "$cpu_stat" | grep burst_usec | awk '{print $2}')

    # @预期结果:1: cpu.stat文件中的burst_usec和nr_bursts均大于0
    if [ "$nr_bursts" -gt 0 ]; then
        assert_true [ "$burst_usec" -eq 50000 ]
    else
        assert_false [ true ]
    fi

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 清理后台进程
    kill -9 "$task_pid"
    sleep 1
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/$CGROUP
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
