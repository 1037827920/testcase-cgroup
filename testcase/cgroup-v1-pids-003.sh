#!/bin/bash
###############################################################################
# @用例ID: 20240801-191225-778933447
# @用例名称: cgroup-v1-pids-003
# @用例级别: 2
# @用例标签: cgroup-v1 pids
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

CGROUP="cgroup-v1-pids-003"
CHILD0="$CGROUP/child0"
TMP_FILE=$(mktemp)

tc_setup() {
    msg "this is tc_setup"
    # @预置条件: 检查cgroup版本是否为cgroup v1
    if ! check_cgroup_version_is_v1; then
        skip_test "cgroup版本不是v1"
    fi
    # @预置条件: 检查是否开启了CONFIG_CGROUP_PIDS配置
    if ! grep -q CONFIG_CGROUP_PIDS=y /boot/config-"$(uname -r)"; then
        skip_test "内核CONFIG_CGROUP_PIDS配置未开启"
    fi

    # @预置条件: 创建cgroup
    mkdir "$CGROUP_TOPDIR"/pids/$CGROUP
    mkdir "$CGROUP_TOPDIR"/pids/$CHILD0
    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 设置pids.max为2
    echo 2 >"$CGROUP_TOPDIR"/pids/$CGROUP/pids.max

    # @测试步骤:2: 获取subcgroup的pids.max
    PID_MAX=$(cat "$CGROUP_TOPDIR"/pids/$CHILD0/pids.max)

    # @预期结果:1: subcgroup的pids.max为max
    assert_true [ "$PID_MAX" = "max" ]

    # @测试步骤:3: 将当前shell加入subcgroup
    echo $$ >"$CGROUP_TOPDIR"/pids/$CHILD0/cgroup.procs

    # @测试步骤:4: 运行了两个子进程
    (echo "Here's some processes for you." | cat) &>"$TMP_FILE"
    echo $$ >"$CGROUP_TOPDIR"/pids/cgroup.procs

    # @测试步骤:5: 获取超过最大进程数的次数
    FAILCNT=$(grep max "$CGROUP_TOPDIR"/pids/$CHILD0/pids.events | awk '{print $2}')

    # @预期结果:2: 运行失败
    if grep -q "Resource temporarily unavailable" "$TMP_FILE"; then
        assert_true [ "$FAILCNT" -gt 0 ]
    else
        assert_false [ true ]
    fi

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/pids/$CHILD0
    rmdir "$CGROUP_TOPDIR"/pids/$CGROUP
    # @清理工作: 删除临时文件
    rm "$TMP_FILE"
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
