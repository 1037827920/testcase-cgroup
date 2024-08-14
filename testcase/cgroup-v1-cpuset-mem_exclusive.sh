#!/bin/bash
###############################################################################
# @用例ID: 20240716-153117-722732954
# @用例名称: cgroup-v1-cpuset-mem_exclusive
# @用例级别: 1
# @用例标签: cgroup-v cpuset mem_exclusive
# @用例类型: 测试cpuset.mem_exclusive接口文件
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

CGROUP="cgroup-v1-cpuset-mem_exclusive"
CHILD0="$CGROUP/child0"
CHILD1="$CGROUP/child1"

tc_setup() {
    msg "this is tc_setup"
    # @预置条件: 检查cgroup版本是否为cgroup v1
    if ! check_cgroup_version_is_v1; then
        skip_test "cgroup版本不是v1"
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

    # @预置条件: 创建两个新的cgroup
    mkdir "$CGROUP_TOPDIR"/cpuset/$CGROUP
    mkdir "$CGROUP_TOPDIR"/cpuset/$CHILD0
    mkdir "$CGROUP_TOPDIR"/cpuset/$CHILD1
    # @预置条件: 获取系统cpu的数量
    cpu_nums=$(grep -c ^processor /proc/cpuinfo)
    msg "cpu_nums: $cpu_nums"
    for_cpu_nums=$((cpu_nums - 2))
    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 获取cpu online list
    file_path="$CGROUP_TOPDIR"/cpuset/cpuset.effective_cpus
    cpu_online_list=$(get_online_cpu_list "$file_path")
    msg "cpu_online_list: $cpu_online_list"

    # @测试步骤:2: 获取没被独占的一个在线cpu
    ret=-1
    for i in $(seq 0 "$for_cpu_nums"); do
        first_online_cpu=$(echo "$cpu_online_list" | awk -v col="$((i + 1))" '{print $col}')
        msg "first_online_cpu: $first_online_cpu"
        if [ -z "$first_online_cpu" ]; then
            skip_test "没有足够的在线cpu"
        fi

        echo "$first_online_cpu" >"$CGROUP_TOPDIR"/cpuset/$CGROUP/cpuset.cpus && ret=0 && break
    done
    if [ $ret -ne 0 ]; then
        skip_test "没有可独占的CPU"
    fi
    echo "$first_online_cpu" >"$CGROUP_TOPDIR"/cpuset/$CHILD0/cpuset.cpus
    echo "$first_online_cpu" >"$CGROUP_TOPDIR"/cpuset/$CHILD1/cpuset.cpus

    # @测试步骤:3: 设置root cgroup和CGROUP的cpuset.cpu_exclusive为1
    echo 1 >"$CGROUP_TOPDIR"/cpuset/cpuset.cpu_exclusive
    echo 1 >"$CGROUP_TOPDIR"/cpuset/$CGROUP/cpuset.cpu_exclusive

    # @测试步骤:4: 获取mem online list
    file_path="$CGROUP_TOPDIR"/cpuset/cpuset.effective_mems
    mem_online_list=$(get_online_mem_list "$file_path")
    msg "mem_online_list: $mem_online_list"

    # @测试步骤:5: 获取两个在线mem
    first_online_mem=$(echo "$mem_online_list" | awk '{print $1}')
    msg "first_online_mem: $first_online_mem"
    second_online_mem=$(echo "$mem_online_list" | awk '{print $2}')
    msg "second_online_mem: $second_online_mem"

    # @测试步骤:6: 设置CGROUP的cpuset.mems
    echo "$first_online_mem-$second_online_mem" >"$CGROUP_TOPDIR"/cpuset/$CGROUP/cpuset.mems

    # @测试步骤:7: 设置CGROUp的cpuset.mem_exclusive文件
    echo 1 >"$CGROUP_TOPDIR"/cpuset/cpuset.mem_exclusive
    echo 1 >"$CGROUP_TOPDIR"/cpuset/$CGROUP/cpuset.mem_exclusive

    # @测试步骤:8: 设置CHILD0独占first_online_mem
    echo "$first_online_mem" >"$CGROUP_TOPDIR"/cpuset/$CHILD0/cpuset.mems
    echo 1 >"$CGROUP_TOPDIR"/cpuset/$CHILD0/cpuset.mem_exclusive

    # @测试步骤:9: 尝试在CHILD1中设置包含被CHILD0独占的first_online_mem
    ret=-1
    echo "$first_online_mem" >"$CGROUP_TOPDIR"/cpuset/$CHILD1/cpuset.mems || ret=0

    # @预期结果:1: 验证设置cpuset.mems失败
    assert_true [ $ret -eq 0 ]

    # @测试步骤:10: 设置CHILD1独占second_online_mem
    echo "$second_online_mem" >"$CGROUP_TOPDIR"/cpuset/$CHILD1/cpuset.mems
    echo 1 >"$CGROUP_TOPDIR"/cpuset/$CHILD1/cpuset.mem_exclusive

    # @测试步骤:11: 尝试在CHILD0中设置包含被CHILD1独占的second_online_mem
    ret=-1
    echo "$second_online_mem" >"$CGROUP_TOPDIR"/cpuset/$CHILD0/cpuset.mems || ret=0

    # @预期结果:2: 验证设置cpuset.mems失败
    assert_true [ $ret -eq 0 ]

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/cpuset/$CHILD0
    rmdir "$CGROUP_TOPDIR"/cpuset/$CHILD1
    rmdir "$CGROUP_TOPDIR"/cpuset/$CGROUP
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
