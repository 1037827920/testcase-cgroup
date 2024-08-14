#!/bin/bash
###############################################################################
# @用例ID: 20240812-171005-611037314
# @用例名称: cgroup-v1-cpu-cfs-002
# @用例级别: 1
# @用例标签: cgroup-v1 cpu cfs
# @用例类型: 测试cpu.cfs_period_us和cpu.cfs_quota_us接口文件
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

CGROUP="cgroup-v1-cpu-cfs-002"

tc_setup() {
    msg "this is tc_setup"    
    
    # @预置条件: 检查cgroup版本是否为cgroup v1
    if ! check_cgroup_version_is_v1; then
        skip_test "cgroup版本不是v1"
    fi

    # @预置条件: 创建一个新的cgroup
    mkdir "$CGROUP_TOPDIR"/cpu/$CGROUP

    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 设置cpu.cfs_period_us和cpu.cfs_quota_us
    echo 500000 >"$CGROUP_TOPDIR"/cpu/"${CGROUP}"/cpu.cfs_period_us
    echo 1000000 >"$CGROUP_TOPDIR"/cpu/"${CGROUP}"/cpu.cfs_quota_us

    # @测试步骤:2: 启动一个占用CPU的进程，并将其放入cgroup
    {
        while true; do :; done
    } &
    task_pid=$!
    echo $task_pid >"$CGROUP_TOPDIR"/cpu/$CGROUP/cgroup.procs

    sleep 3

    # @测试步骤:3: 读取cpu.stat文件
    cpu_stat=$(cat "$CGROUP_TOPDIR"/cpu/"${CGROUP}"/cpu.stat)
    nr_periods=$(echo "$cpu_stat" | grep nr_periods | awk '{print $2}')
    nr_throttled=$(echo "$cpu_stat" | grep nr_throttled | awk '{print $2}')
    throttled_time=$(echo "$cpu_stat" | grep throttled_time | awk '{print $2}')
    msg "nr_periods: $nr_periods"
    msg "nr_throttled: $nr_throttled"
    msg "throttled_time: $throttled_time"

    # @预期结果:1: cpu.stat文件中的nr_periods等于6s, nr_throttled和throttled_time等于0
    if [ "$nr_periods" -eq 6 ] && [ "$nr_throttled" -eq 0 ]; then
        assert_true [ "$throttled_time" -eq 0 ]
    else
        assert_false [ true ]
    fi

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 清理后台进程
    kill -9 "$task_pid"
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/cpu/$CGROUP
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
