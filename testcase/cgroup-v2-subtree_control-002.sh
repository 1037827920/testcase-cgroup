#!/bin/bash
###############################################################################
# @用例ID: 20240810-000036-358265138
# @用例名称: cgroup-v2-subtree_control-002
# @用例级别: 1
# @用例标签: cgroup-v2 subtree_control
# @用例类型: 测试cgroup.subtree_control接口文件，子cgroup的subtree_control只能包含父cgroup的subtree_control
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

CGROUP="cgroup-v2-subtree_control-002"
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
    # @预置条件: 检查当前cgroup是否能启用memory控制器
    if ! check_string_in_file "memory" "$CGROUP_TOPDIR/cgroup.controllers"; then
        skip_test "根cgroup不能启用memory控制器"
    fi
    # @预置条件: 启用memory控制器
    echo "+memory" >"$CGROUP_TOPDIR"/cgroup.subtree_control || return 1

    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 检查CGROUP的subtree_control为空
    assert_true [ -z "$(cat "$CGROUP_TOPDIR"/$CGROUP/cgroup.subtree_control)" ]

    # @测试步骤:2: 启用CHILD0的subtree_control的memory
    ret=0
    echo "+memory" >"$CGROUP_TOPDIR"/$CHILD0/cgroup.subtree_control || ret=-1

    # @预期结果:1: 启用失败
    assert_true [ "$ret" -eq -1 ]

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @测试清理: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/$CHILD0
    rmdir "$CGROUP_TOPDIR"/$CGROUP
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
