#!/bin/bash
###############################################################################
# @用例ID: 20240810-005006-336461552
# @用例名称: cgroup-v2-populated
# @用例级别: 1
# @用例标签: cgroup-v2 populated
# @用例类型: 测试cgroup.events中的populated字段
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

#           CGROUP
#             |
#           CHILD0
#          /    \
#     CHILD00   CHILD01
CGROUP="cgroup-v2-type-001"
CHILD0="$CGROUP/child0"
CHILD00="$CHILD0/child0"
CHILD01="$CHILD0/child1"

tc_setup() {
    msg "this is tc_setup"

    # @预置条件: 检查cgroup版本是否为cgroup v2
    if ! check_cgroup_version_is_v2; then
        skip_test "cgroup版本不是v2"
    fi

    # @预置条件: 创建cgroup
    mkdir "$CGROUP_TOPDIR"/$CGROUP
    mkdir "$CGROUP_TOPDIR"/$CHILD0
    mkdir "$CGROUP_TOPDIR"/$CHILD00
    mkdir "$CGROUP_TOPDIR"/$CHILD01

    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 运行一个进程并将其放入CHILD00
    {
        while true; do :; done
    } &
    task_pid=$!
    echo $task_pid >"$CGROUP_TOPDIR"/$CHILD00/cgroup.procs

    # @预测结果:1: CGROUP, CHILD0, CHILD00的populated字段为1，CHILD01的populated字段为0
    populated=$(grep populated "$CGROUP_TOPDIR"/$CGROUP/cgroup.events | awk '{print $2}')
    assert_true [ "$populated" -eq 1 ]
    populated=$(grep populated "$CGROUP_TOPDIR"/$CHILD0/cgroup.events | awk '{print $2}')
    assert_true [ "$populated" -eq 1 ]
    populated=$(grep populated "$CGROUP_TOPDIR"/$CHILD00/cgroup.events | awk '{print $2}')
    assert_true [ "$populated" -eq 1 ]
    populated=$(grep populated "$CGROUP_TOPDIR"/$CHILD01/cgroup.events | awk '{print $2}')
    assert_true [ "$populated" -eq 0 ]

    # @测试步骤:2: 将进程迁移到root cgroup
    echo $task_pid >"$CGROUP_TOPDIR"/cgroup.procs

    # @预期结果:1: 四个cgroup的populated字段为0
    populated=$(grep populated "$CGROUP_TOPDIR"/$CGROUP/cgroup.events | awk '{print $2}')
    assert_true [ "$populated" -eq 0 ]
    populated=$(grep populated "$CGROUP_TOPDIR"/$CHILD0/cgroup.events | awk '{print $2}')
    assert_true [ "$populated" -eq 0 ]
    populated=$(grep populated "$CGROUP_TOPDIR"/$CHILD00/cgroup.events | awk '{print $2}')
    assert_true [ "$populated" -eq 0 ]
    populated=$(grep populated "$CGROUP_TOPDIR"/$CHILD01/cgroup.events | awk '{print $2}')
    assert_true [ "$populated" -eq 0 ]

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 清理后台进程
    kill -9 "$task_pid"
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/$CHILD01
    rmdir "$CGROUP_TOPDIR"/$CHILD00
    rmdir "$CGROUP_TOPDIR"/$CHILD0
    rmdir "$CGROUP_TOPDIR"/$CGROUP
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
