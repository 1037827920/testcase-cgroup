#!/bin/bash
###############################################################################
# @用例ID: 20240708-202749-391700569
# @用例名称: cgroup-v1-cpuacct-usage_percpu
# @用例级别: 1
# @用例标签: cgroup-v1 cpuacct usage_percpu
# @用例类型: 测试cpuacct.usage_percpu接口文件
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

CGROUP="cgroup-v1-cpuacct-usage_percpu"

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
    mkdir "$CGROUP_TOPDIR"/cpuset/$CGROUP
    # @预置条件: 设置cpuset.mems文件
    echo 0 >"$CGROUP_TOPDIR"/cpuset/$CGROUP/cpuset.mems
    # @获取系统cpu的数量
    cpu_nums=$(grep -c ^processor /proc/cpuinfo)
    msg "cpu_nums: $cpu_nums"
    for_cpu_nums=$((cpu_nums - 2))

    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 获取cpu online list
    file_path="$CGROUP_TOPDIR"/cpuset/cpuset.effective_cpus
    cpu_online_list=$(get_online_cpu_list "$file_path")
    msg "cpu_online_list: $cpu_online_list"

    # @测试步骤:2: 获取没被独占的一个在线cpu
    ret=-1
    for i in $(seq 0 "$for_cpu_nums"); do
        first_online_cpu=$(echo "$cpu_online_list" | awk -v col="$((i + 1))" '{print $col}')
        msg "first_online_cpu: $first_online_cpu"
        if [ -z "$first_online_cpu" ]; then
            skip_test "没有足够的在线cpu"
        fi

        echo "$first_online_cpu" >"$CGROUP_TOPDIR"/cpuset/$CGROUP/cpuset.cpus && ret=0 && break
    done
    if [ $ret -ne 0 ]; then
        skip_test "没有可独占的CPU"
    fi

    # @测试步骤:3: 独占该CPU
    echo 1 >"$CGROUP_TOPDIR"/cpuset/cpuset.cpu_exclusive
    echo 1 >"$CGROUP_TOPDIR"/cpuset/$CGROUP/cpuset.cpu_exclusive

    # @测试步骤:4: 记录运行任务前的每个CPU使用时间
    usage_percpu_before=$(cat "$CGROUP_TOPDIR"/cpuacct/$CGROUP/cpuacct.usage_percpu)
    usage_percpu_before=$(echo "$usage_percpu_before" | awk -v col="$((first_online_cpu + 1))" '{print $col}')
    msg "usage_percpu_before: $usage_percpu_before"

    # @测试步骤:5: 启动一个CPU密集型任务并将其放入cgroup
    {
        while true; do :; done
    } &
    task_pid=$!
    echo $task_pid >"$CGROUP_TOPDIR"/cpuacct/$CGROUP/cgroup.procs
    echo $task_pid >"$CGROUP_TOPDIR"/cpuset/$CGROUP/cgroup.procs
    sleep 3

    # @测试步骤:6: 记录运行任务后的每CPU使用时间
    usage_percpu_after=$(cat "$CGROUP_TOPDIR"/cpuacct/$CGROUP/cpuacct.usage_percpu)
    usage_percpu_after=$(echo "$usage_percpu_after" | awk -v col="$((first_online_cpu + 1))" '{print $col}')
    msg "usage_percpu_after: $usage_percpu_after"

    # @预期结果:1: 验证统计数据是否正确反映了CPU使用情况
    assert_true [ "$usage_percpu_after" -gt "$usage_percpu_before" ]

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 清理后台进程
    kill -9 "$task_pid"
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/cpuacct/$CGROUP
    rmdir "$CGROUP_TOPDIR"/cpuset/$CGROUP
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
