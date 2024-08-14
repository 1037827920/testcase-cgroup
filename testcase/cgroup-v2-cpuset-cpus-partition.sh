#!/bin/bash
###############################################################################
# @用例ID: 20240809-112859-075549357
# @用例名称: cgroup-v2-cpuset-cpus-partition
# @用例级别: 2
# @用例标签: cgroup-v2 cpuset cpus partition
# @用例类型: 测试cpuset.cpus.patition接口文件
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

CGROUP="cgroup-v2-cpuset-cpus-partition"
CHILD0="$CGROUP/child0"
CHILD1="$CGROUP/child1"

tc_setup() {
    msg "this is tc_setup"
    # @预置条件: 检查cgroup版本是否为cgroup v2
    if ! check_cgroup_version_is_v2; then
        skip_test "cgroup版本不是v2"
    fi

    # @预置条件: 创建cgroup
    mkdir "$CGROUP_TOPDIR"/$CGROUP
    # @预置条件: 检查当前cgroup是否能启用cpuset控制器
    if ! check_string_in_file "cpuset" "$CGROUP_TOPDIR/cgroup.controllers"; then
        skip_test "当前cgroup不能启用cpuset控制器"
    fi
    # @预置条件: 启用cpuset控制器
    echo "+cpuset" >"$CGROUP_TOPDIR"/cgroup.subtree_control || return 1
    echo "+cpuset" >"$CGROUP_TOPDIR"/$CGROUP/cgroup.subtree_control || return 1
    # @预置条件: 获取系统cpu的数量
    cpu_nums=$(grep -c ^processor /proc/cpuinfo)
    msg "cpu_nums: $cpu_nums"
    for_cpu_nums=$((cpu_nums - 2))
    if [ "$for_cpu_nums" -le 2 ]; then
        skip_test "当前系统cpu小于等于两个"
    fi

    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 获取cpu online list
    file_path="$CGROUP_TOPDIR"/$CGROUP/cpuset.cpus.effective
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

        echo "$first_online_cpu-$second_online_cpu" >"$CGROUP_TOPDIR"/$CGROUP/cpuset.cpus && ret=0 && break
    done
    if [ $ret -ne 0 ]; then
        skip_test "没有可独占的CPU"
    fi

    # @测试步骤:3: 设置CGROUP为partition root
    echo "root" >"$CGROUP_TOPDIR"/$CGROUP/cpuset.cpus.partition
    
    # @测试步骤:4: 创建子cgroup
    mkdir "$CGROUP_TOPDIR"/$CHILD0
    mkdir "$CGROUP_TOPDIR"/$CHILD1

    # @预期结果:1: 查看CGROUP/CHILD0/CHILD1的cpuset.cpus.effevtive是否为online_cpu
    cgroup_cpuset_cpus_effective=$(cat "$CGROUP_TOPDIR"/$CGROUP/cpuset.cpus.effective)
    assert_true [ "$cgroup_cpuset_cpus_effective" = "$first_online_cpu-$second_online_cpu" ]
    child0_cpuset_cpus_effective=$(cat "$CGROUP_TOPDIR"/$CHILD0/cpuset.cpus.effective)
    assert_true [ "$child0_cpuset_cpus_effective" = "$first_online_cpu-$second_online_cpu" ]
    child1_cpuset_cpus_effective=$(cat "$CGROUP_TOPDIR"/$CHILD1/cpuset.cpus.effective)
    assert_true [ "$child1_cpuset_cpus_effective" = "$first_online_cpu-$second_online_cpu" ]

    # @测试步骤:5: 设置CHILD0的cpuset.cpus为first_online_cpu
    echo "$first_online_cpu" >"$CGROUP_TOPDIR"/$CHILD0/cpuset.cpus

    # @测试步骤:6: 设置CHILD0为partition root
    echo "root" >"$CGROUP_TOPDIR"/$CHILD0/cpuset.cpus.partition

    # @预期结果:2: 查看CHILD0的cpuset.cpus.effevtive是否为first_online_cpu
    child0_cpuset_cpus_effective=$(cat "$CGROUP_TOPDIR"/$CHILD0/cpuset.cpus.effective)
    assert_true [ "$child0_cpuset_cpus_effective" = "$first_online_cpu" ]

    # @预期结果:3: 查看CGROUP/CHILD1的cpuset.cpus.effevtive是否去除了first_online_cpu
    cgroup_cpuset_cpus_effective=$(cat "$CGROUP_TOPDIR"/$CGROUP/cpuset.cpus.effective)
    assert_true [ "$cgroup_cpuset_cpus_effective" = "$second_online_cpu" ]
    child1_cpuset_cpus_effective=$(cat "$CGROUP_TOPDIR"/$CHILD1/cpuset.cpus.effective)
    assert_true [ "$child1_cpuset_cpus_effective" = "$second_online_cpu" ]

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/$CHILD0
    rmdir "$CGROUP_TOPDIR"/$CHILD1
    rmdir "$CGROUP_TOPDIR"/$CGROUP
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
