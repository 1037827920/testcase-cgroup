#!/bin/bash
# 测试套管理工具

export LANG=en_US.UTF-8
export LANGUAGE="en_US:en"
export LC_ALL=en_US.UTF-8

if [ -d "$TST_TS_TOPDIR/tst_common" ]; then
    source "$TST_TS_TOPDIR/tst_common/lib/common.sh" || exit 1
elif [ -d "$TST_TS_TOPDIR/lib" ]; then
    # 只是tst_suite_common使用
    source "$TST_TS_TOPDIR/lib/common.sh" || exit 1
else
    echo "can't find the tsuite common file"
    exit 1
fi

[ -z "$TST_TS_SYSDIR" ] && export TST_TS_SYSDIR="$TST_TS_TOPDIR/logs/.ts.sysdir"

tsuite_usage() {
    echo -e ""
    echo -e "./tsuite options sub_command sub_options"
    echo -e "    help: 显示帮助信息"
    echo -e "    new case sh|c|py case_name [template]: 新增测试用例"
    echo -e "        sh|c|py: 【必选】三选一，sh表示Shell脚本用例，c表示C用例，py表示Python脚本用例"
    echo -e "        case_name: 【必选】要创建的用例名，同时用作文件名"
    echo -e "        template: 【可选】不使用默认用例模板时，可以指定一个文件用作新用例模板"
    echo -e "    list: 列出本测试套的测试用例"
    echo -e "    compile: 编译测试套"
    echo -e "    setup: 执行测试套setup"
    echo -e "    run options: 执行测试用例，options可选参数如下："
    echo -e "        null: 不指定时默认执行所有用例"
    echo -e "        case_path: 执行指定用例"
    echo -e "        -l level: 执行指定级别的用例，例如：0,1,2"
    echo -e "        -f case_list: 执行指定列表文件的用例"
    echo -e "    teardown: 执行测试套teardown"
    echo -e "    clean: 执行make clean"
    echo -e "    cleanall: 执行make cleanall，在clean基础上删除所有临时文件等"
    echo -e ""
}

get_all_testcase() {
    local _tst_case_dir=./testcase
    if [ ! -d "$_tst_case_dir" ]; then
        echo "no testcase dir"
        return 1
    fi
    touch "$TST_TS_SYSDIR/all_testcase.list"
    grep -r "@用例名称:" $_tst_case_dir | awk -F : '{print $1}' | sort | uniq >"$TST_TS_SYSDIR/all_testcase.list"
}

# 获取用例属性
# $1 -- 属性名称
# $2 -- 用例文件
get_case_attr() {
    grep "@${1}:" "$2" 2>/dev/null | head -n 1 | sed "s|.*@${1}:\s*||g" | sed "s|\s*$||g"
}

tsuite_list() {
    local _tst_index=1

    get_all_testcase
    local _tst_nr_all_case
    _tst_nr_all_case=$(wc -l <"$TST_TS_SYSDIR/all_testcase.list")

    echo ""
    for i in $(seq "$_tst_nr_all_case"); do
        local _tst_case_file
        local _tst_case_name
        _tst_case_file="$(sed -n "${i}p" "$TST_TS_SYSDIR/all_testcase.list")"
        _tst_case_name=$(get_case_attr "用例名称" "$_tst_case_file")
        printf "%4d : %-30s : %s\n" $_tst_index "$_tst_case_name" "$_tst_case_file"
        _tst_index=$((_tst_index + 1))
    done
    echo ""
    echo "total $_tst_nr_all_case testcase"
    echo ""
}

