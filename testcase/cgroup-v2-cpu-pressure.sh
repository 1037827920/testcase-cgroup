#!/bin/bash
###############################################################################
# @用例ID: 20240804-225021-343953847
# @用例名称: cgroup-v2-cpu-pressure
# @用例级别: 2
# @用例标签: cgroup-v2 cpu pressure
# @用例类型: 测试cpu.pressure接口文件，设置CPU压力通知
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

CGROUP="cgroup-v2-cpu-pressure"
TMP_FILE=$(mktemp)

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
    # @预置条件: 获取系统cpu的数量
    cpu_nums=$(grep -c ^processor /proc/cpuinfo)
    msg "cpu_nums: $cpu_nums"
    for_cpu_nums=$((cpu_nums - 2))

    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 启用cgroup.pressure
    echo 1 >"$CGROUP_TOPDIR"/$CGROUP/cgroup.pressure || return 1

    # @测试步骤:2: 获取cpu online list
    file_path="$CGROUP_TOPDIR"/$CGROUP/cpuset.cpus.effective
    cpu_online_list=$(get_online_cpu_list "$file_path")
    msg "cpu_online_list: $cpu_online_list"

    # @测试步骤:3: 获取没被独占的一个在线cpu
    ret=-1
    for i in $(seq 0 "$for_cpu_nums"); do
        first_online_cpu=$(echo "$cpu_online_list" | awk -v col="$((i + 1))" '{print $col}')
        msg "first_online_cpu: $first_online_cpu"
        if [ -z "$first_online_cpu" ]; then
            skip_test "没有足够的在线cpu"
        fi

        echo "$first_online_cpu" >"$CGROUP_TOPDIR"/$CGROUP/cpuset.cpus && ret=0 && break
    done
    if [ $ret -ne 0 ]; then
        skip_test "没有可独占的CPU"
    fi

    # @测试步骤:4: 独占该CPU
    echo "root" >"$CGROUP_TOPDIR"/$CGROUP/cpuset.cpus.partition

    # @测试步骤:5: 设置CGROUP的cpuset.cpus为first_online_cpu
    echo "$first_online_cpu" >"$CGROUP_TOPDIR"/$CGROUP/cpuset.cpus

    # @测试步骤:6: 独占该CPU
    echo "root" >"$CGROUP_TOPDIR"/$CGROUP/cpuset.cpus.partition

    # @测试步骤:7: 注册触发器
    stdbuf -oL "${TST_TS_TOPDIR}"/tst_lib/cgroup_util/bin/pressure_listener "$CGROUP_TOPDIR"/$CGROUP/cpu.pressure &>"$TMP_FILE" &

    # @测试步骤:8: 运行两个进程并将其运行在一个CPU核心上
    {
        while true; do :; done
    } &
    task_pid1=$!
    echo $task_pid1 >"$CGROUP_TOPDIR"/$CGROUP/cgroup.procs
    {
        while true; do :; done
    } &
    task_pid2=$!
    echo $task_pid2 >"$CGROUP_TOPDIR"/$CGROUP/cgroup.procs
    sleep 10

    # @测试步骤:9: 读取cpu.pressure文件
    cpu_pressure=$(cat "$CGROUP_TOPDIR"/$CGROUP/cpu.pressure)
    msg "cpu_pressure: "
    msg "$cpu_pressure"
    avg10=$(echo "$cpu_pressure" | awk 'NR==1 {for(i=1;i<=NF;i++) if ($i ~ /^avg10=/) {split($i, a, "="); print a[2]}}')
    msg "avg10: $avg10"

    # @预期结果:1: avg10值应该大于0
    assert_true [ "$(echo "$avg10 > 0" | bc)" -eq 1 ]

    # @预期结果:2: 触发器应该被触发
    if grep -q "event triggered" "$TMP_FILE"; then
        assert_true [ true ]
    else
        assert_false [ true ]
    fi

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 清理后台进程
    kill -9 $task_pid1 $task_pid2
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/$CGROUP
    # @清理工作: 删除临时文件
    rm "$TMP_FILE"
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
