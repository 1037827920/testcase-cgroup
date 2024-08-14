#!/bin/bash
###############################################################################
# @用例ID: 20240806-224039-790267806
# @用例名称: cgroup-v2-memory-swap-max
# @用例级别: 2
# @用例标签: cgroup-v2 memory swap max
# @用例类型: 测试memory.swap.max接口文件
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

CGROUP="cgroup-v2-memory-swap-max"

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
    # @测试步骤:1: 设置memory.swap.max为30M
    echo 30M >"$CGROUP_TOPDIR"/$CGROUP/memory.swap.max

    # @测试步骤:2: 设置memory.max为30M
    echo 30M >"$CGROUP_TOPDIR"/$CGROUP/memory.max

    # @测试步骤:3: 分配31M匿名内存的进程
    "$TST_TS_TOPDIR"/tst_lib/cgroup_util/bin/alloc_anon 200M &
    task_pid=$!
    echo $task_pid >"$CGROUP_TOPDIR"/$CGROUP/cgroup.procs
    sleep 5

    # @预期结果:1: 分配失败
    if [ "$(wc -c <"$CGROUP_TOPDIR/$CGROUP/cgroup.procs")" -eq 0 ]; then
        msg "分配失败"
        assert_true [ true ]
    else
        msg "分配成功"
        assert_false [ true ]
    fi

    # @测试步骤:4: 获取CGROUP的momory.events中的oom
    oom_cnt=$(grep "oom" "$CGROUP_TOPDIR"/$CGROUP/memory.events | awk 'NR==1 {print $2}')
    msg "oom: $oom_cnt"

    # @预期结果:2: oom大于0
    assert_true [ "$oom_cnt" -gt 0 ]

    # @测试步骤:5: 获取CGROUP的memory.events中的oom_kill
    oom_kill_cnt=$(grep "oom_kill" "$CGROUP_TOPDIR"/$CGROUP/memory.events | awk '{print $2}')
    msg "oom_kill: $oom_kill_cnt"

    # @预期结果:3: oom_kill大于0
    assert_true [ "$oom_kill_cnt" -gt 0 ]

    # @测试步骤:6: 分配50MB匿名内存的进程
    echo $$ >"$CGROUP_TOPDIR"/$CGROUP/cgroup.procs
    "$TST_TS_TOPDIR"/tst_lib/cgroup_util/bin/alloc_anon 50M &
    sleep 2

    # @测试步骤:7: 获取CGROUP的memory.current和memory.swap.current
    totol_memory_current=0
    totol_swap_current=0
    for _ in $(seq 1 8); do
        memory_current=$(cat "$CGROUP_TOPDIR"/$CGROUP/memory.current)
        memory_current=$(echo "$memory_current / 1024 / 1024" | bc)
        totol_memory_current=$(echo "$memory_current + $totol_memory_current" | bc)
        swap_current=$(cat "$CGROUP_TOPDIR"/$CGROUP/memory.swap.current)
        swap_current=$(echo "$swap_current / 1024 / 1024" | bc)
        totol_swap_current=$(echo "$swap_current + $totol_swap_current" | bc)
        sleep 1
    done
    aver_memory_current=$(echo "$totol_memory_current / 8" | bc)
    aver_swap_current=$(echo "$totol_swap_current / 8" | bc)
    msg "memory.current: $aver_memory_current"
    msg "memory.swap.current: $aver_swap_current"
    sleep 3

    # @预期结果:4: 在误差允许范围内，memory.current等于30MB, memory.current+memory.swap.current等于50MB
    TOLERANCE=$(echo "($aver_memory_current + 30) * 0.1" | bc)
    diff=$((aver_memory_current - 30))
    abs_diff=${diff#-}
    if [ "$aver_memory_current" -ne 0 ]; then
        assert_true [ "$(echo "$abs_diff < $TOLERANCE" | bc)" -eq 1 ]
    else
        assert_false [ true ]
    fi
    TOLERANCE=$(echo "($aver_memory_current + $aver_swap_current + 50) * 0.03" | bc)
    diff=$((aver_memory_current + aver_swap_current - 50))
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