# 执行单个用例
# $1 -- 用例文件，Shell和Python用例直接执行脚本文件，C可以是源码文件，也可以是二进制文件（两个文件要同名，后缀不同）
tsuite_run_one() {
    local _tst_input_file="$1"
    shift

    local _tst_ret=0
    local _tst_log_dir="$TST_TS_TOPDIR/logs/testcase"

    local _tst_exec_file
    local _tst_case_file
    # C用例
    if file "$_tst_input_file" | grep -w "ELF" >/dev/null; then
        _tst_exec_file="$_tst_input_file"
        _tst_case_file="${_tst_exec_file%.test}"
        _tst_case_file="${_tst_case_file}.c"
    elif file "$_tst_input_file" | grep -w "C source" >/dev/null; then
        _tst_exec_file="${_tst_input_file%.c}"
        _tst_exec_file="${_tst_exec_file}.test"
        _tst_case_file="${_tst_input_file}"
    else
        _tst_exec_file="${_tst_input_file}"
        _tst_case_file="${_tst_input_file}"
    fi
    local _tst_case_name
    _tst_case_name=$(get_case_attr "用例名称" "$_tst_case_file")

    mkdir -p "$_tst_log_dir"

    echo "execute $_tst_case_name: $_tst_exec_file $*"
    "$_tst_exec_file" "$@" || _tst_ret=1

    return $_tst_ret
}

# 执行指定列表文件的用例
# $1 -- 要执行的用例列表文件，每行一个用例，井号'#'表示忽略对应用例
tsuite_run_some() {
    if [ ! -f "$1" ]; then
        echo "testcase list file '$1' not exist"
    fi
    local _tst_run_list="$TST_TS_SYSDIR/run.list"
    local _tst_run_result="$TST_TS_SYSDIR/run.result"
    rm -rf "$_tst_run_list" "$_tst_run_result"
    # 去掉注释行和空行，删掉行前的空格
    grep -v "^[[:blank:]]*#" "$1" | grep -v "^[[:blank:]]*$" | sed "s|^[[:blank:]]\+||g" >"$_tst_run_list"

    local _tst_ret=0
    local _tst_nr_pass=0
    local _tst_nr_skip=0
    local _tst_nr_fail=0
    local _tst_index=1
    local _tst_nr_all_case
    _tst_nr_all_case=$(wc -l <"$_tst_run_list")
    local _tst_case_time_start
    local _tst_case_time_end
    local _tst_case_cost

    printf "\n            %-30s ==>" "ts_setup"
    if tsuite_setup >"$TST_TS_TOPDIR/logs/ts_setup.log" 2>&1; then
        echo " PASS"
    else
        echo " FAIL"
    fi
    mkdir -p "$TST_TS_TOPDIR/logs/testcase"
    for i in $(seq "$_tst_nr_all_case"); do
        local _tst_case_file
        local _tst_case_name
        local _tst_case_result
        _tst_case_file="$(sed -n "${i}p" "$_tst_run_list")"
        _tst_case_name=$(get_case_attr "用例名称" "$_tst_case_file")
        local _tst_case_log="$TST_TS_TOPDIR/logs/testcase/${_tst_case_name}.log"
        printf "%4d/%-4d : %-30s ==>" $_tst_index "$_tst_nr_all_case" "$_tst_case_name"
        _tst_case_time_start=$(get_up_time_ms)
        tsuite_run_one "$_tst_case_file" >"$_tst_case_log" 2>&1
        _tst_case_time_end=$(get_up_time_ms)
        _tst_case_cost=$(diff_time_ms2sec "$_tst_case_time_start" "$_tst_case_time_end")
        _tst_case_result=$(grep "RESULT : .* ==> \[  [A-Z]\+  \]" "$_tst_case_log" |
            tail -n 1 | sed "s|.* ==> \[  \([A-Z]\+\)  \].*|\1|g")
        case "$_tst_case_result" in
            "PASSED")
                _tst_nr_pass=$((_tst_nr_pass + 1))
                echo "$_tst_index/$_tst_nr_all_case $_tst_case_name PASS cost:$_tst_case_cost" >>"$_tst_run_result"
                echo " PASS (cost $_tst_case_cost)"
                ;;
            "SKIP")
                _tst_nr_skip=$((_tst_nr_skip + 1))
                echo "$_tst_index/$_tst_nr_all_case $_tst_case_name SKIP cost:$_tst_case_cost" >>"$_tst_run_result"
                echo " SKIP (cost $_tst_case_cost)"
                ;;
            *)
                _tst_nr_fail=$((_tst_nr_fail + 1))
                echo "$_tst_index/$_tst_nr_all_case $_tst_case_name FAIL cost:$_tst_case_cost" >>"$_tst_run_result"
                echo " FAIL (cost $_tst_case_cost)"
                _tst_ret=1
                ;;
        esac
        _tst_index=$((_tst_index + 1))
    done
    printf "            %-30s ==>" "ts_teardown"
    if tsuite_teardown >"$TST_TS_TOPDIR/logs/ts_teardown.log" 2>&1; then
        echo " PASS"
    else
        echo " FAIL"
    fi

    echo ""
    echo "total: $_tst_nr_all_case"
    echo " pass: $_tst_nr_pass"
    echo " skip: $_tst_nr_skip"
    echo " fail: $_tst_nr_fail"
    echo ""

    return $_tst_ret
}

