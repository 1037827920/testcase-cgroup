#!/bin/bash
# 所有shell脚本的测试用例都应该source此文件
# 约定：
#   1、以下划线"_"开头的函数和变量用例不能直接调用
#   2、环境变量全大写，全局变量加上"g_"前置，局部变量统一加"local"修饰

# Func: 输出调试级别用例日志
dbg() {
    echo "$@" 1>&2
}

# Func: 输出普通级别用例日志
msg() {
    echo "$@" 1>&2
}

# Func: 输出错误级别用例日志，如果是用例上下文，则标记用例为失败状态
err() {
    echo "$@" 1>&2
    # 只有用例上下文才设置用例状态
    is_function _tc_fail && _tc_fail
}

is_function() {
    type "$1" 2>&1 | head -n 1 | grep "$1 is a function" >/dev/null 2>&1
    return $?
}

is_root() {
    [ "$(id -u)" == "0" ] && return 0
    return 1
}

get_up_time_sec() {
    awk -F . '{print $1}' /proc/uptime
}

get_up_time_ms() {
    local _tst_uptime
    _tst_uptime=$(awk '{print $1}' /proc/uptime | tr -d '.')
    echo -n "${_tst_uptime}0"
}

# 获取时间戳
get_timestamp_sec() {
    date +%s
}
get_timestamp_ms() {
    date +%s%N | sed "s|......$||g"
}

# 输出时间差，并将ms转换为sec
# $1 -- start time: ms
# $2 -- end time: ms
diff_time_ms2sec() {
    local _tst_diff_time=$(($2 - $1))
    local _tst_time_sec=$((_tst_diff_time / 1000))
    local _tst_time_ms=$((_tst_diff_time % 1000))
    printf "%d.%03d" $_tst_time_sec $_tst_time_ms
}

# 获取测试套名
get_suite_name() {
    basename "$TST_TS_TOPDIR"
}

# 获取测试结果文件
_get_tst_result_file() {
    if [ -z "$TST_RESULT_FILE" ]; then
        local test_index=0
        while [ $test_index -lt 10000 ]; do
            test_index=$((test_index + 1))
            [ -f "$TST_TS_TOPDIR/logs/${test_index}.result" ] && continue
            break
        done
        export TST_RESULT_ID="$test_index"
        TST_RESULT_FILE="$TST_TS_TOPDIR/logs/${test_index}.result"
        export TST_RESULT_FILE
        {
            echo "TESTSUITE"
            echo "suite-name: $(get_suite_name)"
            echo "suite-start-time: $(get_timestamp_ms)"
            echo "suite-end-time:"
            echo ""
        } >>"$TST_RESULT_FILE"
    fi
    echo "$TST_RESULT_FILE"
}
