#!/bin/bash
###############################################################################
# @用例ID: 20240714-215345-717910787
# @用例名称: cgroup-v1-cpuset-cpu_exclusive
# @用例级别: 3
# @用例标签: cgroup-v1 cpuset cpu_exclusive
# @用例类型: 测试cpu_exclusive接口文件
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

CGROUP="cgroup-v1-cpuset-cpu_exclusive"
CHILD0="$CGROUP/child0"
CHILD1="$CGROUP/child1"

tc_setup() {
    msg "this is tc_setup"
    # @预置条件: 检查cgroup版本是否为cgroup v1
    if ! check_cgroup_version_is_v1; then
        skip_test "cgroup版本不是v1"
    fi

    # @预置条件: 创建cgroup
    mkdir "$CGROUP_TOPDIR"/cpuset/$CGROUP
    mkdir "$CGROUP_TOPDIR"/cpuset/$CHILD0
    mkdir "$CGROUP_TOPDIR"/cpuset/$CHILD1
    # @预置条件: 设置cpuset.mems文件
    echo 0 >"$CGROUP_TOPDIR"/cpuset/$CGROUP/cpuset.mems
    echo 0 >"$CGROUP_TOPDIR"/cpuset/$CHILD0/cpuset.mems
    echo 0 >"$CGROUP_TOPDIR"/cpuset/$CHILD1/cpuset.mems
    # @获取系统cpu的数量
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

    # @测试步骤:2: 获取没被独占的两个在线cpu
    ret=-1
    for i in $(seq 0 "$for_cpu_nums"); do
        first_online_cpu=$(echo "$cpu_online_list" | awk -v col="$((i + 1))" '{print $col}')
        msg "first_online_cpu: $first_online_cpu"
        second_online_cpu=$(echo "$cpu_online_list" | awk -v col="$((i + 2))" '{print $col}')
        msg "second_online_cpu: $second_online_cpu"
        if [ -z "$first_online_cpu" ] || [ -z "$second_online_cpu" ]; then
            skip_test "没有足够的在线cpu"
        fi

        echo "$first_online_cpu-$second_online_cpu" >"$CGROUP_TOPDIR"/cpuset/$CGROUP/cpuset.cpus && ret=0 && break
    done
    if [ $ret -ne 0 ]; then
        skip_test "没有可独占的CPU"
    fi

    # @测试步骤:3: 设置root cgroup和CGROUP的cpuset.cpu_exclusive为1
    echo 1 >"$CGROUP_TOPDIR"/cpuset/cpuset.cpu_exclusive
    echo 1 >"$CGROUP_TOPDIR"/cpuset/$CGROUP/cpuset.cpu_exclusive

    # @测试步骤:4: 设置CHILD0独占first_online_cpu
    echo "$first_online_cpu" >"$CGROUP_TOPDIR"/cpuset/$CHILD0/cpuset.cpus
    echo 1 >"$CGROUP_TOPDIR"/cpuset/$CHILD0/cpuset.cpu_exclusive

    # @测试步骤:5: 尝试在CHILD1中设置包含被CHILD0独占的first_online_cpu
    ret=-1
    echo "$first_online_cpu" >"$CGROUP_TOPDIR"/cpuset/$CHILD1/cpuset.cpus || ret=0

    # @预期结果:1: 验证设置cpuset.cpus失败
    assert_true [ $ret -eq 0 ]

    # @测试步骤:6: 设置CHILD1独占second_online_cpu
    echo "$second_online_cpu" >"$CGROUP_TOPDIR"/cpuset/$CHILD1/cpuset.cpus
    echo 1 >"$CGROUP_TOPDIR"/cpuset/$CHILD1/cpuset.cpu_exclusive

    # @测试步骤:7: 尝试在CHILD0中设置包含被CHILD1独占的second_online_cpu
    ret=-1
    echo "$second_online_cpu" >"$CGROUP_TOPDIR"/cpuset/$CHILD0/cpuset.cpus || ret=0

    # @预期结果:2: 验证设置cpuset.cpus失败
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
