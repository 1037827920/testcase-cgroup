#!/bin/bash
###############################################################################
# @用例ID: 20240723-193002-248259812
# @用例名称: cgroup-v1-memory-pressure_level
# @用例级别: 3
# @用例标签: cgroup-v1 memory pressure_level
# @用例类型: 测试memory.pressure_level控制文件，设置内存压力通知
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

CGROUP="cgroup-v1-memory-pressure_level"
TMP_FILE=$(mktemp)

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
    # @预置条件: 检查是否没有开启CONFIG_PREEMPT_RT配置
    if grep -q CONFIG_PREEMPT_RT=y /boot/config-"$(uname -r)"; then
        skip_test "内核CONFIG_PREEMPT_RT配置开启"
    fi

    # @预置条件: 新建一个cgroup
    mkdir "$CGROUP_TOPDIR"/memory/$CGROUP
    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 在后台运行监听器
    stdbuf -oL "${TST_TS_TOPDIR}"/tst_lib/cgroup_util/bin/cgroup_event_listener "$CGROUP_TOPDIR"/memory/$CGROUP/memory.pressure_level critical,hierarchy &>"$TMP_FILE" &

    # @测试步骤:2: 设置内存限制
    echo 50M >"$CGROUP_TOPDIR"/memory/$CGROUP/memory.limit_in_bytes
    echo 50M >"$CGROUP_TOPDIR"/memory/$CGROUP/memory.memsw.limit_in_bytes

    # @测试步骤:3: 分配51M内存
    echo $$ >"$CGROUP_TOPDIR"/memory/$CGROUP/cgroup.procs
    for _ in $(seq 1 10); do
        "$TST_TS_TOPDIR"/tst_lib/cgroup_util/bin/alloc_anon 51M
    done

    # @预期结果:1: 临时文件应该非空，有内存压力通知
    if [ -s "$TMP_FILE" ]; then
        assert_true [ true ]
    else
        assert_false [ true ]
    fi

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 将shell进程从cgroup中移除
    echo $$ >"$CGROUP_TOPDIR"/memory/cgroup.procs
    # @清理工作: 清空所有内存页
    echo 0 >"$CGROUP_TOPDIR"/memory/$CGROUP/memory.force_empty
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/memory/$CGROUP
    # @清理工作：删除临时文件
    rm "$TMP_FILE"
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
