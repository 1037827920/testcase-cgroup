#!/bin/bash
# 所有shell脚本的测试用例都应该source此文件
# 约定：
#   1、以下划线"_"开头的函数和变量用例不能直接调用
#   2、环境变量全大写，全局变量加上"g_"前置，局部变量统一加"local"修饰

export LANG="en_US.UTF-8"
export LANGUAGE="en_US:en"
export LC_ALL=en_US.UTF-8

if [ -d "$TST_TS_TOPDIR/tst_common" ]; then
    export TST_COMMON_TOPDIR="$TST_TS_TOPDIR/tst_common"
    # 先source测试用例自定义的公共文件
    source "$TST_TS_TOPDIR/tst_lib/ts_common.sh" || exit 1
    # 再source全局公共文件
    source "$TST_COMMON_TOPDIR/lib/common_func.sh" || exit 1
elif [ -d "$TST_TS_TOPDIR/lib" ]; then
    export TST_COMMON_TOPDIR="$TST_TS_TOPDIR"
    # 只是tst_suite_common使用
    source "$TST_TS_TOPDIR/lib/common_func.sh" || exit 1
else
    echo "can't find the tsuite common file"
    exit 1
fi

# 环境变量
# TST_TS_TOPDIR 测试套顶层目录
# TST_TS_SYSDIR 测试套公共运行目录
[ -z "$TST_TS_SYSDIR" ] && export TST_TS_SYSDIR="$TST_TS_TOPDIR/logs/.ts.sysdir"
# TST_TC_SYSDIR 测试用例管理用临时目录
# TST_TC_CWD 测试用例CWD
# TST_TC_PID 测试用例主进程pid
# 下面几个为用例结果状态
export TST_PASS=0
export TST_FAIL=1
export TST_INIT=2
export TST_SKIP=3
# TST_TC_NAME 用例名称
# TST_TC_FILE 用例文件
# TST_VM_SUBNET 虚拟机子网
if [ -z "$TST_VM_SUBNET" ]; then
    TST_VM_SUBNET=$(ifconfig eth0 2>/dev/null | grep "netmask .* broadcast 192\.168\." | awk '{print $2}')
    [ -z "$TST_VM_SUBNET" ] && TST_VM_SUBNET=$(ifconfig eth1 2>/dev/null | grep "netmask .* broadcast 192\.168\." | awk '{print $2}')
    [ -z "$TST_VM_SUBNET" ] && TST_VM_SUBNET=$(ifconfig eth2 2>/dev/null | grep "netmask .* broadcast 192\.168\." | awk '{print $2}')
    TST_VM_SUBNET=${TST_VM_SUBNET%.*}
fi
export TST_VM_SUBNET

g_tst_case_start=$(get_up_time_ms)
g_tst_trap_signal=12

_tcstat_to_str() {
    case "$1" in
        "TST_PASS" | "$TST_PASS")
            echo "TST_PASS"
            ;;
        "TST_FAIL" | "$TST_FAIL")
            echo "TST_FAIL"
            ;;
        "TST_INIT" | "$TST_INIT")
            echo "TST_INIT"
            ;;
        "TST_SKIP" | "$TST_SKIP")
            echo "TST_SKIP"
            ;;
        *)
            echo "TST_UNKNOWN"
            ;;
    esac
}

# 获取用例属性
# $1 -- 用例属性名称，例如：用例ID、用例名称
_get_case_attr() {
    grep "@${1}:" "$TST_TC_FILE_FULL" | head -n 1 | sed "s|.*@${1}:\s*||g" | sed "s|\s*$||g"
}
_get_case_preconditions() {
    grep "@预置条件:" "$TST_TC_FILE_FULL"
}
_get_case_steps() {
    grep "@测试步骤:" "$TST_TC_FILE_FULL"
}
_get_case_expect() {
    grep "@预期结果:" "$TST_TC_FILE_FULL"
}