tsuite_run_all() {
    get_all_testcase
    tsuite_run_some "$TST_TS_SYSDIR/all_testcase.list"
}

tsuite_compile() {
    local _tst_ret=0

    echo "try cleanall before compile"
    make -C "$TST_TS_TOPDIR" cleanall || _tst_ret=1
    echo "compile the testsuite"
    if which bear; then
        bear -- make -C "$TST_TS_TOPDIR" all || _tst_ret=1
    else
        make -C "$TST_TS_TOPDIR" all || _tst_ret=1
    fi

    return $_tst_ret
}

tsuite_setup() {
    local _tst_ret=0

    echo "tsuite try execute ts_setup"
    if [ -f "$TST_TS_TOPDIR/tst_common/lib/tst_ts_setup" ]; then
        "$TST_TS_TOPDIR/tst_common/lib/tst_ts_setup" || _tst_ret=1
    elif [ -f "$TST_TS_TOPDIR/lib/tst_ts_setup" ]; then
        # 只是tst_suite_common使用
        "$TST_TS_TOPDIR/lib/tst_ts_setup" || _tst_ret=1
    else
        echo "the tst_ts_setup not found"
        _tst_ret=1
    fi

    return $_tst_ret
}

tsuite_run() {
    local _tst_ret=0

    # 生成结果记录文件
    _get_tst_result_file

    if [ -z "$1" ]; then
        tsuite_run_all || _tst_ret=1
    elif [ "$1" == "-f" ]; then
        echo "Try run testcases in list file '$2'"
        tsuite_run_some "$2" || _tst_ret=1
    elif [ "$1" == "-l" ]; then
        echo "Try run testcases with level '$2'"
        rm -rf "$TST_TS_SYSDIR/level.list"
        for l in $(echo "$2" | tr ',' ' '); do
            grep -r "@用例级别:[[:blank:]]*$l" ./testcase | awk -F : '{print $1}' |
                sort | uniq >>"$TST_TS_SYSDIR/level.list"
        done
        tsuite_run_some "$TST_TS_SYSDIR/level.list" || _tst_ret=1
    else
        tsuite_run_one "$@" || _tst_ret=1
    fi

    sed -i "/^suite-end-time:/c suite-end-time: $(get_timestamp_ms)" "$TST_RESULT_FILE"

    return $_tst_ret
}

tsuite_teardown() {
    local _tst_ret=0

    mkdir -p "$TST_TS_TOPDIR/logs"
    echo "tsuite try execute ts_teardown"
    if [ -f "$TST_TS_TOPDIR/tst_common/lib/tst_ts_teardown" ]; then
        "$TST_TS_TOPDIR/tst_common/lib/tst_ts_teardown" || _tst_ret=1
    elif [ -f "$TST_TS_TOPDIR/lib/tst_ts_teardown" ]; then
        # 只是tst_suite_common使用
        "$TST_TS_TOPDIR/lib/tst_ts_teardown" || _tst_ret=1
    else
        echo "the tst_ts_setup not found"
        _tst_ret=1
    fi

    return $_tst_ret
}

