#!/bin/bash
###############################################################################
# @用例ID: 20240726-211229-939897776
# @用例名称: cgroup-v1-net_prio
# @用例级别: 3
# @用例标签: cgroup-v1 net_prio
# @用例类型: 测试net_prio.ifpriomap是否能成功设置
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

CGROUP="cgroup-v1-net_prio"

tc_setup() {
    msg "this is tc_setup"
    # @预置条件: 检查cgroup版本是否为cgroup v1
    if ! check_cgroup_version_is_v1; then
        skip_test "cgroup版本不是v1"
    fi
    # @预置条件: 检查是否开启了CONFIG_CGROUP_NET_PRIO配置
    if ! grep -q CONFIG_CGROUP_NET_PRIO=y /boot/config-"$(uname -r)"; then
        skip_test "内核CONFIG_CGROUP_NET_PRIO配置未开启"
    fi

    # @预置条件: 创建cgroup
    mkdir "$CGROUP_TOPDIR"/net_prio/$CGROUP
    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 检查是否有回环接口
    if ! ip addr show lo &>/dev/null; then
        msg "错误信息: 没有找到回环接口lo"
        exit 1
    fi

    # @测试步骤:2: 设置net_prio.ifpriomap
    echo "lo 5" >"$CGROUP_TOPDIR"/net_prio/$CGROUP/net_prio.ifpriomap

    # @测试步骤:3: 获取net_prio.ifpriomap配置
    ifpriomap=$(cat "$CGROUP_TOPDIR"/net_prio/$CGROUP/net_prio.ifpriomap)
    io_ifpriomap=$(echo "$ifpriomap" | grep "lo" | awk '{print $2}')
    msg "io_ifpriomap: $io_ifpriomap"

    # @预期结果:1: 检查是否设置成功
    assert_true [ "$io_ifpriomap" -eq 5 ]

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/net_prio/$CGROUP
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
