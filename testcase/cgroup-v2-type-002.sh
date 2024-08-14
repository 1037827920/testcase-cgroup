#!/bin/bash
###############################################################################
# @用例ID: 20240810-003658-663844108
# @用例名称: cgroup-v2-type-002
# @用例级别: 2
# @用例标签: cgroup-v2 type
# @用例类型: 测试cgroup.type接口文件, 测试层次结构约束
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

CGROUP="cgroup-v2-type-001"
CHILD0="$CGROUP/child0"
CHILD1="$CHILD0/child1"

tc_setup() {
    msg "this is tc_setup"

    # @预置条件: 检查cgroup版本是否为cgroup v2
    if ! check_cgroup_version_is_v2; then
        skip_test "cgroup版本不是v2"
    fi

    # @预置条件: 创建cgroup
    mkdir "$CGROUP_TOPDIR"/$CGROUP
    mkdir "$CGROUP_TOPDIR"/$CHILD0
    mkdir "$CGROUP_TOPDIR"/$CHILD1

    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 启用CHILD0的type为threaded
    echo "threaded" >"$CGROUP_TOPDIR"/$CHILD0/cgroup.type

    # @测试步骤:2: 获取CHILD1的type
    type=$(cat "$CGROUP_TOPDIR"/$CHILD1/cgroup.type)

    # @预期结果:1: CHILD1的type为domain invalid
    assert_true [ "$type" = "domain invalid" ]

    # @测试步骤:3: 运行一个进程
    {
        while true; do :; done
    } &
    task_pid=$!

    # @测试步骤:4: 将进程加入CHILD1
    ret=0
    echo $task_pid >"$CGROUP_TOPDIR"/$CHILD1/cgroup.procs || ret=-1

    # @预期结果:2: 将进程加入CHILD1失败
    assert_true [ $ret -eq -1 ]

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 清理后台进程
    kill -9 "$task_pid"
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/$CHILD1
    rmdir "$CGROUP_TOPDIR"/$CHILD0
    rmdir "$CGROUP_TOPDIR"/$CGROUP
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
