#!/bin/bash
###############################################################################
# @用例ID: 20240730-141048-321945091
# @用例名称: cgroup-v1-perf_event
# @用例级别: 3
# @用例标签: cgroup-v1 perf_event
# @用例类型: 测试perf_event子系统
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

CGROUP="cgroup-v1-perf_event"
CHILD0="$CGROUP/child0"
CHILD1="$CGROUP/child1"
TMP_FILE=$(mktemp)

tc_setup() {
    msg "this is tc_setup"
    # @预置条件: 检查cgroup版本是否为cgroup v1
    if ! check_cgroup_version_is_v1; then
        skip_test "cgroup版本不是v1"
    fi
    # @预置条件: 检查是否安装了perf工具
    if ! is_perf_installed; then
        skip_test "没有安装perf工具"
    fi

    # @预置条件: 创建cgroup
    mkdir "$CGROUP_TOPDIR"/perf_event/$CGROUP
    mkdir "$CGROUP_TOPDIR"/perf_event/$CHILD0
    mkdir "$CGROUP_TOPDIR"/perf_event/$CHILD1

    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 启动一个进程并将其加入CHILD0
    {
        while true; do :; done
    } &
    task_pid0=$!
    echo "$task_pid0" >"$CGROUP_TOPDIR"/perf_event/$CHILD0/cgroup.procs

    # @测试步骤:2: 启动一个进程并将其加入CHILD1
    {
        while true; do :; done
    } &
    task_pid1=$!
    echo "$task_pid1" >"$CGROUP_TOPDIR"/perf_event/$CHILD1/cgroup.procs

    # @测试步骤:2: 使用perf工具监控进程, 睡眠1s
    perf stat -e cpu-clock -a -G $CGROUP sleep 1 &>"$TMP_FILE"
    cpu_clock=$(grep "cpu-clock" "$TMP_FILE" | awk '{print $1}' | tr -d ',')
    cpu_clock=$(echo "scale=2; $cpu_clock / 1000" | bc)
    msg "cpu_clock: $cpu_clock"

    # @预期结果:1: 因为CGROUP中有两个进程, 所以cpu-clock在误差允许的范围内等于2s
    if [ "$(echo "$cpu_clock > 1.8" | bc)" -eq 1 ]; then
        assert_true [ "$(echo "$cpu_clock < 2.2" | bc)" -eq 1 ]
    else
        assert_false [ true ]
    fi
    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: kill后台进程
    kill -9 "$task_pid0" "$task_pid1"
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/perf_event/$CHILD0
    rmdir "$CGROUP_TOPDIR"/perf_event/$CHILD1
    rmdir "$CGROUP_TOPDIR"/perf_event/$CGROUP
    # @清理工作: 删除临时文件
    rm "$TMP_FILE"
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
