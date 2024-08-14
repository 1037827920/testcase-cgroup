#!/bin/bash
###############################################################################
# @用例ID: 20240809-113705-534422637
# @用例名称: cgroup-v2-cpuset-mems
# @用例级别: 1
# @用例标签: cgroup-v2 cpuset mems
# @用例类型: 测试cpuset.mems和cpuset.mems.effetive接口文件
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

CGROUP="cgroup-v2-cpuset-mems"

tc_setup() {
    msg "this is tc_setup"
    # @预置条件: 检查cgroup版本是否为cgroup v2
    if ! check_cgroup_version_is_v2; then
        skip_test "cgroup版本不是v2"
    fi
    # @预置条件：检查numactl命令是否存在
    if ! is_numactl_installed; then
        skip_test "numactl 未安装, 请先安装numactl"
    fi
    # @预置条件：检查是否支持NUMA
    numa_nodes=$(numactl -H | grep "available" | cut -d' ' -f2)
    if [ "$numa_nodes" = "0" ]; then
        skip_test "系统不支持NUMA架构"
    fi
    # @预置条件：检查NUMA节点数量是否大于1
    if [ "$numa_nodes" -lt 2 ]; then
        skip_test "系统NUMA节点数量小于2"
    fi
    # @预置条件: 检查是否安装了numastat
    if ! is_numastat_installed; then
        skip_test "numastat 未安装, 请先安装numastat"
    fi

    # @预置条件: 创建cgroup
    mkdir "$CGROUP_TOPDIR"/$CGROUP
    # @预置条件: 检查当前cgroup是否能启用cpuset控制器
    if ! check_string_in_file "cpuset" "$CGROUP_TOPDIR/cgroup.controllers"; then
        skip_test "当前cgroup不能启用cpuset控制器"
    fi
    # @预置条件: 启用cpuset控制器
    echo "+cpuset" >"$CGROUP_TOPDIR"/cgroup.subtree_control || return 1

    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 设置cpuset.mems
    echo 1 >"$CGROUP_TOPDIR"/$CGROUP/cpuset.mems

    # @预期结果:1: 验证CGROUP的可用内存节点是否为1
    online_mems=$(cat "$CGROUP_TOPDIR"/$CGROUP/cpuset.mems.effective)
    assert_true [ "$online_mems" -eq 1 ]

    # @测试步骤:2: 启动一个进程并将其放入CGROUP
    {
        while true; do :; done
    } &
    task_pid=$!
    echo $task_pid >"$CGROUP_TOPDIR"/$CGROUP/cgroup.procs
    sleep 1

    # @预期结果:2: 验证进程是否绑定了指定的内存节点
    mems_allowed=$(cat /proc/$task_pid/status | grep "Mems_allowed_list" | awk '{print $2}')
    assert_true [ "$mems_allowed" -eq 1 ]

    # @测试步骤:3: 获取指定内存节点上进程的内存使用情况
    mems_usage_in_numa1=$(numastat -p $task_pid | awk 'END{print $3}')
    msg "mems_usage_in_numa1: $mems_usage_in_numa1"

    # @预期结果:3: mems_usage_in_numa1大于0
    assert_true [ "$(echo "$mems_usage_in_numa1 > 0" | bc)" -eq 1 ]

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 清空后台进程
    kill -9 "$task_pid"
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/$CGROUP
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
