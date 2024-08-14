#!/bin/bash
###############################################################################
# @用例ID: 20240806-212858-982022706
# @用例名称: cgroup-v2-memory-oom-group-003
# @用例级别: 2
# @用例标签: cgroup-v2 memory oom group
# @用例类型: 测试memory.oom.group接口文件，分配匿名内存达到oom限制，检查除了设置OOM_SCORE_ADJ_MIN的进程外，其他进程是否被kill
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

CGROUP="cgroup-v2-memory-oom-group-003"
OOM_SCORE_ADJ_MIN=-1000

tc_setup() {
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
    # @测试步骤:1: 设置CGROUP的内存限制为50MB
    echo 50M >"$CGROUP_TOPDIR"/$CGROUP/memory.max

    # @测试步骤:2: 关闭CGROUP的swapping
    echo 0 >"$CGROUP_TOPDIR"/$CGROUP/memory.swap.max

    # @测试步骤:3: 启用CGROUP的oom.group
    echo 1 >"$CGROUP_TOPDIR"/$CGROUP/memory.oom.group

    # @测试步骤:4: 在CGROUP中分配1MB匿名内存
    "$TST_TS_TOPDIR"/tst_lib/cgroup_util/bin/alloc_anon 1M &
    task_pid=$!
    echo $task_pid >"$CGROUP_TOPDIR"/$CGROUP/cgroup.procs
    sleep 1

    # @测试步骤:5: 设置进程task_pid的oom_score_adj为OOM_SCORE_ADJ_MIN
    echo $OOM_SCORE_ADJ_MIN >"/proc/$task_pid/oom_score_adj"

    # @测试步骤:6: 在CGROUP中分配1MB匿名内存
    "$TST_TS_TOPDIR"/tst_lib/cgroup_util/bin/alloc_anon 1M &
    echo $! >"$CGROUP_TOPDIR"/$CGROUP/cgroup.procs
    sleep 1

    # @测试步骤:7: 在CGROUP中分配超出memory.max的匿名内存
    "$TST_TS_TOPDIR"/tst_lib/cgroup_util/bin/alloc_anon 200M &
    echo $! >"$CGROUP_TOPDIR"/$CGROUP/cgroup.procs
    sleep 1

    # @测试步骤:8: 获取CGROUP的oom_kill
    oom_kill_cnt=$(grep "oom_kill" "$CGROUP_TOPDIR"/$CGROUP/memory.events | awk '{print $2}')
    msg "oom kill cnt: $oom_kill_cnt"

    # @预期结果:1: oom_kill_cnt为3
    assert_true [ "$oom_kill_cnt" -eq 3 ]

    # @测试步骤:9: 获取CGROUP的oom_group_kill
    oom_group_kill_cnt=$(grep "oom_group_kill" "$CGROUP_TOPDIR"/$CGROUP/memory.events | awk '{print $2}')
    if [ -z "$oom_group_kill_cnt" ]; then
        assert_true [ true ]
    else 
        # @预期结果:4: oom_group_kill_cnt为1
        assert_true [ "$oom_group_kill_cnt" -eq 1 ]
    fi

    # @测试步骤:10: 尝试kill有OOM_SCORE_ADJ_MIN的进程
    kill -9 $task_pid || assert_false [ true ]

    # @预期结果:3: 进程task_pid被kill
    assert_true [ true ]

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    sleep 1
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/$CGROUP
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
