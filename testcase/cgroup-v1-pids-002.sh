#!/bin/bash
###############################################################################
# @用例ID: 20240801-191404-256040067
# @用例名称: cgroup-v1-pids-002
# @用例级别: 2
# @用例标签: cgroup-v1 pids
# @用例类型: 测试pids.max控制文件, 进程数不超过限制
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

CGROUP="cgroup-v1-pids-002"
TMP_FILE="$(mktemp)"

tc_setup() {
    msg "this is tc_setup"
    # @预置条件: 检查cgroup版本是否为cgroup v1
    if ! check_cgroup_version_is_v1; then
        skip_test "cgroup版本不是v1"
    fi
    # @预置条件: 检查是否开启了CONFIG_CGROUP_PIDS配置
    if ! grep -q CONFIG_CGROUP_PIDS=y /boot/config-"$(uname -r)"; then
        skip_test "内核CONFIG_CGROUP_PIDS配置未开启"
    fi

    # @预置条件: 创建cgroup
    mkdir "$CGROUP_TOPDIR"/pids/$CGROUP
    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 设置pids.max为2
    echo 2 >"$CGROUP_TOPDIR"/pids/$CGROUP/pids.max

    # @测试步骤:2: 将当前shell加入cgroup
    echo $$ >"$CGROUP_TOPDIR"/pids/$CGROUP/cgroup.procs

    # @测试步骤:3: 运行进程并获取pids.current
    PID_NUM=$(cat "$CGROUP_TOPDIR"/pids/$CGROUP/pids.current)
    echo $$ >"$CGROUP_TOPDIR"/pids/cgroup.procs

    # @测试步骤:4: 获取超过最大进程数的次数
    FAILCNT=$(grep max "$CGROUP_TOPDIR"/pids/$CGROUP/pids.events | awk '{print $2}')
    
    # @预期结果:1: PID_NUM为2
    if [ "$PID_NUM" -eq 2 ]; then
        assert_true [ "$FAILCNT" -eq 0 ]
    else
        assert_false [ true ]
    fi

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/pids/$CGROUP
    # @清理工作: 删除临时文件
    rm "$TMP_FILE"
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