tsuite_clean() {
    local _tst_ret=0

    make -C "$TST_TS_TOPDIR" clean || _tst_ret=1

    return $_tst_ret
}

tsuite_cleanall() {
    local _tst_ret=0

    make -C "$TST_TS_TOPDIR" cleanall || _tst_ret=1
    rm -rfv "$TST_TS_TOPDIR/logs" "$TST_TS_TOPDIR/compile_commands.json"

    return $_tst_ret
}

# 新建用例模板
# $1 -- 用例代码类型：sh/c/py
# $2 -- 用例名
# $3 -- 可选参数，用例模板
tsuite_new_case() {
    local _tst_tc_type="$1"
    local _tst_tc_name="$2"
    local _tst_input_template="$3"
    local _tst_tc_id
    _tst_tc_id=$(date '+%Y%m%d-%H%M%S-%N')
    local _tst_tc_file="testcase/${2}.${1}"
    local _tst_template_path="$TST_TS_TOPDIR/tst_common/testcase"
    # 为了适配tst_suite_common
    [ -d "$_tst_template_path" ] || _tst_template_path="$TST_TS_TOPDIR/testcase"
    if [ ! -d "$_tst_template_path" ]; then
        echo "the template path is $_tst_template_path, not dir"
        return 1
    fi

    if [ -z "$_tst_tc_name" ]; then
        echo "the testcase name not set"
        return 1
    fi

    if [ -z "$_tst_input_template" ]; then
        case "$_tst_tc_type" in
            sh)
                cp -v "$_tst_template_path/test_shell_testcase.sh" "$TST_TS_TOPDIR/$_tst_tc_file"
                sed -i "s|}/lib/common|}/tst_common/lib/common|g" "$TST_TS_TOPDIR/$_tst_tc_file"
                ;;
            c)
                cp -v "$_tst_template_path/test_c_testcase.c" "$TST_TS_TOPDIR/$_tst_tc_file"
                ;;
            py)
                cp -v "$_tst_template_path/test_python_testcase.py" "$TST_TS_TOPDIR/$_tst_tc_file"
                sed -i "/from lib.common import TestCase/c from tst_lib.ts_common import MyTestCase" \
                    "$TST_TS_TOPDIR/$_tst_tc_file"
                sed -i "/class PythonTestCase(TestCase):/c class PythonTestCase(MyTestCase):" \
                    "$TST_TS_TOPDIR/$_tst_tc_file"
                ;;
            *)
                echo "unsupported testcase type"
                return 1
                ;;
        esac
    else
        if [ ! -f "$_tst_input_template" ]; then
            echo "the template file $_tst_input_template not exist"
            return 1
        fi
        if ! echo "$_tst_input_template" | grep "\.$_tst_tc_type$" >/dev/null; then
            echo "the template file $_tst_input_template not match the testcase type $_tst_tc_type"
            return 1
        fi
        cp -v "$_tst_input_template" "$TST_TS_TOPDIR/$_tst_tc_file"
    fi

    sed -i "s|@用例ID:.*|@用例ID: $_tst_tc_id|g" "$TST_TS_TOPDIR/$_tst_tc_file"
    sed -i "s|@用例名称:.*|@用例名称: $_tst_tc_name|g" "$TST_TS_TOPDIR/$_tst_tc_file"
    echo ""
    echo "the new testcase info:"
    echo "  name: $_tst_tc_name"
    echo "  type: $_tst_tc_type"
    echo "    id: $_tst_tc_id"
    echo "  file: $_tst_tc_file"
    echo ""
    return 0
}

