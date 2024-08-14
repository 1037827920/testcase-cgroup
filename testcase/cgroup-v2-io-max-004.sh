#!/bin/bash
###############################################################################
# @用例ID: 20240808-110221-955418429
# @用例名称: cgroup-v2-io-max-004
# @用例级别: 1
# @用例标签: cgroup-v2 io max
# @用例类型: 测试io.max接口文件的wiops
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

CGROUP="cgroup-v2-io-max-004"
TMP_FILE="$(mktemp)"

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
    echo "$device_number wiops=100" >"$CGROUP_TOPDIR"/$CGROUP/io.max

    # @测试步骤:3: 启动一个dd进程
    echo $$ >"$CGROUP_TOPDIR"/$CGROUP/cgroup.procs
    dd if=$disk of=/tmp/testfile bs=4k count=500 oflag=direct &>"$TMP_FILE"
    time=$(grep -oP '(?<=, )\d+\.\d+(?= s)' "$TMP_FILE")
    msg "time: $time"

    # @测试步骤:4: 获取写入速度
    deivce_line=$(grep "$device_number" "$CGROUP_TOPDIR"/$CGROUP/io.stat)
    wirte_iops=$(echo "$deivce_line" | grep -oP "wios=\K\d+")
    write_iops_per_second=$(echo "scale=2; $wirte_iops / $time" | bc)
    msg "read_iops: $write_iops_per_second"
    up_wirte_iops=110
    down_wirte_iops=90

    # @预期结果:1: 如果读取速率在100 IO/s左右，说明限速成功
    if [ "$(echo "$write_iops_per_second > $down_wirte_iops" | bc)" -eq 1 ]; then
        assert_true [ "$(echo "$write_iops_per_second < $up_wirte_iops" | bc)" -eq 1 ]
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
    rm "$TMP_FILE"
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