# 功能：设置环境变量
# 参数：
#   $1 -- 环境变量名
#   $2 -- 环境变量值
# 返回值：
#   0 -- 环境变量设置成功
#   1 -- 环境变量设置失败
setup_env_var() {
    local _tst_var_name="$1"
    local _tst_old_value
    eval _tst_old_value=\"\$"${1}"\"
    local _tst_new_value="$2"

    if ! echo "$_tst_var_name" | grep "^[A-Z_]\+$" >/dev/null; then
        msg "the var name must be upper and '_'"
        return 1
    fi
    [ -n "$_tst_old_value" ] && msg "the environment variable $_tst_var_name has old value: $_tst_old_value"
    eval export "$_tst_var_name"=\""$_tst_new_value"\"
    echo "export $_tst_var_name=\"$_tst_new_value\"" >>"$TST_TS_SYSDIR/environment_variable"
    return 0
}

# 功能：将K/M/G/T等单位互相转换
# 参数：wait_proc_exit -p pid [-t timeout] [-s signal]
#   -p pid 【必选参数】进程pid
#   -t timeout 【可选参数】等待超时时间（单位：秒，不指定时默认等待60秒），如果等待超时进程仍未退出则返回失败
#   -s signal 【可选参数】必须配合-t参数使用，超时时间到期后发送-s指定信号到进程
# 返回值：
#   0 -- 进程退出
#   1 -- 等待失败
wait_proc_exit() {
    local _tst_all_args="$*"
    local _tst_pid
    local _tst_timeout
    local _tst_signal
    while [ $# -gt 0 ]; do
        case "$1" in
            "-p")
                shift
                _tst_pid="$1"
                shift
                ;;
            "-t")
                shift
                _tst_timeout="$1"
                shift
                ;;
            "-s")
                shift
                _tst_signal="$1"
                shift
                ;;
            *)
                msg "unknown args $1 in $_tst_all_args"
                return 1
                ;;
        esac
    done
    if [ -z "$_tst_pid" ]; then
        msg "pid not set"
        return 1
    fi
    [ -z "$_tst_timeout" ] && _tst_timeout=60

    local _tst_time_start
    _tst_time_start="$(get_uptime)"
    local _tst_time_now
    _tst_time_now="$(get_uptime)"
    while [ $((_tst_time_start + _tst_timeout)) -gt "$_tst_time_now" ]; do
        [ -d "/proc/$_tst_pid" ] || return 0
        sleep 1
        _tst_time_now="$(get_uptime)"
    done
    [ -n "$_tst_signal" ] && kill -s "$_tst_signal" "$_tst_pid"
    sleep 1
    [ -d "/proc/$_tst_pid" ] || return 0
    return 1
}

# 功能：获取系统启动后到现在的时间，单位：秒
# 参数：无
# 返回值：标准输出时间
get_uptime() {
    awk -F . '{print $1}' /proc/uptime
}

# 功能：将K/M/G/T等单位互相转换
# 参数：conv_unit [-i k|m|g|t] [-o k|m|g|t] value[_with_unit]
#   -i k|m|g|t 【可选参数】输入数据的单位，可选参数，若不指定单位，则默认为1，或者输入的值后面带参数
#   -o k|m|g|t 【可选参数】输出数据的单位，若不指定单位，则默认为1
#   value[_with_unit] 【必选参数】需要转换的数据值，可以跟单位（只取单位第一个字母用于判断k|m|g|t）
# 返回值：标准输出转换后的结果
#   0 -- 转换成功
#   1 -- 转换失败
conv_unit() {
    local _tst_input_all
    local _tst_input_value
    local _tst_input_unit
    local _tst_output_value
    local _tst_output_unit
    while [ $# -gt 0 ]; do
        case "$1" in
            "-i")
                shift
                _tst_input_unit="$1"
                shift
                ;;
            "-o")
                shift
                _tst_output_unit="$1"
                shift
                ;;
            *)
                _tst_input_all="$_tst_input_all $1"
                shift
                ;;
        esac
    done
    # shellcheck disable=SC2001
    _tst_input_value=$(echo "$_tst_input_all" | sed "s|^[[:blank:]]*\([0-9]\+\)[[:blank:]]*\(.*\)|\1|g")
    # shellcheck disable=SC2001
    [ -z "$_tst_input_unit" ] && _tst_input_unit=$(echo "$_tst_input_all" | sed "s|^[[:blank:]]*\([0-9]\+\)[[:blank:]]*\(.*\)|\2|g" | head -c 1)
    [ -z "$_tst_input_unit" ] && _tst_input_unit="b"
    [ -z "$_tst_output_unit" ] && _tst_output_unit="b"
    if [ -z "$_tst_input_value" ]; then
        msg "no input value"
        return 1
    fi
    case "$_tst_input_unit" in
        b | B) ;;
        k | K)
            _tst_input_value=$((_tst_input_value * 1024))
            ;;
        m | M)
            _tst_input_value=$((_tst_input_value * 1024 * 1024))
            ;;
        g | G)
            _tst_input_value=$((_tst_input_value * 1024 * 1024 * 1024))
            ;;
        t | T)
            _tst_input_value=$((_tst_input_value * 1024 * 1024 * 1024 * 1024))
            ;;
        *)
            msg "unknown input unit $_tst_input_unit"
            return 1
            ;;
    esac
    case "$_tst_output_unit" in
        b | B)
            _tst_output_value=$_tst_input_value
            ;;
        k | K)
            _tst_output_value=$((_tst_input_value / 1024))
            ;;
        m | M)
            _tst_output_value=$((_tst_input_value / 1024 / 1024))
            ;;
        g | G)
            _tst_output_value=$((_tst_input_value / 1024 / 1024 / 1024))
            ;;
        t | T)
            _tst_output_value=$((_tst_input_value / 1024 / 1024 / 1024 / 1024))
            ;;
        *)
            msg "unknown output unit $_tst_output_unit"
            return 1
            ;;
    esac
    echo $_tst_output_value
    return 0
}

