#!/bin/bash
###############################################################################
# @用例ID: 20240809-185415-655135944
# @用例名称: cgroup-v2-hugetlb-rsvd-max-002
# @用例级别: 2
# @用例标签: cgroup-v2 hugetlb rsvd max
# @用例类型：测试hugetlb.2MB.rsvd.max接口文件，不超过限制
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

CGROUP="cgroup-v2-hugetlb-rsvd-max-002"
TOLERANCE=0.3

tc_setup() {
    msg "this is tc_setup"
    # @预置条件: 检查cgroup版本是否为cgroup v2
    if ! check_cgroup_version_is_v2; then
        skip_test "cgroup版本不是v2"
    fi

    # @预置条件: 创建cgroup
    mkdir "$CGROUP_TOPDIR"/$CGROUP
    # @预置条件: 检查当前cgroup是否能启用hugetlb控制器
    if ! check_string_in_file "hugetlb" "$CGROUP_TOPDIR/cgroup.controllers"; then
        skip_test "当前cgroup不能启用hugetlb控制器"
    fi
    # @预置条件: 启用hugetlb控制器
    echo "+hugetlb" >"$CGROUP_TOPDIR"/cgroup.subtree_control || return 1

    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 获取系统hugepage数量
    hugepage_size=$(cat /proc/sys/vm/nr_hugepages)

    # @测试步骤:2: 修改系统hugepage数量
    echo 4 >/proc/sys/vm/nr_hugepages

    # @测试步骤:3: 获取hugepage大小
    hugepage_size_kb=$(grep Hugepagesize /proc/meminfo | awk '{print $2}')
    msg "hugepage size: $hugepage_size_kb"
    hugepage_size_mb=$(conv_unit -o M -i K "$hugepage_size_kb")

    # @测试步骤:4: 验证hugepage大小是否为2MB
    if [ "$hugepage_size_mb" -ne 2 ]; then
        skip_test "hugepage大小不等于2MB"
    fi

    # @测试步骤:5: 挂载hugetlbfs
    mkdir -p /mnt/huge
    mount none /mnt/huge -t hugetlbfs

    # @测试步骤:6: 设置CGROUP的hugetlb.2MB.rsvd.max为2MB
    echo 2M >"$CGROUP_TOPDIR"/$CGROUP/hugetlb.2MB.rsvd.max

    # @测试步骤:7: 分配1个hugepage
    echo $$ >"$CGROUP_TOPDIR"/$CGROUP/cgroup.procs
    "${TST_TS_TOPDIR}"/tst_lib/cgroup_util/bin/alloc_hugepage_rsvd 1 "$hugepage_size_mb" &>/dev/null &

    # @测试步骤:8: 获取hugetlb.2MB.rsvd.current
    total_hugepage_current=0
    for _ in $(seq 1 5); do
        current=$(cat "$CGROUP_TOPDIR"/$CGROUP/hugetlb.2MB.rsvd.current)
        current=$(echo "$current / 1024 / 1024" | bc)
        total_hugepage_current=$(echo "$total_hugepage_current + $current" | bc)
        sleep 1
    done
    aver_hugepage_current=$(echo "$total_hugepage_current / 5" | bc)
    msg "aver_hugepage_current: $aver_hugepage_current"

    # @预期结果:1: 在误差允许的范围内，aver_hugepage_current等于2
    diff=$((aver_hugepage_current - 2))
    abs_diff=${diff#-}
    assert_true [ "$(echo "$abs_diff < $TOLERANCE" | bc)" -eq 1 ]

    # @测试步骤:9: 获取hugetlb.2MB.events的max字段
    max_cnt=$(grep "max" "$CGROUP_TOPDIR"/$CGROUP/hugetlb.2MB.events | awk '{print $2}')

    # @预期结果:2: max_cnt等于0
    assert_true [ "$max_cnt" -eq 0 ]

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 将shell进程移出cgroup
    echo $$ >"$CGROUP_TOPDIR"/cgroup.procs
    # @清理工作: 卸载hugetlbfs
    umount /mnt/huge
    rmdir /mnt/huge
    # @清理工作: 恢复系统本来的hugepage的大小
    echo "$hugepage_size" >/proc/sys/vm/nr_hugepages
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/$CGROUP
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
