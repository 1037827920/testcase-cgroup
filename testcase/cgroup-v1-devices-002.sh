#!/bin/bash
###############################################################################
# @用例ID: 20240724-142029-165605406
# @用例名称: cgroup-v1-devices-002
# @用例级别: 3
# @用例标签: cgroup-v1 devices
# @用例类型: 测试deivces的层级结构
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

CGROUP="cgroup-v1-devices-001"
CHILD0="$CGROUP/child0"

tc_setup() {
    msg "this is tc_setup"
    # @预置条件: 检查cgroup版本是否为cgroup v1
    if ! check_cgroup_version_is_v1; then
        skip_test "cgroup版本不是v1"
    fi
    # @预置条件: 检查是否开启了CONFIG_CGROUP_DEVICE配置
    if ! grep -q CONFIG_CGROUP_DEVICE=y /boot/config-"$(uname -r)"; then
        skip_test "内核CONFIG_CGROUP_DEVICE配置未开启"
    fi

    # @预置条件: 创建两个cgroup
    mkdir "$CGROUP_TOPDIR"/devices/$CGROUP
    mkdir "$CGROUP_TOPDIR"/devices/$CHILD0
    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 获取硬盘设备
    if [[ -e /dev/sda ]]; then
        msg "disk is /dev/sda"
        device_number_major="8"
        device_number_minor="0"
    else
        msg "disk is /dev/vda"
        device_number_major="253"
        device_number_minor="0"
    fi

    # @测试步骤:2: 限制CHILD0的所有设备访问
    echo "a *:* rwm" >"$CGROUP_TOPDIR"/devices/$CHILD0/devices.deny

    # @测试步骤:3: 允许CHILD0的硬盘设备访问
    echo "b $device_number_major:$device_number_minor rwm" >"$CGROUP_TOPDIR"/devices/$CHILD0/devices.allow

    # @测试步骤:4: 查看CHILD0的允许访问设备的白名单
    whitelist=$(cat "$CGROUP_TOPDIR"/devices/$CHILD0/devices.list)

    # @预期结果:1: CHILD0白名单中包硬盘设备
    if [ "$(echo "$whitelist" | grep -c "$device_number_major:$device_number_minor")" -eq 1 ]; then
        assert_true [ true ]
    else
        assert_false [ true ]
    fi

    # @测试步骤:5: 在父cgroup中禁用块设备访问（包含了硬盘设备）
    echo "b *:* rwm" >"$CGROUP_TOPDIR"/devices/$CGROUP/devices.deny

    # @测试步骤:6: 查看CHILD0的允许访问设备的白名单
    whitelist=$(cat "$CGROUP_TOPDIR"/devices/$CHILD0/devices.list)

    # @预期结果:2: 此时CHILD0白名单将不再包含硬盘设备
    if [ "$(echo "$whitelist" | grep -c "$device_number_major:$device_number_minor")" -eq 0 ]; then
        assert_true [ true ]
    else
        assert_false [ true ]
    fi
    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/devices/$CHILD0
    rmdir "$CGROUP_TOPDIR"/devices/$CGROUP
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
