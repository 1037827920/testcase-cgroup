#!/bin/bash
###############################################################################
# @用例ID: 20240807-191722-246340813
# @用例名称: cgroup-v2-memory-swap-high
# @用例级别: 1
# @用例标签: cgroup-v2 memory swap high
# @用例类型: 测试memory.swap.high接口文件
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

CGROUP="cgroup-v2-memory-swap-high"

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
    # @预置条件: 查看系统是否启用了swapping
    if [ -z "$(swapon --show)" ]; then
        skip_test "系统未启用swap或没有swapfile"
    fi

    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 读取memory.swap.high的值
    memory_swap_high=$(cat "$CGROUP_TOPDIR"/$CGROUP/memory.swap.high)

    # @预期结果:1: memory.swap.high的值为max
    assert_true [ "$memory_swap_high" = "max" ]

    # @测试步骤:2: 设置memory.swap.high为30M
    echo 30M >"$CGROUP_TOPDIR"/$CGROUP/memory.swap.high

    # @测试步骤:3: 设置memory.high为30M
    echo 30M >"$CGROUP_TOPDIR"/$CGROUP/memory.high

    # @测试步骤:4: 分配31M匿名内存的进程
    "$TST_TS_TOPDIR"/tst_lib/cgroup_util/bin/alloc_anon 200M &
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

    # @测试步骤:5: 分配50M匿名内存的进程
    echo $$ >"$CGROUP_TOPDIR"/$CGROUP/cgroup.procs
    "$TST_TS_TOPDIR"/tst_lib/cgroup_util/bin/alloc_anon 50M &
    sleep 2

    # @测试步骤:6: 获取CGROUP的memory.current和memory.swap.current
    total_memory_current=0
    total_memory_swap_current=0
    for _ in $(seq 1 8); do
        memory_current=$(cat "$CGROUP_TOPDIR"/$CGROUP/memory.current)
        memory_current=$(echo "$memory_current / 1024 / 1024" | bc)
        total_memory_current=$(echo "$total_memory_current + $memory_current" | bc)
        memory_swap_current=$(cat "$CGROUP_TOPDIR"/$CGROUP/memory.swap.current)
        memory_swap_current=$(echo "$memory_swap_current / 1024 / 1024" | bc)
        total_memory_swap_current=$(echo "$total_memory_swap_current + $memory_swap_current" | bc)
        sleep 1
    done
    aver_memory_current=$(echo "$total_memory_current / 8" | bc)
    aver_memory_swap_current=$(echo "$total_memory_swap_current / 8" | bc)
    msg "average memory current: $aver_memory_current"
    msg "average memory current: $aver_memory_swap_current"
    sleep 1

    # @预期结果:3: 在误差允许范围内，memory.current等于30MB, memory.current+memory.swap.current等于50MB
    TOLERANCE=$(echo "($aver_memory_current + 30) * 0.1" | bc)
    diff=$((aver_memory_current - 30))
    abs_diff=${diff#-}
    if [ "$aver_memory_current" -ne 0 ]; then
        assert_true [ "$(echo "$abs_diff < $TOLERANCE" | bc)" -eq 1 ]
    else
        assert_false [ true ]
    fi
    TOLERANCE=$(echo "($aver_memory_current + $aver_memory_swap_current + 50) * 0.03" | bc)
    diff=$((aver_memory_current + aver_memory_swap_current - 50))
    abs_diff=${diff#-}
    if [ "$aver_memory_current" -ne 0 ]; then
        assert_true [ "$(echo "$abs_diff < $TOLERANCE" | bc)" -eq 1 ]
    else
        assert_false [ true ]
    fi

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 将shell移出cgroup
    echo $$ >"$CGROUP_TOPDIR"/cgroup.procs
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/$CGROUP
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
