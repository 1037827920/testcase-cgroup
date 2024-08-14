#!/bin/bash
###############################################################################
# @用例ID: 20240807-224514-698927621
# @用例名称: cgroup-v2-io-weight
# @用例级别: 1
# @用例标签: cgroup-v2 io weight
# @用例类型: 测试io.weight接口文件
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

CGROUP="cgroup-v2-io-weight"
CHILD0="$CGROUP/child0"
CHILD1="$CGROUP/child1"
CHILD2="$CGROUP/child2"
TMP_FILE0="$(mktemp)"
TMP_FILE1="$(mktemp)"
TMP_FILE2="$(mktemp)"

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
    mkdir "$CGROUP_TOPDIR"/$CHILD0
    mkdir "$CGROUP_TOPDIR"/$CHILD1
    mkdir "$CGROUP_TOPDIR"/$CHILD2
    # @预置条件: 检查当前cgroup是否能启用io控制器
    if ! check_string_in_file "io" "$CGROUP_TOPDIR/cgroup.controllers"; then
        skip_test "当前cgroup不能启用io控制器"
    fi
    # @预置条件: 启用io控制器
    echo "+io" >"$CGROUP_TOPDIR"/cgroup.subtree_control || return 1
    echo "+io" >"$CGROUP_TOPDIR"/$CGROUP/cgroup.subtree_control || return 1

    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 获取硬盘设备
    if [[ -e /dev/sda ]]; then
        msg "disk is /dev/sda"
        disk="sda"
        disk_device="8:0"
    else
        msg "disk is /dev/vda"
        disk="vda"
        disk_device="253:0"
    fi

    # @测试步骤:2: 启用io.cost.qos
    echo "$disk_device enable=1 ctrl=auto" >"$CGROUP_TOPDIR"/io.cost.qos

    # @测试步骤:3: 设置CHILD0\CHILD1\CHILD2的io.weight
    echo "$disk_device 100" >"$CGROUP_TOPDIR/$CHILD0/io.weight"
    echo "$disk_device 200" >"$CGROUP_TOPDIR/$CHILD1/io.weight"
    echo "$disk_device 300" >"$CGROUP_TOPDIR/$CHILD2/io.weight"

    # @测试步骤:4: 启动dd进程
    echo $$ >"$CGROUP_TOPDIR/$CHILD0/cgroup.procs"
    dd iflag=direct if=/dev/$disk of=/dev/null bs=1M count=512 &>"$TMP_FILE0" &
    task_pid=$!

    echo $$ >"$CGROUP_TOPDIR/$CHILD1/cgroup.procs"
    dd iflag=direct if=/dev/$disk of=/dev/null bs=1M count=512 &>"$TMP_FILE1" &

    echo $$ >"$CGROUP_TOPDIR/$CHILD2/cgroup.procs"
    dd iflag=direct if=/dev/$disk of=/dev/null bs=1M count=512 &>"$TMP_FILE2" &

    wait $task_pid

    # @测试步骤:5: 获取dd进程的读取速度
    read_speed1=$(grep -oP '\d+.\d+' "$TMP_FILE0" | tail -n 1)
    read_speed2=$(grep -oP '\d+.\d+' "$TMP_FILE1" | tail -n 1)
    read_speed3=$(grep -oP '\d+.\d+' "$TMP_FILE2" | tail -n 1)
    msg "read_speed1: $read_speed1"
    msg "read_speed2: $read_speed2"
    msg "read_speed3: $read_speed3"

    # @预期结果:1: CHIlD0的读取速度小于CHILD1的读取速度, CHILD1的读取速度小于CHILD2的读取速度
    if [ "$(echo "$read_speed1 < $read_speed2" | bc)" -eq 1 ]; then
        assert_true [ "$(echo "$read_speed2 < $read_speed3" | bc)" -eq 1 ]
    else
        assert_false [ true ]
    fi

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 关闭io.cost.qos
    echo "$disk_device enable=0" >"$CGROUP_TOPDIR"/io.cost.qos
    # @清理工作: 将shell进程移出cgroup
    echo $$ >"$CGROUP_TOPDIR/cgroup.procs"
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/$CHILD0
    rmdir "$CGROUP_TOPDIR"/$CHILD1
    rmdir "$CGROUP_TOPDIR"/$CHILD2
    rmdir "$CGROUP_TOPDIR"/$CGROUP
    # @清理工作: 删除临时文件
    rm "$TMP_FILE0" "$TMP_FILE1" "$TMP_FILE2"
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
