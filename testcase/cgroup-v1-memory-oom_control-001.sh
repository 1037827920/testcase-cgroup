#!/bin/bash
###############################################################################
# @用例ID: 20240723-201026-919111329
# @用例名称: cgroup-v1-memory-oom_control-001
# @用例级别: 1
# @用例标签: cgroup-v1 memory oom_control
# @用例类型: 测试memory.oom_control接口文件
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

CGROUP="cgroup-v1-memory-oom_control-001"

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
    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 设置内存限制
    echo 50M >/sys/fs/cgroup/memory/$CGROUP/memory.limit_in_bytes
    echo 50M >/sys/fs/cgroup/memory/$CGROUP/memory.memsw.limit_in_bytes

    # @测试步骤:2: 51M内存
    echo $$ >"$CGROUP_TOPDIR"/memory/$CGROUP/cgroup.procs
    "$TST_TS_TOPDIR/tst_lib/cgroup_util/bin/alloc_anon" 51M

    # @测试步骤:3: 获取被oom_killer杀死的进程数
    oom_control=$(cat "$CGROUP_TOPDIR"/memory/$CGROUP/memory.oom_control)
    oom_kill=$(echo "$oom_control" | awk 'NR==3 {print $2}')
    msg "oom_kill: $oom_kill"

    # @预期结果:1: 被oom_killer杀死的进程数大于0
    assert_true [ "$oom_kill" -gt "0" ]

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 将shell进程从cgroup中移除
    echo $$ >"$CGROUP_TOPDIR"/memory/cgroup.procs
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/memory/$CGROUP
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
