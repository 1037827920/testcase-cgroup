#!/bin/bash
###############################################################################
# @用例ID: 20240808-110216-648820128
# @用例名称: cgroup-v2-io-max-002
# @用例级别: 1
# @用例标签: cgroup-v2 io max
# @用例类型: 测试io.max接口文件的wbps
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

CGROUP="cgroup-v2-io-max-002"
TMP_FILE="$(mktemp)"
TMP_WIRTE_FILE="$(mktemp)"

tc_setup() {
    msg "this is tc_setup"
    # @预置条件: 检查cgroup版本是否为cgroup v2
    if ! check_cgroup_version_is_v2; then
        skip_test "cgroup版本不是v2"
    fi
    # @预置条件: 检查是否安装了dd工具
    if ! is_dd_installed; then
        skip_test "未安装dd命令"
    fi

    # @预置条件: 创建cgroup
    mkdir "$CGROUP_TOPDIR"/$CGROUP
    # @预置条件: 检查当前cgroup是否能启用io控制器
    if ! check_string_in_file "io" "$CGROUP_TOPDIR/cgroup.controllers"; then
        skip_test "当前cgroup不能启用io控制器"
    fi
    # @预置条件: 启用io控制器
    echo "+io" >"$CGROUP_TOPDIR"/cgroup.subtree_control || return 1

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

    # @测试步骤:2: 设置io.max
    echo "$device_number wbps=1048576" >"$CGROUP_TOPDIR"/$CGROUP/io.max

    # @测试步骤:3: 启动一个dd进程
    echo $$ >"$CGROUP_TOPDIR"/$CGROUP/cgroup.procs
    dd if=$disk of="$TMP_WIRTE_FILE" bs=1M count=3 oflag=direct &>"$TMP_FILE"

    # @测试步骤:4: 获取dd进程的写入速度
    write_bps=$(grep -o '[0-9.]\+ MB/s' "$TMP_FILE" | awk '{print $1}')
    msg "write_bps: $write_bps"
    up_write_bps=1.2
    down_write_bps=0.8

    # @预期结果:1: 如果写入速率在1MB/s左右，说明限速成功
    if [ "$(echo "$write_bps > $down_write_bps" | bc)" -eq 1 ]; then
        assert_true [ "$(echo "$write_bps < $up_write_bps" | bc)" -eq 1 ]
    else
        assert_false [ true ]
    fi

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 将shell进程移出cgroup
    echo $$ >"$CGROUP_TOPDIR"/cgroup.procs
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/$CGROUP
    # @清理工作: 删除临时文件
    rm "$TMP_FILE" "$TMP_WIRTE_FILE"
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
