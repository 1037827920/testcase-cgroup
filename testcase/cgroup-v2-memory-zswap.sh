#!/bin/bash
###############################################################################
# @用例ID: 20240807-200055-083750426
# @用例名称: cgroup-v2-memory-zswap
# @用例级别: 2
# @用例标签: cgroup-v2 memory zswap
# @用例类型: 测试memory.zswap.max和memory.zswap.current接口文件, 达到限制不会触发写回操作
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

CGROUP="cgroup-v2-memory-zswap"

tc_setup() {
    msg "this is tc_setup"
    # @预置条件: 检查cgroup版本是否为cgroup v2
    if ! check_cgroup_version_is_v2; then
        skip_test "cgroup版本不是v2"
    fi

    # @预置条件: 创建cgroup
    mkdir "$CGROUP_TOPDIR"/$CGROUP
    # @预置条件: 检查当前cgroup是否能启用memory控制器
    if ! check_string_in_file "memory" "$CGROUP_TOPDIR/cgroup.controllers"; then
        skip_test "当前cgroup不能启用memory控制器"
    fi
    # @预置条件: 启用memory控制器
    echo "+memory" >"$CGROUP_TOPDIR"/cgroup.subtree_control || return 1
    # @预置条件: 查看系统是否启用了zswap
    if ! dmesg | grep zswap &>/dev/null; then
        skip_test "系统未启用zswap"
    fi

    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 设置memory.max为1M
    echo 1M >"$CGROUP_TOPDIR"/$CGROUP/memory.max

    # @测试步骤:2: 设置memory.zswap.max为10K
    echo 10K >"$CGROUP_TOPDIR"/$CGROUP/memory.zswap.max || return 1

    # @测试步骤:3: 获取当前zswap已经写回的页数
    written_back_before=$(cat /sys/kernel/debug/zswap/written_back_pages)
    msg "written_back_before: $written_back_before"

    # @测试步骤:4: 分配10M匿名内存的进程
    echo $$ >"$CGROUP_TOPDIR"/$CGROUP/cgroup.procs
    "$TST_TS_TOPDIR"/tst_lib/cgroup_util/bin/alloc_anon 10M &

    # @测试步骤:5: 获取memory.zswap.current的值
    total_memory_zswap_current=0
    for _ in $(seq 1 10); do
        memory_zswap_current=$(cat /sys/fs/cgroup/$CGROUP/memory.zswap.current)
        memory_zswap_current=$(echo "$memory_zswap_current / 1024" | bc)
        total_memory_zswap_current=$(echo "$total_memory_zswap_current + $memory_zswap_current" | bc)
        sleep 1
    done
    aver_memory_zswap_current=$(echo "$total_memory_zswap_current / 10" | bc)
    msg "aver_memory_zswap_current: $aver_memory_zswap_current KB"

    # @预期结果:1: memory.zswap.current大于0
    assert_true [ "$(echo "$aver_memory_zswap_current > 0" | bc)" -eq 1 ]

    # @测试步骤:6: 获取当前zswap已经写回的页数
    written_back_after=$(cat /sys/kernel/debug/zswap/written_back_pages)
    msg "written_back_after: $written_back_after"

    # @预期结果:2: 之前写回和现在写回的页数相等
    assert_true [ "$written_back_before" -eq "$written_back_after" ]

    # @测试步骤:7: 获取memory.stat中的zswapped字段
    zswapped=$(grep "zswapped" "$CGROUP_TOPDIR"/$CGROUP/memory.stat | awk '{print $2}')
    msg "zswapped: $zswapped"

    # @预期结果:3: zswapped字段大于0
    assert_true [ "$zswapped" -gt 0 ]

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 将当前shell移出cgroup
    echo $$ >"$CGROUP_TOPDIR"/cgroup.procs
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/$CGROUP
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
