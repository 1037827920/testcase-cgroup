#!/bin/bash
###############################################################################
# @用例ID: 20240806-193843-997660285
# @用例名称: cgroup-v2-memory-reclaim-001
# @用例级别: 2
# @用例标签: cgroup-v2 memory reclaim
# @用例类型: 测试memory.reclaim接口文件，回收page cache
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

CGROUP="cgroup-v2-memory-reclaim-001"

tc_setup() {
    msg "this is tc_setup"
    # @预置条件: 检查cgroup版本是否为cgroup v2
    if ! check_cgroup_version_is_v2; then
        skip_test "cgroup版本不是v2"
    fi

    # @预置条件: 创建cgroup
    mkdir "$CGROUP_TOPDIR"/$CGROUP
    # @预置条件: 检查当前cgroup是否能启用memory控制器
    if ! check_string_in_file "memory" "$CGROUP_TOPDIR/cgroup.controllers"; then
        skip_test "当前cgroup不能启用memory控制器"
    fi
    # @预置条件: 启用memory控制器
    echo "+memory" >"$CGROUP_TOPDIR"/cgroup.subtree_control || return 1
    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 关闭CGROUP的swapping
    echo 0 >"$CGROUP_TOPDIR"/$CGROUP/memory.swap.max

    # @测试步骤:2: 运行一个分配50M页缓存内存的进程
    echo $$ >"$CGROUP_TOPDIR"/$CGROUP/cgroup.procs
    "$TST_TS_TOPDIR"/tst_lib/cgroup_util/bin/alloc_pagecache 50M &
    task_pid=$!
    sleep 1

    # @测试步骤:3: 计算回收前的内存
    before_reclaim=0
    for _ in $(seq 1 5); do
        memory_current=$(cat "$CGROUP_TOPDIR"/$CGROUP/memory.current)
        memory_current=$(echo "$memory_current / 1024 / 1024" | bc)
        before_reclaim=$(echo " $before_reclaim + $memory_current" | bc)
        sleep 1
    done
    aver_before_reclaim=$(echo "$before_reclaim / 5" | bc)

    # @测试步骤:4: 主动回收内存
    echo "40M" >"$CGROUP_TOPDIR"/$CGROUP/memory.reclaim || return 1

    # @测试步骤:5: 计算回收后的内存
    after_reclaim=0
    for _ in $(seq 1 4); do
        memory_current=$(cat "$CGROUP_TOPDIR"/$CGROUP/memory.current)
        memory_current=$(echo "$memory_current / 1024 / 1024" | bc)
        after_reclaim=$(echo " $after_reclaim + $memory_current" | bc)
        sleep 1
    done
    aver_after_reclaim=$(echo "$after_reclaim / 4" | bc)
    sleep 3

    # @预期结果:1: 在误差范围内回收了内存40MB
    diff=$(echo "$aver_before_reclaim - $aver_after_reclaim" | bc)
    msg "diff: $diff"
    diff_max=45
    diff_min=35
    if [ "$diff" -gt $diff_min ]; then
        assert_true [ "$diff" -lt $diff_max ]
    else
        assert_false [ true ]
    fi

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 将shell进程移出cgroup
    kill -9 "$task_pid"
    echo $$ >"$CGROUP_TOPDIR"/cgroup.procs
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/$CGROUP
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
