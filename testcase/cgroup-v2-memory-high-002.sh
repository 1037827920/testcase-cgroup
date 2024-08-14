#!/bin/bash
###############################################################################
# @用例ID: 20240806-191958-361673037
# @用例名称: cgroup-v2-memory-high-002
# @用例级别: 1
# @用例标签: cgroup-v2 memory high
# @用例类型: 测试memory.high接口文件，测试是否能有效对内存的大量单次分配进行限制
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

CGROUP="cgroup-v2-memory-high-002"

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
    # @测试步骤:1: 读取memory.events的high字段和max字段
    high_cnt=$(grep "high" "$CGROUP_TOPDIR"/$CGROUP/memory.events | awk '{print $2}')
    max_cnt=$(grep "max" "$CGROUP_TOPDIR"/$CGROUP/memory.events | awk '{print $2}')
    msg "high_cnt: $high_cnt"
    msg "max_cnt: $max_cnt"

    # @预期结果:1: high_cnt和max_cnt都不小于0
    assert_true [ "$high_cnt" -ge 0 ]
    assert_true [ "$max_cnt" -ge 0 ]

    # @测试步骤:2: 关闭CGROUP中的swapping
    echo 0 >"$CGROUP_TOPDIR"/$CGROUP/memory.swap.max

    # @测试步骤:3: 设置memory.high的值为30M
    echo 10M >"$CGROUP_TOPDIR"/$CGROUP/memory.high

    # @测试步骤:4: 设置memory.max的值为140M
    echo 140M >"$CGROUP_TOPDIR"/$CGROUP/memory.max

    # @测试步骤:5: 注册内存事件监控
    "$TST_TS_TOPDIR"/tst_lib/cgroup_util/bin/register_notify "$CGROUP_TOPDIR"/$CGROUP/cgroup.events &

    # @测试步骤:6: 单次分配100MB内存
    "$TST_TS_TOPDIR"/tst_lib/cgroup_util/bin/alloc_anon_mlock 120M &
    task_pid=$!
    echo "$task_pid" >"$CGROUP_TOPDIR"/$CGROUP/cgroup.procs
    sleep 12

    # @测试步骤:7: 读取memory.events的high字段和max字段
    post_high_cnt=$(grep "high" "$CGROUP_TOPDIR"/$CGROUP/memory.events | awk '{print $2}')
    post_max_cnt=$(grep "max" "$CGROUP_TOPDIR"/$CGROUP/memory.events | awk '{print $2}')
    msg "post high_cnt: $post_high_cnt"
    msg "post max_cnt: $post_max_cnt"

    # @预期结果:2: high_cnt和max_cnt都不小于0
    assert_true [ "$post_high_cnt" -ge 0 ]
    assert_true [ "$post_max_cnt" -ge 0 ]

    # @预期结果:3: high_cnt增加，max_cnt不变
    assert_true [ "$post_high_cnt" -ne "$high_cnt" ]
    assert_true [ "$post_max_cnt" -eq "$max_cnt" ]

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
