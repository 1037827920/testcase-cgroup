#!/bin/bash
###############################################################################
# @用例ID: 20240809-235140-559937243
# @用例名称: cgroup-v2-kill-002
# @用例级别: 2
# @用例标签: cgroup-v2  kill
# @用例类型: 测试cgroup.kill接口文件, 测试层次结构
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

#                CGROUP
#        /          |          \
#    CHILD0        CHILD1      CHILD2
#  /        \        |
# CHILD00 CHILD01  CHILD10
#                    |
#                  CHILD100
#                    |
#                  CHILD1000
CGROUP="cgroup-v2-kill-002"
CHILD0="$CGROUP/child0"
CHILD1="$CGROUP/child1"
CHILD2="$CGROUP/child3"
CHILD00="$CHILD0/child0"
CHILD01="$CHILD0/child1"
CHILD10="$CHILD1/child0"
CHILD100="$CHILD10/child0"
CHILD1000="$CHILD100/child0"

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
    mkdir "$CGROUP_TOPDIR"/$CHILD2
    mkdir "$CGROUP_TOPDIR"/$CHILD00
    mkdir "$CGROUP_TOPDIR"/$CHILD01
    mkdir "$CGROUP_TOPDIR"/$CHILD10
    mkdir "$CGROUP_TOPDIR"/$CHILD100
    mkdir "$CGROUP_TOPDIR"/$CHILD1000

    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 在CHILD01上运行一个进程
    {
        while true; do :; done
    } &
    task_pid0=$!
    echo $task_pid0 >"$CGROUP_TOPDIR"/$CHILD01/cgroup.procs

    # @测试步骤:2: 在CHILD1000上运行一个进程
    {
        while true; do :; done
    } &
    task_pid1=$!
    echo $task_pid1 >"$CGROUP_TOPDIR"/$CHILD1000/cgroup.procs

    # @测试步骤:3: 在CHILD2上运行一个进程
    {
        while true; do :; done
    } &
    task_pid2=$!
    echo $task_pid2 >"$CGROUP_TOPDIR"/$CHILD2/cgroup.procs

    # @测试步骤:4: 在CGROUP写入cgroup.kill
    echo 1 >"$CGROUP_TOPDIR"/$CGROUP/cgroup.kill

    # @预期结果:1: CGROUP的cgroup.event中的populated字段为0
    populated=$(grep populated "$CGROUP_TOPDIR"/$CGROUP/cgroup.events | awk '{print $2}')
    assert_true [ "$populated" -eq 0 ]

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 清理后台进程
    kill -9 "$task_pid0" "$task_pid1" "$task_pid2"
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/$CHILD1000
    rmdir "$CGROUP_TOPDIR"/$CHILD100
    rmdir "$CGROUP_TOPDIR"/$CHILD10
    rmdir "$CGROUP_TOPDIR"/$CHILD01
    rmdir "$CGROUP_TOPDIR"/$CHILD00
    rmdir "$CGROUP_TOPDIR"/$CHILD0
    rmdir "$CGROUP_TOPDIR"/$CHILD1
    rmdir "$CGROUP_TOPDIR"/$CHILD2
    rmdir "$CGROUP_TOPDIR"/$CGROUP
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
