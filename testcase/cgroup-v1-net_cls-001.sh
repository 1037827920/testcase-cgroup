#!/bin/bash
###############################################################################
# @用例ID: 20240726-114714-002803899
# @用例名称: cgroup-v1-net_cls-001
# @用例级别: 1
# @用例标签: cgroup-v1 net_cls
# @用例类型: 测试设置带宽限制的情况
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

CGROUP="cgroup-v1-net_cls-001"
TMP_FILE=$(mktemp)

tc_setup() {
    msg "this is tc_setup"
    # @预置条件: 检查cgroup版本是否为cgroup v1
    if ! check_cgroup_version_is_v1; then
        skip_test "cgroup版本不是v1"
    fi
    # @预置条件: 检查是否开启了CONFIG_CGROUP_NET_CLASSID配置
    if ! grep -q CONFIG_CGROUP_NET_CLASSID=y /boot/config-"$(uname -r)"; then
        skip_test "内核CONFIG_CGROUP_NET_CLASSID配置未开启"
    fi
    # @预置条件: 检查是否安装了tc工具
    if ! is_tc_installed; then
        skip_test "没有安装tc工具"
    fi
    # @预置条件: 检查是否安装了iperf3工具
    if ! is_iperf3_installed; then
        skip_test "没有安装iperf3工具"
    fi

    # @预置条件: 创建cgroup
    mkdir "$CGROUP_TOPDIR"/net_cls/$CGROUP
    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 检查是否有回环接口
    if ! ip addr show lo &>/dev/null; then
        msg "错误信息: 没有找到回环接口lo"
        exit 1
    fi

    # @测试步骤:2: 获取lo接口的ip地址
    lo_ip=$(ip -4 addr show lo | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    msg "lo接口的IP地址是: $lo_ip"

    # @测试步骤:3: 设置net_cls.classid
    echo 0x100001 >"$CGROUP_TOPDIR"/net_cls/$CGROUP/net_cls.classid

    # @预期结果:1: 检查是否设置成功
    classid=$(cat "$CGROUP_TOPDIR"/net_cls/$CGROUP/net_cls.classid)
    assert_true [ "$classid" = "1048577" ]

    # @测试步骤:4: 给lo接口添加新的队列规则
    tc qdisc add dev lo root handle 10: htb

    # @测试步骤:5: 给lo接口添加新的类
    tc class add dev lo parent 10: classid 10:1 htb rate 5mbit

    # @测试步骤:6: 创建过滤器
    tc filter add dev lo parent 10: protocol ip prio 10 handle 1: cgroup

    # @测试步骤:7: 使用ipef3启动服务端
    iperf3 -s &>/dev/null &
    task_pid=$!

    # @测试步骤:8: 将进程加入cgroup；启动iperf3客户端发送数据包到服务端
    echo $$ >"$CGROUP_TOPDIR"/net_cls/$CGROUP/cgroup.procs
    iperf3 -c "$lo_ip" -i 1 -t 5 &>"$TMP_FILE"

    # @测试步骤:9: 获取iperf3的接收数据端的bitrate
    bitrate=$(grep 'receiver' "$TMP_FILE" | awk '{print $7}')
    msg "reciever bitrate: $bitrate"
    up_bitrate=6
    down_bitrate=4

    # @预期结果:2: 在误差允许范围内，检查是否限制了带宽
    kill -9 "$task_pid"
    assert_true [ "$(echo "$bitrate > $down_bitrate" | bc)" -eq 1 -a "$(echo "$bitrate < $up_bitrate" | bc)" -eq 1 ]

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 将shell进程移出cgroup
    echo 0 >"$CGROUP_TOPDIR"/net_cls/cgroup.procs
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/net_cls/$CGROUP
    # @清理工作: 删除队列规则
    tc qdisc del dev lo root
    # @清理工作: 删除临时文件
    rm "$TMP_FILE"
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
