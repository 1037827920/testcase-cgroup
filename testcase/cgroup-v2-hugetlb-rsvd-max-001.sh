#!/bin/bash
###############################################################################
# @用例ID: 20240809-185414-695820636
# @用例名称: cgroup-v2-hugetlb-rsvd-max-001
# @用例级别: 1
# @用例标签: cgroup-v2 hugetlb rsvd max
# @用例类型：测试hugetlb.2MB.rsvd.max接口文件，超过限制
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

CGROUP="cgroup-v2-hugetlb-rsvd-max-001"

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

    # @测试步骤:6: 获取CGROUP的hugetlb.2MB.rsvd.max值
    max=$(cat "$CGROUP_TOPDIR"/$CGROUP/hugetlb.2MB.rsvd.max)

    # @预期结果:1: 验证hugetlb.2MB.rsvd.max的值是否为max
    assert_true [ "$max" = "max" ]

    # @测试步骤:7: 设置CGROUP的hugetlb.2MB.rsvd.max为2MB
    echo 2M >"$CGROUP_TOPDIR"/$CGROUP/hugetlb.2MB.rsvd.max

    # @测试步骤:8: 分配2个hugepage
    echo $$ >"$CGROUP_TOPDIR"/$CGROUP/cgroup.procs
    "${TST_TS_TOPDIR}"/tst_lib/cgroup_util/bin/alloc_hugepage_rsvd 2 "$hugepage_size_mb" &>/dev/null

    # @测试步骤:9: 获取hugetlb.2MB.events的max字段
    max_cnt=$(grep "max" "$CGROUP_TOPDIR"/$CGROUP/hugetlb.2MB.events | awk '{print $2}')

    # @预期结果:2: max_cnt大于0
    assert_true [ "$max_cnt" -gt 0 ]

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
