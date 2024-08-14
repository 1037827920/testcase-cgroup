#!/bin/bash
###############################################################################
# @用例ID: 20240721-144526-288264693
# @用例名称: cgroup-v1-blkio-throttle-read_bps_device
# @用例级别: 1
# @用例标签: cgroup-v1 blkio throttle.read_bps_device
# @用例类型: 测试接口文件blkio.throttle.read_bps_device
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

CGROUP="cgroup-v1-blkio-throttle-read_bps_device"
TMP_FILE="$(mktemp)"

tc_setup() {
    msg "this is tc_setup"
    # @预置条件: 检查cgroup版本是否为cgroup v1
    if ! check_cgroup_version_is_v1; then
        skip_test "cgroup版本不是v1"
    fi
    # @预置条件: 检查是否安装了dd工具
    if ! is_dd_installed; then
        skip_test "未安装dd命令"
    fi
    # @预置条件: 检查是否开启CONFIG_BLK_CGROUP配置
    if ! grep -q CONFIG_BLK_CGROUP=y /boot/config-"$(uname -r)"; then
        skip_test "内核CONFIG_BLK_CGROUP配置未开启"
    fi
    # @预置条件: 检查是否开启CONFIG_BLK_DEV_THROTTLING配置
    if ! grep -q CONFIG_BLK_DEV_THROTTLING=y /boot/config-"$(uname -r)"; then
        skip_test "内核CONFIG_BLK_DEV_THROTTLING配置未开启"
    fi

    # @预置条件：创建cgroup组
    mkdir "$CGROUP_TOPDIR"/blkio/$CGROUP
    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 获取硬盘设备
    if [[ -e /dev/sda ]]; then
        msg "disk is /dev/sda"
        disk="/dev/sda"
        device_number="8:0"
    else
        msg "disk is /dev/vda"
        disk="/dev/vda"
        device_number="253:0"
    fi

    # @测试步骤:2: 设置blkio.throttle.read_bps_device，限制速度为1MB/s
    echo "$device_number 1048576" >"$CGROUP_TOPDIR"/blkio/$CGROUP/blkio.throttle.read_bps_device

    # @测试步骤:3: 启动一个dd进程
    echo $$ >"$CGROUP_TOPDIR"/blkio/$CGROUP/cgroup.procs
    dd iflag=direct if=$disk of=/dev/null bs=1M count=3 2>&1 | tee "$TMP_FILE"

    # @测试步骤:4: 获取dd进程的读取速度
    read_bps=$(grep -o '[0-9.]\+ MB/s' "$TMP_FILE" | awk '{print $1}')
    msg "read_bps: $read_bps"
    up_read_bps=1.2
    down_read_bps=0.8

    # @预期结果:1: 如果读取速率在1MB/s左右，说明限速成功
    if [ "$(echo "$read_bps > $down_read_bps" | bc)" -eq 1 ] && [ "$(echo "$read_bps < $up_read_bps" | bc)" -eq 1 ]; then
        assert_true [ true ]
    else
        assert_false [ true ]
    fi

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 将shell进程从cgroup中移除
    echo $$ >"$CGROUP_TOPDIR"/blkio/cgroup.procs
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/blkio/$CGROUP
    # @清理工作: 删除临时文件
    rm "$TMP_FILE"
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
