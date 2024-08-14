#!/bin/bash
###############################################################################
# @用例ID: 20240709-001807-562305058
# @用例名称: cgroup-v1-cpuacct-stat
# @用例级别: 1
# @用例标签: cgroup-v1 cpuacct stat
# @用例类型: 测试cpuacct.stat接口文件
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

CGROUP="cgroup-v1-cpuacct-stat"

tc_setup() {
    msg "this is tc_setup"
    # @预置条件: 检查cgroup版本是否为cgroup v1
    if ! check_cgroup_version_is_v1; then
        skip_test "cgroup版本不是v1"
    fi
    # @预置条件: 检查是否开启了CONFIG_CGROUP_CPUACCT配置
    if ! grep -q CONFIG_CGROUP_CPUACCT=y /boot/config-"$(uname -r)"; then
        skip_test "内核CONFIG_CGROUP_CPUACCT配置未开启"
    fi

    # @预置条件: 创建一个新的cgroup
    mkdir "$CGROUP_TOPDIR"/cpuacct/$CGROUP

    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 记录运行任务前stat值，单位为USER_HZ
    stat_before=$(cat "$CGROUP_TOPDIR"/cpuacct/$CGROUP/cpuacct.stat)
    msg "stat_before: $stat_before"

    # @测试步骤:2: 启动一个任务并将其加入cgroup
    {
        for _ in {1..100}; do
            echo -e "line1\nline2\nline3" | awk 'END {print NR}' &> /dev/null
        done
    } &
    task_pid=$!
    echo $task_pid >"$CGROUP_TOPDIR"/cpuacct/$CGROUP/cgroup.procs
    wait $task_pid

    # @测试步骤:3: 记录运行任务后的stat值
    stat_after=$(cat "$CGROUP_TOPDIR"/cpuacct/$CGROUP/cpuacct.stat)
    msg "stat_after: $stat_after"
    user_before=$(echo "$stat_before" | grep user | awk '{print $2}')
    sys_before=$(echo "$stat_before" | grep system | awk '{print $2}')
    user_after=$(echo "$stat_after" | grep user | awk '{print $2}')
    sys_after=$(echo "$stat_after" | grep system | awk '{print $2}')

    # @预期结果:1:如果用户态和内核态CPU使用情况都有增加，则认为测试通过
    if [ "$user_after" -gt "$user_before" ] && [ "$sys_after" -gt "$sys_before" ]; then
        assert_true [ true ]
        return 0
    fi

    return 1
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/cpuacct/$CGROUP
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
