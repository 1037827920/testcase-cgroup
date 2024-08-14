#!/bin/bash
###############################################################################
# @用例ID: 20240707-111241-514473309
# @用例名称: cgroup-v1-cpuacct-usage
# @用例级别: 1
# @用例标签: cgroup-v1 cpuacct usage
# @用例类型: 测试cpuacct.usage接口文件
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

CGROUP="cgroup-v1-cpuacct-usage"

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

    # @预置条件：创建一个新的cgroup
    mkdir "$CGROUP_TOPDIR"/cpuacct/$CGROUP
    return 0
}

do_test() {
    msg "Running test"

    # @测试步骤:1: 将脚本自身进程放入cgroup
    echo $$ >"$CGROUP_TOPDIR"/cpuacct/$CGROUP/cgroup.procs

    # @测试步骤:2: 运行一个CPU密集型任务
    for i in {1..10000}; do echo "$i" >/dev/null; done

    # @测试步骤:3: 获取cpuacct.usage统计数据
    usage_before=$(cat "$CGROUP_TOPDIR"/cpuacct/$CGROUP/cpuacct.usage)
    msg "usage_before: $usage_before ns"

    # @测试步骤:4: 再运行一个CPU密集型任务
    for i in {1..10000}; do echo "$i" >/dev/null; done

    # @测试步骤:5: 获取cpuacct.usage统计数据
    usage_after=$(sudo cat "$CGROUP_TOPDIR"/cpuacct/$CGROUP/cpuacct.usage)
    msg "usage_after: $usage_after ns"

    # @预期结果:1: 验证统计数据是否正确反映了CPU使用情况，即CPU使用时间增加
    assert_true [ "$usage_after" -gt "$usage_before" ] || {
        msg "usage_after: $usage_after <= usage_before: $usage_before"
        return 1
    }

    return 0
}

tc_teardown() {
    msg "Cleaning up test environment"
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/cpuacct/$CGROUP
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