# 功能：ssh到环境子网中指定机器上
# 参数：
#   $1 -- 需要登录的机器IP编号
#   $* -- 要远程执行的命令及参数
# 返回值：同ssh
env_ssh() {
    local _tst_ip="${TST_VM_SUBNET}.$1"
    shift
    msg "try ssh to $_tst_ip execute: $*"
    timeout -s SIGTERM 60 ssh -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@"$_tst_ip" "$@"
}

# 功能：scp本机的文件到到环境子网中指定机器的指定路径
# 参数：
#   $1 -- scp目标机器IP编号
#   $2 -- 远程机器的目标文件夹
#   $* -- 需要从本机拷贝到远端机器的文件，可以拷贝多个文件
# 返回值：同scp
env_scpt() {
    local _tst_ip="${TST_VM_SUBNET}.$1"
    shift
    local _tst_target="$1"
    shift
    msg "try scp $* to ${_tst_ip}:$_tst_target"
    timeout -s SIGTERM 120 scp -rvq -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$@" root@"$_tst_ip":"$_tst_target"
}

# 功能：scp指定机器的文件到本机路径
# 参数：
#   $1 -- scp目标机器IP编号
#   $2 -- 本机目标文件夹
#   $* -- 需要从远端机器拷贝到本机的文件，可以拷贝多个文件
# 返回值：同scp
env_scpf() {
    local _tst_ret=0
    local _tst_ip="${TST_VM_SUBNET}.$1"
    shift
    local _tst_target="$1"
    shift
    while [ -n "$1" ]; do
        msg "try scp ${_tst_ip}:$1 to local $_tst_target"
        timeout -s SIGTERM 120 scp -rvq -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@"$_tst_ip":"$1" "$_tst_target" || _tst_ret=1
        shift
    done
    return $_tst_ret
}

# 功能：等待指定机器就绪，默认超时时间60秒
# 参数：
#   $1 -- 目标机器IP编号
#   $2 -- 【可选】等待的超时时间，默认等待60秒
# 返回值：
#   0 -- 机器在超时前就绪
#   1 -- 机器启动异常
env_wait() {
    local _tst_start_time
    _tst_start_time=$(get_uptime)
    local _tst_end_time
    _tst_end_time=$(get_uptime)
    local _tst_timeout
    if [ -z "$2" ]; then
        _tst_timeout=60
    else
        _tst_timeout=$2
    fi

    local _tst_ip="${TST_VM_SUBNET}.$1"
    msg "wait env $_tst_ip standby"
    while [ $((_tst_start_time + _tst_timeout)) -ge "$_tst_end_time" ]; do
        echo -n "."
        sleep 3
        _tst_end_time=$(get_uptime)
        ping -w 1 -W 1 -c 1 "$_tst_ip" >/dev/null 2>&1 || continue
        if env_ssh "$1" test -d /proc; then
            msg "the env with IP $_tst_ip ssh success, wait total $((_tst_end_time - _tst_start_time)) seconds"
            return 0
        else
            continue
        fi
    done
    _tst_end_time=$(get_uptime)
    msg "wait the env $_tst_ip timeout, wait total $((_tst_end_time - _tst_start_time)) seconds"
    return 1
}

