#!/bin/bash
###############################################################################
# @用例ID: 20240810-100137-362330129
# @用例名称: cgroup-v2-cpu-stat
# @用例级别: 1
# @用例标签: cgroup-v2 cpu stat
# @用例类型: 测试cpu.stat接口文件
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

CGROUP="cgroup-v2-cpu-stat"

tc_setup() {
    msg "this is tc_setup"
    # @预置条件: 检查cgroup版本是否为cgroup v2
    if ! check_cgroup_version_is_v2; then
        skip_test "cgroup版本不是v2"
    fi

    # @预置条件: 创建cgroup
    mkdir "$CGROUP_TOPDIR"/$CGROUP
    # @预置条件: 检查当前cgroup是否能启用cpu控制器
    if ! check_string_in_file "cpu" "$CGROUP_TOPDIR/cgroup.controllers"; then
        skip_test "当前cgroup不能启用cpu控制器"
    fi
    # @预置条件: 启用cpu控制器
    echo "+cpu" >"$CGROUP_TOPDIR"/cgroup.subtree_control || return 1

    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 运行一个进程
    {
        for _ in {1..100}; do
            echo -e "line1\nline2\nline3" | awk 'END {print NR}' &>/dev/null
        done
    } &
    task_pid=$!
    echo $task_pid >"$CGROUP_TOPDIR"/$CGROUP/cgroup.procs
    wait $task_pid

    # @测试步骤:2: 读取cpu.stat中的usage_usec字段, user_usec字段的值和system_usec字段的值
    usage_usec=$(grep usage_usec "$CGROUP_TOPDIR"/$CGROUP/cpu.stat | awk '{print $2}')
    msg "usage_usec: $usage_usec"
    user_usec=$(grep user_usec "$CGROUP_TOPDIR"/$CGROUP/cpu.stat | awk '{print $2}')
    msg "user_usec: $user_usec"
    system_usec=$(grep system_usec "$CGROUP_TOPDIR"/$CGROUP/cpu.stat | awk '{print $2}')
    msg "system_usec: $system_usec"

    # @预期结果:1: usage_usec字段的值大于0, user_usec字段的值大于0, system_usec字段的值大于0
    assert_true [ "$usage_usec" -gt 0 ]
    assert_true [ "$user_usec" -gt 0 ]
    assert_true [ "$system_usec" -gt 0 ]

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/$CGROUP
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
