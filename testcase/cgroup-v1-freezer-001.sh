#!/bin/bash
###############################################################################
# @用例ID: 20240724-155849-953242621
# @用例名称: cgroup-v1-freezer-001
# @用例级别: 1
# @用例标签: cgroup-v1 freezer
# @用例类型: 测试freezer的正常使用
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

CGROUP="cgroup-v1-freezer-001"
TMP_FILE="$(mktemp)"

tc_setup() {
    msg "this is tc_setup"
    # @预置条件: 检查cgroup版本是否为cgroup v1
    if ! check_cgroup_version_is_v1; then
        skip_test "cgroup版本不是v1"
    fi
    # @预置条件: 检查是否开启了CONFIG_CGROUP_FREEZER配置
    if ! grep -q CONFIG_CGROUP_FREEZER=y /boot/config-"$(uname -r)"; then
        skip_test "内核CONFIG_CGROUP_FREEZER配置未开启"
    fi

    # @预置条件: 创建一个cgroup
    mkdir "$CGROUP_TOPDIR"/freezer/$CGROUP
    return 0
}

do_test() {
    msg "this is do_test"
    # @测试步骤:1: 查看当前的freezer状态
    freezer_state=$(cat "$CGROUP_TOPDIR"/freezer/$CGROUP/freezer.state)

    # @预期结果:1: 当前cgroup状态为THAWED
    if [ "$freezer_state" == "THAWED" ]; then
        assert_true [ true ]
    else
        msg "测试失败: cgroup状态为$freezer_state, 而不是THAWED"
        assert_false [ true ]
    fi

    # @测试步骤:2: 创建一个后台进程，定期输出到文件
    {
        while true; do
            echo "$(date +%s): Runnnig..." >>"$TMP_FILE"
            sleep 1
        done
    } &
    task_pid=$!
    echo $task_pid >"$CGROUP_TOPDIR"/freezer/$CGROUP/cgroup.procs
    sleep 5

    # @测试步骤:3: 将cgroup状态设置为FROZEN
    echo "FROZEN" >"$CGROUP_TOPDIR"/freezer/$CGROUP/freezer.state

    # @测试步骤:4: 进程再睡眠5秒
    sleep 5

    # @测试步骤:5: 获取文件最后更新
    last_update=$(tail -n 1 "$TMP_FILE" | cut -d ':' -f 1)
    msg "last_update: $last_update"
    current_time=$(date +%s)
    msg "current_time: $current_time"
    diff=$((current_time - last_update))
    msg "diff: $diff"

    # @预期结果:2: 文件最后更新时间比现在时间至少差5s
    if [ $diff -ge 5 ]; then
        assert_true [ true ]
    else
        msg "测试失败: 进程没有被冻结"
        assert_false [ true ]
    fi

    # @测试步骤:6: 将cgroup状态设置为THAWED
    echo "THAWED" >"$CGROUP_TOPDIR"/freezer/$CGROUP/freezer.state
    sleep 1

    # @测试步骤:7: 获取文件最后更新
    last_update=$(tail -n 1 "$TMP_FILE" | cut -d ':' -f 1)
    msg "last_update: $last_update"
    current_time=$(date +%s)
    msg "current_time: $current_time"
    diff=$((current_time - last_update))
    msg "diff: $diff"

    # @预期结果:3: 文件最后更新时间跟当前时间一致, 误差最大为1s
    if [ $diff -le 1 ]; then
        assert_true [ true ]
    else
        msg "测试失败: 进程没有被解冻"
        assert_false [ true ]
    fi

    return 0
}

tc_teardown() {
    msg "this is tc_teardown"
    # @清理工作: 清理后台进程
    kill -9 "$task_pid"
    sleep 1
    # @清理工作: 删除cgroup
    rmdir "$CGROUP_TOPDIR"/freezer/$CGROUP
    # @清理工作: 删除临时文件
    rm "$TMP_FILE"
    return 0
}

###############################################################################
tst_main "$@"
###############################################################################
