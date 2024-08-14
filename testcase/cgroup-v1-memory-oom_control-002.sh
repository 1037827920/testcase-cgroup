#!/bin/bash
###############################################################################
# @用例ID: 20240723-201033-714742346
# @用例名称: cgroup-v1-memory-oom_control-002
# @用例级别: 2
# @用例标签: cgroup-v1 memory oom_control
# @用例类型: 测试memory.oom_control接口文件，禁用oom_control
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

CGROUP="cgroup-v1-memory-oom_control-002"

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
    # @测试步骤:1: 禁用oom_control
    echo 1 >"$CGROUP_TOPDIR"/memory/$CGROUP/memory.oom_control

    # @测试步骤:2: 设置内存限制
    echo 50M >"$CGROUP_TOPDIR"/memory/$CGROUP/memory.limit_in_bytes
    echo 50M >"$CGROUP_TOPDIR"/memory/$CGROUP/memory.memsw.limit_in_bytes

    # @测试步骤:3: 运行一个分配100M内存的进程
    "$TST_TS_TOPDIR"/tst_lib/cgroup_util/bin/alloc_anon 100M &
    task_pid0=$!
    echo $task_pid0 >"$CGROUP_TOPDIR"/memory/$CGROUP/cgroup.procs
    sleep 10

    # @测试步骤:4: 获取被oom_killer杀死的进程数
    oom_control=$(cat "$CGROUP_TOPDIR"/memory/$CGROUP/memory.oom_control)
    oom_kill=$(echo "$oom_control" | awk 'NR==3 {print $2}')
    msg "oom_kill: $oom_kill"

    # @预期结果:1: 被oom_killer杀死的进程数等于0
    assert_true [ "$oom_kill" -eq "0" ]

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 清理后台进程
    kill -9 "$task_pid0"
    sleep 1
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/memory/$CGROUP
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
