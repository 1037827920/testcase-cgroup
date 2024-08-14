#!/bin/bash
###############################################################################
# @用例ID: 20240810-002148-359999787
# @用例名称: cgroup-v2-subtree_control-004
# @用例级别: 2
# @用例标签: cgroup-v2 subtree_control
# @用例类型: 测试cgroup.subtree_control接口文件, 在threaded cgroup能够加入线程在启用了subtree_control的cgroup中
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

CGROUP="cgroup-v2-subtree_control-001"
CHILD0="$CGROUP/child0"

tc_setup() {
    msg "this is tc_setup"

    # @预置条件: 检查cgroup版本是否为cgroup v2
    if ! check_cgroup_version_is_v2; then
        skip_test "cgroup版本不是v2"
    fi

    # @预置条件: 创建cgroup
    mkdir "$CGROUP_TOPDIR"/$CGROUP
    mkdir "$CGROUP_TOPDIR"/$CHILD0
    # @预置条件: 检查当前cgroup是否能启用cpu控制器
    if ! check_string_in_file "memory" "$CGROUP_TOPDIR/cgroup.controllers"; then
        skip_test "根cgroup不能启用memory控制器"
    fi
    # @预置条件: 启用cpu控制器
    echo "+memory" >"$CGROUP_TOPDIR"/cgroup.subtree_control || return 1

    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 修改CGROUP和CHILD0的类型
    echo "threaded" >"$CGROUP_TOPDIR"/$CGROUP/cgroup.type
    echo "threaded" >"$CGROUP_TOPDIR"/$CHILD0/cgroup.type

    # @测试步骤:2: 启用CGROUP的subtree_control的cpu
    echo "+cpu" >"$CGROUP_TOPDIR"/$CGROUP/cgroup.subtree_control

    # @测试步骤:3: 运行一个线程
    {
        while true; do :; done
    } &
    task_pid=$!

    # @测试步骤:4: 写入CGROUP的cgroup.procs
    ret=0
    echo $task_pid >"$CGROUP_TOPDIR"/$CGROUP/cgroup.procs || ret=-1

    # @预期结果:1: 写入成功
    assert_true [ "$ret" -eq 0 ]

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 清理后台进程
    kill -9 "$task_pid"
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/$CHILD0
    rmdir "$CGROUP_TOPDIR"/$CGROUP
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
