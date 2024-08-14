#!/bin/bash
###############################################################################
# @用例ID: 20240806-235307-525430290
# @用例名称: cgroup-v2-memory-current
# @用例级别: 1
# @用例标签: cgroup-v2 memory current
# @用例类型: 测试memory.current接口文件，分配一些匿名内存和页缓存，查看memory.current的值
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

CGROUP="cgroup-v2-memory-current"

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
    # @测试步骤:1: 读取memory.current的值
    memory_current=$(cat "$CGROUP_TOPDIR"/$CGROUP/memory.current)

    # @预期结果:1: memory.current的值为0
    assert_true [ "$memory_current" -eq 0 ]

    # @测试步骤:2: 分配50MB匿名内存
    echo $$ >"$CGROUP_TOPDIR"/$CGROUP/cgroup.procs
    "$TST_TS_TOPDIR"/tst_lib/cgroup_util/bin/alloc_anon 50M &
    sleep 2

    # @测试步骤:3: 读取memory.current的值
    total_memory_current=0
    for _ in $(seq 1 8); do
        memory_current=$(cat "$CGROUP_TOPDIR"/$CGROUP/memory.current)
        memory_current=$(echo "$memory_current / 1024 / 1024" | bc)
        total_memory_current=$(echo "$memory_current + $total_memory_current" | bc)
        sleep 1
    done
    aver_memory_current=$(echo "$total_memory_current / 8" | bc)
    msg "memory.current: $aver_memory_current MB"
    sleep 3
    echo $$ >"$CGROUP_TOPDIR"/cgroup.procs

    # @预期结果:2: 在误差范围内，memory.current的值为50MB
    TOLERANCE=$(echo "($aver_memory_current + 30) * 0.05" | bc)
    diff=$((aver_memory_current - 50))
    abs_diff=${diff#-}
    assert_true [ "$(echo "$abs_diff < $TOLERANCE" | bc)" -eq 1 ]

    # @测试步骤:4: 分配50MB页缓存
    echo $$ >"$CGROUP_TOPDIR"/$CGROUP/cgroup.procs
    "$TST_TS_TOPDIR"/tst_lib/cgroup_util/bin/alloc_pagecache 50M &
    sleep 2

    # @测试步骤:5: 读取memory.current的值
    total_memory_current=0
    for _ in $(seq 1 8); do
        memory_current=$(cat "$CGROUP_TOPDIR"/$CGROUP/memory.current)
        memory_current=$(echo "$memory_current / 1024 / 1024" | bc)
        total_memory_current=$(echo "$memory_current + $total_memory_current" | bc)
        sleep 1
    done
    aver_memory_current=$(echo "$total_memory_current / 8" | bc)
    msg "memory.current: $aver_memory_current MB"
    sleep 3
    echo $$ >"$CGROUP_TOPDIR"/cgroup.procs

    # @预期结果:3: 在误差范围内，memory.current的值为50MB
    TOLERANCE=$(echo "($aver_memory_current + 30) * 0.05" | bc)
    diff=$((aver_memory_current - 50))
    abs_diff=${diff#-}
    assert_true [ "$(echo "$abs_diff < $TOLERANCE" | bc)" -eq 1 ]

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/$CGROUP
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