# 新建测试套
# $1 -- 测试套git路径
tsuite_new_suite() {
    local _tst_git_url="$1"
    local _tst_suite_name
    _tst_suite_name=$(basename "$_tst_git_url" | sed "s|\.git$||g")

    if ! echo "$_tst_git_url" | grep "\.git$" >/dev/null; then
        echo "the git url unusable"
        return 1
    fi
    if [ -z "$_tst_suite_name" ]; then
        echo "get suite name fail"
        return 1
    fi
    if [ -d "./$_tst_suite_name" ]; then
        echo "the ./$_tst_suite_name existed"
        return 1
    fi

    echo "git clone $_tst_git_url ./$_tst_suite_name"
    if ! git clone "$_tst_git_url" "./$_tst_suite_name"; then
        echo "clone $_tst_suite_name fail"
        return 1
    fi
    if [ -d "./$_tst_suite_name/tst_common" ]; then
        echo "the suite $_tst_suite_name initialization has been completed yet"
        return 1
    fi

    echo "get suite_example: git clone https://gitee.com/opencloudos-stream/test-suite-example.git"
    rm -rf "$TST_TS_SYSDIR/suite_example"
    if ! git clone https://gitee.com/opencloudos-stream/test-suite-example.git "$TST_TS_SYSDIR/suite_example"; then
        echo "clone suite_example fail"
        rm -rf "./$_tst_suite_name"
        return 1
    fi
    cp -rv "$TST_TS_SYSDIR/suite_example"/* "./$_tst_suite_name"
    cp -rv "$TST_TS_SYSDIR/suite_example/.gitignore" "./$_tst_suite_name"
    rm -rf "$TST_TS_SYSDIR/suite_example"

    cd "./$_tst_suite_name" || return 1
    rm -rf ./tst_common
    echo "add submodule to common for $_tst_suite_name"
    if ! git submodule add https://gitee.com/opencloudos-stream/test-suite-base.git ./common; then
        echo "add submodule fail"
        cd ..
        rm -rf "./$_tst_suite_name"
        return 1
    fi

    echo "remove the sample testcase"
    rm -fv ./testcase/test_*

    return 0
}

tsuite_new() {
    local _tst_ret=0

    case $1 in
        case)
            shift
            tsuite_new_case "$@" || _tst_ret=1
            ;;
        suite)
            shift
            tsuite_new_suite "$@" || _tst_ret=1
            ;;
        *)
            echo "unknown new type: $*"
            _tst_ret=1
            ;;
    esac

    return $_tst_ret
}

tsuite_main() {
    local _tst_ret=0
    local _tst_cmd="$0 $*"
    local _tst_suite_time_start
    _tst_suite_time_start=$(get_up_time_ms)
    local _tst_suite_time_end

    echo "TST_TS_TOPDIR=$TST_TS_TOPDIR"
    cd "$TST_TS_TOPDIR" || return 1
    mkdir -p "$TST_TS_SYSDIR" || return 1

    case "$1" in
        help)
            tsuite_usage
            return 0
            ;;
        new)
            shift
            tsuite_new "$@" || _tst_ret=1
            ;;
        list)
            tsuite_list || _tst_ret=1
            ;;
        compile)
            tsuite_compile || _tst_ret=1
            ;;
        setup)
            tsuite_setup || _tst_ret=1
            ;;
        run)
            shift
            tsuite_run "$@" || _tst_ret=1
            ;;
        teardown)
            tsuite_teardown || _tst_ret=1
            ;;
        clean)
            tsuite_clean || _tst_ret=1
            ;;
        cleanall)
            tsuite_cleanall || _tst_ret=1
            ;;
        *)
            echo "$0 $*"
            tsuite_usage
            return 1
            ;;
    esac

    _tst_suite_time_end=$(get_up_time_ms)
    if [ $_tst_ret -eq 0 ]; then
        echo "execute $_tst_cmd success, cost $(diff_time_ms2sec "$_tst_suite_time_start" "$_tst_suite_time_end")"
    else
        echo "execute $_tst_cmd fail, cost $(diff_time_ms2sec "$_tst_suite_time_start" "$_tst_suite_time_end")"
    fi
    return $_tst_ret
}
