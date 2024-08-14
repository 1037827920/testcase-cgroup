#!/bin/bash
###############################################################################
# @用例ID: 20240808-114352-529042314
# @用例名称: cgroup-v2-pids-max-003
# @用例级别: 3
# @用例标签: cgroup-v2 pids max
# @用例类型: 测试pids的层次结构
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

CGROUP="cgroup-v2-pids-max-003"
CHILD0="$CGROUP/child0"
TMP_FILE=$(mktemp)

tc_setup() {
    msg "this is tc_setup"
    # @预置条件: 检查cgroup版本是否为cgroup v2
    if ! check_cgroup_version_is_v2; then
        skip_test "cgroup版本不是v2"
    fi

    # @预置条件: 创建cgroup
    mkdir "$CGROUP_TOPDIR"/$CGROUP
    mkdir "$CGROUP_TOPDIR"/$CHILD0
    # @预置条件: 检查当前cgroup是否能启用pids控制器
    if ! check_string_in_file "pids" "$CGROUP_TOPDIR/cgroup.controllers"; then
        skip_test "当前cgroup不能启用pids控制器"
    fi
    # @预置条件: 启用io控制器
    echo "+pids" >"$CGROUP_TOPDIR"/cgroup.subtree_control || return 1
    echo "+pids" >"$CGROUP_TOPDIR"/$CGROUP/cgroup.subtree_control || return 1
    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 设置pids.max为2
    echo 2 >"$CGROUP_TOPDIR"/$CGROUP/pids.max

    # @测试步骤:2: 获取CHILD0的pids.max
    pid_max=$(cat "$CGROUP_TOPDIR"/$CHILD0/pids.max)

    # @预期结果:1: CHILD0的pids.max为max
    assert_true [ "$pid_max" = "max" ]

    # @测试步骤:3: 将当前shell加入CHILD0
    echo $$ >"$CGROUP_TOPDIR"/$CHILD0/cgroup.procs

    # @测试步骤:4: 运行了两个子进程
    (echo "Here's some processes for you." | cat) &>"$TMP_FILE"
    echo $$ >"$CGROUP_TOPDIR"/cgroup.procs

    # @测试步骤:5: 获取超过最大进程数的次数
    fail_cnt=$(grep max "$CGROUP_TOPDIR"/$CHILD0/pids.events | awk '{print $2}')

    # @预期结果:2: 运行失败
    if grep -q "Resource temporarily unavailable" "$TMP_FILE"; then
        assert_true [ "$fail_cnt" -gt 0 ]
    else
        assert_false [ true ]
    fi

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 将当前shell从cgroup中移除
    echo $$ >"$CGROUP_TOPDIR"/cgroup.procs
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/$CHILD0
    rmdir "$CGROUP_TOPDIR"/$CGROUP
    # @清理工作: 删除临时文件
    rm "$TMP_FILE"
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
