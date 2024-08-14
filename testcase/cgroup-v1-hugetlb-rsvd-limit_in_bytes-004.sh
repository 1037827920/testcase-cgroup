#!/bin/bash
###############################################################################
# @用例ID: 20240801-130251-278577040
# @用例名称: cgroup-v1-hugetlb-rsvd-limit_in_bytes-004
# @用例级别: 2
# @用例标签: cgroup-v1 hugetbl rsvd limit_in_bytes
# @用例类型: 测试hugetlb.1GB.rsvd.limit_in_bytes接口文件, 不超过限制
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

CGROUP="cgroup-v1-hugetlb-rsvd-limit_in_bytes-004"

tc_setup() {
    msg "this is tc_setup"
    # @预置条l件: 检查cgroup版本是否为cgroup v1
    if ! check_cgroup_version_is_v1; then
        skip_test "cgroup版本不是v1"
    fi
    # @预置条件: 查看是否有CONFIG_CGROUP_HUGETLB配置
    if ! grep -q "CONFIG_CGROUP_HUGETLB=y" "/boot/config-$(uname -r)"; then
        skip_test "内核CONFIG_CGROUP_HUGETLB配置未开启"
    fi
    # @预置条件: 查看是否有CONFIG_HUGETLB_PAGE配置
    if ! grep -q "CONFIG_HUGETLB_PAGE=y" "/boot/config-$(uname -r)"; then
        skip_test "内核CONFIG_HUGETLB_PAGE配置未开启"
    fi
    # @预置条件: 查看是否有CONFIG_HUGETLBFS配置
    if ! grep -q "CONFIG_HUGETLBFS=y" "/boot/config-$(uname -r)"; then
        skip_test "内核CONFIG_HUGETLBFS配置未开启"
    fi

    # @预置条件: 创建一个cgroup
    mkdir "$CGROUP_TOPDIR"/hugetlb/$CGROUP
    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 获取系统本来的hugepage的数量
    HUGEPAGE_SIZE=$(cat /proc/sys/vm/nr_hugepages)
    echo 1 >/proc/sys/vm/nr_hugepages

    # @测试步骤:2: 获取hugepage的大小
    HUGEPAGE_SIZE_KB=$(grep Hugepagesize /proc/meminfo | awk '{print $2}')
    msg "hugepage size: $HUGEPAGE_SIZE_KB"
    HUGEPAGE_SIZE_MB=$(conv_unit -o M -i K "$HUGEPAGE_SIZE_KB")
    if [ "$HUGEPAGE_SIZE_MB" -ne 1024 ]; then
        skip_test "hugepage的大小不等于1GB"
    fi

    # @测试步骤:3: 挂载hugetlbfs
    mkdir -p /mnt/huge
    mount none /mnt/huge -t hugetlbfs

    # @测试步骤:4: 设置cgroup的hugetlb.limit_in_bytes为2MB
    echo 1024M >"$CGROUP_TOPDIR"/hugetlb/$CGROUP/hugetlb.1GB.rsvd.limit_in_bytes

    # @测试步骤:5: 将当前shell进程加入到cgroup中并运行分配hugepage的程序
    echo $$ >"$CGROUP_TOPDIR"/hugetlb/$CGROUP/cgroup.procs
    "${TST_TS_TOPDIR}"/tst_lib/cgroup_util/bin/alloc_hugepage_rsvd 1 "$HUGEPAGE_SIZE_MB" &>/dev/null

    # @测试步骤:6: 获取cgroup的hugetlb.1GB.rsvd.failcnt
    MAX_USAGE=$(cat "$CGROUP_TOPDIR"/hugetlb/$CGROUP/hugetlb.1GB.rsvd.max_usage_in_bytes)
    msg "max usage: $MAX_USAGE"
    FAILCNT=$(cat "$CGROUP_TOPDIR"/hugetlb/$CGROUP/hugetlb.1GB.rsvd.failcnt)
    msg "failcnt: $FAILCNT"

    # @预期结果:1: failcnt等于0
    if [ "$MAX_USAGE" -eq 1073741824 ] && [ "$FAILCNT" -eq 0 ]; then
        assert_true [ true ]
    else
        assert_false [ true ]
    fi

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 将shell进程移出cgroup
    echo $$ >"$CGROUP_TOPDIR"/hugetlb/cgroup.procs
    # @清理工作: 卸载hugetlbfs
    umount /mnt/huge
    rmdir /mnt/huge
    # @清理工作: 恢复系统本来的hugepage的大小
    echo "$HUGEPAGE_SIZE" >/proc/sys/vm/nr_hugepages
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/hugetlb/$CGROUP
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
