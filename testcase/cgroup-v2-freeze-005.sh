#!/bin/bash
###############################################################################
# @用例ID: 20240809-233752-330450571
# @用例名称: cgroup-v2-freeze-005
# @用例级别: 2
# @用例标签: cgroup-v2 freeze
# @用例类型: 测试cgroup.freeze接口文件, 测试迁移的情况
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

CGROUP0="cgroup-v2-freeze-004-01"
CGROUP1="cgroup-v2-freeze-004-02"

tc_setup() {
    msg "this is tc_setup"

    # @预置条件: 检查cgroup版本是否为cgroup v2
    if ! check_cgroup_version_is_v2; then
        skip_test "cgroup版本不是v2"
    fi

    # @预置条件: 创建cgroup
    mkdir "$CGROUP_TOPDIR"/$CGROUP0
    mkdir "$CGROUP_TOPDIR"/$CGROUP1

    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 在CGROUP0中运行一个进程
    {
        while true; do :; done
    } &
    task_pid=$!
    echo $task_pid >"$CGROUP_TOPDIR"/$CGROUP0/cgroup.procs

    # @测试步骤:2: 冻结CGROUP1
    echo 1 >"$CGROUP_TOPDIR"/$CGROUP1/cgroup.freeze

    # @测试步骤:3: 将进程迁移到CGROUP1
    echo $task_pid >"$CGROUP_TOPDIR"/$CGROUP1/cgroup.procs

    # @预期结果:1: CGROUP1的cgorup.event中的frozen字段为1，CGROUP0的frozen字段为0
    frozen=$(grep frozen "$CGROUP_TOPDIR"/$CGROUP1/cgroup.events | awk '{print $2}')
    assert_true [ "$frozen" -eq 1 ]
    frozen=$(grep frozen "$CGROUP_TOPDIR"/$CGROUP0/cgroup.events | awk '{print $2}')
    assert_true [ "$frozen" -eq 0 ]

    # @测试步骤:4: 将进程迁回CGROUP0
    echo $task_pid >"$CGROUP_TOPDIR"/$CGROUP0/cgroup.procs

    # @预期结果:2: CGROUP0的cgorup.event中的frozen字段为0，CGROUP1的frozen字段为1
    frozen=$(grep frozen "$CGROUP_TOPDIR"/$CGROUP0/cgroup.events | awk '{print $2}')
    assert_true [ "$frozen" -eq 0 ]
    frozen=$(grep frozen "$CGROUP_TOPDIR"/$CGROUP1/cgroup.events | awk '{print $2}')
    assert_true [ "$frozen" -eq 1 ]

    # @测试步骤:5: 冻结CGROUP0
    echo 1 >"$CGROUP_TOPDIR"/$CGROUP0/cgroup.freeze

    # @测试步骤:6: 将进程迁移到CGROUP1
    echo $task_pid >"$CGROUP_TOPDIR"/$CGROUP1/cgroup.procs

    # @预期结果:3: CGROUP1的cgorup.event中的frozen字段为1，CGROUP0的frozen字段为1
    frozen=$(grep frozen "$CGROUP_TOPDIR"/$CGROUP1/cgroup.events | awk '{print $2}')
    assert_true [ "$frozen" -eq 1 ]
    frozen=$(grep frozen "$CGROUP_TOPDIR"/$CGROUP0/cgroup.events | awk '{print $2}')
    assert_true [ "$frozen" -eq 1 ]

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 清理后台进程
    kill -9 "$task_pid"
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/$CGROUP0
    rmdir "$CGROUP_TOPDIR"/$CGROUP1
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
