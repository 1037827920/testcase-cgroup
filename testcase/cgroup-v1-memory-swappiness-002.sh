#!/bin/bash
###############################################################################
# @用例ID: 20240723-162157-535660907
# @用例名称: cgroup-v1-memory-swappiness-002
# @用例级别: 2
# @用例标签: cgroup-v1 memory swappiness
# @用例类型: 测试memory.swappiness控制文件，当swappiness为100时，内存会被交换到swap空间
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

CGROUP="cgroup-v1-memory-swappiness-002"

tc_setup() {
    msg "this is tc_setup"
    # @预置条件: 检查cgroup版本是否为cgroup v1
    if ! check_cgroup_version_is_v1; then
        skip_test "cgroup版本不是v1"
    fi
    # @预置条件: 检查是否开启了CONFIG_MEMCG配置
    if ! grep -q CONFIG_MEMCG=y /boot/config-"$(uname -r)"; then
        skip_test "CONFIG_MEMCG 配置未开启"
    fi

    # @预置条件: 创建一个cgroup
    mkdir "$CGROUP_TOPDIR"/memory/$CGROUP
    # @预置条件: 查看系统是否启用了swapping
    if [ -z "$(swapon --show)" ]; then
        skip_test "系统未启用swap或没有swapfile"
    fi
    # @预置条件: 清空swap空间内存
    sudo swapoff -a
    sudo swapon -a
    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 设置cgroup的内存限制为50M
    echo 50M >"$CGROUP_TOPDIR"/memory/$CGROUP/memory.limit_in_bytes

    # @测试步骤:2: 设置cgroup的内存swappiness为100
    echo 100 >"$CGROUP_TOPDIR"/memory/$CGROUP/memory.swappiness

    # @测试步骤:3: 分配50M内存
    echo $$ >"$CGROUP_TOPDIR"/memory/$CGROUP/cgroup.procs
    "$TST_TS_TOPDIR"/tst_lib/cgroup_util/bin/alloc_anon 50M

    # @测试步骤:4: 获取swap空间内存使用量
    swap_usage=$(grep swap "$CGROUP_TOPDIR"/memory/$CGROUP/memory.stat | head -n 1 | awk '{print $2}')
    msg "swap_usage: $swap_usage"

    # @预期结果:1: swap空间内存使用量大于0
    assert_true [ "$swap_usage" -gt "0" ]

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 将shell进程从cgroup中移除
    echo $$ >"$CGROUP_TOPDIR"/memory/cgroup.procs
    # @清理工作: 清空所有内存页
    echo 0 >"$CGROUP_TOPDIR"/memory/$CGROUP/memory.force_empty
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/memory/$CGROUP
    # @清理工作: 清理swap空间
    sudo swapoff -a
    sudo swapon -a
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
