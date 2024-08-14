#!/bin/bash
###############################################################################
# @用例ID: 20240723-133429-048617311
# @用例名称: cgroup-v1-memory-soft_limit_in_bytes
# @用例级别: 2
# @用例标签: cgroup-v1 memory soft_limit_in_bytes
# @用例类型: 测试memory.soft_limit_in_bytes控制文件
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

CGROUP="cgroup-v1-memory-soft_limit_in_bytes-001"

tc_setup() {
    msg "this is tc_setup"
    # @预置条件: 检查cgroup版本是否为cgroup v1
    if ! check_cgroup_version_is_v1; then
        skip_test "cgroup版本不是v1"
    fi
    # @预置条件: 检查是否开启了CONFIG_MEMCG配置
    if ! grep -q CONFIG_MEMCG=y /boot/config-"$(uname -r)"; then
        skip_test "内核CONFIG_MEMCG配置未开启"
    fi
    # @预置条件: 检查是否没有CONFIG_PREEMPT_RT配置
    if grep -q CONFIG_PREEMPT_RT=y /boot/config-"$(uname -r)"; then
        skip_test "内核CONFIG_PREEMPT_RT配置开启"
    fi

    # @预置条件: 创建一个cgroup
    mkdir "$CGROUP_TOPDIR"/memory/$CGROUP
    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 关闭系统上的所有交换空间并设置cgroup的内存限制为50M
    echo 0 >"$CGROUP_TOPDIR"/memory/$CGROUP/memory.swappiness
    echo 50M >"$CGROUP_TOPDIR"/memory/$CGROUP/memory.soft_limit_in_bytes

    # @测试步骤:2: 分配100M内存
    echo $$ >"$CGROUP_TOPDIR"/memory/$CGROUP/cgroup.procs
    "$TST_TS_TOPDIR"/tst_lib/cgroup_util/bin/alloc_anon 100M

    # @测试步骤:3: 获取cgroup的最大内存使用量
    max_usage_in_bytes=$(cat "$CGROUP_TOPDIR"/memory/$CGROUP/memory.max_usage_in_bytes)
    msg "max_usage_in_bytes: $max_usage_in_bytes"

    # @测试步骤:4: 获取该cgroup被oom killer杀死的进程数
    oom_control=$(cat "$CGROUP_TOPDIR"/memory/$CGROUP/memory.oom_control)
    oom_kill=$(echo "$oom_control" | awk 'NR==3 {print $2}')
    msg "oom_kill: $oom_kill"

    # @预期结果:1: 最大内存使用量超过了50M且oom_kill等于0
    if [ "$max_usage_in_bytes" -gt "52428800" ]; then
        assert_true [ "$oom_kill" -eq "0" ]
    else
        assert_false [ true ]
    fi

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
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
