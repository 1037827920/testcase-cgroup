#!/bin/bash
###############################################################################
# @用例ID: 20240708-214708-138227018
# @用例名称: cgroup-v1-cpuacct-usage_user
# @用例级别: 2
# @用例标签: cgroup-v1 cpuacct usage_user
# @用例类型: 测试cpuacct.usage_user接口文件
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

CGROUP="cgroup-v1-cpuacct-usage_user"

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
    # @测试步骤:1: 记录运行任务前的用户态CPU使用时间
    usage_user_before=$(cat "$CGROUP_TOPDIR"/cpuacct/$CGROUP/cpuacct.usage_user)
    msg "usage_user_before: $usage_user_before ns"

    # @测试步骤:2: 启用一个任务并将其放入cgroup
    {
        for _ in {1..100}; do
            echo -e "line1\nline2\nline3" | awk 'END {print NR}' &> /dev/null
        done
    } &
    task_pid=$!
    echo $task_pid >"$CGROUP_TOPDIR"/cpuacct/$CGROUP/cgroup.procs
    wait $task_pid

    # @测试步骤:3: 记录运行任务后的用户态CPU使用时间
    usage_user_after=$(cat "$CGROUP_TOPDIR"/cpuacct/$CGROUP/cpuacct.usage_user)
    msg "usage_user_after: $usage_user_after ns"

    # @预期结果:1: 验证统计数据是否正确反映了用户态CPU使用情况，即用户态CPU使用时间增加
    assert_true [ "$usage_user_after" -gt "$usage_user_before" ]

    return 0
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
