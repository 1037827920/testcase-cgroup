#!/bin/bash
###############################################################################
# @用例ID: 20240804-180942-698874070
# @用例名称: cgroup-v2-cpu-max
# @用例级别: 1
# @用例标签: cgroup-v2 cpu max
# @用例类型: 测试cpu.max接口文件，设置限制
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

CGROUP="cgroup-v2-cpu-max"

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
    # @测试步骤:1: 设置CGROUP的cpu.max值
    echo "100000 1000000" >"$CGROUP_TOPDIR"/$CGROUP/cpu.max

    # @测试步骤:2: 启动一个占用CPU的进程，并将其放入cgroup
    {
        while true; do :; done
    } &
    task_pid=$!
    echo $task_pid >"$CGROUP_TOPDIR"/$CGROUP/cgroup.procs
    sleep 3

    # @测试步骤:3: 读取cpu.stat文件
    cpu_stat=$(cat "$CGROUP_TOPDIR"/$CGROUP/cpu.stat)
    nr_periods=$(echo "$cpu_stat" | grep nr_periods | awk '{print $2}')
    nr_throttled=$(echo "$cpu_stat" | grep nr_throttled | awk '{print $2}')
    throttled_usec=$(echo "$cpu_stat" | grep throttled_usec | awk '{print $2}')
    msg "nr_periods: $nr_periods, nr_throttled: $nr_throttled, throttled_usec: $throttled_usec"

    # @预期结果:1: cpu.stat文件中的nr_periods和nr_throttled，throttled_usec均大于0
    if [ "$nr_periods" -gt 0 ] && [ "$nr_throttled" -gt 0 ]; then
        assert_true [ "$throttled_usec" -gt 0 ]
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
