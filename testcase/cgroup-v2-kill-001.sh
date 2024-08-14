#!/bin/bash
###############################################################################
# @用例ID: 20240809-234742-111875618
# @用例名称: cgroup-v2-kill-001
# @用例级别: 1
# @用例标签: cgroup-v2  kill
# @用例类型: 测试cgroup.kill接口文件
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

CGROUP="cgroup-v2-kill-001"

tc_setup() {
    msg "this is tc_setup"

    # @预置条件: 检查cgroup版本是否为cgroup v2
    if ! check_cgroup_version_is_v2; then
        skip_test "cgroup版本不是v2"
    fi

    # @预置条件: 创建cgroup
    mkdir "$CGROUP_TOPDIR"/$CGROUP

    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 运行一个进程
    {
        while true; do :; done
    } &
    task_pid=$!
    echo $task_pid >"$CGROUP_TOPDIR"/$CGROUP/cgroup.procs

    # @预期结果:1: CGROUP的cgroup.event中的populated字段为1
    populated=$(grep populated "$CGROUP_TOPDIR"/$CGROUP/cgroup.events | awk '{print $2}')
    assert_true [ "$populated" -eq 1 ]

    # @测试步骤:2: 写入cgroup.kill
    echo 1 >"$CGROUP_TOPDIR"/$CGROUP/cgroup.kill

    # @预期结果:2: CGROUP的cgroup.event中的populated字段为0
    populated=$(grep populated "$CGROUP_TOPDIR"/$CGROUP/cgroup.events | awk '{print $2}')
    assert_true [ "$populated" -eq 0 ]

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 清理后台进程
    kill -9 "$task_pid"
    sleep 1
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/$CGROUP
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
