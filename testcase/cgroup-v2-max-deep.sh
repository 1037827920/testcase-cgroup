#!/bin/bash
###############################################################################
# @用例ID: 20240812-234221-157931352
# @用例名称: cgroup-v2-max-deep
# @用例级别: 2
# @用例标签: cgoup-v2 max deep
# @用例类型: 测试cgroup.max.deep接口文件
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

CGROUP="cgroup-v2-max-deep"
CHILD0="$CGROUP/child0"
CHILD00="$CHILD0/child0"

tc_setup() {
    msg "this is tc_setup"

    # @预置条件: 检查cgroup版本是否为cgroup v2
    if ! check_cgroup_version_is_v2; then
        skip_test "cgroup版本不是v2"
    fi

    # @预置条件: 创建cgroup
    mkdir "$CGROUP_TOPDIR"/$CGROUP

    return 0
}

do_test() {
    msg "this is do_test"

    # @测试步骤:1: 读取CGROUP的cgroup.max.descendants
    max_descendants=$(cat "$CGROUP_TOPDIR"/$CGROUP/cgroup.max.descendants)

    # @预期结果:1: cgroup.max.descendants的值为max
    assert_true [ "$max_descendants" = "max" ]

    # @测试步骤:2: 启用CGROUP的cgrou.max.descendants为1
    echo 1 > "$CGROUP_TOPDIR"/$CGROUP/cgroup.max.descendants

    # @测试步骤:3: 创建一个子cgroup
    ret=0
    mkdir "$CGROUP_TOPDIR"/$CHILD0 || ret=-1

    # @预期结果:2: 创建成功
    assert_true [ $ret -eq 0 ]

    # @测试步骤:4: 再创建一个子cgroup
    ret=0
    mkdir "$CGROUP_TOPDIR"/$CHILD00|| ret=-1

    # @预期结果:3: 创建失败
    assert_true [ $ret -eq -1 ]

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
