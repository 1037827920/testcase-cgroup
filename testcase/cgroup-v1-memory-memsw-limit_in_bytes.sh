#!/bin/bash
###############################################################################
# @用例ID: 20240723-131832-170355139
# @用例名称: cgroup-v1-memory-memsw-limit_in_byte
# @用例级别: 1
# @用例标签: cgroup-v1 memory memsw limit_in_bytes
# @用例类型: 测试memory.memsw.limit_in_bytes接口文件
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

CGROUP="cgroup-v1-memory-memsw-limit_in_byte"

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
    # @预置条件: 检查是否开启了CONFIG_SWAP配置
    if ! grep -q CONFIG_SWAP=y /boot/config-"$(uname -r)"; then
        skip_test "内核CONFIG_SWAP配置未开启"
    fi

    # @预置条件: 创建一个cgroup
    mkdir "$CGROUP_TOPDIR"/memory/$CGROUP
    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 设置cgroup的内存和交换空间限制为50M
    echo 50M >/sys/fs/cgroup/memory/$CGROUP/memory.limit_in_bytes
    echo 50M >/sys/fs/cgroup/memory/$CGROUP/memory.memsw.limit_in_bytes

    # @测试步骤:2: 分配51M内存
    echo $$ >"$CGROUP_TOPDIR"/memory/$CGROUP/cgroup.procs
    "$TST_TS_TOPDIR"/tst_lib/cgroup_util/bin/alloc_anon 51M

    # @测试步骤:3: 获取cgroup的最大内存使用量以及内存达到memory.memsw.limit_in_bytes的次数
    max_memsw_usage_in_bytes=$(cat "$CGROUP_TOPDIR"/memory/$CGROUP/memory.memsw.max_usage_in_bytes)
    msg "max_usage_in_bytes: $max_memsw_usage_in_bytes"
    memsw_failcnt=$(cat "$CGROUP_TOPDIR"/memory/$CGROUP/memory.memsw.failcnt)
    msg "failcnt: $memsw_failcnt"

    # @测试步骤:4: 获取该cgroup被oom killer杀死的进程数
    oom_control=$(cat "$CGROUP_TOPDIR"/memory/$CGROUP/memory.oom_control)
    oom_kill=$(echo "$oom_control" | awk 'NR==3 {print $2}')
    msg "oom_kill: $oom_kill"

    # @预期结果:1: 在误差允许的范围内最大内存使用量等于50M且oom_kill大于0
    max_memsw_usage_in_bytes=$(echo "$max_memsw_usage_in_bytes / 1024 /1024 " | bc )
    if [ "$max_memsw_usage_in_bytes" -eq "50" ] && [ "$oom_kill" -gt "0" ]; then
        # @预期结果:2: 内存达到memory.memsw.limit_in_bytes的次数大于0
        assert_true  [ "$memsw_failcnt" -gt 0 ]
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
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
