#!/bin/bash
###############################################################################
# @用例ID: 20240807-205257-782673483
# @用例名称: cgroup-v2-memory-pressure
# @用例级别: 2
# @用例标签: cgroup-v2 memory pressure
# @用例类型: 测试memory.pressure接口文件，设置内存压力通知
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

CGROUP="cgroup-v2-memory-pressure"
TMP_FILE=$(mktemp)

tc_setup() {
    msg "this is tc_setup"
    # @预置条件: 检查cgroup版本是否为cgroup v2
    if ! check_cgroup_version_is_v2; then
        skip_test "cgroup版本不是v2"
    fi

    # @预置条件: 创建cgroup
    mkdir "$CGROUP_TOPDIR"/$CGROUP
    # @预置条件: 检查当前cgroup是否能启用memory控制器
    if ! check_string_in_file "memory" "$CGROUP_TOPDIR/cgroup.controllers"; then
        skip_test "当前cgroup不能启用memory控制器"
    fi
    # @预置条件: 启用memory控制器
    echo "+memory" >"$CGROUP_TOPDIR"/cgroup.subtree_control || return 1

    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 启用cgroup.pressure
    echo 1 >"$CGROUP_TOPDIR"/$CGROUP/cgroup.pressure || return 1

    # @测试步骤:2: 设置memory.high为50MB
    echo 50M >"$CGROUP_TOPDIR"/$CGROUP/memory.high

    # @测试步骤:3: 关闭CGROUP上的memory.swap.max
    echo 0 >"$CGROUP_TOPDIR"/$CGROUP/memory.swap.max

    # @测试步骤:4: 注册触发器
    stdbuf -oL "$TST_TS_TOPDIR"/tst_lib/cgroup_util/bin/pressure_listener "$CGROUP_TOPDIR"/$CGROUP/memory.pressure &>"$TMP_FILE" &

    # @测试步骤:5: 运行两个30MB的匿名分配进程
    echo $$ >"$CGROUP_TOPDIR"/$CGROUP/cgroup.procs
    "$TST_TS_TOPDIR"/tst_lib/cgroup_util/bin/alloc_anon 30M &
    sleep 2
    "$TST_TS_TOPDIR"/tst_lib/cgroup_util/bin/alloc_anon 30M &
    sleep 2

    # @测试步骤:6: 读取memor.pressure文件
    memory_pressure=$(cat "$CGROUP_TOPDIR"/$CGROUP/memory.pressure)
    avg10=$(echo "$memory_pressure" | awk 'NR==1 {for(i=1;i<=NF;i++) if ($i ~ /^avg10=/) {split($i, a, "="); print a[2]}}')
    msg "avg10: $avg10"
    sleep 8

    # @预期结果:1: avg10值应该大于0
    assert_true [ "$(echo "$avg10 > 0" | bc)" -eq 1 ]

    # @预期结果:2: 触发器应该被触发
    msg "file content: $(cat "$TMP_FILE")"
    if grep -q "event triggered" "$TMP_FILE"; then
        assert_true [ true ]
    else
        assert_false [ true ]
    fi

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 将shell进程移出cgroup
    echo $$ >"$CGROUP_TOPDIR"/cgroup.procs
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/$CGROUP
    # @清理工作: 删除临时文件
    rm "$TMP_FILE"
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
