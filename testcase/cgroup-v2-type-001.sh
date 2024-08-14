#!/bin/bash
###############################################################################
# @用例ID: 20240810-003655-734736228
# @用例名称: cgroup-v2-type-001
# @用例级别: 1
# @用例标签: cgroup-v2 type
# @用例类型: 测试cgroup.type接口文件，当子cgroup设置为threaded时，父cgroup自动设置为domain threaded
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
    # @测试步骤:1: 设置CHILD0的type为threaded
    echo "threaded" >"$CGROUP_TOPDIR"/$CHILD0/cgroup.type

    # @测试步骤:2: 获取CGROUP的type
    type=$(cat "$CGROUP_TOPDIR"/$CGROUP/cgroup.type)

    # @预期结果:1: CGROUP的type为domain threaded
    assert_true [ "$type" = "domain threaded" ]

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/$CHILD0
    rmdir "$CGROUP_TOPDIR"/$CGROUP
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
