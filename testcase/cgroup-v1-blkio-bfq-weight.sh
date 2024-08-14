#!/bin/bash
###############################################################################
# @用例ID: 20240721-163304-894253469
# @用例名称: cgroup-v1-blkio-bfq-weight
# @用例级别: 1
# @用例标签: cgroup-v1 blkio bfq-weight
# @用例类型: 测试接口文件blkio.bfq.weight
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

CGROUP="cgroup-v1-blkio-bfq-weight"
CHILD0="$CGROUP/child0"
CHILD1="$CGROUP/child1"
CHILD2="$CGROUP/child2"
TMP_FILE0="$(mktemp)"
TMP_FILE1="$(mktemp)"
TMP_FILE2="$(mktemp)"

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

    # @预置条件: 创建两个cgroup组
    mkdir "$CGROUP_TOPDIR"/blkio/$CGROUP
    mkdir "$CGROUP_TOPDIR"/blkio/$CHILD0
    mkdir "$CGROUP_TOPDIR"/blkio/$CHILD1
    mkdir "$CGROUP_TOPDIR"/blkio/$CHILD2

    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 获取硬盘设备
    if [[ -e /dev/sda ]]; then
        msg "disk is /dev/sda"
        disk="sda"
    else    
        msg "disk is /dev/vda"
        disk="vda"
    fi

    # @测试步骤:2: 保存当前调度器设置
    original_scheduler=$(grep -oP '\[\K[^\]]+' /sys/block/$disk/queue/scheduler)
    echo "原始调度器: $original_scheduler"

    # @测试步骤:3: 设置调度器为bfq
    echo bfq > /sys/block/$disk/queue/scheduler || return 1


    # @测试步骤:4: 设置CHILD0\CHILD1\CHILD2的blkio.bfq.weight
    echo 100 >"$CGROUP_TOPDIR"/blkio/$CHILD0/blkio.bfq.weight
    echo 200 >"$CGROUP_TOPDIR"/blkio/$CHILD1/blkio.bfq.weight
    echo 300 >"$CGROUP_TOPDIR"/blkio/$CHILD2/blkio.bfq.weight

    # @测试步骤:5: 启动dd进程
    sync
    echo 3 >/proc/sys/vm/drop_caches
    echo $$ > "$CGROUP_TOPDIR"/blkio/$CHILD0/cgroup.procs
    dd iflag=direct if=/dev/$disk of=/dev/null bs=1M count=1024 &>"$TMP_FILE0" &
    task_pid0=$!
    echo $$ > "$CGROUP_TOPDIR"/blkio/$CHILD1/cgroup.procs
    dd iflag=direct if=/dev/$disk of=/dev/null bs=1M count=1024 &>"$TMP_FILE1" &
    echo $$ > "$CGROUP_TOPDIR"/blkio/$CHILD2/cgroup.procs
    dd iflag=direct if=/dev/$disk of=/dev/null bs=1M count=1024 &>"$TMP_FILE2" &
    wait $task_pid0

    msg "io serviced 0: $(cat "$CGROUP_TOPDIR"/blkio/$CHILD0/blkio.throttle.io_serviced)"
    msg "io serviced 1: $(cat "$CGROUP_TOPDIR"/blkio/$CHILD1/blkio.throttle.io_serviced)"
    msg "io serviced 2: $(cat "$CGROUP_TOPDIR"/blkio/$CHILD2/blkio.throttle.io_serviced)"
    
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
    # @清理工作: 将shell进程从cgroup中移除
    echo $$ > "$CGROUP_TOPDIR"/blkio/cgroup.procs
    # @清理工作: 恢复调度器设置
    echo "$original_scheduler" > /sys/block/"$disk"/queue/scheduler
    # @清理工作: 删除创建的cgroup组
    rmdir "$CGROUP_TOPDIR"/blkio/$CHILD0
    rmdir "$CGROUP_TOPDIR"/blkio/$CHILD1
    rmdir "$CGROUP_TOPDIR"/blkio/$CHILD2
    rmdir "$CGROUP_TOPDIR"/blkio/$CGROUP
    # @清理工作: 删除临时文件
    rm "$TMP_FILE0"
    rm "$TMP_FILE1"
    rm "$TMP_FILE2"
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################