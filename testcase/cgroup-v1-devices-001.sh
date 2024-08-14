#!/bin/bash
###############################################################################
# @用例ID: 20240724-140024-496158227
# @用例名称: cgroup-v1-devices-001
# @用例级别: 1
# @用例标签: cgroup-v1 devices
# @用例类型: 测试devices.allow接口文件和devices.deny接口文件
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

    # @预置条件: 创建一个cgroup
    mkdir "$CGROUP_TOPDIR"/devices/$CGROUP
    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 获取硬盘设备
    if [[ -e /dev/sda ]]; then
        msg "disk is /dev/sda"
        disk="sda"
        device_number="8:0"
    else
        msg "disk is /dev/vda"
        disk="vda"
        device_number="253:0"
    fi

    # @测试步骤:2: 获取光驱设备
    if [[ -e /dev/sr0 ]]; then
        msg "disk is /dev/sda"
        cdrom="sr0"
    else
        msg "错误信息: 没有光驱设备CD-ROM"
        exit 1
    fi

    # @测试步骤:3: 查看允许访问设备的白名单
    whitelist=$(cat "$CGROUP_TOPDIR"/devices/$CGROUP/devices.list)

    # @预期结果:1: 允许访问设备的白名单为a *:* rwm
    assert_true [ "$whitelist" = "a *:* rwm" ]

    # @测试步骤:4: 限制所有设备访问
    echo "a *:* rwm" >"$CGROUP_TOPDIR"/devices/$CGROUP/devices.deny

    # @测试步骤:5: 查看允许访问设备的白名单
    whitelist=$(cat "$CGROUP_TOPDIR"/devices/$CGROUP/devices.list)

    # @预期结果:2: 允许访问设备的白名单为空
    if [ -z "$whitelist" ]; then
        assert_true [ true ]
    else
        assert_false [ true ]
    fi

    # @测试步骤:6: 允许访问设备
    echo "b $device_number rwm" >"$CGROUP_TOPDIR"/devices/$CGROUP/devices.allow

    # @测试步骤:7: 查看允许访问设备的白名单
    whitelist=$(cat "$CGROUP_TOPDIR"/devices/$CGROUP/devices.list)

    # @预期结果:3: 允许访问设备的白名单包含设备号
    if [ "$(echo "$whitelist" | grep -c "$device_number")" -eq 1 ]; then
        assert_true [ true ]
    else
        assert_false [ true ]
    fi

    # @测试步骤:8: 将当前shell进程加入cgroup

    # @预期结果:4: 验证设备访问限制
    # 访问被允许的设备
    echo $$ >"$CGROUP_TOPDIR"/devices/$CGROUP/cgroup.procs
    ret=-1
    test -r /dev/"$disk" && ret=0
    echo $$ >"$CGROUP_TOPDIR"/devices/cgroup.procs
    assert_true [ "$ret" -eq 0 ] 
    # 访问不被允许的设备
    echo $$ >"$CGROUP_TOPDIR"/devices/$CGROUP/cgroup.procs
    ret=-1
    test -r /dev/"$cdrom" && ret=0
    echo $$ >"$CGROUP_TOPDIR"/devices/cgroup.procs
    assert_false [ "$ret" -eq 0 ]

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/devices/$CGROUP
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
