#!/bin/bash
###############################################################################
# @用例ID: 20240806-181220-908479593
# @用例名称: cgroup-v2-memory-high-001
# @用例级别: 1
# @用例标签: cgroup-v2 memory high
# @用例类型: 测试memory.high接口文件，测试是否能有效控制匿名内存和页缓存所消耗的内存量
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

CGROUP="cgroup-v2-memory-high-001"

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
    # @测试步骤:1: 读取memory.high的值
    memory_high=$(cat "$CGROUP_TOPDIR"/$CGROUP/memory.high)

    # @预期结果:1: memory.high的值为max
    assert_true [ "$memory_high" = "max" ]

    # @测试步骤:2: 关闭CGROUP中的swapping
    echo 0 >"$CGROUP_TOPDIR"/$CGROUP/memory.swap.max

    # @测试步骤:3: 设置memory.high的值为30M
    echo 30M >"$CGROUP_TOPDIR"/$CGROUP/memory.high

    # @测试步骤:4: 分配31MB匿名内存
    "$TST_TS_TOPDIR"/tst_lib/cgroup_util/bin/alloc_anon 31M &
    task_pid=$!
    echo $task_pid >"$CGROUP_TOPDIR"/$CGROUP/cgroup.procs
    sleep 2

    # @预期结果:2: 分配成功
    if [ "$(wc -c <"$CGROUP_TOPDIR/$CGROUP/cgroup.procs")" -eq 0 ]; then
        assert_false [ true ]
    else
        msg "分配成功"
        assert_true [ true ]
    fi
    kill -9 $task_pid

    # @测试步骤:5: 分配50MB页缓存
    echo $$ >"$CGROUP_TOPDIR"/$CGROUP/cgroup.procs
    "$TST_TS_TOPDIR"/tst_lib/cgroup_util/bin/alloc_pagecache 50M &
    sleep 2

    # @测试步骤:6: 获取memory.current
    total_memory_current=0
    for _ in $(seq 1 8); do
        memory_current=$(cat "$CGROUP_TOPDIR"/$CGROUP/memory.current)
        memory_current=$(echo "$memory_current / 1024 / 1024" | bc)
        total_memory_current=$(echo "$total_memory_current + $memory_current" | bc)
        sleep 1
    done
    aver_memory_current=$(echo "$total_memory_current / 8" | bc)
    msg "average memory current: $aver_memory_current"
    sleep 1

    # @预期结果:3: memory.current小于50MB
    assert_true [ "$aver_memory_current" -lt 50 ]

    # @测试步骤:7: 分配30MB页缓存
    echo $$ >"$CGROUP_TOPDIR"/$CGROUP/cgroup.procs
    "$TST_TS_TOPDIR"/tst_lib/cgroup_util/bin/alloc_pagecache 30M &
    sleep 2

    # @测试步骤:8: 获取memory.current
    total_memory_current=0
    for _ in $(seq 1 8); do
        memory_current=$(cat "$CGROUP_TOPDIR"/$CGROUP/memory.current)
        memory_current=$(echo "$memory_current / 1024 / 1024" | bc)
        total_memory_current=$(echo "$total_memory_current + $memory_current" | bc)
        sleep 1
    done
    aver_memory_current=$(echo "$total_memory_current / 8" | bc)
    msg "average memory current: $aver_memory_current"
    sleep 1

    # @预期结果:4: 在误差允许范围内memory.current等于30MB
    TOLERANCE=$(echo "($aver_memory_current + 30) * 0.05" | bc)
    msg "tolerance: $TOLERANCE"
    diff=$((aver_memory_current - 30))
    abs_diff=${diff#-}
    assert_true [ "$(echo "$abs_diff < $TOLERANCE" | bc)" -eq 1 ]

    # @测试步骤:9: 获取CGROUP内存达到memory.high的次数
    high_cnt=$(grep "high" "$CGROUP_TOPDIR"/$CGROUP/memory.events | awk '{print $2}')
    msg "high cnt: $high_cnt"

    # @预期结果:5: high_cnt大于0
    assert_true [ "$high_cnt" -gt "0" ]

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 将shell进程移出cgroup
    echo $$ >"$CGROUP_TOPDIR"/cgroup.procs
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/$CGROUP
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