_assert_trap_exit() {
    kill -s "$g_tst_trap_signal" "$TST_TC_PID"
}

# 功能：标记用例为SKIP状态（当用例不需要测试时）
# 参数：
#   $* -- 对SKIP状态标记的描述
# 返回值：无
skip_test() {
    local _tst_tc_stat
    _tst_tc_stat="$(_get_tcstat)"

    case "$_tst_tc_stat" in
        "$TST_PASS" | "$TST_INIT" | "$TST_SKIP")
            _set_tcstat "$TST_SKIP"
            msg "set testcase SKIP: $*"
            _assert_trap_exit
            ;;
        *)
            msg "set testcase SKIP fail: $*"
            err "the testcase stat is $(_tcstat_to_str "$_tst_tc_stat"), can't set to SKIP"
            ;;
    esac
}

# 功能：当表达式返回真或命令执行成功时，用例不满足测试条件，终止测试
# 参数：
#   $* -- 需要断言的表达式
# 返回值：无
skip_if_true() {
    local _tst_ret
    "$@"
    _tst_ret=$?
    if [ $_tst_ret -eq 0 ]; then
        skip_test "skip_if_true get (_tst_ret:$_tst_ret) ->" "$@"
    fi
}

# 功能：当表达式返回假或命令执行失败，用例不满足测试条件，终止测试
# 参数：
#   $* -- 需要断言的表达式
# 返回值：无
skip_if_false() {
    local _tst_ret
    "$@"
    _tst_ret=$?
    if [ $_tst_ret -ne 0 ]; then
        skip_test "skip_if_false get (_tst_ret:$_tst_ret) ->" "$@"
    fi
}

# 功能：断言表达式返回真或命令执行成功，'_cont'后缀的断言函数在断言失败后用例继续执行，不终止
# 参数：
#   $* -- 需要断言的表达式
# 返回值：无
assert_true_cont() {
    local _tst_ret
    "$@"
    _tst_ret=$?
    if [ $_tst_ret -eq 0 ]; then
        _tc_pass
        return 0
    else
        err "assert_true, but return ${_tst_ret}: $*"
        return 1
    fi
}
assert_true() {
    assert_true_cont "$@" || _assert_trap_exit
}

# 功能：断言表达式返回假或命令执行失败，'_cont'后缀的断言函数在断言失败后用例继续执行，不终止
# 参数：
#   $* -- 需要断言的表达式
# 返回值：无
assert_false_cont() {
    local _tst_ret
    "$@"
    _tst_ret=$?
    if [ $_tst_ret -ne 0 ]; then
        _tc_pass
        return 0
    else
        err "assert_false, but return ${_tst_ret}: $*"
        return 1
    fi
}
assert_false_skip() {
    assert_false_cont "$@" || _skip "expect false but true ->" "$@"
}
assert_false() {
    assert_false_cont "$@" || _assert_trap_exit
}

_set_tcstat() {
    echo "$1" >"$TST_TC_SYSDIR/tcstat"
}

_get_tcstat() {
    cat "$TST_TC_SYSDIR/tcstat" 2>/dev/null
}

_tc_pass() {
    # 只有初始状态的用例才能置为PASS，其他异常状态的用例不能从异常变为PASS
    if [ "$(cat "$TST_TC_SYSDIR/tcstat" 2>/dev/null)" == "$TST_INIT" ]; then
        _set_tcstat $TST_PASS
    fi
}

_tc_fail() {
    if [ "$(_get_tcstat)" != "$TST_FAIL" ]; then
        echo "the testcase first fail here"
    fi
    _set_tcstat $TST_FAIL
}

