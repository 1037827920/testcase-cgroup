#!/bin/bash
###############################################################################
# @用例ID: 20240809-230001-993472792
# @用例名称: cgroup-v2-freeze-002
# @用例级别: 1
# @用例标签: cgroup-v2 freeze
# @用例类型: 测试cgroup.freeze接口文件, 测试cgroup的层次结构
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
CGROUP="cgroup-v2-freeze-002"
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

    # @测试步骤:4: 冻结CHILD0
    echo 1 >"$CGROUP_TOPDIR"/$CHILD0/cgroup.freeze

    # @测试步骤:5: 冻结CHILD10
    echo 1 >"$CGROUP_TOPDIR"/$CHILD10/cgroup.freeze

    # @测试步骤:6: 冻结CHILD100
    echo 1 >"$CGROUP_TOPDIR"/$CHILD100/cgroup.freeze

    # @预期结果:1: CGROUP和CHILD1的cgroup.event中的frozen字段为0
    frozen=$(grep frozen "$CGROUP_TOPDIR"/$CGROUP/cgroup.events | awk '{print $2}')
    assert_true [ "$frozen" -eq 0 ]
    frozen=$(grep frozen "$CGROUP_TOPDIR"/$CHILD1/cgroup.events | awk '{print $2}')
    assert_true [ "$frozen" -eq 0 ]

    # # @测试步骤:7: 冻结CGROUP
    echo 1 >"$CGROUP_TOPDIR"/$CGROUP/cgroup.freeze

    # # @预期结果:2: CGROUP, CHILD0, CHILD1的cgroup.event中的frozen字段为1
    frozen=$(grep frozen "$CGROUP_TOPDIR"/$CGROUP/cgroup.events | awk '{print $2}')
    assert_true [ "$frozen" -eq 1 ]
    # frozen=$(grep frozen "$CGROUP_TOPDIR"/$CHILD0/cgroup.events | awk '{print $2}')
    # assert_true [ "$frozen" -eq 1 ]
    # frozen=$(grep frozen "$CGROUP_TOPDIR"/$CHILD1/cgroup.events | awk '{print $2}')
    # assert_true [ "$frozen" -eq 1 ]

    # # @测试步骤:8: 解冻CHILD0, CHILD10, CHILD100
    # echo 0 >"$CGROUP_TOPDIR"/$CHILD0/cgroup.freeze
    # echo 0 >"$CGROUP_TOPDIR"/$CHILD10/cgroup.freeze
    # echo 0 >"$CGROUP_TOPDIR"/$CHILD100/cgroup.freeze

    # # @预期结果:3: CHILD00, CHILD1000的cgroup.event中的frozen字段为1
    # frozen=$(grep frozen "$CGROUP_TOPDIR"/$CHILD00/cgroup.events | awk '{print $2}')
    # assert_true [ "$frozen" -eq 1 ]
    # frozen=$(grep frozen "$CGROUP_TOPDIR"/$CHILD1000/cgroup.events | awk '{print $2}')
    # assert_true [ "$frozen" -eq 1 ]

    # # @测试步骤:9: 解冻CGROUP
    # echo 0 >"$CGROUP_TOPDIR"/$CGROUP/cgroup.freeze

    # # @预期结果:4: CHILD00, CHILD2的cgroup.event中的frozen字段为0
    # frozen=$(grep frozen "$CGROUP_TOPDIR"/$CHILD00/cgroup.events | awk '{print $2}')
    # assert_true [ "$frozen" -eq 0 ]
    # frozen=$(grep frozen "$CGROUP_TOPDIR"/$CHILD2/cgroup.events | awk '{print $2}')
    # assert_true [ "$frozen" -eq 0 ]

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 清理后台进程
    kill -9 "$task_pid0" "$task_pid1" "$task_pid2"
    sleep  1
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/$CHILD1000
    rmdir "$CGROUP_TOPDIR"/$CHILD100
    rmdir "$CGROUP_TOPDIR"/$CHILD10
    rmdir "$CGROUP_TOPDIR"/$CHILD01
    rmdir "$CGROUP_TOPDIR"/$CHILD00
    rmdir "$CGROUP_TOPDIR"/$CHILD2
    rmdir "$CGROUP_TOPDIR"/$CHILD1
    rmdir "$CGROUP_TOPDIR"/$CHILD0
    rmdir "$CGROUP_TOPDIR"/$CGROUP
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
