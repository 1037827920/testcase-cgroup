#!/bin/bash
###############################################################################
# @用例ID: 20240809-233224-494284037
# @用例名称: cgroup-v2-freeze-004
# @用例级别: 2
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

CGROUP="cgroup-v2-freeze-004"
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

    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 冻结CGROUP的进程
    echo 1 >"$CGROUP_TOPDIR"/$CGROUP/cgroup.freeze

    # @测试步骤:2: 删除CHILD0
    rmdir "$CGROUP_TOPDIR"/$CHILD0

    # @预期结果:1: CGROUP的cgorup.event中的frozen字段为1
    frozen=$(grep frozen "$CGROUP_TOPDIR"/$CGROUP/cgroup.events | awk '{print $2}')
    assert_true [ "$frozen" -eq 1 ]

    # @测试步骤:3: 创建CHILD0
    mkdir "$CGROUP_TOPDIR"/$CHILD0

    # @预期结果:2: CHILD0的cgorup.event中的frozen字段为1
    frozen=$(grep frozen "$CGROUP_TOPDIR"/$CHILD0/cgroup.events | awk '{print $2}')
    assert_true [ "$frozen" -eq 1 ]

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