_tc_setup_common() {
    local _tst_ret=0

    # 只有用例的主进程才能执行此函数
    [ "$TST_TC_PID" != "$$" ] && return 0

    # 对用例执行环境进行初始化设置
    mkdir -p "${TST_TC_SYSDIR}/core"
    ulimit -c >"$TST_TC_SYSDIR/old.ulimit.c"
    ulimit -c unlimited
    cat /proc/sys/kernel/core_pattern >"$TST_TC_SYSDIR/old.proc.core_pattern"
    is_root && echo "${TST_TC_SYSDIR}/core/core-e%e-p%p-i%i-s%s-g%g-u%u-t%t.dump" >/proc/sys/kernel/core_pattern

    if is_function tc_setup_common; then
        msg "try call tc_setup_common"
        if tc_setup_common "$@"; then
            msg "call tc_setup_common success"
        else
            err "call tc_setup_common fail"
            _tst_ret=1
        fi
    else
        msg "tc_setup_common not define"
    fi

    return $_tst_ret
}

_tc_setup() {
    local _tst_ret=0

    # 只有用例的主进程才能执行此函数
    [ "$TST_TC_PID" != "$$" ] && return 0
    touch "$TST_TC_SYSDIR/tc_setup_called"
    if is_function tc_setup; then
        msg "try call tc_setup"
        if tc_setup "$@"; then
            msg "call tc_setup success"
        else
            err "call tc_setup fail"
            _tst_ret=1
        fi
    else
        msg "tc_setup not define"
    fi

    return $_tst_ret
}

_do_test() {
    local _tst_ret=0

    # 只有用例的主进程才能执行此函数
    [ "$TST_TC_PID" != "$$" ] && return 0
    if is_function do_test; then
        msg "try call do_test"
        if do_test "$@"; then
            msg "call do_test success"
        else
            err "call do_test fail"
            _tst_ret=1
        fi
    else
        err "do_test not define"
        _tst_ret=1
    fi

    return $_tst_ret
}

_tc_teardown() {
    local _tst_ret=0

    # 只有用例的主进程才能执行此函数
    [ "$TST_TC_PID" != "$$" ] && return 0
    if is_function tc_teardown; then
        msg "try call tc_teardown"
        if tc_teardown "$@"; then
            msg "call tc_teardown success"
        else
            err "call tc_teardown fail"
            _tst_ret=1
        fi
    else
        msg "tc_teardown not define"
    fi

    return $_tst_ret
}

_tc_teardown_common() {
    local _tst_ret=0

    # 只有用例的主进程才能执行此函数
    [ "$TST_TC_PID" != "$$" ] && return 0
    if is_function tc_teardown_common; then
        msg "try call tc_teardown_common"
        if tc_teardown_common "$@"; then
            msg "call tc_teardown_common success"
        else
            err "call tc_teardown_common fail"
            _tst_ret=1
        fi
    else
        msg "tc_teardown_common not define"
    fi

    # 恢复用例执行前做的初始化设置
    ulimit -c "$(cat "$TST_TC_SYSDIR/old.ulimit.c")"
    is_root && cat "$TST_TC_SYSDIR/old.proc.core_pattern" >/proc/sys/kernel/core_pattern

    return $_tst_ret
}

_tc_trap_call() {
    _tc_run_complete || exit 1
    exit 0
}

_tc_run_complete() {
    local _tst_ret=0

    # 只有用例的主进程才能执行此函数
    [ "$TST_TC_PID" != "$$" ] && return 0
    if [ -e "$TST_TC_SYSDIR/tc_setup_called" ]; then
        if _tc_teardown "$@"; then
            msg "call _tc_teardown success"
        else
            err "call _tc_teardown fail"
            _tst_ret=1
        fi
    else
        msg "the tc_setup not called, so tc_teardown ignore"
    fi
    if _tc_teardown_common "$@"; then
        msg "call _tc_teardown_common success"
    else
        err "call _tc_teardown_common fail"
        _tst_ret=1
    fi

    # TCase自动化执行框架需要用这个输出判断用例是否执行完
    echo "Global test environment tear-down"
    # 用例失败则收集系统日志上传到TCase用于定位
    case "$(_get_tcstat)" in
        "$TST_PASS")
            msg "RESULT : $TST_TC_NAME ==> [  PASSED  ]"
            rm -rf "$TST_TC_SYSDIR"
            echo "case-result: PASS" >>"$TST_RESULT_FILE"
            ;;
        "$TST_FAIL")
            msg "RESULT : $TST_TC_NAME ==> [  FAILED  ]"
            _tst_ret=1
            echo "case-result: FAIL" >>"$TST_RESULT_FILE"
            ;;
        "$TST_INIT")
            msg "RESULT : $TST_TC_NAME ==> [  NOTEST  ]"
            _tst_ret=1
            echo "case-result: ABORT" >>"$TST_RESULT_FILE"
            ;;
        "$TST_SKIP")
            msg "RESULT : $TST_TC_NAME ==> [  SKIP  ]"
            rm -rf "$TST_TC_SYSDIR"
            _tst_ret=0
            echo "case-result: SKIP" >>"$TST_RESULT_FILE"
            ;;
        *)
            msg "RESULT : $TST_TC_NAME ==> [  UNKNOWN  ]"
            _tst_ret=1
            echo "case-result: ABORT" >>"$TST_RESULT_FILE"
            ;;
    esac
    local _tst_case_end
    _tst_case_end=$(get_up_time_ms)
    msg "cost $(diff_time_ms2sec "$g_tst_case_start" "$_tst_case_end")"

    {
        echo "case-end-time: $(get_timestamp_ms)"
        echo ""
    } >>"$TST_RESULT_FILE"

    return $_tst_ret
}

