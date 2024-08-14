#!/bin/bash
###############################################################################
# @用例ID: 20240724-155852-472494491
# @用例名称: cgroup-v1-freezer-002
# @用例级别: 2
# @用例标签: cgroup-v1 freezer
# @用例类型: 测试freezer的层次结构
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

CGROUP="cgroup-v1-freezer-002"
CHILD0="$CGROUP/child0"

tc_setup() {
    msg "this is tc_setup"
    # @预置条件: 检查cgroup版本是否为cgroup v1
    if ! check_cgroup_version_is_v1; then
        skip_test "cgroup版本不是v1"
    fi
    # @预置条件: 检查是否开启了CONFIG_CGROUP_FREEZER配置
    if ! grep -q CONFIG_CGROUP_FREEZER=y /boot/config-"$(uname -r)"; then
        skip_test "内核CONFIG_CGROUP_FREEZER配置未开启"
    fi

    # @预置条件: 创建两个cgroup
    mkdir "$CGROUP_TOPDIR"/freezer/$CGROUP
    mkdir "$CGROUP_TOPDIR"/freezer/$CHILD0
    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 查看CGROUP和CHILD0的状态
    freezer_state=$(cat "$CGROUP_TOPDIR"/freezer/$CGROUP/freezer.state)
    sub_freezer_state=$(cat "$CGROUP_TOPDIR"/freezer/$CHILD0/freezer.state)

    # @预期结果:1: CGROUP状态和CHILD0状态为THAWED
    assert_true [ "$freezer_state" = "THAWED" ]
    assert_true [ "$sub_freezer_state" = "THAWED" ]

    # @测试步骤:2: 冻结CGROUP
    echo "FROZEN" >"$CGROUP_TOPDIR"/freezer/$CGROUP/freezer.state

    # @测试步骤:3: 查看CGROUP和CHILD0的状态
    freezer_state=$(cat "$CGROUP_TOPDIR"/freezer/$CGROUP/freezer.state)
    sub_freezer_state=$(cat "$CGROUP_TOPDIR"/freezer/$CHILD0/freezer.state)

    # @预期结果:2: CGROUP状态和CHILD0状态都为FROZEN
    assert_true [ "$freezer_state" = "FROZEN" ]
    assert_true [ "$sub_freezer_state" = "FROZEN" ]

    # @测试步骤:4: 解冻CHILD0
    echo "THAWED" >"$CGROUP_TOPDIR"/freezer/$CHILD0/freezer.state

    # @测试步骤:5: 查看CHILD0状态
    sub_freezer_state=$(cat "$CGROUP_TOPDIR"/freezer/$CHILD0/freezer.state)

    # @预期结果:3: CHILD0状态仍为FROZEN，因为此时CGROUP仍为FROZEN状态, CHILD0状态不会被有效更改
    assert_true [ "$sub_freezer_state" = "FROZEN" ]

    # @测试步骤:6: 解冻CGROUP
    echo "THAWED" >"$CGROUP_TOPDIR"/freezer/$CGROUP/freezer.state

    # @测试步骤:7: 查看CGROUP和CHILD0的状态
    freezer_state=$(cat "$CGROUP_TOPDIR"/freezer/$CGROUP/freezer.state)
    sub_freezer_state=$(cat "$CGROUP_TOPDIR"/freezer/$CHILD0/freezer.state)

    # @预期结果:4: CGROUP状态和CHILD0状态都为THAWED
    assert_true [ "$freezer_state" = "THAWED" ]
    assert_true [ "$sub_freezer_state" = "THAWED" ]

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/freezer/$CHILD0
    rmdir "$CGROUP_TOPDIR"/freezer/$CGROUP
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
