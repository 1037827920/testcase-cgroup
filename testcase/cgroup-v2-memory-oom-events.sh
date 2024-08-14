#!/bin/bash
###############################################################################
# @用例ID: 20240807-132326-618850104
# @用例名称: cgroup-v2-memory-oom-events
# @用例级别: 2
# @用例标签: cgroup-v2 memory oom-events
# @用例类型: 测试memory.events中的oom和oom_kill事件
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

CGROUP="cgroup-v2-memory-oom-events"

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
    # @测试步骤:1: 设置memory.max为30M
    echo 30M >"$CGROUP_TOPDIR"/$CGROUP/memory.max

    # @测试步骤:2: 关闭CGROUP中的swapping
    echo 0 >"$CGROUP_TOPDIR"/$CGROUP/memory.swap.max

    # @测试步骤:3: 分配100MB匿名内存
    "$TST_TS_TOPDIR"/tst_lib/cgroup_util/bin/alloc_anon 200M &
    echo $! >"$CGROUP_TOPDIR"/$CGROUP/cgroup.procs
    sleep 2

    # @预期结果:1: 分配失败
    if [ "$(wc -c <"$CGROUP_TOPDIR/$CGROUP/cgroup.procs")" -eq 0 ]; then
        msg "分配失败"
        assert_true [ true ]
    else
        assert_false [ true ]
    fi

    # @测试步骤:4: 读取memory.events中的oom字段
    oom_cnt=$(cat "$CGROUP_TOPDIR"/$CGROUP/memory.events | grep oom | awk 'NR==1 {print $2}')
    msg "oom_cnt: $oom_cnt"

    # @预期结果:2: oom_cnt的值为1
    assert_true [ "$oom_cnt" -eq 1 ]

    # @测试步骤:5: 读取memory.events中的oom_kill字段
    oom_kill_cnt=$(cat "$CGROUP_TOPDIR"/$CGROUP/memory.events | grep oom_kill | awk '{print $2}')
    msg "oom_kill_cnt: $oom_kill_cnt"

    # @预期结果:3: oom_kill_cnt的值为1
    assert_true [ "$oom_kill_cnt" -eq 1 ]

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
