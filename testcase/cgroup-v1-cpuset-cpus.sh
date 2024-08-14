#!/bin/bash
###############################################################################
# @用例ID: 20240714-134537-428824230
# @用例名称: cgroup-v1-cpuset-cpus
# @用例级别: 1
# @用例标签: cgroup-v1 cpuset cpus
# @用例类型: 测试cpuset.cpus接口文件
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

CGROUP="cgroup-v1-cpuset-cpus"
TMP_FILE="$(mktemp)"

tc_setup() {
    msg "this is tc_setup"
    # @预置条件: 检查cgroup版本是否为cgroup v1
    if ! check_cgroup_version_is_v1; then
        skip_test "cgroup版本不是v1"
    fi
    # @预置条件: 检查是否安装了mpstat命令
    if ! is_sysstat_installed; then
        skip_test "没有安装mpstat命令"
    fi

    # @预置条件: 创建一个新的cgroup
    mkdir "$CGROUP_TOPDIR"/cpuset/$CGROUP
    # @预置条件: 设置cpuset.mems文件
    echo 0 >"$CGROUP_TOPDIR"/cpuset/$CGROUP/cpuset.mems
    # @预置条件: 获取系统cpu的数量
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

    # @测试步骤:4: 启动一个进程并将其放入cgroup
    {
        while true; do :; done
    } &
    task_pid=$!
    echo $task_pid >"$CGROUP_TOPDIR"/cpuset/$CGROUP/cgroup.procs
    sleep 3

    # @测试步骤:5: 通过mpstat获取first_online_cpu的使用情况（3s）
    cpu0_user_time=$(mpstat -P "$first_online_cpu" 1 3 | grep Average | awk 'NR==2 {print $3}')
    msg "cpu0_user_time: $cpu0_user_time"

    # @预期结果:1: 验证CPU的使用率大于50%
    assert_true [ "$(echo "$cpu0_user_time > 50.0" | bc)" -eq 1 ]

    # @测试步骤:6: 检查进程绑定的CPU
    cpus_allowed=$(cat /proc/$task_pid/status | grep "Cpus_allowed_list" | awk '{print $2}')

    # @预期结果:2: 验证进程是否只在指定的CPU上运行
    assert_true [ "$cpus_allowed" = "$first_online_cpu" ]

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 清理后台进程
    kill -9 "$task_pid"
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/cpuset/$CGROUP
    # @清理工作: 删除临时文件
    rm "$TMP_FILE"
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