_set_ts_setup_stat() {
    echo "$1" >"$TST_TS_SYSDIR/ts.setup.stat"
}

_get_ts_setup_stat() {
    cat "$TST_TS_SYSDIR/ts.setup.stat" 2>/dev/null
}

_is_ts_setup_called() {
    test -f "$TST_TS_SYSDIR/ts.setup.stat"
}

_clean_ts_setup_stat() {
    rm -rf "$TST_TS_SYSDIR/ts.setup.stat"
}

tst_main() {
    local _tst_ret=0

    if [ -z "$TST_TS_TOPDIR" ]; then
        msg "the TST_TS_TOPDIR not set"
        return 1
    fi
    if [ ! -d "$TST_TS_TOPDIR" ]; then
        msg "the TST_TS_TOPDIR=$TST_TS_TOPDIR not dir"
        return 1
    fi

    [ -f "$TST_TS_SYSDIR/environment_variable" ] && source "$TST_TS_SYSDIR/environment_variable"
    export TST_TC_PID=$$
    TST_TC_CWD="$(realpath "$(dirname "$0")")"
    export TST_TC_CWD
    TST_TC_FILE_FULL="$(realpath "$0")"
    export TST_TC_FILE_FULL
    # shellcheck disable=SC2001
    TST_TC_FILE="$(echo "$TST_TC_FILE_FULL" | sed "s|^${TST_TS_TOPDIR}/*||g")"
    export TST_TC_FILE
    TST_TC_NAME="$(_get_case_attr "用例名称")"
    export TST_TC_NAME
    export TST_TC_SYSDIR="$TST_TS_TOPDIR/logs/testcase/.tc.${TST_TC_PID}.sysdir"

    # 用于断言，有的断言会终止测试活动
    trap _tc_trap_call "$g_tst_trap_signal"

    # 生成结果记录文件
    _get_tst_result_file

    {
        echo "TESTCASE"
        echo "case-name: $TST_TC_NAME"
        echo "case-id: $(_get_case_attr "用例ID")"
        echo "case-type: case-type"
        echo "case-level: $(_get_case_attr "用例级别")"
        echo "case-label: $(_get_case_attr "用例标签")"
        echo "case-steps: $(_get_case_steps)"
        echo "case-result-id: ${TST_TC_NAME}-result-${TST_RESULT_ID}"
        echo "case-start-time: $(get_timestamp_ms)"
    } >>"$TST_RESULT_FILE"

    if _is_ts_setup_called; then
        msg "tsuite setup executed, stat is $(_get_ts_setup_stat)"
    else
        msg "tsuite setup may not executed"
    fi

    cd "$TST_TC_CWD" || return 1
    mkdir -p "$TST_TC_SYSDIR"
    _set_tcstat $TST_INIT

    if _tc_setup_common "$@"; then
        if _tc_setup "$@"; then
            msg "call _tc_setup success"
            if _do_test "$@"; then
                msg "call _do_test success"
            else
                err "call _do_test fail"
                _tst_ret=1
            fi
        else
            err "call _tc_setup fail"
            _tst_ret=1
        fi
    else
        err "call _tc_setup_common fail"
        _tst_ret=1
    fi

    _tc_run_complete "$@" || _tst_ret=1

    return $_tst_ret
}
