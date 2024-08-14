#!/bin/bash
###############################################################################
# @用例ID: 20240806-175358-337059818
# @用例名称: cgroup-v2-memory-low-001
# @用例级别: 1
# @用例标签: cgroup-v2 memory low
# @用例类型: 测试memoruy.low接口文件，parent1/2的父cgroup设置的内存上限是200MB, parent2分配的内存为146MB, 不会占用parent1的memory.low保护的内存50MB
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

CGROUP="cgroup-v2-memory-low-001"
PARENT1="$CGROUP/parent1"
PARENT2="$CGROUP/parent2"
CHILD0="$PARENT1/child0"
CHILD1="$PARENT1/child1"
CHILD2="$PARENT1/child2"

tc_setup() {
    msg "this is tc_setup"
    # @预置条件: 检查cgroup版本是否为cgroup v2
    if ! check_cgroup_version_is_v2; then
        skip_test "cgroup版本不是v2"
    fi

    # @预置条件: 创建cgroup
    mkdir "$CGROUP_TOPDIR"/$CGROUP
    mkdir "$CGROUP_TOPDIR"/$PARENT1
    mkdir "$CGROUP_TOPDIR"/$PARENT2
    mkdir "$CGROUP_TOPDIR"/$CHILD0
    mkdir "$CGROUP_TOPDIR"/$CHILD1
    mkdir "$CGROUP_TOPDIR"/$CHILD2
    # @预置条件: 检查当前cgroup是否能启用memory控制器
    if ! check_string_in_file "memory" "$CGROUP_TOPDIR/cgroup.controllers"; then
        skip_test "当前cgroup不能启用memory控制器"
    fi
    # @预置条件: 启用memory控制器
    echo "+memory" >"$CGROUP_TOPDIR"/cgroup.subtree_control || return 1
    echo "+memory" >"$CGROUP_TOPDIR"/$CGROUP/cgroup.subtree_control || return 1
    echo "+memory" >"$CGROUP_TOPDIR"/$PARENT1/cgroup.subtree_control || return 1

    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 关闭系统上的所有交换空间
    echo 0 >"$CGROUP_TOPDIR"/$CGROUP/memory.swap.max

    # @测试步骤:2: 设置memory.max和memory.low
    echo 200M >"$CGROUP_TOPDIR"/$CGROUP/memory.max
    echo 50M >"$CGROUP_TOPDIR"/$PARENT1/memory.low
    echo 75M >"$CGROUP_TOPDIR"/$CHILD0/memory.low
    echo 25M >"$CGROUP_TOPDIR"/$CHILD1/memory.low
    echo 0M >"$CGROUP_TOPDIR"/$CHILD2/memory.low

    # @测试步骤:3: 给PARENT1的三个子cgroup分配50MB内存
    echo $$ >"$CGROUP_TOPDIR"/$CHILD0/cgroup.procs
    "$TST_TS_TOPDIR"/tst_lib/cgroup_util/bin/alloc_pagecache 50M &
    echo $$ >"$CGROUP_TOPDIR"/$CHILD1/cgroup.procs
    "$TST_TS_TOPDIR"/tst_lib/cgroup_util/bin/alloc_pagecache 50M &
    echo $$ >"$CGROUP_TOPDIR"/$CHILD2/cgroup.procs
    "$TST_TS_TOPDIR"/tst_lib/cgroup_util/bin/alloc_pagecache 50M &
    sleep 1 # 确保子进程已经分配内存

    # @测试步骤:4: 给PARENT2分配146MB内存
    echo $$ >"$CGROUP_TOPDIR"/$PARENT2/cgroup.procs
    "$TST_TS_TOPDIR"/tst_lib/cgroup_util/bin/alloc_anon 146M &
    sleep 1

    # @测试步骤:5: 检查内存使用情况
    parent1_memory=0
    chidl0_memory=0
    chidl1_memory=0
    chidl2_memory=0
    parent2_memory=0
    for _ in $(seq 1 8); do
        memory_current=$(cat "$CGROUP_TOPDIR"/$PARENT1/memory.current)
        memory_current=$(echo "$memory_current / 1024 / 1024" | bc)
        parent1_memory=$(echo "$memory_current + $parent1_memory" | bc)

        memory_current=$(cat "$CGROUP_TOPDIR"/$CHILD0/memory.current)
        memory_current=$(echo "$memory_current / 1024 / 1024" | bc)
        chidl0_memory=$(echo "$memory_current + $chidl0_memory" | bc)

        memory_current=$(cat "$CGROUP_TOPDIR"/$CHILD1/memory.current)
        memory_current=$(echo "$memory_current / 1024 / 1024" | bc)
        chidl1_memory=$(echo "$memory_current + $chidl1_memory" | bc)

        memory_current=$(cat "$CGROUP_TOPDIR"/$CHILD2/memory.current)
        memory_current=$(echo "$memory_current / 1024 / 1024" | bc)
        chidl2_memory=$(echo "$memory_current + $chidl2_memory" | bc)

        memory_current=$(cat "$CGROUP_TOPDIR"/$PARENT2/memory.current)
        memory_current=$(echo "$memory_current / 1024 / 1024" | bc)
        parent2_memory=$(echo "$memory_current + $parent2_memory" | bc)
        sleep 1
    done
    aver_parent1_memory=$(echo "$parent1_memory / 8" | bc)
    aver_chidl0_memory=$(echo "$chidl0_memory / 8" | bc)
    aver_chidl1_memory=$(echo "$chidl1_memory / 8" | bc)
    aver_chidl2_memory=$(echo "$chidl2_memory / 8" | bc)
    aver_parent2_memory=$(echo "$parent2_memory / 8" | bc)
    msg "parent1 memory average: $aver_parent1_memory"
    msg "child0 memory average: $aver_chidl0_memory"
    msg "child1 memory average: $aver_chidl1_memory"
    msg "child2 memory average: $aver_chidl2_memory"
    msg "parent2 memory average: $aver_parent2_memory"
    sleep 3

    # @预期结果:1: 在误差允许范围内，PARENT1的三个子cgroup分配的内存总和等于50MB
    TOLERANCE=$(echo "($aver_parent1_memory + 50) * 0.05" | bc)
    diff=$((aver_parent1_memory - 50))
    abs_diff=${diff#-}
    assert_true [ "$(echo "$abs_diff < $TOLERANCE" | bc)" -eq 1 ]

    # @预期结果:2: 在误差允许范围内，CHILD0分配的内存等于25MB, CHILD1分配的内存等于25MB, CHILD2分配的内存等于0MB
    TOLERANCE=$(echo "($aver_chidl0_memory + 29) * 0.2" | bc)
    diff=$((aver_chidl0_memory - 29))
    abs_diff=${diff#-}
    assert_true [ "$(echo "$abs_diff < $TOLERANCE" | bc)" -eq 1 ]
    TOLERANCE=$(echo "($aver_chidl1_memory + 21) * 0.2" | bc)
    diff=$((aver_chidl1_memory - 21))
    abs_diff=${diff#-}
    assert_true [ "$(echo "$abs_diff < $TOLERANCE" | bc)" -eq 1 ]
    assert_true [ "$aver_chidl2_memory" -le 3 ]

    # @预期结果:3: 在误差允许范围内，PARENT2分配的内存等于146MB
    TOLERANCE=$(echo "($aver_parent2_memory + 146) * 0.05" | bc)
    diff=$((aver_parent2_memory - 146))
    abs_diff=${diff#-}
    assert_true [ "$(echo "$abs_diff < $TOLERANCE" | bc)" -eq 1 ]

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 将shell进程移出cgroup
    echo $$ >"$CGROUP_TOPDIR"/cgroup.procs
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/$CHILD0
    rmdir "$CGROUP_TOPDIR"/$CHILD1
    rmdir "$CGROUP_TOPDIR"/$CHILD2
    rmdir "$CGROUP_TOPDIR"/$PARENT1
    rmdir "$CGROUP_TOPDIR"/$PARENT2
    rmdir "$CGROUP_TOPDIR"/$CGROUP
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
